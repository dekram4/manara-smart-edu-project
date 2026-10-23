import test from "node:test";
import assert from "node:assert/strict";
import vm from "node:vm";
import {
  DISABLED_AD_SDK,
  GAME_ASSET_CACHE_REGISTER_SCRIPT,
  withGameAssetCache,
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

test("الألعابُ الأساسية: صفحتُها كما هي وفي رأسها تسجيلُ عامل الذاكرة وحده", () => {
  const page = '<!DOCTYPE html><html><head><meta charset="utf-8"><title>x</title></head><body><script src="main.min.js"></script></body></html>';
  const out = withGameAssetCache(page);
  assert.equal(out.replace(GAME_ASSET_CACHE_REGISTER_SCRIPT, ""), page);
  assert.ok(out.indexOf(GAME_ASSET_CACHE_REGISTER_SCRIPT) === page.indexOf("<meta"));
  assert.ok(!out.includes("SDK_READY"));
  assert.ok(withGameAssetCache("<p>x</p>").startsWith(GAME_ASSET_CACHE_REGISTER_SCRIPT));
});

test("أزرارُ اللمس: لـ«Descent» وحدها، وسكربتُها سليم، وتُحقن في صفحتها", async () => {
  const { touchControlsScript, TOUCH_CONTROLS } = await import("../../../dist/lib/gameEmbed.mjs");
  const descent = "0df4c3adb032460791d0ca844d09313d";
  const script = touchControlsScript(descent);
  assert.ok(script.startsWith("<script>") && script.endsWith("</script>"));
  new vm.Script(script.slice("<script>".length, -"</script>".length));
  for (const k of TOUCH_CONTROLS.get(descent).keys) assert.ok(script.includes(`"code":"${k.code}"`), k.code);
  assert.ok(script.includes("pointer:coarse"));
  assert.equal(touchControlsScript("0123456789abcdef0123456789abcdef"), "");
  const page = "<html><head></head><body></body></html>";
  assert.ok(rewriteRegisteredGame(descent, "html", page).includes(script));
  assert.ok(!rewriteRegisteredGame("0123456789abcdef0123456789abcdef", "html", page).includes("mtc-left"));
});

test("رابطُ الوكيل الكامل بنطاق الموقع يُعرف معرّفُه (ألعابُ المعلم المحفوظةُ هكذا)", async () => {
  const { gameDistributionId, playableGameUrl } = await import("../../../dist/lib/entertainment.mjs");
  const id = "4b88f962af114b0a88322938a647a603";
  for (const url of [
    `https://manara-aiedu.com/api/game-embed/${id}/index.html`,
    `https://manara-edu.up.railway.app/api/game-embed/${id}/index.html`,
  ]) {
    assert.equal(gameDistributionId(url), id, url);
    assert.equal(playableGameUrl(url), `/api/game-embed/${id}/index.html`, url);
  }
  assert.equal(gameDistributionId(`https://manara-aiedu.com/api/game-embed/not-an-id/index.html`), null);
  assert.equal(gameDistributionId(`javascript:/api/game-embed/${id}/x`), null);
  assert.equal(gameDistributionId(`https://example.com/games/${id}/index.html`), null);
});

test("تلميحُ السحب: لـ Mine&Build وSWAT وحدهما، وسكربتُه سليم", async () => {
  const { touchHintScript } = await import("../../../dist/lib/gameEmbed.mjs");
  for (const id of ["4b88f962af114b0a88322938a647a603", "6b40e38875b743a4957e2bb712864c33"]) {
    const s = touchHintScript(id);
    new vm.Script(s.slice("<script>".length, -"</script>".length));
    assert.ok(rewriteRegisteredGame(id, "html", "<html><head></head><body></body></html>").includes(s));
  }
  assert.equal(touchHintScript("0df4c3adb032460791d0ca844d09313d"), "");
});

test("«Hose Down!» (Pixi) لها eval بمعرّفها، وغيرُها كما كان", async () => {
  const { registeredGamePageCsp, GAME_PAGE_CSP, GAME_PAGE_CSP_WITH_EVAL } = await import("../../../dist/lib/gameEmbed.mjs");
  const page = '<script type="module" src="./assets/index.js"></script>';
  assert.equal(registeredGamePageCsp(page, "83b71c0760bd48f8861105a5a0bdfda4"), GAME_PAGE_CSP_WITH_EVAL);
  assert.equal(registeredGamePageCsp(page, "4b88f962af114b0a88322938a647a603"), GAME_PAGE_CSP);
  assert.equal(registeredGamePageCsp(page), GAME_PAGE_CSP);
});

test("تخفيفُ الهاتف: لألعاب داود الثقيلة وحدها، وسكربتُه سليم، ولا يمسّ الأساسية", async () => {
  const { mobileTuningScript, MOBILE_TUNING } = await import("../../../dist/lib/gameEmbed.mjs");
  for (const id of MOBILE_TUNING.keys()) {
    const s = mobileTuningScript(id);
    new vm.Script(s.slice("<script>".length, -"</script>".length));
    assert.ok(s.includes("pointer:coarse"));
    assert.ok(rewriteRegisteredGame(id, "html", "<html><head></head><body></body></html>").includes(s));
  }
  for (const builtin of ["d4a3629101574bc39bd8f9d1888ca58e", "71b64121c58b4a95b7459e08086dcb00", "4b88f962af114b0a88322938a647a603"]) {
    assert.equal(mobileTuningScript(builtin), "", builtin);
  }
  assert.ok(mobileTuningScript("0df4c3adb032460791d0ca844d09313d").includes("descent.settings.v1"));
});
