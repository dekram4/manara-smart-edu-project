/**
 * صلاحيات بطاقات الطالب: قواعدُ بلا قاعدة بيانات — تُختبر وحدها.
 *
 * ── نطاقان، والأضيق يغلب ──
 * قاعدةُ صفّ (`class`) لكل طلاب معلمٍ في صفٍّ دراسيّ، وقاعدةُ طالب
 * (`student`) لطالبٍ واحد. والبطاقةُ التي لم تذكرها قاعدةٌ مفتوحة: نظامٌ
 * جديد لا يُغلق على الطلاب ما كان مفتوحاً لهم أمس.
 */

import { scopeKey } from "./cinema";

/** البطاقات بترتيبها في واجهة الطالب، والمعرّفُ هو ما بعد `portal.` في التطبيق. */
export const STUDENT_CARDS = [
  { id: "lesson", label: "شرح الدرس" },
  { id: "cinema", label: "سينما منارة" },
  { id: "games", label: "عالم الترفيه" },
  { id: "personality", label: "شخصيتي" },
  { id: "tutor", label: "المعلم الافتراضي" },
  { id: "quiz", label: "مركز الاختبارات" },
  { id: "solver", label: "حلّ المسائل" },
  { id: "meeting", label: "اللقاء المباشر" },
  { id: "chat", label: "دردشة منارة" },
  { id: "challenge", label: "تحدَّ زملاءك" },
  { id: "study", label: "مغامرة الأذكياء ومهمة المذاكرة" },
] as const;

export type StudentCardId = (typeof STUDENT_CARDS)[number]["id"];

const CARD_IDS = new Set<string>(STUDENT_CARDS.map((card) => card.id));

export type CardMap = Partial<Record<StudentCardId, boolean>>;

export type CardRule = {
  id: string;
  scope: "class" | "student";
  studentId: string | null;
  teacherId: string;
  gradeId: string | null;
  cards: CardMap;
  updatedBy: string;
  updatedAt: string;
};

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

export function isStudentCardId(value: unknown): value is StudentCardId {
  return typeof value === "string" && CARD_IDS.has(value);
}

/** المعرّفاتُ المعروفة وحدها، وقيمٌ منطقية لا غير. */
export function sanitizeCards(value: unknown): CardMap {
  const cards: CardMap = {};
  if (!value || typeof value !== "object" || Array.isArray(value)) return cards;
  for (const [key, flag] of Object.entries(value as Record<string, unknown>)) {
    if (isStudentCardId(key) && typeof flag === "boolean") cards[key] = flag;
  }
  return cards;
}

export function classRuleId(teacherId: string, gradeId: string): string {
  return `class:${scopeKey(teacherId)}:${scopeKey(gradeId)}`;
}

export function studentRuleId(studentId: string): string {
  return `student:${text(studentId)}`;
}

/** صفٌّ من جدول `student_card_permissions` أو عنصرٌ من مفتاح `app_kv`. */
export function ruleFromRecord(record: Record<string, unknown>): CardRule | null {
  const scope = record.scope === "class" || record.scope === "student" ? record.scope : null;
  const id = text(record.id);
  const teacherId = text(record.teacher_id) || text(record.teacherId);
  if (!scope || !id || !teacherId) return null;
  const studentId = text(record.student_id) || text(record.studentId) || null;
  const gradeId = text(record.grade_id) || text(record.gradeId) || null;
  if (scope === "student" && !studentId) return null;
  if (scope === "class" && !gradeId) return null;
  return {
    id,
    scope,
    studentId,
    teacherId,
    gradeId,
    cards: sanitizeCards(record.cards),
    updatedBy: text(record.updated_by) || text(record.updatedBy),
    updatedAt: text(record.updated_at) || text(record.updatedAt),
  };
}

export function ruleToTableRow(rule: CardRule): Record<string, unknown> {
  return {
    id: rule.id,
    scope: rule.scope,
    student_id: rule.studentId,
    teacher_id: rule.teacherId,
    grade_id: rule.gradeId,
    cards: rule.cards,
    updated_by: rule.updatedBy,
    updated_at: rule.updatedAt || new Date().toISOString(),
  };
}

/**
 * الحالةُ النهائية لكل بطاقة عند طالبٍ بعينه.
 *
 * الكلُّ مفتوحٌ أولاً، ثم قاعدةُ صفّه (معلّمُه وصفُّه)، ثم قاعدتُه هو.
 */
export function effectiveCards(
  rules: CardRule[],
  student: {
    id: string;
    /** كلُّ معرّفات الطالب (معرّف السجلّ ومعرّف الصفّ): القاعدةُ تُطابق أيّاً منها. */
    ids?: string[];
    grade: string;
    teacherIdentities: Set<string>;
  },
): Record<StudentCardId, boolean> {
  const result = Object.fromEntries(
    STUDENT_CARDS.map((card) => [card.id, true]),
  ) as Record<StudentCardId, boolean>;
  const grade = scopeKey(student.grade);

  const classRules = rules.filter((rule) =>
    rule.scope === "class" &&
    student.teacherIdentities.has(scopeKey(rule.teacherId)) &&
    scopeKey(rule.gradeId) === grade,
  );
  for (const rule of classRules) Object.assign(result, rule.cards);

  const ids = new Set([student.id, ...(student.ids ?? [])].map(text).filter(Boolean));
  const own = rules.find((rule) =>
    rule.scope === "student" && ids.has(text(rule.studentId)),
  );
  if (own) Object.assign(result, own.cards);
  return result;
}
