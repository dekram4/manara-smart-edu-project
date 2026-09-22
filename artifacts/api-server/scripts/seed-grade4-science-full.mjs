#!/usr/bin/env node
/**
 * يحقن منهج العلوم للصف الرابع: الشجرة ونصوص الدروس الأربعة عشر.
 *
 * ── يضيف ولا يحذف ──
 * خلافاً لسكربت الرياضيات الذي يصفّر قبل أن يبذر، هذا لا يحذف شيئاً
 * إطلاقاً: مادة الرياضيات في الشجرة تبقى كما هي، وتُضاف العلوم إلى
 * جانبها تحت الصفّ نفسه. وإعادة تشغيله تكتب فوق دروس العلوم بمعرّفاتها
 * ولا تُنشئ نسخاً ثانية.
 *
 * ── لمن تُكتب ──
 * للمعلّم المذكور ولقالب `admin` معاً: الأول ليراها طلابه، والثاني
 * ليَنسخها أي معلّم آخر من «نسخ إلى إعداداتي».
 *
 * ── ويرفع ختم المحتوى ──
 * فيُسقط كل متصفّح نسخته القديمة ويأخذ ما في الخادم. بدونه يبقى جهاز
 * لم يُفتح منذ الحقن لا يرى العلوم، وربما رفع فوقها ما عنده.
 *
 * التشغيل — المعاينة أولاً:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
 *     node scripts/seed-grade4-science-full.mjs --teacher teacher_1786033127503
 *
 * ثم أضف --execute للتنفيذ.
 */

import {
  GRADE,
  SUBJECT,
  ID_PREFIX,
  GRADE4_SCIENCE_CURRICULUM,
  scienceTermsForTree,
} from "./curriculum/grade4-science-curriculum.mjs";

const args = process.argv.slice(2);
const EXECUTE = args.includes("--execute");
const flag = (name) => {
  const at = args.indexOf(name);
  return at === -1 ? null : args[at + 1] ?? null;
};
const TEACHER = flag("--teacher");
const TEACHER_NAME = flag("--teacher-name") ?? "";

const SUPABASE_URL = process.env.SUPABASE_URL?.trim().replace(/\/+$/, "");
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

const HIERARCHY_KEY = "smartEdu_hierarchicalConfigs";
const EPOCH_KEY = "smartEdu_contentEpoch";
const ADMIN = "admin";

const headers = () => ({
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  "Content-Type": "application/json",
});

const text = (value) => (value == null ? "" : String(value).trim());

/** تسوية عربية، نظيرة ما في الخادم: الهمزة لا تصنع مالكاً ولا مادةً ثانية. */
export function norm(value) {
  return text(value)
    .toLowerCase()
    .replace(/[ً-ْٰـ]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/\s+/g, " ")
    .trim();
}

export const ownerOf = (record) =>
  norm(record?.teacherId ?? record?.teacher_id ?? record?.createdBy);

/**
 * الشجرة بعد إضافة العلوم لمالك واحد، بلا مساس بما سواها.
 *
 * إن كان للمالك مدخلٌ لهذا الصفّ أُضيفت إليه المادة، وإن كانت فيه نسخة
 * قديمة من العلوم استُبدلت بها — فإعادة التشغيل تُحدِّث ولا تُكرِّر. وإن
 * لم يكن له مدخل أُنشئ له واحد.
 */
export function withScience(configs, owner, ownerName) {
  const terms = scienceTermsForTree();
  const subject = { subject: SUBJECT, terms };
  const list = Array.isArray(configs) ? [...configs] : [];

  const at = list.findIndex(
    (config) => ownerOf(config) === norm(owner) && norm(config?.grade) === norm(GRADE),
  );

  if (at === -1) {
    list.push({
      grade: GRADE,
      createdBy: owner,
      teacherId: owner,
      createdByName: ownerName || owner,
      createdAt: new Date().toISOString(),
      subjects: [subject],
    });
    return { list, added: true, replaced: false };
  }

  const existing = list[at];
  const subjects = Array.isArray(existing.subjects) ? [...existing.subjects] : [];
  const subjectAt = subjects.findIndex((item) => norm(item?.subject) === norm(SUBJECT));
  const replaced = subjectAt !== -1;
  if (replaced) subjects[subjectAt] = subject;
  else subjects.push(subject);

  list[at] = { ...existing, subjects };
  return { list, added: false, replaced };
}

/** صفوف `lesson_configs`: صفٌّ لكل درس، بمساره الخماسي ونصّه كاملاً. */
export function buildLessonRows(owner, ownerName) {
  return GRADE4_SCIENCE_CURRICULUM.map((item, index) => {
    const id = `${ID_PREFIX}${item.idSuffix}_${owner}`;
    return {
      id,
      data: {
        id,
        grade: GRADE,
        subject: SUBJECT,
        term: item.term,
        unit: item.unit,
        lesson: item.lesson,
        lessonContent: item.content,
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
  if (!TEACHER) {
    console.error("الاستعمال: node scripts/seed-grade4-science-full.mjs --teacher <معرّف المعلّم> [--execute]");
    process.exit(1);
  }

  const owner = norm(TEACHER);
  line(EXECUTE ? "✍️ تنفيذ فعلي." : "🔍 معاينة — لن يُكتب شيء. أضف --execute للتنفيذ.");
  line(`المعلّم: «${TEACHER}»   الصف: «${GRADE}»   المادة: «${SUBJECT}»`);
  line(`الدروس: ${GRADE4_SCIENCE_CURRICULUM.length}`);

  // ── الشجرة ──────────────────────────────────────────────────────────
  head("الشجرة الأكاديمية");
  const kvRows = await readJson(
    `/rest/v1/app_kv?select=key,value&key=eq.${encodeURIComponent(HIERARCHY_KEY)}`,
  );
  const tree = Array.isArray(kvRows?.[0]?.value) ? kvRows[0].value : [];
  line(`المدخلات الآن: ${tree.length}`);

  let next = tree;
  for (const [id, name] of [[owner, TEACHER_NAME], [ADMIN, "المشرف"]]) {
    const result = withScience(next, id, name);
    next = result.list;
    line(
      `  • «${id}»: ${result.added ? "أُنشئ مدخل جديد" : result.replaced ? "استُبدلت نسخة العلوم" : "أُضيفت العلوم"}`,
    );
  }
  // ما بقي من المواد تحت هذا الصفّ لكل مالك، ليُرى أن الرياضيات سليمة.
  for (const config of next) {
    if (norm(config?.grade) !== norm(GRADE)) continue;
    const subjects = (config.subjects ?? []).map((item) => item?.subject).filter(Boolean);
    line(`    ${ownerOf(config)} ← ${subjects.join("، ") || "—"}`);
  }

  for (const term of scienceTermsForTree()) {
    const count = Object.values(term.lessons).flat().length;
    line(`  ${term.term}: ${term.units.length} وحدات، ${count} دروس`);
  }

  // ── الدروس ──────────────────────────────────────────────────────────
  head("نصوص الدروس");
  const rows = buildLessonRows(owner, TEACHER_NAME);
  const lengths = rows.map((row) => row.data.lessonContent.length);
  line(`${rows.length} سجلاً، أطولها ${Math.max(...lengths)} حرفاً وأقصرها ${Math.min(...lengths)}.`);
  line(`المعرّفات: ${ID_PREFIX}<الدرس>_${owner}`);

  const stamp = new Date().toISOString();
  head("ختم المحتوى");
  line(`سيُرفع إلى: ${stamp}`);

  if (!EXECUTE) {
    line();
    line("(معاينة فقط — لم يُكتب شيء)");
    return;
  }

  // ── التنفيذ ─────────────────────────────────────────────────────────
  head("التنفيذ");
  await send("/rest/v1/app_kv?on_conflict=key", "POST", {
    key: HIERARCHY_KEY,
    value: next,
    updated_at: stamp,
  }, "resolution=merge-duplicates,return=minimal");
  line(`كُتبت الشجرة: ${next.length} مدخلاً.`);

  for (let at = 0; at < rows.length; at += 7) {
    await send(
      "/rest/v1/lesson_configs?on_conflict=id",
      "POST",
      rows.slice(at, at + 7).map((row) => ({
        id: row.id,
        data: row.data,
        updated_at: stamp,
      })),
      "resolution=merge-duplicates,return=minimal",
    );
  }
  line(`كُتب ${rows.length} درساً بنصّه.`);

  await send("/rest/v1/app_kv?on_conflict=key", "POST", {
    key: EPOCH_KEY,
    value: stamp,
    updated_at: stamp,
  }, "resolution=merge-duplicates,return=minimal");
  line(`رُفع ختم المحتوى: ${stamp}`);

  // ── التحقّق من المخزون نفسه ─────────────────────────────────────────
  head("التحقّق");
  const afterKv = await readJson(
    `/rest/v1/app_kv?select=key,value&key=eq.${encodeURIComponent(HIERARCHY_KEY)}`,
  );
  const savedTree = Array.isArray(afterKv?.[0]?.value) ? afterKv[0].value : [];
  const subjectsOf = (id) =>
    (savedTree.find(
      (config) => ownerOf(config) === norm(id) && norm(config?.grade) === norm(GRADE),
    )?.subjects ?? []).map((item) => norm(item?.subject));

  const afterLessons = await readJson("/rest/v1/lesson_configs?select=id,data&limit=10000");
  const mine = (Array.isArray(afterLessons) ? afterLessons : []).filter(
    (row) => text(row.id).startsWith(ID_PREFIX) && ownerOf(row?.data) === owner,
  );
  const missingText = mine.filter((row) => !text(row?.data?.lessonContent));

  const problems = [];
  for (const id of [owner, ADMIN]) {
    if (!subjectsOf(id).includes(norm(SUBJECT))) problems.push(`العلوم غائبة عن «${id}»`);
    // الرياضيات شرطُ سلامةٍ لا زينة: هذا السكربت يضيف ولا يحذف.
    if (!subjectsOf(id).includes(norm("الرياضيات"))) {
      line(`  ⚠️ «${id}» بلا مادة الرياضيات — لم تكن موجودة قبل التشغيل.`);
    }
  }
  if (mine.length !== GRADE4_SCIENCE_CURRICULUM.length) {
    problems.push(`الدروس ${mine.length} بدل ${GRADE4_SCIENCE_CURRICULUM.length}`);
  }
  if (missingText.length) problems.push(`${missingText.length} درساً بلا نصّ`);

  if (problems.length) {
    console.error(`❌ التحقّق فشل: ${problems.join(" — ")}`);
    process.exit(1);
  }
  line(`✅ العلوم في الشجرة للمعلّم وللقالب، و${mine.length} درساً بنصّها، والختم مرفوع.`);
}

if (process.argv[1] && process.argv[1].endsWith("seed-grade4-science-full.mjs")) {
  main().catch((error) => {
    console.error("فشل:", error.message);
    process.exit(1);
  });
}
