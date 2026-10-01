/**
 * أسئلةُ المبارزة: حزمةٌ تُبنى مرّةً عند الدعوة وتُحفظ مع المباراة.
 *
 * ── لماذا تُحفظ الحزمةُ لا تُبنى ببذرةٍ على الجهازين ──
 * كان كلُّ جهازٍ يبني أسئلتَه من بذرةٍ هي معرّفُ المباراة، فعدلُ المباراة
 * معلّقٌ بأن يبقى حسابُ البذرة والترتيبُ متطابقين على الجهازين إلى الأبد:
 * نسخةٌ أقدمُ من التطبيق، أو بنكُ درسٍ تغيّر بين القراءتين، أو تعديلٌ في
 * الخلط — وكلُّها تُخرج أسئلةً مختلفةً **بلا خطأٍ يظهر**. كلُّ جهازٍ يعمل
 * وحده صحيحاً، والفرقُ لا يراه إلا من جمع الشاشتين.
 *
 * فصارت الحزمةُ تُبنى في الخادم مرّةً وتُكتب في صفّ المباراة. والجهازان
 * يقرآن الصفَّ نفسه: الأسئلةُ نفسها بالترتيب نفسه والخياراتُ في المواضع
 * نفسها، لا باتّفاقِ حسابين بل لأنها شيءٌ واحد.
 *
 * ── ولا تُولَّد بنموذجٍ عند الدعوة ──
 * التوليدُ يُجلس الطفلَ أمام دوّارةِ انتظارٍ عشرَ ثوانٍ قبل أن تُرسل دعوتُه،
 * ويُسقط الدعوةَ كلَّها إن تعثّر النموذج. فالحزمةُ تُنتقى من بنكٍ مكتوبٍ
 * هنا ومن بنك الدرس إن وُجد — بلا شبكةٍ ولا كلفة، وفي أجزاءٍ من المللي.
 *
 * ── ولماذا أسئلةٌ ليست من الدرس وحده ──
 * المبارزةُ تُلعب مرّةً بعد مرّةٍ بين الزملاء أنفسهم، ودرسٌ واحدٌ يُستنفد في
 * ثلاث جولات ثم يصير حفظاً لمواضع الأزرار. فالبنكُ أربعةُ أبوابٍ: معلوماتٌ
 * عامّة، وذكاءٌ ومنطق، وسرعةُ بديهة، وثقافةٌ مدرسية. وأسئلةُ الدرس تُخلط
 * معها حين يكون للدرس بنك، فتبقى المبارزةُ متّصلةً بما يدرسه ولا تُسجن فيه.
 */

/** بابُ السؤال. يُعرض للطفل فيعرف ما يُسأل عنه قبل أن يقرأ. */
export type DuelCategory = "general" | "logic" | "quick" | "school" | "lesson";

export interface DuelQuestion {
  /** معرّفٌ ثابتٌ للسؤال، يُستعمل لمنع تكراره في الحزمة. */
  id: string;
  category: DuelCategory;
  prompt: string;
  /** الخياراتُ بالترتيب الذي يُعرض به، والجوابُ أحدُها. */
  options: string[];
  answerAt: number;
}

/** طولُ المباراة: ثمانيةٌ إلى عشرة، وعشرةٌ هو المعتاد. */
export const DUEL_PACK_SIZE = 10;
export const DUEL_PACK_MIN = 8;

/** صيغةُ الحزمة. رقمٌ يتغيّر حين تتغيّر القواعد فتُعاد القراءةُ من جديد. */
export const DUEL_PACK_VERSION = 1;

export interface DuelPack {
  version: number;
  builtAt: string;
  questions: DuelQuestion[];
}

interface Seed {
  category: DuelCategory;
  prompt: string;
  /** الجوابُ أوّلاً، ثم المشتّتات. يُخلط الترتيبُ عند البناء. */
  choices: [string, ...string[]];
}

/**
 * البنكُ المكتوب.
 *
 * ── وشروطُ ما يدخل فيه ──
 * المرحلةُ الابتدائية: جملةٌ قصيرةٌ تُقرأ في ثانية، وجوابٌ واحدٌ لا خلافَ
 * عليه، ومشتّتاتٌ معقولةٌ لا سخيفة — مشتّتٌ سخيفٌ يجعل السؤالَ بلا سؤال.
 * ولا شيءَ يتعلّق بمنهجٍ بعينه ولا بسنةٍ تمرّ.
 */
const SEEDS: Seed[] = [
  // ── معلوماتٌ عامّة ──
  { category: "general", prompt: "ما أكبر كوكب في المجموعة الشمسية؟", choices: ["المشتري", "الأرض", "المريخ", "عطارد"] },
  { category: "general", prompt: "كم عدد أيام السنة الميلادية؟", choices: ["365", "360", "350", "375"] },
  { category: "general", prompt: "ما أكبر محيط في العالم؟", choices: ["الهادي", "الأطلسي", "الهندي", "المتجمد"] },
  { category: "general", prompt: "ما عاصمة المملكة العربية السعودية؟", choices: ["الرياض", "جدة", "مكة", "الدمام"] },
  { category: "general", prompt: "ما أسرع حيوان بري في العالم؟", choices: ["الفهد", "الأسد", "الحصان", "الغزال"] },
  { category: "general", prompt: "كم عدد قارات العالم؟", choices: ["سبع", "خمس", "ست", "ثماني"] },
  { category: "general", prompt: "ما الحيوان الذي يُلقّب بسفينة الصحراء؟", choices: ["الجمل", "الحصان", "الحمار", "الثور"] },
  { category: "general", prompt: "أي هذه الكائنات يتنفس بالرئتين؟", choices: ["الحوت", "السمكة", "القريدس", "المحار"] },
  { category: "general", prompt: "ما أكبر حيوان على وجه الأرض؟", choices: ["الحوت الأزرق", "الفيل", "الزرافة", "القرش"] },
  { category: "general", prompt: "ما اللون الذي ينتج من خلط الأزرق والأصفر؟", choices: ["الأخضر", "البرتقالي", "البنفسجي", "البني"] },
  { category: "general", prompt: "كم عدد أضلاع المثلث؟", choices: ["ثلاثة", "أربعة", "اثنان", "خمسة"] },
  { category: "general", prompt: "ما الكوكب الذي نعيش عليه؟", choices: ["الأرض", "الزهرة", "المشتري", "زحل"] },
  { category: "general", prompt: "أي هذه الفصول يأتي بعد الربيع؟", choices: ["الصيف", "الشتاء", "الخريف", "لا شيء"] },
  { category: "general", prompt: "ما الحاسة التي نستخدمها لنعرف طعم الطعام؟", choices: ["التذوق", "السمع", "البصر", "اللمس"] },
  { category: "general", prompt: "من أين تحصل النباتات على طاقتها؟", choices: ["الشمس", "التراب فقط", "الهواء فقط", "القمر"] },

  // ── ذكاءٌ ومنطق ──
  { category: "logic", prompt: "إذا كان عمر أحمد ضعف عمر سارة، وسارة عمرها ٥، فكم عمر أحمد؟", choices: ["10", "7", "15", "5"] },
  { category: "logic", prompt: "أكمل النمط: ٢، ٤، ٦، ٨، ...", choices: ["10", "9", "12", "11"] },
  { category: "logic", prompt: "أكمل النمط: ١، ٤، ٩، ١٦، ...", choices: ["25", "20", "24", "18"] },
  { category: "logic", prompt: "ما العدد الذي لا يشبه البقية: ٢، ٤، ٧، ٨؟", choices: ["7", "2", "4", "8"] },
  { category: "logic", prompt: "عند أمي ٣ تفاحات وأعطتني واحدة، كم بقي عندها؟", choices: ["2", "3", "4", "1"] },
  { category: "logic", prompt: "إذا كان كل الطيور لها أجنحة، والعصفور طائر، فماذا نستنتج؟", choices: ["للعصفور أجنحة", "العصفور لا يطير", "العصفور سمكة", "لا نستنتج شيئاً"] },
  { category: "logic", prompt: "أكمل النمط: أحد، ثلاثاء، أربعاء، خميس، ...", choices: ["جمعة", "سبت", "اثنين", "أحد"] },
  { category: "logic", prompt: "في الصف ٥ صفوف وفي كل صف ٤ طلاب، كم طالباً في الصف؟", choices: ["20", "9", "16", "25"] },
  { category: "logic", prompt: "ما نصف العدد ١٨؟", choices: ["9", "8", "10", "6"] },
  { category: "logic", prompt: "أي هذه الأعداد أكبر: ٣/٤ أم ١/٢؟", choices: ["٣/٤", "١/٢", "متساويان", "لا يُقارنان"] },
  { category: "logic", prompt: "إذا بدأ الدرس ٨:٠٠ وانتهى ٨:٤٥، كم دقيقة طوله؟", choices: ["45", "30", "60", "15"] },
  { category: "logic", prompt: "أكمل النمط: ١٠، ٨، ٦، ٤، ...", choices: ["2", "3", "0", "5"] },

  // ── سرعةُ بديهة ──
  { category: "quick", prompt: "بسرعة! ما ناتج ٧ + ٦؟", choices: ["13", "12", "14", "11"] },
  { category: "quick", prompt: "بسرعة! ما ناتج ٩ × ٣؟", choices: ["27", "24", "21", "30"] },
  { category: "quick", prompt: "بسرعة! ما ناتج ١٥ − ٨؟", choices: ["7", "6", "8", "9"] },
  { category: "quick", prompt: "بسرعة! كم حرفاً في كلمة «مدرسة»؟", choices: ["5", "6", "4", "7"] },
  { category: "quick", prompt: "بسرعة! ما أول حرف في الأبجدية العربية؟", choices: ["الألف", "الباء", "التاء", "الياء"] },
  { category: "quick", prompt: "بسرعة! ما ناتج ٢٠ ÷ ٤؟", choices: ["5", "4", "6", "8"] },
  { category: "quick", prompt: "بسرعة! كم يوماً في الأسبوع؟", choices: ["7", "6", "5", "30"] },
  { category: "quick", prompt: "بسرعة! ما العدد الذي يأتي قبل ١٠٠؟", choices: ["99", "101", "90", "98"] },
  { category: "quick", prompt: "بسرعة! ما ناتج ٦ × ٦؟", choices: ["36", "30", "42", "32"] },
  { category: "quick", prompt: "بسرعة! كم ساعة في اليوم؟", choices: ["24", "12", "60", "30"] },
  { category: "quick", prompt: "بسرعة! ما ضعف العدد ١٢؟", choices: ["24", "22", "26", "14"] },
  { category: "quick", prompt: "بسرعة! ما ناتج ١٠٠ − ٥٥؟", choices: ["45", "55", "35", "50"] },

  // ── ثقافةٌ مدرسية ──
  { category: "school", prompt: "ما الذي نستخدمه لمحو ما كتبناه بالقلم الرصاص؟", choices: ["الممحاة", "المسطرة", "المبراة", "الدفتر"] },
  { category: "school", prompt: "ماذا نفعل قبل أن نتكلم في الصف؟", choices: ["نرفع أيدينا", "نصرخ", "نقف", "نخرج"] },
  { category: "school", prompt: "أين نجد الكتب في المدرسة؟", choices: ["المكتبة", "المقصف", "الملعب", "المختبر"] },
  { category: "school", prompt: "ما الأداة التي نرسم بها الخطوط المستقيمة؟", choices: ["المسطرة", "الممحاة", "المقص", "الفرشاة"] },
  { category: "school", prompt: "أين نجري التجارب العلمية في المدرسة؟", choices: ["المختبر", "المكتبة", "المقصف", "الإدارة"] },
  { category: "school", prompt: "ما الذي نرمي فيه الأوراق التي لا نحتاجها؟", choices: ["سلة المهملات", "الحقيبة", "الدرج", "النافذة"] },
  { category: "school", prompt: "من يشرح الدرس في الصف؟", choices: ["المعلم", "الطالب", "الحارس", "السائق"] },
  { category: "school", prompt: "ماذا نقول عندما يساعدنا أحد؟", choices: ["شكراً", "لا شيء", "اذهب", "بسرعة"] },
  { category: "school", prompt: "ما الذي نحمل فيه كتبنا إلى المدرسة؟", choices: ["الحقيبة", "الكرسي", "السبورة", "القلم"] },
  { category: "school", prompt: "أين نلعب في وقت الفسحة؟", choices: ["الملعب", "المختبر", "المكتبة", "الصف"] },
  { category: "school", prompt: "ما الذي يكتب عليه المعلم أمام الصف؟", choices: ["السبورة", "الدفتر", "المسطرة", "الحقيبة"] },
  { category: "school", prompt: "ماذا نفعل عند سماع جرس نهاية الحصة؟", choices: ["ننظّم أدواتنا", "نجري", "نصرخ", "ننام"] },
];

/** نواةُ عشوائيةٍ ثابتة: البذرةُ نفسها تُخرج الترتيبَ نفسه دائماً. */
function seededRandom(seed: number): () => number {
  let state = seed % 2147483647;
  if (state <= 0) state += 2147483646;
  return () => {
    state = (state * 16807) % 2147483647;
    return (state - 1) / 2147483646;
  };
}

/**
 * بذرةٌ ثابتةٌ من نصّ.
 *
 * ولا تُستعمل دالّةُ تهشيرٍ من المنصّة: المطلوبُ عددٌ محسوبٌ بحسابٍ مكتوبٍ لا
 * يتغيّر بتغيّر إصدارٍ، لأنّ عليه يُبنى ما يُخزَّن ويُقرأ.
 */
export function packSeed(text: string): number {
  let seed = 7;
  for (let i = 0; i < text.length; i += 1) {
    seed = (seed * 31 + text.charCodeAt(i)) % 2147483647;
  }
  return seed;
}

function shuffled<T>(items: readonly T[], next: () => number): T[] {
  const copy = [...items];
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(next() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

/** سؤالٌ من الدرس، كما يُستخرج من بنك الدرس المحفوظ. */
export interface LessonSeed {
  prompt: string;
  answer: string;
  distractors: string[];
}

/**
 * يبني حزمةَ المباراة.
 *
 * ── وتوزيعُ الأبواب مقصود ──
 * أسئلةُ الدرس أوّلاً إن وُجدت — إلى الثلث — فتبقى المبارزةُ متّصلةً بما
 * يدرسه الطفل. ثم يُكمَل الباقي من الأبواب الأربعة مخلوطةً، فلا تأتي أسئلةُ
 * بابٍ واحدٍ متتابعةً فتملّ.
 *
 * وكلُّ ما هنا يتبع البذرة: البناءُ مرّتين بالمعرّف نفسه يُخرج الحزمةَ نفسها
 * حرفاً بحرف. وهو ما يجعل إعادةَ البناء — لصفٍّ قديمٍ بلا حزمة — آمنة.
 */
export function buildDuelPack(
  matchId: string,
  lessonSeeds: readonly LessonSeed[] = [],
  size: number = DUEL_PACK_SIZE,
  now: Date = new Date(),
): DuelPack {
  const count = Math.max(DUEL_PACK_MIN, Math.min(size, DUEL_PACK_SIZE));
  const next = seededRandom(packSeed(matchId));

  const questions: DuelQuestion[] = [];

  // ── أسئلةُ الدرس: إلى الثلث، وما صلح منها فقط ──
  // جولةٌ بلا مشتّتين لا تصير سؤالاً من أربعة خيارات.
  const lessonUsable = lessonSeeds.filter(
    (seed) => text(seed.prompt) && text(seed.answer) && seed.distractors.filter(text).length >= 3,
  );
  const lessonQuota = Math.min(Math.floor(count / 3), lessonUsable.length);
  for (const seed of shuffled(lessonUsable, next).slice(0, lessonQuota)) {
    questions.push(
      finish(
        {
          category: "lesson",
          prompt: text(seed.prompt),
          choices: [text(seed.answer), ...seed.distractors.filter(text).slice(0, 3)] as [string, ...string[]],
        },
        `lesson:${hash(seed.prompt + seed.answer)}`,
        next,
      ),
    );
  }

  // ── والباقي من البنك المكتوب، بابٌ بعد باب ──
  // الأبوابُ تُدار بالتناوب فلا يأتي بابٌ واحدٌ متتابعاً، والاختيارُ داخل
  // كلِّ بابٍ بالبذرة.
  const byCategory = new Map<DuelCategory, Seed[]>();
  for (const seed of SEEDS) {
    const bucket = byCategory.get(seed.category) ?? [];
    bucket.push(seed);
    byCategory.set(seed.category, bucket);
  }
  const order = shuffled([...byCategory.keys()], next);
  const pools = new Map(
    [...byCategory.entries()].map(([key, list]) => [key, shuffled(list, next)]),
  );

  let turn = 0;
  while (questions.length < count) {
    const category = order[turn % order.length];
    turn += 1;
    const pool = pools.get(category);
    if (!pool || pool.length === 0) {
      // بابٌ نفد: إن نفدت الأبوابُ كلُّها خرجنا بما جُمع.
      if ([...pools.values()].every((list) => list.length === 0)) break;
      continue;
    }
    const seed = pool.shift()!;
    questions.push(finish(seed, `${seed.category}:${hash(seed.prompt)}`, next));
  }

  return {
    version: DUEL_PACK_VERSION,
    builtAt: now.toISOString(),
    questions,
  };
}

/** يخلط خياراتِ السؤال ويحفظ موضعَ جوابه. */
function finish(seed: Seed, id: string, next: () => number): DuelQuestion {
  const answer = seed.choices[0];
  const options = shuffled(seed.choices, next);
  return {
    id,
    category: seed.category,
    prompt: seed.prompt,
    options,
    answerAt: options.indexOf(answer),
  };
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function hash(value: string): string {
  return packSeed(value).toString(36);
}

/**
 * يقرأ حزمةً محفوظة، أو `null` لما لا يصلح أن يُلعب.
 *
 * وكلُّ سؤالٍ يُفحص: صفٌّ كُتب بنسخةٍ أقدم، أو حقلٌ ضاع، أو موضعُ جوابٍ خارج
 * الخيارات — وكلُّها تُخرج مباراةً لا جوابَ صحيحَ فيها بلا خطأٍ يظهر.
 */
export function parseDuelPack(raw: unknown): DuelPack | null {
  if (!raw || typeof raw !== "object") return null;
  const row = raw as Record<string, unknown>;
  if (row.version !== DUEL_PACK_VERSION) return null;
  const list = Array.isArray(row.questions) ? row.questions : null;
  if (!list) return null;

  const questions: DuelQuestion[] = [];
  for (const item of list) {
    const question = parseQuestion(item);
    if (question) questions.push(question);
  }
  if (questions.length < DUEL_PACK_MIN) return null;
  return {
    version: DUEL_PACK_VERSION,
    builtAt: text(row.builtAt),
    questions,
  };
}

function parseQuestion(raw: unknown): DuelQuestion | null {
  if (!raw || typeof raw !== "object") return null;
  const row = raw as Record<string, unknown>;
  const prompt = text(row.prompt);
  const id = text(row.id);
  if (!prompt || !id) return null;
  const options = Array.isArray(row.options) ? row.options.map(text).filter(Boolean) : [];
  if (options.length < 2) return null;
  const answerAt = typeof row.answerAt === "number" ? row.answerAt : -1;
  if (!Number.isInteger(answerAt) || answerAt < 0 || answerAt >= options.length) return null;
  const category = text(row.category);
  return {
    id,
    category: isCategory(category) ? category : "general",
    prompt,
    options,
    answerAt,
  };
}

function isCategory(value: string): value is DuelCategory {
  return ["general", "logic", "quick", "school", "lesson"].includes(value);
}
