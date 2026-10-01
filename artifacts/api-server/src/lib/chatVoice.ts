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
  | { ok: true; base64: string; bytes: number; durationMs: number; mime: string }
  | { ok: false; error: string };

const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;

/**
 * نوعُ الصوت من بايتاته الأولى، لا مما يدّعيه الطلب.
 *
 * المسجّلُ في التطبيق يكتب m4a (حاويةُ MPEG-4). لكنّ بعضَ أجهزة أندرويد تكتب
 * AAC خاماً (ADTS) بلا حاوية، ومشغّلاتٌ أخرى تكتب mp3 أو ogg أو wav أو webm.
 * فكلُّها تُقبل وتُحفظ بنوعها، ويُرجَع المقطعُ به فيعرف المشغّلُ كيف يقرؤه.
 * وما ليس صوتاً معروفاً يُرفض: لا يُرفع عبر الدردشة ملفٌّ يُقدَّم لزملاء الصفّ
 * على أنه صوت.
 */
export function sniffAudio(bytes: Buffer): string | null {
  if (bytes.length < 12) return null;
  const ascii = (from: number, to: number) => bytes.subarray(from, to).toString("latin1");
  if (ascii(4, 8) === "ftyp") return "audio/mp4";
  if (ascii(0, 4) === "OggS") return "audio/ogg";
  if (ascii(0, 4) === "RIFF" && ascii(8, 12) === "WAVE") return "audio/wav";
  if (bytes[0] === 0x1a && bytes[1] === 0x45 && bytes[2] === 0xdf && bytes[3] === 0xa3) {
    return "audio/webm";
  }
  if (ascii(0, 3) === "ID3") return "audio/mpeg";
  if (bytes[0] === 0xff && (bytes[1] & 0xf0) === 0xf0 && (bytes[1] & 0x06) === 0) {
    // ADTS: طبقةٌ صفرٌ تعني AAC.
    return "audio/aac";
  }
  if (bytes[0] === 0xff && (bytes[1] & 0xe0) === 0xe0) return "audio/mpeg";
  return null;
}

/** يفحص مقطعاً وصل من التطبيق: ترميزُه وحجمُه ونوعُه. */
export function parseChatVoice(audio: unknown, durationMs: unknown): ChatVoiceNote {
  if (typeof audio !== "string") return { ok: false, error: "missing" };
  // و«data:audio/mp4;base64,...» تُقبل أيضاً: يكتبها بعضُ العملاء هكذا.
  const clean = audio.replace(/^data:[^,]*;base64,/, "").replace(/\s+/g, "");
  if (!clean || clean.length % 4 !== 0 || !BASE64.test(clean)) {
    return { ok: false, error: "encoding" };
  }
  const bytes = Buffer.from(clean, "base64");
  if (bytes.length < CHAT_VOICE_MIN_BYTES) return { ok: false, error: "tooShort" };
  if (bytes.length > CHAT_VOICE_MAX_BYTES) return { ok: false, error: "tooBig" };
  const mime = sniffAudio(bytes);
  if (!mime) return { ok: false, error: "format" };
  const ms = Number(durationMs);
  const duration = Number.isFinite(ms)
    ? Math.round(Math.min(Math.max(ms, 0), CHAT_VOICE_MAX_MS))
    : 0;
  return { ok: true, base64: clean, bytes: bytes.length, durationMs: duration, mime };
}

/** معرّفُ صفّ المقطع: لا يُخمَّن، ويُعرف من شكله أنه مقطع. */
export function isChatVoiceId(value: unknown): value is string {
  return typeof value === "string" && /^chatvoice_[A-Za-z0-9_-]{8,80}$/.test(value);
}
