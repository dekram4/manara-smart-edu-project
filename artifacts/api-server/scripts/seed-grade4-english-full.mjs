#!/usr/bin/env node
/**
 * يحقن منهج اللغة الإنجليزية للصف الرابع: الشجرة ونصوص دروسه الثمانية عشر.
 *
 * ── يضيف ولا يحذف ──
 * خلافاً لسكربت الرياضيات الذي يصفّر قبل أن يبذر، هذا لا يحذف شيئاً
 * إطلاقاً: ما في الشجرة من موادّ — الرياضيات والعلوم وغيرهما — يبقى
 * كما هو، وتُضاف الإنجليزية إلى جانبه تحت الصفّ نفسه. وإعادة تشغيله
 * تكتب فوق دروسها بمعرّفاتها ولا تُنشئ نسخاً ثانية.
 *
 * ── ونصوصه منقّاة من ترميز المعادلات ──
 * التنقية في وحدة المنهج لا هنا: ما يُحفظ هو ما يُقرأ، ولا طبقةَ
 * تنظيفٍ بينهما. والتحقّق أدناه يرفض أيّ درسٍ بقيت فيه علامة دولار.
 *
 * ── لمن تُكتب ──
 * للمعلّم المذكور ولقالب `admin` معاً: الأول ليراها طلابه، والثاني
 * ليَنسخها أي معلّم آخر من «نسخ إلى إعداداتي».
 *
 * ── ويرفع ختم المحتوى ──
 * فيُسقط كل متصفّح نسخته القديمة ويأخذ ما في الخادم. بدونه يبقى جهاز
 * لم يُفتح منذ الحقن لا يرى الإنجليزية، وربما رفع فوقها ما عنده.
 *
 * التشغيل — المعاينة أولاً:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
 *     node scripts/seed-grade4-english-full.mjs --teacher teacher_1786033127503
 *
 * ثم أضف --execute للتنفيذ.
 */

import {
  GRADE,
  SUBJECT,
  ID_PREFIX,
  GRADE4_ENGLISH_CURRICULUM,
  englishTermsForTree,
} from "./curriculum/grade4-english-curriculum.mjs";

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
 * الشجرة بعد إضافة الإنجليزية لمالك واحد، بلا مساس بما سواها.
 *
 * إن كان للمالك مدخلٌ لهذا الصفّ أُضيفت إليه المادة، وإن كانت فيه نسخة
 * قديمة منها استُبدلت بها — فإعادة التشغيل تُحدِّث ولا تُكرِّر. وإن
 * لم يكن له مدخل أُنشئ له واحد.
 */
export function withEnglish(configs, owner, ownerName) {
  const terms = englishTermsForTree();
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
  return GRADE4_ENGLISH_CURRICULUM.map((item, index) => {
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
    console.error("الاستعمال: node scripts/seed-grade4-english-full.mjs --teacher <معرّف المعلّم> [--execute]");
    process.exit(1);
  }

  const owner = norm(TEACHER);
  line(EXECUTE ? "✍️ تنفيذ فعلي." : "🔍 معاينة — لن يُكتب شيء. أضف --execute للتنفيذ.");
  line(`المعلّم: «${TEACHER}»   الصف: «${GRADE}»   المادة: «${SUBJECT}»`);
  line(`الدروس: ${GRADE4_ENGLISH_CURRICULUM.length}`);

  // ── الشجرة ──────────────────────────────────────────────────────────
  head("الشجرة الأكاديمية");
  const kvRows = await readJson(
    `/rest/v1/app_kv?select=key,value&key=eq.${encodeURIComponent(HIERARCHY_KEY)}`,
  );
  const rawTree = kvRows?.[0]?.value;
  // قراءةٌ متسامحة، ووقوفٌ عند الغموض.
  //
  // كان الاشتراط مصفوفةً والارتداد إلى الفراغ عند غيرها، فقيمةٌ
  // محفوظةٌ نصّاً تُقرأ «لا شيء» ثم يُكتب فوق الموجود. والصواب أن
  // يُفكّ النصّ، وأن يُوقَف إن بقي ما لا يُفهم: التوقّف أرخص من المحو.
  let tree = [];
  if (Array.isArray(rawTree)) tree = rawTree;
  else if (typeof rawTree === "string" && rawTree.trim()) {
    try {
      const parsed = JSON.parse(rawTree);
      if (Array.isArray(parsed)) tree = parsed;
    } catch {
      /* يُعالَج أدناه */
    }
    if (!tree.length) {
      console.error("❌ قيمة الشجرة محفوظةٌ بشكلٍ لا يُقرأ. شغّل scripts/rebuild-academic-tree.mjs.");
      process.exit(1);
    }
  } else if (rawTree != null && !Array.isArray(rawTree)) {
    console.error("❌ قيمة الشجرة ليست مصفوفة. شغّل scripts/rebuild-academic-tree.mjs.");
    process.exit(1);
  }
  line(`المدخلات الآن: ${tree.length}`);

  // ما كان لكلّ مالكٍ من موادّ قبل الكتابة، ليُقارَن به بعدها.
  const subjectsBefore = new Map(
    tree
      .filter((config) => norm(config?.grade) === norm(GRADE))
      .map((config) => [
        ownerOf(config),
        (config.subjects ?? []).map((item) => norm(item?.subject)).filter(Boolean),
      ]),
  );

  let next = tree;
  for (const [id, name] of [[owner, TEACHER_NAME], [ADMIN, "المشرف"]]) {
    const result = withEnglish(next, id, name);
    next = result.list;
    line(
      `  • «${id}»: ${result.added ? "أُنشئ مدخل جديد" : result.replaced ? "استُبدلت نسخة الإنجليزية" : "أُضيفت الإنجليزية"}`,
    );
  }
  // ما بقي من المواد تحت هذا الصفّ لكل مالك، ليُرى أن ما قبلها سليم.
  for (const config of next) {
    if (norm(config?.grade) !== norm(GRADE)) continue;
    const subjects = (config.subjects ?? []).map((item) => item?.subject).filter(Boolean);
    line(`    ${ownerOf(config)} ← ${subjects.join("، ") || "—"}`);
  }

  for (const term of englishTermsForTree()) {
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
    if (!subjectsOf(id).includes(norm(SUBJECT))) problems.push(`«${SUBJECT}» غائبة عن «${id}»`);
    // ما كان موجوداً قبل التشغيل فقدانُه خطأ لا تحذير.
    //
    // كان غياب الرياضيات يُطبع سطراً أصفر ثم يُعلن النجاح، فمرّ محوُ منهجٍ
    // كامل في سطرٍ لا يقرؤه أحد. والمقياس الصحيح ليس «هل الرياضيات
    // موجودة؟» بل «هل سقط شيءٌ كان هنا قبل أن أبدأ؟».
    for (const was of subjectsBefore.get(norm(id)) ?? []) {
      if (!subjectsOf(id).includes(was)) problems.push(`سقطت «${was}» من «${id}»`);
    }
  }
  if (mine.length !== GRADE4_ENGLISH_CURRICULUM.length) {
    problems.push(`الدروس ${mine.length} بدل ${GRADE4_ENGLISH_CURRICULUM.length}`);
  }
  if (missingText.length) problems.push(`${missingText.length} درساً بلا نصّ`);

  // علامة الدولار في نصّ لغةٍ لا معنى لها: بقيّةُ ترميزٍ رياضي تسرّب من
  // أداةٍ في الطريق. تُفحص من المخزون نفسه لا من الذاكرة، فالمقياس ما
  // استقرّ في قاعدة البيانات لا ما نوى السكربت كتابته.
  const withMarkup = mine.filter((row) => text(row?.data?.lessonContent).includes("$"));
  if (withMarkup.length) {
    problems.push(`${withMarkup.length} درساً فيه ترميز معادلات ($)`);
    for (const row of withMarkup) line(`      ✖ ${row.id}`);
  }

  if (problems.length) {
    console.error(`❌ التحقّق فشل: ${problems.join(" — ")}`);
    process.exit(1);
  }
  line(`✅ «${SUBJECT}» في الشجرة للمعلّم وللقالب، و${mine.length} درساً بنصّ نظيف، والختم مرفوع.`);
}

if (process.argv[1] && process.argv[1].endsWith("seed-grade4-english-full.mjs")) {
  main().catch((error) => {
    console.error("فشل:", error.message);
    process.exit(1);
  });
}
