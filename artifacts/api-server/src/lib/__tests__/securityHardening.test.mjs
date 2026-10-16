/**
 * إغلاقُ بيانات الطلاب وتشديدُ كلمات المرور.
 *
 *   ١. كلماتُ المرور: scrypt بملحٍ لكل حساب، وقبولُ الصيغتين القديمتين مع
 *      الترقية، ولا تنزيلَ لصيغةٍ ولا تخزينَ لضعيفة.
 *   ٢. لا كلمةَ مرور تغادر الخادم: الجسرُ والدخولُ وملفُّ الطالب.
 *   ٣. التطبيقُ لا يقرأ جداولَ الأشخاص بالمفتاح العام.
 *   ٤. ملفُّ Supabase الموحَّد مولَّدٌ من أجزائه، والإغلاقُ فيه كامل.
 *   ٥. لا فيديو يُحفظ على قرصٍ مؤقّت في الإنتاج.
 *
 * التشغيل:
 *   node ./build.mjs && node --test src/lib/__tests__/securityHardening.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import { readFile } from "node:fs/promises";

let pw;
try {
  pw = await import("../../../dist/lib/passwords.mjs");
} catch (error) {
  throw new Error(`شغّل node ./build.mjs أولاً. (${error?.message ?? error})`);
}
const {
  hashPassword,
  verifyPassword,
  verifyPrehash,
  passwordToStore,
  upgradeStoredValue,
  isStrongHash,
  sha256Hex,
  withoutSecrets,
} = pw;

const src = (rel) => readFile(new URL(`../../${rel}`, import.meta.url), "utf8");
const repo = (rel) => readFile(new URL(`../../../../../${rel}`, import.meta.url), "utf8");
const sha = (value) => crypto.createHash("sha256").update(value).digest("hex");

test("scrypt بملحٍ لكل حساب: كلمتان متطابقتان ببصمتين مختلفتين", () => {
  const a = hashPassword("1234");
  const b = hashPassword("1234");
  assert.ok(isStrongHash(a) && isStrongHash(b));
  assert.notEqual(a, b, "الملحُ عشوائيّ لكل حساب");
  assert.match(a, /^scrypt1\$[A-Za-z0-9_-]{22}\$[A-Za-z0-9_-]{43}$/);
  assert.equal(verifyPassword("1234", a).ok, true);
  assert.equal(verifyPassword("12345", a).ok, false);
  assert.equal(verifyPassword("1234", a).upgrade, null, "الآمنةُ لا تحتاج ترقية");
});

test("الصيغتان القديمتان تُقبلان وتُرقَّيان عند أوّل دخولٍ ناجح", () => {
  for (const legacy of [sha("salma2026"), sha("salma2026").toUpperCase(), "salma2026"]) {
    const check = verifyPassword("salma2026", legacy);
    assert.equal(check.ok, true, legacy.slice(0, 8));
    assert.ok(isStrongHash(check.upgrade), "يعود ببديلٍ آمن");
    assert.equal(verifyPassword("salma2026", check.upgrade).ok, true);
    assert.equal(verifyPassword("wrong", legacy).ok, false);
    assert.equal(verifyPassword("wrong", legacy).upgrade, null);
  }
});

test("الترقيةُ الجماعيّة بلا كلمة المرور: البصمةُ القديمة تُلفّ في مكانها", () => {
  const wrapped = upgradeStoredValue(sha("teacher-pass"));
  assert.ok(isStrongHash(wrapped));
  assert.equal(verifyPassword("teacher-pass", wrapped).ok, true);
  assert.ok(isStrongHash(upgradeStoredValue("plain-old")));
  assert.equal(verifyPassword("plain-old", upgradeStoredValue("plain-old")).ok, true);
  const strong = hashPassword("x");
  assert.equal(upgradeStoredValue(strong), strong, "الآمنةُ تبقى كما هي");
  assert.equal(upgradeStoredValue(""), null);
});

test("جسرُ المزامنة: لا يُنزّل صيغةً، ويلفّ الجديد، ويُبقي المخزَّن", () => {
  const stored = hashPassword("current");
  // نسخةٌ قديمة في المتصفّح ترسل بصمةَ SHA-256 للكلمة نفسها ← يبقى المخزَّن.
  assert.equal(passwordToStore(sha("current"), stored), stored);
  // بلا كلمة مرور في الوارد (اللوحاتُ لا تستلمها) ← يبقى المخزَّن.
  assert.equal(passwordToStore(undefined, stored), stored);
  // كلمةٌ جديدة من لوحة الويب (بصمة) ← تُلفّ بـ scrypt.
  const changed = passwordToStore(sha("new-pass"), stored);
  assert.ok(isStrongHash(changed) && changed !== stored);
  assert.equal(verifyPassword("new-pass", changed).ok, true);
  // حسابٌ جديد ← آمنٌ من أوّل يوم.
  assert.ok(isStrongHash(passwordToStore(sha("first"), undefined)));
  // قيمةُ scrypt يرسلها عميلٌ لا تحلّ محلَّ المخزَّن.
  assert.equal(passwordToStore(hashPassword("attacker"), stored), stored);
  // مخزَّنٌ قديم يُرقّى حين يمرّ بالجسر.
  assert.ok(isStrongHash(passwordToStore(undefined, sha("legacy"))));
  assert.equal(verifyPrehash(sha("current"), stored), true);
  assert.equal(sha256Hex("current"), sha("current"));
});

test("لا كلمةَ مرور تغادر الخادم", async () => {
  assert.deepEqual(withoutSecrets({ name: "س", password: "x", grade: "4" }), { name: "س", grade: "4" });
  const bridge = await src("routes/supabaseBridge.ts");
  assert.match(bridge, /res\.json\(withoutPasswords\(table, scopeRowsToParent\(/);
  assert.match(bridge, /res\.json\(withoutPasswords\(table, scopedRows\)\)/);
  assert.match(bridge, /const secured = await securePasswords\(config, table, validRows\);/);
  const access = await src("lib/studentAccess.ts");
  for (const field of ["password", "nationalId", "parentPhoneNumber"]) {
    assert.match(access, new RegExp(`"${field}"`), field);
  }
  const auth = await src("routes/auth.ts");
  assert.match(auth, /student: record \? \{ id: record\.id, data: safeStudentData\(record\.data\) \} : null/);
  assert.match(auth, /password: hashPassword\(password\),/);
  assert.doesNotMatch(auth, /createHash\("sha256"\)\.update\(password\)/, "لا تُخزَّن بصمةٌ مجرّدة");
  const profile = await src("routes/studentProfile.ts");
  for (const route of ["/student/me", "/student/quiz-results", "/student/tutor-history"]) {
    assert.match(profile, new RegExp(`router\\.get\\("${route.replace(/\//g, "\\/")}", readLimit, requireStudentSession,`));
  }
});

test("التطبيقُ لا يقرأ جداولَ الأشخاص بالمفتاح العام، ولا يتحقّق من كلمة المرور على الهاتف", async () => {
  const auth = await repo("artifacts/manara-student-flutter/lib/src/services/student_auth_service.dart");
  const content = await repo("artifacts/manara-student-flutter/lib/src/services/student_content_service.dart");
  for (const table of ["students", "teachers", "parents", "quiz_results", "interactions"]) {
    assert.doesNotMatch(auth + content, new RegExp(`\\.from\\('${table}'\\)`), table);
  }
  assert.doesNotMatch(auth, /_passwordsMatch|package:crypto/);
  assert.match(content, /_apiGet\('\/api\/student\/me'\)/);
});

test("ملفُّ Supabase الموحَّد: مولَّدٌ من أجزائه، والإغلاقُ فيه كامل", async () => {
  const { renderApplySql, OUTPUT } = await import("../../../scripts/build-apply-sql.mjs");
  const onDisk = (await readFile(OUTPUT, "utf8")).replace(/\r\n/g, "\n");
  assert.equal(onDisk, await renderApplySql(), "أعد: node ./scripts/build-apply-sql.mjs");
  const lockdown = (await readFile(new URL("../../../scripts/security-lockdown.sql", import.meta.url), "utf8"));
  assert.match(lockdown, /revoke all on public\.%I from anon, authenticated/);
  assert.match(lockdown, /drop policy %I on public\.%I/);
  // ما يبقى للمفتاح العام: محتوى التعليم وحده.
  const granted = [...lockdown.matchAll(/grant select on public\.([a-z_]+) to anon/g)].map((m) => m[1]).sort();
  assert.deepEqual(granted, ["app_kv", "created_quizzes", "lesson_configs"]);
  assert.match(lockdown, /drop function %s/, "match_qa_cache المعطوبة تُحذف");
  // والترتيب: الحذفُ قبل إنشاء الصحيحة، والبنكُ أخيراً.
  assert.ok(onDisk.indexOf("security-lockdown.sql") < onDisk.indexOf("ai-qa-cache-vectors.sql"));
  assert.ok(onDisk.indexOf("ai-qa-cache-vectors.sql") < onDisk.indexOf("duel-knowledge-bank.sql"));
});

test("لا فيديو على قرصٍ مؤقّت في الإنتاج", async () => {
  const media = await src("routes/media.ts");
  assert.match(media, /export function localMediaFallbackAllowed\(env: NodeJS\.ProcessEnv = process\.env\): boolean \{\s*return env\.NODE_ENV !== "production";/);
  assert.match(media, /if \(!localMediaFallbackAllowed\(\)\) \{\s*return res\.status\(503\)/);
});
