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
const SYNC_KV_KEYS = new Set([
  "smartEdu_grades",
  "smartEdu_subjects",
  "smartEdu_terms",
  "smartEdu_atrams",
  "smartEdu_units",
  "smartEdu_hierarchicalConfigs",
  "smartEdu_gradeConfigs",
  "smartEdu_adminSettings",
  "smartEdu_permissions",
  "smartEdu_permissionPackages",
  "smartEdu_reports",
  "smartEdu_quizQuestions",
  "smartEdu_videos",
  "smartEdu_deletedVideos",
  "smartEdu_deletedLessons",
  "smartEdu_deletedQuizzes",
  "smartEdu_videoNotifications",
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

function isDeletedIdsKey(key: string): boolean {
  return key === DELETED_VIDEO_KEY ||
    key === "smartEdu_deletedLessons" ||
    key === "smartEdu_deletedQuizzes";
}

function canWriteKv(key: string, actor: NonNullable<ReturnType<typeof getContentActor>>): boolean {
  return actor.role === "admin" || key === VIDEO_KEY;
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

function rowBelongsToActor(
  row: Record<string, unknown>,
  actor: NonNullable<ReturnType<typeof getContentActor>>,
  table: string,
): boolean {
  if (actor.role === "admin") return true;
  const data = row.data && typeof row.data === "object"
    ? row.data as Record<string, unknown>
    : row;
  if (table === "teachers") {
    return stringValue(row.id) === actor.teacherId || stringValue(data.id) === actor.teacherId;
  }
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

router.get("/supabase/context", (req: Request, res: Response) => {
  const actor = getContentActor(req);
  if (!actor) {
    res.status(401).json({ error: "يجب تسجيل الدخول كمعلم أو مشرف لمزامنة البيانات" });
    return;
  }
  res.json(actor.role === "admin"
    ? { role: "admin", scope: "admin" }
    : { role: "teacher", teacherId: actor.teacherId, scope: `teacher:${actor.teacherId}` });
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
    const keys = Array.from(SYNC_KV_KEYS);
    const values = await Promise.all(keys.map(async (key) => ({ key, value: await readValue(config, key) })));
    res.json(values
      .filter(({ key }) => actor.role === "admin" || ![
        "smartEdu_adminSettings",
        "smartEdu_permissions",
        "smartEdu_permissionPackages",
        "smartEdu_reports",
      ].includes(key))
      .map(({ key, value }) => ({
        key,
        value: key === VIDEO_KEY && actor.role !== "admin"
          ? asRecords(value).filter((video) => recordOwner(video) === actor.teacherId)
          : key === DELETED_VIDEO_KEY
            ? mergeDeletedIds([], value)
            : value,
      })));
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

  let key = "";
  try {
    for (const row of rows as Array<{ key?: unknown; value?: unknown }>) {
      key = stringValue(row.key);
      // hydrateKv can batch unrelated legacy keys. This bridge owns the
      // shared keys. Unknown keys are ignored rather than persisted blindly.
      if (!SYNC_KV_KEYS.has(key)) continue;
      const remoteValue = await readValue(config, key);
      if (!canWriteKv(key, actor)) {
        res.status(403).json({ error: "لا يمكن للمعلم تعديل هذا الإعداد المشترك" });
        return;
      }
      const mergedValue = key === VIDEO_KEY
        ? actor.role === "admin"
          ? asRecords(row.value)
          : mergeTeacherVideos(remoteValue, row.value, actor.teacherId)
        : isDeletedIdsKey(key)
          ? mergeDeletedIds(remoteValue, row.value)
          : row.value;

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
    logger.error({ err: error, key }, "Failed to persist shared values to Supabase");
    res.status(502).json({ error: "تعذر حفظ الإعدادات المشتركة" });
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
      : rows.filter((row) => rowBelongsToActor(row, actor, table));
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
  const validRows = rows.filter((row) => stringValue(row.id) && rowBelongsToActor(row, actor, table));
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
      if (actor.role !== "admin" && remoteRows.some((row) => !rowBelongsToActor(row, actor, table))) {
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