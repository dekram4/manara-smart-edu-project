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

// ── أزرارُ اللمس فوق اللعبة ──

/** زرٌّ يضغط مفتاحاً: ما دام الإصبعُ عليه فالمفتاحُ مضغوط. */
interface TouchKey {
  label: string;
  key: string;
  code: string;
  keyCode: number;
}

const UP: TouchKey = { label: "⬆", key: "ArrowUp", code: "ArrowUp", keyCode: 38 };
const DOWN: TouchKey = { label: "⬇", key: "ArrowDown", code: "ArrowDown", keyCode: 40 };
const LEFT: TouchKey = { label: "◀", key: "ArrowLeft", code: "ArrowLeft", keyCode: 37 };
const RIGHT: TouchKey = { label: "▶", key: "ArrowRight", code: "ArrowRight", keyCode: 39 };

/**
 * أزرارُ كلِّ لعبة: يسارُ الشاشة للاتجاه، ويمينُها للقفز والانزلاق.
 *
 * ── لماذا ──
 * ألعابُ الجري والسباق تُلعب بالأسهم، والسحبُ عليها باللمس بطيءٌ وصعبٌ على طفل.
 * فزرٌّ كبيرٌ شفّافٌ لكل مفتاح، يرسل للعبة ما يرسله المفتاحُ نفسه.
 */
export const TOUCH_CONTROLS: Record<string, { left: TouchKey[]; right: TouchKey[] }> = {
  // سباق الفراعنة: قفزٌ وانزلاق.
  "73c29ef316be4f0bb6d149d8b5a39ff3": {
    left: [],
    right: [{ ...UP, label: "⬆ قفز" }, { ...DOWN, label: "⬇ انزلاق" }],
  },
  // انطلاقة النفق: مساراتٌ يميناً ويساراً، وقفزٌ وانزلاق.
  "99ba036a4225425794e2c423fbcf9842": {
    left: [LEFT, RIGHT],
    right: [{ ...UP, label: "⬆ قفز" }, { ...DOWN, label: "⬇ انزلاق" }],
  },
  // إعصار السرعة: توجيهٌ، وتسارعٌ وفرامل.
  "d632553ef7264d99aa438310073a6dc3": {
    left: [LEFT, RIGHT],
    right: [{ ...UP, label: "⬆ تسارع" }, { ...DOWN, label: "⬇ فرامل" }],
  },
  // الروبوت الخارق: الأسهمُ الأربعة.
  "71b64121c58b4a95b7459e08086dcb00": {
    left: [LEFT, RIGHT],
    right: [UP, DOWN],
  },
};

/**
 * سكربتُ الأزرار: يُلحق آخرَ الصفحة.
 *
 * كلُّ زرٍّ يرسل `keydown` حين يُلمس و`keyup` حين يُرفع الإصبع — بـ`key` و`code`
 * و`keyCode` معاً: Phaser يقرأ `keyCode` على `window`، وUnity يقرأ `code`. ويُرسل
 * الحدثُ من لوحة اللعبة فيصعد إلى `document` و`window`، فيصل أيَّهما استمعت اللعبة.
 * ولمسُ الزرّ لا يصل اللعبة لمسةً: لا يُحسب سحباً ولا ضغطةً على شيءٍ تحته.
 */
export function touchControlsScript(gameId: string): string {
  const layout = TOUCH_CONTROLS[gameId];
  if (!layout) return "";
  return `<script>(function(){
var L=${JSON.stringify(layout)};
function fire(type,k){
  var ev;try{ev=new KeyboardEvent(type,{key:k.key,code:k.code,bubbles:true,cancelable:true});}
  catch(e){ev=document.createEvent("Event");ev.initEvent(type,true,true);ev.key=k.key;ev.code=k.code;}
  ["keyCode","which"].forEach(function(n){try{Object.defineProperty(ev,n,{get:function(){return k.keyCode;}});}catch(e){}});
  var t=document.querySelector("canvas")||document.body||document;
  t.dispatchEvent(ev);
}
function button(k){
  var b=document.createElement("div");
  b.textContent=k.label;
  b.style.cssText="pointer-events:auto;min-width:72px;height:72px;padding:0 14px;margin:6px;border-radius:36px;"+
    "display:flex;align-items:center;justify-content:center;font:900 18px system-ui,sans-serif;color:#fff;"+
    "background:rgba(20,10,45,.38);border:2px solid rgba(255,255,255,.55);backdrop-filter:blur(2px);"+
    "user-select:none;-webkit-user-select:none;touch-action:none;box-shadow:0 4px 12px rgba(0,0,0,.25);";
  var down=false;
  function press(e){e.preventDefault();e.stopPropagation();if(down)return;down=true;b.style.background="rgba(249,115,22,.7)";fire("keydown",k);}
  function release(e){if(e){e.preventDefault();e.stopPropagation();}if(!down)return;down=false;b.style.background="rgba(20,10,45,.38)";fire("keyup",k);}
  b.addEventListener("pointerdown",function(e){try{b.setPointerCapture(e.pointerId);}catch(_){}press(e);});
  b.addEventListener("pointerup",release);b.addEventListener("pointercancel",release);
  b.addEventListener("lostpointercapture",function(){release();});
  ["touchstart","touchend","mousedown","mouseup","click"].forEach(function(n){b.addEventListener(n,function(e){e.stopPropagation();},{passive:true});});
  return b;
}
function column(keys,side){
  var c=document.createElement("div");
  c.style.cssText="position:fixed;bottom:12px;"+side+":12px;z-index:2147483647;display:flex;flex-direction:"+
    (side==="left"?"row":"column")+";align-items:center;pointer-events:none;";
  keys.forEach(function(k){c.appendChild(button(k));});
  return c;
}
function mount(){
  if(document.getElementById("manara-touch"))return;
  var root=document.createElement("div");root.id="manara-touch";
  if(L.left.length)root.appendChild(column(L.left,"left"));
  if(L.right.length)root.appendChild(column(L.right,"right"));
  document.body.appendChild(root);
}
if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",mount);else mount();
})();</script>`;
}

/** صفحةُ لعبةٍ جديدة: المكتبةُ بديلة، والنوافذُ معطّلةٌ قبل أيّ سطرٍ من اللعبة. */
export function rewriteGameHtml(gameId: string, source: string): string {
  const html = replaceAdSdk(gameId, source);
  const injected = NO_POPUPS_SCRIPT;
  const head = html.match(/<head[^>]*>/i);
  let out = head && head.index !== undefined
    ? html.slice(0, head.index + head[0].length) + injected + html.slice(head.index + head[0].length)
    : injected + html;
  // وأزرارُ اللمس آخرَ الصفحة، بعد أن تُبنى اللعبة.
  const controls = touchControlsScript(gameId);
  if (controls) {
    const end = out.search(/<\/body>/i);
    out = end >= 0 ? out.slice(0, end) + controls + out.slice(end) : out + controls;
  }
  return out;
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
