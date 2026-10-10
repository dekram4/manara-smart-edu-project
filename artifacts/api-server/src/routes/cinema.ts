import crypto from "node:crypto";
import { Router, type Request, type Response } from "express";
import rateLimit from "express-rate-limit";
import { getContentActor } from "../middleware/adminAuth";
import { requireStudentSession } from "../middleware/studentAuth";
import { forwardedClientKey } from "../middleware/rateLimiter";
import { logger } from "../lib/logger";
import type { StudentActor } from "../lib/studentAccess";
import {
  buildCinemaVideo,
  fromLegacyRecord,
  fromTableRow,
  isManagedBy,
  isVisibleToStudent,
  mergeCinemaVideos,
  publicCinemaVideo,
  toLegacyRecord,
  toTableRow,
  type CinemaVideo,
} from "../lib/cinema";
import {
  asRecords,
  listTeachers,
  readKv,
  rest,
  storeConfig,
  teacherIdentities,
  withTableFallback,
  writeKv,
  type StoreConfig,
} from "../lib/supabaseStore";
import { isCardOpenForStudent } from "./cardPermissions";

/**
 * سينما منارة: إدارتها من لوحة المعلم والمشرف، وعرضها للطالب.
 *
 * المصدر جدول `cinema_videos`، ومعه فيديوهاتُ `app_kv/smartEdu_videos` القديمة
 * حتى تُعدَّل أو تُحذف. وإن لم يُنشأ الجدول بعد فالمفتاح القديم وحده —
 * انظر `lib/supabaseStore.ts`.
 */
const router = Router();

const TABLE = "cinema_videos";
const VIDEO_KEY = "smartEdu_videos";
const DELETED_VIDEO_KEY = "smartEdu_deletedVideos";

const RATE_LIMIT_SHARED = {
  windowMs: 60_000,
  standardHeaders: "draft-8" as const,
  legacyHeaders: false,
  keyGenerator: (req: Request) => forwardedClientKey(req),
  message: { error: "تجاوزت الحد المسموح به من الطلبات. يرجى الانتظار دقيقة." },
};
const cinemaReadLimit = rateLimit({ ...RATE_LIMIT_SHARED, limit: 120 });
const cinemaWriteLimit = rateLimit({ ...RATE_LIMIT_SHARED, limit: 30 });

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

async function readDeletedIds(config: StoreConfig): Promise<string[]> {
  const value = await readKv(config, DELETED_VIDEO_KEY);
  return Array.isArray(value) ? value.map(text).filter(Boolean) : [];
}

async function readLegacyVideos(config: StoreConfig): Promise<CinemaVideo[]> {
  return asRecords(await readKv(config, VIDEO_KEY))
    .map(fromLegacyRecord)
    .filter((video): video is CinemaVideo => Boolean(video));
}

/** كلُّ فيديوهات السينما: الجدول والمفتاح القديم، بلا المحذوف. */
async function loadCinemaVideos(
  config: StoreConfig,
): Promise<{ videos: CinemaVideo[]; storage: "table" | "kv" }> {
  const [legacy, deleted, table] = await Promise.all([
    readLegacyVideos(config),
    readDeletedIds(config),
    withTableFallback(
      TABLE,
      async () => asRecords(await rest(config, `${TABLE}?select=*&order=created_at.desc&limit=5000`))
        .map(fromTableRow)
        .filter((video): video is CinemaVideo => Boolean(video)),
      async () => [] as CinemaVideo[],
    ),
  ]);
  return { videos: mergeCinemaVideos(table.value, legacy, deleted), storage: table.storage };
}

async function removeFromLegacy(config: StoreConfig, id: string): Promise<void> {
  const records = asRecords(await readKv(config, VIDEO_KEY));
  const kept = records.filter((record) => text(record.id) !== id);
  if (kept.length !== records.length) await writeKv(config, VIDEO_KEY, kept);
}

async function saveCinemaVideo(config: StoreConfig, video: CinemaVideo): Promise<"table" | "kv"> {
  const { storage } = await withTableFallback(
    TABLE,
    async () => {
      await rest(config, `${TABLE}?on_conflict=id`, {
        method: "POST",
        headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
        body: JSON.stringify(toTableRow(video)),
      });
      // فيديو قديم عُدّل: صار في الجدول، فلا تبقى نسختُه القديمة تُقرأ.
      if (video.legacy) await removeFromLegacy(config, video.id);
    },
    async () => {
      const records = asRecords(await readKv(config, VIDEO_KEY));
      const record = toLegacyRecord(video);
      const index = records.findIndex((item) => text(item.id) === video.id);
      if (index >= 0) records[index] = record;
      else records.push(record);
      await writeKv(config, VIDEO_KEY, records);
    },
  );
  return storage;
}

async function deleteCinemaVideo(config: StoreConfig, id: string): Promise<void> {
  await withTableFallback(
    TABLE,
    async () => {
      await rest(config, `${TABLE}?id=eq.${encodeURIComponent(id)}`, {
        method: "DELETE",
        headers: { Prefer: "return=minimal" },
      });
    },
    async () => undefined,
  );
  await removeFromLegacy(config, id);
  // شاهدُ الحذف: نسخةُ متصفّحٍ قديمة أو تطبيقٌ قديم لا يُعيد الفيديو.
  const deleted = await readDeletedIds(config);
  if (!deleted.includes(id)) await writeKv(config, DELETED_VIDEO_KEY, [...deleted, id]);
}

// ── لوحة المعلم والمشرف ─────────────────────────────────────────────────

router.use("/cinema", cinemaReadLimit);

router.get("/cinema/videos", async (req: Request, res: Response) => {
  const actor = getContentActor(req);
  if (!actor) {
    res.status(401).json({ error: "يجب تسجيل الدخول كمعلم أو مشرف" });
    return;
  }
  const config = storeConfig();
  if (!config) {
    res.status(503).json({ error: "Supabase غير مُعدّ على الخادم" });
    return;
  }
  try {
    const identities = actor.role === "teacher"
      ? await teacherIdentities(config, actor.teacherId)
      : new Set<string>();
    const { videos, storage } = await loadCinemaVideos(config);
    const teachers = actor.role === "admin" ? await listTeachers(config) : [];
    res.json({
      storage,
      teachers,
      videos: videos
        .filter((video) => isManagedBy(video, actor, identities))
        .map(publicCinemaVideo),
    });
  } catch (error) {
    logger.error({ err: error }, "[cinema] list failed");
    res.status(502).json({ error: "تعذر تحميل فيديوهات السينما" });
  }
});

router.post("/cinema/videos", cinemaWriteLimit, async (req: Request, res: Response) => {
  const actor = getContentActor(req);
  if (!actor) {
    res.status(401).json({ error: "يجب تسجيل الدخول كمعلم أو مشرف" });
    return;
  }
  const config = storeConfig();
  if (!config) {
    res.status(503).json({ error: "Supabase غير مُعدّ على الخادم" });
    return;
  }
  const body = (req.body && typeof req.body === "object" ? req.body : {}) as Record<string, unknown>;
  try {
    const identities = actor.role === "teacher"
      ? await teacherIdentities(config, actor.teacherId)
      : new Set<string>();
    const requestedId = text(body.id);
    let existing: CinemaVideo | null = null;
    if (requestedId) {
      const { videos } = await loadCinemaVideos(config);
      existing = videos.find((video) => video.id === requestedId) ?? null;
      if (existing && !isManagedBy(existing, actor, identities)) {
        res.status(403).json({ error: "لا يمكن تعديل فيديو يخص معلمًا آخر" });
        return;
      }
    }
    const built = buildCinemaVideo(body, actor, {
      newId: () => crypto.randomUUID(),
      existing,
      actorIdentities: identities,
    });
    if (!built.ok) {
      res.status(built.status).json({ error: built.error });
      return;
    }
    const storage = await saveCinemaVideo(config, built.video);
    res.status(existing ? 200 : 201).json({ storage, video: publicCinemaVideo(built.video) });
  } catch (error) {
    logger.error({ err: error }, "[cinema] save failed");
    res.status(502).json({ error: "تعذر حفظ فيديو السينما" });
  }
});

router.delete("/cinema/videos/:id", cinemaWriteLimit, async (req: Request, res: Response) => {
  const actor = getContentActor(req);
  if (!actor) {
    res.status(401).json({ error: "يجب تسجيل الدخول كمعلم أو مشرف" });
    return;
  }
  const config = storeConfig();
  if (!config) {
    res.status(503).json({ error: "Supabase غير مُعدّ على الخادم" });
    return;
  }
  const id = text(req.params.id);
  if (!id || id.length > 200) {
    res.status(400).json({ error: "معرّف الفيديو غير صالح" });
    return;
  }
  try {
    const identities = actor.role === "teacher"
      ? await teacherIdentities(config, actor.teacherId)
      : new Set<string>();
    const { videos } = await loadCinemaVideos(config);
    const video = videos.find((item) => item.id === id);
    if (!video) {
      res.status(204).end();
      return;
    }
    if (!isManagedBy(video, actor, identities)) {
      res.status(403).json({ error: "لا يمكن حذف فيديو يخص معلمًا آخر" });
      return;
    }
    await deleteCinemaVideo(config, id);
    res.status(204).end();
  } catch (error) {
    logger.error({ err: error }, "[cinema] delete failed");
    res.status(502).json({ error: "تعذر حذف فيديو السينما" });
  }
});

// ── تطبيق الطالب ─────────────────────────────────────────────────────────

/**
 * فيديوهات صفّ الطالب من معلّمه — أيّاً كانت المادة أو الدرس المفتوح.
 *
 * الصفّ والمعلم من سجلّ الطالب على الخادم لا من الطلب: لا يطلب طالبٌ
 * فيديوهات صفٍّ آخر بتغيير معامل.
 */
router.get(
  "/student/cinema",
  cinemaReadLimit,
  requireStudentSession,
  async (_req: Request, res: Response) => {
    const student = res.locals.student as StudentActor;
    const config = storeConfig();
    if (!config) {
      res.status(503).json({ error: "Supabase غير مُعدّ على الخادم" });
      return;
    }
    try {
      const identities = await teacherIdentities(config, student.teacherId);
      if (!(await isCardOpenForStudent(config, student, identities, "cinema"))) {
        res.status(403).json({
          error: "عذراً، ليس لديك صلاحية لهذه البطاقة، يرجى مراجعة المشرف أو المعلم",
          code: "card_locked",
        });
        return;
      }
      const { videos } = await loadCinemaVideos(config);
      res.json({
        grade: student.grade,
        videos: videos
          .filter((video) => isVisibleToStudent(video, {
            grade: student.grade,
            teacherIdentities: identities,
          }))
          .map(publicCinemaVideo),
      });
    } catch (error) {
      logger.error({ err: error }, "[cinema] student list failed");
      res.status(502).json({ error: "تعذر تحميل فيديوهات السينما" });
    }
  },
);

export default router;
