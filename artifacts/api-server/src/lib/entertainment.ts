/**
 * «الترفيه والألعاب»: ألعابٌ يضيفها المشرف ويُسندها إلى معلّم — قواعدُها بلا
 * قاعدة بيانات، فتُختبر وحدها.
 *
 * ── اللعبةُ لمعلّمٍ واحد ──
 * كلُّ لعبةٍ مُسندةٌ إلى معلّمٍ إلزاماً، ولا يراها إلا طلابُه، وما دامت مفعّلة.
 * لا «لعبةَ للجميع»: لعبةٌ بلا معلّمٍ تُرفض عند الحفظ، ولا تظهر لأحدٍ إن وُجدت.
 *
 * ── وتُشغَّل كما تُشغَّل ألعابُ «عالم الترفيه» ──
 * التطبيقُ يضيفها بعد ألعاب الفهرس الثابت (`/api/game-catalog`) في الرفّ نفسه،
 * وبالبطاقة نفسها والمشغّل نفسه وقاعدة الفتح بالمستوى نفسها. فالرابطُ رابطٌ
 * مضمَّن يفتحه مشغّلُ الألعاب كما هو.
 */

export type EntertainmentGame = {
  id: string;
  title: string;
  description: string;
  embedUrl: string;
  teacherId: string;
  teacherName: string;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
};

export const GAME_TITLE_MAX = 200;
export const GAME_DESCRIPTION_MAX = 1000;
export const GAME_URL_MAX = 2000;

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/** تسويةٌ للمقارنة — نفسُ `scopeKey` في `supabaseStore` و`cinema`. */
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
 * رابطُ لعبةٍ يُقبل: http(s) مطلقٌ بمضيف، أو صفحةُ لعبةٍ من وكيل الخادم
 * (`/api/game-embed/<id>/index.html`) — وهما ما يفتحه مشغّلُ الألعاب في التطبيق.
 * وما سواهما (`javascript:`، `data:`، مسارٌ آخر) يُرفض.
 */
export function isSafeGameUrl(value: unknown): boolean {
  const url = text(value);
  if (!url || url.length > GAME_URL_MAX || /\s/.test(url)) return false;
  if (url.startsWith("/")) return /^\/api\/game-embed\/[a-f0-9]{32}\/index\.html$/.test(url);
  try {
    const parsed = new URL(url);
    return (parsed.protocol === "https:" || parsed.protocol === "http:") && Boolean(parsed.hostname);
  } catch {
    return false;
  }
}

/** قيمةٌ منطقية من الجسم أو الصفّ: `false` و`"false"` و`0` تعطيل، وغيابُها تفعيل. */
function activeFlag(value: unknown, fallback: boolean): boolean {
  if (value === undefined || value === null || value === "") return fallback;
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  return !/^(false|0|no|off)$/i.test(String(value).trim());
}

export function fromTableRow(row: Record<string, unknown>): EntertainmentGame | null {
  const id = text(row.id);
  const embedUrl = text(row.embed_url);
  if (!id || !embedUrl) return null;
  return {
    id,
    title: text(row.title),
    description: text(row.description),
    embedUrl,
    teacherId: text(row.teacher_id),
    teacherName: text(row.teacher_name),
    isActive: activeFlag(row.is_active, true),
    createdAt: text(row.created_at),
    updatedAt: text(row.updated_at),
  };
}

export function toTableRow(game: EntertainmentGame): Record<string, unknown> {
  return {
    id: game.id,
    title: game.title,
    description: game.description,
    embed_url: game.embedUrl,
    teacher_id: game.teacherId,
    teacher_name: game.teacherName,
    is_active: game.isActive,
    created_at: game.createdAt,
    updated_at: game.updatedAt,
  };
}

/** السجلُّ في `app_kv` قبل إنشاء الجدول: الحقولُ نفسُها بأسماء الواجهة. */
export function fromKvRecord(record: Record<string, unknown>): EntertainmentGame | null {
  const id = text(record.id);
  const embedUrl = text(record.embedUrl);
  if (!id || !embedUrl) return null;
  return {
    id,
    title: text(record.title),
    description: text(record.description),
    embedUrl,
    teacherId: text(record.teacherId),
    teacherName: text(record.teacherName),
    isActive: activeFlag(record.isActive, true),
    createdAt: text(record.createdAt),
    updatedAt: text(record.updatedAt),
  };
}

export function toKvRecord(game: EntertainmentGame): Record<string, unknown> {
  return { ...game };
}

/** الجدولُ أولاً، ثم ما بقي في `app_kv` ولم يُنقل — بلا تكرار، الأقدمُ أولاً. */
export function mergeGames(
  tableGames: EntertainmentGame[],
  kvGames: EntertainmentGame[],
): EntertainmentGame[] {
  const byId = new Map<string, EntertainmentGame>();
  for (const game of [...kvGames, ...tableGames]) byId.set(game.id, game);
  return orderForUnlocking([...byId.values()]);
}

/**
 * الأقدمُ أولاً، كفيديوهات السينما: الألعابُ تُفتح بموضعها في الرفّ (مستوىً لكل
 * لعبة)، فلعبةٌ جديدة تُضاف في آخره ولا تُزيح لعبةً فتحها الطالب.
 */
export function orderForUnlocking(games: EntertainmentGame[]): EntertainmentGame[] {
  return [...games].sort((a, b) =>
    (a.createdAt || "").localeCompare(b.createdAt || "") || a.id.localeCompare(b.id),
  );
}

/**
 * يراها الطالب إن كانت مفعّلةً ومعلّمُها معلّمَه.
 *
 * [teacherIdentities] كلُّ ما يُعرف به معلّمُ الطالب (معرّفٌ واسمُ دخول واسم)،
 * مسوّىً — من `teacherIdentities` في `supabaseStore`. لعبةٌ بلا معلّمٍ لا تُرى.
 */
export function isVisibleToStudent(game: EntertainmentGame, teacherIdentities: Set<string>): boolean {
  if (!game.isActive) return false;
  const owner = scopeKey(game.teacherId);
  return Boolean(owner) && teacherIdentities.has(owner);
}

export type GameInput = Record<string, unknown>;

/**
 * لعبةٌ صالحةٌ للحفظ من جسم الطلب، أو سببُ رفضها.
 *
 * [teachers] المعلمون المسجّلون: المعلمُ المختار يجب أن يكون منهم، واسمُه يؤخذ
 * من سجلّه لا من الطلب. [existing] اللعبةُ قبل التعديل — يبقى تاريخُ إنشائها.
 */
export function buildGame(
  input: GameInput,
  options: {
    newId: () => string;
    now: string;
    teachers: Array<{ id: string; name: string }>;
    existing?: EntertainmentGame | null;
  },
): { ok: true; game: EntertainmentGame } | { ok: false; status: number; error: string } {
  const title = text(input.title);
  const description = text(input.description);
  const embedUrl = text(input.embedUrl) || text(input.url);
  const teacherId = text(input.teacherId);

  if (!title) return { ok: false, status: 400, error: "عنوان اللعبة مطلوب" };
  if (title.length > GAME_TITLE_MAX) return { ok: false, status: 400, error: "عنوان اللعبة طويل جداً" };
  if (description.length > GAME_DESCRIPTION_MAX) return { ok: false, status: 400, error: "الوصف طويل جداً" };
  if (!embedUrl) return { ok: false, status: 400, error: "رابط اللعبة مطلوب" };
  if (!isSafeGameUrl(embedUrl)) {
    return { ok: false, status: 400, error: "رابط اللعبة غير صالح: يجب أن يبدأ بـ https://" };
  }
  if (!teacherId) return { ok: false, status: 400, error: "يرجى اختيار المعلم المسؤول عن اللعبة" };
  const teacher = options.teachers.find((item) => item.id === teacherId);
  if (!teacher) return { ok: false, status: 400, error: "المعلم المختار غير مسجّل في النظام" };

  const existing = options.existing ?? null;
  return {
    ok: true,
    game: {
      id: existing?.id ?? options.newId(),
      title,
      description,
      embedUrl,
      teacherId: teacher.id,
      teacherName: teacher.name,
      isActive: activeFlag(input.isActive, existing?.isActive ?? true),
      createdAt: existing?.createdAt || options.now,
      updatedAt: options.now,
    },
  };
}

/** ما يُرسل للوحة المشرف. */
export function adminGame(game: EntertainmentGame): Record<string, unknown> {
  return {
    id: game.id,
    title: game.title,
    description: game.description,
    embedUrl: game.embedUrl,
    teacherId: game.teacherId,
    teacherName: game.teacherName,
    isActive: game.isActive,
    createdAt: game.createdAt,
    updatedAt: game.updatedAt,
  };
}

/**
 * ما يُرسل للطالب — بصيغة فهرس `/api/game-catalog` نفسها (`url`، `title`،
 * `subtitle`)، فيقرؤه التطبيقُ بالمحلّل نفسه. لا معلّمَ ولا حالة: لا شأن له بهما.
 */
export function studentGame(game: EntertainmentGame): Record<string, unknown> {
  return {
    id: `teacher-game-${game.id}`,
    title: game.title,
    subtitle: game.description,
    url: game.embedUrl,
    orientation: "any",
    width: null,
    height: null,
  };
}
