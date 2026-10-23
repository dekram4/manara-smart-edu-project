/**
 * «الترفيه والألعاب»: ألعابٌ يضيفها المشرف ويُسندها إلى معلّم — قواعدُها بلا
 * قاعدة بيانات، فتُختبر وحدها.
 *
 * ── اللعبةُ لمعلّمٍ واحد ──
 * كلُّ لعبةٍ مُسندةٌ إلى معلّمٍ إلزاماً، ولا يراها إلا طلابُه، وما دامت مفعّلة.
 * لا «لعبةَ للجميع»: لعبةٌ بلا معلّمٍ تُرفض عند الحفظ، ولا تظهر لأحدٍ إن وُجدت.
 * إلا ألعابَ الفهرس الأساسية — انظر «ألعاب الفهرس الأساسية» أدناه.
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

// ── ألعابُ الفهرس الأساسية ─────────────────────────────────────────────
//
// الألعابُ الستّ في `GAME_CATALOG` تُعرض لكل الطلاب من `/api/game-catalog`.
// وتظهر في شاشة المشرف بمعرّفٍ ثابت (`builtin-<id>`)، فيعدّل اسمها ووصفها،
// أو يخفيها، أو يُسندها إلى معلّمٍ فلا يراها إلا طلابه. وما يغيّره يُحفظ
// صفّاً بالمعرّف نفسه في الجدول — تعديلاً فوق الأصل لا نسخةً منه — وحذفُه
// يُعيد اللعبة إلى أصلها. ورابطُها ثابتٌ على وكيل الخادم: هو ما ينظّفها من
// الإعلانات، فلا يُستبدل.

export const BUILTIN_PREFIX = "builtin-";

/** «كل الطلاب»: لعبةٌ أساسية غيرُ مسندةٍ لمعلّم. للأساسية وحدها. */
export const ALL_STUDENTS = "";

export type CatalogEntry = { id: string; title: string; subtitle: string };

export function isBuiltinId(id: string): boolean {
  return id.startsWith(BUILTIN_PREFIX);
}

export function builtinGameUrl(catalogId: string): string {
  return `/api/game-embed/${catalogId}/index.html`;
}

/** الأساسيةُ بأصلها: لكل الطلاب، مفعّلة. */
export function builtinDefaults(catalog: readonly CatalogEntry[]): EntertainmentGame[] {
  return catalog.map((entry) => ({
    id: `${BUILTIN_PREFIX}${entry.id}`,
    title: entry.title,
    description: entry.subtitle,
    embedUrl: builtinGameUrl(entry.id),
    teacherId: ALL_STUDENTS,
    teacherName: "",
    isActive: true,
    createdAt: "",
    updatedAt: "",
  }));
}

/**
 * الأساسيةُ بعد تعديلات المشرف، بترتيب الفهرس. ورابطُها من الأصل دائماً.
 */
export function applyBuiltinOverrides(
  defaults: EntertainmentGame[],
  stored: EntertainmentGame[],
): EntertainmentGame[] {
  const overrides = new Map(stored.filter((game) => isBuiltinId(game.id)).map((game) => [game.id, game]));
  return defaults.map((base) => {
    const override = overrides.get(base.id);
    return override ? { ...override, embedUrl: base.embedUrl } : base;
  });
}

/**
 * فهرسُ `/api/game-catalog` بعد تعديلات المشرف: لا تبقى فيه إلا الأساسيةُ
 * المفعّلةُ لكل الطلاب، باسمها ووصفها كما عدّلهما. والمسندةُ إلى معلّم تخرج
 * منه إلى `/api/student/entertainment` لطلاب ذلك المعلم.
 */
export function publicCatalog<T extends CatalogEntry>(catalog: readonly T[], stored: EntertainmentGame[]): T[] {
  const games = applyBuiltinOverrides(builtinDefaults(catalog), stored);
  return catalog.flatMap((entry, index) => {
    const game = games[index];
    if (!game.isActive || game.teacherId !== ALL_STUDENTS) return [];
    return [{ ...entry, title: game.title || entry.title, subtitle: game.description || entry.subtitle }];
  });
}

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
 * مسارُ وكيل الألعاب نسبياً بأيّ شكلٍ يُلصق: بـ`index.html` أو بلا، وبحروف
 * المعرّف كبيرةً أو صغيرة. ويلتقط المعرّف.
 *
 * ── لماذا يُقبل كلُّ هذا ──
 * المشرفُ ينسخ الرابطَ من لعبةٍ في القائمة أو من صفحتها، فيصل
 * `/api/game-embed/<id>/` أو `api/game-embed/<id>/index.html`. وكان يُقبل شكلٌ
 * واحدٌ فقط، والنموذجُ نفسُه يطلب رابطاً خارجياً كاملاً — فلم تُضف اللعبة.
 */
const PROXY_PATH = /^\/api\/game-embed\/([a-f0-9]{32})(?:\/(?:index\.html)?)?$/i;

/** الرابطُ كما لُصق بلا مسافاتٍ حوله، ومسارُ الوكيل النسبيُّ بشرطته الأولى. */
export function gameUrlInput(value: unknown): string {
  const url = text(value);
  return /^api\/game-embed\//i.test(url) ? `/${url}` : url;
}

/**
 * رابطُ لعبةٍ يُقبل: http(s) مطلقٌ بمضيف، أو صفحةُ لعبةٍ من وكيل الخادم
 * (`/api/game-embed/<id>/index.html`) — وهما ما يفتحه مشغّلُ الألعاب في التطبيق.
 * وما سواهما (`javascript:`، `data:`، مسارٌ آخر) يُرفض.
 */
export function isSafeGameUrl(value: unknown): boolean {
  const url = gameUrlInput(value);
  if (!url || url.length > GAME_URL_MAX || /\s/.test(url)) return false;
  if (url.startsWith("/")) return PROXY_PATH.test(url);
  try {
    const parsed = new URL(url);
    return (parsed.protocol === "https:" || parsed.protocol === "http:") && Boolean(parsed.hostname);
  } catch {
    return false;
  }
}

/**
 * معرّفُ لعبة GameDistribution من رابطها، أو `null`.
 *
 * يقبل رابطَ الصفحة العامّ (`html5.gamedistribution.com/<id>/…`) ورابطَ ملفّاتها
 * (`…/rvvASMiM/<id>/…`) ورابطَ وكيلنا (`/api/game-embed/<id>/…`).
 */
export function gameDistributionId(value: unknown): string | null {
  const url = gameUrlInput(value);
  const proxied = PROXY_PATH.exec(url) ?? /^\/api\/game-embed\/([a-f0-9]{32})\//i.exec(url);
  if (proxied) return proxied[1].toLowerCase();
  try {
    const parsed = new URL(url);
    // ‏رابطُ وكيلنا كاملاً بنطاق الموقع (`https://manara-aiedu.com/api/game-embed/<id>/…`):
    // ‏نسخه المعلمُ من صفحة اللعبة فحُفظ هكذا، فكانت ألعابُه كلُّها «غير موجودة».
    // ‏المعرّفُ وحده يؤخذ؛ والوكيلُ يجلب اللعبةَ من GameDistribution لا من هذا النطاق.
    const ownProxy = PROXY_PATH.exec(parsed.pathname) ??
      /^\/api\/game-embed\/([a-f0-9]{32})\//i.exec(parsed.pathname);
    if (ownProxy && (parsed.protocol === "https:" || parsed.protocol === "http:")) {
      return ownProxy[1].toLowerCase();
    }
    if (parsed.hostname !== "html5.gamedistribution.com") return null;
    const segments = parsed.pathname.split("/").filter(Boolean);
    const id = segments[0] === "rvvASMiM" ? segments[1] : segments[0];
    return id && /^[a-f0-9]{32}$/.test(id.toLowerCase()) ? id.toLowerCase() : null;
  } catch {
    return null;
  }
}

/**
 * ── قاعدةٌ دائمة: كلُّ لعبةٍ بلا إعلانات ──
 * الألعابُ الستّ الأولى تمرّ بوكيل منارة (`/api/game-embed`) الذي يستبدل مكتبةَ
 * إعلانات GameDistribution ببديلٍ صامت. ولعبةٌ يضيفها مشرفٌ أو معلّمٌ برابط
 * GameDistribution العامّ كانت تُفتح كما هي — بإعلاناتها. فيُحوَّل رابطُها هنا
 * إلى الوكيل نفسه، تلقائياً، بلا ضبطٍ يدويّ لأيّ لعبةٍ مستقبلاً. ورابطٌ من مصدرٍ
 * آخر يبقى كما هو.
 */
export function playableGameUrl(embedUrl: string): string {
  const id = gameDistributionId(embedUrl);
  return id ? `/api/game-embed/${id}/index.html` : embedUrl;
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
  const existing = options.existing ?? null;
  // الأساسية: رابطُها ثابت، ويجوز أن تبقى لكل الطلاب. وغيرُها لمعلّمٍ إلزاماً.
  const builtin = Boolean(existing && isBuiltinId(existing.id));
  const title = text(input.title);
  const description = text(input.description);
  const embedUrl = builtin ? existing!.embedUrl : gameUrlInput(input.embedUrl) || gameUrlInput(input.url);
  const teacherId = text(input.teacherId);

  if (!title) return { ok: false, status: 400, error: "عنوان اللعبة مطلوب" };
  if (title.length > GAME_TITLE_MAX) return { ok: false, status: 400, error: "عنوان اللعبة طويل جداً" };
  if (description.length > GAME_DESCRIPTION_MAX) return { ok: false, status: 400, error: "الوصف طويل جداً" };
  if (!embedUrl) return { ok: false, status: 400, error: "رابط اللعبة مطلوب" };
  if (!isSafeGameUrl(embedUrl)) {
    return {
      ok: false,
      status: 400,
      error: "رابط اللعبة غير صالح: رابطٌ يبدأ بـ https:// أو مسارُ لعبة مثل /api/game-embed/<المعرّف>/index.html",
    };
  }
  let teacher: { id: string; name: string } | null = null;
  if (teacherId) {
    teacher = options.teachers.find((item) => item.id === teacherId) ?? null;
    if (!teacher) return { ok: false, status: 400, error: "المعلم المختار غير مسجّل في النظام" };
  } else if (!builtin) {
    return { ok: false, status: 400, error: "يرجى اختيار المعلم المسؤول عن اللعبة" };
  }

  return {
    ok: true,
    game: {
      id: existing?.id ?? options.newId(),
      title,
      description,
      // ‏رابطُ لعبة GameDistribution يُحفظ بصيغة الألعاب الأساسية نفسها
      // ‏(`/api/game-embed/<id>/index.html`) أيّاً كان شكلُ ما لُصق: رابطُها العامّ،
      // ‏أو رابطُ الوكيل كاملاً بنطاق الموقع. وما سواه يُحفظ كما هو.
      embedUrl: builtin ? embedUrl : playableGameUrl(embedUrl),
      teacherId: teacher?.id ?? ALL_STUDENTS,
      teacherName: teacher?.name ?? "",
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
    builtin: isBuiltinId(game.id),
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
export function studentGame(
  game: EntertainmentGame,
  shape: { orientation?: string; width?: number | null; height?: number | null } = {},
): Record<string, unknown> {
  return {
    id: `teacher-game-${game.id}`,
    title: game.title,
    subtitle: game.description,
    url: playableGameUrl(game.embedUrl),
    // الأساسيةُ المسندة تحمل اتجاهَها وأبعادَها من الفهرس.
    orientation: shape.orientation ?? "any",
    width: shape.width ?? null,
    height: shape.height ?? null,
  };
}
