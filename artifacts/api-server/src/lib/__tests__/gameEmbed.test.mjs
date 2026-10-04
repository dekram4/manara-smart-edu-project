import test from "node:test";
import assert from "node:assert/strict";
import vm from "node:vm";
import {
  LEGACY_AD_SDK,
  LEGACY_GAME_IDS,
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

test("الألعابُ القديمة كما كانت: البديلُ الأصلي، ورابطُ https وحده يُستبدل", () => {
  const old = "d4a3629101574bc39bd8f9d1888ca58e";
  assert.ok(LEGACY_GAME_IDS.has(old));
  assert.ok(LEGACY_AD_SDK.includes("success: false"));
  const js = 'a="https://html5.api.gamedistribution.com/main.min.js";b="//html5.api.gamedistribution.com/main.min.js"';
  const out = rewriteGameScript(old, js);
  assert.ok(out.includes('a="/api/game-embed/' + old + '/ad-sdk.js"'));
  assert.ok(out.includes('b="//html5.api.gamedistribution.com/main.min.js"'), "كما كان");
  for (const id of Object.keys(NEW_GAMES)) assert.ok(!LEGACY_GAME_IDS.has(id), id);
});

test("صفحاتُ الألعاب الجديدة: لا CSS ولا وسمَ مُضاف — المكتبةُ والنوافذُ وحدهما", () => {
  const out = rewriteGameHtml("g", "<html><head></head><body></body></html>");
  assert.ok(!out.includes("manara-fit"));
  assert.ok(!out.includes('name="viewport"'));
  assert.ok(out.includes("window.open=function"));
});

test("سياسةُ أمان صفحات الألعاب: صارمة، وتسمح بما تحتاجه الألعابُ وحده", async () => {
  const { GAME_PAGE_CSP } = await import("../../../dist/lib/gameEmbed.mjs");
  const d = Object.fromEntries(GAME_PAGE_CSP.split("; ").map((part) => {
    const [name, ...values] = part.split(" ");
    return [name, values];
  }));
  assert.deepEqual(d["default-src"], ["'self'"]);
  // WebAssembly لألعاب Unity — لا eval لـ JavaScript.
  assert.ok(d["script-src"].includes("'wasm-unsafe-eval'"));
  assert.ok(!d["script-src"].includes("'unsafe-eval'"));
  // محرّكُ «سباق الفراعنة» من مضيفٍ واحدٍ بعينه، لا أيُّ مضيف.
  assert.ok(d["script-src"].includes("https://cdn.jsdelivr.net"));
  assert.ok(!d["script-src"].some((v) => v === "*" || v === "https:"));
  for (const closed of ["frame-src", "object-src", "form-action"]) {
    assert.deepEqual(d[closed], ["'none'"], closed);
  }
  assert.ok(!d["connect-src"].some((v) => v.startsWith("http")), "لا اتصالَ بمضيفٍ خارجي");
});

test("resolveGameId: الثابتُ من القائمة لمعرّفٍ معروف، ولا شيء لغيره", async () => {
  const { resolveGameId, GAME_IDS } = await import("../../../dist/lib/gameEmbed.mjs");
  for (const id of GAME_IDS) {
    assert.equal(resolveGameId(id), id);
  }
  for (const bad of [
    "0123456789abcdef0123456789abcdef", // سليمُ الشكل، خارج القائمة
    "D4A3629101574BC39BD8F9D1888CA58E", // أحرفٌ كبيرة
    "d4a3629101574bc39bd8f9d1888ca58e/", "d4a3629101574bc39bd8f9d1888ca58", "../x",
    "<script>", "", null, undefined, 42, ["d4a3629101574bc39bd8f9d1888ca58e"],
  ]) {
    assert.equal(resolveGameId(bad), null, JSON.stringify(bad));
  }
});

test("isSafeGameAssetPath: مساراتُ الألعاب الحقيقية تمرّ، والخروجُ والحقنُ يُرفضان", async () => {
  const { isSafeGameAssetPath } = await import("../../../dist/lib/gameEmbed.mjs");
  for (const ok of [
    "index.html", "main.min.js", "Build/6.framework.js", "Build/985728d049f55275c34c826df80833c7.wasm.unityweb",
    "bower_components/requirejs/require.js", "icon-256x256.png", "assets/fonts/font~1.woff2", "manifest.json",
  ]) {
    assert.equal(isSafeGameAssetPath(ok), true, ok);
  }
  for (const bad of [
    "../secret", "a/../../b", "./index.html", "a/./b", "/etc/passwd", "a//b", "a/", "",
    "a\b", "x.html?<script>", "<img src=x>.html", "a b.js", "%2e%2e/x", "a\0.js", "x".repeat(301), null, 1,
  ]) {
    assert.equal(isSafeGameAssetPath(bad), false, JSON.stringify(bad));
  }
});

test("resolveRewrittenGameFile: المسارُ الثابتُ من القائمة وحده", async () => {
  const { resolveRewrittenGameFile } = await import("../../../dist/lib/gameEmbed.mjs");
  assert.equal(resolveRewrittenGameFile("d632553ef7264d99aa438310073a6dc3", "index.html"), "index.html");
  assert.equal(resolveRewrittenGameFile("d4a3629101574bc39bd8f9d1888ca58e", "js/init.js"), "js/init.js");
  // الصفحاتُ القديمة لا تُعاد كتابتُها، ولا ملفٌّ خارج القائمة.
  assert.equal(resolveRewrittenGameFile("d4a3629101574bc39bd8f9d1888ca58e", "index.html"), null);
  assert.equal(resolveRewrittenGameFile("d632553ef7264d99aa438310073a6dc3", "yes2sdk.umd.js"), null);
  assert.equal(resolveRewrittenGameFile("0123456789abcdef0123456789abcdef", "index.html"), null);
  assert.equal(resolveRewrittenGameFile("d632553ef7264d99aa438310073a6dc3", "INDEX.html"), null);
});
