import { Router } from "express";
import crypto from "node:crypto";
import { apiSupabaseConfig, findStudentsInScope, normalizeScopeId, type StudentActor } from "../lib/studentAccess";
import { requireStudentSession } from "../middleware/studentAuth";
import { readCookie, TEACHER_SESSION_COOKIE, verifyTeacherSession } from "../middleware/adminAuth";
import { isChatImageId, parseChatImage, teacherRecipient } from "../lib/chatImage";
import { createRateLimit, createStudentRateLimit } from "../middleware/rateLimiter";
import { logger } from "../lib/logger";
import { CHAT_VOICE_MAX_MS, isChatVoiceId, parseChatVoice } from "../lib/chatVoice";
import {
  allSeenAt,
  isChatMessageId,
  isSaved,
  recipientsOf,
  saveUntil,
  seenBy,
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
// ‏اللوحاتُ أثقلُ من المقاطع: إرسالُها أقلّ.
const imageSendLimit = createStudentRateLimit(10);
const imageFetchLimit = createStudentRateLimit(90);
const teacherChatLimit = createRateLimit(120);

/** من يكتب إيصالاً: طالبٌ، أو معلّمُ الصفّ باسم `teacher:<معرّفه>`. */
type ChatReader = { id: string; grade: string; teacherId: string };
/** صفٌّ بعينه: صفُّ الطالب ومعلّمُه. */
type ChatScope = { grade: string; teacherId: string };

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
  // ‏معلّمُ الصفّ نفسُه، لا أيُّ معلّم.
  const teacher = teacherRecipient(student.teacherId);
  if (teacher && requested === teacher) return teacher;
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
  // و`seenAt` من إيصالاتٍ أقدم: أوّلُ العرض وآخرُه معاً.
  const legacy = text(data.seenAt) || null;
  return {
    messageId,
    studentId,
    firstSeenAt: text(data.firstSeenAt) || legacy,
    lastSeenAt: text(data.lastSeenAt) || legacy,
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
  student: ChatReader,
  changes: ReadonlyArray<{ messageId: string; seen?: boolean; savedUntil?: string | null }>,
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
        // أوّلُ العرض يثبت، وآخرُه يتجدّد مع كل عرض.
        firstSeenAt: change.seen ? before?.firstSeenAt ?? now : before?.firstSeenAt ?? null,
        lastSeenAt: change.seen ? now : before?.lastSeenAt ?? null,
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
function inClassOf(data: Record<string, unknown>, student: ChatScope): boolean {
  return normalized(data.grade) === normalized(student.grade) &&
    normalized(data.teacherId) === normalized(student.teacherId);
}


/** آخرُ كنسٍ لكل صفّ. */
const lastClassPurge = new Map<string, number>();

/**
 * يحذف نهائياً رسائلَ الصفّ التي استهلكها كلُّ أطرافها، والعالقةَ القديمة — ومعها
 * مقاطعُها وإيصالاتُها، ما لم تكن محفوظة. انظر `shouldPurge`.
 *
 * [onlyIds]: بعد قراءةٍ تُكنس الرسائلُ المقروءةُ الآن وحدها، بلا انتظار. وبدونها
 * يُكنس الصفُّ كلُّه مرّةً في الدقيقة على الأكثر.
 */
async function purgeClass(student: ChatScope, onlyIds?: readonly string[]): Promise<number> {
  const key = `${normalized(student.teacherId)}:${normalized(student.grade)}`;
  if (!onlyIds) {
    const last = lastClassPurge.get(key) ?? 0;
    if (Date.now() - last < 60_000) return 0;
    lastClassPurge.set(key, Date.now());
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
  // ‏واللوحاتُ معها: صورةٌ شوهدت لا تبقى في القاعدة.
  const images = doomed
    .map((row) => dataOf(row).imageId)
    .filter((id): id is string => isChatImageId(id));
  for (const part of chunks([...ids, ...voices, ...images])) {
    await rest(`interactions?id=${inList(part)}`, { method: "DELETE" });
  }
  await deleteReceipts(ids);
  logger.info({ messages: ids.length, voices: voices.length, images: images.length }, "[student-chat] purged");
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
  const image = isChatImageId(data.imageId) ? data.imageId : "";
  return {
    id: text(row.id),
    from: text(data.from),
    name: text(data.name) || "طالب منارة",
    to: text(data.to),
    message: text(data.message),
    time: text(data.time) || text(row.updated_at),
    ...(image
      ? { kind: "image", imageId: image }
      : voice
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
    const teacher = teacherRecipient(student.teacherId);
    return res.json({
      peers: [
        // ‏معلّمُ الصفّ أوّلاً: تصله الرسائلُ في «رسائل طلابي» في بوابته.
        ...(teacher ? [{ id: teacher, name: "معلّمي", teacher: true }] : []),
        ...peers.filter((peer) => peer.id !== student.id).map((peer) => ({
          id: peer.id,
          name: peer.name,
        })),
      ],
    });
  } catch (error) {
    logger.error({ err: error }, "[student-chat] peer lookup failed");
    return res.status(503).json({ error: "تعذر تحميل زملاء الدردشة الآن" });
  }
});

/**
 * رسائلُ الطالب في هذه الزيارة. `?visit=<وقت>`: بدايةُ الزيارة كما أعادها الخادمُ في
 * أوّل طلب — وبدونه تبدأ زيارةٌ الآن.
 *
 * ما استهلكه قبل بدء الزيارة لا يُعرض، وما استهلكه أثناءها يبقى حتى يخرج. ومع كل
 * رسالةٍ أرسلها: من رآها من المستلمين بأسمائهم، وهل رآها الجميع.
 */
router.get("/student/chat/messages", requireStudentSession, async (req, res) => {
  const student = activeStudent(res);
  if (!canUseChat(student)) {
    return res.status(403).json({ error: "الدردشة غير مفعلة لحسابك" });
  }
  try {
    const now = new Date();
    const asked = Date.parse(text(req.query?.visit));
    // زيارةٌ في المستقبل أو قبل يومٍ لا تُصدَّق: تبدأ الآن.
    const visit = Number.isFinite(asked) && asked <= now.getTime() && now.getTime() - asked < 24 * 3600e3
      ? new Date(asked)
      : now;
    const rows = (await readMessages())
      .filter((row) => row.data && typeof row.data === "object")
      .filter((row) => visibleToStudent(row.data as Record<string, unknown>, student));
    const classmates = await findStudentsInScope(student.grade, student.teacherId);
    const classIds = [...new Set([...classmates.map((p) => p.id), student.id])];
    const names = new Map(classmates.map((p) => [p.id, p.name]));
    const myTeacher = teacherRecipient(student.teacherId);
    if (myTeacher) names.set(myTeacher, "معلّمي");
    const receipts: ChatReceipt[] = [];
    let ephemeral = true;
    for (const part of chunks(rows.map((row) => text(row.id)))) {
      const found = await receiptsOfMessages(part);
      if (found === null) {
        ephemeral = false;
        break;
      }
      receipts.push(...found);
    }
    const messages = rows
      .filter((row) => {
        if (!ephemeral) return true;
        const meta = metaOf(row);
        return visibleTo(meta, student.id, recipientsOf(meta, classIds), receipts, visit, now);
      })
      .map((row): Record<string, unknown> => {
        const meta = metaOf(row);
        const recipients = recipientsOf(meta, classIds);
        const mine = receipts.find((r) => r.messageId === meta.id && r.studentId === student.id);
        const out: Record<string, unknown> = {
          ...publicMessage(row),
          savedUntil: isSaved(mine, now) ? mine!.savedUntil : null,
        };
        if (meta.from === student.id) {
          const readers = seenBy(meta, recipients, receipts);
          out.readBy = readers.map((id) => names.get(id) || "طالب منارة");
          out.readByAll = allSeenAt(meta, recipients, receipts) !== null;
          out.recipients = recipients.length;
        }
        return out;
      })
      .filter((message) => text(message.message) || message.kind === "voice" || message.kind === "image")
      .slice(-120);
    if (ephemeral) {
      void purgeClass(student).catch((error) =>
        logger.error({ err: error }, "[student-chat] purge failed"));
    }
    return res.json({ messages, ephemeral, saveHours: 24, visit: visit.toISOString() });
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
    const valid = ids.filter((id) => mineToSee.has(id));
    const written = await writeReceipts(
      student,
      valid.map((id) => ({ messageId: id, seen: true })),
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

/** صفٌّ واحدٌ بمعرّفه من `interactions` — مقطعٌ أو صورة. */
async function storedRow(id: string): Promise<Record<string, unknown> | null> {
  const config = apiSupabaseConfig();
  if (!config) throw new Error("Supabase is not configured");
  const url = new URL(`${config.url}/rest/v1/interactions`);
  url.searchParams.set("select", "id,data");
  url.searchParams.set("id", `eq.${id}`);
  url.searchParams.set("limit", "1");
  const response = await fetch(url, { headers: serviceHeaders(config.key) });
  if (!response.ok) throw new Error(`Chat row read failed (${response.status})`);
  const rows = await response.json();
  return Array.isArray(rows) && rows[0]?.data && typeof rows[0].data === "object"
    ? rows[0].data as Record<string, unknown>
    : null;
}

function sendImage(res: any, data: Record<string, unknown>) {
  const image = Buffer.from(String(data.image), "base64");
  res.setHeader(
    "Content-Type",
    typeof data.mime === "string" && data.mime.startsWith("image/") ? data.mime : "image/png",
  );
  // ‏صورةٌ تختفي بعد مشاهدتها: لا تُحفظ في ذاكرة المتصفّح أو الجهاز.
  res.setHeader("Cache-Control", "private, no-store");
  return res.status(200).send(image);
}

/**
 * لوحةٌ من «لوحاتي»: الصورةُ في صفٍّ، والرسالةُ التي تشير إليها في صفٍّ آخر —
 * كالرسالة الصوتية. وتُكتب الصورةُ أوّلاً: رسالةٌ بلا صورتها زرٌّ لا يعمل.
 */
router.post("/student/chat/image", requireStudentSession, imageSendLimit, async (req, res) => {
  const student = activeStudent(res);
  if (!canUseChat(student)) {
    return res.status(403).json({ error: "الدردشة غير مفعلة لحسابك" });
  }
  const image = parseChatImage(req.body?.image);
  if (!image.ok) {
    logger.warn({ studentId: student.id, code: image.error }, "[student-chat] image rejected");
    return res.status(image.error === "tooBig" ? 413 : 400).json({
      error: image.error === "tooBig"
        ? "اللوحة أكبر من المسموح"
        : image.error === "missing"
          ? "لم تصل اللوحة إلى الخادم"
          : "اللوحة بصيغة غير مدعومة",
      code: image.error,
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
    const imageId = `chatimage_${Date.now()}_${crypto.randomUUID()}`;
    await writeRow(
      imageId,
      { type: "student_chat_image", ...scope, image: image.base64, mime: image.mime, time: now },
      now,
    );
    const id = `chat_${Date.now()}_${crypto.randomUUID()}`;
    await writeRow(id, { type: "student_chat", ...scope, name: student.name, message: "", imageId, time: now }, now);
    return res.status(201).json({
      message: { id, from: student.id, name: student.name, to: recipient, message: "", kind: "image", imageId, time: now },
    });
  } catch (error) {
    logger.error({ err: error, studentId: student.id }, "[student-chat] image send failed");
    return res.status(503).json({ error: "تعذر إرسال اللوحة الآن", code: "storage" });
  }
});

/** اللوحةُ لمن يرى رسالتَها وحده. ولا يحقّ له: 404 لا 403 — فلا يُعرف أنها موجودة. */
router.get("/student/chat/image/:id", requireStudentSession, imageFetchLimit, async (req, res) => {
  const student = activeStudent(res);
  if (!canUseChat(student)) {
    return res.status(403).json({ error: "الدردشة غير مفعلة لحسابك" });
  }
  const id = req.params.id;
  if (!isChatImageId(id)) return res.status(404).json({ error: "اللوحة غير موجودة" });
  try {
    const data = await storedRow(id);
    if (!data || data.type !== "student_chat_image" || !visibleToStudent(data, student) ||
        typeof data.image !== "string") {
      return res.status(404).json({ error: "اللوحة غير موجودة" });
    }
    return sendImage(res, data);
  } catch (error) {
    logger.error({ err: error }, "[student-chat] image load failed");
    return res.status(503).json({ error: "تعذر تحميل اللوحة الآن" });
  }
});

// ── «رسائل طلابي»: ما أرسله الطلابُ إلى معلّمهم ──────────────────────────
//
// المعلّمُ مستلمٌ كأيّ زميل (`teacher:<معرّفه>`)، فتجري عليه الدورةُ نفسها: يرى
// الرسالةَ ويغادر فتختفي عنده، ويرى الطالبُ أنها قُرئت، ثم تُحذف نهائياً.

/** المعلّمُ من جلسته — بمعرّفه كما يُقارن في نطاق الطلاب. */
function teacherReader(req: any): { key: string; recipient: string } | null {
  const actor = verifyTeacherSession(readCookie(req, TEACHER_SESSION_COOKIE));
  if (!actor || actor.role !== "teacher") return null;
  const key = normalizeScopeId(actor.teacherId);
  return key ? { key, recipient: teacherRecipient(key) } : null;
}

/** رسالةٌ إلى هذا المعلّم من طلابه. */
function toTeacher(data: Record<string, unknown>, teacher: { key: string; recipient: string }): boolean {
  return text(data.to) === teacher.recipient && normalizeScopeId(data.teacherId) === teacher.key;
}

router.get("/teacher/chat/messages", teacherChatLimit, async (req, res) => {
  const teacher = teacherReader(req);
  if (!teacher) return res.status(401).json({ error: "سجّل الدخول كمعلّم أولاً" });
  try {
    const now = new Date();
    const asked = Date.parse(text(req.query?.visit));
    const visit = Number.isFinite(asked) && asked <= now.getTime() && now.getTime() - asked < 24 * 3600e3
      ? new Date(asked)
      : now;
    const rows = (await readMessages()).filter((row) => toTeacher(dataOf(row), teacher));
    const receipts: ChatReceipt[] = [];
    let ephemeral = true;
    for (const part of chunks(rows.map((row) => text(row.id)))) {
      const found = await receiptsOfMessages(part);
      if (found === null) {
        ephemeral = false;
        break;
      }
      receipts.push(...found);
    }
    const messages = rows
      .filter((row) => {
        if (!ephemeral) return true;
        const meta = metaOf(row);
        return visibleTo(meta, teacher.recipient, [teacher.recipient], receipts, visit, now);
      })
      .map((row): Record<string, unknown> => ({ ...publicMessage(row), grade: text(dataOf(row).grade) }))
      .filter((message) => text(message.message) || message.kind === "voice" || message.kind === "image")
      .slice(-200);
    return res.json({ messages, ephemeral, visit: visit.toISOString() });
  } catch (error) {
    logger.error({ err: error }, "[teacher-chat] message load failed");
    return res.status(503).json({ error: "تعذر تحميل رسائل الطلاب الآن" });
  }
});

/** شاهد المعلّمُ هذه الرسائل: لا تعود له بعد مغادرته، ويرى الطالبُ أنها قُرئت. */
router.post("/teacher/chat/seen", teacherChatLimit, async (req, res) => {
  const teacher = teacherReader(req);
  if (!teacher) return res.status(401).json({ error: "سجّل الدخول كمعلّم أولاً" });
  const asked = Array.isArray(req.body?.ids) ? req.body.ids : [];
  const ids = [...new Set(asked.filter(isChatMessageId))].slice(0, 300) as string[];
  if (ids.length === 0) return res.json({ seen: 0, purged: 0 });
  try {
    const mine = (await readMessages()).filter((row) =>
      ids.includes(text(row.id)) && toTeacher(dataOf(row), teacher));
    // ‏إيصالٌ لكل صفّ: الصفُّ يُكنس بنطاقه.
    const byGrade = new Map<string, string[]>();
    for (const row of mine) {
      const grade = text(dataOf(row).grade);
      byGrade.set(grade, [...(byGrade.get(grade) ?? []), text(row.id)]);
    }
    let seen = 0;
    let purged = 0;
    for (const [grade, gradeIds] of byGrade) {
      const reader = { id: teacher.recipient, grade, teacherId: teacher.key };
      const written = await writeReceipts(reader, gradeIds.map((id) => ({ messageId: id, seen: true })));
      if (!written) return res.json({ seen, purged, ephemeral: false });
      seen += gradeIds.length;
      purged += await purgeClass({ grade, teacherId: teacher.key }, gradeIds).catch((error) => {
        logger.error({ err: error }, "[teacher-chat] purge after seen failed");
        return 0;
      });
    }
    return res.json({ seen, purged });
  } catch (error) {
    logger.error({ err: error }, "[teacher-chat] seen failed");
    return res.status(503).json({ error: "تعذر تحديث حالة الرسائل الآن" });
  }
});

/** لوحةٌ أو مقطعٌ أرسله طالبٌ إلى هذا المعلّم وحده. */
async function teacherMedia(req: any, res: any, kind: "image" | "voice") {
  const teacher = teacherReader(req);
  if (!teacher) return res.status(401).json({ error: "سجّل الدخول كمعلّم أولاً" });
  const id = String(req.params.id ?? "");
  const valid = kind === "image" ? isChatImageId(id) : isChatVoiceId(id);
  if (!valid) return res.status(404).json({ error: "غير موجود" });
  try {
    const data = await storedRow(id);
    const type = kind === "image" ? "student_chat_image" : "student_chat_voice";
    const field = kind === "image" ? "image" : "audio";
    if (!data || data.type !== type || !toTeacher(data, teacher) || typeof data[field] !== "string") {
      return res.status(404).json({ error: "غير موجود" });
    }
    if (kind === "image") return sendImage(res, data);
    res.setHeader(
      "Content-Type",
      typeof data.mime === "string" && data.mime.startsWith("audio/") ? data.mime : "audio/mp4",
    );
    res.setHeader("Cache-Control", "private, no-store");
    return res.status(200).send(Buffer.from(String(data.audio), "base64"));
  } catch (error) {
    logger.error({ err: error }, "[teacher-chat] media load failed");
    return res.status(503).json({ error: "تعذر التحميل الآن" });
  }
}

router.get("/teacher/chat/image/:id", teacherChatLimit, (req, res) => teacherMedia(req, res, "image"));
router.get("/teacher/chat/voice/:id", teacherChatLimit, (req, res) => teacherMedia(req, res, "voice"));

export default router;