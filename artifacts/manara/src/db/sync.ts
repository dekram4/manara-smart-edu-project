import { onRemoteRecovered, RemoteRequestError, supabase } from './remoteSupabase';
import {
  applyParentLinkPlan,
  planParentLinkMigration,
} from '../utils/parentLinkMigration';

// ============================================================
// طبقة المزامنة بين localStorage و Supabase
// الفكرة: عند إقلاع التطبيق نملأ التخزين المحلي من Supabase (hydrate)،
// ثم نعترض عمليات الكتابة على التخزين المحلي ونعكسها إلى Supabase (write-through).
// هكذا يبقى الكود المتزامن الحالي كما هو، لكن البيانات حقيقية ومشتركة.
//
// المتانة: أي كتابة تفشل (انقطاع شبكة) تُحفظ في طابور دائم محلي ثم تُرسَل عند
// الإقلاع التالي قبل التحميل، والتحميل لا يطمس أي تغييرات محلية غير مُزامَنة.
// ============================================================

// مفاتيح الكيانات (مصفوفة سجلات لكل منها id) → اسم الجدول في Supabase
const ROW_TABLES: Record<string, string> = {
  smartEdu_students: 'students',
  smartEdu_parents: 'parents',
  smartEdu_teachers: 'teachers',
  smartEdu_lessonConfigs: 'lesson_configs',
  smartEdu_createdQuizzes: 'created_quizzes',
  smartEdu_quizResults: 'quiz_results',
  smartEdu_interactions: 'interactions',
  smartEdu_privateMessages: 'private_messages',
  smartEdu_chatMessages: 'public_messages',
  smartEdu_certificates: 'certificates',
};

const LEGACY_PUBLIC_MESSAGES_KEY = 'CHAT_MESSAGES';
const PUBLIC_MESSAGES_KEY = 'smartEdu_chatMessages';

// مفاتيح الإعدادات/القوائم/البنى المتشعّبة → تُخزّن في جدول app_kv
const KV_KEYS = [
  'smartEdu_grades',
  'smartEdu_subjects',
  'smartEdu_terms',
  'smartEdu_units',
  'smartEdu_hierarchicalConfigs',
  'smartEdu_gradeConfigs',
  'smartEdu_adminSettings',
  'smartEdu_permissions',
  'smartEdu_permissionPackages',
  'smartEdu_reports',
  // Shared collections that were historically kept only in browser storage.
  'smartEdu_quizQuestions',
  'smartEdu_videos',
  'smartEdu_deletedVideos',
  'smartEdu_deletedLessons',
  'smartEdu_deletedQuizzes',
  'smartEdu_videoNotifications',
];

const KV_SET = new Set(KV_KEYS);

// مفتاح محلي فقط لحفظ العمليات المعلّقة (غير مُزامَن إطلاقاً)
const PENDING_KEY = 'smartEdu_pendingSync';

// المفاتيح المحلية فقط (جلسة الدخول الحالية + علامات القراءة) — لا تُزامَن
// activeStudent / currentTeacher / activeParent / LAST_READ_MESSAGE_*

// نحتفظ بالدوال الأصلية قبل الاعتراض
const nativeSetItem = window.localStorage.setItem.bind(window.localStorage);
const nativeRemoveItem = window.localStorage.removeItem.bind(window.localStorage);
const nativeGetItem = window.localStorage.getItem.bind(window.localStorage);

let writeThroughInstalled = false;
let syncInitializationPromise: Promise<void> | null = null;

function safeParse(raw: string | null): any {
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function mergeArrayRecords(remote: any[], local: any[]): any[] {
  const merged = [...remote];
  const remoteIds = new Set(
    remote
      .filter((item) => item && typeof item === 'object' && item.id != null)
      .map((item) => String(item.id)),
  );

  for (const item of local) {
    if (item && typeof item === 'object' && item.id != null) {
      if (!remoteIds.has(String(item.id))) merged.push(item);
      continue;
    }
    if (!merged.some((existing) => JSON.stringify(existing) === JSON.stringify(item))) {
      merged.push(item);
    }
  }
  return merged;
}

function mergeSharedValue(remoteValue: any, localValue: any): any {
  if (Array.isArray(remoteValue) && Array.isArray(localValue)) {
    return mergeArrayRecords(remoteValue, localValue);
  }
  return remoteValue ?? localValue;
}

function stringIdArray(value: any): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((item) => item != null && (typeof item === 'string' || typeof item === 'number'))
    .map((item) => String(item));
}

function removeDeletedVideos(value: any, deletedVideoIds: Set<string>): any[] {
  if (!Array.isArray(value)) return [];
  return value.filter(
    (video) => video?.id == null || !deletedVideoIds.has(String(video.id)),
  );
}

function removeDeletedLessons(value: any, deletedLessonIds: Set<string>): any[] {
  if (!Array.isArray(value)) return [];
  return value.filter(
    (lesson) => lesson?.id == null || !deletedLessonIds.has(String(lesson.id)),
  );
}

function removeDeletedQuizzes(value: any, deletedQuizIds: Set<string>): any[] {
  if (!Array.isArray(value)) return [];
  return value.filter(
    (quiz) => quiz?.id == null || !deletedQuizIds.has(String(quiz.id)),
  );
}

function prepareDeletedQuizTombstones(): void {
  const existingIds = new Set(
    stringIdArray(safeParse(nativeGetItem('smartEdu_deletedQuizzes'))),
  );
  const localQuizzes = safeParse(nativeGetItem('smartEdu_createdQuizzes'));
  if (Array.isArray(localQuizzes)) {
    localQuizzes
      .filter((quiz) => quiz?.deleted && quiz.id != null)
      .forEach((quiz) => existingIds.add(String(quiz.id)));
  }
  nativeSetItem('smartEdu_deletedQuizzes', JSON.stringify(Array.from(existingIds)));
}

function mergeLegacyPublicMessages(): string | null {
  const legacy = safeParse(nativeGetItem(LEGACY_PUBLIC_MESSAGES_KEY));
  if (!Array.isArray(legacy) || legacy.length === 0) return null;

  const current = safeParse(nativeGetItem(PUBLIC_MESSAGES_KEY));
  const merged = new Map<string, any>();
  if (Array.isArray(current)) {
    current.forEach(message => {
      if (message?.id != null) merged.set(String(message.id), message);
    });
  }
  legacy.forEach(message => {
    if (message?.id != null && !merged.has(String(message.id))) {
      merged.set(String(message.id), message);
    }
  });

  return JSON.stringify(Array.from(merged.values()));
}

// ------------------------------------------------------------
// الطابور الدائم: عمليات لم تنجح بعد، تُعاد محاولتها لاحقاً
// ------------------------------------------------------------
type PendingOp =
  | { type: 'row_upsert'; table: string; rows: { id: string; data: any }[]; scope?: string }
  | { type: 'row_delete'; table: string; ids: string[]; scope?: string }
  | { type: 'kv'; key: string; value: any; scope?: string };

type SyncContext = {
  role: 'admin' | 'teacher' | 'parent';
  scope: string;
  teacherId?: string;
  parentId?: string;
};

/**
 * ولي الأمر قارئ فقط.
 *
 * الخادم يمنعه من الكتابة أصلاً (مسارات الكتابة تستدعي `getContentActor`
 * الذي لا يعرف دور ولي الأمر)، لكن الاعتماد على ذلك وحده يعني أن كل كتابة
 * من لوحته ستنطلق إلى الشبكة لتُرفض بـ 401 — فيظهر الشريط الأحمر على شيء
 * ليس خطأ. المنع هنا يوقفها قبل أن تُرسَل.
 */
function isReadOnlyActor(): boolean {
  return activeSyncContext?.role === 'parent';
}

let activeSyncContext: SyncContext | null = null;

function loadPending(): PendingOp[] {
  const parsed = safeParse(nativeGetItem(PENDING_KEY));
  return Array.isArray(parsed) ? parsed : [];
}

/**
 * يكتب الطابور، ولا يسمح لامتلاء التخزين بأن يُفشل الكتابة المحلية.
 *
 * سقف `MAX_PENDING_OPS` يحدّ **عدد** العمليات لا **حجمها**: عملية واحدة
 * ثقيلة (سؤال باختبار يحمل صورة مضمّنة مثلاً) تكفي لتجاوز حصّة الأصل. ولأن
 * `nativeSetItem` ترمي عندئذٍ `QuotaExceededError`، كان الاستثناء يصعد عبر
 * `appendPending` إلى مسار الكتابة نفسه فيُسقط حفظ ما بين يدَي المستخدم.
 *
 * فهنا: نقلّص الطابور إلى النصف مراراً ونعيد المحاولة، وإن بقي العجز
 * أفرغناه. فقدان تعديلات قديمة غير مُزامَنة أهون من تعطُّل الحفظ الحاضر،
 * والمستخدم يُبلَّغ في الحالتين.
 */
function savePending(ops: PendingOp[]): void {
  let attempt = ops;
  while (true) {
    try {
      nativeSetItem(PENDING_KEY, JSON.stringify(attempt));
      return;
    } catch (error) {
      if (attempt.length === 0) {
        // لم يعد في الطابور ما يُقلَّص، فالامتلاء من مفاتيح أخرى.
        console.error('[sync] تعذّرت كتابة الطابور رغم إفراغه.', error);
        reportFailure('dropped', 'طابور المزامنة', new Error(
          'تخزين المتصفح ممتلئ؛ تعذّر حفظ طابور المزامنة وأُفرغ بالكامل.',
        ));
        return;
      }
      const kept = Math.floor(attempt.length / 2);
      console.warn(
        `[sync] تخزين المتصفح ممتلئ — تقليص الطابور من ${attempt.length} إلى ${kept} عملية.`,
      );
      attempt = attempt.slice(attempt.length - kept);
    }
  }
}

/**
 * أقصى عدد عمليات في الطابور.
 *
 * الطابور يعيش في `localStorage` وسعتها 5–10 ميجابايت للأصل كله. جلسة طويلة
 * بلا خادم كانت تضيف بلا حدّ حتى تمتلئ، فترمي `QuotaExceededError` — وعندها
 * تتعطّل **الكتابة المحلية نفسها** لا المزامنة وحدها، فيفقد المستخدم عمله
 * الحاضر أيضاً. السقف يجعل الفشل مقيّداً ومعروفاً بدل أن يكون كارثياً
 * ومفاجئاً.
 */
const MAX_PENDING_OPS = 100;

function appendPending(op: PendingOp): void {
  const ops = loadPending();
  ops.push(op);
  if (ops.length > MAX_PENDING_OPS) {
    // يُسقَط الأقدم لا الأحدث: الأحدث يحمل آخر ما كتبه المستخدم، وهو ما
    // يريد وصوله. والأقدم في جدول الصفوف غالباً مُتجاوَز أصلاً لأن الكتابة
    // التالية على الصف نفسه تحمل حالته الكاملة.
    const dropped = ops.length - MAX_PENDING_OPS;
    ops.splice(0, dropped);
    console.warn(
      `[sync] الطابور بلغ ${MAX_PENDING_OPS} عملية — أُسقطت ${dropped} من أقدمها. ` +
        'تحقّق من اتصال الخادم؛ بعض التعديلات القديمة لن تصل.',
    );
    reportFailure('dropped', 'طابور المزامنة', new Error(
      `تجاوز الطابور ${MAX_PENDING_OPS} عملية؛ أُسقطت ${dropped} من أقدم التعديلات ولن تصل إلى الخادم.`,
    ));
  }
  savePending(ops);
}

function currentScope(): string {
  return activeSyncContext?.scope ?? 'unverified';
}

// يجب أن تطابق هذه الدالة `rowBelongsToActor` في خادم الـ API حرفياً: هي
// تُستخدم الآن لتصفية ما يُرسَل، فأي تشدّد زائد فيها يحجب كتابة مشروعة بصمت،
// وأي تساهل يُعيد الشريط الأحمر الذي جاءت لتمنعه.
//
// وتحديداً `||` وليس `??`: الخادم يتخطّى السلسلة عند النص الفارغ أيضاً، فسجلّ
// فيه `teacherId: ''` و`createdBy: 't1'` يملكه 't1' عنده. لو استُعمل `??` هنا
// لتوقّفت السلسلة عند الفراغ فيُحجب السجل رغم أن الخادم كان سيقبله.
function recordBelongsToContext(record: any, context: SyncContext, table: string): boolean {
  if (context.role === 'admin') return true;
  // ولي الأمر لا يملك أي صف: نطاقه قراءة فقط.
  if (context.role === 'parent') return false;
  if (!record || typeof record !== 'object') return false;
  if (table === 'teachers') return String(record.id ?? '').trim() === context.teacherId;
  const owner =
    String(record.teacher_id ?? '').trim() ||
    String(record.teacherId ?? '').trim() ||
    String(record.createdBy ?? '').trim();
  return owner === context.teacherId;
}

function shouldRetry(error: unknown): boolean {
  return !(error instanceof RemoteRequestError) || error.retryable;
}

// ------------------------------------------------------------
// حالة المزامنة المرئية للمستخدم
//
// كان كل فشل يُكتب في الكونسول فقط، فيظن المعلم أن تعديله حُفظ بينما لم
// يصل إلى Supabase إطلاقاً — والطالب يبقى يرى القديم. الآن كل فشل يُبلَّغ
// للواجهة لتعرضه، ويُفرَّق بين نوعين:
//
//   queued  : فشل مؤقت (شبكة). العملية محفوظة وستُعاد.
//   dropped : فشل غير قابل للإعادة (صلاحية/RLS/بيانات مرفوضة). هذه كانت
//             تُهمَل بصمت تماماً — لا تُحفظ ولا تُعرض — فيضيع التعديل نهائياً
//             دون أن يعلم أحد. وهي الأخطر، ولذلك تُعرض بلهجة أشد.
// ------------------------------------------------------------
//   offline : الخادم لا يملك إعدادات Supabase أصلاً (أو لا يعمل). ليس فشلاً
//             في عمل المستخدم ولا في صلاحيته، فلا يُعرض بلهجة الخطأ — لكنه
//             لا يُخفى أيضاً: تعديلاته تعيش في المتصفح وحده حتى يعود
//             الاتصال، وإخفاء ذلك يعني أن يظنّها محفوظة وهي ليست كذلك.
export type SyncFailureKind = 'queued' | 'dropped' | 'offline';

export type SyncStatus = {
  /** عدد العمليات المنتظرة في الطابور. */
  pending: number;
  /** آخر فشل حدث، أو null إن كان كل شيء سليماً. */
  lastFailure: { kind: SyncFailureKind; label: string; message: string } | null;
  /** true أثناء تفريغ الطابور يدوياً. */
  retrying: boolean;
  /**
   * true أثناء أول تحميل من Supabase.
   *
   * الشاشات تقرأ الشجرة الأكاديمية من التخزين المحلي قراءةً متزامنة، فإن
   * كان التحميل لم يكتمل بعد تكون القراءة فارغة. بدون هذه الراية تعرض
   * القائمة «لا توجد دروس» — وهي رسالة خاطئة تدفع المعلّم إلى إضافة دروس
   * موجودة أصلاً.
   */
  hydrating: boolean;
};

let syncStatus: SyncStatus = { pending: 0, lastFailure: null, retrying: false, hydrating: false };
const statusListeners = new Set<(status: SyncStatus) => void>();

function emitStatus(patch: Partial<SyncStatus>): void {
  syncStatus = { ...syncStatus, ...patch, pending: patch.pending ?? loadPending().length };
  for (const listener of statusListeners) {
    try {
      listener(syncStatus);
    } catch {
      // مستمع معطوب يجب ألا يوقف المزامنة نفسها.
    }
  }
}

/** يشترك في حالة المزامنة ويستقبلها فوراً، ويعيد دالة لإلغاء الاشتراك. */
export function onSyncStatus(listener: (status: SyncStatus) => void): () => void {
  statusListeners.add(listener);
  listener(syncStatus);
  return () => statusListeners.delete(listener);
}

export function getSyncStatus(): SyncStatus {
  return syncStatus;
}

function reportFailure(kind: SyncFailureKind, label: string, error: any): void {
  const rawMessage = String(error?.message ?? error ?? '').slice(0, 300);
  // الخطأ الصامت هو «الخادم بلا Supabase» — رسالته إنجليزية تقنية لا تعني
  // المعلّم شيئاً، وكانت تظهر له حرفياً في شريط أحمر. تُصنَّف هنا حالةً
  // مستقلة برسالة عربية مفهومة ونبرة إخبارية.
  const isSilent = Boolean((error as { silent?: boolean } | null)?.silent);
  const effectiveKind: SyncFailureKind = isSilent ? 'offline' : kind;
  const message = isSilent
    ? 'الخادم غير مهيّأ للمزامنة حالياً — تعديلاتك محفوظة في المتصفح وستُرسل عند عودة الاتصال.'
    : rawMessage;
  const tone = effectiveKind === 'dropped'
    ? 'فشل نهائي'
    : effectiveKind === 'offline'
      ? 'تعذّر الوصول'
      : 'فشل مؤقت';
  if (effectiveKind === 'offline') {
    console.info(`[sync] ${tone} — ${label}: ${rawMessage}`);
  } else {
    console.error(`[sync] ${tone} — ${label}:`, message);
  }
  emitStatus({ lastFailure: { kind: effectiveKind, label, message } });
}

/**
 * يعيد إرسال كل ما في الطابور الآن، بدل انتظار الإقلاع التالي.
 *
 * هذا ما يربطه زر "إعادة محاولة المزامنة": الطابور كان لا يُفرَّغ إلا عند
 * بدء التطبيق، فمعلّم فقد الاتصال لحظةً كان عليه إغلاق اللوحة وفتحها.
 */
export async function retryPendingSync(): Promise<SyncStatus> {
  const context = activeSyncContext;
  if (!context) {
    emitStatus({
      lastFailure: {
        kind: 'dropped',
        label: 'المزامنة',
        message: 'لم تبدأ جلسة مزامنة بعد. سجّل الدخول ثم أعد المحاولة.',
      },
    });
    return syncStatus;
  }
  emitStatus({ retrying: true });
  try {
    await flushPending(context);
    const left = loadPending().filter((op) => op.scope === context.scope).length;
    emitStatus({
      retrying: false,
      // لا تُمسح رسالة الفشل إلا إذا خرج الطابور فارغاً فعلاً.
      lastFailure: left === 0 ? null : syncStatus.lastFailure,
    });
  } catch (error) {
    emitStatus({ retrying: false });
    reportFailure('queued', 'إعادة المحاولة', error);
  }
  return syncStatus;
}

function canCurrentActorWriteKv(key: string): boolean {
  // ولي الأمر أولاً: بدون هذا الشرط كان بإمكانه الكتابة على `smartEdu_videos`
  // لأن الاستثناء التالي غير مقيّد بدور.
  if (isReadOnlyActor()) return false;
  return activeSyncContext?.role === 'admin' || key === 'smartEdu_videos';
}

function executeOp(op: PendingOp): PromiseLike<{ error: any }> {
  if (op.type === 'row_upsert') {
    return supabase.from(op.table).upsert(op.rows, { onConflict: 'id' });
  }
  if (op.type === 'row_delete') {
    return supabase.from(op.table).delete().in('id', op.ids);
  }
  return supabase.from('app_kv').upsert({ key: op.key, value: op.value }, { onConflict: 'key' });
}

// ------------------------------------------------------------
// إعادة المحاولة عند فشل الشبكة المؤقت
// ------------------------------------------------------------
async function withRetry(
  label: string,
  fn: () => PromiseLike<{ error: any }>
): Promise<{ error: any }> {
  let last: { error: any } = { error: null };
  for (let attempt = 0; attempt < 3; attempt++) {
    last = await fn();
    if (!last.error) return last;
    if (last.error.silent) return last;
    if (!shouldRetry(last.error)) return last;
    await new Promise((r) => setTimeout(r, 250 * (attempt + 1)));
  }
  console.error(`[sync] فشل ${label} بعد عدة محاولات:`, last?.error?.message);
  return last;
}

// ------------------------------------------------------------
// طابور تسلسلي لكل مفتاح: يمنع وصول كتابة قديمة بعد كتابة أحدث (out-of-order)
// ------------------------------------------------------------
const queues = new Map<string, Promise<void>>();

function enqueue(key: string, op: () => Promise<void>): Promise<void> {
  const prev = queues.get(key) || Promise.resolve();
  const next = prev
    .catch(() => {})
    .then(op)
    .catch((e) => console.error(`[sync] خطأ مزامنة ${key}:`, e?.message || e));
  queues.set(key, next);
  return next;
}

// ------------------------------------------------------------
// إرسال العمليات المعلّقة قبل أي تحميل. تُعيد المفاتيح التي ما زالت معلّقة
// حتى لا يطمسها التحميل لاحقاً.
// ------------------------------------------------------------
async function flushPending(context: SyncContext): Promise<{ pendingTables: Set<string>; pendingKv: Set<string> }> {
  const ops = loadPending();
  const remaining: PendingOp[] = [];

  for (const op of ops) {
    // Pending writes are account-scoped. A legacy entry without a scope cannot
    // be attributed safely, so do not replay it under whichever teacher signs
    // in next. Scoped writes for another account remain available for that
    // account's next session.
    if (op.scope !== context.scope) {
      if (!op.scope) console.warn('[sync] تم تجاهل عملية قديمة بلا نطاق حساب');
      else remaining.push(op);
      continue;
    }
    const res = await withRetry('إرسال عملية معلّقة', () => executeOp(op));
    if (res.error && shouldRetry(res.error)) remaining.push(op);
  }
  savePending(remaining);

  const pendingTables = new Set<string>();
  const pendingKv = new Set<string>();
  for (const op of remaining.filter((op) => op.scope === context.scope)) {
    if (op.type === 'kv') pendingKv.add(op.key);
    else pendingTables.add(op.table);
  }
  return { pendingTables, pendingKv };
}

// ------------------------------------------------------------
// التحميل (Hydrate) مع حماية من فقدان البيانات:
// - عند فشل القراءة لا نلمس المحلي إطلاقاً.
// - إن كان الجدول معلّقاً (تغييرات محلية لم تُرسَل) لا نطمسه.
// - إن كان الجدول فارغاً عن بُعد والمحلي غير فارغ، نرفع المحلي (هجرة أولى).
// ------------------------------------------------------------
async function hydrateRowTable(
  storageKey: string,
  table: string,
  pendingTables: Set<string>,
  context: SyncContext,
): Promise<void> {
  if (pendingTables.has(table)) return; // المحلي هو المرجع، لا تطمسه

  const { data, error } = await supabase.from(table).select('id,data');
  if (error) {
    if (!(error as Error & { silent?: boolean }).silent) {
      console.error(`[sync] فشل تحميل ${table}:`, error.message);
    }
    return; // لا نلمس المحلي عند فشل القراءة
  }
  const remote = (data || []).map((row: any) => row.data);
  const local = safeParse(nativeGetItem(storageKey));
  const localArr = (Array.isArray(local) ? local : [])
    .filter((record: any) => recordBelongsToContext(record, context, table));
  const deletedLessonIds = new Set(
    stringIdArray(safeParse(nativeGetItem('smartEdu_deletedLessons'))),
  );
  const deletedQuizIds = new Set(
    stringIdArray(safeParse(nativeGetItem('smartEdu_deletedQuizzes'))),
  );
  if (storageKey === 'smartEdu_createdQuizzes') {
    const previousDeletedQuizCount = deletedQuizIds.size;
    remote
      .filter((quiz: any) => quiz?.deleted && quiz.id != null)
      .forEach((quiz: any) => deletedQuizIds.add(String(quiz.id)));
    if (deletedQuizIds.size !== previousDeletedQuizCount) {
      const tombstoneValue = Array.from(deletedQuizIds);
      nativeSetItem('smartEdu_deletedQuizzes', JSON.stringify(tombstoneValue));
      const tombstoneResult = await withRetry('حفظ علامات حذف الاختبارات', () =>
        supabase.from('app_kv').upsert(
          { key: 'smartEdu_deletedQuizzes', value: tombstoneValue },
          { onConflict: 'key' },
        ),
      );
      if (tombstoneResult.error) {
        appendPending({
          type: 'kv',
          key: 'smartEdu_deletedQuizzes',
          value: tombstoneValue,
          scope: currentScope(),
        });
      }
    }
  }
  const deletedIds = storageKey === 'smartEdu_createdQuizzes' ? deletedQuizIds : deletedLessonIds;
  const filteredRemote = storageKey === 'smartEdu_lessonConfigs'
    ? removeDeletedLessons(remote, deletedLessonIds)
    : storageKey === 'smartEdu_createdQuizzes'
      ? removeDeletedQuizzes(remote, deletedQuizIds)
      : remote;
  const filteredLocal = storageKey === 'smartEdu_lessonConfigs'
    ? removeDeletedLessons(localArr, deletedLessonIds)
    : storageKey === 'smartEdu_createdQuizzes'
      ? removeDeletedQuizzes(localArr, deletedQuizIds)
      : localArr;
  const merged = mergeArrayRecords(filteredRemote, filteredLocal);
  const remoteIds = new Set(filteredRemote.map((item: any) => String(item?.id)));
  const localOnly = merged
    .filter((item: any) => item?.id != null && !remoteIds.has(String(item.id)))
    .map((item: any) => ({ id: String(item.id), data: item }));

  if (localOnly.length) {
    const res = await withRetry(`دمج ${table}`, () =>
      supabase.from(table).upsert(localOnly, { onConflict: 'id' }),
    );
    if (res.error && shouldRetry(res.error)) {
      appendPending({ type: 'row_upsert', table, rows: localOnly, scope: currentScope() });
    }
  }

  if (
    (storageKey === 'smartEdu_lessonConfigs' && deletedLessonIds.size) ||
    (storageKey === 'smartEdu_createdQuizzes' && deletedQuizIds.size)
  ) {
    const staleRemoteIds = remote
      .filter((item: any) => item?.id != null && deletedIds.has(String(item.id)))
      .map((item: any) => String(item.id));
    if (staleRemoteIds.length) {
      const res = await withRetry(
        storageKey === 'smartEdu_createdQuizzes'
          ? 'حذف الاختبارات المحذوفة من created_quizzes'
          : 'حذف المحتوى المحذوف من lesson_configs',
        () =>
        supabase.from(table).delete().in('id', staleRemoteIds),
      );
      if (res.error && shouldRetry(res.error)) {
        appendPending({ type: 'row_delete', table, ids: staleRemoteIds, scope: currentScope() });
      }
    }
  }

  nativeSetItem(storageKey, JSON.stringify(merged));
}

async function hydrateKv(pendingKv: Set<string>): Promise<void> {
  const { data, error } = await supabase.from('app_kv').select('key,value');
  if (error) {
    if (!(error as Error & { silent?: boolean }).silent) {
      console.error('[sync] فشل تحميل app_kv:', error.message);
    }
    return;
  }
  const byKey = new Map((data || []).map((row: any) => [row.key, row.value]));
  const toUpload: { key: string; value: any }[] = [];
  const deletedVideoIds = new Set([
    ...stringIdArray(byKey.get('smartEdu_deletedVideos')),
    ...stringIdArray(safeParse(nativeGetItem('smartEdu_deletedVideos'))),
  ]);
  const deletedLessonIds = new Set([
    ...stringIdArray(byKey.get('smartEdu_deletedLessons')),
    ...stringIdArray(safeParse(nativeGetItem('smartEdu_deletedLessons'))),
  ]);
  const deletedQuizIds = new Set([
    ...stringIdArray(byKey.get('smartEdu_deletedQuizzes')),
    ...stringIdArray(safeParse(nativeGetItem('smartEdu_deletedQuizzes'))),
  ]);

  for (const key of KV_KEYS) {
    if (pendingKv.has(key)) continue; // تغييرات محلية معلّقة، لا تطمسها
    const localVal = safeParse(nativeGetItem(key));
    if (byKey.has(key)) {
      const merged =
        key === 'smartEdu_deletedVideos'
          ? Array.from(deletedVideoIds)
          : key === 'smartEdu_deletedLessons'
            ? Array.from(deletedLessonIds)
            : key === 'smartEdu_deletedQuizzes'
              ? Array.from(deletedQuizIds)
          : key === 'smartEdu_videos'
            ? removeDeletedVideos(mergeSharedValue(byKey.get(key), localVal), deletedVideoIds)
            : key === 'smartEdu_lessonConfigs'
              ? removeDeletedLessons(mergeSharedValue(byKey.get(key), localVal), deletedLessonIds)
            : mergeSharedValue(byKey.get(key), localVal);
      nativeSetItem(key, JSON.stringify(merged));
      if (JSON.stringify(merged) !== JSON.stringify(byKey.get(key))) {
        if (canCurrentActorWriteKv(key)) {
          toUpload.push({ key, value: merged });
        }
      }
    } else {
      if (localVal !== null) {
        const value =
          key === 'smartEdu_videos'
            ? removeDeletedVideos(localVal, deletedVideoIds)
            : key === 'smartEdu_deletedVideos'
              ? Array.from(deletedVideoIds)
              : key === 'smartEdu_deletedLessons'
                ? Array.from(deletedLessonIds)
                : key === 'smartEdu_deletedQuizzes'
                  ? Array.from(deletedQuizIds)
              : localVal;
        nativeSetItem(key, JSON.stringify(value));
        if (canCurrentActorWriteKv(key)) {
          toUpload.push({ key, value });
        }
      }
    }
  }

  if (toUpload.length) {
    const res = await withRetry('رفع app_kv (هجرة أولى)', () =>
      supabase.from('app_kv').upsert(toUpload, { onConflict: 'key' })
    );
    if (res.error && shouldRetry(res.error)) {
      for (const item of toUpload) {
        appendPending({ type: 'kv', key: item.key, value: item.value, scope: currentScope() });
      }
    }
  }
}

// تحميل كل البيانات من Supabase إلى التخزين المحلي
export async function hydrateFromSupabase(
  pendingTables: Set<string> = new Set(),
  pendingKv: Set<string> = new Set(),
  context: SyncContext = activeSyncContext ?? { role: 'admin', scope: 'admin' },
): Promise<void> {
  await hydrateKv(pendingKv).catch((e) =>
    console.error('[sync] خطأ أثناء تحميل app_kv:', e?.message || e)
  );
  await Promise.all([
    ...Object.entries(ROW_TABLES).map(([storageKey, table]) =>
      hydrateRowTable(storageKey, table, pendingTables, context).catch((e) =>
        console.error(`[sync] خطأ أثناء تحميل ${table}:`, e?.message || e)
      )
    ),
  ]);
}

// مزامنة جدول كيانات عبر مقارنة المصفوفة القديمة بالجديدة (upsert/delete للمتغيّر فقط)
//
// قاعدة الملكية كانت مطبّقة عند القراءة فقط (`hydrateRowTable`) ومفقودة تماماً
// عند الكتابة. النتيجة: أي كتابة لـ `smartEdu_teachers` من جلسة معلّم تُرسِل
// صفوفاً لا يملكها إلى الخادم، فيرفضها RLS رفضاً نهائياً غير قابل للإعادة،
// فيظهر الشريط الأحمر «رفض الخادم العملية — حفظ teachers» على شاشة المعلّم
// في كل مرة، رغم أن لا شيء من عمله ضاع فعلاً.
//
// الحل ليس إخفاء الشريط: الشريط محقّ حين يضيع تعديل. الحل ألا تُرسَل أصلاً
// كتابةٌ معروفٌ سلفاً أنها ليست من حق هذا الحساب — وهي نفس القاعدة المعتمدة
// على القراءة، فلا يمكن أن تُسقط بياناتٍ لم تكن القراءة لتُسقطها.
async function syncRowTable(table: string, oldArr: any[], newArr: any[]): Promise<void> {
  const oldById = new Map<string, any>();
  for (const r of oldArr) if (r && r.id != null) oldById.set(String(r.id), r);

  const newById = new Map<string, any>();
  for (const r of newArr) if (r && r.id != null) newById.set(String(r.id), r);

  const context = activeSyncContext;
  const writable = (record: any): boolean =>
    !context || recordBelongsToContext(record, context, table);

  const upserts: { id: string; data: any }[] = [];
  let blockedUpserts = 0;
  for (const [id, rec] of newById) {
    const prev = oldById.get(id);
    if (prev && JSON.stringify(prev) === JSON.stringify(rec)) continue;
    if (!writable(rec)) {
      blockedUpserts++;
      continue;
    }
    upserts.push({ id, data: rec });
  }

  const deletes: string[] = [];
  let blockedDeletes = 0;
  for (const [id, prev] of oldById) {
    if (newById.has(id)) continue;
    if (!writable(prev)) {
      blockedDeletes++;
      continue;
    }
    deletes.push(id);
  }

  // تشخيص في الكونسول دون إزعاج المستخدم: لا شيء ضاع، الصفوف المحجوبة ليست
  // ملك هذا الحساب أصلاً ونسخته المحلية منها مجرد أثر تحميل سابق.
  if (blockedUpserts || blockedDeletes) {
    console.info(
      `[sync] تخطّي ${blockedUpserts + blockedDeletes} صفاً خارج ملكية الحساب في ${table}`,
    );
  }

  if (upserts.length) {
    const res = await withRetry(`حفظ ${table}`, () =>
      supabase.from(table).upsert(upserts, { onConflict: 'id' })
    );
    if (res.error) {
      if (shouldRetry(res.error)) {
        appendPending({ type: 'row_upsert', table, rows: upserts, scope: currentScope() });
        reportFailure('queued', `حفظ ${table}`, res.error);
      } else {
        // غير قابل للإعادة: كان يُهمَل بصمت هنا فيضيع التعديل نهائياً.
        reportFailure('dropped', `حفظ ${table}`, res.error);
      }
    }
  }
  if (deletes.length) {
    const res = await withRetry(`حذف من ${table}`, () =>
      supabase.from(table).delete().in('id', deletes)
    );
    if (res.error) {
      if (shouldRetry(res.error)) {
        appendPending({ type: 'row_delete', table, ids: deletes, scope: currentScope() });
        reportFailure('queued', `حذف من ${table}`, res.error);
      } else {
        reportFailure('dropped', `حذف من ${table}`, res.error);
      }
    }
  }
}

async function syncKv(key: string, value: any): Promise<void> {
  if (!canCurrentActorWriteKv(key)) return;
  const res = await withRetry(`حفظ ${key}`, () =>
    supabase.from('app_kv').upsert({ key, value }, { onConflict: 'key' })
  );
  if (res.error) {
    if (shouldRetry(res.error)) {
      appendPending({ type: 'kv', key, value, scope: currentScope() });
      reportFailure('queued', `حفظ ${key}`, res.error);
    } else {
      reportFailure('dropped', `حفظ ${key}`, res.error);
    }
  }
}

/**
 * Immediately persists a shared collection value while retaining the normal
 * offline queue. Use this for tombstones that other applications must see
 * without waiting for another localStorage write or hydration cycle.
 */
export function syncSharedValue(key: string, value: unknown): void {
  if (!KV_SET.has(key)) return;
  void enqueue(key, () => syncKv(key, value));
}

// تركيب الاعتراض على الكتابة (يُستدعى بعد hydrate)
export function installWriteThrough(): void {
  if (writeThroughInstalled) return;
  writeThroughInstalled = true;

  window.localStorage.setItem = function (key: string, value: string): void {
    const oldRaw = ROW_TABLES[key] ? nativeGetItem(key) : null;

    // اكتب محلياً أولاً حتى يبقى التخزين المحلي متسقاً حتى لو فشلت الشبكة
    nativeSetItem(key, value);

    if (ROW_TABLES[key]) {
      const table = ROW_TABLES[key];
      const oldArr = Array.isArray(safeParse(oldRaw)) ? safeParse(oldRaw) : [];
      const newArr = Array.isArray(safeParse(value)) ? safeParse(value) : [];
      void enqueue(key, () => syncRowTable(table, oldArr, newArr));
    } else if (KV_SET.has(key)) {
      const parsed = safeParse(value);
      void enqueue(key, () => syncKv(key, parsed));
    }
    // المفاتيح المحلية فقط: لا شيء يُرسل إلى Supabase
  };

  window.localStorage.removeItem = function (key: string): void {
    nativeRemoveItem(key);
    // الحذف يُستخدم فقط لمفاتيح الجلسة المحلية، فلا نلمس قاعدة البيانات
  };
}

// تهيئة كاملة: أرسل المعلّق ← حمّل (دون طمس المعلّق) ← فعّل الاعتراض
/**
 * يملأ `parentId` الناقص من مطابقة رقم جوال لا لبس فيها، مرة واحدة بعد كل
 * تحميل، ويعكسه إلى Supabase عبر write-through.
 *
 * لماذا داخل التطبيق وليس في سكريبت وحده: قراءة أبناء وليّ الأمر صارت
 * محصورة بـ `parentId` وحده. الطالب الذي لم يُرحَّل بعدُ ينقطع عن وليّه
 * انقطاعاً صامتاً. هذا يجعل الترحيل يقع من تلقائه أول مرة يفتح فيها مشرف أو
 * معلم لوحته، فلا يتوقف إصلاح البيانات على تذكّر أحدٍ تشغيلَ سكريبت.
 *
 * ولا يُشغَّل لدور ولي الأمر: نطاقه قراءة فقط، وهو لا يرى إلا أبناءه
 * المربوطين أصلاً فلا بيانات لديه ليُصلحها.
 */
function backfillParentLinks(context: SyncContext): void {
  if (context.role !== 'admin' && context.role !== 'teacher') return;
  try {
    const students = safeParse(nativeGetItem('smartEdu_students'));
    const parents = safeParse(nativeGetItem('smartEdu_parents'));
    if (!Array.isArray(students) || !Array.isArray(parents)) return;
    if (students.length === 0 || parents.length === 0) return;

    const plan = planParentLinkMigration(students, parents);
    if (plan.conflicts.length) {
      // لا تُحسم آلياً: رقم واحد لوليَّي أمر هو الالتباس الذي جاء الترحيل
      // لإزالته، وأي اختيار هنا تخمين يثبّت الخطأ.
      console.warn(
        `[sync] ${plan.conflicts.length} طالباً برقم جوال يطابق أكثر من وليّ أمر — ` +
          'يحتاج ربطاً يدوياً:',
        plan.conflicts,
      );
    }
    if (plan.updates.length === 0) return;

    const updated = applyParentLinkPlan(students, plan);
    // عبر `localStorage.setItem` المعترَض قصداً، فتنتقل الكتابة إلى Supabase
    // بنفس مسار أي تعديل آخر بدل مسار خاص.
    window.localStorage.setItem('smartEdu_students', JSON.stringify(updated));
    console.info(`[sync] رُبط ${plan.updates.length} طالباً بوليّ أمره عبر parentId`);
  } catch (error) {
    // إصلاح البيانات مساعدة لا شرط إقلاع: فشله لا يمنع المزامنة.
    console.error('[sync] تعذّر ترحيل روابط أولياء الأمور:', error);
  }
}

/**
 * يُفرَّغ الطابور تلقائياً لحظة عودة الخادم.
 *
 * مسجَّل مرة واحدة فقط: تسجيله داخل التهيئة يعني مستمعاً جديداً مع كل
 * إعادة تهيئة (تبديل دور مثلاً)، فتُفرَّغ العمليات مرات متزامنة.
 */
let recoveryHookInstalled = false;

function installRecoveryFlush(): void {
  if (recoveryHookInstalled) return;
  recoveryHookInstalled = true;
  onRemoteRecovered(() => {
    if (loadPending().length === 0) return;
    console.info('[sync] عاد الخادم — يجري إرسال العمليات المعلّقة');
    void retryPendingSync();
  });
}

export function initSupabaseSync(): Promise<void> {
  installRecoveryFlush();
  // React StrictMode and fast remounts can invoke the boot effect twice.
  // Share one initialization promise so hydration/write-through cannot race.
  if (syncInitializationPromise) return syncInitializationPromise;

  syncInitializationPromise = (async () => {
    emitStatus({ hydrating: true });
    try {
      const contextResult = await supabase.context();
      if (contextResult.error) {
        console.error('[sync] تعذر تحديد حساب المزامنة:', contextResult.error.message);
        return;
      }
      activeSyncContext = contextResult.data;
      const { pendingTables, pendingKv } = await flushPending(activeSyncContext);
      // Convert older deleted quiz records into shared tombstones before hydration.
      // This prevents stale rows from being merged back from Supabase.
      prepareDeletedQuizTombstones();
      await hydrateFromSupabase(pendingTables, pendingKv, activeSyncContext);

      // دمج الرسائل القديمة بعد hydrate حتى لا تطمس الرسائل المحلية القديمة
      // نسخة Supabase الحالية، ثم مرّر الدمج عبر write-through لمزامنته.
      const migratedMessages = mergeLegacyPublicMessages();
      if (migratedMessages) {
        window.localStorage.setItem(PUBLIC_MESSAGES_KEY, migratedMessages);
        nativeRemoveItem(LEGACY_PUBLIC_MESSAGES_KEY);
      }

      backfillParentLinks(activeSyncContext);
    } catch (error) {
      // Local data remains usable when the connector is unavailable.
      console.error('[sync] initialization failed; continuing with local data:', error);
    } finally {
      emitStatus({ hydrating: false });
      installWriteThrough();
    }
  })();

  return syncInitializationPromise;
}

/**
 * Call immediately after the authenticated server session changes. This
 * rehydrates the active browser cache from the new account's server scope
 * without replaying pending work created by a different account.
 */
export function refreshSupabaseSync(): Promise<void> {
  activeSyncContext = null;
  syncInitializationPromise = null;
  return initSupabaseSync();
}
