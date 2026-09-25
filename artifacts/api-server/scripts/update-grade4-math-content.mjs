#!/usr/bin/env node
/**
 * يُحدّث منهج الرياضيات للصف الرابع وحده: نصوصَه وأسماءَ دروسه وفرعَه
 * في الشجرة. ولا يمسّ العلوم ولا الإنجليزية ولا أيّ مادةٍ سواها.
 *
 * ── لماذا لا يُستعمل `seed-grade4-math-full.mjs` ──
 * ذاك يحذف **كلّ** دروس المعلّم والقالب قبل أن يبذر، ويكتب الشجرة
 * إحلالاً بمادةٍ واحدة. كان ذلك صواباً يوم كانت الرياضيات وحدها في
 * النظام؛ وتشغيلُه اليوم يمحو العلوم والإنجليزية معاً. فلا تشغّله.
 *
 * ── ما يفعله هذا ──
 * ١. يستبدل فرع «الرياضيات» في شجرة المعلّم والقالب بفرع المنهج الجديد،
 *    ويترك بقيّة الموادّ في مكانها كما هي — تُقرأ الشجرة أولاً ويُوقَف
 *    التنفيذ إن تعذّرت قراءتها، فلا يُكتب فوق ما لم يُفهم.
 * ٢. يكتب الدروس الثلاثة والعشرين بنصوصها في `lesson_configs`.
 * ٣. يحذف معرّفات `g4math_` التي لم تعد في المنهج — وهي دروسٌ حُذفت أو
 *    أُعيد ترقيمها، تبقى في الجدول بلا فرعٍ في الشجرة إن لم تُحذف.
 * ٤. يرفع ختم المحتوى فتُسقط المتصفّحات نسخها القديمة.
 * ٥. يتحقّق من المخزون نفسه: الموادّ الثلاث قائمة، والدروس ثلاثة
 *    وعشرون، ولا درس فيه علامة دولار.
 *
 * التشغيل — المعاينة أولاً:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
 *     node scripts/update-grade4-math-content.mjs --teacher teacher_1786033127503
 *
 * ثم أضف --execute للتنفيذ.
 */

import { GRADE, SUBJECT, UNITS, curriculumRows } from "./grade4-math-curriculum.mjs";
import {
  SUBJECT as SCIENCE_SUBJECT,
  GRADE4_SCIENCE_CURRICULUM,
} from "./curriculum/grade4-science-curriculum.mjs";
import {
  SUBJECT as ENGLISH_SUBJECT,
  GRADE4_ENGLISH_CURRICULUM,
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
const ID_PREFIX = "g4math_";
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
  norm(record?.teacher_id ?? record?.teacherId ?? record?.createdBy);

/** معرّف الدرس من رقمه، كما بُني أوّل مرّة ولا يتغيّر. */
export const lessonId = (number, owner) =>
  `${ID_PREFIX}${number.replace(".", "_")}_${owner}`;

/** فصول الرياضيات ووحداتها ودروسها، بترتيب المنهج. */
export function mathTermsForTree() {
  const rows = curriculumRows();
  const terms = [];
  for (const group of UNITS) {
    let term = terms.find((item) => item.term === group.term);
    if (!term) {
      term = { term: group.term, units: [], lessons: {} };
      terms.push(term);
    }
    if (!term.units.includes(group.unit)) term.units.push(group.unit);
    term.lessons[group.unit] = group.lessons.map(
      (number) => rows.find((row) => row.number === number).name,
    );
  }
  return terms;
}

/**
 * الشجرة بعد استبدال فرع الرياضيات لمالك واحد، بلا مساس بما سواه.
 *
 * الاستبدال لا الضمّ: المنهج الجديد يحذف دروساً ويعيد ترقيم وحدات، فلو
 * ضُمّ لبقيت الوحدات القديمة إلى جانب الجديدة وظهر للطالب منهجان.
 * والحصرُ في مادةٍ واحدة هو ما يحفظ العلوم والإنجليزية: لا تُقرأ ولا
 * تُكتب، فتمرّ كما هي.
 */
export function withMath(configs, owner, ownerName) {
  const subject = { subject: SUBJECT, terms: mathTermsForTree() };
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
  return curriculumRows().map((row, index) => {
    const id = lessonId(row.number, owner);
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
    console.error(
      "الاستعمال: node scripts/update-grade4-math-content.mjs --teacher <معرّف المعلّم> [--execute]",
    );
    process.exit(1);
  }

  const owner = norm(TEACHER);
  line(EXECUTE ? "✍️ تنفيذ فعلي." : "🔍 معاينة — لن يُكتب شيء. أضف --execute للتنفيذ.");
  line(`المعلّم: «${TEACHER}»   الصف: «${GRADE}»   المادة: «${SUBJECT}» وحدها`);

  // ── الشجرة ──────────────────────────────────────────────────────────
  head("الشجرة الأكاديمية");
  const kvRows = await readJson(
    `/rest/v1/app_kv?select=key,value&key=eq.${encodeURIComponent(HIERARCHY_KEY)}`,
  );
  const rawTree = kvRows?.[0]?.value;
  // قراءةٌ متسامحة، ووقوفٌ عند الغموض: الارتداد إلى الفراغ يُتبعه كتابةٌ
  // فوق الموجود، وهي كيف ضاع منهجٌ كامل من قبل.
  let tree = [];
  if (Array.isArray(rawTree)) tree = rawTree;
  else if (rawTree != null) {
    if (typeof rawTree === "string" && rawTree.trim()) {
      try {
        const parsed = JSON.parse(rawTree);
        if (Array.isArray(parsed)) tree = parsed;
      } catch {
        /* يُعالَج أدناه */
      }
    }
    if (!tree.length) {
      console.error("❌ قيمة الشجرة محفوظةٌ بشكلٍ لا يُقرأ. شغّل scripts/rebuild-academic-tree.mjs.");
      process.exit(1);
    }
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
    const result = withMath(next, id, name);
    next = result.list;
    line(
      `  • «${id}»: ${result.added ? "أُنشئ مدخل جديد" : result.replaced ? "استُبدل فرع الرياضيات" : "أُضيفت الرياضيات"}`,
    );
  }
  for (const config of next) {
    if (norm(config?.grade) !== norm(GRADE)) continue;
    const subjects = (config.subjects ?? []).map((item) => item?.subject).filter(Boolean);
    line(`    ${ownerOf(config)} ← ${subjects.join("، ") || "—"}`);
  }

  line();
  for (const term of mathTermsForTree()) {
    const count = Object.values(term.lessons).flat().length;
    line(`  ${term.term}: ${term.units.length} وحدات، ${count} دروس`);
    for (const unit of term.units) {
      line(`      ${unit}: ${term.lessons[unit].join("، ")}`);
    }
  }

  // ── الدروس ──────────────────────────────────────────────────────────
  head("نصوص الدروس");
  const rows = buildLessonRows(owner, TEACHER_NAME);
  const lengths = rows.map((row) => row.data.lessonContent.length);
  line(`${rows.length} سجلاً، أطولها ${Math.max(...lengths)} حرفاً وأقصرها ${Math.min(...lengths)}.`);

  const existing = await readJson("/rest/v1/lesson_configs?select=id,data&limit=10000");
  const allRows = Array.isArray(existing) ? existing : [];
  const wanted = new Set(rows.map((row) => row.id));
  // معرّفات `g4math_` لهذا المالك خرجت من المنهج: دروسٌ حُذفت أو أُعيد
  // ترقيمها. تبقى في الجدول بلا فرعٍ يراها إن لم تُحذف.
  const stale = allRows.filter(
    (row) =>
      text(row.id).startsWith(ID_PREFIX) &&
      ownerOf(row?.data) === owner &&
      !wanted.has(text(row.id)),
  );
  line(`معرّفات خرجت من المنهج: ${stale.length}`);
  for (const row of stale) {
    line(`      ✖ ${row.id}  «${text(row?.data?.lesson) || "—"}»`);
  }

  const others = allRows.filter(
    (row) => !text(row.id).startsWith(ID_PREFIX) && ownerOf(row?.data) === owner,
  );
  line(`دروس الموادّ الأخرى لهذا المالك (لا تُمسّ): ${others.length}`);

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

  for (const row of stale) {
    await send(
      `/rest/v1/lesson_configs?id=eq.${encodeURIComponent(row.id)}`,
      "DELETE",
      undefined,
      "return=minimal",
    );
  }
  line(`حُذف ${stale.length} معرّفاً خرج من المنهج.`);

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
  const after = Array.isArray(afterLessons) ? afterLessons : [];
  const mine = after.filter(
    (row) => text(row.id).startsWith(ID_PREFIX) && ownerOf(row?.data) === owner,
  );

  const problems = [];
  for (const id of [owner, ADMIN]) {
    if (!subjectsOf(id).includes(norm(SUBJECT))) problems.push(`«${SUBJECT}» غائبة عن «${id}»`);
    // ما كان موجوداً قبل التشغيل فقدانُه خطأ لا تحذير: هذا السكربت يعد
    // بألّا يمسّ سوى مادة واحدة، والوعد يُقاس لا يُفترض.
    for (const was of subjectsBefore.get(norm(id)) ?? []) {
      if (!subjectsOf(id).includes(was)) problems.push(`سقطت مادة من «${id}»`);
    }
  }
  if (mine.length !== rows.length) {
    problems.push(`دروس الرياضيات ${mine.length} بدل ${rows.length}`);
  }
  const missingText = mine.filter((row) => !text(row?.data?.lessonContent));
  if (missingText.length) problems.push(`${missingText.length} درساً بلا نصّ`);

  // علامة الدولار في نصّ درس: بقيّةُ ترميزٍ رياضي تسرّب من أداةٍ في
  // الطريق. تُفحص من المخزون نفسه لا من الذاكرة.
  const withMarkup = after.filter((row) => text(row?.data?.lessonContent).includes("$"));
  if (withMarkup.length) {
    problems.push(`${withMarkup.length} درساً فيه ترميز معادلات ($)`);
    for (const row of withMarkup) line(`      ✖ ${row.id}`);
  }

  // الجرد الكامل: كل منهجٍ وعدده، ليُرى أن الرياضيات وحدها تغيّرت.
  const counts = [
    { subject: SUBJECT, prefix: ID_PREFIX, want: rows.length },
    { subject: SCIENCE_SUBJECT, prefix: "g4sci_", want: GRADE4_SCIENCE_CURRICULUM.length },
    { subject: ENGLISH_SUBJECT, prefix: "g4eng_", want: GRADE4_ENGLISH_CURRICULUM.length },
  ];
  let total = 0;
  for (const entry of counts) {
    const found = after.filter((row) => text(row.id).startsWith(entry.prefix)).length;
    total += found;
    const mark = found === entry.want ? "✅" : "⚠️";
    line(`  ${mark} ${entry.subject}: ${found} من ${entry.want}`);
    if (found !== entry.want) problems.push(`${entry.subject}: ${found} بدل ${entry.want}`);
  }
  line(`  المجموع المعتمد: ${total} من ${counts.reduce((s, e) => s + e.want, 0)}`);

  if (problems.length) {
    console.error(`❌ التحقّق فشل: ${problems.join(" — ")}`);
    process.exit(1);
  }
  line();
  line(`✅ الرياضيات ${mine.length} درساً بنصّ نظيف، والعلوم والإنجليزية كما كانتا، والختم مرفوع.`);
}

if (process.argv[1] && process.argv[1].endsWith("update-grade4-math-content.mjs")) {
  main().catch((error) => {
    console.error("فشل:", error.message);
    process.exit(1);
  });
}
