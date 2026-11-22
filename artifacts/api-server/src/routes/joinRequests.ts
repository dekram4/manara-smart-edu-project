import { Router } from "express";
import crypto from "node:crypto";
import { requireAdmin } from "../middleware/adminAuth";
import { createRateLimit } from "../middleware/rateLimiter";
import { apiSupabaseConfig } from "../lib/studentAccess";
import { logger } from "../lib/logger";
import { JOIN_REQUEST_TYPE, JOIN_STATUSES, parseJoinRequest } from "../lib/subscriptionPlans";

/**
 * «احصل على حساب رسمي»: طلبٌ من التطبيق يصل المشرفَ في «طلبات الانضمام الجديدة».
 *
 * يُكتب صفّاً في \`interactions\` (\`type: join_request\`) كما تُكتب رسائلُ الدردشة،
 * فلا يحتاج جدولاً جديداً. والإرسالُ عامّ (الزائرُ بلا حساب) ومحدودٌ بالعدد.
 */
const router = Router();
const submitLimit = createRateLimit(5);
const adminLimit = createRateLimit(60);

function headers(key: string): Record<string, string> {
  return { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" };
}

router.post("/join-requests", submitLimit, async (req, res) => {
  const parsed = parseJoinRequest(req.body);
  if ("error" in parsed) return res.status(400).json({ error: parsed.error });
  const config = apiSupabaseConfig();
  if (!config) return res.status(503).json({ error: "الخادم غير مُعدّ" });
  const id = `join_${Date.now()}_${crypto.randomBytes(5).toString("hex")}`;
  try {
    const response = await fetch(`${config.url}/rest/v1/interactions`, {
      method: "POST",
      headers: { ...headers(config.key), Prefer: "return=minimal" },
      body: JSON.stringify({ id, data: { type: JOIN_REQUEST_TYPE, ...parsed }, updated_at: parsed.createdAt }),
    });
    if (!response.ok) throw new Error(`join request write failed (${response.status})`);
    return res.status(201).json({ id });
  } catch (error) {
    logger.error({ err: error }, "[join-requests] save failed");
    return res.status(502).json({ error: "تعذر إرسال الطلب الآن. حاول مرة أخرى أو تواصل عبر واتساب." });
  }
});

router.get("/admin/join-requests", adminLimit, requireAdmin, async (_req, res) => {
  const config = apiSupabaseConfig();
  if (!config) return res.status(503).json({ error: "الخادم غير مُعدّ" });
  try {
    const url = new URL(`${config.url}/rest/v1/interactions`);
    url.searchParams.set("select", "id,data,updated_at");
    url.searchParams.set("data->>type", `eq.${JOIN_REQUEST_TYPE}`);
    url.searchParams.set("order", "updated_at.desc");
    url.searchParams.set("limit", "500");
    const response = await fetch(url, { headers: headers(config.key) });
    if (!response.ok) throw new Error(`join requests read failed (${response.status})`);
    const rows = (await response.json()) as Array<{ id: string; data: Record<string, unknown> }>;
    return res.json({
      requests: rows.map((row) => ({ id: row.id, ...row.data })).sort((a, b) =>
        String((b as Record<string, unknown>).createdAt ?? "").localeCompare(String((a as Record<string, unknown>).createdAt ?? ""))),
    });
  } catch (error) {
    logger.error({ err: error }, "[join-requests] read failed");
    return res.status(502).json({ error: "تعذر تحميل الطلبات" });
  }
});

router.patch("/admin/join-requests/:id", adminLimit, requireAdmin, async (req, res) => {
  const status = req.body?.status;
  if (!(JOIN_STATUSES as readonly string[]).includes(status)) {
    return res.status(400).json({ error: "حالةٌ غير معروفة" });
  }
  const id = String(req.params.id ?? "");
  if (!/^join_[A-Za-z0-9_]{6,80}$/.test(id)) return res.status(400).json({ error: "طلبٌ غير معروف" });
  const config = apiSupabaseConfig();
  if (!config) return res.status(503).json({ error: "الخادم غير مُعدّ" });
  try {
    const read = await fetch(`${config.url}/rest/v1/interactions?select=data&id=eq.${encodeURIComponent(id)}`, {
      headers: headers(config.key),
    });
    const [row] = (await read.json()) as Array<{ data: Record<string, unknown> }>;
    if (!row || row.data?.type !== JOIN_REQUEST_TYPE) return res.status(404).json({ error: "الطلب غير موجود" });
    const now = new Date().toISOString();
    const write = await fetch(`${config.url}/rest/v1/interactions?id=eq.${encodeURIComponent(id)}`, {
      method: "PATCH",
      headers: { ...headers(config.key), Prefer: "return=minimal" },
      body: JSON.stringify({ data: { ...row.data, status, statusAt: now }, updated_at: now }),
    });
    if (!write.ok) throw new Error(`join request update failed (${write.status})`);
    return res.json({ id, status });
  } catch (error) {
    logger.error({ err: error }, "[join-requests] update failed");
    return res.status(502).json({ error: "تعذر تحديث الطلب" });
  }
});

export default router;
