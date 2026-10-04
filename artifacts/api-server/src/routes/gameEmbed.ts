import { Router } from "express";
import { Readable } from "node:stream";
import type { ReadableStream as WebReadableStream } from "node:stream/web";
import { logger } from "../lib/logger";
import {
  AD_SDK_PATH,
  DISABLED_AD_SDK,
  GAME_ID_PATTERN,
  GAME_PAGE_CSP,
  GAME_HOST,
  LEGACY_AD_SDK,
  LEGACY_GAME_IDS,
  catalogJson,
  isSafeGameAssetPath,
  resolveGameId,
  resolveRewrittenGameFile,
  rewriteGameHtml,
  rewriteGameScript,
} from "../lib/gameEmbed";

const router = Router();

/** أكبرُ ردٍّ يُعلَن حجمُه — دون حدّ منصّة النشر (٣٢ ميغابايت) بهامش. */
const MAX_DECLARED_LENGTH = 30 * 1024 * 1024;

router.get("/game-catalog", (_req, res) => {
  res.json({ games: catalogJson() });
});

/**
 * نوعُ الملف من امتداده أولاً، ثم ممّا أعلنه المصدر.
 *
 * مع `nosniff` لا يخمّن المتصفّح: نوعٌ عامٌّ (`binary/octet-stream`) على ملفّ أنماطٍ
 * أو wasm يُرفض. وخادمُ الألعاب يرسل أنواعاً عامّةً كهذه أحياناً — فالامتدادُ أصدق.
 */
const EXTENSION_TYPES: Record<string, string> = {
  ".js": "application/javascript; charset=utf-8",
  ".mjs": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".webmanifest": "application/manifest+json; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".wasm": "application/wasm",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".webp": "image/webp",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".mp3": "audio/mpeg",
  ".ogg": "audio/ogg",
  ".wav": "audio/wav",
  ".m4a": "audio/mp4",
  ".mp4": "video/mp4",
  ".webm": "video/webm",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".ttf": "font/ttf",
  ".otf": "font/otf",
  ".txt": "text/plain; charset=utf-8",
  ".xml": "application/xml; charset=utf-8",
};

function getContentType(pathname: string, upstreamType: string): string {
  const clean = pathname.split("?")[0].toLowerCase();
  const dot = clean.lastIndexOf(".");
  const known = dot >= 0 ? EXTENSION_TYPES[clean.slice(dot)] : undefined;
  if (known) return known;
  if (upstreamType) return upstreamType;
  return "application/octet-stream";
}

// Express 5 requires named wildcards — use *gameAssetPath
router.get("/game-embed/:gameId/*gameAssetPath", async (req, res) => {
  // لا تخمينَ لنوع أيِّ ردٍّ من هنا: يُعامَل بما أُعلن فقط. انظر getContentType.
  res.setHeader("X-Content-Type-Options", "nosniff");
  const { gameId: rawGameId, gameAssetPath: rawAssetPath } = req.params as Record<string, unknown>;
  // Express 5 named wildcards may be delivered as an array of segments
  const rawPath = Array.isArray(rawAssetPath)
    ? rawAssetPath.join("/")
    : (rawAssetPath || "index.html");

  // ── المدخلاتُ تُفحص كلُّها قبل أيّ طلبٍ أو ردّ ──
  // شكلٌ غير صالحٍ ← 400؛ ومعرّفٌ سليمُ الشكل خارج القائمة ← 404. ثم لا يُستعمل
  // إلا gameId الثابتُ من القائمة، وrequestedPath الذي اجتاز الفحص.
  if (typeof rawGameId !== "string" || !GAME_ID_PATTERN.test(rawGameId) || !isSafeGameAssetPath(rawPath)) {
    res.status(400).json({ error: "Invalid game asset request" });
    return;
  }
  const gameId = resolveGameId(rawGameId);
  if (!gameId) {
    res.status(404).json({ error: "Game not found" });
    return;
  }
  const requestedPath: string = rawPath;

  if (requestedPath === AD_SDK_PATH.slice(1)) {
    res
      .set("Content-Type", "application/javascript; charset=utf-8")
      .send(LEGACY_GAME_IDS.has(gameId) ? LEGACY_AD_SDK : DISABLED_AD_SDK);
    return;
  }

  try {
    // ── الملفّاتُ المُعادُ كتابتُها: مسارُها ومعرّفُها ثابتان من الكود ──
    // هذه وحدها تُبنى نصّاً وتُرسل (انظر REWRITTEN_GAME_FILES)؛ فلا يصل إليها
    // من الطلب شيءٌ إلا عبر مطابقةٍ تامّةٍ مع القائمة.
    const rewrittenFile = resolveRewrittenGameFile(gameId, requestedPath);
    if (rewrittenFile) {
      const upstream = await fetch(`${GAME_HOST}/${gameId}/${rewrittenFile}`);
      if (!upstream.ok) {
        res.status(upstream.status).json({ error: "Game asset request failed" });
        return;
      }
      const source = await upstream.text();
      const isPage = rewrittenFile.endsWith(".html");
      // يُكتب الردُّ مباشرةً (writeHead ثم end) بنوعه وحجمه. هذا لا يعقّم شيئاً:
      // المحتوى شيفرةُ اللعبة نفسُها ولا يُعقَّم دون أن تتعطّل. وما يحميه: مصدرٌ ثابتٌ
      // من القائمة (REWRITTEN_GAME_FILES)، وسياسةُ أمان المحتوى GAME_PAGE_CSP على الردّ.
      const body = Buffer.from(
        isPage ? rewriteGameHtml(gameId, source) : rewriteGameScript(gameId, source),
        "utf-8",
      );
      res.writeHead(200, {
        "Content-Type": isPage ? "text/html; charset=utf-8" : "application/javascript; charset=utf-8",
        "Cache-Control": "no-store",
        "Content-Security-Policy": GAME_PAGE_CSP,
        "Content-Length": body.byteLength,
      });
      res.end(body);
      return;
    }

    // ── وكلُّ ما سواها يُمرَّر كما هو، تدفّقاً ──
    // صفحاتُ الألعاب القديمة وسكربتاتُ لا تحتاج تعديلاً، وبياناتُ لعبة Unity
    // (عشراتُ الميغابايتات: كانت تُحمَّل كلُّها في الذاكرة قبل أن يصل بايتٌ للطالب).
    const upstream = await fetch(`${GAME_HOST}/${gameId}/${requestedPath}`);
    if (!upstream.ok) {
      res.status(upstream.status).json({ error: "Game asset request failed" });
      return;
    }
    const contentType = getContentType(requestedPath, upstream.headers.get("content-type") || "");
    res.set("Content-Type", contentType);
    if (/^(?:text\/html|application\/javascript)/.test(contentType)) {
      // الصفحاتُ والسكربتاتُ كما كانت: لا تُخزَّن، وسياسةُ أمان المحتوى عليها.
      res.set("Cache-Control", "no-store").set("Content-Security-Policy", GAME_PAGE_CSP);
    } else {
      // والبياناتُ لا تتغيّر بعد نشرها (أسماؤها ببصمتها)، فتُحفظ في الجهاز يوماً.
      res.set("Cache-Control", "public, max-age=86400");
    }
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
    res.status(502).json({ error: "Game asset proxy failed" });
  }
});

export default router;
