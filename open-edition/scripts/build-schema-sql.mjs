#!/usr/bin/env node
/**
 * يجمع بنيةَ قاعدة منارة كاملةً في ملفٍّ واحد لمشروع `manara-open-app`:
 * `open-edition/sql/01-schema.sql`.
 *
 * ── من ملفّات المشروع نفسها، لا نسخةٍ منها ──
 * الأجزاءُ هي سكربتاتُ الخادم كما هي (`artifacts/api-server/scripts/*.sql`)
 * بترتيب اعتمادها، فتبقى القاعدتان على بنيةٍ واحدة: يُعدَّل الجزءُ في مكانه
 * ثم يُعاد هذا السكربت. ولا يقرأ قاعدةً ولا يكتب فيها.
 *
 * ── وما يُترك عمداً ──
 *   harden-rls.sql            قديم: security-lockdown.sql يحلّ محلّه.
 *   duel-party.sql            لم يعد لازماً (انظر رأسه).
 *   duel-reset.sql            حذفٌ للمباريات — لا معنى له في قاعدةٍ جديدة.
 *   dev-level-up.sql          أداةُ تجربةٍ لطالبٍ بعينه.
 *   split-noorania-subject.sql هجرةُ بياناتٍ تمّت في القديمة، ونتيجتُها تُنسخ مع المحتوى.
 *   chat-ephemeral.sql        تنظيفٌ لمرّةٍ لرسائل قديمة لا وجود لها هنا.
 *   apply-supabase*.sql       تجميعاتٌ لأجزاءٍ مدرجةٍ هنا.
 *
 * التشغيل (من جذر المستودع): node open-edition/scripts/build-schema-sql.mjs
 */

import { readFile, writeFile, mkdir } from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { editionRoot, repoRoot } from "./lib.mjs";

const scripts = path.join(repoRoot, "artifacts", "api-server", "scripts");

/** الأجزاءُ بترتيب اعتمادها. */
export const PARTS = [
  ["artifacts/manara/src/db/schema.sql", "جداولُ الكيانات و app_kv"],
  [path.join(scripts, "ai-qa-cache.sql"), "ذاكرةُ إجابات الذكاء الاصطناعي"],
  [path.join(scripts, "challenge-matches.sql"), "مبارياتُ التحدي"],
  [path.join(scripts, "duel-upgrade.sql"), "حزمةُ أسئلة المباراة وسجلُّ المحادثة"],
  [path.join(scripts, "duel-question-bank.sql"), "بنكُ أسئلة المبارزة"],
  [path.join(scripts, "duel-live.sql"), "المبارزةُ الحيّة"],
  [path.join(scripts, "duel-handshake.sql"), "مصافحةُ النزال"],
  [path.join(scripts, "duel-question-sources.sql"), "مصدرُ أسئلة المبارزة"],
  [path.join(scripts, "cinema-and-card-permissions.sql"), "السينما وصلاحياتُ البطاقات"],
  [path.join(scripts, "entertainment-games.sql"), "الترفيهُ والألعاب"],
  [path.join(scripts, "solved-questions-cache.sql"), "ذاكرةُ «حل المسائل»"],
  [path.join(scripts, "security-lockdown.sql"), "إغلاقُ المفتاح العام — قراءةُ المحتوى وحده"],
  [path.join(scripts, "ai-qa-cache-vectors.sql"), "مطابقةُ الإجابات بالمعنى"],
  [path.join(scripts, "duel-knowledge-bank.sql"), "أبوابُ المعرفة العامّة"],
];

export const OUTPUT = path.join(editionRoot, "sql", "01-schema.sql");

const VERIFY = `-- ┌──────────────────────────────────────────────────────────────
-- │ التحقّق — صفٌّ واحد يظهر في المحرّر
-- └──────────────────────────────────────────────────────────────

notify pgrst, 'reload schema';

select
  (select count(*) from pg_tables where schemaname = 'public') as public_tables,
  (select count(*) from information_schema.role_table_grants
     where table_schema = 'public' and grantee = 'service_role' and privilege_type = 'INSERT')
    as service_role_writable_tables,
  (select count(*) from information_schema.role_table_grants
     where table_schema = 'public' and grantee in ('anon', 'authenticated')
       and privilege_type <> 'SELECT')
    as anon_write_grants_expected_0,
  (select string_agg(distinct table_name, ', ' order by table_name)
     from information_schema.role_table_grants
     where table_schema = 'public' and grantee = 'anon' and privilege_type = 'SELECT')
    as anon_readable_expected_app_kv_created_quizzes_lesson_configs;
`;

export async function renderSchemaSql() {
  const sections = [];
  for (const [file, label] of PARTS) {
    const full = path.isAbsolute(file) ? file : path.join(repoRoot, file);
    const body = (await readFile(full, "utf8")).replace(/^﻿/, "").replace(/\r\n/g, "\n").trimEnd();
    const name = path.relative(repoRoot, full).split(path.sep).join("/");
    sections.push(`-- ┌──────────────────────────────────────────────────────────────\n-- │ ${name} — ${label}\n-- └──────────────────────────────────────────────────────────────\n\n${body}\n`);
  }
  return [
    "-- مولَّدٌ بـ open-edition/scripts/build-schema-sql.mjs — لا يُعدَّل باليد.",
    "-- ⚠️ لمشروع manara-open-app وحده: Supabase → SQL Editor → New query → الصق الملفَّ كلَّه → Run.",
    "-- آمنٌ على قاعدةٍ فيها الجداولُ من قبل، ويُعاد تشغيله بلا ضرر.",
    "-- قبل اللصق: محرّرٌ فارغ، ولا تحديدَ لجزءٍ من النصّ (المحرّر يشغّل المحدَّد وحده).",
    "",
    sections.join("\n"),
    VERIFY,
  ].join("\n");
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  await mkdir(path.dirname(OUTPUT), { recursive: true });
  await writeFile(OUTPUT, await renderSchemaSql(), "utf8");
  console.log(`wrote ${OUTPUT}`);
}
