import test from "node:test";
import assert from "node:assert/strict";
import {
  allSeenAt,
  consumedAt,
  isChatMessageId,
  recipientsOf,
  saveUntil,
  seenBy,
  shouldPurge,
  visibleTo,
} from "../../../dist/lib/chatLifecycle.mjs";

const T0 = Date.parse("2026-10-03T10:00:00Z");
const MIN = 60 * 1000;
const HOUR = 60 * MIN;
const iso = (ms) => new Date(T0 + ms).toISOString();
const at = (ms) => new Date(T0 + ms);
const ID = "chat_1_aaaaaaaa";
const dm = { id: ID, from: "joury", to: "rose", createdAt: iso(0) };
const group = { id: ID, from: "joury", to: "all", createdAt: iso(0) };
const CLASS = ["joury", "rose", "sara"];
const r = (studentId, over = {}) => ({
  messageId: ID, studentId, firstSeenAt: null, lastSeenAt: null, savedUntil: null, ...over,
});
const seen = (studentId, first, last = first) =>
  r(studentId, { firstSeenAt: iso(first), lastSeenAt: iso(last) });

test("المستلمون بلا المرسِل", () => {
  assert.deepEqual(recipientsOf(group, CLASS), ["rose", "sara"]);
  assert.deepEqual(recipientsOf(dm, CLASS), ["rose"]);
});

// ── خاصّة: جوري → روز ──

test("روز لم ترها: تبقى عند جوري مهما خرجت وعادت", () => {
  const receipts = [seen("joury", 1 * MIN, 5 * MIN)];
  assert.equal(visibleTo(dm, "joury", ["rose"], receipts, at(10 * MIN)), true);
  assert.equal(visibleTo(dm, "joury", ["rose"], receipts, at(5 * HOUR)), true);
});

test("روز رأتها: تبقى ظاهرةً عند روز في الزيارة نفسها، وتختفي بعودتها", () => {
  const receipts = [seen("rose", 2 * MIN)];
  assert.equal(visibleTo(dm, "rose", ["rose"], receipts, at(1 * MIN)), true, "الزيارةُ التي رأتها فيها");
  assert.equal(visibleTo(dm, "rose", ["rose"], receipts, at(3 * MIN)), false, "زيارةٌ بعدها");
});

test("جوري: بعد أن رأتها روز ورأت جوري ذلك، تختفي بعودتها — لا قبل", () => {
  const roseSaw = seen("rose", 2 * MIN);
  // جوري لم تعرض الرسالةَ بعد قراءة روز: لم تستهلكها.
  let receipts = [seen("joury", 1 * MIN, 1 * MIN), roseSaw];
  assert.equal(consumedAt(dm, "joury", ["rose"], receipts), null);
  assert.equal(visibleTo(dm, "joury", ["rose"], receipts, at(10 * MIN)), true);
  // عُرضت لجوري بعد قراءة روز (رأت المؤشّر): تختفي في زيارتها التالية.
  receipts = [seen("joury", 1 * MIN, 4 * MIN), roseSaw];
  assert.equal(visibleTo(dm, "joury", ["rose"], receipts, at(3 * MIN)), true, "الزيارةُ الحالية");
  assert.equal(visibleTo(dm, "joury", ["rose"], receipts, at(5 * MIN)), false, "بعد العودة");
});

test("📌 حفظ: تبقى لصاحبه 24 ساعة ثم تذهب", () => {
  const receipts = [
    r("rose", { firstSeenAt: iso(2 * MIN), lastSeenAt: iso(2 * MIN), savedUntil: iso(2 * MIN + 24 * HOUR) }),
  ];
  assert.equal(visibleTo(dm, "rose", ["rose"], receipts, at(3 * HOUR), at(3 * HOUR)), true);
  assert.equal(visibleTo(dm, "rose", ["rose"], receipts, at(25 * HOUR), at(25 * HOUR)), false);
  assert.equal(saveUntil(at(0)), iso(24 * HOUR));
});

// ── الصفّ ──

test("رسالةُ الصفّ: أسماءُ من رآها، وتبقى عند المرسِل حتى يراها الجميع", () => {
  let receipts = [seen("joury", 1 * MIN, 9 * MIN), seen("rose", 2 * MIN)];
  assert.deepEqual(seenBy(group, ["rose", "sara"], receipts), ["rose"]);
  assert.equal(allSeenAt(group, ["rose", "sara"], receipts), null);
  assert.equal(visibleTo(group, "joury", ["rose", "sara"], receipts, at(20 * MIN)), true, "سارة لم ترها");
  receipts = [...receipts, seen("sara", 30 * MIN)];
  assert.deepEqual(seenBy(group, ["rose", "sara"], receipts), ["rose", "sara"]);
  assert.equal(visibleTo(group, "joury", ["rose", "sara"], receipts, at(40 * MIN)), true, "لم ترَ جوري اكتمالها");
  receipts = receipts.map((x) => (x.studentId === "joury" ? seen("joury", 1 * MIN, 35 * MIN) : x));
  assert.equal(visibleTo(group, "joury", ["rose", "sara"], receipts, at(40 * MIN)), false, "رأت الاكتمال ثم عادت");
});

// ── الحذف النهائي ──

test("تُحذف حين يستهلكها الجميع — المرسِلُ بعد أن رأى القراءة", () => {
  const roseSaw = seen("rose", 2 * MIN);
  assert.equal(shouldPurge(dm, ["rose"], [seen("joury", 1 * MIN), roseSaw], at(10 * MIN)), false);
  assert.equal(shouldPurge(dm, ["rose"], [seen("joury", 1 * MIN, 4 * MIN), roseSaw], at(10 * MIN)), true);
});

test("لم يرها المستلم: لا تُحذف قبل 7 أيام", () => {
  const receipts = [seen("joury", 1 * MIN)];
  assert.equal(shouldPurge(dm, ["rose"], receipts, at(3 * 24 * HOUR)), false);
  assert.equal(shouldPurge(dm, ["rose"], receipts, at(8 * 24 * HOUR)), true);
});

test("تنظيف العالق: رآها المستلمون ومضى عليها 24 ساعة، أو بلا أيّ إيصال ومضى عليها 24 ساعة", () => {
  assert.equal(shouldPurge(dm, ["rose"], [seen("rose", 2 * MIN)], at(25 * HOUR)), true);
  assert.equal(shouldPurge(dm, ["rose"], [], at(25 * HOUR)), true, "رسالةٌ قديمةٌ قبل الإيصالات");
  assert.equal(shouldPurge(dm, ["rose"], [], at(2 * HOUR)), false);
});

test("حفظٌ قائمٌ يمنع الحذف — حتى العالق", () => {
  const saved = [r("rose", { firstSeenAt: iso(1), lastSeenAt: iso(1), savedUntil: iso(30 * HOUR) })];
  assert.equal(shouldPurge(dm, ["rose"], saved, at(25 * HOUR)), false);
  assert.equal(shouldPurge(dm, ["rose"], saved, at(31 * HOUR)), true);
});

test("معرّفُ الرسالة بشكله وحده", () => {
  assert.equal(isChatMessageId("chat_1700000000000_6f1c2d7e-1111-4222-8333-944445555666"), true);
  assert.equal(isChatMessageId("chatvoice_1_aaaaaaaa"), false);
  assert.equal(isChatMessageId("chat_1,2"), false);
});
