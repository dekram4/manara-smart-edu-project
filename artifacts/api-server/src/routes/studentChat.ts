import { Router } from "express";
import crypto from "node:crypto";
import { apiSupabaseConfig, findStudentsInScope, type StudentActor } from "../lib/studentAccess";
import { requireStudentSession } from "../middleware/studentAuth";
import { createRateLimit, createStudentRateLimit } from "../middleware/rateLimiter";
import { logger } from "../lib/logger";
import { CHAT_VOICE_MAX_MS, isChatVoiceId, parseChatVoice } from "../lib/chatVoice";
import {
  isChatMessageId,
  isSaved,
  recipientsOf,
  saveUntil,
  shouldPurge,
  visibleTo,
  type ChatMessageMeta,
  type ChatReceipt,
} from "../lib/chatLifecycle";

const router = Router();
const chatRateLimit = createRateLimit(30);
// المقاطعُ أثقلُ من النصّ، وتُعدّ لكل طالب: صفٌّ كاملٌ يشارك عنواناً واحداً.
const voiceSendLimit = createStudentRateLimit(12);
const voiceFetchLimit = createStudentRateLimit(90);
const receiptLimit = createStudentRateLimit(60);

/** نوعُ صفّ الإيصال في `interactions` — بجانب الرسائل نفسها. */
const RECEIPT_TYPE = "student_chat_receipt";

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
  // الأحدثُ أوّلاً ثم يُقلب: الحدُّ يقصّ الأقدمَ لا الأحدث.
  url.searchParams.set("order", "updated_at.desc");
  url.searchParams.set("limit", "300");
  const response = await fetch(url, {
    headers: { apikey: config.key, Authorization: `Bearer ${config.key}` },
  });
  if (!response.ok) throw new Error(`Chat read failed (${response.status})`);
  const rows = await response.json();
  return Array.isArray(rows) ? rows.reverse() : [];
}

/** طلبٌ إلى PostgREST بمفتاح الخدمة. */
async function rest(path: string, init: RequestInit = {}): Promise<Response> {
  const config = apiSupabaseConfig();
  if (!config) throw new Error("Supabase is not configured");
  return fetch(`${config.url}/rest/v1/${path}`, {
    ...init,
    headers: { ...serviceHeaders(config.key), ...(init.headers as Record<string, string>) },
  });
}

/** قوائمُ `in.(...)` قصيرة: معرّفاتٌ كثيرةٌ في عنوانٍ واحد تتجاوز حدَّه. */
function chunks<T>(items: readonly T[], size = 40): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

const inList = (ids: readonly string[]) => `in.(${ids.map((id) => `"${id}"`).join(",")})`;

/**
 * إيصالاتُ القراءة والحفظ — في `interactions` بجانب الرسائل، لا في جدولٍ وحدها.
 *
 * ── لماذا لا جدولٌ خاصّ ──
 * كان لها جدولٌ يُنشئه `scripts/chat-ephemeral.sql`، ولم يُشغَّل — فبقيت الدردشةُ بلا
 * اختفاءٍ ولا حفظ، ولم يظهر للطالب شيءٌ مما بُني. و`interactions` قائمٌ ويكتب فيه
 * الخادمُ الرسائلَ نفسها: فالميزةُ تعمل بنشر الخادم وحده.
 *
 * صفٌّ لكل (رسالة، طالب)، معرّفُه منهما فيُكتب فوقه. و`null` إن تعذّرت القراءة.
 */
function receiptId(messageId: string, studentId: string): string {
  return `chatrcpt_${messageId}__${studentId}`;
}

function readReceipt(row: Record<string, unknown>): ChatReceipt | null {
  const data = row.data && typeof row.data === "object" ? row.data as Record<string, unknown> : {};
  const messageId = text(data.messageId);
  const studentId = text(data.studentId);
  if (!messageId || !studentId) return null;
  return {
    messageId,
    studentId,
    seenAt: text(data.seenAt) || null,
    savedUntil: text(data.savedUntil) || null,
  };
}

async function receiptsWhere(filter: string): Promise<ChatReceipt[] | null> {
  const response = await rest(
    `interactions?select=id,data&data->>type=eq.${RECEIPT_TYPE}&${filter}&limit=5000`,
  );
  if (!response.ok) {
    logger.warn({ status: response.status }, "[student-chat] receipts unavailable");
    return null;
  }
  const rows = await response.json();
  return (Array.isArray(rows) ? rows : [])
    .map((row: Record<string, unknown>) => readReceipt(row))
    .filter((receipt): receipt is ChatReceipt => receipt !== null);
}

const receiptsOfStudent = (studentId: string) =>
  receiptsWhere(`data->>studentId=eq.${encodeURIComponent(studentId)}`);

const receiptsOfMessages = (ids: readonly string[]) =>
  receiptsWhere(`data->>messageId=${inList(ids)}`);

/**
 * يكتب قراءةً أو حفظاً لطالب. وما لم يُذكر يبقى كما كان: قراءةٌ لا تمحو حفظاً،
 * وحفظٌ لا يمحو قراءة.
 */
async function writeReceipts(
  student: StudentActor,
  changes: ReadonlyArray<{ messageId: string; seenAt?: string; savedUntil?: string | null }>,
): Promise<boolean> {
  if (changes.length === 0) return true;
  const existing = new Map<string, ChatReceipt>();
  for (const part of chunks(changes.map((change) => change.messageId))) {
    const found = await receiptsWhere(
      `data->>studentId=eq.${encodeURIComponent(student.id)}&data->>messageId=${inList(part)}`,
    );
    if (found === null) return false;
    for (const receipt of found) existing.set(receipt.messageId, receipt);
  }
  const now = new Date().toISOString();
  const rows = changes.map((change) => {
    const before = existing.get(change.messageId);
    return {
      id: receiptId(change.messageId, student.id),
      updated_at: now,
      data: {
        type: RECEIPT_TYPE,
        messageId: change.messageId,
        studentId: student.id,
        grade: student.grade,
        teacherId: student.teacherId,
        seenAt: change.seenAt ?? before?.seenAt ?? null,
        savedUntil: "savedUntil" in change ? change.savedUntil ?? null : before?.savedUntil ?? null,
      },
    };
  });
  const response = await rest("interactions?on_conflict=id", {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
    body: JSON.stringify(rows),
  });
  if (!response.ok) {
    logger.warn(
      { status: response.status, detail: (await response.text().catch(() => "")).slice(0, 200) },
      "[student-chat] receipts not written",
    );
  }
  return response.ok;
}

async function deleteReceipts(messageIds: readonly string[]): Promise<void> {
  for (const part of chunks(messageIds)) {
    await rest(
      `interactions?data->>type=eq.${RECEIPT_TYPE}&data->>messageId=${inList(part)}`,
      { method: "DELETE" },
    );
  }
}

function dataOf(row: Record<string, unknown>): Record<string, unknown> {
  return row.data && typeof row.data === "object" ? row.data as Record<string, unknown> : {};
}

function metaOf(row: Record<string, unknown>): ChatMessageMeta {
  const data = dataOf(row);
  return {
    id: text(row.id),
    from: text(data.from),
    to: text(data.to),
    createdAt: text(data.time) || text(row.updated_at),
  };
}

/** رسالةٌ من صفّ هذا الطالب — لا يُكنس إلا صفُّه. */
function inClassOf(data: Record<string, unknown>, student: StudentActor): boolean {
  return normalized(data.grade) === normalized(student.grade) &&
    normalized(data.teacherId) === normalized(student.teacherId);
}


/** آخرُ كنسٍ لكل صفّ، وللكنس العامّ في القاعدة. */
const lastClassPurge = new Map<string, number>();
let lastSweep = 0;

/**
 * يحذف نهائياً رسائلَ الصفّ التي قرأها كلُّ من أُرسلت إليه ولم يحفظها أحد، أو
 * مضى عمرُها — ومعها مقاطعُها وإيصالاتُها. انظر `shouldPurge`.
 *
 * [onlyIds]: بعد قراءةٍ تُكنس الرسائلُ المقروءةُ الآن وحدها، بلا انتظار. وبدونها
 * يُكنس الصفُّ كلُّه مرّةً في الدقيقة على الأكثر.
 */
async function purgeClass(student: StudentActor, onlyIds?: readonly string[]): Promise<number> {
  const key = `${normalized(student.teacherId)}:${normalized(student.grade)}`;
  if (!onlyIds) {
    const last = lastClassPurge.get(key) ?? 0;
    if (Date.now() - last < 60_000) return 0;
    lastClassPurge.set(key, Date.now());
  }
  if (Date.now() - lastSweep > 15 * 60_000) {
    lastSweep = Date.now();
    void rest("rpc/purge_student_chat", { method: "POST", body: "{}" }).catch(() => null);
  }
  const rows = (await readMessages())
    .filter((row) => inClassOf(dataOf(row), student))
    .filter((row) => !onlyIds || onlyIds.includes(text(row.id)));
  if (rows.length === 0) return 0;
  const classIds = (await findStudentsInScope(student.grade, student.teacherId)).map((p) => p.id);
  const receipts: ChatReceipt[] = [];
  for (const part of chunks(rows.map((row) => text(row.id)))) {
    const found = await receiptsOfMessages(part);
    if (found === null) return 0;
    receipts.push(...found);
  }
  const now = new Date();
  const doomed = rows.filter((row) => {
    const meta = metaOf(row);
    return shouldPurge(meta, recipientsOf(meta, classIds), receipts, now);
  });
  if (doomed.length === 0) return 0;
  const ids = doomed.map((row) => text(row.id));
  const voices = doomed
    .map((row) => dataOf(row).voiceId)
    .filter((id): id is string => isChatVoiceId(id));
  for (const part of chunks([...ids, ...voices])) {
    await rest(`interactions?id=${inList(part)}`, { method: "DELETE" });
  }
  await deleteReceipts(ids);
  logger.info({ messages: ids.length, voices: voices.length }, "[student-chat] purged");
  return ids.length;
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
    const rows = (await readMessages())
      .filter((row) => row.data && typeof row.data === "object")
      .filter((row) => visibleToStudent(row.data as Record<string, unknown>, student));
    // ── ما قرأه وغادر لا يعود — إلا ما حفظه ──
    const mine = await receiptsOfStudent(student.id);
    const byId = new Map((mine ?? []).map((receipt) => [receipt.messageId, receipt]));
    const now = new Date();
    const messages = rows
      .filter((row) => mine === null || visibleTo(metaOf(row), byId.get(text(row.id)), now))
      .map((row): Record<string, unknown> => {
        const receipt = byId.get(text(row.id));
        return {
          ...publicMessage(row),
          savedUntil: isSaved(receipt, now) ? receipt!.savedUntil : null,
        };
      })
      .filter((message) => text(message.message) || message.kind === "voice")
      .slice(-120);
    if (mine !== null) {
      void purgeClass(student).catch((error) =>
        logger.error({ err: error }, "[student-chat] purge failed"));
    }
    return res.json({ messages, ephemeral: mine !== null, saveHours: 24 });
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
 * قرأتُ هذه الرسائلَ (أو سمعتُها) وغادرتُ الدردشة. الجسم: `{ ids: [...] }`.
 *
 * لا تعود لي بعدها إلا ما حفظتُه. وما قرأه كلُّ من أُرسل إليه يُحذف نهائياً الآن.
 */
router.post("/student/chat/seen", requireStudentSession, receiptLimit, async (req, res) => {
  const student = activeStudent(res);
  if (!canUseChat(student)) {
    return res.status(403).json({ error: "الدردشة غير مفعلة لحسابك" });
  }
  const asked = Array.isArray(req.body?.ids) ? req.body.ids : [];
  const ids = [...new Set(asked.filter(isChatMessageId))].slice(0, 300) as string[];
  if (ids.length === 0) return res.json({ seen: 0, purged: 0 });
  try {
    // ولا يُكتب إيصالٌ لرسالةٍ لا يراها: صفٌّ آخر أو خاصّةٌ بين غيره.
    const mineToSee = new Set(
      (await readMessages())
        .filter((row) => visibleToStudent(dataOf(row), student))
        .map((row) => text(row.id)),
    );
    const now = new Date().toISOString();
    const valid = ids.filter((id) => mineToSee.has(id));
    const written = await writeReceipts(
      student,
      valid.map((id) => ({ messageId: id, seenAt: now })),
    );
    if (!written) return res.json({ seen: 0, purged: 0, ephemeral: false });
    const purged = await purgeClass(student, valid).catch((error) => {
      logger.error({ err: error }, "[student-chat] purge after seen failed");
      return 0;
    });
    return res.json({ seen: valid.length, purged });
  } catch (error) {
    logger.error({ err: error, studentId: student.id }, "[student-chat] seen failed");
    return res.status(503).json({ error: "تعذر تحديث حالة الرسائل الآن" });
  }
});

/**
 * حفظُ رسالةٍ ٢٤ ساعةً أو إلغاءُ حفظها. الجسم: `{ id, saved: true | false }`.
 *
 * الحفظُ لي وحدي: تبقى في سجلّي وإن قرأتُها وغادرت، حتى ينتهي حفظُها أو ألغيه.
 */
router.post("/student/chat/save", requireStudentSession, receiptLimit, async (req, res) => {
  const student = activeStudent(res);
  if (!canUseChat(student)) {
    return res.status(403).json({ error: "الدردشة غير مفعلة لحسابك" });
  }
  const id = req.body?.id;
  const saved = req.body?.saved;
  if (!isChatMessageId(id) || typeof saved !== "boolean") {
    return res.status(400).json({ error: "طلب الحفظ ناقص", code: "bad_request" });
  }
  try {
    const row = (await readMessages()).find((entry) => text(entry.id) === id);
    if (!row || !visibleToStudent(dataOf(row), student)) {
      return res.status(404).json({ error: "الرسالة لم تعد موجودة", code: "not_found" });
    }
    const now = new Date();
    const until = saved ? saveUntil(now) : null;
    const written = await writeReceipts(student, [{ messageId: id, savedUntil: until }]);
    if (!written) {
      return res.status(503).json({ error: "تعذر حفظ الرسالة الآن", code: "save_unavailable" });
    }
    return res.json({ id, savedUntil: until });
  } catch (error) {
    logger.error({ err: error, studentId: student.id }, "[student-chat] save failed");
    return res.status(503).json({ error: "تعذر حفظ الرسالة الآن" });
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