/**
 * ألعابُ «عالم الترفيه»: الفهرس، وتنظيفُ ملفّات اللعبة من الإعلانات والروابط.
 *
 * ── كيف تُشغَّل لعبة ──
 * رابطُ GameDistribution العامّ (`html5.gamedistribution.com/<id>/`) صفحةٌ تغلّف
 * اللعبةَ بمكتبة إعلاناتها ثم تفتحها في إطار. فلا يُستعمل: الخادمُ يجلب اللعبةَ نفسها
 * من `/rvvASMiM/<id>/` ويمرّرها عبر `/api/game-embed/<id>/...`، وفي الطريق:
 *   • يستبدل مكتبةَ الإعلانات (`main.min.js`) ببديلٍ صامتٍ يكمل ما تنتظره اللعبة —
 *     انظر [DISABLED_AD_SDK] — بكل صيغ رابطها، في HTML وJS.
 *   • يعطّل `window.open` في الصفحة: «ألعابٌ أخرى» لا تفتح متصفّحاً ولا نافذة.
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

/** شكلُ معرّف لعبة GameDistribution: ٣٢ محرفاً ستّ‌عشرياً صغيراً، لا غير. */
export const GAME_ID_PATTERN = /^[a-f0-9]{32}$/;

/**
 * المعرّفُ من القائمة البيضاء نفسها — أو `null`.
 *
 * يُعاد الثابتُ المخزَّن في GAME_IDS لا القيمةُ الواردة في الطلب: فكلُّ ما يُبنى
 * بعدها (رابطُ المصدر، وrewriteGameHtml) يأخذ معرّفاً من الكود لا من الطالب.
 */
export function resolveGameId(value: unknown): string | null {
  if (typeof value !== "string" || !GAME_ID_PATTERN.test(value)) return null;
  for (const id of GAME_IDS) {
    if (id === value) return id;
  }
  return null;
}

/**
 * مسارُ ملفٍّ داخل لعبة: مقاطعُ من حروفٍ وأرقامٍ و`_ . ~ -` يفصلها `/` — وكلُّ ما
 * تطلبه الألعابُ الستّ (٦٩ ملفاً) على هذا الشكل. ولا مقطعَ `.` أو `..`.
 */
const GAME_ASSET_PATH_PATTERN = /^[A-Za-z0-9_.~-]+(?:\/[A-Za-z0-9_.~-]+)*$/;

export function isSafeGameAssetPath(value: unknown): value is string {
  if (typeof value !== "string" || value.length > 300) return false;
  if (!GAME_ASSET_PATH_PATTERN.test(value)) return false;
  return value.split("/").every((segment) => segment !== "." && segment !== "..");
}

/**
 * الألعابُ التي كانت تعمل قبل إضافة الأربع: تُقدَّم كما كانت حرفياً — صفحتُها بلا
 * تعديل، وبديلُ الإعلانات الأصلي، واستبدالُ رابط المكتبة بصيغة https وحدها.
 * والمعالجةُ الجديدة للألعاب الأربع وحدها.
 */
export const LEGACY_GAME_IDS = new Set<string>([
  "d4a3629101574bc39bd8f9d1888ca58e",
  "172e0bd0c40442dbae3d4adb42a98433",
  "659090e00bfc4650899550d63f8a130d",
  "be797a3996324c03b20bad496a82819f",
  "19c63777ed1e4653b64b2200560907fd",
  "72d861a52f3c4e788ae0421649633be3",
]);

/** بديلُ الإعلانات الأصلي، كما كان للألعاب القديمة. */
export const LEGACY_AD_SDK = `
  (() => {
    const safeResult = Promise.resolve({ args: { success: false } });
    window.gdsdk = window.gdsdk || {
      showAd: () => safeResult,
      preloadAd: () => Promise.resolve(),
    };
  })();
`;

/**
 * سياسةُ أمان المحتوى لصفحات الألعاب: تمنع حقنَ ما ليس من اللعبة (XSS).
 *
 * ── ولماذا ليست `default-src 'self' 'unsafe-inline' data: blob:` وحدها ──
 * جُرّبت في متصفّحٍ حقيقيّ على الألعاب الستّ: «سباق الفراعنة» يحمّل محرّكه (Phaser)
 * من cdn.jsdelivr.net فيُحجب، وألعابُ Unity الثلاث لا يُترجَم فيها WebAssembly — فلا
 * تعمل أربعٌ من ستّ. وهذه تسمح بالأمرين وحدهما: 'wasm-unsafe-eval' (WebAssembly
 * وحده، لا eval لـ JavaScript) وذلك المضيفَ وحده. وما سواهما مغلق: لا اتصالَ بمضيفٍ
 * خارجيّ، ولا إطارات، ولا كائنات، ولا نماذجَ تُرسل، ولا تبديلَ لأصل الروابط.
 * والستُّ كلُّها تعمل بها بلا مخالفةٍ واحدة.
 */
export const GAME_PAGE_CSP = [
  "default-src 'self'",
  "script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' blob: https://cdn.jsdelivr.net",
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data: blob:",
  "font-src 'self' data:",
  "media-src 'self' data: blob:",
  "connect-src 'self' data: blob:",
  "worker-src 'self' blob:",
  "frame-src 'none'",
  "object-src 'none'",
  "base-uri 'self'",
  "form-action 'none'",
].join("; ");

/** مضيفُ ملفّات اللعبة نفسها، لا صفحةِ الإعلانات المغلِّفة لها. */
export const GAME_HOST = "https://html5.gamedistribution.com/rvvASMiM";

export const AD_SDK_PATH = "/ad-sdk.js";

/**
 * بديلُ مكتبة إعلانات GameDistribution: لا إعلان، واللعبةُ تمضي.
 *
 * ── لماذا لا يكفي «لا شيء» ──
 * اللعبةُ تطلب إعلاناً ثم تنتظر حدثَين: `SDK_GAME_PAUSE` ثم `SDK_GAME_START`، ولا
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

/** صفحةُ لعبةٍ جديدة: المكتبةُ بديلة، والنوافذُ معطّلةٌ قبل أيّ سطرٍ من اللعبة. */
export function rewriteGameHtml(gameId: string, source: string): string {
  const html = replaceAdSdk(gameId, source);
  const injected = NO_POPUPS_SCRIPT;
  const head = html.match(/<head[^>]*>/i);
  if (head && head.index !== undefined) {
    const at = head.index + head[0].length;
    return html.slice(0, at) + injected + html.slice(at);
  }
  return injected + html;
}

/**
 * ملفُّ JS للعبة: المكتبةُ بديلة، ودوالُّ الإعلان في إضافات Construct تعود فوراً.
 *
 * والألعابُ القديمة كما كانت: رابطُ https وحده يُستبدل.
 */
export function rewriteGameScript(gameId: string, source: string): string {
  let rewritten = LEGACY_GAME_IDS.has(gameId)
    ? source.replaceAll(
      "https://html5.api.gamedistribution.com/main.min.js",
      `/api/game-embed/${gameId}${AD_SDK_PATH}`,
    )
    : replaceAdSdk(gameId, source);

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
