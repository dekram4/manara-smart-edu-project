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
  bestSimilarKey,
  cacheKey,
  chargeFor,
  normalizeQuestion,
  questionOfKey,
  readQuota,
  snapshotOf,
  spend,
} from "../lib/aiQuota";
import { lightDiacritics } from "../lib/arabicText";
import { sameQuantities } from "../lib/questionMath";
import {
  type StudyPack,
  expansionPrompt,
  lessonStampOf,
  mergeScenarios,
  parseExpansion,
  parseStudyPack,
  readStudyPack,
  studyPrompt,
  targetScenarios,
} from "../lib/interactiveStudy";
import { VECTOR_THRESHOLD, bestByMeaning, embedQuestion } from "../lib/embeddings";
import { createHash } from "node:crypto";
import { SOLVER_SCOPE_INSTRUCTION, cacheReadableColumns, imageKeyText, isRefusalAnswer } from "../lib/solverPolicy";
import {
  QUIZ_RESPONSE_SCHEMA,
  QUIZ_SYSTEM_INSTRUCTION,
  clampCount as clampQuizCount,
  parseQuizQuestions,
  quizPrompt,
} from "../lib/quizGenerator";
import {
  STUDY_GAMES_SCHEMA,
  STUDY_GAMES_SYSTEM_INSTRUCTION,
  parseStudyGames,
  readStudyGames,
  studyGamesPrompt,
  freshGamePrompt,
  isStudyGameType,
  parseFreshGame,
  MAX_EXCLUDE as MAX_FRESH_EXCLUDE,
} from "../lib/studyGames";
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
import { LESSON_TEXT_SAFETY_LIMIT } from "../lib/lessonText";

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

/**
 * سقف المحاولة الواحدة، فلا يبتلع نموذجٌ بطيء الميزانية كلّها.
 *
 * ثلاثون ثانية كانت تعني أن نموذجاً واحداً مزدحماً يستنفد ثلاثة أخماس
 * الميزانية قبل أن يُجرَّب الذي بعده — والطفل ينتظر شاشةً تدور. وأسرعُ
 * النماذج يجيب في ثانيتين إلى أربع، فمن تجاوز الخمس عشرة مزدحمٌ ولن
 * يصير أسرع بالانتظار. والتخلّي عنه مبكراً يترك لثلاثة بعده متّسعاً.
 */
const GEMINI_SINGLE_TRY_MS = 15_000;

/**
 * سقفُ طول الإجابة في بطاقة حلّ المسائل.
 *
 * ── لماذا يُقصَّر ──
 * كان ٢٠٤٨ رمزاً، والنموذج يملأ ما يُعطى: يشرح، ثم يلخّص ما شرح، ثم
 * يضيف «نصائح». والرموز تُولَّد واحداً واحداً، فطولُ الإجابة هو زمنُ
 * الانتظار حرفياً — ومضاعفةُ الطول مضاعفةُ الصمت قبل أن يقرأ الطفل
 * حرفاً.
 *
 * وشرحُ مسألةٍ لتلميذ ابتدائيّ خطواتٌ معدودة. فما زاد إسهابٌ يُبطئ
 * ويُتعب، لا تفصيلٌ يُفيد.
 */
const SOLVER_MAX_TOKENS = 900;

async function callGemini(
  prompt: string,
  {
    temperature = 0.2,
    maxOutputTokens = 2048,
    json = false,
    image,
    budgetMs = GEMINI_BUDGET_MS,
    systemInstruction,
    responseSchema,
    singleTryMs = GEMINI_SINGLE_TRY_MS,
    preferQuality = false,
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
    /** توجيهُ النظام: ضوابطُ ثابتة لا يغيّرها نصُّ الطلب. */
    systemInstruction?: string;
    /** مخطّطُ JSON يفرضه النموذج على ردّه (يقتضي [json]). */
    responseSchema?: unknown;
    /** سقفُ نموذجٍ واحد — للأعمال الطويلة كبنك أسئلة كامل. */
    singleTryMs?: number;
    /**
     * يُقدَّم النموذجُ الأقوى على الأخفّ: الأسرعُ يكفي لإجابة طفل، وبنكُ
     * اختبارٍ يُبنى مرّةً ويُعاد لكل الطلاب يستحقّ الأدقّ.
     */
    preferQuality?: boolean;
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
  const discovered = await getGeminiModels(apiKey);
  const models = (preferQuality
    ? [
        ...discovered.filter((model) => /flash/i.test(model) && !/lite/i.test(model)),
        ...discovered.filter((model) => !(/flash/i.test(model) && !/lite/i.test(model))),
      ]
    : discovered
  ).slice(0, 6);
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
            ...(systemInstruction
              ? { systemInstruction: { parts: [{ text: systemInstruction }] } }
              : {}),
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
              ...(json && responseSchema ? { responseSchema } : {}),
            },
          }),
          // ما بقي من الميزانية، وبسقف لنموذج واحد حتى لا يبتلعها أوّلُ
          // نموذج بطيء ويحرم البقية من محاولة.
          signal: AbortSignal.timeout(
            Math.min(remaining, singleTryMs),
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
      /** وحزمةُ المذاكرة الذكية، إن وُلّدت. */
      interactiveStudy?: unknown;
      /** وألعابُ المذاكرة التفاعلية، إن وُلّدت. */
      studyGames?: unknown;
      grade?: string;
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
    interactiveStudy: lesson.interactiveStudy,
    studyGames: lesson.studyGames,
    grade: typeof lesson.grade === "string" ? lesson.grade : "",
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
      // رفضٌ حُفظ قبل توسيع النطاق: إخفاقٌ لا إصابة — فيُولَّد جوابٌ
      // صحيح ويُكتب فوقه بالمفتاح نفسه. انظر `isRefusalAnswer`.
      if (isRefusalAnswer(answer)) {
        logger.warn({ key }, "[cache] MISS — stored refusal ignored, will be replaced");
        return null;
      }
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

/**
 * إجابةُ أقربِ سؤالٍ معنىً، بالمتّجهات.
 *
 * ── موضعُها من السلّم ──
 * ثلاثُ طبقاتٍ ترتيبُها ترتيبُ كلفتها، وكلٌّ تُصيب صنفاً أصعب:
 *   ١. المفتاحُ الحرفيّ — استعلامٌ مفهرَسٌ واحد، بلا شبكة. السؤالُ
 *      أُعيد بحرفه، وهو الشائع.
 *   ٢. مقياسُ الكلمات — استعلامٌ واحد، بلا شبكة. الترتيبُ مقلوب أو
 *      حرفٌ أخطأ فيه قارئُ الصورة.
 *   ٣. المتّجهات — هذه: نداءٌ شبكيّ ثم استعلام. الكلماتُ نفسها اختلفت
 *      والمعنى واحد: «ما وظيفة الخلية» و«ماذا تفعل الخلية».
 *
 * فلا يدفع ثمنَ الشبكة إلا من لم تكفِه طبقةٌ أرخص. ولو قُدِّمت هذه
 * لأُضيف نداءٌ إلى كل سؤالٍ في الخدمة، بما فيه ما كان يُصاب في جزءٍ من
 * الثانية.
 *
 * ── وكلُّ تعذّرٍ يعود بـ`null` ──
 * إضافةٌ لم تُفعَّل، أو دالّةٌ لم تُنشأ، أو نموذجٌ لم يُسمَح به: كلُّها
 * تعني استدعاءَ النموذج التوليدي كما كان. والذاكرةُ تسريعٌ لا شرط.
 *
 * ويُعاد المتّجهُ مع الإجابة لأنه يُحفظ مع الصفّ الجديد عند الإخفاق —
 * وحسابُه ثانيةً نداءٌ ثانٍ بلا داع.
 */
async function findByMeaning(
  lessonId: string,
  question: string,
): Promise<{ answer: string | null; vector: number[] | null }> {
  const config = apiSupabaseConfig();
  // ── ويُحسب المتّجه من السؤال المطبَّع لا الخام ──
  //
  // «ايش يعني الخلية» و«ما هي الخلية» سؤالٌ واحد، والتطبيعُ يردّهما إلى
  // «الخلية» — نصٌّ واحد ومتّجهٌ واحد، فالمطابقةُ يقينٌ لا نسبةٌ تُقارَب
  // بعتبة. والخامُ يُبقي أداةَ الاستفهام في النصّ المُتَّجَه، وأدواتُ
  // اللهجة بعيدةٌ في فضاء المعنى عن أدوات الفصحى بما يكفي لأن تُنقص
  // النسبةَ عن العتبة في سؤالين موضوعُهما واحد.
  //
  // وأثرُه على ما حُفظ قبله: صفوفٌ متّجهُها محسوبٌ من الخام تبقى تُصاب
  // — النصّان متقاربان على كل حال — وما يُحفظ بعده مطبَّعٌ من الطرفين.
  // فالجدولُ يشفى بنفسه صفاً صفاً، ولا ترحيلَ يُطلب من أحد.
  const vector = await embedQuestion(normalizeQuestion(question));
  if (!config || !vector) return { answer: null, vector };
  try {
    const row = await nearestByMeaning(config, lessonId, vector);
    const answer = typeof row?.answer === "string" ? row.answer.trim() : "";
    if (!answer) {
      logger.info({ lessonId }, "[cache] MISS — nothing close in meaning");
      return { answer: null, vector };
    }
    if (isRefusalAnswer(answer)) {
      logger.warn({ key: row?.id }, "[cache] MISS — closest match is a stored refusal");
      return { answer: null, vector };
    }
    // ── والمعنى لا يكفي في المسائل ──
    //
    // المتّجهُ يقرّب المعنى، ومسألتان تختلفان في رقمٍ واحد معناهما واحد
    // عنده — بل أقربُ ما يكون. وخفضُ العتبة إلى ٠٫٧٨ يوسّع هذا القرب،
    // فيُشترط بعده تطابقُ الأرقام والوحدات كلِّها.
    //
    // ويُقرأ السؤالُ المحفوظ من المفتاح لا من العمود: المفتاح مطبَّعٌ
    // كما يُطبَّع السؤالُ الوارد، فيُقارَن مثلٌ بمثل.
    if (!sameQuantities(normalizeQuestion(question), questionOfKey(String(row?.id ?? "")))) {
      logger.info(
        { key: row?.id },
        "[cache] MISS — same meaning, different quantities",
      );
      return { answer: null, vector };
    }
    logger.info(
      { key: row?.id, similarity: Number(Number(row?.similarity).toFixed(3)) },
      "[cache] HIT — same meaning",
    );
    return { answer, vector };
  } catch (error) {
    logger.warn({ err: error }, "[cache] vector search failed");
    return { answer: null, vector };
  }
}

/** متى عُرف أن `match_qa_cache` في القاعدة لا تعمل — فلا تُسأل قبل أن يمضي. */
let meaningRpcDownUntil = 0;
const MEANING_RPC_RETRY_MS = 10 * 60_000;

/**
 * أقربُ صفٍّ معنىً في الدرس: من دالّة القاعدة إن عملت، وإلا قيس في الخادم.
 *
 * الدالّةُ أسرع (فهرسُ hnsw)، فتُسأل أوّلاً. وإن رُدّت — غائبةً (٤٠٤) أو
 * معطوبة (٤٠٠: وُجدت في الإنتاج تشير إلى عمودٍ غير موجود) — قيس على صفوف
 * الدرس هنا، وتُترك الدالّةُ عشر دقائق ثم تُجرَّب ثانيةً: فإن طُبّق
 * `ai-qa-cache-vectors.sql` عاد إليها الخادمُ بنفسه.
 */
async function nearestByMeaning(
  config: { url: string; key: string },
  lessonId: string,
  vector: number[],
): Promise<{ id?: unknown; answer?: unknown; similarity?: unknown } | null> {
  const headers = {
    apikey: config.key,
    Authorization: `Bearer ${config.key}`,
    "Content-Type": "application/json",
  };
  if (Date.now() >= meaningRpcDownUntil) {
    const response = await fetch(`${config.url}/rest/v1/rpc/match_qa_cache`, {
      method: "POST",
      headers,
      body: JSON.stringify({
        query_embedding: vector,
        p_lesson_id: lessonId,
        match_threshold: VECTOR_THRESHOLD,
      }),
    });
    if (response.ok) {
      const rows = await response.json();
      return Array.isArray(rows) ? (rows[0] ?? null) : null;
    }
    meaningRpcDownUntil = Date.now() + MEANING_RPC_RETRY_MS;
    logger.warn(
      { status: response.status, detail: (await response.text()).slice(0, 200) },
      "[cache] match_qa_cache unavailable — measuring in the server (apply ai-qa-cache-vectors.sql for the fast path)",
    );
  }
  const response = await fetch(
    `${config.url}/rest/v1/ai_qa_cache?select=id,embedding,answer:data->>answer&data->>lessonId=eq.${encodeURIComponent(lessonId)}&embedding=not.is.null&limit=${SIMILARITY_SCAN_LIMIT}`,
    { headers },
  );
  if (!response.ok) {
    logger.warn({ status: response.status }, "[cache] meaning scan refused by the database");
    return null;
  }
  const rows = await response.json();
  const best = Array.isArray(rows) ? bestByMeaning(rows, vector) : null;
  return best ? { id: best.row.id, answer: best.row.answer, similarity: best.similarity } : null;
}

/** سقفُ ما يُقاس من مفاتيح الدرس، فلا يثقل درسٌ قديمٌ الاستعلام. */
const SIMILARITY_SCAN_LIMIT = 500;

/**
 * إجابةُ أقربِ سؤالٍ محفوظٍ في الدرس نفسه، أو `null`.
 *
 * ── لماذا بعد المطابقة الحرفية لا قبلها ──
 * الحرفيةُ استعلامٌ واحد على مفتاحٍ مفهرَس: أسرعُ ما في الخدمة، وهي
 * تُصيب في الشائع — سؤالٌ أُعيد كما هو. وهذه تقرأ مفاتيح الدرس كلَّها
 * وتقيسها، فلو جاءت أوّلاً لأبطأت كلَّ إصابةٍ من أجل النادر منها.
 *
 * ── ولماذا المفاتيح وحدها تُقرأ ──
 * المفتاح يحمل السؤالَ مطبَّعاً في نصّه: `<الدرس>::<السؤال>`. فلا عمودَ
 * يُضاف ولا ترحيلَ يُطلب من أحد — يُقرأ `id` وحده، وهو نصٌّ قصير، ثم
 * تُقرأ إجابةُ الفائز وحدها.
 */
async function findSimilarCachedAnswer(
  lessonId: string,
  question: string,
): Promise<string | null> {
  const config = apiSupabaseConfig();
  if (!config) return null;
  try {
    const response = await fetch(
      `${config.url}/rest/v1/ai_qa_cache?select=id&data->>lessonId=eq.${encodeURIComponent(lessonId)}&limit=${SIMILARITY_SCAN_LIMIT}`,
      { headers: { apikey: config.key, Authorization: `Bearer ${config.key}` } },
    );
    if (!response.ok) {
      logger.warn(
        { status: response.status },
        "[cache] similar lookup refused by the database",
      );
      return null;
    }
    const rows = await response.json();
    const all: string[] = Array.isArray(rows)
      ? rows.map((row: any) => String(row?.id ?? "")).filter(Boolean)
      : [];
    // ── والمقاديرُ تُصفّى قبل أن يُقاس اللفظ ──
    //
    // «احسب محيط مستطيل طوله ٥ وعرضه ٣» و«... طوله ٧ وعرضه ٣» يشتركان
    // في كل كلمةٍ إلا رقماً، فيقيسان فوق العتبة ويُعاد جوابُ الأول على
    // الثاني. والتصفيةُ قبل القياس لا بعده: لو رُدّ الفائزُ وحده لكان
    // مرشَّحٌ صحيحُ الأرقام قد خسر أمامه.
    const asked = normalizeQuestion(question);
    const keys = all.filter((key) => sameQuantities(asked, questionOfKey(key)));
    if (keys.length < all.length) {
      logger.info(
        { lessonId, dropped: all.length - keys.length },
        "[cache] candidates dropped — different quantities",
      );
    }
    const hit = bestSimilarKey(keys, question);
    if (!hit) {
      logger.info({ lessonId, scanned: keys.length }, "[cache] MISS — nothing similar");
      return null;
    }
    // ويُقرأ الفائزُ بمفتاحه الحرفيّ، فتمرّ القراءة على الفهرس نفسه.
    const answer = await readCachedAnswer(hit.key);
    if (answer) {
      logger.info(
        { key: hit.key, score: Number(hit.score.toFixed(3)) },
        "[cache] HIT — similar question",
      );
    }
    return answer;
  } catch (error) {
    logger.warn({ err: error }, "[cache] similar lookup failed");
    return null;
  }
}

/** محاولاتُ الكتابة قبل أن يُسلَّم بالفشل، والانتظارُ يطول بينها. */
const SAVE_ATTEMPTS = 3;

/**
 * يحفظ إجابةً جديدة في الذاكرة الدائمة — كلَّ إجابة، بمتّجهها.
 *
 * ── ما كان يُفلت، وما يسدّه هذا ──
 * • المتّجهُ: كان يُحفظ ما حُسب في أثناء البحث، فإن تعثّر نداؤه حُفظ الصفُّ
 *   بلا متّجه ولم يُصَب بالمعنى أبداً. فيُعاد حسابُه هنا مرّتين قبل الكتابة.
 * • الكتابةُ: كانت محاولةً واحدة، وتعثّرُ شبكةٍ لحظةً يُضيّع الإجابة.
 *   فثلاثُ محاولاتٍ يطول الانتظار بينها.
 * • الرفضُ لا يُحفظ: الذاكرةُ دائمة، ورفضٌ محفوظ يُعاد على الجميع.
 *
 * ولا يرمي أبداً: يُنادى ولا يُنتظر، وكلُّ فشلٍ يُكتب في السجلّ باسمه.
 */
async function persistAnswer(entry: {
  key: string;
  lessonId: string;
  question: string;
  answer: string;
  vector: number[] | null;
  /** للسؤال نصٌّ يُقاس بالمعنى (لا صورةٌ لم تُقرأ). */
  searchable: boolean;
  /** مادّةُ الدرس — تُكتب في عمود `domain`. */
  domain?: string;
}): Promise<void> {
  try {
    if (isRefusalAnswer(entry.answer)) {
      logger.warn({ key: entry.key }, "[cache] refusal not saved");
      return;
    }
    let vector = entry.vector;
    for (let attempt = 0; !vector && entry.searchable && attempt < 2; attempt += 1) {
      vector = await embedQuestion(normalizeQuestion(entry.question));
    }
    if (entry.searchable && !vector) {
      logger.warn({ key: entry.key }, "[cache] saving without a vector — embedding unavailable");
    }
    for (let attempt = 1; attempt <= SAVE_ATTEMPTS; attempt += 1) {
      try {
        await writeCachedAnswer(entry.key, entry.lessonId, entry.question, entry.answer, vector, entry.domain);
        return;
      } catch (error) {
        // ‏السببُ مكتوبٌ نصّاً في السطر نفسه — رمزُ القاعدة ورسالتُها — لا
        // ‏مدفوناً في كائن: من يقرأ سجلّ Railway يرى لماذا فشل الحفظ.
        logger.error(
          {
            key: entry.key,
            attempt,
            of: SAVE_ATTEMPTS,
            reason: error instanceof Error ? error.message : String(error),
          },
          "[cache] SAVE FAILED",
        );
        if (attempt < SAVE_ATTEMPTS) {
          await new Promise((resolve) => setTimeout(resolve, attempt * 800));
        }
      }
    }
  } catch (error) {
    logger.error({ err: error, key: entry.key }, "[cache] SAVE FAILED — unexpected");
  }
}

/** يحفظ الإجابة لمن يسأل بعده. */
async function writeCachedAnswer(
  key: string,
  lessonId: string,
  question: string,
  answer: string,
  /**
   * متّجهُ السؤال، إن حُسب في أثناء البحث.
   *
   * يُحفظ معه فلا يحتاج من يسأل بعده إلى أن يُحسب ثانيةً. وغيابُه —
   * حين أصابت طبقةٌ أرخص أو تعذّر النداء — يعني صفاً بلا متّجه: يُصاب
   * حرفياً وبالكلمات، ولا يُصاب بالمعنى حتى يُعاد السؤال فيُحسب له.
   */
  embedding?: number[] | null,
  domain?: string,
): Promise<void> {
  const config = apiSupabaseConfig();
  if (!config) {
    // ‏كان يعود صامتاً: إجابةٌ تُعرض ولا تُحفظ ولا سطرَ في السجلّ يقول لماذا.
    throw new Error("Supabase is not configured (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY)");
  }
  const now = new Date().toISOString();
  const body: Record<string, unknown> = {
    id: key,
    // السؤال يُحفظ كما كتبه الطفل لا مطبَّعاً: المفتاح للمطابقة،
    // وهذا لمن يقرأ الجدول ليعرف عمّ سُئل.
    data: { lessonId, question, answer, createdAt: now },
    // والعمودُ لا يُذكر إن لم يكن ثَمّ متّجه: ذكرُه فارغاً يمحو
    // متّجهاً محفوظاً لو كُتب الصفُّ نفسه ثانيةً.
    ...(embedding ? { embedding } : {}),
    updated_at: now,
  };
  const send = (payload: Record<string, unknown>) =>
    fetch(`${config.url}/rest/v1/ai_qa_cache?on_conflict=id`, {
      method: "POST",
      headers: {
        apikey: config.key,
        Authorization: `Bearer ${config.key}`,
        "Content-Type": "application/json",
        Prefer: "resolution=merge-duplicates,return=minimal",
      },
      body: JSON.stringify(payload),
    });
  // ‏والأعمدةُ المقروءة: أُضيفت إلى الجدول في الإنتاج وعليها يقوم عرضُ
  // ‏`solved_questions_cache`. والخادمُ كان يكتب في `data` وحده فبقيت فارغة،
  // ‏فبدا كلُّ صفٍّ محفوظٍ في العرض كأنه لم يُحفظ. فتُكتب هنا مع `data`.
  const readable = readableCacheColumns ? cacheReadableColumns(key, lessonId, question, answer, domain) : {};
  let response = await send({ ...body, ...readable });
  if (!response.ok && readableCacheColumns) {
    const detail = await response.text();
    // ‏قاعدةٌ بلا هذه الأعمدة (بيئةٌ أخرى): تُترك ويُكتب الصفُّ كما كان، لا
    // ‏أن يضيع الحفظ كلُّه بسبب عمودٍ للعرض.
    if (/PGRST204|column/i.test(detail)) {
      readableCacheColumns = false;
      logger.warn({ detail: detail.slice(0, 200) }, "[cache] readable columns missing — saving data only");
      response = await send(body);
    } else {
      throw new Error(`cache write failed (${response.status} ${detail.slice(0, 300)})`);
    }
  }
  if (!response.ok) {
    throw new Error(
      `cache write failed (${response.status} ${(await response.text()).slice(0, 300)})`,
    );
  }
  logger.info(
    { key, lessonId, withVector: Boolean(embedding), readableColumns: readableCacheColumns },
    "[cache] SAVED",
  );
}

/** هل في الجدول الأعمدةُ المقروءة؟ يُفترض نعم حتى تردّ القاعدةُ بغير ذلك. */
let readableCacheColumns = true;

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
    // ‏وصورةٌ لم تُقرأ تُحفظ ببصمتها: كانت تُجاب ولا تُحفظ. ولا تُقاس
    // ‏بالكلمات ولا بالمعنى — لا نصَّ لها — فتُصاب إن أُرسلت هي نفسها.
    const key = keyText
      ? cacheKey(lesson.id, keyText)
      : image
        ? cacheKey(
            lesson.id,
            imageKeyText(
              createHash("sha256").update(image.data).digest("hex").slice(0, 24),
              question === PHOTO_DEFAULT_PROMPT ? "" : question,
            ),
          )
        : "";
    // ── سلّمُ الذاكرة: الأرخصُ أوّلاً ──
    //
    // حرفياً، ثم بالكلمات، ثم بالمعنى. وأوّلُ من يُصيب يُوقف السلّم،
    // فلا يُحسب متّجهٌ لسؤالٍ وُجد جوابُه بلا شبكة.
    let cached = key ? await readCachedAnswer(key) : null;
    if (!cached && key && keyText) {
      cached = await findSimilarCachedAnswer(lesson.id, keyText);
    }
    // ومتّجهُ السؤال يُحتفظ به إن حُسب: يُخزَّن مع الصفّ الجديد عند
    // الإخفاق، فلا يُنادى النموذجُ ثانيةً لحسابه.
    let vector: number[] | null = null;
    if (!cached && key && keyText) {
      const byMeaning = await findByMeaning(lesson.id, keyText);
      cached = byMeaning.answer;
      vector = byMeaning.vector;
    }
    if (cached) {
      // إصابةٌ في الذاكرة لا تُحسب من الحصّة ولا تُكلّف جوهرة: لم
      // يُستدعَ النموذج. والحصّةُ تُقرأ لتُعرض وحدها، لا لتُنقص.
      const seen = await readStudentQuota(student);
      // ويُنقّى المحفوظ عند قراءته: ما كُتب في الذاكرة قبل هذه
      // التنقية مشكولٌ كما ردّه النموذج.
      return res.json({
        answer: lightDiacritics(cached),
        cached: true,
        quota: seen.quota.snapshot,
      });
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

    // ── والإيجازُ مطلوبٌ في النصّ لا في السقف وحده ──
    //
    // السقفُ يقطع الإسهاب في منتصفه، فيصل الطفلَ شرحٌ مبتور. وطلبُ
    // الإيجاز يجعل النموذج يخطّط لإجابةٍ قصيرة من أوّلها فتنتهي تامّة.
    // فالاثنان معاً: هذا يُقصّر، وذاك يحرس.
    const brevity =
      "اجعل إجابتك موجزة: خطواتٌ مرقّمة قصيرة ثم الناتج. لا مقدّمة ولا خاتمة ولا تلخيصٌ لما قلته، ولا نصائح إضافية.";
    // ── ونبرةُ الشرح ──
    //
    // الإجابةُ تُقرأ وتُسمع: الطفل يقرؤها في الشاشة ويضغط زرَّ النطق
    // فيسمعها. ومحرّكُ النطق ينطق ما يُكتب كما كُتب — فإن كُتبت الإجابة
    // فصحى مشكولةً نطقها بالإعراب حرفاً حرفاً، فيسمع الطفل درساً في
    // النحو لا شرحاً لمسألته.
    //
    // والحلُّ في الكتابة لا في النطق وحده. إسقاطُ التشكيل قبل النطق
    // يمنع الحركاتَ المكتوبة، ولا يمنع «إنَّ هذا الحلَّ يستلزم» — فتُطلب
    // النبرةُ من المصدر: معلّمٌ سعوديٌّ يشرح لطفل، بلهجةٍ بيضاء يفهمها
    // كلُّ من في المدارس.
    //
    // ── واللهجةُ دارجةٌ لا بيضاء ──
    // كانت بيضاءَ — فصحى مبسّطة — والمطلوبُ عاميٌّ صريح: «شوف يا بطل»
    // لا «انظر أيها الطالب». والفرقُ ليس ذوقاً: الطفل في الصف الرابع
    // يسمع الدارجةَ في بيته ومدرسته، ويقرأ الفصحى في كتابه. والشرحُ
    // بلسانِ ما يسمعه يُفهم من أوّل مرّة، وبلسانِ ما يقرؤه يُفهم بعد أن
    // يُترجمه في رأسه.
    //
    // ── وثمنُ ذلك مذكورٌ هنا لا مكتومٌ ──
    // الإجابةُ تُقرأ مكتوبةً كما تُسمع، والدارجةُ مكتوبةً تُخالف رسمَ
    // كتابه. فهي أفهمُ مسموعةً وأغربُ مقروءة، وهذا اختيارٌ صُنع بعد أن
    // قيلت المفاضلة.
    //
    // والتشكيلُ ممنوعٌ هنا أيضاً لا في التطبيق وحده: المصفاةُ في
    // `speakableText` تحرس النطق، وهذا يحرس ما يُقرأ في الشاشة.
    const tone =
      "اكتب بلهجة سعودية بيضاء عامية دافئة وبسيطة مئة بالمئة، ككلام شخصي يومي من معلّم لطالبه — لا كلام كتب. " +
      "استخدم دائمًا كلمات مثل: «عشان»، «كذا»، «شوف يا بطل»، «ما فيه»، «تخيّل». " +
      "وممنوع منعًا باتًا أي لغة فصحى أو كلمات معربة رسمية أو مصطلحات متكلّفة. " +
      // التشكيلُ الخفيف لا المنعُ ولا الكامل — انظر `lightDiacritics`.
      "ضع الشدّة دائمًا، وضع الحركة داخل الكلمة فقط حين تمنع الالتباس في نطقها (مثل: عَلّم، فَهِمت، يُفرِّق)، " +
      "ولا تضع أي حركة أو سكون على آخر حرف في الكلمة، ولا تنوين أبدًا. " +
      "واجعل جملك قصيرة يفصل بينها فاصلة أو نقطة، فالإجابة تُقرأ بصوت مسموع ويحتاج الطالب أن يلتقط أنفاسه معك. " +
      "وجملةٌ واحدة لكل فكرة، لا تتجاوز عشر كلمات تقريبًا، بلا أقواس ولا رموز زخرفية.";
    const prompt = image
      ? `أنت مساعد تعليمي ذكي لطفلٍ في المرحلة الابتدائية. في الصورة المرفقة مسألةٌ من كتابه أو دفتره.

اقرأ ما في الصورة أوّلاً، ثم أجب عن طلب الطالب: ${question}

اشرح الحلّ خطوةً خطوة بلغةٍ يفهمها طفل. ${tone} ${brevity} ${SOLVER_SCOPE_INSTRUCTION} وإن كانت الصورة غير واضحة فقل ذلك صراحةً واطلب صورةً أوضح، ولا تخمّن ما لا تراه.

وللاستئناس، هذا نصّ درسه:
${lesson.text}`
      : `أنت مساعد تعليمي ذكي. اقرأ النص التالي للاستفادة منه داخليًا:\n\n${lesson.text}\n\nالسؤال: ${question}\n\nأجب مباشرة وبأسلوب مفيد وخطوة بخطوة للطالب. ${tone} ${brevity} لا تذكر أنك اعتمدت على نص الدرس، ولا تقل "بناءً على النص الموجود في الدرس" أو أي عبارة مشابهة؛ ابدأ بالإجابة أو الحل مباشرة. ${SOLVER_SCOPE_INSTRUCTION}`;
    // وما بقي من الميزانية بعد القراءة، لا ميزانيةٌ كاملةٌ ثانية: الخادم
    // ينتظر ما ينتظره التطبيق وينتهي قبله.
    const data = await callGemini(prompt, {
      maxOutputTokens: SOLVER_MAX_TOKENS,
      ...(image
        ? { image, budgetMs: GEMINI_BUDGET_MS - (Date.now() - startedAt) }
        : {}),
    });
    // والتشكيلُ يسقط هنا، قبل أن يُعرض ويُحفظ ويُنطق.
    //
    // الطلبُ يمنعه، والنموذج يمتثل في الغالب لا دائماً: عبارةٌ منقولةٌ
    // من نصّ الدرس تأتي مشكولةً كما في الكتاب. فالطلبُ نيّة، وهذه حراسة.
    const answer = lightDiacritics(getGeminiText(data));
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
    // ‏الحفظُ في الذاكرة يبدأ ولا يُنتظر: الطفلُ لا ينتظر كتابةً لا تخصّه،
    // ‏و`persistAnswer` لا يُسقط شيئاً — يعيد المحاولة ويكمل المتّجه وحده.
    if (key) {
      void persistAnswer({
        key,
        lessonId: lesson.id,
        question: keyText ?? (image ? `[صورة] ${question}` : question),
        answer,
        vector,
        searchable: Boolean(keyText),
        domain: lesson.subject,
      });
    }
    await Promise.all([
      writeStudentQuota(rowId, studentRow, nextQuota, gems - verdict.gemsCharged).catch((error) =>
        logger.error({ err: error }, "[gemini] quota not saved"),
      ),
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

/**
 * بنكُ أسئلة الاختبار من نصّ الدرس — بتوجيهٍ تربويٍّ ومخطّطٍ صارم على الخادم.
 *
 * الطلبُ يحمل الدرسَ وسياقَه والعدد، لا توجيهاً: الضوابطُ في
 * `lib/quizGenerator` لا يغيّرها المتصفّح. والردُّ `{ questions }` بصيغة
 * التطبيق، بعد أن يُفحص كلُّ سؤال ويُردّ ما لا يصلح.
 *
 * وطلبٌ بحقل `prompt` وحده (نسخةُ لوحةٍ أقدم ما زالت مفتوحة) يُخدم كما كان.
 */
const QUIZ_BUDGET_MS = 110_000;
const QUIZ_SINGLE_TRY_MS = 75_000;

router.post("/gemini/generate-quiz", requireContentManager, async (req, res) => {
  const lessonContent =
    typeof req.body?.lessonContent === "string" ? req.body.lessonContent.trim() : "";
  if (lessonContent) {
    if (lessonContent.length > LESSON_TEXT_SAFETY_LIMIT) {
      return res.status(400).json({ error: "نصّ الدرس أطول من المسموح" });
    }
    const count = clampQuizCount(req.body?.count);
    const field = (key: string) =>
      typeof req.body?.[key] === "string" ? req.body[key].trim().slice(0, 200) : "";
    try {
      const data = await callGemini(
        quizPrompt({
          lessonContent,
          count,
          grade: field("grade"),
          subject: field("subject"),
          unit: field("unit"),
          lesson: field("lesson"),
        }),
        {
          systemInstruction: QUIZ_SYSTEM_INSTRUCTION,
          responseSchema: QUIZ_RESPONSE_SCHEMA,
          json: true,
          temperature: 0.55,
          maxOutputTokens: 32_000,
          budgetMs: QUIZ_BUDGET_MS,
          singleTryMs: QUIZ_SINGLE_TRY_MS,
          preferQuality: true,
        },
      );
      const { questions, rejected } = parseQuizQuestions(getGeminiText(data) ?? "", count);
      if (Object.keys(rejected).length) {
        logger.info({ count, kept: questions.length, rejected }, "[gemini] quiz bank filtered");
      }
      if (questions.length === 0) {
        logger.warn(
          { finishReason: data?.candidates?.[0]?.finishReason, rejected },
          "[gemini] quiz bank empty",
        );
        return res.status(502).json({
          error: "لم يُولَّد سؤالٌ صالح، حاول مرة أخرى",
          finishReason: data?.candidates?.[0]?.finishReason,
        });
      }
      return res.json({ questions, requested: count });
    } catch (error: any) {
      logger.error({ err: error }, "[gemini] quiz generation failed");
      return res
        .status(error?.statusCode || 500)
        .json({ error: "تعذر توليد الاختبار بالذكاء الاصطناعي" });
    }
  }

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

/** ما لا يُنتظر أكثر منه لتوليد حزمة المذاكرة. */
const STUDY_BUDGET_MS = 75_000;

/** وسقفُ ما يُخرجه النموذج لها: خريطةٌ وثلاث مغامرات تحتاج متّسعاً. */
const STUDY_MAX_TOKENS = 8_000;

/**
 * يحفظ حزمة المذاكرة مع الدرس، فلا تُولَّد ثانيةً.
 *
 * و[build] يبني ما يُكتب من السجلّ كما هو الآن — لا من نسخةٍ قُرئت قبل نداء
 * النموذج: التوسعةُ تضمّ مغامراتها إلى المحفوظ فعلاً، فلا تمحو توسعةٌ أخرى
 * سبقتها. ويُرجع `null` ليُترك السجلّ كما هو — نصُّ الدرس تغيّر مثلاً.
 */
async function persistStudyPack(
  lessonId: string,
  pack: StudyPack,
  build?: (data: Record<string, unknown>) => StudyPack | null,
): Promise<void> {
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
  if (!read.ok) throw new Error(`study read failed (${read.status})`);
  const rows = await read.json();
  const data = Array.isArray(rows) && rows[0]?.data && typeof rows[0].data === "object"
    ? (rows[0].data as Record<string, unknown>)
    : null;
  if (!data) throw new Error("lesson row vanished before the pack was saved");
  const next = build ? build(data) : pack;
  if (!next) return;
  const write = await fetch(
    `${config.url}/rest/v1/lesson_configs?id=eq.${encodeURIComponent(lessonId)}`,
    {
      method: "PATCH",
      headers: { ...headers, Prefer: "return=minimal" },
      body: JSON.stringify({
        data: { ...data, interactiveStudy: next },
        updated_at: new Date().toISOString(),
      }),
    },
  );
  if (!write.ok) throw new Error(`study write failed (${write.status})`);
}

/** دروسٌ تُوسَّع حزمتُها الآن، فلا تُطلق توسعتان لدرسٍ واحد. */
const expandingStudy = new Set<string>();

/** محاولاتُ التوسعة لكل درس في عمر الخادم: نموذجٌ يُخفق مرّةً بعد مرّة لا يُنادى بلا نهاية. */
const studyExpansionTries = new Map<string, number>();
const STUDY_EXPANSION_MAX_TRIES = 3;

/**
 * يوسّع حزمةَ درسٍ في الخلفية بمغامراتٍ جديدة من نصّه، حتى تبلغ هدفَها.
 *
 * لا يُنتظر ولا يمسّ الردّ: الطفلُ يلعب ما في الحزمة الآن، والجديدُ يصله
 * في فتحته التالية. ويُكتب بشرط أن يبقى نصُّ الدرس كما هو — درسٌ عُدّل
 * أثناء التوسعة يُولَّد من جديد لا يُرقَّع.
 */
function expandStudyInBackground(
  lesson: { id: string; text: string; unit?: string; lesson?: string; subject?: string },
  pack: StudyPack,
): void {
  if (pack.scenarios.length >= targetScenarios(pack)) return;
  const tries = studyExpansionTries.get(lesson.id) ?? 0;
  if (expandingStudy.has(lesson.id) || tries >= STUDY_EXPANSION_MAX_TRIES) return;
  expandingStudy.add(lesson.id);
  studyExpansionTries.set(lesson.id, tries + 1);
  const owner = { lessonId: lesson.id, lessonStamp: lessonStampOf(lesson.text) };
  void (async () => {
    try {
      const title = [lesson.unit, lesson.lesson].filter(Boolean).join(" — ");
      const data = await callGemini(
        expansionPrompt({ lessonTitle: title || lesson.lesson || lesson.subject || "", lessonText: lesson.text, pack }),
        { maxOutputTokens: STUDY_MAX_TOKENS, budgetMs: STUDY_BUDGET_MS },
      );
      const extra = parseExpansion(getGeminiText(data));
      if (extra.length === 0) {
        logger.warn({ lessonId: lesson.id }, "[study] expansion returned nothing usable");
        return;
      }
      await persistStudyPack(lesson.id, pack, (row) => {
        const text = typeof row.lessonContent === "string" && row.lessonContent.trim()
          ? row.lessonContent.trim()
          : typeof row.lessonText === "string" ? row.lessonText.trim() : "";
        if (lessonStampOf(text) !== owner.lessonStamp) return null;
        const current = readStudyPack(row.interactiveStudy, owner) ?? pack;
        return mergeScenarios(current, extra);
      });
      logger.info({ lessonId: lesson.id, added: extra.length }, "[study] expanded");
    } catch (error) {
      logger.warn({ err: error, lessonId: lesson.id }, "[study] expansion failed");
    } finally {
      expandingStudy.delete(lesson.id);
    }
  })();
}

/**
 * حزمةُ المذاكرة الذكية لدرس: خريطةٌ ذهنية ومغامراتٌ قصصية.
 *
 * ── لماذا تُخزَّن مع الدرس ──
 * توليدُها نداءٌ واحد كبير — خريطةٌ وثلاثُ مغامرات بتسعة مواقف — وثلاثون
 * طفلاً في الصفّ يفتحون الدرس نفسه. فتُولَّد أوّل مرّة وتُحفظ في سجلّ
 * الدرس، ثم تُقرأ منه في جزءٍ من الثانية بلا نداء ولا حصّة.
 *
 * وهي حزمةٌ للدرس لا للطفل: المغامراتُ نفسها تصلح لكل من يدرسه، والجديدُ
 * في كل جولةٍ هو أيَّها يُختار — واختيارُه في التطبيق.
 *
 * ── ولماذا لا تُحسب من حصّة الأسئلة ──
 * حصّةُ `aiQuota` تحرس أسئلةَ الطفل الحرّة، وهذه مادةُ درسٍ تُولَّد مرّةً
 * لكل درس. فحسابُها على أوّل من يفتح الدرس يحرمه عشرَ أسئلةٍ لأنه سبق
 * زملاءه.
 */
router.post(
  "/ai/interactive-study",
  answerRateLimit,
  requireStudentSession,
  async (req, res) => {
    const lessonId =
      typeof req.body?.lessonId === "string" ? req.body.lessonId.trim() : "";
    if (!lessonId) {
      return res
        .status(400)
        .json({ error: "لم يصل معرّف الدرس", code: "bad_request" });
    }
    try {
      const student = res.locals.student as StudentActor;
      const lesson = await resolveStudentLesson(lessonId, student);
      if (lesson.reason) {
        const messages = {
          not_found: "لم يُعثر على هذا الدرس في قاعدة البيانات.",
          out_of_scope: lesson.detail
            ? `هذا الدرس ليس ضمن مسار حسابك — ${lesson.detail}`
            : "هذا الدرس ليس ضمن مسار حسابك.",
          no_text: "هذا الدرس لا يحتوي على شرح نصي بعد — اطلب من معلمك إضافته.",
        } as const;
        return res
          .status(403)
          .json({ error: messages[lesson.reason], code: lesson.reason });
      }

      // ── المحفوظ أوّلاً، إن كان لهذا الدرس ولنصّه الحالي ──
      // حزمةٌ نُسخت مع مخطّطٍ من درسٍ آخر، أو بقيت بعد تعديل نصّ الدرس،
      // لا تُقرأ: كلُّ مخطّطٍ مستقلٌّ بأسئلته من نصّه هو.
      const owner = { lessonId: lesson.id, lessonStamp: lessonStampOf(lesson.text) };
      const stored = readStudyPack(lesson.interactiveStudy, owner);
      if (stored) {
        logger.info({ lessonId }, "[study] served from the lesson row");
        expandStudyInBackground(lesson, stored);
        return res.json({ pack: stored, generated: false });
      }

      const title = [lesson.unit, lesson.lesson].filter(Boolean).join(" — ");
      const data = await callGemini(
        studyPrompt({
          lessonTitle: title || lesson.lesson || lesson.subject,
          lessonText: lesson.text,
          grade: lesson.subject,
        }),
        { maxOutputTokens: STUDY_MAX_TOKENS, budgetMs: STUDY_BUDGET_MS },
      );
      const pack = parseStudyPack(getGeminiText(data), title, undefined, owner);
      if (!pack) {
        // ولا يُخزَّن ناقصٌ: الإخفاقُ الصريح يُعيد التوليد في المرّة
        // القادمة، والنصفُ المخزَّن يبقى ناقصاً إلى الأبد.
        logger.warn({ lessonId }, "[study] model output was not a usable pack");
        return res.status(502).json({
          error: "تعذّر تحضير المذاكرة لهذا الدرس الآن. حاول مرة أخرى.",
          code: "bad_pack",
        });
      }

      // الحفظُ لا يُنتظر ولا يُسقط الردّ: فشلُه يعني توليداً ثانياً في
      // المرّة القادمة لا حزمةً ضائعة.
      // والتوسعةُ بعد الحفظ لا معه: تضمّ إلى المحفوظ، فتنتظر أن يُحفظ.
      void persistStudyPack(lessonId, pack)
        .then(() => expandStudyInBackground(lesson, pack))
        .catch((error) =>
          logger.error({ err: error, lessonId }, "[study] pack not saved"),
        );
      logger.info(
        { lessonId, scenarios: pack.scenarios.length },
        "[study] generated",
      );
      return res.json({ pack, generated: true });
    } catch (error) {
      logger.error({ err: error, lessonId }, "[study] failed");
      return res.status(503).json({
        error: "تعذّر تحضير المذاكرة الآن. حاول مرة أخرى.",
        code: "unavailable",
      });
    }
  },
);

/**
 * ألعابُ «بطاقة المذاكرة» التفاعلية لدرس: سحبٌ وإسقاط، ومطابقة، وأسئلةٌ متتالية.
 *
 * كحزمة المذاكرة: تُولَّد من نصّ الدرس أوّلَ مرّة، وتُحفظ في سجلّه
 * (`data.studyGames`) ببصمة نصّه، ثم تُقرأ منه. ونصٌّ عدّله المعلم يُولّد
 * ألعاباً جديدة. والمكافآتُ فيها محصورةٌ على الخادم (`lib/studyGames`)،
 * ويصرفها `/student/progress/reward` من السجلّ لا من التطبيق.
 */
const studyGamesInFlight = new Map<string, Promise<unknown>>();

async function persistStudyGames(lessonId: string, pack: unknown): Promise<void> {
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
  if (!read.ok) throw new Error(`study games read failed (${read.status})`);
  const rows = await read.json();
  const data = Array.isArray(rows) && rows[0]?.data && typeof rows[0].data === "object"
    ? (rows[0].data as Record<string, unknown>)
    : null;
  if (!data) throw new Error("lesson row vanished before the games were saved");
  const write = await fetch(
    `${config.url}/rest/v1/lesson_configs?id=eq.${encodeURIComponent(lessonId)}`,
    {
      method: "PATCH",
      headers: { ...headers, Prefer: "return=minimal" },
      body: JSON.stringify({ data: { ...data, studyGames: pack }, updated_at: new Date().toISOString() }),
    },
  );
  if (!write.ok) throw new Error(`study games write failed (${write.status})`);
}

router.post(
  "/ai/study-games",
  answerRateLimit,
  requireStudentSession,
  async (req, res) => {
    const lessonId = typeof req.body?.lessonId === "string" ? req.body.lessonId.trim() : "";
    if (!lessonId) {
      return res.status(400).json({ error: "لم يصل معرّف الدرس", code: "bad_request" });
    }
    try {
      const student = res.locals.student as StudentActor;
      const lesson = await resolveStudentLesson(lessonId, student);
      if (lesson.reason) {
        const messages = {
          not_found: "لم يُعثر على هذا الدرس في قاعدة البيانات.",
          out_of_scope: "هذا الدرس ليس ضمن مسار حسابك.",
          no_text: "هذا الدرس لا يحتوي على شرح نصي بعد — اطلب من معلمك إضافته.",
        } as const;
        return res.status(403).json({ error: messages[lesson.reason], code: lesson.reason });
      }
      const owner = { lessonId: lesson.id, lessonStamp: lessonStampOf(lesson.text) };
      const stored = readStudyGames(lesson.studyGames, owner);
      if (stored) return res.json({ pack: stored, generated: false });

      // طفلان فتحا الدرس معاً: توليدٌ واحد يخدمهما.
      const flightKey = `${owner.lessonId}:${owner.lessonStamp}`;
      let flight = studyGamesInFlight.get(flightKey);
      if (!flight) {
        flight = (async () => {
          const title = [lesson.unit, lesson.lesson].filter(Boolean).join(" — ");
          const data = await callGemini(
            studyGamesPrompt({
              lessonTitle: title || lesson.lesson || lesson.subject,
              lessonText: lesson.text,
              subject: lesson.subject,
              grade: lesson.grade,
            }),
            {
              systemInstruction: STUDY_GAMES_SYSTEM_INSTRUCTION,
              responseSchema: STUDY_GAMES_SCHEMA,
              json: true,
              temperature: 0.8,
              maxOutputTokens: STUDY_MAX_TOKENS * 3,
              budgetMs: STUDY_BUDGET_MS,
              singleTryMs: 45_000,
            },
          );
          const pack = parseStudyGames(getGeminiText(data) ?? "", owner);
          if (pack) {
            void persistStudyGames(lesson.id, pack).catch((error) =>
              logger.error({ err: error, lessonId }, "[study-games] not saved"),
            );
          }
          return pack;
        })().finally(() => studyGamesInFlight.delete(flightKey));
        studyGamesInFlight.set(flightKey, flight);
      }
      const pack = await flight;
      if (!pack) {
        logger.warn({ lessonId }, "[study-games] model output was not usable");
        return res.status(502).json({
          error: "تعذّر تحضير ألعاب هذا الدرس الآن. حاول مرة أخرى.",
          code: "bad_pack",
        });
      }
      logger.info({ lessonId }, "[study-games] generated");
      return res.json({ pack, generated: true });
    } catch (error) {
      logger.error({ err: error, lessonId }, "[study-games] failed");
      return res.status(503).json({
        error: "تعذّر تحضير الألعاب الآن. حاول مرة أخرى.",
        code: "unavailable",
      });
    }
  },
);


/**
 * نسخةٌ جديدة من لعبة مذاكرة عند إعادة اللعب — لا تتكرّر أسئلتها.
 *
 * التطبيقُ يرسل نوعَ اللعبة وما رآه الطالب منها من قبل (\`exclude\`)، فتُولَّد
 * نسخةٌ من النصّ الكامل للدرس تتجنّبه. ولا تُحفظ: هي لهذه الجولة وحدها،
 * والمكافأةُ تبقى على اللعبة نفسها (\`درس::نوع\`) تُصرف مرّةً كما كانت.
 */
router.post(
  "/ai/study-games/fresh",
  answerRateLimit,
  requireStudentSession,
  async (req, res) => {
    const lessonId = typeof req.body?.lessonId === "string" ? req.body.lessonId.trim() : "";
    const type = req.body?.gameType;
    if (!lessonId || !isStudyGameType(type)) {
      return res.status(400).json({ error: "طلبٌ غير صالح", code: "bad_request" });
    }
    const exclude = Array.isArray(req.body?.exclude)
      ? req.body.exclude
          .filter((item: unknown): item is string => typeof item === "string")
          .slice(-MAX_FRESH_EXCLUDE)
      : [];
    try {
      const student = res.locals.student as StudentActor;
      const lesson = await resolveStudentLesson(lessonId, student);
      if (lesson.reason) {
        return res.status(lesson.reason === "not_found" ? 404 : 403).json({ error: "الدرس غير متاح", code: lesson.reason });
      }
      const title = [lesson.unit, lesson.lesson].filter(Boolean).join(" — ");
      const data = await callGemini(
        freshGamePrompt({
          type,
          lessonTitle: title || lesson.lesson || lesson.subject,
          lessonText: lesson.text,
          subject: lesson.subject,
          grade: lesson.grade,
          exclude,
        }),
        {
          systemInstruction: STUDY_GAMES_SYSTEM_INSTRUCTION,
          responseSchema: STUDY_GAMES_SCHEMA,
          json: true,
          // ‏أعلى من التوليد الأول: التنوّعُ هو المطلوب هنا.
          temperature: 1,
          maxOutputTokens: STUDY_MAX_TOKENS * 3,
          budgetMs: STUDY_BUDGET_MS,
          singleTryMs: 45_000,
        },
      );
      const game = parseFreshGame(getGeminiText(data) ?? "", type, exclude);
      if (!game) {
        logger.warn({ lessonId, type }, "[study-games] fresh game not usable");
        return res.status(502).json({ error: "تعذّر تحضير نسخةٍ جديدة الآن", code: "bad_pack" });
      }
      return res.json({ game });
    } catch (error) {
      logger.error({ err: error, lessonId, type }, "[study-games] fresh failed");
      return res.status(503).json({ error: "تعذّر تحضير نسخةٍ جديدة الآن", code: "unavailable" });
    }
  },
);

export default router;
