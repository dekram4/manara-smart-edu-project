/**
 * اختبارات محرّك أسئلة التحدي.
 *
 * تعمل بـ `node --test` على مصدر TypeScript بعد تجريده من الأنواع؟ لا —
 * تستورد الوحدة بعد بنائها. وحين لا يكون البناء متاحاً (لا `node_modules`
 * على جهاز المطوّر) يُخطّى الملف بدل أن يفشل، فالفشلُ هنا يعني «البيئة
 * ناقصة» لا «القاعدة خاطئة».
 *
 * التشغيل:
 *   npm run build && node --test src/lib/__tests__/challengeQuestions.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";

// مسارٌ بديل لتشغيلها على ترجمةٍ مؤقتة بلا بناءٍ كامل.
const target = process.env.CHALLENGE_MODULE ?? "../../../dist/lib/challengeQuestions.js";
let mod;
try {
  mod = await import(target);
} catch {
  console.log("تُخطّى: لم يُبنَ dist بعد (npm run build).");
  process.exit(0);
}

const {
  acceptQuestion,
  buildPrompt,
  cleanText,
  detectSubject,
  outputBudget,
  parseQuestions,
  unsafeCommand,
} = mod;

const good = {
  question: "ما القيمة المنزلية للرقم 7 في العدد 572,104؟",
  options: ["70,000", "7,000", "700", "7"],
  correctAnswer: "70,000",
  explanation: "الرقم في منزلة عشرات الألوف.",
};

test("تعرف المادة مهما اختلفت همزتها", () => {
  assert.equal(detectSubject("اللغة الإنجليزية"), "english");
  assert.equal(detectSubject("اللغة الانجليزيه"), "english");
  assert.equal(detectSubject("الرياضيات"), "math");
  assert.equal(detectSubject("العلوم"), "science");
  assert.equal(detectSubject("التربية الفنية"), "other");
});

test("تنقّي ترميز المعادلات وتُبقي المعنى", () => {
  assert.equal(cleanText("احسب $5 + 4$ ثم قارن"), "احسب 5 + 4 ثم قارن");
  assert.equal(cleanText("الكسر \\frac{3}{4} كبير"), "الكسر 3/4 كبير");
  assert.equal(cleanText("$$20$$"), "20");
  assert.equal(cleanText("نصّ سليم"), "نصّ سليم");
});

test("ترصد أمراً لا تُعرف تنقيته", () => {
  assert.equal(unsafeCommand("ما ناتج \\sqrt{16}؟"), "sqrt");
  assert.equal(unsafeCommand("الكسر \\frac{1}{2}"), null);
});

test("تقبل السؤال السليم وتردّ المعطوب، وتقول لماذا", () => {
  assert.equal(acceptQuestion(good, "math").ok, true);

  const cases = [
    [{ ...good, options: ["أ", "ب", "ج"] }, "خيارات لا أربعة"],
    [{ ...good, options: ["70,000", "70,000", "700", "7"] }, "خياران متطابقان"],
    [{ ...good, correctAnswer: "900" }, "ليست من الخيارات"],
    [{ ...good, question: " " }, "قصير أو فارغ"],
    [{ ...good, question: "ما ناتج \\sqrt{16}؟" }, "LaTeX"],
  ];
  for (const [raw, fragment] of cases) {
    const verdict = acceptQuestion(raw, "math");
    assert.equal(verdict.ok, false, JSON.stringify(raw));
    assert.ok(verdict.why.includes(fragment), `${verdict.why} ⊅ ${fragment}`);
  }
});

test("تردّ حرفاً عربياً واحداً في تحدّي الإنجليزية", () => {
  const mixed = {
    question: "What is the plural of book؟",
    options: ["books", "bookes", "book", "bookies"],
    correctAnswer: "books",
    explanation: "نضيف s",
  };
  const verdict = acceptQuestion(mixed, "english");
  assert.equal(verdict.ok, false);
  assert.ok(verdict.why.includes("عربي"));

  const clean = { ...mixed, question: "What is the plural of book?", explanation: "Add s." };
  assert.equal(acceptQuestion(clean, "english").ok, true);
});

test("تُصحّح نصّ الإجابة ليطابق الخيار حرفاً بحرف", () => {
  // النموذج يكتب الإجابة ثانيةً فتختلف همزتُها عن الخيار، والتطبيق
  // يقارن نصّاً بنصّ — فتُردّ الإجابةُ الصحيحة على الطفل.
  const verdict = acceptQuestion(
    {
      question: "أيّ هذه من أدوات القياس؟",
      options: ["المسطرة", "الآلة الحاسبة", "الممحاة", "المقلمة"],
      correctAnswer: "الالة الحاسبة",
      explanation: "—",
    },
    "science",
  );
  assert.equal(verdict.ok, true);
  assert.equal(verdict.question.correctAnswer, "الآلة الحاسبة");
});

test("تفكّ ردّ النموذج ولو لفّه بسياج JSON", () => {
  const fenced = "```json\n" + JSON.stringify({ questions: [good] }) + "\n```";
  const { questions } = parseQuestions(fenced, "math", 5);
  assert.equal(questions.length, 1);
});

test("تُسقط المكرّر وتقف عند الحدّ", () => {
  const list = [good, good, { ...good, question: "سؤال آخر مختلف تماماً؟" }];
  const { questions, rejected } = parseQuestions({ questions: list }, "math", 5);
  assert.equal(questions.length, 2);
  assert.equal(rejected["سؤال مكرّر"], 1);

  const limited = parseQuestions({ questions: list }, "math", 1);
  assert.equal(limited.questions.length, 1);
});

test("تُسقط ما رآه اللاعب قبل قليل", () => {
  const { questions } = parseQuestions({ questions: [good] }, "math", 5, [
    good.question,
  ]);
  assert.equal(questions.length, 0);
});

test("ردٌّ ليس JSON يُعاد فارغاً بسببه لا برمية", () => {
  const { questions, rejected } = parseQuestions("ليس JSON", "math", 5);
  assert.equal(questions.length, 0);
  assert.ok(rejected["ردّ ليس JSON صالحاً"]);
});

test("التوجيه يحمل نصّ الدرس والبذرة والمستبعَد", () => {
  const prompt = buildPrompt({
    subject: "العلوم",
    unit: "الوحدة الأولى",
    lesson: "الخلايا",
    lessonText: "الخلية أصغر وحدة حية.",
    count: 6,
    seed: "abc123",
    exclude: ["سؤال قديم"],
  });
  assert.ok(prompt.includes("الخلية أصغر وحدة حية."));
  assert.ok(prompt.includes("abc123"));
  assert.ok(prompt.includes("سؤال قديم"));
  assert.ok(prompt.includes("6"));
});

test("توجيه الإنجليزية إنجليزيٌّ في قواعده وفي فقرة المنع", () => {
  const prompt = buildPrompt({
    subject: "اللغة الإنجليزية",
    lessonText: "Good morning means صباح الخير.",
    count: 5,
    seed: "s",
    exclude: ["Old question"],
  });
  assert.ok(prompt.includes("ENGLISH ONLY"));
  assert.ok(prompt.includes("Do NOT repeat"));
  assert.ok(prompt.includes("Round key: s"));
});

test("سقف المخرجات يتبع العدد ولا يتجاوز الحدّ", () => {
  assert.ok(outputBudget(6) < outputBudget(14));
  assert.equal(outputBudget(1000), 32000);
});
