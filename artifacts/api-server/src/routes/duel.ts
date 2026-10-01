import { Router, type Request, type Response } from "express";
import { apiSupabaseConfig, type StudentActor } from "../lib/studentAccess";
import { requireStudentSession } from "../middleware/studentAuth";
import { createStudentRateLimit } from "../middleware/rateLimiter";
import { logger } from "../lib/logger";
import {
  DUEL_MAX_SCORE,
  DUEL_POINTS_PER_QUESTION,
  DUEL_QUESTION_SECONDS,
  DUEL_ROUNDS,
  DUEL_WIN_GEMS,
  classKey,
  duelRewardActivity,
  isDuelGame,
  matchId as newMatchId,
  outcomeOf,
  roomStateOf,
  scoresFromAnswers,
  sideOf,
  type RoomState,
  standingsOf,
  type MatchRow,
} from "../lib/duel";
import { awardDuelWin } from "./studentProgress";
import { parseDuelPack, type DuelPack } from "../lib/duelQuestions";

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
const inviteLimit = createStudentRateLimit(6);
const scoreLimit = createStudentRateLimit(20);
/** عشرةُ أسئلةٍ في دقيقتين، ومحاولةٌ لكلٍّ: ستّون تكفي ولا تُغرق. */
const answerLimit = createStudentRateLimit(60);

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
  /**
   * هل صُرفت جوائزُ الفوز؟ `null` قبل الحسم أو لتعادل، و`false` لفائزٍ كانت
   * جائزةُ هذا الدرس قد صُرفت له من قبل.
   */
  rewardPaid: boolean | null;
  /** المصافحة: متى قبل الزميل، ومتى دخل كلٌّ الغرفة. انظر `roomStateOf`. */
  acceptedAt: string | null;
  hostJoinedAt: string | null;
  guestJoinedAt: string | null;
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
    rewardPaid: typeof row.reward_paid === "boolean" ? row.reward_paid : null,
    acceptedAt: text(row.accepted_at) || null,
    hostJoinedAt: text(row.host_joined_at) || null,
    guestJoinedAt: text(row.guest_joined_at) || null,
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
    // الأسئلةُ مع المباراة لا في ردّ الصندوق: أسئلةُ أربعين مباراةً تُثقل كل فتحةٍ
    // للردهة بما لا يُقرأ منه شيء.
    questions: packOf(match)?.questions ?? [],
    questionSeconds: DUEL_QUESTION_SECONDS,
    // نقاطُ السؤال لأوّل من يُجيب صحيحاً، ولا نقاطَ سرعةٍ فوقها: السرعةُ هي
    // من يكسب السؤال.
    pointsCorrect: DUEL_POINTS_PER_QUESTION,
    pointsSpeedMax: 0,
    maxScore: DUEL_MAX_SCORE,
    winGems: DUEL_WIN_GEMS,
    rewardPaid: match.rewardPaid,
    room: roomJson(match),
  };
}

/**
 * حزمةُ أسئلة المباراة، أو `null` إن لم تُكتب أو لم تصلح.
 *
 * ولا تُبنى هنا: الحزمةُ تُختار في القاعدة بـ`claim_duel_pack` من بنك
 * `duel_questions` — ستّةٌ من مجال الدرس وأربعةٌ ذكاءٌ وسرعة — وتُكتب مرّةً
 * تحت قفل الصفّ، فيقرأ الجهازان الحزمةَ نفسها. انظر
 * `scripts/duel-question-bank.sql`. وحزمةٌ يكتبها الخادمُ هنا قبلها كانت
 * تُثبَّت بأسئلة الدرس الحرفية، وتمنع الدالّةَ من بناء حزمة المجال.
 */
function packOf(match: StoredMatch): DuelPack | null {
  return parseDuelPack(match.questions);
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
router.post("/duel/invite", requireStudentSession, inviteLimit, async (req, res) => {
  const student = res.locals.student as StudentActor;
  const lessonId = text(req.body?.lessonId);
  const guestId = text(req.body?.guestId);
  const game = text(req.body?.game);

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
    // والحزمةُ لا تُكتب هنا: يثبّتها أوّلُ من يفتح المباراة بـ`claim_duel_pack`.
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
        // حيّةٌ دائماً: التحدّي لا يُرسل إلا لزميلٍ متصلٍ الآن، فيلعبان معاً.
        mode: "live",
        status: "pending",
      }),
    });
    logger.info({ id, game }, "[duel] invited");
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

const ANSWERS = "match_answers";

/** حالُ غرفة المباراة الآن. انظر `roomStateOf`. */
function roomOf(match: StoredMatch, now: Date = new Date()): RoomState {
  return roomStateOf(
    {
      status: match.status,
      createdAt: match.createdAt,
      acceptedAt: match.acceptedAt,
      hostJoinedAt: match.hostJoinedAt,
      guestJoinedAt: match.guestJoinedAt,
    },
    now,
  );
}

/** الغرفةُ كما تُرسل: والوقتُ الآن في الخادم، ليحسب الجهازُ فرقَ ساعته عنه. */
function roomJson(match: StoredMatch) {
  const now = new Date();
  const room = roomOf(match, now);
  return {
    phase: room.phase,
    hostJoined: room.hostJoined,
    guestJoined: room.guestJoined,
    startAt: room.startAt?.toISOString() ?? null,
    serverNow: now.toISOString(),
  };
}

/**
 * ردُّ الزميل على الدعوة. الجسم: `{ accept: true | false }`.
 *
 * ── والقَبولُ يُكتب هنا قبل أن يدخل أحد ──
 * كان الضيفُ يدخل لحظةَ يضغط «اقبل»، والداعي يعرف ذلك من إشارةٍ قد لا تصله. والآن
 * لا يدخل الضيفُ إلا إن كتب الخادمُ قَبولَه، والداعي يقرأ القَبولَ نفسه من هنا.
 *
 * والكتابةُ مشروطةٌ بأن تكون الدعوةُ ما زالت قائمة: قَبولٌ وإلغاءٌ يصلان معاً
 * يُكتب أحدُهما فقط، فيرى الطرفان النتيجةَ نفسها.
 */
router.post("/duel/:id/respond", requireStudentSession, scoreLimit, async (req, res) => {
  const student = res.locals.student as StudentActor;
  const id = text(req.params.id);
  const accept = req.body?.accept;
  if (!id || typeof accept !== "boolean") {
    return res.status(400).json({ error: "ردٌّ ناقص", code: "bad_request" });
  }
  try {
    const match = await findMatch(id);
    if (!match) return res.status(404).json({ error: "المباراة غير موجودة", code: "not_found" });
    if (sideOf(match, student.id) !== "guest") {
      return res.status(403).json({ error: "الردُّ للمدعوّ وحده", code: "not_guest" });
    }
    const room = roomOf(match);
    if (room.phase !== "invited") {
      // قُبلت من قبل، أو انتهت: يُعاد حالُها كما هو، فيعرف الجهازُ أين هو.
      return res.json({ match: toJson(match, student.id), room: roomJson(match) });
    }
    const filter = `${MATCHES}?id=eq.${encodeURIComponent(id)}&status=eq.pending&accepted_at=is.null`;
    await rest(filter, {
      method: "PATCH",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify(
        accept
          ? { accepted_at: new Date().toISOString(), updated_at: new Date().toISOString() }
          : { status: "expired", updated_at: new Date().toISOString() },
      ),
    });
    const fresh = (await findMatch(id))!;
    logger.info({ id, accept, phase: roomOf(fresh).phase }, "[duel] invite answered");
    return res.json({ match: toJson(fresh, student.id), room: roomJson(fresh) });
  } catch (error) {
    logger.error({ err: error, id }, "[duel] respond failed");
    return res.status(503).json({ error: "تعذّر إرسال الردّ الآن", code: "unavailable" });
  }
});

/**
 * دخولُ الغرفة. يُكتب وقتُ دخولي، ويُعاد حالُ الغرفة.
 *
 * ولا يبدأ النزالُ إلا حين يدخل الاثنان: الموعدُ يُحسب من دخول الثاني، فلا عدّادَ
 * ولا سؤالَ عند أحدهما والآخرُ غائب.
 */
router.post("/duel/:id/join", requireStudentSession, scoreLimit, async (req, res) => {
  const student = res.locals.student as StudentActor;
  const id = text(req.params.id);
  if (!id) return res.status(400).json({ error: "معرّف المباراة ناقص", code: "bad_request" });
  try {
    const match = await findMatch(id);
    if (!match) return res.status(404).json({ error: "المباراة غير موجودة", code: "not_found" });
    const side = sideOf(match, student.id);
    if (side === null) {
      return res.status(403).json({ error: "لست طرفاً في هذه المباراة", code: "not_a_player" });
    }
    const room = roomOf(match);
    const column = side === "host" ? "host_joined_at" : "guest_joined_at";
    const already = side === "host" ? match.hostJoinedAt : match.guestJoinedAt;
    if (room.phase === "accepted" && !already) {
      await rest(
        `${MATCHES}?id=eq.${encodeURIComponent(id)}&status=eq.pending&${column}=is.null`,
        {
          method: "PATCH",
          headers: { Prefer: "return=minimal" },
          body: JSON.stringify({ [column]: new Date().toISOString() }),
        },
      );
    }
    const fresh = (await findMatch(id))!;
    return res.json({ match: toJson(fresh, student.id), room: roomJson(fresh) });
  } catch (error) {
    logger.error({ err: error, id }, "[duel] join failed");
    return res.status(503).json({ error: "تعذّر دخول الغرفة الآن", code: "unavailable" });
  }
});


/**
 * جوابُ سؤالٍ في المباراة. الجسم: `{ index, choice }`.
 *
 * ── والأوّلُ يُحسم في القاعدة ──
 * الصحةُ تُقرأ من حزمة المباراة المحفوظة، لا من ادّعاء التطبيق. ثم
 * `record_duel_answer` تسجّل الجوابَ تحت قفلٍ لكل سؤال، فتقول هل كان أوّلَ صحيح —
 * وجهازان يُرسلان في اللحظة نفسها يُفصل بينهما هناك، في مكانٍ واحد.
 *
 * ولكل لاعبٍ محاولةٌ واحدةٌ لكل سؤال: الثانيةُ تُعاد بنتيجة الأولى.
 */
router.post("/duel/:id/answer", requireStudentSession, answerLimit, async (req, res) => {
  const student = res.locals.student as StudentActor;
  const id = text(req.params.id);
  const index = req.body?.index;
  const choice = req.body?.choice;
  if (!id || !Number.isInteger(index) || index < 0 || !Number.isInteger(choice)) {
    return res.status(400).json({ error: "جوابٌ ناقص", code: "bad_answer" });
  }
  try {
    const match = await findMatch(id);
    if (!match) return res.status(404).json({ error: "المباراة غير موجودة", code: "not_found" });
    if (sideOf(match, student.id) === null) {
      return res.status(403).json({ error: "لست طرفاً في هذه المباراة", code: "not_a_player" });
    }
    if (match.status !== "pending") {
      return res.status(409).json({ error: "انتهت المباراة", code: "settled" });
    }
    // ── ولا جوابَ قبل أن يبدأ النزالُ للاثنين ──
    // جهازٌ يعرض السؤالَ قبل موعده، أو والزميلُ لم يدخل، يكسب أسئلةً لم تُطرح
    // على زميله. وثانيةٌ من السماحة لفرق ساعتين.
    const room = roomOf(match);
    if (room.phase !== "ready" || Date.now() < room.startAt!.getTime() - 1000) {
      return res.status(409).json({ error: "لم يبدأ النزالُ بعد", code: "not_started" });
    }
    const question = packOf(match)?.questions[index];
    if (!question) {
      return res.status(400).json({ error: "لا سؤالَ بهذا الرقم", code: "bad_index" });
    }
    const correct = choice === question.answerAt;
    const recorded = await rest("rpc/record_duel_answer", {
      method: "POST",
      body: JSON.stringify({
        p_match_id: id,
        p_question_index: index,
        p_student_id: student.id,
        p_correct: correct,
      }),
    }) as Record<string, unknown> | null;
    return res.json({
      index,
      correct: recorded?.correct === true,
      won: recorded?.won === true,
      duplicate: recorded?.duplicate === true,
      answerAt: question.answerAt,
      points: recorded?.won === true ? DUEL_POINTS_PER_QUESTION : 0,
    });
  } catch (error) {
    logger.error({ err: error, id }, "[duel] answer failed");
    return res.status(503).json({ error: "تعذّر تسجيل الجواب الآن", code: "unavailable" });
  }
});

/** نتيجةُ المباراة كما يراها [me] بعد حسمها. */
function settledJson(match: StoredMatch, me: string) {
  const iWon = match.winnerId !== null && match.winnerId === me;
  return {
    match: toJson(match, me),
    gems: iWon && match.rewardPaid === true ? DUEL_WIN_GEMS : 0,
    // فاز، ومكافأةُ هذا الدرس صُرفت له من قبل: يقال له ذلك، لا «صفر» بلا سبب.
    rewardTaken: iWon && match.rewardPaid === false,
    draw: match.status === "done" && match.winnerId === null,
  };
}

/**
 * حسمُ المباراة من إجاباتها المسجّلة.
 *
 * ── ومرّةً واحدة ──
 * الجهازان يطلبان الحسمَ عند آخر سؤال، وغالباً في اللحظة نفسها. فالكتابةُ مشروطةٌ
 * بأن تكون المباراةُ معلّقة: من وجدها كذلك حسمها وصرف الجائزة، والآخرُ يقرأ ما
 * حُسم. وما يُكتب في `reward_paid` يقوله للاثنين: صُرفت الجواهر، أو كانت جائزةُ
 * الدرس قد صُرفت من قبل.
 */
async function settle(id: string, me: string): Promise<ReturnType<typeof settledJson> | null> {
  let match = await findMatch(id);
  if (!match) return null;
  if (match.status === "pending") {
    const answers = await rest(
      `${ANSWERS}?select=student_id,question_index,won&match_id=eq.${encodeURIComponent(id)}&won=is.true`,
    );
    const { hostScore, guestScore } = scoresFromAnswers(
      (Array.isArray(answers) ? answers : []).map((row) => {
        const r = row as Record<string, unknown>;
        return {
          studentId: text(r.student_id),
          questionIndex: Number(r.question_index),
          won: r.won === true,
        };
      }),
      match.hostId,
      match.guestId,
    );
    const outcome = outcomeOf({
      hostId: match.hostId,
      guestId: match.guestId,
      hostScore,
      guestScore,
    });
    const written = await rest(
      `${MATCHES}?id=eq.${encodeURIComponent(id)}&status=eq.pending`,
      {
        method: "PATCH",
        headers: { Prefer: "return=representation" },
        body: JSON.stringify({
          host_score: hostScore,
          guest_score: guestScore,
          status: "done",
          winner_id: outcome.settled ? outcome.winnerId : null,
          updated_at: new Date().toISOString(),
        }),
      },
    );
    const settledHere = Array.isArray(written) && written.length > 0;
    if (settledHere && outcome.settled && outcome.winnerId) {
      // والصرفُ لا يُسقط الحسم: فشلُه يعني جوائزَ لم تُصرف، والفوزُ مكتوبٌ على
      // كل حال — ويُقرأ من الجدول لا من الرصيد.
      // مرّةً لكل لعبةٍ في كل درس: انظر `duelRewardActivity`.
      const reward = duelRewardActivity(match.lessonId, match.game);
      const paid = await awardDuelWin(outcome.winnerId, reward).catch((error) => {
        logger.error({ err: error, id }, "[duel] win gems not paid");
        return false;
      });
      await rest(`${MATCHES}?id=eq.${encodeURIComponent(id)}`, {
        method: "PATCH",
        headers: { Prefer: "return=minimal" },
        body: JSON.stringify({ reward_paid: paid }),
      });
    }
    logger.info({ id, hostScore, guestScore, settledHere }, "[duel] settled");
  }
  // ومن لم يحسمها قد يقرأ قبل أن تُكتب الجائزة: لحظاتٌ قليلةٌ ينتظرها.
  for (let attempt = 0; attempt < 5; attempt += 1) {
    match = await findMatch(id);
    if (!match) return null;
    if (match.winnerId === null || match.rewardPaid !== null) break;
    await new Promise((resolve) => setTimeout(resolve, 300));
  }
  return settledJson(match!, me);
}

async function finishRoute(req: Request, res: Response) {
  const student = res.locals.student as StudentActor;
  const id = text(req.params.id);
  if (!id) return res.status(400).json({ error: "معرّف المباراة ناقص", code: "bad_request" });
  try {
    const match = await findMatch(id);
    if (!match) return res.status(404).json({ error: "المباراة غير موجودة", code: "not_found" });
    if (sideOf(match, student.id) === null) {
      return res.status(403).json({ error: "لست طرفاً في هذه المباراة", code: "not_a_player" });
    }
    if (match.status === "expired") {
      return res.status(409).json({ error: "أُلغيت المباراة", code: "expired" });
    }
    const phase = roomOf(match).phase;
    if (phase !== "ready" && phase !== "done") {
      return res.status(409).json({ error: "لم يبدأ النزالُ بعد", code: "not_started" });
    }
    const result = await settle(id, student.id);
    if (!result) return res.status(404).json({ error: "المباراة غير موجودة", code: "not_found" });
    return res.json(result);
  } catch (error) {
    logger.error({ err: error, id }, "[duel] finish failed");
    return res.status(503).json({ error: "تعذّر حسم المباراة الآن", code: "unavailable" });
  }
}

/** حسمُ المباراة. انظر [settle]. */
router.post("/duel/:id/finish", requireStudentSession, scoreLimit, finishRoute);

/**
 * المسارُ القديم، لنسخٍ من التطبيق لم تُحدَّث بعد.
 *
 * يحسم كما يحسم `finish` ويُهمل النتيجةَ المرسلة: النتيجةُ لم تعد ادّعاءً من
 * التطبيق، وقبولُها هنا كان سيفتح باباً يُغلق في المسار الجديد.
 */
router.post("/duel/:id/score", requireStudentSession, scoreLimit, finishRoute);

/**
 * إلغاءُ مباراةٍ لم تبدأ: دعوةٌ رُفضت، أو انتهت مهلتُها، أو تراجع عنها صاحبُها.
 *
 * ولا تُلغى مباراةٌ سُجّل فيها جواب: من غادر في منتصفها لا يمحوها على زميله،
 * والزميلُ يُكملها ويحسمها.
 */
router.post("/duel/:id/cancel", requireStudentSession, scoreLimit, async (req, res) => {
  const student = res.locals.student as StudentActor;
  const id = text(req.params.id);
  if (!id) return res.status(400).json({ error: "معرّف المباراة ناقص", code: "bad_request" });
  try {
    const match = await findMatch(id);
    if (!match) return res.status(404).json({ error: "المباراة غير موجودة", code: "not_found" });
    if (sideOf(match, student.id) === null) {
      return res.status(403).json({ error: "لست طرفاً في هذه المباراة", code: "not_a_player" });
    }
    const room = roomOf(match);
    // دخلا معاً: بدأ النزال، ومن غادر لا يمحوه على زميله.
    if (room.phase === "ready" || room.phase === "done") {
      return res.json({ cancelled: false, status: room.phase, room: roomJson(match) });
    }
    if (room.phase === "expired" && match.status !== "pending") {
      return res.json({ cancelled: true, status: "expired", room: roomJson(match) });
    }
    const answered = await rest(
      `${ANSWERS}?select=match_id&match_id=eq.${encodeURIComponent(id)}&limit=1`,
    );
    if (Array.isArray(answered) && answered.length > 0) {
      return res.json({ cancelled: false, status: "playing", room: roomJson(match) });
    }
    // ── والإلغاءُ مشروطٌ بما رآه ──
    // قبل القَبول: لا يُكتب إن كُتب قَبولٌ بينهما. وبعده: لا يُكتب إن دخل الاثنان.
    // فقَبولٌ وإلغاءٌ يتسابقان يُكتب أحدُهما، ويقرأ الجهازان ما كُتب.
    const guard = room.phase === "invited"
      ? "accepted_at=is.null"
      : "or=(host_joined_at.is.null,guest_joined_at.is.null)";
    const written = await rest(
      `${MATCHES}?id=eq.${encodeURIComponent(id)}&status=eq.pending&${guard}`,
      {
        method: "PATCH",
        headers: { Prefer: "return=representation" },
        body: JSON.stringify({ status: "expired", updated_at: new Date().toISOString() }),
      },
    );
    const fresh = (await findMatch(id))!;
    const cancelled = Array.isArray(written) && written.length > 0;
    return res.json({
      cancelled,
      status: cancelled ? "expired" : roomOf(fresh).phase,
      room: roomJson(fresh),
    });
  } catch (error) {
    logger.error({ err: error, id }, "[duel] cancel failed");
    return res.status(503).json({ error: "تعذّر إلغاء المباراة الآن", code: "unavailable" });
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
    return res.json({ match: toJson(match, student.id) });
  } catch (error) {
    logger.error({ err: error, id }, "[duel] match read failed");
    return res.status(503).json({ error: "تعذّر قراءة المباراة الآن" });
  }
});

// ── سجلُّ المحادثة ──

const MESSAGES = "match_messages";

/** ستّون رسالةً في الدقيقة: تكفي حديثاً حيّاً ولا تكفي إغراقاً. */
const chatLimit = createStudentRateLimit(60);

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

router.post("/duel/:id/messages", requireStudentSession, chatLimit, async (req, res) => {
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
