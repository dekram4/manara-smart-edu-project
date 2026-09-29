/**
 * من يُسمح له بقراءة ردود هذا الخادم من متصفّح.
 *
 * ── لماذا وحدةٌ مستقلّة ──
 * كان القرارُ سطرين داخل إعداد `cors` في `app.ts`، ولا يُختبر: اختبارُه
 * يحتاج خادماً يُشغَّل وطلباً يُرسَل بترويسة. فبقي خمسةَ أشهر يردّ أصلَ
 * النشر نفسه بلا أن يُلاحظ.
 *
 * وصورةُ الخطأ كانت تُبعد النظرَ عنه: `curl` لا يرسل `Origin` فيمرّ
 * ويعود ٢٠٠، والمتصفّح يرسله فيُردّ ويعود ٥٠٠. فالخادمُ يعمل من الطرفية
 * ويفشل من الشاشة، والواجهةُ تقرأ الردَّ الفاشل «كلمة المرور خاطئة».
 *
 * فصار القرارُ دالّةً نقيّةً عليها اختبار.
 */

/** مضيفُ الأصل، أو `null` إن لم يكن عنواناً صالحاً. */
function hostOf(origin: string): string | null {
  try {
    return new URL(origin).host;
  } catch {
    return null;
  }
}

export interface OriginPolicy {
  /** مضيفُ الطلب نفسه، من ترويسة `Host`. */
  host?: string | undefined;
  /** نطاقُ مساحة العمل، إن كنّا فيها. */
  devDomain?: string | undefined;
  /** نطاقاتُ النشر كما تصل من Replit: مفصولةٌ بفواصل. */
  deployDomains?: string | undefined;
}

/** الأصولُ المسموحة دائماً، للتطوير المحلّي. */
const LOCAL = ["http://localhost", "http://127.0.0.1"];

/**
 * هل يُثق بهذا الأصل؟
 *
 * ── والمضيفُ أوّلاً لا القائمة ──
 * هذا الخادم يخدم واجهةَ الويب وAPIها من أصلٍ واحد: `GET /` صفحةٌ،
 * و`POST /api/...` جسدُ JSON. فطلبُ الصفحة إلى مسارها أصلُه أصلُ الخادم،
 * ولا معنى لأن يُردّ.
 *
 * ومقارنتُه بمضيف الطلب تصحّ على نطاق النشر، ونطاق التطوير، ونطاقٍ
 * مخصَّصٍ يُضاف غداً، وعلى إعادة تسميةٍ للمشروع — بلا أن يُكتب أيٌّ منها
 * في قائمة. وذلك ما أخفق: القائمةُ كانت تحمل نطاقَ التطوير وحده، وهو
 * متغيّرٌ لا يُضبط في النشر.
 */
export function isTrustedOrigin(
  origin: string,
  policy: OriginPolicy = {},
): boolean {
  if (!origin) return false;
  const { host, devDomain, deployDomains } = policy;

  // أصلُ الخادم نفسه.
  if (host && hostOf(origin) === host) return true;

  // والمحلّيُّ بأيّ منفذ: Vite يفتح منافذَ مختلفة.
  if (LOCAL.some((local) => origin === local || origin.startsWith(`${local}:`))) {
    return true;
  }

  // ونطاقُ مساحة العمل، وما تحته من نطاقاتٍ فرعية.
  if (devDomain) {
    if (origin === `https://${devDomain}`) return true;
    if (origin.endsWith(`.${devDomain}`)) return true;
  }

  // ونطاقاتُ النشر التي تُعلنها Replit.
  return (deployDomains ?? "")
    .split(",")
    .map((domain) => domain.trim())
    .filter(Boolean)
    .some((domain) => origin === `https://${domain}`);
}
