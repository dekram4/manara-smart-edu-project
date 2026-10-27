/**
 * اختبارات لعبة «تسميع القرآن الكريم» — حصراً لدرس «حفظ وشرح السور القصيرة» في الروضة.
 *
 * التشغيل:
 *   npm run build && node --test src/lib/__tests__/quranRecitation.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";

const quran = await import(process.env.QURAN_MODULE ?? "../../../dist/lib/quranRecitation.mjs");
const studyGames = await import(process.env.STUDY_GAMES_MODULE ?? "../../../dist/lib/studyGames.mjs");

const { quranRecitationAllowed, quranRewardKey, QURAN_SURAHS, QURAN_REWARD } = quran;
const { parseStudyGameActivityId } = studyGames;

const lesson = {
  id: "L1",
  grade: "روضة منارة المعرفة",
  subject: "القرآن الكريم",
  lesson: "حفظ وشرح السور القصيرة",
};

test("الصفُّ والمادّةُ والدرسُ معاً — بأيّ همزةٍ وتاءٍ كُتبت", () => {
  assert.ok(quranRecitationAllowed(lesson));
  assert.ok(quranRecitationAllowed({ ...lesson, subject: "القران الكريم", lesson: "درس: حفظ وشرح السور القصيره" }));
  assert.ok(!quranRecitationAllowed({ ...lesson, grade: "الصف الأول" }));
  assert.ok(!quranRecitationAllowed({ ...lesson, subject: "الحروف العربية" }));
  assert.ok(!quranRecitationAllowed({ ...lesson, lesson: "سورة الفيل" }));
  assert.ok(!quranRecitationAllowed({}));
});

test("مفتاحُ المكافأة لكل سورةٍ من الثماني، ولا لغيرها", () => {
  assert.equal(QURAN_SURAHS.length, 8);
  assert.equal(quranRewardKey(lesson, "ikhlas"), "quran:L1:ikhlas");
  assert.notEqual(quranRewardKey(lesson, "nas"), quranRewardKey(lesson, "falaq"));
  assert.equal(quranRewardKey(lesson, "baqara"), null);
  assert.equal(quranRewardKey(lesson, ""), null);
  assert.equal(quranRewardKey({ ...lesson, grade: "الصف الثاني" }, "ikhlas"), null);
  assert.ok(QURAN_REWARD.gems > 0 && QURAN_REWARD.points > 0);
});

test("معرّفُ النشاط «درس::quran» يُقبل للمكافأة", () => {
  assert.deepEqual(parseStudyGameActivityId("L1::quran"), { lessonId: "L1", gameId: "quran" });
});
