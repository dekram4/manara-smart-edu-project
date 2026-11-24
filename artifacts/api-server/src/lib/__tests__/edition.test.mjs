/**
 * «النسخة المفتوحة»: لا أثرَ لها في النسخة العادية، وفي المفتوحة تُغلق
 * بوابتا المشرف ووليّ الأمر، ويُنشأ للطالب حسابٌ في صفّ المعلم الوحيد.
 *
 * التشغيل: node ./build.mjs && node --test src/lib/__tests__/edition.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";

const edition = await import(process.env.EDITION_MODULE ?? "../../../dist/lib/edition.mjs");

const OPEN = { MANARA_EDITION: "open", OPEN_TEACHER_ID: "teacher_open_kg" };

test("بلا MANARA_EDITION فالنسخةُ عادية — حالُ النشر الحالي", () => {
  assert.equal(edition.editionOf({}), "standard");
  assert.equal(edition.isOpenEdition({}), false);
  assert.equal(edition.editionOf({ MANARA_EDITION: "" }), "standard");
  assert.equal(edition.editionOf({ MANARA_EDITION: "standard" }), "standard");
  assert.equal(edition.editionOf({ MANARA_EDITION: "opened" }), "standard", "قيمةٌ غيرُ مطابقة لا تفتح شيئاً");
});

test("MANARA_EDITION=open يفعّل النسخة المفتوحة، بأيّ حالةٍ للحروف", () => {
  assert.equal(edition.editionOf(OPEN), "open");
  assert.equal(edition.editionOf({ MANARA_EDITION: " OPEN " }), "open");
  assert.equal(edition.openTeacherId(OPEN), "teacher_open_kg");
});

test("المفتوحةُ تُغلق بوابتي المشرف ووليّ الأمر وحسابي العرض", () => {
  assert.ok(edition.openEditionBlock("POST", "/auth/admin"));
  assert.ok(edition.openEditionBlock("post", "/auth/admin/"));
  assert.ok(edition.openEditionBlock("POST", "/auth/parent/login"));
  assert.ok(edition.openEditionBlock("POST", "/auth/parent/change-password"));
  assert.ok(edition.openEditionBlock("POST", "/auth/student/demo"));
});

test("وتُبقي دخولَ المعلم والطالب وكلَّ ما سواهما", () => {
  for (const [method, path] of [
    ["POST", "/auth/teacher/login"],
    ["POST", "/auth/teacher/session"],
    ["POST", "/auth/student/session"],
    ["GET", "/auth/admin/session"],
    ["GET", "/auth/whoami"],
    ["POST", "/auth/logout"],
    ["GET", "/student/me"],
    ["POST", "/supabase/rest"],
    ["GET", "/edition"],
    ["POST", "/open/student"],
  ]) {
    assert.equal(edition.openEditionBlock(method, path), null, `${method} ${path}`);
  }
});

test("دخولُ المعلم: الاسمُ المضبوط وحده، وبلا ضبطٍ كلُّ من في القاعدة", () => {
  assert.equal(edition.teacherLoginAllowed("anyone", OPEN), true);
  const only = { ...OPEN, OPEN_TEACHER_USERNAME: "dekram" };
  assert.equal(edition.teacherLoginAllowed("dekram", only), true);
  assert.equal(edition.teacherLoginAllowed(" DEKRAM ", only), true);
  assert.equal(edition.teacherLoginAllowed("b", only), false);
  assert.equal(edition.teacherLoginAllowed(undefined, only), false);
  assert.equal(edition.isTeacherLoginPath("POST", "/auth/teacher/login"), true);
  assert.equal(edition.isTeacherLoginPath("POST", "/auth/teacher/session"), true);
  assert.equal(edition.isTeacherLoginPath("POST", "/auth/teacher/logout"), false);
});

test("اسمُ الطالب يُنظَّف ويُقصَر، والفارغُ يُرفض", () => {
  assert.equal(edition.cleanStudentName("  سارة   أحمد "), "سارة أحمد");
  assert.equal(edition.cleanStudentName("<b>علي</b>"), "bعلي/b");
  assert.equal(edition.cleanStudentName("   "), "");
  assert.equal(edition.cleanStudentName("123 !!"), "", "لا حرف فيه");
  assert.equal(edition.cleanStudentName(42), "");
  assert.ok(edition.cleanStudentName("م".repeat(100)).length <= edition.OPEN_NAME_MAX);
});

test("صفوفُ المعلم من شجرته وحده", () => {
  const hierarchy = [
    { grade: "الصف الرابع", teacherId: "admin" },
    { grade: "روضة منارة المعرفة", teacher_id: "teacher_open_kg" },
    { grade: "روضة منارة المعرفة", createdBy: "teacher_open_kg" },
    { grade: "الصف الأول", teacher_id: "teacher_other" },
    null,
  ];
  assert.deepEqual(edition.openGradesFrom(hierarchy, "teacher_open_kg"), ["روضة منارة المعرفة"]);
  assert.deepEqual(edition.openGradesFrom(hierarchy, ""), []);
  assert.deepEqual(edition.openGradesFrom(null, "teacher_open_kg"), []);
});

test("حسابُ الطالب الذاتي: في صفّ المعلم، وكلمةُ مروره مخزّنةٌ بصمةً لا نصّاً", () => {
  let n = 0;
  const random = (bytes) => Buffer.alloc(bytes, ++n);
  const student = edition.buildOpenStudent({
    name: "سارة",
    grade: "روضة منارة المعرفة",
    teacher: { id: "teacher_open_kg", name: "معلم الروضة داود سيد" },
    gender: "female",
    now: new Date("2026-11-24T10:00:00.000Z"),
    hash: (plain) => `hashed:${plain}`,
    random,
  });
  assert.match(student.username, /^open_[0-9a-f]{10}$/);
  assert.ok(student.password.length >= 20);
  assert.equal(student.data.password, `hashed:${student.password}`);
  assert.notEqual(student.data.password, student.password);
  assert.equal(student.data.id, student.id);
  assert.equal(student.data.teacherId, "teacher_open_kg");
  assert.equal(student.data.createdBy, "teacher_open_kg");
  assert.equal(student.data.createdByName, "معلم الروضة داود سيد");
  assert.equal(student.data.grade, "روضة منارة المعرفة");
  assert.equal(student.data.primaryGrade, "روضة منارة المعرفة");
  assert.equal(student.data.gender, "female");
  assert.equal(student.data.canChangeGrade, false);
  assert.equal(student.data.selfRegistered, true);
  assert.match(student.id, /^1795\d+$/);
});

test("كلُّ تسجيلٍ باسمٍ وكلمة مرورٍ جديدين", () => {
  const make = () => edition.buildOpenStudent({
    name: "علي",
    grade: "روضة",
    teacher: { id: "t", name: "م" },
    hash: (p) => p,
  });
  const a = make();
  const b = make();
  assert.notEqual(a.username, b.username);
  assert.notEqual(a.password, b.password);
  assert.equal(a.data.gender, "male");
});
