/**
 * الرسائلُ الصوتية في دردشة الصفّ: ما يُقبل منها وكيف يُحفظ.
 *
 * ── لماذا المقطعُ في صفٍّ وحده ──
 * قائمةُ الرسائل تُقرأ كلُّها في كل تحديث — مئتان وخمسون صفّاً. ولو حُمل الصوتُ
 * في صفّ الرسالة لصار كلُّ تحديثٍ ميغابايتات لا يُسمع منها شيء. فصفُّ الرسالة
 * يحمل معرّفَ المقطع ومدّتَه، والمقطعُ يُجلب حين يُضغط «تشغيل» وحده.
 */

/** أقصى مدّةٍ للتسجيل: جملةٌ أو جملتان، لا محاضرة. */
export const CHAT_VOICE_MAX_MS = 30_000;

/**
 * أقصى حجمٍ للمقطع.
 *
 * التطبيقُ يرمّز AAC على ١٦ كيلوبت/ث بقناةٍ واحدة: ثلاثون ثانيةً ≈ ستون
 * كيلوبايت. فالسقفُ أوسعُ من الحاجة بضعفين، ويمنع أن يصير المسارُ مخزنَ ملفّات.
 */
export const CHAT_VOICE_MAX_BYTES = 160 * 1024;

/** أصغرُ من هذا ضغطةٌ عابرة، لا كلام. */
export const CHAT_VOICE_MIN_BYTES = 512;

export type ChatVoiceNote =
  | { ok: true; base64: string; bytes: number; durationMs: number }
  | { ok: false; error: string };

const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;

/**
 * يفحص مقطعاً وصل من التطبيق.
 *
 * ولا يُقبل إلا حاويةُ MPEG-4 (`ftyp` في البايت الرابع) — وهي ما يكتبه المسجّل.
 * فلا يُرفع عبر الدردشة ملفٌّ آخرُ يُقدَّم لزملاء الصفّ على أنه صوت.
 */
export function parseChatVoice(audio: unknown, durationMs: unknown): ChatVoiceNote {
  if (typeof audio !== "string") return { ok: false, error: "missing" };
  const clean = audio.replace(/\s+/g, "");
  if (!clean || clean.length % 4 !== 0 || !BASE64.test(clean)) {
    return { ok: false, error: "encoding" };
  }
  const bytes = Buffer.from(clean, "base64");
  if (bytes.length < CHAT_VOICE_MIN_BYTES) return { ok: false, error: "tooShort" };
  if (bytes.length > CHAT_VOICE_MAX_BYTES) return { ok: false, error: "tooBig" };
  if (bytes.subarray(4, 8).toString("latin1") !== "ftyp") {
    return { ok: false, error: "format" };
  }
  const ms = Number(durationMs);
  const duration = Number.isFinite(ms)
    ? Math.round(Math.min(Math.max(ms, 0), CHAT_VOICE_MAX_MS))
    : 0;
  return { ok: true, base64: clean, bytes: bytes.length, durationMs: duration };
}

/** معرّفُ صفّ المقطع: لا يُخمَّن، ويُعرف من شكله أنه مقطع. */
export function isChatVoiceId(value: unknown): value is string {
  return typeof value === "string" && /^chatvoice_[A-Za-z0-9_-]{8,80}$/.test(value);
}
