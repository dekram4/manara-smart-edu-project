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
import {
  GRADE4_SCIENCE_CURRICULUM,
  ID_PREFIX as SCIENCE_PREFIX,
  SUBJECT as SCIENCE_SUBJECT,
} from "./curriculum/grade4-science-curriculum.mjs";
import {
  GRADE4_ENGLISH_CURRICULUM,
  ID_PREFIX as ENGLISH_PREFIX,
  SUBJECT as ENGLISH_SUBJECT,
} from "./curriculum/grade4-english-curriculum.mjs";

const args = process.argv.slice(2);
const EXECUTE = args.includes("--execute");
const WITH_QUIZZES = args.includes("--with-quizzes");
const WITH_TREE = args.includes("--with-tree");

const SUPABASE_URL = process.env.SUPABASE_URL?.trim().replace(/\/+$/, "");
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

const EPOCH_KEY = "smartEdu_contentEpoch";
const HIERARCHY_KEY = "smartEdu_hierarchicalConfigs";

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
 * المناهج المعتمدة: لكلٍّ مادته وبادئة معرّفاته وأسماء دروسه ونصوصها.
 *
 * تُقرأ من ملفَّي المنهج نفسيهما، فإضافة مادة ثالثة لاحقاً تُضاف هنا
 * بسطر ولا تُنسَخ أسماؤها في موضعين يفترقان.
 */
const CURRICULA = [
  {
    subject: SUBJECT,
    prefix: "g4math_",
    lessons: curriculumRows().map((row) => ({ name: row.name, text: row.text })),
  },
  {
    subject: SCIENCE_SUBJECT,
    prefix: SCIENCE_PREFIX,
    lessons: GRADE4_SCIENCE_CURRICULUM.map((item) => ({
      name: item.lesson,
      text: item.content,
    })),
  },
  {
    subject: ENGLISH_SUBJECT,
    prefix: ENGLISH_PREFIX,
    lessons: GRADE4_ENGLISH_CURRICULUM.map((item) => ({
      name: item.lesson,
      text: item.content,
    })),
  },
];

/** فهرسٌ بالمادة: أسماء دروسها ونصوصها وبادئتها. */
const BY_SUBJECT = new Map(
  CURRICULA.map((entry) => [
    normSubject(entry.subject),
    {
      prefix: entry.prefix,
      names: new Set(entry.lessons.map((lesson) => norm(lesson.name))),
      texts: new Set(entry.lessons.map((lesson) => norm(lesson.text))),
    },
  ]),
);

function normSubject(value) {
  return norm(value);
}

/**
 * هل هذا السجلّ من دروس المنهج المعتمد؟
 *
 * ── لماذا لا يكفي المسار ──
 * كانت المقارنة بالمسار وحده — الصف والمادة واسم الدرس — لتبقى نسخة
 * الدرس عند معلّم آخر، فهي منهجٌ معتمد كذلك. لكن سجلاً قديماً كُتب بيد
 * المعلّم تحت الاسم نفسه يمرّ من هذا الباب: أربعة منها نجت من التنظيف
 * وبقيت في الجدول خمسة وعشرين بدل واحد وعشرين، ونصوصها مبتورة (١٧٢ إلى
 * ٤١٦ حرفاً) بينما نصوص المنهج أطول من ذلك بكثير — فيقرأ الطالب نصفَ
 * درس، ويولّد منه الذكاءُ الاصطناعي نصفَ اختبار.
 *
 * ── فما يُعتمد ──
 * أن يكون على مسار المنهج، **و** أن يحمل بادئة البذر أو نصَّ المنهج
 * حرفاً بحرف. فنسخ البذر تبقى مهما كان مالكها — معرّفاتها كلّها تبدأ
 * بالبادئة — ويسقط ما كُتب باليد تحت الاسم نفسه.
 */
export function isCurriculumLesson(data, _names, _texts, id) {
  if (norm(data?.grade) !== norm(GRADE)) return false;
  const curriculum = BY_SUBJECT.get(normSubject(data?.subject));
  if (!curriculum) return false;
  if (!curriculum.names.has(norm(data?.lesson))) return false;
  return (
    text(id).startsWith(curriculum.prefix) ||
    curriculum.texts.has(norm(data?.lessonContent))
  );
}

/** سبب الإسقاط، ليُطبع بجانب السجلّ فيُعرف لماذا ذهب. */
export function dropReason(data, _names, _texts, id) {
  if (norm(data?.grade) !== norm(GRADE)) return `صفّ آخر: ${text(data?.grade) || "—"}`;
  const curriculum = BY_SUBJECT.get(normSubject(data?.subject));
  if (!curriculum) return `مادة خارج المناهج المعتمدة: ${text(data?.subject) || "—"}`;
  if (!curriculum.names.has(norm(data?.lesson))) {
    return `درس خارج المنهج: ${text(data?.lesson) || "—"}`;
  }
  if (
    !text(id).startsWith(curriculum.prefix) &&
    !curriculum.texts.has(norm(data?.lessonContent))
  ) {
    return `نسخة قديمة بالاسم نفسه (${text(data?.lessonContent).length} حرفاً)`;
  }
  return "—";
}

export function partitionLessons(rows, names, texts) {
  const kept = [];
  const dropped = [];
  for (const row of Array.isArray(rows) ? rows : []) {
    (isCurriculumLesson(row?.data, names, texts, row?.id) ? kept : dropped).push(row);
  }
  return { kept, dropped };
}

/**
 * الشجرة بعد إسقاط كل ما ليس الصفّ والمادة المعتمدين، من كل مالك.
 *
 * الشجرة هي ما يملأ قوائم إدارة المحتوى وشاشة الطالب، فصفٌّ أو مادة
 * باقية فيها تظهر للمستخدم ولو لم يبقَ تحتها درس — وذلك ما يُرى «محتوًى
 * قديماً لم يُحذف».
 *
 * والمدخل الذي يحمل الصفّ المعتمد يُنقّى ولا يُحذف: تُترك فيه المادة
 * المعتمدة وتُسقط سائر المواد، فلا تضيع شجرة معلّم بنى عليها.
 */
export function pruneTree(configs) {
  const kept = [];
  const notes = [];
  for (const config of Array.isArray(configs) ? configs : []) {
    if (!config || typeof config !== "object") continue;
    const owner = ownerOf(config);
    if (norm(config.grade) !== norm(GRADE)) {
      notes.push(`حُذف صفّ «${text(config.grade)}» [${owner}]`);
      continue;
    }
    const subjects = Array.isArray(config.subjects) ? config.subjects : [];
    const mine = subjects.filter((item) => BY_SUBJECT.has(normSubject(item?.subject)));
    for (const item of subjects) {
      if (!BY_SUBJECT.has(normSubject(item?.subject))) {
        notes.push(`حُذفت مادة «${text(item?.subject)}» من «${text(config.grade)}» [${owner}]`);
      }
    }
    if (mine.length === 0) {
      notes.push(`حُذف «${text(config.grade)}» [${owner}] — لا مادة معتمدة فيه`);
      continue;
    }
    kept.push({ ...config, subjects: mine });
  }
  return { kept, notes };
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

  const names = null;
  const texts = null;
  const total = CURRICULA.reduce((sum, entry) => sum + entry.lessons.length, 0);
  line(EXECUTE ? "✍️ تنفيذ فعلي." : "🔍 معاينة — لن يُكتب شيء. أضف --execute للتنفيذ.");
  line(`المناهج المعتمدة لـ«${GRADE}»: ${total} درساً —`);
  for (const entry of CURRICULA) {
    line(`  • ${entry.subject}: ${entry.lessons.length} درساً، بادئتها ${entry.prefix}`);
  }

  // ── الدروس ──────────────────────────────────────────────────────────
  head("الدروس");
  const lessons = await readJson("/rest/v1/lesson_configs?select=id,data&limit=10000");
  const { kept, dropped } = partitionLessons(lessons, names, texts);
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
    line("وبالتفصيل:");
    for (const row of dropped) {
      line(`  ✖ id=${row.id}  «${text(row?.data?.lesson) || "—"}»  — ${dropReason(row?.data, names, texts, row?.id)}`);
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

  // ── الشجرة الأكاديمية ───────────────────────────────────────────────
  head("الشجرة الأكاديمية");
  const kvRows = await readJson(
    `/rest/v1/app_kv?select=key,value&key=eq.${encodeURIComponent(HIERARCHY_KEY)}`,
  );
  const tree = Array.isArray(kvRows?.[0]?.value) ? kvRows[0].value : [];
  const pruned = pruneTree(tree);
  if (!WITH_TREE) {
    line(`المدخلات: ${tree.length} — تبقى كما هي (أضف --with-tree لتنقيتها).`);
    const wouldDrop = tree.length - pruned.kept.length;
    if (wouldDrop > 0 || pruned.notes.length) {
      line(`  (لو نُقّيت: تبقى ${pruned.kept.length}، وتُحذف ${wouldDrop})`);
    }
  } else {
    line(`المدخلات: ${tree.length} → تبقى ${pruned.kept.length}`);
    for (const note of pruned.notes) line(`  • ${note}`);
  }

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

  if (WITH_TREE) {
    const treeResponse = await fetch(`${SUPABASE_URL}/rest/v1/app_kv?on_conflict=key`, {
      method: "POST",
      headers: { ...headers(), Prefer: "resolution=merge-duplicates,return=minimal" },
      body: JSON.stringify({
        key: HIERARCHY_KEY,
        value: pruned.kept,
        updated_at: new Date().toISOString(),
      }),
    });
    if (!treeResponse.ok) {
      throw new Error(`تعذّرت كتابة الشجرة: ${treeResponse.status}`);
    }
    line(`نُقّيت الشجرة: ${pruned.kept.length} مدخلاً.`);
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
  const left = partitionLessons(after, names, texts);
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
