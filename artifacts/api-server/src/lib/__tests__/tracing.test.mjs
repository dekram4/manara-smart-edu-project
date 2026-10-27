/**
 * اختبارات لعبة «تتبّع واكتب» في بطاقة المذاكرة — حصراً لروضة منارة المعرفة.
 *
 * التشغيل:
 *   npm run build && node --test src/lib/__tests__/tracing.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";

const tracing = await import(process.env.TRACING_MODULE ?? "../../../dist/lib/tracing.mjs");
const studyGames = await import(process.env.STUDY_GAMES_MODULE ?? "../../../dist/lib/studyGames.mjs");

const {
  withTracingGame,
  alphabetGame,
  alphabetSetOf,
  alphabetItems,
  tracingSetFor,
  isKindergartenGrade,
  arabicNumberWords,
  englishNumberWords,
  KINDERGARTEN_GRADE,
  TRACING_REWARD,
  tracingRewardKey,
} = tracing;
const { parseStudyGameActivityId, GAME_TYPES, STUDY_GAMES_SCHEMA } = studyGames;

const texts = (items) => items.map((item) => item.text);
const KG = KINDERGARTEN_GRADE;

// ── متى تظهر: الروضةُ وموادُّها الأربع معاً، وحصراً ─────────────────────

test("صفُّ الروضة يُعرف بأيّ همزةٍ وتاءٍ ومسافةٍ كُتب، وغيرُه لا", () => {
  assert.ok(isKindergartenGrade("روضة منارة المعرفة"));
  assert.ok(isKindergartenGrade("روضه مناره المعرفه"));
  assert.ok(isKindergartenGrade("  روضة  منارة المعرفة "));
  assert.ok(!isKindergartenGrade("الصف الأول"));
  assert.ok(!isKindergartenGrade("الصف الرابع"));
  assert.ok(!isKindergartenGrade(""));
});

test("التتبّعُ للروضة وموادّها الأربع معاً، ولا شيءَ لغيرهما", () => {
  assert.equal(tracingSetFor({ grade: KG, subject: "الحروف العربية" }), "arabic_letters");
  assert.equal(tracingSetFor({ grade: KG, subject: "الحروف الإنجليزية" }), "english_letters");
  assert.equal(tracingSetFor({ grade: KG, subject: "الارقام العربية" }), "arabic_digits");
  assert.equal(tracingSetFor({ grade: KG, subject: "الارقام الانجليزية" }), "english_digits");
  // صفٌّ آخر بالمادّة نفسها: لا.
  assert.equal(tracingSetFor({ grade: "الصف الأول", subject: "الحروف العربية" }), null);
  assert.equal(tracingSetFor({ grade: "", subject: "الأرقام العربية" }), null);
  // الروضةُ بمادّةٍ أخرى: لا.
  assert.equal(tracingSetFor({ grade: KG, subject: "العلوم" }), null);
  assert.equal(tracingSetFor({ grade: KG, subject: "اللغة العربية" }), null);
  assert.equal(alphabetGame({ title: "", subject: "الحروف العربية", grade: "الصف الثالث" }), null);
});

test("موادُّ الروضة الأربع تُعرف بأيّ همزةٍ أو تاءٍ كُتبت", () => {
  assert.equal(alphabetSetOf("الحروف العربيه"), "arabic_letters");
  assert.equal(alphabetSetOf("الحروف الانجليزية"), "english_letters");
  assert.equal(alphabetSetOf("الأرقام العربية"), "arabic_digits");
  assert.equal(alphabetSetOf("الأرقام الإنجليزية"), "english_digits");
  assert.equal(alphabetSetOf("الرياضيات"), null);
});

// ── ما فيها ──────────────────────────────────────────────────────────────

test("الحروفُ كاملةً، ومع كلٍّ اسمُه للنطق", () => {
  const arabic = alphabetItems("arabic_letters");
  assert.equal(arabic.length, 28);
  assert.deepEqual([arabic[1].text, arabic[1].speech], ["ب", "باء"]);
  assert.equal(arabic.at(-1).text, "ي");
  assert.ok(arabic.every((item) => item.kind === "letter" && item.lang === "ar" && item.speech));

  const english = alphabetItems("english_letters");
  assert.equal(english.length, 26);
  assert.deepEqual([english[0].text, english[0].speech], ["Aa", "A"]);
  assert.equal(english.at(-1).text, "Zz");
});

test("الأعدادُ من ٠ إلى ١٠٠ بالنظامين، وتُنطق كلماتٍ بلغتها", () => {
  const arabic = alphabetItems("arabic_digits");
  assert.equal(arabic.length, 101);
  assert.deepEqual(texts(arabic).slice(0, 3), ["٠", "١", "٢"]);
  assert.deepEqual([arabic[25].text, arabic[25].speech], ["٢٥", "خمسة وعشرون"]);
  assert.deepEqual([arabic.at(-1).text, arabic.at(-1).speech], ["١٠٠", "مئة"]);
  const english = alphabetItems("english_digits");
  assert.equal(english.length, 101);
  assert.deepEqual([english[42].text, english[42].speech], ["42", "forty two"]);
  assert.equal(english.at(-1).speech, "one hundred");
});

test("كلماتُ الأعداد العربية والإنجليزية", () => {
  const ar = { 0: "صفر", 1: "واحد", 2: "اثنان", 10: "عشرة", 11: "أحد عشر", 12: "اثنا عشر",
    19: "تسعة عشر", 20: "عشرون", 21: "واحد وعشرون", 58: "ثمانية وخمسون", 90: "تسعون",
    99: "تسعة وتسعون", 100: "مئة" };
  for (const [n, words] of Object.entries(ar)) assert.equal(arabicNumberWords(Number(n)), words, n);
  const en = { 0: "zero", 13: "thirteen", 20: "twenty", 37: "thirty seven", 100: "one hundred" };
  for (const [n, words] of Object.entries(en)) assert.equal(englishNumberWords(Number(n)), words, n);
});

test("اللعبة: المجموعةُ كلُّها، وتبدأ من حرف الدرس أو عدده", () => {
  const game = alphabetGame({ title: "الوحدة الأولى — حرف الباء", subject: "الحروف العربية", grade: KG });
  assert.equal(game.id, "tracing");
  assert.equal(game.title, "تتبّع واكتب!");
  assert.equal(game.items.tracing.length, 28);
  assert.equal(game.items.start, 1, "يفتح على الباء");
  assert.equal(game.items.reward_after, undefined, "لا حدَّ خمسة: الجلسةُ مفتوحة");
  const numbers = (title) => alphabetGame({ title, subject: "الأرقام العربية", grade: KG }).items.start;
  assert.equal(numbers(""), 0);
  assert.equal(numbers("العدد ٢٥"), 25);
  assert.equal(numbers("العدد 100"), 100, "أيّاً كانت أرقامُ العنوان");
  assert.equal(alphabetGame({ title: "Letter C", subject: "الحروف الإنجليزية", grade: KG }).items.start, 2);
});

test("المكافأةُ جوهرةٌ ونقطةٌ عن كل حرف، ومفتاحُها لحرفٍ من مجموعة الدرس وحده", () => {
  assert.deepEqual({ ...TRACING_REWARD }, { gems: 1, points: 1 });
  const lesson = { id: "L1", subject: "الحروف العربية", grade: KG };
  assert.equal(tracingRewardKey(lesson, "ب"), "tracing:L1:ب");
  assert.notEqual(tracingRewardKey(lesson, "ب"), tracingRewardKey(lesson, "ت"), "لكل حرفٍ مفتاحُه");
  assert.equal(tracingRewardKey(lesson, "Aa"), null, "ليس من حروف الدرس");
  assert.equal(tracingRewardKey(lesson, ""), null);
  assert.equal(tracingRewardKey(lesson, "ب".repeat(500)), null, "لا مفتاحَ بطولٍ يختاره التطبيق");
  const numbers = { id: "L2", subject: "الأرقام العربية", grade: KG };
  assert.equal(tracingRewardKey(numbers, "٢٥"), "tracing:L2:٢٥");
  assert.equal(tracingRewardKey(numbers, "١٠١"), null);
  assert.equal(tracingRewardKey({ ...lesson, grade: "الصف الأول" }, "ب"), null, "خارج الروضة لا مكافأة");
});

test("تُضاف إلى الحزمة مرّةً واحدة، ولا شيءَ إن لم تكن لعبة", () => {
  const game = alphabetGame({ title: "", subject: "الحروف العربية", grade: KG });
  const once = withTracingGame({ games: [] }, game);
  assert.equal(withTracingGame(once, game).games.filter((entry) => entry.id === "tracing").length, 1);
  assert.equal(withTracingGame({ games: [] }, null).games.length, 0);
});

test("مكافأتُها تُطلب بمعرّفها، والنموذجُ لا يعرفها", () => {
  assert.deepEqual(parseStudyGameActivityId("lesson-1::tracing"), { lessonId: "lesson-1", gameId: "tracing" });
  assert.ok(!GAME_TYPES.includes("tracing"));
  const schemaTypes = STUDY_GAMES_SCHEMA.properties.games.items.properties.game_type.enum;
  assert.ok(!schemaTypes.includes("tracing"));
});
