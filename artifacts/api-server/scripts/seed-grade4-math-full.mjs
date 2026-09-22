#!/usr/bin/env node
/**
 * يصفّر منهج معلّم ويحقن منهج رياضيات الصف الرابع كاملاً: الشجرة
 * الأكاديمية، ونصّ كل درس في إدارة المحتوى.
 *
 * ── سكربت يحذف، فاقرأ هذا قبل تشغيله ──
 * لا يكتب شيئاً بلا `--execute`. والتشغيل بلا علم يعرض ما سيقع ويقف.
 *
 * والحذف مقيّد بالمالك: شجرة المعلّم المذكور وقالب المشرف ودروسهما
 * واختباراتهما. أما شجرات بقية المعلمين ودروسهم واختباراتهم فلا تُمسّ —
 * ولو طُلب «حذف الكل». ومن أراد ذلك فبـ `--purge-all-teachers` صراحةً،
 * وهو علمٌ يُكتب باليد مرة واحدة ولا يُنسى.
 *
 * ── ما يُكتب ──
 * الشجرة تُكتب مرتين: باسم المعلّم ليراها طلابه، وباسم `admin` قالباً
 * يَنسخه أي معلّم آخر من «نسخ إلى إعداداتي». ونصوص الدروس تُكتب في
 * `lesson_configs` صفاً لكل درس، مربوطاً بمساره الخماسي كاملاً.
 *
 * التشغيل — المعاينة أولاً:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
 *     node scripts/seed-grade4-math-full.mjs --teacher teacher_1786033127503
 *
 * ثم التنفيذ:
 *   ... node scripts/seed-grade4-math-full.mjs \
 *         --teacher teacher_1786033127503 --execute
 */

import {
  GRADE,
  SUBJECT,
  UNITS,
  curriculumRows,
} from "./grade4-math-curriculum.mjs";

const args = process.argv.slice(2);
const EXECUTE = args.includes("--execute");
const PURGE_ALL = args.includes("--purge-all-teachers");
const flag = (name) => {
  const at = args.indexOf(name);
  return at === -1 ? null : args[at + 1] ?? null;
};
const TEACHER = flag("--teacher");
const TEACHER_NAME = flag("--teacher-name") ?? "";

const SUPABASE_URL = process.env.SUPABASE_URL?.trim().replace(/\/+$/, "");
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

const HIERARCHY_KEY = "smartEdu_hierarchicalConfigs";
const ADMIN = "admin";

const headers = () => ({
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  "Content-Type": "application/json",
});

/** تسوية عربية، نظيرة ما في الخادم: الهمزة لا تصنع مالكاً ثانياً. */
export function norm(value) {
  const raw = value == null ? "" : String(value).trim().toLowerCase();
  return raw
    .replace(/[ً-ْٰـ]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/\s+/g, " ")
    .trim();
}

export const ownerOf = (record) =>
  norm(record?.teacherId ?? record?.teacher_id ?? record?.createdBy);

/** الشجرة كما تُكتب لمالك واحد: صفٌّ واحد بمادّته وفصليه ووحداته ودروسه. */
export function buildTree(owner, ownerName) {
  const terms = [];
  for (const group of UNITS) {
    let term = terms.find((item) => item.term === group.term);
    if (!term) {
      term = { term: group.term, units: [], lessons: {} };
      terms.push(term);
    }
    term.units.push(group.unit);
    term.lessons[group.unit] = group.lessons.map(
      (number) => curriculumRows().find((row) => row.number === number).name,
    );
  }
  return {
    grade: GRADE,
    createdBy: owner,
    teacherId: owner,
    createdByName: ownerName || owner,
    createdAt: new Date().toISOString(),
    subjects: [{ subject: SUBJECT, terms }],
  };
}

/** صفوف `lesson_configs`: صفٌّ لكل درس، بمساره الخماسي ونصّه كاملاً. */
export function buildLessonRows(owner, ownerName) {
  return curriculumRows().map((row, index) => {
    const id = `g4math_${row.number.replace(".", "_")}_${owner}`;
    return {
      id,
      data: {
        id,
        grade: GRADE,
        subject: SUBJECT,
        term: row.term,
        unit: row.unit,
        lesson: row.name,
        lessonContent: row.text,
        explanationVideoUrl: "",
        explanationVideoType: "embed",
        explanationVideos: [],
        avatarInteractionUrl: "",
        liveMeetingUrl: "",
        createdBy: owner,
        teacherId: owner,
        createdByName: ownerName || owner,
        createdAt: new Date(Date.now() + index).toISOString(),
      },
    };
  });
}

async function readJson(path) {
  const response = await fetch(`${SUPABASE_URL}${path}`, { headers: headers() });
  if (!response.ok) {
    throw new Error(`GET ${path} → ${response.status} ${(await response.text()).slice(0, 200)}`);
  }
  return response.json();
}

async function send(path, method, body, prefer) {
  const response = await fetch(`${SUPABASE_URL}${path}`, {
    method,
    headers: { ...headers(), ...(prefer ? { Prefer: prefer } : {}) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  if (!response.ok) {
    throw new Error(`${method} ${path} → ${response.status} ${(await response.text()).slice(0, 300)}`);
  }
}

const line = (text = "") => console.log(text);
const head = (text) => {
  line();
  line(`════ ${text} ════`);
};

async function main() {
  if (!SUPABASE_URL || !SERVICE_KEY) {
    console.error("SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY مطلوبان.");
    process.exit(1);
  }
  if (!TEACHER) {
    console.error("الاستعمال: node scripts/seed-grade4-math-full.mjs --teacher <معرّف المعلّم> [--execute]");
    process.exit(1);
  }

  const owner = norm(TEACHER);
  const rows = curriculumRows();
  line(EXECUTE ? "✍️ تنفيذ فعلي." : "🔍 معاينة — لن يُكتب شيء. أضف --execute للتنفيذ.");
  line(`المعلّم: «${TEACHER}»   الصف: «${GRADE}»   المادة: «${SUBJECT}»`);
  line(`الدروس في المنهج: ${rows.length}`);

  // ── ما سيُحذف ───────────────────────────────────────────────────────
  head("التصفير");
  const kvRows = await readJson(
    `/rest/v1/app_kv?select=key,value&key=eq.${encodeURIComponent(HIERARCHY_KEY)}`,
  );
  const tree = Array.isArray(kvRows?.[0]?.value) ? kvRows[0].value : [];
  const mineInTree = (config) =>
    [owner, ADMIN, "supervisor"].includes(ownerOf(config));
  const keptTree = PURGE_ALL ? [] : tree.filter((config) => !mineInTree(config));
  line(`الشجرة: ${tree.length} مدخلاً → يُحذف ${tree.length - keptTree.length}، يبقى ${keptTree.length}`);
  if (!PURGE_ALL && keptTree.length > 0) {
    const owners = [...new Set(keptTree.map(ownerOf))];
    line(`  (تبقى شجرات: ${owners.join("، ")} — لا تُمسّ)`);
  }

  const lessons = await readJson("/rest/v1/lesson_configs?select=id,data&limit=5000");
  const doomedLessons = (Array.isArray(lessons) ? lessons : []).filter((row) =>
    PURGE_ALL ? true : [owner, ADMIN, "supervisor"].includes(ownerOf(row?.data)),
  );
  line(`الدروس: ${lessons.length} سجلاً → يُحذف ${doomedLessons.length}`);

  const quizzes = await readJson("/rest/v1/created_quizzes?select=id,data&limit=5000");
  const doomedQuizzes = (Array.isArray(quizzes) ? quizzes : []).filter((row) =>
    PURGE_ALL ? true : [owner, ADMIN, "supervisor"].includes(ownerOf(row?.data)),
  );
  line(`الاختبارات: ${quizzes.length} سجلاً → يُحذف ${doomedQuizzes.length}`);

  // ── ما سيُكتب ───────────────────────────────────────────────────────
  head("ما سيُكتب");
  const teacherTree = buildTree(owner, TEACHER_NAME);
  const adminTree = buildTree(ADMIN, "المشرف");
  const lessonRows = buildLessonRows(owner, TEACHER_NAME);
  for (const group of UNITS) {
    line(`  ${group.term} ▸ ${group.unit}: ${group.lessons.length} دروس`);
  }
  line(`  الشجرة تُكتب لـ «${TEACHER}» ولقالب «admin».`);
  line(`  نصوص الدروس: ${lessonRows.length} سجلاً، أطولها ${
    Math.max(...lessonRows.map((row) => row.data.lessonContent.length))
  } حرفاً وأقصرها ${
    Math.min(...lessonRows.map((row) => row.data.lessonContent.length))
  }.`);

  if (!EXECUTE) {
    line();
    line("(معاينة فقط — لم يُكتب شيء)");
    return;
  }

  // ── التنفيذ ─────────────────────────────────────────────────────────
  head("التنفيذ");
  for (const row of doomedLessons) {
    await send(`/rest/v1/lesson_configs?id=eq.${encodeURIComponent(row.id)}`, "DELETE", undefined, "return=minimal");
  }
  line(`حُذف ${doomedLessons.length} درساً.`);
  for (const row of doomedQuizzes) {
    await send(`/rest/v1/created_quizzes?id=eq.${encodeURIComponent(row.id)}`, "DELETE", undefined, "return=minimal");
  }
  line(`حُذف ${doomedQuizzes.length} اختباراً.`);

  const nextTree = [...keptTree, teacherTree, adminTree];
  await send("/rest/v1/app_kv?on_conflict=key", "POST", {
    key: HIERARCHY_KEY,
    value: nextTree,
    updated_at: new Date().toISOString(),
  }, "resolution=merge-duplicates,return=minimal");
  line(`كُتبت الشجرة: ${nextTree.length} مدخلاً.`);

  // دفعات لئلّا يُرفض طلبٌ واحد ضخم.
  for (let at = 0; at < lessonRows.length; at += 10) {
    await send(
      "/rest/v1/lesson_configs?on_conflict=id",
      "POST",
      lessonRows.slice(at, at + 10).map((row) => ({
        id: row.id,
        data: row.data,
        updated_at: new Date().toISOString(),
      })),
      "resolution=merge-duplicates,return=minimal",
    );
  }
  line(`كُتب ${lessonRows.length} درساً بنصّه.`);

  // ── التحقّق من المخزون نفسه ─────────────────────────────────────────
  head("التحقّق");
  const afterKv = await readJson(
    `/rest/v1/app_kv?select=key,value&key=eq.${encodeURIComponent(HIERARCHY_KEY)}`,
  );
  const savedTree = Array.isArray(afterKv?.[0]?.value) ? afterKv[0].value : [];
  const savedMine = savedTree.find((config) => ownerOf(config) === owner);
  const savedAdmin = savedTree.find((config) => ownerOf(config) === ADMIN);

  const afterLessons = await readJson("/rest/v1/lesson_configs?select=id,data&limit=5000");
  const savedLessons = (Array.isArray(afterLessons) ? afterLessons : []).filter(
    (row) => ownerOf(row?.data) === owner,
  );
  const missingText = savedLessons.filter(
    (row) => !String(row?.data?.lessonContent ?? "").trim(),
  );
  const expected = new Set(rows.map((row) => row.name));
  const found = new Set(savedLessons.map((row) => row?.data?.lesson));
  const absent = [...expected].filter((name) => !found.has(name));

  const problems = [];
  if (!savedMine) problems.push("شجرة المعلّم لم تُكتب");
  if (!savedAdmin) problems.push("قالب المشرف لم يُكتب");
  if (savedLessons.length !== rows.length) {
    problems.push(`عدد الدروس ${savedLessons.length} بدل ${rows.length}`);
  }
  if (missingText.length) problems.push(`${missingText.length} درساً بلا نصّ`);
  if (absent.length) problems.push(`دروس غائبة: ${absent.join("، ")}`);

  if (problems.length) {
    console.error(`❌ التحقّق فشل: ${problems.join(" — ")}`);
    process.exit(1);
  }
  line(`✅ الشجرة للمعلّم وللقالب، و${savedLessons.length} درساً كلُّها بنصّها، وتأكّد بالقراءة.`);
}

if (process.argv[1] && process.argv[1].endsWith("seed-grade4-math-full.mjs")) {
  main().catch((error) => {
    console.error("فشل:", error.message);
    process.exit(1);
  });
}
