/**
 * عدّادُ دخول الطالب: يزيد مع كل دخول، ولا يرجع إلى الوراء حين تحفظ لوحةُ
 * الويب نسخةً أقدم من سجلّ الطالب.
 *
 * التشغيل: node ./build.mjs && node --test src/lib/__tests__/studentLogins.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";

const logins = await import(process.env.STUDENT_LOGINS_MODULE ?? "../../../dist/lib/studentLogins.mjs");

const at = (iso) => new Date(iso);

test("أوّلُ دخولٍ يبدأ العدّ من واحد", () => {
  assert.deepEqual(logins.nextLoginStats({}, at("2026-11-06T08:00:00.000Z")), {
    loginCount: 1,
    lastLoginAt: "2026-11-06T08:00:00.000Z",
  });
});

test("كلُّ دخولٍ بعد نصف ساعة يزيد العدّ", () => {
  const data = { loginCount: 4, lastLoginAt: "2026-11-06T08:00:00.000Z" };
  assert.equal(logins.nextLoginStats(data, at("2026-11-06T09:00:00.000Z"))?.loginCount, 5);
});

test("جلسةٌ تتكرّر خلال نصف ساعة ليست دخولاً جديداً", () => {
  const data = { loginCount: 4, lastLoginAt: "2026-11-06T08:00:00.000Z" };
  assert.equal(logins.nextLoginStats(data, at("2026-11-06T08:10:00.000Z")), null);
});

test("عدٌّ تالفٌ في السجلّ يُعامَل صفراً", () => {
  assert.equal(logins.nextLoginStats({ loginCount: "abc" }, at("2026-11-06T08:00:00.000Z"))?.loginCount, 1);
});

test("حفظُ نسخةٍ أقدم من الويب لا يُرجع العدّ ولا آخرَ دخول", () => {
  const stored = { loginCount: 9, lastLoginAt: "2026-11-06T08:00:00.000Z" };
  const incoming = { loginCount: 7, lastLoginAt: "2026-11-01T08:00:00.000Z", name: "سارة" };
  assert.deepEqual(logins.keepLoginStats(stored, incoming), {
    loginCount: 9,
    lastLoginAt: "2026-11-06T08:00:00.000Z",
  });
});

test("طالبٌ لم يدخل قطّ: لا حقولَ تُضاف", () => {
  assert.deepEqual(logins.keepLoginStats(undefined, { name: "سارة" }), {});
  assert.deepEqual(logins.keepLoginStats({}, {}), {});
});
