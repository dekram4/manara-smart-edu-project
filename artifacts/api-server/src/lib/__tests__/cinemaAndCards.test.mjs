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

test("قاعدة الطالب تُطابق أيّ معرّفٍ له (معرّف السجل أو معرّف الصف)", () => {
  const rules = [
    cards.ruleFromRecord({
      id: "student:row-7", scope: "student", student_id: "row-7", teacher_id: "test", cards: { meeting: false },
    }),
  ];
  // المعرّف المعتمد في الخادم غير معرّف الصفّ الذي يعرفه التطبيق.
  const result = cards.effectiveCards(rules, { ...student, id: "data-7", ids: ["row-7"] });
  assert.equal(result.meeting, false);
  assert.equal(cards.effectiveCards(rules, { ...student, id: "data-7" }).meeting, true);
});

// حالةُ سادن: استثناءٌ قديمٌ فتح كلَّ البطاقات، ثم أغلق المعلمُ اثنتين لصفّه كلّه.
test("القرارُ الأحدث يغلب: إغلاقُ المعلم لصفّه يصل طالباً له استثناءٌ أقدم", () => {
  const open = Object.fromEntries(cards.STUDENT_CARDS.map((card) => [card.id, true]));
  const oldException = cards.ruleFromRecord({
    id: cards.studentRuleId("s1"), scope: "student", student_id: "s1", teacher_id: "test",
    cards: open, updated_at: "2026-10-19T21:24:12.701Z",
  });
  const classClose = cards.ruleFromRecord({
    id: cards.classRuleId("test", "الصف الرابع"), scope: "class", teacher_id: "test", grade_id: "الصف الرابع",
    cards: { tutor: false, meeting: false }, updated_at: "2026-10-19T23:18:45.429Z",
  });
  const result = cards.effectiveCards([oldException, classClose], student);
  assert.equal(result.tutor, false);
  assert.equal(result.meeting, false);
  assert.equal(result.quiz, true);

  // واستثناءٌ يُحفظ بعد قرار الصفّ يغلبه، كما يتوقّع من حفظه.
  const newException = cards.ruleFromRecord({
    id: cards.studentRuleId("s1"), scope: "student", student_id: "s1", teacher_id: "test",
    cards: { tutor: true }, updated_at: "2026-10-20T08:00:00.000Z",
  });
  const later = cards.effectiveCards([classClose, newException], student);
  assert.equal(later.tutor, true);
  assert.equal(later.meeting, false);
});

// ── الحفظ في جدول cinema_videos وحده ─────────────────────────────────────

test("روابط YouTube العادية تصير روابط تضمين، وملف MP4 يبقى كما هو", () => {
  const id = "dQw4w9WgXcQ";
  for (const url of [
    `https://www.youtube.com/watch?v=${id}`,
    `https://youtube.com/watch?v=${id}&list=PL1`,
    `https://m.youtube.com/watch?v=${id}`,
    `https://youtu.be/${id}`,
    `https://www.youtube.com/shorts/${id}`,
    `https://www.youtube.com/live/${id}?si=abc`,
    `https://www.youtube.com/embed/${id}`,
    `https://www.youtube-nocookie.com/embed/${id}`,
  ]) {
    assert.equal(cinema.toEmbedUrl(url), `https://www.youtube.com/embed/${id}`, url);
  }
  assert.equal(cinema.toEmbedUrl(`https://youtu.be/${id}?t=90`), `https://www.youtube.com/embed/${id}?start=90`);
  assert.equal(cinema.toEmbedUrl(`https://www.youtube.com/watch?v=${id}&t=1m30s`), `https://www.youtube.com/embed/${id}?start=90`);
  const mp4 = "https://cdn.example.com/videos/lesson.mp4";
  assert.equal(cinema.toEmbedUrl(mp4), mp4);
  const built = cinema.buildCinemaVideo({ title: "ف", url: `https://youtu.be/${id}`, gradeId: "الصف الرابع" }, teacherTest, { newId });
  assert.equal(built.video.embedUrl, `https://www.youtube.com/embed/${id}`);
  assert.equal(built.video.sourceType, "embed");
  const file = cinema.buildCinemaVideo({ title: "ف", url: mp4, gradeId: "الصف الرابع" }, teacherTest, { newId });
  assert.equal(file.video.embedUrl, mp4);
  assert.equal(file.video.sourceType, "mp4");
});

/** جدولٌ مُنشأٌ بالأعمدة الأساسية وحدها، كما في Supabase. */
function fakeTable({ columns, idIsUuid = false, rls = false }) {
  const rows = new Map();
  const calls = [];
  const send = async (row, upsert) => {
    calls.push({ row: { ...row }, upsert });
    if (rls) throw { status: 403, body: JSON.stringify({ code: "42501", message: 'new row violates row-level security policy for table "cinema_videos"' }) };
    for (const column of Object.keys(row)) {
      if (!columns.includes(column)) {
        throw { status: 400, body: JSON.stringify({ code: "PGRST204", message: `Could not find the '${column}' column of 'cinema_videos' in the schema cache` }) };
      }
    }
    if (idIsUuid && !/^[0-9a-f-]{36}$/.test(row.id)) {
      throw { status: 400, body: JSON.stringify({ code: "22P02", message: `invalid input syntax for type uuid: "${row.id}"` }) };
    }
    rows.set(row.id, row);
  };
  return { rows, calls, send };
}
const isFailure = (error) => (error && typeof error.body === "string" ? error : null);

test("يُحفظ الفيديو صفّاً في جدول بالأعمدة الست الأساسية وحدها — لا ارتداد إلى app_kv", async () => {
  const core = ["id", "title", "embed_url", "grade_id", "teacher_id", "created_by"];
  const table = fakeTable({ columns: core });
  const absentColumns = new Set();
  const built = cinema.buildCinemaVideo(
    { title: "الكسور", url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ", gradeId: "الصف الرابع" },
    teacherTest,
    { newId: () => "11111111-1111-4111-8111-111111111111" },
  );
  const saved = await cinema.writeCinemaRow(built.video, table.send, { absentColumns, newId: () => "x", isFailure });
  const row = table.rows.get(saved.id);
  assert.deepEqual(Object.keys(row).sort(), [...core].sort());
  assert.equal(row.embed_url, "https://www.youtube.com/embed/dQw4w9WgXcQ");
  assert.equal(row.grade_id, "الصف الرابع");
  assert.equal(row.teacher_id, "test");
  assert.equal(row.created_by, "test");
  assert.equal(table.calls.at(-1).upsert, true);
  // ‏الحفظُ الثاني لا يجرّب الأعمدة الناقصة من جديد.
  const before = table.calls.length;
  await cinema.writeCinemaRow({ ...built.video, title: "معدّل" }, table.send, { absentColumns, newId: () => "x", isFailure });
  assert.equal(table.calls.length, before + 1);
  assert.equal(table.rows.get(saved.id).title, "معدّل");

  // ‏والجدولُ الكامل يأخذ الأعمدة كلَّها.
  const full = fakeTable({ columns: Object.keys(cinema.toTableRow(built.video)) });
  await cinema.writeCinemaRow(built.video, full.send, { absentColumns: new Set(), newId: () => "x", isFailure });
  assert.equal(full.rows.get(saved.id).source_type, "embed");
});

test("رفضُ RLS أو عمودٌ أساسيٌّ ناقص يُرمى برسالة Supabase، لا يُبتلع", async () => {
  const built = cinema.buildCinemaVideo({ title: "ف", url: "https://cdn.example.com/a.mp4", gradeId: "الصف الرابع" }, teacherTest, { newId });
  const rls = fakeTable({ columns: [], rls: true });
  await assert.rejects(
    cinema.writeCinemaRow(built.video, rls.send, { absentColumns: new Set(), newId, isFailure }),
    (error) => /row-level security/.test(error.body),
  );
  const text = cinema.describeSupabaseFailure(JSON.stringify({ code: "42501", message: "new row violates row-level security policy" }), 403);
  assert.match(text, /42501/);
  assert.match(text, /RLS/);
  assert.match(text, /service_role/);
  const noEmbed = fakeTable({ columns: ["id", "title", "grade_id", "teacher_id", "created_by"] });
  await assert.rejects(
    cinema.writeCinemaRow(built.video, noEmbed.send, { absentColumns: new Set(), newId, isFailure }),
    (error) => /embed_url/.test(error.body),
  );
});

test("فيديو قديم من app_kv يُنقل إلى الجدول عند تعديله — بمعرّف uuid جديد إن لزم", async () => {
  const legacy = cinema.fromLegacyRecord({ id: "legacy-7", title: "قديم", url: "https://youtu.be/dQw4w9WgXcQ", gradeId: "الصف الرابع", teacherId: "test" });
  const table = fakeTable({ columns: Object.keys(cinema.toTableRow(legacy)), idIsUuid: true });
  const saved = await cinema.writeCinemaRow(legacy, table.send, {
    absentColumns: new Set(),
    newId: () => "22222222-2222-4222-8222-222222222222",
    isFailure,
  });
  assert.equal(saved.id, "22222222-2222-4222-8222-222222222222");
  assert.equal(saved.legacy, false);
  assert.equal(table.calls.at(-1).upsert, false, "إدخالٌ لا تحديث");
  assert.ok(table.rows.has(saved.id));
});
