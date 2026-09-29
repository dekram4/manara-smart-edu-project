/**
 * اختبارات تنقية النصّ من التشكيل.
 *
 * ── لماذا تُختبر وهي سطرٌ واحد ──
 * الخطأُ فيها لا يُرى في الشاشة ولا يُسمع خطأً واضحاً: يُنطق الشرح
 * مُعرَباً متكلّفاً، فيبدو كأنّ المحرّك كذلك. وقد كان الأمرُ يُظنّ في
 * المحرّك سنةً قبل أن يُعرف أنه في النصّ.
 *
 * والحدُّ الحسّاس أن يُحذف الحرفُ ولا يُستبدل بمسافة: الحركةُ فوق حرفها
 * لا بينه وبين ما يليه، فمسافةٌ مكانَها تقطع الكلمة.
 *
 * التشغيل:
 *   npm run build && node --test src/lib/__tests__/arabicText.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";

const target = process.env.ARABIC_MODULE ?? "../../../dist/lib/arabicText.mjs";
let mod;
try {
  mod = await import(target);
} catch (error) {
  throw new Error(
    `تعذّر استيراد ${target} — شغّل npm run build أولاً. (${error?.message ?? error})`,
  );
}

const { stripDiacritics } = mod;

test("الحركاتُ والتنوين تسقط", () => {
  assert.equal(stripDiacritics("الخَلِيَّةُ"), "الخلية");
  assert.equal(stripDiacritics("كتاباً جديداً"), "كتابا جديدا");
  assert.equal(stripDiacritics("مُحَمَّدٌ ذَهَبَ"), "محمد ذهب");
});

test("والتطويلُ حرفُ مطٍّ يسقط معها", () => {
  assert.equal(stripDiacritics("مرحبـــا"), "مرحبا");
});

test("وتُحذف ولا تصير مسافةً تقطع الكلمة", () => {
  // لو استُبدلت بمسافة لصارت «أوّلاً» كلمتين: «أو» و«لا» — ونقيضَ معناها.
  assert.equal(stripDiacritics("أوّلاً"), "أولا");
  assert.equal(stripDiacritics("الشَّمْسُ مُشْرِقَةٌ").split(" ").length, 2);
});

test("وما لا تشكيل فيه يمرّ كما هو", () => {
  assert.equal(stripDiacritics("شوف يا بطل، الجواب 12"), "شوف يا بطل، الجواب 12");
  assert.equal(stripDiacritics("plain english 42"), "plain english 42");
});

test("وما ليس نصاً يعود فارغاً لا يُسقط الخدمة", () => {
  // `getGeminiText` تعود بـ`null` حين لا يصل نصّ، والمسار يفحص الفراغ
  // بعدها — فالفارغُ هنا يعني ما كان يعنيه `null`.
  assert.equal(stripDiacritics(null), "");
  assert.equal(stripDiacritics(undefined), "");
  assert.equal(stripDiacritics(42), "");
});
