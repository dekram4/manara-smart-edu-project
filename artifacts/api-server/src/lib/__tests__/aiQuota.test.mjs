/**
 * اختبارات ترشيد استهلاك الذكاء الاصطناعي.
 *
 * التشغيل:
 *   npm run build && node --test src/lib/__tests__/aiQuota.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";

const target = process.env.QUOTA_MODULE ?? "../../../dist/lib/aiQuota.js";
let mod;
try {
  mod = await import(target);
} catch {
  console.log("تُخطّى: لم يُبنَ dist بعد (npm run build).");
  process.exit(0);
}

const {
  FREE_DAILY_QUESTIONS,
  GEM_PRICE,
  cacheKey,
  chargeFor,
  dayStamp,
  normalizeQuestion,
  readQuota,
  snapshotOf,
  spend,
} = mod;

test("السؤال نفسه بهمزتين مختلفتين مفتاحٌ واحد", () => {
  // ولولا ذلك لسُئل النموذج مرّتين عن الشيء نفسه، وهو ما جاءت الذاكرة
  // لتمنعه.
  assert.equal(
    normalizeQuestion("ما هي الخلية؟"),
    normalizeQuestion("ما هى الخليه"),
  );
  assert.equal(normalizeQuestion("  ما   الفكرة ؟ "), "ما الفكره");
});

test("الدرس جزءٌ من المفتاح", () => {
  // «ما الفكرة الرئيسية؟» سؤالٌ صالحٌ لكل درس وإجابتُه تختلف.
  assert.notEqual(cacheKey("g4sci_1_1", "ما الفكرة؟"), cacheKey("g4sci_1_2", "ما الفكرة؟"));
  assert.equal(cacheKey("g4sci_1_1", "ما الفكرة؟"), cacheKey("g4sci_1_1", "ما الفكره"));
});

test("يومٌ جديد يعني عدّاداً جديداً بلا تصفيرٍ مجدول", () => {
  const stale = { day: "2020-01-01", used: 9, gemsSpent: 40 };
  const fresh = readQuota(stale, "2026-09-28");
  assert.equal(fresh.used, 0);
  assert.equal(fresh.gemsSpent, 0);
  assert.equal(fresh.day, "2026-09-28");

  const same = readQuota({ day: "2026-09-28", used: 3, gemsSpent: 0 }, "2026-09-28");
  assert.equal(same.used, 3);
});

test("قيمةٌ معطوبة تُقرأ صفراً لا تُسقط الحساب", () => {
  const quota = readQuota({ day: dayStamp(), used: -5, gemsSpent: "xx" });
  assert.equal(quota.used, 0);
  assert.equal(quota.gemsSpent, 0);
  assert.equal(readQuota(null).used, 0);
  assert.equal(readQuota("nonsense").used, 0);
});

test("المجاني يُستهلك أولاً بلا جواهر", () => {
  let quota = readQuota(null);
  for (let index = 0; index < FREE_DAILY_QUESTIONS; index += 1) {
    const verdict = chargeFor(quota, 0);
    assert.equal(verdict.allowed, true, `السؤال ${index + 1}`);
    assert.equal(verdict.gemsCharged, 0);
    assert.equal(verdict.remainingFree, FREE_DAILY_QUESTIONS - index - 1);
    quota = spend(quota, verdict);
  }
  assert.equal(quota.used, FREE_DAILY_QUESTIONS);
});

test("بعد النفاد يُدفع بالجواهر", () => {
  const quota = { day: dayStamp(), used: FREE_DAILY_QUESTIONS, gemsSpent: 0 };
  const verdict = chargeFor(quota, 20);
  assert.equal(verdict.allowed, true);
  assert.equal(verdict.gemsCharged, GEM_PRICE);
  const after = spend(quota, verdict);
  assert.equal(after.gemsSpent, GEM_PRICE);
  assert.equal(after.used, FREE_DAILY_QUESTIONS + 1);
});

test("رصيدٌ دون الثمن يمنع السؤال ويقول لماذا", () => {
  const quota = { day: dayStamp(), used: FREE_DAILY_QUESTIONS, gemsSpent: 0 };
  const verdict = chargeFor(quota, GEM_PRICE - 1);
  assert.equal(verdict.allowed, false);
  assert.equal(verdict.reason, "no_gems");
  assert.equal(verdict.gemsCharged, 0);
  // ولا يُحسب على الطفل سؤالٌ مُنع.
  assert.deepEqual(spend(quota, verdict), quota);
});

test("ما يُعرض في الشات يصف الحال بدقّة", () => {
  const fresh = snapshotOf(readQuota(null), 0);
  assert.equal(fresh.remainingFree, FREE_DAILY_QUESTIONS);
  assert.equal(fresh.canAsk, true);
  assert.equal(fresh.gemPrice, GEM_PRICE);

  const spent = { day: dayStamp(), used: FREE_DAILY_QUESTIONS, gemsSpent: 0 };
  assert.equal(snapshotOf(spent, 0).canAsk, false);
  assert.equal(snapshotOf(spent, GEM_PRICE).canAsk, true);
  assert.equal(snapshotOf(spent, 99).remainingFree, 0);
});

test("اليوم يُقرأ من ساعة الخادم بصيغةٍ ثابتة", () => {
  assert.match(dayStamp(new Date("2026-09-28T23:59:59Z")), /^2026-09-28$/);
});
