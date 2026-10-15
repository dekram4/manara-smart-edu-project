/**
 * يُكمل متّجهاتِ المعنى لصفوف ai_qa_cache التي حُفظت بلا متّجه.
 *
 * ── لماذا ──
 * نموذجُ المتّجهات القديم (text-embedding-004) أُوقف فكان يردّ ٤٠٤، فحُفظت
 * الإجاباتُ كلُّها بلا متّجه: تُصاب حرفياً وبالكلمات، ولا تُصاب بالمعنى أبداً.
 * وهذا يحسب لكلٍّ متّجهَه بالنموذج الحالي وبالتطبيع نفسه الذي يبحث به الخادم.
 *
 * ── وما لا يمسّه ──
 * الرفضُ المحفوظ (يُستبدل حين يُسأل ثانيةً)، والصورُ المحفوظة ببصمتها (لا نصَّ
 * لها يُقاس)، والصفُّ التجريبي. ويكتب عمودَ المتّجه وحده.
 *
 * التشغيل (بمتغيّرات الخادم، بلا طباعة سرّ):
 *   node ./build.mjs && railway run node ./scripts/backfill-cache-embeddings.mjs
 */

const { embedQuestion } = await import(new URL("../dist/lib/embeddings.mjs", import.meta.url).href);
const { normalizeQuestion } = await import(new URL("../dist/lib/aiQuota.mjs", import.meta.url).href);
const { isRefusalAnswer } = await import(new URL("../dist/lib/solverPolicy.mjs", import.meta.url).href);

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key || !process.env.GEMINI_API_KEY) {
  console.error("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY / GEMINI_API_KEY مطلوبة");
  process.exit(1);
}
const headers = { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" };

const response = await fetch(`${url}/rest/v1/ai_qa_cache?select=id,data&embedding=is.null&limit=1000`, { headers });
if (!response.ok) {
  console.error("read failed", response.status, (await response.text()).slice(0, 200));
  process.exit(1);
}
const rows = await response.json();
let filled = 0;
let skipped = 0;
let failed = 0;
for (const row of rows) {
  const question = String(row.data?.question ?? "").trim();
  if (
    !question ||
    row.data?.lessonId === "__selftest__" ||
    question.startsWith("[صورة]") ||
    isRefusalAnswer(row.data?.answer)
  ) {
    skipped += 1;
    continue;
  }
  const vector = await embedQuestion(normalizeQuestion(question));
  if (!vector) {
    failed += 1;
    continue;
  }
  const patch = await fetch(`${url}/rest/v1/ai_qa_cache?id=eq.${encodeURIComponent(row.id)}`, {
    method: "PATCH",
    headers: { ...headers, Prefer: "return=minimal" },
    body: JSON.stringify({ embedding: vector }),
  });
  if (patch.ok) filled += 1;
  else {
    failed += 1;
    console.error("write failed", patch.status, (await patch.text()).slice(0, 160));
  }
}
console.log(JSON.stringify({ withoutVector: rows.length, filled, skipped, failed }));
