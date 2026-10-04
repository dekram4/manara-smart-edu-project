import path from "node:path";

/**
 * مسارُ ملفٍّ داخل مجلدٍ مصرّحٍ به — أو `null`.
 *
 * ── لماذا هنا لا عند كل نداء ──
 * كلُّ قراءةٍ وكتابةٍ وحذفٍ لملفّات الوسائط تبني مسارَها من اسمٍ جاء في طلب. ففحصٌ
 * واحدٌ في المكان الذي يُبنى فيه المسار يحرسها كلَّها، ولا يُنسى عند نداءٍ جديد.
 *
 * يُرفض الاسم إن:
 *   • لم يكن اسماً مجرّداً — فيه `/` أو `\\` أو `..` (`path.basename` يغيّره)؛
 *   • لم يطابق [pattern] — اسمَ الملف المتوقّع لا أيَّ اسم؛
 *   • خرج المسارُ الناتج — بعد `path.resolve` — عن [directory] لأيّ سبب.
 */
export function safeFilePath(
  directory: string,
  fileName: string,
  options: { pattern?: RegExp; suffix?: string } = {},
): string | null {
  if (typeof fileName !== "string" || fileName.length === 0) return null;
  if (fileName.includes("\0")) return null;
  const base = path.basename(fileName);
  if (base !== fileName || base === "." || base === "..") return null;
  if (options.pattern && !options.pattern.test(base)) return null;
  const root = path.resolve(directory);
  const resolved = path.resolve(root, base + (options.suffix ?? ""));
  if (!resolved.startsWith(root + path.sep)) return null;
  return resolved;
}

/** اسمُ ملف فيديو مرفوع: معرّفٌ ثم `.mp4`، لا غير. */
export const VIDEO_FILE_NAME = /^[a-zA-Z0-9-]+\.mp4$/;
