/**
 * اختبارات بنك جولات التحدي.
 *
 * التشغيل:
 *   npm run build && node --test src/lib/__tests__/challengeBank.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";

const target = process.env.BANK_MODULE ?? "../../../dist/lib/challengeBank.js";
let mod;
try {
  mod = await import(target);
} catch {
  console.log("تُخطّى: لم يُبنَ dist بعد (npm run build).");
  process.exit(0);
}

const {
  BANK_VERSION,
  acceptRound,
  bankPrompt,
  clean,
  detectSubject,
  drawRounds,
  fingerprint,
  parseBank,
  readBank,
} = mod;

const fill = (over = {}) => ({
  kind: "fill",
  before: "الخلية هي أصغر",
  after: "قادرة على الحياة.",
  answer: "وحدة",
  distractors: ["نواة", "غشاء", "نسيج"],
  ...over,
});

const classify = (over = {}) => ({
  kind: "classify",
  prompt: "صنّف الحيوانات",
  buckets: ["مزرعة", "برّية"],
  items: { بقرة: "مزرعة", أسد: "برّية", خروف: "مزرعة", نمر: "برّية" },
  ...over,
});

const match = (over = {}) => ({
  kind: "match",
  pairs: [
    { term: "النواة", meaning: "مركز التحكّم في الخلية" },
    { term: "الغشاء", meaning: "غطاءٌ يسيطر على الدخول والخروج" },
    { term: "السايتوبلازم", meaning: "مادةٌ هلامية تملأ الفراغ" },
  ],
  ...over,
});

test("الأنواع الثلاثة تُقبل", () => {
  for (const round of [fill(), classify(), match()]) {
    const verdict = acceptRound(round, "science");
    assert.equal(verdict.ok, true, `${round.kind}: ${verdict.why ?? ""}`);
  }
});

test("جواب مكتوبٌ في الجملة يُردّ — يُقرأ قبل أن يُسحب", () => {
  const verdict = acceptRound(
    fill({ before: "الوحدة الصغرى هي", answer: "وحدة" }),
    "science",
  );
  assert.equal(verdict.ok, false);
  assert.ok(verdict.why.includes("مكتوب في الجملة"));
});

test("مشتّتٌ واحد لا يكفي", () => {
  const verdict = acceptRound(fill({ distractors: ["نواة"] }), "science");
  assert.equal(verdict.ok, false);
  assert.ok(verdict.why.includes("مشتّت"));
});

test("المشتّت المطابق للجواب يُسقَط ولا يُعرض مرّتين", () => {
  const verdict = acceptRound(
    fill({ distractors: ["وحدة", "نواة", "غشاء", "نسيج"] }),
    "science",
  );
  assert.equal(verdict.ok, true);
  assert.ok(!verdict.round.distractors.some((item) => item === "وحدة"));
  assert.equal(verdict.round.distractors.length, 3);
});

test("مجموعة بلا عنصر تُردّ — تبقى فارغةً فيظنّ الطفل أنه أخطأ", () => {
  const verdict = acceptRound(
    classify({
      buckets: ["مزرعة", "برّية", "بحرية"],
      items: { بقرة: "مزرعة", أسد: "برّية", خروف: "مزرعة", نمر: "برّية" },
    }),
    "science",
  );
  assert.equal(verdict.ok, false);
  assert.ok(verdict.why.includes("بلا عنصر"));
});

test("عنصرٌ في مجموعةٍ غير معلنة يُردّ", () => {
  const verdict = acceptRound(
    classify({ items: { بقرة: "مزرعة", أسد: "برّية", حوت: "بحرية", نمر: "برّية" } }),
    "science",
  );
  assert.equal(verdict.ok, false);
  assert.ok(verdict.why.includes("غير معلنة"));
});

test("تعريفٌ يذكر مصطلحه يُردّ — يُحلّ بالنظر بلا فهم", () => {
  const verdict = acceptRound(
    match({
      pairs: [
        { term: "النواة", meaning: "النواة هي مركز التحكّم" },
        { term: "الغشاء", meaning: "غطاء خارجي" },
        { term: "السايتوبلازم", meaning: "مادة هلامية" },
      ],
    }),
    "science",
  );
  assert.equal(verdict.ok, false);
  assert.ok(verdict.why.includes("يذكر مصطلحه"));
});

test("حرف عربي في تحدّي الإنجليزية يُردّ", () => {
  const english = {
    kind: "fill",
    before: "A bird can",
    after: "in the sky.",
    answer: "fly",
    distractors: ["swim", "run", "يسبح"],
  };
  const verdict = acceptRound(english, "english");
  assert.equal(verdict.ok, false);
  assert.ok(verdict.why.includes("عربي"));

  const clean2 = { ...english, distractors: ["swim", "run", "jump"] };
  assert.equal(acceptRound(clean2, "english").ok, true);
});

test("ترميز المعادلات يُنقّى، وما لا يُعرف يُردّ", () => {
  assert.equal(clean("احسب $5 + 4$"), "احسب 5 + 4");
  assert.equal(clean("الكسر \\frac{3}{4}"), "الكسر 3/4");
  const verdict = acceptRound(fill({ answer: "\\sqrt{16}" }), "math");
  assert.equal(verdict.ok, false);
  assert.ok(verdict.why.includes("LaTeX"));
});

test("نوعٌ غير معروف يُردّ باسمه", () => {
  const verdict = acceptRound({ kind: "mcq", question: "?" }, "math");
  assert.equal(verdict.ok, false);
  assert.ok(verdict.why.includes("mcq"));
});

test("البنك يُصفّى ويُسقط المكرّر", () => {
  const { rounds, rejected } = parseBank(
    { rounds: [fill(), fill(), classify(), { kind: "mcq" }] },
    "science",
  );
  assert.equal(rounds.length, 2);
  assert.equal(rejected["جولة مكرّرة"], 1);
  assert.ok(rejected["نوع جولة غير معروف: mcq"]);
});

test("سياج JSON يُفكّ", () => {
  const fenced = "```json\n" + JSON.stringify({ rounds: [match()] }) + "\n```";
  assert.equal(parseBank(fenced, "science").rounds.length, 1);
});

test("البصمة تفرّق بين جولتين وتُطابق نفسها", () => {
  assert.equal(fingerprint(acceptRound(fill(), "science").round),
    fingerprint(acceptRound(fill(), "science").round));
  assert.notEqual(
    fingerprint(acceptRound(fill(), "science").round),
    fingerprint(acceptRound(classify(), "science").round),
  );
});

test("البنك القديم الصيغة لا يُقرأ، فيُعاد توليده", () => {
  assert.equal(readBank({ version: 0, rounds: [fill()] }), null);
  assert.equal(readBank(null), null);
  assert.equal(readBank({ version: BANK_VERSION, rounds: [] }), null);
  const bank = readBank({ version: BANK_VERSION, rounds: [fill(), match()] });
  assert.equal(bank.rounds.length, 2);
});

test("السحب لا يكرّر داخل الجولة، ويختلف بالبذرة", () => {
  const bank = {
    version: BANK_VERSION,
    generatedAt: "",
    subject: "العلوم",
    rounds: Array.from({ length: 20 }, (_, index) =>
      fill({ answer: `كلمة${index}` }),
    ),
  };
  const first = drawRounds(bank, 5, 11);
  assert.equal(first.length, 5);
  assert.equal(new Set(first.map((r) => r.answer)).size, 5);
  // البذرة نفسها تُعيد السحبة نفسها، وغيرها تُخرج غيرها — وهو ما يجعل
  // إعادة التحدي تحدّياً آخر.
  assert.deepEqual(drawRounds(bank, 5, 11).map((r) => r.answer), first.map((r) => r.answer));
  assert.notDeepEqual(
    drawRounds(bank, 5, 12).map((r) => r.answer),
    first.map((r) => r.answer),
  );
});

test("بنكٌ أصغر من المطلوب يُسحب كلّه ولا يُكرّر", () => {
  const bank = {
    version: BANK_VERSION,
    generatedAt: "",
    subject: "العلوم",
    rounds: [fill(), classify(), match()],
  };
  assert.equal(drawRounds(bank, 5, 1).length, 3);
});

test("التوجيه يحمل نصّ الدرس، وللإنجليزية قواعدها", () => {
  const arabic = bankPrompt({
    subject: "العلوم",
    lesson: "الخلايا",
    lessonText: "الخلية أصغر وحدة حية.",
  });
  assert.ok(arabic.includes("الخلية أصغر وحدة حية."));
  assert.ok(arabic.includes("سحبٍ وإفلات"));

  const english = bankPrompt({
    subject: "اللغة الإنجليزية",
    lessonText: "Good morning.",
  });
  assert.ok(english.includes("ENGLISH ONLY"));
  assert.ok(english.includes("drag-and-drop"));
});

test("تُعرف المادة مهما اختلفت همزتها", () => {
  assert.equal(detectSubject("اللغة الانجليزيه"), "english");
  assert.equal(detectSubject("الرياضيات"), "math");
  assert.equal(detectSubject("العلوم"), "science");
});
