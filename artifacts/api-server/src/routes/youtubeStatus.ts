import { Router, type Request, type Response } from "express";
import rateLimit from "express-rate-limit";
import { requireContentManager } from "../middleware/adminAuth";
import { forwardedClientKey } from "../middleware/rateLimiter";
import { YOUTUBE_ID, youtubeStatusFor, type YoutubeStatus } from "../lib/youtubeStatus";

/**
 * `GET /api/media/youtube-status?ids=a,b,c` — حالُ فيديوهات يوتيوب لمن يدير المحتوى.
 *
 * يسأل يوتيوب (oEmbed) عن كلٍّ منها، ويحفظ الجواب: المتاحُ ست ساعات، والمحذوفُ
 * ساعة (قد يعيده صاحبه)، والمجهولُ لا يُحفظ. خمسون معرّفاً في الطلب على الأكثر.
 */
const router = Router();

const limit = rateLimit({
  windowMs: 60_000,
  limit: 30,
  standardHeaders: "draft-8",
  legacyHeaders: false,
  keyGenerator: (req: Request) => forwardedClientKey(req),
});

const cache = new Map<string, { status: YoutubeStatus; until: number }>();
const TTL: Record<YoutubeStatus, number> = {
  available: 6 * 3_600_000,
  embed_blocked: 3_600_000,
  unavailable: 3_600_000,
  unknown: 0,
};

async function statusOf(id: string): Promise<YoutubeStatus> {
  const hit = cache.get(id);
  if (hit && hit.until > Date.now()) return hit.status;
  let status: YoutubeStatus = "unknown";
  try {
    const response = await fetch(
      `https://www.youtube.com/oembed?url=${encodeURIComponent(`https://www.youtube.com/watch?v=${id}`)}&format=json`,
      { signal: AbortSignal.timeout(6_000) },
    );
    status = youtubeStatusFor(response.status);
  } catch {
    status = "unknown";
  }
  if (TTL[status] > 0) cache.set(id, { status, until: Date.now() + TTL[status] });
  return status;
}

router.get("/media/youtube-status", limit, requireContentManager, async (req: Request, res: Response) => {
  const ids = String(req.query.ids ?? "")
    .split(",")
    .map((id) => id.trim())
    .filter((id) => YOUTUBE_ID.test(id));
  const unique = [...new Set(ids)].slice(0, 50);
  const entries = await Promise.all(unique.map(async (id) => [id, await statusOf(id)] as const));
  res.set("Cache-Control", "no-store").json({ statuses: Object.fromEntries(entries) });
});

export default router;
