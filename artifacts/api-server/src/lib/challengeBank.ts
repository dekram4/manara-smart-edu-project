/**
 * بنك جولات التحدي: جولاتٌ حركية تُولَّد من نصّ الدرس وتُخزَّن معه.
 *
 * ── لماذا جولاتٌ لا أسئلة ──
 * سؤالُ الاختيار من متعدّد امتحانٌ مصغّر: يقرأ الطفل ويختار حرفاً. وهذه
 * لعبة — يسحب الكلمة إلى فراغها، ويفرز العناصر في مجموعاتها، ويطابق
 * المصطلح بتعريفه. الفرقُ ليس في الشكل: الإفلات الخاطئ يرتدّ ولا يُحسب
 * خطأً، فلا عقوبةَ على المحاولة.
 *
 * ── ولماذا بنكٌ مخزَّن لا توليدٌ لحظيّ ──
 * التوليد عند الفتح يُجلس طفلاً أمام دوّارةِ انتظارٍ عشر ثوانٍ، ويُسقط
 * البطاقة كلّها إن تعثّر النموذج. فيُولَّد البنك مرّةً ويُحفظ مع الدرس،
 * ثم تُسحب منه جولاتٌ عشوائية فوراً. وإعادةُ التحدي تسحب غيرها من
 * البنك نفسه — فالتجدّد من سَعة البنك لا من طلبٍ جديد.
 *
 * هذه الوحدة نقيّةٌ وخاليةٌ من الشبكة: قواعد القبول أدناه هي ما يُخطئ
 * على نصٍّ حقيقي، وتُختبر مباشرةً.
 */

export type RoundKind = "fill" | "classify" | "match";

/** أكمل جملة الدرس بالكلمة المسحوبة إلى فراغها. */
export interface FillRound {
  kind: "fill";
  /** ما قبل الفراغ وما بعده، من جملة الدرس نفسها. */
  before: string;
  after: string;
  answer: string;
  /** كلماتٌ من الدرس تُعرض مع الجواب، ولا تناسب الفراغ. */
  distractors: string[];
}

/** افرز عناصر الدرس في مجموعاتها بالسحب. */
export interface ClassifyRound {
  kind: "classify";
  prompt: string;
  buckets: string[];
  /** العنصر ← المجموعة التي يخصّها. */
  items: Record<string, string>;
}

/** طابق كل مصطلحٍ بتعريفه من الدرس. */
export interface MatchRound {
  kind: "match";
  pairs: { term: string; meaning: string }[];
}

export type ChallengeRound = FillRound | ClassifyRound | MatchRound;

export interface ChallengeBank {
  version: number;
  generatedAt: string;
  subject: string;
  rounds: ChallengeRound[];
}

/** صيغة البنك. رقمٌ يتغيّر حين تتغيّر القواعد، فيُعاد التوليد. */
export const BANK_VERSION = 1;

/** حجم البنك المطلوب من النموذج. */
export const BANK_SIZE = 20;

/** ما يُسحب منه لجولةِ لعبٍ واحدة. */
export const ROUNDS_PER_PLAY = 5;

export type ChallengeSubject = "english" | "math" | "science" | "other";

const text = (value: unknown): string =>
  typeof value === "string" ? value.trim() : "";

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

export function detectSubject(subject: unknown): ChallengeSubject {
  const wanted = norm(subject);
  if (!wanted) return "other";
  if (wanted.includes("انجليز") || wanted.includes("english")) return "english";
  if (wanted.includes("رياضيات") || wanted.includes("math")) return "math";
  if (wanted.includes("علوم") || wanted.includes("science")) return "science";
  return "other";
}

/** يُزيل ترميز المعادلات ويُبقي المعنى. */
export function clean(value: unknown): string {
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

const SAFE_COMMANDS =
  /^(?:d|t)?(?:frac|times|div|cdot|text|mathrm|mathbf|textbf|mbox|left|right)$/;

/** أوّل أمر LaTeX لا تُعرف تنقيته، أو `null`. */
export function unsafeCommand(...values: unknown[]): string | null {
  for (const value of values) {
    for (const match of text(value).matchAll(/\\([a-zA-Z]+)/g)) {
      if (!SAFE_COMMANDS.test(match[1])) return match[1];
    }
  }
  return null;
}

const ARABIC = /[؀-ۿ]/;

// ── القبول ─────────────────────────────────────────────────────────────

export type Verdict =
  | { ok: true; round: ChallengeRound }
  | { ok: false; why: string };

/** هل كل نصوص الجولة بلسانها الصحيح؟ */
function languageOk(subject: ChallengeSubject, parts: string[]): string | null {
  const joined = parts.join(" ");
  if (subject === "english" && ARABIC.test(joined)) {
    return "حرف عربي في تحدّي الإنجليزية";
  }
  return null;
}

/**
 * يقبل الجولة أو يردّها، ويقول لماذا.
 *
 * كل قاعدةٍ هنا تقابل خطأً يُخرج لعبةً لا تُلعب: فراغٌ بلا جواب، أو
 * جوابٌ مذكورٌ في الجملة نفسها فيُقرأ قبل سحبه، أو مجموعةٌ لا عنصر لها
 * فتبقى فارغةً إلى الأبد، أو تعريفٌ يذكر مصطلحه فيُحلّ بالنظر.
 */
export function acceptRound(raw: unknown, subject: ChallengeSubject): Verdict {
  const item = (raw ?? {}) as Record<string, unknown>;
  const kind = text(item.kind).toLowerCase();

  if (kind === "fill") return acceptFill(item, subject);
  if (kind === "classify") return acceptClassify(item, subject);
  if (kind === "match") return acceptMatch(item, subject);
  return { ok: false, why: `نوع جولة غير معروف: ${kind || "(فارغ)"}` };
}

function acceptFill(item: Record<string, unknown>, subject: ChallengeSubject): Verdict {
  const before = clean(item.before);
  const after = clean(item.after);
  const answer = clean(item.answer);
  const distractors = (Array.isArray(item.distractors) ? item.distractors : [])
    .map(clean)
    .filter(Boolean);

  const unsafe = unsafeCommand(item.before, item.after, item.answer, ...distractors);
  if (unsafe) return { ok: false, why: `أمر LaTeX لا تُعرف تنقيته: \\${unsafe}` };

  if (!answer) return { ok: false, why: "فراغ بلا جواب" };
  if (before.length + after.length < 8) {
    return { ok: false, why: "جملة أقصر من أن تُقرأ" };
  }
  // الجواب مذكورٌ في الجملة: يُقرأ قبل أن يُسحب، فلا لغز.
  if (norm(`${before} ${after}`).includes(norm(answer))) {
    return { ok: false, why: "الجواب مكتوب في الجملة نفسها" };
  }
  const unique = [...new Set(distractors.map(norm))].filter(
    (value) => value !== norm(answer),
  );
  if (unique.length < 2) return { ok: false, why: "أقلّ من مشتّتَين" };

  const problem = languageOk(subject, [before, after, answer, ...distractors]);
  if (problem) return { ok: false, why: problem };

  const picked: string[] = [];
  for (const candidate of distractors) {
    const key = norm(candidate);
    if (key === norm(answer)) continue;
    if (picked.some((value) => norm(value) === key)) continue;
    picked.push(candidate);
    if (picked.length === 3) break;
  }

  return {
    ok: true,
    round: { kind: "fill", before, after, answer, distractors: picked },
  };
}

function acceptClassify(
  item: Record<string, unknown>,
  subject: ChallengeSubject,
): Verdict {
  const prompt = clean(item.prompt);
  const buckets = (Array.isArray(item.buckets) ? item.buckets : [])
    .map(clean)
    .filter(Boolean);
  const rawItems =
    item.items && typeof item.items === "object" && !Array.isArray(item.items)
      ? (item.items as Record<string, unknown>)
      : {};

  const entries: [string, string][] = [];
  for (const [name, bucket] of Object.entries(rawItems)) {
    const cleanName = clean(name);
    const cleanBucket = clean(bucket);
    if (!cleanName || !cleanBucket) continue;
    entries.push([cleanName, cleanBucket]);
  }

  const unsafe = unsafeCommand(
    item.prompt,
    ...buckets,
    ...entries.flat(),
  );
  if (unsafe) return { ok: false, why: `أمر LaTeX لا تُعرف تنقيته: \\${unsafe}` };

  if (buckets.length < 2) return { ok: false, why: "أقلّ من مجموعتين" };
  if (new Set(buckets.map(norm)).size !== buckets.length) {
    return { ok: false, why: "مجموعتان بالاسم نفسه" };
  }
  if (entries.length < 4) return { ok: false, why: "أقلّ من أربعة عناصر" };

  const bucketKeys = new Set(buckets.map(norm));
  const used = new Set<string>();
  const items: Record<string, string> = {};
  for (const [name, bucket] of entries) {
    if (!bucketKeys.has(norm(bucket))) {
      return { ok: false, why: `عنصرٌ في مجموعةٍ غير معلنة: ${bucket}` };
    }
    if (items[name] !== undefined) continue;
    items[name] = buckets.find((value) => norm(value) === norm(bucket))!;
    used.add(norm(items[name]));
  }
  // مجموعةٌ بلا عنصر تبقى فارغةً إلى آخر الجولة، فيظنّ الطفل أنه أخطأ.
  if (used.size !== buckets.length) {
    return { ok: false, why: "مجموعة بلا عنصر" };
  }

  const problem = languageOk(subject, [
    prompt,
    ...buckets,
    ...Object.keys(items),
  ]);
  if (problem) return { ok: false, why: problem };

  return {
    ok: true,
    round: {
      kind: "classify",
      prompt: prompt || "صنّف العناصر في مجموعاتها",
      buckets,
      items,
    },
  };
}

function acceptMatch(
  item: Record<string, unknown>,
  subject: ChallengeSubject,
): Verdict {
  const rawPairs = Array.isArray(item.pairs) ? item.pairs : [];
  const pairs: { term: string; meaning: string }[] = [];
  const seenTerms = new Set<string>();
  const seenMeanings = new Set<string>();

  for (const entry of rawPairs) {
    const pair = (entry ?? {}) as Record<string, unknown>;
    const term = clean(pair.term);
    const meaning = clean(pair.meaning);
    if (!term || !meaning) continue;
    const unsafe = unsafeCommand(pair.term, pair.meaning);
    if (unsafe) return { ok: false, why: `أمر LaTeX لا تُعرف تنقيته: \\${unsafe}` };
    // تعريفٌ يذكر مصطلحه يُحلّ بالنظر بلا فهم.
    if (norm(meaning).includes(norm(term))) {
      return { ok: false, why: "التعريف يذكر مصطلحه" };
    }
    if (seenTerms.has(norm(term)) || seenMeanings.has(norm(meaning))) continue;
    seenTerms.add(norm(term));
    seenMeanings.add(norm(meaning));
    pairs.push({ term, meaning });
    if (pairs.length === 4) break;
  }

  if (pairs.length < 3) return { ok: false, why: "أقلّ من ثلاثة أزواج" };

  const problem = languageOk(
    subject,
    pairs.flatMap((pair) => [pair.term, pair.meaning]),
  );
  if (problem) return { ok: false, why: problem };

  return { ok: true, round: { kind: "match", pairs } };
}

// ── التوجيه ────────────────────────────────────────────────────────────

const SHAPE = `أعد JSON فقط، بلا أيّ نصّ قبله أو بعده:
{"rounds":[
  {"kind":"fill","before":"ما قبل الفراغ","after":"ما بعده","answer":"الكلمة الناقصة","distractors":["خطأ 1","خطأ 2","خطأ 3"]},
  {"kind":"classify","prompt":"تعليمة قصيرة","buckets":["مجموعة أ","مجموعة ب"],"items":{"عنصر 1":"مجموعة أ","عنصر 2":"مجموعة ب","عنصر 3":"مجموعة أ","عنصر 4":"مجموعة ب"}},
  {"kind":"match","pairs":[{"term":"مصطلح","meaning":"تعريفه"},{"term":"مصطلح 2","meaning":"تعريفه 2"},{"term":"مصطلح 3","meaning":"تعريفه 3"}]}
]}`;

const COMMON = `قواعد إلزامية لكل الجولات:
- لا تخرج عن نصّ الدرس المرفق. كل كلمةٍ ومصطلحٍ وعددٍ منه.
- ممنوع أيّ رمز LaTeX أو علامة دولار أو شرطة مائلة عكسية.
- في جولة "fill": الكلمة الناقصة يجب ألّا تكون مكتوبةً في "before" ولا في "after" — وإلا قرأها الطفل بدل أن يفكّر. والمشتّتات ثلاثٌ من الدرس نفسه، معقولةٌ في موضعها ولكنها خاطئة.
- في جولة "classify": مجموعتان أو ثلاث، وأربعة عناصر فأكثر، ولكل مجموعة عنصرٌ واحدٌ على الأقل.
- في جولة "match": ثلاثة أزواج أو أربعة، والتعريف لا يذكر مصطلحه.
- نوّع الأنواع الثلاثة: لا تجعل البنك كلّه من نوعٍ واحد.`;

const ENGLISH = `MANDATORY:
- Every string — sentences, words, bucket names, terms, definitions — in ENGLISH ONLY. Not one Arabic character.
- Target a grade-four EFL learner. Build rounds from the grammar and vocabulary this lesson teaches: complete the sentence with the right word, sort words into word classes or groups the lesson names, match a word to its meaning.
- "fill" sentences come from the lesson's own English sentences.`;

const MATH = `إضافةً لذلك في الرياضيات:
- اجعل "fill" معادلةً أو جملةً عددية ينقصها عددٌ أو مصطلح: "ناتج 7 × 8 هو ___".
- المشتّتات أعدادٌ قريبةٌ من الجواب، أخطاءٌ يقع فيها طفلٌ فعلاً.
- اكتب الأعداد والعمليات نصّاً عادياً: "5 × 4 = 20"، و"3/4".
- في "classify" افرز بحسب ما صنّفه الدرس: زوجيّ وفرديّ، أكبر وأصغر، عمليةٌ ونتيجتها.`;

const SCIENCE = `إضافةً لذلك في العلوم:
- ابنِ الجولات على الظواهر والمفاهيم المشروحة: صنّف الكائنات أو المواد أو القوى كما صنّفها الدرس، وطابق العضو بوظيفته والمصطلح بتعريفه.
- "fill" جملةٌ من الدرس ينقصها مصطلحه المفتاحي.`;

export function bankPrompt(input: {
  subject: string;
  unit?: string;
  lesson?: string;
  lessonText: string;
  count?: number;
}): string {
  const subject = detectSubject(input.subject);
  const english = subject === "english";
  const count = input.count ?? BANK_SIZE;
  const extra =
    subject === "math" ? MATH : subject === "science" ? SCIENCE : "";
  const rules = english ? ENGLISH : `${COMMON}\n${extra}`;
  const head = english
    ? `You are designing ${count} rounds of a drag-and-drop learning game for a grade-four class.`
    : `أنت تصمّم ${count} جولةً من لعبة سحبٍ وإفلاتٍ تعليمية لصفٍّ رابع ابتدائي.`;

  return `${head}

المادة: ${input.subject}
${input.unit ? `الوحدة: ${input.unit}\n` : ""}${input.lesson ? `الدرس: ${input.lesson}\n` : ""}
نصّ الدرس المعتمد — لا تخرج عنه:
"""
${input.lessonText.slice(0, 7000)}
"""

${english ? `${COMMON}\n${ENGLISH}` : rules}
- ${count} ${english ? "rounds" : "جولة"}، لا أقلّ، ولا جولتان متطابقتان.

${SHAPE}`;
}

// ── التصفية ────────────────────────────────────────────────────────────

export interface ParseResult {
  rounds: ChallengeRound[];
  rejected: Record<string, number>;
}

/** بصمةُ جولةٍ، لكشف التكرار بين الجولات لا داخلها. */
export function fingerprint(round: ChallengeRound): string {
  switch (round.kind) {
    case "fill":
      return `fill:${norm(round.answer)}:${norm(round.before)}`;
    case "classify":
      return `classify:${Object.keys(round.items).map(norm).sort().join(",")}`;
    case "match":
      return `match:${round.pairs.map((pair) => norm(pair.term)).sort().join(",")}`;
  }
}

export function parseBank(
  raw: unknown,
  subject: ChallengeSubject,
  limit = BANK_SIZE,
): ParseResult {
  let payload: any = raw;
  if (typeof payload === "string") {
    const fenced = payload.match(/```(?:json)?\s*([\s\S]*?)```/);
    try {
      payload = JSON.parse((fenced ? fenced[1] : payload).trim());
    } catch {
      return { rounds: [], rejected: { "ردّ ليس JSON صالحاً": 1 } };
    }
  }
  const list: unknown[] = Array.isArray(payload)
    ? payload
    : Array.isArray(payload?.rounds)
      ? payload.rounds
      : [];

  const rounds: ChallengeRound[] = [];
  const rejected: Record<string, number> = {};
  const seen = new Set<string>();

  for (const candidate of list) {
    if (rounds.length >= limit) break;
    const verdict = acceptRound(candidate, subject);
    if (!verdict.ok) {
      rejected[verdict.why] = (rejected[verdict.why] ?? 0) + 1;
      continue;
    }
    const key = fingerprint(verdict.round);
    if (seen.has(key)) {
      rejected["جولة مكرّرة"] = (rejected["جولة مكرّرة"] ?? 0) + 1;
      continue;
    }
    seen.add(key);
    rounds.push(verdict.round);
  }
  return { rounds, rejected };
}

/** يقرأ بنكاً محفوظاً، أو `null` إن لم يكن صالحاً أو كانت صيغته قديمة. */
export function readBank(value: unknown): ChallengeBank | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const bank = value as Record<string, unknown>;
  if (Number(bank.version) !== BANK_VERSION) return null;
  const rounds = Array.isArray(bank.rounds) ? bank.rounds : [];
  const valid = rounds.filter(
    (round): round is ChallengeRound =>
      Boolean(round) && typeof round === "object" &&
      ["fill", "classify", "match"].includes(String((round as any).kind)),
  );
  if (valid.length === 0) return null;
  return {
    version: BANK_VERSION,
    generatedAt: text(bank.generatedAt),
    subject: text(bank.subject),
    rounds: valid,
  };
}

/**
 * يسحب [count] جولةً من البنك بلا تكرارٍ داخل السحبة.
 *
 * البذرة تجعل السحبة قابلةً للإعادة في الاختبار، وتختلف في التشغيل
 * الحقيقي — فإعادةُ التحدي تُخرج غيرَ ما خرج.
 */
export function drawRounds(
  bank: ChallengeBank,
  count = ROUNDS_PER_PLAY,
  seed = Date.now(),
): ChallengeRound[] {
  const pool = [...bank.rounds];
  const picked: ChallengeRound[] = [];
  let state = seed >>> 0 || 1;
  const next = () => {
    // مولّدٌ بسيط ثابت: لا يُطلب منه جودةٌ تعمية، بل ترتيبٌ يُعاد بنفس
    // البذرة ويختلف بغيرها.
    state = (state * 1664525 + 1013904223) >>> 0;
    return state / 0x100000000;
  };
  while (pool.length > 0 && picked.length < count) {
    picked.push(pool.splice(Math.floor(next() * pool.length), 1)[0]);
  }
  return picked;
}
