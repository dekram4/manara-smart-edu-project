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
export const STUDY_VERSION = 3;

/** فروعُ الخريطة الذهنية: ثلاثةٌ أو أربعة، لا أكثر. */
export const MIN_BRANCHES = 3;
export const MAX_BRANCHES = 5;

/**
 * مغامرتان لكل فرع.
 *
 * ── لماذا اثنتان لا واحدة ──
 * واحدةٌ لكل فرع تعني أن إعادةَ التحدي تُعيد الأسئلة بحرفها: الطفل يعرف
 * الجوابَ من موضعه لا من فهمه، فتصير الإعادةُ حفظاً لا مذاكرة. واثنتان
 * تجعلان الإعادةَ تُبدّل الحكاية.
 *
 * ── ولماذا لا أكثر ──
 * كلُّ مغامرةٍ ثلاثةُ مواقف، وكلُّ موقفٍ نصٌّ وخيارات. فخمسةُ فروعٍ في
 * ثلاث مغامراتٍ خمسةَ عشرَ مشهداً في نداءٍ واحد — يطول ويُقتطع في منتصفه
 * فتُردّ الحزمةُ كلُّها.
 */
export const SCENARIOS_PER_BRANCH = 2;

/**
 * وحدُّ المغامرات في الحزمة: مغامرتان لكل فرع.
 *
 * والأدنى يوافق أقلَّ الفروع، والأقصى أكثرَها. وسيناريو بلا فرعٍ معروف
 * يُحسب في الأدنى كما يُحسب غيرُه: الحزمةُ تصلح ولو أخطأ النموذجُ في اسم
 * فرع، و`forBranch` ترتدّ إلى الكلّ.
 */
export const MIN_SCENARIOS = MIN_BRANCHES * SCENARIOS_PER_BRANCH;
export const MAX_SCENARIOS = MAX_BRANCHES * SCENARIOS_PER_BRANCH;

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

/**
 * نمطُ التحدي — وهو ما يُغيّر شكلَ الموقف على الشاشة لا حسابَه.
 *
 * ── لماذا ثلاثةٌ لا واحد ──
 * أربعةُ أزرارٍ متشابهة في كل موقف تصير عادةً بعد الموقف الثالث: الطفل
 * يقرأ الخيارات ويختار أقربها، ولا يتحرّك في المشهد شيء. والثلاثةُ هنا
 * تسأل السؤالَ نفسه بأفعالٍ مختلفة: يمشي، ويسحب، ويفرقع.
 *
 * ── وحسابُ الجواهر واحدٌ فيها ──
 * كلُّها تُخزَّن بـ`options` و`answer`: موضعُ الصحيح في القائمة. فلا
 * يعرف محرّكُ المكافآت أنماطاً، ولا يتبدّل شرطُ الجوهرتين ولا حارسُ
 * التكرار بتبدّل الشكل.
 */
export type ChallengeType = "avatar_path" | "swipe_fact" | "spot_imposter";

/** الأنماطُ الثلاثة، وعددُ خياراتِ كلٍّ منها. */
export const CHALLENGE_OPTIONS: Record<ChallengeType, number> = {
  // بوّابتان يمشي بينهما.
  avatar_path: 2,
  // حقيقةٌ تُسحب: صفرٌ صحيحة، وواحدٌ خطأ. ولا نصَّ خيارٍ يُخزَّن — التطبيق
  // يكتب «صحيح» و«خطأ» بلغته.
  swipe_fact: 0,
  // ثلاثُ فقاعات، إحداها متسلّلة.
  spot_imposter: 3,
};

export interface Situation {
  /** نمطُ التحدي. */
  type: ChallengeType;
  /** الموقفُ كما يُحكى للطفل، أو الحقيقةُ في نمط السحب. */
  prompt: string;
  options: string[];
  /** موضعُ الصحيح في [options] — أو ٠/١ في نمط السحب. */
  answer: number;
  /** لماذا هو الصحيح — يُعرض بعد الاختيار. */
  because: string;
}

export interface Scenario {
  title: string;
  /**
   * عنوانُ فرع الخريطة الذي يقيسه هذا السيناريو.
   *
   * ── لماذا ──
   * الطفل يضغط فرعاً في الشجرة ليقرأه، ثم يريد أن يُختبر فيه هو لا في
   * الدرس كلِّه. ولو كانت الأسئلةُ عامّةً لكان ضغطُ الفرع قراءةً بلا أثر.
   *
   * وفارغٌ مقبول: حزمةٌ من نموذجٍ لم يُلزمه الطلبُ بعد، أو سيناريو يجمع
   * فروعاً. وحينها يُعرض في «كل الدرس».
   */
  branch: string;
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
    '      "branch": "اسم الفرع الذي تقيسه هذه المغامرة، من فروع mindMap",',
    '      "situations": [',
    "        {",
    '          "type": "avatar_path",',
    '          "prompt": "موقف قصصي: امام الطالب بوابتان ويحتاج ان يختار",',
    '          "options": ["البوابة الاولى", "البوابة الثانية"],',
    '          "answer": 0,',
    '          "because": "لماذا هذه البوابة صحيحة، بجملة قصيرة"',
    "        },",
    "        {",
    '          "type": "swipe_fact",',
    '          "prompt": "جملة معلومة واحدة عن الفرع، قد تكون صحيحة وقد تكون مشوهة",',
    '          "options": [],',
    '          "isTrue": true,',
    '          "because": "لماذا هي صحيحة او مشوهة، بجملة قصيرة"',
    "        },",
    "        {",
    '          "type": "spot_imposter",',
    '          "prompt": "اي معلومة من الثلاث متسللة وليست من الدرس؟",',
    '          "options": ["حقيقة صحيحة", "حقيقة صحيحة اخرى", "معلومة متسللة مشوهة"],',
    '          "answer": 2,',
    '          "because": "لماذا هذه المتسللة، بجملة قصيرة"',
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
    // ── ومغامرتان لكل فرع، لا حزمةٌ واحدةٌ للدرس ──
    // كان الطلبُ يطلب مغامرتين أو ثلاثاً للدرس كلِّه، فيصل الطفلَ التحديُ
    // نفسه أيَّ فرعٍ ضغط — والإعادةُ تُعيده بحرفه.
    `- لكل فرع من فروع mindMap مغامرتان بالضبط، فمجموع المغامرات = عدد الفروع × ${SCENARIOS_PER_BRANCH}.`,
    '- "branch" في كل مغامرة يطابق حرفيا عنوان فرعها في mindMap.',
    "- ومغامرتا الفرع الواحد مختلفتان: حكاية اخرى، ومواقف اخرى، واسئلة لا تتشابه.",
    "- ومواقف كل مغامرة مشتقة من شرح فرعها بعينه، لا من الدرس عموما ولا من فرع اخر.",
    `- كل مغامرة فيها ${SITUATIONS_PER_SCENARIO} مواقف بالضبط، وكل مغامرة تخص فرعا واحدا تذكره في "branch".`,
    // ── والأنماطُ الثلاثة في كل مغامرة ──
    // نمطٌ واحدٌ يتكرّر ثلاثاً يصير عادةً في الموقف الثاني. والتنويعُ
    // يُطلب صريحاً بالترتيب، وإلا أخرج النموذج `avatar_path` ثلاثَ مرّات.
    `- المواقف الثلاثة انماطها بهذا الترتيب: "avatar_path" ثم "swipe_fact" ثم "spot_imposter".`,
    '- "avatar_path": خياران بالضبط في "options"، و"answer" موضع الصحيح (0 او 1).',
    '- "swipe_fact": "options" مصفوفة فارغة، و"prompt" جملة المعلومة نفسها، و"isTrue" صح او خطأ.',
    '- "spot_imposter": ثلاثة خيارات، اثنتان صحيحتان وواحدة متسللة، و"answer" موضع المتسللة.',
    '- "answer" رقم يبدا من صفر.',
    "- الخيارات في الموقف مختلفة، والخطأ منها معقول لا سخيف.",
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

/** نمطُ التحدي من الردّ، أو `null` إن لم يكن واحداً من الثلاثة. */
export function parseChallengeType(raw: unknown): ChallengeType | null {
  const value = typeof raw === "string" ? raw.trim().toLowerCase() : "";
  return value in CHALLENGE_OPTIONS ? (value as ChallengeType) : null;
}

/**
 * موقفٌ واحد، أو `null`.
 *
 * ── وعددُ الخيارات يتبع النمط ──
 * بوّابتان في المسار، وثلاثُ فقاعاتٍ في الرادار، ولا خيارَ في السحب —
 * الحقيقةُ في `prompt` والجوابُ صفرٌ أو واحد. فعددٌ لا يوافق نمطَه يُسقط
 * الموقف: موقفٌ بثلاث بوّاباتٍ لا تعرف الشاشةُ كيف ترسمه.
 */
export function parseSituation(raw: unknown): Situation | null {
  const map = raw && typeof raw === "object" ? (raw as Record<string, unknown>) : null;
  if (!map) return null;
  const type = parseChallengeType(map.type ?? map.challengeType);
  if (!type) return null;
  const prompt = clean(map.prompt ?? map.fact, 300);
  if (!prompt) return null;

  const wanted = CHALLENGE_OPTIONS[type];
  const options: string[] = [];
  for (const entry of asArray(map.options)) {
    const option = clean(entry, 120);
    // والمتطابقُ يُسقط الموقف لا يُهمل: خيارٌ مكرّر يعني أنّ الصحيح قد
    // يكون اثنين، فلا يُعرف أيُّهما أراد النموذج.
    if (!option || options.includes(option)) return null;
    options.push(option);
  }
  if (options.length !== wanted) return null;

  // و«الصحيح» يأتي رقماً أو نصَّ الخيار: كلاهما يُقرأ، وما سواهما يُردّ.
  //
  // وفي السحب لا خيارات، فيُقرأ `isTrue` بدلاً عنها: حقيقةٌ صحيحة جوابُها
  // صفر، ومشوَّهةٌ جوابُها واحد.
  let answer = -1;
  if (type === "swipe_fact") {
    const flag = map.isTrue ?? map.correct ?? map.answer;
    if (typeof flag === "boolean") {
      answer = flag ? 0 : 1;
    } else if (typeof flag === "number" && (flag === 0 || flag === 1)) {
      answer = flag;
    } else if (typeof flag === "string") {
      const text = flag.trim().toLowerCase();
      if (text === "true" || text === "0") answer = 0;
      if (text === "false" || text === "1") answer = 1;
    }
    if (answer !== 0 && answer !== 1) return null;
  } else {
    if (typeof map.answer === "number" && Number.isInteger(map.answer)) {
      answer = map.answer;
    } else if (typeof map.answer === "string") {
      const asNumber = Number(map.answer.trim());
      answer = Number.isInteger(asNumber)
        ? asNumber
        : options.indexOf(clean(map.answer, 120));
    }
    if (answer < 0 || answer >= options.length) return null;
  }

  return {
    type,
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
  return title
    ? { title, branch: clean(map.branch, 60), situations }
    : null;
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
    if (scenarios.length >= MAX_SCENARIOS) break;
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
