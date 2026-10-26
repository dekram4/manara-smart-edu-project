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

const { tracingItemsFrom, buildTracingGame, withTracingGame, TRACING_REWARD, TRACING_MAX_ITEMS } = tracing;
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

test("تُضاف إلى الحزمة مرّةً واحدة", () => {
  const lesson = { title: "حرف التاء", text: "تفاحة وتمر" };
  const once = withTracingGame({ games: [] }, lesson);
  const twice = withTracingGame(once, lesson);
  assert.equal(twice.games.filter((game) => game.id === "tracing").length, 1);
});

test("مكافأتُها تُطلب بمعرّفها، والنموذجُ لا يعرفها", () => {
  assert.deepEqual(parseStudyGameActivityId("lesson-1::tracing"), { lessonId: "lesson-1", gameId: "tracing" });
  assert.ok(!GAME_TYPES.includes("tracing"));
  const schemaTypes = STUDY_GAMES_SCHEMA.properties.games.items.properties.game_type.enum;
  assert.ok(!schemaTypes.includes("tracing"));
});
