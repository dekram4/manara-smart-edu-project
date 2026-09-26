import { Router } from "express";
import { apiSupabaseConfig, type StudentActor } from "../lib/studentAccess";
import { requireStudentSession } from "../middleware/studentAuth";
import { createRateLimit } from "../middleware/rateLimiter";
import { logger } from "../lib/logger";
import { buildLeaderboard, isClassmate } from "../lib/leaderboard";

/**
 * كتابات تقدّم الطالب — الوجه الخادمي.
 *
 * كان التطبيق يكتب في `students` و`quiz_results` و`interactions` مباشرةً
 * بمفتاح anon. ولأن مسار دخول الطالب لا يستعمل مصادقة Supabase، لا يوجد
 * `auth.uid()` تُقصر به الصفوف على صاحبها، فكانت أي سياسة كتابة لدور anon
 * تعني: كل حامل للمفتاح يعدّل درجات كل طالب. والمفتاح يُستخرَج من أي APK.
 *
 * الآن تمرّ الكتابات الست من هنا. والفارق الجوهري ليس أن الخادم يكتب بدلاً
 * من التطبيق — بل أن **هويّة الطالب تؤخذ من الرمز الموقَّع لا من الطلب**،
 * وأن **المكافأة تُحسب هنا لا تُستقبَل**. لو اكتفينا بتمرير ما يرسله
 * التطبيق لكنّا نقلنا الثغرة ولم نُغلقها: يكفي أن يرسل أحدهم
 * `{"gems": 999999}`.
 */

const router = Router();

// أسخى من محادثة الطالب لأن الكتابات هنا تتبع إيقاع الدروس والاختبارات،
// لكنه يكفي لكبح أي عميل يحاول تكرار المكافأة آلياً.
const progressRateLimit = createRateLimit(60);

type Json = Record<string, unknown>;

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asMap(value: unknown): Json {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Json)
    : {};
}

function num(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) return Math.trunc(value);
  const parsed = Number.parseInt(String(value ?? ""), 10);
  return Number.isFinite(parsed) ? parsed : 0;
}

function activeStudent(res: any): StudentActor {
  return res.locals.student as StudentActor;
}

function config() {
  const settings = apiSupabaseConfig();
  if (!settings) throw new Error("Supabase is not configured");
  return settings;
}

function headers(extra: Record<string, string> = {}): Record<string, string> {
  const settings = config();
  return {
    apikey: settings.key,
    Authorization: `Bearer ${settings.key}`,
    "Content-Type": "application/json",
    ...extra,
  };
}

/**
 * يُرفَض الكتابة مبكراً إن لم يكن مفتاح الخدمة مضبوطاً.
 *
 * بعد تشديد RLS لم يعد لدور anon حقّ الكتابة في `students` ولا
 * `quiz_results` ولا `interactions` — وهذا هو المقصود. فإن شُغِّل الخادم
 * بمفتاح anon وحده، تُردّ كل كتابة من Supabase بـ 401/403، ويرى الطفل
 * «تعذّر حفظ النتيجة» دون أن يذكر شيءٌ السبب. هذا الفحص يسمّيه.
 */
function assertWritable(): void {
  if (!process.env.SUPABASE_SERVICE_ROLE_KEY?.trim()) {
    throw new Error(
      "SUPABASE_SERVICE_ROLE_KEY is not configured: student progress writes " +
        "are refused by row-level security when the server holds only the anon key",
    );
  }
}

/** نصّ خطأ PostgREST كما ورد، مقصوصاً بما يكفي للسجلّ والرسالة. */
async function failureDetail(
  response: { status: number; text: () => Promise<string> },
): Promise<string> {
  let body = "";
  try {
    body = (await response.text()).trim();
  } catch {
    body = "";
  }
  return body === "" ? `${response.status}` : `${response.status} ${body.slice(0, 400)}`;
}

// ── قراءة صف الطالب ──────────────────────────────────────────────────────
//
// `StudentActor.id` قد يكون المعرّف المخزّن داخل `data` لا معرّف الصف، وهما
// يختلفان في السجلات القديمة. والتحديث يحتاج معرّف الصف تحديداً، فنقرأ
// الاثنين معاً ونُرجعهما.
type StudentRow = { rowId: string; data: Json };

async function readStudentRow(student: StudentActor): Promise<StudentRow | null> {
  const settings = config();
  const attempt = async (filter: string): Promise<StudentRow | null> => {
    const response = await fetch(
      `${settings.url}/rest/v1/students?select=id,data&${filter}&limit=1`,
      { headers: headers() },
    );
    if (!response.ok) throw new Error(`Student read failed (${response.status})`);
    const rows = await response.json();
    if (!Array.isArray(rows) || rows.length === 0) return null;
    const row = rows[0];
    const rowId = text(row?.id);
    return rowId ? { rowId, data: asMap(row?.data) } : null;
  };
  const id = encodeURIComponent(student.id);
  return (await attempt(`id=eq.${id}`)) ?? (await attempt(`data->>id=eq.${id}`));
}

async function writeStudentData(rowId: string, data: Json): Promise<void> {
  assertWritable();
  const settings = config();
  const response = await fetch(
    `${settings.url}/rest/v1/students?id=eq.${encodeURIComponent(rowId)}`,
    {
      method: "PATCH",
      headers: headers({ Prefer: "return=minimal" }),
      body: JSON.stringify({ data, updated_at: new Date().toISOString() }),
    },
  );
  if (!response.ok) {
    throw new Error(`Student write failed (${await failureDetail(response)})`);
  }
}

async function upsertRow(table: string, row: Json): Promise<void> {
  assertWritable();
  const settings = config();
  const response = await fetch(`${settings.url}/rest/v1/${table}`, {
    method: "POST",
    headers: headers({ Prefer: "resolution=merge-duplicates,return=minimal" }),
    body: JSON.stringify(row),
  });
  if (!response.ok) {
    // مع نصّ الردّ: بدونه كان كل فشل يصل كرقم حالة وحده، فلا يُعرف
    // أهو رفض صلاحيات أم عمود مفقود أم قيمة لا يقبلها الجدول.
    throw new Error(`${table} write failed (${await failureDetail(response)})`);
  }
}

// ── نموذج اللعبنة ────────────────────────────────────────────────────────
//
// مطابق لـ `StudentGamification` في التطبيق حرفاً بحرف، ومنه تأتي القاعدة
// التي لا تُخالَف: المستوى مشتقّ من الخبرة دائماً (⌊xp/100⌋) ولا يُقرأ من
// اللقطة المخزّنة، فلا يستطيع عميلٌ رفع مستواه بكتابته مباشرةً.
type Achievement = { id: string; title: string; description: string; icon: string };

type Gamification = {
  xp: number;
  gems: number;
  streak: number;
  totalQuizzes: number;
  totalLessons: number;
  totalGames: number;
  averageScore: number;
  lastQuizAt: string | null;
  lastQuizPercentage: number | null;
  achievements: Achievement[];
  completedActivities: string[];
};

function levelOf(xp: number): number {
  return Math.floor(xp / 100);
}

function readGamification(value: unknown): Gamification {
  const map = asMap(value);
  const rawAchievements = Array.isArray(map.achievements) ? map.achievements : [];
  const rawActivities = Array.isArray(map.completedActivities) ? map.completedActivities : [];
  return {
    xp: num(map.xp),
    gems: num(map.gems),
    streak: num(map.streak),
    totalQuizzes: num(map.totalQuizzes),
    totalLessons: num(map.totalLessons),
    totalGames: num(map.totalGames),
    averageScore: num(map.averageScore),
    lastQuizAt: text(map.lastQuizAt) || null,
    lastQuizPercentage: map.lastQuizPercentage == null ? null : num(map.lastQuizPercentage),
    achievements: rawAchievements
      .map((item) => {
        const entry = asMap(item);
        return {
          id: text(entry.id),
          title: text(entry.title),
          description: text(entry.description ?? entry.desc),
          icon: text(entry.icon),
        };
      })
      .filter((item) => item.id !== ""),
    completedActivities: rawActivities
      .map((item) => String(item ?? ""))
      .filter((item) => item !== ""),
  };
}

function writeGamification(stats: Gamification): Json {
  const level = levelOf(stats.xp);
  const out: Json = {
    xp: stats.xp,
    gems: stats.gems,
    level,
    levelProgress: stats.xp % 100,
    streak: stats.streak,
    totalQuizzes: stats.totalQuizzes,
    totalLessons: stats.totalLessons,
    totalGames: stats.totalGames,
    achievementsCount: stats.achievements.length,
    achievements: stats.achievements.map((item) => ({
      id: item.id,
      title: item.title,
      description: item.description,
      icon: item.icon,
    })),
    completedActivities: stats.completedActivities,
    averageScore: stats.averageScore,
    updatedAt: new Date().toISOString(),
  };
  if (stats.lastQuizAt != null) out.lastQuizAt = stats.lastQuizAt;
  if (stats.lastQuizPercentage != null) out.lastQuizPercentage = stats.lastQuizPercentage;
  return out;
}

// نصوص الإنجازات بالعربية، مطابقة لما في `student_strings.dart`. تبقى هنا
// لأن الخادم صار هو من يكتبها في الصف، ويقرؤها التطبيق ولوحة المعلم معاً.
const ACHIEVEMENTS: Record<string, Omit<Achievement, "id">> = {
  first_quiz: { title: "أول اختبار", description: "أكمل أول اختبار", icon: "🎯" },
  quiz_warrior: { title: "مقاتل الاختبارات", description: "أكمل 10 اختبارات", icon: "⚔️" },
  perfect_quiz: { title: "نتيجة مثالية", description: "حصل على 100% في اختبار", icon: "⭐" },
  first_lesson: { title: "أول درس", description: "أكمل أول درس", icon: "📚" },
  lesson_master: { title: "سيد الدروس", description: "أكمل 10 دروس", icon: "🏆" },
  math_solver: { title: "حلال المسائل", description: "حل أول مسألة", icon: "🔢" },
  game_master: { title: "سيد الألعاب", description: "العب 5 ألعاب", icon: "🎮" },
  memory_master: { title: "سيد الذاكرة", description: "انتصر في لعبة الذاكرة", icon: "🧠" },
  speed_demon: { title: "سريع كالبرق", description: "فوز في الاختبار السريع", icon: "⚡" },
  level_5: { title: "المستوى 5", description: "اوصل إلى المستوى 5", icon: "💪" },
  gem_collector: { title: "جامع الجواهر", description: "اجمع 50 جوهرة", icon: "💎" },
  streak_3: { title: "3 أيام متواصل", description: "تعلم 3 أيام متتالية", icon: "🔥" },
  streak_5: { title: "5 أيام متواصل", description: "تعلم 5 أيام متتالية واحصل على مكافأة", icon: "🏅" },
  streak_7: { title: "أسبوع متواصل", description: "تعلم 7 أيام متتالية", icon: "🔥" },
};

function achievement(id: string): Achievement | null {
  const entry = ACHIEVEMENTS[id];
  return entry ? { id, ...entry } : null;
}

function achievementsFor(
  stats: Gamification,
  type: string,
  perfectQuiz: boolean,
  activityId: string,
): Achievement[] {
  const ids: string[] = [];
  if (type === "quiz" && stats.totalQuizzes === 1) ids.push("first_quiz");
  if (type === "quiz" && stats.totalQuizzes >= 10) ids.push("quiz_warrior");
  if (type === "quiz" && perfectQuiz) ids.push("perfect_quiz");
  if (type === "lesson" && stats.totalLessons === 1) ids.push("first_lesson");
  if (type === "lesson" && stats.totalLessons >= 10) ids.push("lesson_master");
  if (type === "problem") ids.push("math_solver");
  if (type === "game" && stats.totalGames >= 5) ids.push("game_master");
  const normalizedActivity = activityId.toLowerCase();
  if (type === "game" && normalizedActivity.includes("memory")) ids.push("memory_master");
  if (type === "game" && normalizedActivity.includes("speed")) ids.push("speed_demon");
  if (levelOf(stats.xp) >= 5) ids.push("level_5");
  if (stats.gems >= 50) ids.push("gem_collector");
  return ids
    .map(achievement)
    .filter((item): item is Achievement => item !== null);
}

// ── المكافأة ─────────────────────────────────────────────────────────────

const ACTIVITY_TYPES = new Set([
  "quiz",
  "lesson",
  "video",
  "lesson_video",
  "problem",
  "game",
]);

type RewardOutcome = {
  xp: number;
  gems: number;
  alreadyRewarded: boolean;
  levelUp: boolean;
  newAchievements: Achievement[];
  snapshot: Json;
};

function rewardFor(
  current: Gamification,
  activityType: string,
  activityId: string,
  rewardId: string,
  correctAnswers: number | null,
  quizTotal: number | null,
): { outcome: RewardOutcome; next: Gamification | null } {
  const type = activityType.trim().toLowerCase();
  const key = rewardId.trim() !== "" ? rewardId.trim() : `${type}:${activityId}`;
  const legacyQuizKey = type === "quiz" ? `quiz:${activityId}` : "";
  const legacyVideoKeys =
    type === "video"
      ? [`lesson_video:${activityId}`]
      : type === "lesson_video"
        ? [`video:${activityId}`]
        : [];

  // السجلّ يجعل الإعادة بلا أثر: لا مكافأة مرتين على نشاط واحد. وهو الحارس
  // الذي يمنع تكرار الطلب من مضاعفة الجواهر.
  if (
    current.completedActivities.includes(key) ||
    (legacyQuizKey !== "" && current.completedActivities.includes(legacyQuizKey)) ||
    legacyVideoKeys.some((item) => current.completedActivities.includes(item))
  ) {
    return {
      outcome: {
        xp: 0,
        gems: 0,
        alreadyRewarded: true,
        levelUp: false,
        newAchievements: [],
        snapshot: writeGamification(current),
      },
      next: null,
    };
  }

  let gems = 0;
  let quizzes = current.totalQuizzes;
  let lessons = current.totalLessons;
  let games = current.totalGames;
  let average = current.averageScore;
  let perfectQuiz = false;
  let quizPercentage: number | null = null;

  if (type === "quiz") {
    // الجواهر = عدد الإجابات الصحيحة، محصورةً بعدد الأسئلة. الحصر هنا هو
    // موضع الحماية: التطبيق يدّعي النتيجة، والخادم يرفض ما يتجاوز الممكن.
    const total = Math.max(0, quizTotal ?? 0);
    const score = Math.min(Math.max(0, correctAnswers ?? 0), total);
    gems = score;
    quizzes += 1;
    if (total > 0) {
      const scorePercentage = Math.trunc((score * 100) / total);
      quizPercentage = scorePercentage;
      perfectQuiz = scorePercentage === 100;
      average = Math.trunc((current.averageScore * (quizzes - 1) + scorePercentage) / quizzes);
    }
  } else if (type === "lesson") {
    gems = 5;
    lessons += 1;
  } else if (type === "video" || type === "lesson_video") {
    // مشاهدة السينما لا تمنح مكافأة.
    gems = 0;
  } else if (type === "problem") {
    gems = 1;
  } else if (type === "game") {
    gems = 3;
    games += 1;
  }

  const beforeLevel = levelOf(current.xp);
  const nextGems = current.gems + gems;
  // الخبرة لا تُمنح مباشرةً: تتراكم 20 نقطة عند كل عشر جواهر مكتملة. هذه هي
  // المعادلة الوحيدة في التطبيق، وأي `xp` يُرسله العميل يُهمَل.
  const gemMilestones = Math.floor(nextGems / 10) - Math.floor(current.gems / 10);
  const xp = gemMilestones * 20;
  const nextXp = current.xp + xp;

  const projected: Gamification = {
    ...current,
    xp: nextXp,
    gems: nextGems,
    totalQuizzes: quizzes,
    totalLessons: lessons,
    totalGames: games,
  };
  const knownIds = new Set(current.achievements.map((item) => item.id));
  const newAchievements = achievementsFor(projected, type, perfectQuiz, activityId).filter(
    (item) => !knownIds.has(item.id),
  );

  const next: Gamification = {
    ...projected,
    averageScore: average,
    lastQuizAt: type === "quiz" ? new Date().toISOString() : current.lastQuizAt,
    lastQuizPercentage: type === "quiz" ? quizPercentage : current.lastQuizPercentage,
    achievements: [...current.achievements, ...newAchievements],
    completedActivities: [...current.completedActivities, key],
  };

  return {
    outcome: {
      xp,
      gems,
      alreadyRewarded: false,
      levelUp: levelOf(nextXp) > beforeLevel,
      newAchievements,
      snapshot: writeGamification(next),
    },
    next,
  };
}

// ── المسارات ─────────────────────────────────────────────────────────────

router.use("/student/progress", requireStudentSession, progressRateLimit);

/** مكافأة نشاط واحد. الجسد يصف ما جرى؛ الخادم وحده يقرّر ما يستحقّه. */
router.post("/student/progress/reward", async (req, res) => {
  const student = activeStudent(res);
  const body = asMap(req.body);
  const activityType = text(body.activityType).toLowerCase();
  const activityId = text(body.activityId);

  if (activityId === "") {
    res.status(400).json({ error: "معرّف النشاط مطلوب" });
    return;
  }
  if (!ACTIVITY_TYPES.has(activityType)) {
    res.status(400).json({ error: `نوع نشاط غير معروف: ${activityType}` });
    return;
  }

  try {
    const row = await readStudentRow(student);
    if (!row) {
      res.status(404).json({ error: "سجلّ الطالب غير موجود" });
      return;
    }
    const current = readGamification(asMap(row.data).gamification);
    const { outcome, next } = rewardFor(
      current,
      activityType,
      activityId,
      text(body.rewardId),
      body.correctAnswers == null ? null : num(body.correctAnswers),
      body.quizTotal == null ? null : num(body.quizTotal),
    );
    if (next) {
      await writeStudentData(row.rowId, {
        ...row.data,
        gamification: outcome.snapshot,
        lastActivity: new Date().toISOString(),
      });
    }
    res.json(outcome);
  } catch (error) {
    logger.error({ err: error }, "[student-progress] reward failed");
    res.status(503).json({ error: "تعذر حفظ التقدّم الآن" });
  }
});

/**
 * لوحة صدارة زملاء الصفّ بالجواهر.
 *
 * ── من يظهر فيها ──
 * طلاب المعلّم نفسه في الصفّ نفسه. لا المادة ولا الفصل الدراسي: الجواهر
 * تُجمع من كل ما يفعله الطفل في المنصّة، فترشيحُ اللوحة بالمادة يُخرج
 * زميلاً يجلس بجانبه لأنه يدرس مادةً أخرى.
 *
 * ── ولماذا قراءةٌ واحدة تُرشَّح هنا ──
 * جدول `students` يحمل الصفّ والمالك داخل `data` لا في أعمدة، فلا
 * يُرشَّح على الخادم بشرطٍ واحد موثوق. والترشيح بعد القراءة يقرأ أكثر
 * ممّا يحتاج، لكنه الوحيد الذي يطبّق التسوية العربية نفسها التي تطبّقها
 * بقيّة المنظومة — والهمزة وحدها كانت تُخرج نصف الفصل.
 *
 * ولا يخرج من هنا ما لا يلزم اللوحة: الاسم والشخصية والجواهر والخبرة
 * والمستوى. لا اسم مستخدم ولا كلمة مرور ولا وليّ أمر.
 */
router.get("/student/progress/leaderboard", async (_req, res) => {
  const student = activeStudent(res);
  try {
    const settings = config();
    const response = await fetch(
      `${settings.url}/rest/v1/students?select=id,data&limit=5000`,
      { headers: headers() },
    );
    if (!response.ok) {
      throw new Error(`Students read failed (${await failureDetail(response)})`);
    }
    const rows = await response.json();
    const classmates = (Array.isArray(rows) ? rows : []).filter((row: any) =>
      isClassmate(asMap(row?.data), student.teacherId, student.grade),
    );
    const board = buildLeaderboard(classmates, student.id);
    res.json({
      ...board,
      grade: student.grade,
      // الطالب قد لا يظهر في القائمة إن كان سجلّه بصفٍّ مختلفٍ عن جلسته؛
      // يُقال ذلك صراحةً بدل أن يُعرض «المركز 0».
      listed: board.myRank > 0,
    });
  } catch (error) {
    logger.error({ err: error, studentId: student.id }, "[student-progress] leaderboard failed");
    res.status(503).json({ error: "تعذر تحميل لوحة الصدارة الآن" });
  }
});

/** سلسلة الأيام المتتالية. اليوم يُحسب من ساعة الخادم لا من ساعة الجهاز. */
router.post("/student/progress/streak", async (_req, res) => {
  const student = activeStudent(res);
  try {
    const row = await readStudentRow(student);
    if (!row) {
      res.status(404).json({ error: "سجلّ الطالب غير موجود" });
      return;
    }
    const current = readGamification(asMap(row.data).gamification);
    const today = new Date();
    const dayKey = `${today.getFullYear()}-${today.getMonth() + 1}-${today.getDate()}`;
    const marker = `streak-day:${dayKey}`;

    if (current.completedActivities.includes(marker)) {
      res.json({
        xp: 0,
        gems: 0,
        alreadyRewarded: true,
        levelUp: false,
        newAchievements: [],
        snapshot: writeGamification(current),
      });
      return;
    }

    const prefix = "streak-day:";
    const days = current.completedActivities.filter((item) => item.startsWith(prefix));
    let streak = 1;
    const lastDay = days.length > 0 ? days[days.length - 1].slice(prefix.length) : "";
    if (lastDay !== "") {
      const parsed = new Date(lastDay);
      if (!Number.isNaN(parsed.getTime())) {
        const midnightToday = Date.UTC(today.getFullYear(), today.getMonth(), today.getDate());
        const midnightLast = Date.UTC(parsed.getFullYear(), parsed.getMonth(), parsed.getDate());
        if (Math.round((midnightToday - midnightLast) / 86_400_000) === 1) {
          streak = current.streak + 1;
        }
      }
    }

    const bonus = streak % 5 === 0 ? 100 : 0;
    const knownIds = new Set(current.achievements.map((item) => item.id));
    const earned: Achievement[] = [];
    for (const [threshold, id] of [
      [3, "streak_3"],
      [5, "streak_5"],
      [7, "streak_7"],
    ] as const) {
      if (streak >= threshold && !knownIds.has(id)) {
        const unlocked = achievement(id);
        if (unlocked) earned.push(unlocked);
      }
    }

    const nextXp = current.xp + bonus;
    const next: Gamification = {
      ...current,
      xp: nextXp,
      streak,
      achievements: [...current.achievements, ...earned],
      // السجلّ يبقى كما هو ويُضاف إليه اليوم. كانت النسخة التي في التطبيق
      // تكتب `[...days, marker]` أي أيام السلسلة وحدها، فتمحو كل مفاتيح
      // المكافآت المكتسبة — ويستطيع الطالب بعدها إعادة كسب مكافأة كل درس
      // واختبار سبق أن أنهاه. أُصلح هنا لا نُقل.
      completedActivities: [...current.completedActivities, marker],
    };

    await writeStudentData(row.rowId, {
      ...row.data,
      gamification: writeGamification(next),
      lastActivity: new Date().toISOString(),
    });

    res.json({
      xp: bonus,
      gems: 0,
      alreadyRewarded: false,
      levelUp: levelOf(nextXp) > levelOf(current.xp),
      newAchievements: earned,
      snapshot: writeGamification(next),
    });
  } catch (error) {
    logger.error({ err: error }, "[student-progress] streak failed");
    res.status(503).json({ error: "تعذر تحديث السلسلة الآن" });
  }
});

/** مظهر الشخصية. لا يمسّ اللعبنة، فيُكتب وحده. */
router.post("/student/progress/appearance", async (req, res) => {
  const student = activeStudent(res);
  const appearance = asMap(asMap(req.body).appearance);
  try {
    const row = await readStudentRow(student);
    if (!row) {
      res.status(404).json({ error: "سجلّ الطالب غير موجود" });
      return;
    }
    await writeStudentData(row.rowId, {
      ...row.data,
      appearance,
      lastActivity: new Date().toISOString(),
    });
    res.json({ ok: true });
  } catch (error) {
    logger.error({ err: error }, "[student-progress] appearance save failed");
    res.status(503).json({ error: "تعذر حفظ الشخصية الآن" });
  }
});

/**
 * نتيجة اختبار.
 *
 * `studentId` و`studentName` يُكتبان من الجلسة لا من الجسد — وهذا هو
 * الفارق كلّه: بدونه يستطيع أي طالب تسجيل نتيجة باسم زميله.
 */
router.post("/student/progress/quiz-result", async (req, res) => {
  const student = activeStudent(res);
  const body = asMap(req.body);
  const result = asMap(body.result);
  const id = text(result.id);
  if (id === "") {
    res.status(400).json({ error: "معرّف النتيجة مطلوب" });
    return;
  }

  const quizType = text(result.quizType).toLowerCase() === "teacher" ? "teacher" : "periodic";
  const safeResult: Json = {
    ...result,
    id,
    studentId: student.id,
    studentName: student.name,
    quizType,
    grade: text(result.grade) || student.grade,
    subject: text(result.subject) || student.subject,
    term: text(result.term) || student.term,
    unit: text(result.unit) || student.unit,
    lesson: text(result.lesson),
  };

  try {
    // اختبار المعلم يُحلّ مرة واحدة. الفحص هنا على الخادم، فلا يستطيع عميل
    // معدَّل تخطّيه بإعادة الإرسال.
    if (quizType === "teacher") {
      const settings = config();
      const quizId = text(safeResult.quizId);
      const url = new URL(`${settings.url}/rest/v1/quiz_results`);
      url.searchParams.set("select", "id,data");
      url.searchParams.set("data->>studentId", `eq.${student.id}`);
      url.searchParams.set("data->>quizId", `eq.${quizId}`);
      url.searchParams.set("limit", "1");
      const response = await fetch(url, { headers: headers() });
      if (!response.ok) throw new Error(`Quiz lookup failed (${response.status})`);
      const rows = await response.json();
      const existing = Array.isArray(rows) ? rows : [];
      for (const row of existing) {
        const stored = asMap(asMap(row).data);
        if (text(stored.quizType).toLowerCase() === "teacher") {
          res.status(409).json({
            error: "سبق تسليم هذا الاختبار",
            result: { ...stored, id: text(asMap(row).id) || text(stored.id) },
          });
          return;
        }
      }
    }

    await upsertRow("quiz_results", {
      id,
      data: safeResult,
      updated_at: new Date().toISOString(),
    });
    res.json({ result: safeResult });
  } catch (error) {
    logger.error(
      { err: error, studentId: student.id, resultId: id },
      "[student-progress] quiz result save failed",
    );
    // التفصيل يرافق الرسالة: حفظُ نتيجة اختبار يفشل صامتاً هو درجةٌ ضائعة،
    // ولا سبيل لمعرفة السبب من جهاز طالب دون أن يُقال.
    res.status(503).json({
      error: "تعذر حفظ نتيجة الاختبار الآن",
      detail: error instanceof Error ? error.message : String(error),
    });
  }
});

/** تفاعلات المعلم الافتراضي وحلّال المسائل. */
router.post("/student/progress/interaction", async (req, res) => {
  const student = activeStudent(res);
  const body = asMap(req.body);
  const kind = text(body.type);
  if (kind !== "virtual_teacher" && kind !== "problem_solver") {
    res.status(400).json({ error: `نوع تفاعل غير معروف: ${kind}` });
    return;
  }

  const now = new Date();
  const suffix = kind === "problem_solver" ? "_solver_" : "_";
  const id = `${student.id}${suffix}${now.getTime()}${Math.floor(Math.random() * 1000)}`;
  const data: Json =
    kind === "virtual_teacher"
      ? {
          studentId: student.id,
          type: "virtual_teacher",
          question: text(body.question),
          answer: text(body.answer),
          createdAt: now.toISOString(),
        }
      : {
          studentId: student.id,
          studentName: student.name,
          // حقول النطاق تأتي من سجلّ الطالب لا من الطلب: تقارير المعلم
          // والمشرف تُصفّي عليها، فلو قبِلناها من العميل لأمكن دسّ تفاعل
          // في صفّ معلم آخر.
          teacherId: student.teacherId,
          type: "problem_solver",
          lessonId: text(body.lessonId),
          question: text(body.question),
          grade: student.grade,
          subject: student.subject,
          term: student.term,
          unit: student.unit,
          createdAt: now.toISOString(),
        };

  try {
    await upsertRow("interactions", { id, data, updated_at: now.toISOString() });
    res.json({ ok: true, id });
  } catch (error) {
    logger.error({ err: error }, "[student-progress] interaction save failed");
    res.status(503).json({ error: "تعذر حفظ التفاعل الآن" });
  }
});

export default router;
