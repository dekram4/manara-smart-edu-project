/**
 * مَن معلّمُ هذا الطالب في الدردشة — وكيف يُعرف المعلّمُ نفسُه — بمفتاحٍ واحد.
 *
 * ── لماذا ──
 * المعلّمُ يُكتب في سجلّ الطالب بأكثر من صورة: `teacherId` أو `teacher_id`، وفي
 * السجلّات الأقدم `createdBy` وحدها، أو لا شيء والطالبُ مربوطٌ بوليّ أمرٍ أنشأه
 * المعلّم. والقيمةُ نفسها قد تكون معرّفَ صفّ المعلّم، أو `data.id`، أو اسمَ
 * دخوله، أو رقمَه. ولوحةُ الويب تقرأ ذلك كلّه (`getStudentTeacherScope`)، وكانت
 * الدردشةُ تقرأ `teacherId` حرفياً وحده: فطالبٌ أنشأه معلّمُه يرى «لا يوجد معلّمٌ
 * مربوط بالصف»، ومعلّمٌ دخل بمعرّفه لا يرى طالباً كُتب له باسم دخوله.
 *
 * فيُحسب هنا مفتاحٌ واحد لكل معلّم — معرّفُه المسوّى — ويُردّ إليه كلُّ اسمٍ
 * يُعرف به، من جهة الطالب ومن جهة جلسة المعلّم معاً.
 *
 * بلا قاعدة بيانات: الجداولُ تُقرأ في المسار وتُمرَّر هنا، فيُختبر وحده.
 */
import { normalizeScopeId } from "./studentAccess";

type Row = { id?: unknown; data?: unknown };
type Json = Record<string, unknown>;

export type ChatTeacher = { key: string; name: string };

export type TeacherDirectory = {
  teachers: ChatTeacher[];
  /** كلُّ اسمٍ يُعرف به معلّمٌ واحدٌ فقط ← مفتاحُه. */
  byIdentity: Map<string, ChatTeacher>;
  /** الصفّ ← مفاتيحُ المعلّمين الذين يملكونه في الشجرة الأكاديمية. */
  gradeOwners: Map<string, Set<string>>;
  /** وليُّ الأمر ← من أنشأه. */
  parentOwner: Map<string, string>;
};

/** ما يلزم من سجلّ الطالب لمعرفة معلّمه. */
export type StudentTeacherFields = {
  teacherId: string;
  createdBy?: string;
  parentId?: string;
  grade: string;
};

/** مالكون ليسوا معلّمين: قوالبُ المشرف. */
const NOT_TEACHERS = new Set(["admin", "supervisor"]);

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : typeof value === "number" ? String(value) : "";
}

function dataOf(row: Row): Json {
  return row.data && typeof row.data === "object" ? (row.data as Json) : {};
}

export function buildTeacherDirectory(
  teacherRows: Row[],
  hierarchy: unknown = [],
  parentRows: Row[] = [],
): TeacherDirectory {
  const teachers: ChatTeacher[] = [];
  const claims = new Map<string, Set<string>>();
  const entries = new Map<string, ChatTeacher>();
  for (const row of teacherRows) {
    const data = dataOf(row);
    const key = normalizeScopeId(text(data.id) || text(row.id));
    if (!key || entries.has(key)) continue;
    const teacher = {
      key,
      name: text(data.name) || text(data.fullName) || text(data.username) || "معلّمي",
    };
    entries.set(key, teacher);
    teachers.push(teacher);
    const names = [row.id, data.id, data.username, data.teacherId, data.teacher_id, data.nationalId,
      data.email, data.name, data.fullName]
      .map((value) => normalizeScopeId(text(value)))
      .filter((name) => name && !NOT_TEACHERS.has(name));
    for (const name of names) {
      const set = claims.get(name) ?? new Set<string>();
      set.add(key);
      claims.set(name, set);
    }
  }
  // ‏اسمٌ يتقاسمه معلّمان (اسمٌ كامل مكرّر مثلاً) لا يدلّ على أحدهما: يُسقط.
  // والمعرّفُ يبقى لصاحبه دائماً.
  const byIdentity = new Map<string, ChatTeacher>();
  for (const [name, keys] of claims) {
    if (keys.size === 1) byIdentity.set(name, entries.get([...keys][0])!);
  }
  for (const [key, teacher] of entries) byIdentity.set(key, teacher);

  const gradeOwners = new Map<string, Set<string>>();
  for (const config of Array.isArray(hierarchy) ? hierarchy : []) {
    if (!config || typeof config !== "object") continue;
    const record = config as Json;
    const owner = normalizeScopeId(text(record.teacher_id) || text(record.teacherId) || text(record.createdBy));
    const grade = normalizeScopeId(text(record.grade));
    const teacher = owner ? byIdentity.get(owner) : undefined;
    if (!grade || !teacher) continue;
    const set = gradeOwners.get(grade) ?? new Set<string>();
    set.add(teacher.key);
    gradeOwners.set(grade, set);
  }

  const parentOwner = new Map<string, string>();
  for (const row of parentRows) {
    const data = dataOf(row);
    const owner = normalizeScopeId(text(data.createdBy) || text(data.teacherId) || text(data.teacher_id));
    if (!owner || NOT_TEACHERS.has(owner)) continue;
    for (const id of [row.id, data.id]) {
      const key = normalizeScopeId(text(id));
      if (key) parentOwner.set(key, owner);
    }
  }
  return { teachers, byIdentity, gradeOwners, parentOwner };
}

/** اسمٌ يُعرف به معلّم ← مفتاحُه؛ وما لا يُعرف يبقى كما هو مسوّىً. */
export function teacherKeyOf(directory: TeacherDirectory, identity: unknown): string {
  const name = normalizeScopeId(text(identity));
  if (!name) return "";
  return directory.byIdentity.get(name)?.key ?? name;
}

/**
 * مفتاحُ معلّم الطالب، بترتيب لوحة الويب: `teacherId`، ثم `createdBy`، ثم من
 * أنشأ وليَّ أمره. فإن خلا ذلك كلُّه، فمالكُ صفّه في الشجرة الأكاديمية — إن
 * كان واحداً لا غير؛ صفٌّ يدرّسه معلّمان لا يُنسب طالبُه إلى أحدهما تخميناً.
 */
export function studentTeacherKey(directory: TeacherDirectory, student: StudentTeacherFields): string {
  const createdBy = normalizeScopeId(text(student.createdBy));
  const fromParent = directory.parentOwner.get(normalizeScopeId(text(student.parentId))) ?? "";
  const named = [student.teacherId, NOT_TEACHERS.has(createdBy) ? "" : createdBy, fromParent]
    .map((value) => normalizeScopeId(text(value)))
    .find(Boolean);
  if (named) return teacherKeyOf(directory, named);
  const owners = directory.gradeOwners.get(normalizeScopeId(student.grade));
  return owners && owners.size === 1 ? [...owners][0] : "";
}

/** المعلّمُ بمفتاحه، للعرض. */
export function chatTeacherByKey(directory: TeacherDirectory, key: string): ChatTeacher | null {
  return key ? directory.byIdentity.get(key) ?? null : null;
}
