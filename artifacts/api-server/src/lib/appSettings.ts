/**
 * إعداداتُ المنصّة التي يغيّرها المشرف بلا تعديل كود — أوّلُها رابطُ تحميل
 * تطبيق الطالب (APK) الذي يظهر زرُّه في شاشة اختيار الأدوار.
 *
 * ── لماذا في الخادم لا في المتصفّح ──
 * «إعدادات النظام» في لوحة المشرف تحفظ في `localStorage`: لكل متصفّحٍ
 * نسختُه، فرابطٌ يضعه المشرف في جهازه لا يراه زائرُ شاشة الأدوار في جهازٍ
 * آخر. فالرابطُ يُحفظ في `app_kv` في Supabase، ويقرؤه الجميع من الخادم.
 */

/** مفتاحُ الرابط في `app_kv`. */
export const STUDENT_APK_KEY = "smartEdu_studentApkUrl";

/**
 * الرابطُ الافتراضي: ملفُّ الـAPK نفسه في آخر GitHub Release.
 *
 * ── لماذا `latest/download` لا رقمُ الإصدار ──
 * GitHub يحوّل هذا العنوان إلى ملفّ آخر إصدارٍ منشور، فيبقى الرابطُ صالحاً
 * مع كل إصدارٍ جديد (v1.0.1 وما بعده) بلا تعديلٍ هنا ولا في لوحة المشرف.
 * وهو تنزيلٌ مباشرٌ لملفّ `.apk` للجميع بلا تسجيل دخول — بخلاف رابط
 * GitHub Actions المؤقّت الذي سبقه (يتطلّب الدخول ويصل ملفَّ zip).
 * ويبقى للمشرف أن يضع غيره من لوحته.
 */
export const DEFAULT_STUDENT_APK_URL =
  "https://github.com/dekram4/manara-smart-edu-project/releases/latest/download/manara-student.apk";

/** أطولُ رابطٍ يُقبل. */
export const MAX_APK_URL_LENGTH = 2048;

/**
 * الرابطُ صالحاً للحفظ، أو `null`.
 *
 * `https` وحده (و`http` لعنوانٍ محلّيٍّ في التطوير): الرابطُ يُفتح من
 * شاشةٍ عامّة لكل زائر، فلا يُقبل `javascript:` ولا `data:` ولا ما يشبهها —
 * رابطٌ من هذه يصير شيفرةً تُنفَّذ في متصفّح كلّ من يضغط الزرّ.
 */
export function normalizeApkUrl(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const value = raw.trim();
  if (!value || value.length > MAX_APK_URL_LENGTH) return null;
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    return null;
  }
  const local = parsed.hostname === "localhost" || parsed.hostname === "127.0.0.1";
  if (parsed.protocol !== "https:" && !(local && parsed.protocol === "http:")) return null;
  if (parsed.username || parsed.password) return null;
  return parsed.toString();
}

/** القيمةُ المحفوظة في `app_kv`. */
export interface StudentApkSetting {
  url: string;
  updatedAt: string;
}

/** يقرأ القيمةَ المحفوظة، أو `null` لما لا يصلح. */
export function parseStudentApkSetting(raw: unknown): StudentApkSetting | null {
  const record = raw && typeof raw === "object" ? (raw as Record<string, unknown>) : null;
  const url = normalizeApkUrl(record ? record.url : raw);
  if (!url) return null;
  const updatedAt = record && typeof record.updatedAt === "string" ? record.updatedAt : "";
  return { url, updatedAt };
}
