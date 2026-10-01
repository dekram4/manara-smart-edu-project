import { Router } from "express";
import crypto from "node:crypto";
import { apiSupabaseConfig, findStudentsInScope, type StudentActor } from "../lib/studentAccess";
import { requireStudentSession } from "../middleware/studentAuth";
import { createRateLimit, createStudentRateLimit } from "../middleware/rateLimiter";
import { logger } from "../lib/logger";
import { CHAT_VOICE_MAX_MS, isChatVoiceId, parseChatVoice } from "../lib/chatVoice";

const router = Router();
const chatRateLimit = createRateLimit(30);
// المقاطعُ أثقلُ من النصّ، وتُعدّ لكل طالب: صفٌّ كاملٌ يشارك عنواناً واحداً.
const voiceSendLimit = createStudentRateLimit(12);
const voiceFetchLimit = createStudentRateLimit(90);

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function normalized(value: unknown): string {
  return text(value).toLowerCase();
}

function activeStudent(res: any): StudentActor {
  return res.locals.student as StudentActor;
}

function canUseChat(student: StudentActor): boolean {
  // Some existing student records have not yet been assigned a teacher.
  // They can still use the grade-scoped room with other unassigned students;
  // `findStudentsInScope` and message visibility both require the same empty
  // teacher scope, so this does not merge classrooms.
  return student.canAccessChat && Boolean(student.grade);
}

function serviceHeaders(key: string): Record<string, string> {
  return {
    apikey: key,
    Authorization: `Bearer ${key}`,
    "Content-Type": "application/json",
  };
}

async function writeRow(id: string, data: Record<string, unknown>, now: string): Promise<void> {
  const config = apiSupabaseConfig();
  if (!config) throw new Error("Supabase is not configured");
  const response = await fetch(`${config.url}/rest/v1/interactions`, {
    method: "POST",
    headers: { ...serviceHeaders(config.key), Prefer: "return=minimal" },
    body: JSON.stringify({ id, data, updated_at: now }),
  });
  if (!response.ok) {
    // نصُّ رفضِ قاعدة البيانات في السجلّ: «فشل (400)» وحده لا يقول أيَّ عمودٍ
    // أو صلاحيةٍ رفضت الكتابة.
    const detail = (await response.text().catch(() => "")).slice(0, 300);
    throw new Error(`Chat write failed (${response.status}) ${detail}`);
  }
}

/** يعيّن المستلم: «الكل» أو زميلٌ في صفّ المرسِل نفسه، وإلا فلا أحد. */
async function recipientFor(student: StudentActor, requested: string): Promise<string> {
  if (requested === "all") return "all";
  const peers = await findStudentsInScope(student.grade, student.teacherId);
  return peers.some((peer) => peer.id === requested && peer.id !== student.id)
    ? requested
    : "";
}

async function readMessages(): Promise<Array<Record<string, unknown>>> {
  const config = apiSupabaseConfig();
  if (!config) throw new Error("Supabase is not configured");
  const url = new URL(`${config.url}/rest/v1/interactions`);
  url.searchParams.set("select", "id,data,updated_at");
  url.searchParams.set("data->>type", "eq.student_chat");
  url.searchParams.set("order", "updated_at.asc");
  url.searchParams.set("limit", "250");
  const response = await fetch(url, {
    headers: { apikey: config.key, Authorization: `Bearer ${config.key}` },
  });
  if (!response.ok) throw new Error(`Chat read failed (${response.status})`);
  const rows = await response.json();
  return Array.isArray(rows) ? rows : [];
}

function visibleToStudent(data: Record<string, unknown>, student: StudentActor): boolean {
  if (normalized(data.grade) !== normalized(student.grade) ||
      normalized(data.teacherId) !== normalized(student.teacherId)) return false;
  const recipient = text(data.to);
  const sender = text(data.from);
  return recipient === "all" || recipient === student.id || sender === student.id;
}

function publicMessage(row: Record<string, unknown>): Record<string, unknown> {
  const data = row.data && typeof row.data === "object"
    ? row.data as Record<string, unknown>
    : {};
  const voice = isChatVoiceId(data.voiceId) ? data.voiceId : "";
  return {
    id: text(row.id),
    from: text(data.from),
    name: text(data.name) || "طالب منارة",
    to: text(data.to),
    message: text(data.message),
    time: text(data.time) || text(row.updated_at),
    ...(voice
      ? {
        kind: "voice",
        voiceId: voice,
        durationMs: Math.min(Math.max(Number(data.durationMs) || 0, 0), CHAT_VOICE_MAX_MS),
      }
      : { kind: "text" }),
  };
}

router.get("/student/chat/peers", requireStudentSession, async (_req, res) => {
  const student = activeStudent(res);
  if (!canUseChat(student)) {
    return res.status(403).json({ error: "الدردشة غير مفعلة لحسابك" });
  }
  try {
    const peers = await findStudentsInScope(student.grade, student.teacherId);
    return res.json({
      peers: peers.filter((peer) => peer.id !== student.id).map((peer) => ({
        id: peer.id,
        name: peer.name,
      })),
    });
  } catch (error) {
    logger.error({ err: error }, "[student-chat] peer lookup failed");
    return res.status(503).json({ error: "تعذر تحميل زملاء الدردشة الآن" });
  }
});

router.get("/student/chat/messages", requireStudentSession, async (_req, res) => {
  const student = activeStudent(res);
  if (!canUseChat(student)) {
    return res.status(403).json({ error: "الدردشة غير مفعلة لحسابك" });
  }
  try {
    const messages = (await readMessages())
      .filter((row) => row.data && typeof row.data === "object")
      .filter((row) => visibleToStudent(row.data as Record<string, unknown>, student))
      .map(publicMessage)
      .filter((message) => text(message.message) || message.kind === "voice")
      .slice(-120);
    return res.json({ messages });
  } catch (error) {
    logger.error({ err: error }, "[student-chat] message load failed");
    return res.status(503).json({ error: "تعذر تحميل الرسائل الآن" });
  }
});

router.post("/student/chat/messages", chatRateLimit, requireStudentSession, async (req, res) => {
  const student = activeStudent(res);
  if (!canUseChat(student)) {
    return res.status(403).json({ error: "الدردشة غير مفعلة لحسابك" });
  }
  const message = text(req.body?.message);
  const requestedRecipient = text(req.body?.to) || "all";
  if (!message || message.length > 1000) {
    return res.status(400).json({ error: "الرسالة يجب أن تكون بين 1 و1000 حرف" });
  }
  try {
    const recipient = await recipientFor(student, requestedRecipient);
    if (!recipient) {
      return res.status(403).json({ error: "لا يمكنك إرسال رسالة إلى هذا الحساب" });
    }
    const config = apiSupabaseConfig();
    if (!config) throw new Error("Supabase is not configured");
    const now = new Date().toISOString();
    const id = `chat_${Date.now()}_${crypto.randomUUID()}`;
    const data = {
      type: "student_chat",
      from: student.id,
      name: student.name,
      to: recipient,
      message,
      grade: student.grade,
      teacherId: student.teacherId,
      time: now,
    };
    const response = await fetch(`${config.url}/rest/v1/interactions`, {
      method: "POST",
      headers: {
        apikey: config.key,
        Authorization: `Bearer ${config.key}`,
        "Content-Type": "application/json",
        Prefer: "return=representation",
      },
      body: JSON.stringify({ id, data, updated_at: now }),
    });
    if (!response.ok) throw new Error(`Chat write failed (${response.status})`);
    return res.status(201).json({ message: { id, ...data } });
  } catch (error) {
    logger.error({ err: error }, "[student-chat] message send failed");
    return res.status(503).json({ error: "تعذر إرسال الرسالة الآن" });
  }
});

/**
 * رسالةٌ صوتية: المقطعُ في صفٍّ، والرسالةُ التي تشير إليه في صفٍّ آخر.
 *
 * ويُكتب المقطعُ أوّلاً: رسالةٌ تشير إلى مقطعٍ لم يُكتب تُظهر للصفّ زرَّ تشغيلٍ لا
 * يعمل. والعكسُ — مقطعٌ بلا رسالة — لا يراه أحد.
 */
router.post("/student/chat/voice", requireStudentSession, voiceSendLimit, async (req, res) => {
  const student = activeStudent(res);
  if (!canUseChat(student)) {
    return res.status(403).json({ error: "الدردشة غير مفعلة لحسابك" });
  }
  const note = parseChatVoice(req.body?.audio, req.body?.durationMs);
  if (!note.ok) {
    logger.warn(
      {
        studentId: student.id,
        code: note.error,
        contentType: req.headers["content-type"],
        audioChars: typeof req.body?.audio === "string" ? req.body.audio.length : null,
      },
      "[student-chat] voice rejected",
    );
    return res.status(400).json({
      error: note.error === "tooBig"
        ? "الرسالة الصوتية أطول من المسموح"
        : note.error === "tooShort"
          ? "الرسالة الصوتية قصيرة جداً"
          : note.error === "format"
            ? "الرسالة الصوتية بصيغة غير مدعومة"
            : note.error === "missing"
              ? "لم يصل المقطع الصوتي إلى الخادم"
              : "الرسالة الصوتية غير صالحة",
      code: note.error,
    });
  }
  try {
    const recipient = await recipientFor(student, text(req.body?.to) || "all");
    if (!recipient) {
      return res.status(403).json({ error: "لا يمكنك إرسال رسالة إلى هذا الحساب" });
    }
    const now = new Date().toISOString();
    const scope = {
      from: student.id,
      to: recipient,
      grade: student.grade,
      teacherId: student.teacherId,
    };
    const voiceId = `chatvoice_${Date.now()}_${crypto.randomUUID()}`;
    await writeRow(
      voiceId,
      { type: "student_chat_voice", ...scope, audio: note.base64, mime: note.mime, time: now },
      now,
    );
    const id = `chat_${Date.now()}_${crypto.randomUUID()}`;
    const data = {
      type: "student_chat",
      ...scope,
      name: student.name,
      message: "",
      voiceId,
      durationMs: note.durationMs,
      time: now,
    };
    await writeRow(id, data, now);
    return res.status(201).json({
      message: {
        id,
        from: student.id,
        name: student.name,
        to: recipient,
        message: "",
        kind: "voice",
        voiceId,
        durationMs: note.durationMs,
        time: now,
      },
    });
  } catch (error) {
    logger.error({ err: error, studentId: student.id }, "[student-chat] voice send failed");
    return res.status(503).json({
      error: "تعذر حفظ الرسالة الصوتية على الخادم الآن",
      code: "storage",
    });
  }
});

/**
 * يُرجع المقطعَ لمن يرى رسالتَه وحده: صفُّه ومعلّمُه، والمرسلُ والمستلم.
 * ومقطعٌ لا يحقّ له يُردّ عليه بـ404 لا 403 — فلا يُعرف أنه موجود.
 */
router.get("/student/chat/voice/:id", requireStudentSession, voiceFetchLimit, async (req, res) => {
  const student = activeStudent(res);
  if (!canUseChat(student)) {
    return res.status(403).json({ error: "الدردشة غير مفعلة لحسابك" });
  }
  const id = req.params.id;
  if (!isChatVoiceId(id)) return res.status(404).json({ error: "الرسالة الصوتية غير موجودة" });
  try {
    const config = apiSupabaseConfig();
    if (!config) throw new Error("Supabase is not configured");
    const url = new URL(`${config.url}/rest/v1/interactions`);
    url.searchParams.set("select", "id,data");
    url.searchParams.set("id", `eq.${id}`);
    url.searchParams.set("limit", "1");
    const response = await fetch(url, { headers: serviceHeaders(config.key) });
    if (!response.ok) throw new Error(`Voice read failed (${response.status})`);
    const rows = await response.json();
    const data = Array.isArray(rows) && rows[0]?.data && typeof rows[0].data === "object"
      ? rows[0].data as Record<string, unknown>
      : null;
    if (!data || data.type !== "student_chat_voice" || !visibleToStudent(data, student) ||
        typeof data.audio !== "string") {
      return res.status(404).json({ error: "الرسالة الصوتية غير موجودة" });
    }
    const audio = Buffer.from(data.audio, "base64");
    res.setHeader(
      "Content-Type",
      typeof data.mime === "string" && data.mime.startsWith("audio/") ? data.mime : "audio/mp4",
    );
    // المقطعُ لا يتغيّر بعد كتابته.
    res.setHeader("Cache-Control", "private, max-age=86400, immutable");
    return res.status(200).send(audio);
  } catch (error) {
    logger.error({ err: error }, "[student-chat] voice load failed");
    return res.status(503).json({ error: "تعذر تحميل الرسالة الصوتية الآن" });
  }
});

export default router;