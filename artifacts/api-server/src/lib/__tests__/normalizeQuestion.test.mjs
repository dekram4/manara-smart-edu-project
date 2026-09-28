/**
 * اختبارات تطبيع السؤال وشرطِ المقادير.
 *
 * ── ما يُختبر هنا ──
 * قاعدتان متعاكستان يحرسهما ملفٌّ واحد لأنهما تتنازعان الحدَّ نفسه:
 *
 *   ١. سؤالان اتّحد معناهما واختلف لفظُهما يصيران مفتاحاً واحداً — وإلا
 *      استُدعي النموذجُ مرّتين وخُصم من الطفل الثاني ثمنُ جوابٍ محفوظ.
 *   ٢. مسألتان اتّحد لفظُهما واختلف رقمٌ فيهما لا تلتقيان أبداً — وإلا
 *      قرأ الطفلُ جواباً صحيحاً عن مسألةٍ ليست مسألته.
 *
 * والأولى تدفع نحو الجمع، والثانية نحو الفصل. فكلُّ توسيعٍ في التطبيع
 * يُختبر هنا بالاثنتين معاً، لا بالأولى وحدها.
 *
 * التشغيل:
 *   npm run build && node --test src/lib/__tests__/normalizeQuestion.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";

const quotaTarget = process.env.QUOTA_MODULE ?? "../../../dist/lib/aiQuota.mjs";
const mathTarget = process.env.MATH_MODULE ?? "../../../dist/lib/questionMath.mjs";
let quota;
let math;
try {
  quota = await import(quotaTarget);
  math = await import(mathTarget);
} catch (error) {
  throw new Error(
    `تعذّر استيراد وحدات dist — شغّل npm run build أولاً. (${error?.message ?? error})`,
  );
}

const {
  NEVER_DROP,
  cacheKey,
  normalizeQuestion,
  questionSimilarity,
  questionTokens,
} = quota;
const { isMathQuestion, mathNumbers, mathUnits, sameQuantities } = math;

/** هل يقع السؤالان على مفتاحٍ واحد في الدرس نفسه؟ */
const sameKey = (a, b) => cacheKey("lesson-1", a) === cacheKey("lesson-1", b);

// ─────────────────────────────────────────────────────────────────────
// ١ ── الأسئلة العامة: ما اتّحد معناه يجتمع.
// ─────────────────────────────────────────────────────────────────────

test("«ما هي» و«ما المقصود بـ» بابان إلى سؤالٍ واحد", () => {
  // العطبُ المُبلَّغ بعينه: هذان كانا مفتاحين، فيُستدعى Gemini مرّتين.
  assert.ok(sameKey("ما هي البلاستيدات", "ما المقصود بالبلاستيدات"));
  assert.equal(normalizeQuestion("ما المقصود بالبلاستيدات"), "البلاستيدات");
});

test("وأدواتُ الاستفهام والمقدّماتُ الحشوية تسقط، عربيةً وإنجليزية", () => {
  const same = [
    ["ما هي الخلية", "الخلية"],
    ["ماهو الخلية", "عرّف الخلية"],
    ["اشرح الخلية", "وضح الخلية"],
    ["ما معنى الخلية", "ما تعريف الخلية"],
    ["what is the cell", "the cell"],
    ["define the cell", "explain the cell"],
    ["meaning of photosynthesis", "what is photosynthesis"],
  ];
  for (const [a, b] of same) {
    assert.ok(sameKey(a, b), `${a} ≠ ${b}`);
  }
});

test("والإنجليزيةُ تُوحَّد إلى الحروف الصغيرة", () => {
  assert.equal(normalizeQuestion("What Is A CELL"), "cell");
  assert.ok(sameKey("What is the Cell", "what is the cell"));
});

test("والتشكيلُ والهمزاتُ زينةُ كتابةٍ لا تُغيّر السؤال", () => {
  assert.ok(sameKey("ما هي الخَلِيَّةُ", "ما هي الخلية"));
  assert.ok(sameKey("أين تقع الخلية", "اين تقع الخلية"));
});

// ─────────────────────────────────────────────────────────────────────
// ٢ ── وما لا يُحذف: النفيُ وحروفُ الأفعال الاصطلاحية.
// ─────────────────────────────────────────────────────────────────────

test("النفيُ لا يُحذف: «يتجمد» و«لا يتجمد» سؤالان", () => {
  // «لا» كانت في قائمة الحشو، فكان القياسُ بينهما ١ — وجوابُهما نقيضان.
  assert.notEqual(
    normalizeQuestion("هل الماء يتجمد"),
    normalizeQuestion("هل الماء لا يتجمد"),
  );
  assert.ok(questionTokens("هل الماء لا يتجمد").includes("لا"));
  assert.ok(questionSimilarity("هل الماء يتجمد", "هل الماء لا يتجمد") < 1);
});

test("وكلُّ أداةِ نفيٍ محروسةٍ تبقى في كلمات القياس", () => {
  // الحرسُ مكتوبٌ في `NEVER_DROP`، وهذا يمنع أن يعود شيءٌ منه إلى الحشو
  // من غير أن يسقط اختبار.
  for (const word of NEVER_DROP) {
    assert.ok(
      questionTokens(`the water ${word} freezes هل الماء ${word} يتجمد`).includes(
        word,
      ),
      `أداةُ النفي «${word}» حُذفت من كلمات القياس`,
    );
  }
});

test("وحرفُ الفعل الاصطلاحي يبقى مقروناً بفعله", () => {
  // «turn on» و«turn off» فعلان متناقضان، وحرفُهما في قائمة الحشو —
  // فكانا يصيران «turn» و«turn».
  assert.ok(questionTokens("what does turn on mean").includes("turn_on"));
  assert.ok(questionTokens("what does turn off mean").includes("turn_off"));
  assert.ok(
    questionSimilarity("what does turn on mean", "what does turn off mean") < 1,
  );
  // و«on» وحدها حشوٌ حقيقيّ حيث لا فعلَ قبلها.
  assert.ok(!questionTokens("the book on the table").includes("on"));
});

// ─────────────────────────────────────────────────────────────────────
// ٣ ── المسائل: لا يُمسّ رقمٌ ولا رمزٌ ولا قوس.
// ─────────────────────────────────────────────────────────────────────

test("المسألةُ تُعرَف من عمليتها أو وحدتها أو عبارة طلبها", () => {
  assert.ok(isMathQuestion("احسب 5+3"));
  assert.ok(isMathQuestion("أوجد قيمة x"));
  assert.ok(isMathQuestion("solve 2x+5=10"));
  assert.ok(isMathQuestion("كم يساوي 12 ÷ 4"));
  assert.ok(isMathQuestion("طول الضلع 5 سم"));
  // ورقمٌ وحده ليس مسألة.
  assert.ok(!isMathQuestion("كم عدد قارات العالم"));
  assert.ok(!isMathQuestion("ما هي الخلية"));
});

test("والأرقامُ الهندية تُوحَّد ولا تُمسّ قيمتُها", () => {
  assert.deepEqual(mathNumbers("احسب ٥+٣"), ["5", "3"]);
  assert.deepEqual(mathNumbers("احسب 5+3"), ["5", "3"]);
  assert.ok(sameQuantities("احسب ٥+٣", "احسب 5+3"));
  assert.ok(sameKey("احسب ٥+٣", "احسب 5+3"));
});

test("والرموزُ والمتغيّراتُ والأقواسُ تبقى في المفتاح", () => {
  const key = normalizeQuestion("احسب 2×(3+4)");
  assert.ok(key.includes("("), `الأقواس سقطت: ${key}`);
  assert.ok(key.includes(")"), `الأقواس سقطت: ${key}`);
  assert.ok(key.includes("*"), `علامةُ الضرب سقطت: ${key}`);
  assert.ok(key.includes("+"), `علامةُ الجمع سقطت: ${key}`);
  // والقوسُ يُغيّر الناتج، فمسألتان لا واحدة.
  assert.ok(!sameKey("احسب 2×(3+4)", "احسب 2×3+4"));
  // والأُسُّ كذلك: ٢^٣ ثمانيةٌ لا ٢٣.
  assert.ok(normalizeQuestion("احسب 2^3").includes("^"));
  assert.ok(!sameKey("احسب 2^3", "احسب 23"));
  // والمعادلةُ تنجو بمتغيّرها وعلامتها.
  assert.equal(normalizeQuestion("solve 2x + 5 = 10"), "2x+5=10");
});

test("والفاصلةُ العشرية تبقى، ونقطةُ آخر الجملة تسقط", () => {
  assert.deepEqual(mathNumbers(normalizeQuestion("طوله 2.5 متر")), ["2.5"]);
  assert.ok(sameKey("ما هي الخلية.", "ما هي الخلية"));
  // و٢٫٥ ليست ٢٥.
  assert.ok(!sameQuantities("طوله 2.5 متر", "طوله 25 متر"));
});

test("والحذفُ في المسألة مقصورٌ على عبارة الطلب", () => {
  assert.equal(normalizeQuestion("احسب 5+3"), "5+3");
  assert.equal(normalizeQuestion("أوجد قيمة 5+3"), "5+3");
  assert.equal(normalizeQuestion("ما ناتج 5+3"), "5+3");
  assert.equal(normalizeQuestion("calculate 5+3"), "5+3");
  assert.equal(normalizeQuestion("solve 5+3"), "5+3");
  // وما ليس طلباً يبقى: «طوله» و«عرضه» شرطان من شروط المسألة.
  const key = normalizeQuestion("احسب محيط مستطيل طوله 5 وعرضه 3");
  assert.ok(key.includes("طوله"), key);
  assert.ok(key.includes("عرضه"), key);
  // وطلبٌ بلا مسألةٍ يبقى بلفظه، فلا يُطابق كلَّ فارغٍ في الدرس.
  assert.equal(normalizeQuestion("احسب"), "احسب");
  assert.notEqual(normalizeQuestion("احسب"), normalizeQuestion("حل"));
});

// ─────────────────────────────────────────────────────────────────────
// ٤ ── وشرطُ المقادير: رقمٌ واحدٌ يختلف يُلغي الذاكرة.
// ─────────────────────────────────────────────────────────────────────

test("مسألتان تختلفان في رقمٍ واحد لا تلتقيان", () => {
  const a = "احسب محيط مستطيل طوله 5 وعرضه 3";
  const b = "احسب محيط مستطيل طوله 7 وعرضه 3";
  // اللفظُ يكاد يكون واحداً — وهذا ما يجعل المطابقة خطيرة.
  assert.ok(questionSimilarity(a, b) > 0.8, "اللفظان متقاربان كما تقتضي الحالة");
  // والمقاديرُ تفصل.
  assert.ok(!sameQuantities(a, b));
  assert.ok(!sameKey(a, b));
});

test("وترتيبُ الأرقام شرطٌ: ١٢÷٤ ليست ٤÷١٢", () => {
  assert.ok(!sameQuantities("احسب 12 ÷ 4", "احسب 4 ÷ 12"));
});

test("والوحدةُ جزءٌ من المقدار: ٥ كم ليست ٥ سم", () => {
  assert.deepEqual(mathUnits("طول الطريق 5 كم"), ["كم"]);
  assert.ok(!sameQuantities("طول الطريق 5 كم", "طول الطريق 5 سم"));
  // والتاءُ المربوطة لا تصنع وحدتين.
  assert.ok(sameQuantities("زمنه 30 دقيقة", "زمنه 30 دقيقه"));
});

test("والشرطُ يمتدّ إلى ما ليس مسألةً حسابية", () => {
  // «اذكر ٣ فوائد» و«اذكر ٥ فوائد» ليسا مسألتين، وجوابُهما مختلف.
  assert.ok(!sameQuantities("اذكر 3 فوائد للماء", "اذكر 5 فوائد للماء"));
  // وما لا رقمَ فيه يمرّ بلا شرط.
  assert.ok(sameQuantities("ما هي الخلية", "عرّف الخلية"));
});

test("والمسألةُ تطابق نفسها ولو كُتبت بإصبعٍ آخر", () => {
  assert.ok(sameQuantities("احسب ٢ × ٣", "احسب 2*3"));
  assert.ok(sameQuantities("2.50 متر", "2.5 متر"));
  assert.ok(sameQuantities("05 دقيقة", "5 دقيقة"));
});
