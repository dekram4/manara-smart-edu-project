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
): unknown {
  const mine = isOwnedBy(identities);
  if (key === HIERARCHY_KEY) {
    return records(value).filter((config) => mine(config) || TEMPLATE_OWNERS.has(ownerOf(config)));
  }
  if (FLAT_KEYS.has(key)) return flatFrom(key, records(hierarchy).filter(mine));
  if (OWNED_RECORD_KEYS.has(key)) return Array.isArray(value) ? records(value).filter(mine) : value;
  return value;
}
