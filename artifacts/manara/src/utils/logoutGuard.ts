import { readSessionValue, removeSessionValue, writeSessionValue } from './sessionPersistence';

/**
 * خروجٌ صريح لا تفتح بعده أيُّ لوحةٍ إلا بكلمة مرور.
 *
 * ── لماذا ──
 * الخروجُ يمحو كعكاتِ الأدوار بطلبٍ إلى الخادم، والواجهةُ كانت تنتظره أربع
 * ثوانٍ ثم تمضي. فإن أبطأ الخادمُ أو انقطعت الشبكة بقيت كعكةُ المشرف في
 * المتصفّح، وفتحت لمسةُ «مشرف» لوحتَه بلا كلمة مرور. فهذه العلامةُ تُكتب عند
 * الخروج، وما دامت قائمةً لا تستعيد لوحةٌ جلسةً قديمة: تُعيد طلبَ الخروج من
 * الخادم ثم تعرض شاشةَ الدخول. ولا يمحوها إلا دخولٌ ناجح بكلمة مرور.
 */
const LOGGED_OUT_KEY = 'smartEdu_loggedOut';

export function markLoggedOut(): void {
  writeSessionValue(LOGGED_OUT_KEY, '1');
}

export function isLoggedOut(): boolean {
  return readSessionValue(LOGGED_OUT_KEY) === '1';
}

/** بعد دخولٍ ناجح بكلمة مرور. */
export function clearLoggedOut(): void {
  removeSessionValue(LOGGED_OUT_KEY);
}

/**
 * يمحو كلَّ ردٍّ من `/api/` حفظه عاملُ الخدمة (PWA) القديم في ذاكرة المتصفّح:
 * جلسةَ المشرف وجداولَ الحساب ورسائلَه. العاملُ الجديد لا يحفظها، وهذا يطهّر
 * ما حفظه القديم قبل أن يُستبدل. لا يرمي أبداً.
 */
export async function purgeApiCache(): Promise<void> {
  try {
    if (typeof caches === 'undefined') return;
    for (const name of await caches.keys()) {
      const cache = await caches.open(name);
      for (const request of await cache.keys()) {
        if (new URL(request.url).pathname.startsWith('/api/')) await cache.delete(request);
      }
    }
  } catch {
    // ذاكرةٌ محجوبة (تصفّحٌ خاص): لا شيء فيها يُمحى.
  }
}

/** يمحو كعكاتِ الأدوار الثلاثة من الخادم؛ `true` إن أكّد الخادمُ ذلك. */
export async function endServerSession(timeoutMs = 8000): Promise<boolean> {
  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch('/api/auth/logout', {
      method: 'POST',
      credentials: 'same-origin',
      cache: 'no-store',
      signal: controller.signal,
    });
    return response.ok;
  } catch {
    return false;
  } finally {
    window.clearTimeout(timeout);
  }
}
