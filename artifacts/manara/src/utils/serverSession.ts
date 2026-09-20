/**
 * جلسة الخادم: ما يجعل حفظ المعلم يصل إلى قاعدة البيانات.
 *
 * تسجيل الدخول في اللوحة يقع على نسخة المتصفح من جدول المعلمين، فينجح بلا
 * أي اتصال بالخادم. والخادم لا يعرف من يكتب إلا من كعكة الجلسة
 * (`manara_teacher_session`)، فبدونها يردّ كل حفظ بـ 401: «يجب تسجيل
 * الدخول كمعلم أو مشرف لمزامنة البيانات» — والمعلم يرى نفسه داخلاً، ويرى
 * تعديلاته أمامه، ولا يصل منها شيء.
 *
 * لذلك تُطلب الجلسة عند كل دخول، ويُعلَن فشلها بدل أن يُكتب في الطرفية.
 */

export type SessionResult = { ok: true } | { ok: false; reason: string };

async function post(url: string, body: unknown): Promise<SessionResult> {
  try {
    const response = await fetch(url, {
      method: 'POST',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      return { ok: false, reason: payload?.error || `رفض الخادم الطلب (${response.status})` };
    }
    return { ok: true };
  } catch (error) {
    return {
      ok: false,
      reason: error instanceof Error ? error.message : 'تعذّر الاتصال بالخادم',
    };
  }
}

/** يفتح جلسة معلم على الخادم باسم المستخدم وكلمة المرور. */
export function openTeacherSession(username: string, password: string): Promise<SessionResult> {
  return post('/api/auth/teacher/session', { username, password });
}

/** هل للمتصفح جلسة معلم صالحة على الخادم الآن؟ */
export async function hasTeacherSession(): Promise<boolean> {
  try {
    const response = await fetch('/api/supabase/context', { credentials: 'same-origin' });
    if (!response.ok) return false;
    const payload = await response.json().catch(() => ({}));
    return payload?.role === 'teacher' || payload?.role === 'admin';
  } catch {
    return false;
  }
}

/**
 * يطلب كلمة المرور ويفتح الجلسة من جديد، دون تسجيل خروج.
 *
 * الكعكة تعيش اثنتي عشرة ساعة وجلسة المعلم قد تطول، فانتهاؤها في منتصف
 * العمل كان يحوّل كل حفظ لاحق إلى رفض صامت.
 */
export async function reopenTeacherSession(username: string): Promise<SessionResult> {
  const password = window.prompt(
    `لإعادة فتح جلسة الحفظ على الخادم، أدخل كلمة مرور الحساب «${username}»:`,
  );
  if (password == null || password === '') {
    return { ok: false, reason: 'أُلغي إدخال كلمة المرور' };
  }
  return openTeacherSession(username, password);
}
