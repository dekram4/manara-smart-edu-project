#!/usr/bin/env node
/**
 * تفريغُ محتوى `manara-open-app` قبل الاستنساخ، بعد نسخةٍ احتياطيةٍ محلّية.
 *
 * ── لماذا ──
 * وُجدت في القاعدة الجديدة نسخةٌ جزئيةٌ من المنصّة القديمة استُوردت قبل الاستنساخ:
 * - معلّمان، أحدهما حسابُ تجربة.
 * - طلابٌ حقيقيون ووليُّ أمر، وتفاعلاتُهم ونتائجُهم ورسائلُهم وشهاداتُهم.
 * - دروسُ المعلم الآخر وفيديوهاتُه وألعابه.
 * والنسخةُ المفتوحة لمعلّمٍ واحد، وطلابُها يدخلون بأسمائهم فيها. فتُفرَّغ هذه
 * الجداول، ثم يملؤها clone-teacher.mjs --apply بالمعلم الجديد ومحتواه وحده.
 *
 * ── ما لا يُمسّ ──
 * - القاعدةُ القديمة: لا يعرف عنوانها ولا يتّصل بها.
 * - `duel_questions`: بنكُ الأسئلة العام (seed)، والاستنساخُ يحدّثه.
 * - `ai_qa_cache`: دائمٌ بقادحٍ يمنع الحذف (solved-questions-cache.sql).
 * - جداولُ لا يستعملها الخادم (duel_questions_bank…).
 *
 * ── الحماية ──
 * - لا يعمل إلا على مشروع manara-open-app (yvvgvbwokclinsiabmzx)، ومع `--confirm`.
 * - يكتب أوّلاً كلَّ صفوف الجداول التي يفرّغها في `open-edition/out/backup-<الوقت>.json`،
 *   وهو مستثنى من git لأن فيه بياناتٍ شخصية.
 *
 * التشغيل: node open-edition/scripts/reset-open.mjs --confirm
 */

import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { arg, cleanUrl, client, editionRoot, loadEnvOpen, required } from "./lib.mjs";

loadEnvOpen();

const OPEN_REF = "yvvgvbwokclinsiabmzx";
const url = required("SUPABASE_URL");
if (!cleanUrl(url).includes(OPEN_REF)) {
  console.error(`✖ SUPABASE_URL ليس manara-open-app (${OPEN_REF}) — توقّفتُ قبل أيّ شيء.`);
  process.exit(2);
}
if (process.env.OLD_SUPABASE_URL && cleanUrl(process.env.OLD_SUPABASE_URL) === cleanUrl(url)) {
  console.error("✖ OLD_SUPABASE_URL و SUPABASE_URL متطابقان — توقّفتُ قبل أيّ شيء.");
  process.exit(2);
}

/** الجدولُ وعمودٌ لا يكون فارغاً، فيُحذف به كلُّ صفّ (PostgREST لا يحذف بلا شرط). */
export const RESET_TABLES = [
  ["challenge_matches", "id"], // ‏ومعها match_answers و match_messages (on delete cascade)
  ["match_answers", "match_id"],
  ["match_messages", "id"],
  ["interactions", "id"],
  ["quiz_results", "id"],
  ["private_messages", "id"],
  ["public_messages", "id"],
  ["certificates", "id"],
  ["student_card_permissions", "id"],
  ["students", "id"],
  ["parents", "id"],
  ["lesson_configs", "id"],
  ["created_quizzes", "id"],
  ["cinema_videos", "id"],
  ["entertainment_games", "id"],
  ["app_kv", "key"],
  ["teachers", "id"],
];

const db = client({ url, key: required("SUPABASE_SERVICE_ROLE_KEY"), label: "manara-open-app" });

const backup = {};
for (const [table] of RESET_TABLES) backup[table] = await db.all(table);
const counts = Object.fromEntries(Object.entries(backup).map(([t, rows]) => [t, rows.length]));
console.log("• في القاعدة الآن:", counts);

if (arg("confirm", false) !== true) {
  console.log("  لم يُحذف شيء. أعد التشغيل بـ --confirm للتفريغ.");
  process.exit(0);
}

const stamp = new Date().toISOString().replace(/[:.]/g, "-");
const file = path.join(editionRoot, "out", `backup-${stamp}.json`);
mkdirSync(path.dirname(file), { recursive: true });
writeFileSync(file, JSON.stringify({ url: cleanUrl(url), takenAt: new Date().toISOString(), tables: backup }), "utf8");
console.log(`✔ نسخةٌ احتياطية: ${file}`);

for (const [table, column] of RESET_TABLES) {
  await db.call(`${table}?${column}=not.is.null`, { method: "DELETE", headers: { Prefer: "return=minimal" } });
  const left = await db.call(`${table}?select=${column}&limit=1`);
  console.log(`  ${left.length ? "✖" : "✔"} ${table}: ${counts[table]} ← ${left.length ? "بقي فيه صفوف" : "فارغ"}`);
}
console.log("✔ فُرِّغت. التالي: node open-edition/scripts/clone-teacher.mjs --apply");
