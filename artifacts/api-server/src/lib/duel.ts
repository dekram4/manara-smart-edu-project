/**
 * منطقُ مباراة التحدي: من فاز، وبكم، ومتى تُصرف الجوهرة.
 *
 * ── لماذا وحدةٌ نقيّة ──
 * الفوزُ يُصرف عليه جوهرة، فهو قرارٌ له ثمن. وقرارٌ كهذا يجب أن يُقرأ في
 * مكانٍ واحد ويُختبر بلا شبكةٍ ولا قاعدةِ بيانات — لا أن يُستنتج من شروطٍ
 * مبثوثةٍ في مسار.
 *
 * والتطبيقُ يدّعي النتيجة، فكلُّ ما هنا يفترض ذلك: تُحصَر النتيجةُ بسقفٍ
 * معلوم، ويُرفض ما لا يُحتمل.
 */

/** الألعابُ الأربع في بطاقة التحدي. */
export const DUEL_GAMES = ["sprint", "balloons", "tug", "gems"] as const;

export type DuelGame = (typeof DUEL_GAMES)[number];

/**
 * جوهرةٌ واحدة للفائز.
 *
 * ── ولماذا واحدةٌ لا أكثر ──
 * المباراةُ دقيقةٌ أو دقيقتان، وطالبان يستطيعان أن يتحدّيا بعضَهما عشرين
 * مرّةً في حصّة. فجوهرتان أو ثلاث تجعل الرصيدَ يُجمع بالتحدّي لا بالدرس،
 * وتُفرِغ ما جُعلت الجواهرُ له.
 *
 * والخاسرُ لا يُخصم منه: الخصمُ يجعل الطفل يخاف أن يُتحدّى، والمقصودُ أن
 * يُقبل التحدي لا أن يُتجنَّب.
 */
export const DUEL_WIN_GEMS = 1;

/**
 * عددُ الأسئلة في المباراة.
 *
 * ── وعشرةٌ لا خمس ──
 * خمسةُ أسئلةٍ تنتهي في أربعين ثانية، فتنتهي المباراةُ قبل أن تبدأ الإثارة:
 * لا مجالَ لتأخّرٍ يُدرَك ولا للحاقٍ به. والعشرُ تجعل للمنحنى معنىً — من
 * تأخّر يستطيع أن يعود — وتبقى دون ملل.
 */
export const DUEL_ROUNDS = 10;

/**
 * نقاطُ الجواب الصحيح، وما يُضاف لسرعته.
 *
 * ── ولماذا نقاطٌ لا عددُ إجاباتٍ صحيحة ──
 * الصحيحُ وحده يجعل مباراتين متساويتين وإحداهما أُجيبت في ثانيتين والأخرى
 * في العشرة كلّها. والسرعةُ جزءٌ من اللعبة، فتُحسب.
 *
 * والأساسُ عشرةٌ والسرعةُ خمسةٌ على الأكثر: فالصحيحُ البطيء يبقى خيراً من
 * السريع الخاطئ بفارقٍ لا يُلحق بالسرعة وحدها — وإلا صار التخمينُ السريع
 * استراتيجيّة.
 */
export const DUEL_POINTS_CORRECT = 10;
export const DUEL_POINTS_SPEED_MAX = 5;

/** أقصى نتيجةٍ ممكنة: كلُّ سؤالٍ صحيحٌ وفي أسرع وقت. */
export const DUEL_MAX_SCORE =
  DUEL_ROUNDS * (DUEL_POINTS_CORRECT + DUEL_POINTS_SPEED_MAX);

/** ثوانيَ السؤال في المباراة الحيّة. */
export const DUEL_QUESTION_SECONDS = 10;

/**
 * نقاطُ جوابٍ صحيحٍ أُجيب وقد بقي [msLeft] من وقت السؤال.
 *
 * دالّةٌ نقيّةٌ في مكانٍ واحد: التطبيقُ يحسب بها ليعرض، والخادم يحسب بها
 * سقفَ ما يُقبل. وحسابان يفترقان يجعلان نتيجةً صحيحةً تُرفض.
 */
export function speedPoints(
  msLeft: number,
  windowMs: number = DUEL_QUESTION_SECONDS * 1000,
): number {
  if (!Number.isFinite(msLeft) || msLeft <= 0 || windowMs <= 0) return 0;
  const share = Math.min(1, msLeft / windowMs);
  return Math.round(share * DUEL_POINTS_SPEED_MAX);
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
