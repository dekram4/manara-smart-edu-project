import { Router } from "express";
import crypto from "node:crypto";
import { apiSupabaseConfig, type StudentActor } from "../lib/studentAccess";
import { requireStudentSession } from "../middleware/studentAuth";
import { createStudentRateLimit } from "../middleware/rateLimiter";
import { logger } from "../lib/logger";
import {
  ARTWORK_MAX_PER_STUDENT,
  artworkTitle,
  isArtworkId,
  parseArtworkDoc,
  parseArtworkImage,
} from "../lib/artworks";

/**
 * «لوحاتي في السحابة» (انظر `lib/artworks.ts`). كلُّ مسارٍ للطالب صاحبِ الجلسة
 * وحده: لا يرى لوحةَ غيره ولا يحذفها — ولوحةُ غيره تُردّ 404 لا 403.
 */
const router = Router();
const writeLimit = createStudentRateLimit(20);
const readLimit = createStudentRateLimit(120);
const TYPE = "student_artwork";

function student(res: any): StudentActor {
  return res.locals.student as StudentActor;
}

async function rest(path: string, init: RequestInit = {}): Promise<Response> {
  const config = apiSupabaseConfig();
  if (!config) throw new Error("Supabase is not configured");
  return fetch(`${config.url}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: config.key,
      Authorization: `Bearer ${config.key}`,
      "Content-Type": "application/json",
      ...(init.headers as Record<string, string>),
    },
  });
}

const mine = (studentId: string) =>
  `data->>type=eq.${TYPE}&data->>studentId=eq.${encodeURIComponent(studentId)}`;

/** لوحاتُ الطالب بلا صورها ولا خطواتها: المعرّفُ والاسمُ والوقت، الأحدثُ أوّلاً. */
async function listOf(studentId: string): Promise<Array<{ id: string; title: string; time: string }>> {
  const response = await rest(
    `interactions?select=id,updated_at,title:data->>title,time:data->>time&${mine(studentId)}` +
      `&order=updated_at.desc&limit=${ARTWORK_MAX_PER_STUDENT + 5}`,
  );
  if (!response.ok) throw new Error(`Artwork list failed (${response.status})`);
  const rows = await response.json();
  return (Array.isArray(rows) ? rows : []).map((row: Record<string, unknown>) => ({
    id: String(row.id ?? ""),
    title: String(row.title ?? ""),
    time: String(row.time ?? row.updated_at ?? ""),
  }));
}

/** صفُّ لوحةٍ لهذا الطالب، أو `null`. */
async function ownRow(id: string, studentId: string): Promise<Record<string, unknown> | null> {
  const response = await rest(`interactions?select=id,data&id=eq.${encodeURIComponent(id)}&${mine(studentId)}&limit=1`);
  if (!response.ok) throw new Error(`Artwork read failed (${response.status})`);
  const rows = await response.json();
  const data = Array.isArray(rows) ? rows[0]?.data : null;
  return data && typeof data === "object" ? data as Record<string, unknown> : null;
}

router.get("/student/artworks", requireStudentSession, readLimit, async (_req, res) => {
  try {
    return res.json({ artworks: await listOf(student(res).id), max: ARTWORK_MAX_PER_STUDENT });
  } catch (error) {
    logger.error({ err: error }, "[artworks] list failed");
    return res.status(503).json({ error: "تعذر تحميل لوحاتك من السحابة الآن" });
  }
});

router.post("/student/artworks", requireStudentSession, writeLimit, async (req, res) => {
  const me = student(res);
  const image = parseArtworkImage(req.body?.image);
  if (!image.ok) {
    return res.status(image.error === "tooBig" ? 413 : 400).json({
      error: image.error === "tooBig" ? "اللوحة أكبر من المسموح" : "صورة اللوحة غير صالحة",
      code: image.error,
    });
  }
  const doc = parseArtworkDoc(req.body?.doc);
  if (!doc.ok) {
    return res.status(doc.error === "docTooBig" ? 413 : 400).json({ error: "خطوات اللوحة غير صالحة", code: doc.error });
  }
  const replaces = isArtworkId(req.body?.replaces) ? req.body.replaces as string : "";
  try {
    const existing = await listOf(me.id);
    const replacing = replaces && existing.some((item) => item.id === replaces);
    if (!replacing && existing.length >= ARTWORK_MAX_PER_STUDENT) {
      return res.status(409).json({
        error: `في السحابة ${ARTWORK_MAX_PER_STUDENT} لوحة — احذف لوحة قديمة لتحفظ جديدة`,
        code: "full",
      });
    }
    const now = new Date().toISOString();
    const id = `artwork_${Date.now()}_${crypto.randomUUID()}`;
    const title = artworkTitle(req.body?.title);
    const response = await rest("interactions", {
      method: "POST",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({
        id,
        updated_at: now,
        data: { type: TYPE, studentId: me.id, title, image: image.base64, mime: image.mime, doc: doc.doc, time: now },
      }),
    });
    if (!response.ok) throw new Error(`Artwork write failed (${response.status})`);
    // ‏الجديدةُ كُتبت أوّلاً، ثم تُحذف القديمةُ التي حلّت محلَّها — فلا تضيع لوحةٌ في المنتصف.
    if (replacing) {
      await rest(`interactions?id=eq.${encodeURIComponent(replaces)}&${mine(me.id)}`, { method: "DELETE" });
    }
    return res.status(201).json({ artwork: { id, title, time: now } });
  } catch (error) {
    logger.error({ err: error, studentId: me.id }, "[artworks] save failed");
    return res.status(503).json({ error: "تعذر حفظ اللوحة في السحابة الآن" });
  }
});

router.get("/student/artworks/:id/image", requireStudentSession, readLimit, async (req, res) => {
  const id = req.params.id;
  if (!isArtworkId(id)) return res.status(404).json({ error: "اللوحة غير موجودة" });
  try {
    const data = await ownRow(id, student(res).id);
    if (!data || typeof data.image !== "string") return res.status(404).json({ error: "اللوحة غير موجودة" });
    res.setHeader(
      "Content-Type",
      typeof data.mime === "string" && data.mime.startsWith("image/") ? data.mime : "image/png",
    );
    // ‏اللوحةُ لا تتغيّر بعد حفظها: تعديلُها لوحةٌ جديدةٌ بمعرّفٍ جديد.
    res.setHeader("Cache-Control", "private, max-age=86400, immutable");
    return res.status(200).send(Buffer.from(data.image, "base64"));
  } catch (error) {
    logger.error({ err: error }, "[artworks] image failed");
    return res.status(503).json({ error: "تعذر تحميل اللوحة الآن" });
  }
});

router.get("/student/artworks/:id/doc", requireStudentSession, readLimit, async (req, res) => {
  const id = req.params.id;
  if (!isArtworkId(id)) return res.status(404).json({ error: "اللوحة غير موجودة" });
  try {
    const data = await ownRow(id, student(res).id);
    if (!data) return res.status(404).json({ error: "اللوحة غير موجودة" });
    return res.json({ id, title: String(data.title ?? ""), doc: typeof data.doc === "string" ? data.doc : "" });
  } catch (error) {
    logger.error({ err: error }, "[artworks] doc failed");
    return res.status(503).json({ error: "تعذر فتح اللوحة الآن" });
  }
});

router.delete("/student/artworks/:id", requireStudentSession, writeLimit, async (req, res) => {
  const id = req.params.id;
  if (!isArtworkId(id)) return res.status(404).json({ error: "اللوحة غير موجودة" });
  try {
    const me = student(res);
    if (!(await ownRow(id, me.id))) return res.status(404).json({ error: "اللوحة غير موجودة" });
    const response = await rest(`interactions?id=eq.${encodeURIComponent(id)}&${mine(me.id)}`, { method: "DELETE" });
    if (!response.ok) throw new Error(`Artwork delete failed (${response.status})`);
    return res.json({ deleted: id });
  } catch (error) {
    logger.error({ err: error }, "[artworks] delete failed");
    return res.status(503).json({ error: "تعذر حذف اللوحة الآن" });
  }
});

export default router;
