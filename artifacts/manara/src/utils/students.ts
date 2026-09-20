import { STORAGE_KEYS } from '../constants';

/**
 * يسجّل حذف طالب قبل إزالة سجلّه.
 *
 * المزامنة تدمج البعيد مع المحلي اتحاداً: السجلّ المحذوف من هذا المتصفّح
 * وحده يعود من النسخة البعيدة في أول مزامنة، ويبقى ظاهراً في بقية
 * البوابات. والعلامة هي ما يجعل الحذف يصمد: تُزامَن مثل أي مفتاح، وتُسقِط
 * السجلّ من الطرفين، ويُحذف الصفّ البعيد عند أول اتصال.
 *
 * نفس عقد الدروس والاختبارات والفيديو حرفاً.
 */
export function markStudentDeleted(id: string): void {
  const stored = localStorage.getItem(STORAGE_KEYS.DELETED_STUDENTS);
  const existing: unknown[] = stored ? JSON.parse(stored) : [];
  const next = Array.from(
    new Set([
      ...existing.filter(value => value != null).map(String),
      String(id),
    ]),
  );
  localStorage.setItem(STORAGE_KEYS.DELETED_STUDENTS, JSON.stringify(next));
}

/** الطلاب الذين لم يُحذفوا، لأي شاشة تقرأ القائمة من التخزين مباشرة. */
export function withoutDeletedStudents<T extends { id?: unknown }>(students: T[]): T[] {
  const stored = localStorage.getItem(STORAGE_KEYS.DELETED_STUDENTS);
  if (!stored) return students;
  const deleted = new Set<string>(
    (JSON.parse(stored) as unknown[])
      .filter(value => value != null)
      .map(String),
  );
  if (deleted.size === 0) return students;
  return students.filter(student => student?.id == null || !deleted.has(String(student.id)));
}
