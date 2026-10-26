import { fullLessonText } from "./lessonText";
/**
 * ألعابُ «بطاقة المذاكرة» التفاعلية: تُولَّد من نصّ الدرس بالذكاء الاصطناعي.
 *
 * ثلاثُ ألعابٍ لكل درس:
 *   drag_drop     اسحب كلَّ بطاقةٍ إلى سلّتها (تصنيف).
 *   matching      صِل كلَّ مفهومٍ بمعناه (أزواج).
 *   endless_quiz  أسئلةٌ سريعةٌ متتالية بلا نهاية حتى تنفد المحاولات.
 *
 * ── الصيغة (Strict JSON) ──
 *   { game_type, title, instructions,
 *     items: { drag_items, drop_targets, correct_pairs, questions? },
 *     gems_reward, points_reward }
 *
 * ── والمكافأةُ يحسمها الخادم ──
 * النموذجُ يقترح الجواهر والنقاط، وتُحصر هنا في [REWARD_LIMITS] قبل أن
 * تُحفظ مع الدرس. والتطبيقُ لا يرسل مقداراً: يقول «فاز في اللعبة كذا»،
 * فيقرأ الخادمُ مكافأتها من سجلّ الدرس، ويصرفها مرّةً واحدة لكل لعبة.
 *
 * بلا شبكة ولا قاعدة بيانات، فيُختبر وحده.
 */

/// ٢: سباقٌ أغنى — ٢٠ إلى ٤٠ سؤالاً بثلاثة أشكال (اختيار، صح/خطأ، أكمل الفراغ).
/// والحزمُ الأقدم تُولَّد من جديد بالشكل الجديد.
/// ٣: نصُّ الدرس كاملاً (كان يُقطع عند ١٠٠٠٠ حرف).
export const STUDY_GAMES_VERSION = 3;

/** أشكالُ أسئلة السباق: تتبدّل فلا يملّ الطفل ولا يحفظ نمطاً. */
export const QUESTION_KINDS = ["mcq", "true_false", "fill_blank"] as const;
export type QuestionKind = (typeof QUESTION_KINDS)[number];
export const TRUE_FALSE = ["صح", "خطأ"] as const;
export const TRUE_FALSE_EN = ["True", "False"] as const;

export const GAME_TYPES = ["drag_drop", "matching", "endless_quiz"] as const;
export type StudyGameType = (typeof GAME_TYPES)[number];

/**
 * كلُّ ألعاب البطاقة، ومنها «التتبّع» التي لا يولّدها النموذج بل تُبنى من نصّ
 * الدرس (`tracing.ts`) — فلا تدخل [GAME_TYPES] ولا مخطّطَه.
 */
export type StudyGameKind = StudyGameType | "tracing";
export const REWARDABLE_GAME_IDS: readonly StudyGameKind[] = [...GAME_TYPES, "tracing"];

/** حرفٌ أو رقمٌ أو كلمةٌ يتتبّعها الطفل؛ والمسارُ يبنيه التطبيقُ من خطّه. */
export interface TracingItem {
  text: string;
  kind: "letter" | "number" | "word";
  lang: "ar" | "en";
}

export const REWARD_LIMITS = {
  gems: { min: 3, max: 12 },
  points: { min: 10, max: 60 },
} as const;

/** حدودُ كل لعبة: ما يتّسع له هاتفُ طفلٍ دون تمرير. */
export const LIMITS = {
  dragItems: { min: 4, max: 8 },
  dropTargets: { min: 2, max: 3 },
  pairs: { min: 3, max: 6 },
  questions: { min: 12, max: 40 },
} as const;

export interface CorrectPair {
  item: string;
  target: string;
}

export interface QuickQuestion {
  kind: QuestionKind;
  question: string;
  options: string[];
  answer: string;
}

export interface StudyGame {
  id: string;
  game_type: StudyGameKind;
  title: string;
  instructions: string;
  items: {
    drag_items: string[];
    drop_targets: string[];
    correct_pairs: CorrectPair[];
    questions?: QuickQuestion[];
    tracing?: TracingItem[];
  };
  gems_reward: number;
  points_reward: number;
}

export interface StudyGamesPack {
  version: number;
  lessonId: string;
  lessonStamp: string;
  generatedAt: string;
  games: StudyGame[];
}

export const STUDY_GAMES_SYSTEM_INSTRUCTION = `أنت مصمّم ألعاب تعليمية للأطفال في منصّة عربية. تبني من نصّ الدرس ثلاث ألعاب قصيرة ممتعة تُثبّت مفاهيمه.

ضوابط:
- كل محتوى مأخوذ من الدرس المرفق وحده، صحيح علمياً، بلا معلومات من خارجه.
- لغة عربية بسيطة مناسبة لعمر الطالب، وعبارات قصيرة جداً (كلمة إلى خمس كلمات للبطاقة).
- العنوان حماسي قصير، والإرشادات جملة واحدة موجّهة للطفل بصيغة المخاطب.
- إن كانت مادة الدرس اللغة الإنجليزية فاكتب محتوى الألعاب بالإنجليزية.

الألعاب الثلاث بالترتيب:
1) "drag_drop": تصنيف. "drop_targets" من 2 إلى 3 سلال (فئات من الدرس)، و"drag_items" من 6 إلى 8 بطاقات، و"correct_pairs" يربط كل بطاقة بسلّتها الصحيحة (item = نص البطاقة حرفياً، target = اسم السلة حرفياً). كل بطاقة تنتمي لسلة واحدة فقط بلا لبس.
2) "matching": مطابقة. "drag_items" من 4 إلى 6 مفاهيم، و"drop_targets" معانيها أو أمثلتها بالعدد نفسه، و"correct_pairs" تربط كل مفهوم بمعناه واحداً لواحد.
3) "endless_quiz": سباق أسئلة غني ومتنوّع. "questions" من 30 إلى 40 سؤالاً تغطي الدرس كله، متدرّجة من السهل إلى الصعب، بثلاثة أشكال تتناوب ("kind"):
   - "mcq": اختيار من متعدد، 3 أو 4 خيارات قصيرة.
   - "true_false": عبارة يحكم عليها الطفل، والخياران بالضبط ["صح","خطأ"] (أو ["True","False"] للإنجليزية).
   - "fill_blank": جملة فيها فراغ يُكتب "____"، و3 خيارات لكلمة الفراغ.
   نحو نصفها "mcq" وربعها لكلٍّ من الآخرَين. "answer" نص الخيار الصحيح حرفياً. الأسئلة تقيس الفهم والتطبيق لا الحفظ الحرفي، ولا يتكرر سؤال بصياغة أخرى. واترك "drag_items" و"drop_targets" و"correct_pairs" فارغة.

المكافآت: "gems_reward" بين ${REWARD_LIMITS.gems.min} و${REWARD_LIMITS.gems.max} بحسب صعوبة اللعبة، و"points_reward" بين ${REWARD_LIMITS.points.min} و${REWARD_LIMITS.points.max}.

أخرج JSON فقط مطابقاً للمخطط، بلا أي نص آخر.`;

const STRING_ARRAY = { type: "ARRAY", items: { type: "STRING" } } as const;

/** مخطّطُ الردّ بصيغة Gemini (`generationConfig.responseSchema`). */
export const STUDY_GAMES_SCHEMA = {
  type: "OBJECT",
  properties: {
    games: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          game_type: { type: "STRING", enum: [...GAME_TYPES] },
          title: { type: "STRING" },
          instructions: { type: "STRING" },
          items: {
            type: "OBJECT",
            properties: {
              drag_items: STRING_ARRAY,
              drop_targets: STRING_ARRAY,
              correct_pairs: {
                type: "ARRAY",
                items: {
                  type: "OBJECT",
                  properties: { item: { type: "STRING" }, target: { type: "STRING" } },
                  required: ["item", "target"],
                },
              },
              questions: {
                type: "ARRAY",
                items: {
                  type: "OBJECT",
                  properties: {
                    kind: { type: "STRING", enum: [...QUESTION_KINDS] },
                    question: { type: "STRING" },
                    options: STRING_ARRAY,
                    answer: { type: "STRING" },
                  },
                  required: ["kind", "question", "options", "answer"],
                },
              },
            },
            required: ["drag_items", "drop_targets", "correct_pairs"],
          },
          gems_reward: { type: "INTEGER" },
          points_reward: { type: "INTEGER" },
        },
        required: ["game_type", "title", "instructions", "items", "gems_reward", "points_reward"],
        propertyOrdering: ["game_type", "title", "instructions", "items", "gems_reward", "points_reward"],
      },
    },
  },
  required: ["games"],
} as const;

export function studyGamesPrompt({
  lessonTitle,
  lessonText,
  subject,
  grade,
}: {
  lessonTitle: string;
  lessonText: string;
  subject?: string;
  grade?: string;
}): string {
  const context = [
    grade ? `- الصف: ${grade}` : "",
    subject ? `- المادة: ${subject}` : "",
    lessonTitle ? `- الدرس: ${lessonTitle}` : "",
  ]
    .filter(Boolean)
    .join("\n");
  // ‏النصُّ كاملاً: الألعابُ تغطي الدرسَ كلَّه لا أوّلَه.
  const text = fullLessonText(lessonText);
  return `ابنِ الألعاب الثلاث (drag_drop ثم matching ثم endless_quiz) من هذا الدرس.
${context ? `\n${context}\n` : ""}
نص الدرس:
"""
${text.trim()}
"""`;
}

function clean(value: unknown, max = 120): string {
  return typeof value === "string" ? value.replace(/\s+/g, " ").trim().slice(0, max) : "";
}

function key(value: string): string {
  return value
    .toLowerCase()
    .replace(/[ً-ْٰـ]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim();
}

function uniqueStrings(value: unknown, max: number): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const item of Array.isArray(value) ? value : []) {
    const text = clean(item, 80);
    const k = key(text);
    if (!text || !k || seen.has(k)) continue;
    seen.add(k);
    out.push(text);
    if (out.length >= max) break;
  }
  return out;
}

function clampInt(value: unknown, { min, max }: { min: number; max: number }): number {
  const n = Math.round(Number(value));
  return Number.isFinite(n) ? Math.min(Math.max(n, min), max) : min;
}

/** يربط نصّاً بعنصرٍ من القائمة بعد التسوية، أو `null`. */
function resolve(list: string[], value: unknown): string | null {
  const wanted = key(clean(value, 80));
  return wanted ? list.find((item) => key(item) === wanted) ?? null : null;
}

function parsePairs(raw: unknown, items: string[], targets: string[]): CorrectPair[] {
  const pairs: CorrectPair[] = [];
  const used = new Set<string>();
  for (const entry of Array.isArray(raw) ? raw : []) {
    if (!entry || typeof entry !== "object") continue;
    const record = entry as Record<string, unknown>;
    const item = resolve(items, record.item);
    const target = resolve(targets, record.target);
    if (!item || !target || used.has(item)) continue;
    used.add(item);
    pairs.push({ item, target });
  }
  return pairs;
}

function parseDragDrop(items: Record<string, unknown>): StudyGame["items"] | null {
  const targets = uniqueStrings(items.drop_targets, LIMITS.dropTargets.max);
  const candidates = uniqueStrings(items.drag_items, 20);
  if (targets.length < LIMITS.dropTargets.min) return null;
  // ما لا سلّةَ له لا يُسحب: بطاقةٌ لا موضع صحيحاً لها لعبةٌ لا تُكسب.
  const pairs = parsePairs(items.correct_pairs, candidates, targets).slice(0, LIMITS.dragItems.max);
  if (pairs.length < LIMITS.dragItems.min) return null;
  // وكلُّ سلّةٍ فيها بطاقةٌ على الأقل.
  const filled = new Set(pairs.map((pair) => pair.target));
  const usedTargets = targets.filter((target) => filled.has(target));
  if (usedTargets.length < LIMITS.dropTargets.min) return null;
  return {
    drag_items: pairs.map((pair) => pair.item),
    drop_targets: usedTargets,
    correct_pairs: pairs,
  };
}

function parseMatching(items: Record<string, unknown>): StudyGame["items"] | null {
  const left = uniqueStrings(items.drag_items, 12);
  const right = uniqueStrings(items.drop_targets, 12);
  const pairs: CorrectPair[] = [];
  const usedTargets = new Set<string>();
  for (const pair of parsePairs(items.correct_pairs, left, right)) {
    // واحدٌ لواحد: معنىً لمفهومين يجعل المطابقةَ تخميناً.
    if (usedTargets.has(pair.target)) continue;
    usedTargets.add(pair.target);
    pairs.push(pair);
    if (pairs.length >= LIMITS.pairs.max) break;
  }
  if (pairs.length < LIMITS.pairs.min) return null;
  return {
    drag_items: pairs.map((pair) => pair.item),
    drop_targets: pairs.map((pair) => pair.target),
    correct_pairs: pairs,
  };
}

function parseQuestions(items: Record<string, unknown>): StudyGame["items"] | null {
  const questions: QuickQuestion[] = [];
  const seen = new Set<string>();
  for (const entry of Array.isArray(items.questions) ? items.questions : []) {
    if (!entry || typeof entry !== "object") continue;
    const record = entry as Record<string, unknown>;
    const kind: QuestionKind = (QUESTION_KINDS as readonly string[]).includes(String(record.kind))
      ? (record.kind as QuestionKind)
      : "mcq";
    const question = clean(record.question, 200);
    const options = uniqueStrings(record.options, 4);
    const answer = resolve(options, record.answer);
    if (question.length < 5 || !answer || seen.has(key(question))) continue;
    // ‏كلُّ شكلٍ بخياراته: صح/خطأ اثنان بالضبط، وأكمل الفراغ فيه فراغ.
    const isTrueFalse =
      options.length === 2 &&
      [TRUE_FALSE, TRUE_FALSE_EN].some((pair) => pair.every((word) => options.some((o) => key(o) === key(word))));
    if (kind === "true_false" && !isTrueFalse) continue;
    if (kind === "fill_blank" && !/_{2,}|\.{3,}|…/.test(question)) continue;
    if (kind !== "true_false" && (options.length < 3 || options.length > 4)) continue;
    seen.add(key(question));
    questions.push({ kind, question, options, answer });
    if (questions.length >= LIMITS.questions.max) break;
  }
  if (questions.length < LIMITS.questions.min) return null;
  return { drag_items: [], drop_targets: [], correct_pairs: [], questions };
}

function parseGame(raw: unknown, type: StudyGameType): StudyGame | null {
  if (!raw || typeof raw !== "object") return null;
  const record = raw as Record<string, unknown>;
  const items = record.items && typeof record.items === "object" ? (record.items as Record<string, unknown>) : {};
  const parsed =
    type === "drag_drop" ? parseDragDrop(items) : type === "matching" ? parseMatching(items) : parseQuestions(items);
  if (!parsed) return null;
  return {
    id: type,
    game_type: type,
    title: clean(record.title, 60) || DEFAULT_TITLES[type],
    instructions: clean(record.instructions, 160) || DEFAULT_INSTRUCTIONS[type],
    items: parsed,
    gems_reward: clampInt(record.gems_reward, REWARD_LIMITS.gems),
    points_reward: clampInt(record.points_reward, REWARD_LIMITS.points),
  };
}

const DEFAULT_TITLES: Record<StudyGameType, string> = {
  drag_drop: "اسحب وصنّف!",
  matching: "صِل المتشابهين!",
  endless_quiz: "سباق الأسئلة!",
};

const DEFAULT_INSTRUCTIONS: Record<StudyGameType, string> = {
  drag_drop: "اسحب كل بطاقة إلى السلة التي تناسبها.",
  matching: "اسحب كل كلمة إلى معناها الصحيح.",
  endless_quiz: "أجب بسرعة واجمع النجوم قبل أن تنفد قلوبك!",
};

function extract(raw: unknown): unknown[] {
  let value = raw;
  if (typeof value === "string") {
    const cleaned = value.replace(/^\s*```(?:json)?\s*/i, "").replace(/\s*```\s*$/i, "").trim();
    try {
      value = JSON.parse(cleaned);
    } catch {
      const start = cleaned.indexOf("{");
      const end = cleaned.lastIndexOf("}");
      if (start < 0 || end <= start) return [];
      try {
        value = JSON.parse(cleaned.slice(start, end + 1));
      } catch {
        return [];
      }
    }
  }
  if (Array.isArray(value)) return value;
  if (value && typeof value === "object" && Array.isArray((value as { games?: unknown }).games)) {
    return (value as { games: unknown[] }).games;
  }
  return [];
}

/**
 * الألعابُ الصالحة من ردّ النموذج، لعبةٌ واحدة لكل نوع بترتيب [GAME_TYPES].
 * و`null` إن لم تصلح لعبةٌ واحدة — فلا يُحفظ فارغٌ يبقى فارغاً.
 */
export function parseStudyGames(
  raw: unknown,
  owner: { lessonId: string; lessonStamp: string },
  now = new Date().toISOString(),
): StudyGamesPack | null {
  const entries = extract(raw);
  const games: StudyGame[] = [];
  for (const type of GAME_TYPES) {
    const candidate = entries.find(
      (entry) => entry && typeof entry === "object" && (entry as Record<string, unknown>).game_type === type,
    );
    const game = parseGame(candidate, type);
    if (game) games.push(game);
  }
  if (games.length === 0) return null;
  return { version: STUDY_GAMES_VERSION, ...owner, generatedAt: now, games };
}

/** الحزمةُ المحفوظة مع الدرس إن كانت لهذا الدرس ولنصّه الحالي. */
export function readStudyGames(
  stored: unknown,
  owner: { lessonId: string; lessonStamp: string },
): StudyGamesPack | null {
  if (!stored || typeof stored !== "object") return null;
  const pack = stored as Partial<StudyGamesPack>;
  if (pack.version !== STUDY_GAMES_VERSION) return null;
  if (pack.lessonId !== owner.lessonId || pack.lessonStamp !== owner.lessonStamp) return null;
  if (!Array.isArray(pack.games) || pack.games.length === 0) return null;
  return pack as StudyGamesPack;
}

/** معرّفُ نشاط المكافأة: الدرسُ واللعبة. */
export function studyGameActivityId(lessonId: string, gameId: string): string {
  return `${lessonId}::${gameId}`;
}

export function parseStudyGameActivityId(activityId: string): { lessonId: string; gameId: StudyGameKind } | null {
  const at = activityId.lastIndexOf("::");
  if (at <= 0) return null;
  const lessonId = activityId.slice(0, at);
  const gameId = activityId.slice(at + 2);
  return (REWARDABLE_GAME_IDS as readonly string[]).includes(gameId)
    ? { lessonId, gameId: gameId as StudyGameKind }
    : null;
}

/** مكافأةُ لعبةٍ محفوظة، محصورةً مرّةً أخرى — سجلٌّ عُدّل يدوياً لا يتجاوز الحدّ. */
export function rewardOf(stored: unknown, gameId: StudyGameKind): { gems: number; points: number } | null {
  if (!stored || typeof stored !== "object") return null;
  const games = (stored as { games?: unknown }).games;
  const game = Array.isArray(games)
    ? games.find((entry) => entry && typeof entry === "object" && (entry as StudyGame).id === gameId)
    : null;
  if (!game) return null;
  return {
    gems: clampInt((game as StudyGame).gems_reward, REWARD_LIMITS.gems),
    points: clampInt((game as StudyGame).points_reward, REWARD_LIMITS.points),
  };
}

// ── نسخةٌ جديدة من لعبة: لا تتكرّر الأسئلة عند إعادة اللعب ─────────────────

/** أقصى ما يُذكر للنموذج ممّا رآه الطالب — يكفي ليتجنّبه ولا ينتفخ الطلب. */
export const MAX_EXCLUDE = 120;

/**
 * توجيهُ نسخةٍ جديدة من لعبةٍ واحدة، من النصّ الكامل للدرس.
 *
 * ── لماذا ──
 * الحزمةُ المحفوظة مع الدرس تُولَّد مرّة، فكانت إعادةُ اللعب تُعيد الأسئلةَ
 * نفسها بترتيبٍ آخر — والطفلُ يحفظ الجوابَ من موضعه لا من فهمه. فكلُّ إعادةٍ
 * تطلب من النموذج نسخةً جديدة، ويُذكر له ما رآه الطالبُ من قبل ليتجنّبه.
 */
export function freshGamePrompt({
  type,
  lessonTitle,
  lessonText,
  subject,
  grade,
  exclude = [],
}: {
  type: StudyGameType;
  lessonTitle: string;
  lessonText: string;
  subject?: string;
  grade?: string;
  exclude?: string[];
}): string {
  const context = [
    grade ? `- الصف: ${grade}` : "",
    subject ? `- المادة: ${subject}` : "",
    lessonTitle ? `- الدرس: ${lessonTitle}` : "",
  ]
    .filter(Boolean)
    .join("\n");
  const seen = exclude
    .map((item) => clean(item, 160))
    .filter(Boolean)
    .slice(-MAX_EXCLUDE);
  const avoid = seen.length
    ? `\nلعب الطالب هذه اللعبة من قبل ورأى ما يلي — لا تُعِد أيّاً منه ولا تُعِد صياغته؛ اختر مفاهيم وتفاصيل أخرى من الدرس وأمثلة جديدة:\n${seen.map((item) => `- ${item}`).join("\n")}\n`
    : "";
  return `ابنِ لعبة واحدة فقط من نوع "${type}" — نسخة جديدة كلياً — من هذا الدرس، وفق ضوابط هذا النوع. أخرجها داخل "games" مصفوفةً من عنصر واحد.
${context ? `\n${context}\n` : ""}${avoid}
نص الدرس:
"""
${fullLessonText(lessonText)}
"""`;
}

/**
 * النسخةُ الجديدة من ردّ النموذج، بعد فحصها كالحزمة. وأسئلةُ السباق التي رآها
 * الطالب تسقط ولو أعادها النموذج — فلا يتكرّر سؤالٌ بنصّه.
 */
export function parseFreshGame(
  raw: unknown,
  type: StudyGameType,
  exclude: string[] = [],
): StudyGame | null {
  const candidate = extract(raw).find(
    (entry) => entry && typeof entry === "object" && (entry as Record<string, unknown>).game_type === type,
  );
  const game = parseGame(candidate, type);
  if (!game) return null;
  if (type !== "endless_quiz") return game;
  const seen = new Set(exclude.map((item) => key(clean(item, 200))));
  const questions = (game.items.questions ?? []).filter((q) => !seen.has(key(q.question)));
  if (questions.length < 6) return null;
  return { ...game, items: { ...game.items, questions } };
}

export function isStudyGameType(value: unknown): value is StudyGameType {
  return (GAME_TYPES as readonly string[]).includes(String(value));
}
