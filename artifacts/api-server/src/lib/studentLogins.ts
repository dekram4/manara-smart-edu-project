/**
 * عدّادُ دخول الطالب: كم مرّةً دخل تطبيقه، ومتى آخرها.
 *
 * يُكتب في سجلّه (`students.data.loginCount` و`lastLoginAt`) ويقرؤه وليُّ
 * الأمر والمعلم في لوحتيهما. والخادمُ وحده يكتبه: عند كل جلسةٍ يفتحها
 * التطبيق (`/auth/student/session`).
 *
 * ── لماذا يُحمى عند الحفظ ──
 * لوحاتُ الويب تحفظ سجلَّ الطالب كاملاً من نسخة المتصفّح، وتلك النسخة قد
 * تكون أقدمَ من آخر دخول. فحفظُ المعلم لصفّ الطالب كان سيُعيد العدّاد إلى
 * ما كان عليه حين فتح لوحته. فعند كل حفظٍ يُؤخذ الأكبرُ والأحدث مما في
 * قاعدة البيانات وما أُرسل.
 */

/** جلسةٌ جديدة خلال هذه المدّة من سابقتها ليست دخولاً جديداً (إعادةُ محاولة، تجديد). */
export const LOGIN_REPEAT_WINDOW_MS = 30 * 60 * 1000;

export type LoginStats = { loginCount: number; lastLoginAt: string };

function count(value: unknown): number {
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : 0;
}

function time(value: unknown): number {
  if (typeof value !== "string" || !value) return NaN;
  return Date.parse(value);
}

/** ما يُكتب بعد دخولٍ في [now]، أو `null` إن كان تكراراً لدخولٍ قريب. */
export function nextLoginStats(data: Record<string, unknown>, now: Date): LoginStats | null {
  const last = time(data.lastLoginAt);
  if (Number.isFinite(last) && now.getTime() - last >= 0 && now.getTime() - last < LOGIN_REPEAT_WINDOW_MS) {
    return null;
  }
  return { loginCount: count(data.loginCount) + 1, lastLoginAt: now.toISOString() };
}

/** حقلا الدخول بعد حفظٍ من الويب: الأكبرُ عدّاً والأحدثُ وقتاً من النسختين. */
export function keepLoginStats(
  stored: Record<string, unknown> | undefined,
  incoming: Record<string, unknown>,
): Partial<LoginStats> {
  const out: Partial<LoginStats> = {};
  const loginCount = Math.max(count(stored?.loginCount), count(incoming.loginCount));
  if (loginCount > 0) out.loginCount = loginCount;
  const storedAt = time(stored?.lastLoginAt);
  const incomingAt = time(incoming.lastLoginAt);
  const latest = [storedAt, incomingAt].filter(Number.isFinite).sort((a, b) => b - a)[0];
  if (latest !== undefined) {
    out.lastLoginAt = latest === storedAt ? String(stored?.lastLoginAt) : String(incoming.lastLoginAt);
  }
  return out;
}
