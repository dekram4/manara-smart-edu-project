/**
 * كمّياتُ السؤال: أرقامُه ووحداتُ قياسه.
 *
 * ── لماذا وحدةٌ مستقلّة عن التطبيع ──
 * التطبيعُ يجمع ما اتّحد معناه واختلف لفظه، وهذه تفرّق ما اتّحد لفظه
 * واختلف مقدارُه. و«احسب محيط مستطيل طوله ٥ وعرضه ٣» و«احسب محيط
 * مستطيل طوله ٧ وعرضه ٣» سؤالٌ واحد في كل كلمةٍ إلا رقماً — فيقيسهما
 * كلُّ مقياسٍ لفظيّ أو دلاليّ متطابقين تقريباً، ويُعاد جوابُ الأول على
 * الثاني.
 *
 * وهذا أسوأ ما تفعله ذاكرة: لا أن تخيب، بل أن تُصيب بثقةٍ في السؤال
 * الخطأ. فالطفل يقرأ «المحيط ١٦» لمسألةٍ محيطُها ٢٠، وليس في الشاشة ما
 * يقول له إن الجواب ليس جوابَ مسألته.
 *
 * فالأرقامُ شرطٌ قاطعٌ قبل أيّ إصابةٍ في الذاكرة: تتطابق كلُّها أو
 * يُسأل النموذج من الصفر.
 */

/** الأرقام العربية-الهندية والفارسية إلى أرقامٍ يُقارَن بها. */
function asciiDigits(input: string): string {
  return input
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06f0));
}

/**
 * يوحّد ما لا يُغيّر المقدار: التشكيل والهمزات والتاء المربوطة.
 *
 * الوحدةُ تُقارَن بوحدة، وأحدُ الطرفين يأتي مطبَّعاً من مفتاحٍ محفوظ
 * والآخر كما كتبه الطفل. فلولا هذا لكانت «دقيقة» و«دقيقه» وحدتين.
 */
function fold(input: string): string {
  return asciiDigits(input.toLowerCase())
    .replace(/[ً-ْٰـ]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه");
}

/**
 * وحداتُ القياس التي تُعَدّ جزءاً من المسألة.
 *
 * ── لماذا الوحدة مع الرقم ──
 * «٥ كم» و«٥ سم» رقمٌ واحد ومسألتان، وجوابُهما يختلف بمئة ألف. فلو
 * قُصر الشرط على الأرقام لطابقت إحداهما الأخرى.
 *
 * ومكتوبةٌ مطبَّعةً كما يخرج من [fold]: التاءُ المربوطة هاءً، فلا
 * تُكتب «ثانية» و«ثانيه» سطرين.
 */
const UNITS = new Set([
  // الطول.
  "مم", "سم", "م", "كم",
  "مليمتر", "سنتمتر", "متر", "كيلومتر",
  "mm", "cm", "m", "km",
  "millimeter", "centimeter", "meter", "kilometer",
  "millimeters", "centimeters", "meters", "kilometers",
  // الكتلة.
  "جم", "جرام", "كجم", "كيلو", "كيلوجرام", "طن",
  "mg", "g", "kg", "gram", "grams", "kilogram", "kilograms", "ton", "tons",
  // السعة.
  "مل", "لتر", "مليلتر",
  "ml", "l", "liter", "liters", "litre", "litres",
  // الزمن.
  "ثانيه", "دقيقه", "ساعه", "يوم", "اسبوع", "شهر", "سنه",
  "sec", "second", "seconds", "min", "minute", "minutes",
  "hour", "hours", "day", "days", "week", "weeks",
  "month", "months", "year", "years",
  // والمال وما يُقاس في كتب المرحلة غيرَهما.
  "ريال", "هلله", "درجه", "مئويه", "قطعه", "صفحه",
  "riyal", "riyals", "degree", "degrees", "celsius",
  "page", "pages", "piece", "pieces", "percent",
]);

/**
 * العباراتُ التوجيهية التي تُحذف من صدر المسألة، وهي كلُّ ما يُحذف منها.
 *
 * ── لماذا هذه القائمة وحدها ──
 * المسألةُ اللفظية كلامٌ وأرقام، وكلُّ كلمةٍ فيها قد تكون شرطاً: «طوله»
 * و«عرضه» و«أكثر» و«أقل» و«لكلٍّ منهم». فحذفُ أدوات الاستفهام وحشوِ
 * المقدّمات — وهو الصواب في سؤالٍ عن مفهوم — يُسقط من المسألة ما يحمل
 * العلاقة بين أرقامها. فلا يُحذف منها إلا ما لا يحتمل إلا الطلب.
 *
 * ومرتَّبةٌ من الأطول إلى الأقصر، فـ«أوجد قيمة» تُطابق كلمتيها لا
 * كلمةً واحدةً تترك «قيمة» في المفتاح.
 */
export const MATH_OPENERS: readonly string[] = [
  "ما هو ناتج",
  "ما هي نتيجه",
  "ما هو حل",
  "ما ناتج",
  "ما نتيجه",
  "ما حل",
  "اوجد قيمه",
  "جد قيمه",
  "كم يساوي",
  "كم ناتج",
  "احسب",
  "اوجد",
  "جد",
  "حل",
  "بسط",
  "what is the value of",
  "find the value of",
  "how much is",
  "work out",
  "calculate",
  "evaluate",
  "compute",
  "solve",
];

/**
 * أرقامُ السؤال، بترتيب ورودها وبصورةٍ واحدة.
 *
 * ── لماذا الترتيب يُحفظ ──
 * «١٢ ÷ ٤» و«٤ ÷ ١٢» رقمان بعينهما وجوابان مختلفان. فلو قُورنت
 * الأرقامُ مجموعةً بلا ترتيب لطابقت المسألتان.
 *
 * و«٥» و«٠٥» و«٥٫٠» رقمٌ واحد كُتب ثلاثاً، فتُوحَّد صورتُه — وإلا
 * أخفقت مسألةٌ في مطابقة نفسها.
 */
export function mathNumbers(value: unknown): string[] {
  const text = asciiDigits(String(value ?? ""));
  const found = text.match(/\d+(?:\.\d+)?/g) ?? [];
  return found.map((raw) => {
    const number = Number(raw);
    // ورقمٌ أطولُ من دقّة `double` يُقارَن بحرفه: تحويلُه يُدخل فرقاً
    // ليس في السؤال.
    return Number.isFinite(number) ? String(number) : raw;
  });
}

/**
 * وحداتُ القياس الملاصقة لأرقام السؤال، بترتيب ورودها.
 *
 * تُقرأ الكلمةُ التالية للرقم وحدها: «٥ كم» وحدتُها «كم»، و«٥ تفاحات»
 * لا وحدةَ لها — و«تفاحات» كلمةٌ تحملها المطابقةُ اللفظية على كل حال.
 * فلا يُحصى هنا إلا ما يُغيّر المقدار.
 */
export function mathUnits(value: unknown): string[] {
  const text = fold(String(value ?? ""));
  const units: string[] = [];
  // الوحدةُ تلي رقمها، بمسافةٍ أو بلا مسافة: «٥كم» و«٥ كم» سواء. و«%»
  // تأتي رمزاً لا كلمةً، فهي في الاختيار نفسه.
  for (const match of text.matchAll(/(\d+(?:\.\d+)?)\s*(\p{L}+|%)/gu)) {
    const word = match[2]!;
    if (word === "%" || UNITS.has(word)) units.push(word);
  }
  return units;
}

/**
 * هل هذا سؤالٌ حسابيّ؟
 *
 * ── لماذا يُسأل أصلاً ──
 * التطبيعُ يحذف من صدر السؤال ما لا يحمل معنى، والمسألةُ لا تتحمّل ذلك
 * — فيُعرَف أيُّهما قبل أن يُحذف شيء.
 *
 * ورقمٌ وحده لا يكفي: «كم عدد قارات العالم» ليس مسألة. فيُشترط معه
 * عمليةٌ، أو وحدةُ قياس، أو رقمٌ ثانٍ — أو عبارةُ طلبٍ صريحة في صدره.
 */
export function isMathQuestion(value: unknown): boolean {
  const text = fold(String(value ?? ""));
  const words = text.split(/\s+/).filter(Boolean);
  for (const opener of MATH_OPENERS) {
    const parts = opener.split(" ");
    if (parts.every((part, index) => words[index] === part)) return true;
  }
  const numbers = mathNumbers(text);
  if (numbers.length === 0) return false;
  if (numbers.length >= 2) return true;
  if (mathUnits(text).length > 0) return true;
  return /[+\-*/=^()]/.test(text);
}

export interface MathSignature {
  /** هل يُعامَل السؤال معاملةَ مسألة؟ */
  math: boolean;
  /** أرقامُه بترتيبها. */
  numbers: string[];
  /** ووحداتُها. */
  units: string[];
}

export function mathSignature(value: unknown): MathSignature {
  return {
    math: isMathQuestion(value),
    numbers: mathNumbers(value),
    units: mathUnits(value),
  };
}

const sameList = (a: readonly string[], b: readonly string[]): boolean =>
  a.length === b.length && a.every((item, index) => item === b[index]);

/**
 * هل السؤالان عن المقادير نفسها؟
 *
 * الشرطُ يُطبَّق على كل سؤالٍ فيه رقم لا على المسائل وحدها: «اذكر ٣
 * فوائد» و«اذكر ٥ فوائد» ليسا مسألتين حسابيتين، وجوابُهما مختلف. وهو
 * يمرّ بلا كلفةٍ على ما لا رقمَ فيه — وهو أكثرُ ما يُسأل.
 *
 * ولا يُقاس تشابهٌ هنا ولا تُحتمل نسبة: تتطابق الأرقامُ والوحدات كلُّها
 * أو لا يُجاب من الذاكرة. الفرقُ في رقمٍ واحد فرقٌ في الجواب كلِّه.
 */
export function sameQuantities(a: unknown, b: unknown): boolean {
  const left = mathSignature(a);
  const right = mathSignature(b);
  return (
    sameList(left.numbers, right.numbers) && sameList(left.units, right.units)
  );
}
