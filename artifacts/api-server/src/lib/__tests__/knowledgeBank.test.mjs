/**
 * أبوابُ المعرفة العامّة في «تحدَّ زملاءكَ»، وذاكرةُ «حل المسائل» الدائمة.
 *
 * التشغيل:
 *   node ./build.mjs && node --test src/lib/__tests__/knowledgeBank.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../../..");

let bank;
let questions;
try {
  bank = await import("../../../dist/lib/knowledgeBank.mjs");
  questions = await import("../../../dist/lib/duelQuestions.mjs");
} catch (error) {
  throw new Error(`شغّل node ./build.mjs أولاً. (${error?.message ?? error})`);
}
const { renderKnowledgeSql, OUTPUT } = await import("../../../scripts/duel-knowledge-sql.mjs");

const { KNOWLEDGE_SEEDS, KNOWLEDGE_CATEGORIES, knowledgeId, isKnowledgeCategory } = bank;
const { buildDuelPack, parseDuelPack } = questions;

test("خمسةُ أبواب، ولكلٍّ منها بنكٌ يكفي جولاتٍ كثيرة", () => {
  assert.deepEqual([...KNOWLEDGE_CATEGORIES], ["culture", "sports", "geography", "history", "science"]);
  for (const category of KNOWLEDGE_CATEGORIES) {
    const count = KNOWLEDGE_SEEDS.filter((seed) => seed.category === category).length;
    assert.ok(count >= 25, `${category}: ${count}`);
  }
});

test("كلُّ سؤالٍ صالح: نصٌّ قصير، وأربعةُ خياراتٍ مختلفة، والجوابُ أحدُها", () => {
  for (const seed of KNOWLEDGE_SEEDS) {
    assert.ok(isKnowledgeCategory(seed.category), seed.prompt);
    const prompt = seed.prompt.trim();
    assert.ok(prompt.length >= 4 && prompt.length <= 220, prompt);
    assert.equal(seed.choices.length, 4, prompt);
    assert.equal(new Set(seed.choices.map((c) => c.trim())).size, 4, `خياران متطابقان: ${prompt}`);
    for (const choice of seed.choices) assert.ok(choice.trim(), prompt);
    assert.ok(!prompt.includes("'") && !seed.choices.some((c) => c.includes("'")), prompt);
  }
});

test("لا تكرار: لا سؤالان بنصٍّ واحد ولا بمعرّفٍ واحد، ولا تكرارَ لما في البنك الأوّل", async () => {
  const ids = KNOWLEDGE_SEEDS.map(knowledgeId);
  assert.equal(new Set(ids).size, ids.length);
  const prompts = KNOWLEDGE_SEEDS.map((seed) => seed.prompt.trim());
  assert.equal(new Set(prompts).size, prompts.length);

  const first = await readFile(path.resolve(root, "scripts/duel-question-bank.sql"), "utf8");
  for (const [index, prompt] of prompts.entries()) {
    assert.ok(!first.includes(`'${prompt}'`), `مكرّرٌ في البنك الأوّل: ${prompt}`);
    assert.ok(!first.includes(`'${ids[index]}'`), `معرّفٌ مكرّر: ${ids[index]}`);
  }
});

test("ملفُّ SQL مولَّدٌ من البنك نفسه، لم يفترق عنه", async () => {
  const onDisk = (await readFile(OUTPUT, "utf8")).replace(/\r\n/g, "\n");
  assert.equal(onDisk, renderKnowledgeSql(KNOWLEDGE_SEEDS, knowledgeId));
  // وفيه الأبوابُ الجديدة في القيد، وتوزيعُ الحزمة الجديد.
  for (const category of KNOWLEDGE_CATEGORIES) assert.ok(onDisk.includes(`'${category}'`));
  assert.match(onDisk, /v_pattern constant text := 'DKBDKDKBDK'/);
  assert.match(onDisk, /on conflict do nothing;/);
});

test("الحزمةُ تخلط أبوابَ المعرفة بلا تكرارٍ داخلها، وتبقى صالحةً للقراءة", () => {
  const seen = new Set();
  for (let i = 0; i < 60; i += 1) {
    const pack = buildDuelPack(`duel_knowledge_${i}`);
    const ids = pack.questions.map((q) => q.id);
    assert.equal(new Set(ids).size, ids.length, "سؤالٌ مكرّرٌ في المباراة");
    for (const question of pack.questions) {
      assert.equal(question.options[question.answerAt] !== undefined, true);
      if (isKnowledgeCategory(question.category)) seen.add(question.category);
    }
    const parsed = parseDuelPack(JSON.parse(JSON.stringify(pack)));
    assert.ok(parsed, "حزمةٌ لا تُقرأ");
    // البابُ يبقى كما هو بعد القراءة، لا يُردّ إلى «عامّة».
    assert.deepEqual(
      parsed.questions.map((q) => q.category),
      pack.questions.map((q) => q.category),
    );
  }
  assert.deepEqual([...seen].sort(), [...KNOWLEDGE_CATEGORIES].sort(), "بابٌ لم يظهر قطّ");
});

test("الجوابُ الصحيح في الحزمة هو الخيارُ الأوّل في البنك", () => {
  const byId = new Map(KNOWLEDGE_SEEDS.map((seed) => [knowledgeId(seed), seed]));
  for (let i = 0; i < 30; i += 1) {
    for (const question of buildDuelPack(`duel_answer_${i}`).questions) {
      const seed = byId.get(question.id);
      if (!seed) continue;
      assert.equal(question.options[question.answerAt], seed.choices[0]);
    }
  }
});

test("ذاكرةُ حل المسائل دائمة: لا حذفَ في الخادم، والقاعدةُ ترفضه", async () => {
  const gemini = await readFile(path.resolve(root, "src/routes/gemini.ts"), "utf8");
  // كلُّ نداءٍ للجدول قراءةٌ أو كتابةٌ بالدمج — لا DELETE ولا مدّةَ صلاحية.
  const calls = gemini.match(/ai_qa_cache[^`]*`[\s\S]{0,200}?method:\s*"(\w+)"/g) ?? [];
  for (const call of calls) assert.doesNotMatch(call, /method:\s*"DELETE"/);
  assert.doesNotMatch(gemini, /ai_qa_cache[^\n]*(delete|expires|ttl)/i);
  assert.match(gemini, /resolution=merge-duplicates/);

  const guard = await readFile(path.resolve(root, "scripts/solved-questions-cache.sql"), "utf8");
  assert.match(guard, /before delete on public\.ai_qa_cache/);
  assert.match(guard, /before truncate on public\.ai_qa_cache/);
  assert.match(guard, /create or replace view public\.solved_questions_cache/);
  assert.match(guard, /revoke all on public\.solved_questions_cache from public, anon, authenticated/);
});
