import { Router } from "express";
import { requireContentManager } from "../middleware/adminAuth";
import { requireStudentSession } from "../middleware/studentAuth";
import { createRateLimit } from "../middleware/rateLimiter";
import { logger } from "../lib/logger";
import {
  apiSupabaseConfig,
  lastScopeRejectionReason,
  matchesStudentScope,
  type StudentActor,
} from "../lib/studentAccess";
import {
  FREE_DAILY_QUESTIONS,
  GEM_PRICE,
  cacheKey,
  chargeFor,
  readQuota,
  snapshotOf,
  spend,
} from "../lib/aiQuota";
import {
  BANK_SIZE,
  BANK_VERSION,
  ROUNDS_PER_PLAY,
  bankPrompt,
  detectSubject,
  drawRounds,
  parseBank,
  readBank,
  type ChallengeBank,
} from "../lib/challengeBank";

// 20 AI-answer requests per IP per minute — prevents Gemini quota abuse
// while still allowing normal student lesson use
const answerRateLimit = createRateLimit(20);

// التحدي جولةٌ واحدة تُطلب ثمّ تُلعب، فالمعدّل أقلّ من معدّل السؤال:
// طفلٌ يُعيد اللعب بسرعة لا يتجاوز بضع جولاتٍ في الدقيقة، وما زاد فهو
// إمّا زرٌّ عالق أو استنزافٌ لحصّة Gemini.
const challengeRateLimit = createRateLimit(12);

const router = Router();

interface GeminiError extends Error {
  statusCode?: number;
}

let geminiModelsPromise: Promise<string[]> | undefined;

async function getGeminiModels(apiKey: string): Promise<string[]> {
  if (!geminiModelsPromise) {
    geminiModelsPromise = (async () => {
      const configuredModel = String(process.env.GEMINI_MODEL || "")
        .trim()
        .replace(/^models\//, "");
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models?key=${encodeURIComponent(apiKey)}`,
      );
      const data: any = await response.json().catch(() => ({}));
      if (!response.ok) {
        const error: GeminiError = new Error("Gemini model discovery failed");
        error.statusCode = response.status >= 500 ? 502 : response.status;
        throw error;
      }

      const availableModels: string[] = Array.isArray(data.models)
        ? data.models
            .filter(
              (item: any) =>
                item?.name &&
                item.supportedGenerationMethods?.includes("generateContent"),
            )
            .map((item: any) =>
              String(item.name).replace(/^models\//, ""),
            )
        : [];

      const preferredModels = [
        "gemini-flash-lite-latest",
        "gemini-2.5-flash-lite",
        configuredModel,
        "gemini-flash-latest",
        "gemini-3.1-flash-lite",
        "gemini-3.5-flash",
        "gemini-2.5-flash",
      ].filter(Boolean) as string[];

      const models = [
        ...preferredModels.filter((c) => availableModels.includes(c)),
        ...availableModels.filter(
          (c) =>
            !preferredModels.includes(c) &&
            /flash/i.test(c) &&
            !/(tts|image|audio)/i.test(c),
        ),
        ...availableModels.filter((c) => !preferredModels.includes(c)),
      ];

      if (models.length === 0) {
        const error: GeminiError = new Error(
          "No Gemini model supports generateContent",
        );
        error.statusCode = 503;
        throw error;
      }
      logger.info(`[gemini] discovered ${models.length} candidate model(s)`);
      return models.map((model) => `models/${model}`);
    })().catch((error) => {
      geminiModelsPromise = undefined;
      throw error;
    });
  }
  return geminiModelsPromise;
}

/**
 * ما ينتظره الخادم كلّه قبل أن يردّ بالفشل.
 *
 * أقصر ممّا ينتظره التطبيق (٦٠ ثانية) بهامش: الخادم يجب أن يتكلّم أولاً،
 * وإلا رأى الطفلُ انقطاعَ اتصالٍ مكان سببٍ مكتوب.
 */
const GEMINI_BUDGET_MS = 50_000;

/** سقف المحاولة الواحدة، فلا يبتلع نموذجٌ بطيء الميزانية كلّها. */
const GEMINI_SINGLE_TRY_MS = 30_000;

async function callGemini(
  prompt: string,
  {
    temperature = 0.2,
    maxOutputTokens = 2048,
    json = false,
    image,
    budgetMs = GEMINI_BUDGET_MS,
  }: {
    temperature?: number;
    maxOutputTokens?: number;
    json?: boolean;
    /** صورةُ المسألة كما التقطها الطفل: base64 بلا ترويسة. */
    image?: { data: string; mimeType: string };
    /**
     * ميزانيةُ هذا النداء وحده.
     *
     * الطلبُ الواحد صار نداءين حين تكون ثَمّ صورة — قراءةٌ ثم إجابة —
     * وكلٌّ منهما بميزانيةٍ كاملة يجعل الخادم ينتظر مئة ثانية والتطبيق
     * ينتظر ستّين. فتُقسَّم الميزانيةُ الواحدة بينهما.
     */
    budgetMs?: number;
  } = {},
): Promise<any> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    const error: GeminiError = new Error("GEMINI_API_KEY is not configured");
    error.statusCode = 503;
    throw error;
  }
  // A short ordered fallback list is more reliable than trying every model
  // returned by discovery. In particular, the general flash model can spend
  // a long time reporting high demand while the lite model is ready.
  const models = (await getGeminiModels(apiKey)).slice(0, 6);
  let lastUnavailableMessage = "";

  // ميزانية واحدة للطلب كلّه، لا مهلة لكل نموذج على حدة.
  //
  // كانت ستة نماذج × ١٨ ثانية = ١٠٨ ثوانٍ في أسوأ الحالات، والتطبيق
  // ينتظر ٢٥ — فيقطع الاتصال والخادم ما زال يجرّب. ومن هنا جاء «يجيب
  // أحياناً ويتعذّر أحياناً»: تُجاب المسألة إن وفّق أوّلُ نموذج، وتسقط
  // إن تجاوزه إلى الثاني.
  //
  // فصار للطلب حدٌّ أقصى واحد أقصر ممّا ينتظره التطبيق، ويتقاسمه ما
  // يُجرَّب من النماذج: ينتهي الخادم دائماً قبل أن ييأس العميل، فيصل
  // سببُ الفشل بدل أن ينقطع الخيط.
  const deadline = Date.now() + Math.max(4_000, budgetMs);

  for (const model of models) {
    const remaining = deadline - Date.now();
    if (remaining <= 2_000) {
      logger.warn(`[gemini] budget spent before trying ${model}`);
      break;
    }
    let response: Response;
    try {
      response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/${model}:generateContent?key=${encodeURIComponent(apiKey)}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [
              {
                parts: image
                  ? [
                      { text: prompt },
                      { inlineData: { mimeType: image.mimeType, data: image.data } },
                    ]
                  : [{ text: prompt }],
              },
            ],
            generationConfig: {
              temperature,
              maxOutputTokens,
              ...(json ? { responseMimeType: "application/json" } : {}),
            },
          }),
          // ما بقي من الميزانية، وبسقف لنموذج واحد حتى لا يبتلعها أوّلُ
          // نموذج بطيء ويحرم البقية من محاولة.
          signal: AbortSignal.timeout(
            Math.min(remaining, GEMINI_SINGLE_TRY_MS),
          ),
        },
      );
    } catch (error: any) {
      lastUnavailableMessage = error?.message || "Gemini request timed out";
      logger.warn(`[gemini] model ${model} timed out or failed: ${lastUnavailableMessage}`);
      continue;
    }
    const data: any = await response.json().catch(() => ({}));
    if (response.ok) {
      logger.info(`[gemini] generated with ${model.replace(/^models\//, "")}`);
      return data;
    }

    const message = data?.error?.message || "Gemini request failed";
    const modelUnavailable =
      response.status === 404 ||
      /not found|not available|not supported|new users/i.test(message);
    const modelBusy = response.status === 429 ||
      response.status >= 500 ||
      /high demand|overloaded|resource exhausted|temporarily unavailable/i.test(message);
    if (modelUnavailable || modelBusy) {
      lastUnavailableMessage = message;
      logger.warn(
        `[gemini] skipping ${modelBusy ? "busy" : "unavailable"} model ${model}: ${message}`,
      );
      continue;
    }

    const error: GeminiError = new Error(message);
    error.statusCode = response.status >= 500 ? 502 : response.status;
    throw error;
  }

  const error: GeminiError = new Error(
    lastUnavailableMessage || "No available Gemini model",
  );
  error.statusCode = 503;
  throw error;
}

function getGeminiText(data: any): string | null {
  return (
    data?.candidates?.[0]?.content?.parts
      ?.map((part: any) =>
        typeof part?.text === "string" ? part.text : "",
      )
      .join("")
      .trim() || null
  );
}

/**
 * الدرس، أو سبب تعذّره.
 *
 * كانت تُعيد `null` في ثلاث حالات مختلفة — لا سجلّ بهذا المعرّف، ودرسٌ
 * خارج نطاق الطالب، ودرسٌ بلا نصّ مكتوب — فيخرج منها ردٌّ واحد لا يفرّق
 * بينها. ولا يُشخَّص العطل من الخارج إن كان الخادم نفسه لا يميّزه.
 */
type LessonLookup =
  | {
      id: string;
      text: string;
      // المسار يصحب النصّ لأن التحدي يبني توجيهه على المادة: مسألةٌ
      // ذهنية للرياضيات، وظاهرةٌ للعلوم، وسؤالٌ إنجليزيّ بالكامل
      // للإنجليزية. وقراءتُه هنا تغني عن قراءة السجلّ مرّتين.
      subject: string;
      unit: string;
      lesson: string;
      /** بنك جولات التحدي المحفوظ مع الدرس، إن وُلّد من قبل. */
      challengeBank?: unknown;
      reason?: undefined;
      detail?: undefined;
    }
  | {
      reason: "not_found" | "out_of_scope" | "no_text";
      detail?: string;
      id?: undefined;
      text?: undefined;
    };

async function resolveStudentLesson(
  lessonId: string,
  student: StudentActor,
): Promise<LessonLookup> {
  const config = apiSupabaseConfig();
  if (!config || !lessonId) return { reason: "not_found" };
  const url = new URL(`${config.url}/rest/v1/lesson_configs`);
  url.searchParams.set("select", "id,data");
  url.searchParams.set("id", `eq.${lessonId}`);
  const response = await fetch(url, {
    headers: { apikey: config.key, Authorization: `Bearer ${config.key}` },
  });
  if (!response.ok) throw new Error(`Lesson lookup failed (${response.status})`);
  const rows = await response.json();
  const row = Array.isArray(rows) ? rows[0] : null;
  const data = row?.data && typeof row.data === "object" ? row.data : null;
  if (!data) return { reason: "not_found" };
  if (!matchesStudentScope(data, student)) {
    // المسار كاملاً من الطرفين: أي حقل اختلف، وبأي قيمتين. بدونه يبقى
    // «خارج المسار» جملةً لا يُشخَّص منها شيء.
    logger.warn(
      {
        lessonId,
        studentId: student.id,
        lesson: {
          grade: data.grade, subject: data.subject,
          term: data.term, unit: data.unit, lesson: data.lesson,
          owner: data.teacherId ?? data.teacher_id ?? data.createdBy,
        },
        student: {
          grade: student.grade, subject: student.subject,
          assignedSubjects: student.assignedSubjects,
          teacherId: student.teacherId,
        },
        mismatch: lastScopeRejectionReason(),
      },
      "[gemini] lesson rejected: outside the student's scope",
    );
    return { reason: "out_of_scope", detail: lastScopeRejectionReason() };
  }
  const lesson = data as Record<string, unknown>;
  const text = typeof lesson.lessonContent === "string"
    ? lesson.lessonContent.trim()
    : typeof lesson.lessonText === "string"
      ? lesson.lessonText.trim()
      : "";
  if (!text) return { reason: "no_text" };
  return {
    id: String(row.id || lessonId),
    text,
    subject: typeof lesson.subject === "string" ? lesson.subject : "",
    unit: typeof lesson.unit === "string" ? lesson.unit : "",
    lesson: typeof lesson.lesson === "string" ? lesson.lesson : "",
    challengeBank: lesson.challengeBank,
  };
}

/**
 * يحفظ البنك داخل `data` من سجلّ الدرس.
 *
 * داخل `data` لا في عمودٍ خاص: الجدول `(id, data jsonb)` ولا عمود
 * `challenge_bank` فيه، وإضافةُ عمودٍ تحتاج ترحيلاً على قاعدةٍ تعمل.
 * والقراءة تُسلَّم من `data` نفسها فلا فرق عند الاستعمال.
 *
 * ويُقرأ السجلّ قبل الكتابة ويُدمج: `PATCH` على `data` يستبدلها كاملةً،
 * فكتابةُ البنك وحده تمحو نصّ الدرس ومساره.
 */
async function persistBank(lessonId: string, bank: ChallengeBank): Promise<void> {
  const config = apiSupabaseConfig();
  if (!config) return;
  const headers = {
    apikey: config.key,
    Authorization: `Bearer ${config.key}`,
    "Content-Type": "application/json",
  };
  const read = await fetch(
    `${config.url}/rest/v1/lesson_configs?select=data&id=eq.${encodeURIComponent(lessonId)}`,
    { headers },
  );
  if (!read.ok) throw new Error(`bank read failed (${read.status})`);
  const rows = await read.json();
  const data = Array.isArray(rows) && rows[0]?.data && typeof rows[0].data === "object"
    ? (rows[0].data as Record<string, unknown>)
    : null;
  if (!data) throw new Error("lesson row vanished before the bank was saved");

  const write = await fetch(
    `${config.url}/rest/v1/lesson_configs?id=eq.${encodeURIComponent(lessonId)}`,
    {
      method: "PATCH",
      headers: { ...headers, Prefer: "return=minimal" },
      body: JSON.stringify({
        data: { ...data, challengeBank: bank },
        updated_at: new Date().toISOString(),
      }),
    },
  );
  if (!write.ok) throw new Error(`bank write failed (${write.status})`);
}

/** ما تُعطاه قراءةُ الصورة من الميزانية، وما يبقى منها للإجابة. */
const IMAGE_READ_BUDGET_MS = 12_000;

/**
 * نصُّ المسألة التي في الصورة، أو `null` إن تعذّر.
 *
 * ── لماذا نداءان لا نداء ──
 * الصورة كانت تتخطّى الذاكرة كلَّها: المفتاح لا يعرف الصورة، فصورتان
 * مختلفتان بالسؤال نفسه كانتا تعودان بجوابٍ واحد لو قُرئتا منها. فكان
 * التخطّي صواباً، وكان ثمنُه أن ثلاثين طفلاً يصوّرون المسألة نفسها من
 * الكتاب نفسه يستدعون النموذج ثلاثين مرّة — وهي أكثرُ حالاتِ التكرار
 * وروداً، لا أقلّها.
 *
 * فبدل أن يُفتاح على الصورة يُفتاح على ما فيها: تُقرأ أوّلاً قراءةً
 * قصيرة — سطرُ نصٍّ أو معادلةٍ أو وصفٌ للشكل — ثم يُبنى المفتاح من هذا
 * النصّ كما يُبنى من سؤالٍ مكتوب. فصورتان لمسألةٍ واحدة تلتقيان على
 * مفتاح، وصورتان لمسألتين تفترقان.
 *
 * ── وما تكلفته ──
 * القراءة نداءٌ صغير: مئتا رمزٍ في الخرج، وحرارةُ صفرٍ كي يقرأ الشيءَ
 * نفسه مرّتين بالعبارة نفسها. فالإصابةُ توفّر نداءً كاملاً بالصورة،
 * والإخفاقُ يزيد نداءً صغيراً. والتكرارُ هنا هو الغالب.
 *
 * ── ولا تُحسب على الطفل ──
 * هذه قراءةٌ لا إجابة: تجري قبل الحصّة وقبل الجواهر، فلا تُخصم ولا
 * تُعدّ. وطفلٌ تُنقص حصّتُه لأن الخادم قرأ صورته ثم لم يجد لها جواباً
 * محفوظاً يكون قد دفع ثمن ترتيبٍ داخليّ لا يعرفه.
 */
async function readQuestionFromImage(
  image: { data: string; mimeType: string },
  typed: string,
): Promise<string | null> {
  const prompt = `في الصورة مسألةٌ أو سؤالٌ من كتاب تلميذ.

اكتب ما في الصورة نصّاً، بلا شرحٍ ولا حلٍّ ولا مقدّمة:
- إن كان فيها نصٌّ أو معادلة، انسخها كما هي في سطرٍ واحد.
- وإن كانت شكلاً أو رسماً بلا نصٍّ كافٍ، فصفه في سطرٍ واحد قصير: نوعُ الشكل، والأرقامُ المكتوبة عليه، والمطلوب.
- وإن كانت غير واضحة، اكتب: غير واضحة

ولا تكتب شيئاً غير ذلك.`;
  try {
    const data = await callGemini(prompt, {
      image,
      temperature: 0,
      maxOutputTokens: 200,
      budgetMs: IMAGE_READ_BUDGET_MS,
    });
    const read = getGeminiText(data)?.trim() ?? "";
    // «غير واضحة» ليست نصّاً يُفتاح عليه: صورتان ضبابيّتان لمسألتين
    // مختلفتين تلتقيان عليه، فيُجاب طفلٌ عن مسألةِ غيره.
    if (!read || read.length < 4 || read.length > 600) return null;
    if (/غير\s*واضح/.test(read)) return null;
    // وما كتبه الطفل يدخل المفتاح معه: صورةٌ واحدة يُسأل عنها «احسب
    // المحيط» و«احسب المساحة» سؤالان.
    return typed && typed !== PHOTO_DEFAULT_PROMPT ? `${typed} ${read}` : read;
  } catch (error) {
    logger.warn({ err: error }, "[cache] image read failed — key skipped");
    return null;
  }
}

/**
 * السؤالُ الافتراضي حين يكتفي الطفل بالتصوير.
 *
 * مكرّرٌ في التطبيق (`PhotoQuestion.defaultPrompt`)، ويُقارَن به هنا كي
 * لا يدخل المفتاحَ نصٌّ لم يكتبه أحد.
 */
const PHOTO_DEFAULT_PROMPT = "حلّ هذه المسألة واشرح الخطوات.";

/**
 * إجابةٌ محفوظة لهذا المفتاح، أو `null`.
 *
 * كلُّ تعذّرٍ يعود بـ `null`: الذاكرة تسريعٌ لا شرط. وجدولٌ لم يُنشأ بعد
 * يجب أن يُبطئ الخدمة لا أن يُسقطها.
 */
async function readCachedAnswer(key: string): Promise<string | null> {
  const config = apiSupabaseConfig();
  if (!config) {
    logger.warn("[cache] MISS — Supabase is not configured");
    return null;
  }
  try {
    const response = await fetch(
      `${config.url}/rest/v1/ai_qa_cache?select=data&id=eq.${encodeURIComponent(key)}&limit=1`,
      { headers: { apikey: config.key, Authorization: `Bearer ${config.key}` } },
    );
    if (!response.ok) {
      // رمزُ الردّ ونصُّه معاً.
      //
      // كانت كلُّ علّةٍ تعود بـ `null` صامتةً، فيبدو الجدولُ الغائب
      // والصلاحيةُ المرفوضة والسؤالُ الجديد شيئاً واحداً — ولا يُعرف
      // لماذا لا تُصاب الذاكرة أبداً. و401/403 هنا تعني أن دور الخدمة
      // لا يملك صلاحيةً على الجدول، و404 أن الجدول لم يُنشأ.
      logger.warn(
        { status: response.status, detail: (await response.text()).slice(0, 200) },
        "[cache] MISS — read refused by the database",
      );
      return null;
    }
    const rows = await response.json();
    const answer = Array.isArray(rows) ? rows[0]?.data?.answer : null;
    if (typeof answer === "string" && answer.trim()) {
      logger.info({ key }, "[cache] HIT");
      return answer;
    }
    logger.info({ key }, "[cache] MISS — no stored answer for this key");
    return null;
  } catch (error) {
    logger.warn({ err: error }, "[cache] MISS — read failed");
    return null;
  }
}

/** يحفظ الإجابة لمن يسأل بعده. */
async function writeCachedAnswer(
  key: string,
  lessonId: string,
  question: string,
  answer: string,
): Promise<void> {
  const config = apiSupabaseConfig();
  if (!config) return;
  const now = new Date().toISOString();
  const response = await fetch(`${config.url}/rest/v1/ai_qa_cache?on_conflict=id`, {
    method: "POST",
    headers: {
      apikey: config.key,
      Authorization: `Bearer ${config.key}`,
      "Content-Type": "application/json",
      Prefer: "resolution=merge-duplicates,return=minimal",
    },
    body: JSON.stringify({
      id: key,
      // السؤال يُحفظ كما كتبه الطفل لا مطبَّعاً: المفتاح للمطابقة،
      // وهذا لمن يقرأ الجدول ليعرف عمّ سُئل.
      data: { lessonId, question, answer, createdAt: now },
      updated_at: now,
    }),
  });
  if (!response.ok) {
    throw new Error(
      `cache write failed (${response.status} ${(await response.text()).slice(0, 200)})`,
    );
  }
  logger.info({ key, lessonId }, "[cache] SAVED");
}

/** صفُّ الطالب وحصّتُه وجواهرُه. */
async function readStudentQuota(student: StudentActor): Promise<{
  quota: { state: ReturnType<typeof readQuota>; snapshot: ReturnType<typeof snapshotOf> };
  gems: number;
  rowId: string;
  data: Record<string, unknown>;
}> {
  const empty = readQuota(null);
  const config = apiSupabaseConfig();
  if (!config) {
    return { quota: { state: empty, snapshot: snapshotOf(empty, 0) }, gems: 0, rowId: "", data: {} };
  }
  const id = encodeURIComponent(student.id);
  for (const filter of [`id=eq.${id}`, `data->>id=eq.${id}`]) {
    const response = await fetch(
      `${config.url}/rest/v1/students?select=id,data&${filter}&limit=1`,
      { headers: { apikey: config.key, Authorization: `Bearer ${config.key}` } },
    );
    if (!response.ok) continue;
    const rows = await response.json();
    const row = Array.isArray(rows) ? rows[0] : null;
    if (!row) continue;
    const data = (row.data && typeof row.data === "object" ? row.data : {}) as Record<string, unknown>;
    const game = (data.gamification && typeof data.gamification === "object"
      ? data.gamification
      : {}) as Record<string, unknown>;
    const gems = Math.max(0, Number(game.gems) || 0);
    const state = readQuota(data.aiQuota);
    return {
      quota: { state, snapshot: snapshotOf(state, gems) },
      gems,
      rowId: String(row.id ?? ""),
      data,
    };
  }
  return { quota: { state: empty, snapshot: snapshotOf(empty, 0) }, gems: 0, rowId: "", data: {} };
}

/**
 * يحفظ الحصّة والجواهر بعد سؤال.
 *
 * السجلّ كاملاً ومعهما: `PATCH` على `data` يستبدلها، فكتابةُ الحصّة
 * وحدها تمحو اسم الطالب ومساره وتقدّمه.
 */
async function writeStudentQuota(
  rowId: string,
  data: Record<string, unknown>,
  quota: ReturnType<typeof readQuota>,
  gems: number,
): Promise<void> {
  const config = apiSupabaseConfig();
  if (!config || !rowId) return;
  const game = (data.gamification && typeof data.gamification === "object"
    ? data.gamification
    : {}) as Record<string, unknown>;
  const response = await fetch(
    `${config.url}/rest/v1/students?id=eq.${encodeURIComponent(rowId)}`,
    {
      method: "PATCH",
      headers: {
        apikey: config.key,
        Authorization: `Bearer ${config.key}`,
        "Content-Type": "application/json",
        Prefer: "return=minimal",
      },
      body: JSON.stringify({
        data: { ...data, aiQuota: quota, gamification: { ...game, gems } },
        updated_at: new Date().toISOString(),
      }),
    },
  );
  if (!response.ok) throw new Error(`quota write failed (${response.status})`);
}

async function recordProblemSolverActivity(
  student: StudentActor,
  lessonId: string,
  question: string,
  answer: string,
): Promise<void> {
  const config = apiSupabaseConfig();
  if (!config) return;
  const now = new Date().toISOString();
  await fetch(`${config.url}/rest/v1/interactions`, {
    method: "POST",
    headers: {
      apikey: config.key,
      Authorization: `Bearer ${config.key}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      id: `solver_${student.id}_${Date.now()}`,
      data: {
        type: "problem_solver",
        studentId: student.id,
        studentName: student.name,
        teacherId: student.teacherId,
        lessonId,
        question,
        answer,
        grade: student.grade,
        subject: student.subject,
        term: student.term,
        unit: student.unit,
        createdAt: now,
      },
      updated_at: now,
    }),
  });
}

/**
 * حالةُ الحصّة، بلا سؤال.
 *
 * الشاشة تحتاجها عند فتحها: العدّاد كان لا يظهر حتى يسأل الطفل سؤالاً
 * أوّل، فيرى الحدَّ بعد أن يستهلك منه — وهو أسوأ وقتٍ لمعرفته.
 */
router.get("/gemini/quota", requireStudentSession, async (_req, res) => {
  const student = res.locals.student as StudentActor;
  try {
    const { quota } = await readStudentQuota(student);
    return res.json({ quota: quota.snapshot });
  } catch (error) {
    logger.error({ err: error }, "[gemini] quota read failed");
    return res.status(503).json({ error: "تعذّر قراءة حصّتك الآن" });
  }
});

router.post("/gemini/answer", answerRateLimit, requireStudentSession, async (req, res) => {
  const lessonId =
    typeof req.body?.lessonId === "string" ? req.body.lessonId.trim() : "";
  const question =
    typeof req.body?.question === "string" ? req.body.question.trim() : "";

  // صورةُ المسألة، إن صوّرها الطفل.
  //
  // تُقبل base64 بحدٍّ قدره ستة ميغابايتات بعد الترميز — أكبر ممّا
  // تُخرجه كاميرا الهاتف بعد الضغط، وأصغر من أن يخنق الطلبَ أو الذاكرة.
  // وبلا حدٍّ يستطيع طلبٌ واحد أن يُسقط الخادم.
  // هل أذن الطفل بدفع الجواهر؟
  //
  // بلا إذنه يُردّ الطلبُ بـ402 وفيه ثمنُ السؤال ورصيدُه، فتسأله الشاشة
  // ثم تعيد الإرسال بهذه الراية. وخصمٌ بلا استئذان يفاجئ طفلاً جمع
  // جواهره بالدروس ثم وجدها نقصت بلا أن يختار.
  const payWithGems = req.body?.payWithGems === true;

  const rawImage = typeof req.body?.image === "string" ? req.body.image.trim() : "";
  const imageType =
    typeof req.body?.imageMimeType === "string"
      ? req.body.imageMimeType.trim().toLowerCase()
      : "image/jpeg";
  const ALLOWED_IMAGE = new Set(["image/jpeg", "image/png", "image/webp"]);
  if (rawImage && (rawImage.length > 6_000_000 || !ALLOWED_IMAGE.has(imageType))) {
    return res.status(400).json({
      error: rawImage.length > 6_000_000
        ? "الصورة أكبر من الحدّ المسموح"
        : "صيغة الصورة غير مدعومة",
      code: "bad_image",
    });
  }
  const image = rawImage ? { data: rawImage, mimeType: imageType } : undefined;

  if (!lessonId || !question || question.length > 2000) {
    // ‏أيّ الحقلين أسقط الطلب: سؤالٌ فارغ وسؤالٌ أطول من الحدّ ومعرّفٌ
    // ‏مفقود كانت ترجع الرسالة نفسها، فلا يُعرف أيّها وقع.
    logger.warn(
      { hasLessonId: Boolean(lessonId), questionLength: question.length },
      "[gemini] answer rejected: bad request",
    );
    return res.status(400).json({
      error: !lessonId
        ? "لم يصل معرّف الدرس مع السؤال"
        : !question
          ? "السؤال فارغ"
          : "السؤال أطول من الحدّ المسموح (2000 حرف)",
      code: "bad_request",
    });
  }
  try {
    const student = res.locals.student as StudentActor;
    const lesson = await resolveStudentLesson(lessonId, student);
    if (lesson.reason) {
      logger.warn(
        { lessonId, studentId: student.id, reason: lesson.reason },
        "[gemini] answer rejected: lesson unavailable",
      );
      const messages = {
        not_found: "لم يُعثر على هذا الدرس في قاعدة البيانات.",
        out_of_scope: lesson.detail
          ? `هذا الدرس ليس ضمن مسار حسابك — ${lesson.detail}`
          : "هذا الدرس ليس ضمن مسار حسابك.",
        no_text: "هذا الدرس لا يحتوي على شرح نصي بعد — اطلب من معلمك إضافته.",
      } as const;
      return res.status(403).json({ error: messages[lesson.reason], code: lesson.reason });
    }
    // ── الذاكرة أولاً ──
    //
    // ثلاثون طفلاً في صفٍّ واحد يسألون عن الدرس نفسه، فيُسأل النموذج
    // ثلاثين مرّة عن سؤالٍ واحد وإجابتُه لا تتغيّر. فتُحفظ أوّل مرّة
    // وتُعاد على البقيّة في جزءٍ من الثانية.
    //
    // والإجابة المحفوظة لا تُحسب من الحصّة ولا تُكلّف جوهرة: لم يُستدعَ
    // النموذج، ولا معنى لأن يُحرم طفلٌ من سؤالٍ لأن غيره سأله قبله.
    // والصورةُ تدخل الذاكرة من بابٍ واحد مع المكتوب والمنطوق: يُقرأ
    // نصُّها أوّلاً، ثم يُبنى المفتاح من هذا النصّ. فالأبوابُ الثلاثة
    // تصبّ في `cacheKey` وحدها، ولا بابَ يتخطّى الذاكرة.
    const startedAt = Date.now();
    const imageText = image ? await readQuestionFromImage(image, question) : null;
    // صورةٌ لم تُقرأ تعود إلى ما كان: لا ذاكرةَ لها، ولا يُمنع الطفلُ
    // من جوابٍ لأن القراءة تعذّرت.
    const keyText = image ? imageText : question;
    const key = keyText ? cacheKey(lesson.id, keyText) : "";
    const cached = key ? await readCachedAnswer(key) : null;
    if (cached) {
      // إصابةٌ في الذاكرة لا تُحسب من الحصّة ولا تُكلّف جوهرة: لم
      // يُستدعَ النموذج. والحصّةُ تُقرأ لتُعرض وحدها، لا لتُنقص.
      const seen = await readStudentQuota(student);
      return res.json({ answer: cached, cached: true, quota: seen.quota.snapshot });
    }

    // ── ثم الحصّة ──
    // `student` هو اسم الصفّ في هذا النطاق، فيُسمّى صفُّ الجدول غيرَه.
    const { quota, gems, rowId, data: studentRow } = await readStudentQuota(student);
    const verdict = chargeFor(quota.state, gems);
    if (verdict.allowed && verdict.gemsCharged > 0 && !payWithGems) {
      return res.status(402).json({
        error: `انتهت أسئلتك المجانية اليوم. السؤال الإضافي بـ${GEM_PRICE} جواهر.`,
        code: "confirm_gems",
        gemPrice: GEM_PRICE,
        quota: quota.snapshot,
      });
    }
    if (!verdict.allowed) {
      return res.status(402).json({
        error: `انتهت أسئلتك المجانية اليوم (${FREE_DAILY_QUESTIONS}). السؤال الإضافي بـ${GEM_PRICE} جواهر، ورصيدك ${gems}.`,
        code: "quota_exhausted",
        quota: quota.snapshot,
      });
    }

    const prompt = image
      ? `أنت مساعد تعليمي ذكي لطفلٍ في المرحلة الابتدائية. في الصورة المرفقة مسألةٌ من كتابه أو دفتره.

اقرأ ما في الصورة أوّلاً، ثم أجب عن طلب الطالب: ${question}

اشرح الحلّ خطوةً خطوة بلغةٍ يفهمها طفل. وإن كانت الصورة غير واضحة فقل ذلك صراحةً واطلب صورةً أوضح، ولا تخمّن ما لا تراه.

وللاستئناس، هذا نصّ درسه:
${lesson.text}`
      : `أنت مساعد تعليمي ذكي. اقرأ النص التالي للاستفادة منه داخليًا:\n\n${lesson.text}\n\nالسؤال: ${question}\n\nأجب مباشرة وبأسلوب مفيد وخطوة بخطوة للطالب. لا تذكر أنك اعتمدت على نص الدرس، ولا تقل "بناءً على النص الموجود في الدرس" أو أي عبارة مشابهة؛ ابدأ بالإجابة أو الحل مباشرة. إذا لم تجد الإجابة في نص الدرس، قل بوضوح: "هذا السؤال ليس من ضمن الدرس ولا أستطيع الإجابة عليه" ولا تستخدم معرفتك العامة.`;
    // وما بقي من الميزانية بعد القراءة، لا ميزانيةٌ كاملةٌ ثانية: الخادم
    // ينتظر ما ينتظره التطبيق وينتهي قبله.
    const data = await callGemini(
      prompt,
      image
        ? {
            image,
            maxOutputTokens: 3000,
            budgetMs: GEMINI_BUDGET_MS - (Date.now() - startedAt),
          }
        : {},
    );
    const answer = getGeminiText(data);
    if (!answer) {
      logger.warn({ lessonId }, "[gemini] answer rejected: empty completion");
      return res.status(502).json({
        error: "لم تصل إجابة صالحة من خدمة الذكاء الاصطناعي",
        code: "empty_answer",
      });
    }
    // الخصم بعد أن تصل الإجابة لا قبلها: طفلٌ خُصمت جواهرُه ثم تعطّل
    // النموذج يكون قد دفع ثمن لا شيء.
    const nextQuota = spend(quota.state, verdict);
    await Promise.all([
      writeStudentQuota(rowId, studentRow, nextQuota, gems - verdict.gemsCharged).catch((error) =>
        logger.error({ err: error }, "[gemini] quota not saved"),
      ),
      // الحفظ في الذاكرة لا يُنتظر ولا يُسقط الردّ: فشلُه يعني استدعاءً
      // ثانياً في المرّة القادمة لا إجابةً ضائعة.
      //
      // ويُحفظ ما صُوّر كما يُحفظ ما كُتب، ما دام للصورة نصٌّ قُرئ منها
      // — فمن صوّر المسألة بعده يجدها محفوظة.
      key
        ? writeCachedAnswer(key, lesson.id, keyText ?? question, answer).catch((error) =>
            logger.error({ err: error, key }, "[cache] SAVE FAILED"),
          )
        : Promise.resolve(),
      recordProblemSolverActivity(student, lesson.id, question, answer).catch((error) =>
        logger.warn({ err: error }, "[gemini] problem solver activity was not recorded"),
      ),
    ]);
    return res.json({
      answer,
      cached: false,
      quota: snapshotOf(nextQuota, gems - verdict.gemsCharged),
    });
  } catch (error: any) {
    // ‏المفتاح الغائب ليس انقطاع اتصال: إرساله تحت الرسالة نفسها كان
    // ‏يدفع المعلّم إلى فحص شبكته بينما الخادم ينقصه إعداد.
    const notConfigured = error?.statusCode === 503;
    logger.error(
      { err: error, lessonId, statusCode: error?.statusCode, notConfigured },
      "[gemini] answer failed",
    );
    return res.status(error?.statusCode || 500).json({
      error: notConfigured
        ? "خدمة الذكاء الاصطناعي غير مهيّأة على الخادم (GEMINI_API_KEY)."
        : "تعذر الاتصال بخدمة الذكاء الاصطناعي",
      code: notConfigured ? "ai_not_configured" : "ai_unavailable",
    });
  }
});

// Quiz generation is available to the teacher who is creating the assessment
// and to administrators. The caller still needs a signed content session.
/**
 * جولةُ «بطاقة التحدي»: أسئلةٌ تُولَّد الآن من نصّ درس الطالب نفسه.
 *
 * ── لماذا لا تُقرأ من بنكٍ محفوظ ──
 * البنك يصلح للاختبار: أسئلةٌ ثابتةٌ تُصحَّح وتُقارَن بين طالبٍ وآخر.
 * والتحدي لعبةٌ تُعاد، وإعادتُها على الأسئلة نفسها تُحوّلها من تفكيرٍ
 * إلى حفظِ ترتيب. فتُولَّد عند كل طلب، وتُمرَّر معها الأسئلةُ التي رآها
 * اللاعب قبل قليل كي لا تعود.
 *
 * ── ولماذا نصّ الدرس شرطٌ لا زينة ──
 * النموذج إن لم يُعطَ نصّاً ولّد من معرفته العامة، فيسأل طفلاً عمّا لم
 * يدرسه ويُخطئه على ما لم يُعلَّم. فالدرس يُقرأ من `lesson_configs`،
 * ويُردّ الطلبُ إن لم يكن له نصّ — ولا يُولَّد شيءٌ بلا مصدر.
 *
 * والنطاق مُحكم كإحكامه في «حل المسائل»: `resolveStudentLesson` ترفض
 * درساً خارج مسار الطالب، فلا يبلغ تحدّي صفٍّ آخر طفلاً ليس منه.
 */
router.post(
  "/gemini/challenge",
  challengeRateLimit,
  requireStudentSession,
  async (req, res) => {
    const student = (req as any).student as StudentActor;
    const lessonId =
      typeof req.body?.lessonId === "string" ? req.body.lessonId.trim() : "";
    const requested = Number(req.body?.count);
    const count = Number.isFinite(requested)
      ? Math.min(Math.max(Math.trunc(requested), 3), 10)
      : ROUNDS_PER_PLAY;
    const seed =
      typeof req.body?.seed === "string" && req.body.seed.trim()
        ? req.body.seed.trim().slice(0, 64)
        : `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
    const exclude = Array.isArray(req.body?.exclude)
      ? req.body.exclude
          .map((item: unknown) => String(item ?? "").trim())
          .filter(Boolean)
          .slice(0, 24)
      : [];

    if (!lessonId) {
      return res.status(400).json({ error: "لم يصل معرّف الدرس" });
    }

    try {
      const lesson = await resolveStudentLesson(lessonId, student);
      if (lesson.reason) {
        const message =
          lesson.reason === "not_found"
            ? "لم يُعثر على هذا الدرس"
            : lesson.reason === "out_of_scope"
              ? "هذا الدرس ليس ضمن مسار حسابك"
              : "لم يضف المعلّم نصّ هذا الدرس بعد";
        logger.warn(
          { lessonId, studentId: student.id, reason: lesson.reason, detail: lesson.detail },
          "[gemini] challenge rejected",
        );
        return res.status(lesson.reason === "not_found" ? 404 : 422).json({ error: message });
      }

      const subject = detectSubject(lesson.subject);

      // البنك المحفوظ أولاً.
      //
      // التوليد عند كل فتحة كان يُجلس طفلاً أمام انتظارٍ عشر ثوانٍ،
      // ويُسقط البطاقة كلّها إن تعثّر النموذج. والبنك يُولَّد مرّةً
      // ويُحفظ مع الدرس، فتُسحب منه جولاتٌ فوراً، وإعادةُ التحدي تسحب
      // غيرها — فالتجدّد من سَعة البنك لا من طلبٍ جديد.
      let bank = readBank(lesson.challengeBank);
      let generated = false;

      if (!bank) {
        const raw = await callGemini(
          bankPrompt({
            subject: lesson.subject,
            unit: lesson.unit,
            lesson: lesson.lesson,
            lessonText: lesson.text,
          }),
          { temperature: 0.9, maxOutputTokens: 32000, json: true },
        );
        const { rounds, rejected } = parseBank(
          typeof raw === "string" ? raw : (getGeminiText(raw) ?? raw),
          subject,
        );
        if (rounds.length === 0) {
          logger.warn({ lessonId, subject, rejected }, "[gemini] challenge bank empty");
          return res
            .status(502)
            .json({ error: "تعذّر توليد جولات التحدي، حاول مرة أخرى" });
        }
        if (Object.keys(rejected).length) {
          logger.info({ lessonId, subject, rejected }, "[gemini] challenge bank filtered");
        }
        bank = {
          version: BANK_VERSION,
          generatedAt: new Date().toISOString(),
          subject: lesson.subject,
          rounds,
        };
        generated = true;
        // الحفظ لا يُنتظَر ولا يُسقط الردّ: الطفل ينتظر جولاته، وفشلُ
        // الكتابة يعني توليداً ثانياً في المرة القادمة لا شاشةً فارغة.
        void persistBank(lessonId, bank).catch((error) =>
          logger.error({ err: error, lessonId }, "[gemini] bank not saved"),
        );
      }

      return res.json({
        lessonId: lesson.id,
        subject: lesson.subject,
        seed,
        bankSize: bank.rounds.length,
        generated,
        rounds: drawRounds(bank, count, Number.parseInt(seed.slice(-8), 36) || Date.now()),
      });
    } catch (error: any) {
      logger.error({ err: error, lessonId }, "[gemini] challenge failed");
      return res
        .status(error?.statusCode || 502)
        .json({ error: "تعذّر توليد أسئلة التحدي، حاول مرة أخرى" });
    }
  },
);

router.post("/gemini/generate-quiz", requireContentManager, async (req, res) => {
  const prompt =
    typeof req.body?.prompt === "string" ? req.body.prompt.trim() : "";
  const temperature = Number.isFinite(req.body?.temperature)
    ? req.body.temperature
    : 0.7;
  const maxOutputTokens = Number.isFinite(req.body?.maxOutputTokens)
    ? Math.min(Math.max(req.body.maxOutputTokens, 256), 9000)
    : 3000;
  if (!prompt || prompt.length > 14000) {
    return res.status(400).json({ error: "طلب توليد الاختبار غير صالح" });
  }
  try {
    const data = await callGemini(prompt, {
      temperature,
      maxOutputTokens,
      json: true,
    });
    return res.json(data);
  } catch (error: any) {
    logger.error({ err: error }, "[gemini] quiz generation failed");
    return res
      .status(error?.statusCode || 500)
      .json({ error: "تعذر توليد الاختبار بالذكاء الاصطناعي" });
  }
});

export default router;
