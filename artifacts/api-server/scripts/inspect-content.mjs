#!/usr/bin/env node
/**
 * يجرد كل موضع يمكن أن يسكنه درسٌ أو مادة، ويطبع ما فيه. لا يكتب شيئاً.
 *
 * ── لماذا ──
 * حين يبقى المحتوى القديم ظاهراً بعد التنظيف، يستحيل الفصل بين ثلاثة
 * احتمالات من الشاشة وحدها: محتوًى ما زال في قاعدة البيانات، أو نسخة
 * قديمة في متصفّح لم يُحدَّث بناؤه، أو موضعٌ لم يُنظَّف أصلاً. هذا الجرد
 * يقطع الشك: كل ما يطبعه مقروء من Supabase في هذه اللحظة.
 *
 * ── أين يُبحث ──
 * جدول `lesson_configs` — وهو المصدر الوحيد الذي تقرؤه شاشة إدارة
 * المحتوى، عبر `smartEdu_lessonConfigs` في متصفّح المستخدم. ثم كل مفاتيح
 * `app_kv` بلا استثناء: تُطبع بأسمائها وأحجامها، ويُكشف ما يحمل منها
 * مواد أو دروساً — فإن كان المحتوى في مفتاح لم يخطر ببال أحد، ظهر هنا.
 *
 * التشغيل:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
 *     node scripts/inspect-content.mjs
 */

import { curriculumRows } from "./grade4-math-curriculum.mjs";
import { GRADE4_SCIENCE_CURRICULUM } from "./curriculum/grade4-science-curriculum.mjs";
import { GRADE4_ENGLISH_CURRICULUM } from "./curriculum/grade4-english-curriculum.mjs";

/** البادئات المعتمدة وعدد دروس كل منهج، ليُقارن بها ما في الجدول. */
const EXPECTED = [
  { prefix: "g4math_", subject: "الرياضيات", count: curriculumRows().length },
  { prefix: "g4sci_", subject: "العلوم", count: GRADE4_SCIENCE_CURRICULUM.length },
  { prefix: "g4eng_", subject: "اللغة الإنجليزية", count: GRADE4_ENGLISH_CURRICULUM.length },
];

const SUPABASE_URL = process.env.SUPABASE_URL?.trim().replace(/\/+$/, "");
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

const headers = () => ({
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  "Content-Type": "application/json",
});

const text = (value) => (value == null ? "" : String(value).trim());
const ownerOf = (record) =>
  text(record?.teacherId ?? record?.teacher_id ?? record?.createdBy).toLowerCase() ||
  "(بلا مالك)";

/** يعدّ القيم ويرتّبها تنازلياً، للطباعة. */
export function tally(values) {
  const counts = new Map();
  for (const value of values) {
    const key = text(value) || "(فارغ)";
    counts.set(key, (counts.get(key) || 0) + 1);
  }
  return [...counts].sort((a, b) => b[1] - a[1]);
}

/**
 * هل تحمل هذه القيمة مواد أو دروساً؟
 *
 * تُفحص القيمة نفسها لا اسم مفتاحها: المحتوى قد يسكن مفتاحاً لا يدلّ
 * اسمه عليه، وهو بالضبط ما يُبحث عنه هنا.
 */
export function looksAcademic(value) {
  const seen = { subjects: new Set(), grades: new Set(), lessons: 0 };
  const walk = (node, depth) => {
    if (!node || depth > 6) return;
    if (Array.isArray(node)) {
      for (const item of node) walk(item, depth + 1);
      return;
    }
    if (typeof node !== "object") return;
    if (text(node.subject)) seen.subjects.add(text(node.subject));
    if (text(node.grade)) seen.grades.add(text(node.grade));
    if (text(node.lesson) || text(node.lessonContent)) seen.lessons += 1;
    for (const child of Object.values(node)) walk(child, depth + 1);
  };
  walk(value, 0);
  return seen;
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
  line("جردٌ للقراءة فقط — لا يُكتب ولا يُحذف شيء.");

  // ── الجدول الذي تقرؤه شاشة إدارة المحتوى ───────────────────────────
  head("lesson_configs — مصدر شاشة إدارة المحتوى");
  const lessons = await readJson("/rest/v1/lesson_configs?select=id,data&limit=10000");
  const rows = Array.isArray(lessons) ? lessons : [];
  line(`عدد السجلّات: ${rows.length}`);

  // ما يطابق البادئات المعتمدة، وما لا يطابقها — وهو ما يُشكّ فيه.
  line();
  line("بحسب البادئة المعتمدة:");
  let recognised = 0;
  for (const entry of EXPECTED) {
    const found = rows.filter((r) => String(r.id ?? "").startsWith(entry.prefix));
    recognised += found.length;
    const mark = found.length === entry.count ? "✅" : "⚠️";
    line(`  ${mark} ${entry.prefix} (${entry.subject}): ${found.length} من ${entry.count}`);
  }
  const strangers = rows.filter(
    (r) => !EXPECTED.some((e) => String(r.id ?? "").startsWith(e.prefix)),
  );
  line(`  ${strangers.length === 0 ? "✅" : "⚠️"} بلا بادئة معتمدة: ${strangers.length}`);
  if (strangers.length) {
    for (const row of strangers) {
      line(`      ✖ id=${row.id}  «${text(row?.data?.lesson) || "—"}»  [${ownerOf(row?.data)}]`);
    }
  }
  line(`  المجموع المعتمد: ${recognised} من ${EXPECTED.reduce((s, e) => s + e.count, 0)}`);

  // ترميز المعادلات في نصّ درس: علامةُ دولارٍ تسرّبت من أداةٍ في الطريق،
  // فيصل إلى الطالب رمزٌ لا معنى له. تُرصد هنا لأنّها لا تُرى إلا بالعدّ.
  const withMarkup = rows.filter((r) => text(r?.data?.lessonContent).includes("$"));
  line(`  ${withMarkup.length === 0 ? "✅" : "⚠️"} دروس فيها ترميز معادلات ($): ${withMarkup.length}`);
  for (const row of withMarkup) {
    line(`      ✖ id=${row.id}  «${text(row?.data?.lesson) || "—"}»`);
  }

  if (rows.length) {
    line();
    line("المواد:");
    for (const [name, count] of tally(rows.map((r) => r.data?.subject))) {
      line(`  • ${name}: ${count}`);
    }
    line();
    line("الصفوف:");
    for (const [name, count] of tally(rows.map((r) => r.data?.grade))) {
      line(`  • ${name}: ${count}`);
    }
    line();
    line("المُلّاك:");
    for (const [name, count] of tally(rows.map((r) => ownerOf(r.data)))) {
      line(`  • ${name}: ${count}`);
    }
    line();
    line("الدروس، كلٌّ بمساره ومالكه:");
    for (const row of rows) {
      const d = row.data ?? {};
      const chars = text(d.lessonContent).length;
      line(
        `  - ${text(d.grade) || "—"} ▸ ${text(d.subject) || "—"} ▸ ${text(d.term) || "—"} ▸ ` +
          `${text(d.unit) || "—"} ▸ ${text(d.lesson) || "—"}   [${ownerOf(d)}] ` +
          `${chars ? `${chars} حرفاً` : "بلا نصّ"}   id=${row.id}`,
      );
    }
  }

  // ── كل مفاتيح app_kv، بلا استثناء ──────────────────────────────────
  head("app_kv — كل المفاتيح");
  const kv = await readJson("/rest/v1/app_kv?select=key,value&limit=1000");
  const keys = Array.isArray(kv) ? kv : [];
  line(`عدد المفاتيح: ${keys.length}`);
  line();
  for (const row of keys) {
    const size = JSON.stringify(row.value ?? null).length;
    const found = looksAcademic(row.value);
    const note = found.subjects.size || found.lessons
      ? `  ← مواد: [${[...found.subjects].join("، ") || "—"}]` +
        `  صفوف: [${[...found.grades].join("، ") || "—"}]` +
        `  دروس: ${found.lessons}`
      : "";
    line(`  • ${row.key}  (${size} حرفاً)${note}`);
  }

  // ── الاختبارات ──────────────────────────────────────────────────────
  head("created_quizzes");
  const quizzes = await readJson("/rest/v1/created_quizzes?select=id,data&limit=10000");
  const quizRows = Array.isArray(quizzes) ? quizzes : [];
  line(`عدد الاختبارات: ${quizRows.length}`);
  if (quizRows.length) {
    for (const [name, count] of tally(quizRows.map((r) => r.data?.subject))) {
      line(`  • ${name}: ${count}`);
    }
  }

  head("الخلاصة");
  line("شاشة إدارة المحتوى تقرأ `lesson_configs` وحده، عبر نسخة المتصفّح");
  line("من `smartEdu_lessonConfigs`. فإن كان الجدول أعلاه نظيفاً وما زال");
  line("القديم ظاهراً على الشاشة، فالمصدر نسخة المتصفّح لا قاعدة البيانات:");
  line("يلزم بناءٌ يحمل ختم المحتوى، أو مسح بيانات الموقع من المتصفّح.");
}

if (process.argv[1] && process.argv[1].endsWith("inspect-content.mjs")) {
  main().catch((error) => {
    console.error("فشل الجرد:", error.message);
    process.exit(1);
  });
}
