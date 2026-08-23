import { Router } from "express";
import { logger } from "../lib/logger";

const router = Router();

const GAME_IDS = new Set([
  "d4a3629101574bc39bd8f9d1888ca58e",
  "172e0bd0c40442dbae3d4adb42a98433",
  "659090e00bfc4650899550d63f8a130d",
  "be797a3996324c03b20bad496a82819f",
  "19c63777ed1e4653b64b2200560907fd",
  "72d861a52f3c4e788ae0421649633be3",
]);

const GAME_HOST = "https://html5.gamedistribution.com/rvvASMiM";
const AD_SDK_PATH = "/ad-sdk.js";

const disabledAdSdk = `
  (() => {
    const safeResult = Promise.resolve({ args: { success: false } });
    window.gdsdk = window.gdsdk || {
      showAd: () => safeResult,
      preloadAd: () => Promise.resolve(),
    };
  })();
`;

router.get("/game-catalog", (_req, res) => {
  res.json({
    games: [
      {
        id: "d4a3629101574bc39bd8f9d1888ca58e",
        title: "مغامرة التعلم",
        subtitle: "لعبة تعليمية تفاعلية داخل منارة",
        url: "/api/game-embed/d4a3629101574bc39bd8f9d1888ca58e/index.html",
      },
      {
        id: "172e0bd0c40442dbae3d4adb42a98433",
        title: "تحدي المعرفة",
        subtitle: "اختبر مهاراتك بطريقة ممتعة",
        url: "/api/game-embed/172e0bd0c40442dbae3d4adb42a98433/index.html",
      },
    ],
  });
});

function rewriteGameScript(gameId: string, source: string): string {
  let rewritten = source.replaceAll(
    "https://html5.api.gamedistribution.com/main.min.js",
    `/api/game-embed/${gameId}${AD_SDK_PATH}`,
  );

  const replaceMethod = (
    methodStart: string,
    methodEnd: string,
    replacement: string,
  ) => {
    const start = rewritten.indexOf(methodStart);
    const end = start === -1 ? -1 : rewritten.indexOf(methodEnd, start);
    if (start === -1 || end === -1) return;
    rewritten =
      rewritten.slice(0, start) + replacement + rewritten.slice(end + 1);
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

function getContentType(pathname: string, upstreamType: string): string {
  if (upstreamType) return upstreamType;
  if (pathname.endsWith(".js")) return "application/javascript; charset=utf-8";
  if (pathname.endsWith(".json") || pathname.endsWith(".webmanifest"))
    return "application/json; charset=utf-8";
  if (pathname.endsWith(".css")) return "text/css; charset=utf-8";
  if (pathname.endsWith(".html")) return "text/html; charset=utf-8";
  return "application/octet-stream";
}

// Express 5 requires named wildcards — use *gameAssetPath
router.get("/game-embed/:gameId/*gameAssetPath", async (req, res) => {
  const { gameId, gameAssetPath: rawAssetPath } = req.params as any;
  // Express 5 named wildcards may be delivered as an array of segments
  const requestedPath: string = Array.isArray(rawAssetPath)
    ? rawAssetPath.join("/")
    : (rawAssetPath || "index.html");

  if (
    !GAME_IDS.has(gameId) ||
    requestedPath.includes("..") ||
    requestedPath.startsWith("/")
  ) {
    res.status(404).send("Game asset not found");
    return;
  }

  if (requestedPath === AD_SDK_PATH.slice(1)) {
    res.type("application/javascript").send(disabledAdSdk);
    return;
  }

  const upstreamUrl = `${GAME_HOST}/${gameId}/${requestedPath}`;
  try {
    const upstream = await fetch(upstreamUrl);
    if (!upstream.ok) {
      res
        .status(upstream.status)
        .send(`Game asset request failed (${upstream.status})`);
      return;
    }

    const upstreamType = upstream.headers.get("content-type") || "";
    const isHtml =
      requestedPath.endsWith(".html") || upstreamType.includes("text/html");
    const isJavaScript =
      requestedPath.endsWith(".js") || upstreamType.includes("javascript");

    if (isHtml) {
      const source = await upstream.text();
      res.type("html").set("Cache-Control", "no-store").send(source);
      return;
    }

    if (isJavaScript) {
      const source = await upstream.text();
      res
        .type("application/javascript")
        .set("Cache-Control", "no-store")
        .send(rewriteGameScript(gameId, source));
      return;
    }

    const body = Buffer.from(await upstream.arrayBuffer());
    res
      .set("Content-Type", getContentType(requestedPath, upstreamType))
      .set("Cache-Control", "no-store")
      .send(body);
  } catch (error) {
    logger.error({ err: error }, "Game asset proxy error");
    res.status(502).send("Game asset proxy failed");
  }
});

export default router;
