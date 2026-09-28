/**
 * اختبارات ترشيد استهلاك الذكاء الاصطناعي.
 *
 * التشغيل:
 *   npm run build && node --test src/lib/__tests__/aiQuota.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";

const target = process.env.QUOTA_MODULE ?? "../../../dist/lib/aiQuota.mjs";
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
  FREE_DAILY_QUESTIONS,
  GEM_PRICE,
  SIMILARITY_THRESHOLD,
  bestSimilarKey,
  cacheKey,
  chargeFor,
  dayStamp,
  normalizeQuestion,
  questionOfKey,
  questionSimilarity,
  questionTokens,
  readQuota,
  snapshotOf,
  spend,
} = mod;

test("ترتيبُ الكلمات لا يصنع سؤالاً ثانياً", () => {
  // «الخلية ماهي» يقولها طفلٌ ويقول آخر «ماهي الخلية»، والسؤال واحد.
  assert.deepEqual(questionTokens("ماهي الخلية"), questionTokens("الخلية ماهي"));
  assert.equal(questionSimilarity("ماهي الخلية", "الخلية ماهي"), 1);
  assert.equal(
    questionSimilarity("ما الفرق بين الخلية والنواة", "الفرق بين النواة والخلية"),
    1,
  );
});

test("وخطأُ حرفٍ من قارئ الصورة لا يصنعه كذلك", () => {
  // «ماهلي» نقطةٌ في غير موضعها، لا سؤالٌ آخر.
  assert.equal(questionSimilarity("ماهي الخلية", "ماهلي الخليه"), 1);
  assert.ok(questionSimilarity("وظيفة النواة", "وظيفه النواه") >= SIMILARITY_THRESHOLD);
});

test("والكلماتُ القصيرةُ المختلفة لا تُخلط", () => {
  // حرفٌ واحد بين «شمس» و«شمع»، وهما شيئان. فالسماحُ لا يبدأ إلا مع
  // الكلمات الأطول، وإلا صار التسامحُ خلطاً.
  assert.ok(questionSimilarity("ما الشمس", "ما القمر") < SIMILARITY_THRESHOLD);
  assert.ok(questionSimilarity("عدد الخلايا", "عدد الاوراق") < SIMILARITY_THRESHOLD);
});

test("والكلمةُ الزائدة تُنقص التشابه فلا يُجاب سؤالٌ أوسع", () => {
  // «الخلية» ليست «الخلية النباتية والحيوانية».
  assert.ok(
    questionSimilarity("ما الخلية", "ما الخلية النباتية والحيوانية") <
      SIMILARITY_THRESHOLD,
  );
});

test("وأدواتُ السؤال لا تُحسب في القياس", () => {
  assert.equal(questionTokens("اشرح لي وظيفة النواة من فضلك").join(" "), "النواه وظيفه");
  // وسؤالٌ كلُّه أدواتٌ يُقاس بكلماته لا يصير فارغاً يطابق كلَّ شيء.
  assert.ok(questionTokens("هل هو كذلك").length > 0);
});

test("المفتاحُ الأقربُ يُختار من مفاتيح الدرس", () => {
  const stored = [
    cacheKey("g4sci_1_1", "ما هي الخلية؟"),
    cacheKey("g4sci_1_1", "ما وظيفة النواة"),
    cacheKey("g4sci_1_1", "عدد الكروموسومات"),
  ];
  const hit = bestSimilarKey(stored, "الخليه ماهلي");
  assert.ok(hit, "كان يجب أن يُصاب مفتاح الخلية");
  assert.equal(questionOfKey(hit.key), "الخليه");

  // وسؤالٌ لا يشبه شيئاً لا يُصيب شيئاً — ولا تُعاد إجابةُ غيره.
  assert.equal(bestSimilarKey(stored, "ما الجهاز الهضمي"), null);
});

test("ومفتاحُ درسٍ آخر لا يبلغ الطالب", () => {
  // الفرزُ بالدرس يجري في الاستعلام، وهذه تحرس ما بعده: مفتاحٌ ينتمي
  // لدرسٍ آخر لو وصل القائمة يبقى معرّفُه في نصّه.
  assert.equal(questionOfKey("g4sci_1_2::الخليه"), "الخليه");
  assert.equal(questionOfKey("no-separator"), "");
});

test("صِيَغ السؤال الواحد كلّها مفتاحٌ واحد", () => {
  // ما يصل من الكتابة ومن الصوت ومن قراءة الصورة — كلّه صياغاتٌ لسؤال
  // واحد، ولولا التطبيع لسُئل النموذج عن الشيء نفسه مرّةً لكل صياغة.
  //
  // و«الخلية» وحدها في القائمة: هكذا تصل من الصوت غالباً، فمحرّك
  // التعرّف يسمع الكلمة ويسقط أداة الاستفهام قبلها.
  const same = [
    "ما هي الخلية؟",
    "ماهي الخلية",
    "ما هو الخلية",
    "ما هى الخليه",
    "مَا هِيَ الخَلِيَّةُ؟",
    "  ما   هي   الخلية  !! ",
    "ما هي الخلية؟؟ 🤔",
    "ما الخلية",
    "عرّف الخلية",
    "اشرح الخلية",
    "الخلية",
  ].map(normalizeQuestion);
  assert.equal(new Set(same).size, 1, JSON.stringify([...new Set(same)]));
});

test("وصِيَغُ السؤال الإنجليزي كذلك", () => {
  const same = [
    "What is the cell?",
    "what is a cell",
    "What are the cells",
    "Define the cell.",
    "explain cell",
    "  CELL  ",
  ].map(normalizeQuestion);
  // «cells» تبقى جمعاً — لا تُجذَّر الكلماتُ هنا، فذلك تخمينٌ لغويّ
  // يُذيب فروقاً حقيقية.
  assert.equal(
    new Set(same).size,
    2,
    JSON.stringify([...new Set(same)]),
  );
  assert.equal(normalizeQuestion("What is the cell?"), "cell");
});

test("الحسابُ لا يفقد عملياته — وهذا أخطر ما في التطبيع", () => {
  // ولولا ذلك لصار «٢+٣» و«٢-٣» مفتاحاً واحداً، فيُجاب السائلُ عن
  // الطرح بجواب الجمع. وذاكرةٌ تُصيب بثقةٍ في السؤال الخطأ أسوأ من
  // ذاكرةٍ لا تُصيب.
  assert.notEqual(normalizeQuestion("٢ + ٣"), normalizeQuestion("٢ - ٣"));
  assert.notEqual(normalizeQuestion("١٢ ÷ ٤"), normalizeQuestion("١٢ × ٤"));
  assert.equal(normalizeQuestion("٢ + ٣"), "2+3");
});

test("المعادلةُ الواحدة بكتابتين مفتاحٌ واحد", () => {
  assert.equal(normalizeQuestion("2 x + 5 = 10"), "2x+5=10");
  assert.equal(normalizeQuestion("2x+5=10"), "2x+5=10");
  // والضربُ بأيّ رمزٍ كُتب.
  assert.equal(normalizeQuestion("٦ × ٧"), "6*7");
  assert.equal(normalizeQuestion("6 x 7"), "6*7");
  assert.equal(normalizeQuestion("6*7"), "6*7");
  // والقسمةُ كذلك.
  assert.equal(normalizeQuestion("١٢ ÷ ٤"), "12/4");
  assert.equal(normalizeQuestion("12 / 4"), "12/4");
});

test("الترقيم والرموز والإيموجي لا تصنع سؤالاً ثانياً", () => {
  assert.equal(
    normalizeQuestion("اشرح الجمع، من فضلك."),
    normalizeQuestion("اشرح الجمع من فضلك"),
  );
  assert.equal(normalizeQuestion("الناتج ☢ ★ ؟"), "الناتج");
});

test("الأرقام العربية-الهندية تُطابق نظيرتها", () => {
  assert.equal(normalizeQuestion("احسب ٥ + ٣"), normalizeQuestion("احسب 5 + 3"));
});

test("وسؤالان مختلفان يبقيان مختلفين", () => {
  // التطبيع لا يجوز أن يُذيب الفروق: «ما الخلية» و«ما النواة» سؤالان.
  assert.notEqual(normalizeQuestion("ما الخلية"), normalizeQuestion("ما النواة"));
  assert.notEqual(normalizeQuestion("متى نستعمل الضرب"), normalizeQuestion("متى نستعمل القسمة"));
});

test("السؤال نفسه بهمزتين مختلفتين مفتاحٌ واحد", () => {
  // ولولا ذلك لسُئل النموذج مرّتين عن الشيء نفسه، وهو ما جاءت الذاكرة
  // لتمنعه.
  assert.equal(
    normalizeQuestion("ما هي الخلية؟"),
    normalizeQuestion("ما هى الخليه"),
  );
  assert.equal(normalizeQuestion("  ما   الفكرة ؟ "), "الفكره");
});

test("وأداةُ الاستفهام وحدها لا تصير مفتاحاً", () => {
  // سؤالٌ لا شيء فيه سوى الأداة يعود فارغاً، فلا تُحفظ إجابةٌ تحت
  // مفتاحٍ يطابق كلَّ سؤالٍ ناقص.
  assert.equal(normalizeQuestion("ما هي؟"), "");
  assert.equal(normalizeQuestion("what is"), "");
  assert.equal(normalizeQuestion("؟؟؟"), "");
});

test("الدرس جزءٌ من المفتاح", () => {
  // «ما الفكرة الرئيسية؟» سؤالٌ صالحٌ لكل درس وإجابتُه تختلف.
  assert.notEqual(cacheKey("g4sci_1_1", "ما الفكرة؟"), cacheKey("g4sci_1_2", "ما الفكرة؟"));
  assert.equal(cacheKey("g4sci_1_1", "ما الفكرة؟"), cacheKey("g4sci_1_1", "ما الفكره"));
});

test("يومٌ جديد يعني عدّاداً جديداً بلا تصفيرٍ مجدول", () => {
  const stale = { day: "2020-01-01", used: 9, gemsSpent: 40 };
  const fresh = readQuota(stale, "2026-09-28");
  assert.equal(fresh.used, 0);
  assert.equal(fresh.gemsSpent, 0);
  assert.equal(fresh.day, "2026-09-28");

  const same = readQuota({ day: "2026-09-28", used: 3, gemsSpent: 0 }, "2026-09-28");
  assert.equal(same.used, 3);
});

test("قيمةٌ معطوبة تُقرأ صفراً لا تُسقط الحساب", () => {
  const quota = readQuota({ day: dayStamp(), used: -5, gemsSpent: "xx" });
  assert.equal(quota.used, 0);
  assert.equal(quota.gemsSpent, 0);
  assert.equal(readQuota(null).used, 0);
  assert.equal(readQuota("nonsense").used, 0);
});

test("المجاني يُستهلك أولاً بلا جواهر", () => {
  let quota = readQuota(null);
  for (let index = 0; index < FREE_DAILY_QUESTIONS; index += 1) {
    const verdict = chargeFor(quota, 0);
    assert.equal(verdict.allowed, true, `السؤال ${index + 1}`);
    assert.equal(verdict.gemsCharged, 0);
    assert.equal(verdict.remainingFree, FREE_DAILY_QUESTIONS - index - 1);
    quota = spend(quota, verdict);
  }
  assert.equal(quota.used, FREE_DAILY_QUESTIONS);
});

test("بعد النفاد يُدفع بالجواهر", () => {
  const quota = { day: dayStamp(), used: FREE_DAILY_QUESTIONS, gemsSpent: 0 };
  const verdict = chargeFor(quota, 20);
  assert.equal(verdict.allowed, true);
  assert.equal(verdict.gemsCharged, GEM_PRICE);
  const after = spend(quota, verdict);
  assert.equal(after.gemsSpent, GEM_PRICE);
  assert.equal(after.used, FREE_DAILY_QUESTIONS + 1);
});

test("رصيدٌ دون الثمن يمنع السؤال ويقول لماذا", () => {
  const quota = { day: dayStamp(), used: FREE_DAILY_QUESTIONS, gemsSpent: 0 };
  const verdict = chargeFor(quota, GEM_PRICE - 1);
  assert.equal(verdict.allowed, false);
  assert.equal(verdict.reason, "no_gems");
  assert.equal(verdict.gemsCharged, 0);
  // ولا يُحسب على الطفل سؤالٌ مُنع.
  assert.deepEqual(spend(quota, verdict), quota);
});

test("ما يُعرض في الشات يصف الحال بدقّة", () => {
  const fresh = snapshotOf(readQuota(null), 0);
  assert.equal(fresh.remainingFree, FREE_DAILY_QUESTIONS);
  assert.equal(fresh.canAsk, true);
  assert.equal(fresh.gemPrice, GEM_PRICE);

  const spent = { day: dayStamp(), used: FREE_DAILY_QUESTIONS, gemsSpent: 0 };
  assert.equal(snapshotOf(spent, 0).canAsk, false);
  assert.equal(snapshotOf(spent, GEM_PRICE).canAsk, true);
  assert.equal(snapshotOf(spent, 99).remainingFree, 0);
});

test("اليوم يُقرأ من ساعة الخادم بصيغةٍ ثابتة", () => {
  assert.match(dayStamp(new Date("2026-09-28T23:59:59Z")), /^2026-09-28$/);
});
