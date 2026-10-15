/**
 * رابطُ تحميل تطبيق الطالب: يُقبل https وحده، ويُقرأ للجميع ويُكتب للمشرف وحده.
 *
 * التشغيل:
 *   node ./build.mjs && node --test src/lib/__tests__/appSettings.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

let mod;
try {
  mod = await import("../../../dist/lib/appSettings.mjs");
} catch (error) {
  throw new Error(`شغّل node ./build.mjs أولاً. (${error?.message ?? error})`);
}
const { normalizeApkUrl, parseStudentApkSetting, DEFAULT_STUDENT_APK_URL, STUDENT_APK_KEY } = mod;

test("يُقبل رابطُ https، ويُرفض ما يصير شيفرةً في متصفّح الزائر", () => {
  assert.equal(normalizeApkUrl("  https://example.com/manara.apk "), "https://example.com/manara.apk");
  assert.equal(normalizeApkUrl("http://localhost:8080/a.apk"), "http://localhost:8080/a.apk");
  for (const bad of [
    "javascript:alert(1)",
    "data:text/html,<script>alert(1)</script>",
    "http://example.com/a.apk",
    "ftp://example.com/a.apk",
    "https://user:pass@example.com/a.apk",
    "not a url",
    "",
    null,
    42,
    `https://example.com/${"a".repeat(2100)}`,
  ]) {
    assert.equal(normalizeApkUrl(bad), null, String(bad).slice(0, 40));
  }
});

test("القيمةُ المحفوظة تُقرأ، والمعطوبةُ تُردّ فيظهر الرابطُ المؤقّت", () => {
  assert.deepEqual(
    parseStudentApkSetting({ url: "https://example.com/a.apk", updatedAt: "2026-10-15T00:00:00.000Z" }),
    { url: "https://example.com/a.apk", updatedAt: "2026-10-15T00:00:00.000Z" },
  );
  assert.deepEqual(parseStudentApkSetting("https://example.com/b.apk"), { url: "https://example.com/b.apk", updatedAt: "" });
  assert.equal(parseStudentApkSetting({ url: "javascript:alert(1)" }), null);
  assert.equal(parseStudentApkSetting(null), null);
  assert.ok(normalizeApkUrl(DEFAULT_STUDENT_APK_URL), "الرابطُ المؤقّت نفسه صالح");
  assert.equal(STUDENT_APK_KEY, "smartEdu_studentApkUrl");
});

test("المسار: القراءةُ عامّة، والكتابةُ خلف requireAdmin ومحدودةُ المعدّل", async () => {
  const route = await readFile(new URL("../../routes/appSettings.ts", import.meta.url), "utf8");
  const index = await readFile(new URL("../../routes/index.ts", import.meta.url), "utf8");
  assert.match(route, /router\.get\("\/app-settings\/student-apk", async/);
  assert.match(route, /router\.put\(\s*"\/app-settings\/student-apk",\s*writeLimit,\s*requireAdmin,/);
  assert.match(route, /normalizeApkUrl\(/);
  assert.match(index, /router\.use\(appSettingsRouter\);/);
});
