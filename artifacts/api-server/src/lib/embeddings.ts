/**
 * متّجهاتُ الأسئلة: المطابقةُ بالمعنى حين تخيب المطابقةُ بالحروف.
 *
 * ── لماذا ──
 * «ما وظيفة الخلية» و«ماذا تفعل الخلية» سؤالٌ واحد وإجابتُه واحدة، ولا
 * كلمةَ مفتاحيةً مشتركةً بينهما. فكلُّ مقياسٍ يقوم على الحروف يخيب
 * فيهما، ويُستدعى النموذجُ مرّتين ويُخصم من الطفل الثاني ثمنُ سؤالٍ
 * إجابتُه محفوظة.
 *
 * والمتّجهُ يقرّب ما تباعدت حروفُه واتّحد معناه. وثمنُه نداءٌ شبكيّ
 * صغير، فلا يُنادى إلا بعد أن يخيب ما لا يحتاج شبكةً.
 *
 * ── وهذه الوحدة نصفُها نقيّ ──
 * بناءُ الطلب وقراءةُ الجواب والتحقّقُ من المتّجه: كلُّها دوالُّ تُختبر
 * بلا شبكة، وهي حيث يقع الخطأ فعلاً. والنداءُ وحده يحتاج مفتاحاً.
 */

import { logger } from "./logger";

/** النموذج ومقاسُ متّجهه. */
export const EMBEDDING_MODEL = "text-embedding-004";

/**
 * عددُ أبعاد المتّجه.
 *
 * مربوطٌ بعمود `vector(768)` في قاعدة البيانات: متّجهٌ بمقاسٍ آخر ترفضه
 * القاعدة صراحةً، وهو خيرٌ من أن يُقارَن بمتّجهٍ من فضاءٍ آخر فتخرج
 * نسبةٌ لا تعني شيئاً. فيُتحقَّق من المقاس هنا قبل أن يُرسَل.
 */
export const EMBEDDING_DIMENSIONS = 768;

/**
 * أدنى تشابهٍ يُعَدّ سؤالاً واحداً — وهو نفسُه في `match_qa_cache`.
 *
 * ── لماذا ٠٫٧٨ لا ٠٫٨٨ ──
 * ٠٫٨٨ عتبةُ المقياس اللفظيّ، ونُقلت إلى المتّجهات بلا أن تُقاس فيها.
 * وهما مقياسان لا يُعطيان الرقم نفسه للقرب نفسه: اللفظيُّ يقيس كلماتاً
 * مشتركة، فـ٠٫٨٨ فيه سؤالان يشتركان في كل كلمةٍ إلا واحدة. والمتّجهُ
 * يقيس معنىً في فضاءٍ ٧٦٨ بُعداً، وسؤالان متطابقا المعنى مختلفا
 * الكلمات — «ما هي البلاستيدات الخضراء» و«ما المقصود بالبلاستيدات» —
 * يقعان بين ٠٫٨٠ و٠٫٨٦ فيه. فكانت العتبةُ تردّ ما جاءت الطبقةُ لتصيبه،
 * فيُستدعى النموذج مرّتين لسؤالٍ واحد.
 *
 * ── وما يحرس الخفض ──
 * ٠٫٧٨ تقبل قرباً أوسع، ومعه يقترب سؤالان عن مقدارين مختلفين. فالأرقامُ
 * تُشترط مطابقةً قاطعةً بعد الإصابة — انظر `sameQuantities` — فما خُفض
 * هنا يُشدّ هناك.
 */
export const VECTOR_THRESHOLD = 0.78;

/** ما لا يُنتظر أكثر منه لمتّجه. */
export const EMBEDDING_TIMEOUT_MS = 5_000;

/**
 * جسمُ طلب المتّجه.
 *
 * ── لماذا `SEMANTIC_SIMILARITY` لا `RETRIEVAL_*` ──
 * نوعا الاسترجاع مصنوعان لحالةٍ غير حالتنا: سؤالٌ قصير يُبحث به في
 * مستنداتٍ طويلة، فيُحسب متّجه السؤال بطريقةٍ ومتّجه المستند بأخرى.
 * وهنا الطرفان سؤالان، والقياسُ بينهما يجب أن يكون متناظراً — ولو
 * حُسب المحفوظ «مستنداً» والوارد «سؤالاً» لاختلف الفضاءان وخرجت نسبةٌ
 * أقلَّ من الحقيقة، فتُفلت أسئلةٌ متطابقةُ المعنى من العتبة.
 */
export function embeddingRequest(text: string): Record<string, unknown> {
  return {
    model: `models/${EMBEDDING_MODEL}`,
    content: { parts: [{ text }] },
    taskType: "SEMANTIC_SIMILARITY",
  };
}

/**
 * المتّجهُ من جواب الخدمة، أو `null` إن لم يكن متّجهاً صالحاً.
 *
 * التحقّقُ صارم: مقاسٌ مختلف، أو رقمٌ غيرُ منتهٍ، أو متّجهٌ أصفارٌ
 * كلُّه — كلُّها تُردّ. ومتّجهٌ معطوبٌ يُخزَّن أسوأ من متّجهٍ لا يُخزَّن:
 * الثاني يعني استدعاءً ثانياً، والأول يعني إجابةً تُعاد على سؤالٍ لا
 * يشبهها ولا يُعرف لماذا.
 */
export function parseEmbedding(payload: unknown): number[] | null {
  const values = (payload as any)?.embedding?.values;
  if (!Array.isArray(values) || values.length !== EMBEDDING_DIMENSIONS) {
    return null;
  }
  const vector: number[] = [];
  let magnitude = 0;
  for (const value of values) {
    const number = Number(value);
    if (!Number.isFinite(number)) return null;
    vector.push(number);
    magnitude += number * number;
  }
  // متّجهٌ طولُه صفر لا اتجاه له، ومسافةُ الجيب إليه غير معرَّفة —
  // فتُخرج القاعدةُ عليه نتائجَ لا معنى لها بدل أن تخطئ صراحةً.
  return magnitude > 0 ? vector : null;
}

/**
 * متّجهُ هذا السؤال، أو `null`.
 *
 * كلُّ تعذّرٍ يعود بـ`null`: المتّجه تسريعٌ لا شرط. ومفتاحٌ غائب، أو
 * نموذجٌ لم يُفعَّل في المشروع، أو شبكةٌ بطيئة — كلُّها تعني أن يُستدعى
 * النموذجُ التوليدي كما كان، لا أن يُحرم الطفل من جواب.
 */
export async function embedQuestion(text: string): Promise<number[] | null> {
  const question = text.trim();
  if (!question) return null;
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) return null;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), EMBEDDING_TIMEOUT_MS);
  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${EMBEDDING_MODEL}:embedContent?key=${encodeURIComponent(apiKey)}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(embeddingRequest(question)),
        signal: controller.signal,
      },
    );
    if (!response.ok) {
      // الرمزُ والنصّ معاً: ٤٠٣ تعني نموذجاً غيرَ مفعَّل في المشروع،
      // و٤٢٩ حدَّ استهلاك. وصامتٌ واحدٌ لكلٍّ منهما يجعل المتّجهات تبدو
      // كأنها لا تعمل بلا سببٍ يُقرأ.
      logger.warn(
        { status: response.status, detail: (await response.text()).slice(0, 200) },
        "[embed] refused",
      );
      return null;
    }
    const vector = parseEmbedding(await response.json());
    if (!vector) logger.warn("[embed] response was not a usable vector");
    return vector;
  } catch (error) {
    logger.warn({ err: error }, "[embed] failed");
    return null;
  } finally {
    clearTimeout(timer);
  }
}
