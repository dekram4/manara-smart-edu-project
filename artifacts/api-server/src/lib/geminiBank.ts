/**
 * نداءٌ واحد إلى Gemini لتوليد بنك جولات التحدي.
 *
 * مفصولٌ عن مسار Gemini لأن جسر المزامنة يحتاجه أيضاً — يولّد البنك في
 * الخلفية بعد أن يحفظ المعلّم درساً. واستيراد المسار من الجسر يجرّ معه
 * حدودَ المعدّل والجلسات وما لا شأن له بنداءٍ في الخلفية.
 */

import { logger } from "./logger";
import { bankPrompt } from "./challengeBank";

/** النماذج المفضّلة، بترتيب المسار نفسه. */
const MODELS = [
  process.env.GEMINI_MODEL?.trim().replace(/^models\//, ""),
  "gemini-flash-lite-latest",
  "gemini-2.5-flash-lite",
  "gemini-flash-latest",
  "gemini-2.5-flash",
].filter(Boolean) as string[];

export interface BankRequest {
  subject: string;
  unit?: string;
  lesson?: string;
  lessonText: string;
}

/**
 * يطلب بنكاً ويعيد نصّ الردّ كما جاء، للمصفّي أن يفكّه.
 *
 * يجرّب النماذج بالترتيب: نموذجٌ يردّ 404 أو 400 لا يُعاد عليه — تلك
 * حال نموذجٍ لا وجود له أو طلبٍ لا يقبله — وما سواه يُعاد بعد مهلة.
 */
export async function generateChallengeBank(input: BankRequest): Promise<string> {
  const apiKey = process.env.GEMINI_API_KEY?.trim();
  if (!apiKey) throw new Error("GEMINI_API_KEY is not configured");

  const prompt = bankPrompt(input);
  let lastError: unknown = null;

  for (const model of MODELS) {
    try {
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(apiKey)}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: {
              temperature: 0.9,
              maxOutputTokens: 32000,
              responseMimeType: "application/json",
            },
          }),
          // مهلةٌ سخيّة: هذا يعمل في الخلفية بعد أن ردّ المسار، فلا أحد
          // ينتظره. وقطعُه مبكراً يُهدر نداءً كاد يكتمل.
          signal: AbortSignal.timeout(120_000),
        },
      );
      if (!response.ok) {
        lastError = new Error(`${model} → ${response.status}`);
        if (response.status === 404 || response.status === 400) continue;
        continue;
      }
      const data: any = await response.json();
      const text = data?.candidates?.[0]?.content?.parts
        ?.map((part: any) => (typeof part?.text === "string" ? part.text : ""))
        .join("")
        .trim();
      if (text) return text;
      lastError = new Error(`${model} أعاد ردّاً فارغاً`);
    } catch (error) {
      lastError = error;
    }
  }

  logger.warn({ err: lastError }, "[gemini] challenge bank generation exhausted models");
  throw lastError instanceof Error ? lastError : new Error("تعذّر توليد البنك");
}
