// اختبارُ تحويلات «تثبيت القاعدة النورانية» على بياناتٍ مثالية — بلا شبكة.
//   node --test scripts/split-noorania-subject.test.mjs
import assert from "node:assert/strict";
import test from "node:test";

import {
  NEW_LESSON,
  NEW_SUBJECT,
  NEW_TERM,
  NEW_UNIT,
  findTeacher,
  movedPath,
  namesIn,
  splitTree,
  updateFlat,
  updateStudent,
  updateTeacher,
  withOwner,
  withPath,
} from "./split-noorania-subject.mjs";

const kg = "روضة منارة المعرفة";
const teacherRows = [
  { id: "t_dawood", data: { id: "t_dawood", name: "داود سيد اكرام", username: "dawood" } },
  { id: "t_other", data: { id: "t_other", name: "معلمة أخرى", username: "other" } },
];
const dawood = findTeacher(teacherRows);

const quranOld = () => ({
  subject: "القرآن الكريم",
  terms: [
    { term: "حفظ السور القصيرة", units: ["جزء عم"], lessons: { "جزء عم": ["سورة الفاتحة", "سورة الناس"] } },
    {
      term: "تعليم القاعدة النورانية",
      units: ["القاعدة النورانية"],
      lessons: { "القاعدة النورانية": ["تعليم القراءة والقاعدة النورانية"] },
    },
  ],
});

/** كما في الواقع: القرآنُ في مدخل داود بمعرّفه، والمادّةُ التي أنشأها في مدخلٍ مالكُه اسمُه. */
const tree = () => [
  {
    grade: kg,
    teacherId: "t_dawood",
    subjects: [quranOld(), { subject: "العلوم", terms: [{ term: "الفصل الأول", units: ["النبات"], lessons: { النبات: ["الجذر"] } }] }],
  },
  { grade: kg, createdBy: "داود سيد اكرام", subjects: [{ subject: NEW_SUBJECT, terms: [] }] },
  // ‏صفٌّ آخر فيه «القرآن الكريم» بفصلٍ نورانيّ: لا يُمسّ — الروضةُ وحدها.
  {
    grade: "الصف الأول",
    createdBy: "t_other",
    subjects: [{ subject: "القرآن الكريم", terms: [{ term: "القاعدة النورانية", units: ["أ"], lessons: { أ: ["ب"] } }] }],
  },
];

test("المعلّم: يُعرف بمعرّفه واسمه واسم دخوله، ويُرفض الالتباس", () => {
  assert.equal(dawood.id, "t_dawood");
  assert.ok(dawood.identities.has("dawood"));
  assert.throws(() => findTeacher([...teacherRows, { id: "t2", data: { name: "داود سيد اكرام" } }]), /أكثرُ من معلّم/);
  assert.equal(findTeacher([...teacherRows, { id: "t2", data: { name: "داود سيد اكرام" } }], "t2").id, "t2");
  assert.throws(() => findTeacher([teacherRows[1]]), /لم يوجد/);
});

test("الشجرة: المادّةُ في مدخل داود بمعرّفه، بعد القرآن، وفيها الفصلُ والوحدةُ والدرس", () => {
  const { configs, moved, notes } = splitTree(tree(), dawood);
  const kgConfigs = configs.filter((c) => c.grade === kg);
  assert.equal(kgConfigs.length, 1, "مدخلُ اسمِه دُمج في مدخل معرّفه");
  assert.equal(kgConfigs[0].teacherId, "t_dawood");
  const subjects = kgConfigs[0].subjects;
  assert.deepEqual(subjects.map((s) => s.subject), ["القرآن الكريم", NEW_SUBJECT, "العلوم"]);
  assert.deepEqual(subjects[0].terms.map((t) => t.term), ["حفظ السور القصيرة"], "القرآن بلا نورانية");
  assert.deepEqual(subjects[1].terms, [{ term: NEW_TERM, units: [NEW_UNIT], lessons: { [NEW_UNIT]: [NEW_LESSON] } }]);
  assert.deepEqual(moved[0].lessons, [
    { term: "تعليم القاعدة النورانية", unit: "القاعدة النورانية", lesson: "تعليم القراءة والقاعدة النورانية", to: NEW_LESSON },
  ]);
  assert.ok(notes.some((n) => n.includes("دُمج")));
  // ‏الصف الأول كما هو.
  assert.deepEqual(configs.find((c) => c.grade === "الصف الأول"), tree()[2]);
});

test("مدخلُ داود مالكُه اسمُه وحده: يصير معرّفَه", () => {
  const t = tree();
  t[0].teacherId = "داود سيد اكرام";
  t.splice(1, 1);
  const { configs, notes } = splitTree(t, dawood);
  const home = configs.find((c) => c.grade === kg);
  assert.equal(home.teacher_id, "t_dawood");
  assert.equal(home.teacherId, "t_dawood");
  assert.ok(home.subjects.some((s) => s.subject === NEW_SUBJECT));
  assert.ok(notes.some((n) => n.includes("لا معرّفُه")));
});

test("القرآنُ في مدخل المشرف: تُنزع النورانيةُ منه، وتُبنى المادّةُ في مدخلٍ جديدٍ لداود", () => {
  const { configs } = splitTree([{ grade: kg, createdBy: "admin", subjects: [quranOld()] }], dawood);
  assert.deepEqual(configs[0].subjects[0].terms.map((t) => t.term), ["حفظ السور القصيرة"]);
  assert.equal(configs[1].teacher_id, "t_dawood");
  assert.equal(configs[1].grade, kg);
  assert.deepEqual(configs[1].subjects[0].terms[0].lessons[NEW_UNIT], [NEW_LESSON]);
});

test("ما أنشأه المعلّم في المادّة يبقى، ودروسٌ عدّة تبقى أسماؤها", () => {
  const t = tree();
  t[1].subjects[0].terms = [{ term: "مراجعة", units: ["الحروف"], lessons: { الحروف: ["حرف الألف"] } }];
  t[0].subjects[0].terms[1].lessons["القاعدة النورانية"].push("الدرس الثاني");
  const subject = splitTree(t, dawood).configs[0].subjects.find((s) => s.subject === NEW_SUBJECT);
  assert.deepEqual(subject.terms.map((x) => x.term), ["مراجعة", NEW_TERM]);
  assert.deepEqual(subject.terms[0].lessons.الحروف, ["حرف الألف"]);
  assert.deepEqual(subject.terms[1].lessons[NEW_UNIT], ["تعليم القراءة والقاعدة النورانية", "الدرس الثاني"]);
});

test("نسخةٌ فارغة في صفٍّ آخر تُحذف، ونسخةٌ فيها محتوى لغيره تبقى", () => {
  const t = tree();
  t[2].subjects.push({ subject: NEW_SUBJECT, terms: [] });
  t.push({ grade: "الصف الثاني", createdBy: "t_other", subjects: [{ subject: NEW_SUBJECT, terms: [{ term: "ف", units: ["و"], lessons: { و: ["د"] } }] }] });
  const { configs, notes } = splitTree(t, dawood);
  assert.ok(!configs.find((c) => c.grade === "الصف الأول").subjects.some((s) => s.subject === NEW_SUBJECT));
  assert.ok(configs.find((c) => c.grade === "الصف الثاني").subjects.some((s) => s.subject === NEW_SUBJECT));
  assert.ok(notes.some((n) => n.includes("بقيت مكانها")));
});

test("تشغيلٌ ثانٍ لا يكرّر ولا يغيّر شيئاً", () => {
  const once = splitTree(tree(), dawood).configs;
  const twice = splitTree(once, dawood);
  assert.equal(twice.moved.length, 0);
  assert.deepEqual(twice.configs, once);
});

test("الدرس: يتغيّر مسارُه ومالكُه وحدهما، ويبقى محتواه كلُّه ومعرّفُه", () => {
  const data = {
    grade: kg,
    subject: "القرآن الكريم",
    term: "تعليم القاعدة النورانية",
    unit: "القاعدة النورانية",
    lesson: "تعليم القراءة والقاعدة النورانية",
    title: "تعليم القراءة والقاعدة النورانية",
    teacher_id: "داود سيد اكرام",
    content: "نصّ الدرس",
    audio: ["a.mp3"],
    videos: [{ url: "https://x" }],
    games: [{ id: "g" }],
    challengeBank: { rounds: [1, 2] },
  };
  const renames = new Map([["تعليم القراءه والقاعده النورانيه", NEW_LESSON]]);
  const moved = withPath(data, movedPath(data, renames));
  const next = withOwner(moved, dawood);
  assert.equal(next.subject, NEW_SUBJECT);
  assert.equal(next.term, NEW_TERM);
  assert.equal(next.unit, NEW_UNIT);
  assert.equal(next.lesson, NEW_LESSON);
  assert.equal(next.title, NEW_LESSON);
  assert.equal(next.teacher_id, "t_dawood");
  for (const key of ["grade", "content", "audio", "videos", "games", "challengeBank"]) {
    assert.deepEqual(next[key], data[key], key);
  }
  assert.equal(withOwner({ teacher_id: "T_Dawood" }, dawood), null, "مالكُه معرّفُه من قبل");
  // ‏درسٌ من فصلٍ آخر أو صفٍّ آخر لا يُمسّ؛ ووحدةٌ نورانيةٌ تحت فصلٍ آخر تُنقل.
  assert.equal(movedPath({ ...data, term: "حفظ السور القصيرة", unit: "جزء عم" }, renames), null);
  assert.equal(movedPath({ ...data, grade: "الصف الأول" }, renames), null);
  assert.ok(movedPath({ ...data, term: "الفصل الأول" }, renames));
});

test("الطالب: طالبُ الروضة تُسند إليه المادّة، ويُنقل مسارُه المحفوظ", () => {
  const renames = new Map([["تعليم القراءه والقاعده النورانيه", NEW_LESSON]]);
  const next = updateStudent(
    {
      name: "جوري داود",
      grade: kg,
      assignedSubjects: ["القرآن الكريم", "العلوم"],
      lastPath: { grade: kg, subject: "القرآن الكريم", term: "تعليم القاعدة النورانية", unit: "القاعدة النورانية", lesson: "تعليم القراءة والقاعدة النورانية", lessonId: "L9" },
    },
    renames,
  );
  assert.deepEqual(next.assignedSubjects, ["القرآن الكريم", "العلوم", NEW_SUBJECT]);
  assert.equal(next.lastPath.subject, NEW_SUBJECT);
  assert.equal(next.lastPath.lesson, NEW_LESSON);
  assert.equal(next.lastPath.lessonId, "L9", "المعرّفُ لا يتغيّر");
  // ‏طالبُ صفٍّ آخر لا تُسند إليه.
  assert.equal(updateStudent({ grade: "الصف الأول", assignedSubjects: ["القرآن الكريم"] }, renames), null);
  assert.equal(updateStudent({ assignedSubjects: ["العلوم"] }, renames), null);
  // ‏كلُّ الموادّ مسموحة (قائمةٌ فارغة): تبقى كذلك.
  assert.equal(updateStudent({ assignedSubjects: [] }, renames), null);
  assert.equal(updateStudent({ assignedSubjects: ["القرآن الكريم", NEW_SUBJECT] }, renames), null);
});

test("المعلّم: تُضاف المادّةُ إلى موادّه مرّةً واحدة", () => {
  assert.deepEqual(updateTeacher({ subjects: ["القرآن الكريم"] }).subjects, ["القرآن الكريم", NEW_SUBJECT]);
  assert.deepEqual(updateTeacher({ subjects: [] }).subjects, [NEW_SUBJECT]);
  assert.equal(updateTeacher({ subjects: ["القرآن الكريم", NEW_SUBJECT] }), null);
  assert.equal(updateTeacher({ name: "بلا قائمة" }), null);
});

test("القوائم المسطّحة: يُضاف الجديد، ويُحذف اسمُ النورانية القديم الذي لم يبقَ", () => {
  const configs = splitTree(tree(), dawood).configs;
  const { terms, units } = namesIn(configs);
  assert.deepEqual(updateFlat(["الفصل الأول", "تعليم القاعدة النورانية"], NEW_TERM, terms), ["الفصل الأول", NEW_TERM]);
  // ‏«القاعدة النورانية» فصلٌ في الصف الأول ما زال: يبقى.
  assert.equal(updateFlat(["الفصل الأول", NEW_TERM], NEW_TERM, terms), null);
  assert.deepEqual(updateFlat(["جزء عم", "القاعدة النورانية"], NEW_UNIT, units), ["جزء عم", NEW_UNIT]);
  assert.deepEqual(updateFlat(["القرآن الكريم"], NEW_SUBJECT, new Set()), ["القرآن الكريم", NEW_SUBJECT]);
});
