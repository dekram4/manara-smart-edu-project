/**
 * بنكُ الأعداد والحساب: أسئلةٌ تُولَّد ولا تُكتب، فلا تنفد ولا تتكرّر.
 *
 * ── لماذا التوليد ──
 * البنكُ المكتوب في `duelQuestions.ts` واحدٌ وخمسون سؤالاً، والمباراةُ عشرة.
 * فبعد خمس مبارياتٍ بين الزملاء أنفسهم يعود السؤالُ نفسه ويُحفظ جوابُه لا
 * يُفكَّر فيه. والحسابُ يُولَّد: كلُّ مباراةٍ ببذرتها أعدادٌ جديدة وأبوابٌ
 * بترتيبٍ جديد، فيبقى السؤالُ سؤالاً.
 *
 * ── الأبواب ──
 * الجمعُ والطرحُ والضربُ والقسمة، وقيمةُ الرقم في منزلته، ومقارنةُ الأعداد،
 * والكسورُ البسيطة، والأنماط، والتقريب — ما يدرسه طفلُ المرحلة الابتدائية.
 *
 * والمشتّتاتُ قريبةٌ من الجواب لا سخيفة: خطأٌ في منزلةٍ، أو زيادةُ واحد،
 * أو عكسُ العملية — الأخطاءُ التي يقع فيها الطفل فعلاً.
 */

export type MathSection =
  | "addition"
  | "subtraction"
  | "multiplication"
  | "division"
  | "placeValue"
  | "compare"
  | "fractions"
  | "patterns"
  | "rounding";

export const MATH_SECTIONS: readonly MathSection[] = [
  "addition",
  "subtraction",
  "multiplication",
  "division",
  "placeValue",
  "compare",
  "fractions",
  "patterns",
  "rounding",
];

export interface MathQuestion {
  section: MathSection;
  prompt: string;
  /** الجوابُ أوّلاً ثم المشتّتات (ثلاثةٌ عادةً). */
  choices: [string, ...string[]];
}

const DIGITS = "٠١٢٣٤٥٦٧٨٩";

/** الأرقامُ العربية في نصّ السؤال، كما في كتاب الطفل. */
export function arabicDigits(value: number | string): string {
  return String(value).replace(/[0-9]/g, (d) => DIGITS[Number(d)]);
}

function int(next: () => number, min: number, max: number): number {
  return min + Math.floor(next() * (max - min + 1));
}

/** ثلاثةُ مشتّتاتٍ مختلفةٍ عن الجواب وعن بعضها، موجبةٌ، من المرشّحين أوّلاً. */
function distractors(
  answer: number,
  candidates: number[],
  next: () => number,
): [string, string, string] {
  const picked = new Set<number>();
  for (const value of candidates) {
    if (picked.size === 3) break;
    if (Number.isInteger(value) && value >= 0 && value !== answer) picked.add(value);
  }
  let spread = 1;
  while (picked.size < 3) {
    const value = answer + (next() < 0.5 ? -spread : spread);
    if (value >= 0 && value !== answer) picked.add(value);
    spread += 1;
  }
  const [a, b, c] = [...picked];
  return [String(a), String(b), String(c)];
}

function numeric(
  section: MathSection,
  prompt: string,
  answer: number,
  candidates: number[],
  next: () => number,
): MathQuestion {
  return {
    section,
    prompt,
    choices: [String(answer), ...distractors(answer, candidates, next)],
  };
}

const PLACE_NAMES = ["الآحاد", "العشرات", "المئات", "الألوف"];

/** سؤالٌ واحد من [section]، بأعدادٍ من [next]. */
export function generateMathQuestion(section: MathSection, next: () => number): MathQuestion {
  switch (section) {
    case "addition": {
      const a = int(next, 12, 89);
      const b = int(next, 6, 59);
      const sum = a + b;
      return numeric(
        section,
        `ما ناتجُ ${arabicDigits(a)} + ${arabicDigits(b)}؟`,
        sum,
        // نسيانُ الحمل، وزيادةُ عشرة، وخطأُ واحد.
        [sum - 10, sum + 10, sum + 1, sum - 1],
        next,
      );
    }
    case "subtraction": {
      const a = int(next, 30, 99);
      const b = int(next, 7, a - 5);
      const diff = a - b;
      return numeric(
        section,
        `ما ناتجُ ${arabicDigits(a)} − ${arabicDigits(b)}؟`,
        diff,
        [diff + 10, diff - 10, a + b, diff + 1],
        next,
      );
    }
    case "multiplication": {
      const a = int(next, 2, 9);
      const b = int(next, 3, 10);
      const product = a * b;
      return numeric(
        section,
        `ما ناتجُ ${arabicDigits(a)} × ${arabicDigits(b)}؟`,
        product,
        // جدولُ الجار، والجمعُ بدل الضرب.
        [a * (b + 1), a * (b - 1), a + b, product + a],
        next,
      );
    }
    case "division": {
      const divisor = int(next, 2, 9);
      const quotient = int(next, 2, 10);
      const dividend = divisor * quotient;
      return numeric(
        section,
        `ما ناتجُ ${arabicDigits(dividend)} ÷ ${arabicDigits(divisor)}؟`,
        quotient,
        [quotient + 1, quotient - 1, divisor, quotient + 2],
        next,
      );
    }
    case "placeValue": {
      // عددٌ من أربع خانات بأرقامٍ مختلفة، فلا يلتبس أيُّ رقمٍ يُقصد.
      const digits: number[] = [];
      while (digits.length < 4) {
        const d = int(next, digits.length === 0 ? 1 : 0, 9);
        if (!digits.includes(d)) digits.push(d);
      }
      const number = Number(digits.join(""));
      const place = int(next, 0, 3); // 0 آحاد … 3 ألوف
      const digit = digits[3 - place];
      if (next() < 0.5 && digit !== 0) {
        const value = digit * 10 ** place;
        return numeric(
          section,
          `ما قيمةُ الرقم ${arabicDigits(digit)} في العدد ${arabicDigits(number)}؟`,
          value,
          // القيمةُ في المنازل الأخرى: الخطأُ الذي يُعلَّم هذا البابُ لمنعه.
          [0, 1, 2, 3].filter((p) => p !== place).map((p) => digit * 10 ** p),
          next,
        );
      }
      const others = PLACE_NAMES.filter((_, i) => i !== place);
      return {
        section,
        prompt: `في أيِّ منزلةٍ يقع الرقم ${arabicDigits(digit)} في العدد ${arabicDigits(number)}؟`,
        choices: [PLACE_NAMES[place], others[0], others[1], others[2]],
      };
    }
    case "compare": {
      if (next() < 0.5) {
        // أكبرُ عددٍ من أربعة متقاربة: تختلف في منزلةٍ واحدةٍ على الأقل.
        const base = int(next, 120, 880);
        const set = new Set<number>([base]);
        while (set.size < 4) set.add(base + int(next, -90, 90));
        const values = [...set];
        const max = Math.max(...values);
        return {
          section,
          prompt: `أيُّ هذه الأعداد هو الأكبر؟`,
            choices: [String(max), ...values.filter((v) => v !== max).map(String)],
        };
      }
      const a = int(next, 100, 999);
      let b = int(next, 100, 999);
      if (next() < 0.2) b = a;
      const sign = a > b ? ">" : a < b ? "<" : "=";
      // ثلاثةُ خياراتٍ لا أربعة: رابعٌ مثل «≠» يصحّ مع «>» و«<» فيصير للسؤال جوابان.
      const rest = [">", "<", "="].filter((s) => s !== sign);
      return {
        section,
        prompt: `اختر الإشارةَ المناسبة: ${arabicDigits(a)} ⬜ ${arabicDigits(b)}`,
        choices: [sign, rest[0], rest[1]],
      };
    }
    case "fractions": {
      const kind = int(next, 0, 2);
      if (kind === 0) {
        const whole = int(next, 2, 12) * 2;
        const half = whole / 2;
        return numeric(
          section,
          `ما نصفُ العدد ${arabicDigits(whole)}؟`,
          half,
          [whole, half + 1, half - 1, whole * 2],
          next,
        );
      }
      if (kind === 1) {
        const whole = int(next, 2, 10) * 4;
        const quarter = whole / 4;
        return numeric(
          section,
          `ما ربعُ العدد ${arabicDigits(whole)}؟`,
          quarter,
          [whole / 2, quarter + 1, quarter - 1, whole],
          next,
        );
      }
      const pieces = int(next, 3, 8);
      const taken = int(next, 1, pieces - 1);
      return {
        section,
        prompt: `قُسِّمت كعكةٌ إلى ${arabicDigits(pieces)} قطع متساوية، وأُكلت ${arabicDigits(taken)} منها. ما الكسرُ الذي أُكل؟`,
        choices: [
          `${arabicDigits(taken)}/${arabicDigits(pieces)}`,
          // «الباقي» مشتّتٌ إلا حين يساوي ما أُكل — النصفُ تماماً — فيصير جواباً ثانياً.
          `${arabicDigits(2 * taken === pieces ? taken + 1 : pieces - taken)}/${arabicDigits(pieces)}`,
          `${arabicDigits(pieces)}/${arabicDigits(taken)}`,
          `${arabicDigits(taken)}/${arabicDigits(pieces + 1)}`,
        ],
      };
    }
    case "patterns": {
      const step = int(next, 2, 12) * (next() < 0.25 ? -1 : 1);
      const start = step < 0 ? int(next, 60, 120) : int(next, 1, 40);
      const seq = [0, 1, 2, 3].map((i) => start + step * i);
      const answer = start + step * 4;
      return numeric(
        section,
        `أكمل النمط: ${seq.map(arabicDigits).join("، ")}، ...`,
        answer,
        [answer + step, answer - 1, answer + 1, seq[3]],
        next,
      );
    }
    case "rounding": {
      const tens = next() < 0.6;
      const value = tens ? int(next, 11, 99) : int(next, 110, 990);
      const unit = tens ? 10 : 100;
      // نصفُ المسافة يُقرَّب للأعلى، كما في الكتاب.
      const rounded = Math.round(value / unit) * unit;
      return numeric(
        section,
        `قرِّب العدد ${arabicDigits(value)} لأقرب ${tens ? "عشرة" : "مئة"}.`,
        rounded,
        [rounded + unit, rounded - unit, value],
        next,
      );
    }
  }
}

/**
 * [count] سؤالاً من أبوابٍ مختلفة بالتناوب، بلا نصٍّ مكرَّر.
 *
 * الأبوابُ تُخلط بالبذرة ثم تُدار، فلا يأتي بابٌ مرّتين متتابعتين ما دام في
 * الأبواب ما لم يأتِ.
 */
export function generateMathSet(count: number, next: () => number): MathQuestion[] {
  const order = [...MATH_SECTIONS];
  for (let i = order.length - 1; i > 0; i -= 1) {
    const j = Math.floor(next() * (i + 1));
    [order[i], order[j]] = [order[j], order[i]];
  }
  const seen = new Set<string>();
  const out: MathQuestion[] = [];
  let turn = 0;
  let guard = 0;
  while (out.length < count && guard < count * 20) {
    guard += 1;
    const question = generateMathQuestion(order[turn % order.length], next);
    turn += 1;
    if (seen.has(question.prompt)) continue;
    seen.add(question.prompt);
    out.push(question);
  }
  return out;
}
