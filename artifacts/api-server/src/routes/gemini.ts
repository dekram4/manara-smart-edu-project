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

// 20 AI-answer requests per IP per minute — prevents Gemini quota abuse
// while still allowing normal student lesson use
const answerRateLimit = createRateLimit(20);

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
  }: { temperature?: number; maxOutputTokens?: number; json?: boolean } = {},
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
  const deadline = Date.now() + GEMINI_BUDGET_MS;

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
            contents: [{ parts: [{ text: prompt }] }],
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
  | { id: string; text: string; reason?: undefined; detail?: undefined }
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
  return { id: String(row.id || lessonId), text };
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

router.post("/gemini/answer", answerRateLimit, requireStudentSession, async (req, res) => {
  const lessonId =
    typeof req.body?.lessonId === "string" ? req.body.lessonId.trim() : "";
  const question =
    typeof req.body?.question === "string" ? req.body.question.trim() : "";
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
    const prompt = `أنت مساعد تعليمي ذكي. اقرأ النص التالي للاستفادة منه داخليًا:\n\n${lesson.text}\n\nالسؤال: ${question}\n\nأجب مباشرة وبأسلوب مفيد وخطوة بخطوة للطالب. لا تذكر أنك اعتمدت على نص الدرس، ولا تقل "بناءً على النص الموجود في الدرس" أو أي عبارة مشابهة؛ ابدأ بالإجابة أو الحل مباشرة. إذا لم تجد الإجابة في نص الدرس، قل بوضوح: "هذا السؤال ليس من ضمن الدرس ولا أستطيع الإجابة عليه" ولا تستخدم معرفتك العامة.`;
    const data = await callGemini(prompt);
    const answer = getGeminiText(data);
    if (!answer) {
      logger.warn({ lessonId }, "[gemini] answer rejected: empty completion");
      return res.status(502).json({
        error: "لم تصل إجابة صالحة من خدمة الذكاء الاصطناعي",
        code: "empty_answer",
      });
    }
    await recordProblemSolverActivity(student, lesson.id, question, answer).catch((error) =>
      logger.warn({ err: error }, "[gemini] problem solver activity was not recorded"),
    );
    return res.json({ answer });
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
