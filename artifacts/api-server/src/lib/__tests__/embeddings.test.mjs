/**
 * اختبارات متّجهات الأسئلة.
 *
 * ── ما يُختبر وما لا يُختبر ──
 * النداءُ الشبكيّ لا يُختبر هنا: يحتاج مفتاحاً ويُقاس بالمال. والمُختبَرُ
 * حيث يقع الخطأ فعلاً — بناءُ الطلب، والتحقّقُ من المتّجه الوارد. ومتّجهٌ
 * معطوبٌ يُخزَّن أسوأ من متّجهٍ لا يُخزَّن: الثاني استدعاءٌ ثانٍ، والأول
 * إجابةٌ تُعاد على سؤالٍ لا يشبهها ولا يُعرف لماذا.
 *
 * التشغيل:
 *   node --test src/lib/__tests__/embeddings.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const target = process.env.EMBEDDINGS_MODULE ?? "../../../dist/lib/embeddings.mjs";
let mod;
try {
  mod = await import(target);
} catch (error) {
  // يفشل ولا يُخطّى.
  //
  // كان هنا `process.exit(0)` ورسالةٌ تُطبع، فكان الملفُّ يخرج أخضرَ
  // وهو لم يُشغّل اختباراً واحداً. وهكذا مرّت الاختباراتُ كلُّها بلا أن
  // تعمل: الاستيرادُ يفشل، والتخطّي يكتمه، والتقريرُ يقول «pass» — فلا
  // يحرس شيءٌ مما جاءت تحرسه.
  //
  // وبناءٌ ناقصٌ خطأٌ في التشغيل يُقال صراحةً، لا حالةٌ تُتَخطّى بصمت.
  throw new Error(
    `تعذّر استيراد ${target} — شغّل npm run build أولاً. (${error?.message ?? error})`,
  );
}

const {
  EMBEDDING_DIMENSIONS,
  EMBEDDING_MODEL,
  VECTOR_THRESHOLD,
  embeddingRequest,
  parseEmbedding,
} = mod;

/** متّجهٌ صالحٌ بالمقاس المطلوب. */
const vectorOf = (fill = 0.1) =>
  Array.from({ length: EMBEDDING_DIMENSIONS }, () => fill);

test("الطلبُ يحمل النموذج والنصّ ونوعَ المهمّة", () => {
  const body = embeddingRequest("ما وظيفة الخلية");
  assert.equal(body.model, `models/${EMBEDDING_MODEL}`);
  assert.deepEqual(body.content, { parts: [{ text: "ما وظيفة الخلية" }] });
  // متناظرٌ لا استرجاعيّ: الطرفان سؤالان، ولو حُسب المحفوظ «مستنداً»
  // والوارد «سؤالاً» لاختلف الفضاءان وخرجت نسبةٌ أقلَّ من الحقيقة.
  assert.equal(body.taskType, "SEMANTIC_SIMILARITY");
});

test("العتبةُ هي نفسها المكتوبة في دالّة القاعدة", () => {
  // العتبةُ في مكانين — هنا وفي `match_qa_cache` — ويُرسلها الخادم مع
  // كل نداء، فلا تفترقان.
  //
  // وتُقرأ من الملفّ لا تُكتب رقماً ثالثاً: رقمٌ مكتوبٌ هنا يحرس أن
  // القيمة لم تتغيّر، ولا يحرس أن الاثنتين واحدة — وهي المشكلةُ التي
  // جاء هذا الاختبار لها. فيُقرأ الـSQL ويُقارَن به.
  const sql = readFileSync(
    new URL("../../../scripts/ai-qa-cache-vectors.sql", import.meta.url),
    "utf8",
  );
  const declared = sql.match(/match_threshold\s+double\s+precision\s+default\s+([\d.]+)/);
  assert.ok(declared, "لم يُعثر على العتبة في ai-qa-cache-vectors.sql");
  assert.equal(VECTOR_THRESHOLD, Number(declared[1]));
  // ومخفوضةٌ عن عتبة المقياس اللفظي: المتّجهُ يقيس معنىً لا كلمات،
  // وسؤالان متطابقا المعنى مختلفا اللفظ يقعان دون ٠٫٨٨ فيه.
  assert.equal(VECTOR_THRESHOLD, 0.78);
});

test("المتّجهُ الصالح يُقرأ كما هو", () => {
  const values = vectorOf(0.25);
  const parsed = parseEmbedding({ embedding: { values } });
  assert.equal(parsed?.length, EMBEDDING_DIMENSIONS);
  assert.equal(parsed?.[0], 0.25);
});

test("والمقاسُ المختلف يُردّ", () => {
  // عمودُ القاعدة `vector(768)`: متّجهٌ بمقاسٍ آخر يُرفض هناك صراحةً،
  // فيُمسَك هنا قبل أن يُرسَل.
  assert.equal(parseEmbedding({ embedding: { values: [0.1, 0.2] } }), null);
  assert.equal(
    parseEmbedding({ embedding: { values: vectorOf().concat(0.1) } }),
    null,
  );
});

test("والرقمُ غيرُ المنتهي يُردّ", () => {
  const broken = vectorOf();
  broken[7] = Number.NaN;
  assert.equal(parseEmbedding({ embedding: { values: broken } }), null);

  const infinite = vectorOf();
  infinite[3] = Number.POSITIVE_INFINITY;
  assert.equal(parseEmbedding({ embedding: { values: infinite } }), null);
});

test("والمتّجهُ الأصفارُ كلُّه يُردّ", () => {
  // طولُه صفرٌ فلا اتجاه له، ومسافةُ الجيب إليه غير معرَّفة — فتُخرج
  // القاعدةُ عليه نتائجَ لا معنى لها بدل أن تخطئ صراحةً.
  assert.equal(parseEmbedding({ embedding: { values: vectorOf(0) } }), null);
});

test("والجوابُ المشوَّه لا يُسقط الخدمة", () => {
  // كلُّ هذه تعني «لا متّجه»، وهو يعني استدعاءَ النموذج التوليدي كما
  // كان — لا شاشةً تنهار.
  for (const payload of [
    null,
    undefined,
    {},
    { embedding: null },
    { embedding: {} },
    { embedding: { values: "nonsense" } },
    { error: { message: "quota" } },
    "not json at all",
  ]) {
    assert.equal(parseEmbedding(payload), null, JSON.stringify(payload ?? null));
  }
});
