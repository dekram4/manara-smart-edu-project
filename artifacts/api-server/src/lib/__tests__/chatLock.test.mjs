import test from "node:test";
import assert from "node:assert/strict";
import {
  applyLockChange,
  CHAT_LOCK_TYPE,
  CHAT_LOCKED_MESSAGE,
  chatLockRowId,
  emptyLock,
  isLockedFor,
  readChatLock,
} from "../../../dist/lib/chatLock.mjs";

const now = new Date("2026-11-15T10:00:00Z");

test("قفلُ طالبٍ بعينه لا يمسّ زملاءه، وفتحُه يعيده", () => {
  const locked = applyLockChange(emptyLock(), { studentId: "s1", locked: true }, now);
  assert.equal(isLockedFor(locked, "s1"), true);
  assert.equal(isLockedFor(locked, "s2"), false);
  const opened = applyLockChange(locked, { studentId: "s1", locked: false }, now);
  assert.equal(isLockedFor(opened, "s1"), false);
});

test("قفلُ الجميع يقفل كلَّ طالب، وفتحُ الجميع يفتح المقفولين بأعيانهم أيضاً", () => {
  let lock = applyLockChange(emptyLock(), { studentId: "s1", locked: true }, now);
  lock = applyLockChange(lock, { all: true }, now);
  assert.equal(isLockedFor(lock, "s9"), true);
  lock = applyLockChange(lock, { all: false }, now);
  assert.equal(isLockedFor(lock, "s1"), false);
  assert.equal(isLockedFor(lock, "s9"), false);
});

test("طلبٌ ناقص لا يغيّر شيئاً، وصفٌّ غريب يُقرأ «لا قفل»", () => {
  assert.equal(applyLockChange(emptyLock(), { studentId: "s1" }, now), null);
  assert.equal(applyLockChange(emptyLock(), null, now), null);
  assert.deepEqual(readChatLock({ type: "other", all: true }), emptyLock());
  const stored = readChatLock({ type: CHAT_LOCK_TYPE, all: false, students: ["s1", "s1", 5] });
  assert.deepEqual(stored.students, ["s1"]);
});

test("معرّفُ صفّ القفل آمنٌ في العنوان، والرسالةُ كما يراها الطالب", () => {
  assert.match(chatLockRowId("أ.محمد 1"), /^chatlock_[A-Za-z0-9_-]+$/);
  assert.notEqual(chatLockRowId("t1"), chatLockRowId("t2"));
  assert.equal(CHAT_LOCKED_MESSAGE, "المعلم قام بقفل الدردشة حالياً");
});
