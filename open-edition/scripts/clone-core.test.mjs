/**
 * الاستنساخ: يُنسخ ما يملكه المعلم وحده، وتُستبدل هويّتُه في كل موضع.
 *
 * التشغيل: node --test open-edition/scripts/clone-core.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";
import { buildClone, flatLists, ownedBy, normalizeOwner, renderSeedSql, rewriteIdentity, summarize } from "./clone-core.mjs";

const SRC = "teacher_1792324373418";
const NAME = "داود سيد اكرام";
const target = { id: "teacher_open_kg_dawood", name: "معلم الروضة داود سيد" };

function fixture() {
  return {
    teacher: { id: SRC, data: { id: SRC, teacherId: SRC, name: NAME, username: "dekram", password: "scrypt$x$y", permissionPackageId: "pkg1" } },
    lessonConfigs: [
      { id: "l1", data: { id: "l1", grade: "روضة", teacherId: SRC, createdBy: SRC, createdByName: NAME, lesson: "الألف" } },
      { id: "l2", data: { id: "l2", grade: "الرابع", teacherId: "teacher_other", createdBy: "teacher_other", lesson: "الخلية" } },
    ],
    createdQuizzes: [
      { id: "q1", data: { id: "q1", createdBy: SRC, lessonId: "l1" } },
      { id: "q2", data: { id: "q2", createdBy: "teacher_other" } },
    ],
    kv: {
      smartEdu_hierarchicalConfigs: [
        { grade: "روضة", teacher_id: SRC, createdByName: NAME, subjects: [{ subject: "الحروف", terms: [{ term: "الأول", units: ["الألف"] }] }] },
        { grade: "الرابع", teacher_id: "teacher_other", subjects: [] },
        { grade: "الرابع", teacherId: "admin", subjects: [] },
      ],
      smartEdu_videos: [{ id: "v1", teacherId: SRC }, { id: "v2", teacherId: "teacher_other" }],
      smartEdu_cardPermissions: [{ id: `class:${SRC}:روضة`, teacher_id: SRC }, { id: "class:teacher_other:الرابع", teacher_id: "teacher_other" }],
      smartEdu_grades: ["روضة", "الرابع"],
      smartEdu_adminSettings: { chatEnabled: true },
      smartEdu_permissionPackages: [{ id: "pkg1", name: "حزمته" }, { id: "pkg2", name: "غيره" }],
      smartEdu_deletedLessons: ["x"],
      smartEdu_studentApkUrl: { url: "https://old" },
    },
    cinemaVideos: [{ id: "c1", teacher_id: NAME, created_by: NAME, title: "فيلم" }, { id: "c2", teacher_id: "teacher_other", title: "غيره" }],
    entertainmentGames: [{ id: "g1", teacher_id: SRC, teacher_name: NAME }, { id: "g2", teacher_id: "teacher_other" }],
    duelQuestions: [{ id: "d1", teacher_id: SRC }, { id: "d2", teacher_id: null }, { id: "d3", teacher_id: "teacher_other" }],
    now: "2026-11-24T00:00:00.000Z",
  };
}

test("التسويةُ كما في الخادم", () => {
  assert.equal(normalizeOwner("  داوود سيد إكرام "), normalizeOwner("داوود سيد اكرام"));
  assert.equal(normalizeOwner("مدرسة"), "مدرسه");
});

test("الملكيةُ بأيّ حقلٍ للمالك", () => {
  const ids = new Set([SRC, NAME].map(normalizeOwner));
  assert.ok(ownedBy({ teacherId: SRC }, ids));
  assert.ok(ownedBy({ teacher_id: NAME }, ids));
  assert.ok(ownedBy({ createdBy: SRC }, ids));
  assert.ok(!ownedBy({ teacherId: "teacher_other" }, ids));
  assert.ok(!ownedBy(null, ids));
});

test("استبدالُ الهوية: المعرّفُ أينما كان، والاسمُ حين يكون القيمةَ كلَّها", () => {
  const swap = { fromId: SRC, toId: target.id, fromName: NAME, toName: target.name };
  assert.deepEqual(
    rewriteIdentity({ a: SRC, b: `class:${SRC}:روضة`, c: NAME, d: `درسٌ أعدّه ${NAME}`, [SRC]: 1, n: 5 }, swap),
    { a: target.id, b: `class:${target.id}:روضة`, c: target.name, d: `درسٌ أعدّه ${NAME}`, [target.id]: 1, n: 5 },
  );
});

test("يُنسخ ما للمعلم وحده، بهويته الجديدة", () => {
  const rows = buildClone(fixture(), target);
  assert.deepEqual(summarize(rows), {
    teachers: 1, lesson_configs: 1, created_quizzes: 1, cinema_videos: 1, entertainment_games: 1, duel_questions: 2, app_kv: rows.app_kv.length,
  });
  const [teacher] = rows.teachers;
  assert.equal(teacher.id, target.id);
  assert.equal(teacher.data.name, target.name);
  assert.equal(teacher.data.teacherId, target.id);
  assert.equal(teacher.data.username, "dekram", "يدخل باسم دخوله نفسه");
  assert.equal(teacher.data.password, "scrypt$x$y", "وبكلمة مروره نفسها");
  assert.equal(teacher.data.clonedFrom.id, SRC);
  assert.equal(rows.lesson_configs[0].id, "l1", "معرّفُ الدرس كما هو");
  assert.equal(rows.lesson_configs[0].data.teacherId, target.id);
  assert.equal(rows.lesson_configs[0].data.createdByName, target.name);
  assert.equal(rows.created_quizzes[0].data.lessonId, "l1", "ورابطُ الاختبار بدرسه سليم");
  assert.equal(rows.cinema_videos[0].teacher_id, target.name);
  assert.deepEqual(rows.duel_questions.map((q) => q.id), ["d1", "d2"], "أسئلتُه والبنكُ العامّ، لا أسئلةُ غيره");
  assert.equal(rows.duel_questions[0].teacher_id, target.id);
  const { clonedFrom, ...rest } = teacher.data;
  const json = JSON.stringify({ ...rows, teachers: [{ ...teacher, data: rest }] });
  assert.ok(!json.includes(SRC), "لا أثرَ للمعرّف القديم إلا في سجلّ المصدر (clonedFrom)");
  assert.ok(!json.includes("teacher_other"), "ولا لمحتوى غيره");
});

test("app_kv: شجرتُه وقوائمُها، وحزمةُ صلاحياته، والإعداداتُ العامّة — لا قوائمُ الحذف ولا رابطُ التطبيق القديم", () => {
  const kv = Object.fromEntries(buildClone(fixture(), target).app_kv.map((r) => [r.key, r.value]));
  assert.equal(kv.smartEdu_hierarchicalConfigs.length, 1);
  assert.equal(kv.smartEdu_hierarchicalConfigs[0].teacher_id, target.id);
  assert.deepEqual(kv.smartEdu_grades, ["روضة"]);
  assert.deepEqual(kv.smartEdu_subjects, ["الحروف"]);
  assert.deepEqual(kv.smartEdu_units, ["الألف"]);
  assert.deepEqual(kv.smartEdu_videos.map((v) => v.id), ["v1"]);
  assert.deepEqual(kv.smartEdu_cardPermissions.map((p) => p.id), [`class:${target.id}:روضة`]);
  assert.deepEqual(kv.smartEdu_permissionPackages.map((p) => p.id), ["pkg1"]);
  assert.deepEqual(kv.smartEdu_adminSettings, { chatEnabled: true });
  assert.equal(kv.smartEdu_deletedLessons, undefined);
  assert.equal(kv.smartEdu_studentApkUrl, undefined);
});

test("القوائمُ المسطّحة من الشجرة", () => {
  assert.deepEqual(flatLists([{ grade: "أ", subjects: ["س", { subject: "ص", terms: [{ term: "ف", units: ["و", "و"] }] }] }]), {
    smartEdu_grades: ["أ"], smartEdu_subjects: ["س", "ص"], smartEdu_terms: ["ف"], smartEdu_units: ["و"],
  });
});

test("SQL: معاملةٌ واحدة، وupsert يُعاد بلا تكرار، والنصوصُ مقتبسةٌ بأمان", () => {
  const rows = buildClone(fixture(), target);
  rows.lesson_configs[0].data.lesson = "درس 'الألف' $x$";
  const sql = renderSeedSql(rows, { fromId: SRC, fromName: NAME, toId: target.id, toName: target.name });
  assert.match(sql, /^begin;$/m);
  assert.match(sql, /^commit;$/m);
  assert.ok(sql.includes("insert into public.lesson_configs (id, data) values ('l1', $manara_open$"));
  assert.ok(sql.includes("on conflict (id) do update set data = excluded.data"));
  assert.ok(sql.includes("on conflict (key) do update set value = excluded.value"));
  assert.ok(sql.includes("jsonb_populate_record(null::public.cinema_videos"));
  assert.ok(sql.includes(`"title" = excluded."title"`));
  assert.ok(!sql.includes("teacher_other"));
  assert.throws(() => renderSeedSql({ ...rows, app_kv: [{ key: "k", value: "$manara_open$" }] }, { fromId: SRC, fromName: NAME, toId: target.id, toName: target.name }));
});
