/**
 * سينما منارة: قواعدُ الفيديو بلا قاعدة بيانات — تُختبر وحدها.
 *
 * ── الفيديو للصفّ، لا للدرس ──
 * كان فيديو السينما يُحفظ بمسارٍ سداسيّ (صفّ، مادة، فصل، وحدة، درس) ويُعرض
 * للطالب حين يطابق الدرسَ الذي يتصفّحه. فطالبةٌ فتحت درساً آخر لا ترى
 * فيديوهات صفّها، ومعلمٌ أخطأ حرفاً في اسم الوحدة حجب الفيديو عن الصفّ كله.
 *
 * الآن الربطُ ثلاثةُ أشياء لا غير: الصفُّ الدراسيّ، والمعلمُ المسؤول، ومن
 * أضافه. وما يراه الطالب يحسمه صفُّه ومعلّمُه، أيّاً كان الدرسُ المفتوح.
 */

export type CinemaSourceType = "embed" | "mp4";

export type CinemaVideo = {
  id: string;
  title: string;
  embedUrl: string;
  sourceType: CinemaSourceType;
  description: string;
  gradeId: string;
  teacherId: string;
  teacherName: string;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
  /** محفوظٌ في `app_kv/smartEdu_videos` لا في جدول `cinema_videos`. */
  legacy: boolean;
};

export type CinemaActor = { role: "admin" } | { role: "teacher"; teacherId: string };

/** مالكون يُعرض ما يملكونه لكل الطلاب في الصفّ: سجلاتٌ قديمة بلا معلم. */
const SHARED_OWNERS = new Set(["admin", "supervisor"]);

export const CINEMA_TITLE_MAX = 200;
export const CINEMA_DESCRIPTION_MAX = 2000;
export const CINEMA_URL_MAX = 2000;

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * تسوية عربية للمقارنة لا للعرض — نفسُ ما في `studentAccess`.
 *
 * الصفُّ يُكتب في لوحة المعلم ويُقارن بسجلّ الطالب، ولا يمرّ بينهما تدقيق:
 * «الصف الأول» و«الصف الاول» صفٌّ واحد.
 */
export function scopeKey(value: unknown): string {
  return text(value)
    .toLowerCase()
    .replace(/[ً-ْٰـ]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06F0))
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * رابطٌ يُسمح بحفظه: http(s) مطلق، أو مسارٌ على الخادم نفسه (`/api/...`).
 *
 * `//host` ليس مساراً بل رابطاً بلا بروتوكول، و`javascript:` وأخواتها تُرفض.
 */
export function isSafeCinemaUrl(value: unknown): boolean {
  const url = text(value);
  if (!url || url.length > CINEMA_URL_MAX) return false;
  if (url.startsWith("/")) return !url.startsWith("//") && !/[\s\\]/.test(url);
  try {
    const parsed = new URL(url);
    return parsed.protocol === "https:" || parsed.protocol === "http:";
  } catch {
    return false;
  }
}

function sourceTypeOf(value: unknown, url: string): CinemaSourceType {
  if (value === "mp4" || value === "embed") return value;
  return /\.mp4(?:$|[?#])/i.test(url) ? "mp4" : "embed";
}

/** صفٌّ من جدول `cinema_videos`. */
export function fromTableRow(row: Record<string, unknown>): CinemaVideo | null {
  const id = text(row.id);
  const embedUrl = text(row.embed_url);
  if (!id || !embedUrl) return null;
  return {
    id,
    title: text(row.title),
    embedUrl,
    sourceType: sourceTypeOf(row.source_type, embedUrl),
    description: text(row.description),
    gradeId: text(row.grade_id),
    teacherId: text(row.teacher_id),
    teacherName: text(row.teacher_name),
    createdBy: text(row.created_by),
    createdAt: text(row.created_at),
    updatedAt: text(row.updated_at),
    legacy: false,
  };
}

export function toTableRow(video: CinemaVideo): Record<string, unknown> {
  return {
    id: video.id,
    title: video.title,
    embed_url: video.embedUrl,
    source_type: video.sourceType,
    description: video.description,
    grade_id: video.gradeId,
    teacher_id: video.teacherId,
    teacher_name: video.teacherName,
    created_by: video.createdBy,
    created_at: video.createdAt || new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };
}

/**
 * سجلٌّ من `app_kv/smartEdu_videos` — الشكلُ القديم وما يُكتب فيه حين يغيب الجدول.
 *
 * المالكُ القديم يُقرأ كما يقرؤه الجسر (`teacher_id` ثم `teacherId` ثم
 * `createdBy`)، فلا يتغيّر من يملك فيديو قديماً بهذا الانتقال.
 */
export function fromLegacyRecord(record: Record<string, unknown>): CinemaVideo | null {
  const id = text(record.id);
  const embedUrl = text(record.embedUrl) || text(record.url);
  if (!id || !embedUrl) return null;
  const teacherId = text(record.teacher_id) || text(record.teacherId) || text(record.createdBy);
  return {
    id,
    title: text(record.title),
    embedUrl,
    sourceType: sourceTypeOf(record.sourceType, embedUrl),
    description: text(record.description),
    gradeId: text(record.gradeId) || text(record.grade_id) || text(record.grade),
    teacherId,
    teacherName: text(record.teacherName),
    createdBy: text(record.created_by) || text(record.addedBy) || teacherId,
    createdAt: text(record.createdAt),
    updatedAt: text(record.updatedAt) || text(record.createdAt),
    legacy: true,
  };
}

/**
 * الشكلُ القديم بحقوله القديمة والجديدة معاً.
 *
 * القديمةُ لأن لوحاتٍ ونسخَ تطبيقٍ ما زالت تقرأ `grade` و`url` و`teacher_id`؛
 * والجديدةُ ليُقرأ السجلّ بلا تخمين حين يُنقل إلى الجدول.
 */
export function toLegacyRecord(video: CinemaVideo): Record<string, unknown> {
  return {
    id: video.id,
    title: video.title,
    description: video.description,
    url: video.embedUrl,
    embedUrl: video.embedUrl,
    sourceType: video.sourceType,
    grade: video.gradeId,
    gradeId: video.gradeId,
    teacher_id: video.teacherId,
    teacherId: video.teacherId,
    teacherName: video.teacherName,
    createdBy: video.teacherId,
    created_by: video.createdBy,
    createdAt: video.createdAt || new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
}

/**
 * الجدولُ والمفتاحُ القديم في قائمةٍ واحدة.
 *
 * الجدولُ يغلب عند تكرار المعرّف: فيديو قديم عُدّل بعد تشغيل SQL صار له صفٌّ
 * في الجدول، والنسخةُ القديمة في `app_kv` لم تعد الحقيقة. والمحذوفُ لا يعود.
 */
export function mergeCinemaVideos(
  tableVideos: CinemaVideo[],
  legacyVideos: CinemaVideo[],
  deletedIds: Iterable<string>,
): CinemaVideo[] {
  const deleted = new Set(Array.from(deletedIds, (id) => text(id)).filter(Boolean));
  const byId = new Map<string, CinemaVideo>();
  for (const video of legacyVideos) {
    if (!deleted.has(video.id)) byId.set(video.id, video);
  }
  for (const video of tableVideos) {
    if (!deleted.has(video.id)) byId.set(video.id, video);
  }
  return Array.from(byId.values()).sort((a, b) =>
    (b.createdAt || "").localeCompare(a.createdAt || ""),
  );
}

/**
 * هل يرى الطالبُ هذا الفيديو؟ صفُّه ومعلّمُه وحدهما.
 *
 * `teacherIdentities` كلُّ ما يُعرف به معلّمُ الطالب (المعرّف واسم الدخول
 * والاسم الظاهر)، مسوّاةً بـ [scopeKey]: الفيديو يُكتب باسم المعلم مرةً
 * وبمعرّفه مرةً، وكانت المطابقةُ على قيمةٍ واحدة تحجب عن الطالبة فيديوهات
 * معلّمها نفسه.
 */
export function isVisibleToStudent(
  video: CinemaVideo,
  student: { grade: string; teacherIdentities: Set<string> },
): boolean {
  const owner = scopeKey(video.teacherId);
  if (!owner) return false;
  if (!SHARED_OWNERS.has(owner) && !student.teacherIdentities.has(owner)) return false;
  const videoGrade = scopeKey(video.gradeId);
  const studentGrade = scopeKey(student.grade);
  // فيديو قديم بلا صفّ يبقى لصفوف معلّمه كلها، كما كان يُعرض قبل اليوم.
  if (!videoGrade || !studentGrade) return true;
  return videoGrade === studentGrade;
}

/** ما يديره المعلم: فيديوهاتُه وحده. والمشرف يدير الكل. */
export function isManagedBy(
  video: CinemaVideo,
  actor: CinemaActor,
  teacherIdentities: Set<string>,
): boolean {
  if (actor.role === "admin") return true;
  return teacherIdentities.has(scopeKey(video.teacherId));
}

export type CinemaInput = {
  id?: unknown;
  title?: unknown;
  embedUrl?: unknown;
  url?: unknown;
  sourceType?: unknown;
  description?: unknown;
  gradeId?: unknown;
  teacherId?: unknown;
  teacherName?: unknown;
};

export type CinemaValidation =
  | { ok: true; video: CinemaVideo }
  | { ok: false; status: number; error: string };

/**
 * يبني فيديو من طلب اللوحة، ويرفض ما ينقصه.
 *
 * الصفُّ والمعلمُ المسؤول إلزاميّان للدورين. والمعلم لا يُسند فيديو لغيره:
 * `teacherId` عنده هو هو، وأيّ قيمةٍ أخرى تُرفض لا تُستبدل بصمت.
 */
export function buildCinemaVideo(
  input: CinemaInput,
  actor: CinemaActor,
  options: {
    newId: () => string;
    existing?: CinemaVideo | null;
    actorIdentities?: Set<string>;
  },
): CinemaValidation {
  const title = text(input.title);
  const embedUrl = text(input.embedUrl) || text(input.url);
  const gradeId = text(input.gradeId);
  let teacherId = text(input.teacherId);
  const description = text(input.description);

  if (!gradeId) return { ok: false, status: 400, error: "يرجى تحديد الصف الدراسي للفيديو" };
  if (actor.role === "teacher") {
    const identities = options.actorIdentities ?? new Set([scopeKey(actor.teacherId)]);
    if (!teacherId) teacherId = actor.teacherId;
    if (!identities.has(scopeKey(teacherId))) {
      return { ok: false, status: 403, error: "لا يمكن للمعلم إسناد فيديو لمعلم آخر" };
    }
  }
  if (!teacherId) return { ok: false, status: 400, error: "يرجى تحديد المعلم المسؤول عن الفيديو" };
  if (!isSafeCinemaUrl(embedUrl)) {
    return { ok: false, status: 400, error: "رابط الفيديو غير صالح — يُقبل رابط http(s) فقط" };
  }
  if (title.length > CINEMA_TITLE_MAX || description.length > CINEMA_DESCRIPTION_MAX) {
    return { ok: false, status: 400, error: "عنوان الفيديو أو وصفه أطول من المسموح" };
  }

  const existing = options.existing ?? null;
  const now = new Date().toISOString();
  return {
    ok: true,
    video: {
      id: existing?.id || text(input.id) || options.newId(),
      title: title || existing?.title || "فيديو سينما منارة",
      embedUrl,
      sourceType: sourceTypeOf(input.sourceType, embedUrl),
      description,
      gradeId,
      teacherId,
      teacherName: text(input.teacherName) || existing?.teacherName || "",
      // من أضافه أوّل مرة يبقى: التعديلُ لا يغيّر صاحبَ الإضافة.
      createdBy: existing?.createdBy || (actor.role === "admin" ? "admin" : actor.teacherId),
      createdAt: existing?.createdAt || now,
      updatedAt: now,
      legacy: existing?.legacy ?? false,
    },
  };
}

/** ما يُرسل للوحة وللتطبيق: بلا علامة التخزين الداخلية. */
export function publicCinemaVideo(video: CinemaVideo): Record<string, unknown> {
  return {
    id: video.id,
    title: video.title,
    embedUrl: video.embedUrl,
    url: video.embedUrl,
    sourceType: video.sourceType,
    description: video.description,
    gradeId: video.gradeId,
    teacherId: video.teacherId,
    teacherName: video.teacherName,
    createdBy: video.createdBy,
    createdAt: video.createdAt,
    updatedAt: video.updatedAt,
  };
}
