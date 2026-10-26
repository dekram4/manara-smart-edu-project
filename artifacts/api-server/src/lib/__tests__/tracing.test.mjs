/**
 * اختبارات لعبة «التتبّع» في بطاقة المذاكرة.
 *
 * التشغيل:
 *   npm run build && node --test src/lib/__tests__/tracing.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";

const tracing = await import(process.env.TRACING_MODULE ?? "../../../dist/lib/tracing.mjs");
const studyGames = await import(process.env.STUDY_GAMES_MODULE ?? "../../../dist/lib/studyGames.mjs");
const tracingQuiz = await import(process.env.TRACING_QUIZ_MODULE ?? "../../../dist/lib/tracingQuiz.mjs");

const {
  tracingItemsFrom,
  buildTracingGame,
  withTracingGame,
  alphabetGame,
  alphabetSetOf,
  alphabetItems,
  TRACING_REWARD,
  TRACING_MAX_ITEMS,
  ALPHABET_REWARD_AFTER,
} = tracing;
const { parseTracingQuiz, readTracingQuiz, isTraceableAnswer, TRACING_QUIZ_LIMITS, TRACING_QUIZ_SCHEMA } =
  tracingQuiz;
const { REWARD_LIMITS, parseStudyGameActivityId, GAME_TYPES, STUDY_GAMES_SCHEMA } = studyGames;

const texts = (items) => items.map((item) => item.text);

test("«حرف الباء» حرفٌ، وكلماتُه بعده", () => {
  const items = tracingItemsFrom({
    title: "حرف الباء",
    text: "نتعلّم اليوم حرف الباء. بَطّة تسبح، وباب البيت كبير. بطة بيضاء عند الباب.",
  });
  assert.equal(items[0].text, "ب");
  assert.equal(items[0].kind, "letter");
  assert.equal(items[0].lang, "ar");
  const words = items.filter((item) => item.kind === "word").map((item) => item.text);
  assert.ok(words.includes("بطة"), `بلا تشكيل: ${words}`);
  assert.ok(!words.includes("حرف") && !words.includes("الباء"), "لا كلمةَ «حرف» ولا اسمَ الحرف");
});

test("حرفٌ مكتوبٌ بنفسه: «الحرف م»", () => {
  assert.equal(tracingItemsFrom({ title: "", text: "الحرف م في أول الكلمة" })[0].text, "م");
});

test("الأرقامُ كما كُتبت", () => {
  const items = tracingItemsFrom({ title: "العدد ٥", text: "نعدّ حتى الرقم 7" });
  assert.deepEqual(
    items.filter((item) => item.kind === "number").map((item) => item.text),
    ["٥", "7"],
  );
});

test("درسُ الإنجليزية: الحرفُ كبيراً وصغيراً، والكلماتُ بالإنجليزية", () => {
  const items = tracingItemsFrom({
    title: "Letter B",
    text: "The letter B. A ball and a bag. The ball is big.",
    subject: "English",
  });
  assert.deepEqual(texts(items).slice(0, 2), ["B", "b"]);
  assert.ok(items.every((item) => item.lang === "en"));
  assert.ok(texts(items).includes("ball"));
  assert.ok(!texts(items).includes("the"));
});

test("بلا تكرار، وبحدٍّ أعلى", () => {
  const items = tracingItemsFrom({
    title: "",
    text: "قلم كتاب باب شمس قمر نجم بحر نهر جبل وردة قلم قلم",
  });
  assert.ok(items.length <= TRACING_MAX_ITEMS);
  assert.equal(new Set(texts(items)).size, items.length);
  assert.equal(items[0].text, "قلم", "الأكثرُ ذكراً أوّلاً");
});

test("نصٌّ بلا ما يُتتبّع: لا لعبة", () => {
  assert.equal(buildTracingGame({ title: "", text: "في من على إلى" }), null);
});

test("اللعبةُ بصيغة ألعاب البطاقة، ومكافأتُها داخل الحدود", () => {
  const game = buildTracingGame({ title: "حرف التاء", text: "تفاحة وتمر" });
  assert.equal(game.id, "tracing");
  assert.equal(game.game_type, "tracing");
  assert.ok(game.items.tracing.length > 0);
  assert.ok(TRACING_REWARD.gems >= REWARD_LIMITS.gems.min && TRACING_REWARD.gems <= REWARD_LIMITS.gems.max);
  assert.ok(
    TRACING_REWARD.points >= REWARD_LIMITS.points.min && TRACING_REWARD.points <= REWARD_LIMITS.points.max,
  );
});

test("تُضاف إلى الحزمة مرّةً واحدة، ولا شيءَ إن لم تكن لعبة", () => {
  const game = buildTracingGame({ title: "حرف التاء", text: "تفاحة وتمر" });
  const once = withTracingGame({ games: [] }, game);
  const twice = withTracingGame(once, game);
  assert.equal(twice.games.filter((entry) => entry.id === "tracing").length, 1);
  assert.equal(withTracingGame({ games: [] }, null).games.length, 0);
});

// ── الروضة: المجموعاتُ كاملة ───────────────────────────────────────────

test("موادُّ الروضة الأربع تُعرف بأيّ همزةٍ وتاءٍ كُتبت، وغيرُها لا", () => {
  assert.equal(alphabetSetOf("الحروف العربية"), "arabic_letters");
  assert.equal(alphabetSetOf("الحروف العربيه"), "arabic_letters");
  assert.equal(alphabetSetOf("الحروف الإنجليزية"), "english_letters");
  assert.equal(alphabetSetOf("الحروف الانجليزية"), "english_letters");
  assert.equal(alphabetSetOf("الأرقام العربية"), "arabic_digits");
  assert.equal(alphabetSetOf("الارقام الإنجليزية"), "english_digits");
  assert.equal(alphabetSetOf("English Letters"), "english_letters");
  assert.equal(alphabetSetOf("العلوم"), null);
  assert.equal(alphabetSetOf("اللغة العربية"), null, "مادّةُ لغةٍ لا مجموعةُ حروف");
  assert.equal(alphabetSetOf("الرياضيات"), null);
});

test("المجموعاتُ كاملة لا أوّلُ ستّة، ومع كلٍّ اسمُه للنطق", () => {
  const arabic = alphabetItems("arabic_letters");
  assert.equal(arabic.length, 28);
  assert.equal(arabic[1].text, "ب");
  assert.equal(arabic[1].speech, "باء");
  assert.equal(arabic.at(-1).text, "ي");
  assert.ok(arabic.every((item) => item.kind === "letter" && item.lang === "ar" && item.speech));

  const english = alphabetItems("english_letters");
  assert.equal(english.length, 26);
  assert.deepEqual([english[0].text, english[0].speech], ["Aa", "A"]);
  assert.equal(english.at(-1).text, "Zz");

  // الأرقامُ من الصفر إلى المئة، وتُنطق بأرقامها الغربية فيقرؤها المحرّكُ عدداً.
  const arabicDigits = alphabetItems("arabic_digits");
  assert.equal(arabicDigits.length, 101);
  assert.deepEqual(texts(arabicDigits).slice(0, 3), ["٠", "١", "٢"]);
  assert.equal(arabicDigits[25].text, "٢٥");
  assert.equal(arabicDigits[25].speech, "25");
  assert.equal(arabicDigits.at(-1).text, "١٠٠");
  const englishDigits = alphabetItems("english_digits");
  assert.equal(englishDigits.length, 101);
  assert.equal(englishDigits[42].text, "42");
  assert.equal(englishDigits.at(-1).text, "100");
  assert.ok([...arabicDigits, ...englishDigits].every((item) => item.kind === "number"));
});

test("لعبةُ الروضة: المجموعةُ كلُّها، تبدأ من حرف الدرس، والمكافأةُ بعد خمسة", () => {
  const game = alphabetGame({ title: "الوحدة الأولى — حرف الباء", subject: "الحروف العربية" });
  assert.equal(game.items.tracing.length, 28);
  assert.equal(game.items.start, 1, "يفتح على الباء");
  assert.equal(game.items.reward_after, ALPHABET_REWARD_AFTER);
  assert.equal(alphabetGame({ title: "", subject: "الأرقام العربية" }).items.start, 0);
  assert.equal(alphabetGame({ title: "العدد ٥", subject: "الأرقام العربية" }).items.start, 5);
  assert.equal(alphabetGame({ title: "العدد ٢٥", subject: "الأرقام العربية" }).items.start, 25);
  assert.equal(alphabetGame({ title: "العدد 100", subject: "الأرقام العربية" }).items.start, 100, "أيّاً كانت أرقامُ العنوان");
  assert.equal(alphabetGame({ title: "Letter C", subject: "الحروف الإنجليزية" }).items.start, 2);
  assert.equal(alphabetGame({ title: "", subject: "العلوم" }), null);
});

// ── أجب وتتبّع: أسئلةُ الذكاء الاصطناعي ────────────────────────────────

const owner = { lessonId: "L1", lessonStamp: "s1" };
const question = (n, answer = "الشمس", options = ["الشمس", "القمر", "النجوم"]) => ({
  question: `ما مصدر الضوء في النهار رقم ${n}؟`,
  options,
  answer,
});

test("خيارٌ يُمرَّر عليه: إلى ثلاث كلماتٍ قصيرة بلا رموز", () => {
  assert.ok(isTraceableAnswer("الشمس"));
  assert.ok(isTraceableAnswer("ضوء الشمس"));
  assert.ok(isTraceableAnswer("ضوء الشمس الساطع"));
  assert.ok(isTraceableAnswer("Sun"));
  assert.ok(isTraceableAnswer("12"));
  assert.ok(!isTraceableAnswer("ضوء الشمس الساطع جدا"), "أربعُ كلمات");
  assert.ok(!isTraceableAnswer("البروتوبلازماتالخلوية"), "أطولُ من ١٨ حرفاً");
  assert.ok(!isTraceableAnswer("H2O"), "حروفٌ وأرقامٌ في كلمة");
  assert.ok(!isTraceableAnswer("3.5"));
  assert.ok(!isTraceableAnswer(""));
});

test("من ٦ إلى ١٠ أسئلة صالحة، والإجابةُ بين ثلاثة خيارات", () => {
  const raw = JSON.stringify({ questions: Array.from({ length: 14 }, (_, i) => question(i)) });
  const quiz = parseTracingQuiz(raw, owner, { subject: "العلوم" });
  assert.equal(quiz.items.length, TRACING_QUIZ_LIMITS.max);
  for (const item of quiz.items) {
    assert.equal(item.kind, "answer");
    assert.equal(item.lang, "ar");
    assert.equal(item.options.length, 3);
    assert.ok(item.options.includes(item.text));
    assert.ok(item.prompt.length > 5);
  }
});

test("ما لا يُمرَّر عليه يسقط، وأقلُّ من ستّةٍ صالحةٍ لا يُحفظ", () => {
  const raw = {
    questions: [
      question(1),
      question(2),
      question(3),
      question(4),
      question(5),
      question(6, "ضوء الشمس الساطع جداً اليوم", ["ضوء الشمس الساطع جداً اليوم", "القمر", "النجوم"]),
      question(7, "الشمس", ["الشمس", "الشمس"]),
      { question: "قصير", options: ["أ", "ب", "ج"], answer: "أ" },
    ],
  };
  assert.equal(parseTracingQuiz(raw, owner), null);
  raw.questions.push(question(8));
  assert.equal(parseTracingQuiz(raw, owner).items.length, 6);
});

test("الإعادةُ أسئلةٌ جديدة: ما رآه الطالب يسقط ولو أعاده النموذج، ويُذكر له ليتجنّبه", () => {
  const raw = { questions: Array.from({ length: 9 }, (_, i) => question(i)) };
  const seen = [question(0).question, question(1).question, question(2).question];
  const fresh = parseTracingQuiz(raw, owner, { exclude: seen });
  assert.equal(fresh.items.length, 6);
  assert.ok(fresh.items.every((item) => !seen.includes(item.prompt)));
  const prompt = tracingQuiz.tracingQuizPrompt({ lessonTitle: "الضوء", lessonText: "نص", exclude: seen });
  assert.ok(seen.every((q) => prompt.includes(q)));
  assert.ok(!tracingQuiz.tracingQuizPrompt({ lessonTitle: "الضوء", lessonText: "نص" }).includes("من قبل"));
});

test("مكافأةُ الجولة: جوهرةٌ وعشرُ نقاطٍ عن كل صحيحة، محصورةً بعدد الأسئلة", () => {
  const { tracingQuizReward } = tracingQuiz;
  assert.deepEqual(tracingQuizReward(7, 10), { gems: 7, points: 70 });
  assert.deepEqual(tracingQuizReward(0, 8), { gems: 0, points: 0 });
  assert.deepEqual(tracingQuizReward(12, 8), { gems: 8, points: 80 }, "لا أكثرَ من الأسئلة");
  assert.deepEqual(tracingQuizReward(50, 50), { gems: 10, points: 100 }, "ولا أكثرَ من حدّ الجولة");
  assert.deepEqual(tracingQuizReward(-3, 5), { gems: 0, points: 0 });
  assert.deepEqual(tracingQuizReward(null, null), { gems: 0, points: 0 });
});

test("المحفوظُ يُقرأ لدرسه ونصّه وحدهما", () => {
  const quiz = parseTracingQuiz({ questions: Array.from({ length: 6 }, (_, i) => question(i)) }, owner);
  assert.ok(readTracingQuiz(quiz, owner));
  assert.equal(readTracingQuiz(quiz, { ...owner, lessonStamp: "edited" }), null);
  assert.equal(readTracingQuiz(quiz, { ...owner, lessonId: "L2" }), null);
  assert.equal(readTracingQuiz({ ...quiz, version: 0 }, owner), null);
});

test("مخطّطُ النموذج يطلب السؤال وخياراته وإجابته", () => {
  const props = TRACING_QUIZ_SCHEMA.properties.questions.items;
  assert.deepEqual(props.required, ["question", "options", "answer"]);
});

test("لعبةُ الأسئلة: عنوانُها «أجب وتتبّع» ومكافأتُها بعد آخر سؤال", () => {
  const quiz = parseTracingQuiz({ questions: Array.from({ length: 7 }, (_, i) => question(i)) }, owner);
  const game = tracing.tracingGame(quiz.items);
  assert.equal(game.title, "أجب وتتبّع!");
  assert.equal(game.items.reward_after, 7);
});

test("مكافأتُها تُطلب بمعرّفها، والنموذجُ لا يعرفها", () => {
  assert.deepEqual(parseStudyGameActivityId("lesson-1::tracing"), { lessonId: "lesson-1", gameId: "tracing" });
  assert.ok(!GAME_TYPES.includes("tracing"));
  const schemaTypes = STUDY_GAMES_SCHEMA.properties.games.items.properties.game_type.enum;
  assert.ok(!schemaTypes.includes("tracing"));
});
