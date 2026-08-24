import { Router, type Request, type Response } from "express";
import { getContentActor } from "../middleware/adminAuth";
import { logger } from "../lib/logger";

const router = Router();

const VIDEO_KEY = "smartEdu_videos";
const DELETED_VIDEO_KEY = "smartEdu_deletedVideos";
const ROW_TABLES = new Set([
  "students",
  "parents",
  "teachers",
  "lesson_configs",
  "created_quizzes",
  "quiz_results",
  "interactions",
  "private_messages",
  "public_messages",
  "certificates",
]);

type SupabaseConfig = { url: string; serviceRoleKey: string };

function getSupabaseConfig(): SupabaseConfig | null {
  const url = process.env.SUPABASE_URL?.trim().replace(/\/+$/, "");
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  return url && serviceRoleKey ? { url, serviceRoleKey } : null;
}

function headers(config: SupabaseConfig, extra: Record<string, string> = {}): Record<string, string> {
  return {
    apikey: config.serviceRoleKey,
    Authorization: `Bearer ${config.serviceRoleKey}`,
    Accept: "application/json",
    ...extra,
  };
}

async function rest(
  config: SupabaseConfig,
  resource: string,
  init: RequestInit = {},
): Promise<unknown> {
  const response = await fetch(`${config.url}/rest/v1/${resource}`, {
    ...init,
    headers: headers(config, {
      ...(init.body ? { "Content-Type": "application/json" } : {}),
      ...(init.headers as Record<string, string> | undefined),
    }),
  });
  const text = await response.text();
  if (!response.ok) {
    throw new Error(text || `Supabase request failed (${response.status})`);
  }
  return text ? JSON.parse(text) : null;
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function recordOwner(value: unknown): string {
  if (!value || typeof value !== "object") return "";
  const record = value as Record<string, unknown>;
  return stringValue(record.teacher_id) ||
    stringValue(record.teacherId) ||
    stringValue(record.createdBy);
}

function asRecords(value: unknown): Record<string, unknown>[] {
  return Array.isArray(value)
    ? value.filter((item): item is Record<string, unknown> => Boolean(item) && typeof item === "object")
    : [];
}

function mergeTeacherVideos(
  remoteValue: unknown,
  requestedValue: unknown,
  teacherId: string,
): Record<string, unknown>[] {
  const remote = asRecords(remoteValue);
  const requested = asRecords(requestedValue);
  const requestedById = new Map(
    requested
      .filter((video) => recordOwner(video) === teacherId && stringValue(video.id))
      .map((video) => [stringValue(video.id), video]),
  );

  // Replace this teacher's known records only. Other teachers' videos must not
  // disappear when a browser has not hydrated the shared collection yet.
  const retained = remote.filter((video) => recordOwner(video) !== teacherId);
  return [...retained, ...requestedById.values()];
}

function mergeDeletedIds(remoteValue: unknown, requestedValue: unknown): string[] {
  return Array.from(new Set([
    ...(Array.isArray(remoteValue) ? remoteValue : []),
    ...(Array.isArray(requestedValue) ? requestedValue : []),
  ].map(stringValue).filter(Boolean)));
}

function recordIds(value: unknown): Set<string> {
  return new Set(
    asRecords(value)
      .map((record) => stringValue(record.id))
      .filter(Boolean),
  );
}

function tableName(req: Request): string {
  const table = stringValue(req.params.table);
  return ROW_TABLES.has(table) ? table : "";
}

function rowBelongsToActor(row: Record<string, unknown>, actor: NonNullable<ReturnType<typeof getContentActor>>): boolean {
  if (actor.role === "admin") return true;
  const data = row.data && typeof row.data === "object"
    ? row.data as Record<string, unknown>
    : row;
  const owner = recordOwner(data);
  return owner === actor.teacherId;
}

async function readValue(config: SupabaseConfig, key: string): Promise<unknown> {
  const rows = await rest(
    config,
    `app_kv?select=key,value&key=eq.${encodeURIComponent(key)}`,
  );
  return Array.isArray(rows) && rows[0] ? (rows[0] as { value?: unknown }).value : null;
}

router.get("/supabase/health", (_req, res) => {
  if (!getSupabaseConfig()) {
    res.status(503).json({ ready: false, error: "Supabase is not configured on the API server" });
    return;
  }
  res.json({ ready: true });
});

router.get("/supabase/app_kv", async (req: Request, res: Response) => {
  const actor = getContentActor(req);
  if (!actor) {
    res.status(401).json({ error: "يجب تسجيل الدخول كمعلم أو مشرف لمزامنة المحتوى" });
    return;
  }
  const config = getSupabaseConfig();
  if (!config) {
    res.status(503).json({ error: "Supabase is not configured on the API server" });
    return;
  }

  try {
    const videos = await readValue(config, VIDEO_KEY);
    const deletedVideoIds = await readValue(config, DELETED_VIDEO_KEY);
    const scopedVideos = actor.role === "admin"
      ? asRecords(videos)
      : asRecords(videos).filter((video) => recordOwner(video) === actor.teacherId);
    res.json([
      { key: VIDEO_KEY, value: scopedVideos },
      { key: DELETED_VIDEO_KEY, value: mergeDeletedIds([], deletedVideoIds) },
    ]);
  } catch (error) {
    logger.error({ err: error }, "Failed to load shared cinema videos from Supabase");
    res.status(502).json({ error: "تعذر تحميل فيديوهات السينما المشتركة" });
  }
});

router.post("/supabase/app_kv/upsert", async (req: Request, res: Response) => {
  const actor = getContentActor(req);
  if (!actor) {
    res.status(401).json({ error: "يجب تسجيل الدخول كمعلم أو مشرف لمزامنة المحتوى" });
    return;
  }
  const config = getSupabaseConfig();
  if (!config) {
    res.status(503).json({ error: "Supabase is not configured on the API server" });
    return;
  }

  const rows = Array.isArray(req.body?.rows) ? req.body.rows : [];
  if (!rows.length || rows.some((row: unknown) => !row || typeof row !== "object")) {
    res.status(400).json({ error: "صيغة طلب المزامنة غير صالحة" });
    return;
  }

  try {
    for (const row of rows as Array<{ key?: unknown; value?: unknown }>) {
      const key = stringValue(row.key);
      // hydrateKv can batch unrelated legacy keys. This bridge owns the
      // shared video keys; other app_kv keys continue using their own path.
      if (key !== VIDEO_KEY && key !== DELETED_VIDEO_KEY) continue;
      const remoteValue = await readValue(config, key);
      const mergedValue = key === VIDEO_KEY
        ? actor.role === "admin"
          ? asRecords(row.value)
          : mergeTeacherVideos(remoteValue, row.value, actor.teacherId)
        : mergeDeletedIds(remoteValue, row.value);

      await rest(config, "app_kv?on_conflict=key", {
        method: "POST",
        headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
        body: JSON.stringify({ key, value: mergedValue }),
      });

      // A saved live video is an explicit restore action. Clear only the
      // submitted live IDs from the tombstone list; deletion itself removes
      // records from smartEdu_videos, so this cannot revive a deleted record.
      if (key === VIDEO_KEY) {
        const submittedIds = recordIds(row.value);
        if (submittedIds.size) {
          const deletedIds = mergeDeletedIds(
            await readValue(config, DELETED_VIDEO_KEY),
            [],
          );
          const restoredDeletedIds = deletedIds.filter((id) => !submittedIds.has(id));
          if (restoredDeletedIds.length !== deletedIds.length) {
            await rest(config, "app_kv?on_conflict=key", {
              method: "POST",
              headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
              body: JSON.stringify({ key: DELETED_VIDEO_KEY, value: restoredDeletedIds }),
            });
          }
        }
      }
    }
    res.status(204).end();
  } catch (error) {
    logger.error({ err: error, key }, "Failed to persist shared cinema videos to Supabase");
    res.status(502).json({ error: "تعذر حفظ فيديوهات السينما المشتركة" });
  }
});

router.get("/supabase/:table", async (req: Request, res: Response) => {
  const actor = getContentActor(req);
  const table = tableName(req);
  if (!actor) {
    res.status(401).json({ error: "يجب تسجيل الدخول كمعلم أو مشرف لمزامنة البيانات" });
    return;
  }
  if (!table) {
    res.status(404).json({ error: "جدول المزامنة غير معروف" });
    return;
  }
  const config = getSupabaseConfig();
  if (!config) {
    res.status(503).json({ error: "Supabase is not configured on the API server" });
    return;
  }

  try {
    const rows = asRecords(await rest(config, `${table}?select=id,data`));
    const scopedRows = actor.role === "admin"
      ? rows
      : rows.filter((row) => rowBelongsToActor(row, actor));
    res.json(scopedRows);
  } catch (error) {
    logger.error({ err: error, table }, "Failed to load Supabase rows");
    res.status(502).json({ error: "تعذر تحميل البيانات المشتركة" });
  }
});

router.post("/supabase/:table/upsert", async (req: Request, res: Response) => {
  const actor = getContentActor(req);
  const table = tableName(req);
  if (!actor) {
    res.status(401).json({ error: "يجب تسجيل الدخول كمعلم أو مشرف لمزامنة البيانات" });
    return;
  }
  if (!table) {
    res.status(404).json({ error: "جدول المزامنة غير معروف" });
    return;
  }
  const config = getSupabaseConfig();
  if (!config) {
    res.status(503).json({ error: "Supabase is not configured on the API server" });
    return;
  }
  const rows = asRecords(req.body?.rows);
  const validRows = rows.filter((row) => stringValue(row.id) && rowBelongsToActor(row, actor));
  if (validRows.length !== rows.length) {
    res.status(403).json({ error: "لا يمكن للمعلم تعديل سجلات تخص مستخدمًا آخر" });
    return;
  }

  try {
    if (validRows.length) {
      await rest(config, `${table}?on_conflict=id`, {
        method: "POST",
        headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
        body: JSON.stringify(validRows.map((row) => ({ id: stringValue(row.id), data: row.data }))),
      });
    }
    res.status(204).end();
  } catch (error) {
    logger.error({ err: error, table }, "Failed to persist Supabase rows");
    res.status(502).json({ error: "تعذر حفظ البيانات المشتركة" });
  }
});

router.post("/supabase/:table/delete", async (req: Request, res: Response) => {
  const actor = getContentActor(req);
  const table = tableName(req);
  if (!actor) {
    res.status(401).json({ error: "يجب تسجيل الدخول كمعلم أو مشرف لمزامنة البيانات" });
    return;
  }
  if (!table) {
    res.status(404).json({ error: "جدول المزامنة غير معروف" });
    return;
  }
  const config = getSupabaseConfig();
  if (!config) {
    res.status(503).json({ error: "Supabase is not configured on the API server" });
    return;
  }
  const ids = Array.isArray(req.body?.ids) ? req.body.ids.map(stringValue).filter(Boolean) : [];

  try {
    if (ids.length) {
      const remoteRows = asRecords(await rest(config, `${table}?select=id,data&id=in.(${ids.map(encodeURIComponent).join(",")})`));
      if (actor.role !== "admin" && remoteRows.some((row) => !rowBelongsToActor(row, actor))) {
        res.status(403).json({ error: "لا يمكن للمعلم حذف سجلات تخص مستخدمًا آخر" });
        return;
      }
      await rest(config, `${table}?id=in.(${ids.map(encodeURIComponent).join(",")})`, {
        method: "DELETE",
        headers: { Prefer: "return=minimal" },
      });
    }
    res.status(204).end();
  } catch (error) {
    logger.error({ err: error, table }, "Failed to delete Supabase rows");
    res.status(502).json({ error: "تعذر حذف البيانات المشتركة" });
  }
});

export default router;