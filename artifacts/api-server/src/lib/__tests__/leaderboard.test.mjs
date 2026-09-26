/**
 * اختبارات ترتيب لوحة الصدارة.
 *
 * التشغيل:
 *   npm run build && node --test src/lib/__tests__/leaderboard.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";

const target = process.env.LEADERBOARD_MODULE ?? "../../../dist/lib/leaderboard.js";
let mod;
try {
  mod = await import(target);
} catch {
  console.log("تُخطّى: لم يُبنَ dist بعد (npm run build).");
  process.exit(0);
}

const { buildLeaderboard, isClassmate, ownerOf } = mod;

const student = (id, name, gems, xp = 0, extra = {}) => ({
  id,
  data: { id, name, gamification: { gems, xp, level: Math.floor(xp / 100) }, ...extra },
});

test("الزميل: المعلّم نفسه والصفّ نفسه", () => {
  const data = {
    teacherId: "teacher_1",
    grade: "الصف الرابع الابتدائي",
  };
  assert.equal(isClassmate(data, "teacher_1", "الصف الرابع الابتدائي"), true);
  assert.equal(isClassmate(data, "teacher_2", "الصف الرابع الابتدائي"), false);
  assert.equal(isClassmate(data, "teacher_1", "الصف الخامس الابتدائي"), false);
});

test("الهمزة لا تُخرج زميلاً من صفّه", () => {
  // «الصف الرابع الابتدائى» بالألف المقصورة، و«الإبتدائي» بالهمزة:
  // كلّها الصفّ نفسه، والترشيح الحرفيّ كان يُخرج نصف الفصل.
  const data = { teacherId: "TEACHER_1", grade: "الصف الرابع الابتدائى" };
  assert.equal(isClassmate(data, "teacher_1", "الصف الرابع الابتدائي"), true);
});

test("المالك يُقرأ بالترتيب الذي تقرؤه بقيّة المنظومة", () => {
  assert.equal(ownerOf({ teacher_id: "A", teacherId: "B", createdBy: "C" }), "a");
  assert.equal(ownerOf({ teacherId: "B", createdBy: "C" }), "b");
  assert.equal(ownerOf({ createdBy: "C" }), "c");
});

test("الترتيب بالجواهر تنازلياً، ومركز صاحب اللوحة يُحسب", () => {
  const board = buildLeaderboard(
    [
      student("s1", "سارة", 30),
      student("s2", "جوري", 50),
      student("s3", "محمد", 10),
    ],
    "s2",
  );
  assert.deepEqual(board.entries.map((e) => e.name), ["جوري", "سارة", "محمد"]);
  assert.deepEqual(board.entries.map((e) => e.rank), [1, 2, 3]);
  assert.equal(board.myRank, 1);
  assert.equal(board.total, 3);
  assert.equal(board.topGems, 50);
  assert.equal(board.entries[0].isMe, true);
});

test("المتساويان يشتركان في المركز، والذي يليهما يقفز", () => {
  const board = buildLeaderboard(
    [
      student("a", "أحمد", 20, 300),
      student("b", "بدر", 20, 100),
      student("c", "خالد", 5),
    ],
    "c",
  );
  assert.deepEqual(board.entries.map((e) => e.rank), [1, 1, 3]);
  assert.equal(board.myRank, 3);
});

test("التساوي يُفضّ بالخبرة ثم بالاسم، فلا يتبادلان المركزين بلا سبب", () => {
  const rows = [student("b", "بدر", 20, 100), student("a", "أحمد", 20, 300)];
  const first = buildLeaderboard(rows, "a").entries.map((e) => e.id);
  const reversed = buildLeaderboard([...rows].reverse(), "a").entries.map((e) => e.id);
  assert.deepEqual(first, reversed);
  // الأعلى خبرةً أوّلاً رغم تساوي الجواهر.
  assert.equal(first[0], "a");
});

test("الفارق عن المركز الذي فوقه لا عن المتصدّر", () => {
  // «تنقصك ثلاث جواهر لتتقدّم» تُحرّك طفلاً، و«تنقصك مئة» تُقعده.
  const board = buildLeaderboard(
    [
      student("top", "المتصدّر", 100),
      student("mid", "الوسط", 33),
      student("me", "أنا", 30),
    ],
    "me",
  );
  assert.equal(board.myRank, 3);
  assert.equal(board.gemsToNext, 3);
  assert.equal(board.topGems, 100);
});

test("المتصدّر لا فارق له", () => {
  const board = buildLeaderboard([student("me", "أنا", 40)], "me");
  assert.equal(board.myRank, 1);
  assert.equal(board.gemsToNext, 0);
});

test("القصّ لا يُفسد المركز ولا العدد", () => {
  const rows = Array.from({ length: 30 }, (_, index) =>
    student(`s${index}`, `طالب ${index}`, 100 - index),
  );
  const board = buildLeaderboard(rows, "s25", 10);
  assert.equal(board.entries.length, 10);
  assert.equal(board.total, 30);
  assert.equal(board.myRank, 26); // محسوبٌ قبل القصّ
});

test("طالبٌ لا سجلّ له في القائمة لا يكسر اللوحة", () => {
  const board = buildLeaderboard([student("a", "أحمد", 10)], "ghost");
  assert.equal(board.myRank, 0);
  assert.equal(board.gemsToNext, 0);
});

test("سجلٌّ بلا معرّف يُسقَط ولا يُعدّ", () => {
  const board = buildLeaderboard(
    [{ data: { name: "بلا معرّف", gamification: { gems: 99 } } }, student("a", "أحمد", 10)],
    "a",
  );
  assert.equal(board.total, 1);
  assert.equal(board.entries[0].name, "أحمد");
});

test("لا يخرج من اللوحة إلا ما تحتاجه", () => {
  const board = buildLeaderboard(
    [student("a", "أحمد", 10, 0, { username: "ahmad", password: "x", parentId: "p1" })],
    "a",
  );
  assert.deepEqual(Object.keys(board.entries[0]).sort(), [
    "appearance",
    "gems",
    "id",
    "isMe",
    "level",
    "name",
    "rank",
    "xp",
  ]);
});
