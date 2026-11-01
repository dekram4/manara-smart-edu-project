/**
 * عزلُ المعلم في مفاتيح `app_kv` المشتركة: ما يُرسل له منها — بلا قاعدة بيانات،
 * فيُختبر وحده.
 *
 * ── لماذا ──
 * صفوفُ `app_kv` (الشجرة الأكاديمية، والقوائم المسطّحة، والإشعارات) مفتاحٌ واحد
 * لكل المعلمين. وكانت تُرسل للمعلم كاملة، فتعرض لوحتُه صفوفَ غيره وموادَّه، وإن
 * صفّتها شاشةٌ نسيتها أخرى. فالتصفيةُ هنا، عند المصدر: ما لا يملكه لا يصل إليه.
 *
 * ── ما يصل ──
 *   الشجرة            إعداداتُه، وقوالبُ المشرف (تبويبُ «الإعدادات العامة» يَنسخ منها).
 *   القوائم المسطّحة   مشتقّةٌ من شجرته وحدها — لا من قوالب المشرف ولا غيره.
 *   سجلّاتٌ بمالك      ما يملكه وحده (إشعاراتُ الفيديو، إعداداتُ الصفوف…).
 *
 * والكتابةُ محميّةٌ في الجسر أصلاً (`mergeTeacherConfigs`): ما يُرسله المعلم من
 * الشجرة يُبقي ما لغيره كما هو، فتصفيةُ القراءة لا تمحو عمل أحد.
 */

export const HIERARCHY_KEY = "smartEdu_hierarchicalConfigs";

/** القوائم المسطّحة، وكيف تُشتقّ من الشجرة. */
const FLAT_KEYS = new Set(["smartEdu_grades", "smartEdu_subjects", "smartEdu_terms", "smartEdu_units"]);

/** مفاتيحُ سجلّاتها بمالك: يصل منها ما يملكه المعلم. */
const OWNED_RECORD_KEYS = new Set([
  "smartEdu_gradeConfigs",
  "smartEdu_quizQuestions",
  "smartEdu_videoNotifications",
]);

/** مالكو القوالب العامة. */
const TEMPLATE_OWNERS = new Set(["admin", "supervisor"]);

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/** نفسُ تسوية المالك في الجسر (`normalizeOwner`). */
export function normalizeOwner(value: unknown): string {
  return text(value)
    .toLowerCase()
    .replace(/[ً-ْٰـ]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/\s+/g, " ")
    .trim();
}

function records(value: unknown): Record<string, unknown>[] {
  return Array.isArray(value)
    ? value.filter((item): item is Record<string, unknown> => Boolean(item) && typeof item === "object")
    : [];
}

export function ownerOf(record: Record<string, unknown>): string {
  return normalizeOwner(text(record.teacher_id) || text(record.teacherId) || text(record.createdBy));
}

const isOwnedBy = (identities: Set<string>) => (record: Record<string, unknown>) => {
  const owner = ownerOf(record);
  return Boolean(owner) && identities.has(owner);
};

function unique(values: string[]): string[] {
  const byKey = new Map<string, string>();
  for (const value of values) {
    const key = normalizeOwner(value);
    if (key && !byKey.has(key)) byKey.set(key, value);
  }
  return [...byKey.values()];
}

/** القائمةُ المسطّحة من شجرة المعلم. */
function flatFrom(key: string, configs: Record<string, unknown>[]): string[] {
  const subjects = configs.flatMap((config) => (Array.isArray(config.subjects) ? config.subjects : []));
  const subjectRecords = subjects.filter((s): s is Record<string, unknown> => Boolean(s) && typeof s === "object");
  const terms = subjectRecords.flatMap((s) => records(s.terms));
  switch (key) {
    case "smartEdu_grades":
      return unique(configs.map((config) => text(config.grade)));
    case "smartEdu_subjects":
      return unique(subjects.map((s) => (typeof s === "string" ? s.trim() : text((s as Record<string, unknown>)?.subject))));
    case "smartEdu_terms":
      return unique(terms.map((term) => text(term.term)));
    case "smartEdu_units":
      return unique(terms.flatMap((term) => (Array.isArray(term.units) ? term.units.map(text) : [])));
    default:
      return [];
  }
}

/**
 * قيمةُ المفتاح كما تُرسل لهذا المعلم.
 *
 * [identities] كلُّ ما يُعرف به المعلم، مسوّىً بـ [normalizeOwner] — من
 * `teacherIdentities` في الجسر. و[hierarchy] الشجرةُ كاملةً كما في `app_kv`،
 * تُشتقّ منها القوائمُ المسطّحة.
 */
export function scopeKvForTeacher(
  key: string,
  value: unknown,
  identities: Set<string>,
  hierarchy: unknown,
  teacherId = "",
): unknown {
  const mine = isOwnedBy(identities);
  if (key === HIERARCHY_KEY) {
    const scoped = records(value).filter((config) => mine(config) || TEMPLATE_OWNERS.has(ownerOf(config)));
    return teacherId ? canonicalTeacherConfigs(scoped, identities, teacherId) : scoped;
  }
  if (FLAT_KEYS.has(key)) return flatFrom(key, records(hierarchy).filter(mine));
  if (OWNED_RECORD_KEYS.has(key)) return Array.isArray(value) ? records(value).filter(mine) : value;
  return value;
}

// ─────────────────────────────────────────────────────────────────────
// مدخلاتُ المعلم بمعرّفه
// ─────────────────────────────────────────────────────────────────────

type Json = Record<string, unknown>;

/** مفتاحُ الصفّ كما تدمجه شاشاتُ الويب (`dedupeHierarchicalConfigs`): حرفيٌّ إلا الحالة. */
const gradeKey = (config: Json): string => text(config.grade).toLowerCase();

function arrayOf(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function objectOf(value: unknown): Json {
  return value && typeof value === "object" && !Array.isArray(value) ? (value as Json) : {};
}

/** يضمّ دروسَ [from] ووحداتِه إلى الفصل [into] — اتّحاداً، بلا تكرار. */
function mergeTerm(into: Json, from: Json): void {
  const units = arrayOf(into.units).map((u) => text(u)).filter(Boolean);
  const lessons: Json = { ...objectOf(into.lessons) };
  const fromLessons = objectOf(from.lessons);
  for (const unit of [...arrayOf(from.units).map((u) => text(u)), ...Object.keys(fromLessons)]) {
    if (!unit) continue;
    if (!units.includes(unit)) units.push(unit);
    const have = arrayOf(lessons[unit]).map((l) => text(l));
    for (const lesson of arrayOf(fromLessons[unit]).map((l) => text(l))) {
      if (lesson && !have.includes(lesson)) have.push(lesson);
    }
    if (have.length || unit in fromLessons || unit in lessons) lessons[unit] = have;
  }
  into.units = units;
  if (Object.keys(lessons).length || "lessons" in into || "lessons" in from) into.lessons = lessons;
}

/** يضمّ موادَّ [from] إلى [into]: المادّةُ والفصلُ باسمهما، وما سواهما يُلحق. */
function mergeSubjects(into: Json, from: unknown): void {
  const subjects = arrayOf(into.subjects) as Json[];
  for (const subject of arrayOf(from) as Json[]) {
    const name = text(subject?.subject);
    if (!name) continue;
    let target = subjects.find((s) => text(s?.subject) === name);
    if (!target) {
      subjects.push(structuredClone(subject));
      continue;
    }
    const terms = arrayOf(target.terms) as Json[];
    for (const term of arrayOf(subject.terms) as Json[]) {
      const termName = text(term?.term);
      if (!termName) continue;
      const existing = terms.find((t) => text(t?.term) === termName);
      if (existing) mergeTerm(existing, term);
      else terms.push(structuredClone(term));
    }
    target.terms = terms;
  }
  into.subjects = subjects;
}

/**
 * مدخلاتُ الشجرة التي يملكها هذا المعلم — بأيّ اسمٍ يُعرف به — مختومةً
 * بمعرّفه، ومدموجاً ما تكرّر منها للصفّ نفسه. وما لغيره كما هو.
 *
 * ── لماذا ──
 * الخادم يعرف المعلّم بكل أسمائه (المعرّف، واسم الدخول، والاسم)، وشاشاتُ
 * الويب — «الإعدادات الأكاديمية» و«إدارة المحتوى» — لا تعرض إلا ما مالكُه
 * معرّفُه حرفياً. فمدخلٌ مالكُه اسمُه يصل إلى متصفّحه ولا يُعرض فيه: المادّةُ
 * التي تحته لا تظهر، وما يُضاف إلى الصفّ نفسه يذهب إلى مدخلٍ ثانٍ. والمالكُ
 * يُقرأ في الخادم بـ`||` وفي الويب بـ`??`، فمدخلٌ `teacher_id` فيه فارغ
 * يُنسب في الأوّل إلى المعلم وفي الثاني إلى لا أحد. والختمُ يضع المعرّفَ في
 * كل حقلٍ للمالك موجود، فيتّفق الاثنان.
 */
export function canonicalTeacherConfigs(
  configs: Json[],
  identities: Set<string>,
  teacherId: string,
): Json[] {
  const id = text(teacherId);
  if (!id) return configs;
  const mine = isOwnedBy(identities);
  const out: Json[] = [];
  const byGrade = new Map<string, Json>();
  for (const config of configs) {
    if (!mine(config)) {
      out.push(config);
      continue;
    }
    const stamped: Json = { ...structuredClone(config), teacher_id: id };
    if ("teacherId" in config) stamped.teacherId = id;
    if ("createdBy" in config && identities.has(normalizeOwner(config.createdBy))) stamped.createdBy = id;
    const key = gradeKey(config);
    const existing = key ? byGrade.get(key) : undefined;
    if (existing) {
      mergeSubjects(existing, stamped.subjects);
      continue;
    }
    if (key) byGrade.set(key, stamped);
    out.push(stamped);
  }
  return out;
}
