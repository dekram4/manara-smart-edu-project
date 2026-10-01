/**
 * اختبارات أسئلة المبارزة من مجال الدرس: المصفّي، والمفاتيح، والصلاحيات.
 *
 * ── لماذا تُختبر بشدّة ──
 * ما يقبله المصفّي يُفعَّل فوراً ويصل إلى الطلاب بلا مراجعة. ومفتاحُ مادّةٍ
 * يحسبه الخادمُ غيرَ ما تحسبه `claim_duel_pack` يكتب أسئلةً لا تُختار أبداً،
 * بلا خطأٍ يظهر. وصلاحيةٌ تُخطئ تُعطي معلماً تعطيلَ أسئلة صفوف غيره.
 *
 * التشغيل:
 *   npm run build && node --test src/lib/__tests__/duelDomainBank.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";

const target = process.env.DUEL_DOMAIN_MODULE ?? "../../../dist/lib/duelDomainBank.mjs";
let mod;
try {
  mod = await import(target);
} catch (error) {
  throw new Error(
    `تعذّر استيراد ${target} — شغّل npm run build أولاً. (${error?.message ?? error})`,
  );
}

const {
  DOMAIN_MIN_ACCEPTED,
  canSeeQuestion,
  canToggleQuestion,
  copiedFromLesson,
  disabledByOf,
  domainRows,
  duelDomainPrompt,
  duelGradeBand,
  duelSubjectKey,
  lessonOwner,
  lessonStamp,
  ownerKey,
  parseDomainQuestions,
} = mod;

const LESSON =
  "يتكوّن الجهاز الهضمي من الفم والمريء والمعدة والأمعاء الدقيقة والأمعاء الغليظة. " +
  "تبدأ عملية الهضم في الفم حيث تقوم الأسنان بتقطيع الطعام وطحنه، ويختلط باللعاب.";

const good = (over = {}) => ({
  prompt: "أي عضو يخزّن الطعام ويهضمه بعد البلع؟",
  answer: "المعدة",
  distractors: ["الرئة", "القلب", "الكلية"],
  ...over,
});

const parse = (questions, subject = "العلوم") =>
  parseDomainQuestions(JSON.stringify({ questions }), { subject, lessonText: LESSON });

// ── مفتاحُ المادة وشريحةُ الصفّ: هما ما تحسبه القاعدة ──
// القيمُ المتوقَّعة أُخرجت من `duel_subject_key` و`duel_grade_band` نفسيهما على
// PostgreSQL، بعد تطبيق `scripts/duel-question-bank.sql`.

test("مفتاحُ المادة يطابق duel_subject_key في القاعدة", () => {
  const fromSql = {
    "العلوم": "science", "علوم": "science", "Science": "science",
    "الرياضيات": "math", "رياضيّات": "math", "Math": "math",
    "اللغة الإنجليزية": "english", "English": "english", "انكليزي": "english",
    "الدراسات الإسلامية": "islamic", "القرآن الكريم": "islamic", "التوحيد": "islamic",
    "الدراسات الاجتماعية": "social", "التربية الوطنية": "social",
    "اللغة العربية": "arabic", "لغتي": "arabic", "Arabic": "arabic",
    "التربية الفنية": "other", "التربية البدنية": "other", "": "other",
  };
  for (const [subject, key] of Object.entries(fromSql)) {
    assert.equal(duelSubjectKey(subject), key, subject);
  }
});

test("شريحةُ الصفّ تطابق duel_grade_band في القاعدة", () => {
  const fromSql = {
    "الصف الأول": "low", "الصف الاول": "low", "الصف الثاني": "low", "الصف الثالث": "low",
    "الصف الرابع": "high", "الصف الخامس": "high", "الصف السادس": "high",
    "1": "low", "3": "low", "4": "high", "12": "high",
    "Grade 2": "low", "grade 5": "high", "a3": "high", "": "all",
  };
  for (const [grade, band] of Object.entries(fromSql)) {
    assert.equal(duelGradeBand(grade), band, grade);
  }
});

// ── الطلب ──

test("الطلبُ يحمل المادة والوحدة ويمنع النسخ وأكمل الفراغ", () => {
  const prompt = duelDomainPrompt({
    subject: "العلوم",
    unit: "أجهزة الجسم",
    grade: "الصف الرابع",
    lessonText: LESSON,
  });
  assert.match(prompt, /العلوم/);
  assert.match(prompt, /أجهزة الجسم/);
  assert.match(prompt, /لا تنسخ/);
  assert.match(prompt, /أكمل الفراغ/);
  assert.match(prompt, /"questions"/);
});

test("وطلبُ الإنجليزية يطلبها بلا حرفٍ عربي", () => {
  assert.match(
    duelDomainPrompt({ subject: "English", lessonText: "Animals live in many places." }),
    /بالإنجليزية البسيطة وحدها/,
  );
});

// ── المصفّي ──

test("سؤالٌ سليمٌ يُقبل كما هو", () => {
  const { accepted, rejected } = parse([good()]);
  assert.equal(accepted.length, 1);
  assert.deepEqual(rejected, {});
  assert.equal(accepted[0].answer, "المعدة");
  assert.equal(accepted[0].distractors.length, 3);
});

test("الردُّ المغلّف بسياج markdown يُقرأ", () => {
  const raw = "```json\n" + JSON.stringify({ questions: [good()] }) + "\n```";
  assert.equal(parseDomainQuestions(raw, { subject: "العلوم", lessonText: LESSON }).accepted.length, 1);
});

test("ردٌّ ليس JSON لا يُسقط شيئاً ويُعدّ", () => {
  const { accepted, rejected } = parseDomainQuestions("ليس هذا JSON", {
    subject: "العلوم",
    lessonText: LESSON,
  });
  assert.equal(accepted.length, 0);
  assert.equal(rejected["ردٌّ ليس JSON"], 1);
});

test("كلُّ سببٍ من أسباب الردّ يُردّ ويُعدّ", () => {
  const cases = [
    [good({ prompt: "قصير" }), "طولُ السؤال"],
    [good({ distractors: ["الرئة"] }), "جوابٌ أو مشتّتاتٌ ناقصة"],
    [good({ answer: "" }), "جوابٌ أو مشتّتاتٌ ناقصة"],
    [good({ distractors: ["المَعِدة", "القلب", "الكلية"] }), "خيارٌ مكرّر"],
    [good({ prompt: "الطعام يُهضم في ______ بعد البلع" }), "أكمل الفراغ"],
    [good({ distractors: ["الرئة", "القلب", "كل ما سبق"] }), "كل ما سبق"],
    [good({ prompt: "ما اسم المعدة التي تهضم الطعام؟" }), "الجوابُ في السؤال"],
    [good({ distractors: ["الرئة", "القلب", "x".repeat(41)] }), "خيارٌ طويل"],
    [good({ prompt: "Which organ digests food first?" }), "لسانٌ آخر"],
    [good({ prompt: "كم يساوي \\frac{1}{2} من وجبة الطعام؟" }), "رموزٌ لا تُعرض"],
    [good({ prompt: "تبدأ عملية الهضم في الفم حيث تقوم الأسنان بتقطيع الطعام؟" }), "منسوخٌ من الدرس"],
  ];
  for (const [question, why] of cases) {
    const { accepted, rejected } = parse([question]);
    assert.equal(accepted.length, 0, why);
    assert.equal(rejected[why], 1, `${why}: ${JSON.stringify(rejected)}`);
  }
});

test("التكرارُ داخل الدفعة يُترك، ولو اختلفت الحركات", () => {
  const { accepted, rejected } = parse([
    good(),
    good({ prompt: "أيُّ عضوٍ يخزّن الطعامَ ويهضمه بعد البلع؟" }),
  ]);
  assert.equal(accepted.length, 1);
  assert.equal(rejected["مكرّرٌ في الدفعة"], 1);
});

test("سؤالُ الإنجليزية بحرفٍ عربيٍّ يُردّ، وبلا عربيةٍ يُقبل", () => {
  const english = {
    prompt: "Which animal gives us milk?",
    answer: "cow",
    distractors: ["lion", "eagle", "shark"],
  };
  assert.equal(parse([english], "English").accepted.length, 1);
  assert.equal(
    parse([{ ...english, distractors: ["lion", "نسر", "shark"] }], "English").rejected["لسانٌ آخر"],
    1,
  );
});

test("النسخُ: الموضوعُ نفسه ليس نسخاً، والجملةُ المنقولة نسخ", () => {
  assert.equal(copiedFromLesson("أي جزء من الجهاز الهضمي يطحن الطعام؟", LESSON), false);
  assert.equal(
    copiedFromLesson("تبدأ عملية الهضم في الفم حيث تقوم الأسنان؟", LESSON),
    true,
  );
  assert.equal(copiedFromLesson("المعدة؟", LESSON), false);
});

test("أقلُّ دفعةٍ تُكتب معقولة", () => {
  assert.ok(DOMAIN_MIN_ACCEPTED >= 3 && DOMAIN_MIN_ACCEPTED <= 8);
});

// ── صفوفُ الكتابة ──

test("الصفوفُ تحمل الدرسَ والمعلمَ والبصمة، والجوابُ أوّلاً", () => {
  const [row] = domainRows([good()], {
    id: "L1",
    subject: "العلوم",
    unit: "أجهزة الجسم",
    grade: "الصف الرابع",
    teacherId: "T-9",
    lessonText: LESSON,
  });
  assert.match(row.id, /^ai:science:[0-9a-z]+$/);
  assert.equal(row.subject_key, "science");
  assert.equal(row.grade_band, "high");
  assert.equal(row.category, "domain");
  assert.equal(row.source, "ai");
  assert.equal(row.active, true);
  assert.equal(row.lesson_id, "L1");
  assert.equal(row.teacher_id, "T-9");
  assert.equal(row.lesson_stamp, lessonStamp(LESSON));
  assert.deepEqual(row.choices, ["المعدة", "الرئة", "القلب", "الكلية"]);
});

test("المعرّفُ ثابتٌ للسؤال نفسه، ولا تغيّره الحركات", () => {
  const lesson = { id: "L1", subject: "العلوم", lessonText: LESSON };
  const a = domainRows([good()], lesson)[0].id;
  const b = domainRows([good({ prompt: "أيُّ عضوٍ يخزّن الطعامَ ويهضمه بعد البلع؟" })], lesson)[0].id;
  const c = domainRows([good()], { ...lesson, id: "L2" })[0].id;
  assert.equal(a, b);
  assert.equal(a, c, "السؤالُ نفسه في درسين من المادة نفسها يُكتب مرّة");
});

test("البصمةُ تتغيّر بتغيّر نصّ الدرس", () => {
  assert.equal(lessonStamp(LESSON), lessonStamp(LESSON));
  assert.notEqual(lessonStamp(LESSON), lessonStamp(LESSON + " "));
});

test("مالكُ الدرس بترتيب جسر المزامنة", () => {
  assert.equal(lessonOwner({ teacher_id: "A", teacherId: "B", createdBy: "C" }), "A");
  assert.equal(lessonOwner({ teacherId: "B", createdBy: "C" }), "B");
  assert.equal(lessonOwner({ createdBy: "C" }), "C");
  assert.equal(lessonOwner(null), "");
});

// ── الصلاحيات ──

const admin = { role: "admin" };
const teacher = { role: "teacher", teacherId: "T1" };
const subjects = new Set(["science"]);

test("المشرفُ يرى كلَّ سؤالٍ ويعطّله", () => {
  for (const question of [
    { teacher_id: null, subject_key: "*" },
    { teacher_id: "T2", subject_key: "math" },
    { teacher_id: "T1", subject_key: "science" },
  ]) {
    assert.equal(canToggleQuestion(admin, question), true);
    assert.equal(canSeeQuestion(admin, question, new Set()), true);
  }
});

test("المعلمُ يعطّل ما وُلّد من دروسه، ولا تفرّقه حالةُ الحروف", () => {
  assert.equal(canToggleQuestion(teacher, { teacher_id: "T1", subject_key: "science" }), true);
  assert.equal(canToggleQuestion(teacher, { teacher_id: "t1", subject_key: "science" }), true);
});

test("ولا يعطّل المشترك ولا ما وُلّد من دروس غيره", () => {
  assert.equal(canToggleQuestion(teacher, { teacher_id: null, subject_key: "science" }), false);
  assert.equal(canToggleQuestion(teacher, { teacher_id: "", subject_key: "*" }), false);
  assert.equal(canToggleQuestion(teacher, { teacher_id: "T2", subject_key: "science" }), false);
  assert.equal(canToggleQuestion(teacher, { teacher_id: "T1x", subject_key: "science" }), false);
});

test("والمعلمُ يرى المشتركَ في موادّه والعامّ، ولا يرى مادّةً ليست له", () => {
  assert.equal(canSeeQuestion(teacher, { teacher_id: null, subject_key: "science" }, subjects), true);
  assert.equal(canSeeQuestion(teacher, { teacher_id: null, subject_key: "*" }, subjects), true);
  assert.equal(canSeeQuestion(teacher, { teacher_id: "T2", subject_key: "science" }, subjects), true);
  assert.equal(canSeeQuestion(teacher, { teacher_id: null, subject_key: "math" }, subjects), false);
  assert.equal(canSeeQuestion(teacher, { teacher_id: "T2", subject_key: "math" }, subjects), false);
  // وما وُلّد من دروسه يراه ولو لم تبقَ المادّةُ في دروسه.
  assert.equal(canSeeQuestion(teacher, { teacher_id: "T1", subject_key: "math" }, subjects), true);
});

test("disabled_by يقول من عطّل", () => {
  assert.equal(disabledByOf(admin), "admin");
  assert.equal(disabledByOf(teacher), "teacher:T1");
});

test("تسويةُ المالك لا تحذف الرموز", () => {
  assert.equal(ownerKey(" Test "), "test");
  assert.notEqual(ownerKey("t-1"), ownerKey("t_1"));
  assert.equal(ownerKey("برداوى"), ownerKey("برداوي"));
});
