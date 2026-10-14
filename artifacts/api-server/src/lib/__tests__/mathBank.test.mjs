/**
 * بنكُ الأعداد المولَّد: الجوابُ صحيحٌ في كل باب، والخياراتُ مختلفة،
 * ولا يتكرّر السؤالُ بين المباريات.
 *
 * التشغيل:
 *   npm run build && node --test src/lib/__tests__/mathBank.test.mjs
 */
import test from "node:test";
import assert from "node:assert/strict";

const bank = await import(process.env.MATH_MODULE ?? "../../../dist/lib/mathBank.mjs");
const duel = await import(process.env.DUEL_MODULE ?? "../../../dist/lib/duelQuestions.mjs");

function rng(seed) {
  let s = seed;
  return () => {
    s = (s * 16807) % 2147483647;
    return (s - 1) / 2147483646;
  };
}

const western = (text) => text.replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660));
const numbersIn = (prompt) => (western(prompt).match(/\d+/g) ?? []).map(Number);

test("كلُّ باب: خياراتٌ مختلفة، والجوابُ أوّلُها، ولا أعدادَ سالبة", () => {
  for (const section of bank.MATH_SECTIONS) {
    const next = rng(11 + section.length);
    for (let i = 0; i < 300; i++) {
      const q = bank.generateMathQuestion(section, next);
      assert.ok(q.choices.length >= 3, `${section}: ${q.prompt}`);
      assert.equal(new Set(q.choices).size, q.choices.length, `${section}: ${q.choices}`);
      for (const c of q.choices) assert.ok(!/^-/.test(c), `${section}: ${c}`);
    }
  }
});

test("الحسابُ صحيح: الجمعُ والطرحُ والضربُ والقسمة", () => {
  const next = rng(99);
  const ops = {
    addition: ([a, b]) => a + b,
    subtraction: ([a, b]) => a - b,
    multiplication: ([a, b]) => a * b,
    division: ([a, b]) => a / b,
  };
  for (const [section, op] of Object.entries(ops)) {
    for (let i = 0; i < 200; i++) {
      const q = bank.generateMathQuestion(section, next);
      assert.equal(Number(q.choices[0]), op(numbersIn(q.prompt)), q.prompt);
    }
  }
});

test("قيمةُ الرقم والتقريبُ والأنماطُ صحيحة", () => {
  const next = rng(7);
  for (let i = 0; i < 300; i++) {
    const q = bank.generateMathQuestion("placeValue", next);
    if (q.prompt.startsWith("ما قيمةُ")) {
      const [digit, number] = numbersIn(q.prompt);
      const s = String(number);
      const place = s.length - 1 - s.indexOf(String(digit));
      assert.equal(Number(q.choices[0]), digit * 10 ** place, q.prompt);
    }
    const r = bank.generateMathQuestion("rounding", next);
    const [value] = numbersIn(r.prompt);
    const unit = r.prompt.includes("عشرة") ? 10 : 100;
    assert.equal(Number(r.choices[0]), Math.round(value / unit) * unit, r.prompt);
    const p = bank.generateMathQuestion("patterns", next);
    const seq = numbersIn(p.prompt);
    assert.equal(Number(p.choices[0]), seq[3] + (seq[1] - seq[0]), p.prompt);
  }
});

test("مقارنةُ الإشارات: جوابٌ واحدٌ صحيح لا اثنان", () => {
  const next = rng(5);
  for (let i = 0; i < 300; i++) {
    const q = bank.generateMathQuestion("compare", next);
    if (!q.prompt.startsWith("اختر")) continue;
    const [a, b] = numbersIn(q.prompt);
    const truth = a > b ? ">" : a < b ? "<" : "=";
    assert.equal(q.choices[0], truth);
    assert.ok(!q.choices.includes("≠"));
  }
});

test("الحزمة: فيها بابُ الأعداد، وتختلف بين المباريات", () => {
  const packs = Array.from({ length: 40 }, (_, i) => duel.buildDuelPack(`match-${i}`));
  for (const pack of packs) {
    assert.ok(pack.questions.some((q) => q.category === "numbers"));
    assert.equal(new Set(pack.questions.map((q) => q.id)).size, pack.questions.length);
  }
  const numberPrompts = packs.flatMap((p) => p.questions.filter((q) => q.category === "numbers").map((q) => q.prompt));
  // عشرات الأسئلة المولّدة عبر أربعين مباراة، وشبهُ كلّها مختلف.
  assert.ok(new Set(numberPrompts).size >= numberPrompts.length * 0.9);
  // والبناءُ بالمعرّف نفسه يُخرج الحزمةَ نفسها — شرطُ إعادة البناء الآمنة.
  assert.deepEqual(
    duel.buildDuelPack("same", [], 10, new Date(0)),
    duel.buildDuelPack("same", [], 10, new Date(0)),
  );
});
