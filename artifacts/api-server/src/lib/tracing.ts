/**
 * لعبةُ «تتبّع واكتب» في بطاقة المذاكرة — حصراً لصفّ «روضة منارة المعرفة».
 *
 * ── متى تظهر ──
 * الصفُّ «روضة منارة المعرفة» **و**المادّةُ إحدى الأربع معاً: «الحروف العربية»،
 * «الحروف الإنجليزية»، «الأرقام العربية»، «الأرقام الإنجليزية» ([tracingSetFor]).
 * وأيُّ صفٍّ آخر أو مادّةٍ أخرى: لا تتبّعَ أصلاً، وتبقى للدرس ألعابُه العادية.
 *
 * ── ما فيها ──
 * المجموعةُ كاملة: ٢٨ حرفاً عربياً، و٢٦ إنجليزياً، والأعدادُ من ٠ إلى ١٠٠
 * بالنظامين — ومع كلٍّ ما يُنطق به: اسمُ الحرف («باء») والعددُ كلماتٍ («خمسة
 * وعشرون»). ولا تحتاج نصّاً: درسُ الروضة كثيراً ما يكون بلا شرحٍ مكتوب.
 * ومساراتُ التتبّع لا تُرسل من هنا: يحملها التطبيقُ محسوبةً مسبقاً من خطّه.
 *
 * ── والمكافأةُ لكل حرف ──
 * جوهرةٌ ونقطةٌ ([TRACING_REWARD]) عن كل حرفٍ أو عددٍ يكتبه الطفلُ صحيحاً،
 * مرّةً لكل حرفٍ في الدرس ([tracingRewardKey]): الجلسةُ مفتوحةٌ بلا حدّ، ومن
 * أعاد كتابةَ حرفٍ كتبه من قبل يلعب بحرّيةٍ ولا يكسب شيئاً جديداً.
 *
 * بلا شبكة ولا قاعدة بيانات، فيُختبر وحده.
 */
import type { StudyGame, TracingItem } from "./studyGames";

export type { TracingItem };

export const TRACING_GAME_ID = "tracing" as const;

export type TracingKind = TracingItem["kind"];
export type TracingLang = TracingItem["lang"];

/** عن كل حرفٍ أو عددٍ يُكتب صحيحاً، مرّةً لكل حرفٍ في الدرس. */
export const TRACING_REWARD = { gems: 1, points: 1 } as const;

// بالرموز لا بالحروف: نطاقُ «ً-ٰ» المكتوب بحروفه يشمل الأرقامَ الهندية ٠-٩
// (U+0660–0669) فيمحوها.
const TASHKEEL = /[ً-ٰٟـ]/g;

/** أسماءُ الحروف كما يكتبها المعلم: «حرف الباء» → ب. */
const ARABIC_LETTER_NAMES: Record<string, string> = {
  الالف: "ا", الألف: "ا", الهمزه: "ء", الهمزة: "ء",
  الباء: "ب", التاء: "ت", الثاء: "ث", الجيم: "ج", الحاء: "ح", الخاء: "خ",
  الدال: "د", الذال: "ذ", الراء: "ر", الزاي: "ز", الزاء: "ز", السين: "س",
  الشين: "ش", الصاد: "ص", الضاد: "ض", الطاء: "ط", الظاء: "ظ", العين: "ع",
  الغين: "غ", الفاء: "ف", القاف: "ق", الكاف: "ك", اللام: "ل", الميم: "م",
  النون: "ن", الهاء: "ه", الواو: "و", الياء: "ي",
};

function text(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function stripMarks(value: string): string {
  return value.replace(TASHKEEL, "");
}

/** حرفُ الدرس من عنوانه («حرف الباء» → ب) — منه تبدأ اللعبة. */
function lettersIn(source: string, lang: TracingLang): string[] {
  const out: string[] = [];
  if (lang === "ar") {
    const clean = stripMarks(source);
    for (const match of clean.matchAll(/(?:^|[\s(«"])(?:ال)?حرف\s+(?:ال)?([ء-ي]+)/g)) {
      const word = match[1];
      if (word.length === 1) {
        out.push(word);
        continue;
      }
      const named = ARABIC_LETTER_NAMES[`ال${word}`] ?? ARABIC_LETTER_NAMES[word];
      if (named) out.push(named);
    }
  } else {
    for (const match of source.matchAll(/\bletters?\s+([A-Za-z])\b/gi)) {
      const letter = match[1];
      out.push(letter.toUpperCase(), letter.toLowerCase());
    }
  }
  return out;
}

function numbersIn(source: string): string[] {
  const out: string[] = [];
  for (const match of source.matchAll(/(?:رقم|الرقم|العدد|number)\s+([0-9٠-٩]{1,3})(?![0-9٠-٩])/gi)) {
    out.push(match[1]);
  }
  return out;
}

// ── مجموعاتُ الروضة الكاملة ─────────────────────────────────────────

/** الحروفُ العربية بترتيبها، واسمُ كلٍّ منها كما يُنطق للطفل. */
export const ARABIC_LETTERS: readonly (readonly [string, string])[] = [
  ["ا", "ألف"], ["ب", "باء"], ["ت", "تاء"], ["ث", "ثاء"], ["ج", "جيم"], ["ح", "حاء"],
  ["خ", "خاء"], ["د", "دال"], ["ذ", "ذال"], ["ر", "راء"], ["ز", "زاي"], ["س", "سين"],
  ["ش", "شين"], ["ص", "صاد"], ["ض", "ضاد"], ["ط", "طاء"], ["ظ", "ظاء"], ["ع", "عين"],
  ["غ", "غين"], ["ف", "فاء"], ["ق", "قاف"], ["ك", "كاف"], ["ل", "لام"], ["م", "ميم"],
  ["ن", "نون"], ["ه", "هاء"], ["و", "واو"], ["ي", "ياء"],
];

/** أعلى عددٍ في مجموعة الأرقام: من الصفر إلى المئة. */
export const NUMBERS_MAX = 100;

/** «25» بالأرقام الهندية: «٢٥». */
export function toArabicIndic(value: string): string {
  return value.replace(/[0-9]/g, (d) => String.fromCharCode(0x0660 + Number(d)));
}

/** «٢٥» بالأرقام الغربية: «25» — للمقارنة. */
export function toWesternDigits(value: string): string {
  return value.replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660));
}

const AR_UNITS = [
  "صفر", "واحد", "اثنان", "ثلاثة", "أربعة", "خمسة", "ستة", "سبعة", "ثمانية", "تسعة",
  "عشرة", "أحد عشر", "اثنا عشر", "ثلاثة عشر", "أربعة عشر", "خمسة عشر", "ستة عشر",
  "سبعة عشر", "ثمانية عشر", "تسعة عشر",
];
const AR_TENS = ["", "", "عشرون", "ثلاثون", "أربعون", "خمسون", "ستون", "سبعون", "ثمانون", "تسعون"];

/**
 * العددُ كلماتٍ عربية، من الصفر إلى المئة: «خمسة وعشرون».
 *
 * يُنطق بالكلمات لا بالأرقام: محرّكُ نطقٍ لا صوتَ عربياً عنده يقرأ «25»
 * بالإنجليزية، والطفلُ يسمع «twenty five» في درس الأرقام العربية.
 */
export function arabicNumberWords(n: number): string {
  if (n === 100) return "مئة";
  if (n < 20) return AR_UNITS[n];
  const unit = n % 10;
  const tens = AR_TENS[Math.floor(n / 10)];
  return unit === 0 ? tens : `${AR_UNITS[unit]} و${tens}`;
}

const EN_UNITS = [
  "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
  "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen",
];
const EN_TENS = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"];

/** العددُ كلماتٍ إنجليزية، من zero إلى one hundred. */
export function englishNumberWords(n: number): string {
  if (n === 100) return "one hundred";
  if (n < 20) return EN_UNITS[n];
  const unit = n % 10;
  const tens = EN_TENS[Math.floor(n / 10)];
  return unit === 0 ? tens : `${tens} ${EN_UNITS[unit]}`;
}

/** الصفُّ الوحيد الذي تظهر فيه لعبةُ التتبّع. */
export const KINDERGARTEN_GRADE = "روضة منارة المعرفة";

export type AlphabetSet = "arabic_letters" | "english_letters" | "arabic_digits" | "english_digits";

function subjectKey(value: string): string {
  return stripMarks(value)
    .toLowerCase()
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * مادّةُ روضةٍ تُتتبّع فيها المجموعةُ كاملة: «الحروف العربية»، «الحروف
 * الإنجليزية»، «الأرقام العربية»، «الأرقام الإنجليزية» — بأيّ همزةٍ أو تاءٍ
 * مربوطةٍ كُتبت، وبالإنجليزية كذلك. `null` لأيّ مادّةٍ أخرى.
 */
export function alphabetSetOf(subject: string): AlphabetSet | null {
  const key = subjectKey(subject);
  const english = /انجليز|انكليز|english/.test(key);
  const arabic = /عربي|arabic/.test(key);
  if (/حروف|الحرف|letters|alphabet/.test(key)) {
    if (english) return "english_letters";
    if (arabic) return "arabic_letters";
  }
  if (/ارقام|اعداد|numbers|digits/.test(key)) {
    if (english) return "english_digits";
    if (arabic) return "arabic_digits";
  }
  return null;
}

/** صفُّ «روضة منارة المعرفة» بأيّ همزةٍ أو تاءٍ مربوطةٍ أو مسافةٍ كُتب. */
export function isKindergartenGrade(grade: string): boolean {
  return subjectKey(grade) === subjectKey(KINDERGARTEN_GRADE);
}

/**
 * مجموعةُ التتبّع لدرسٍ، أو `null`: الصفُّ «روضة منارة المعرفة» **و**المادّةُ
 * إحدى الأربع معاً. أيُّ صفٍّ آخر أو مادّةٍ أخرى: لا لعبةَ تتبّع أصلاً، وتبقى
 * للدرس ألعابُه العادية.
 */
export function tracingSetFor(lesson: { subject?: string; grade?: string }): AlphabetSet | null {
  if (!isKindergartenGrade(lesson.grade ?? "")) return null;
  return alphabetSetOf(lesson.subject ?? "");
}

/** المجموعةُ كاملةً بترتيبها، لا أوّلُ ستّةٍ منها. */
export function alphabetItems(set: AlphabetSet): TracingItem[] {
  switch (set) {
    case "arabic_letters":
      return ARABIC_LETTERS.map(([text, speech]) => ({ text, kind: "letter", lang: "ar", speech }));
    case "english_letters":
      // الكبيرُ والصغيرُ معاً: «Aa» يُتتبّع جرّاتٍ ويُنطق «A».
      return Array.from({ length: 26 }, (_, i) => {
        const upper = String.fromCharCode(65 + i);
        return { text: `${upper}${upper.toLowerCase()}`, kind: "letter" as const, lang: "en" as const, speech: upper };
      });
    // من الصفر إلى المئة. ويُنطق العددُ بأرقامه الغربية: محرّكُ النطق يقرأ
    // «25» بالعربية «خمسة وعشرون» وبالإنجليزية «twenty five» — أصحُّ من
    // جدولِ أسماءٍ مكتوبٍ باليد لمئة عدد.
    case "arabic_digits":
      return Array.from({ length: NUMBERS_MAX + 1 }, (_, n) => ({
        text: toArabicIndic(String(n)),
        kind: "number" as const,
        lang: "ar" as const,
        speech: arabicNumberWords(n),
      }));
    case "english_digits":
      return Array.from({ length: NUMBERS_MAX + 1 }, (_, n) => ({
        text: String(n),
        kind: "number" as const,
        lang: "en" as const,
        speech: englishNumberWords(n),
      }));
  }
}

/**
 * من أيّ عنصرٍ تبدأ اللعبة: حرفُ الدرس إن ذكره عنوانه («حرف الباء» يفتح
 * على الباء، و«العدد ٥» على الخمسة)، وإلا أوّلُ المجموعة. والمجموعةُ كلُّها
 * متاحةٌ في الحالين.
 */
export function alphabetStart(items: TracingItem[], title: string): number {
  const lang = items[0]?.lang ?? "ar";
  const wanted = [...lettersIn(title, lang), ...numbersIn(title)];
  for (const value of wanted) {
    // «العدد ٢٥» يفتح على ٢٥ أيّاً كانت أرقامُ المادّة.
    const number = toWesternDigits(value);
    const at = items.findIndex(
      (item) =>
        item.text === value ||
        (item.kind === "number" && toWesternDigits(item.text) === number) ||
        (item.kind === "letter" && item.text.startsWith(value.toUpperCase())),
    );
    if (at >= 0) return at;
  }
  return 0;
}

/**
 * مفتاحُ مكافأة حرفٍ في سجلّ الطالب، أو `null` إن لم يكن [item] من مجموعة
 * الدرس — فلا يُصرف لنصٍّ يرسله التطبيقُ من عنده، ولا يُكتب في السجلّ
 * مفتاحٌ بطولٍ يختاره هو.
 */
export function tracingRewardKey(
  lesson: { id: string; subject?: string; grade?: string },
  item: string,
): string | null {
  const set = tracingSetFor(lesson);
  if (!set || !alphabetItems(set).some((entry) => entry.text === item)) return null;
  return `tracing:${lesson.id}:${item}`;
}

// ── اللعبة ───────────────────────────────────────────────────────────

/** لعبةُ التتبّع بصيغة بقيّة ألعاب البطاقة، من عناصرَ جاهزة. */
export function tracingGame(items: TracingItem[], { start = 0 }: { start?: number } = {}): StudyGame | null {
  if (items.length === 0) return null;
  const en = items[0].lang === "en";
  return {
    id: TRACING_GAME_ID,
    // ليس في GAME_TYPES: نموذجُ الحزمة لا يولّدها ومخطّطُه لا يعرفها.
    game_type: TRACING_GAME_ID,
    title: en ? "Trace and write!" : "تتبّع واكتب!",
    instructions: en
      ? "Tap a letter or number to hear it, then trace it."
      : "المس حرفاً أو رقماً لتسمعه، ثم تتبّعه بإصبعك.",
    items: {
      drag_items: [],
      drop_targets: [],
      correct_pairs: [],
      tracing: items,
      start: Math.min(Math.max(0, start), items.length - 1),
    },
    gems_reward: TRACING_REWARD.gems,
    points_reward: TRACING_REWARD.points,
  };
}

/** مجموعةُ الروضة الكاملة لدرسها، أو `null` خارج الروضة وموادّها الأربع. */
export function alphabetGame(lesson: { title: string; subject?: string; grade?: string }): StudyGame | null {
  const set = tracingSetFor(lesson);
  if (!set) return null;
  const items = alphabetItems(set);
  return tracingGame(items, { start: alphabetStart(items, lesson.title) });
}

/** يضيف لعبةَ التتبّع إلى ألعاب الدرس، ولا يكرّرها إن وُجدت. */
export function withTracingGame<T extends { games: StudyGame[] }>(pack: T, tracing: StudyGame | null): T {
  if (!tracing || pack.games.some((game) => game.id === TRACING_GAME_ID)) return pack;
  return { ...pack, games: [...pack.games, tracing] };
}

export function lessonTitleOf(lesson: Record<string, unknown>): string {
  return [text(lesson.unit), text(lesson.lesson)].filter(Boolean).join(" — ");
}
