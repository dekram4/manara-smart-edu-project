import { LESSON_TEXT_SAFETY_LIMIT, fullLessonText } from "./lessonText";
/**
 * توليدُ بنك أسئلة الاختبارات من نصّ الدرس — التوجيهُ، والمخطّط، وقراءةُ الردّ.
 *
 * ── ما كان ──
 * كان التوجيهُ يُكتب في المتصفّح ويُرسل نصّاً حرّاً: «أسئلة متنوعة تغطي
 * المحتوى»، وأوّلُ ألفي حرفٍ من الدرس وحدها. فجاءت الأسئلةُ نقلاً حرفياً
 * لجُمل البداية («ما هو …؟» وجوابُه السطرُ نفسه)، وخياراتٌ مضلّلةٌ لا تضلّل،
 * والجوابُ الصحيح في الموضع الأول غالباً.
 *
 * ── ما صار ──
 *   • توجيهُ نظامٍ بضوابط تربوية ثابتة على الخادم، لا يغيّره طلب.
 *   • نصُّ الدرس كاملاً — انظر `lib/lessonText`.
 *   • مخطّطُ JSON صارم يفرضه النموذج نفسه ([QUIZ_RESPONSE_SCHEMA]).
 *   • وما يعود يُفحص هنا ([parseQuizQuestions]): ما لا يصلح يُردّ، والمكرّرُ
 *     يسقط، وموضعُ الجواب الصحيح يُوزَّع على الخيارات الأربعة.
 *
 * والصيغةُ الخارجة هي صيغةُ التطبيق المعتمدة كما هي:
 *   { question, options: [4], correctAnswer: "A"|"B"|"C"|"D" }
 *
 * بلا قاعدة بيانات ولا شبكة، فيُختبر وحده.
 */

export const LETTERS = ["A", "B", "C", "D"] as const;
export type AnswerLetter = (typeof LETTERS)[number];

export interface QuizQuestion {
  question: string;
  options: string[];
  correctAnswer: AnswerLetter;
}

/** أقصى أسئلةٍ في البنك الواحد. */
export const MAX_BANK_SIZE = 60;
/** حدُّ الأمان وحده — النصُّ يُرسل كاملاً. انظر `lib/lessonText`. */
export const MAX_LESSON_CHARS = LESSON_TEXT_SAFETY_LIMIT;

/** مستوياتُ التفكير المقبولة — لا «تذكّر» بينها. */
export const COGNITIVE_LEVELS = ["فهم", "تطبيق", "تحليل", "استنتاج"] as const;

export const QUIZ_SYSTEM_INSTRUCTION = `أنت خبير تقويم تربوي ومصمّم اختبارات محترف لمنصّة تعليمية عربية، تكتب أسئلة اختيار من متعدد لطلاب المدارس.

مهمتك: بناء بنك أسئلة يقيس الفهم الحقيقي لمحتوى الدرس المرفق، لا الحفظ.

ضوابط صارمة لكل سؤال:
1) قِس الفهم والتطبيق والتحليل والاستنتاج — لا التذكّر الحرفي. وزّع الأسئلة تقريباً: ٣٥٪ فهم، ٣٠٪ تطبيق، ٢٠٪ تحليل، ١٥٪ استنتاج.
2) لا تنسخ جملة من النص ثم تحذف منها كلمة، ولا تجعل الجواب الصحيح عبارةً منقولة حرفياً من الدرس. أعد الصياغة بلغتك، واستعمل مواقف وأمثلة جديدة من حياة الطالب تتطلّب توظيف المفهوم.
3) كل سؤال مستند إلى معلومة أو مفهوم وارد في الدرس فعلاً — لا تسأل عمّا لم يُشرح فيه، ولا تعتمد على معرفة خارجية.
4) غطِّ الدرس كله بتوازن: كل مفهوم رئيسي، من أوله إلى آخره، ولا تكرر فكرة واحدة بصياغات مختلفة.
5) أربعة خيارات بالضبط، إجابة واحدة صحيحة قطعاً بلا جدال.
6) الخيارات المضلِّلة ذكية: كل خيار خاطئ يمثّل خطأً شائعاً أو تصوّراً بديلاً حقيقياً يقع فيه الطلاب، معقول ظاهرياً لمن لم يفهم، ومن جنس الإجابة الصحيحة وبطولٍ قريب منها. لا خيارات سخيفة أو بعيدة أو مكشوفة.
7) ممنوع: «جميع ما سبق»، «كل ما سبق»، «لا شيء مما سبق»، «أ و ب معاً»، والنفي المزدوج، والتلميح إلى الإجابة من صياغة السؤال، والأسئلة المبهمة.
8) لغة عربية فصيحة سليمة واضحة، مناسبة لعمر الطالب في المرحلة المذكورة: جمل قصيرة، ومفردات من مستواه.
9) نصّ السؤال مكتمل يُفهم وحده دون الرجوع إلى الدرس.
10) إن كانت مادة الدرس اللغة الإنجليزية فاكتب السؤال وخياراته بالإنجليزية.

صيغة الإخراج: JSON فقط مطابق للمخطط المعطى، بلا أي نص قبله أو بعده، وبلا Markdown.
- "question": نص السؤال.
- "options": أربعة نصوص، بلا ترقيم أو حروف في أولها.
- "correctAnswer": حرف موضع الإجابة الصحيحة: "A" أو "B" أو "C" أو "D".
- "cognitiveLevel": أحد: ${COGNITIVE_LEVELS.join("، ")}.`;

/** مخطّطُ الردّ بصيغة Gemini (`generationConfig.responseSchema`). */
export const QUIZ_RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    questions: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          question: { type: "STRING" },
          options: { type: "ARRAY", items: { type: "STRING" }, minItems: 4, maxItems: 4 },
          correctAnswer: { type: "STRING", enum: [...LETTERS] },
          cognitiveLevel: { type: "STRING", enum: [...COGNITIVE_LEVELS] },
        },
        required: ["question", "options", "correctAnswer", "cognitiveLevel"],
        propertyOrdering: ["question", "options", "correctAnswer", "cognitiveLevel"],
      },
    },
  },
  required: ["questions"],
} as const;

export interface QuizRequest {
  lessonContent: string;
  count: number;
  grade?: string;
  subject?: string;
  unit?: string;
  lesson?: string;
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/** عددُ الأسئلة المطلوب، محصوراً في [1, MAX_BANK_SIZE]. */
export function clampCount(value: unknown): number {
  const count = Math.trunc(Number(value));
  return Number.isFinite(count) ? Math.min(Math.max(count, 1), MAX_BANK_SIZE) : 10;
}

/** نصُّ الدرس بحدّه، مقطوعاً عند آخر نهاية جملة قبل الحدّ لا وسط كلمة. */
export function trimLesson(content: string, limit = MAX_LESSON_CHARS): string {
  return fullLessonText(content, limit);
}

/** رسالةُ المستخدم: سياقُ الدرس ونصُّه والعدد. الضوابطُ في توجيه النظام. */
export function quizPrompt(request: QuizRequest): string {
  const count = clampCount(request.count);
  const context = [
    ["الصف / المرحلة", text(request.grade)],
    ["المادة", text(request.subject)],
    ["الوحدة", text(request.unit)],
    ["الدرس", text(request.lesson)],
  ]
    .filter(([, value]) => value)
    .map(([label, value]) => `- ${label}: ${value}`)
    .join("\n");
  return `ابنِ بنك أسئلة من ${count} سؤال اختيار من متعدد بالضبط من محتوى الدرس التالي، وفق الضوابط.
سيختار النظام لكل طالب مجموعة مختلفة من هذا البنك، فاجعل كل سؤال مستقلاً ومتفاوت الصعوبة بين السهل والمتوسط والمتقدم.
${context ? `\nسياق الدرس:\n${context}\n` : ""}
محتوى الدرس:
"""
${trimLesson(request.lessonContent)}
"""`;
}

const BANNED_OPTION = /(جميع|كل|لا\s*شيء)\s*(مما|ما)\s*سبق|all of the above|none of the above|both a and b/i;
const OPTION_PREFIX = /^\s*(?:[(\[]?\s*(?:[A-Da-d]|[أبجد]|[1-4١-٤])\s*[)\].:\-–]\s*)/;

function normalizeForCompare(value: string): string {
  return value
    .toLowerCase()
    .replace(/[ً-ْٰـ]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim();
}

/** يقرأ JSON من ردّ النموذج: نصّاً، أو داخل سياج Markdown، أو مصفوفةً مجرّدة. */
export function extractQuestions(raw: unknown): unknown[] {
  let value: unknown = raw;
  if (typeof value === "string") {
    const cleaned = value.replace(/^\s*```(?:json)?\s*/i, "").replace(/\s*```\s*$/i, "").trim();
    try {
      value = JSON.parse(cleaned);
    } catch {
      const start = cleaned.search(/[[{]/);
      const end = Math.max(cleaned.lastIndexOf("]"), cleaned.lastIndexOf("}"));
      if (start < 0 || end <= start) return [];
      try {
        value = JSON.parse(cleaned.slice(start, end + 1));
      } catch {
        return [];
      }
    }
  }
  if (Array.isArray(value)) return value;
  if (value && typeof value === "object" && Array.isArray((value as { questions?: unknown }).questions)) {
    return (value as { questions: unknown[] }).questions;
  }
  return [];
}

/** حرفُ الجواب من «A» أو «b» أو رقمٍ 0–3 أو 1–4 أو نصِّ الخيار نفسه. */
function answerIndex(value: unknown, options: string[]): number {
  if (typeof value === "number" && Number.isInteger(value)) {
    if (value >= 0 && value <= 3) return value;
    return -1;
  }
  const raw = text(value);
  const letter = raw.toUpperCase();
  const byLetter = LETTERS.indexOf(letter as AnswerLetter);
  if (byLetter >= 0) return byLetter;
  const arabic = ["أ", "ب", "ج", "د"].indexOf(raw);
  if (arabic >= 0) return arabic;
  const wanted = normalizeForCompare(raw);
  return wanted ? options.findIndex((option) => normalizeForCompare(option) === wanted) : -1;
}

export type RejectReason =
  | "shape"
  | "options"
  | "answer"
  | "banned_option"
  | "duplicate"
  | "answer_in_question";

/**
 * مواضعُ الجواب الصحيح في كل أربعة أسئلة متتالية: كلُّ موضعٍ مرّةً في الكتلة،
 * وترتيبُها يتبدّل من كتلةٍ إلى أخرى فلا يُحفظ نمط.
 */
const POSITION_BLOCKS = [
  [2, 0, 3, 1],
  [1, 3, 0, 2],
  [3, 1, 2, 0],
  [0, 2, 1, 3],
] as const;

/**
 * يفحص ما عاد به النموذج، ويُعيد الصالح بصيغة التطبيق، بحدّ [count].
 *
 * ومواضعُ الجواب الصحيح تُوزَّع بالتساوي على الخيارات ([POSITION_BLOCKS]):
 * النماذجُ تضعه أوّلاً في الغالب، فيكسب من يختار «أ» دائماً. والخياراتُ الخاطئة تبقى
 * بترتيبها.
 */
export function parseQuizQuestions(
  raw: unknown,
  count: number,
): { questions: QuizQuestion[]; rejected: Partial<Record<RejectReason, number>> } {
  const rejected: Partial<Record<RejectReason, number>> = {};
  const reject = (reason: RejectReason) => {
    rejected[reason] = (rejected[reason] ?? 0) + 1;
  };
  const seen = new Set<string>();
  const questions: QuizQuestion[] = [];

  for (const item of extractQuestions(raw)) {
    if (questions.length >= clampCount(count)) break;
    if (!item || typeof item !== "object") {
      reject("shape");
      continue;
    }
    const record = item as Record<string, unknown>;
    const question = text(record.question);
    const options = Array.isArray(record.options)
      ? record.options.map((option) => text(option).replace(OPTION_PREFIX, "").trim())
      : [];
    if (question.length < 8) {
      reject("shape");
      continue;
    }
    const distinct = new Set(options.map(normalizeForCompare));
    if (options.length !== 4 || options.some((option) => !option) || distinct.size !== 4 || distinct.has("")) {
      reject("options");
      continue;
    }
    if (options.some((option) => BANNED_OPTION.test(option))) {
      reject("banned_option");
      continue;
    }
    const correct = answerIndex(record.correctAnswer, options);
    if (correct < 0) {
      reject("answer");
      continue;
    }
    // الجوابُ مكتوبٌ في نصّ السؤال نفسه: سؤالٌ يُجاب بالنظر لا بالفهم.
    const correctText = normalizeForCompare(options[correct]);
    if (correctText.length >= 6 && normalizeForCompare(question).includes(correctText)) {
      reject("answer_in_question");
      continue;
    }
    const key = normalizeForCompare(question);
    if (seen.has(key)) {
      reject("duplicate");
      continue;
    }
    seen.add(key);

    const target = POSITION_BLOCKS[Math.floor(questions.length / 4) % POSITION_BLOCKS.length][questions.length % 4];
    const distractors = options.filter((_, index) => index !== correct);
    const arranged = [...distractors];
    arranged.splice(target, 0, options[correct]);
    questions.push({ question, options: arranged, correctAnswer: LETTERS[target] });
  }
  return { questions, rejected };
}
