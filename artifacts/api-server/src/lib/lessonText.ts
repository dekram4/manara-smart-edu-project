/**
 * نصُّ الدرس كما يُرسل إلى Gemini: كاملاً.
 *
 * ── ما كان ──
 * كلُّ مولّدٍ كان يقطع النصَّ عند حدٍّ رآه كافياً: ٦٠٠٠ حرفٍ للتحدي والمذاكرة،
 * و٧٠٠٠ لبنك الجولات، و١٠٠٠٠ لألعاب المذاكرة، و١٢٠٠٠ للاختبارات. فالدرسُ
 * الطويل — أو الوحدةُ التي تُجمع دروسُها لاختبارٍ شامل — كانت تُسأل عن أوّلها
 * وحده، وآخرُها لا يصله سؤالٌ أبداً.
 *
 * ── ما صار ──
 * النصُّ كلُّه، مصدرٌ واحدٌ لكل المولّدات. والسياقُ في نماذج Gemini يتّسع لأضعاف
 * أطول وحدة. وما بقي حدٌّ للأمان وحده ([LESSON_TEXT_SAFETY_LIMIT]): نصٌّ أطولُ منه
 * ليس درساً بل خطأُ لصقٍ أو إساءة، فلا يُرسل كلُّه على حساب الخدمة.
 */

/** حدُّ الأمان: نحو ٦٠ ألف رمز — أضعافُ أطول وحدةٍ في المناهج. */
export const LESSON_TEXT_SAFETY_LIMIT = 200_000;

/**
 * النصُّ كاملاً بعد تسوية الأسطر وحدها. ويُقطع عند آخر نهاية جملةٍ قبل حدّ
 * الأمان إن تجاوزه — لا وسط كلمة.
 */
export function fullLessonText(value: unknown, limit = LESSON_TEXT_SAFETY_LIMIT): string {
  const clean = String(value ?? "")
    .replace(/\r\n?/g, "\n")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
  if (clean.length <= limit) return clean;
  const cut = clean.slice(0, limit);
  const end = Math.max(cut.lastIndexOf("."), cut.lastIndexOf("۔"), cut.lastIndexOf("؟"), cut.lastIndexOf("\n"));
  return (end > limit * 0.9 ? cut.slice(0, end + 1) : cut).trim();
}
