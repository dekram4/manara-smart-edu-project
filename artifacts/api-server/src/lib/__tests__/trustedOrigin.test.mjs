/**
 * اختبارات سياسة الأصل.
 *
 * ── العطبُ الذي تحرسه ──
 * أصلُ النشر نفسه كان مرفوضاً، لأن القائمة تحمل `REPLIT_DEV_DOMAIN` وحده
 * وهو متغيّرٌ لا يُضبط في النشر. والرفضُ كان يُرفع `Error` فيصير «500
 * Internal Server Error» صفحةَ HTML.
 *
 * فكلُّ طلبٍ من المتصفّح في الإنتاج يفشل — دخولُ المعلم والمشرف وولي
 * الأمر وكلُّ مسارٍ سواها — وتُظهر الواجهةُ «كلمة المرور خاطئة» لأنها
 * تقرأ أيَّ ردٍّ غير ناجحٍ كذلك.
 *
 * ولم يظهر في فحصٍ بـ`curl`: هو لا يرسل `Origin` فيمرّ. فكان الخادم يعمل
 * من الطرفية ويفشل من الشاشة، وبقي خمسةَ أشهر.
 *
 * التشغيل:
 *   npm run build && node --test src/lib/__tests__/trustedOrigin.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";

const target = process.env.ORIGIN_MODULE ?? "../../../dist/lib/trustedOrigin.mjs";
let mod;
try {
  mod = await import(target);
} catch (error) {
  throw new Error(
    `تعذّر استيراد ${target} — شغّل npm run build أولاً. (${error?.message ?? error})`,
  );
}

const { isTrustedOrigin } = mod;

const DEPLOY = "manara-smart-edu-project.replit.app";
const DEV = "3daed49c-74e9-464a-89fa-0dd61cae7661-00-1r2hrmhp8fjuc.sisko.replit.dev";

test("أصلُ الخادم نفسه موثوقٌ ولو لم يكن في أي قائمة", () => {
  // هذا هو العطبُ بعينه: في النشر لا `REPLIT_DEV_DOMAIN` ولا قائمةَ
  // تحمل النطاق، والطلبُ آتٍ من الصفحة التي يخدمها الخادم نفسه.
  assert.ok(
    isTrustedOrigin(`https://${DEPLOY}`, { host: DEPLOY }),
    "أصلُ النشر مرفوضٌ وهو أصلُ الخادم — وهذا العطب الذي أسقط الدخول",
  );
});

test("ويصحّ على أيّ نطاقٍ يُضاف غداً بلا تعديلِ شيفرة", () => {
  for (const host of [
    "manara.sa",
    "app.manara.sa",
    "manara-smart-edu-new.replit.app",
    "localhost:8099",
  ]) {
    assert.ok(
      isTrustedOrigin(`https://${host}`, { host }),
      `نطاقٌ مخصَّص «${host}» مرفوض وهو أصلُ الخادم`,
    );
  }
});

test("ونطاقُ مساحة العمل وما تحته", () => {
  assert.ok(isTrustedOrigin(`https://${DEV}`, { devDomain: DEV }));
  assert.ok(isTrustedOrigin(`https://sub.${DEV}`, { devDomain: DEV }));
});

test("ونطاقاتُ النشر التي تُعلنها Replit، مفصولةً بفواصل", () => {
  const declared = ` ${DEPLOY} , manara.sa `;
  assert.ok(isTrustedOrigin(`https://${DEPLOY}`, { deployDomains: declared }));
  assert.ok(isTrustedOrigin("https://manara.sa", { deployDomains: declared }));
  assert.ok(!isTrustedOrigin("https://other.sa", { deployDomains: declared }));
});

test("والمحلّيُّ بأيّ منفذ — فـVite يفتح منافذَ مختلفة", () => {
  assert.ok(isTrustedOrigin("http://localhost", {}));
  assert.ok(isTrustedOrigin("http://localhost:5173", {}));
  assert.ok(isTrustedOrigin("http://127.0.0.1:4173", {}));
});

test("وما ليس منها يُردّ", () => {
  assert.ok(!isTrustedOrigin("https://evil.example.com", { host: DEPLOY }));
  // ولا يُخدَع بمضيفٍ يبدأ بالمسموح: «localhost.evil.com» ليس محلّياً.
  assert.ok(!isTrustedOrigin("http://localhost.evil.com", {}));
  // ولا بنطاقٍ يشبه نطاقَ التطوير دون أن يكون تحته.
  assert.ok(!isTrustedOrigin(`https://evil-${DEV}`, { devDomain: DEV }));
});

test("وأصلٌ ليس عنواناً صالحاً لا يُسقط الفحص", () => {
  // `null` تصل نصّاً من WebView بأصلٍ معتم، وسواها من الكلام المشوَّه.
  for (const bad of ["null", "", "not a url", "://", "file://"]) {
    assert.equal(typeof isTrustedOrigin(bad, { host: DEPLOY }), "boolean");
  }
  assert.ok(!isTrustedOrigin("null", { host: DEPLOY }));
});
