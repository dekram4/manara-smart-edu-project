/**
 * ترشيد استهلاك الذكاء الاصطناعي: ذاكرةُ إجاباتٍ وحصّةٌ يومية.
 *
 * ── لماذا ──
 * ثلاثون طفلاً في صفٍّ واحد يسألون عن الدرس نفسه، فيُسأل النموذج ثلاثين
 * مرّة عن سؤالٍ واحد. والإجابة لا تتغيّر: الدرس هو الدرس. فتُحفظ أوّل
 * مرّة وتُعاد على البقيّة في جزءٍ من الثانية.
 *
 * والحصّة اليومية تحرس ما لا تحرسه الذاكرة: طفلٌ يسأل مئة سؤالٍ مختلف
 * في ساعة. عشرةٌ مجاناً كل يوم، وما بعدها بخمس جواهر — وهي عملةٌ يكسبها
 * بالدروس والاختبارات، فيصير السؤال اختياراً لا عادة.
 *
 * هذه الوحدة نقيّة: التطبيع والمفاتيح والحساب هنا، والشبكةُ في المسار.
 */

/** أسئلةٌ مجانية لكل طالب في اليوم. */
export const FREE_DAILY_QUESTIONS = 10;

/** ثمنُ السؤال بعد نفاد المجاني. */
export const GEM_PRICE = 5;

const text = (value: unknown): string =>
  typeof value === "string" ? value.trim() : "";

/**
 * أدواتُ الاستفهام التي تُحذف من أوّل السؤال.
 *
 * ── لماذا تُحذف لا تُوحَّد ──
 * «ما هي الخلية» و«ماهو الخلية» و«عرّف الخلية» و«الخلية؟» أربعُ طرائق
 * لطلب الشيء نفسه، وإجابةُ النموذج عنها واحدة. وتوحيدُها إلى صيغةٍ
 * واحدة يجمع ثلاثاً ويترك الرابعة — وهي أكثرها وروداً من الصوت، فمحرّك
 * التعرّف يسمع «الخلية» ويسقط ما قبلها.
 *
 * وما يُحذف صدرُ الجملة وحده: «من» في «من هو العالم» أداة، و«من» في
 * «من فضلك» حرفُ جرّ — فلا تُحذف مفردةً، بل مع ضميرها.
 */
const AR_OPENERS_ONE = new Set([
  "ما", "ماذا", "ماهي", "ماهو", "منهي", "منهو",
  "عرف", "اشرح", "وضح", "فسر", "لخص",
]);
const AR_OPENERS_TWO = new Set(["ما هي", "ما هو", "من هي", "من هو", "ماذا عن"]);

/** ونظائرُها في الإنجليزية، ومعها أداةُ التعريف. */
const EN_OPENERS = [
  "what is", "what are", "whats", "what s", "who is", "who are",
  "how do i", "how do you", "tell me about", "define", "explain", "describe",
];
const EN_ARTICLES = new Set(["the", "a", "an"]);

/**
 * تطبيعُ السؤال للمطابقة — نقطةُ التوحيد الوحيدة.
 *
 * ── لماذا هنا وحدها ──
 * السؤال يصل من ثلاثة أبواب: يُكتب، ويُنطق فيُفرَّغ نصّاً، ويُصوَّر
 * فيُستخرج نصُّه. والثلاثة تُكتب العربية كتاباتٍ مختلفة: الكتابةُ
 * بالهمزات، والصوتُ بلا ترقيم، والصورةُ بالتشكيل كما في الكتاب. ولو
 * طُبّع كلُّ بابٍ على حدة لتسرّب فرقٌ صغير فصار السؤال الواحد ثلاثة
 * مفاتيح — وهو بالضبط ما جاءت الذاكرة لتمنعه. فالأبوابُ الثلاثة تصبّ
 * في هذه الدالة قبل أن يُبنى مفتاح.
 *
 * والتطبيع للمفتاح وحده: السؤال يُحفظ كما كتبه الطفل، ويُعرض كما كتبه.
 */
export function normalizeQuestion(value: unknown): string {
  let text = String(value ?? "")
    .toLowerCase()
    // التشكيل والتطويل: زينةُ كتابةٍ لا تُغيّر السؤال.
    .replace(/[ً-ْٰـ]/g, "")
    // الهمزات: «أين» و«اين» سؤالٌ واحد.
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    // الأرقام العربية-الهندية إلى أرقامٍ يُقارَن بها.
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06F0))
    // ورموزُ الحساب إلى صورةٍ واحدة: الضربُ يُكتب «×» في الكتاب و«*»
    // على لوحة المفاتيح، والقسمةُ «÷» و«/»، والطرحُ بشَرطةٍ طويلةٍ أو
    // قصيرة. وثلاثُ كتاباتٍ لعمليةٍ واحدة ثلاثةُ مفاتيح.
    .replace(/[×٭]/g, "*")
    // و«x» بين رقمين ضربٌ، وبعد رقمٍ وحده متغيّر: «2 x 3» حسابٌ،
    // و«2x+5» معادلة. فلا يُحوَّل الحرفُ إلا حيث لا يحتمل غير الضرب.
    .replace(/([0-9])\s*[x*]\s*([0-9])/g, "$1*$2")
    .replace(/[÷]/g, "/")
    .replace(/[−‒–—―]/g, "-")
    .replace(/[＝]/g, "=");

  // ثم لا يبقى إلا حرفٌ أو رقمٌ أو عمليةُ حساب.
  //
  // الترقيم والرموز والإيموجي: طفلٌ يكتب «ما الخلية؟؟ 🤔» وآخر يكتبها
  // بلا شيء، والسؤال واحد. ويشمل هذا ما يأتي من الصوت — محرّك التعرّف
  // يضيف نقطةً في آخر الجملة — ومن قراءة الصورة.
  //
  // وعلاماتُ الحساب تنجو وحدها من هذا المسح. وكانت تسقط معه، فيصير
  // «٢+٣» و«٢-٣» مفتاحاً واحداً هو «2 3» — فيُجاب طفلٌ سأل عن الطرح
  // بجواب الجمع. وهو أسوأ ما تفعله ذاكرة: لا أن تُخطئ، بل أن تُصيب
  // بثقةٍ في السؤال الخطأ.
  text = text.replace(/[^\p{L}\p{N}+\-*/=%]+/gu, " ").trim();

  // والمسافاتُ حول العمليات تسقط، والمتغيّرُ يلتصق برقمه.
  //
  // «2 x + 5 = 10» و«2x+5=10» معادلةٌ واحدة كتبها طفلان بإصبعين
  // مختلفين، ويقرؤها النموذج سواء.
  text = text
    .replace(/\s*([+\-*/=])\s*/g, "$1")
    .replace(/([0-9])\s+([a-z])(?![a-z])/g, "$1$2")
    .replace(/([a-z])(?![a-z])\s+([0-9])/g, "$1$2")
    .replace(/\s+/g, " ")
    .trim();

  // وأخيراً صدرُ السؤال.
  //
  // على الكلمات لا بتعبيرٍ نمطيّ: العربيّةُ داخل regex في ملفٍّ يخلط
  // الاتجاهين تُقرأ صحيحةً بالعين وقد تُخزَّن بترتيبٍ آخر، فلا يُطابق
  // النمطُ شيئاً ولا يظهر لذلك أثر — يمرّ السؤالان مفتاحين لا مفتاحاً.
  // ومقارنةُ كلمةٍ بكلمة لا تحتمل هذا الالتباس.
  for (const opener of EN_OPENERS) {
    if (text === opener) return "";
    if (text.startsWith(`${opener} `)) {
      text = text.slice(opener.length + 1);
      break;
    }
  }

  let words = text.split(" ").filter(Boolean);
  if (words.length > 1 && AR_OPENERS_TWO.has(words.slice(0, 2).join(" "))) {
    words = words.slice(2);
  } else if (words.length > 1 && AR_OPENERS_ONE.has(words[0]!)) {
    words = words.slice(1);
  }
  // وأداةُ التعريف الإنجليزية بعدها: «what is the cell» و«the cell»
  // و«cell» سؤالٌ واحد. والعربيةُ «الـ» ملتصقةٌ بكلمتها فلا تُمسّ —
  // حذفُها يخلط «العلم» بـ«علم».
  if (words.length > 1 && EN_ARTICLES.has(words[0]!)) words = words.slice(1);

  return words.join(" ");
}

/**
 * مفتاح الذاكرة: الدرس والسؤال معاً.
 *
 * الدرس جزءٌ من المفتاح لأن «ما الفكرة الرئيسية؟» سؤالٌ صالحٌ لكل درس،
 * وإجابتُه تختلف بينها. وبلا الدرس في المفتاح يُجاب طفلٌ عن درسٍ لم
 * يفتحه.
 */
export function cacheKey(lessonId: unknown, question: unknown): string {
  return `${text(lessonId)}::${normalizeQuestion(question)}`;
}

/** السؤالُ المطبَّع من مفتاحٍ مخزَّن، أو `""` إن لم يكن مفتاحاً. */
export function questionOfKey(key: unknown): string {
  const at = String(key ?? "").indexOf("::");
  return at < 0 ? "" : String(key).slice(at + 2);
}

/**
 * كلماتٌ لا تحمل معنى السؤال، فلا تدخل في قياس التشابه.
 *
 * حروفُ الجرّ والضمائر والأفعال المساعدة: يكتبها طفلٌ ويسقطها آخر،
 * فوجودها يجعل سؤالين متطابقي المعنى مختلفَي القياس.
 */
const STOPWORDS = new Set([
  // أدواتُ الاستفهام مفردةً وملتصقة.
  //
  // التطبيعُ يحذفها من صدر السؤال وحده، لأن الحذف هناك لا يحتمل غير
  // الاستفهام. وهي تأتي في آخره أيضاً — «الخلية ماهي» — فتنجو من ذلك
  // وتصير كلمةً مفتاحية، فيقيس السؤالُ نصفَ تشابهٍ مع نفسه مقلوباً.
  // و«وظيفة» و«تركيب» و«أهمية» ليست منها: «وظيفة الخلية» ليست «الخلية»،
  // وإسقاطُها يجمع سؤالين عن الشيء الواحد من جهتين.
  "ماهي", "ماهو", "منهي", "منهو", "ماذا", "عرف", "اشرح", "وضح", "فسر",
  "لخص", "تعريف", "معني",
  // العربية، مطبَّعةً كما يخرج من `normalizeQuestion`.
  "في", "من", "علي", "الي", "عن", "مع", "هل", "هي", "هو", "هذا", "هذه",
  "ذلك", "تلك", "التي", "الذي", "كان", "كانت", "يكون", "تكون", "ان",
  "او", "ثم", "قد", "كل", "عند", "حتي", "لكن", "لا", "ما", "كما", "بين",
  "لماذا", "كيف", "متي", "اين", "ايش", "وش", "بعد", "قبل", "ايضا",
  "يعني", "شرح", "مثال", "فضلك", "لي", "لك",
  // والإنجليزية.
  "the", "a", "an", "is", "are", "was", "were", "of", "in", "on", "at",
  "to", "for", "and", "or", "it", "this", "that", "with", "do", "does",
  "did", "how", "why", "when", "where", "please", "me", "my", "you",
]);

/**
 * كلماتُ السؤال المفتاحية، مرتَّبةً هجائياً وبلا مكرَّر.
 *
 * ── لماذا الترتيب ──
 * «الخلية ماهي» و«ماهي الخلية» سؤالٌ واحد قاله طفلان، وكان يخرج منهما
 * مفتاحان لأن الحروفَ نفسها في ترتيبين. والترتيبُ الهجائي يُلغي أثر
 * الترتيب كلَّه بلا تخمين.
 *
 * ── وما يُعرَّض له ──
 * ترتيبٌ مُلغى يعني أن «الخلية جزء من النسيج» و«النسيج جزء من الخلية»
 * يقيسان متطابقين. وهما سؤالان لا واحد. والمطابقةُ الحرفية تُجرَّب
 * أولاً وتُصيب في الغالب، فهذا لا يقع إلا حين يُسأل السؤالان بالكلمات
 * نفسها معكوسةً في الدرس نفسه — وهو نادرٌ في سؤال طفلٍ عن درسه، لكنّه
 * ليس مستحيلاً. وهو الثمنُ المدفوع عن ألّا يُخصم من طفلٍ سألَ سؤالاً
 * مسؤولاً عنه بكلماتٍ مقدَّمةٍ ومؤخَّرة.
 */
export function questionTokens(value: unknown): string[] {
  const words = normalizeQuestion(value).split(" ").filter(Boolean);
  // والأداةُ تُعرَف ولو أخطأ فيها حرف: «ماهلي» أداةُ استفهامٍ قرأها
  // الـOCR بنقطةٍ زائدة، ولو بقيت كلمةً مفتاحية لطابقت سؤالاً بالكلمة
  // الخطأ نفسها وحده — أي لا شيء.
  //
  // و`sameWord` لا تتسامح مع ما دون أربعة أحرف، فأدواتُ الحرفين
  // والثلاثة — «من» و«في» و«هل» — تُطابَق حرفاً بحرف ولا تجذب إليها
  // كلمةً تشبهها.
  const kept = words.filter(
    (word) =>
      !STOPWORDS.has(word) &&
      ![...STOPWORDS].some((stop) => sameWord(word, stop)),
  );
  // وسؤالٌ كلُّه أدواتٌ يُقاس بكلماته كما هي: إسقاطُها كلَّها يجعله
  // فارغاً فيطابق كلَّ سؤالٍ فارغٍ آخر.
  const base = kept.length > 0 ? kept : words;
  return [...new Set(base)].sort();
}

/** مسافةُ التحرير بين كلمتين — كم حرفاً يُبدَّل أو يُزاد أو يُحذف. */
function editDistance(a: string, b: string): number {
  if (a === b) return 0;
  if (!a.length || !b.length) return Math.max(a.length, b.length);
  let previous = Array.from({ length: b.length + 1 }, (_, index) => index);
  for (let i = 1; i <= a.length; i += 1) {
    const current = [i];
    for (let j = 1; j <= b.length; j += 1) {
      current[j] = Math.min(
        previous[j]! + 1,
        current[j - 1]! + 1,
        previous[j - 1]! + (a[i - 1] === b[j - 1] ? 0 : 1),
      );
    }
    previous = current;
  }
  return previous[b.length]!;
}

/**
 * هل الكلمتان كلمةٌ واحدة أخطأ في حرفٍ منها قارئُ الصورة؟
 *
 * «ماهلي» و«ماهي» و«الخليه» و«الخلبه»: حرفٌ واحد بينهما، ومصدرُه أن
 * الـOCR قرأ نقطةً في غير موضعها. والسماحُ يتّسع بطول الكلمة — حرفٌ في
 * الخمسة، واثنان في العشرة — فلا تُخلط كلمتان قصيرتان مختلفتان:
 * «شمس» و«قمر» ثلاثةُ أحرفٍ لا يُغتفر بينها شيء.
 */
function sameWord(a: string, b: string): boolean {
  if (a === b) return true;
  const shorter = Math.min(a.length, b.length);
  if (shorter < 4) return false;
  return editDistance(a, b) <= Math.max(1, Math.floor(shorter / 5));
}

/**
 * قياسُ التشابه بين سؤالين: صفرٌ لا يشتركان، وواحدٌ سؤالٌ واحد.
 *
 * مقياسُ Jaccard على الكلمات المفتاحية، والكلمةُ تُطابق نظيرتَها ولو
 * أخطأ فيها حرف. فسؤالان يشتركان في كل كلماتهما المفتاحية يقيسان ١
 * ولو اختلف ترتيبُهما وأدواتُهما.
 */
export function questionSimilarity(a: unknown, b: unknown): number {
  const left = questionTokens(a);
  const right = questionTokens(b);
  if (left.length === 0 || right.length === 0) return 0;

  const unmatched = [...right];
  let shared = 0;
  for (const word of left) {
    const at = unmatched.findIndex((other) => sameWord(word, other));
    if (at >= 0) {
      unmatched.splice(at, 1);
      shared += 1;
    }
  }
  // المشتركُ على المجموع: كلمةٌ زائدة في أحدهما تُنقص القياس، فلا يُطابق
  // «الخلية» سؤالاً عن «الخلية النباتية والحيوانية».
  return (2 * shared) / (left.length + right.length);
}

/** أدنى تشابهٍ يُعَدّ سؤالاً واحداً. */
export const SIMILARITY_THRESHOLD = 0.88;

/**
 * أقربُ سؤالٍ محفوظٍ إلى هذا السؤال، أو `null` إن لم يقربه شيء.
 *
 * تُنادى بعد أن تخيب المطابقةُ الحرفية: تلك استعلامٌ واحد على مفتاحٍ
 * مفهرَس، وهذه تقيس ما في الدرس كلَّه. فالشائعُ — سؤالٌ أُعيد بحرفه —
 * يبقى سريعاً كما كان، والنادرُ يُصاب بكلفةٍ صغيرة.
 */
export function bestSimilarKey(
  keys: readonly string[],
  question: unknown,
  threshold = SIMILARITY_THRESHOLD,
): { key: string; score: number } | null {
  let best: { key: string; score: number } | null = null;
  for (const key of keys) {
    const score = questionSimilarity(question, questionOfKey(key));
    if (score >= threshold && (!best || score > best.score)) {
      best = { key, score };
    }
  }
  return best;
}

/** اليوم بتقويم الخادم، لا بساعة الجهاز — فلا تُجدَّد الحصّة بتغيير الساعة. */
export function dayStamp(now: Date = new Date()): string {
  return now.toISOString().slice(0, 10);
}

export interface QuotaState {
  /** اليوم الذي يُحسب عليه العدّاد. */
  day: string;
  /** كم سؤالاً مجانياً استُهلك اليوم. */
  used: number;
  /** كم جوهرةً أُنفقت على أسئلةٍ إضافية اليوم. */
  gemsSpent: number;
}

export function readQuota(value: unknown, today = dayStamp()): QuotaState {
  const map = value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
  const day = text(map.day);
  // يومٌ جديد يعني عدّاداً جديداً. ولا يُخزَّن تصفيرٌ ولا تُجدول مهمّة:
  // المقارنة عند القراءة تكفي، وهي لا تنسى ولا تفشل.
  if (day !== today) return { day: today, used: 0, gemsSpent: 0 };
  return {
    day,
    used: Math.max(0, Number(map.used) || 0),
    gemsSpent: Math.max(0, Number(map.gemsSpent) || 0),
  };
}

export interface QuotaVerdict {
  /** هل يُسمح بهذا السؤال؟ */
  allowed: boolean;
  /** كم جوهرةً تُخصم. صفرٌ ما دام في الحصّة المجانية متّسع. */
  gemsCharged: number;
  /** ما بقي من المجاني بعد هذا السؤال. */
  remainingFree: number;
  /** سببُ المنع، إن مُنع. */
  reason?: "no_gems";
}

/**
 * هل يُسأل هذا السؤال، وبأيّ ثمن؟
 *
 * الإجابة المحفوظة لا تُحسب من الحصّة ولا تُكلّف جوهرة: لم يُستدعَ
 * النموذج، ولا معنى لأن يُحرم طفلٌ من سؤالٍ لأن غيره سأله قبله.
 * والمسار يستدعي هذه الدالة بعد أن يخيب بحثُه في الذاكرة.
 */
export function chargeFor(quota: QuotaState, gems: number): QuotaVerdict {
  if (quota.used < FREE_DAILY_QUESTIONS) {
    return {
      allowed: true,
      gemsCharged: 0,
      remainingFree: FREE_DAILY_QUESTIONS - quota.used - 1,
    };
  }
  if (gems < GEM_PRICE) {
    return { allowed: false, gemsCharged: 0, remainingFree: 0, reason: "no_gems" };
  }
  return { allowed: true, gemsCharged: GEM_PRICE, remainingFree: 0 };
}

/** الحصّة بعد سؤالٍ سُمح به. */
export function spend(quota: QuotaState, verdict: QuotaVerdict): QuotaState {
  if (!verdict.allowed) return quota;
  return {
    day: quota.day,
    used: quota.used + 1,
    gemsSpent: quota.gemsSpent + verdict.gemsCharged,
  };
}

/** ما يُعرض للطفل في الشات: كم بقي، وبكم السؤال بعدها. */
export interface QuotaSnapshot {
  remainingFree: number;
  freePerDay: number;
  gemPrice: number;
  gems: number;
  /** هل يستطيع أن يسأل الآن أصلاً؟ */
  canAsk: boolean;
}

export function snapshotOf(quota: QuotaState, gems: number): QuotaSnapshot {
  const remainingFree = Math.max(0, FREE_DAILY_QUESTIONS - quota.used);
  return {
    remainingFree,
    freePerDay: FREE_DAILY_QUESTIONS,
    gemPrice: GEM_PRICE,
    gems,
    canAsk: remainingFree > 0 || gems >= GEM_PRICE,
  };
}
