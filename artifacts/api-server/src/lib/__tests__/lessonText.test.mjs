/**
 * نصُّ الدرس يصل Gemini كاملاً في كل مولّد: الاختبار، وألعاب المذاكرة وسباقها،
 * وحزمة المذاكرة، والتحدي.
 *
 * التشغيل:
 *   npm run build && node --test src/lib/__tests__/lessonText.test.mjs
 */
import test from "node:test";
import assert from "node:assert/strict";

const { LESSON_TEXT_SAFETY_LIMIT, fullLessonText } = await import("../../../dist/lib/lessonText.mjs");
const { quizPrompt } = await import("../../../dist/lib/quizGenerator.mjs");
const { studyGamesPrompt } = await import("../../../dist/lib/studyGames.mjs");
const { buildPrompt } = await import("../../../dist/lib/challengeQuestions.mjs");

// درسٌ طويل: ٤٠ ألف حرف، وجملةٌ مميّزة في آخره — كانت كلُّ المولّدات تقطع قبلها.
const tail = "الجملةُ الأخيرة في الدرس عن دورة الماء.";
const lesson = "النبات كائن حي يصنع غذاءه بنفسه. ".repeat(1500) + tail;

test("النصُّ يمرّ كاملاً، ولا يُقطع إلا فوق حدّ الأمان وعند نهاية جملة", () => {
  assert.ok(lesson.length > 40_000);
  assert.equal(fullLessonText(lesson), lesson.trim());
  assert.equal(fullLessonText("أ\r\n\r\n\r\n\r\nب"), "أ\n\nب");
  const huge = "جملة. ".repeat(LESSON_TEXT_SAFETY_LIMIT / 3);
  const cut = fullLessonText(huge);
  assert.ok(cut.length <= LESSON_TEXT_SAFETY_LIMIT);
  assert.ok(cut.endsWith("."));
});

test("كلُّ مولّدٍ يرسل آخرَ الدرس", () => {
  assert.ok(quizPrompt({ lessonContent: lesson, count: 30 }).includes(tail), "quiz");
  assert.ok(studyGamesPrompt({ lessonTitle: "النبات", lessonText: lesson }).includes(tail), "study games");
  assert.ok(buildPrompt({ subject: "العلوم", lessonText: lesson, count: 5 }).includes(tail), "challenge");
});
