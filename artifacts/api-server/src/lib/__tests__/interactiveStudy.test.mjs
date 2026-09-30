/**
 * اختبارات حزمة المذاكرة الذكية.
 *
 * ── ما يُختبر ──
 * النداءُ إلى النموذج لا يُختبر — يحتاج مفتاحاً ويُقاس بالمال. والمُختبَرُ
 * حيث يقع الخطأ فعلاً: قراءةُ ما يعود، وردُّ ما لا يصلح.
 *
 * والنموذجُ يعود بما لم يُطلب: فرعاً بلا شرح، وخياراً صحيحاً ليس من
 * الخيارات، وثلاثةَ خياراتٍ أحدها مكرَّر، وموقفين بدل ثلاثة. وكلُّها تصل
 * الطفلَ شاشةً لا تُلعَب إن لم تُردّ هنا.
 *
 * التشغيل:
 *   npm run build && node --test src/lib/__tests__/interactiveStudy.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";

const target = process.env.STUDY_MODULE ?? "../../../dist/lib/interactiveStudy.mjs";
let mod;
try {
  mod = await import(target);
} catch (error) {
  throw new Error(
    `تعذّر استيراد ${target} — شغّل npm run build أولاً. (${error?.message ?? error})`,
  );
}

const {
  MAX_SCENARIOS,
  MIN_BRANCHES,
  SITUATIONS_PER_SCENARIO,
  STUDY_VERSION,
  clean,
  extractJson,
  maxSituations,
  parseSituation,
  parseStudyPack,
  readStudyPack,
  studyPrompt,
} = mod;

/** موقفٌ صالح. */
const situation = (n = 1) => ({
  prompt: `الموقف رقم ${n}: ماذا تفعل؟`,
  options: [`خيار أ${n}`, `خيار ب${n}`, `خيار ج${n}`],
  answer: 1,
  because: "لأنه يوافق ما في الدرس",
});

const scenario = (n = 1) => ({
  title: `مغامرة ${n}`,
  situations: [situation(n * 10 + 1), situation(n * 10 + 2), situation(n * 10 + 3)],
});

const pack = () => ({
  mindMap: {
    title: "الخلية",
    branches: [
      { title: "الغشاء", summary: "يحيط بالخلية" },
      { title: "النواة", summary: "تحفظ المعلومات" },
      { title: "السيتوبلازم", summary: "يملأ الخلية" },
    ],
  },
  scenarios: [scenario(1), scenario(2)],
});

test("الطلبُ يحمل نصّ الدرس وشروطَ الشكل", () => {
  const prompt = studyPrompt({
    lessonTitle: "الخلية",
    lessonText: "الخلية وحدة بناء الكائن الحي",
    grade: "علوم",
  });
  assert.match(prompt, /الخلية وحدة بناء/);
  assert.match(prompt, /mindMap/);
  assert.match(prompt, /scenarios/);
  // والشروطُ العددية مكتوبةٌ من الثوابت لا بأرقامٍ يدوية.
  assert.match(prompt, new RegExp(`${SITUATIONS_PER_SCENARIO} مواقف`));
  // وتُطلب اللهجةُ ومنعُ التشكيل كما في بقية المسارات.
  assert.match(prompt, /تشكيل/);
});

test("ونصُّ الدرس يُقتطع فلا يتجاوز الطلبُ حدّه", () => {
  const prompt = studyPrompt({
    lessonTitle: "طويل",
    lessonText: "ا".repeat(20000),
  });
  assert.ok(prompt.length < 9000, `الطلب ${prompt.length} حرفاً`);
});

test("الحزمةُ الصالحة تُقرأ", () => {
  const parsed = parseStudyPack(JSON.stringify(pack()), "الخلية");
  assert.ok(parsed);
  assert.equal(parsed.version, STUDY_VERSION);
  assert.equal(parsed.mindMap.branches.length, 3);
  assert.equal(parsed.scenarios.length, 2);
  assert.equal(parsed.scenarios[0].situations.length, SITUATIONS_PER_SCENARIO);
  assert.equal(parsed.scenarios[0].situations[0].answer, 1);
});

test("وسياجُ الشيفرة وكلامٌ حول JSON لا يمنعان قراءته", () => {
  const raw = "تفضل هذه الحزمة:\n```json\n" + JSON.stringify(pack()) + "\n```\nبالتوفيق";
  assert.ok(parseStudyPack(raw, "الخلية"));
  assert.ok(extractJson("```\n{\"a\":1}\n```"));
  assert.equal(extractJson("لا جيسون هنا"), null);
});

test("والتشكيلُ يسقط من كل نصٍّ في الحزمة", () => {
  const raw = pack();
  raw.mindMap.branches[0].title = "الغِشَاءُ";
  const parsed = parseStudyPack(JSON.stringify(raw), "");
  assert.equal(parsed.mindMap.branches[0].title, "الغشاء");
  assert.equal(clean("مُحَمَّدٌ"), "محمد");
});

// ── وما يُردّ ──

test("فروعٌ أقلُّ من ثلاثة تُسقط الحزمة", () => {
  const raw = pack();
  raw.mindMap.branches = raw.mindMap.branches.slice(0, MIN_BRANCHES - 1);
  assert.equal(parseStudyPack(JSON.stringify(raw), "الخلية"), null);
});

test("وفرعٌ بلا شرحٍ لا يُحسب", () => {
  const raw = pack();
  raw.mindMap.branches[1].summary = "   ";
  assert.equal(parseStudyPack(JSON.stringify(raw), "الخلية"), null);
});

test("ومغامرةٌ واحدة لا تكفي", () => {
  const raw = pack();
  raw.scenarios = [scenario(1)];
  assert.equal(parseStudyPack(JSON.stringify(raw), "الخلية"), null);
});

test("ومغامرةٌ بموقفين تُهمل، فإن بقي أقلُّ من اثنتين سقطت الحزمة", () => {
  const raw = pack();
  raw.scenarios[0].situations = raw.scenarios[0].situations.slice(0, 2);
  assert.equal(parseStudyPack(JSON.stringify(raw), "الخلية"), null);
});

test("والخيارُ الصحيح خارج القائمة يُسقط الموقف", () => {
  assert.equal(parseSituation({ ...situation(), answer: 5 }), null);
  assert.equal(parseSituation({ ...situation(), answer: -1 }), null);
});

test("وخيارٌ مكرَّر يُسقط الموقف — فلا يُعرف أيُّ الصحيحين أراد", () => {
  assert.equal(
    parseSituation({ ...situation(), options: ["أ", "ب", "أ"] }),
    null,
  );
});

test("وعددُ الخيارات ثلاثةٌ بالضبط", () => {
  assert.equal(parseSituation({ ...situation(), options: ["أ", "ب"] }), null);
  assert.equal(
    parseSituation({ ...situation(), options: ["أ", "ب", "ج", "د"] }),
    null,
  );
});

test("و«الصحيح» يُقبل نصَّ الخيار كما يُقبل موضعه", () => {
  // النموذج يعود بأحدهما، فيُقرأ كلاهما بدل أن تُردّ حزمةٌ صالحة.
  const byText = parseSituation({ ...situation(1), answer: "خيار ج1" });
  assert.ok(byText);
  assert.equal(byText.answer, 2);
  const byDigitString = parseSituation({ ...situation(), answer: "2" });
  assert.equal(byDigitString?.answer, 2);
});

test("وردٌّ ليس JSON أصلاً يعود null لا يرفع خطأ", () => {
  for (const bad of ["", "نعم", "{", "null", null, undefined, 42, []]) {
    assert.equal(parseStudyPack(bad, "الخلية"), null);
  }
});

// ── والمخزَّن ──

test("المخزَّنُ يُقرأ، والنسخةُ الأقدم تُهمل فيُعاد التوليد", () => {
  const stored = parseStudyPack(JSON.stringify(pack()), "الخلية");
  assert.ok(readStudyPack(stored));
  assert.equal(readStudyPack({ ...stored, version: STUDY_VERSION - 1 }), null);
  assert.equal(readStudyPack(null), null);
  assert.equal(readStudyPack({}), null);
});

test("وسقفُ ما يُكافأ عليه عددُ المواقف في الحزمة", () => {
  const stored = parseStudyPack(JSON.stringify(pack()), "الخلية");
  assert.equal(maxSituations(stored), 2 * SITUATIONS_PER_SCENARIO);
  // ولا تزيد الحزمةُ على ثلاث مغامرات ولو أخرج النموذج أكثر.
  const many = pack();
  many.scenarios = [scenario(1), scenario(2), scenario(3), scenario(4)];
  const capped = parseStudyPack(JSON.stringify(many), "الخلية");
  assert.equal(capped.scenarios.length, MAX_SCENARIOS);
});
