/**
 * «لوحاتي في السحابة»: لوحاتُ «لوحة الألوان السحرية» يحفظها الطالبُ على الخادم
 * فتصحبه إلى أيّ جهاز.
 *
 * ── ما يُحفظ ──
 * صورةٌ مضغوطةٌ على جهاز الطالب (PNG أو JPEG بضلع ٥١٢) للعرض، وخطواتُ اللوحة
 * (JSON مضغوطاً بـ gzip ثم base64) لتُفتح وتُكمَل. كلاهما بسقف، وللطالب عددٌ
 * أقصى من اللوحات — فلا يصير المسارُ مخزنَ ملفّات.
 */

import { parseChatImage, type ChatImage } from "./chatImage";

/** أقصى عددٍ من اللوحات السحابية لكل طالب. */
export const ARTWORK_MAX_PER_STUDENT = 30;

/** أقصى حجمٍ لصورة اللوحة بعد الضغط على الجهاز. */
export const ARTWORK_IMAGE_MAX_BYTES = 300 * 1024;

/** أقصى طولٍ لخطوات اللوحة (base64 لـ gzip). */
export const ARTWORK_DOC_MAX_CHARS = 400 * 1024;

const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;

/** معرّفُ صفّ اللوحة: لا يُخمَّن، ويُعرف من شكله. */
export function isArtworkId(value: unknown): value is string {
  return typeof value === "string" && /^artwork_[A-Za-z0-9_-]{8,80}$/.test(value);
}

export function artworkTitle(value: unknown): string {
  const title = typeof value === "string" ? value.trim().replace(/\s+/g, " ") : "";
  return title.slice(0, 60) || "لوحتي";
}

/** صورةُ اللوحة: صورةٌ حقيقيةٌ بسقف اللوحات (أصغرُ من سقف الدردشة). */
export function parseArtworkImage(value: unknown): ChatImage {
  const image = parseChatImage(value);
  if (image.ok && image.bytes > ARTWORK_IMAGE_MAX_BYTES) return { ok: false, error: "tooBig" };
  return image;
}

/** خطواتُ اللوحة: base64 لبايتاتٍ تبدأ بتوقيع gzip، بسقف. فارغةٌ مقبولة. */
export function parseArtworkDoc(value: unknown): { ok: true; doc: string } | { ok: false; error: string } {
  if (value === undefined || value === null || value === "") return { ok: true, doc: "" };
  if (typeof value !== "string") return { ok: false, error: "doc" };
  const clean = value.replace(/\s+/g, "");
  if (clean.length > ARTWORK_DOC_MAX_CHARS) return { ok: false, error: "docTooBig" };
  if (clean.length % 4 !== 0 || !BASE64.test(clean)) return { ok: false, error: "doc" };
  const head = Buffer.from(clean.slice(0, 8), "base64");
  if (head[0] !== 0x1f || head[1] !== 0x8b) return { ok: false, error: "doc" };
  return { ok: true, doc: clean };
}
