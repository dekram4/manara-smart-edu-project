// اختبارُ تحويلات «فصل القاعدة النورانية» على بياناتٍ مثالية — بلا شبكة.
//   node --test scripts/split-noorania-subject.test.mjs
import assert from "node:assert/strict";
import test from "node:test";

import {
  NEW_LESSON,
  NEW_SUBJECT,
  NEW_TERM,
  NEW_UNIT,
  movedPath,
  splitTree,
  updateStudent,
  updateTeacher,
  withPath,
} from "./split-noorania-subject.mjs";

const kg = "روضة منارة المعرفة";
const tree = () => [
  {
    grade: kg,
    teacherId: "teacher_dawood",
    subjects: [
      {
        subject: "القرآن الكريم",
        terms: [
          { term: "حفظ السور القصيرة", units: ["جزء عم"], lessons: { "جزء عم": ["سورة الفاتحة", "سورة الناس"] } },
          { term: "تعليم القاعدة النورانية", units: ["الحروف"], lessons: { الحروف: ["الدرس الأول"] } },
        ],
      },
      { subject: "العلوم", terms: [{ term: "الفصل الأول", units: ["النبات"], lessons: { النبات: ["الجذر"] } }] },
    ],
  },
  // ‏صفٌّ آخر فيه «القرآن الكريم» بفصلٍ نورانيّ: لا يُمسّ — الروضةُ وحدها.
  {
    grade: "الصف الأول",
    subjects: [{ subject: "القرآن الكريم", terms: [{ term: "القاعدة النورانية", units: ["أ"], lessons: { أ: ["ب"] } }] }],
  },
];

test("الشجرة: يُنزع الفصلُ من القرآن وتُضاف المادّةُ بفصلٍ ووحدةٍ ودرس", () => {
  const { configs, moved } = splitTree(tree());
  const subjects = configs[0].subjects;
  assert.deepEqual(subjects.map((s) => s.subject), ["القرآن الكريم", NEW_SUBJECT, "العلوم"]);
  assert.deepEqual(subjects[0].terms.map((t) => t.term), ["حفظ السور القصيرة"], "القرآن بفصلٍ واحد");
  assert.deepEqual(subjects[1].terms, [{ term: NEW_TERM, units: [NEW_UNIT], lessons: { [NEW_UNIT]: [NEW_LESSON] } }]);
  assert.equal(moved.length, 1);
  assert.equal(moved[0].owner, "teacher_dawood");
  assert.deepEqual(moved[0].lessons, [{ term: "تعليم القاعدة النورانية", unit: "الحروف", lesson: "الدرس الأول", to: NEW_LESSON }]);
  // ‏الصف الأول كما هو.
  assert.deepEqual(configs[1], tree()[1]);
});

test("دروسٌ عدّة في الفصل: تبقى أسماؤها، ولا يُدمج درسان في درس", () => {
  const t = tree();
  t[0].subjects[0].terms[1].lessons = { الحروف: ["الدرس الأول", "الدرس الثاني"] };
  const { configs, moved } = splitTree(t);
  assert.deepEqual(configs[0].subjects[1].terms[0].lessons[NEW_UNIT], ["الدرس الأول", "الدرس الثاني"]);
  assert.deepEqual(moved[0].lessons.map((l) => l.to), ["الدرس الأول", "الدرس الثاني"]);
});

test("تشغيلٌ ثانٍ لا يكرّر ولا يغيّر شيئاً", () => {
  const once = splitTree(tree()).configs;
  const twice = splitTree(once);
  assert.equal(twice.moved.length, 0);
  assert.deepEqual(twice.configs, once);
});

test("الدرس: يتغيّر مسارُه وحده، ويبقى محتواه كلُّه ومعرّفُه", () => {
  const data = {
    grade: kg,
    subject: "القرآن الكريم",
    term: "تعليم القاعدة النورانية",
    unit: "الحروف",
    lesson: "الدرس الأول",
    title: "الدرس الأول",
    teacher_id: "teacher_dawood",
    content: "نصّ الدرس",
    audio: ["a.mp3"],
    videos: [{ url: "https://x" }],
    games: [{ id: "g" }],
    challengeBank: { rounds: [1, 2] },
  };
  const renames = new Map([["الدرس الاول", NEW_LESSON]]);
  const path = movedPath(data, renames);
  const next = withPath(data, path);
  assert.equal(next.subject, NEW_SUBJECT);
  assert.equal(next.term, NEW_TERM);
  assert.equal(next.unit, NEW_UNIT);
  assert.equal(next.lesson, NEW_LESSON);
  assert.equal(next.title, NEW_LESSON);
  for (const key of ["grade", "teacher_id", "content", "audio", "videos", "games", "challengeBank"]) {
    assert.deepEqual(next[key], data[key], key);
  }
  // ‏درسٌ من فصلٍ آخر أو صفٍّ آخر لا يُمسّ.
  assert.equal(movedPath({ ...data, term: "حفظ السور القصيرة" }, renames), null);
  assert.equal(movedPath({ ...data, grade: "الصف الأول" }, renames), null);
});

test("الطالب: تُسند إليه المادّةُ الجديدة، ويُنقل مسارُه المحفوظ", () => {
  const renames = new Map([["الدرس الاول", NEW_LESSON]]);
  const next = updateStudent(
    {
      name: "جوري داود",
      grade: kg,
      assignedSubjects: ["القرآن الكريم", "العلوم"],
      lastPath: { grade: kg, subject: "القرآن الكريم", term: "تعليم القاعدة النورانية", unit: "الحروف", lesson: "الدرس الأول", lessonId: "L9" },
    },
    renames,
  );
  assert.deepEqual(next.assignedSubjects, ["القرآن الكريم", "العلوم", NEW_SUBJECT]);
  assert.equal(next.lastPath.subject, NEW_SUBJECT);
  assert.equal(next.lastPath.lesson, NEW_LESSON);
  assert.equal(next.lastPath.lessonId, "L9", "المعرّفُ لا يتغيّر");
  // ‏طالبٌ بلا قرآنٍ ولا مسارٍ فيه: لا تغيير.
  assert.equal(updateStudent({ assignedSubjects: ["العلوم"] }, renames), null);
  // ‏كلُّ الموادّ مسموحة (قائمةٌ فارغة): تبقى كذلك.
  assert.equal(updateStudent({ assignedSubjects: [] }, renames), null);
  // ‏أُسندت إليه من قبل: لا تُكرَّر.
  assert.equal(updateStudent({ assignedSubjects: ["القرآن الكريم", NEW_SUBJECT] }, renames), null);
});

test("المعلّم: من كانت له «القرآن الكريم» تُضاف إليه المادّة", () => {
  assert.deepEqual(updateTeacher({ subjects: ["القرآن الكريم"] }).subjects, ["القرآن الكريم", NEW_SUBJECT]);
  assert.equal(updateTeacher({ subjects: ["العلوم"] }), null);
  assert.equal(updateTeacher({ subjects: ["القرآن الكريم", NEW_SUBJECT] }), null);
});
