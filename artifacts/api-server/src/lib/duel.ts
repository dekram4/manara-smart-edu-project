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
export function standingsOf(rows: readonly MatchRow[]): DuelStanding[] {
  const table = new Map<string, DuelStanding>();
  const touch = (id: string): DuelStanding => {
    const found = table.get(id);
    if (found) return found;
    const fresh = { studentId: id, wins: 0, played: 0 };
    table.set(id, fresh);
    return fresh;
  };
  for (const row of rows) {
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

// ── المصافحة: لا يبدأ نزالٌ إلا والطرفان فيه ──

/** مهلةُ الردّ على الدعوة. وما بعدها دعوةٌ منتهيةٌ وإن لم يُلغها أحد. */
export const DUEL_INVITE_SECONDS = 30;

/** مهلةُ دخول الغرفة بعد القَبول: من لم يدخل فيها لم يدخل. */
export const DUEL_JOIN_SECONDS = 25;

/**
 * ما بين دخول الثاني وأوّل سؤال: عدٌّ تنازليٌّ يراه الاثنان، ويتّسع لتأخّر
 * الشبكة بين الجهازين.
 */
export const DUEL_START_DELAY_MS = 4000;

/** أوقاتُ المصافحة كما تُقرأ من صفّ المباراة. */
export interface RoomTimes {
  status: string;
  createdAt: string;
  acceptedAt: string | null;
  hostJoinedAt: string | null;
  guestJoinedAt: string | null;
}

/**
 * حالُ الغرفة:
 *   invited  — الدعوةُ تنتظر ردّ الزميل.
 *   accepted — قَبِل، والغرفةُ تنتظر دخولَ الطرفين.
 *   ready    — دخلا معاً: النزالُ يبدأ عند [startAt]، لا قبله.
 *   expired  — رُفضت، أو أُلغيت، أو فاتت مهلتُها.
 *   done     — حُسمت.
 */
export type RoomPhase = "invited" | "accepted" | "ready" | "expired" | "done";

export interface RoomState {
  phase: RoomPhase;
  hostJoined: boolean;
  guestJoined: boolean;
  /** موعدُ أوّل سؤال، حين يدخل الاثنان. */
  startAt: Date | null;
}

const at = (value: string | null): number | null => {
  if (!value) return null;
  const time = Date.parse(value);
  return Number.isNaN(time) ? null : time;
};

/**
 * حالُ الغرفة من أوقاتها — والخادمُ هو الحَكَم.
 *
 * ── لماذا هنا لا على الجهازين ──
 * كان كلُّ جهازٍ يقرّر بما وصله من بثّ: الضيفُ يدخل لحظةَ يضغط «اقبل»، والداعي
 * يقرّر بإشارةٍ قد تفوته ومؤقّتٍ ينتهي عنده. فرأى الداعي «لا يستطيع» ودخل الضيفُ
 * وحده يحلّ ويدردش. والآن القَبولُ والدخولُ والموعدُ أوقاتٌ في صفٍّ واحد، يقرؤها
 * الجهازان فيريان الشيءَ نفسه.
 *
 * والمهلُ تُحسب عند القراءة: دعوةٌ فاتت مهلتُها منتهيةٌ وإن لم يكتب أحدٌ ذلك.
 */
export function roomStateOf(row: RoomTimes, now: Date = new Date()): RoomState {
  const hostJoined = at(row.hostJoinedAt) !== null;
  const guestJoined = at(row.guestJoinedAt) !== null;
  const base = { hostJoined, guestJoined, startAt: null };
  if (row.status === "done") return { ...base, phase: "done" };
  if (row.status !== "pending") return { ...base, phase: "expired" };

  const accepted = at(row.acceptedAt);
  if (accepted === null) {
    const created = at(row.createdAt) ?? now.getTime();
    return now.getTime() - created > DUEL_INVITE_SECONDS * 1000
      ? { ...base, phase: "expired" }
      : { ...base, phase: "invited" };
  }

  if (hostJoined && guestJoined) {
    const second = Math.max(at(row.hostJoinedAt)!, at(row.guestJoinedAt)!);
    return { ...base, phase: "ready", startAt: new Date(second + DUEL_START_DELAY_MS) };
  }
  return now.getTime() - accepted > DUEL_JOIN_SECONDS * 1000
    ? { ...base, phase: "expired" }
    : { ...base, phase: "accepted" };
}
