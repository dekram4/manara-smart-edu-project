/**
 * أسئلةُ المبارزة من مجال الدرس: توليدُها، وفحصُها، ومن يملك تعطيلَها.
 *
 * ── ما المطلوب من النموذج ──
 * أسئلةٌ تنافسيةٌ خفيفةٌ في **موضوع** الدرس، لا في **نصّه**: درسُ الجهاز الهضمي
 * يُخرج «أيُّ عضوٍ يهضم الطعام أوّلاً؟» لا «أكمل: تبدأ عمليةُ الهضم في ___».
 * فالمبارزةُ تُلعب مرّةً بعد مرّة بين الزملاء أنفسهم، ونصٌّ محفوظٌ يصير حفظاً
 * لمواضع الأزرار بعد جولتين.
 *
 * ── ولا يُكتب في البنك إلا ما مرّ بالمصفّي ──
 * والأسئلةُ تُفعَّل فورَ كتابتها بلا مراجعة: فالمصفّي هو المراجعة. وكلُّ قاعدةٍ
 * فيه تقابل خطأً يُخرج سؤالاً لا يُلعب أو لا يُنصف، وما يفوته يُعطّله المعلمُ أو
 * المشرف من اللوحة.
 *
 * دوالُّ نقيّةٌ كلُّها: لا شبكةَ ولا قاعدة، فتُختبر وحدها.
 */

import { packSeed } from "./duelQuestions";

/** ما يُطلب من النموذج لكل درس. */
export const DOMAIN_BATCH = 15;

/** أقلُّ ما يُكتب: دفعةٌ أفقرُ منه تدلّ على ردٍّ معطوب لا على درسٍ فقير. */
export const DOMAIN_MIN_ACCEPTED = 4;

export type DuelSubjectKey =
  | "math"
  | "science"
  | "english"
  | "islamic"
  | "social"
  | "arabic"
  | "other";

const text = (value: unknown): string =>
  typeof value === "string" ? value.trim() : "";

/** تسويةٌ للمقارنة: الحركات وصورُ الألف والتاء المربوطة والمسافات. */
export function normalizeArabic(value: unknown): string {
  return text(value)
    .toLowerCase()
    .replace(/[ً-ْٰـ]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/[«»"'“”،,.؟?!:؛;()\[\]{}…\-–—_]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * مفتاحُ المادة — هو `duel_subject_key` في `scripts/duel-question-bank.sql`
 * حرفاً بحرف، وبالترتيب نفسه. فسؤالٌ يكتبه الخادمُ بمفتاحٍ لا تحسبه الدالّةُ
 * للدرس نفسه لا يُختار أبداً، بلا خطأٍ يظهر.
 */
export function duelSubjectKey(raw: unknown): DuelSubjectKey {
  const value = text(raw).toLowerCase();
  if (!value) return "other";
  if (/(رياضيات|رياضيّات|math)/.test(value)) return "math";
  if (/(علوم|science)/.test(value)) return "science";
  if (/(انجليز|إنجليز|انكليز|english)/.test(value)) return "english";
  if (/(اسلام|إسلام|قرآن|قران|توحيد|فقه|حديث|تجويد|تفسير|islamic)/.test(value)) {
    return "islamic";
  }
  if (/(اجتماع|وطني|تاريخ|جغراف|social)/.test(value)) return "social";
  if (/(عربي|لغتي|arabic)/.test(value)) return "arabic";
  return "other";
}

/** شريحةُ الصفّ — `duel_grade_band` في الـSQL. */
export function duelGradeBand(raw: unknown): "all" | "low" | "high" {
  const value = text(raw).toLowerCase();
  if (!value) return "all";
  // و`\m[1-3]\M` في الـSQL حدُّ كلمة: رقمٌ وحده، لا جزءٌ من «12» ولا من «a3».
  if (/(الأول|الاول|الثاني|الثالث|(^|[^\p{L}\p{N}])[1-3]($|[^\p{L}\p{N}])|grade\s*[1-3])/u.test(value)) {
    return "low";
  }
  return "high";
}

export interface DomainRequest {
  subject: string;
  unit?: string;
  lesson?: string;
  grade?: string;
  lessonText: string;
  count?: number;
}

/** الطلبُ المرسل إلى النموذج. */
export function duelDomainPrompt(input: DomainRequest): string {
  const count = input.count ?? DOMAIN_BATCH;
  const english = duelSubjectKey(input.subject) === "english";
  const language = english
    ? "اكتب السؤال والخيارات بالإنجليزية البسيطة وحدها، بلا أي حرف عربي."
    : "اكتب بالعربية الفصحى البسيطة.";
  return `أنت تكتب ${count} سؤالاً لمسابقةٍ سريعةٍ بين طالبين في المرحلة الابتدائية${
    input.grade ? ` (${input.grade})` : ""
  }.

المادة: ${input.subject}
${input.unit ? `الوحدة: ${input.unit}\n` : ""}${input.lesson ? `الدرس: ${input.lesson}\n` : ""}
هذا نصُّ الدرس لتعرف **موضوعه** فقط:
"""
${input.lessonText.slice(0, 5000)}
"""

المطلوب: أسئلةُ معلوماتٍ عامّةٍ ممتعةٍ وخفيفةٍ في **مجال** هذا الدرس وموضوعه — ما يعرفه طفلٌ مهتمٌّ بالموضوع، وما يثير فضوله.

القواعد:
- لا تنسخ جملةً من نصّ الدرس، ولا تكتب سؤالاً يُجاب بحفظ سطرٍ منه. اسأل عن الموضوع بكلماتك.
- لا أسئلةَ «أكمل الفراغ» ولا «______».
- السؤالُ جملةٌ واحدةٌ قصيرة تُقرأ في ثوانٍ، أقلُّ من ١٥ كلمة.
- جوابٌ واحدٌ صحيحٌ لا خلافَ عليه، وثلاثةُ مشتّتاتٍ معقولةٍ من النوع نفسه — لا سخيفة.
- كلُّ خيارٍ كلمةٌ أو كلمتان أو رقم. ولا يُذكر الجوابُ في نصّ السؤال.
- لا خياراتٍ مثل «كل ما سبق» أو «لا شيء مما سبق».
- لا تكرّر سؤالاً بصيغةٍ أخرى.
- ${language}

أعد JSON فقط بهذا الشكل:
{"questions":[{"prompt":"...","answer":"...","distractors":["...","...","..."]}]}`;
}

export interface DomainQuestion {
  prompt: string;
  answer: string;
  distractors: [string, string, string];
}

export interface DomainParse {
  accepted: DomainQuestion[];
  rejected: Record<string, number>;
}

const ARABIC = /[؀-ۿ]/;

/** كلماتُ النصّ المسوّاة، لكشف النسخ. */
function words(value: string): string[] {
  return normalizeArabic(value).split(" ").filter(Boolean);
}

/** المتتالياتُ الرباعية: ما يجعل جملتين «منسوختين» لا متشابهتين في كلمة. */
function shingles(list: string[], size = 4): Set<string> {
  const out = new Set<string>();
  for (let i = 0; i + size <= list.length; i += 1) {
    out.add(list.slice(i, i + size).join(" "));
  }
  return out;
}

/**
 * هل السؤالُ منسوخٌ من الدرس؟
 *
 * نصفُ متتالياته الرباعية فأكثر موجودٌ في النصّ حرفياً. وما دون الأربع كلماتٍ
 * يقع اتّفاقاً في أي سؤالٍ عن الموضوع نفسه — «في الجهاز الهضمي» — فلا يُعدّ نسخاً.
 */
export function copiedFromLesson(prompt: string, lessonText: string): boolean {
  const asked = shingles(words(prompt));
  if (asked.size === 0) return false;
  const source = shingles(words(lessonText));
  let hits = 0;
  for (const piece of asked) if (source.has(piece)) hits += 1;
  return hits / asked.size >= 0.5;
}

/**
 * يقبل أسئلةَ الردّ أو يردّها، ويعدّ أسبابَ الردّ.
 *
 * كلُّ قاعدةٍ تقابل سؤالاً لا يُلعب أو لا يُنصف:
 * - فراغٌ أو جوابٌ ناقص: لا سؤال.
 * - خيارٌ مكرّر: جوابان صحيحان، فيُظلم من اختار «الآخر».
 * - الجوابُ في نصّ السؤال: يُقرأ قبل أن يُفكَّر فيه.
 * - «كل ما سبق»: لا يصلح مع خلط الخيارات.
 * - لسانٌ آخر: سؤالُ الإنجليزية بحرفٍ عربيٍّ، أو سؤالٌ عربيٌّ بلا عربية.
 * - منسوخٌ من الدرس: وهو ما بُني التوليدُ ليتجنّبه.
 */
export function parseDomainQuestions(
  raw: string,
  context: { subject: string; lessonText: string },
): DomainParse {
  const rejected: Record<string, number> = {};
  const reject = (why: string) => {
    rejected[why] = (rejected[why] ?? 0) + 1;
  };

  let parsed: unknown;
  try {
    const body = raw.trim().replace(/^```(?:json)?\s*/i, "").replace(/```$/, "");
    parsed = JSON.parse(body);
  } catch {
    return { accepted: [], rejected: { "ردٌّ ليس JSON": 1 } };
  }
  const list = Array.isArray(parsed)
    ? parsed
    : Array.isArray((parsed as { questions?: unknown })?.questions)
      ? (parsed as { questions: unknown[] }).questions
      : null;
  if (!list) return { accepted: [], rejected: { "لا قائمةَ أسئلة": 1 } };

  const english = duelSubjectKey(context.subject) === "english";
  const seen = new Set<string>();
  const accepted: DomainQuestion[] = [];

  for (const item of list) {
    const row = (item ?? {}) as Record<string, unknown>;
    const prompt = text(row.prompt).replace(/\s+/g, " ");
    const answer = text(row.answer);
    const distractors = Array.isArray(row.distractors)
      ? row.distractors.map(text).filter(Boolean)
      : [];

    if (prompt.length < 6 || prompt.length > 160) {
      reject("طولُ السؤال");
      continue;
    }
    if (!answer || distractors.length < 3) {
      reject("جوابٌ أو مشتّتاتٌ ناقصة");
      continue;
    }
    const choices = [answer, ...distractors.slice(0, 3)];
    if (choices.some((choice) => choice.length > 40)) {
      reject("خيارٌ طويل");
      continue;
    }
    if (new Set(choices.map(normalizeArabic)).size !== choices.length) {
      reject("خيارٌ مكرّر");
      continue;
    }
    if (/_{2,}|\.{4,}/.test(prompt)) {
      reject("أكمل الفراغ");
      continue;
    }
    if (choices.some((choice) => /(كل ما سبق|لا شيء مما سبق|جميع ما سبق|all of the above|none of the above)/i.test(choice))) {
      reject("كل ما سبق");
      continue;
    }
    const answerKey = normalizeArabic(answer);
    if (answerKey.length >= 3 && normalizeArabic(prompt).includes(answerKey)) {
      reject("الجوابُ في السؤال");
      continue;
    }
    const joined = [prompt, ...choices].join(" ");
    if (english ? ARABIC.test(joined) : !ARABIC.test(prompt)) {
      reject("لسانٌ آخر");
      continue;
    }
    if (/\\[a-z]+/i.test(joined)) {
      reject("رموزٌ لا تُعرض");
      continue;
    }
    if (copiedFromLesson(prompt, context.lessonText)) {
      reject("منسوخٌ من الدرس");
      continue;
    }
    const key = normalizeArabic(prompt);
    if (seen.has(key)) {
      reject("مكرّرٌ في الدفعة");
      continue;
    }
    seen.add(key);
    accepted.push({
      prompt,
      answer,
      distractors: [distractors[0], distractors[1], distractors[2]],
    });
  }
  return { accepted, rejected };
}

/** بصمةُ نصّ الدرس: طولُه وبصمتُه. يتغيّر الدرسُ فتتغيّر، فيُولَّد له من جديد. */
export function lessonStamp(lessonText: string): string {
  return `${lessonText.length}:${packSeed(lessonText).toString(36)}`;
}

/** صفُّ `duel_questions` كما يُكتب. */
export interface DomainRow {
  id: string;
  subject_key: DuelSubjectKey;
  unit: string | null;
  grade_band: "all" | "low" | "high";
  category: "domain";
  prompt: string;
  choices: string[];
  source: "ai";
  active: true;
  lesson_id: string;
  teacher_id: string | null;
  lesson_stamp: string;
}

/**
 * صفوفُ الكتابة.
 *
 * والمعرّفُ من المادة ونصّ السؤال المسوّى: السؤالُ نفسه يُولَّد لدرسين في المادة
 * فيُكتب مرّةً — والفهرسُ الفريد على (المادة، السؤال) يحرس ما تفلته التسوية.
 */
export function domainRows(
  questions: DomainQuestion[],
  lesson: {
    id: string;
    subject: string;
    unit?: string;
    grade?: string;
    teacherId?: string;
    lessonText: string;
  },
): DomainRow[] {
  const subject = duelSubjectKey(lesson.subject);
  const stamp = lessonStamp(lesson.lessonText);
  return questions.map((question) => ({
    id: `ai:${subject}:${packSeed(normalizeArabic(question.prompt)).toString(36)}`,
    subject_key: subject,
    unit: text(lesson.unit) || null,
    grade_band: duelGradeBand(lesson.grade),
    category: "domain",
    prompt: question.prompt,
    choices: [question.answer, ...question.distractors],
    source: "ai",
    active: true,
    lesson_id: lesson.id,
    teacher_id: text(lesson.teacherId) || null,
    lesson_stamp: stamp,
  }));
}

// ── من يرى ومن يعطّل ──

export type QuestionActor =
  | { role: "admin" }
  | { role: "teacher"; teacherId: string };

export interface QuestionOwnership {
  teacher_id?: string | null;
  subject_key?: string | null;
}

/**
 * تسويةُ معرّف المعلم — `normalizeOwner` في جسر المزامنة نفسها: «Test» و«test»
 * مالكٌ واحد. ولا تُحذف الرموز: «t-1» و«t_1» معلّمان.
 */
export function ownerKey(value: unknown): string {
  return text(value)
    .toLowerCase()
    .replace(/[ً-ْٰـ]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * هل يملك الفاعلُ تعطيلَ السؤال؟
 *
 * المشرفُ يملك كلَّ سؤال. والمعلمُ يملك ما وُلّد من دروسه وحدها: السؤالُ
 * المشترك — المكتوبُ في البنك، أو المولَّدُ من درس معلمٍ آخر — يصل إلى كل
 * الصفوف، فتعطيلُه قرارٌ عن غيره. فيراه المعلمُ ولا يعطّله، ويطلبه من المشرف.
 */
export function canToggleQuestion(
  actor: QuestionActor,
  question: QuestionOwnership,
): boolean {
  if (actor.role === "admin") return true;
  const owner = ownerKey(question.teacher_id);
  return owner !== "" && owner === ownerKey(actor.teacherId);
}

/**
 * هل يرى المعلمُ السؤال؟
 *
 * ما وُلّد من دروسه، والمشتركُ في موادّه — وهو ما يلعبه طلّابه فعلاً. والمشرفُ
 * يرى كلَّ شيء.
 */
export function canSeeQuestion(
  actor: QuestionActor,
  question: QuestionOwnership,
  teacherSubjects: ReadonlySet<string>,
): boolean {
  if (actor.role === "admin") return true;
  if (canToggleQuestion(actor, question)) return true;
  const subject = text(question.subject_key);
  return subject === "*" || teacherSubjects.has(subject);
}

/** مالكُ الدرس — `recordOwner` في جسر المزامنة: الحقولُ الثلاثة بترتيبها. */
export function lessonOwner(data: unknown): string {
  if (!data || typeof data !== "object") return "";
  const record = data as Record<string, unknown>;
  return text(record.teacher_id) || text(record.teacherId) || text(record.createdBy);
}

/** ما يُكتب في `disabled_by`: من عطّل، لا من فعّل. */
export function disabledByOf(actor: QuestionActor): string {
  return actor.role === "admin" ? "admin" : `teacher:${actor.teacherId}`;
}
