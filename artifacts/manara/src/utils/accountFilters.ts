import type { ParentInfo, StudentInfo } from '../types';

export interface AccountFilter {
  query: string;
  /** `'all'` أو معرّفُ ولي أمر. */
  parentId: string;
  /** `'all'` أو معرّفُ طالب. */
  studentId: string;
}

const includes = (value: unknown, query: string) =>
  String(value ?? '').toLowerCase().includes(query);

export const studentMatches = (student: StudentInfo, query: string) =>
  !query ||
  includes(student.name, query) ||
  includes(student.username, query) ||
  includes(student.nationalId, query) ||
  includes(student.studentIdNumber, query);

export const parentMatches = (parent: ParentInfo, query: string) =>
  !query ||
  includes(parent.name, query) ||
  includes(parent.phoneNumber, query) ||
  includes(parent.nationalId, query) ||
  includes(parent.username, query);

/**
 * طلابُ المعلم وأولياؤه بعد الفلترة — قاعدةٌ واحدة لجدولي الطلاب وأولياء الأمور.
 *
 * ── ما كان ──
 * كانت القائمة أولياءَ أمورٍ تحت كلٍّ منهم أبناؤه. فـ«جميع الطلاب» لم تكن
 * قائمةَ طلاب، والطالبُ الذي لا وليَّ أمرٍ له عند المعلم لا يظهر أبداً. واختيارُ
 * ولي أمر يُظهره مع أبنائه، واختيارُ طالب يُلغي اختيارَ ولي الأمر.
 *
 * ── القاعدة الآن ──
 *   طالبٌ محدّد        ← هو وحده، وولي أمره وحده.
 *   ولي أمرٍ محدّد      ← هو وحده، وأبناؤه وحدهم.
 *   «الجميع»           ← كلُّ طلاب المعلم — بوليّ أمرٍ أو بدونه — وكلُّ أوليائه.
 * والبحثُ يحصر «الجميع»: الطالبُ يظهر إن طابق هو أو طابق وليُّ أمره، والعكس.
 */
export function filterAccounts(
  students: StudentInfo[],
  parents: ParentInfo[],
  filter: AccountFilter,
): { students: StudentInfo[]; parents: ParentInfo[] } {
  const query = filter.query.trim().toLowerCase();
  const parentById = new Map(parents.map((parent) => [parent.id, parent]));

  if (filter.studentId !== 'all') {
    const student = students.find((item) => item.id === filter.studentId);
    if (!student) return { students: [], parents: [] };
    const parent = student.parentId ? parentById.get(student.parentId) : undefined;
    return { students: [student], parents: parent ? [parent] : [] };
  }

  if (filter.parentId !== 'all') {
    const parent = parentById.get(filter.parentId);
    if (!parent) return { students: [], parents: [] };
    return {
      students: students.filter((student) => student.parentId === parent.id && studentMatches(student, query)),
      parents: [parent],
    };
  }

  return {
    students: students.filter((student) => {
      if (studentMatches(student, query)) return true;
      const parent = student.parentId ? parentById.get(student.parentId) : undefined;
      return Boolean(parent && query && parentMatches(parent, query));
    }),
    parents: parents.filter(
      (parent) =>
        parentMatches(parent, query) ||
        students.some((student) => student.parentId === parent.id && Boolean(query) && studentMatches(student, query)),
    ),
  };
}
