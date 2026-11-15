import { gunzipSync } from "node:zlib";

/**
 * الملفاتُ والمستندات في الدردشة: PDF، ووورد، وإكسل، وبوربوينت، ونصوص، وصور.
 *
 * ── كالصورة والمقطع ──
 * الملفُّ في صفٍّ وحده، والرسالةُ تحمل معرّفَه واسمَه وحجمَه — فقائمةُ الرسائل
 * تبقى خفيفة، والملفُّ يُجلب حين يُضغط «فتح» وحده، ويختفي بعد المشاهدة بالآلية
 * نفسها.
 *
 * ── والضغط ──
 * التطبيقُ يضغط الملفَّ (gzip) قبل رفعه إن صغُر به — النصوصُ والمستنداتُ القديمة
 * تصغر كثيراً. فيُفكّ هنا ليُفحص نوعُه وحجمُه الحقيقيّ، ويُخزَّن مضغوطاً كما وصل،
 * ويُفكّ عند التنزيل.
 *
 * ── وما يُقبل ──
 * النوعُ من بايتاته الأولى لا من اسمه: ملفٌّ تنفيذيٌّ سُمّي «درس.pdf» يُرفض.
 */

/** أقصى حجمٍ للملفّ بعد فكّه. */
export const CHAT_FILE_MAX_BYTES = 1_500 * 1024;

/** أقصى ما يُخزَّن (مضغوطاً أو لا). */
export const CHAT_FILE_MAX_STORED_BYTES = 1_100 * 1024;

export const CHAT_FILE_MIN_BYTES = 1;

export type ChatFile =
  | { ok: true; base64: string; gzip: boolean; bytes: number; mime: string; name: string }
  | { ok: false; error: string };

const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;

/** امتداداتُ حاويةِ ZIP المقبولة: مستنداتُ أوفيس الحديثة وOpenDocument. */
const ZIP_TYPES: Record<string, string> = {
  docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  pptx: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  odt: "application/vnd.oasis.opendocument.text",
  ods: "application/vnd.oasis.opendocument.spreadsheet",
  odp: "application/vnd.oasis.opendocument.presentation",
};

/** أوفيس القديم (حاوية OLE). */
const OLE_TYPES: Record<string, string> = {
  doc: "application/msword",
  xls: "application/vnd.ms-excel",
  ppt: "application/vnd.ms-powerpoint",
};

const TEXT_TYPES: Record<string, string> = {
  txt: "text/plain",
  csv: "text/csv",
  md: "text/markdown",
  json: "application/json",
};

function extensionOf(name: string): string {
  const dot = name.lastIndexOf(".");
  return dot < 0 ? "" : name.slice(dot + 1).toLowerCase();
}

/** نصٌّ حقيقيّ: UTF-8 صالح بلا بايتاتٍ صفرية. */
function looksLikeText(bytes: Buffer): boolean {
  const sample = bytes.subarray(0, 64 * 1024);
  if (sample.includes(0)) return false;
  try {
    new TextDecoder("utf-8", { fatal: true }).decode(sample.length === bytes.length ? sample : bytes);
    return true;
  } catch {
    return false;
  }
}

/** نوعُ الملفّ من بايتاته، وامتدادُه يفرّق بين أنواع الحاوية الواحدة. */
export function sniffFile(bytes: Buffer, name: string): string | null {
  if (bytes.length === 0) return null;
  const ext = extensionOf(name);
  const ascii = (from: number, to: number) => bytes.subarray(from, to).toString("latin1");
  if (ascii(0, 5) === "%PDF-") return "application/pdf";
  if (bytes[0] === 0x89 && ascii(1, 4) === "PNG") return "image/png";
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return "image/jpeg";
  if (ascii(0, 4) === "RIFF" && ascii(8, 12) === "WEBP") return "image/webp";
  if (ascii(0, 4) === "GIF8") return "image/gif";
  if (ascii(0, 4) === "PK\u0003\u0004") return ZIP_TYPES[ext] ?? null;
  if (bytes[0] === 0xd0 && bytes[1] === 0xcf && bytes[2] === 0x11 && bytes[3] === 0xe0) return OLE_TYPES[ext] ?? null;
  if (ascii(0, 5) === "{\\rtf") return "application/rtf";
  if (TEXT_TYPES[ext] && looksLikeText(bytes)) return TEXT_TYPES[ext];
  return null;
}

/** اسمٌ يُعرض ويُنزَّل به: بلا مسارٍ ولا محارفِ تحكّم، وبطولٍ معقول. */
export function cleanFileName(value: unknown): string {
  const raw = typeof value === "string" ? value : "";
  const base = raw.split(/[\\/]/).pop() ?? "";
  // eslint-disable-next-line no-control-regex
  const safe = base.replace(/[\u0000-\u001f\u007f"<>|*?:]/g, "").trim().slice(0, 120);
  return safe || "ملف";
}

/** يفحص ملفاً وصل من التطبيق أو البوابة: ترميزُه، وضغطُه، وحجمُه، ونوعُه. */
export function parseChatFile(file: unknown, name: unknown, gzip: unknown): ChatFile {
  if (typeof file !== "string") return { ok: false, error: "missing" };
  const clean = file.replace(/^data:[^,]*;base64,/, "").replace(/\s+/g, "");
  if (!clean || clean.length % 4 !== 0 || !BASE64.test(clean)) {
    return { ok: false, error: "encoding" };
  }
  const stored = Buffer.from(clean, "base64");
  if (stored.length > CHAT_FILE_MAX_STORED_BYTES) return { ok: false, error: "tooBig" };
  const compressed = gzip === true;
  let bytes: Buffer;
  if (compressed) {
    try {
      bytes = gunzipSync(stored, { maxOutputLength: CHAT_FILE_MAX_BYTES + 1 });
    } catch (error) {
      const tooBig = String((error as { code?: string }).code ?? "").includes("BUFFER") ||
        /output length/i.test(String(error));
      return { ok: false, error: tooBig ? "tooBig" : "encoding" };
    }
  } else {
    bytes = stored;
  }
  if (bytes.length < CHAT_FILE_MIN_BYTES) return { ok: false, error: "tooShort" };
  if (bytes.length > CHAT_FILE_MAX_BYTES) return { ok: false, error: "tooBig" };
  const fileName = cleanFileName(name);
  const mime = sniffFile(bytes, fileName);
  if (!mime) return { ok: false, error: "format" };
  return { ok: true, base64: clean, gzip: compressed, bytes: bytes.length, mime, name: fileName };
}

/** يُرجع بايتاتِ الملفّ كما أُرسل من صفّه المخزَّن. */
export function storedFileBytes(data: Record<string, unknown>): Buffer {
  const raw = Buffer.from(String(data.file ?? ""), "base64");
  return data.gzip === true ? gunzipSync(raw) : raw;
}

/** معرّفُ صفّ الملفّ. */
export function isChatFileId(value: unknown): value is string {
  return typeof value === "string" && /^chatfile_[A-Za-z0-9_-]{8,80}$/.test(value);
}
