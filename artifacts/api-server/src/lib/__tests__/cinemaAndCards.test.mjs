/**
 * اختبارات سينما منارة (مستقلّة عن الدروس) وصلاحيات بطاقات الطالب.
 *
 * التشغيل:
 *   npm run build && node --test src/lib/__tests__/cinemaAndCards.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";

const cinema = await import(process.env.CINEMA_MODULE ?? "../../../dist/lib/cinema.mjs");
const cards = await import(process.env.CARDS_MODULE ?? "../../../dist/lib/cardPermissions.mjs");

const teacherTest = { role: "teacher", teacherId: "test" };
const admin = { role: "admin" };
let counter = 0;
const newId = () => `v${++counter}`;

// ── السينما ────────────────────────────────────────────────────────────

test("الفيديو يُرى بصفّ الطالبة ومعلّمها، أيّاً كان درسها", () => {
  const built = cinema.buildCinemaVideo(
    { title: "الكسور", url: "https://www.youtube.com/watch?v=x", gradeId: "الصف الرابع" },
    teacherTest,
    { newId },
  );
  assert.equal(built.ok, true);
  const video = built.video;
  assert.equal(video.teacherId, "test");
  assert.equal(video.createdBy, "test");

  // «جوري» طالبة المعلم test في الصف الرابع — بهمزةٍ مختلفة في الصف.
  const jouri = { grade: "الصف الرابع", teacherIdentities: new Set(["test"]) };
  assert.equal(cinema.isVisibleToStudent(video, jouri), true);

  const otherGrade = { grade: "الصف الخامس", teacherIdentities: new Set(["test"]) };
  assert.equal(cinema.isVisibleToStudent(video, otherGrade), false);

  const otherTeacher = { grade: "الصف الرابع", teacherIdentities: new Set(["sara"]) };
  assert.equal(cinema.isVisibleToStudent(video, otherTeacher), false);
});

test("الصف يُطابَق بتسوية عربية", () => {
  const video = cinema.fromLegacyRecord({
    id: "a", url: "https://e.com/v", grade: "الصف الأول", teacher_id: "Test",
  });
  assert.equal(
    cinema.isVisibleToStudent(video, { grade: "الصف الاول", teacherIdentities: new Set(["test"]) }),
    true,
  );
});

test("المشرف يُلزَم بالصف والمعلم المسؤول", () => {
  const noGrade = cinema.buildCinemaVideo({ url: "https://e.com/v", teacherId: "t1" }, admin, { newId });
  assert.equal(noGrade.ok, false);
  assert.match(noGrade.error, /الصف/);

  const noTeacher = cinema.buildCinemaVideo({ url: "https://e.com/v", gradeId: "g" }, admin, { newId });
  assert.equal(noTeacher.ok, false);
  assert.match(noTeacher.error, /المعلم/);

  const ok = cinema.buildCinemaVideo(
    { url: "https://e.com/v", gradeId: "g", teacherId: "t1" }, admin, { newId },
  );
  assert.equal(ok.ok, true);
  assert.equal(ok.video.createdBy, "admin");
  assert.equal(ok.video.teacherId, "t1");
});

test("المعلم لا يُسند فيديو لمعلم آخر", () => {
  const result = cinema.buildCinemaVideo(
    { url: "https://e.com/v", gradeId: "g", teacherId: "other" }, teacherTest, { newId },
  );
  assert.equal(result.ok, false);
  assert.equal(result.status, 403);
});

test("روابط غير http(s) تُرفض", () => {
  assert.equal(cinema.isSafeCinemaUrl("javascript:alert(1)"), false);
  assert.equal(cinema.isSafeCinemaUrl("//evil.com/x"), false);
  assert.equal(cinema.isSafeCinemaUrl("data:text/html,x"), false);
  assert.equal(cinema.isSafeCinemaUrl("https://youtu.be/x"), true);
  assert.equal(cinema.isSafeCinemaUrl("/api/media/videos/a.mp4"), true);
});

test("الجدول يغلب المفتاح القديم، والمحذوف لا يعود", () => {
  const legacy = [
    cinema.fromLegacyRecord({ id: "1", url: "https://e.com/old", grade: "g", teacher_id: "t" }),
    cinema.fromLegacyRecord({ id: "2", url: "https://e.com/2", grade: "g", teacher_id: "t" }),
    cinema.fromLegacyRecord({ id: "3", url: "https://e.com/3", grade: "g", teacher_id: "t" }),
  ];
  const table = [
    cinema.fromTableRow({ id: "1", embed_url: "https://e.com/new", grade_id: "g", teacher_id: "t", created_by: "t" }),
  ];
  const merged = cinema.mergeCinemaVideos(table, legacy, ["3"]);
  assert.deepEqual(merged.map((v) => v.id).sort(), ["1", "2"]);
  assert.equal(merged.find((v) => v.id === "1").embedUrl, "https://e.com/new");
});

test("السجل القديم يُحفظ بحقوله القديمة والجديدة معاً", () => {
  const built = cinema.buildCinemaVideo(
    { url: "https://e.com/v.mp4", gradeId: "g", teacherId: "t1" }, admin, { newId },
  );
  const record = cinema.toLegacyRecord(built.video);
  assert.equal(record.grade, "g");
  assert.equal(record.teacher_id, "t1");
  assert.equal(record.url, "https://e.com/v.mp4");
  assert.equal(record.sourceType, "mp4");
  assert.equal(record.created_by, "admin");
});

// ── صلاحيات البطاقات ──────────────────────────────────────────────────

const student = { id: "s1", grade: "الصف الرابع", teacherIdentities: new Set(["test"]) };

test("بلا قواعد: كل البطاقات مفتوحة", () => {
  const result = cards.effectiveCards([], student);
  for (const card of cards.STUDENT_CARDS) assert.equal(result[card.id], true);
});

test("قاعدة الصف تُغلق، وقاعدة الطالب تغلبها", () => {
  const rules = [
    cards.ruleFromRecord({
      id: cards.classRuleId("test", "الصف الرابع"), scope: "class",
      teacher_id: "test", grade_id: "الصف الرابع", cards: { tutor: false, cinema: false },
    }),
    cards.ruleFromRecord({
      id: cards.studentRuleId("s1"), scope: "student",
      student_id: "s1", teacher_id: "test", cards: { cinema: true },
    }),
  ];
  const result = cards.effectiveCards(rules, student);
  assert.equal(result.tutor, false);
  assert.equal(result.cinema, true);
  assert.equal(result.lesson, true);

  const classmate = cards.effectiveCards(rules, { ...student, id: "s2" });
  assert.equal(classmate.cinema, false);
});

test("قاعدة صف معلم آخر أو صف آخر لا تمسّ الطالب", () => {
  const rules = [
    cards.ruleFromRecord({
      id: "class:x:y", scope: "class", teacher_id: "other", grade_id: "الصف الرابع", cards: { quiz: false },
    }),
    cards.ruleFromRecord({
      id: "class:test:z", scope: "class", teacher_id: "test", grade_id: "الصف الخامس", cards: { quiz: false },
    }),
  ];
  assert.equal(cards.effectiveCards(rules, student).quiz, true);
});

test("بطاقات غير معروفة وقيم غير منطقية تُسقط", () => {
  assert.deepEqual(cards.sanitizeCards({ tutor: false, hack: false, cinema: "no" }), { tutor: false });
});
