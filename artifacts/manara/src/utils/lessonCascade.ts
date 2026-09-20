import { STORAGE_KEYS } from '../constants';
import { LessonConfig } from '../types';
import { normalizeScopeValue } from './scope';

/**
 * الدروس تتبع الشجرة الأكاديمية.
 *
 * الشجرة والدروس مخزّنان منفصلين: الشجرة في `app_kv`، والدروس في
 * `lesson_configs` وكل درس يحمل مساره نصّاً (صف، مادة، فصل، وحدة). فإعادة
 * تسمية وحدة في الإعدادات كانت تترك دروسها معلّقة على الاسم القديم: لا
 * تظهر للطالب لأن مسارها لم يعد في الشجرة، ولا تظهر في الإعدادات لأنها
 * ليست جزءاً منها. وحذف عقدة كان يتركها كذلك.
 *
 * هذه الدوال تُبقي الطرفين متّفقين: إعادة التسمية تنتقل إلى الدروس،
 * والحذف يَسِم دروسه محذوفةً بنفس عقد الحذف المستعمل في إدارة المحتوى
 * (علامة في `DELETED_LESSONS` ثم إزالة من القائمة) — فلا تعود من المزامنة.
 */

/** المستوى الذي يُطابَق عليه، وما فوقه من المسار. */
export type LessonScope = {
  grade: string;
  subject?: string;
  term?: string;
  unit?: string;
};

const same = (a: unknown, b: unknown) => normalizeScopeValue(a) === normalizeScopeValue(b);

function readLessons(): LessonConfig[] {
  const stored = localStorage.getItem(STORAGE_KEYS.LESSON_CONFIGS);
  const parsed = stored ? JSON.parse(stored) : [];
  return Array.isArray(parsed) ? parsed : [];
}

function writeLessons(lessons: LessonConfig[]): void {
  localStorage.setItem(STORAGE_KEYS.LESSON_CONFIGS, JSON.stringify(lessons));
}

function matchesScope(lesson: LessonConfig, scope: LessonScope): boolean {
  if (!same(lesson.grade, scope.grade)) return false;
  if (scope.subject !== undefined && !same(lesson.subject, scope.subject)) return false;
  if (scope.term !== undefined && !same(lesson.term, scope.term)) return false;
  if (scope.unit !== undefined && !same(lesson.unit, scope.unit)) return false;
  return true;
}

/** كم درساً يقع تحت هذه العقدة — لتقوله رسالة التأكيد قبل الحذف. */
export function countLessonsUnder(scope: LessonScope): number {
  return readLessons().filter(lesson => matchesScope(lesson, scope)).length;
}

/**
 * يُعيد تسمية مستوى في مسار كل درس يقع تحته.
 *
 * [scope] يصف العقدة بالاسم القديم، و[field] هو المستوى الذي تغيّر.
 * يُرجع عدد الدروس التي تبعت التسمية.
 */
export function renameLessonsPath(
  scope: LessonScope,
  field: 'grade' | 'subject' | 'term' | 'unit',
  nextName: string,
): number {
  const name = nextName.trim();
  if (!name) return 0;
  const lessons = readLessons();
  let changed = 0;
  const updated = lessons.map(lesson => {
    if (!matchesScope(lesson, scope)) return lesson;
    if (same(lesson[field], name)) return lesson;
    changed += 1;
    return { ...lesson, [field]: name };
  });
  if (changed > 0) writeLessons(updated);
  return changed;
}

/**
 * يَسِم دروس عقدة محذوفة بالحذف.
 *
 * نفس عقد إدارة المحتوى: العلامة تُكتب أولاً حتى لا تُعيدها المزامنة، ثم
 * يُزال السجلّ. يُرجع عدد الدروس التي حُذفت.
 */
export function markLessonsDeletedUnder(scope: LessonScope): number {
  const lessons = readLessons();
  const doomed = lessons.filter(lesson => matchesScope(lesson, scope));
  if (doomed.length === 0) return 0;

  const stored = localStorage.getItem(STORAGE_KEYS.DELETED_LESSONS);
  const existing: unknown[] = stored ? JSON.parse(stored) : [];
  const deletedIds = Array.from(
    new Set([
      ...existing.filter(value => value != null).map(String),
      ...doomed.map(lesson => String(lesson.id)),
    ]),
  );
  localStorage.setItem(STORAGE_KEYS.DELETED_LESSONS, JSON.stringify(deletedIds));

  const doomedIds = new Set(doomed.map(lesson => String(lesson.id)));
  writeLessons(lessons.filter(lesson => !doomedIds.has(String(lesson.id))));
  return doomed.length;
}
