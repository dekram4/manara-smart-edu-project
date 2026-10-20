import test from "node:test";
import assert from "node:assert/strict";
import vm from "node:vm";
import {
  DISABLED_AD_SDK,
  GAMEPUSH_PLATFORM_SCRIPT,
  isSafeGameAssetPath,
  rewriteRegisteredGame,
  upstreamAssetPath,
} from "../../../dist/lib/gameEmbed.mjs";

// ألعابُ المعلم الجديدة (٢٠٢٦-١٠-٢٠): ثلاثُ علّاتٍ في ثلاث ألعاب، وما سبقها كما كان.

const tick = () => new Promise((resolve) => setTimeout(resolve, 5));

test("SDK_READY يصل لمحرّكٍ يضع GD_OPTIONS بعد البديل ثم يحمّل المكتبة («Burger Catch»)", async () => {
  const window = {};
  const context = vm.createContext({ window, setTimeout, Promise });
  // البديلُ أوّلَ الصفحة: لا مستمعَ بعد.
  vm.runInContext(DISABLED_AD_SDK, context);
  await tick();
  const events = [];
  window.GD_OPTIONS = { onEvent: (event) => events.push(event.name) };
  // المحرّكُ يحمّل المكتبةَ (ad-sdk.js) بنفسه.
  vm.runInContext(DISABLED_AD_SDK, context);
  await tick();
  assert.deepEqual(events, ["SDK_READY"]);
  // وتحميلٌ ثالث لا يكرّره.
  vm.runInContext(DISABLED_AD_SDK, context);
  await tick();
  assert.deepEqual(events, ["SDK_READY"]);
});

test("SDK_READY يصل حين تُوضع GD_OPTIONS بلا تحميلٍ ثانٍ للمكتبة (GamePush «Mine&Build»)", async () => {
  const window = {};
  const context = vm.createContext({ window, setTimeout, Promise });
  vm.runInContext(DISABLED_AD_SDK, context);
  await tick();
  const events = [];
  window.GD_OPTIONS = { gameId: "x", onEvent: (event) => events.push(event.name) };
  assert.equal(window.GD_OPTIONS.gameId, "x");
  await tick();
  assert.deepEqual(events, ["SDK_READY"]);
  // ووضعُها ثانيةً لا يكرّره.
  window.GD_OPTIONS = { onEvent: (event) => events.push(event.name) };
  await tick();
  assert.deepEqual(events, ["SDK_READY"]);
});

test("لعبةٌ سمعت SDK_READY أوّلَ مرّة لا يصلها ثانيةً إن حمّلت المكتبة", async () => {
  const events = [];
  const window = { GD_OPTIONS: { onEvent: (event) => events.push(event.name) } };
  const context = vm.createContext({ window, setTimeout, Promise });
  vm.runInContext(DISABLED_AD_SDK, context);
  await tick();
  vm.runInContext(DISABLED_AD_SDK, context);
  await tick();
  assert.deepEqual(events, ["SDK_READY"]);
});

test("مساراتٌ بأقواس («SWAT») تمرّ، والخروجُ والحقنُ ما زالا يُرفضان", () => {
  for (const ok of ["Build/SWATSquadTactics[2]-prime.framework.js", "Build/a(1).data", "index.html"]) {
    assert.equal(isSafeGameAssetPath(ok), true, ok);
  }
  for (const bad of ["../x", "a/[..]/../b", "a b.js", "x?<y>", "%5B", "a\\b"]) {
    assert.equal(isSafeGameAssetPath(bad), false, bad);
  }
});

test("مسارُ المضيف: الأقواسُ مُرمَّزة، وما سواها حرفاً بحرف", () => {
  assert.equal(
    upstreamAssetPath("Build/SWATSquadTactics[2]-prime.loader.js"),
    "Build/SWATSquadTactics%5B2%5D-prime.loader.js",
  );
  for (const old of ["index.html", "Build/6.framework.js", "assets/fonts/font~1.woff2", "a_b-c.d"]) {
    assert.equal(upstreamAssetPath(old), old);
  }
});

test("GamePush لنسخة GameDistribution: المنصّةُ تُعلَن قبل المكتبة، وغيرُها بلا تغيير", () => {
  const id = "4b88f962af114b0a88322938a647a603";
  const gp = '<html><head><script async src="./sdk-bundle/gamepush.gd.js?projectId=1"></script></head></html>';
  const out = rewriteRegisteredGame(id, "html", gp);
  assert.ok(out.includes(GAMEPUSH_PLATFORM_SCRIPT));
  assert.ok(out.indexOf("__GS_BOOT_CONFIG__") < out.indexOf("gamepush.gd.js"));
  const window = {};
  vm.runInContext(GAMEPUSH_PLATFORM_SCRIPT.replace(/<\/?script>/g, ""), vm.createContext({ window }));
  assert.equal(window.__GS_BOOT_CONFIG__.platformType, "GAME_DISTRIBUTION");

  const plain = "<html><head><script src=\"main.js\"></script></head></html>";
  assert.ok(!rewriteRegisteredGame(id, "html", plain).includes("__GS_BOOT_CONFIG__"));
});

test("سياسةُ الصفحة: eval لصفحة Defold وحدها، وما سواها بلا تغيير", async () => {
  const { GAME_PAGE_CSP, GAME_PAGE_CSP_WITH_EVAL, registeredGamePageCsp } = await import("../../../dist/lib/gameEmbed.mjs");
  const defold = '<script id="engine-loader" src="dmloader.js"></script>';
  assert.equal(registeredGamePageCsp(defold), GAME_PAGE_CSP_WITH_EVAL);
  assert.ok(GAME_PAGE_CSP_WITH_EVAL.includes("script-src 'self' 'unsafe-eval'"));
  // والباقي حرفاً بحرف: لا اتصالَ خارجيّ ولا إطارات.
  assert.equal(GAME_PAGE_CSP_WITH_EVAL.replace(" 'unsafe-eval'", ""), GAME_PAGE_CSP);
  for (const other of ["<script src=\"main.js\"></script>", "<script src=\"Build/x.loader.js\"></script>", ""]) {
    assert.equal(registeredGamePageCsp(other), GAME_PAGE_CSP);
  }
  assert.ok(!GAME_PAGE_CSP.includes("'unsafe-eval'"));
});

test("ذاكرةُ الألعاب: الملفّاتُ الثقيلة وحدها، لا الصفحاتُ ولا السكربتات ولا JSON", async () => {
  const { isCacheableGameAsset } = await import("../../../dist/lib/gameEmbed.mjs");
  const g = "/api/game-embed/53e2a2012a3547aab35066d2d913eaef/";
  for (const ok of [
    "Build/html5.data", "Build/html5.wasm", "Build/HookABrainrot_V2.data.unityweb", "Build/x.wasm.gz",
    "archive/game0.arcd", "StreamingAssets/aa/WebGL/ee05f3c652cdc0564b6dbca56a97d8f2.bundle",
    "icon.png", "music/st_finish.ogg", "COOKIERUN-BLACK.TTF",
  ]) assert.equal(isCacheableGameAsset(g + ok), true, ok);
  for (const no of [
    "index.html", "Build/html5.framework.js", "Build/html5.loader.js", "bundle.js", "ad-sdk.js",
    "archive/archive_files.json", "gs-config.json", "language.json",
  ]) assert.equal(isCacheableGameAsset(g + no), false, no);
  assert.equal(isCacheableGameAsset("/api/game-embed/sw.js"), false);
  assert.equal(isCacheableGameAsset("/api/supabase/students"), false);
});

test("عاملُ خدمة الألعاب سليمُ الصياغة، وصفحةُ اللعبة المضافة تسجّله", async () => {
  const { GAME_ASSET_CACHE_SW, GAME_ASSET_CACHE_REGISTER_SCRIPT, rewriteRegisteredGame } = await import("../../../dist/lib/gameEmbed.mjs");
  assert.doesNotThrow(() => new vm.Script(GAME_ASSET_CACHE_SW));
  assert.ok(GAME_ASSET_CACHE_SW.includes('request.headers.has("range")'), "لا طلباتِ مقاطع");
  const out = rewriteRegisteredGame("a9afce108d824d6f838218dd87aa2ef4", "html", "<html><head></head><body></body></html>");
  assert.ok(out.includes(GAME_ASSET_CACHE_REGISTER_SCRIPT));
  assert.ok(GAME_ASSET_CACHE_REGISTER_SCRIPT.includes('scope:"/api/game-embed/"'));
});
