/**
 * لعبةُ «تتبّع الحروف والأرقام والكلمات» في بطاقة المذاكرة.
 *
 * ── ثلاثةُ مصادر ──
 * - مادّةُ حروفٍ أو أرقام في الروضة ([alphabetSetOf]): المجموعةُ كاملة —
 *   ٢٨ حرفاً عربياً، و٢٦ إنجليزياً، وعشرةُ أرقام — ومع كلٍّ اسمُه للنطق.
 *   ولا تحتاج نصّاً: درسُ الروضة كثيراً ما يكون بلا شرحٍ مكتوب.
 * - غيرُها: أسئلةٌ يولّدها الذكاء الاصطناعي من نصّ الدرس (`tracingQuiz.ts`)،
 *   يختار الطفلُ الإجابة ثم يتتبّعها.
 * - وإن تعذّر النموذج: ما يُستخرج من النصّ هنا بلا نموذج ([tracingItemsFrom]).
 *
 * ── من نصّ المعلم، بلا نموذج ──
 * ما يُتتبّع يُستخرج هنا من عنوان الدرس ونصّه: «حرف الباء» حرفٌ، و«العدد ٥»
 * رقم، وأكثرُ الكلمات القصيرة تكراراً كلمات. لا يُسأل النموذج: الاستخراجُ
 * فوريّ ومجّاني، ولا يُبطل حزمَ الألعاب المحفوظة مع الدروس كما يفعل تغييرُ
 * مخطّطها. ومساراتُ التتبّع نفسها لا تُرسل من هنا: يبنيها التطبيقُ من شكل
 * الحرف في خطّه، فتطابق ما يراه الطفل حرفاً حرفاً.
 *
 * ── والمكافأةُ ثابتة ──
 * لا حزمةَ محفوظة تُقرأ منها، فتُصرف [TRACING_REWARD] لدرسٍ في مسار الطالب
 * فيه ما يُتتبّع — مرّةً واحدة كبقيّة الألعاب (`درس::tracing`).
 *
 * بلا شبكة ولا قاعدة بيانات، فيُختبر وحده.
 */
import type { StudyGame, TracingItem } from "./studyGames";

export type { TracingItem };

export const TRACING_GAME_ID = "tracing" as const;

export type TracingKind = TracingItem["kind"];
export type TracingLang = TracingItem["lang"];

/** داخل حدود [REWARD_LIMITS] في `studyGames.ts`. */
export const TRACING_REWARD = { gems: 6, points: 30 } as const;

/** ما يتّسع له تمرينٌ واحد قبل أن يملّ الطفل. */
export const TRACING_MAX_ITEMS = 6;
const MAX_WORD_LETTERS = { ar: 5, en: 6 } as const;

// بالرموز لا بالحروف: نطاقُ «ً-ٰ» المكتوب بحروفه يشمل الأرقامَ الهندية ٠-٩
// (U+0660–0669) فيمحوها.
const TASHKEEL = /[ً-ٰٟـ]/g;
const AR_WORD = /^[ء-ي]+$/;
const EN_WORD = /^[A-Za-z]+$/;

/** أسماءُ الحروف كما يكتبها المعلم: «حرف الباء» → ب. */
const ARABIC_LETTER_NAMES: Record<string, string> = {
  الالف: "ا", الألف: "ا", الهمزه: "ء", الهمزة: "ء",
  الباء: "ب", التاء: "ت", الثاء: "ث", الجيم: "ج", الحاء: "ح", الخاء: "خ",
  الدال: "د", الذال: "ذ", الراء: "ر", الزاي: "ز", الزاء: "ز", السين: "س",
  الشين: "ش", الصاد: "ص", الضاد: "ض", الطاء: "ط", الظاء: "ظ", العين: "ع",
  الغين: "غ", الفاء: "ف", القاف: "ق", الكاف: "ك", اللام: "ل", الميم: "م",
  النون: "ن", الهاء: "ه", الواو: "و", الياء: "ي",
};

const AR_STOPWORDS = new Set([
  "في", "من", "على", "الى", "إلى", "عن", "مع", "هذا", "هذه", "ذلك", "تلك", "التي", "الذي",
  "هو", "هي", "هم", "نحن", "انت", "أنت", "كان", "كانت", "يكون", "او", "أو", "ثم", "لا", "لم",
  "لن", "ما", "ماذا", "متى", "اين", "أين", "كيف", "كل", "بعض", "قد", "لقد", "عند", "بين", "حتى",
  "إن", "ان", "أن", "إذا", "اذا", "لكن", "بل", "يا", "ها", "هنا", "هناك", "نعم", "حرف", "الحرف",
  "رقم", "الرقم", "العدد", "عدد", "درس", "الدرس", "وحدة", "الوحدة", "نشاط", "تمرين", "اكتب",
  "اقرأ", "لون", "ارسم", "صل", "مع", "الطفل", "الطالب", "الاطفال", "الأطفال",
]);

const EN_STOPWORDS = new Set([
  "the", "and", "for", "with", "this", "that", "are", "was", "you", "your", "his", "her", "its",
  "our", "they", "them", "have", "has", "had", "not", "but", "can", "will", "from", "into", "what",
  "who", "how", "when", "where", "why", "lesson", "unit", "letter", "number", "write", "read",
  "trace", "color", "colour", "draw", "match", "page",
]);

function text(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function stripMarks(value: string): string {
  return value.replace(TASHKEEL, "");
}

/** الأرقامُ كما كُتبت: ١٢ تبقى ١٢، و12 تبقى 12 — الطفلُ يتتبّع ما في كتابه. */
function isDigits(value: string): boolean {
  return /^(?:[0-9]{1,2}|[٠-٩]{1,2})$/.test(value);
}

/** لغةُ الدرس: مادّةُ الإنجليزية، أو نصٌّ حروفُه اللاتينية أكثر. */
export function tracingLangOf(subject: string, sample: string): TracingLang {
  if (/english|انجليز|إنجليز/i.test(subject)) return "en";
  const latin = (sample.match(/[A-Za-z]/g) ?? []).length;
  const arabic = (sample.match(/[ء-ي]/g) ?? []).length;
  return latin > arabic ? "en" : "ar";
}

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
  for (const match of source.matchAll(/(?:رقم|الرقم|العدد|number)\s+([0-9٠-٩]{1,2})(?![0-9٠-٩])/gi)) {
    out.push(match[1]);
  }
  return out;
}

/** الكلماتُ القصيرة الأكثر ذكراً؛ وما في العنوان يُقدَّم، وما فيه حرفُ الدرس كذلك. */
function wordsIn(title: string, body: string, lang: TracingLang, letters: string[]): string[] {
  const score = new Map<string, number>();
  const firstSeen = new Map<string, number>();
  let order = 0;
  const visit = (source: string, weight: number) => {
    for (const raw of stripMarks(source).split(/[^ء-يA-Za-z]+/)) {
      const word = lang === "en" ? raw.toLowerCase() : raw;
      if (word.length < 2 || word.length > MAX_WORD_LETTERS[lang]) continue;
      if (lang === "ar" ? !AR_WORD.test(word) || AR_STOPWORDS.has(word) : !EN_WORD.test(word) || EN_STOPWORDS.has(word)) {
        continue;
      }
      if (ARABIC_LETTER_NAMES[word]) continue;
      score.set(word, (score.get(word) ?? 0) + weight);
      if (!firstSeen.has(word)) firstSeen.set(word, order++);
    }
  };
  visit(title, 3);
  visit(body, 1);
  const letterBonus = (word: string) =>
    letters.some((letter) => word.includes(letter.toLowerCase()) || word.includes(letter)) ? 2 : 0;
  return [...score.keys()].sort(
    (a, b) =>
      score.get(b)! + letterBonus(b) - (score.get(a)! + letterBonus(a)) ||
      firstSeen.get(a)! - firstSeen.get(b)!,
  );
}

/**
 * ما يتتبّعه الطفل من هذا الدرس: الحروفُ ثم الأرقامُ ثم الكلمات، بلا تكرار.
 * قائمةٌ فارغة إن لم يُوجد ما يُتتبّع.
 */
export function tracingItemsFrom({
  title,
  text: body,
  subject = "",
}: {
  title: string;
  text: string;
  subject?: string;
}): TracingItem[] {
  const source = `${title}\n${body}`;
  const lang = tracingLangOf(subject, source);
  const items: TracingItem[] = [];
  const seen = new Set<string>();
  const add = (value: string, kind: TracingKind) => {
    const clean = stripMarks(value).trim();
    if (!clean || seen.has(clean) || items.length >= TRACING_MAX_ITEMS) return;
    seen.add(clean);
    items.push({ text: clean, kind, lang });
  };

  const letters = lettersIn(source, lang);
  for (const letter of letters) add(letter, "letter");
  for (const number of numbersIn(source)) if (isDigits(number)) add(number, "number");
  for (const word of wordsIn(title, body, lang, letters)) add(word, "word");
  return items;
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

const ARABIC_DIGITS: readonly (readonly [string, string])[] = [
  ["٠", "صفر"], ["١", "واحد"], ["٢", "اثنان"], ["٣", "ثلاثة"], ["٤", "أربعة"],
  ["٥", "خمسة"], ["٦", "ستة"], ["٧", "سبعة"], ["٨", "ثمانية"], ["٩", "تسعة"],
];

const ENGLISH_DIGITS: readonly (readonly [string, string])[] = [
  ["0", "zero"], ["1", "one"], ["2", "two"], ["3", "three"], ["4", "four"],
  ["5", "five"], ["6", "six"], ["7", "seven"], ["8", "eight"], ["9", "nine"],
];

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
    case "arabic_digits":
      return ARABIC_DIGITS.map(([text, speech]) => ({ text, kind: "number", lang: "ar", speech }));
    case "english_digits":
      return ENGLISH_DIGITS.map(([text, speech]) => ({ text, kind: "number", lang: "en", speech }));
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
    const at = items.findIndex((item) => item.text === value || item.text.startsWith(value.toUpperCase()));
    if (at >= 0) return at;
  }
  return 0;
}

/** بعد كم عنصراً تُصرف المكافأة: المجموعاتُ طويلة، فلا ينتظر الطفلُ ٢٨ حرفاً. */
export const ALPHABET_REWARD_AFTER = 5;

// ── اللعبة ───────────────────────────────────────────────────────────

/** لعبةُ التتبّع بصيغة بقيّة ألعاب البطاقة، من عناصرَ جاهزة. */
export function tracingGame(
  items: TracingItem[],
  { rewardAfter = items.length, start = 0 }: { rewardAfter?: number; start?: number } = {},
): StudyGame | null {
  if (items.length === 0) return null;
  const en = items[0].lang === "en";
  const quiz = items.some((item) => item.prompt);
  return {
    id: TRACING_GAME_ID,
    // ليس في GAME_TYPES: نموذجُ الحزمة لا يولّدها ومخطّطُه لا يعرفها.
    game_type: TRACING_GAME_ID,
    title: quiz ? (en ? "Answer and trace!" : "أجب وتتبّع!") : en ? "Trace and write!" : "تتبّع واكتب!",
    instructions: quiz
      ? en
        ? "Pick the right answer, then trace it with your finger."
        : "اختر الإجابة الصحيحة، ثم تتبّعها بإصبعك."
      : en
        ? "Follow the dots in order with your finger."
        : "مرّر إصبعك على النقاط بالترتيب من البداية.",
    items: {
      drag_items: [],
      drop_targets: [],
      correct_pairs: [],
      tracing: items,
      reward_after: Math.min(Math.max(1, rewardAfter), items.length),
      start: Math.min(Math.max(0, start), items.length - 1),
    },
    gems_reward: TRACING_REWARD.gems,
    points_reward: TRACING_REWARD.points,
  };
}

/** من نصّ الدرس بلا نموذج — بديلُ أسئلة الذكاء الاصطناعي إن تعذّرت. */
export function buildTracingGame(lesson: { title: string; text: string; subject?: string }): StudyGame | null {
  return tracingGame(tracingItemsFrom(lesson));
}

/** مجموعةُ الروضة الكاملة لمادّتها، أو `null` إن لم تكن مادّةَ حروفٍ أو أرقام. */
export function alphabetGame(lesson: { title: string; subject?: string }): StudyGame | null {
  const set = alphabetSetOf(lesson.subject ?? "");
  if (!set) return null;
  const items = alphabetItems(set);
  return tracingGame(items, {
    rewardAfter: ALPHABET_REWARD_AFTER,
    start: alphabetStart(items, lesson.title),
  });
}

/** يضيف لعبةَ التتبّع إلى ألعاب الدرس، ولا يكرّرها إن وُجدت. */
export function withTracingGame<T extends { games: StudyGame[] }>(pack: T, tracing: StudyGame | null): T {
  if (!tracing || pack.games.some((game) => game.id === TRACING_GAME_ID)) return pack;
  return { ...pack, games: [...pack.games, tracing] };
}

export function lessonTitleOf(lesson: Record<string, unknown>): string {
  return [text(lesson.unit), text(lesson.lesson)].filter(Boolean).join(" — ");
}
