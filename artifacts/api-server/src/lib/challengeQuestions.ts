/**
 * محرّك أسئلة «بطاقة التحدي»: بناء التوجيه، وتصفية ما يعود.
 *
 * مفصول عن المسار عمداً، وخالٍ من Express: قواعد القبول هنا هي أكثر ما
 * يُخطئ على نصٍّ حقيقي، ولا يُرى خطؤها من اختبارٍ يمرّ بالشبكة. وهي
 * تُختبر مباشرةً بدل أن تُستنتج من ردٍّ.
 *
 * ── لماذا التوليد عند كل محاولة ──
 * البنك المحفوظ يصلح للاختبار: أسئلةٌ ثابتةٌ تُصحَّح وتُقارَن. والتحدي
 * لعبةٌ تُعاد، وإعادتُها على الأسئلة نفسها تُحوّلها إلى حفظِ ترتيبٍ لا
 * تفكير. فيُولَّد عند كل محاولة، ويُمرَّر معه ما رآه الطالب قبل قليل كي
 * لا يعود.
 */

export type ChallengeSubject = "english" | "math" | "science" | "other";

export interface ChallengeQuestion {
  question: string;
  options: string[];
  correctAnswer: string;
  explanation: string;
}

const text = (value: unknown): string =>
  value == null ? "" : String(value).trim();

/** تسوية عربية للمقارنة: الهمزة لا تصنع خياراً ثانياً. */
export function norm(value: unknown): string {
  return text(value)
    .toLowerCase()
    .replace(/[ً-ْٰـ]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/\s+/g, " ")
    .trim();
}

/** المادة بحسب اسمها، مهما اختلفت همزتُه أو تشكيلُه. */
export function detectSubject(subject: unknown): ChallengeSubject {
  const wanted = norm(subject);
  if (!wanted) return "other";
  if (wanted.includes("انجليز") || wanted.includes("english")) return "english";
  if (wanted.includes("رياضيات") || wanted.includes("math")) return "math";
  if (wanted.includes("علوم") || wanted.includes("science")) return "science";
  return "other";
}

/**
 * يُزيل ترميز المعادلات من نصٍّ عاد من النموذج.
 *
 * `\frac{3}{4}` تصير «3/4» فيسلم المعنى. وما لا يُعرف تحويله يُترك
 * أثرُه ظاهراً ليردّه `accept` — فالحذف الصامت يُخرج «ما ناتج 16؟» من
 * «ما ناتج \sqrt{16}؟»: سؤالاً بلا معنى يبدو سليماً.
 */
export function cleanText(value: unknown): string {
  return text(value)
    .replace(/\$\$([\s\S]*?)\$\$/g, "$1")
    .replace(/\$([^$\n]*?)\$/g, "$1")
    .replace(/\\\(([\s\S]*?)\\\)/g, "$1")
    .replace(/\\\[([\s\S]*?)\\\]/g, "$1")
    .replace(/\\(?:d|t)?frac\s*\{([^{}]*)\}\s*\{([^{}]*)\}/g, "$1/$2")
    .replace(/\\(?:times|cdot)\b/g, "×")
    .replace(/\\div\b/g, "÷")
    .replace(/\\(?:text|mathrm|mathbf|textbf|mbox)\s*\{([^{}]*)\}/g, "$1")
    .replace(/\$/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

/** أوامر LaTeX التي تُعرف تنقيتُها بلا خسارة معنى. */
const SAFE_COMMANDS =
  /^(?:d|t)?(?:frac|times|div|cdot|text|mathrm|mathbf|textbf|mbox|left|right)$/;

/** اسم أوّل أمرٍ لا تُعرف تنقيته، أو `null`. */
export function unsafeCommand(...values: unknown[]): string | null {
  for (const value of values) {
    for (const match of text(value).matchAll(/\\([a-zA-Z]+)/g)) {
      if (!SAFE_COMMANDS.test(match[1])) return match[1];
    }
  }
  return null;
}

const ARABIC = /[؀-ۿ]/;
const LATIN = /[A-Za-z]/;

export type Verdict =
  | { ok: true; question: ChallengeQuestion }
  | { ok: false; why: string };

/**
 * يقبل السؤال أو يردّه، ويقول لماذا.
 *
 * النموذج يخطئ بأشكالٍ معروفة تمرّ صامتةً إن لم تُفحص: خياراتٌ ثلاثة،
 * أو إجابةٌ صحيحة ليست منها، أو خياران متطابقان بعد التسوية، أو عربيّةٌ
 * في تحدّي الإنجليزية. وكلّها تصل إلى طفلٍ في صورة سؤالٍ بلا جواب.
 */
export function acceptQuestion(
  raw: unknown,
  subject: ChallengeSubject,
): Verdict {
  const item = (raw ?? {}) as Record<string, unknown>;
  const rawOptions = Array.isArray(item.options) ? item.options : [];

  const unsafe = unsafeCommand(item.question, item.explanation, ...rawOptions);
  if (unsafe) return { ok: false, why: `أمر LaTeX لا تُعرف تنقيته: \\${unsafe}` };

  const question = cleanText(item.question);
  const explanation = cleanText(item.explanation);
  const options = rawOptions.map(cleanText).filter(Boolean);
  const answer = cleanText(item.correctAnswer);

  if (question.length < 8) return { ok: false, why: "سؤال قصير أو فارغ" };
  if (options.length !== 4) {
    return { ok: false, why: `${options.length} خيارات لا أربعة` };
  }
  if (new Set(options.map(norm)).size !== 4) {
    return { ok: false, why: "خياران متطابقان" };
  }
  if (!options.some((option) => norm(option) === norm(answer))) {
    return { ok: false, why: "الإجابة الصحيحة ليست من الخيارات" };
  }

  const english = subject === "english";
  if (english && ARABIC.test([question, explanation, ...options].join(" "))) {
    return { ok: false, why: "حرف عربي في تحدّي الإنجليزية" };
  }
  if (!english && !ARABIC.test(question) && LATIN.test(question)) {
    return { ok: false, why: "سؤال بالإنجليزية في مادة عربية" };
  }

  // نصُّ الخيار الصحيح كما كُتب في الخيارات، لا كما كتبه النموذج ثانيةً:
  // فرقُ همزةٍ بينهما يجعل التصحيح في التطبيق يردّ الإجابة الصحيحة.
  const correctAnswer =
    options.find((option) => norm(option) === norm(answer)) ?? answer;

  return { ok: true, question: { question, options, correctAnswer, explanation } };
}

// ── بناء التوجيه ───────────────────────────────────────────────────────

const ENGLISH_RULES = `MANDATORY RULES:
- Write the question, ALL four options, and the explanation in ENGLISH ONLY. Not a single Arabic character anywhere.
- Target a 9-to-10-year-old EFL learner. Simple, correct, natural English.
- Focus on grammar, vocabulary, and choosing the right word for the context of a sentence, using only what this lesson teaches.
- Make it feel like a fast game round: short stems, no long reading passages.
- Four options: one correct, three plausible distractors a real learner might pick.
- "explanation" is ONE short English sentence saying why the answer is right.
- No LaTeX, no dollar signs, no backslashes.`;

const MATH_RULES = `القواعد الإلزامية:
- اكتب بالعربية المبسّطة بمستوى طفلٍ في الصف الرابع.
- اجعلها مسائل ذهنية لفظية تقيس سرعة البديهة والتفكير الرياضي: موقفٌ قصير ثمّ سؤال، لا تمريناً مجرّداً.
- ممنوع منعاً باتاً أيّ رمز LaTeX أو علامة دولار أو شرطة مائلة عكسية. اكتب الأرقام والعمليات نصّاً عادياً: "5 × 4 = 20"، و"ثلاثة أرباع" أو "3/4".
- استعمل القوانين والمفاهيم المذكورة في نصّ الدرس وحدها.
- أربعة خيارات: واحدٌ صحيح وثلاثةٌ خاطئة لكنها معقولة — خطأٌ يقع فيه طفلٌ فعلاً، لا خيارٌ سخيف.
- "explanation" سطرٌ واحد يشرح الطريق إلى الجواب لا يكرّر نصّ الخيار.`;

const SCIENCE_RULES = `القواعد الإلزامية:
- اكتب بالعربية المبسّطة بمستوى طفلٍ في الصف الرابع.
- ابنِ السؤال على ظاهرةٍ أو مفهومٍ مشروحٍ في نصّ الدرس: "ماذا يحدث لو…"، "لماذا…"، "أيّها مثالٌ على…".
- اسأل عن الفهم لا عن حفظ لفظٍ بعينه.
- أربعة خيارات: واحدٌ صحيح وثلاثةٌ خاطئة لكنها معقولة.
- "explanation" سطرٌ واحد يربط الجواب بما في الدرس.
- ممنوع أيّ رمز LaTeX أو علامة دولار.`;

const GENERIC_RULES = `القواعد الإلزامية:
- اكتب بالعربية المبسّطة بمستوى طفلٍ في الصف الرابع.
- استعمل ما في نصّ الدرس وحده.
- أربعة خيارات: واحدٌ صحيح وثلاثةٌ خاطئة لكنها معقولة.
- "explanation" سطرٌ واحد.
- ممنوع أيّ رمز LaTeX أو علامة دولار.`;

export function rulesFor(subject: ChallengeSubject): string {
  switch (subject) {
    case "english":
      return ENGLISH_RULES;
    case "math":
      return MATH_RULES;
    case "science":
      return SCIENCE_RULES;
    default:
      return GENERIC_RULES;
  }
}

const SCHEMA = `أعد JSON فقط، بلا أيّ نصّ قبله أو بعده، بهذا الشكل بالضبط:
{"questions":[{"question":"...","options":["...","...","...","..."],"correctAnswer":"...","explanation":"..."}]}
حيث "correctAnswer" نصُّ الخيار الصحيح حرفاً بحرف كما كُتب في "options".`;

export interface ChallengePromptInput {
  subject: string;
  unit?: string;
  lesson?: string;
  lessonText: string;
  count: number;
  /** بذرةُ الجولة: تدخل التوجيه فيتغيّر المخرَج بين محاولةٍ وأخرى. */
  seed: string;
  /** ما رآه الطالب في محاولاته القريبة، فلا يُعاد عليه. */
  exclude?: string[];
}

/**
 * أطول ما يُرسل من نصّ الدرس.
 *
 * الدرس كلّه يُرسل عادةً — أطولُ درسٍ في المناهج الثلاثة دون ألفَي حرف.
 * والحدّ لدرسٍ يكتبه معلّمٌ بيده فيطول: قطعُه أهونُ من طلبٍ يُردّ لطوله
 * فلا يجد الطفل تحدياً.
 */
const MAX_LESSON_CHARS = 6000;

/** أكثر ما يُذكر من أسئلةٍ سابقة، فلا ينتفخ التوجيه بلا فائدة. */
const MAX_EXCLUDE = 24;

export function buildPrompt(input: ChallengePromptInput): string {
  const subject = detectSubject(input.subject);
  const english = subject === "english";
  const body = input.lessonText.slice(0, MAX_LESSON_CHARS);
  const head = english
    ? `You are designing one round of a fast, competitive quiz game for a grade-four class. Write ${input.count} multiple-choice questions.`
    : `أنت تصمّم جولةً من لعبة تحدٍّ سريعة وتنافسية لصفٍّ رابع ابتدائي. اكتب ${input.count} سؤال اختيارٍ من متعدّد.`;

  const exclude = (input.exclude ?? [])
    .map((item) => text(item))
    .filter(Boolean)
    .slice(0, MAX_EXCLUDE);
  const avoid = exclude.length
    ? english
      ? `\n\nThe player has just seen these questions. Do NOT repeat or rephrase any of them:\n${exclude.map((q) => `- ${q}`).join("\n")}`
      : `\n\nرأى اللاعب هذه الأسئلة قبل قليل. لا تُعِدها ولا تُعِد صياغتها:\n${exclude.map((q) => `- ${q}`).join("\n")}`
    : "";

  // البذرة سطرٌ في التوجيه لا معامل في الطلب: واجهة Gemini لا تأخذ بذرةً
  // تُثبِّت المخرَج أو تُغيّره، والنموذج يستجيب لتغيّر النصّ. ومع
  // `temperature` مرتفعة يكفي هذا لتختلف الجولة عن أختها.
  const rotation = english
    ? `\n\nRound key: ${input.seed}. Approach the lesson from a different angle than the previous rounds.`
    : `\n\nمفتاح الجولة: ${input.seed}. اقترب من الدرس من زاويةٍ غير زوايا الجولات السابقة.`;

  return `${head}

المادة: ${input.subject}
${input.unit ? `الوحدة: ${input.unit}\n` : ""}${input.lesson ? `الدرس: ${input.lesson}\n` : ""}
نصّ الدرس المعتمد — لا تخرج عنه:
"""
${body}
"""

${rulesFor(subject)}
- ${input.count} ${english ? "questions" : "سؤالاً"}، لا أقلّ ولا أكثر، ولا سؤالان متشابهان.${avoid}${rotation}

${SCHEMA}`;
}

// ── التصفية ────────────────────────────────────────────────────────────

export interface ParseResult {
  questions: ChallengeQuestion[];
  rejected: Record<string, number>;
}

/**
 * يفكّ ردّ النموذج ويصفّيه.
 *
 * يقبل الردّ نصّاً أو كائناً مفكوكاً، ويحتمل أن يلفّه النموذج بسياجٍ
 * ```json — وهو يفعل رغم طلب JSON صِرفاً.
 */
export function parseQuestions(
  raw: unknown,
  subject: ChallengeSubject,
  limit: number,
  seen: Iterable<string> = [],
): ParseResult {
  let payload: any = raw;
  if (typeof payload === "string") {
    const fenced = payload.match(/```(?:json)?\s*([\s\S]*?)```/);
    const body = (fenced ? fenced[1] : payload).trim();
    try {
      payload = JSON.parse(body);
    } catch {
      return { questions: [], rejected: { "ردّ ليس JSON صالحاً": 1 } };
    }
  }
  const list: unknown[] = Array.isArray(payload)
    ? payload
    : Array.isArray(payload?.questions)
      ? payload.questions
      : [];

  const questions: ChallengeQuestion[] = [];
  const rejected: Record<string, number> = {};
  const used = new Set<string>();
  for (const item of seen) used.add(norm(item));

  for (const candidate of list) {
    if (questions.length >= limit) break;
    const verdict = acceptQuestion(candidate, subject);
    if (!verdict.ok) {
      rejected[verdict.why] = (rejected[verdict.why] ?? 0) + 1;
      continue;
    }
    const key = norm(verdict.question.question);
    if (used.has(key)) {
      rejected["سؤال مكرّر"] = (rejected["سؤال مكرّر"] ?? 0) + 1;
      continue;
    }
    used.add(key);
    questions.push(verdict.question);
  }
  return { questions, rejected };
}

/**
 * سقف المخرجات بحسب عدد الأسئلة.
 *
 * الثابت يقطع ردّ الجولة الطويلة في منتصفه فيعود JSON ناقصاً لا يُفكّ،
 * فيبدو الخطأ خطأَ نموذجٍ وهو خطأُ سقف.
 */
export const outputBudget = (count: number): number =>
  Math.min(420 * count + 2000, 32000);
