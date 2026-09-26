/**
 * ترتيب زملاء الصفّ بالجواهر.
 *
 * مفصول عن المسار وخالٍ من Express والشبكة: قواعد الترشيح والترتيب هي
 * ما يُخطئ هنا — طالبٌ من صفٍّ آخر يتسرّب، أو متساويان يُرتَّبان بالصدفة
 * فيتبادلان المركزين بين فتحةٍ وأخرى — ولا يُرى ذلك من ردّ شبكة.
 */

export interface LeaderboardEntry {
  id: string;
  name: string;
  gems: number;
  xp: number;
  level: number;
  /** ما اختاره الطفل من شخصيات، كما يخزّنه سجلّه. */
  appearance: Record<string, unknown> | null;
  rank: number;
  isMe: boolean;
}

export interface Leaderboard {
  entries: LeaderboardEntry[];
  /** مركز الطالب الحالي، أو 0 إن لم يظهر في القائمة. */
  myRank: number;
  total: number;
  /** جواهر المتصدّر، ليُعرف الفارق بلا حسابٍ في الواجهة. */
  topGems: number;
  /** كم جوهرةً تفصله عن المركز الذي فوقه. صفرٌ للمتصدّر. */
  gemsToNext: number;
}

const text = (value: unknown): string =>
  typeof value === "string" ? value.trim() : "";

const asMap = (value: unknown): Record<string, unknown> =>
  value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};

const num = (value: unknown): number => {
  if (typeof value === "number" && Number.isFinite(value)) return Math.trunc(value);
  const parsed = Number.parseInt(String(value ?? ""), 10);
  return Number.isFinite(parsed) ? parsed : 0;
};

/** تسوية عربية للمقارنة: الهمزة لا تصنع صفّاً ثانياً. */
export function norm(value: unknown): string {
  return text(value)
    .toLowerCase()
    .replace(/[ً-ْٰـ]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/\s+/g, " ")
    .trim();
}

/** مالك السجلّ، بالترتيب الذي تقرؤه بقيّة المنظومة. */
export const ownerOf = (record: unknown): string => {
  const data = asMap(record);
  return norm(data.teacher_id ?? data.teacherId ?? data.createdBy);
};

/**
 * هل هذا الطالب زميلٌ لصاحب اللوحة؟
 *
 * المعلّم نفسه والصفّ نفسه، لا أكثر. والمادة لا تدخل: الجواهر تُجمع من
 * كل ما يفعله الطفل في المنصّة لا من مادةٍ بعينها، فترشيحُ اللوحة بها
 * يُخرج زميلاً يجلس بجانبه في الفصل لأنه يدرس مادةً أخرى.
 */
export function isClassmate(
  data: unknown,
  teacherId: string,
  grade: string,
): boolean {
  const record = asMap(data);
  if (ownerOf(record) !== norm(teacherId)) return false;
  return norm(record.grade) === norm(grade);
}

/**
 * الترتيب، والمركز، والفارق.
 *
 * ── لماذا الترتيب ثابت عند التساوي ──
 * طالبان بالجواهر نفسها يُرتَّبان بنقاط الخبرة ثم بالاسم ثم بالمعرّف.
 * ولولا ذلك لاعتمد ترتيبُهما على ما يعيده الخادم في تلك اللحظة،
 * فيتبادلان المركزين بين فتحةٍ وأخرى بلا أن يكسب أحدهما شيئاً — وطفلٌ
 * يرى مركزه ينزل بلا سبب يفقد الثقة في العدّاد كلّه.
 *
 * ── والمتساويان مركزُهما واحد ──
 * ثلاثةٌ لهم عشرون جوهرة كلّهم في المركز الأول، والذي يليهم رابع. هذا
 * ما يفهمه الطفل من «الترتيب»، وهو ما تفعله المنافسات.
 */
export function buildLeaderboard(
  rows: unknown[],
  meId: string,
  limit = 50,
): Leaderboard {
  const me = norm(meId);
  const people = rows
    .map((row) => {
      const record = asMap(row);
      const data = asMap(record.data ?? record);
      const game = asMap(data.gamification);
      const id = text(data.id) || text(record.id);
      return {
        id,
        name: text(data.name) || "—",
        gems: num(game.gems),
        xp: num(game.xp),
        level: num(game.level),
        appearance: data.appearance ? asMap(data.appearance) : null,
        isMe: norm(id) === me,
      };
    })
    .filter((person) => person.id !== "");

  people.sort((left, right) => {
    if (right.gems !== left.gems) return right.gems - left.gems;
    if (right.xp !== left.xp) return right.xp - left.xp;
    const byName = left.name.localeCompare(right.name, "ar");
    return byName !== 0 ? byName : left.id.localeCompare(right.id);
  });

  const entries: LeaderboardEntry[] = [];
  let rank = 0;
  let previousGems: number | null = null;
  people.forEach((person, index) => {
    if (previousGems === null || person.gems !== previousGems) {
      rank = index + 1;
      previousGems = person.gems;
    }
    entries.push({ ...person, rank });
  });

  const mine = entries.find((entry) => entry.isMe);
  const topGems = entries.length ? entries[0].gems : 0;

  // الفارق عن المركز الذي فوقه لا عن المتصدّر: «تنقصك ثلاث جواهر
  // لتتقدّم» يُحرّك طفلاً، و«تنقصك مئة» يُقعده.
  let gemsToNext = 0;
  if (mine && mine.rank > 1) {
    const above = entries
      .filter((entry) => entry.gems > mine.gems)
      .reduce<number | null>(
        (lowest, entry) =>
          lowest === null || entry.gems < lowest ? entry.gems : lowest,
        null,
      );
    if (above !== null) gemsToNext = above - mine.gems;
  }

  return {
    // الصدر وحده يُرسل: قائمةٌ بخمسين تكفي فصلاً، وما بعدها لا يُقرأ.
    // ومركز صاحب اللوحة يبقى صحيحاً لأنه يُحسب قبل القصّ.
    entries: entries.slice(0, limit),
    myRank: mine?.rank ?? 0,
    total: entries.length,
    topGems,
    gemsToNext,
  };
}
