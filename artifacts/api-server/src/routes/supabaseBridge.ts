import { Router, type Request, type Response } from "express";
import { getContentActor, getReaderActor } from "../middleware/adminAuth";
import { logger } from "../lib/logger";
import {
  BANK_SIZE,
  BANK_VERSION,
  detectSubject,
  parseBank,
  readBank,
} from "../lib/challengeBank";
import { generateChallengeBank } from "../lib/geminiBank";

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
  "smartEdu_deletedStudents",
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

/**
 * تسوية اسم المالك للمقارنة.
 *
 * كانت المقارنة قصّ مسافات لا غير: «Test» و«test» مالكان مختلفان عندها،
 * وكذلك «برداوي» و«برداوى». وأثرها هنا أسوأ من حجب: إعداد المعلم يُعدّ
 * لغيره فيُحفظ في `retained` **ويُضاف** إليه ما أرسله، فيتضاعف الصفّ في
 * الشجرة عند كل حفظ.
 */
function normalizeOwner(value: unknown): string {
  return stringValue(value)
    .toLowerCase()
    .replace(/[\u064B-\u0652\u0670\u0640]/g, "")
    .replace(/[\u0623\u0625\u0622\u0671]/g, "\u0627")
    .replace(/\u0649/g, "\u064A")
    .replace(/\u0629/g, "\u0647")
    .replace(/\s+/g, " ")
    .trim();
}

function ownerKey(value: unknown): string {
  return normalizeOwner(recordOwner(value));
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

const HIERARCHY_KEY = "smartEdu_hierarchicalConfigs";

/**
 * يدمج شجرة معلم مع شجرة المنصّة.
 *
 * كان المفتاح للمشرف وحده، فإعدادات المعلم لم تكن تصل إلى قاعدة
 * البيانات أبداً: يبني شجرته في متصفّحه، ويراها أمامه، ولا يراها طلابه.
 *
 * والسماح له بالكتابة لا يعني تسليمه المفتاح كله: إعداداته وحدها تُستبدل،
 * وما يملكه غيره يُحفظ كما هو من النسخة المخزّنة — نفس عقد `mergeTeacherVideos`.
 */
function mergeTeacherConfigs(
  remoteValue: unknown,
  requestedValue: unknown,
  identities: Set<string>,
): Record<string, unknown>[] {
  const mine = (config: unknown) => identities.has(ownerKey(config));
  // ما أرسله المعلم هو حاله كاملاً: ما حذفه ليس فيه، فلا يعود.
  const requested = asRecords(requestedValue).filter(mine);
  // وما لا يملكه يُحفظ كما هو من النسخة المخزّنة — قوالب المشرف وشجرات
  // بقية المعلمين — فلا يمحوها حفظُ أحدهم.
  const retained = asRecords(remoteValue).filter((config) => !mine(config));
  return [...retained, ...requested];
}

/**
 * الأسماء التي يُعرف بها هذا المعلم في سجلّات الملكية.
 *
 * الملكية تُكتب نصّاً: معرّفاً أحياناً، واسم دخول أو اسماً معروضاً أحياناً
 * أخرى. فإذا أُعيدت تسمية المعلم صار لنفس الشخص مالكان — والقديم يقع
 * خارج «ما يملكه» فيُحفظ في `retained` عند كل حفظ: يحذفه المعلم من شاشته
 * فيعود إليه عند الحفظ التالي، ولا سبيل له إلى إزالته أبداً.
 *
 * واسمٌ يتقاسمه معلّمان يسقط من القائمة: لو بقي لاستطاع أحدهما أن يمحو
 * شجرة الآخر بحفظ واحد. المعرّف وحده مضمون التفرّد، وما سواه يُقبل بشرط
 * ألّا يدلّ على غيره.
 */
async function teacherIdentities(
  config: SupabaseConfig,
  teacherId: string,
): Promise<Set<string>> {
  const identities = new Set<string>([normalizeOwner(teacherId)]);
  identities.delete("");
  try {
    const rows = asRecords(await rest(config, "teachers?select=id,data&limit=2000"));
    const mine: string[] = [];
    const others = new Set<string>();
    for (const row of rows) {
      const data = (row.data && typeof row.data === "object"
        ? row.data
        : {}) as Record<string, unknown>;
      const names = [row.id, data.id, data.username, data.name]
        .map(normalizeOwner)
        .filter(Boolean);
      const isMine = names.includes(normalizeOwner(teacherId));
      for (const name of names) {
        if (isMine) mine.push(name);
        else others.add(name);
      }
    }
    for (const name of mine) {
      if (!others.has(name)) identities.add(name);
    }
  } catch (error) {
    // تعذّرت القراءة: يبقى المعرّف وحده. الحفظ يمضي، وأسوأ ما يقع أن
    // يبقى سجلٌّ باسم قديم كما كان قبل اليوم — لا أن يُفقد عمل أحد.
    logger.warn({ err: error, teacherId }, "[supabase] teacher identities unavailable");
  }
  return identities;
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
  if (actor.role === "admin") return true;
  // المعلم يكتب فيديوهاته وشجرته الأكاديمية؛ وكلاهما يُدمج أدناه
  // فلا يمسّ ما يملكه غيره.
  return key === VIDEO_KEY || key === HIERARCHY_KEY;
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

/**
 * الجداول التي يُسمح لولي الأمر بقراءتها. أي جدول خارج هذه القائمة يعيد له
 * قائمة فارغة — قائمة سماح لا قائمة منع، فالجدول الذي يُضاف لاحقاً يكون
 * محجوباً عنه تلقائياً حتى يُقرَّر خلاف ذلك صراحةً.
 */
const PARENT_READABLE_TABLES = new Set([
  "parents",
  "students",
  "quiz_results",
  "certificates",
]);

/**
 * معرّفات أبناء ولي الأمر — عبر `parentId` الصريح وحده.
 *
 * كان هنا ارتداد إلى مطابقة رقم الجوال عند غياب `parentId`، وهو ثغرة على
 * حدّ أمني حقيقي: وليّا أمرٍ يحملان الرقم نفسه — خطأ إدخال وارد جداً — كان
 * يقرأ كلٌّ منهما سجلات أبناء الآخر ونتائجهم وشهاداتهم من الخادم مباشرة.
 *
 * الطالب الذي لم يُرحَّل بعد ينقطع عن وليّه هنا. وهذا مقصود: الانقطاع
 * المرئي أهون من ربط خاطئ صامت، وترحيل `parentId` يقع آلياً أول مرة يفتح
 * فيها مشرف أو معلم لوحته.
 */
async function parentChildIds(
  config: SupabaseConfig,
  parentId: string,
): Promise<{ childIds: Set<string>; childRows: Record<string, unknown>[] }> {
  const students = asRecords(await rest(config, "students?select=id,data"));
  const childRows = students.filter((row) => {
    const data = row.data && typeof row.data === "object"
      ? (row.data as Record<string, unknown>)
      : row;
    return stringValue(data.parentId) === parentId;
  });

  const childIds = new Set(
    childRows
      .map((row) => stringValue(row.id) || stringValue((row.data as Record<string, unknown>)?.id))
      .filter(Boolean),
  );
  return { childIds, childRows };
}

/** يقصر صفوف جدول على ما يخصّ أبناء ولي الأمر. */
function scopeRowsToParent(
  rows: Record<string, unknown>[],
  table: string,
  parentId: string,
  childIds: Set<string>,
  childRows: Record<string, unknown>[],
): Record<string, unknown>[] {
  if (table === "parents") {
    return rows.filter((row) => stringValue(row.id) === parentId);
  }
  if (table === "students") {
    return childRows;
  }
  if (table === "quiz_results" || table === "certificates") {
    return rows.filter((row) => {
      const data = row.data && typeof row.data === "object"
        ? (row.data as Record<string, unknown>)
        : row;
      const studentId = stringValue(data.studentId);
      return Boolean(studentId) && childIds.has(studentId);
    });
  }
  return [];
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
  const actor = getReaderActor(req);
  if (!actor) {
    res.status(401).json({ error: "يجب تسجيل الدخول لمزامنة البيانات" });
    return;
  }
  if (actor.role === "admin") {
    res.json({ role: "admin", scope: "admin" });
    return;
  }
  if (actor.role === "parent") {
    res.json({
      role: "parent",
      parentId: actor.parentId,
      scope: `parent:${actor.parentId}`,
    });
    return;
  }
  res.json({ role: "teacher", teacherId: actor.teacherId, scope: `teacher:${actor.teacherId}` });
});

/**
 * مفاتيح `app_kv` المتاحة لولي الأمر: بنية أكاديمية لا بيانات أشخاص.
 * لوحته تحتاجها لعرض أسماء الصفوف والمواد في تقدّم أبنائه.
 */
/**
 * ختم المحتوى: يُقرأ ولا يُكتب من المتصفح.
 *
 * ولم يكن يُقرأ أصلاً. الجسر لا يخدم إلا مفاتيح `SYNC_KV_KEYS`، وهذا
 * ليس منها، فكان المتصفح يسأل عن الختم فلا يجده، فيمضي على نسخته
 * القديمة. وكل ختمٍ رُفع بعد تنظيف قاعدة البيانات ذهب بلا أثر: لا
 * جهازٌ أسقط نسخته، ولا معلّمٌ رأى ما نُظّف. وهذا وحده كان يُبقي
 * الدروس المحذوفة ظاهرةً بعد حذفها.
 *
 * وهو خارج `SYNC_KV_KEYS` عمداً: مفتاحٌ لا يعرفه الرفع يُتخطّى صامتاً،
 * فيبقى الختم بيد من ينظّف وحده ولا يكتبه متصفّحٌ فوق نفسه.
 */
const CONTENT_EPOCH_KEY = "smartEdu_contentEpoch";

const PARENT_READABLE_KV = new Set([
  "smartEdu_grades",
  "smartEdu_subjects",
  "smartEdu_terms",
  "smartEdu_units",
  "smartEdu_hierarchicalConfigs",
  "smartEdu_gradeConfigs",
]);

router.get("/supabase/app_kv", async (req: Request, res: Response) => {
  const actor = getReaderActor(req);
  if (!actor) {
    res.status(401).json({ error: "يجب تسجيل الدخول لمزامنة المحتوى" });
    return;
  }
  const config = getSupabaseConfig();
  if (!config) {
    res.status(503).json({ error: "Supabase is not configured on the API server" });
    return;
  }

  try {
    // ولي الأمر يقرأ البنية الأكاديمية فقط، فلا داعي لجلب البقية أصلاً.
    const keys = actor.role === "parent"
      ? Array.from(SYNC_KV_KEYS).filter((key) => PARENT_READABLE_KV.has(key))
      : Array.from(SYNC_KV_KEYS);
    // الختم لكل دور: من لا يقرؤه لا يعرف أن نسخته بطلت.
    keys.push(CONTENT_EPOCH_KEY);
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
        // المعلم يرى مقاطعه وحده. وولي الأمر لا يصل هنا أصلاً: مفتاح
        // السينما ليس في `PARENT_READABLE_KV`، فلا يُجلب له.
        value: key === VIDEO_KEY && actor.role === "teacher"
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
        : key === HIERARCHY_KEY && actor.role !== "admin"
          ? mergeTeacherConfigs(
              remoteValue,
              row.value,
              await teacherIdentities(config, actor.teacherId),
            )
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
  const actor = getReaderActor(req);
  const table = tableName(req);
  if (!actor) {
    res.status(401).json({ error: "يجب تسجيل الدخول لمزامنة البيانات" });
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
    // ولي الأمر: قائمة سماح للجداول، ثم قصر الصفوف على أبنائه. الجدول غير
    // المسموح يعيد قائمة فارغة لا 403 — فالمزامنة تمرّ على كل الجداول
    // بالتتابع، و403 على واحد منها يُظهر لولي الأمر شريط خطأ أحمر على شيء
    // ليس خطأ أصلاً.
    if (actor.role === "parent") {
      if (!PARENT_READABLE_TABLES.has(table)) {
        res.json([]);
        return;
      }
      const { childIds, childRows } = await parentChildIds(config, actor.parentId);
      const rows = table === "students"
        ? []
        : asRecords(await rest(config, `${table}?select=id,data`));
      res.json(scopeRowsToParent(rows, table, actor.parentId, childIds, childRows));
      return;
    }

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

/**
 * يولّد بنك جولات التحدي للدروس التي تغيّر نصُّها، في الخلفية.
 *
 * ── متى يُعاد التوليد ──
 * حين لا يكون للدرس بنك، أو حين يتغيّر نصّه. والنصّ يُبصَم بطوله وأوّله
 * وآخره في البنك نفسه: مقارنةُ البصمة أرخص من الاحتفاظ بنسخةٍ ثانية من
 * النصّ، ومعلّمٌ يصحّح فاصلةً لا يُنفق عليه توليدٌ جديد لأن الطول تغيّر
 * — بل يُنفق، وذلك مقبول: التصحيح نادر والتوليد رخيص، والبديل بنكٌ
 * يسأل عن نصٍّ لم يعد موجوداً.
 *
 * ── ولا يُنتظر ──
 * يعمل بعد أن يردّ المسار. فشلُه يُسجَّل ولا يُرى، والبنك يُولَّد عند
 * أوّل فتحةٍ للتحدي إن لم يُولَّد هنا.
 */
async function refreshChallengeBanks(rows: Record<string, unknown>[]): Promise<void> {
  const config = getSupabaseConfig();
  if (!config || !process.env.GEMINI_API_KEY?.trim()) return;

  for (const row of rows) {
    const id = stringValue(row.id);
    const data = row.data && typeof row.data === "object"
      ? (row.data as Record<string, unknown>)
      : null;
    if (!id || !data) continue;
    const text = stringValue(data.lessonContent) || stringValue(data.lessonText);
    if (!text) continue;

    const stamp = lessonStamp(text);
    const existing = readBank(data.challengeBank);
    if (existing && (existing as any).lessonStamp === stamp) continue;

    try {
      const raw = await generateChallengeBank({
        subject: stringValue(data.subject),
        unit: stringValue(data.unit),
        lesson: stringValue(data.lesson),
        lessonText: text,
      });
      const { rounds } = parseBank(raw, detectSubject(data.subject));
      if (rounds.length < BANK_SIZE / 2) {
        logger.warn({ id, got: rounds.length }, "[bridge] bank too small to save");
        continue;
      }
      await rest(config, `lesson_configs?id=eq.${encodeURIComponent(id)}`, {
        method: "PATCH",
        headers: { Prefer: "return=minimal" },
        body: JSON.stringify({
          // السجلّ كاملاً ومعه البنك: `PATCH` على `data` يستبدلها، فكتابةُ
          // البنك وحده تمحو نصّ الدرس ومساره.
          data: {
            ...data,
            challengeBank: {
              version: BANK_VERSION,
              generatedAt: new Date().toISOString(),
              subject: stringValue(data.subject),
              lessonStamp: stamp,
              rounds,
            },
          },
          updated_at: new Date().toISOString(),
        }),
      });
      logger.info({ id, rounds: rounds.length }, "[bridge] challenge bank refreshed");
    } catch (error) {
      logger.error({ err: error, id }, "[bridge] challenge bank generation failed");
    }
  }
}

/** بصمةُ نصٍّ: طولُه وطرفاه. تكفي لكشف تغيّره بلا حفظ نسخةٍ منه. */
function lessonStamp(text: string): string {
  return `${text.length}:${text.slice(0, 24)}:${text.slice(-24)}`;
}

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
    // جدول المعلمين وحده يُستثنى من الرفض: نسخة المتصفح عند المعلم تحمل
    // كل المعلمين — يحتاجها ليسجّل دخوله ويرى الأسماء — فأي حفظ للجدول
    // يرسلهم جميعاً، ولمسة واحدة على `lastActivity` عند الدخول تكفي
    // لإطلاقه. فكان الردّ رفضاً يُسقط الكتابة كلّها ويُظهر الشريط الأحمر
    // «حفظ teachers» في وجه المعلم قبل أن يفعل شيئاً.
    //
    // فيُكتب الآن سجلّه هو — وبه يحفظ حسابه فعلاً — ويُهمل ما سواه بلا
    // خطأ، إذ لم يقصد تعديله أصلاً. وبقية الجداول تبقى على الرفض الصريح:
    // نسخة المعلم منها لا تحمل إلا سجلاته، فمجيء سجلّ غريب فيها خلل
    // يستحق أن يُقال لا أن يُبتلع.
    if (!(table === "teachers" && actor.role === "teacher")) {
      res.status(403).json({ error: "لا يمكن للمعلم تعديل سجلات تخص مستخدمًا آخر" });
      return;
    }
    logger.info(
      { table, teacherId: actor.teacherId, ignored: rows.length - validRows.length },
      "Ignored foreign teacher rows from a teacher sync",
    );
  }

  try {
    if (validRows.length) {
      await rest(config, `${table}?on_conflict=id`, {
        method: "POST",
        headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
        // و`updated_at` معهما: العمود له قيمة افتراضية عند الإنشاء وحده،
        // فكان يبقى على تاريخ أوّل كتابة مهما عُدّل السجلّ بعدها — فلا يُعرف من الجدول
        // متى تغيّر شيء، ولا يصلح للمفاضلة بين نسختين.
        body: JSON.stringify(validRows.map((row) => ({
          id: stringValue(row.id),
          data: row.data,
          updated_at: new Date().toISOString(),
        }))),
      });
    }
    res.status(204).end();

    // بنك التحدي يُولَّد في الخلفية بعد حفظ الدرس.
    //
    // بعد الردّ لا قبله: المعلّم يحفظ درسه فيرى «حُفظ» في لحظته، ولا
    // ينتظر نموذجاً لغوياً يبني عشرين جولة. وفشلُ التوليد لا يُسقط
    // الحفظ — الدرس محفوظٌ على كل حال، والبنك يُولَّد عند أوّل فتحةٍ
    // للتحدي إن لم يُولَّد هنا.
    if (table === "lesson_configs") {
      void refreshChallengeBanks(validRows).catch((error) =>
        logger.error({ err: error }, "[bridge] challenge banks not refreshed"),
      );
    }
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