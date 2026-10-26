/**
 * لعبةُ «تتبّع الحروف والأرقام والكلمات» في بطاقة المذاكرة.
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

/** اللعبةُ بصيغة بقيّة ألعاب البطاقة، أو `null` إن لم يكن في الدرس ما يُتتبّع. */
export function buildTracingGame(lesson: {
  title: string;
  text: string;
  subject?: string;
}): StudyGame | null {
  const items = tracingItemsFrom(lesson);
  if (items.length === 0) return null;
  const en = items[0].lang === "en";
  return {
    id: TRACING_GAME_ID,
    // ليس في GAME_TYPES: النموذجُ لا يولّدها ومخطّطُه لا يعرفها.
    game_type: TRACING_GAME_ID,
    title: en ? "Trace and write!" : "تتبّع واكتب!",
    instructions: en
      ? "Follow the dots in order with your finger."
      : "مرّر إصبعك على النقاط بالترتيب من البداية.",
    items: { drag_items: [], drop_targets: [], correct_pairs: [], tracing: items },
    gems_reward: TRACING_REWARD.gems,
    points_reward: TRACING_REWARD.points,
  };
}

/** يضيف لعبةَ التتبّع إلى ألعاب الدرس، ولا يكرّرها إن وُجدت. */
export function withTracingGame<T extends { games: StudyGame[] }>(
  pack: T,
  lesson: { title: string; text: string; subject?: string },
): T {
  if (pack.games.some((game) => game.id === TRACING_GAME_ID)) return pack;
  const tracing = buildTracingGame(lesson);
  return tracing ? { ...pack, games: [...pack.games, tracing] } : pack;
}

export function lessonTitleOf(lesson: Record<string, unknown>): string {
  return [text(lesson.unit), text(lesson.lesson)].filter(Boolean).join(" — ");
}
