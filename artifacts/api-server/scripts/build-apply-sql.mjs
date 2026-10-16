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

export async function renderApplySql() {
  const sections = [];
  for (const name of PARTS) {
    const body = (await readFile(path.resolve(here, name), "utf8")).replace(/\r\n/g, "\n").trimEnd();
    sections.push(`-- ┌──────────────────────────────────────────────────────────────\n-- │ ${name}\n-- └──────────────────────────────────────────────────────────────\n\n${body}\n`);
  }
  return `-- مولَّدٌ بـ scripts/build-apply-sql.mjs — لا يُعدَّل باليد.\n-- يُلصق كاملاً في محرّر SQL في Supabase ويُشغَّل مرّةً واحدة؛ ويُعاد تشغيله بأمان.\n\n${sections.join("\n")}`;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  await writeFile(OUTPUT, await renderApplySql(), "utf8");
  console.log(`wrote ${OUTPUT}`);
}
