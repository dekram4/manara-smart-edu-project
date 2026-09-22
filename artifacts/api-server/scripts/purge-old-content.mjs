#!/usr/bin/env node
/**
 * يُبقي دروس منهج الرياضيات الواحد والعشرين ويحذف كل ما عداها، من كل
 * مالك، ثم يرفع ختم المحتوى ليُسقط كاش الأجهزة.
 *
 * ── لماذا لا يكفي الحذف وحده ──
 * نسخة الجهاز تُدمج مع ما في الخادم اتحاداً، وما ليس في الخادم يُرفع
 * إليه. فجوّالٌ لم يُفتح منذ التنظيف لا يعرض المحذوف فحسب: يرفعه من جديد
 * فيعود إلى الجميع — وهذا ما رآه صاحب المشروع. فيرفع هذا السكربت
 * `smartEdu_contentEpoch`، والتطبيق يقارنه بما رآه فيُسقط نسخته كلّها
 * ويأخذ ما في الخادم. مرةً واحدة، ثم يعود الدمج المعتاد.
 *
 * ── ما يُحذف وما يبقى ──
 * يبقى: كل درس معرّفه من معرّفات المنهج الواحد والعشرين، مهما كان مالكه.
 * يُحذف: كل ما سواه في `lesson_configs`، **من كل مالك** — b و admin
 * والمعلمون ومن لا مالك له. وهذا ما طُلب صراحةً.
 *
 * والاختبارات تُحذف كلّها بـ `--with-quizzes`، فهي مبنية على دروس لم تعد
 * موجودة. وتبقى بدونه.
 *
 * ── الضمانة ──
 * لا يكتب شيئاً بلا `--execute`. ويطبع ما سيُحذف وما سيبقى قبل ذلك،
 * ويقرأ المخزون بعده للتحقّق.
 *
 * التشغيل:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
 *     node scripts/purge-old-content.mjs --with-quizzes
 *   ثم أضف --execute للتنفيذ.
 */

import { curriculumRows, GRADE, SUBJECT } from "./grade4-math-curriculum.mjs";

const args = process.argv.slice(2);
const EXECUTE = args.includes("--execute");
const WITH_QUIZZES = args.includes("--with-quizzes");

const SUPABASE_URL = process.env.SUPABASE_URL?.trim().replace(/\/+$/, "");
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

const EPOCH_KEY = "smartEdu_contentEpoch";

const headers = () => ({
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  "Content-Type": "application/json",
});

const text = (value) => (value == null ? "" : String(value).trim());
const norm = (value) => text(value).toLowerCase();

const ownerOf = (record) =>
  norm(record?.teacherId ?? record?.teacher_id ?? record?.createdBy) || "(بلا مالك)";

/**
 * هل هذا السجلّ من دروس المنهج المعتمد؟
 *
 * يُعرف بمساره لا بمعرّفه: المعرّف يحمل اسم المالك، فنسخة الدرس نفسها
 * عند معلّم آخر معرّفها مختلف — وهي منهجٌ معتمد كذلك. والمسار هو ما
 * يُقارَن: الصف والمادة واسم الدرس.
 */
export function isCurriculumLesson(data, names) {
  return (
    norm(data?.grade) === norm(GRADE) &&
    norm(data?.subject) === norm(SUBJECT) &&
    names.has(norm(data?.lesson))
  );
}

export function partitionLessons(rows, names) {
  const kept = [];
  const dropped = [];
  for (const row of Array.isArray(rows) ? rows : []) {
    (isCurriculumLesson(row?.data, names) ? kept : dropped).push(row);
  }
  return { kept, dropped };
}

async function readJson(path) {
  const response = await fetch(`${SUPABASE_URL}${path}`, { headers: headers() });
  if (!response.ok) {
    throw new Error(`GET ${path} → ${response.status} ${(await response.text()).slice(0, 200)}`);
  }
  return response.json();
}

const line = (t = "") => console.log(t);
const head = (t) => {
  line();
  line(`════ ${t} ════`);
};

async function main() {
  if (!SUPABASE_URL || !SERVICE_KEY) {
    console.error("SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY مطلوبان.");
    process.exit(1);
  }

  const names = new Set(curriculumRows().map((row) => norm(row.name)));
  line(EXECUTE ? "✍️ تنفيذ فعلي." : "🔍 معاينة — لن يُكتب شيء. أضف --execute للتنفيذ.");
  line(`المنهج المعتمد: ${names.size} درساً في «${SUBJECT}» لـ«${GRADE}».`);

  // ── الدروس ──────────────────────────────────────────────────────────
  head("الدروس");
  const lessons = await readJson("/rest/v1/lesson_configs?select=id,data&limit=10000");
  const { kept, dropped } = partitionLessons(lessons, names);
  line(`الإجمالي: ${lessons.length}   يبقى: ${kept.length}   يُحذف: ${dropped.length}`);

  const byOwner = new Map();
  for (const row of dropped) {
    const owner = ownerOf(row?.data);
    byOwner.set(owner, (byOwner.get(owner) || 0) + 1);
  }
  if (byOwner.size) {
    line("المحذوف بحسب المالك:");
    for (const [owner, count] of [...byOwner].sort((a, b) => b[1] - a[1])) {
      line(`  • ${owner}: ${count}`);
    }
  }
  const keptOwners = new Map();
  for (const row of kept) {
    const owner = ownerOf(row?.data);
    keptOwners.set(owner, (keptOwners.get(owner) || 0) + 1);
  }
  if (keptOwners.size) {
    line("الباقي بحسب المالك:");
    for (const [owner, count] of keptOwners) line(`  • ${owner}: ${count}`);
  }
  const withoutText = kept.filter((row) => !text(row?.data?.lessonContent));
  if (withoutText.length) {
    line(`⚠️ ${withoutText.length} من الباقي بلا نصّ — شغّل seed-grade4-math-full.mjs بعده.`);
  }

  // ── الاختبارات ──────────────────────────────────────────────────────
  head("الاختبارات");
  const quizzes = await readJson("/rest/v1/created_quizzes?select=id,data&limit=10000");
  line(
    WITH_QUIZZES
      ? `الإجمالي: ${quizzes.length} — تُحذف كلّها (مبنية على دروس لم تعد موجودة).`
      : `الإجمالي: ${quizzes.length} — تبقى كما هي (أضف --with-quizzes لحذفها).`,
  );

  const stamp = new Date().toISOString();
  head("ختم المحتوى");
  line(`سيُرفع إلى: ${stamp}`);
  line("وكل جهاز يفتح بعده يُسقط نسخته المحلية ويأخذ ما في الخادم.");

  if (!EXECUTE) {
    line();
    line("(معاينة فقط — لم يُكتب شيء)");
    return;
  }

  // ── التنفيذ ─────────────────────────────────────────────────────────
  head("التنفيذ");
  for (const row of dropped) {
    const response = await fetch(
      `${SUPABASE_URL}/rest/v1/lesson_configs?id=eq.${encodeURIComponent(row.id)}`,
      { method: "DELETE", headers: { ...headers(), Prefer: "return=minimal" } },
    );
    if (!response.ok) throw new Error(`تعذّر حذف الدرس ${row.id}: ${response.status}`);
  }
  line(`حُذف ${dropped.length} درساً.`);

  if (WITH_QUIZZES) {
    for (const row of quizzes) {
      const response = await fetch(
        `${SUPABASE_URL}/rest/v1/created_quizzes?id=eq.${encodeURIComponent(row.id)}`,
        { method: "DELETE", headers: { ...headers(), Prefer: "return=minimal" } },
      );
      if (!response.ok) throw new Error(`تعذّر حذف الاختبار ${row.id}: ${response.status}`);
    }
    line(`حُذف ${quizzes.length} اختباراً.`);
  }

  const epochResponse = await fetch(`${SUPABASE_URL}/rest/v1/app_kv?on_conflict=key`, {
    method: "POST",
    headers: { ...headers(), Prefer: "resolution=merge-duplicates,return=minimal" },
    body: JSON.stringify({ key: EPOCH_KEY, value: stamp, updated_at: stamp }),
  });
  if (!epochResponse.ok) {
    throw new Error(`تعذّر رفع الختم: ${epochResponse.status}`);
  }
  line(`رُفع ختم المحتوى: ${stamp}`);

  // ── التحقّق ─────────────────────────────────────────────────────────
  head("التحقّق");
  const after = await readJson("/rest/v1/lesson_configs?select=id,data&limit=10000");
  const left = partitionLessons(after, names);
  const afterQuizzes = await readJson("/rest/v1/created_quizzes?select=id&limit=10000");
  const afterEpoch = await readJson(
    `/rest/v1/app_kv?select=key,value&key=eq.${encodeURIComponent(EPOCH_KEY)}`,
  );

  line(`الدروس في قاعدة البيانات الآن: ${after.length} — منها ${left.kept.length} من المنهج، و${left.dropped.length} غريب.`);
  line(`الاختبارات: ${afterQuizzes.length}`);
  line(`الختم المخزّن: ${afterEpoch?.[0]?.value ?? "—"}`);

  const problems = [];
  if (left.dropped.length) problems.push(`بقي ${left.dropped.length} درساً قديماً`);
  if (WITH_QUIZZES && afterQuizzes.length) problems.push(`بقي ${afterQuizzes.length} اختباراً`);
  if (text(afterEpoch?.[0]?.value) !== stamp) problems.push("الختم لم يُكتب");
  if (problems.length) {
    console.error(`❌ التحقّق فشل: ${problems.join(" — ")}`);
    process.exit(1);
  }
  line("✅ لم يبقَ إلا المنهج، والختم مرفوع.");
}

if (process.argv[1] && process.argv[1].endsWith("purge-old-content.mjs")) {
  main().catch((error) => {
    console.error("فشل:", error.message);
    process.exit(1);
  });
}
