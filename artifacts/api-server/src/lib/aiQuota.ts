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
 * تطبيعُ السؤال للمطابقة.
 *
 * «ما هي الخلية؟» و«ما هى الخليه» سؤالٌ واحد، والفرقُ بينهما همزةٌ
 * وتاءٌ مربوطة وعلامةُ استفهام. ولولا التطبيع لسُئل النموذج مرّتين عن
 * الشيء نفسه — وهو بالضبط ما جاءت الذاكرة لتمنعه.
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
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06F0));

  // كلُّ ما ليس حرفاً ولا رقماً يصير فاصلاً.
  //
  // الترقيم والرموز والإيموجي: طفلٌ يكتب «ما الخلية؟؟ 🤔» وآخر يكتبها
  // بلا شيء، والسؤال واحد. ويشمل هذا ما يأتي من الصوت — محرّك التعرّف
  // يضيف نقطةً في آخر الجملة — ومن قراءة الصورة.
  text = text.replace(/[^\p{L}\p{N}]+/gu, " ").trim();

  // صِيَغ الاستفهام المتكافئة تُختصر إلى واحدة.
  //
  // «ما هي الخلية» و«ماهي الخلية» و«ما هو الخلية» ثلاثُ كتاباتٍ لسؤالٍ
  // واحد. والفرق بين «هي» و«هو» فرقُ تذكيرٍ لا فرقُ معنى في سؤال طفل.
  //
  // والحروف مكتوبةٌ بترميزها لا بأنفسها.
  //
  // عربيّةٌ داخل تعبيرٍ نمطيّ في ملفٍّ يخلط الاتجاهين تُقرأ صحيحةً
  // بالعين وقد تُخزَّن بترتيبٍ آخر، فلا يُطابق النمطُ شيئاً ولا يظهر
  // لذلك أثر — يمرّ السؤالان مفتاحين لا مفتاحاً.
  //
  // وحرفيّاتُ regex لا قوالبُ نصّية: القالب يبتلع `\s` فيصير `s`،
  // فيتحوّل حدُّ الكلمة إلى مطابقةِ حرفٍ لا وجود له.
  //
  // و`(?=\s|$)` لا `\b`: الثانية تعرف حروف ASCII وحدها، فهي مع العربية
  // تضع حدّاً حيث لا حدّ وتُسقطه حيث يجب.
  const MA = "ما"; // ما
  const MIN = "من"; // من

  text = text
    // الملتصق يُفصل أوّلاً: «ماهي» كلمةٌ واحدة قبل هذا السطر.
    .replace(/^ما(?:هي|هو)(?=\s|$)/u, MA)
    .replace(/^من(?:هي|هو)(?=\s|$)/u, MIN)
    // ثم المفصول.
    .replace(/^ما\s+(?:هي|هو)(?=\s|$)/u, MA)
    .replace(/^من\s+(?:هي|هو)(?=\s|$)/u, MIN)
    .replace(/\s+/g, " ")
    .trim();

  return text;
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
