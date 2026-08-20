import { Router } from "express";
import express from "express";
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";
import {
  getContentActor,
  requireContentManager,
  type ContentActor,
} from "../middleware/adminAuth";
import { logger } from "../lib/logger";

const router = Router();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// Store uploads at workspace root so they survive api-server rebuilds
export const uploadDirectory = path.resolve(
  __dirname,
  "../../../../uploads/videos",
);
fs.mkdirSync(uploadDirectory, { recursive: true });

type UploadOwner = {
  role: ContentActor["role"];
  teacherId?: string;
};

function ownerFilePath(fileName: string): string {
  return path.join(uploadDirectory, `${fileName}.owner.json`);
}

async function writeOwner(fileName: string, actor: ContentActor): Promise<void> {
  const owner: UploadOwner =
    actor.role === "admin"
      ? { role: "admin" }
      : { role: "teacher", teacherId: actor.teacherId };
  await fs.promises.writeFile(ownerFilePath(fileName), JSON.stringify(owner), "utf8");
}

async function readOwner(fileName: string): Promise<UploadOwner | null> {
  try {
    const raw = await fs.promises.readFile(ownerFilePath(fileName), "utf8");
    const owner = JSON.parse(raw) as UploadOwner;
    if (
      owner?.role === "admin" ||
      (owner?.role === "teacher" &&
        typeof owner.teacherId === "string" &&
        owner.teacherId.trim())
    ) {
      return owner;
    }
  } catch {
    // Files uploaded before owner tracking are administered by the admin only.
  }
  return null;
}

// GET /api/media/videos/:fileName — serve from local uploads
router.get("/media/videos/:fileName", (req, res) => {
  const fileName = String(req.params.fileName || "");
  if (!/^[a-zA-Z0-9-]+\.mp4$/.test(fileName)) {
    return res.status(400).json({ error: "اسم ملف فيديو غير صالح" });
  }
  const filePath = path.join(uploadDirectory, fileName);
  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: "ملف الفيديو غير موجود" });
  }
  return res.sendFile(filePath);
});

// POST /api/media/upload — save video to local disk (raw body)
const rawVideoParser = express.raw({
  type: ["video/mp4", "application/octet-stream"],
  limit: "500mb",
});

router.post("/media/upload", requireContentManager, rawVideoParser, async (req, res) => {
  if (!Buffer.isBuffer(req.body) || (req.body as Buffer).length === 0) {
    return res.status(400).json({ error: "لم يتم اختيار ملف MP4" });
  }
  const contentType = String(req.headers["content-type"] || "")
    .split(";")[0]
    .toLowerCase();
  const originalName = String(req.headers["x-file-name"] || "video.mp4");
  if (
    contentType !== "video/mp4" &&
    path.extname(originalName).toLowerCase() !== ".mp4"
  ) {
    return res.status(400).json({ error: "يسمح برفع ملفات MP4 فقط" });
  }
  try {
    const fileName = `${crypto.randomUUID()}.mp4`;
    const filePath = path.join(uploadDirectory, fileName);
    await fs.promises.writeFile(filePath, req.body as Buffer);
    const actor = res.locals.contentActor as ContentActor;
    await writeOwner(fileName, actor);
    // Use /api/media/videos/ so the browser fetches through the API artifact.
    // A bare /uploads/videos/ path is caught by the web artifact's SPA rewrite.
    const url = `/api/media/videos/${fileName}`;
    return res.status(201).json({
      url,
      fileName: originalName,
      size: (req.body as Buffer).length,
      contentType: "video/mp4",
      storage: "local",
      warning:
        "تم حفظ الفيديو مؤقتًا على خادم التطبيق. سيتم نقله إلى Supabase Storage لاحقًا.",
    });
  } catch (error: any) {
    logger.error({ err: error }, "[media] upload failed");
    return res
      .status(500)
      .json({ error: error?.message || "تعذر حفظ ملف الفيديو" });
  }
});

// POST /api/media/delete
router.post("/media/delete", requireContentManager, async (req, res) => {
  const rawUrl = typeof req.body?.url === "string" ? req.body.url : "";
  // Accept both the new API-routed URL and the legacy /uploads/videos/ path
  const localMatch =
    rawUrl.match(/^\/api\/media\/videos\/([a-zA-Z0-9-]+\.mp4)$/) ||
    rawUrl.match(/^\/uploads\/videos\/([a-zA-Z0-9-]+\.mp4)$/);
  if (!localMatch) {
    return res.status(400).json({ error: "مسار ملف غير صالح" });
  }
  const filePath = path.join(uploadDirectory, localMatch[1]);
  if (!filePath.startsWith(`${uploadDirectory}${path.sep}`)) {
    return res.status(400).json({ error: "مسار ملف غير صالح" });
  }
  try {
    const actor = getContentActor(req);
    const owner = await readOwner(localMatch[1]);
    if (
      actor?.role !== "admin" &&
      (!owner || owner.role !== "teacher" || owner.teacherId !== actor?.teacherId)
    ) {
      return res.status(403).json({ error: "لا تملك صلاحية حذف هذا الملف" });
    }
    await fs.promises.unlink(filePath);
    await fs.promises.unlink(ownerFilePath(localMatch[1])).catch(() => {});
  } catch (error: any) {
    if (error?.code !== "ENOENT") {
      return res.status(500).json({ error: "تعذر حذف ملف الفيديو" });
    }
  }
  return res.status(204).end();
});

export default router;
