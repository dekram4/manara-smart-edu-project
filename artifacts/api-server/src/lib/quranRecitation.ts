/**
 * لعبةُ «تسميع القرآن الكريم» في بطاقة المذاكرة — حصراً لدرسٍ واحد.
 *
 * ── متى تظهر ──
 * الصفُّ «روضة منارة المعرفة» **و**المادّةُ «القرآن الكريم» **و**الدرسُ «حفظ
 * وشرح السور القصيرة» معاً ([quranRecitationAllowed]). ولا تظهر في غيره أبداً.
 * والتطبيقُ يحمل نصوصَ السور ويقيّم التلاوة على الجهاز؛ وهنا القاعدةُ والمكافأة.
 *
 * ── المكافأةُ لكل سورة ──
 * [QURAN_REWARD] عن كل سورةٍ تُسمَّع كاملةً صحيحة، مرّةً لكل سورةٍ في الدرس
 * ([quranRewardKey]): والمفتاحُ يبنيه الخادم من سورةٍ تحقّق أنها من السور الثماني.
 *
 * بلا شبكة ولا قاعدة بيانات، فيُختبر وحده.
 */
import { isKindergartenGrade } from "./tracing";

export const QURAN_GAME_ID = "quran" as const;

/** عن كل سورةٍ تُسمَّع كاملةً صحيحة، مرّةً لكل سورةٍ في الدرس. */
export const QURAN_REWARD = { gems: 3, points: 3 } as const;

/** السورُ القصيرة في الدرس، بمعرّفاتها في التطبيق. */
export const QURAN_SURAHS = [
  "fatiha",
  "kafirun",
  "nasr",
  "masad",
  "ikhlas",
  "falaq",
  "nas",
  "kawthar",
] as const;

export type QuranSurahId = (typeof QURAN_SURAHS)[number];

const TASHKEEL = /[ً-ٰٟـ]/g;

function key(value: string): string {
  return value
    .replace(TASHKEEL, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/\s+/g, " ")
    .trim();
}

export function isQuranSubject(subject: string): boolean {
  return key(subject).includes("القران الكريم");
}

/**
 * درسُ حفظ السور القصيرة بأيّ اسمٍ سُمّي: «حفظ وشرح السور القصيرة» أو «تعلم
 * وحفظ السور القصيرة» — ولو سبقته «درس» أو تلته وحدةٌ أو رقم. والقاعدةُ
 * نفسُها في التطبيق (`isShortSurahsLesson`).
 */
export function isShortSurahsLesson(lesson: string): boolean {
  const k = key(lesson);
  return k.includes(key("السور القصيرة")) && k.includes("حفظ");
}

export function quranRecitationAllowed(lesson: { grade?: string; subject?: string; lesson?: string }): boolean {
  return (
    isKindergartenGrade(lesson.grade ?? "") &&
    isQuranSubject(lesson.subject ?? "") &&
    isShortSurahsLesson(lesson.lesson ?? "")
  );
}

/** مفتاحُ مكافأة سورةٍ في درسٍ، أو `null` لدرسٍ آخر أو سورةٍ ليست من الثماني. */
export function quranRewardKey(
  lesson: { id: string; grade?: string; subject?: string; lesson?: string },
  surah: string,
): string | null {
  if (!quranRecitationAllowed(lesson)) return null;
  if (!(QURAN_SURAHS as readonly string[]).includes(surah)) return null;
  return `quran:${lesson.id}:${surah}`;
}
