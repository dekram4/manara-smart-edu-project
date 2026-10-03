/**
 * ألعابُ «عالم الترفيه»: الفهرس، وتنظيفُ ملفّات اللعبة من الإعلانات والروابط.
 *
 * ── كيف تُشغَّل لعبة ──
 * رابطُ GameDistribution العامّ (\`html5.gamedistribution.com/<id>/\`) صفحةٌ تغلّف
 * اللعبةَ بمكتبة إعلاناتها ثم تفتحها في إطار. فلا يُستعمل: الخادمُ يجلب اللعبةَ نفسها
 * من \`/rvvASMiM/<id>/\` ويمرّرها عبر \`/api/game-embed/<id>/...\`، وفي الطريق:
 *   • يستبدل مكتبةَ الإعلانات (\`main.min.js\`) ببديلٍ صامتٍ يكمل ما تنتظره اللعبة —
 *     انظر [DISABLED_AD_SDK] — بكل صيغ رابطها، في HTML وJS.
 *   • يعطّل \`window.open\` في الصفحة: «ألعابٌ أخرى» لا تفتح متصفّحاً ولا نافذة.
 */

export type GameOrientation = "landscape" | "portrait" | "any";

export interface CatalogGame {
  id: string;
  title: string;
  subtitle: string;
  /** اتجاهُ الشاشة الذي صُمّمت له اللعبة: يُقفل عليه الجهازُ ما دامت مفتوحة. */
  orientation: GameOrientation;
  /** أبعادُ اللعبة الأصلية — منها نسبةُ العرض إلى الارتفاع. */
  width: number | null;
  height: number | null;
}

/** الألعاب بترتيبها: الترتيبُ هو مستوى الفتح (الأولى عند المستوى 1، وهكذا). */
export const GAME_CATALOG: readonly CatalogGame[] = [
  {
    id: "d4a3629101574bc39bd8f9d1888ca58e",
    title: "صراع الأذكياء",
    subtitle: "من يحسم المعركة بعقله أولاً؟",
    orientation: "any",
    width: null,
    height: null,
  },
  {
    id: "172e0bd0c40442dbae3d4adb42a98433",
    title: "عاصفة المعرفة",
    subtitle: "أسئلة كالبرق… هل تصمد حتى النهاية؟",
    orientation: "any",
    width: null,
    height: null,
  },
  {
    id: "73c29ef316be4f0bb6d149d8b5a39ff3",
    title: "سباق الفراعنة",
    subtitle: "اركض بين المعابد واجمع الجعارين الذهبية!",
    orientation: "landscape",
    width: 1280,
    height: 720,
  },
  {
    id: "99ba036a4225425794e2c423fbcf9842",
    title: "انطلاقة النفق",
    subtitle: "قفزات سريعة وهروب لا يتوقف!",
    orientation: "portrait",
    width: 1080,
    height: 1920,
  },
  {
    id: "d632553ef7264d99aa438310073a6dc3",
    title: "إعصار السرعة",
    subtitle: "سباق شوارع… من يصل أولاً؟",
    orientation: "landscape",
    width: 800,
    height: 600,
  },
  {
    id: "71b64121c58b4a95b7459e08086dcb00",
    title: "الروبوت الخارق",
    subtitle: "سيارة تتحوّل إلى روبوت… انطلق للمعركة!",
    orientation: "landscape",
    width: 960,
    height: 600,
  },
];

/**
 * ما يُسمح بتمريره. ومعه معرّفاتٌ أقدم كانت مسموحةً، كي لا يتعطّل رابطٌ محفوظٌ لها.
 */
export const GAME_IDS = new Set<string>([
  ...GAME_CATALOG.map((game) => game.id),
  "659090e00bfc4650899550d63f8a130d",
  "be797a3996324c03b20bad496a82819f",
  "19c63777ed1e4653b64b2200560907fd",
  "72d861a52f3c4e788ae0421649633be3",
]);

/** مضيفُ ملفّات اللعبة نفسها، لا صفحةِ الإعلانات المغلِّفة لها. */
export const GAME_HOST = "https://html5.gamedistribution.com/rvvASMiM";

export const AD_SDK_PATH = "/ad-sdk.js";

/**
 * بديلُ مكتبة إعلانات GameDistribution: لا إعلان، واللعبةُ تمضي.
 *
 * ── لماذا لا يكفي «لا شيء» ──
 * اللعبةُ تطلب إعلاناً ثم تنتظر حدثَين: \`SDK_GAME_PAUSE\` ثم \`SDK_GAME_START\`، ولا
 * تكمل قبلهما. بديلٌ يعود بلا أحداث يُجمّدها عند أوّل استراحة. فهذا يُطلق الحدثين
 * فوراً كأنّ الإعلانَ انتهى، ويَمنح مكافأةَ «شاهد إعلاناً» بلا إعلان.
 */
export const DISABLED_AD_SDK = `
(() => {
  if (window.gdsdk && window.gdsdk.__manara) return;
  const options = () => window.GD_OPTIONS || {};
  const emit = (name) => {
    try {
      const handler = options().onEvent;
      if (typeof handler === "function") handler({ name, message: name, status: "success" });
    } catch (error) {}
  };
  const AdType = { Interstitial: "interstitial", Rewarded: "rewarded", Display: "display", Midroll: "midroll" };
  const showAd = (type) => new Promise((resolve) => {
    emit("SDK_GAME_PAUSE");
    setTimeout(() => {
      if (type === AdType.Rewarded || type === "rewarded") emit("SDK_REWARDED_WATCH_COMPLETE");
      emit("SDK_GAME_START");
      resolve({ args: { success: true } });
    }, 0);
  });
  window.gdsdk = {
    __manara: true,
    AdType,
    showAd,
    preloadAd: () => Promise.resolve(),
    cancelAd: () => Promise.resolve(),
    showBanner: () => {},
    sendEvent: () => Promise.resolve(),
    openConsole: () => {},
  };
  setTimeout(() => emit("SDK_READY"), 0);
})();
`;

/**
 * يُحقن أوّلَ الصفحة: لا نوافذَ جديدة، ولا انتقالَ للصفحة كلّها إلى موقعٍ آخر.
 */
export const NO_POPUPS_SCRIPT =
  "<script>(function(){try{window.open=function(){return null};}catch(e){}})();</script>";

/** مكتبةُ الإعلانات بكل صيغ رابطها: https:// و http:// و //. */
const AD_SDK_URL = /(?:https?:)?\/\/html5\.api\.gamedistribution\.com\/main\.min\.js/g;

/** يستبدل مكتبةَ الإعلانات ببديلها الصامت. */
export function replaceAdSdk(gameId: string, source: string): string {
  return source.replace(AD_SDK_URL, `/api/game-embed/${gameId}${AD_SDK_PATH}`);
}

/** صفحةُ اللعبة: المكتبةُ بديلةٌ، والنوافذُ معطّلةٌ قبل أيّ سطرٍ من اللعبة. */
export function rewriteGameHtml(gameId: string, source: string): string {
  const html = replaceAdSdk(gameId, source);
  const head = html.match(/<head[^>]*>/i);
  if (head && head.index !== undefined) {
    const at = head.index + head[0].length;
    return html.slice(0, at) + NO_POPUPS_SCRIPT + html.slice(at);
  }
  return NO_POPUPS_SCRIPT + html;
}

/**
 * ملفُّ JS للعبة: المكتبةُ بديلة، ودوالُّ الإعلان في إضافات Construct تعود فوراً.
 */
export function rewriteGameScript(gameId: string, source: string): string {
  let rewritten = replaceAdSdk(gameId, source);

  const replaceMethod = (methodStart: string, methodEnd: string, replacement: string) => {
    const start = rewritten.indexOf(methodStart);
    const end = start === -1 ? -1 : rewritten.indexOf(methodEnd, start);
    if (start === -1 || end === -1) return;
    rewritten = rewritten.slice(0, start) + replacement + rewritten.slice(end + 1);
  };

  replaceMethod(
    "d.prototype.showAd=function(){return gdsdk.showAd()",
    "},d.prototype.showRewardedAd=",
    "d.prototype.showAd=function(){return Promise.resolve(!1)}",
  );
  replaceMethod(
    "e.prototype.showAd=function(){var a,b,c;",
    "},e.prototype.updateSkipAds=",
    "e.prototype.showAd=function(){return Promise.resolve(!0)}",
  );
  return rewritten;
}

/** الفهرسُ كما يُرسل للتطبيق. */
export function catalogJson() {
  return GAME_CATALOG.map((game) => ({
    ...game,
    url: `/api/game-embed/${game.id}/index.html`,
  }));
}
