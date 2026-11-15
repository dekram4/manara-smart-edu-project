import test from "node:test";
import assert from "node:assert/strict";
import {
  buildTeacherDirectory,
  chatTeacherByKey,
  studentTeacherKey,
  teacherKeyOf,
} from "../../../dist/lib/chatTeacher.mjs";

const teachers = [
  { id: "t-row-1", data: { id: "T1", username: "ahmad.t", name: "أحمد علي", teacherId: "1029384756" } },
  { id: "t-row-2", data: { id: "T2", username: "mona", name: "منى" } },
  { id: "t-row-3", data: { id: "T3", username: "mona2", name: "منى" } },
];
const hierarchy = [
  { grade: "الصف الرابع", teacher_id: "T1" },
  { grade: "الصف الخامس", teacherId: "ahmad.t" },
  { grade: "الصف الخامس", teacherId: "T2" },
  { grade: "الصف السادس", teacher_id: "admin" },
];
const parents = [{ id: "p1", data: { id: "P1", createdBy: "ahmad.t" } }];
const dir = buildTeacherDirectory(teachers, hierarchy, parents);

test("كلُّ اسمٍ يُعرف به المعلّمُ يُردّ إلى مفتاحٍ واحد", () => {
  for (const name of ["T1", "t1", "t-row-1", "ahmad.t", "AHMAD.T", "1029384756", "أحمد علي"]) {
    assert.equal(teacherKeyOf(dir, name), "t1", name);
  }
  assert.equal(chatTeacherByKey(dir, "t1").name, "أحمد علي");
  // ‏اسمٌ كامل يتقاسمه معلّمان لا يدلّ على أحدهما.
  assert.equal(teacherKeyOf(dir, "منى"), "مني");
  // ‏ومن لا يُعرف يبقى كما هو، فيعمل كما كان قبل الدليل.
  assert.equal(teacherKeyOf(dir, "Legacy"), "legacy");
});

test("الطالبُ يجد معلّمه بأي صورةٍ كُتب: teacherId أو createdBy أو وليُّ أمره", () => {
  assert.equal(studentTeacherKey(dir, { teacherId: "ahmad.t", grade: "الصف الرابع" }), "t1");
  assert.equal(studentTeacherKey(dir, { teacherId: "", createdBy: "T1", grade: "x" }), "t1");
  assert.equal(studentTeacherKey(dir, { teacherId: "", parentId: "P1", grade: "x" }), "t1");
  // ‏المشرفُ ليس معلّماً.
  assert.equal(studentTeacherKey(dir, { teacherId: "", createdBy: "admin", grade: "الصف الرابع" }), "t1");
});

test("بلا أيّ ربط: مالكُ الصفّ إن كان واحداً، ولا تخمين إن كانا اثنين", () => {
  assert.equal(studentTeacherKey(dir, { teacherId: "", grade: "الصف الرابع" }), "t1");
  assert.equal(studentTeacherKey(dir, { teacherId: "", grade: "الصف الرابع " }), "t1");
  assert.equal(studentTeacherKey(dir, { teacherId: "", grade: "الصف الخامس" }), "");
  assert.equal(studentTeacherKey(dir, { teacherId: "", grade: "الصف السادس" }), "");
});

test("بلا جدول معلّمين: يبقى المعرّفُ كما كُتب", () => {
  const empty = buildTeacherDirectory([]);
  assert.equal(studentTeacherKey(empty, { teacherId: "T1", grade: "g" }), "t1");
  assert.equal(studentTeacherKey(empty, { teacherId: "", grade: "g" }), "");
});
