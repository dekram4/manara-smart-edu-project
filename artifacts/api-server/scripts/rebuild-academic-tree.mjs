#!/usr/bin/env node
/**
 * يعيد بناء الشجرة الأكاديمية بالضمّ لا بالإحلال — فلا يسقط منها شيء.
 *
 * ── لماذا احتيج إليه ──
 * سكربت بذر الرياضيات يكتب الشجرة إحلالاً: يبني مدخلاً للمعلّم وآخر
 * للقالب، فيهما مادةٌ واحدة، ويضع الاثنين مكان ما كان. وسكربت العلوم
 * يقرأ ما هناك ثم يضيف إليه. فإن تعذّرت القراءة لأيّ سبب — صفٌّ غائب،
 * أو قيمة محفوظة نصّاً لا مصفوفةً — قرأ «لا شيء» وكتب مدخلين فيهما
 * العلوم وحدها، فذهبت الرياضيات. وتحقّقُه كان يمرّ: غيابُ الرياضيات
 * عنده تحذيرٌ لا خطأ.
 *
 * ── ما يفعله هذا ──
 * يجمع الشجرة من ثلاثة مصادر ثم يوحّدها، ولا يحذف من أيٍّ منها:
 *   ١. ما في `app_kv` الآن — يُقرأ متسامحاً: مصفوفةً كان أو نصّاً.
 *   ٢. المنهجان المعتمدان للصف الرابع، من وحدتيهما — وهما مرجع
 *      الترتيب والتسمية: الفصل قبل الفصل، والوحدة قبل الوحدة.
 *   ٣. ما في `lesson_configs` نفسه — فكلّ درسٍ موجودٍ له مسارٌ، ولا
 *      يصحّ أن يبقى نصٌّ في الجدول بلا فرعٍ في الشجرة يراه المعلّم.
 *
 * والضمّ بتسويةٍ عربية: «الفصل الدراسي الاول» و«الأول» فرعٌ واحد لا
 * فرعان، ويبقى الاسم المعتمد.
 *
 * ثم يكتب `smartEdu_grades` تبعاً للشجرة، ويُسقط من قائمة المحذوفات
 * أيَّ درسٍ من المنهجين (فقائمة المحذوفات تُخفيه عن شاشة إدارة
 * المحتوى ولو كان في الجدول)، ويرفع ختم المحتوى ليأخذ كلُّ متصفّح
 * النسخة الجديدة.
 *
 * التشغيل — المعاينة أولاً:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
 *     node scripts/rebuild-academic-tree.mjs --teacher teacher_1786033127503
 *
 * ثم أضف --execute للتنفيذ.
 */

import {
  GRADE,
  SUBJECT as MATH_SUBJECT,
  UNITS as MATH_UNITS,
  curriculumRows,
} from "./grade4-math-curriculum.mjs";
import {
  SUBJECT as SCIENCE_SUBJECT,
  ID_PREFIX as SCIENCE_PREFIX,
  GRADE4_SCIENCE_CURRICULUM,
  scienceTermsForTree,
} from "./curriculum/grade4-science-curriculum.mjs";
import {
  SUBJECT as ENGLISH_SUBJECT,
  ID_PREFIX as ENGLISH_PREFIX,
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
const GRADES_KEY = "smartEdu_grades";
const DELETED_LESSONS_KEY = "smartEdu_deletedLessons";
const EPOCH_KEY = "smartEdu_contentEpoch";
const ADMIN = "admin";

const headers = () => ({
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  "Content-Type": "application/json",
});

const text = (value) => (value == null ? "" : String(value).trim());

/** تسوية عربية للمقارنة وحدها: الهمزة لا تصنع فرعاً ثانياً. */
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
  norm(record?.teacher_id ?? record?.teacherId ?? record?.createdBy) || ADMIN;

/**
 * قيمة `app_kv` كما هي أو بعد فكّ نصّها.
 *
 * السبب الذي ضاعت به الرياضيات: القراءة كانت تشترط مصفوفةً وترتدّ إلى
 * «لا شيء» عند غيرها، فيُكتب فوق الموجود. هنا تُجرَّب المصفوفة ثم النصّ
 * ثم الغلاف، ولا يُرتدّ إلى الفراغ إلا حين لا يكون ثمّة شيء حقاً.
 */
export function asArray(value) {
  if (Array.isArray(value)) return value;
  if (value && typeof value === "object" && Array.isArray(value.value)) return value.value;
  if (typeof value === "string" && value.trim()) {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
  return [];
}

// ── بناء فروع المنهجين المعتمدين ───────────────────────────────────────

/** فصول الرياضيات ووحداتها ودروسها، بترتيب المنهج. */
export function mathTermsForTree() {
  const rows = curriculumRows();
  const terms = [];
  for (const group of MATH_UNITS) {
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

/** المناهج المعتمدة: مرجعُ التسمية والترتيب لموادّ الصف الرابع. */
export const KNOWN_SUBJECTS = [
  { subject: MATH_SUBJECT, terms: () => mathTermsForTree() },
  { subject: SCIENCE_SUBJECT, terms: () => scienceTermsForTree() },
  { subject: ENGLISH_SUBJECT, terms: () => englishTermsForTree() },
];

/** معرّفات دروس المناهج، لتنقية قائمة المحذوفات منها. */
export function curriculumLessonIds(owners) {
  const ids = new Set();
  for (const owner of owners) {
    for (const row of curriculumRows()) {
      ids.add(`g4math_${row.number.replace(".", "_")}_${owner}`);
    }
    for (const item of GRADE4_SCIENCE_CURRICULUM) {
      ids.add(`${SCIENCE_PREFIX}${item.idSuffix}_${owner}`);
    }
    for (const item of GRADE4_ENGLISH_CURRICULUM) {
      ids.add(`${ENGLISH_PREFIX}${item.idSuffix}_${owner}`);
    }
  }
  return ids;
}

// ── الضمّ ──────────────────────────────────────────────────────────────

const findBy = (list, key, name) =>
  list.find((item) => norm(item?.[key]) === norm(name));

/**
 * يضمّ فرعاً إلى الشجرة بلا حذف: ما كان فيها بقي، وما جُدّ أُلحق.
 *
 * والاسم المعتمد هو اسم المنهج حين يلتقيان بعد التسوية، فتُطوى نسخةُ
 * الهمزة الناقصة في أختها بدل أن تعيش إلى جانبها فرعاً ثانياً.
 */
export function mergeSubject(configs, owner, ownerName, grade, subject) {
  const list = Array.isArray(configs) ? [...configs] : [];
  let config = list.find(
    (item) => ownerOf(item) === norm(owner) && norm(item?.grade) === norm(grade),
  );
  if (!config) {
    config = {
      grade,
      createdBy: owner,
      teacherId: owner,
      createdByName: ownerName || owner,
      createdAt: new Date().toISOString(),
      subjects: [],
    };
    list.push(config);
  }
  if (!Array.isArray(config.subjects)) config.subjects = [];

  let target = findBy(config.subjects, "subject", subject.subject);
  if (!target) {
    target = { subject: subject.subject, terms: [] };
    config.subjects.push(target);
  }
  if (!Array.isArray(target.terms)) target.terms = [];

  for (const incoming of subject.terms) {
    let term = findBy(target.terms, "term", incoming.term);
    if (!term) {
      term = { term: incoming.term, units: [], lessons: {} };
      target.terms.push(term);
    } else {
      term.term = incoming.term; // الاسم المعتمد يغلب نسخته الناقصة
    }
    if (!Array.isArray(term.units)) term.units = [];
    if (!term.lessons || typeof term.lessons !== "object") term.lessons = {};

    for (const unit of incoming.units) {
      const existingUnit = term.units.find((item) => norm(item) === norm(unit));
      if (existingUnit && existingUnit !== unit) {
        // وحدةٌ بالاسم نفسه بعد التسوية: تُسمّى باسم المنهج وتُنقل دروسها.
        term.units[term.units.indexOf(existingUnit)] = unit;
        if (term.lessons[existingUnit]) {
          term.lessons[unit] = [
            ...(term.lessons[unit] ?? []),
            ...term.lessons[existingUnit],
          ];
          delete term.lessons[existingUnit];
        }
      } else if (!existingUnit) {
        term.units.push(unit);
      }

      const wanted = incoming.lessons?.[unit] ?? [];
      const have = Array.isArray(term.lessons[unit]) ? term.lessons[unit] : [];
      // دروس المنهج أولاً بترتيبه، ثم ما أضافه صاحب الشاشة بيده.
      const merged = [...wanted];
      for (const lesson of have) {
        if (!merged.some((item) => norm(item) === norm(lesson))) merged.push(lesson);
      }
      if (merged.length) term.lessons[unit] = merged;
    }
  }

  return list;
}

/**
 * فروعٌ مستخرَجة من `lesson_configs` نفسه.
 *
 * كل درسٍ في الجدول مسارٌ خماسي كامل؛ فما لم يكن له فرعٌ في الشجرة
 * أُنشئ له. وبه لا يبقى نصٌّ محقونٌ لا يراه أحد.
 */
export function subjectsFromLessons(rows) {
  const byOwner = new Map();
  for (const row of rows) {
    const data = row?.data ?? {};
    const grade = text(data.grade);
    const subject = text(data.subject);
    const term = text(data.term);
    const unit = text(data.unit);
    const lesson = text(data.lesson);
    if (!grade || !subject || !term || !unit || !lesson) continue;

    const owner = ownerOf(data);
    if (!byOwner.has(owner)) byOwner.set(owner, new Map());
    const grades = byOwner.get(owner);
    if (!grades.has(norm(grade))) grades.set(norm(grade), { grade, subjects: [] });
    const entry = grades.get(norm(grade));

    let targetSubject = findBy(entry.subjects, "subject", subject);
    if (!targetSubject) {
      targetSubject = { subject, terms: [] };
      entry.subjects.push(targetSubject);
    }
    let targetTerm = findBy(targetSubject.terms, "term", term);
    if (!targetTerm) {
      targetTerm = { term, units: [], lessons: {} };
      targetSubject.terms.push(targetTerm);
    }
    if (!targetTerm.units.some((item) => norm(item) === norm(unit))) {
      targetTerm.units.push(unit);
    }
    const lessons = (targetTerm.lessons[unit] ??= []);
    if (!lessons.some((item) => norm(item) === norm(lesson))) lessons.push(lesson);
  }
  return byOwner;
}

/** كل ما في الشجرة من مسارات، لعدّها وطباعتها. */
export function summarise(configs) {
  const lines = [];
  for (const config of configs) {
    const subjects = Array.isArray(config?.subjects) ? config.subjects : [];
    for (const subject of subjects) {
      const terms = Array.isArray(subject?.terms) ? subject.terms : [];
      const units = terms.reduce((sum, t) => sum + (t.units?.length ?? 0), 0);
      const lessons = terms.reduce(
        (sum, t) => sum + Object.values(t.lessons ?? {}).flat().length,
        0,
      );
      lines.push({
        owner: ownerOf(config),
        grade: text(config.grade),
        subject: text(subject.subject),
        terms: terms.length,
        units,
        lessons,
      });
    }
  }
  return lines;
}

// ── الشبكة ─────────────────────────────────────────────────────────────

async function readJson(path) {
  const response = await fetch(`${SUPABASE_URL}${path}`, { headers: headers() });
  if (!response.ok) {
    throw new Error(`GET ${path} → ${response.status} ${(await response.text()).slice(0, 200)}`);
  }
  return response.json();
}

async function putKv(key, value, stamp) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/app_kv?on_conflict=key`, {
    method: "POST",
    headers: { ...headers(), Prefer: "resolution=merge-duplicates,return=minimal" },
    body: JSON.stringify({ key, value, updated_at: stamp }),
  });
  if (!response.ok) {
    throw new Error(`POST ${key} → ${response.status} ${(await response.text()).slice(0, 300)}`);
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
      "الاستعمال: node scripts/rebuild-academic-tree.mjs --teacher <معرّف المعلّم> [--execute]",
    );
    process.exit(1);
  }

  const owner = norm(TEACHER);
  line(EXECUTE ? "✍️ تنفيذ فعلي." : "🔍 معاينة — لن يُكتب شيء. أضف --execute للتنفيذ.");
  line(`المعلّم: «${TEACHER}»   القالب: «${ADMIN}»   الصف: «${GRADE}»`);

  // ── تشخيص: ما في قاعدة البيانات الآن ────────────────────────────────
  head("التشخيص");
  const kvRows = await readJson("/rest/v1/app_kv?select=key,value&limit=1000");
  const kv = new Map((Array.isArray(kvRows) ? kvRows : []).map((r) => [r.key, r.value]));

  const rawTree = kv.get(HIERARCHY_KEY);
  const shape = Array.isArray(rawTree)
    ? "مصفوفة"
    : rawTree == null
      ? "غائب"
      : typeof rawTree;
  const before = asArray(rawTree);
  line(`${HIERARCHY_KEY}: ${shape}، ${before.length} مدخلاً`);
  if (!Array.isArray(rawTree) && before.length) {
    line("  ⚠️ القيمة ليست مصفوفةً مباشرة — وهذا وحده كان يُفقد الشجرةَ عند كل بذر.");
  }
  for (const entry of summarise(before)) {
    line(
      `  • ${entry.owner} ▸ ${entry.grade} ▸ ${entry.subject}: ` +
        `${entry.terms} فصول، ${entry.units} وحدات، ${entry.lessons} دروس`,
    );
  }
  if (!before.length) line("  (الشجرة خالية تماماً)");

  const lessonRows = await readJson("/rest/v1/lesson_configs?select=id,data&limit=10000");
  const lessons = Array.isArray(lessonRows) ? lessonRows : [];
  line();
  line(`lesson_configs: ${lessons.length} سجلاً`);
  const bySubject = new Map();
  for (const row of lessons) {
    const key = `${ownerOf(row?.data)} ▸ ${text(row?.data?.subject) || "—"}`;
    bySubject.set(key, (bySubject.get(key) ?? 0) + 1);
  }
  for (const [key, count] of [...bySubject].sort((a, b) => b[1] - a[1])) {
    line(`  • ${key}: ${count}`);
  }

  const deleted = asArray(kv.get(DELETED_LESSONS_KEY)).map(String);
  const curriculumIds = curriculumLessonIds([owner, ADMIN]);
  const wronglyDeleted = deleted.filter((id) => curriculumIds.has(id));
  line();
  line(`${DELETED_LESSONS_KEY}: ${deleted.length} معرّفاً`);
  if (wronglyDeleted.length) {
    line(`  ⚠️ منها ${wronglyDeleted.length} من المنهجين — تُخفي الدرسَ ولو كان في الجدول:`);
    for (const id of wronglyDeleted) line(`      ✖ ${id}`);
  }

  // ── البناء ──────────────────────────────────────────────────────────
  head("البناء");
  let next = before.map((config) => JSON.parse(JSON.stringify(config)));

  // ١. المنهجان المعتمدان، للمعلّم وللقالب.
  for (const [id, name] of [[owner, TEACHER_NAME], [ADMIN, "المشرف"]]) {
    for (const known of KNOWN_SUBJECTS) {
      next = mergeSubject(next, id, name, GRADE, {
        subject: known.subject,
        terms: known.terms(),
      });
    }
  }
  line(`ضُمَّ المنهجان (${KNOWN_SUBJECTS.map((k) => k.subject).join("، ")}) للمعلّم وللقالب.`);

  // ٢. كل ما في `lesson_configs` ولو لم يكن من المنهجين.
  let extra = 0;
  for (const [lessonOwner, grades] of subjectsFromLessons(lessons)) {
    for (const entry of grades.values()) {
      for (const subject of entry.subjects) {
        const wasThere = next.some(
          (config) =>
            ownerOf(config) === lessonOwner &&
            norm(config?.grade) === norm(entry.grade) &&
            (config.subjects ?? []).some((s) => norm(s?.subject) === norm(subject.subject)),
        );
        next = mergeSubject(next, lessonOwner, "", entry.grade, subject);
        if (!wasThere) extra += 1;
      }
    }
  }
  line(`ضُمَّ ما في الجدول: ${extra} فرعاً لم يكن في الشجرة.`);

  line();
  line("الشجرة بعد البناء:");
  for (const entry of summarise(next)) {
    line(
      `  • ${entry.owner} ▸ ${entry.grade} ▸ ${entry.subject}: ` +
        `${entry.terms} فصول، ${entry.units} وحدات، ${entry.lessons} دروس`,
    );
  }

  const gradesList = Array.from(
    new Map(next.map((config) => [norm(config?.grade), text(config?.grade)])).values(),
  ).filter(Boolean);
  line();
  line(`${GRADES_KEY}: ${gradesList.join("، ") || "—"}`);

  // لا يُكتب إن كان البناء أفقر مما كان: هذا السكربت يضمّ ولا يُنقص.
  const lost = summarise(before).filter(
    (was) =>
      !summarise(next).some(
        (is) =>
          is.owner === was.owner &&
          norm(is.grade) === norm(was.grade) &&
          norm(is.subject) === norm(was.subject),
      ),
  );
  if (lost.length) {
    console.error("❌ البناء أسقط فروعاً — لن يُكتب شيء:");
    for (const entry of lost) console.error(`   ${entry.owner} ▸ ${entry.grade} ▸ ${entry.subject}`);
    process.exit(1);
  }

  if (!EXECUTE) {
    line();
    line("(معاينة فقط — لم يُكتب شيء)");
    return;
  }

  // ── الكتابة ─────────────────────────────────────────────────────────
  head("الكتابة");
  const stamp = new Date().toISOString();
  await putKv(HIERARCHY_KEY, next, stamp);
  line(`كُتبت الشجرة: ${next.length} مدخلاً.`);
  await putKv(GRADES_KEY, gradesList, stamp);
  line(`كُتبت الصفوف: ${gradesList.length}.`);
  if (wronglyDeleted.length) {
    await putKv(
      DELETED_LESSONS_KEY,
      deleted.filter((id) => !curriculumIds.has(id)),
      stamp,
    );
    line(`نُقّيت قائمة المحذوفات من ${wronglyDeleted.length} درساً من المنهجين.`);
  }
  await putKv(EPOCH_KEY, stamp, stamp);
  line(`رُفع ختم المحتوى: ${stamp}`);

  // ── التحقّق من المخزون نفسه ─────────────────────────────────────────
  head("التحقّق");
  const after = asArray(
    (await readJson(`/rest/v1/app_kv?select=key,value&key=eq.${encodeURIComponent(HIERARCHY_KEY)}`))
      ?.[0]?.value,
  );
  const expected = [
    { subject: MATH_SUBJECT, lessons: curriculumRows().length },
    { subject: SCIENCE_SUBJECT, lessons: GRADE4_SCIENCE_CURRICULUM.length },
    { subject: ENGLISH_SUBJECT, lessons: GRADE4_ENGLISH_CURRICULUM.length },
  ];
  const problems = [];
  for (const id of [owner, ADMIN]) {
    for (const want of expected) {
      const found = summarise(after).find(
        (entry) =>
          entry.owner === id &&
          norm(entry.grade) === norm(GRADE) &&
          norm(entry.subject) === norm(want.subject),
      );
      if (!found) {
        problems.push(`«${want.subject}» غائبة عن «${id}»`);
      } else if (found.lessons < want.lessons) {
        problems.push(`«${want.subject}» عند «${id}»: ${found.lessons} درساً بدل ${want.lessons}`);
      } else {
        line(`  ✅ ${id} ▸ ${want.subject}: ${found.lessons} درساً في ${found.units} وحدة`);
      }
    }
  }
  if (problems.length) {
    console.error(`❌ التحقّق فشل: ${problems.join(" — ")}`);
    process.exit(1);
  }
  line();
  line("✅ الشجرة قائمة بالمادّتين للمعلّم وللقالب، والختم مرفوع.");
  line("   افتح شاشة الإعدادات الأكاديمية بعد تحديث الصفحة — تأخذ النسخة الجديدة من الخادم.");
}

if (process.argv[1] && process.argv[1].endsWith("rebuild-academic-tree.mjs")) {
  main().catch((error) => {
    console.error("فشل:", error.message);
    process.exit(1);
  });
}
