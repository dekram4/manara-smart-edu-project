/**
 * يجمع ما يُطبَّق على Supabase في ملفٍّ واحدٍ يُلصق مرّةً في محرّر SQL:
 *   ١. security-lockdown.sql   — إغلاقُ المفتاح العام، وحذفُ match_qa_cache المعطوبة.
 *   ٢. ai-qa-cache-vectors.sql — match_qa_cache بالتوقيع الذي يناديه الخادم.
 *   ٣. duel-knowledge-bank.sql — أبوابُ المعرفة العامّة الخمسة (١٤٦ سؤالاً).
 *
 * الملفُّ الناتج مولَّد: يُعدَّل كلٌّ من الثلاثة في مكانه ثم يُعاد هذا.
 * واختبارُ securityLockdown.test.mjs يتحقّق أنه لم يفترق عنها.
 *
 * التشغيل: node ./scripts/build-apply-sql.mjs
 */
import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
export const PARTS = ["security-lockdown.sql", "ai-qa-cache-vectors.sql", "duel-knowledge-bank.sql"];
export const OUTPUT = path.resolve(here, "apply-supabase.sql");

/**
 * ختامُ الملفّ: تحديثُ ذاكرة مخطّط PostgREST (فتظهر الدالّةُ الجديدة للخادم
 * فوراً)، ثم صفُّ تحقّقٍ يظهر في المحرّر — فالنجاحُ يُرى أرقاماً لا «Success»
 * وحدها، ويُعرف إن شُغّل جزءٌ من الملفّ دون الباقي.
 */
const VERIFY = `-- ┌──────────────────────────────────────────────────────────────
-- │ التحقّق
-- └──────────────────────────────────────────────────────────────

notify pgrst, 'reload schema';

select
  (select count(*) from public.duel_questions
     where category in ('culture', 'sports', 'geography', 'history', 'science'))
    as knowledge_questions_expected_146,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'match_qa_cache'
       and pg_get_function_identity_arguments(p.oid) like 'query_embedding vector%')
    as match_qa_cache_expected_1,
  (select count(*) from information_schema.role_table_grants
     where table_schema = 'public' and grantee in ('anon', 'authenticated')
       and privilege_type <> 'SELECT')
    as anon_write_grants_expected_0,
  (select string_agg(distinct table_name, ', ' order by table_name)
     from information_schema.role_table_grants
     where table_schema = 'public' and grantee = 'anon' and privilege_type = 'SELECT')
    as anon_readable_expected_app_kv_created_quizzes_lesson_configs;
`;

export async function renderApplySql() {
  const sections = [];
  for (const name of PARTS) {
    const body = (await readFile(path.resolve(here, name), "utf8")).replace(/\r\n/g, "\n").trimEnd();
    sections.push(`-- ┌──────────────────────────────────────────────────────────────\n-- │ ${name}\n-- └──────────────────────────────────────────────────────────────\n\n${body}\n`);
  }
  return `-- مولَّدٌ بـ scripts/build-apply-sql.mjs — لا يُعدَّل باليد.\n-- يُلصق كاملاً في محرّر SQL في Supabase ويُشغَّل مرّةً واحدة؛ ويُعاد تشغيله بأمان.\n-- ‏قبل اللصق: محرّرٌ فارغ، ولا تحديدَ لجزءٍ من النصّ (المحرّر يشغّل المحدَّد وحده).\n\n${sections.join("\n")}\n${VERIFY}`;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  await writeFile(OUTPUT, await renderApplySql(), "utf8");
  console.log(`wrote ${OUTPUT}`);
}
