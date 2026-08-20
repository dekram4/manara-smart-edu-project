import { Router } from "express";
import express from "express";
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";
import {
  getContentActor,
  requireAdmin,
  requireContentManager,
  type ContentActor,
} from "../middleware/adminAuth";
import { logger } from "../lib/logger";

const router = Router();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// Keep this directory only as a read/delete fallback for videos uploaded before
// Supabase Storage was enabled. New uploads must use durable remote storage.
export const uploadDirectory = path.resolve(
  __dirname,
  "../../../uploads/videos",
);
fs.mkdirSync(uploadDirectory, { recursive: true });

const legacyUploadDirectories = [
  path.resolve(__dirname, "../../../smart-edu-project/uploads/videos"),
];

function videoFilePath(fileName: string): string {
  const primaryPath = path.join(uploadDirectory, fileName);
  if (fs.existsSync(primaryPath)) return primaryPath;

  for (const directory of legacyUploadDirectories) {
    const legacyPath = path.join(directory, fileName);
    if (fs.existsSync(legacyPath)) return legacyPath;
  }

  return primaryPath;
}

type UploadOwner = {
  role: ContentActor["role"];
  teacherId?: string;
};

function supabaseStorageConfig(): { url: string; key: string; bucket: string } | null {
  const url = process.env.SUPABASE_URL?.trim().replace(/\/+$/, "");
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  const bucket = (process.env.SUPABASE_VIDEO_BUCKET || "lesson-videos").trim();
  return url && key && bucket ? { url, key, bucket } : null;
}

function supabaseHeaders(
  key: string,
  extra: Record<string, string> = {},
): Record<string, string> {
  return {
    apikey: key,
    Authorization: `Bearer ${key}`,
    "x-client-info": "supabase-js/2.112.3",
    ...extra,
  };
}

function storageObjectUrl(config: { url: string; bucket: string }, objectPath: string): string {
  return `${config.url}/storage/v1/object/public/${encodeURIComponent(config.bucket)}/${objectPath
    .split("/")
    .map(encodeURIComponent)
    .join("/")}`;
}

function localPublicVideoUrl(req: import("express").Request, fileName: string): string {
  const origin = req.get("origin")?.trim();
  if (!origin) return `/api/media/videos/${fileName}`;
  try {
    const base = new URL(origin);
    if (base.protocol === "http:" || base.protocol === "https:") {
      return new URL(`/api/media/videos/${fileName}`, base.origin).toString();
    }
  } catch {
    // Keep a portable relative URL when the browser origin is unavailable.
  }
  return `/api/media/videos/${fileName}`;
}

async function uploadToSupabase(
  config: { url: string; key: string; bucket: string },
  objectPath: string,
  body: Buffer,
): Promise<string> {
  const response = await fetch(
    `${config.url}/storage/v1/object/${encodeURIComponent(config.bucket)}/${objectPath
      .split("/")
      .map(encodeURIComponent)
      .join("/")}`,
    {
      method: "POST",
      headers: supabaseHeaders(config.key, {
        "Content-Type": "video/mp4",
        "x-upsert": "false",
      }),
      body,
    },
  );
  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    throw new Error(
      detail
        ? `تعذر حفظ الفيديو في التخزين الدائم: ${detail.slice(0, 240)}`
        : "تعذر حفظ الفيديو في التخزين الدائم",
    );
  }
  return storageObjectUrl(config, objectPath);
}

type SupabaseConfig = { url: string; key: string; bucket: string };

async function supabaseRest(
  config: SupabaseConfig,
  resource: string,
  init: RequestInit = {},
): Promise<any> {
  const response = await fetch(`${config.url}/rest/v1/${resource}`, {
    ...init,
    headers: {
      apikey: config.key,
      Authorization: `Bearer ${config.key}`,
      Accept: "application/json",
      ...(init.body ? { "Content-Type": "application/json" } : {}),
      ...init.headers,
    },
  });
  const text = await response.text().catch(() => "");
  let body: any = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }
  if (!response.ok) {
    const detail = typeof body === "string" ? body : body?.message || body?.hint;
    throw new Error(detail ? `Supabase: ${detail.slice(0, 240)}` : `Supabase REST error (${response.status})`);
  }
  return body;
}

function localVideoName(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const raw = value.trim();
  const match = raw.match(/(?:^|\/)(?:api\/)?(?:uploads\/videos|media\/videos)\/([a-zA-Z0-9-]+\.mp4)$/i);
  return match?.[1] || null;
}

function replaceLegacyVideoUrls(value: any, replacements: Map<string, string>): { value: any; count: number } {
  let count = 0;
  if (typeof value === "string") {
    const fileName = localVideoName(value);
    if (fileName && replacements.has(fileName)) {
      return { value: replacements.get(fileName), count: 1 };
    }
    return { value, count: 0 };
  }
  if (Array.isArray(value)) {
    const next = value.map((item) => {
      const result = replaceLegacyVideoUrls(item, replacements);
      count += result.count;
      return result.value;
    });
    return { value: next, count };
  }
  if (value && typeof value === "object") {
    const next: Record<string, any> = {};
    for (const [key, item] of Object.entries(value)) {
      const result = replaceLegacyVideoUrls(item, replacements);
      count += result.count;
      next[key] = result.value;
    }
    return { value: next, count };
  }
  return { value, count };
}

type MigrationFileReport = {
  fileName: string;
  path: string;
  size: number;
  status: "planned" | "migrated" | "already_migrated" | "unreferenced" | "failed";
  url?: string;
  references?: number;
  error?: string;
};

async function listLegacyVideoFiles(): Promise<{ fileName: string; filePath: string; size: number }[]> {
  const files = new Map<string, { fileName: string; filePath: string; size: number }>();
  for (const directory of [uploadDirectory, ...legacyUploadDirectories]) {
    const entries = await fs.promises.readdir(directory, { withFileTypes: true }).catch(() => []);
    for (const entry of entries) {
      if (!entry.isFile() || !/^[a-zA-Z0-9-]+\.mp4$/i.test(entry.name)) continue;
      const filePath = path.join(directory, entry.name);
      const stat = await fs.promises.stat(filePath).catch(() => null);
      if (stat?.isFile()) files.set(entry.name, { fileName: entry.name, filePath, size: stat.size });
    }
  }
  return [...files.values()];
}

async function migrateFileToSupabase(
  config: SupabaseConfig,
  file: { fileName: string; filePath: string },
): Promise<{ url: string; alreadyExists: boolean }> {
  const objectPath = `videos/admin/legacy-${file.fileName}`;
  const url = storageObjectUrl(config, objectPath);
  const existing = await fetch(url, {
    method: "HEAD",
    headers: { apikey: config.key, Authorization: `Bearer ${config.key}` },
  }).catch(() => null);
  if (existing?.ok) return { url, alreadyExists: true };

  const body = await fs.promises.readFile(file.filePath);
  const response = await fetch(
    `${config.url}/storage/v1/object/${encodeURIComponent(config.bucket)}/${objectPath
      .split("/")
      .map(encodeURIComponent)
      .join("/")}`,
    {
      method: "POST",
      headers: {
        apikey: config.key,
        Authorization: `Bearer ${config.key}`,
        "Content-Type": "video/mp4",
        "x-upsert": "true",
      },
      body,
    },
  );
  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    throw new Error(detail ? detail.slice(0, 240) : `HTTP ${response.status}`);
  }
  return { url, alreadyExists: false };
}

function countLegacyVideoUrls(value: any, knownFiles: Set<string>): number {
  if (typeof value === "string") return localVideoName(value) && knownFiles.has(localVideoName(value)!) ? 1 : 0;
  if (Array.isArray(value)) return value.reduce((total, item) => total + countLegacyVideoUrls(item, knownFiles), 0);
  if (value && typeof value === "object") {
    return Object.values(value).reduce<number>(
      (total, item) => total + countLegacyVideoUrls(item, knownFiles),
      0,
    );
  }
  return 0;
}

async function ensureSupabaseBucket(config: {
  url: string;
  key: string;
  bucket: string;
}): Promise<void> {
  const headers = supabaseHeaders(config.key);
  const existing = await fetch(
    `${config.url}/storage/v1/bucket/${encodeURIComponent(config.bucket)}`,
    { headers },
  );
  if (existing.ok) return;
  const existingDetail = await existing.text().catch(() => "");
  const bucketMissing =
    existing.status === 404 || existingDetail.includes("NoSuchBucket");
  if (!bucketMissing) {
    throw new Error("تعذر التحقق من إعداد تخزين الفيديو");
  }

  const created = await fetch(`${config.url}/storage/v1/bucket`, {
    method: "POST",
    headers: supabaseHeaders(config.key, { "Content-Type": "application/json" }),
    body: JSON.stringify({
      id: config.bucket,
      name: config.bucket,
      public: true,
      allowed_mime_types: ["video/mp4"],
    }),
  });
  if (!created.ok && created.status !== 409) {
    throw new Error("تعذر إنشاء مساحة تخزين الفيديو العامة");
  }
}

async function deleteFromSupabase(
  config: { url: string; key: string; bucket: string },
  objectPath: string,
): Promise<void> {
  const response = await fetch(`${config.url}/storage/v1/object/${encodeURIComponent(config.bucket)}`, {
    method: "DELETE",
    headers: supabaseHeaders(config.key, {
      "Content-Type": "application/json",
    }),
    body: JSON.stringify({ prefixes: [objectPath] }),
  });
  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    throw new Error(detail || "تعذر حذف الفيديو من التخزين الدائم");
  }
}

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

// GET /api/media/videos/:fileName — legacy local-media compatibility route
router.get("/media/videos/:fileName", (req, res) => {
  const fileName = String(req.params.fileName || "");
  if (!/^[a-zA-Z0-9-]+\.mp4$/.test(fileName)) {
    return res.status(400).json({ error: "اسم ملف فيديو غير صالح" });
  }
  const filePath = videoFilePath(fileName);
  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: "ملف الفيديو غير موجود" });
  }
  return res.sendFile(filePath);
});

// POST /api/media/migrate-legacy — admin-only migration for pre-Supabase MP4 files.
// dryRun defaults to true so an accidental request cannot change content.
router.post("/media/migrate-legacy", requireAdmin, async (req, res) => {
  const storage = supabaseStorageConfig();
  if (!storage) {
    return res.status(503).json({
      error: "لم يتم إعداد التخزين الدائم للفيديو. أضف إعدادات Supabase للخادم.",
    });
  }

  const dryRun = req.body?.dryRun !== false;
  try {
    if (!dryRun) await ensureSupabaseBucket(storage);
    const files = await listLegacyVideoFiles();
    const knownFiles = new Set(files.map((file) => file.fileName));
    let lessonRows: any;
    let kvRows: any;
    try {
      [lessonRows, kvRows] = await Promise.all([
        supabaseRest(storage, "lesson_configs?select=id,data"),
        supabaseRest(storage, "app_kv?select=key,value"),
      ]);
    } catch (error: any) {
      const filesReport: MigrationFileReport[] = files.map((file) => ({
        fileName: file.fileName,
        path: file.filePath,
        size: file.size,
        status: "failed",
        url: storageObjectUrl(storage, `videos/admin/legacy-${file.fileName}`),
        error: "تعذر قراءة سجلات الدروس من Supabase قبل الترحيل",
      }));
      return res.status(502).json({
        dryRun,
        bucket: storage.bucket,
        scanned: filesReport.length,
        migrated: 0,
        failed: filesReport.length,
        updatedLessonConfigs: 0,
        updatedVideoCollections: 0,
        files: filesReport,
        error: error?.message || "تعذر الاتصال بقاعدة بيانات Supabase",
        warning: "لم يتم رفع أو تعديل أي ملف. أصلح إعدادات Supabase ثم أعد تشغيل المعاينة.",
      });
    }
    const lessons = Array.isArray(lessonRows) ? lessonRows : [];
    const kv = Array.isArray(kvRows) ? kvRows : [];
    const contentRows = [
      ...lessons.map((row: any) => ({ source: "lesson_configs" as const, row })),
      ...kv
        .filter((row: any) => row?.key === "smartEdu_videos")
        .map((row: any) => ({ source: "app_kv" as const, row })),
    ];

    const reports: MigrationFileReport[] = files.map((file) => ({
      fileName: file.fileName,
      path: file.filePath,
      size: file.size,
      status: "planned",
      references: contentRows.reduce(
        (total, entry) => total + countLegacyVideoUrls(entry.row?.data ?? entry.row?.value, new Set([file.fileName])),
        0,
      ),
    }));
    const replacements = new Map<string, string>();

    for (const report of reports) {
      const file = files.find((item) => item.fileName === report.fileName)!;
      const objectPath = `videos/admin/legacy-${file.fileName}`;
      const plannedUrl = storageObjectUrl(storage, objectPath);
      report.url = plannedUrl;
      if (dryRun) continue;
      try {
        const result = await migrateFileToSupabase(storage, file);
        replacements.set(file.fileName, result.url);
        report.url = result.url;
        report.status = result.alreadyExists
          ? "already_migrated"
          : report.references
            ? "migrated"
            : "unreferenced";
      } catch (error: any) {
        report.status = "failed";
        report.error = error?.message || "تعذر نقل الملف";
      }
    }

    let updatedLessonConfigs = 0;
    let updatedVideoCollections = 0;
    if (!dryRun && replacements.size) {
      for (const row of lessons) {
        const result = replaceLegacyVideoUrls(row.data, replacements);
        if (!result.count) continue;
        await supabaseRest(
          storage,
          `lesson_configs?id=eq.${encodeURIComponent(String(row.id))}`,
          {
            method: "PATCH",
            headers: { Prefer: "return=minimal" },
            body: JSON.stringify({ data: result.value }),
          },
        );
        updatedLessonConfigs += 1;
      }
      for (const row of kv.filter((item: any) => item?.key === "smartEdu_videos")) {
        const result = replaceLegacyVideoUrls(row.value, replacements);
        if (!result.count) continue;
        await supabaseRest(
          storage,
          `app_kv?key=eq.${encodeURIComponent(String(row.key))}`,
          {
            method: "PATCH",
            headers: { Prefer: "return=minimal" },
            body: JSON.stringify({ value: result.value }),
          },
        );
        updatedVideoCollections += 1;
      }
    }

    const failed = reports.filter((report) => report.status === "failed");
    return res.json({
      dryRun,
      bucket: storage.bucket,
      scanned: reports.length,
      migrated: reports.filter((report) => report.status === "migrated").length,
      alreadyMigrated: reports.filter((report) => report.status === "already_migrated").length,
      unreferenced: reports.filter((report) => report.status === "unreferenced").length,
      failed: failed.length,
      updatedLessonConfigs,
      updatedVideoCollections,
      files: reports,
      warning: failed.length ? "بعض الملفات لم تُنقل؛ راجع قائمة files وأعد تشغيل الترحيل بعد معالجة السبب." : undefined,
    });
  } catch (error: any) {
    logger.error({ err: error }, "[media] legacy migration failed");
    return res.status(500).json({
      error: error?.message || "تعذر تنفيذ ترحيل فيديوهات الدروس القديمة",
    });
  }
});

// POST /api/media/upload — save video to Supabase Storage (raw body)
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
    const storage = supabaseStorageConfig();
    const actor = res.locals.contentActor as ContentActor;
    const fileName = `${crypto.randomUUID()}.mp4`;
    const ownerKey = actor.role === "admin"
      ? "admin"
      : crypto.createHmac("sha256", process.env.SESSION_SECRET || "manara")
          .update(actor.teacherId)
          .digest("hex")
          .slice(0, 24);

    if (storage) {
      const storagePath = `videos/${ownerKey}/${fileName}`;
      try {
        await ensureSupabaseBucket(storage);
        const url = await uploadToSupabase(storage, storagePath, req.body as Buffer);
        return res.status(201).json({
          url,
          fileName: originalName,
          size: (req.body as Buffer).length,
          contentType: "video/mp4",
          storage: "supabase",
          storagePath,
        });
      } catch (error: any) {
        logger.warn(
          { err: error },
          "[media] durable storage unavailable; using local fallback",
        );
      }
    }

    await fs.promises.writeFile(
      path.join(uploadDirectory, fileName),
      req.body as Buffer,
    );
    await writeOwner(fileName, actor);
    return res.status(201).json({
      url: localPublicVideoUrl(req, fileName),
      fileName: originalName,
      size: (req.body as Buffer).length,
      contentType: "video/mp4",
      storage: "local",
      warning:
        "تمت إضافة الفيديو، لكن التخزين الدائم غير متاح حاليًا؛ سيعمل الفيديو الآن وقد تحتاج الإدارة إلى إعادة رفعه بعد إصلاح إعداد Supabase Storage.",
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
  try {
    const actor = getContentActor(req);
    const storage = supabaseStorageConfig();
    let remotePath: string | null = null;
    if (storage) {
      try {
        const parsed = new URL(rawUrl);
        const prefix = `/storage/v1/object/public/${storage.bucket}/`;
        if (parsed.origin === storage.url && parsed.pathname.startsWith(prefix)) {
          remotePath = decodeURIComponent(parsed.pathname.slice(prefix.length));
        }
      } catch {
        // Fall through to legacy local URL handling.
      }
    }
    if (remotePath) {
      if (!remotePath.startsWith("videos/") || !/^videos\/[a-zA-Z0-9_-]+\/[a-zA-Z0-9-]+\.mp4$/.test(remotePath)) {
        return res.status(400).json({ error: "مسار ملف غير صالح" });
      }
      const ownerKey = remotePath.split("/")[1];
      const teacherKey = actor?.role === "teacher"
        ? crypto.createHmac("sha256", process.env.SESSION_SECRET || "manara")
            .update(actor.teacherId)
            .digest("hex")
            .slice(0, 24)
        : "";
      if (actor?.role !== "admin" && ownerKey !== teacherKey) {
        return res.status(403).json({ error: "لا تملك صلاحية حذف هذا الملف" });
      }
      await deleteFromSupabase(storage!, remotePath);
      return res.status(204).end();
    }
    if (!localMatch) {
      return res.status(400).json({ error: "مسار ملف غير صالح" });
    }
    const filePath = videoFilePath(localMatch[1]);
    if (![uploadDirectory, ...legacyUploadDirectories].some((directory) =>
      filePath.startsWith(`${directory}${path.sep}`))) {
      return res.status(400).json({ error: "مسار ملف غير صالح" });
    }
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
