import { Router, type RequestHandler } from "express";
import crypto from "node:crypto";
import {
  apiSupabaseConfig,
  listStudents,
  normalizeScopeId,
  type StudentActor,
} from "../lib/studentAccess";
import { requireStudentSession } from "../middleware/studentAuth";
import {
  buildTeacherDirectory,
  chatTeacherByKey,
  studentTeacherKey,
  teacherKeyOf,
  type TeacherDirectory,
} from "../lib/chatTeacher";
import { HIERARCHY_KEY } from "../lib/teacherScope";
import { readKv, rest as storeRest, storeConfig } from "../lib/supabaseStore";
import { readCookie, TEACHER_SESSION_COOKIE, verifyTeacherSession } from "../middleware/adminAuth";
import { isChatImageId, parseChatImage, teacherRecipient } from "../lib/chatImage";
import { CHAT_FILE_MAX_BYTES, isChatFileId, parseChatFile, storedFileBytes } from "../lib/chatFile";
import {
  applyLockChange,
  CHAT_LOCK_TYPE,
  CHAT_LOCKED_MESSAGE,
  chatLockRowId,
  emptyLock,
  isLockedFor,
  lockBlocks,
  readChatLock,
  type ChatLock,
} from "../lib/chatLock";
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
const fileSendLimit = createStudentRateLimit(10);
const fileFetchLimit = createStudentRateLimit(90);
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

// ── معلّمُ الصفّ: مفتاحٌ واحد من كل صوره ─────────────────────────────────
//
// انظر `lib/chatTeacher.ts`. يُقرأ جدولُ المعلمين وأولياءِ الأمور والشجرةُ
// الأكاديمية مرّةً كل دقيقة، لا مع كل رسالة.

const DIRECTORY_TTL_MS = 60_000;
let directoryCache: { at: number; directory: TeacherDirectory } | null = null;

async function teacherDirectory(): Promise<TeacherDirectory> {
  if (directoryCache && Date.now() - directoryCache.at < DIRECTORY_TTL_MS) return directoryCache.directory;
  const config = storeConfig();
  if (!config) return buildTeacherDirectory([]);
  const rows = (value: unknown) => (Array.isArray(value) ? value : []) as Array<{ id?: unknown; data?: unknown }>;
  const [teachers, parents, hierarchy] = await Promise.all([
    storeRest(config, "teachers?select=id,data&limit=2000").then(rows).catch(() => []),
    storeRest(config, "parents?select=id,data&limit=2000").then(rows).catch(() => []),
    readKv(config, HIERARCHY_KEY).catch(() => []),
  ]);
  const directory = buildTeacherDirectory(teachers, hierarchy, parents);
  // ‏جدولُ المعلمين غير مقروء: لا يُحفظ الفراغ، فيُعاد في الطلب التالي.
  if (teachers.length) directoryCache = { at: Date.now(), directory };
  return directory;
}

/** الطالبُ بمفتاح معلّمه المحسوب، لا بما كُتب في سجلّه حرفياً. */
function withTeacherKey(directory: TeacherDirectory, student: StudentActor): StudentActor {
  return { ...student, teacherId: studentTeacherKey(directory, student) };
}

/** بعد جلسة الطالب: يُستبدل معلّمُه بمفتاحه، فكلُّ ما بعده يقارن مفتاحاً واحداً. */
const resolveChatTeacher: RequestHandler = async (_req, res, next) => {
  try {
    const directory = await teacherDirectory();
    res.locals.student = withTeacherKey(directory, activeStudent(res));
  } catch (error) {
    logger.warn({ err: error }, "[chat] teacher directory unavailable");
  }
  next();
};


/** زملاءُ الصفّ: الصفُّ نفسه ومفتاحُ المعلّم نفسه، كلٌّ بمعلّمه المحسوب. */
async function findStudentsInScope(grade: string, teacherKey: string): Promise<StudentActor[]> {
  const [directory, students] = await Promise.all([teacherDirectory(), listStudents()]);
  const wantedGrade = normalizeScopeId(grade);
  const wantedTeacher = normalizeScopeId(teacherKey);
  return students
    .map((student) => withTeacherKey(directory, student))
    .filter((student) => student.canAccessChat && normalizeScopeId(student.grade) === wantedGrade &&
      student.teacherId === wantedTeacher);
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

// ── قفلُ الدردشة ──────────────────────────────────────────────────────

const lockCache = new Map<string, { lock: ChatLock; at: number }>();

/** قفلُ معلّمٍ [teacherKey] — من ذاكرةٍ قصيرة، فلا يُقرأ مع كل رسالة. */
async function lockOf(teacherKey: string): Promise<ChatLock> {
  if (!teacherKey) return emptyLock();
  const hit = lockCache.get(teacherKey);
  if (hit && Date.now() - hit.at < 5_000) return hit.lock;
  let lock = emptyLock();
  try {
    lock = readChatLock(await storedRow(chatLockRowId(teacherKey)));
  } catch (error) {
    // ‏تعذّرت قراءتُه: لا يُقفل أحدٌ بخطأ شبكة.
    logger.warn({ err: error }, "[student-chat] lock read failed");
  }
  lockCache.set(teacherKey, { lock, at: Date.now() });
  return lock;
}

async function chatLockedFor(student: StudentActor): Promise<boolean> {
  return isLockedFor(await lockOf(normalizeScopeId(student.teacherId)), student.id);
}

/** القفلُ يمنع هذا الإرسال: إلى المعلّم وحده — والزملاءُ مفتوحون. */
async function lockedTo(student: StudentActor, recipient: string): Promise<boolean> {
  return lockBlocks(await lockOf(normalizeScopeId(student.teacherId)), student.id, recipient);
}

/** 423: «المعلم قام بقفل الدردشة حالياً» — والتطبيقُ يعرضها كما هي. */
function sendLocked(res: any) {
  return res.status(423).json({ error: CHAT_LOCKED_MESSAGE, code: "chat_locked" });
}

async function saveLock(teacherKey: string, lock: ChatLock): Promise<void> {
  const id = chatLockRowId(teacherKey);
  const response = await rest("interactions?on_conflict=id", {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
    body: JSON.stringify({
      id,
      data: { type: CHAT_LOCK_TYPE, teacherId: teacherKey, ...lock },
      updated_at: lock.updatedAt || new Date().toISOString(),
    }),
  });
  if (!response.ok) throw new Error(`Lock write failed (${response.status})`);
  lockCache.set(teacherKey, { lock, at: Date.now() });
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
  const files = doomed
    .map((row) => dataOf(row).fileId)
    .filter((id): id is string => isChatFileId(id));
  for (const part of chunks([...ids, ...voices, ...images, ...files])) {
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
  const file = isChatFileId(data.fileId) ? data.fileId : "";
  const from = text(data.from);
  return {
    id: text(row.id),
    from,
    name: text(data.name) || (from.startsWith("teacher:") ? "معلّمي" : "طالب منارة"),
    to: text(data.to),
    message: text(data.message),
    time: text(data.time) || text(row.updated_at),
    ...(from.startsWith("teacher:") ? { fromTeacher: true } : {}),
    ...(file
      ? {
        kind: "file",
        fileId: file,
        fileName: text(data.fileName) || "ملف",
        fileSize: Math.min(Math.max(Number(data.fileSize) || 0, 0), CHAT_FILE_MAX_BYTES),
        mime: text(data.mime),
      }
      : image
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

router.get("/student/chat/peers", requireStudentSession, resolveChatTeacher, async (_req, res) => {
  const student = activeStudent(res);
  if (!canUseChat(student)) {
    return res.status(403).json({ error: "الدردشة غير مفعلة لحسابك" });
  }
  try {
    const peers = await findStudentsInScope(student.grade, student.teacherId);
    const teacher = teacherRecipient(student.teacherId);
    const known = chatTeacherByKey(await teacherDirectory(), student.teacherId);
    const teacherName = known ? `معلّمي: ${known.name}` : "معلّمي";
    return res.json({
      peers: [
        // ‏معلّمُ الصفّ أوّلاً: تصله الرسائلُ في «رسائل طلابي» في بوابته.
        ...(teacher ? [{ id: teacher, name: teacherName, teacher: true }] : []),
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
router.get("/student/chat/messages", requireStudentSession, resolveChatTeacher, async (req, res) => {
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
      .filter((message) => text(message.message) || message.kind !== "text")
      .slice(-120);
    if (ephemeral) {
      void purgeClass(student).catch((error) =>
        logger.error({ err: error }, "[student-chat] purge failed"));
    }
    const locked = await chatLockedFor(student);
    return res.json({ messages, ephemeral, saveHours: 24, visit: visit.toISOString(), locked });
  } catch (error) {
    logger.error({ err: error }, "[student-chat] message load failed");
    return res.status(503).json({ error: "تعذر تحميل الرسائل الآن" });
  }
});

router.post("/student/chat/messages", chatRateLimit, requireStudentSession, resolveChatTeacher, async (req, res) => {
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
    if (await lockedTo(student, recipient)) return sendLocked(res);
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
router.post("/student/chat/seen", requireStudentSession, resolveChatTeacher, receiptLimit, async (req, res) => {
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
router.post("/student/chat/save", requireStudentSession, resolveChatTeacher, receiptLimit, async (req, res) => {
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
router.post("/student/chat/voice", requireStudentSession, resolveChatTeacher, voiceSendLimit, async (req, res) => {
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
    if (await lockedTo(student, recipient)) return sendLocked(res);
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
router.get("/student/chat/voice/:id", requireStudentSession, resolveChatTeacher, voiceFetchLimit, async (req, res) => {
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
router.post("/student/chat/image", requireStudentSession, resolveChatTeacher, imageSendLimit, async (req, res) => {
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
    if (await lockedTo(student, recipient)) return sendLocked(res);
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
router.get("/student/chat/image/:id", requireStudentSession, resolveChatTeacher, imageFetchLimit, async (req, res) => {
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

// ── الملفاتُ والمستندات ──────────────────────────────────────────────────

function fileRejection(res: any, code: string) {
  return res.status(code === "tooBig" ? 413 : 400).json({
    error: code === "tooBig"
      ? "الملف أكبر من المسموح (1.5 ميغابايت)"
      : code === "missing"
        ? "لم يصل الملف إلى الخادم"
        : code === "format"
          ? "نوع الملف غير مدعوم — يُرسل PDF ووورد وإكسل وبوربوينت والنصوص والصور"
          : "الملف غير صالح",
    code,
  });
}

function sendFile(res: any, data: Record<string, unknown>) {
  const bytes = storedFileBytes(data);
  const name = text(data.fileName) || "file";
  res.setHeader("Content-Type", text(data.mime) || "application/octet-stream");
  res.setHeader("Content-Disposition", `attachment; filename*=UTF-8''${encodeURIComponent(name)}`);
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("Cache-Control", "private, no-store");
  return res.status(200).send(bytes);
}

/** يكتب الملفَّ في صفّه ثم الرسالةَ التي تشير إليه. */
async function writeFileMessage(
  scope: { from: string; to: string; grade: string; teacherId: string },
  name: string,
  file: { base64: string; gzip: boolean; bytes: number; mime: string; name: string },
) {
  const now = new Date().toISOString();
  const fileId = `chatfile_${Date.now()}_${crypto.randomUUID()}`;
  await writeRow(
    fileId,
    { type: "student_chat_file", ...scope, file: file.base64, gzip: file.gzip, mime: file.mime, fileName: file.name, time: now },
    now,
  );
  const id = `chat_${Date.now()}_${crypto.randomUUID()}`;
  const meta = { fileId, fileName: file.name, fileSize: file.bytes, mime: file.mime };
  await writeRow(id, { type: "student_chat", ...scope, name, message: "", ...meta, time: now }, now);
  return { id, from: scope.from, name, to: scope.to, message: "", kind: "file", ...meta, time: now };
}

/** ملفٌّ أو مستند: إلى الصفّ، أو زميل، أو المعلّم. */
router.post("/student/chat/file", requireStudentSession, resolveChatTeacher, fileSendLimit, async (req, res) => {
  const student = activeStudent(res);
  if (!canUseChat(student)) {
    return res.status(403).json({ error: "الدردشة غير مفعلة لحسابك" });
  }
  const file = parseChatFile(req.body?.file, req.body?.name, req.body?.gzip);
  if (!file.ok) {
    logger.warn({ studentId: student.id, code: file.error }, "[student-chat] file rejected");
    return fileRejection(res, file.error);
  }
  try {
    const recipient = await recipientFor(student, text(req.body?.to) || "all");
    if (!recipient) {
      return res.status(403).json({ error: "لا يمكنك إرسال رسالة إلى هذا الحساب" });
    }
    if (await lockedTo(student, recipient)) return sendLocked(res);
    const message = await writeFileMessage(
      { from: student.id, to: recipient, grade: student.grade, teacherId: student.teacherId },
      student.name,
      file,
    );
    return res.status(201).json({ message });
  } catch (error) {
    logger.error({ err: error, studentId: student.id }, "[student-chat] file send failed");
    return res.status(503).json({ error: "تعذر إرسال الملف الآن", code: "storage" });
  }
});

router.get("/student/chat/file/:id", requireStudentSession, resolveChatTeacher, fileFetchLimit, async (req, res) => {
  const student = activeStudent(res);
  if (!canUseChat(student)) {
    return res.status(403).json({ error: "الدردشة غير مفعلة لحسابك" });
  }
  const id = req.params.id;
  if (!isChatFileId(id)) return res.status(404).json({ error: "الملف غير موجود" });
  try {
    const data = await storedRow(id);
    if (!data || data.type !== "student_chat_file" || !visibleToStudent(data, student) ||
        typeof data.file !== "string") {
      return res.status(404).json({ error: "الملف غير موجود" });
    }
    return sendFile(res, data);
  } catch (error) {
    logger.error({ err: error }, "[student-chat] file load failed");
    return res.status(503).json({ error: "تعذر تحميل الملف الآن" });
  }
});

// ── «رسائل طلابي»: ما أرسله الطلابُ إلى معلّمهم ──────────────────────────
//
// المعلّمُ مستلمٌ كأيّ زميل (`teacher:<معرّفه>`)، فتجري عليه الدورةُ نفسها: يرى
// الرسالةَ ويغادر فتختفي عنده، ويرى الطالبُ أنها قُرئت، ثم تُحذف نهائياً.

/** المعلّمُ من جلسته — بمعرّفه كما يُقارن في نطاق الطلاب. */
async function teacherReader(req: any): Promise<{ key: string; recipient: string } | null> {
  const actor = verifyTeacherSession(readCookie(req, TEACHER_SESSION_COOKIE));
  if (!actor || actor.role !== "teacher") return null;
  // ‏بمفتاحه في الدليل، كما يُحسب لطلابه — لا بالمعرّف الذي دخل به حرفياً.
  const key = teacherKeyOf(await teacherDirectory().catch(() => buildTeacherDirectory([])), actor.teacherId);
  return key ? { key, recipient: teacherRecipient(key) } : null;
}

/** رسالةٌ إلى هذا المعلّم من طلابه. */
function toTeacher(data: Record<string, unknown>, teacher: { key: string; recipient: string }): boolean {
  return text(data.to) === teacher.recipient && normalizeScopeId(data.teacherId) === teacher.key;
}

/** رسالةٌ أرسلها هذا المعلّمُ إلى أحد طلابه. */
function fromTeacher(data: Record<string, unknown>, teacher: { key: string; recipient: string }): boolean {
  return text(data.from) === teacher.recipient && normalizeScopeId(data.teacherId) === teacher.key;
}

/** في محادثة هذا المعلّم: إليه أو منه. */
function teacherThread(data: Record<string, unknown>, teacher: { key: string; recipient: string }): boolean {
  return toTeacher(data, teacher) || fromTeacher(data, teacher);
}

/** طلابُ هذا المعلّم كلُّهم، بكل صفوفه. */
async function studentsOfTeacher(teacherKey: string): Promise<StudentActor[]> {
  const [directory, students] = await Promise.all([teacherDirectory(), listStudents()]);
  return students
    .map((student) => withTeacherKey(directory, student))
    .filter((student) => student.teacherId === teacherKey);
}

/** طالبٌ من طلاب هذا المعلّم بمعرّفه، وإلا `null`. */
async function teacherStudent(teacherKey: string, id: string): Promise<StudentActor | null> {
  if (!id) return null;
  return (await studentsOfTeacher(teacherKey)).find((student) => student.id === id) ?? null;
}

/** نطاقُ رسالةٍ من المعلّم إلى [student]: صفُّ الطالب كما هو مخزَّن. */
function teacherScope(teacher: { recipient: string }, student: StudentActor) {
  return { from: teacher.recipient, to: student.id, grade: student.grade, teacherId: student.teacherId };
}

const TEACHER_NAME = "المعلّم";

router.get("/teacher/chat/messages", teacherChatLimit, async (req, res) => {
  const teacher = await teacherReader(req);
  if (!teacher) return res.status(401).json({ error: "سجّل الدخول كمعلّم أولاً" });
  try {
    const now = new Date();
    const asked = Date.parse(text(req.query?.visit));
    const visit = Number.isFinite(asked) && asked <= now.getTime() && now.getTime() - asked < 24 * 3600e3
      ? new Date(asked)
      : now;
    const rows = (await readMessages()).filter((row) => teacherThread(dataOf(row), teacher));
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
    // ‏رسالةٌ «لجميع الطلاب» مستلموها طلابُ صفّها كلُّهم، لا طالبٌ واحد.
    const classOf = new Map<string, string[]>();
    for (const row of rows) {
      const data = dataOf(row);
      const grade = text(data.grade);
      if (text(data.to) === "all" && !classOf.has(grade)) {
        classOf.set(grade, (await findStudentsInScope(grade, teacher.key)).map((p) => p.id));
      }
    }
    const recipientsFor = (row: Record<string, unknown>) => {
      const meta = metaOf(row);
      if (meta.from !== teacher.recipient) return [teacher.recipient];
      return meta.to === "all" ? classOf.get(text(dataOf(row).grade)) ?? [] : [meta.to];
    };
    const messages = rows
      .filter((row) => {
        if (!ephemeral) return true;
        return visibleTo(metaOf(row), teacher.recipient, recipientsFor(row), receipts, visit, now);
      })
      .map((row): Record<string, unknown> => {
        const meta = metaOf(row);
        const out: Record<string, unknown> = { ...publicMessage(row), grade: text(dataOf(row).grade) };
        if (meta.from === teacher.recipient) {
          out.mine = true;
          const recipients = recipientsFor(row);
          out.readByAll = allSeenAt(meta, recipients, receipts) !== null;
          if (meta.to === "all") {
            out.recipients = recipients.length;
            out.seenCount = seenBy(meta, recipients, receipts).length;
          }
        }
        return out;
      })
      .filter((message) => text(message.message) || message.kind !== "text")
      .slice(-300);
    const lock = await lockOf(teacher.key);
    return res.json({ messages, ephemeral, visit: visit.toISOString(), lock: { all: lock.all, students: lock.students } });
  } catch (error) {
    logger.error({ err: error }, "[teacher-chat] message load failed");
    return res.status(503).json({ error: "تعذر تحميل رسائل الطلاب الآن" });
  }
});

/** شاهد المعلّمُ هذه الرسائل: لا تعود له بعد مغادرته، ويرى الطالبُ أنها قُرئت. */
router.post("/teacher/chat/seen", teacherChatLimit, async (req, res) => {
  const teacher = await teacherReader(req);
  if (!teacher) return res.status(401).json({ error: "سجّل الدخول كمعلّم أولاً" });
  const asked = Array.isArray(req.body?.ids) ? req.body.ids : [];
  const ids = [...new Set(asked.filter(isChatMessageId))].slice(0, 300) as string[];
  if (ids.length === 0) return res.json({ seen: 0, purged: 0 });
  try {
    const mine = (await readMessages()).filter((row) =>
      ids.includes(text(row.id)) && teacherThread(dataOf(row), teacher));
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

/** مقطعٌ أو صورةٌ أو ملفٌّ في محادثة هذا المعلّم وحدها: إليه أو منه. */
async function teacherMedia(req: any, res: any, kind: "voice" | "image" | "file") {
  const teacher = await teacherReader(req);
  if (!teacher) return res.status(401).json({ error: "سجّل الدخول كمعلّم أولاً" });
  const id = String(req.params.id ?? "");
  const valid = kind === "voice" ? isChatVoiceId(id) : kind === "image" ? isChatImageId(id) : isChatFileId(id);
  if (!valid) return res.status(404).json({ error: "غير موجود" });
  const field = kind === "voice" ? "audio" : kind;
  try {
    const data = await storedRow(id);
    if (!data || data.type !== `student_chat_${kind}` || !teacherThread(data, teacher) ||
        typeof data[field] !== "string") {
      return res.status(404).json({ error: "غير موجود" });
    }
    if (kind === "image") return sendImage(res, data);
    if (kind === "file") return sendFile(res, data);
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

router.get("/teacher/chat/voice/:id", teacherChatLimit, (req, res) => teacherMedia(req, res, "voice"));
router.get("/teacher/chat/image/:id", teacherChatLimit, (req, res) => teacherMedia(req, res, "image"));
router.get("/teacher/chat/file/:id", teacherChatLimit, (req, res) => teacherMedia(req, res, "file"));

// ── المعلّمُ يراسل طلابه ويقفل الدردشة ─────────────────────────────────────

/** قائمةُ طلاب المعلّم للدردشة، ومن منهم مقفولٌ عليه. */
router.get("/teacher/chat/students", teacherChatLimit, async (req, res) => {
  const teacher = await teacherReader(req);
  if (!teacher) return res.status(401).json({ error: "سجّل الدخول كمعلّم أولاً" });
  try {
    const [students, lock] = await Promise.all([studentsOfTeacher(teacher.key), lockOf(teacher.key)]);
    return res.json({
      students: students
        .map((student) => ({
          id: student.id,
          name: student.name || student.username || "طالب",
          grade: student.grade,
          chat: student.canAccessChat,
          locked: isLockedFor(lock, student.id),
        }))
        .sort((a, b) => a.grade.localeCompare(b.grade, "ar") || a.name.localeCompare(b.name, "ar")),
      lock: { all: lock.all, students: lock.students },
    });
  } catch (error) {
    logger.error({ err: error }, "[teacher-chat] students load failed");
    return res.status(503).json({ error: "تعذر تحميل الطلاب الآن" });
  }
});

type TeacherScope = ReturnType<typeof teacherScope>;

/**
 * يحلّ المستلمَ أو يردّ بالخطأ: طالبٌ من طلاب المعلّم، أو `all` — جميعُ طلابه.
 *
 * ── «لجميع الطلاب»: رسالةٌ لكل صفّ ──
 * طلابُ المعلّم في صفوفٍ مختلفة، والطالبُ يرى ما في صفّه وحده. فتُكتب الرسالةُ مرّةً
 * لكل صفّ، إلى `all` فيه — كرسالة الطالب إلى صفّه. فتجري عليها دورةُ القراءة نفسها:
 * يراها كلُّ طالب، ويرى المعلّمُ كم شاهدها، وتُحذف حين يشاهدها الصفُّ كلُّه.
 */
async function teacherTargets(req: any, res: any): Promise<{ teacher: { key: string; recipient: string }; scopes: TeacherScope[] } | null> {
  const teacher = await teacherReader(req);
  if (!teacher) {
    res.status(401).json({ error: "سجّل الدخول كمعلّم أولاً" });
    return null;
  }
  const to = text(req.body?.to);
  if (to === "all") {
    const byGrade = new Map<string, TeacherScope>();
    for (const student of await studentsOfTeacher(teacher.key)) {
      if (!student.canAccessChat) continue;
      const grade = normalizeScopeId(student.grade);
      if (grade && !byGrade.has(grade)) {
        byGrade.set(grade, { ...teacherScope(teacher, student), to: "all" });
      }
    }
    if (byGrade.size === 0) {
      res.status(404).json({ error: "لا يوجد طلاب مربوطون بك بعد", code: "no_students" });
      return null;
    }
    return { teacher, scopes: [...byGrade.values()] };
  }
  const student = await teacherStudent(teacher.key, to);
  if (!student) {
    res.status(403).json({ error: "هذا الطالب ليس من طلابك", code: "not_your_student" });
    return null;
  }
  return { teacher, scopes: [teacherScope(teacher, student)] };
}

router.post("/teacher/chat/messages", teacherChatLimit, async (req, res) => {
  const message = text(req.body?.message);
  if (!message || message.length > 2000) {
    return res.status(400).json({ error: "الرسالة يجب أن تكون بين 1 و2000 حرف" });
  }
  try {
    const target = await teacherTargets(req, res);
    if (!target) return;
    const now = new Date().toISOString();
    const sent: Record<string, unknown>[] = [];
    for (const scope of target.scopes) {
      const id = `chat_${Date.now()}_${crypto.randomUUID()}`;
      const data = { type: "student_chat", ...scope, name: TEACHER_NAME, message, time: now };
      await writeRow(id, data, now);
      sent.push({ id, ...data, kind: "text", mine: true });
    }
    return res.status(201).json({ message: sent[0], classes: sent.length });
  } catch (error) {
    logger.error({ err: error }, "[teacher-chat] send failed");
    return res.status(503).json({ error: "تعذر إرسال الرسالة الآن" });
  }
});

router.post("/teacher/chat/voice", teacherChatLimit, async (req, res) => {
  const note = parseChatVoice(req.body?.audio, req.body?.durationMs);
  if (!note.ok) {
    return res.status(400).json({ error: "الرسالة الصوتية غير صالحة", code: note.error });
  }
  try {
    const target = await teacherTargets(req, res);
    if (!target) return;
    const now = new Date().toISOString();
    const sent: Record<string, unknown>[] = [];
    for (const scope of target.scopes) {
      const voiceId = `chatvoice_${Date.now()}_${crypto.randomUUID()}`;
      await writeRow(voiceId, { type: "student_chat_voice", ...scope, audio: note.base64, mime: note.mime, time: now }, now);
      const id = `chat_${Date.now()}_${crypto.randomUUID()}`;
      const data = { type: "student_chat", ...scope, name: TEACHER_NAME, message: "", voiceId, durationMs: note.durationMs, time: now };
      await writeRow(id, data, now);
      sent.push({ ...data, id, kind: "voice", mine: true });
    }
    return res.status(201).json({ message: sent[0], classes: sent.length });
  } catch (error) {
    logger.error({ err: error }, "[teacher-chat] voice send failed");
    return res.status(503).json({ error: "تعذر إرسال الرسالة الصوتية الآن" });
  }
});

router.post("/teacher/chat/image", teacherChatLimit, async (req, res) => {
  const image = parseChatImage(req.body?.image);
  if (!image.ok) {
    return res.status(image.error === "tooBig" ? 413 : 400).json({ error: "الصورة غير صالحة أو كبيرة", code: image.error });
  }
  try {
    const target = await teacherTargets(req, res);
    if (!target) return;
    const now = new Date().toISOString();
    const sent: Record<string, unknown>[] = [];
    for (const scope of target.scopes) {
      const imageId = `chatimage_${Date.now()}_${crypto.randomUUID()}`;
      await writeRow(imageId, { type: "student_chat_image", ...scope, image: image.base64, mime: image.mime, time: now }, now);
      const id = `chat_${Date.now()}_${crypto.randomUUID()}`;
      const data = { type: "student_chat", ...scope, name: TEACHER_NAME, message: "", imageId, time: now };
      await writeRow(id, data, now);
      sent.push({ ...data, id, kind: "image", mine: true });
    }
    return res.status(201).json({ message: sent[0], classes: sent.length });
  } catch (error) {
    logger.error({ err: error }, "[teacher-chat] image send failed");
    return res.status(503).json({ error: "تعذر إرسال الصورة الآن" });
  }
});

router.post("/teacher/chat/file", teacherChatLimit, async (req, res) => {
  const file = parseChatFile(req.body?.file, req.body?.name, req.body?.gzip);
  if (!file.ok) return fileRejection(res, file.error);
  try {
    const target = await teacherTargets(req, res);
    if (!target) return;
    const sent: Record<string, unknown>[] = [];
    for (const scope of target.scopes) {
      sent.push({ ...(await writeFileMessage(scope, TEACHER_NAME, file)), mine: true });
    }
    return res.status(201).json({ message: sent[0], classes: sent.length });
  } catch (error) {
    logger.error({ err: error }, "[teacher-chat] file send failed");
    return res.status(503).json({ error: "تعذر إرسال الملف الآن" });
  }
});

/** قفلُ الدردشة الحاليّ. */
router.get("/teacher/chat/lock", teacherChatLimit, async (req, res) => {
  const teacher = await teacherReader(req);
  if (!teacher) return res.status(401).json({ error: "سجّل الدخول كمعلّم أولاً" });
  lockCache.delete(teacher.key);
  const lock = await lockOf(teacher.key);
  return res.json({ lock: { all: lock.all, students: lock.students } });
});

/** يقفل أو يفتح: `{ all }` للجميع، أو `{ studentId, locked }` لطالب. */
router.post("/teacher/chat/lock", teacherChatLimit, async (req, res) => {
  const teacher = await teacherReader(req);
  if (!teacher) return res.status(401).json({ error: "سجّل الدخول كمعلّم أولاً" });
  try {
    lockCache.delete(teacher.key);
    const current = await lockOf(teacher.key);
    if (typeof req.body?.studentId === "string" && !(await teacherStudent(teacher.key, text(req.body.studentId)))) {
      return res.status(403).json({ error: "هذا الطالب ليس من طلابك", code: "not_your_student" });
    }
    const next = applyLockChange(current, req.body);
    if (!next) return res.status(400).json({ error: "طلب القفل ناقص", code: "bad_request" });
    await saveLock(teacher.key, next);
    return res.json({ lock: { all: next.all, students: next.students } });
  } catch (error) {
    logger.error({ err: error }, "[teacher-chat] lock failed");
    return res.status(503).json({ error: "تعذر تغيير قفل الدردشة الآن" });
  }
});

export default router;