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
 * الملفّاتُ التي تُعاد كتابتُها — وحدها، بمسارٍ ثابتٍ هنا.
 *
 * فُحص كلُّ ملفّ HTML وJS تطلبه الألعابُ العشر (الستّ والأقدمُ الأربع): هذه وحدها
 * يغيّرها rewriteGameHtml أو rewriteGameScript؛ وكلُّ ما سواها يُمرَّر كما هو.
 *
 * ونسخُها المُعادةُ كتابتُها مثبّتةٌ في المستودع (static-games/<معرّف>/<مسار>) تُقدَّم
 * كما هي — لا تُجلب من GameDistribution عند الطلب، فلا يصل تغييرٌ هناك إلى الطلاب
 * دون مراجعة. وتُولَّد بـ scripts/vendor-game-files.mjs؛ فإن حدّث الناشرُ لعبةً
 * فتوقّفت، يُعاد توليدُها، ويُضاف هنا أيُّ اسمٍ جديد (Build/<بصمة>.framework.js).
 */
const REWRITTEN_GAME_FILES: ReadonlyMap<string, readonly string[]> = new Map([
  ["d4a3629101574bc39bd8f9d1888ca58e", ["js/init.js"]],
  ["73c29ef316be4f0bb6d149d8b5a39ff3", ["index.html"]],
  ["99ba036a4225425794e2c423fbcf9842", ["index.html", "Build/6.framework.js"]],
  ["d632553ef7264d99aa438310073a6dc3", ["index.html", "yes2sdk-gamedistribution.js"]],
  ["71b64121c58b4a95b7459e08086dcb00", [
    "index.html",
    "Build/b87cb569842ecaed08a4ace4f6d461fa.framework.js",
  ]],
]);

/** كلُّ [معرّف اللعبة، المسار] في REWRITTEN_GAME_FILES — لسكربت توليد النسخ واختبارها. */
export function rewrittenGameFileList(): Array<[string, string]> {
  return [...REWRITTEN_GAME_FILES].flatMap(([id, files]) => files.map((file): [string, string] => [id, file]));
}

/** المسارُ الثابتُ من REWRITTEN_GAME_FILES إن كان الملفُّ يُعاد كتابتُه — أو `null`. */
export function resolveRewrittenGameFile(gameId: string, path: string): string | null {
  for (const file of REWRITTEN_GAME_FILES.get(gameId) ?? []) {
    if (file === path) return file;
  }
  return null;
}

/**
 * مسارُ ملفٍّ داخل لعبة: مقاطعُ من حروفٍ وأرقامٍ و`_ . ~ -` يفصلها `/` — وكلُّ ما
 * تطلبه الألعابُ الستّ (٦٩ ملفاً) على هذا الشكل. ولا مقطعَ `.` أو `..`.
 */
const GAME_ASSET_PATH_PATTERN = /^[A-Za-z0-9_.~()[\]-]+(?:\/[A-Za-z0-9_.~()[\]-]+)*$/;

/**
 * والأقواسُ `[] ()` أيضاً: «SWAT: Squad Tactics» (Unity) ملفّاتُه
 * `Build/SWATSquadTactics[2]-prime.*` فكانت تُرفض (400) وتتوقّف اللعبة عند شعارها.
 */
export function isSafeGameAssetPath(value: unknown): value is string {
  if (typeof value !== "string" || value.length > 300) return false;
  if (!GAME_ASSET_PATH_PATTERN.test(value)) return false;
  return value.split("/").every((segment) => segment !== "." && segment !== "..");
}

/**
 * المسارُ كما يُطلب من مضيف اللعبة: كلُّ مقطعٍ مُرمَّز. ومسارٌ بلا أقواس — كلُّ ما
 * طلبته الألعابُ السابقة — يخرج كما دخل حرفاً بحرف.
 */
export function upstreamAssetPath(path: string): string {
  return path.split("/").map(encodeURIComponent).join("/");
}

/**
 * لعبةٌ بُنيت بـ GamePush لنسخة GameDistribution (`gamepush.gd.js`): المكتبةُ تعرف
 * منصّتها من اسم الموقع، وعلى غير موقع GameDistribution ترمي «wrong platform type»
 * فتبقى الصفحةُ زرقاءَ فارغة («Mine&Build»). والمكتبةُ نفسها تقبل إعلانَ المنصّة
 * مسبقاً في `__GS_BOOT_CONFIG__` — فيُعلَن قبلها، وما سواها لا يتغيّر.
 */
const GAMEPUSH_GD_BUNDLE = /gamepush\.gd\.js/i;
export const GAMEPUSH_PLATFORM_SCRIPT =
  "<script>window.__GS_BOOT_CONFIG__=Object.assign({platformType:\"GAME_DISTRIBUTION\"},window.__GS_BOOT_CONFIG__||{});</script>";

/**
 * زرٌّ على الشاشة يضغط مفتاحاً ما دام الإصبعُ عليه.
 *
 * `side`: يسارُ أسفل الشاشة (التوجيه) أو يمينُها (الأفعال) أو أعلاها (أفعالٌ نادرة).
 */
export type TouchKey = {
  label: string;
  code: string;
  key: string;
  side: "left" | "right" | "top";
};

/**
 * ألعابٌ مضافة لا تُلعب إلا بلوحة المفاتيح: يُضاف لها على الهاتف واللوح أزرارٌ
 * تضغط مفاتيحَها. لكل لعبةٍ أزرارُها من جدول تحكّمها هي.
 *
 * «Descent» (دراجةُ منحدرات — «مغامرات الروضة» عند المعلم): لا تستمع لللمس إلا
 * لتشغيل الصوت، وتقرأ المفاتيحَ بـ`e.code` من `window` دون أن تسأل أهي حقيقية —
 * فالزرُّ يرسل المفتاحَ نفسه ولا تتغيّر اللعبة.
 */
export type TouchControls = {
  keys: readonly TouchKey[];
  /** تظهر الأزرارُ ما دام هذا في الصفحة (واجهةُ اللعب) … */
  activeWhen: string;
  /** … وليس هذا (قوائمُ اللعبة: لا تغطّي الأزرارُ أزرارَها). */
  hiddenWhen: string;
};

export const TOUCH_CONTROLS: ReadonlyMap<string, TouchControls> = new Map([
  ["0df4c3adb032460791d0ca844d09313d", {
    activeWhen: ".compact:not(.is-hidden):not(.is-dimmed)",
    hiddenWhen: ".dm-view.dm-open",
    keys: [
      { label: "◀", code: "KeyA", key: "a", side: "left" },
      { label: "▶", code: "KeyD", key: "d", side: "left" },
      { label: "▲", code: "KeyW", key: "w", side: "left" },
      { label: "▼", code: "KeyS", key: "s", side: "left" },
      { label: "دوّس", code: "ShiftLeft", key: "Shift", side: "right" },
      { label: "قفز", code: "Space", key: " ", side: "right" },
      { label: "فرامل", code: "KeyK", key: "k", side: "right" },
      { label: "↺", code: "KeyR", key: "r", side: "top" },
      { label: "⏸", code: "Escape", key: "Escape", side: "top" },
    ],
  }],
]);

/**
 * طبقةُ الأزرار للعبةٍ في TOUCH_CONTROLS — أو "" لغيرها. تظهر على الأجهزة
 * اللمسية وحدها وأثناء اللعب وحده؛ وما بين الأزرار يمرّ لمسُه إلى اللعبة.
 * وكلُّ إصبعٍ مستقلّ: التوجيهُ والدوّاسةُ معاً. وحين تُفتح قائمةٌ يُرفع كلُّ مفتاحٍ
 * مضغوط، فلا تبقى الدرّاجةُ مندفعةً بعد الإيقاف.
 */
export function touchControlsScript(gameId: string): string {
  const controls = TOUCH_CONTROLS.get(gameId);
  if (!controls) return "";
  return `<script>(function(){try{
var KEYS=${JSON.stringify(controls.keys)},ON=${JSON.stringify(controls.activeWhen)},OFF=${JSON.stringify(controls.hiddenWhen)};
if(!(window.matchMedia&&matchMedia("(pointer:coarse)").matches)&&!(navigator.maxTouchPoints>0))return;
function send(type,k){window.dispatchEvent(new KeyboardEvent(type,{key:k.key,code:k.code,bubbles:true,cancelable:true}));}
function build(){
var css=document.createElement("style");
css.textContent=".mtc{position:fixed;z-index:2147483647;display:flex;gap:10px;pointer-events:none;-webkit-user-select:none;user-select:none}"+
".mtc-left{left:calc(12px + env(safe-area-inset-left,0px));bottom:calc(12px + env(safe-area-inset-bottom,0px));display:grid;grid-template-columns:repeat(3,58px);grid-template-rows:repeat(2,58px)}"+
".mtc-right{right:calc(12px + env(safe-area-inset-right,0px));bottom:calc(12px + env(safe-area-inset-bottom,0px));flex-direction:column;align-items:flex-end}"+
".mtc-top{right:calc(12px + env(safe-area-inset-right,0px));top:calc(12px + env(safe-area-inset-top,0px))}"+
".mtc button{pointer-events:auto;touch-action:none;min-width:58px;height:58px;padding:0 14px;border-radius:29px;border:2px solid rgba(255,255,255,.75);background:rgba(0,0,0,.38);color:#fff;font:700 20px system-ui,sans-serif;-webkit-tap-highlight-color:transparent}"+
".mtc-top button{min-width:44px;height:44px;border-radius:22px;font-size:18px}"+
".mtc button.on{background:rgba(255,255,255,.45)}.mtc[hidden]{display:none!important}";
document.head.appendChild(css);
var boxes={},releases=[];["left","right","top"].forEach(function(s){var d=document.createElement("div");d.className="mtc mtc-"+s;d.hidden=true;boxes[s]=d;document.body.appendChild(d);});
var place={KeyA:"2/1",KeyD:"2/3",KeyW:"1/2",KeyS:"2/2"};
KEYS.forEach(function(k){var b=document.createElement("button");b.type="button";b.textContent=k.label;b.setAttribute("aria-label",k.code);
if(k.side==="left"&&place[k.code]){var p=place[k.code].split("/");b.style.gridRow=p[0];b.style.gridColumn=p[1];}
var held=0;
function down(e){e.preventDefault();e.stopPropagation();try{b.setPointerCapture(e.pointerId);}catch(x){}if(held++===0){b.classList.add("on");send("keydown",k);}}
function up(e){e.preventDefault();e.stopPropagation();if(held>0&&--held===0){b.classList.remove("on");send("keyup",k);}}
b.addEventListener("pointerdown",down);b.addEventListener("pointerup",up);b.addEventListener("pointercancel",up);b.addEventListener("lostpointercapture",function(e){if(held>0){held=1;up(e);}});
b.addEventListener("contextmenu",function(e){e.preventDefault();});
releases.push(function(){if(held>0){held=0;b.classList.remove("on");send("keyup",k);}});
boxes[k.side].appendChild(b);});
function sync(){var show=!!document.querySelector(ON)&&!document.querySelector(OFF);
for(var s in boxes)boxes[s].hidden=!show;if(!show)releases.forEach(function(r){r();});}
sync();setInterval(sync,250);
}
if(document.body)build();else document.addEventListener("DOMContentLoaded",build);
}catch(e){}})();</script>`;
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

/**
 * صفحةُ لعبةٍ مضافة بمحرّك Defold (`dmloader.js`): المحرّكُ يصل بين Lua وJavaScript
 * بـ `eval`، فبدونه تبقى اللعبةُ شاشةً زرقاء بلا خطأٍ ظاهر («Mine&Build»). فلها
 * وحدها `'unsafe-eval'`، وكلُّ ما سواه في السياسة كما هو. وما سواها من الألعاب
 * يبقى على [GAME_PAGE_CSP] بلا eval.
 */
const DEFOLD_LOADER = /dmloader\.js/i;
export const GAME_PAGE_CSP_WITH_EVAL = GAME_PAGE_CSP.replace(
  "script-src 'self'",
  "script-src 'self' 'unsafe-eval'",
);

/** سياسةُ صفحة لعبةٍ مضافة من مصدرها. */
export function registeredGamePageCsp(source: string): string {
  return DEFOLD_LOADER.test(source) ? GAME_PAGE_CSP_WITH_EVAL : GAME_PAGE_CSP;
}

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
 *
 * ── و`SDK_READY` لا يضيع ──
 * البديلُ يُحقن أوّلَ الصفحة، وبعضُ المحرّكات («Burger Catch») تضع `GD_OPTIONS`
 * بعده ثم تحمّل المكتبةَ بنفسها وتنتظر `SDK_READY`. كان يُطلق مرّةً قبل أن يوجد من
 * يسمعه، والتحميلُ الثاني يعود فوراً — فتبقى اللعبةُ سوداءَ إلى الأبد. وGamePush
 * («Mine&Build») يضع `GD_OPTIONS` ثم لا يحمّل المكتبةَ أصلاً لأنه يجد `gdsdk`.
 * الآن يُعدّ مُسلَّماً حين يجد مستمعاً فقط، ويُطلَق حين تُوضع `GD_OPTIONS` أو تُحمَّل
 * المكتبةُ ثانيةً إن لم يُسلَّم. واللعبةُ التي سمعته أوّلَ مرّة لا يصلها شيءٌ جديد.
 */
export const DISABLED_AD_SDK = `
(() => {
  if (window.gdsdk && window.gdsdk.__manara) {
    if (typeof window.gdsdk.__lateReady === "function") window.gdsdk.__lateReady();
    return;
  }
  const options = () => window.GD_OPTIONS || {};
  const emit = (name) => {
    const handler = options().onEvent;
    if (typeof handler !== "function") return false;
    try {
      handler({ name, message: name, status: "success" });
    } catch (error) {}
    return true;
  };
  let ready = false;
  const sendReady = () => setTimeout(() => {
    if (!ready) ready = emit("SDK_READY");
  }, 0);
  let gdOptions = window.GD_OPTIONS;
  try {
    Object.defineProperty(window, "GD_OPTIONS", {
      configurable: true,
      enumerable: true,
      get: () => gdOptions,
      set: (value) => {
        gdOptions = value;
        sendReady();
      },
    });
  } catch (error) {}
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
    __lateReady: sendReady,
  };
  sendReady();
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

/**
 * لعبةٌ أضافها مشرفٌ أو معلّمٌ من GameDistribution: تُنظَّف عند الطلب.
 *
 * الستُّ الأولى نسخُها المُعادةُ كتابتُها مثبّتةٌ ومراجَعة. والمضافةُ لاحقاً تأخذ
 * القاعدةَ نفسها آلياً: صفحتُها تبدأ ببديل الإعلانات الصامت (فيجده محرّكُ Unity
 * أو Construct قبل أن يطلب الإعلان) وبتعطيل النوافذ، ورابطُ المكتبة في صفحاتها
 * وسكربتاتها يشير إلى البديل. والمكتبةُ الحقيقية لا تُحمَّل أصلاً: سياسةُ أمان
 * الصفحة لا تسمح بمضيفها.
 */
export function rewriteRegisteredGame(gameId: string, kind: "html" | "js", source: string): string {
  if (kind === "js") return rewriteGameScript(gameId, source);
  const html = rewriteGameHtml(gameId, source);
  const platform = GAMEPUSH_GD_BUNDLE.test(source) ? GAMEPUSH_PLATFORM_SCRIPT : "";
  const stub = `${platform}<script>${DISABLED_AD_SDK}</script>${GAME_ASSET_CACHE_REGISTER_SCRIPT}${touchControlsScript(gameId)}`;
  const head = html.match(/<head[^>]*>/i);
  if (head && head.index !== undefined) {
    const at = head.index + head[0].length;
    return html.slice(0, at) + stub + html.slice(at);
  }
  return stub + html;
}

/**
 * ذاكرةُ ملفّات الألعاب في الجهاز — تُحمَّل اللعبةُ مرّةً، وتُفتح بعدها فوراً.
 *
 * ── لماذا ──
 * قيسَ التحميلُ على الإنتاج: «Tung Tung Racing» ٩٠ ميغابايت، و«SWAT» ٦٠ في ٨٣٩
 * ملفّاً، و«الحبال» ٥١. على شبكة هاتف هذه دقائق. ولم يكن في الطريق انتظارٌ لخادم
 * إعلانات: البديلُ يُطلق SDK_READY فوراً، وسياسةُ الأمان تحجب مكتبات الإعلانات
 * لحظتها. والعلّة أنها تُحمَّل **كلَّ مرّة**: ذاكرةُ HTTP في WebView أصغر من
 * هذه الملفّات، و«Tung Tung» لا تفعّل ذاكرةَ Unity أصلاً.
 *
 * فعاملُ خدمةٍ نطاقُه صفحاتُ الألعاب وحدها (`/api/game-embed/`) يحفظ ملفّاتِها
 * الثقيلة — البيانات وwasm والصور والأصوات والخطوط — في ذاكرة الجهاز عند أوّل
 * طلب، ويردّ منها بعد ذلك. ولا يمسّ الصفحاتِ ولا السكربتات (تُعاد كتابتُها عند
 * كل طلب)، ولا JSON، ولا طلباتِ المقاطع (Range). فما تشغّله اللعبةُ هو نفسُ ما
 * كان يصلها من الشبكة، بايتاً ببايت.
 *
 * لكل لعبةٍ ذاكرتُها، وتُطرد الأقدمُ استعمالاً فوق ثماني ألعاب، وتُجدَّد ذاكرةُ اللعبة
 * كلُّها بعد أربعة عشر يوماً.
 */
export const GAME_ASSET_CACHE_SW_PATH = "/api/game-embed/sw.js";

/** امتداداتُ الملفّات الثقيلة التي لا تتغيّر بعد نشرها. */
export const GAME_ASSET_CACHEABLE = /\.(?:data|wasm|unityweb|bundle|arcd|arci|dmanifest|projectc|bin|mem|symbols|png|jpe?g|gif|webp|svg|ogg|mp3|m4a|wav|webm|mp4|woff2?|ttf|otf|atlas|fnt|glb|gltf|ktx2?|basis)(?:\.(?:gz|br|unityweb))?$/i;

/** مسارُ ملفٍّ داخل لعبةٍ يُحفظ في الجهاز — للاختبار ولعامل الخدمة معاً. */
const GAME_ASSET_PATH = /^\/api\/game-embed\/([a-f0-9]{32})\/(.+)$/;

export function isCacheableGameAsset(pathname: string): boolean {
  const match = GAME_ASSET_PATH.exec(pathname);
  return Boolean(match && GAME_ASSET_CACHEABLE.test(match[2]));
}

/**
 * يسجّل عاملَ الذاكرة، ويقف أمام عامل اللعبة نفسها: قوالبُ Unity 6 تسجّل
 * `ServiceWorker.js` بنطاق مجلّدها، والنطاقُ الأضيق يغلب — فكان يُقصي عاملَنا ولا
 * يحفظ شيئاً، فتُحمَّل «Tung Tung» ثمانين ميغابايتاً في كل مرّة. عاملُ اللعبة
 * للعمل بلا شبكة وحده، فلا تفقد اللعبةُ بغيابه شيئاً. ويُزال ما سُجّل منه قبلُ
 * داخل مجلّدات الألعاب — لا عاملُ الموقع نفسه.
 */
export const GAME_ASSET_CACHE_REGISTER_SCRIPT =
  `<script>(function(){try{var sw=navigator.serviceWorker;if(!sw)return;` +
  `var ours=sw.register("${GAME_ASSET_CACHE_SW_PATH}",{scope:"/api/game-embed/"});ours.catch(function(){});` +
  `sw.register=function(){return ours;};` +
  `sw.getRegistrations().then(function(rs){rs.forEach(function(r){var w=r.active||r.waiting||r.installing;` +
  `if(r.scope.indexOf(location.origin+"/api/game-embed/")===0&&r.scope!==location.origin+"/api/game-embed/"&&!(w&&/\\/api\\/game-embed\\/sw\\.js$/.test(w.scriptURL)))r.unregister();});}).catch(function(){});` +
  `}catch(e){}})();</script>`;

/**
 * صفحةُ لعبةٍ أساسية (الستّ وما قبلها) كما هي حرفاً، وفي رأسها تسجيلُ عامل الذاكرة
 * وحده — لا بديلَ إعلاناتٍ ولا غيرَه — فتُحفظ ملفّاتُها الثقيلة في الجهاز كالمضافة
 * («الروبوت الخارق» ٧٥ ميغابايتاً كانت تُحمَّل في كل مرّة).
 */
export function withGameAssetCache(html: string): string {
  const head = html.match(/<head[^>]*>/i);
  if (head && head.index !== undefined) {
    const at = head.index + head[0].length;
    return html.slice(0, at) + GAME_ASSET_CACHE_REGISTER_SCRIPT + html.slice(at);
  }
  return GAME_ASSET_CACHE_REGISTER_SCRIPT + html;
}

export const GAME_ASSET_CACHE_SW = `
const PREFIX = "manara-game-";
const MAX_GAMES = 8;
const MAX_AGE_MS = 14 * 24 * 60 * 60 * 1000;
const CACHEABLE = ${GAME_ASSET_CACHEABLE.toString()};
const ASSET = ${GAME_ASSET_PATH.toString()};

self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()));

async function touch(gameId) {
  try {
    const meta = await caches.open(PREFIX + "meta");
    await meta.put("/__used/" + gameId, new Response(String(Date.now())));
    const names = (await caches.keys()).filter((n) => n.startsWith(PREFIX) && n !== PREFIX + "meta");
    if (names.length <= MAX_GAMES) return;
    const used = await Promise.all(names.map(async (n) => {
      const hit = await meta.match("/__used/" + n.slice(PREFIX.length));
      return [n, hit ? Number(await hit.text()) : 0];
    }));
    used.sort((a, b) => a[1] - b[1]);
    for (const [n] of used.slice(0, used.length - MAX_GAMES)) {
      await caches.delete(n);
      await meta.delete("/__used/" + n.slice(PREFIX.length));
    }
  } catch (e) {}
}

const checked = new Set();

/** لعبةٌ حُفظت منذ أكثر من أربعة عشر يوماً: تُطرد ذاكرتُها مرّةً فتُجدَّد. */
async function expireIfOld(gameId) {
  if (checked.has(gameId)) return;
  checked.add(gameId);
  try {
    const meta = await caches.open(PREFIX + "meta");
    const born = await meta.match("/__born/" + gameId);
    if (!born) return meta.put("/__born/" + gameId, new Response(String(Date.now())));
    if (Date.now() - Number(await born.text()) > MAX_AGE_MS) {
      await caches.delete(PREFIX + gameId);
      await meta.put("/__born/" + gameId, new Response(String(Date.now())));
    }
  } catch (e) {}
}

async function fromCacheOrNetwork(request, gameId) {
  await expireIfOld(gameId);
  const cache = await caches.open(PREFIX + gameId);
  const hit = await cache.match(request.url);
  if (hit) return hit;
  const response = await fetch(request);
  if (response.status === 200 && response.type === "basic") {
    // ‏نسخةٌ تتدفّق إلى الذاكرة بينما تقرأ اللعبةُ الأصل — بلا تحميلٍ للملفّ كلّه في الذاكرة.
    cache.put(request.url, response.clone()).then(() => touch(gameId)).catch(() => {});
  }
  return response;
}

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET" || request.headers.has("range")) return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  const match = ASSET.exec(url.pathname);
  if (!match || !CACHEABLE.test(match[2])) return;
  event.respondWith(fromCacheOrNetwork(request, match[1]).catch(() => fetch(request)));
});
`;
