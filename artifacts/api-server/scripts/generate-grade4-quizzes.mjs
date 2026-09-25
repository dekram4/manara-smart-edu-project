#!/usr/bin/env node
/**
 * يولّد بنوك أسئلة الصف الرابع من نصوص الدروس نفسها، ويحفظها اختباراتٍ
 * في `created_quizzes`.
 *
 * ── ما يُولَّد ──
 * لكل درس: بنكٌ من خمسة عشر سؤالاً، يُعرض للطالب منها خمسة في كل
 * محاولة، ويُعاد الاختبار. ولكل وحدة: بنكٌ من ثلاثين سؤالاً تراكمياً
 * على دروسها كلّها، يُعرض منها عشرة، ويُؤدّى مرّة واحدة.
 *
 * ويُطلب من النموذج أكثر ممّا يُحفظ — عشرون للدرس وأربعون للوحدة —
 * لأن التصفية تردّ نحو الربع. وما نقص بعد ذلك يُستكمَل بطلب الباقي
 * وحده، لا بإسقاط الاختبار كلّه.
 *
 * والفرق بينهما في النظام ليس عدداً بل نوعاً: اختبار الدرس `periodic`
 * ويحمل اسم درسه، واختبار الوحدة `teacher` ولا يحمل درساً — وتطبيق
 * الطالب يمنع إعادة الثاني ويسمح بإعادة الأول. وهو ما تفعله شاشة إدارة
 * الاختبارات نفسها، فالسجلّ الخارج من هنا لا يُفرّق عن سجلٍّ أنشأه
 * معلّمٌ بيده.
 *
 * ── لغة الأسئلة ──
 * مادة اللغة الإنجليزية أسئلتها إنجليزية بالكامل — سؤالاً وخيارات
 * وتفسيراً. والرياضيات والعلوم بالعربية، بلا رمز معادلاتٍ ولا علامة
 * دولار: يُطلب ذلك في التوجيه، ثم يُنقّى ما يعود، ثم يُرفض ما بقي فيه
 * أثرٌ منه. ثلاثُ طبقاتٍ لأن النموذج يخطئ.
 *
 * ── التشغيل ──
 * يحتاج ثلاثة متغيّرات في البيئة، لا في سطر الأمر:
 *   SUPABASE_URL، SUPABASE_SERVICE_ROLE_KEY، GEMINI_API_KEY
 *
 *   # الخطة وحدها، بلا استدعاء نموذج ولا كتابة
 *   node scripts/generate-grade4-quizzes.mjs --teacher teacher_1786033127503
 *
 *   # عيّنة واحدة تُطبع ولا تُحفظ، ليُرى مستوى الأسئلة قبل الباقي
 *   node scripts/generate-grade4-quizzes.mjs --teacher ... --sample
 *
 *   # التوليد والحفظ
 *   node scripts/generate-grade4-quizzes.mjs --teacher ... --execute
 *
 * ويُستأنف: ما كان بنكُه كاملاً يُتخطّى، فالانقطاع في منتصف الطريق لا
 * يُعيد العمل من أوّله. و`--force` يُعيد توليد كل شيء.
 */

const args = process.argv.slice(2);
const EXECUTE = args.includes("--execute");
const SAMPLE = args.includes("--sample");
const FORCE = args.includes("--force");
const flag = (name, fallback = null) => {
  const at = args.indexOf(name);
  return at === -1 ? fallback : args[at + 1] ?? fallback;
};
const TEACHER = flag("--teacher");
const TEACHER_NAME = flag("--teacher-name") ?? "";
const ONLY = flag("--only");
const LIMIT = Number(flag("--limit", "0")) || 0;

const SUPABASE_URL = process.env.SUPABASE_URL?.trim().replace(/\/+$/, "");
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
const GEMINI_KEY = process.env.GEMINI_API_KEY?.trim();

const EPOCH_KEY = "smartEdu_contentEpoch";

/** أحجام البنوك وما يُعرض منها — وهي التي طُلبت. */
export const LESSON_BANK = 15;
export const LESSON_PER_ATTEMPT = 5;
export const UNIT_BANK = 30;
export const UNIT_PER_ATTEMPT = 10;

/**
 * ما يُطلب من النموذج، وهو أكثر ممّا يُحفظ.
 *
 * التصفية تردّ نحو الربع: خياراتٌ ثلاثة، أو إجابةٌ ليست من الخيارات، أو
 * سؤالان متشابهان. فطلبُ خمسةَ عشرَ يُبقي أحدَ عشر، والبنك يخرج ناقصاً.
 * وطلبُ عشرين يُبقي خمسةَ عشرَ بهامش.
 */
export const LESSON_ASK = 20;
export const UNIT_ASK = 40;

/**
 * كم مرّةً يُسأل النموذج عن الباقي إن نقص البنك.
 *
 * الزيادة في الطلب وحدها لا تكفي دائماً: درسٌ نصُّه قصير قد لا يحتمل
 * عشرين سؤالاً متمايزاً من محاولة واحدة. فيُسأل عن الناقص وحده، ومعه
 * أسئلتُه السابقة كي لا يعيدها.
 */
const TOP_UP_ROUNDS = 2;

const SUBJECT_CODES = [
  { match: "الرياضيات", code: "math", english: false },
  { match: "العلوم", code: "sci", english: false },
  { match: "اللغة الانجليزيه", code: "eng", english: true },
];

const text = (value) => (value == null ? "" : String(value).trim());

export function norm(value) {
  return text(value)
    .toLowerCase()
    .replace(/[ً-ْٰـ]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/\s+/g, " ")
    .trim();
}

export const ownerOf = (record) =>
  norm(record?.teacher_id ?? record?.teacherId ?? record?.createdBy);

/** تعريف المادة: رمزها في المعرّفات، وبأيّ لسانٍ تُسأل. */
export function subjectInfo(subject) {
  const wanted = norm(subject);
  return (
    SUBJECT_CODES.find((entry) => norm(entry.match) === wanted) ?? {
      match: subject,
      code: "x",
      english: false,
    }
  );
}

/**
 * يُزيل ترميز المعادلات من نصّ سؤال.
 *
 * نظيرة ما في وحدات المناهج، مكرّرة هنا عمداً: هذا السكربت يعالج نصّاً
 * يأتيه من نموذجٍ لغوي لا من ملفٍّ راجعناه، فتنقيتُه شرطُ قبولٍ لا
 * تهذيبُ مصدر.
 */
export function clean(value) {
  return (
    text(value)
      // أغلفة الرياضيات أولاً، فما بداخلها نصٌّ يُبقى.
      .replace(/\$\$([\s\S]*?)\$\$/g, "$1")
      .replace(/\$([^$\n]*?)\$/g, "$1")
      .replace(/\\\(([\s\S]*?)\\\)/g, "$1")
      .replace(/\\\[([\s\S]*?)\\\]/g, "$1")
      // الكسر يُكتب كما يكتبه الطفل: بسطٌ فمائلٌ فمقام.
      .replace(/\\(?:d|t)?frac\s*\{([^{}]*)\}\s*\{([^{}]*)\}/g, "$1/$2")
      // أمرٌ بوسيطٍ واحد: يبقى وسيطه ويذهب هو.
      .replace(/\\[a-zA-Z]+\s*\{([^{}]*)\}/g, "$1")
      // وأمرٌ بلا وسيط: يذهب كلّه (\times و\div وأشباههما).
      .replace(/\\[a-zA-Z]+/g, " ")
      .replace(/[$\\{}]/g, "")
      .replace(/\s+/g, " ")
      .trim()
  );
}

// ── بناء التوجيه ───────────────────────────────────────────────────────

const ARABIC_RULES = `القواعد الإلزامية:
- اكتب بالعربية الفصيحة المبسّطة، بمستوى طفلٍ في الصف الرابع الابتدائي.
- ممنوع منعاً باتاً أيّ رمز LaTeX أو علامة دولار ($) أو شرطة مائلة عكسية. اكتب المعادلات والكسور بالكلمات والأرقام العادية: "ثلاثة أرباع" أو "3/4"، و"5 × 4 = 20".
- كل سؤال أربعة خيارات، واحدٌ صحيح وثلاثةٌ خاطئة لكنها معقولة (لا خيار سخيف يُستبعد بلا تفكير).
- نوّع: أسئلة فهم، وأسئلة تطبيق وحساب، وأسئلة تمييز بين مفهومين.
- "explanation" سطرٌ واحد يشرح لماذا هذه الإجابة صحيحة، لا يكرّر نصّ الخيار.
- لا تسأل عمّا ليس في نصّ الدرس.`;

const ENGLISH_RULES = `Mandatory rules:
- Write the ENTIRE question, ALL four options, and the explanation in ENGLISH only. No Arabic anywhere.
- Target a 9-to-10-year-old EFL learner in grade four. Simple, correct, natural English.
- No LaTeX, no dollar signs, no backslashes.
- Four options per question: one correct, three plausible distractors (a wrong answer a real learner might pick, never a silly one).
- Cover a mix of grammar, vocabulary, and phonics as the lesson allows.
- "explanation" is one short English sentence saying why the answer is right.
- Ask only about what the lesson text teaches.`;

const SCHEMA = `أعد JSON فقط، بلا أي نصّ قبله أو بعده، بهذا الشكل بالضبط:
{"questions":[{"question":"...","options":["...","...","...","..."],"correctAnswer":"...","explanation":"..."}]}
حيث "correctAnswer" نصُّ الخيار الصحيح حرفاً بحرف كما كُتب في "options".`;

/**
 * ما سبق أن قُبل، يُذكر للنموذج كي لا يعيده.
 *
 * طلبُ الباقي بلا هذا يعيد الأسئلة الأولى نفسها، فتردّها تصفيةُ التكرار
 * ويبقى البنك ناقصاً كما كان.
 */
function avoidClause(already, english) {
  if (!already?.length) return "";
  const list = already.map((item) => `- ${item.question}`).join("\n");
  return english
    ? `\n\nDo NOT repeat or rephrase any of these questions, which are already in the bank:\n${list}`
    : `\n\nلا تُعِد ولا تُعِد صياغة أيٍّ من هذه الأسئلة، فهي في البنك بالفعل:\n${list}`;
}

export function lessonPrompt({ subject, unit, lesson, content, english }, ask = LESSON_ASK, already = []) {
  const rules = english ? ENGLISH_RULES : ARABIC_RULES;
  const head = english
    ? `You are an experienced grade-four English teacher. Write ${ask} multiple-choice questions for this lesson.`
    : `أنت معلّمٌ خبيرٌ للصف الرابع الابتدائي. اكتب ${ask} سؤال اختيارٍ من متعدّد لهذا الدرس.`;
  return `${head}

المادة: ${subject}
الوحدة: ${unit}
الدرس: ${lesson}

نصّ الدرس:
"""
${content}
"""

${rules}
- ${ask} سؤالاً، لا أقلّ ولا أكثر، ولا سؤالان متشابهان.${avoidClause(already, english)}

${SCHEMA}`;
}

export function unitPrompt({ subject, unit, lessons, english }, ask = UNIT_ASK, already = []) {
  const rules = english ? ENGLISH_RULES : ARABIC_RULES;
  const head = english
    ? `You are an experienced grade-four English teacher. Write ${ask} multiple-choice questions for a cumulative end-of-unit exam.`
    : `أنت معلّمٌ خبيرٌ للصف الرابع الابتدائي. اكتب ${ask} سؤال اختيارٍ من متعدّد لاختبار وحدةٍ شاملٍ تراكمي.`;
  const body = lessons
    .map((item, index) => `--- الدرس ${index + 1}: ${item.lesson} ---\n${item.content}`)
    .join("\n\n");
  return `${head}

المادة: ${subject}
الوحدة: ${unit}
عدد دروسها: ${lessons.length}

نصوص دروس الوحدة:
"""
${body}
"""

${rules}
- ${ask} سؤالاً، لا أقلّ ولا أكثر، ولا سؤالان متشابهان.
- وزّعها على دروس الوحدة كلّها بالعدل، فلا يُهمَل درس.
- اجعل ثلثها أسئلةَ تطبيقٍ تجمع بين درسين من الوحدة.${avoidClause(already, english)}

${SCHEMA}`;
}

// ── الشبكة ─────────────────────────────────────────────────────────────

const headers = () => ({
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  "Content-Type": "application/json",
});

async function readJson(path) {
  const response = await fetch(`${SUPABASE_URL}${path}`, { headers: headers() });
  if (!response.ok) {
    throw new Error(`GET ${path} → ${response.status} ${(await response.text()).slice(0, 200)}`);
  }
  return response.json();
}

async function send(path, method, body, prefer) {
  const response = await fetch(`${SUPABASE_URL}${path}`, {
    method,
    headers: { ...headers(), ...(prefer ? { Prefer: prefer } : {}) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  if (!response.ok) {
    throw new Error(`${method} ${path} → ${response.status} ${(await response.text()).slice(0, 300)}`);
  }
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/** النماذج المفضّلة، بترتيب الخادم نفسه. */
const MODELS = [
  process.env.GEMINI_MODEL?.trim().replace(/^models\//, ""),
  "gemini-flash-lite-latest",
  "gemini-2.5-flash-lite",
  "gemini-flash-latest",
  "gemini-2.5-flash",
].filter(Boolean);

/**
 * يسأل النموذج ويعيد الأسئلة، مع إعادة المحاولة.
 *
 * الخطأ هنا يعني بنكاً ناقصاً لدرسٍ يقرؤه طفل، فالمحاولة تُعاد على
 * نموذجٍ آخر ثم على مهلةٍ متصاعدة. والانتظار قبل كل إعادة لا بعدها:
 * حدُّ المعدّل يُعالَج بالصبر لا بالإلحاح.
 */
/**
 * سقف المخرجات بحسب عدد الأسئلة المطلوبة.
 *
 * كان ثابتاً عند تسعة آلاف، وهو سقف الخادم لطلبٍ واحد من الشاشة. وأربعون
 * سؤالاً عربياً بخياراتها وتفسيراتها تتجاوزه، فيُقطع الردّ في منتصفه
 * ويعود JSON ناقصاً لا يُفكّ — فيبدو الخطأ خطأَ نموذجٍ وهو خطأُ سقف.
 */
export const outputBudget = (ask) => Math.min(420 * ask + 2000, 32000);

export async function askGemini(prompt, { tries = 3, maxOutputTokens = 9000 } = {}) {
  let lastError = null;
  for (let round = 0; round < tries; round += 1) {
    for (const model of MODELS) {
      try {
        const response = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(GEMINI_KEY)}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              contents: [{ parts: [{ text: prompt }] }],
              generationConfig: {
                temperature: 0.8,
                maxOutputTokens,
                responseMimeType: "application/json",
              },
            }),
            signal: AbortSignal.timeout(90_000),
          },
        );
        if (!response.ok) {
          const detail = (await response.text()).slice(0, 200);
          lastError = new Error(`${model} → ${response.status} ${detail}`);
          if (response.status === 404 || response.status === 400) continue;
          await sleep(3000 * (round + 1));
          continue;
        }
        const data = await response.json();
        const raw = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
        const parsed = JSON.parse(raw);
        const questions = Array.isArray(parsed?.questions) ? parsed.questions : [];
        if (questions.length) return questions;
        lastError = new Error(`${model} أعاد صفر أسئلة`);
      } catch (error) {
        lastError = error;
        await sleep(2000 * (round + 1));
      }
    }
  }
  throw lastError ?? new Error("تعذّر التوليد");
}

// ── التصفية والقبول ────────────────────────────────────────────────────

const LATIN = /[A-Za-z]/;
const ARABIC = /[؀-ۿ]/;

/**
 * أوامر LaTeX التي تُعرف تنقيتُها بلا خسارة معنى.
 *
 * `\frac{3}{4}` تصير «3/4» فيُقرأ المعنى كاملاً. أما `\sqrt{16}` فلا
 * مقابل لها في التنقية، فحذفُها يترك «ما ناتج 16؟» — سؤالاً بلا معنى
 * يبدو سليماً. فما خرج عن هذه القائمة يُردّ سؤالُه كلّه: بنكُ الخمسة
 * عشر يحتمل فقدان سؤال، ولا يحتمل سؤالاً مشوّهاً.
 */
const SAFE_COMMANDS = /^(?:d|t)?(?:frac|times|div|text|mathrm|mathbf|textbf|mbox|cdot|left|right)$/;

export function hasUnsafeMarkup(...values) {
  for (const value of values) {
    for (const match of text(value).matchAll(/\\([a-zA-Z]+)/g)) {
      if (!SAFE_COMMANDS.test(match[1])) return match[1];
    }
  }
  return null;
}

/**
 * يقبل السؤال أو يردّه، ويقول لماذا.
 *
 * النموذج يخطئ بأشكالٍ معروفة: خياراتٌ ثلاثة، أو إجابةٌ صحيحة ليست من
 * الخيارات، أو خياران متطابقان، أو عربيّةٌ في امتحان الإنجليزية. كلّها
 * تمرّ صامتةً إن لم تُفحص، فيصل إلى الطفل سؤالٌ بلا جواب.
 */
export function acceptQuestion(raw, { english }) {
  const unsafe = hasUnsafeMarkup(
    raw?.question,
    raw?.explanation,
    ...(Array.isArray(raw?.options) ? raw.options : []),
  );
  if (unsafe) return { ok: false, why: `أمر LaTeX لا تُعرف تنقيته: \\${unsafe}` };

  const question = clean(raw?.question);
  const explanation = clean(raw?.explanation);
  const options = (Array.isArray(raw?.options) ? raw.options : []).map(clean).filter(Boolean);
  const answer = clean(raw?.correctAnswer);

  if (question.length < 8) return { ok: false, why: "سؤال قصير أو فارغ" };
  if (options.length !== 4) return { ok: false, why: `${options.length} خيارات لا أربعة` };
  if (new Set(options.map(norm)).size !== 4) return { ok: false, why: "خياران متطابقان" };
  if (!options.some((option) => norm(option) === norm(answer))) {
    return { ok: false, why: "الإجابة الصحيحة ليست من الخيارات" };
  }
  const all = [question, explanation, ...options].join(" ");
  if (all.includes("$") || all.includes("\\")) return { ok: false, why: "بقي فيه ترميز معادلات" };
  if (english && ARABIC.test([question, ...options].join(" "))) {
    return { ok: false, why: "عربيّة في امتحان الإنجليزية" };
  }
  if (!english && !ARABIC.test(question) && LATIN.test(question)) {
    return { ok: false, why: "سؤال بالإنجليزية في مادة عربية" };
  }
  return { ok: true, question: { question, options, correctAnswer: answer, explanation } };
}

// ── بناء السجلّ ────────────────────────────────────────────────────────

/**
 * سجلُّ اختبارٍ كما تكتبه شاشة إدارة الاختبارات بالضبط.
 *
 * كلّ حقلٍ هنا يقرؤه شيء: `questionsPerAttempt` تقرؤه قرعةُ تطبيق
 * الطالب، و`quizType` يقرؤه منعُ الإعادة، و`lesson` يقرؤه ترشيحُ
 * المسار، و`creationMode` تقرؤه الشاشة لتعرف أنّ الأسئلة مولّدة.
 */
export function buildQuiz({
  id,
  title,
  grade,
  subject,
  term,
  unit,
  lesson,
  questions,
  perAttempt,
  owner,
  ownerName,
  createdAt,
}) {
  const stamp = createdAt ?? new Date().toISOString();
  const isLesson = Boolean(lesson);
  const quizType = isLesson ? "periodic" : "teacher";
  return {
    id,
    title,
    grade,
    subject,
    term,
    unit,
    ...(isLesson ? { lesson } : {}),
    quizType,
    isRepeatable: isLesson,
    allowRetake: isLesson,
    questionCount: questions.length,
    questionsPerAttempt: Math.min(perAttempt, questions.length),
    isActive: true,
    creationMode: "ai",
    questions: questions.map((item, index) => ({
      id: `${id}_q${index + 1}`,
      question: item.question,
      options: item.options,
      correctAnswer: item.correctAnswer,
      explanation: item.explanation,
      lessonId: "generated",
      grade,
      subject,
      term,
      unit,
      quizType,
      quizId: id,
      createdAt: stamp,
      source: "ai-generated",
      variation: index + 1,
    })),
    createdAt: stamp,
    createdBy: owner,
    createdByName: ownerName || owner,
    lastModified: stamp,
    deleted: false,
  };
}

// ── الخطة ──────────────────────────────────────────────────────────────

/** يبني قائمة ما سيُولَّد من صفوف الدروس: اختبارٌ لكل درس ولكل وحدة. */
export function planFrom(rows, owner) {
  const lessons = [];
  const units = new Map();

  for (const row of rows) {
    const data = row?.data ?? {};
    if (ownerOf(data) !== owner) continue;
    const grade = text(data.grade);
    const subject = text(data.subject);
    const term = text(data.term);
    const unit = text(data.unit);
    const lesson = text(data.lesson);
    const content = text(data.lessonContent);
    if (!grade || !subject || !term || !unit || !lesson || !content) continue;

    const info = subjectInfo(subject);
    const suffix = text(row.id).replace(/^g4(math|sci|eng)_/, "").replace(`_${owner}`, "");
    lessons.push({
      kind: "lesson",
      id: `quiz_${info.code}_${suffix}_${owner}`,
      title: `اختبار الدرس: ${lesson}`,
      grade,
      subject,
      term,
      unit,
      lesson,
      content,
      english: info.english,
      code: info.code,
      bank: LESSON_BANK,
      ask: LESSON_ASK,
      perAttempt: LESSON_PER_ATTEMPT,
    });

    const key = `${info.code}::${norm(unit)}`;
    if (!units.has(key)) {
      units.set(key, {
        kind: "unit",
        id: "",
        title: `اختبار الوحدة: ${unit}`,
        grade,
        subject,
        term,
        unit,
        english: info.english,
        code: info.code,
        bank: UNIT_BANK,
        ask: UNIT_ASK,
        perAttempt: UNIT_PER_ATTEMPT,
        lessons: [],
      });
    }
    units.get(key).lessons.push({ lesson, content });
  }

  // معرّف الوحدة من ترتيبها داخل مادّتها، فيثبت بين تشغيلٍ وآخر.
  const seen = new Map();
  const unitList = [...units.values()].map((entry) => {
    const index = (seen.get(entry.code) ?? 0) + 1;
    seen.set(entry.code, index);
    return { ...entry, id: `quiz_${entry.code}_unit${index}_${owner}` };
  });

  return [...lessons, ...unitList];
}

const line = (t = "") => console.log(t);
const head = (t) => {
  line();
  line(`════ ${t} ════`);
};

async function main() {
  if (!SUPABASE_URL || !SERVICE_KEY) {
    console.error("SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY مطلوبان.");
    process.exit(1);
  }
  if (!TEACHER) {
    console.error(
      "الاستعمال: node scripts/generate-grade4-quizzes.mjs --teacher <معرّف> [--sample] [--execute]",
    );
    process.exit(1);
  }
  if ((EXECUTE || SAMPLE) && !GEMINI_KEY) {
    console.error("GEMINI_API_KEY مطلوب للتوليد. ضعه في البيئة لا في سطر الأمر.");
    process.exit(1);
  }

  const owner = norm(TEACHER);
  line(
    EXECUTE
      ? "✍️ توليد وحفظ."
      : SAMPLE
        ? "🧪 عيّنة واحدة — تُطبع ولا تُحفظ."
        : "🔍 الخطة وحدها — لا استدعاء نموذج ولا كتابة.",
  );
  line(`المعلّم: «${TEACHER}»`);

  // ── الخطة ───────────────────────────────────────────────────────────
  head("الخطة");
  const lessonRows = await readJson("/rest/v1/lesson_configs?select=id,data&limit=10000");
  let plan = planFrom(Array.isArray(lessonRows) ? lessonRows : [], owner);
  if (ONLY) {
    const wanted = norm(ONLY);
    plan = plan.filter(
      (item) => item.code === wanted || norm(item.subject).includes(wanted),
    );
  }

  const bySubject = new Map();
  for (const item of plan) {
    const entry = bySubject.get(item.subject) ?? { lessons: 0, units: 0 };
    entry[item.kind === "lesson" ? "lessons" : "units"] += 1;
    bySubject.set(item.subject, entry);
  }
  for (const [subject, entry] of bySubject) {
    line(
      `  • ${subject}: ${entry.lessons} اختبار درس (يُطلب ${LESSON_ASK} ← يُحفظ ${LESSON_BANK} ← يُعرض ${LESSON_PER_ATTEMPT})` +
        ` و${entry.units} اختبار وحدة (يُطلب ${UNIT_ASK} ← يُحفظ ${UNIT_BANK} ← يُعرض ${UNIT_PER_ATTEMPT})`,
    );
  }
  const totalQuestions = plan.reduce((sum, item) => sum + item.bank, 0);
  line(`  المجموع: ${plan.length} اختباراً، ${totalQuestions} سؤالاً.`);

  // ما هو موجودٌ وكاملٌ يُتخطّى، فالانقطاع لا يُعيد العمل من أوّله.
  const existingRows = await readJson("/rest/v1/created_quizzes?select=id,data&limit=10000");
  const existing = new Map(
    (Array.isArray(existingRows) ? existingRows : []).map((row) => [text(row.id), row.data]),
  );
  const done = plan.filter((item) => {
    const found = existing.get(item.id);
    return found && (found.questions ?? []).length >= item.bank && found.deleted !== true;
  });
  const todo = FORCE ? plan : plan.filter((item) => !done.includes(item));
  line(`  مكتملٌ من قبل: ${done.length}${FORCE ? " (يُعاد توليدها: --force)" : " — تُتخطّى"}`);
  line(`  سيُولَّد الآن: ${todo.length}`);

  const work = LIMIT > 0 ? todo.slice(0, LIMIT) : todo;
  if (LIMIT > 0) line(`  محدودٌ بـ --limit ${LIMIT}`);

  if (!EXECUTE && !SAMPLE) {
    line();
    line("(الخطة فقط — أضف --sample لعيّنة أو --execute للتوليد والحفظ)");
    return;
  }

  // ── العيّنة ─────────────────────────────────────────────────────────
  if (SAMPLE) {
    const item = work[0];
    if (!item) {
      line("لا شيء لتوليده.");
      return;
    }
    head(`عيّنة: ${item.title}`);
    const prompt =
      item.kind === "lesson" ? lessonPrompt(item, item.ask) : unitPrompt(item, item.ask);
    const raw = await askGemini(prompt, { maxOutputTokens: outputBudget(item.ask) });
    let kept = 0;
    for (const candidate of raw.slice(0, 5)) {
      const verdict = acceptQuestion(candidate, item);
      if (!verdict.ok) {
        line(`  ✖ مرفوض: ${verdict.why}`);
        continue;
      }
      kept += 1;
      line();
      line(`  ${kept}. ${verdict.question.question}`);
      for (const option of verdict.question.options) {
        const mark = norm(option) === norm(verdict.question.correctAnswer) ? "✔" : " ";
        line(`      ${mark} ${option}`);
      }
      if (verdict.question.explanation) line(`      ← ${verdict.question.explanation}`);
    }
    line();
    line(`(النموذج أعاد ${raw.length} سؤالاً؛ عُرضت خمسة. لم يُحفظ شيء.)`);
    return;
  }

  // ── التوليد والحفظ ──────────────────────────────────────────────────
  head("التوليد");
  const stats = { saved: 0, failed: 0, questions: 0, rejected: 0, short: 0, topUps: 0, reasons: new Map() };
  const failures = [];

  for (const [index, item] of work.entries()) {
    const label = `[${index + 1}/${work.length}] ${item.title}`;
    try {
      const questions = [];
      const seenText = new Set();

      /** يصفّي ما عاد من النموذج ويضيف المقبول حتى يمتلئ البنك. */
      const absorb = (raw) => {
        for (const candidate of raw) {
          if (questions.length >= item.bank) break;
          const verdict = acceptQuestion(candidate, item);
          if (!verdict.ok) {
            stats.rejected += 1;
            stats.reasons.set(verdict.why, (stats.reasons.get(verdict.why) ?? 0) + 1);
            continue;
          }
          const key = norm(verdict.question.question);
          if (seenText.has(key)) {
            stats.rejected += 1;
            stats.reasons.set("سؤال مكرّر", (stats.reasons.get("سؤال مكرّر") ?? 0) + 1);
            continue;
          }
          seenText.add(key);
          questions.push(verdict.question);
        }
      };

      const build = (ask, already) =>
        item.kind === "lesson" ? lessonPrompt(item, ask, already) : unitPrompt(item, ask, already);

      absorb(
        await askGemini(build(item.ask, []), { maxOutputTokens: outputBudget(item.ask) }),
      );

      // ونقصُ البنك يُستكمَل بطلب الباقي، لا يُترك.
      //
      // كان الاختبار يسقط كلّه إن ردّت التصفيةُ ما ردّت — فدرسٌ عاد منه
      // تسعةُ أسئلةٍ مقبولة يُهدَر، وتُهدَر معه الأسئلةُ التسعة. وسؤالُ
      // النموذج عن الناقص وحده أرخص من إعادة الدرس من أوّله، وأقرب إلى
      // أن ينجح: الطلب أصغر، ومعه ما لا يُعاد.
      for (let round = 0; round < TOP_UP_ROUNDS && questions.length < item.bank; round += 1) {
        const missing = item.bank - questions.length;
        line(`     ↻ ${label} — ${questions.length}/${item.bank}، يُطلب ${missing} إضافياً.`);
        stats.topUps += 1;
        await sleep(1200);
        const ask = Math.max(missing + 4, 6);
        absorb(await askGemini(build(ask, questions), { maxOutputTokens: outputBudget(ask) }));
      }

      // بنكٌ دون ثلثي المطلوب لا يُحفظ: اختبارٌ ناقصٌ أسوأ من غيابه،
      // لأنّه يبدو جاهزاً فلا يُعاد توليده.
      const floor = Math.ceil(item.bank * 0.67);
      if (questions.length < floor) {
        stats.failed += 1;
        failures.push(`${item.title}: ${questions.length} سؤالاً من ${item.bank}`);
        line(`  ✖ ${label} — ${questions.length}/${item.bank}، لم يُحفظ.`);
        continue;
      }
      if (questions.length < item.bank) stats.short += 1;

      const quiz = buildQuiz({
        id: item.id,
        title: item.title,
        grade: item.grade,
        subject: item.subject,
        term: item.term,
        unit: item.unit,
        lesson: item.kind === "lesson" ? item.lesson : undefined,
        questions,
        perAttempt: item.perAttempt,
        owner,
        ownerName: TEACHER_NAME,
      });

      await send(
        "/rest/v1/created_quizzes?on_conflict=id",
        "POST",
        [{ id: quiz.id, data: quiz, updated_at: new Date().toISOString() }],
        "resolution=merge-duplicates,return=minimal",
      );
      stats.saved += 1;
      stats.questions += questions.length;
      line(
        `  ✅ ${label} — ${questions.length} سؤالاً، يُعرض ${quiz.questionsPerAttempt}` +
          `${item.kind === "lesson" ? "، يُعاد" : "، مرّة واحدة"}`,
      );
    } catch (error) {
      stats.failed += 1;
      failures.push(`${item.title}: ${error.message}`);
      line(`  ✖ ${label} — ${error.message}`);
    }
    await sleep(1200); // مهلةٌ بين الطلبات، فلا يُصدم حدّ المعدّل
  }

  // ── الختم ───────────────────────────────────────────────────────────
  if (stats.saved > 0) {
    const stamp = new Date().toISOString();
    await send(
      "/rest/v1/app_kv?on_conflict=key",
      "POST",
      { key: EPOCH_KEY, value: stamp, updated_at: stamp },
      "resolution=merge-duplicates,return=minimal",
    );
    line();
    line(`رُفع ختم المحتوى: ${stamp}`);
  }

  // ── الإحصاء ─────────────────────────────────────────────────────────
  head("الإحصاء");
  line(`  اختبارات حُفظت: ${stats.saved}`);
  line(`  أسئلة حُفظت: ${stats.questions}`);
  line(`  بنوكٌ نقصت عن المطلوب لكنها قُبلت: ${stats.short}`);
  line(`  طلبات استكمال: ${stats.topUps}`);
  line(`  أسئلة رُدّت في التصفية: ${stats.rejected}`);
  for (const [why, count] of [...stats.reasons].sort((a, b) => b[1] - a[1])) {
    line(`      • ${why}: ${count}`);
  }
  line(`  اختبارات فشلت: ${stats.failed}`);
  for (const failure of failures) line(`      ✖ ${failure}`);

  const afterRows = await readJson("/rest/v1/created_quizzes?select=id,data&limit=10000");
  const mine = (Array.isArray(afterRows) ? afterRows : []).filter(
    (row) => ownerOf(row?.data) === owner && row?.data?.deleted !== true,
  );
  const lessonQuizzes = mine.filter((row) => row.data?.quizType === "periodic").length;
  const unitQuizzes = mine.filter((row) => row.data?.quizType === "teacher").length;
  line();
  line(`  في قاعدة البيانات الآن: ${mine.length} اختباراً لهذا المعلّم`);
  line(`      اختبارات دروس (تُعاد): ${lessonQuizzes}`);
  line(`      اختبارات وحدات (مرّة واحدة): ${unitQuizzes}`);

  if (stats.failed > 0) {
    line();
    line("أعد التشغيل بالأمر نفسه: ما نجح يُتخطّى، وما فشل يُحاوَل من جديد.");
    process.exit(1);
  }
}

if (process.argv[1] && process.argv[1].endsWith("generate-grade4-quizzes.mjs")) {
  main().catch((error) => {
    console.error("فشل:", error.message);
    process.exit(1);
  });
}
