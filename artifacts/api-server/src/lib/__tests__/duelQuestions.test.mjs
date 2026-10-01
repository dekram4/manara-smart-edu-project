/**
 * اختبارات حزمة أسئلة المبارزة.
 *
 * ── لماذا تُختبر بشدّة ──
 * الحزمةُ تُكتب مرّةً ويقرؤها الجهازان، وعليها تقوم عدالةُ المباراة. وخللٌ
 * فيها لا يرفع خطأً: سؤالٌ بموضعِ جوابٍ خارج خياراته يُخرج مباراةً لا جوابَ
 * صحيحَ فيها، وحزمةٌ تختلف بين بناءين تُخرج مباراتين لا مباراة — وكلُّ جهازٍ
 * يعمل وحده صحيحاً.
 *
 * التشغيل:
 *   npm run build && node --test src/lib/__tests__/duelQuestions.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";

const target = process.env.DUEL_QUESTIONS_MODULE ?? "../../../dist/lib/duelQuestions.mjs";
let mod;
try {
  mod = await import(target);
} catch (error) {
  throw new Error(
    `تعذّر استيراد ${target} — شغّل npm run build أولاً. (${error?.message ?? error})`,
  );
}

const {
  DUEL_PACK_MIN,
  DUEL_PACK_SIZE,
  DUEL_PACK_VERSION,
  buildDuelPack,
  packSeed,
  parseDuelPack,
} = mod;

const lessonSeeds = [
  { prompt: "الماءُ ______ عند التبريد", answer: "يتجمّد", distractors: ["يتبخّر", "يسيل", "يغلي"] },
  { prompt: "الشمسُ ______ في الشرق", answer: "تشرق", distractors: ["تغيب", "تختفي", "تنزل"] },
  { prompt: "النباتُ يحتاج ______ لينمو", answer: "الماء", distractors: ["الحجر", "الورق", "الرمل"] },
  { prompt: "عددُ أيام الأسبوع ______", answer: "سبعة", distractors: ["خمسة", "ثلاثة", "عشرة"] },
];

test("الحزمةُ عشرةُ أسئلة", () => {
  // ── والطلبُ المُبلَّغ: من ٨ إلى ١٠ ──
  const pack = buildDuelPack("duel_abc_1");
  assert.equal(pack.questions.length, DUEL_PACK_SIZE);
  assert.ok(pack.questions.length >= DUEL_PACK_MIN);
  assert.equal(pack.version, DUEL_PACK_VERSION);
});

test("والبناءُ بالمعرّف نفسه يُخرج الحزمةَ نفسها حرفاً بحرف", () => {
  // ── وهذا أصلُ عدالة المباراة ──
  // لصفٍّ قديمٍ بلا حزمةٍ يُعاد البناءُ على الجهازين قبل أن تُكتب. فلو اختلف
  // البناءان لرأى كلٌّ أسئلةً، ولا يظهر ذلك عطباً: كلُّ جهازٍ يعمل وحده.
  const first = buildDuelPack("duel_xyz_9", lessonSeeds);
  const second = buildDuelPack("duel_xyz_9", lessonSeeds);
  assert.deepEqual(first.questions, second.questions);
});

test("ومباراةٌ أخرى حزمتُها أخرى", () => {
  // وإلا لُعبت الأسئلةُ نفسها في كل مباراةٍ فصارت حفظاً لمواضع الأزرار.
  const a = buildDuelPack("duel_one", lessonSeeds);
  const b = buildDuelPack("duel_two", lessonSeeds);
  assert.notDeepEqual(a.questions, b.questions);
});

test("وكلُّ سؤالٍ جوابُه داخل خياراته", () => {
  // موضعٌ خارج الخيارات يُخرج مباراةً لا جوابَ صحيحَ فيها.
  for (const id of ["duel_a", "duel_b", "duel_c", "duel_d"]) {
    for (const question of buildDuelPack(id, lessonSeeds).questions) {
      assert.ok(question.options.length >= 2, question.id);
      assert.ok(
        question.answerAt >= 0 && question.answerAt < question.options.length,
        `${question.id}: ${question.answerAt} من ${question.options.length}`,
      );
      assert.ok(question.prompt.length > 0, question.id);
    }
  }
});

test("ولا يتكرّر سؤالٌ في الحزمة الواحدة", () => {
  // سؤالٌ مرّتين في عشرةٍ يُفقد المباراةَ سؤالاً، ويُقرأ عطباً في الحال.
  for (const id of ["duel_a", "duel_b", "duel_c", "duel_d", "duel_e"]) {
    const pack = buildDuelPack(id, lessonSeeds);
    const ids = pack.questions.map((question) => question.id);
    assert.equal(new Set(ids).size, ids.length, id);
  }
});

test("ولا تتكرّر خيارات السؤال", () => {
  for (const question of buildDuelPack("duel_dupes", lessonSeeds).questions) {
    assert.equal(
      new Set(question.options).size,
      question.options.length,
      question.id,
    );
  }
});

test("والأبوابُ متنوّعةٌ لا بابٌ واحد", () => {
  // ── والطلبُ: فكُّ الارتباط بنصوص المذاكرة ──
  // حزمةٌ كلُّها من بابٍ واحدٍ تُقرأ امتحاناً لا مبارزة.
  const categories = new Set(
    buildDuelPack("duel_mix", lessonSeeds).questions.map((q) => q.category),
  );
  assert.ok(categories.size >= 3, [...categories].join(","));
});

test("وأسئلةُ الدرس تُخلط ولا تُغرق الحزمة", () => {
  // إلى الثلث: فتبقى المبارزةُ متّصلةً بما يدرسه ولا تُسجن فيه.
  const pack = buildDuelPack("duel_lesson", lessonSeeds);
  const fromLesson = pack.questions.filter((q) => q.category === "lesson");
  assert.ok(fromLesson.length >= 1, "لا سؤالَ من الدرس");
  assert.ok(
    fromLesson.length <= Math.floor(DUEL_PACK_SIZE / 3),
    `${fromLesson.length} من الدرس`,
  );
});

test("ودرسٌ بلا بنكٍ يُبنى من البنك المكتوب وحده", () => {
  // بطاقةٌ تُفتح على درسٍ لم يُولَّد بنكُه بعد: مباراةٌ كاملةٌ لا شاشةٌ فارغة.
  const pack = buildDuelPack("duel_nolesson", []);
  assert.equal(pack.questions.length, DUEL_PACK_SIZE);
  assert.equal(pack.questions.filter((q) => q.category === "lesson").length, 0);
});

test("وجولةُ درسٍ ناقصةٌ تُترك لا تُقبل", () => {
  // جولةٌ بمشتّتٍ واحدٍ لا تصير سؤالاً من أربعةِ خيارات.
  const pack = buildDuelPack("duel_thin", [
    { prompt: "ناقصة", answer: "جواب", distractors: ["واحد"] },
    { prompt: "", answer: "جواب", distractors: ["أ", "ب", "ج"] },
  ]);
  assert.equal(pack.questions.filter((q) => q.category === "lesson").length, 0);
  assert.equal(pack.questions.length, DUEL_PACK_SIZE);
});

// ── قراءةُ ما خُزّن ──

test("حزمةٌ سليمةٌ تُقرأ كما كُتبت", () => {
  const pack = buildDuelPack("duel_round_trip", lessonSeeds);
  const read = parseDuelPack(JSON.parse(JSON.stringify(pack)));
  assert.ok(read);
  assert.deepEqual(read.questions, pack.questions);
});

test("وصيغةٌ أقدمُ تُردّ فتُعاد الحزمة", () => {
  // قراءةُ حزمةٍ بقواعدَ تغيّرت تُخرج مباراةً لا تُلعب.
  const pack = buildDuelPack("duel_old", lessonSeeds);
  assert.equal(parseDuelPack({ ...pack, version: DUEL_PACK_VERSION + 1 }), null);
  assert.equal(parseDuelPack({ ...pack, version: 0 }), null);
});

test("وما ليس حزمةً يُردّ ولا يرفع", () => {
  for (const bad of [null, undefined, 0, "", "حزمة", [], {}, { version: 1 }]) {
    assert.equal(parseDuelPack(bad), null, JSON.stringify(bad) ?? "undefined");
  }
});

test("وحزمةٌ نقصت أسئلتُها عن الحدّ تُردّ", () => {
  // ── والردُّ لا القبولُ بما بقي ──
  // مباراةٌ بثلاثة أسئلةٍ ليست المباراةَ التي لعبها الطرفُ الآخر بعشرة.
  const pack = buildDuelPack("duel_short", lessonSeeds);
  assert.equal(
    parseDuelPack({ ...pack, questions: pack.questions.slice(0, DUEL_PACK_MIN - 1) }),
    null,
  );
  // وما بلغ الحدَّ يُقبل.
  assert.ok(parseDuelPack({ ...pack, questions: pack.questions.slice(0, DUEL_PACK_MIN) }));
});

test("وسؤالٌ معطوبٌ يُسقَط ولا يُسقط الحزمة", () => {
  const pack = buildDuelPack("duel_broken", lessonSeeds);
  const questions = JSON.parse(JSON.stringify(pack.questions));
  questions[0].answerAt = 99;
  questions[1].options = [];
  const read = parseDuelPack({ ...pack, questions });
  assert.ok(read, "الحزمةُ سقطت كلُّها");
  assert.equal(read.questions.length, pack.questions.length - 2);
});

test("والبذرةُ ثابتةٌ بحسابٍ مكتوب", () => {
  // ── ولا يُتّخذ تهشيرُ المنصّة بذرةً ──
  // عليها تُبنى حزمةٌ تُخزَّن وتُقرأ، فتغيّرُها بين إصدارين يُفسد الأصلَ كلَّه.
  assert.equal(packSeed("duel_abc"), packSeed("duel_abc"));
  assert.notEqual(packSeed("duel_abc"), packSeed("duel_abd"));
  assert.equal(packSeed("a"), 7 * 31 + "a".charCodeAt(0));
  assert.ok(packSeed("") >= 0);
  assert.ok(packSeed("مباراةٌ بالعربية") >= 0);
});
