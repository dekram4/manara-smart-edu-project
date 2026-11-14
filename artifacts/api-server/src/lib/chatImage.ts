/**
 * صورُ الدردشة: لوحاتُ «لوحة الألوان السحرية» يرسلها الطالبُ من «لوحاتي».
 *
 * ── كالرسالة الصوتية تماماً ──
 * الصورةُ في صفٍّ وحدها، والرسالةُ تحمل معرّفَها — فقائمةُ الرسائل تبقى خفيفة،
 * والصورةُ تُجلب حين يضغط المستلمُ «شاهد» وحده. وتختفي بعد المشاهدة بالآلية
 * نفسها: إيصالٌ، ثم خروجٌ وعودة، ثم حذفٌ نهائيّ مع صفّ صورتها.
 */

/**
 * أقصى حجمٍ للصورة. التطبيقُ يرسم اللوحةَ PNG بستّمئة نقطة: رسمٌ بخطوطٍ ومساحاتٍ
 * ملوّنة يقارب خمسين إلى مئة وخمسين كيلوبايت. والسقفُ أوسعُ من ذلك، ويمنع أن
 * يصير المسارُ مخزنَ صور.
 */
export const CHAT_IMAGE_MAX_BYTES = 600 * 1024;

/** أصغرُ من هذا ليس صورةً حقيقية. */
export const CHAT_IMAGE_MIN_BYTES = 64;

export type ChatImage =
  | { ok: true; base64: string; bytes: number; mime: string }
  | { ok: false; error: string };

const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;

/** نوعُ الصورة من بايتاتها الأولى، لا مما يدّعيه الطلب. */
export function sniffImage(bytes: Buffer): string | null {
  if (bytes.length < 12) return null;
  if (bytes[0] === 0x89 && bytes.subarray(1, 4).toString("latin1") === "PNG") return "image/png";
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return "image/jpeg";
  if (bytes.subarray(0, 4).toString("latin1") === "RIFF" &&
      bytes.subarray(8, 12).toString("latin1") === "WEBP") return "image/webp";
  return null;
}

/** يفحص صورةً وصلت من التطبيق: ترميزُها وحجمُها ونوعُها. */
export function parseChatImage(image: unknown): ChatImage {
  if (typeof image !== "string") return { ok: false, error: "missing" };
  const clean = image.replace(/^data:[^,]*;base64,/, "").replace(/\s+/g, "");
  if (!clean || clean.length % 4 !== 0 || !BASE64.test(clean)) {
    return { ok: false, error: "encoding" };
  }
  const bytes = Buffer.from(clean, "base64");
  if (bytes.length < CHAT_IMAGE_MIN_BYTES) return { ok: false, error: "tooShort" };
  if (bytes.length > CHAT_IMAGE_MAX_BYTES) return { ok: false, error: "tooBig" };
  const mime = sniffImage(bytes);
  if (!mime) return { ok: false, error: "format" };
  return { ok: true, base64: clean, bytes: bytes.length, mime };
}

/** معرّفُ صفّ الصورة: لا يُخمَّن، ويُعرف من شكله أنه صورة. */
export function isChatImageId(value: unknown): value is string {
  return typeof value === "string" && /^chatimage_[A-Za-z0-9_-]{8,80}$/.test(value);
}

/**
 * مستلمُ رسالةٍ إلى معلّم الصفّ: `teacher:<معرّفه>`. مستلمٌ واحدٌ كأيّ زميل،
 * فتجري عليه دورةُ الحياة نفسها — إيصالُه يُكتب باسمه هذا.
 */
export function teacherRecipient(teacherId: string): string {
  return teacherId ? `teacher:${teacherId}` : "";
}

/**
 * الصورُ واللوحاتُ بين الطلاب وحدهم: الصفُّ كلُّه أو زميلٌ بعينه — لا المعلّم.
 * والنصُّ والصوتُ يصلانه كما كانا.
 */
export function imageRecipientAllowed(recipient: string): boolean {
  return Boolean(recipient) && !recipient.startsWith("teacher:");
}
