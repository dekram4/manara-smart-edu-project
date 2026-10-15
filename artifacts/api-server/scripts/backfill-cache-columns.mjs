/**
 * يملأ الأعمدةَ المقروءة (question_text و answer_json و question_hash و domain)
 * لصفوف ai_qa_cache التي حُفظت قبل أن يكتبها الخادم.
 *
 * ── لماذا ──
 * أُضيفت هذه الأعمدة إلى الجدول في الإنتاج، وعليها يقوم عرضُ
 * solved_questions_cache. والخادمُ كان يكتب السؤالَ والإجابة في `data` وحده،
 * فبدا كلُّ صفٍّ محفوظٍ في العرض فارغاً. وهذا ينقلها من `data` بالدالّة نفسها
 * التي يكتب بها الخادمُ الآن (`cacheReadableColumns`).
 *
 * التشغيل (بمتغيّرات الخادم، بلا طباعة سرّ):
 *   node ./build.mjs && railway run node ./scripts/backfill-cache-columns.mjs
 */

const { cacheReadableColumns } = await import(new URL("../dist/lib/solverPolicy.mjs", import.meta.url).href);

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) {
  console.error("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY مطلوبة");
  process.exit(1);
}
const headers = { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" };

const response = await fetch(`${url}/rest/v1/ai_qa_cache?select=id,data&question_text=is.null&limit=1000`, { headers });
if (!response.ok) {
  console.error("read failed", response.status, (await response.text()).slice(0, 200));
  process.exit(1);
}
const rows = await response.json();
const subjects = new Map();
async function subjectOf(lessonId) {
  if (!lessonId) return "";
  if (!subjects.has(lessonId)) {
    const lesson = await fetch(`${url}/rest/v1/lesson_configs?select=data&id=eq.${encodeURIComponent(lessonId)}`, { headers });
    const [row] = lesson.ok ? await lesson.json() : [];
    subjects.set(lessonId, String(row?.data?.subject ?? ""));
  }
  return subjects.get(lessonId);
}

let filled = 0;
let failed = 0;
for (const row of rows) {
  const data = row.data ?? {};
  const columns = cacheReadableColumns(
    row.id,
    String(data.lessonId ?? ""),
    String(data.question ?? ""),
    String(data.answer ?? ""),
    await subjectOf(data.lessonId),
  );
  const patch = await fetch(`${url}/rest/v1/ai_qa_cache?id=eq.${encodeURIComponent(row.id)}`, {
    method: "PATCH",
    headers: { ...headers, Prefer: "return=minimal" },
    body: JSON.stringify(columns),
  });
  if (patch.ok) filled += 1;
  else {
    failed += 1;
    console.error("write failed", patch.status, (await patch.text()).slice(0, 160));
  }
}
console.log(JSON.stringify({ empty: rows.length, filled, failed }));
