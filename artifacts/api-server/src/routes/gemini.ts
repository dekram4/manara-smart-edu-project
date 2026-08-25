import { Router } from "express";
import { requireAdmin } from "../middleware/adminAuth";
import { requireStudentSession } from "../middleware/studentAuth";
import { createRateLimit } from "../middleware/rateLimiter";
import { logger } from "../lib/logger";
import {
  apiSupabaseConfig,
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

  for (const model of models) {
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
          signal: AbortSignal.timeout(18_000),
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

async function resolveStudentLesson(
  lessonId: string,
  student: StudentActor,
): Promise<{ id: string; text: string } | null> {
  const config = apiSupabaseConfig();
  if (!config || !lessonId) return null;
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
  if (!data || !matchesStudentScope(data, student)) return null;
  const lesson = data as Record<string, unknown>;
  const text = typeof lesson.lessonContent === "string"
    ? lesson.lessonContent.trim()
    : typeof lesson.lessonText === "string"
      ? lesson.lessonText.trim()
      : "";
  return text ? { id: String(row.id || lessonId), text } : null;
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
        atram: student.atram,
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
    return res.status(400).json({ error: "معرّف الدرس أو السؤال غير صالح" });
  }
  try {
    const student = res.locals.student as StudentActor;
    const lesson = await resolveStudentLesson(lessonId, student);
    if (!lesson) {
      return res.status(403).json({ error: "هذا الدرس غير متاح لحسابك أو لا يحتوي على شرح نصي." });
    }
    const prompt = `أنت مساعد تعليمي ذكي. اقرأ النص التالي للاستفادة منه داخليًا:\n\n${lesson.text}\n\nالسؤال: ${question}\n\nأجب مباشرة وبأسلوب مفيد وخطوة بخطوة للطالب. لا تذكر أنك اعتمدت على نص الدرس، ولا تقل "بناءً على النص الموجود في الدرس" أو أي عبارة مشابهة؛ ابدأ بالإجابة أو الحل مباشرة. إذا لم تجد الإجابة في نص الدرس، قل بوضوح: "هذا السؤال ليس من ضمن الدرس ولا أستطيع الإجابة عليه" ولا تستخدم معرفتك العامة.`;
    const data = await callGemini(prompt);
    const answer = getGeminiText(data);
    if (!answer) return res.status(502).json({ error: "لم تصل إجابة صالحة من خدمة الذكاء الاصطناعي" });
    await recordProblemSolverActivity(student, lesson.id, question, answer).catch((error) =>
      logger.warn({ err: error }, "[gemini] problem solver activity was not recorded"),
    );
    return res.json({ answer });
  } catch (error: any) {
    logger.error({ err: error }, "[gemini] answer failed");
    return res
      .status(error?.statusCode || 500)
      .json({ error: "تعذر الاتصال بخدمة الذكاء الاصطناعي" });
  }
});

// Quiz generation is an admin operation — guard with session check
router.post("/gemini/generate-quiz", requireAdmin, async (req, res) => {
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
