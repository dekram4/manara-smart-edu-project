/**
 * اختبارات مولّد بنك أسئلة الاختبارات.
 *
 * النداءُ إلى النموذج لا يُختبر — يحتاج مفتاحاً ويُقاس بالمال. والمُختبَرُ ما
 * يقع عليه الخطأ: التوجيهُ وضوابطه، والمخطّط، وفحصُ ما يعود.
 *
 * التشغيل:
 *   npm run build && node --test src/lib/__tests__/quizGenerator.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";

const target = process.env.QUIZ_MODULE ?? "../../../dist/lib/quizGenerator.mjs";
let mod;
try {
  mod = await import(target);
} catch (error) {
  throw new Error(`تعذّر استيراد ${target} — شغّل npm run build أولاً. (${error?.message ?? error})`);
}

const {
  MAX_BANK_SIZE,
  MAX_LESSON_CHARS,
  QUIZ_RESPONSE_SCHEMA,
  QUIZ_SYSTEM_INSTRUCTION,
  clampCount,
  parseQuizQuestions,
  quizPrompt,
  trimLesson,
} = mod;

const good = (n, extra = {}) => ({
  question: `ماذا يحدث للماء إذا وُضع في المجمّد مدة طويلة؟ (${n})`,
  options: [`يتجمّد ${n}`, `يغلي ${n}`, `يتبخّر ${n}`, `يختفي ${n}`],
  correctAnswer: "A",
  cognitiveLevel: "تطبيق",
  ...extra,
});

test("توجيهُ النظام يفرض الفهم لا الحفظ، والمضلِّلات الذكية، وJSON الصارم", () => {
  for (const rule of ["لا الحفظ", "التحليل", "الخيارات المضلِّلة ذكية", "خطأً شائعاً", "JSON فقط", "لعمر الطالب", "جميع ما سبق"]) {
    assert.ok(QUIZ_SYSTEM_INSTRUCTION.includes(rule), rule);
  }
  const item = QUIZ_RESPONSE_SCHEMA.properties.questions.items;
  assert.deepEqual(item.required, ["question", "options", "correctAnswer", "cognitiveLevel"]);
  assert.equal(item.properties.options.minItems, 4);
  assert.equal(item.properties.options.maxItems, 4);
  assert.deepEqual(item.properties.correctAnswer.enum, ["A", "B", "C", "D"]);
});

test("الرسالةُ تحمل الدرس كاملاً وسياقَه والعدد", () => {
  const lesson = "جملة. ".repeat(600); // ٣٦٠٠ حرف: كان يُقطع عند ألفين
  const prompt = quizPrompt({ lessonContent: lesson, count: 24, grade: "الرابع", subject: "العلوم", unit: "المادة", lesson: "حالات المادة" });
  assert.ok(prompt.includes("24 سؤال"));
  assert.ok(prompt.includes("الصف / المرحلة: الرابع"));
  assert.ok(prompt.includes("الدرس: حالات المادة"));
  assert.ok(prompt.includes(lesson.trim()));
  assert.equal(clampCount(500), MAX_BANK_SIZE);
  assert.equal(clampCount(0), 1);
  assert.equal(clampCount("x"), 10);
  const long = trimLesson("أ. ".repeat(10_000));
  assert.ok(long.length <= MAX_LESSON_CHARS);
  assert.ok(long.endsWith("."));
});

test("الصالحُ يمرّ بصيغة التطبيق، من كائنٍ أو مصفوفةٍ أو داخل سياج Markdown", () => {
  for (const raw of [
    JSON.stringify({ questions: [good(1)] }),
    JSON.stringify([good(1)]),
    "```json\n" + JSON.stringify({ questions: [good(1)] }) + "\n```",
  ]) {
    const { questions } = parseQuizQuestions(raw, 10);
    assert.equal(questions.length, 1);
    const [q] = questions;
    assert.deepEqual(Object.keys(q).sort(), ["correctAnswer", "options", "question"]);
    assert.equal(q.options.length, 4);
    assert.equal(q.options[["A", "B", "C", "D"].indexOf(q.correctAnswer)], "يتجمّد 1");
  }
});

test("ما لا يصلح يُردّ: خياراتٌ ناقصة أو مكرّرة، «جميع ما سبق»، جوابٌ مجهول، الجوابُ في السؤال، والمكرّر", () => {
  const raw = JSON.stringify({
    questions: [
      good(1),
      good(2, { options: ["أ", "ب", "ج"] }),
      good(3, { options: ["يتجمّد", "يتجمّد", "يغلي", "يتبخّر"] }),
      good(4, { options: ["يتجمّد", "يغلي", "يتبخّر", "جميع ما سبق"] }),
      good(5, { correctAnswer: "E" }),
      good(6, { question: "الماء في المجمّد يتجمّد سريعاً، فماذا يحدث له؟", options: ["يتجمّد سريعاً", "يغلي", "يتبخّر", "يختفي"] }),
      good(1),
    ],
  });
  const { questions, rejected } = parseQuizQuestions(raw, 10);
  assert.equal(questions.length, 1);
  assert.deepEqual(rejected, { options: 2, banned_option: 1, answer: 1, answer_in_question: 1, duplicate: 1 });
});

test("الجوابُ يُقرأ حرفاً أو رقماً أو نصّاً، وتسقط حروفُ الترقيم من الخيارات", () => {
  const raw = [
    good(1, { correctAnswer: "b", options: ["أ) يغلي 1", "ب) يتجمّد 1", "ج) يتبخّر 1", "د) يختفي 1"] }),
    good(2, { correctAnswer: 2, options: ["يغلي 2", "يتبخّر 2", "يتجمّد 2", "يختفي 2"] }),
    good(3, { correctAnswer: "يتجمّد 3", options: ["يغلي 3", "يتبخّر 3", "يختفي 3", "يتجمّد 3"] }),
  ];
  const { questions } = parseQuizQuestions(raw, 10);
  assert.equal(questions.length, 3);
  for (const [index, q] of questions.entries()) {
    assert.equal(q.options[["A", "B", "C", "D"].indexOf(q.correctAnswer)], `يتجمّد ${index + 1}`);
    assert.ok(q.options.every((option) => !/^[أبجد]\)/.test(option)));
  }
});

test("موضعُ الجواب الصحيح موزّعٌ بالتساوي، والعددُ لا يُتجاوز", () => {
  const raw = Array.from({ length: 40 }, (_, i) => good(i + 1)); // كلُّها «A» من النموذج
  const { questions } = parseQuizQuestions(raw, 32);
  assert.equal(questions.length, 32);
  const tally = { A: 0, B: 0, C: 0, D: 0 };
  for (const q of questions) tally[q.correctAnswer]++;
  assert.deepEqual(tally, { A: 8, B: 8, C: 8, D: 8 });
  // ولا نمطَ دوريّاً بسيطاً A,B,C,D.
  assert.notDeepEqual(questions.slice(0, 4).map((q) => q.correctAnswer), ["A", "B", "C", "D"]);
});

test("ردٌّ ليس JSON: لا أسئلة، ولا استثناء", () => {
  assert.deepEqual(parseQuizQuestions("عذراً لا أستطيع", 10).questions, []);
  assert.deepEqual(parseQuizQuestions(null, 10).questions, []);
});
