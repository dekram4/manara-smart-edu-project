import { Router } from "express";
import crypto from "node:crypto";
import { apiSupabaseConfig, findStudentsInScope, type StudentActor } from "../lib/studentAccess";
import { requireStudentSession } from "../middleware/studentAuth";
import { createRateLimit } from "../middleware/rateLimiter";
import { logger } from "../lib/logger";

const router = Router();
const chatRateLimit = createRateLimit(30);

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
  return {
    id: text(row.id),
    from: text(data.from),
    name: text(data.name) || "طالب منارة",
    to: text(data.to),
    message: text(data.message),
    time: text(data.time) || text(row.updated_at),
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
      .filter((message) => text(message.message))
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
    const peers = await findStudentsInScope(student.grade, student.teacherId);
    const recipient = requestedRecipient === "all"
      ? "all"
      : peers.some((peer) => peer.id === requestedRecipient && peer.id !== student.id)
        ? requestedRecipient
        : "";
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

export default router;