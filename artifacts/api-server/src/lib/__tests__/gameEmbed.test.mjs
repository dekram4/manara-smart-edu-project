import test from "node:test";
import assert from "node:assert/strict";
import vm from "node:vm";
import {
  DISABLED_AD_SDK,
  GAME_CATALOG,
  GAME_IDS,
  catalogJson,
  replaceAdSdk,
  rewriteGameHtml,
  rewriteGameScript,
} from "../../../dist/lib/gameEmbed.mjs";

const NEW_GAMES = {
  "73c29ef316be4f0bb6d149d8b5a39ff3": ["landscape", 1280, 720],
  "99ba036a4225425794e2c423fbcf9842": ["portrait", 1080, 1920],
  "d632553ef7264d99aa438310073a6dc3": ["landscape", 800, 600],
  "71b64121c58b4a95b7459e08086dcb00": ["landscape", 960, 600],
};

test("الفهرس: ستُّ ألعاب، والجديدةُ بأبعادها واتجاهها", () => {
  assert.equal(GAME_CATALOG.length, 6);
  for (const [id, [orientation, width, height]] of Object.entries(NEW_GAMES)) {
    const game = GAME_CATALOG.find((entry) => entry.id === id);
    assert.ok(game, id);
    assert.deepEqual([game.orientation, game.width, game.height], [orientation, width, height], id);
    assert.ok(GAME_IDS.has(id), id);
  }
  const ids = GAME_CATALOG.map((game) => game.id);
  assert.equal(new Set(ids).size, ids.length, "لا تكرار");
});

test("الأسماءُ حماسيةٌ لا عامّة، وكلُّ لعبةٍ برابط الوكيل لا بصفحة الإعلانات", () => {
  for (const game of catalogJson()) {
    assert.ok(game.title && !/^(?:ال)?لعبة|game/i.test(game.title), game.title);
    assert.equal(game.url, `/api/game-embed/${game.id}/index.html`);
  }
});

test("مكتبةُ الإعلانات تُستبدل بكل صيغ رابطها", () => {
  for (const url of [
    "https://html5.api.gamedistribution.com/main.min.js",
    "http://html5.api.gamedistribution.com/main.min.js",
    "//html5.api.gamedistribution.com/main.min.js",
  ]) {
    const out = replaceAdSdk("g1", `js.src="${url}";`);
    assert.equal(out, 'js.src="/api/game-embed/g1/ad-sdk.js";', url);
  }
  // ولا يمسّ غيرَها.
  assert.equal(replaceAdSdk("g1", 'src="Build/6.loader.js"'), 'src="Build/6.loader.js"');
});

test("صفحةُ اللعبة: المكتبةُ في HTML تُستبدل، والنوافذُ تُعطّل أوّلَ الصفحة", () => {
  const html = '<html><head><meta charset="utf-8"><script>js.src = \'https://html5.api.gamedistribution.com/main.min.js\';</script></head><body></body></html>';
  const out = rewriteGameHtml("g1", html);
  assert.ok(!out.includes("html5.api.gamedistribution.com"));
  assert.ok(out.indexOf("window.open=function") < out.indexOf("<meta"), "قبل أيّ شيء");
  assert.ok(out.startsWith("<html><head>"));
});

test("ملفّاتُ JS: الصيغةُ المجرّدة (//) تُستبدل أيضاً", () => {
  const js = 'js.id=id;js.src="//html5.api.gamedistribution.com/main.min.js";fjs.parentNode';
  assert.ok(rewriteGameScript("g9", js).includes('"/api/game-embed/g9/ad-sdk.js"'));
});

function runSdk(onEvent) {
  const window = { GD_OPTIONS: { onEvent } };
  const context = vm.createContext({ window, setTimeout, Promise });
  vm.runInContext(DISABLED_AD_SDK, context);
  return window;
}

test("البديلُ الصامت: إعلانٌ «ينتهي» فوراً فتمضي اللعبة", async () => {
  const events = [];
  const window = runSdk((event) => events.push(event.name));
  await new Promise((resolve) => setTimeout(resolve, 5));
  assert.deepEqual(events, ["SDK_READY"]);
  const result = await window.gdsdk.showAd(window.gdsdk.AdType.Interstitial);
  assert.equal(result.args.success, true);
  assert.deepEqual(events, ["SDK_READY", "SDK_GAME_PAUSE", "SDK_GAME_START"]);
});

test("البديلُ الصامت: إعلانُ المكافأة يمنح المكافأةَ بلا إعلان", async () => {
  const events = [];
  const window = runSdk((event) => events.push(event.name));
  await window.gdsdk.showAd("rewarded");
  assert.deepEqual(events.filter((e) => e !== "SDK_READY"), [
    "SDK_GAME_PAUSE",
    "SDK_REWARDED_WATCH_COMPLETE",
    "SDK_GAME_START",
  ]);
  // وما تستعمله ألعابُ Unity موجود.
  await window.gdsdk.preloadAd("rewarded");
  await window.gdsdk.sendEvent({});
  assert.equal(window.gdsdk.AdType.Rewarded, "rewarded");
});

test("البديلُ الصامت لا يرمي إن لم تُعرّف اللعبةُ GD_OPTIONS", async () => {
  const window = {};
  vm.runInContext(DISABLED_AD_SDK, vm.createContext({ window, setTimeout, Promise }));
  await window.gdsdk.showAd();
});

test("صفحةٌ بلا وسم viewport: يُضاف — وإلا رُسمت بعرض حاسوبٍ صغيرةً في ركن", async () => {
  const { rewriteGameHtml: rewrite } = await import("../../../dist/lib/gameEmbed.mjs");
  const bare = rewrite("g", "<html><head><title>x</title></head><body></body></html>");
  assert.equal((bare.match(/name="viewport"/g) ?? []).length, 1);
  const own = rewrite("g", '<html><head><meta name="viewport" content="width=device-width"></head></html>');
  assert.equal((own.match(/name=["']?viewport/g) ?? []).length, 1, "لا وسمَ ثانياً");
});

test("اللعبةُ ملءُ الشاشة: الصفحةُ بعرضها وارتفاعها بلا هوامش ولا تمرير", async () => {
  const { rewriteGameHtml: rewrite } = await import("../../../dist/lib/gameEmbed.mjs");
  const out = rewrite("g", "<html><head></head><body></body></html>");
  for (const rule of ["width:100vw!important", "height:100vh!important", "overflow:hidden!important", "position:fixed!important", "inset:0!important", "margin:0!important", "padding:0!important"]) {
    assert.ok(out.includes(rule), rule);
  }
});
