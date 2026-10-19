/**
 * اختبارات ألعاب بطاقة المذاكرة التفاعلية.
 *
 * التشغيل:
 *   npm run build && node --test src/lib/__tests__/studyGames.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";

const target = process.env.STUDY_GAMES_MODULE ?? "../../../dist/lib/studyGames.mjs";
let mod;
try {
  mod = await import(target);
} catch (error) {
  throw new Error(`تعذّر استيراد ${target} — شغّل npm run build أولاً. (${error?.message ?? error})`);
}

const {
  GAME_TYPES,
  REWARD_LIMITS,
  STUDY_GAMES_SCHEMA,
  STUDY_GAMES_SYSTEM_INSTRUCTION,
  parseStudyGameActivityId,
  parseStudyGames,
  readStudyGames,
  rewardOf,
  studyGameActivityId,
  studyGamesPrompt,
} = mod;

const owner = { lessonId: "L1", lessonStamp: "s1" };

const dragDrop = {
  game_type: "drag_drop",
  title: "صنّف الكائنات!",
  instructions: "اسحب كل كائن إلى مجموعته.",
  items: {
    drag_items: ["القط", "النخلة", "الأسد", "الوردة", "العصفور", "القمح"],
    drop_targets: ["حيوان", "نبات"],
    correct_pairs: [
      { item: "القط", target: "حيوان" },
      { item: "النخلة", target: "نبات" },
      { item: "الأسد", target: "حيوان" },
      { item: "الوردة", target: "نبات" },
      { item: "العصفور", target: "حيوان" },
      { item: "القمح", target: "نبات" },
    ],
  },
  gems_reward: 8,
  points_reward: 30,
};

const matching = {
  game_type: "matching",
  title: "صِل!",
  instructions: "صل كل كلمة بمعناها.",
  items: {
    drag_items: ["الجذر", "الساق", "الورقة"],
    drop_targets: ["يمتص الماء", "يحمل النبات", "تصنع الغذاء"],
    correct_pairs: [
      { item: "الجذر", target: "يمتص الماء" },
      { item: "الساق", target: "يحمل النبات" },
      { item: "الورقة", target: "تصنع الغذاء" },
    ],
  },
  gems_reward: 99,
  points_reward: 1,
};

const quiz = {
  game_type: "endless_quiz",
  title: "سباق!",
  instructions: "أجب بسرعة.",
  items: {
    drag_items: [],
    drop_targets: [],
    correct_pairs: [],
    questions: [
      ...Array.from({ length: 8 }, (_, i) => ({
        kind: "mcq",
        question: `أي جزء من النبات يمتص الماء؟ ${i}`,
        options: [`الجذر ${i}`, `الزهرة ${i}`, `الثمرة ${i}`, `الورقة ${i}`],
        answer: `الجذر ${i}`,
      })),
      ...Array.from({ length: 4 }, (_, i) => ({
        kind: "true_false",
        question: `الجذر يمتص الماء من التربة (${i})`,
        options: ["صح", "خطأ"],
        answer: "صح",
      })),
      ...Array.from({ length: 4 }, (_, i) => ({
        kind: "fill_blank",
        question: `تصنع ____ الغذاء للنبات (${i})`,
        options: [`الورقة ${i}`, `الساق ${i}`, `الجذر ${i}`],
        answer: `الورقة ${i}`,
      })),
    ],
  },
  gems_reward: 6,
  points_reward: 25,
};

test("التوجيهُ والمخطّط: الأنواعُ الثلاثة وحقولُ الصيغة المطلوبة", () => {
  assert.deepEqual([...GAME_TYPES], ["drag_drop", "matching", "endless_quiz"]);
  const game = STUDY_GAMES_SCHEMA.properties.games.items;
  assert.deepEqual(game.required, ["game_type", "title", "instructions", "items", "gems_reward", "points_reward"]);
  assert.deepEqual(game.properties.items.required, ["drag_items", "drop_targets", "correct_pairs"]);
  for (const word of ["drag_drop", "matching", "endless_quiz", "JSON فقط"]) {
    assert.ok(STUDY_GAMES_SYSTEM_INSTRUCTION.includes(word), word);
  }
  assert.ok(studyGamesPrompt({ lessonTitle: "النبات", lessonText: "نص الدرس", subject: "العلوم" }).includes("نص الدرس"));
});

test("الألعابُ الثلاث تُقرأ، والمكافآت تُحصر في حدودها", () => {
  const pack = parseStudyGames(JSON.stringify({ games: [quiz, matching, dragDrop] }), owner, "t");
  assert.equal(pack.lessonId, "L1");
  assert.deepEqual(pack.games.map((g) => g.id), ["drag_drop", "matching", "endless_quiz"]);
  const [dd, mt, eq] = pack.games;
  assert.equal(dd.items.drop_targets.length, 2);
  assert.equal(dd.items.correct_pairs.length, 6);
  assert.equal(mt.gems_reward, REWARD_LIMITS.gems.max);
  assert.equal(mt.points_reward, REWARD_LIMITS.points.min);
  assert.equal(eq.items.questions.length, 16);
  assert.deepEqual(
    [...new Set(eq.items.questions.map((q) => q.kind))].sort(),
    ["fill_blank", "mcq", "true_false"],
  );
  assert.equal(eq.gems_reward, 6);
});

test("ما لا يصلح يسقط: بطاقةٌ بلا سلّة، معنىً لمفهومين، سؤالٌ جوابُه ليس من خياراته", () => {
  const broken = {
    games: [
      { ...dragDrop, items: { ...dragDrop.items, correct_pairs: dragDrop.items.correct_pairs.slice(0, 3) } },
      {
        ...matching,
        items: {
          ...matching.items,
          correct_pairs: [
            { item: "الجذر", target: "يمتص الماء" },
            { item: "الساق", target: "يمتص الماء" },
            { item: "الورقة", target: "تصنع الغذاء" },
          ],
        },
      },
      { ...quiz, items: { ...quiz.items, questions: quiz.items.questions.map((q) => ({ ...q, answer: "غيره" })) } },
    ],
  };
  assert.equal(parseStudyGames(broken, owner), null);
  assert.equal(parseStudyGames("ليس JSON", owner), null);
});

test("المحفوظ يُقرأ لدرسه ولنصّه الحالي وحدهما", () => {
  const pack = parseStudyGames({ games: [dragDrop] }, owner);
  assert.ok(readStudyGames(pack, owner));
  assert.equal(readStudyGames(pack, { ...owner, lessonStamp: "s2" }), null);
  assert.equal(readStudyGames(pack, { ...owner, lessonId: "L2" }), null);
});

test("معرّفُ النشاط والمكافأة من السجلّ", () => {
  const id = studyGameActivityId("lesson-7", "matching");
  assert.deepEqual(parseStudyGameActivityId(id), { lessonId: "lesson-7", gameId: "matching" });
  assert.equal(parseStudyGameActivityId("lesson-7::hack"), null);
  assert.equal(parseStudyGameActivityId("lesson-7"), null);
  const pack = parseStudyGames({ games: [dragDrop, matching] }, owner);
  assert.deepEqual(rewardOf(pack, "drag_drop"), { gems: 8, points: 30 });
  assert.equal(rewardOf(pack, "endless_quiz"), null);
  // سجلٌّ عُدّل يدوياً لا يتجاوز الحدّ.
  const tampered = { games: [{ id: "drag_drop", gems_reward: 10_000, points_reward: 10_000 }] };
  assert.deepEqual(rewardOf(tampered, "drag_drop"), { gems: REWARD_LIMITS.gems.max, points: REWARD_LIMITS.points.max });
});

test("السباق: كلُّ شكلٍ بخياراته — صح/خطأ اثنان، وأكمل الفراغ فيه فراغ", () => {
  const bad = {
    ...quiz,
    items: {
      ...quiz.items,
      questions: [
        ...quiz.items.questions,
        { kind: "true_false", question: "عبارة بخيارات ثلاثة", options: ["صح", "خطأ", "ربما"], answer: "صح" },
        { kind: "fill_blank", question: "جملة بلا فراغ أصلاً", options: ["أ", "ب", "ج"], answer: "أ" },
      ],
    },
  };
  const pack = parseStudyGames({ games: [bad] }, owner);
  assert.equal(pack.games[0].items.questions.length, 16);
});
