/**
 * المذاكرةُ الذكية: خريطةٌ ذهنية للدرس، ومغامراتٌ قصصية فيه.
 *
 * ── لماذا وحدةٌ نقيّة ──
 * النداءُ إلى النموذج سطرٌ واحد، وما حوله هو العمل: صياغةُ الطلب، وقراءةُ
 * ما يعود، وردُّ ما لا يصلح. والنموذجُ يعود بما لم يُطلب أحياناً — فرعاً
 * ناقصاً، أو خياراً صحيحاً ليس من الخيارات، أو ثلاثةَ خياراتٍ متطابقة —
 * وكلُّها تصل الطفلَ شاشةً لا تُلعَب إن لم تُردّ هنا.
 *
 * فالصياغةُ والقراءةُ والتحقّقُ هنا وعليها اختبارات، والشبكةُ في المسار.
 */

/** نسخةُ الحزمة المخزَّنة. تُرفع حين يتغيّر شكلُها فيُعاد التوليد. */
export const STUDY_VERSION = 1;

/** فروعُ الخريطة الذهنية: ثلاثةٌ أو أربعة، لا أكثر. */
export const MIN_BRANCHES = 3;
export const MAX_BRANCHES = 5;

/** السيناريوهات: اثنان أو ثلاثة. */
export const MIN_SCENARIOS = 2;
export const MAX_SCENARIOS = 3;

/** وكلُّ سيناريو ثلاثةُ مواقف. */
export const SITUATIONS_PER_SCENARIO = 3;

/** وكلُّ موقفٍ ثلاثةُ خيارات. */
export const OPTIONS_PER_SITUATION = 3;

export interface MindMapBranch {
  title: string;
  summary: string;
  /** رمزٌ تعبيريٌّ واحد، أو فارغٌ إن لم يُرسله النموذج. */
  icon: string;
}

export interface MindMap {
  title: string;
  branches: MindMapBranch[];
}

export interface Situation {
  /** الموقفُ كما يُحكى للطفل. */
  prompt: string;
  options: string[];
  /** موضعُ الصحيح في [options]. */
  answer: number;
  /** لماذا هو الصحيح — يُعرض بعد الاختيار. */
  because: string;
}

export interface Scenario {
  title: string;
  situations: Situation[];
}

export interface StudyPack {
  version: number;
  mindMap: MindMap;
  scenarios: Scenario[];
  createdAt: string;
}

/** نصٌّ منقّى: بلا تشكيل ولا فراغٍ زائد، ومحدودُ الطول. */
export function clean(value: unknown, limit = 240): string {
  if (typeof value !== "string") return "";
  return value
    // التشكيل يسقط هنا كما يسقط في الإجابات: الشاشةُ تُقرأ ويُنطق منها.
    .replace(/[ً-ٰٟۖ-ۭـ]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, limit);
}

/**
 * طلبُ التوليد.
 *
 * ── ولماذا يُطلب الشكلُ صريحاً ──
 * النموذج يعود بما يُشبه المطلوب لا بالمطلوب: «الفروع» قائمةَ نصوصٍ لا
 * كائنات، و«الصحيح» نصَّ الخيار لا موضعَه. ووصفُ الشكل حرفاً حرفاً مع
 * مثالٍ يُقلّل ذلك — ولا يُغني عن التحقّق بعده.
 */
export function studyPrompt(input: {
  lessonTitle: string;
  lessonText: string;
  grade?: string;
}): string {
  const grade = clean(input.grade, 40);
  return [
    "انت معلم سعودي تعد مادة مذاكرة ذكية لطالب في المرحلة الابتدائية" +
      (grade ? ` (${grade})` : "") +
      ".",
    "",
    `عنوان الدرس: ${clean(input.lessonTitle, 120)}`,
    "نص الدرس:",
    input.lessonText.slice(0, 6000),
    "",
    "اخرج كائن JSON واحدا فقط، بلا اي شرح قبله او بعده، وبلا علامات تنسيق، بهذا الشكل:",
    "{",
    '  "mindMap": {',
    '    "title": "عنوان الدرس بكلمات قليلة — وهو جذر الشجرة",',
    '    "branches": [',
    '      { "icon": "🌿", "title": "اسم الفرع", "summary": "شرح الفرع في سطرين مفهومين" }',
    "    ]",
    "  },",
    '  "scenarios": [',
    "    {",
    '      "title": "عنوان المغامرة",',
    '      "situations": [',
    "        {",
    '          "prompt": "موقف قصصي يواجه الطالب ويحتاج قرارا",',
    '          "options": ["خيار اول", "خيار ثان", "خيار ثالث"],',
    '          "answer": 0,',
    '          "because": "لماذا هذا الخيار صحيح، بجملة قصيرة"',
    "        }",
    "      ]",
    "    }",
    "  ]",
    "}",
    "",
    "وهذه شروط لازمة:",
    // ── والفروعُ شرطٌ مشدَّد ──
    // خريطةٌ بجذرٍ بلا فروع ليست خريطة، وهي أوّلُ ما يخرج به النموذج حين
    // يُترك الشرطُ رخواً: عنوانٌ واحد وقائمةٌ فارغة. فيُقال العددُ مرّتين —
    // في الشكل وفي الشروط — ويُطلب صريحاً ألّا تكون فارغة.
    `- "branches" مصفوفة فيها ${MIN_BRANCHES} إلى ${MAX_BRANCHES} فروع، ولا تكون فارغة أبدا.`,
    '- كل فرع كائن فيه "title" و"summary" و"icon"، ولا يخلو من واحد منها.',
    '- "summary" شرح مفهوم في سطرين، لا كلمة واحدة ولا تكرار للعنوان.',
    '- "icon" رمز تعبيري واحد يناسب الفرع.',
    "- والفروع اجزاء الدرس الكبرى: كل فرع مفهوم قائم بنفسه، لا جملة من النص.",
    `- عدد المغامرات بين ${MIN_SCENARIOS} و${MAX_SCENARIOS}، وكل واحدة مختلفة عن الاخرى في حكايتها.`,
    `- كل مغامرة فيها ${SITUATIONS_PER_SCENARIO} مواقف بالضبط، وكل موقف ${OPTIONS_PER_SITUATION} خيارات بالضبط.`,
    '- "answer" رقم موضع الخيار الصحيح في القائمة، يبدا من صفر.',
    "- الخيارات الثلاثة مختلفة، والخطأ منها معقول لا سخيف.",
    "- كل موقف يقيس مفهوما من مفاهيم الدرس، لا معلومة عامة من خارجه.",
    "- اكتب بلهجة سعودية بيضاء سهلة، وبلا اي تشكيل على الحروف.",
  ].join("\n");
}

/** يفكّ JSON من ردٍّ قد يحمل سياج شيفرةٍ أو كلاماً حوله. */
export function extractJson(raw: unknown): unknown {
  if (typeof raw !== "string") return null;
  const fenced = raw.match(/```(?:json)?\s*([\s\S]*?)```/);
  const body = fenced ? fenced[1]! : raw;
  const start = body.indexOf("{");
  const end = body.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    return JSON.parse(body.slice(start, end + 1));
  } catch {
    return null;
  }
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

/** الخريطةُ الذهنية، أو `null` إن لم تصلح. */
export function parseMindMap(raw: unknown, fallbackTitle: string): MindMap | null {
  const map = raw && typeof raw === "object" ? (raw as Record<string, unknown>) : null;
  if (!map) return null;
  const branches: MindMapBranch[] = [];
  for (const entry of asArray(map.branches)) {
    const item = entry && typeof entry === "object"
      ? (entry as Record<string, unknown>)
      : null;
    if (!item) continue;
    const title = clean(item.title, 60);
    const summary = clean(item.summary, 200);
    if (!title || !summary) continue;
    // ولا فرعان بعنوانٍ واحد: شجرةٌ فيها فرعان متطابقان تبدو عطباً.
    if (branches.some((branch) => branch.title === title)) continue;
    branches.push({ title, summary, icon: clean(item.icon, 8) });
    if (branches.length === MAX_BRANCHES) break;
  }
  if (branches.length < MIN_BRANCHES) return null;
  const title = clean(map.title, 80) || clean(fallbackTitle, 80);
  return title ? { title, branches } : null;
}

/** موقفٌ واحد، أو `null`. */
export function parseSituation(raw: unknown): Situation | null {
  const map = raw && typeof raw === "object" ? (raw as Record<string, unknown>) : null;
  if (!map) return null;
  const prompt = clean(map.prompt, 300);
  if (!prompt) return null;

  const options: string[] = [];
  for (const entry of asArray(map.options)) {
    const option = clean(entry, 120);
    // والمتطابقُ يُسقط الموقف لا يُهمل: خيارٌ مكرّر يعني أنّ الصحيح قد
    // يكون اثنين، فلا يُعرف أيُّهما أراد النموذج.
    if (!option || options.includes(option)) return null;
    options.push(option);
  }
  if (options.length !== OPTIONS_PER_SITUATION) return null;

  // و«الصحيح» يأتي رقماً أو نصَّ الخيار: كلاهما يُقرأ، وما سواهما يُردّ.
  let answer = -1;
  if (typeof map.answer === "number" && Number.isInteger(map.answer)) {
    answer = map.answer;
  } else if (typeof map.answer === "string") {
    const asNumber = Number(map.answer.trim());
    answer = Number.isInteger(asNumber)
      ? asNumber
      : options.indexOf(clean(map.answer, 120));
  }
  if (answer < 0 || answer >= options.length) return null;

  return {
    prompt,
    options,
    answer,
    because: clean(map.because, 200),
  };
}

/** سيناريو واحد، أو `null`. */
export function parseScenario(raw: unknown): Scenario | null {
  const map = raw && typeof raw === "object" ? (raw as Record<string, unknown>) : null;
  if (!map) return null;
  const situations: Situation[] = [];
  for (const entry of asArray(map.situations)) {
    const situation = parseSituation(entry);
    if (situation) situations.push(situation);
    if (situations.length === SITUATIONS_PER_SCENARIO) break;
  }
  if (situations.length !== SITUATIONS_PER_SCENARIO) return null;
  const title = clean(map.title, 80);
  return title ? { title, situations } : null;
}

/**
 * الحزمةُ كاملةً من ردّ النموذج، أو `null`.
 *
 * ── ولماذا الكلُّ أو لا شيء ──
 * حزمةٌ نصفُها صالح تصل الطفلَ شاشةً فيها خريطةٌ بلا مغامرة، أو مغامرةٌ
 * بموقفين. والإخفاقُ الصريح يُعيد التوليد في المرّة القادمة؛ والنصفُ
 * يُخزَّن فيبقى ناقصاً إلى الأبد.
 */
export function parseStudyPack(
  raw: unknown,
  fallbackTitle: string,
  now: () => Date = () => new Date(),
): StudyPack | null {
  const payload = extractJson(raw) ?? raw;
  const map = payload && typeof payload === "object"
    ? (payload as Record<string, unknown>)
    : null;
  if (!map) return null;

  const mindMap = parseMindMap(map.mindMap, fallbackTitle);
  if (!mindMap) return null;

  const scenarios: Scenario[] = [];
  for (const entry of asArray(map.scenarios)) {
    const scenario = parseScenario(entry);
    if (!scenario) continue;
    if (scenarios.some((item) => item.title === scenario.title)) continue;
    scenarios.push(scenario);
    if (scenarios.length === MAX_SCENARIOS) break;
  }
  if (scenarios.length < MIN_SCENARIOS) return null;

  return {
    version: STUDY_VERSION,
    mindMap,
    scenarios,
    createdAt: now().toISOString(),
  };
}

/**
 * الحزمةُ المخزَّنة، أو `null` إن غابت أو كانت من نسخةٍ أقدم.
 *
 * ونسخةٌ أقدم تُهمل ولا تُصلَح: شكلُها تغيّر، والتوليدُ نداءٌ واحد.
 */
export function readStudyPack(value: unknown): StudyPack | null {
  const map = value && typeof value === "object"
    ? (value as Record<string, unknown>)
    : null;
  if (!map || map.version !== STUDY_VERSION) return null;
  const mindMap = parseMindMap(map.mindMap, "");
  if (!mindMap) return null;
  const scenarios = asArray(map.scenarios)
    .map((entry) => parseScenario(entry))
    .filter((entry): entry is Scenario => entry !== null);
  if (scenarios.length < MIN_SCENARIOS) return null;
  return {
    version: STUDY_VERSION,
    mindMap,
    scenarios,
    createdAt: typeof map.createdAt === "string" ? map.createdAt : "",
  };
}

/**
 * عددُ المواقف في الحزمة كلِّها — سقفُ ما يُكافأ عليه.
 *
 * يُقرأ في الخادم لا يُؤخذ من التطبيق: الجواهر تُحسب من الإجابات الصحيحة،
 * والسقفُ يمنع طلباً يدّعي أكثر ممّا في الحزمة.
 */
export function maxSituations(pack: StudyPack): number {
  return pack.scenarios.reduce(
    (total, scenario) => total + scenario.situations.length,
    0,
  );
}
