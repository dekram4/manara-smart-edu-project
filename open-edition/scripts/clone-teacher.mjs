#!/usr/bin/env node
/**
 * استنساخُ حساب المعلم «داود سيد اكرام» بكامل محتواه إلى «معلم الروضة داود سيد»
 * في قاعدة النسخة المفتوحة `manara-open-app`.
 *
 * ── ما يلمسه ──
 *   القاعدةُ القديمة: قراءةٌ وحدها (GET). عميلُها يرفض أيَّ طلبٍ آخر قبل أن يخرج.
 *   القاعدةُ الجديدة: لا شيء، إلا مع `--apply` (upsert بمفتاح خدمتها).
 *
 * ── التشغيل (من جذر المستودع) ──
 *   node open-edition/scripts/clone-teacher.mjs            ← يكتب open-edition/out/seed-teacher.sql
 *   node open-edition/scripts/clone-teacher.mjs --apply    ← ويكتب في manara-open-app مباشرة
 *
 * خياراتٌ:  --source-id <id>  --source-name <اسم>  --target-id <id>  --target-name <اسم>
 *           --out <ملف>  --dry (ملخّصٌ بلا ملف)
 *
 * المفاتيح من `.env.open` (مستثنى من git):
 *   OLD_SUPABASE_URL, OLD_SUPABASE_SERVICE_ROLE_KEY   ← القديمة، للقراءة
 *   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY           ← الجديدة (الثاني لـ --apply وحده)
 */

import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { arg, cleanUrl, client, editionRoot, loadEnvOpen, required } from "./lib.mjs";
import { buildClone, normalizeOwner, renderSeedSql, summarize } from "./clone-core.mjs";
import { DEFAULT_SOURCE_NAME, DEFAULT_TARGET_ID, DEFAULT_TARGET_NAME } from "./defaults.mjs";


loadEnvOpen();

const oldUrl = required("OLD_SUPABASE_URL");
const oldKey = required("OLD_SUPABASE_SERVICE_ROLE_KEY");
const newUrl = required("SUPABASE_URL");

if (cleanUrl(oldUrl) === cleanUrl(newUrl)) {
  console.error("✖ OLD_SUPABASE_URL و SUPABASE_URL متطابقان — توقّفتُ قبل أيّ شيء. الجديدةُ يجب أن تكون manara-open-app.");
  process.exit(2);
}

const apply = arg("apply", false) === true;
const dry = arg("dry", false) === true;
const target = {
  id: String(arg("target-id", DEFAULT_TARGET_ID)),
  name: String(arg("target-name", DEFAULT_TARGET_NAME)),
};

const old = client({ url: oldUrl, key: oldKey, readOnly: true, label: "القديمة" });

// ── ١. المعلمُ المصدر ──
const teachers = await old.all("teachers", "select=id,data");
const sourceId = arg("source-id");
const sourceName = String(arg("source-name", DEFAULT_SOURCE_NAME));
const source = typeof sourceId === "string"
  ? teachers.find((t) => t.id === sourceId)
  : teachers.find((t) => normalizeOwner(t.data?.name) === normalizeOwner(sourceName));
if (!source) {
  console.error(`✖ لم أجد المعلم المصدر (${sourceId || sourceName}). المعلمون: ${teachers.map((t) => `${t.data?.name} [${t.id}]`).join("، ")}`);
  process.exit(1);
}
console.log(`• المصدر: ${source.data.name} [${source.id}] ← الهدف: ${target.name} [${target.id}]`);

// ── ٢. محتواه (قراءةٌ وحدها) ──
async function maybe(table, query) {
  try {
    return await old.all(table, query);
  } catch (error) {
    if (error.status === 404) return [];
    throw error;
  }
}
const kvRows = await old.all("app_kv", "select=key,value");
const rows = buildClone(
  {
    teacher: source,
    lessonConfigs: await old.all("lesson_configs", "select=id,data"),
    createdQuizzes: await old.all("created_quizzes", "select=id,data"),
    kv: Object.fromEntries(kvRows.map((r) => [r.key, r.value])),
    cinemaVideos: await maybe("cinema_videos", "select=*"),
    entertainmentGames: await maybe("entertainment_games", "select=*"),
    duelQuestions: await maybe("duel_questions", "select=*&order=id"),
  },
  target,
);
const counts = summarize(rows);
console.log("• ما يُنسخ:", counts);

if (dry) process.exit(0);

// ── ٣. ملفُّ SQL ──
const outFile = path.resolve(String(arg("out", path.join(editionRoot, "out", "seed-teacher.sql"))));
mkdirSync(path.dirname(outFile), { recursive: true });
writeFileSync(
  outFile,
  renderSeedSql(rows, { fromId: source.id, fromName: source.data.name, toId: target.id, toName: target.name }),
  "utf8",
);
console.log(`✔ كُتب ${outFile}`);

// ── ٤. الكتابةُ في manara-open-app (اختياري) ──
if (apply) {
  const fresh = client({ url: newUrl, key: required("SUPABASE_SERVICE_ROLE_KEY"), label: "manara-open-app" });
  const conflict = { app_kv: "key" };
  // ‏في جداول الأعمدة: الحقلُ الفارغ (null) في القديمة يُترك فيأخذ قيمته الافتراضية
  // ‏(description='' مثلاً)، فـ null صريحٌ يكسر not null ولا يطبّق الافتراضي.
  const withoutNulls = (row) => Object.fromEntries(Object.entries(row).filter(([, v]) => v !== null && v !== undefined));
  for (const [table, list] of Object.entries(rows)) {
    for (let i = 0; i < list.length; i += 200) {
      const chunk = list.slice(i, i + 200).map(withoutNulls);
      // ‏PostgREST يطلب مفاتيحَ واحدةً لكل صفوف الطلب، إلا مع `columns`: فيُعطى اتحادُها،
      // ‏والمفتاحُ الغائب عن صفٍّ يأخذ الافتراضي (missing=default).
      const columns = [...new Set(chunk.flatMap((row) => Object.keys(row)))].join(",");
      await fresh.call(`${table}?on_conflict=${conflict[table] || "id"}&columns=${encodeURIComponent(columns)}`, {
        method: "POST",
        headers: { Prefer: "resolution=merge-duplicates,missing=default,return=minimal" },
        body: JSON.stringify(chunk),
      });
    }
    console.log(`  ✔ ${table}: ${list.length}`);
  }
  console.log(`✔ اكتمل الاستنساخ في ${cleanUrl(newUrl)}.`);
  console.log(`  اضبط في خدمة Railway الجديدة: OPEN_TEACHER_ID=${target.id}`);
} else {
  console.log("  لم يُكتب شيءٌ في manara-open-app. الصق الملفَّ في SQL Editor، أو أعد التشغيل بـ --apply.");
}
