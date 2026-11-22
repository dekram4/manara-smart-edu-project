/**
 * أسئلةُ «تحدَّ زملاءك» للروضة: مئةُ سؤالٍ مسموع، وحزمةٌ ثابتةٌ لكل مباراة.
 *
 * التشغيل:
 *   node ./build.mjs && node --test src/lib/__tests__/kgDuelBank.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";

let mod;
let tracing;
try {
  mod = await import("../../../dist/lib/kgDuelBank.mjs");
  tracing = await import("../../../dist/lib/tracing.mjs");
} catch {
  mod = null;
}

const skip = mod ? false : "شغّل node ./build.mjs أولاً";

test("مئةُ سؤال، بمعرّفاتٍ kg_001…kg_100 مختلفة", { skip }, () => {
  assert.equal(mod.KG_QUESTIONS.length, 100);
  const ids = new Set(mod.KG_QUESTIONS.map((q) => q.id));
  assert.equal(ids.size, 100);
  assert.equal(mod.KG_QUESTIONS[0].id, "kg_001");
  assert.equal(mod.KG_QUESTIONS[99].id, "kg_100");
  assert.equal(mod.KG_QUESTIONS[0].answer, "القطة");
});

test("الحزمةُ نفسُها للمباراة نفسِها، وتختلف بين مباراتين", { skip }, () => {
  const a = mod.kgPackFor("duel_abc");
  const b = mod.kgPackFor("duel_abc");
  assert.deepEqual(a, b);
  const c = mod.kgPackFor("duel_xyz");
  assert.notDeepEqual(a.questions.map((q) => q.id), c.questions.map((q) => q.id));
});

test("عشرةُ أسئلةٍ مختلفة، والجوابُ بين الخيارات بلا تكرار", { skip }, () => {
  for (const id of ["m1", "m2", "duel_1", "duel_2", "x"]) {
    const pack = mod.kgPackFor(id);
    assert.equal(pack.version, 1);
    assert.equal(pack.questions.length, 10);
    assert.equal(new Set(pack.questions.map((q) => q.id)).size, 10);
    for (const q of pack.questions) {
      const source = mod.KG_QUESTIONS.find((k) => k.id === q.id);
      assert.ok(source, q.id);
      assert.equal(q.prompt, source.prompt);
      assert.equal(q.options[q.answerAt], source.answer);
      assert.equal(new Set(q.options).size, q.options.length, `${q.id}: خياراتٌ مكرّرة`);
      assert.ok(q.options.length === 2 || q.options.length === 4, `${q.id}: ${q.options.length}`);
    }
  }
});

test("سؤالُ نعم/لا خياراه نعم ولا وحدهما", { skip }, () => {
  for (let i = 0; i < 60; i++) {
    for (const q of mod.kgPackFor(`yn_${i}`).questions) {
      const source = mod.KG_QUESTIONS.find((k) => k.id === q.id);
      if (source.answer === "نعم" || source.answer === "لا") {
        assert.deepEqual([...q.options].sort(), ["لا", "نعم"]);
      }
    }
  }
});

test("صفُّ الروضة يُعرف بأيّ كتابة، والرابعُ ليس روضة", { skip }, () => {
  assert.equal(tracing.isKindergartenGrade("روضة منارة المعرفة"), true);
  assert.equal(tracing.isKindergartenGrade("الصف الرابع الابتدائي"), false);
});
