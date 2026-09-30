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
  CHALLENGE_OPTIONS,
  MAX_SCENARIOS,
  MIN_BRANCHES,
  SITUATIONS_PER_SCENARIO,
  STUDY_VERSION,
  parseChallengeType,
  clean,
  extractJson,
  maxSituations,
  parseSituation,
  parseStudyPack,
  readStudyPack,
  studyPrompt,
} = mod;

/** بوّابتان يمشي الطالب بينهما. */
const pathSituation = (n = 1) => ({
  type: "avatar_path",
  prompt: `الموقف رقم ${n}: أيّ بوّابة تعبر؟`,
  options: [`البوابة أ${n}`, `البوابة ب${n}`],
  answer: 0,
  because: "لأنها توافق ما في الدرس",
});

/** حقيقةٌ تُسحب. */
const swipeSituation = ({ isTrue = true, n = 1 } = {}) => ({
  type: "swipe_fact",
  prompt: `المعلومة رقم ${n} عن الفرع`,
  options: [],
  isTrue,
  because: "لأن الدرس يقولها كذا",
});

/** ثلاثُ فقاعاتٍ إحداها متسلّلة. */
const imposterSituation = (n = 1) => ({
  type: "spot_imposter",
  prompt: "أيّها متسلّلة؟",
  options: [`صحيحة أ${n}`, `صحيحة ب${n}`, `متسلّلة ج${n}`],
  answer: 2,
  because: "لأنها ليست من الدرس",
});

/** موقفٌ صالحٌ من أيّ نمط — يُستعمل حيث لا يهمّ النمط. */
const situation = (n = 1) => pathSituation(n);

const scenario = (n = 1) => ({
  title: `مغامرة ${n}`,
  branch: `الفرع ${n}`,
  situations: [
    pathSituation(n * 10 + 1),
    swipeSituation({ n: n * 10 + 2 }),
    imposterSituation(n * 10 + 3),
  ],
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
  // والأنماطُ الثلاثة مذكورةٌ بأسمائها، وإلا أخرج النموذج نمطاً واحداً.
  for (const type of Object.keys(CHALLENGE_OPTIONS)) {
    assert.match(prompt, new RegExp(type), type);
  }
  assert.match(prompt, /branch/);
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
  // وأوّلُ موقفٍ مسارٌ ببوّابتين، وصحيحُه الأولى.
  assert.equal(parsed.scenarios[0].situations[0].type, "avatar_path");
  assert.equal(parsed.scenarios[0].situations[0].answer, 0);
  // وترتيبُ الأنماط كما يُطلب في الطلب: نمطٌ واحدٌ يتكرّر ثلاثاً يصير
  // عادةً في الموقف الثاني.
  assert.deepEqual(
    parsed.scenarios[0].situations.map((item) => item.type),
    ["avatar_path", "swipe_fact", "spot_imposter"],
  );
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
  assert.equal(parseSituation({ ...pathSituation(), answer: 5 }), null);
  assert.equal(parseSituation({ ...pathSituation(), answer: -1 }), null);
});

test("وخيارٌ مكرَّر يُسقط الموقف — فلا يُعرف أيُّ الصحيحين أراد", () => {
  assert.equal(
    parseSituation({ ...imposterSituation(), options: ["أ", "ب", "أ"] }),
    null,
  );
});

test("وعددُ الخيارات يتبع النمط لا رقماً واحداً", () => {
  // بوّابتان في المسار: ثلاثةٌ أو واحدةٌ لا تعرف الشاشةُ كيف ترسمها.
  assert.equal(parseSituation({ ...pathSituation(), options: ["أ"] }), null);
  assert.equal(
    parseSituation({ ...pathSituation(), options: ["أ", "ب", "ج"] }),
    null,
  );
  // وثلاثُ فقاعاتٍ في الرادار.
  assert.equal(
    parseSituation({ ...imposterSituation(), options: ["أ", "ب"] }),
    null,
  );
  // ولا خيارَ في السحب: الحقيقةُ في `prompt`.
  assert.equal(
    parseSituation({ ...swipeSituation(), options: ["صحيح", "خطأ"] }),
    null,
  );
  assert.equal(CHALLENGE_OPTIONS.avatar_path, 2);
  assert.equal(CHALLENGE_OPTIONS.swipe_fact, 0);
  assert.equal(CHALLENGE_OPTIONS.spot_imposter, 3);
});

test("والنمطُ شرطٌ: موقفٌ بلا نمطٍ معروف يُسقط", () => {
  // الشاشةُ ترسم بالنمط، فموقفٌ بلا نمطٍ لا تعرف كيف تعرضه.
  const raw = { ...pathSituation() };
  delete raw.type;
  assert.equal(parseSituation(raw), null);
  assert.equal(parseSituation({ ...pathSituation(), type: "quiz" }), null);
  // ويُقبل `challengeType` اسماً بديلاً، فردٌّ صالحٌ لا يُردّ لأن النموذج
  // اختار الاسم الآخر.
  const alias = { ...pathSituation() };
  delete alias.type;
  assert.ok(parseSituation({ ...alias, challengeType: "avatar_path" }));
  assert.equal(parseChallengeType("SWIPE_FACT"), "swipe_fact");
  assert.equal(parseChallengeType("nope"), null);
});

test("وحقيقةُ السحب: صحيحةٌ صفرٌ ومشوَّهةٌ واحد", () => {
  assert.equal(parseSituation(swipeSituation({ isTrue: true })).answer, 0);
  assert.equal(parseSituation(swipeSituation({ isTrue: false })).answer, 1);
  // ويُقبل نصّاً ورقماً: النموذج يُخرج أحدهما.
  const raw = swipeSituation();
  delete raw.isTrue;
  assert.equal(parseSituation({ ...raw, answer: "false" }).answer, 1);
  assert.equal(parseSituation({ ...raw, correct: 0 }).answer, 0);
  // وما ليس واحداً منهما يُسقط الموقف.
  assert.equal(parseSituation({ ...raw, isTrue: "maybe" }), null);
});

test("والمغامرةُ تحمل فرعَها، فيُختبر الفرعُ الذي قرأه", () => {
  const parsed = parseStudyPack(JSON.stringify(pack()), "الخلية");
  assert.equal(parsed.scenarios[0].branch, "الفرع 1");
  // وفارغٌ مقبول: حزمةٌ من نموذجٍ لم يُلزمه الطلبُ بعد.
  const raw = pack();
  delete raw.scenarios[0].branch;
  assert.equal(parseStudyPack(JSON.stringify(raw), "الخلية").scenarios[0].branch, "");
});

test("و«الصحيح» يُقبل نصَّ الخيار كما يُقبل موضعه", () => {
  // النموذج يعود بأحدهما، فيُقرأ كلاهما بدل أن تُردّ حزمةٌ صالحة.
  const byText = parseSituation({
    ...imposterSituation(1),
    answer: "متسلّلة ج1",
  });
  assert.ok(byText);
  assert.equal(byText.answer, 2);
  // ورقماً في صورة نصّ. وعلى نمطٍ له ثلاثةُ خيارات، فـ٢ داخل مداه.
  const byDigitString = parseSituation({ ...imposterSituation(), answer: "2" });
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
