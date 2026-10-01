import { Router } from "express";
import { apiSupabaseConfig, type StudentActor } from "../lib/studentAccess";
import { requireStudentSession } from "../middleware/studentAuth";
import { createRateLimit } from "../middleware/rateLimiter";
import { logger } from "../lib/logger";
import {
  DUEL_MAX_SCORE,
  DUEL_POINTS_CORRECT,
  DUEL_POINTS_SPEED_MAX,
  DUEL_QUESTION_SECONDS,
  DUEL_ROUNDS,
  DUEL_WIN_GEMS,
  canSubmit,
  classKey,
  isDuelGame,
  matchId as newMatchId,
  outcomeOf,
  parseScore,
  sideOf,
  standingsOf,
  type MatchRow,
} from "../lib/duel";
import { awardDuelWin } from "./studentProgress";
import {
  buildDuelPack,
  parseDuelPack,
  type DuelPack,
  type LessonSeed,
} from "../lib/duelQuestions";
import { readBank } from "../lib/challengeBank";

/**
 * مبارياتُ التحدي بين زملاء الصفّ.
 *
 * ── والقرارُ كلُّه هنا لا في التطبيق ──
 * التطبيقُ يقول «نتيجتي أربع»، والخادم هو من يقرّر أنّ ذلك ممكن، وأنّ هذا
 * الطالبَ طرفٌ في المباراة، وأنه لم يُرسل نتيجتَه قبل، ومن فاز، وأنّ
 * الجوهرةَ تُصرف مرّةً واحدة. ولو تُرك شيءٌ من ذلك للتطبيق لكان رصيدُ
 * الجواهر مسألةَ من يُعدّل الطلب.
 *
 * ── والمباراةُ شبحٌ في جوهرها ──
 * كلٌّ يلعب جولتَه وتُسجَّل نتيجتُه، والمقارنةُ تقع حين تحضر الثانية. فلا
 * فرقَ في الخادم بين مباراةٍ حيّةٍ ومؤجَّلة — `mode` وصفٌ لما يُعرض في
 * التطبيق لا منطقٌ ثانٍ يُصان. وانقطاعُ الشبكة يُسقط العرضَ الحيّ ولا
 * يُسقط مباراة.
 */
const router = Router();

/** ستُّ دعواتٍ في الدقيقة: تكفي حصّةً ولا تكفي إغراقَ زميل. */
const inviteLimit = createRateLimit(6);
const scoreLimit = createRateLimit(20);

const MATCHES = "challenge_matches";

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

type Config = { url: string; key: string };

function config(): Config | null {
  const settings = apiSupabaseConfig();
  return settings ? { url: settings.url, key: settings.key } : null;
}

function headers(extra: Record<string, string> = {}): Record<string, string> {
  const settings = config();
  return {
    apikey: settings?.key ?? "",
    Authorization: `Bearer ${settings?.key ?? ""}`,
    "Content-Type": "application/json",
    ...extra,
  };
}

/** صفُّ المباراة كما يُقرأ من القاعدة. */
interface StoredMatch extends MatchRow {
  id: string;
  lessonId: string;
  game: string;
  classKey: string;
  mode: string;
  status: string;
  winnerId: string | null;
  createdAt: string;
  /** حزمةُ أسئلة المباراة كما كُتبت عند الدعوة. */
  questions: unknown;
}

function readMatch(raw: unknown): StoredMatch | null {
  const row = raw && typeof raw === "object" ? (raw as Record<string, unknown>) : null;
  const id = text(row?.id);
  if (!row || !id) return null;
  const score = (value: unknown): number | null =>
    typeof value === "number" && Number.isInteger(value) ? value : null;
  return {
    id,
    lessonId: text(row.lesson_id),
    game: text(row.game),
    hostId: text(row.host_id),
    guestId: text(row.guest_id),
    classKey: text(row.class_key),
    mode: text(row.mode),
    status: text(row.status),
    hostScore: score(row.host_score),
    guestScore: score(row.guest_score),
    winnerId: text(row.winner_id) || null,
    createdAt: text(row.created_at),
    questions: row.questions ?? null,
  };
}

/** ما يُرسَل إلى التطبيق. */
function toJson(match: StoredMatch, me: string): Record<string, unknown> {
  const side = sideOf(match, me);
  return {
    id: match.id,
    lessonId: match.lessonId,
    game: match.game,
    mode: match.mode,
    status: match.status,
    hostId: match.hostId,
    guestId: match.guestId,
    // «أنا» و«هو» بدل host/guest: الشاشةُ تعرض نتيجتي أمام نتيجته، ولا
    // يعنيها من أرسل الدعوة.
    mine: side === "host" ? match.hostScore : match.guestScore,
    theirs: side === "host" ? match.guestScore : match.hostScore,
    opponentId: side === "host" ? match.guestId : match.hostId,
    winnerId: match.winnerId,
    iWon: match.winnerId !== null && match.winnerId === me,
    rounds: DUEL_ROUNDS,
    createdAt: match.createdAt,
    // 25002500 06480627064406230633062606440629064f 06450639 06270644064506280627063106270629 06440627 0641064a 063706440628064d 062b06270646064d 25002500
    // 06270644062c06470627063206270646 064a06420631062306270646 06270644063506410651064e 0646064106330647060c 064106440627 062a062a0639064406510642 062706440639062f062706440629064f 06280627062a0651064106270642 062d063306270628064a0646.
    questions: packOf(match)?.questions ?? [],
    questionSeconds: DUEL_QUESTION_SECONDS,
    pointsCorrect: DUEL_POINTS_CORRECT,
    pointsSpeedMax: DUEL_POINTS_SPEED_MAX,
    maxScore: DUEL_MAX_SCORE,
  };
}

/**
 * حزمةُ أسئلة المباراة، أو `null` إن لم تُكتب أو لم تصلح.
 *
 * ولا تُبنى هنا عند الغياب: البناءُ يعطي حزمتين مختلفتين لو قرأ الجهازان في
 * لحظتين وقد تغيّر البنكُ بينهما. فمن قرأ صفّاً بلا حزمةٍ يُعاد توليدُها
 * وتُكتب — مرّةً واحدة — قبل أن تُرسل. انظر [ensurePack].
 */
function packOf(match: StoredMatch): DuelPack | null {
  return parseDuelPack(match.questions);
}

/**
 * أسئلةٌ من بنك الدرس، لتُخلط في الحزمة.
 *
 * ── وما لا يصلح سؤالاً من أربعةٍ يُترك ──
 * بنكُ الدرس جولاتُ سحبٍ: ملءُ فراغٍ وتصنيفٌ ومطابقة. والمليءُ وحده يصير
 * سؤالاً بخيارات — له جوابٌ ومشتّتات — والبقيّةُ تحتاج سحباً وترتيباً.
 */
async function lessonSeedsFor(lessonId: string): Promise<LessonSeed[]> {
  if (!lessonId) return [];
  try {
    const rows = await rest(
      `lesson_configs?select=id,data&id=eq.${encodeURIComponent(lessonId)}&limit=1`,
    );
    const row = Array.isArray(rows) ? rows[0] : null;
    const data = row && typeof row === "object"
      ? ((row as Record<string, unknown>).data as Record<string, unknown> | null)
      : null;
    const bank = readBank(data?.challengeBank);
    if (!bank) return [];
    const seeds: LessonSeed[] = [];
    for (const round of bank.rounds) {
      if (round.kind !== "fill") continue;
      const sentence = `${round.before} ______ ${round.after}`.trim();
      seeds.push({
        prompt: sentence,
        answer: round.answer,
        distractors: round.distractors,
      });
    }
    return seeds;
  } catch (error) {
    // بنكٌ لم يُقرأ لا يُسقط دعوةً: الحزمةُ تُبنى من البنك المكتوب وحده.
    logger.warn({ err: error, lessonId }, "[duel] lesson bank unread");
    return [];
  }
}

/**
 * يضمن أنّ للمباراة حزمةً، ويكتبها إن لم تكن.
 *
 * لصفوفٍ كُتبت قبل أن تُحفظ الحزمةُ مع المباراة: تُبنى بمعرّفها — والبناءُ
 * بالمعرّف نفسه يُخرج الشيءَ نفسه دائماً — وتُكتب، فيقرأ الجهازُ الثاني ما
 * كُتب لا ما بناه هو.
 */
async function ensurePack(match: StoredMatch): Promise<DuelPack> {
  const existing = packOf(match);
  if (existing) return existing;
  const pack = buildDuelPack(match.id, await lessonSeedsFor(match.lessonId));
  try {
    await rest(`${MATCHES}?id=eq.${encodeURIComponent(match.id)}`, {
      method: "PATCH",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({ questions: pack }),
    });
    match.questions = pack;
  } catch (error) {
    // الكتابةُ تعذّرت: تُرسل الحزمةُ كما بُنيت، وهي نفسُها على الجهازين لأنّ
    // البناءَ يتبع المعرّف. والكتابةُ تُجرَّب في القراءة التالية.
    logger.warn({ err: error, id: match.id }, "[duel] pack not stored");
  }
  return pack;
}

async function rest(
  path: string,
  init: RequestInit = {},
): Promise<unknown> {
  const settings = config();
  if (!settings) throw new Error("Supabase is not configured");
  const response = await fetch(`${settings.url}/rest/v1/${path}`, {
    ...init,
    headers: { ...headers(), ...(init.headers as Record<string, string>) },
  });
  if (!response.ok) {
    throw new Error(
      `duel ${path} failed (${response.status} ${(await response.text()).slice(0, 200)})`,
    );
  }
  const body = await response.text();
  return body ? JSON.parse(body) : null;
}

async function findMatch(id: string): Promise<StoredMatch | null> {
  const rows = await rest(
    `${MATCHES}?select=*&id=eq.${encodeURIComponent(id)}&limit=1`,
  );
  return Array.isArray(rows) && rows[0] ? readMatch(rows[0]) : null;
}

/**
 * هل هذا الزميلُ في صفّ هذا الطالب؟
 *
 * ── ولماذا يُسأل الجدولُ لا يُصدَّق الطلب ──
 * التطبيقُ يُرسل معرّفَ الزميل، ومعرّفٌ من خارج الصفّ يعني مباراةً مع من
 * لا يعرفه الطالب — وجوهرةً تُصرف في صفٍّ آخر. والقراءةُ بمفتاح الصفّ
 * تجعل الحدَّ محروساً في الخادم.
 */
async function isClassmateOf(
  student: StudentActor,
  guestId: string,
): Promise<boolean> {
  const rows = await rest(
    `students?select=id,data&id=eq.${encodeURIComponent(guestId)}&limit=1`,
  );
  const row = Array.isArray(rows) ? rows[0] : null;
  const data = row && typeof row === "object"
    ? ((row as Record<string, unknown>).data as Record<string, unknown> | null)
    : null;
  if (!data) return false;
  return (
    text(data.teacherId ?? data.teacher_id) === student.teacherId &&
    text(data.grade) === student.grade
  );
}

/**
 * دعوةُ زميلٍ إلى مباراة.
 *
 * تُنشأ المباراةُ معلّقةً بلا نتيجة، ثم يُسجّل كلٌّ نتيجتَه. والمتحدّي قد
 * يلعب قبل أن يقبل الزميلُ — وهي المباراةُ المؤجَّلة.
 */
router.post("/duel/invite", inviteLimit, requireStudentSession, async (req, res) => {
  const student = res.locals.student as StudentActor;
  const lessonId = text(req.body?.lessonId);
  const guestId = text(req.body?.guestId);
  const game = text(req.body?.game);
  const live = req.body?.live === true;

  if (!lessonId || !guestId || !isDuelGame(game)) {
    return res.status(400).json({
      error: "بيانات الدعوة ناقصة",
      code: "bad_request",
    });
  }
  if (guestId === student.id) {
    // مباراةٌ مع النفس يفوز فيها دائماً، فتكون باباً إلى جوهرةٍ بكل ضغطة.
    return res.status(400).json({
      error: "لا يمكنك تحدّي نفسك",
      code: "self_duel",
    });
  }
  const key = classKey(student.teacherId, student.grade);
  if (!key) {
    return res.status(403).json({
      error: "حسابك ليس في صفٍّ بعد",
      code: "no_class",
    });
  }
  try {
    if (!(await isClassmateOf(student, guestId))) {
      return res.status(403).json({
        error: "هذا الزميل ليس في صفّك",
        code: "not_classmate",
      });
    }
    const id = newMatchId();
    // ── والحزمةُ تُبنى وتُكتب مع الصفّ ──
    // لا تُولَّد بنموذجٍ: التوليدُ يُجلس الطفلَ أمام انتظارٍ قبل أن تُرسل
    // دعوتُه. وتُنتقى من بنكٍ مكتوبٍ ومن بنك الدرس، فتُكتب في المللي نفسه.
    const pack = buildDuelPack(id, await lessonSeedsFor(lessonId));
    await rest(MATCHES, {
      method: "POST",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({
        id,
        lesson_id: lessonId,
        game,
        host_id: student.id,
        guest_id: guestId,
        class_key: key,
        mode: live ? "live" : "ghost",
        status: "pending",
        questions: pack,
      }),
    });
    logger.info({ id, game, live }, "[duel] invited");
    const created = await findMatch(id);
    return res.status(201).json({
      match: created ? toJson(created, student.id) : { id },
    });
  } catch (error) {
    logger.error({ err: error }, "[duel] invite failed");
    return res.status(503).json({
      error: "تعذّر إرسال التحدي الآن",
      code: "unavailable",
    });
  }
});

/**
 * تسجيلُ نتيجةِ اللاعب، وحسمُ المباراة إن حضرت النتيجتان.
 *
 * ── والجوهرةُ تُصرف هنا لا في التطبيق ──
 * حين تحضر الثانيةُ يُعرف الفائزُ فتُصرف له جوهرة. وقد يكون الفائزُ
 * الزميلَ لا صاحبَ الطلب: من أرسل النتيجةَ الثانية قد يكون الخاسر.
 */
router.post("/duel/:id/score", scoreLimit, requireStudentSession, async (req, res) => {
  const student = res.locals.student as StudentActor;
  const id = text(req.params.id);
  const score = parseScore(req.body?.score);
  if (!id || score === null) {
    return res.status(400).json({
      error: `النتيجة يجب أن تكون بين صفر و${DUEL_ROUNDS}`,
      code: "bad_score",
    });
  }
  try {
    const match = await findMatch(id);
    if (!match) {
      return res.status(404).json({ error: "المباراة غير موجودة", code: "not_found" });
    }
    const side = sideOf(match, student.id);
    if (side === null) {
      return res.status(403).json({ error: "لست طرفاً في هذه المباراة", code: "not_a_player" });
    }
    if (!canSubmit(match, student.id)) {
      // ولا تُبدَّل نتيجةٌ كُتبت: الردُّ يحمل المباراةَ كما هي، فتعرض
      // الشاشةُ الحقيقةَ بدل أن تُظهر خطأً على طلبٍ مكرّر.
      return res.status(200).json({
        match: toJson(match, student.id),
        alreadySubmitted: true,
      });
    }

    const patched: MatchRow = {
      hostId: match.hostId,
      guestId: match.guestId,
      hostScore: side === "host" ? score : match.hostScore,
      guestScore: side === "guest" ? score : match.guestScore,
    };
    const outcome = outcomeOf(patched);
    const body: Record<string, unknown> = {
      [side === "host" ? "host_score" : "guest_score"]: score,
      updated_at: new Date().toISOString(),
    };
    if (outcome.settled) {
      body.status = "done";
      body.winner_id = outcome.winnerId;
    }
    await rest(`${MATCHES}?id=eq.${encodeURIComponent(id)}`, {
      method: "PATCH",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify(body),
    });

    let gems = 0;
    if (outcome.settled && outcome.winnerId) {
      // والصرفُ لا يُسقط الردّ: فشلُه يعني جوهرةً لم تُصرف، والمباراةُ
      // محسومةٌ في الجدول على كل حال — ويُقرأ الفوزُ منه لا من الرصيد.
      const paid = await awardDuelWin(outcome.winnerId, id).catch((error) => {
        logger.error({ err: error, id }, "[duel] win gem not paid");
        return false;
      });
      if (paid && outcome.winnerId === student.id) gems = DUEL_WIN_GEMS;
    }
    const fresh = await findMatch(id);
    logger.info(
      { id, settled: outcome.settled, winner: outcome.settled ? outcome.winnerId : null },
      "[duel] score recorded",
    );
    return res.json({
      match: fresh ? toJson(fresh, student.id) : null,
      gems,
      draw: outcome.settled && outcome.draw,
    });
  } catch (error) {
    logger.error({ err: error, id }, "[duel] score failed");
    return res.status(503).json({ error: "تعذّر حفظ النتيجة الآن", code: "unavailable" });
  }
});

/**
 * مبارياتي: ما ينتظرني، وما أنتظر فيه زميلي، وما انتهى حديثاً.
 *
 * والمنتهيةُ تُرسل أيضاً: الطالبُ الذي لعب جولتَه أمس يحتاج أن يرى نتيجتَها
 * حين يفتح التطبيق — وإلا بقيت المباراةُ في ذهنه معلّقةً وقد حُسمت.
 */
router.get("/duel/inbox", requireStudentSession, async (_req, res) => {
  const student = res.locals.student as StudentActor;
  try {
    const id = encodeURIComponent(student.id);
    const rows = await rest(
      `${MATCHES}?select=*&or=(host_id.eq.${id},guest_id.eq.${id})` +
        `&status=neq.expired&order=created_at.desc&limit=40`,
    );
    const matches = (Array.isArray(rows) ? rows : [])
      .map(readMatch)
      .filter((match): match is StoredMatch => match !== null)
      .map((match) => toJson(match, student.id));
    return res.json({ matches });
  } catch (error) {
    logger.error({ err: error }, "[duel] inbox failed");
    return res.status(503).json({ error: "تعذّر قراءة تحدّياتك الآن" });
  }
});

/**
 * صدارةُ الصفّ بعدد الانتصارات.
 *
 * تُحسب من المباريات لا من عدّادٍ محفوظ: عدّادٌ يُزاد عند كل فوز يفترق عن
 * السجلّ عند أوّل طلبٍ يُعاد.
 */
router.get("/duel/standings", requireStudentSession, async (_req, res) => {
  const student = res.locals.student as StudentActor;
  const key = classKey(student.teacherId, student.grade);
  if (!key) return res.json({ standings: [] });
  try {
    const rows = await rest(
      `${MATCHES}?select=host_id,guest_id,host_score,guest_score` +
        `&class_key=eq.${encodeURIComponent(key)}&status=eq.done&limit=1000`,
    );
    const matches = (Array.isArray(rows) ? rows : [])
      .map(readMatch)
      .filter((match): match is StoredMatch => match !== null);
    const table = standingsOf(matches);

    // والأسماءُ من جدول الطلاب: الصدارةُ تُقرأ بأسماءٍ لا بمعرّفات.
    const names = new Map<string, { name: string; appearance: unknown }>();
    if (table.length > 0) {
      const ids = table.map((item) => `"${item.studentId}"`).join(",");
      const people = await rest(`students?select=id,data&id=in.(${encodeURIComponent(ids)})`);
      for (const person of Array.isArray(people) ? people : []) {
        const row = person as Record<string, unknown>;
        const data = (row.data ?? {}) as Record<string, unknown>;
        names.set(text(row.id), {
          name: text(data.name) || text(data.username),
          appearance: data.appearance ?? null,
        });
      }
    }
    return res.json({
      standings: table.map((item, index) => ({
        ...item,
        rank: index + 1,
        isMe: item.studentId === student.id,
        name: names.get(item.studentId)?.name ?? "",
        appearance: names.get(item.studentId)?.appearance ?? null,
      })),
    });
  } catch (error) {
    logger.error({ err: error }, "[duel] standings failed");
    return res.status(503).json({ error: "تعذّر قراءة الصدارة الآن" });
  }
});

/**
 * مباراةٌ بعينها، بأسئلتها.
 *
 * ── ولماذا مسارٌ لها وحدها ──
 * الحزمةُ تُقرأ من الصفّ، وصندوقُ المباريات يُرسل أربعين صفّاً — فحملُ
 * أسئلةِ أربعين مباراةً في كل فتحةٍ للردهة هدرٌ لا يُقرأ منه شيء. فالردهةُ
 * تأخذ الأسماءَ والنتائج، وفتحُ المباراة يأخذ أسئلتَها.
 */
router.get("/duel/:id", requireStudentSession, async (req, res) => {
  const student = res.locals.student as StudentActor;
  const id = text(req.params.id);
  if (!id) return res.status(400).json({ error: "معرّف المباراة ناقص" });
  try {
    const match = await findMatch(id);
    if (!match) return res.status(404).json({ error: "المباراة غير موجودة" });
    // ولا يقرأ المباراةَ إلا طرفاها: أسئلتُها فيها، وثالثٌ يقرؤها يعرف
    // أجوبةَ مباراةٍ قد يُدعى إليها.
    if (sideOf(match, student.id) === null) {
      return res.status(403).json({ error: "لست طرفاً في هذه المباراة" });
    }
    await ensurePack(match);
    return res.json({ match: toJson(match, student.id) });
  } catch (error) {
    logger.error({ err: error, id }, "[duel] match read failed");
    return res.status(503).json({ error: "تعذّر قراءة المباراة الآن" });
  }
});

// ── سجلُّ المحادثة ──

const MESSAGES = "match_messages";

/** ستّون رسالةً في الدقيقة: تكفي حديثاً حيّاً ولا تكفي إغراقاً. */
const chatLimit = createRateLimit(60);

/** أقصى حجمٍ للمقطع الصوتي بعد الترميز. مُطابقٌ لما يحرسه التطبيق. */
const VOICE_MAX_CHARS = 180 * 1024;
const TEXT_MAX_CHARS = 80;

/** آخرُ ما يُحفظ من رسائل المباراة. */
const MESSAGES_KEPT = 40;

function messageJson(raw: unknown): Record<string, unknown> | null {
  if (!raw || typeof raw !== "object") return null;
  const row = raw as Record<string, unknown>;
  const id = text(row.id);
  const sender = text(row.sender_id);
  if (!id || !sender) return null;
  const kind = text(row.kind) === "voice" ? "voice" : "text";
  return {
    id,
    senderId: sender,
    kind,
    text: kind === "text" ? text(row.body) : "",
    audio: kind === "voice" ? text(row.body) : "",
    createdAt: text(row.created_at),
  };
}

/**
 * سجلُّ المحادثة في مباراة.
 *
 * ── ولماذا يُحفظ أصلاً ──
 * البثُّ الحيُّ يصل لمن كان على القناة في تلك اللحظة. والمبارزةُ المؤجَّلةُ
 * يلعب فيها كلٌّ في وقته، فرسالةُ من لعب أوّلاً كانت تضيع قبل أن يفتح زميلُه
 * المباراة — وهو الوقتُ الوحيد الذي يقرأ فيه.
 */
router.get("/duel/:id/messages", requireStudentSession, async (req, res) => {
  const student = res.locals.student as StudentActor;
  const id = text(req.params.id);
  if (!id) return res.status(400).json({ error: "معرّف المباراة ناقص" });
  try {
    const match = await findMatch(id);
    if (!match) return res.status(404).json({ error: "المباراة غير موجودة" });
    if (sideOf(match, student.id) === null) {
      return res.status(403).json({ error: "لست طرفاً في هذه المباراة" });
    }
    const rows = await rest(
      `${MESSAGES}?select=*&match_id=eq.${encodeURIComponent(id)}` +
        `&order=created_at.asc&limit=${MESSAGES_KEPT}`,
    );
    const messages = (Array.isArray(rows) ? rows : [])
      .map(messageJson)
      .filter((row): row is Record<string, unknown> => row !== null);
    return res.json({ messages });
  } catch (error) {
    logger.error({ err: error, id }, "[duel] messages read failed");
    return res.status(503).json({ error: "تعذّر قراءة المحادثة الآن" });
  }
});

router.post("/duel/:id/messages", chatLimit, requireStudentSession, async (req, res) => {
  const student = res.locals.student as StudentActor;
  const id = text(req.params.id);
  const kind = text(req.body?.kind) === "voice" ? "voice" : "text";
  const body = typeof req.body?.body === "string" ? req.body.body : "";

  if (!id || !body) {
    return res.status(400).json({ error: "الرسالة ناقصة", code: "bad_request" });
  }
  // ── والحجمُ يُفحص في الخادم أيضاً ──
  // التطبيقُ يحرسه، وجهازٌ معدَّلٌ لا يحرسه. ومقطعٌ بميغابايتٍ يُكتب في صفٍّ
  // يُقرأ في كل فتحةٍ للمباراة.
  const cap = kind === "voice" ? VOICE_MAX_CHARS : TEXT_MAX_CHARS;
  if (body.length > cap) {
    return res.status(413).json({ error: "الرسالة كبيرة", code: "too_large" });
  }

  try {
    const match = await findMatch(id);
    if (!match) return res.status(404).json({ error: "المباراة غير موجودة" });
    if (sideOf(match, student.id) === null) {
      return res.status(403).json({ error: "لست طرفاً في هذه المباراة" });
    }
    await rest(MESSAGES, {
      method: "POST",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({
        match_id: id,
        sender_id: student.id,
        kind,
        body,
      }),
    });
    return res.status(201).json({ ok: true });
  } catch (error) {
    logger.error({ err: error, id }, "[duel] message not stored");
    return res.status(503).json({ error: "تعذّر إرسال الرسالة الآن" });
  }
});

export default router;
