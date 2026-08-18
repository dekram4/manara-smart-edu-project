import { Router } from "express";
import { requireAdmin } from "../middleware/adminAuth";
import { createRateLimit } from "../middleware/rateLimiter";
import { logger } from "../lib/logger";

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
        configuredModel,
        "gemini-flash-latest",
        "gemini-flash-lite-latest",
        "gemini-3.5-flash",
        "gemini-3.1-flash-lite",
        "gemini-2.5-flash-lite",
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
  const models = await getGeminiModels(apiKey);
  let lastUnavailableMessage = "";

  for (const model of models) {
    const response = await fetch(
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
      },
    );
    const data: any = await response.json().catch(() => ({}));
    if (response.ok) {
      logger.info(`[gemini] generated with ${model.replace(/^models\//, "")}`);
      return data;
    }

    const message = data?.error?.message || "Gemini request failed";
    const modelUnavailable =
      response.status === 404 ||
      /not found|not available|not supported|new users/i.test(message);
    if (modelUnavailable) {
      lastUnavailableMessage = message;
      logger.warn(
        `[gemini] skipping unavailable model ${model}: ${message}`,
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

// /api/gemini/answer is public (students need it) but rate-limited per IP
router.post("/gemini/answer", answerRateLimit, async (req, res) => {
  const lesson =
    typeof req.body?.lesson === "string" ? req.body.lesson.trim() : "";
  const question =
    typeof req.body?.question === "string" ? req.body.question.trim() : "";
  if (!lesson || !question || lesson.length > 12000 || question.length > 2000) {
    return res.status(400).json({ error: "محتوى الدرس أو السؤال غير صالح" });
  }
  const prompt = `أنت مساعد تعليمي ذكي. اقرأ النص التالي:\n\n${lesson}\n\nالسؤال: ${question}\n\nأجب إجابة مباشرة، ذكية، مفصلة، وبدون مقدمات أو تكرار للسؤال. إذا لم تجد الإجابة في نص الدرس، قل بوضوح: "هذا السؤال ليس من ضمن الدرس ولا أستطيع الإجابة عليه" ولا تستخدم معرفتك العامة. فقط أعطِ الجواب النهائي للطالب.\n`;
  try {
    const data = await callGemini(prompt);
    return res.json({ answer: getGeminiText(data) });
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
