import { Router } from "express";
import { Readable } from "node:stream";
import type { ReadableStream as WebReadableStream } from "node:stream/web";
import { logger } from "../lib/logger";
import {
  AD_SDK_PATH,
  DISABLED_AD_SDK,
  GAME_HOST,
  GAME_IDS,
  catalogJson,
  rewriteGameHtml,
  rewriteGameScript,
} from "../lib/gameEmbed";

const router = Router();

/** أكبرُ ردٍّ يُعلَن حجمُه — دون حدّ منصّة النشر (٣٢ ميغابايت) بهامش. */
const MAX_DECLARED_LENGTH = 30 * 1024 * 1024;

router.get("/game-catalog", (_req, res) => {
  res.json({ games: catalogJson() });
});

function getContentType(pathname: string, upstreamType: string): string {
  if (upstreamType) return upstreamType;
  if (pathname.endsWith(".js")) return "application/javascript; charset=utf-8";
  if (pathname.endsWith(".json") || pathname.endsWith(".webmanifest"))
    return "application/json; charset=utf-8";
  if (pathname.endsWith(".css")) return "text/css; charset=utf-8";
  if (pathname.endsWith(".html")) return "text/html; charset=utf-8";
  if (pathname.endsWith(".wasm")) return "application/wasm";
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
    res.type("application/javascript").send(DISABLED_AD_SDK);
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
      res.type("html").set("Cache-Control", "no-store").send(rewriteGameHtml(gameId, source));
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

    // ── والملفّاتُ الكبيرة تُمرَّر تدفّقاً ──
    // بياناتُ لعبة Unity عشراتُ الميغابايتات. وكانت تُحمَّل كلُّها في ذاكرة الخادم
    // قبل أن يصل بايتٌ للطالب — فصفٌّ يفتح اللعبةَ معاً يملأ الذاكرة. ولا تتغيّر
    // بعد نشرها (أسماؤها ببصمتها)، فتُحفظ في الجهاز يوماً.
    res.set("Content-Type", getContentType(requestedPath, upstreamType));
    res.set("Cache-Control", "public, max-age=86400");
    // ── والحجمُ لا يُعلَن فوق ٣٠ ميغابايت ──
    // منصّةُ النشر (Cloud Run) تردّ ٥٠٠ فارغاً على ردٍّ يُعلن حجماً فوق ٣٢
    // ميغابايتاً — وبياناتُ «الروبوت الخارق» ٤٤. وبلا `Content-Length` يُرسل
    // الردُّ مقطّعاً (chunked)، وهذا لا حدَّ له.
    const length = Number(upstream.headers.get("content-length") ?? "");
    if (Number.isFinite(length) && length > 0 && length <= MAX_DECLARED_LENGTH) {
      res.set("Content-Length", String(length));
    }
    if (!upstream.body) {
      res.end();
      return;
    }
    Readable.fromWeb(upstream.body as unknown as WebReadableStream<Uint8Array>)
      .on("error", (error) => {
        logger.error({ err: error, gameId }, "Game asset stream error");
        res.destroy(error);
      })
      .pipe(res);
  } catch (error) {
    logger.error({ err: error }, "Game asset proxy error");
    res.status(502).send("Game asset proxy failed");
  }
});

export default router;
