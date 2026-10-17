/**
 * يُدرج أسئلة المعرفة العامة (١٤٦، خمسة أبواب) في duel_questions بمفتاح الخدمة،
 * بالمعرّفات نفسها التي في duel-knowledge-bank.sql — فلا تتكرّر إن طُبّق ذاك أيضاً.
 *
 * يُشغَّل بعد apply-supabase-schema.sql (قيدُ الأبواب الجديدة شرطٌ له).
 *   node ./build.mjs && railway run node ./scripts/seed-knowledge-questions.mjs
 */
const { KNOWLEDGE_SEEDS, knowledgeId } = await import(new URL("../dist/lib/knowledgeBank.mjs", import.meta.url).href);
const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) {
  console.error("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY مطلوبة");
  process.exit(1);
}
const rows = KNOWLEDGE_SEEDS.map((seed) => ({
  id: knowledgeId(seed),
  subject_key: "*",
  category: seed.category,
  prompt: seed.prompt,
  choices: seed.choices,
}));
const response = await fetch(`${url}/rest/v1/duel_questions?on_conflict=id`, {
  method: "POST",
  headers: {
    apikey: key,
    Authorization: `Bearer ${key}`,
    "Content-Type": "application/json",
    Prefer: "resolution=ignore-duplicates,return=minimal",
  },
  body: JSON.stringify(rows),
});
console.log(response.ok ? `inserted or kept ${rows.length} questions` : `failed ${response.status} ${(await response.text()).slice(0, 300)}`);
if (!response.ok) process.exitCode = 1;
