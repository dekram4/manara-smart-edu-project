import { fullLessonText } from "./lessonText";
import type { TracingItem } from "./studyGames";
import { tracingLangOf } from "./tracing";

/**
 * أسئلةُ «أجب وتتبّع» لغير موادّ الروضة: يولّدها الذكاء الاصطناعي من نصّ الدرس.
 *
 * يرى الطفلُ السؤال وخياراته، فيختار؛ والخطأُ صوتُ تنبيهٍ ومحاولةٌ أخرى،
 * والصوابُ يُفتح تتبّعاً للإجابة نفسها. فالإجابةُ تُكتب بإصبعٍ صغير:
 * كلمةٌ أو كلمتان قصيرتان، بلا تشكيلٍ ولا رموز — وما لا يُتتبّع يسقط هنا
 * ولو اقترحه النموذج.
 *
 * ── وتُحفظ مع الدرس ──
 * في `lesson_configs.data.tracingQuiz`، مختومةً بنصّ الدرس: تُولَّد مرّةً لكل
 * نصّ، وتعديلُ المعلم للنصّ يولّدها من جديد.
 *
 * بلا شبكة ولا قاعدة بيانات، فيُختبر وحده.
 */

export const TRACING_QUIZ_VERSION = 1;

/** من ٥ إلى ١٠ أسئلة: أقلُّ من خمسةٍ لا يُعدّ تمريناً، وأكثرُ من عشرةٍ يُملّ الصغير. */
export const TRACING_QUIZ_LIMITS = { min: 5, max: 10 } as const;

/** أطولُ إجابةٍ تُتتبّع: حروفاً بلا مسافات، وكلماتٍ. */
export const ANSWER_LIMITS = { letters: 12, words: 2 } as const;

export interface TracingQuizPack {
  version: number;
  lessonId: string;
  lessonStamp: string;
  generatedAt: string;
  items: TracingItem[];
}

export const TRACING_QUIZ_SYSTEM_INSTRUCTION = `أنت معلّمٌ خبير تكتب أسئلةً قصيرةً للأطفال في منصّة عربية. يُجيب الطفل باختيار الإجابة ثم يكتبها بإصبعه على الشاشة، فالإجابةُ قصيرةٌ جداً.

ضوابط:
- كلُّ سؤالٍ من الدرس المرفق وحده، صحيحٌ علمياً، يقيس الفهم لا الحفظ الحرفي، ولا يتكرّر بصياغةٍ أخرى.
- "question": جملةٌ واحدة واضحة بلغةٍ بسيطةٍ تناسب عمر الطالب، لا تتجاوز ١٥ كلمة.
- "answer": كلمةٌ واحدة أو كلمتان على الأكثر، لا تتجاوز ${ANSWER_LIMITS.letters} حرفاً، بلا تشكيلٍ ولا أرقامٍ عشرية ولا رموز ولا علامات ترقيم. يجوز أن تكون عدداً صحيحاً قصيراً.
- "options": ثلاثةُ خياراتٍ بالضبط بالشروط نفسها، أحدها "answer" حرفياً، والآخران خاطئان معقولان من موضوع الدرس.
- إن كانت مادة الدرس اللغة الإنجليزية فاكتب الأسئلة والخيارات بالإنجليزية.
- اكتب بين ${TRACING_QUIZ_LIMITS.min} و${TRACING_QUIZ_LIMITS.max} أسئلة (يفضَّل ٨)، متدرّجةً من السهل إلى الأصعب، تغطّي الدرس كلّه.

أخرج JSON فقط مطابقاً للمخطط، بلا أي نص آخر.`;

/** مخطّطُ الردّ بصيغة Gemini (`generationConfig.responseSchema`). */
export const TRACING_QUIZ_SCHEMA = {
  type: "OBJECT",
  properties: {
    questions: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          question: { type: "STRING" },
          options: { type: "ARRAY", items: { type: "STRING" } },
          answer: { type: "STRING" },
        },
        required: ["question", "options", "answer"],
        propertyOrdering: ["question", "options", "answer"],
      },
    },
  },
  required: ["questions"],
} as const;

export function tracingQuizPrompt({
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
  return `اكتب أسئلة «أجب وتتبّع» من هذا الدرس.
${context ? `\n${context}\n` : ""}
نص الدرس:
"""
${fullLessonText(lessonText).trim()}
"""`;
}

// بالرموز: نطاقُ التشكيل المكتوب بحروفه يشمل الأرقامَ الهندية فيمحوها.
const TASHKEEL = /[ً-ٰٟـ]/g;

function clean(value: unknown, max: number): string {
  return typeof value === "string" ? value.replace(TASHKEEL, "").replace(/\s+/g, " ").trim().slice(0, max) : "";
}

function key(value: string): string {
  return value
    .toLowerCase()
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .trim();
}

/**
 * إجابةٌ تُكتب بإصبع: حروفٌ عربيةٌ أو لاتينيةٌ أو أرقام، كلمةٌ أو كلمتان،
 * بلا رموز — فكلُّ ما فيها شكلٌ يُتتبّع.
 */
export function isTraceableAnswer(value: string): boolean {
  if (!value) return false;
  const words = value.split(" ");
  if (words.length > ANSWER_LIMITS.words) return false;
  if (value.replace(/ /g, "").length > ANSWER_LIMITS.letters) return false;
  return words.every((word) => /^(?:[ء-ي]+|[A-Za-z]+|[0-9]+|[٠-٩]+)$/.test(word));
}

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
  if (value && typeof value === "object" && Array.isArray((value as { questions?: unknown }).questions)) {
    return (value as { questions: unknown[] }).questions;
  }
  return [];
}

/**
 * الأسئلةُ الصالحة من ردّ النموذج، أو `null` إن صلح أقلُّ من خمسة — فلا
 * يُحفظ تمرينٌ ناقصٌ يبقى ناقصاً.
 */
export function parseTracingQuiz(
  raw: unknown,
  owner: { lessonId: string; lessonStamp: string },
  { subject = "", now = new Date().toISOString() }: { subject?: string; now?: string } = {},
): TracingQuizPack | null {
  const items: TracingItem[] = [];
  const seen = new Set<string>();
  for (const entry of extract(raw)) {
    if (!entry || typeof entry !== "object") continue;
    const record = entry as Record<string, unknown>;
    const question = clean(record.question, 200);
    const answer = clean(record.answer, 40);
    if (question.length < 5 || !isTraceableAnswer(answer) || seen.has(key(question))) continue;

    const options: string[] = [];
    for (const option of Array.isArray(record.options) ? record.options : []) {
      const text = clean(option, 40);
      if (isTraceableAnswer(text) && !options.some((o) => key(o) === key(text))) options.push(text);
    }
    // الإجابةُ بين الخيارات حرفياً، وخياران خاطئان على الأقل.
    const right = options.find((option) => key(option) === key(answer));
    const wrong = options.filter((option) => key(option) !== key(answer)).slice(0, 2);
    if (wrong.length < 2) continue;

    seen.add(key(question));
    const text = right ?? answer;
    items.push({
      text,
      kind: "answer",
      lang: tracingLangOf(subject, `${question} ${text}`),
      prompt: question,
      options: shuffleStable([text, ...wrong], question),
      speech: text,
    });
    if (items.length >= TRACING_QUIZ_LIMITS.max) break;
  }
  if (items.length < TRACING_QUIZ_LIMITS.min) return null;
  return { version: TRACING_QUIZ_VERSION, ...owner, generatedAt: now, items };
}

/**
 * ترتيبٌ ثابتٌ للخيارات من نصّ السؤال: الإجابةُ لا تقع أوّلاً دائماً، ولا
 * يتبدّل موضعُها بين قراءتين للحزمة نفسها.
 */
function shuffleStable(options: string[], seed: string): string[] {
  let hash = 0;
  for (const char of seed) hash = (hash * 31 + char.charCodeAt(0)) >>> 0;
  const out = [...options];
  for (let i = out.length - 1; i > 0; i--) {
    hash = (hash * 1103515245 + 12345) >>> 0;
    const j = hash % (i + 1);
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}

/** المحفوظُ مع الدرس إن كان لهذا الدرس ولنصّه الحالي. */
export function readTracingQuiz(
  stored: unknown,
  owner: { lessonId: string; lessonStamp: string },
): TracingQuizPack | null {
  if (!stored || typeof stored !== "object") return null;
  const pack = stored as Partial<TracingQuizPack>;
  if (pack.version !== TRACING_QUIZ_VERSION) return null;
  if (pack.lessonId !== owner.lessonId || pack.lessonStamp !== owner.lessonStamp) return null;
  if (!Array.isArray(pack.items) || pack.items.length < TRACING_QUIZ_LIMITS.min) return null;
  return pack as TracingQuizPack;
}
