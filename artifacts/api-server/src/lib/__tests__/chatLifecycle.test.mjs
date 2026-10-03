import test from "node:test";
import assert from "node:assert/strict";
import {
  CHAT_SAVE_MS,
  CHAT_TTL_MS,
  isChatMessageId,
  isSaved,
  recipientsOf,
  saveUntil,
  shouldPurge,
  visibleTo,
} from "../../../dist/lib/chatLifecycle.mjs";

const T0 = Date.parse("2026-10-01T10:00:00Z");
const iso = (ms) => new Date(T0 + ms).toISOString();
const now = (ms) => new Date(T0 + ms);
const HOUR = 60 * 60 * 1000;
const msg = (over = {}) => ({ id: "chat_1_aaaaaaaa", from: "a", to: "all", createdAt: iso(0), ...over });
const receipt = (studentId, over = {}) => ({
  messageId: "chat_1_aaaaaaaa",
  studentId,
  seenAt: null,
  savedUntil: null,
  ...over,
});

test("العمرُ والحفظُ ٢٤ ساعةً", () => {
  assert.equal(CHAT_TTL_MS, 24 * HOUR);
  assert.equal(CHAT_SAVE_MS, 24 * HOUR);
  assert.equal(saveUntil(now(0)), iso(24 * HOUR));
});

test("لم يقرأها: يراها. قرأها وغادر: لا يراها", () => {
  assert.equal(visibleTo(msg(), undefined, now(1000)), true);
  assert.equal(visibleTo(msg(), receipt("b"), now(1000)), true);
  assert.equal(visibleTo(msg(), receipt("b", { seenAt: iso(500) }), now(1000)), false);
});

test("قرأها وحفظها: تبقى له حتى ينتهي حفظُه", () => {
  const saved = receipt("b", { seenAt: iso(500), savedUntil: iso(500 + 24 * HOUR) });
  assert.equal(visibleTo(msg(), saved, now(10 * HOUR)), true);
  assert.equal(visibleTo(msg(), saved, now(24 * HOUR + 501)), false);
  assert.equal(isSaved(saved, now(24 * HOUR + 501)), false);
});

test("مضى عمرُها: لا تُرى وإن لم تُقرأ — إلا محفوظة", () => {
  assert.equal(visibleTo(msg(), undefined, now(24 * HOUR + 1)), false);
  const saved = receipt("b", { savedUntil: iso(30 * HOUR) });
  assert.equal(visibleTo(msg(), saved, now(25 * HOUR)), true);
});

test("المستلمون: الصفُّ كلُّه مع المرسِل، أو اثنان في الخاصّة", () => {
  assert.deepEqual(recipientsOf(msg(), ["b", "c", "a"]), ["b", "c", "a"]);
  assert.deepEqual(recipientsOf(msg({ to: "b" }), ["b", "c"]), ["a", "b"]);
});

test("تُحذف حين يقرؤها الجميع، لا قبل", () => {
  const people = ["a", "b", "c"];
  const seen = (id) => receipt(id, { seenAt: iso(100) });
  assert.equal(shouldPurge(msg(), people, [seen("a"), seen("b")], now(1000)), false, "c لم يقرأها");
  assert.equal(shouldPurge(msg(), people, [seen("a"), seen("b"), seen("c")], now(1000)), true);
});

test("حفظٌ قائمٌ عند أحدهم يُبقيها — حتى بعد عمرها", () => {
  const people = ["a", "b"];
  const receipts = [
    receipt("a", { seenAt: iso(100) }),
    receipt("b", { seenAt: iso(100), savedUntil: iso(30 * HOUR) }),
  ];
  assert.equal(shouldPurge(msg(), people, receipts, now(1000)), false);
  assert.equal(shouldPurge(msg(), people, receipts, now(25 * HOUR)), false);
  assert.equal(shouldPurge(msg(), people, receipts, now(30 * HOUR + 1)), true, "انتهى الحفظ");
});

test("مضى عمرُها بلا حفظ: تُحذف وإن لم يقرأها أحد", () => {
  assert.equal(shouldPurge(msg(), ["a", "b"], [], now(24 * HOUR + 1)), true);
  assert.equal(shouldPurge(msg(), ["a", "b"], [], now(HOUR)), false);
});

test("إيصالاتُ رسالةٍ أخرى لا تُحسب لها", () => {
  const other = { ...receipt("b", { seenAt: iso(1) }), messageId: "chat_2_bbbbbbbb" };
  assert.equal(shouldPurge(msg({ to: "b" }), ["a", "b"], [receipt("a", { seenAt: iso(1) }), other], now(1000)), false);
});

test("معرّفُ الرسالة بشكله وحده", () => {
  assert.equal(isChatMessageId("chat_1700000000000_6f1c2d7e-1111-4222-8333-944445555666"), true);
  assert.equal(isChatMessageId("chatvoice_1_aaaaaaaa"), false);
  assert.equal(isChatMessageId("chat_1,2"), false);
  assert.equal(isChatMessageId(undefined), false);
});
