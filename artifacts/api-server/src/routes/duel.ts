import { Router, type Request, type Response } from "express";
import { apiSupabaseConfig, type StudentActor } from "../lib/studentAccess";
import { requireStudentSession } from "../middleware/studentAuth";
import { createStudentRateLimit } from "../middleware/rateLimiter";
import { logger } from "../lib/logger";
import {
  DUEL_INVITE_SECONDS,
  DUEL_MAX_INVITEES,
  DUEL_MAX_SCORE,
  DUEL_POINTS_PER_QUESTION,
  DUEL_QUESTION_SECONDS,
  DUEL_ROUNDS,
  DUEL_WIN_GEMS,
  canRespond,
  classKey,
  duelRewardActivity,
  isDuelGame,
  legacyPlayers,
  matchId as newMatchId,
  partyRoomOf,
  partyScores,
  rankParty,
  type PartyStanding,
  type PlayerRow,
  type RoomState,
  standingsOf,
  type MatchRow,
} from "../lib/duel";
import { awardDuelWin } from "./studentProgress";
import { parseDuelPack, type DuelPack } from "../lib/duelQuestions";

/**
 * مبارياتُ التحدي بين زملاء الصفّ — لاعبان أو أكثر.
 *
 * ── والقرارُ كلُّه هنا لا في التطبيق ──
 * من يُدعى، ومن وافق في المهلة، ومتى يبدأ النزال، ومن كسب كلَّ سؤال، ومن فاز،
 * وأنّ الجواهرَ تُصرف مرّةً واحدة — كلُّه في الخادم. ولو تُرك شيءٌ منه للتطبيق
 * لكان رصيدُ الجواهر مسألةَ من يُعدّل الطلب.
 *
 * ── واللاعبون في جدولٍ لهم ──
 * `challenge_match_players`: الداعي ومن دعاهم، وردُّ كلٍّ ونتيجتُه. ومباراةٌ
 * قديمةٌ قبله تُقرأ بلاعبَين من `host_id`/`guest_id` — انظر `legacyPlayers`.
 */
const router = Router();

/** ستُّ دعواتٍ في الدقيقة: تكفي حصّةً ولا تكفي إغراقَ زميل. */
const inviteLimit = createStudentRateLimit(6);
const scoreLimit = createStudentRateLimit(30);
/** عشرةُ أسئلةٍ في دقيقتين، ومحاولةٌ لكلٍّ: ستّون تكفي ولا تُغرق. */
const answerLimit = createStudentRateLimit(60);

const MATCHES = "challenge_matches";
const PLAYERS = "challenge_match_players";

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

/** صفُّ المباراة كما يُقرأ من القاعدة، ومعه لاعبوها. */
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
   * جائزةُ هذه اللعبة في الدرس قد صُرفت له من قبل.
   */
  rewardPaid: boolean | null;
  acceptedAt: string | null;
  /** اللاعبون: الداعي ومن دعاهم. */
  players: PlayerRow[];
  /** نتائجُ اللاعبين بعد الحسم، من جدولهم. */
  results: Map<string, { score: number | null; rank: number | null }>;
  /** مباراةٌ بلا صفوفٍ في جدول اللاعبين: قبله، أو والجدولُ لم يُنشأ بعد. */
  legacy: boolean;
}

function readMatch(raw: unknown): StoredMatch | null {
  const row = raw && typeof raw === "object" ? (raw as Record<string, unknown>) : null;
  const id = text(row?.id);
  if (!row || !id) return null;
  const score = (value: unknown): number | null =>
    typeof value === "number" && Number.isInteger(value) ? value : null;
  const match: StoredMatch = {
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
    players: [],
    results: new Map(),
    legacy: true,
  };
  match.players = legacyPlayers(match);
  return match;
}

/** يقرأ لاعبي المباراة من جدولهم، وإن لم يكونوا فيه بقيت لاعبَيها القديمَين. */
function withPlayers(match: StoredMatch, rows: unknown): StoredMatch {
  const list = Array.isArray(rows) ? rows : [];
  const players: PlayerRow[] = [];
  const results = new Map<string, { score: number | null; rank: number | null }>();
  for (const raw of list) {
    const row = raw as Record<string, unknown>;
    const studentId = text(row.student_id);
    if (!studentId) continue;
    players.push({
      studentId,
      role: text(row.role) === "host" ? "host" : "guest",
      respondedAt: text(row.responded_at) || null,
      accepted: typeof row.accepted === "boolean" ? row.accepted : null,
    });
    results.set(studentId, {
      score: typeof row.score === "number" ? row.score : null,
      rank: typeof row.rank === "number" ? row.rank : null,
    });
  }
  if (players.length === 0) return match;
  return { ...match, players, results, legacy: false };
}

function isPlayer(match: StoredMatch, studentId: string): boolean {
  return match.players.some((player) => player.studentId === studentId);
}

function roomOf(match: StoredMatch, now: Date = new Date()): RoomState {
  return partyRoomOf(match, match.players, now);
}

/** الغرفةُ كما تُرسل: والوقتُ الآن في الخادم، ليحسب الجهازُ فرقَ ساعته عنه. */
function roomJson(match: StoredMatch) {
  const now = new Date();
  const room = roomOf(match, now);
  return {
    phase: room.phase,
    decideBy: room.decideBy.toISOString(),
    startAt: room.startAt?.toISOString() ?? null,
    roster: room.roster,
    players: match.players.map((player) => ({
      id: player.studentId,
      role: player.role,
      status: room.statuses[player.studentId] ?? "pending",
    })),
    inviteSeconds: DUEL_INVITE_SECONDS,
    serverNow: now.toISOString(),
    // لنسخٍ أقدم من التطبيق كانت تنتظر «دخل الاثنان».
    hostJoined: room.phase === "ready",
    guestJoined: room.phase === "ready",
  };
}

/** نتائجُ اللاعبين كما تُرسل: من جدولهم بعد الحسم. */
function scoresJson(match: StoredMatch) {
  return match.players.map((player) => {
    const result = match.results.get(player.studentId);
    let score = result?.score ?? null;
    // مباراةٌ قديمة: النتيجتان في صفّ المباراة.
    if (match.legacy) {
      score = player.studentId === match.hostId ? match.hostScore : match.guestScore;
    }
    return { id: player.studentId, role: player.role, score, rank: result?.rank ?? null };
  });
}

/** ما يُرسَل إلى التطبيق. */
function toJson(match: StoredMatch, me: string): Record<string, unknown> {
  const scores = scoresJson(match);
  const mine = scores.find((entry) => entry.id === me)?.score ?? null;
  const others = scores.filter((entry) => entry.id !== me);
  const theirs = others.reduce<number | null>(
    (best, entry) => (entry.score === null ? best : Math.max(best ?? 0, entry.score)),
    null,
  );
  return {
    id: match.id,
    lessonId: match.lessonId,
    game: match.game,
    mode: match.mode,
    status: match.status,
    hostId: match.hostId,
    guestId: match.guestId,
    // «أنا» و«أفضلُ منافس»: الشاشةُ تعرض نتيجتي أمام من يتقدّمني.
    mine,
    theirs,
    opponentId: others[0]?.id ?? "",
    players: scores,
    winnerId: match.winnerId,
    iWon: match.winnerId !== null && match.winnerId === me,
    rounds: DUEL_ROUNDS,
    createdAt: match.createdAt,
    questions: packOf(match)?.questions ?? [],
    questionSeconds: DUEL_QUESTION_SECONDS,
    pointsCorrect: DUEL_POINTS_PER_QUESTION,
    pointsSpeedMax: 0,
    maxScore: DUEL_MAX_SCORE,
    winGems: DUEL_WIN_GEMS,
    rewardPaid: match.rewardPaid,
    room: roomJson(match),
  };
}

/** حزمةُ أسئلة المباراة، أو `null` إن لم تُكتب أو لم تصلح. انظر `claim_duel_pack`. */
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

/**
 * لاعبو المباراة من جدولهم، أو `null` إن لم يُنشأ الجدولُ بعد.
 *
 * ولا يُسقط غيابُه المباريات: تُقرأ بلاعبَيها القديمَين حتى يُشغَّل
 * `scripts/duel-party.sql`.
 */
async function readPlayers(filter: string): Promise<unknown[] | null> {
  try {
    const rows = await rest(`${PLAYERS}?select=*&${filter}`);
    return Array.isArray(rows) ? rows : [];
  } catch (error) {
    logger.warn({ err: error }, "[duel] players table unavailable");
    return null;
  }
}

async function findMatch(id: string): Promise<StoredMatch | null> {
  const rows = await rest(
    `${MATCHES}?select=*&id=eq.${encodeURIComponent(id)}&limit=1`,
  );
  const match = Array.isArray(rows) && rows[0] ? readMatch(rows[0]) : null;
  if (!match) return null;
  const players = await readPlayers(`match_id=eq.${encodeURIComponent(id)}`);
  return players ? withPlayers(match, players) : match;
}

/**
 * من هؤلاء في صفّ هذا الطالب؟
 *
 * ── ولماذا يُسأل الجدولُ لا يُصدَّق الطلب ──
 * معرّفٌ من خارج الصفّ يعني مباراةً مع من لا يعرفه الطالب — وجوهرةً تُصرف في صفٍّ
 * آخر. والقراءةُ بمفتاح الصفّ تجعل الحدَّ محروساً في الخادم.
 */
async function classmatesAmong(
  student: StudentActor,
  ids: readonly string[],
): Promise<Set<string>> {
  const list = ids.map((id) => `"${id}"`).join(",");
  const rows = await rest(
    `students?select=id,data&id=in.(${encodeURIComponent(list)})`,
  );
  const found = new Set<string>();
  for (const raw of Array.isArray(rows) ? rows : []) {
    const row = raw as Record<string, unknown>;
    const data = (row.data ?? {}) as Record<string, unknown>;
    if (
      text(data.teacherId ?? data.teacher_id) === student.teacherId &&
      text(data.grade) === student.grade
    ) {
      found.add(text(row.id));
    }
  }
  return found;
}

/** المدعوّون من الطلب: `guestIds` قائمةً، أو `guestId` واحداً لنسخٍ أقدم. */
function inviteesOf(body: unknown): string[] {
  const raw = (body ?? {}) as Record<string, unknown>;
  const list = Array.isArray(raw.guestIds) ? raw.guestIds : [raw.guestId];
  const ids: string[] = [];
  for (const value of list) {
    const id = text(value);
    if (id && !ids.includes(id)) ids.push(id);
  }
  return ids;
}

/**
 * دعوةُ زميلٍ أو أكثر إلى مباراة. الجسم: `{ lessonId, game, guestIds: [...] }`.
 *
 * تُنشأ المباراةُ معلّقة، والداعي لاعبٌ وافق منذ البداية، والمدعوّون ينتظر كلٌّ
 * ردَّه. ثم يبدأ النزالُ حين يردّ الجميع أو تنتهي المهلة — انظر `partyRoomOf`.
 */
router.post("/duel/invite", requireStudentSession, inviteLimit, async (req, res) => {
  const student = res.locals.student as StudentActor;
  const lessonId = text(req.body?.lessonId);
  const game = text(req.body?.game);
  const guestIds = inviteesOf(req.body);

  if (!lessonId || guestIds.length === 0 || !isDuelGame(game)) {
    return res.status(400).json({ error: "بيانات الدعوة ناقصة", code: "bad_request" });
  }
  if (guestIds.includes(student.id)) {
    // مباراةٌ مع النفس يفوز فيها دائماً، فتكون باباً إلى جوهرةٍ بكل ضغطة.
    return res.status(400).json({ error: "لا يمكنك تحدّي نفسك", code: "self_duel" });
  }
  if (guestIds.length > DUEL_MAX_INVITEES) {
    return res.status(400).json({
      error: `يمكنك دعوة ${DUEL_MAX_INVITEES} زملاء على الأكثر`,
      code: "too_many",
    });
  }
  const key = classKey(student.teacherId, student.grade);
  if (!key) {
    return res.status(403).json({ error: "حسابك ليس في صفٍّ بعد", code: "no_class" });
  }
  try {
    const mates = await classmatesAmong(student, guestIds);
    if (guestIds.some((id) => !mates.has(id))) {
      return res.status(403).json({ error: "أحدُ الزملاء ليس في صفّك", code: "not_classmate" });
    }
    const id = newMatchId();
    const now = new Date().toISOString();
    await rest(MATCHES, {
      method: "POST",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({
        id,
        lesson_id: lessonId,
        game,
        host_id: student.id,
        // أوّلُ مدعوّ: للتوافق مع ما سبق جدولَ اللاعبين.
        guest_id: guestIds[0],
        class_key: key,
        mode: "live",
        status: "pending",
        created_at: now,
      }),
    });
    try {
      await rest(PLAYERS, {
        method: "POST",
        headers: { Prefer: "return=minimal" },
        body: JSON.stringify([
          {
            match_id: id,
            student_id: student.id,
            role: "host",
            invited_at: now,
            responded_at: now,
            accepted: true,
          },
          ...guestIds.map((guest) => ({
            match_id: id,
            student_id: guest,
            role: "guest",
            invited_at: now,
          })),
        ]),
      });
    } catch (error) {
      // الجدولُ لم يُنشأ: زميلٌ واحدٌ يُلعب بالطريقة القديمة، وأكثرُ لا يمكن.
      if (guestIds.length > 1) {
        await rest(`${MATCHES}?id=eq.${encodeURIComponent(id)}`, { method: "DELETE" }).catch(
          () => null,
        );
        logger.error({ err: error }, "[duel] party needs duel-party.sql");
        return res.status(503).json({
          error: "التحدي الجماعي يحتاج تحديث قاعدة البيانات",
          code: "party_unavailable",
        });
      }
    }
    logger.info({ id, game, invited: guestIds.length }, "[duel] invited");
    const created = await findMatch(id);
    return res.status(201).json({
      match: created ? toJson(created, student.id) : { id },
    });
  } catch (error) {
    logger.error({ err: error }, "[duel] invite failed");
    return res.status(503).json({ error: "تعذّر إرسال التحدي الآن", code: "unavailable" });
  }
});

const ANSWERS = "match_answers";

/**
 * ردُّ المدعوّ على الدعوة. الجسم: `{ accept: true | false }`.
 *
 * ── وفي المهلة وحدها ──
 * ردٌّ بعد العشرين ثانية لا يُكتب: بدأ النزالُ بمن وافق، أو أُلغي. ويُعاد حالُ الغرفة
 * كما هو، فيعرف الجهازُ أين هو.
 *
 * والقَبولُ دخولٌ للغرفة: من وافق ينتظر فيها مع الداعي حتى يُحسم من يلعب.
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
    const me = match.players.find((player) => player.studentId === student.id);
    if (!me || me.role !== "guest") {
      return res.status(403).json({ error: "الردُّ للمدعوّ وحده", code: "not_guest" });
    }
    const now = new Date();
    if (!canRespond(match, match.players, student.id, now) || match.status !== "pending") {
      return res.json({ match: toJson(match, student.id), room: roomJson(match) });
    }
    if (match.legacy) {
      await rest(
        `${MATCHES}?id=eq.${encodeURIComponent(id)}&status=eq.pending&accepted_at=is.null`,
        {
          method: "PATCH",
          headers: { Prefer: "return=minimal" },
          body: JSON.stringify(
            accept
              ? { accepted_at: now.toISOString(), updated_at: now.toISOString() }
              : { status: "expired", updated_at: now.toISOString() },
          ),
        },
      );
    } else {
      await rest(
        `${PLAYERS}?match_id=eq.${encodeURIComponent(id)}` +
          `&student_id=eq.${encodeURIComponent(student.id)}&responded_at=is.null`,
        {
          method: "PATCH",
          headers: { Prefer: "return=minimal" },
          body: JSON.stringify({ responded_at: now.toISOString(), accepted: accept }),
        },
      );
    }
    const fresh = (await findMatch(id))!;
    logger.info({ id, accept, phase: roomOf(fresh).phase }, "[duel] invite answered");
    return res.json({ match: toJson(fresh, student.id), room: roomJson(fresh) });
  } catch (error) {
    logger.error({ err: error, id }, "[duel] respond failed");
    return res.status(503).json({ error: "تعذّر إرسال الردّ الآن", code: "unavailable" });
  }
});

/**
 * دخولُ الغرفة — لنسخٍ أقدم من التطبيق. القَبولُ صار هو الدخول، فيُعاد حالُ الغرفة.
 */
router.post("/duel/:id/join", requireStudentSession, scoreLimit, async (req, res) => {
  const student = res.locals.student as StudentActor;
  const id = text(req.params.id);
  if (!id) return res.status(400).json({ error: "معرّف المباراة ناقص", code: "bad_request" });
  try {
    const match = await findMatch(id);
    if (!match) return res.status(404).json({ error: "المباراة غير موجودة", code: "not_found" });
    if (!isPlayer(match, student.id)) {
      return res.status(403).json({ error: "لست طرفاً في هذه المباراة", code: "not_a_player" });
    }
    return res.json({ match: toJson(match, student.id), room: roomJson(match) });
  } catch (error) {
    logger.error({ err: error, id }, "[duel] join failed");
    return res.status(503).json({ error: "تعذّر دخول الغرفة الآن", code: "unavailable" });
  }
});

/**
 * جوابُ سؤالٍ في المباراة. الجسم: `{ index, choice }`.
 *
 * ── والأوّلُ يُحسم في القاعدة ──
 * الصحةُ تُقرأ من حزمة المباراة المحفوظة، و`record_duel_answer` تسجّل الجوابَ تحت
 * قفلٍ لكل سؤال فتقول هل كان أوّلَ صحيح — بين لاعبَين أو ستّة، في مكانٍ واحد.
 *
 * ولا يُجيب إلا من في قائمة اللاعبين: من تأخّر في الردّ فاستُبعد لا يكسب أسئلةً.
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
    if (match.status !== "pending") {
      return res.status(409).json({ error: "انتهت المباراة", code: "settled" });
    }
    const room = roomOf(match);
    if (!room.roster.includes(student.id)) {
      return res.status(403).json({ error: "لست لاعباً في هذا النزال", code: "not_a_player" });
    }
    // ولا جوابَ قبل الموعد: ثانيةٌ من السماحة لفرق الساعات.
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
    // فاز، ومكافأةُ هذه اللعبة في الدرس صُرفت له من قبل: يقال له ذلك.
    rewardTaken: iWon && match.rewardPaid === false,
    draw: match.status === "done" && match.winnerId === null,
  };
}

/**
 * حسمُ المباراة من إجاباتها المسجّلة.
 *
 * ── ومرّةً واحدة ──
 * الأجهزةُ كلُّها تطلب الحسمَ عند آخر سؤال. فالكتابةُ مشروطةٌ بأن تكون المباراةُ
 * معلّقة: من وجدها كذلك حسمها وصرف الجائزة، والباقون يقرؤون ما حُسم.
 */
async function settle(id: string, me: string): Promise<ReturnType<typeof settledJson> | null> {
  let match = await findMatch(id);
  if (!match) return null;
  if (match.status === "pending") {
    const roster = roomOf(match).roster;
    const answers = await rest(
      `${ANSWERS}?select=student_id,question_index,won&match_id=eq.${encodeURIComponent(id)}&won=is.true`,
    );
    const scores = partyScores(
      (Array.isArray(answers) ? answers : []).map((row) => {
        const r = row as Record<string, unknown>;
        return {
          studentId: text(r.student_id),
          questionIndex: Number(r.question_index),
          won: r.won === true,
        };
      }),
      roster,
    );
    const { standings, winnerId } = rankParty(scores);
    const hostScore = scores.get(match.hostId) ?? 0;
    const best = Math.max(0, ...standings.filter((s) => s.studentId !== match!.hostId).map((s) => s.score));
    const written = await rest(
      `${MATCHES}?id=eq.${encodeURIComponent(id)}&status=eq.pending`,
      {
        method: "PATCH",
        headers: { Prefer: "return=representation" },
        body: JSON.stringify({
          // صفُّ المباراة يحمل نتيجةَ الداعي وأفضلَ منافس، للتوافق مع ما سبق.
          host_score: hostScore,
          guest_score: best,
          status: "done",
          winner_id: winnerId,
          updated_at: new Date().toISOString(),
        }),
      },
    );
    const settledHere = Array.isArray(written) && written.length > 0;
    if (settledHere) {
      if (!match.legacy) await writeResults(id, standings);
      if (winnerId) {
        // والصرفُ لا يُسقط الحسم. ومرّةً لكل لعبةٍ في كل درس: انظر `duelRewardActivity`.
        const reward = duelRewardActivity(match.lessonId, match.game);
        const paid = await awardDuelWin(winnerId, reward).catch((error) => {
          logger.error({ err: error, id }, "[duel] win gems not paid");
          return false;
        });
        await rest(`${MATCHES}?id=eq.${encodeURIComponent(id)}`, {
          method: "PATCH",
          headers: { Prefer: "return=minimal" },
          body: JSON.stringify({ reward_paid: paid }),
        });
      }
    }
    logger.info({ id, players: roster.length, winnerId, settledHere }, "[duel] settled");
  }
  // ومن لم يحسمها قد يقرأ قبل أن تُكتب الجائزةُ والنتائج: لحظاتٌ قليلةٌ ينتظرها.
  for (let attempt = 0; attempt < 5; attempt += 1) {
    match = await findMatch(id);
    if (!match) return null;
    const resultsWritten = match.legacy ||
      [...match.results.values()].some((result) => result.rank !== null);
    if ((match.winnerId === null || match.rewardPaid !== null) && resultsWritten) break;
    await new Promise((resolve) => setTimeout(resolve, 300));
  }
  return settledJson(match!, me);
}

/** يكتب نتيجةَ كلِّ لاعبٍ ومركزَه. */
async function writeResults(id: string, standings: readonly PartyStanding[]) {
  await Promise.all(standings.map((entry) =>
    rest(
      `${PLAYERS}?match_id=eq.${encodeURIComponent(id)}&student_id=eq.${encodeURIComponent(entry.studentId)}`,
      {
        method: "PATCH",
        headers: { Prefer: "return=minimal" },
        body: JSON.stringify({ score: entry.score, rank: entry.rank }),
      },
    ).catch((error) => logger.error({ err: error, id }, "[duel] result not written"))
  ));
}

async function finishRoute(req: Request, res: Response) {
  const student = res.locals.student as StudentActor;
  const id = text(req.params.id);
  if (!id) return res.status(400).json({ error: "معرّف المباراة ناقص", code: "bad_request" });
  try {
    const match = await findMatch(id);
    if (!match) return res.status(404).json({ error: "المباراة غير موجودة", code: "not_found" });
    if (!isPlayer(match, student.id)) {
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

/** المسارُ القديم، لنسخٍ من التطبيق لم تُحدَّث بعد. */
router.post("/duel/:id/score", requireStudentSession, scoreLimit, finishRoute);

/**
 * مغادرةُ مباراةٍ لم تبدأ.
 *
 * الداعي يغادر: تُلغى الدعوةُ على الجميع. ومدعوٌّ وافق ثم غادر قبل الحسم: يُكتب
 * رفضاً، ويبدأ الباقون بدونه. ولا تُلغى مباراةٌ حُسم من يلعب فيها: من غادر لا
 * يمحوها على زملائه.
 */
router.post("/duel/:id/cancel", requireStudentSession, scoreLimit, async (req, res) => {
  const student = res.locals.student as StudentActor;
  const id = text(req.params.id);
  if (!id) return res.status(400).json({ error: "معرّف المباراة ناقص", code: "bad_request" });
  try {
    const match = await findMatch(id);
    if (!match) return res.status(404).json({ error: "المباراة غير موجودة", code: "not_found" });
    const me = match.players.find((player) => player.studentId === student.id);
    if (!me) {
      return res.status(403).json({ error: "لست طرفاً في هذه المباراة", code: "not_a_player" });
    }
    const room = roomOf(match);
    if (room.phase !== "invited") {
      return res.json({
        cancelled: room.phase === "expired",
        status: room.phase,
        room: roomJson(match),
      });
    }
    const now = new Date().toISOString();
    let cancelled = false;
    if (me.role === "host" || match.legacy) {
      const written = await rest(
        `${MATCHES}?id=eq.${encodeURIComponent(id)}&status=eq.pending`,
        {
          method: "PATCH",
          headers: { Prefer: "return=representation" },
          body: JSON.stringify({ status: "expired", updated_at: now }),
        },
      );
      cancelled = Array.isArray(written) && written.length > 0;
    } else {
      // مدعوٌّ يغادر قبل الحسم: رفضٌ — ردٌّ لم يكن، أو قَبولٌ يُسحب.
      await rest(
        `${PLAYERS}?match_id=eq.${encodeURIComponent(id)}&student_id=eq.${encodeURIComponent(student.id)}`,
        {
          method: "PATCH",
          headers: { Prefer: "return=minimal" },
          body: JSON.stringify({
            responded_at: me.respondedAt ?? now,
            accepted: false,
          }),
        },
      );
      cancelled = true;
    }
    const fresh = (await findMatch(id))!;
    return res.json({ cancelled, status: roomOf(fresh).phase, room: roomJson(fresh) });
  } catch (error) {
    logger.error({ err: error, id }, "[duel] cancel failed");
    return res.status(503).json({ error: "تعذّر إلغاء المباراة الآن", code: "unavailable" });
  }
});

/** مبارياتي: ما ينتظرني، وما انتهى حديثاً — ثنائيةً أو جماعية. */
router.get("/duel/inbox", requireStudentSession, async (_req, res) => {
  const student = res.locals.student as StudentActor;
  try {
    const id = encodeURIComponent(student.id);
    const mine = await readPlayers(`student_id=eq.${id}&order=invited_at.desc&limit=40`);
    const partyIds = (mine ?? []).map((row) => text((row as Record<string, unknown>).match_id));
    const filter = partyIds.length > 0
      ? `or=(host_id.eq.${id},guest_id.eq.${id},id.in.(${partyIds.map((m) => `"${m}"`).join(",")}))`
      : `or=(host_id.eq.${id},guest_id.eq.${id})`;
    const rows = await rest(
      `${MATCHES}?select=*&${filter}&status=neq.expired&order=created_at.desc&limit=40`,
    );
    const matches = (Array.isArray(rows) ? rows : [])
      .map(readMatch)
      .filter((match): match is StoredMatch => match !== null);
    const players = matches.length > 0
      ? await readPlayers(`match_id=in.(${matches.map((m) => `"${m.id}"`).join(",")})`)
      : [];
    const byMatch = new Map<string, unknown[]>();
    for (const row of players ?? []) {
      const key = text((row as Record<string, unknown>).match_id);
      byMatch.set(key, [...(byMatch.get(key) ?? []), row]);
    }
    return res.json({
      matches: matches.map((match) => toJson(withPlayers(match, byMatch.get(match.id) ?? []), student.id)),
    });
  } catch (error) {
    logger.error({ err: error }, "[duel] inbox failed");
    return res.status(503).json({ error: "تعذّر قراءة تحدّياتك الآن" });
  }
});

/**
 * صدارةُ الصفّ بعدد الانتصارات، من المباريات المنتهية ولاعبيها.
 */
router.get("/duel/standings", requireStudentSession, async (_req, res) => {
  const student = res.locals.student as StudentActor;
  const key = classKey(student.teacherId, student.grade);
  if (!key) return res.json({ standings: [] });
  try {
    const rows = await rest(
      `${MATCHES}?select=id,host_id,guest_id,host_score,guest_score,winner_id` +
        `&class_key=eq.${encodeURIComponent(key)}&status=eq.done&limit=1000`,
    );
    const matches = (Array.isArray(rows) ? rows : [])
      .map(readMatch)
      .filter((match): match is StoredMatch => match !== null);
    const players = matches.length > 0
      ? await readPlayers(
        `match_id=in.(${matches.map((m) => `"${m.id}"`).join(",")})`,
      )
      : [];
    const byMatch = new Map<string, string[]>();
    for (const row of players ?? []) {
      const r = row as Record<string, unknown>;
      const key = text(r.match_id);
      byMatch.set(key, [...(byMatch.get(key) ?? []), text(r.student_id)]);
    }
    const table = standingsOf(matches.map((match) => ({
      ...match,
      players: byMatch.get(match.id),
      winnerId: match.winnerId,
    })));

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

/** مباراةٌ بعينها، بأسئلتها وغرفتها. ولا يقرؤها إلا لاعبوها. */
router.get("/duel/:id", requireStudentSession, async (req, res) => {
  const student = res.locals.student as StudentActor;
  const id = text(req.params.id);
  if (!id) return res.status(400).json({ error: "معرّف المباراة ناقص" });
  try {
    const match = await findMatch(id);
    if (!match) return res.status(404).json({ error: "المباراة غير موجودة" });
    if (!isPlayer(match, student.id)) {
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
    if (!isPlayer(match, student.id)) {
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
    if (!isPlayer(match, student.id)) {
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
