/**
 * رابطُ لعبةٍ في نموذج «الترفيه والألعاب»: ما يقبله الخادم، قبل الإرسال.
 *
 * ── لماذا لا `type="url"` ──
 * المتصفّحُ يرفض فيه كلَّ ما ليس رابطاً مطلقاً، فكان مسارُ وكيل الألعاب
 * (`/api/game-embed/<المعرّف>/index.html`) — وهو الصيغةُ التي تُحفظ بها كلُّ
 * لعبةٍ من GameDistribution — يُردّ قبل أن يصل. ولا تُضاف اللعبة، ولا يُحفظ
 * أيُّ تعديلٍ على لعبةٍ محفوظةٍ به أصلاً.
 *
 * والقاعدةُ نفسُها في الخادم (`isSafeGameUrl`)، وهو الحَكَم: هذا يقول للمشرف
 * السببَ قبل الإرسال فقط.
 */
const PROXY_PATH = /^\/?api\/game-embed\/[a-f0-9]{32}(?:\/(?:index\.html)?)?$/i;

export const GAME_URL_HINT =
  'رابطٌ كامل يبدأ بـ https:// أو مسارُ لعبةٍ مثل /api/game-embed/a9afce108d824d6f838218dd87aa2ef4/index.html';

/** سببُ رفض الرابط، أو `null` إن كان مقبولاً. */
export function gameUrlProblem(value: string): string | null {
  const url = value.trim();
  if (!url) return 'رابط اللعبة مطلوب';
  if (/\s/.test(url)) return 'رابط اللعبة لا يحتوي مسافات';
  if (PROXY_PATH.test(url)) return null;
  if (/^\/?api\/game-embed\//i.test(url)) {
    return 'مسارُ اللعبة غير صحيح: يجب أن يكون /api/game-embed/ ثم معرّفاً من 32 حرفاً ثم /index.html';
  }
  try {
    const parsed = new URL(url);
    if ((parsed.protocol === 'https:' || parsed.protocol === 'http:') && parsed.hostname) return null;
  } catch {
    // يُكمل إلى الرسالة العامّة.
  }
  return `رابط اللعبة غير صالح: ${GAME_URL_HINT}`;
}
