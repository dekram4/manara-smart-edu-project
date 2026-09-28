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
