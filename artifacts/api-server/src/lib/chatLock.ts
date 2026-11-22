/**
 * قفلُ الدردشة: المعلّمُ يوقف الإرسالَ لطالبٍ بعينه أو لطلابه جميعاً متى شاء.
 *
 * ── ما يُقفل ──
 * الإرسالُ وحده — نصّاً وصوتاً وصورةً وملفّاً، إلى الزملاء وإلى المعلّم. والقراءةُ
 * باقية: يرى الطالبُ ما وصله، ويرى سطراً يقول إن المعلّم قفل الدردشة. والمعلّمُ
 * نفسه يرسل كما يشاء.
 *
 * ── وأين يُحفظ ──
 * صفٌّ واحدٌ لكل معلّم في `interactions` (`chatlock_<معرّفه>`): لا جدولَ جديداً
 * يحتاج ترحيلاً.
 */

export const CHAT_LOCK_TYPE = "student_chat_lock";

export type ChatLock = {
  /** الطلابُ جميعاً. */
  all: boolean;
  /** طلابٌ بأعيانهم (معرّفاتُهم). */
  students: string[];
  updatedAt: string;
};

export const CHAT_LOCKED_MESSAGE = "المعلم قام بقفل الدردشة حالياً";

export function emptyLock(): ChatLock {
  return { all: false, students: [], updatedAt: "" };
}

/** معرّفُ صفّ القفل لمعلّمٍ [teacherKey] (معرّفُه مطبَّعاً). */
export function chatLockRowId(teacherKey: string): string {
  const safe = teacherKey.replace(/[^A-Za-z0-9_-]/g, (c) => `-${c.codePointAt(0)!.toString(16)}`);
  return `chatlock_${safe}`.slice(0, 180);
}

/** يقرأ القفلَ من بيانات صفّه — وما لم يُفهم: لا قفل. */
export function readChatLock(data: unknown): ChatLock {
  if (!data || typeof data !== "object") return emptyLock();
  const raw = data as Record<string, unknown>;
  if (raw.type !== CHAT_LOCK_TYPE) return emptyLock();
  const students = Array.isArray(raw.students)
    ? [...new Set(raw.students.filter((s): s is string => typeof s === "string" && s.length > 0 && s.length <= 200))]
    : [];
  return {
    all: raw.all === true,
    students: students.slice(0, 2000),
    updatedAt: typeof raw.updatedAt === "string" ? raw.updatedAt : "",
  };
}

export function isLockedFor(lock: ChatLock, studentId: string): boolean {
  return lock.all || lock.students.includes(studentId);
}

/**
 * القفلُ بعد طلب المعلّم: `{ all: true|false }` للجميع، أو
 * `{ studentId, locked: true|false }` لطالبٍ واحد.
 */
export function applyLockChange(lock: ChatLock, change: unknown, now: Date = new Date()): ChatLock | null {
  if (!change || typeof change !== "object") return null;
  const body = change as Record<string, unknown>;
  const stamp = now.toISOString();
  if (typeof body.all === "boolean") {
    // ‏فتحُ الجميع يفتح المقفولين بأعيانهم أيضاً: «افتح للكلّ» تعني الكلّ.
    return body.all
      ? { all: true, students: lock.students, updatedAt: stamp }
      : { all: false, students: [], updatedAt: stamp };
  }
  const id = typeof body.studentId === "string" ? body.studentId.trim() : "";
  if (!id || id.length > 200 || typeof body.locked !== "boolean") return null;
  const students = body.locked
    ? [...new Set([...lock.students, id])]
    : lock.students.filter((s) => s !== id);
  return { all: lock.all, students, updatedAt: stamp };
}
