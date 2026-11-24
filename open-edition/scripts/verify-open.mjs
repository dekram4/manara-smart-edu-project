#!/usr/bin/env node
/**
 * التحقّقُ من النسخة المفتوحة — قراءاتٌ فقط، إلا محاولةَ كتابةٍ بالمفتاح العام
 * يُنتظر أن تُرفض.
 *
 *   node open-edition/scripts/verify-open.mjs
 *   node open-edition/scripts/verify-open.mjs --api https://<نطاق-الخدمة-الجديدة>
 *
 * يفحص:
 *   ١. manara-open-app بالمفتاح العام: المحتوى مقروء، والكتابةُ مرفوضة.
 *   ٢. manara-open-app بمفتاح الخدمة: معلّمٌ واحدٌ باسمه، ومحتواه.
 *   ٣. القديمة (قراءةٌ وحدها): المعلمُ الأصلي ومحتواه كما هما.
 *   ٤. (مع --api) الخادمُ الجديد: `open`، جاهز، وبوابةُ المشرف مغلقة.
 */

import { arg, cleanUrl, client, loadEnvOpen, required } from "./lib.mjs";
import { DEFAULT_SOURCE_NAME, DEFAULT_TARGET_ID, DEFAULT_TARGET_NAME } from "./defaults.mjs";
import { normalizeOwner, ownedBy } from "./clone-core.mjs";

loadEnvOpen();

let failures = 0;
const ok = (cond, label, detail = "") => {
  console.log(`${cond ? "✔" : "✖"} ${label}${detail ? ` — ${detail}` : ""}`);
  if (!cond) failures += 1;
};

const newUrl = required("SUPABASE_URL");
const anon = client({ url: newUrl, key: required("SUPABASE_ANON_KEY"), label: "open/anon" });
const service = client({ url: newUrl, key: required("SUPABASE_SERVICE_ROLE_KEY"), label: "open/service" });
const targetId = String(arg("target-id", DEFAULT_TARGET_ID));
const targetName = String(arg("target-name", DEFAULT_TARGET_NAME));

console.log(`— manara-open-app: ${cleanUrl(newUrl)}`);
if (process.env.OLD_SUPABASE_URL) ok(cleanUrl(process.env.OLD_SUPABASE_URL) !== cleanUrl(newUrl), "القاعدتان مختلفتان");

// ── ١. المفتاح العام ──
const lessons = await anon.all("lesson_configs", "select=id").catch((e) => e);
ok(Array.isArray(lessons) && lessons.length > 0, "الدروس مقروءةٌ بالمفتاح العام", Array.isArray(lessons) ? `${lessons.length}` : lessons.message);
const anonWrite = await anon.call("app_kv", {
  method: "POST",
  headers: { Prefer: "return=minimal" },
  body: JSON.stringify({ key: "verify_anon_write_must_fail", value: true }),
}).then(() => null, (e) => e);
ok(anonWrite instanceof Error, "الكتابةُ بالمفتاح العام مرفوضة", anonWrite ? `HTTP ${anonWrite.status}` : "قُبلت! شغّل sql/01-schema.sql");
const students = await anon.call("students?select=id&limit=1").then(() => null, (e) => e);
ok(students instanceof Error, "سجلّاتُ الطلاب غير مقروءةٍ بالمفتاح العام", students ? `HTTP ${students.status}` : "");

// ── ٢. مفتاح الخدمة ──
const teachers = await service.all("teachers", "select=id,data").catch((error) => {
  ok(false, "مفتاحُ الخدمة يقرأ القاعدة الجديدة", error.status === 403 ? "لا صلاحيات — شغّل open-edition/sql/01-schema.sql في SQL Editor أولاً" : error.message);
  console.log(`
✖ ${failures} فحصٌ لم ينجح.`);
  process.exit(1);
});
ok(teachers.length === 1, "معلّمٌ واحدٌ في القاعدة الجديدة", teachers.map((t) => `${t.data?.name} [${t.id}]`).join("، "));
const teacher = teachers.find((t) => t.id === targetId);
ok(Boolean(teacher), `حسابُ ${targetName} موجود`, targetId);
ok(teacher?.data?.name === targetName, "الاسمُ مطابق", teacher?.data?.name);
const ids = new Set([targetId, targetName].map(normalizeOwner));
const openLessons = await service.all("lesson_configs", "select=id,data");
const openQuizzes = await service.all("created_quizzes", "select=id,data");
ok(openLessons.length > 0 && openLessons.every((r) => ownedBy(r.data, ids)), "كلُّ الدروس له", `${openLessons.length}`);
ok(openQuizzes.every((r) => ownedBy(r.data, ids)), "كلُّ الاختبارات له", `${openQuizzes.length}`);
const kv = await service.all("app_kv", "select=key,value");
const tree = kv.find((r) => r.key === "smartEdu_hierarchicalConfigs")?.value;
ok(Array.isArray(tree) && tree.length > 0 && tree.every((c) => ownedBy(c, ids)), "الشجرةُ الأكاديمية له", Array.isArray(tree) ? tree.map((c) => c.grade).join("، ") : "مفقودة");

// ── ٣. القديمة (قراءةٌ وحدها) ──
if (process.env.OLD_SUPABASE_URL && process.env.OLD_SUPABASE_SERVICE_ROLE_KEY) {
  const old = client({ url: process.env.OLD_SUPABASE_URL, key: process.env.OLD_SUPABASE_SERVICE_ROLE_KEY, readOnly: true, label: "القديمة" });
  const oldTeachers = await old.all("teachers", "select=id,data");
  const source = oldTeachers.find((t) => normalizeOwner(t.data?.name) === normalizeOwner(DEFAULT_SOURCE_NAME));
  ok(Boolean(source), `المعلمُ الأصلي «${DEFAULT_SOURCE_NAME}» باقٍ في القديمة`, source?.id);
  ok(!oldTeachers.some((t) => t.id === targetId), "الحسابُ الجديد غيرُ موجودٍ في القديمة");
  if (source) {
    const sourceIds = new Set([source.id, source.data.name, source.data.username].map(normalizeOwner));
    const oldLessons = (await old.all("lesson_configs", "select=id,data")).filter((r) => ownedBy(r.data, sourceIds));
    ok(oldLessons.length === openLessons.length, "دروسُه في القديمة كما هي، وعددُها كعدد المنسوخ", `${oldLessons.length}`);
  }
} else {
  console.log("• تُخطّى فحصُ القديمة: OLD_SUPABASE_* غير مضبوطة.");
}

// ── ٤. الخادمُ الجديد ──
const api = arg("api");
if (typeof api === "string") {
  const base = cleanUrl(api);
  const edition = await fetch(`${base}/api/edition`).then((r) => r.json()).catch((e) => ({ error: e.message }));
  ok(edition.edition === "open", "الخادمُ في النسخة المفتوحة", JSON.stringify(edition));
  ok(edition.ready === true, "جاهزٌ للطلاب (المعلمُ وصفوفُه)", (edition.grades || []).join("، "));
  const admin = await fetch(`${base}/api/auth/admin`, { method: "POST", headers: { "Content-Type": "application/json" }, body: "{}" });
  ok(admin.status === 404, "بوابةُ المشرف مغلقة", `HTTP ${admin.status}`);
  const parent = await fetch(`${base}/api/auth/parent/login`, { method: "POST", headers: { "Content-Type": "application/json" }, body: "{}" });
  ok(parent.status === 404, "بوابةُ وليّ الأمر مغلقة", `HTTP ${parent.status}`);
}

console.log(failures ? `\n✖ ${failures} فحصٌ لم ينجح.` : "\n✔ كلُّ الفحوص نجحت.");
process.exit(failures ? 1 : 0);
