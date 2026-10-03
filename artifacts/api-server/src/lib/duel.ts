/**
 * منطقُ مباراة التحدي: من فاز، وبكم، ومتى تُصرف الجوهرة.
 *
 * ── لماذا وحدةٌ نقيّة ──
 * الفوزُ يُصرف عليه جوهرة، فهو قرارٌ له ثمن. وقرارٌ كهذا يجب أن يُقرأ في
 * مكانٍ واحد ويُختبر بلا شبكةٍ ولا قاعدةِ بيانات — لا أن يُستنتج من شروطٍ
 * مبثوثةٍ في مسار.
 *
 * والنتيجةُ لا يدّعيها التطبيق: تُحسب من الإجابات المسجّلة — انظر
 * `scoresFromAnswers` — وما بقي من حصر النتيجة لمسارٍ قديم.
 */

/** الألعابُ الأربع في بطاقة التحدي. */
export const DUEL_GAMES = ["sprint", "balloons", "tug", "gems"] as const;

export type DuelGame = (typeof DUEL_GAMES)[number];

/**
 * خمسُ جواهرَ للفائز — مرّةً واحدةً لكل لعبةٍ في كل درس.
 *
 * ── ولماذا مرّةً لكل لعبةٍ في الدرس ──
 * المباراةُ دقيقةٌ أو دقيقتان، وزميلان يستطيعان أن يتحدّيا بعضَهما عشرين مرّةً
 * في حصّة. فجائزةٌ لكل فوزٍ تجعل الرصيدَ يُجمع بتكرار التحدي نفسه لا بالتعلّم.
 * والجائزةُ لكل لعبةٍ في الدرس: الفوزُ في لعبةٍ أخرى من الدرس نفسه يُكافأ، وإعادةُ
 * اللعبة نفسها في الدرس نفسه لا تُكافأ مرّةً ثانية.
 *
 * ومفتاحُ المنع في سجلّ الطالب `duel:<الدرس>:<اللعبة>` — انظر [duelRewardActivity].
 * والخاسرُ لا يُخصم منه: الخصمُ يجعل الطفل يخاف أن يُتحدّى.
 */
export const DUEL_WIN_GEMS = 5;

/**
 * ما يُسجَّل في سجلّ الطالب عن جائزة الفوز: الدرسُ واللعبة.
 *
 * و`awardDuelWin` يضع قبله `duel:`، فيكون المفتاحُ `duel:<الدرس>:<اللعبة>`.
 */
export function duelRewardActivity(lessonId: string, game: string): string {
  return `${lessonId.trim()}:${game.trim()}`;
}

/**
 * عددُ الأسئلة في المباراة.
 *
 * ── وعشرةٌ لا خمس ──
 * خمسةُ أسئلةٍ تنتهي في أربعين ثانية، فتنتهي المباراةُ قبل أن تبدأ الإثارة:
 * لا مجالَ لتأخّرٍ يُدرَك ولا للحاقٍ به. والعشرُ تجعل للمنحنى معنىً.
 */
export const DUEL_ROUNDS = 10;

/**
 * نقاطُ السؤال، وتذهب كلُّها لأوّل من يُجيب صحيحاً.
 *
 * ── السرعةُ هي القاعدة ──
 * لا نقاطَ لجوابٍ صحيحٍ جاء ثانياً: السؤالُ يُكسب ولا يُقتسم. والأوّلُ يُحسم في
 * القاعدة (`record_duel_answer`) تحت قفلٍ لكل سؤال، لا بادّعاء التطبيق — فجهازان
 * يُرسلان في اللحظة نفسها يُفصل بينهما في مكانٍ واحد.
 */
export const DUEL_POINTS_PER_QUESTION = 10;

/** أقصى نتيجة: كلُّ سؤالٍ كُسب. */
export const DUEL_MAX_SCORE = DUEL_ROUNDS * DUEL_POINTS_PER_QUESTION;

/** ثوانيَ السؤال. */
export const DUEL_QUESTION_SECONDS = 10;

/** إجابةٌ مسجّلةٌ في `match_answers`. */
export interface DuelAnswer {
  studentId: string;
  questionIndex: number;
  won: boolean;
}

/**
 * نتيجتا اللاعبين من إجاباتهما المسجّلة.
 *
 * من القاعدة لا من التطبيق: نقاطُ كلّ سؤالٍ كسبه، ولا شيءَ لسواه. وسؤالٌ واحدٌ لا
 * يُكسب مرّتين — الفهرسُ الفريد في القاعدة يمنعه — لكنّ الحساب لا يعتمد عليه:
 * يُعدّ كلُّ سؤالٍ مرّةً لأوّل فائزٍ به يُقرأ.
 */
export function scoresFromAnswers(
  answers: readonly DuelAnswer[],
  hostId: string,
  guestId: string,
): { hostScore: number; guestScore: number } {
  const counted = new Set<number>();
  let hostScore = 0;
  let guestScore = 0;
  for (const answer of answers) {
    if (!answer.won || counted.has(answer.questionIndex)) continue;
    if (answer.studentId === hostId) {
      hostScore += DUEL_POINTS_PER_QUESTION;
    } else if (answer.studentId === guestId) {
      guestScore += DUEL_POINTS_PER_QUESTION;
    } else {
      continue;
    }
    counted.add(answer.questionIndex);
  }
  return { hostScore, guestScore };
}


export function isDuelGame(value: unknown): value is DuelGame {
  return typeof value === "string" && (DUEL_GAMES as readonly string[]).includes(value);
}

/**
 * نتيجةٌ مقبولة، أو `null`.
 *
 * صحيحٌ بين صفرٍ و[DUEL_MAX_SCORE]. وما فوق السقف يُردّ لا يُقصّ: قصُّه يقبل
 * طلباً مدّعىً ويسجّله صحيحاً، وردُّه يُظهر الخطأ لمن أرسله.
 */
export function parseScore(value: unknown): number | null {
  // ── ولا يُمرَّر الغائبُ عبر `Number` ──
  // `Number(null)` و`Number("")` و`Number([])` كلُّها صفر. فطلبٌ بلا نتيجة
  // كان يُسجَّل صفراً — نتيجةٌ حاضرةٌ في الجدول لم يلعبها أحد، تمنح الخصمَ
  // فوزاً وجوهرةً على مباراةٍ لم تُلعب.
  //
  // فالنوعُ يُفحص أوّلاً، والنصُّ لا يُقبل إلا أرقاماً.
  if (typeof value === "number") {
    return Number.isInteger(value) && value >= 0 && value <= DUEL_MAX_SCORE
      ? value
      : null;
  }
  if (typeof value === "string") {
    const digits = value.trim();
    if (!/^\d+$/.test(digits)) return null;
    const score = Number(digits);
    return score <= DUEL_MAX_SCORE ? score : null;
  }
  return null;
}

/** مفتاحُ الصفّ: حدُّ الدعوة والصدارة. */
export function classKey(teacherId: unknown, grade: unknown): string {
  const teacher = typeof teacherId === "string" ? teacherId.trim() : "";
  const level = typeof grade === "string" ? grade.trim() : "";
  return teacher && level ? `${teacher}:${level}` : "";
}

/**
 * معرّفُ المباراة.
 *
 * يحمل وقتَه ونصيباً عشوائياً: الوقتُ يجعله مرتَّباً في السجلّ، والعشوائيُّ
 * يمنع تصادمَ مباراتين بدأتا في المللي نفسها.
 */
export function matchId(now: Date = new Date()): string {
  const stamp = now.getTime().toString(36);
  const salt = Math.random().toString(36).slice(2, 8);
  return `duel_${stamp}_${salt}`;
}

export interface MatchRow {
  hostId: string;
  guestId: string;
  hostScore: number | null;
  guestScore: number | null;
}

export type DuelOutcome =
  | { settled: false }
  | { settled: true; winnerId: string | null; draw: boolean };

/**
 * هل انتهت المباراة، ومن فاز؟
 *
 * ── وتنتهي حين تحضر النتيجتان ──
 * لا بوقتٍ ولا بأن يُنهي أحدُهما: المباراةُ مقارنةٌ بين نتيجتين، فنصفُها
 * ليس مباراةً. والمتحدّي الذي لعب وحده ينتظر زميلَه — وهي المباراةُ
 * المؤجَّلة بعينها.
 *
 * ── والتعادلُ لا فائزَ له ولا جوهرة ──
 * جوهرةٌ لكلٍّ في التعادل تجعل التعادلَ مقصوداً: يتّفق زميلان على أن
 * يُصيبا واحداً فيربحا معاً في كل مباراة. ولا جوهرةَ فيه يُبقيه ما هو —
 * تعادلاً.
 */
export function outcomeOf(row: MatchRow): DuelOutcome {
  const { hostScore, guestScore } = row;
  if (hostScore === null || guestScore === null) return { settled: false };
  if (hostScore === guestScore) {
    return { settled: true, winnerId: null, draw: true };
  }
  return {
    settled: true,
    winnerId: hostScore > guestScore ? row.hostId : row.guestId,
    draw: false,
  };
}

/**
 * أيُّ اللاعبين هذا؟
 *
 * ويُردّ من ليس طرفاً فيها: مباراةٌ بين اثنين لا يكتب فيها ثالث.
 */
export function sideOf(row: MatchRow, studentId: string): "host" | "guest" | null {
  if (studentId === row.hostId) return "host";
  if (studentId === row.guestId) return "guest";
  return null;
}

/**
 * هل يُقبل أن يُسجّل هذا الطالبُ نتيجتَه الآن؟
 *
 * ── ولا تُكتب نتيجةٌ مرّتين ──
 * إعادةُ الإرسال — من ضغطةٍ مكرّرة أو شبكةٍ أعادت الطلب — كانت ستُبدّل
 * النتيجةَ بعد أن حُسب الفوز وصُرفت الجوهرة. فأوّلُ ما يُكتب يثبت.
 */
export function canSubmit(row: MatchRow, studentId: string): boolean {
  const side = sideOf(row, studentId);
  if (side === null) return false;
  return side === "host" ? row.hostScore === null : row.guestScore === null;
}

/** ترتيبُ الصفّ بعدد الانتصارات. */
export interface DuelStanding {
  studentId: string;
  wins: number;
  played: number;
}

/**
 * الصدارةُ من المباريات المنتهية.
 *
 * ── وتُحسب من السجلّ لا تُخزَّن عدّاداً ──
 * عدّادٌ يُزاد عند كل فوز يفترق عن السجلّ عند أوّل طلبٍ يُعاد أو صفٍّ
 * يُصحَّح بيد. والحسابُ من المباريات لا يكذب، وعددُها في صفٍّ واحد لا
 * يثقل استعلاماً.
 *
 * ويُحسب «لُعبت» للطرفين والفوزُ للفائز: طالبٌ لعب عشراً وفاز بثلاثٍ يُقرأ
 * حالُه من الرقمين، ولا يُقرأ من الفوز وحده.
 */
export function standingsOf(
  rows: readonly (MatchRow & { players?: readonly string[]; winnerId?: string | null })[],
): DuelStanding[] {
  const table = new Map<string, DuelStanding>();
  const touch = (id: string): DuelStanding => {
    const found = table.get(id);
    if (found) return found;
    const fresh = { studentId: id, wins: 0, played: 0 };
    table.set(id, fresh);
    return fresh;
  };
  for (const row of rows) {
    // مباراةٌ جماعية: لاعبوها من جدولهم، وفائزُها ما كتبه الحسم.
    if (row.players && row.players.length > 0) {
      for (const id of row.players) touch(id).played += 1;
      if (row.winnerId) touch(row.winnerId).wins += 1;
      continue;
    }
    const outcome = outcomeOf(row);
    if (!outcome.settled) continue;
    touch(row.hostId).played += 1;
    touch(row.guestId).played += 1;
    if (outcome.winnerId) touch(outcome.winnerId).wins += 1;
  }
  return [...table.values()].sort(
    (a, b) => b.wins - a.wins || b.played - a.played,
  );
}

// ── الغرفة: الدعوةُ لزميلٍ أو أكثر، ويبدأ النزالُ بمن وافق ──

/**
 * مهلةُ الردّ على الدعوة.
 *
 * عشرون ثانية: تكفي طفلاً ليقرأ الدعوة ويقرّر، ولا تُبقي الداعي ومن وافق ينتظرون
 * زميلاً لن يردّ. ومن ردّ بعدها لا يدخل — بدأ النزالُ بدونه.
 */
export const DUEL_INVITE_SECONDS = 20;

/** أقصى عددٍ من المدعوّين في تحدٍّ واحد: ستّةُ لاعبين مع الداعي. */
export const DUEL_MAX_INVITEES = 5;

/**
 * ما بين حسم من يلعب وأوّل سؤال: عدٌّ تنازليٌّ يراه الجميع، ويتّسع لتأخّر الشبكة
 * بين الأجهزة.
 */
export const DUEL_START_DELAY_MS = 4000;

/** لاعبٌ في المباراة كما يُقرأ من `challenge_match_players`. */
export interface PlayerRow {
  studentId: string;
  role: "host" | "guest";
  respondedAt: string | null;
  accepted: boolean | null;
}

/**
 * حالُ الغرفة:
 *   invited — الدعوةُ تنتظر الردود. الداعي ومن وافق في غرفة الانتظار.
 *   ready   — حُسم من يلعب: يبدأ النزالُ عند [startAt]، لا قبله.
 *   expired — أُلغيت، أو لم يوافق أحدٌ في المهلة.
 *   done    — حُسمت.
 */
export type RoomPhase = "invited" | "ready" | "expired" | "done";

/** حالُ مدعوٍّ كما تُعرض: ينتظر، وافق، رفض، أو تأخّر فاستُبعد. */
export type PlayerStatus = "host" | "pending" | "accepted" | "declined" | "late";

export interface RoomState {
  phase: RoomPhase;
  /** آخرُ لحظةٍ للردّ. */
  decideBy: Date;
  /** موعدُ أوّل سؤال، حين يُحسم من يلعب. */
  startAt: Date | null;
  /** من يلعب: الداعي ومن وافق في المهلة. فارغٌ قبل الحسم. */
  roster: string[];
  statuses: Record<string, PlayerStatus>;
}

const at = (value: string | null): number | null => {
  if (!value) return null;
  const time = Date.parse(value);
  return Number.isNaN(time) ? null : time;
};

/**
 * حالُ الغرفة من الردود وأوقاتها — والخادمُ هو الحَكَم.
 *
 * ── متى يبدأ ──
 * ردّ كلُّ المدعوّين في المهلة: يبدأ فوراً، فلا ينتظر أحدٌ عشرين ثانيةً بلا سبب.
 * وإن انتهت المهلةُ يبدأ بمن وافق فيها، ومن لم يردّ يُستبعد. ولا يُلعب نزالٌ بلاعبٍ
 * واحد: إن لم يوافق أحدٌ أُلغي.
 *
 * ── ولماذا يُحسب عند القراءة ──
 * الأجهزةُ كلُّها تسأل الخادمَ فترى الشيءَ نفسه، ولا يحتاج شيءٌ أن «يُعلن» انتهاءَ
 * المهلة: ردٌّ بعدها لا يُقبل (انظر مسار الردّ)، فالحسمُ لا يتغيّر بعد وقوعه.
 */
export function partyRoomOf(
  match: { status: string; createdAt: string },
  players: readonly PlayerRow[],
  now: Date = new Date(),
): RoomState {
  const created = at(match.createdAt) ?? now.getTime();
  const deadline = created + DUEL_INVITE_SECONDS * 1000;
  const decideBy = new Date(deadline);
  const host = players.find((player) => player.role === "host");
  const guests = players.filter((player) => player.role === "guest");

  // ردٌّ في المهلة وحده يُحسب.
  const inTime = (player: PlayerRow) => {
    const time = at(player.respondedAt);
    return time !== null && time <= deadline;
  };
  const statuses: Record<string, PlayerStatus> = {};
  for (const guest of guests) {
    statuses[guest.studentId] = !inTime(guest)
      ? guest.respondedAt !== null || now.getTime() > deadline
        ? "late"
        : "pending"
      : guest.accepted
        ? "accepted"
        : "declined";
  }
  if (host) statuses[host.studentId] = "host";

  const base = { decideBy, startAt: null, roster: [] as string[], statuses };
  if (match.status === "expired") return { ...base, phase: "expired" };

  const accepted = guests.filter((guest) => inTime(guest) && guest.accepted === true);
  const allAnswered = guests.length > 0 && guests.every(inTime);
  const decidedAt = allAnswered
    ? Math.max(...guests.map((guest) => at(guest.respondedAt)!))
    : now.getTime() > deadline
      ? deadline
      : null;
  const roster = host && accepted.length > 0
    ? [host.studentId, ...accepted.map((guest) => guest.studentId)]
    : [];

  if (match.status === "done") {
    return { ...base, phase: "done", roster };
  }
  if (decidedAt === null) return { ...base, phase: "invited" };
  if (roster.length < 2) return { ...base, phase: "expired" };
  return {
    ...base,
    phase: "ready",
    roster,
    startAt: new Date(decidedAt + DUEL_START_DELAY_MS),
  };
}

/**
 * هل يُقبل ردُّ هذا المدعوّ الآن؟
 *
 * مدعوٌّ في هذه المباراة، لم يردّ بعد، والمهلةُ قائمة، والمباراةُ معلّقة.
 */
export function canRespond(
  match: { status: string; createdAt: string },
  players: readonly PlayerRow[],
  studentId: string,
  now: Date = new Date(),
): boolean {
  const me = players.find((player) => player.studentId === studentId);
  if (!me || me.role !== "guest" || me.respondedAt !== null) return false;
  return partyRoomOf(match, players, now).phase === "invited";
}

/** نتائجُ اللاعبين من إجاباتهم المسجّلة: نقاطُ كلِّ سؤالٍ كسبه أوّلاً. */
export function partyScores(
  answers: readonly DuelAnswer[],
  roster: readonly string[],
): Map<string, number> {
  const scores = new Map(roster.map((id) => [id, 0]));
  const counted = new Set<number>();
  for (const answer of answers) {
    if (!answer.won || counted.has(answer.questionIndex)) continue;
    if (!scores.has(answer.studentId)) continue;
    scores.set(answer.studentId, scores.get(answer.studentId)! + DUEL_POINTS_PER_QUESTION);
    counted.add(answer.questionIndex);
  }
  return scores;
}

export interface PartyStanding {
  studentId: string;
  score: number;
  /** المركز، والمتساويان يشتركان فيه. */
  rank: number;
}

/**
 * الترتيبُ والفائز.
 *
 * ── والفائزُ واحدٌ أو لا أحد ──
 * صاحبُ أعلى نتيجةٍ وحده ينال الجواهر. وإن تساوى اثنان في القمّة فلا فائز: جوهرةٌ
 * لكلٍّ تجعل التعادلَ مقصوداً — يتّفق زميلان على أن يتقاسما الأسئلة فيربحا معاً.
 */
export function rankParty(scores: ReadonlyMap<string, number>): {
  standings: PartyStanding[];
  winnerId: string | null;
} {
  const sorted = [...scores.entries()].sort(
    (a, b) => b[1] - a[1] || a[0].localeCompare(b[0]),
  );
  const standings: PartyStanding[] = [];
  sorted.forEach(([studentId, score], index) => {
    const previous = standings[index - 1];
    const rank = previous && previous.score === score ? previous.rank : index + 1;
    standings.push({ studentId, score, rank });
  });
  const top = standings.filter((entry) => entry.rank === 1);
  return { standings, winnerId: top.length === 1 ? top[0].studentId : null };
}

/**
 * لاعبو مباراةٍ قديمةٍ قبل جدول اللاعبين: الداعي وزميلُه، والقَبولُ من
 * `accepted_at`. فتُقرأ بالقواعد نفسها.
 */
export function legacyPlayers(match: {
  hostId: string;
  guestId: string;
  acceptedAt: string | null;
  createdAt: string;
}): PlayerRow[] {
  return [
    { studentId: match.hostId, role: "host", respondedAt: match.createdAt, accepted: true },
    {
      studentId: match.guestId,
      role: "guest",
      respondedAt: match.acceptedAt,
      accepted: match.acceptedAt ? true : null,
    },
  ];
}
