/**
 * «حل المسائل»: نطاقُ ما يُجاب عنه، والرفضُ لا يُعاد من الذاكرة ولا يُحفظ فيها،
 * وكلُّ إجابةٍ جديدة تُحفظ بمتّجهها.
 *
 * التشغيل:
 *   node ./build.mjs && node --test src/lib/__tests__/solverPolicy.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

let mod;
try {
  mod = await import("../../../dist/lib/solverPolicy.mjs");
} catch (error) {
  throw new Error(`شغّل node ./build.mjs أولاً. (${error?.message ?? error})`);
}
const { SOLVER_SCOPE_INSTRUCTION, isRefusalAnswer, imageKeyText } = mod;
const gemini = await readFile(new URL("../../routes/gemini.ts", import.meta.url), "utf8");

test("الرفضُ القديم يُعرف بأيّ صورةٍ كُتب", () => {
  // النصُّ كما حُفظ فعلاً في ai_qa_cache قبل توسيع النطاق.
  assert.ok(isRefusalAnswer("هذا السؤال ليس من ضمن الدرس ولا أستطيع الإجابة عليه"));
  assert.ok(isRefusalAnswer("هذا السُّؤال لَيس مِن ضِمن الدَّرس ولا أستطيع الإجابة عليه."));
  assert.ok(isRefusalAnswer("شوف يا بطل، هذا السؤال مو من ضمن الدرس."));
  assert.ok(isRefusalAnswer("  ما اقدر اجاوب على هذا السؤال"));
});

test("والإجابةُ الصحيحة لا تُعدّ رفضاً وإن ذكرت الدرس", () => {
  assert.equal(isRefusalAnswer("منزلة الرقم ٢ في العدد ٥٢٣٠ هي المئات، فقيمته ٢٠٠."), false);
  assert.equal(isRefusalAnswer("في العدد ١٠٠٠٠٠ خمسة أصفار."), false);
  const long = "١. نكتب العدد في جدول المنازل.\n".repeat(8) + "وهذا ليس من ضمن الدرس فقط بل مهارة عامة.";
  assert.equal(isRefusalAnswer(long), false, "الرفضُ جملةٌ تبدأ بها الإجابة، لا كلمةٌ في آخرها");
  assert.equal(isRefusalAnswer(""), false);
  assert.equal(isRefusalAnswer(null), false);
});

test("النطاقُ مهاراتُ المادة وموضوعُ الدرس، والرفضُ للخارج عن التعليم وحده", () => {
  assert.match(SOLVER_SCOPE_INSTRUCTION, /مهارات المادة أو موضوع الدرس/);
  assert.match(SOLVER_SCOPE_INSTRUCTION, /مئات الألوف/);
  assert.match(SOLVER_SCOPE_INSTRUCTION, /لا علاقة له بالتعليم/);
  // والأمرُ القديم بالرفض غائبٌ عن المسار كلِّه، وعن البابين.
  assert.doesNotMatch(gemini, /قل بوضوح: "هذا السؤال ليس من ضمن الدرس/);
  assert.doesNotMatch(gemini, /ولا تستخدم معرفتك العامة/);
  assert.equal(gemini.split("${SOLVER_SCOPE_INSTRUCTION}").length - 1, 2, "المكتوبُ والمصوَّر كلاهما");
});

test("الرفضُ المحفوظ إخفاقٌ عند القراءة، ولا يُكتب رفضٌ جديد", () => {
  assert.match(gemini, /if \(isRefusalAnswer\(answer\)\) \{\s*logger\.warn\(\{ key \}, "\[cache\] MISS — stored refusal ignored/);
  assert.match(gemini, /closest match is a stored refusal/);
  assert.match(gemini, /if \(isRefusalAnswer\(entry\.answer\)\) \{\s*logger\.warn\(\{ key: entry\.key \}, "\[cache\] refusal not saved"\)/);
});

test("كلُّ إجابةٍ جديدة تُحفظ: بمتّجهها، وبإعادة المحاولة، ولو صورةً لم تُقرأ", () => {
  // نداءٌ واحدٌ للحفظ في المسار، ولا كتابةَ مباشرةً تتخطّاه.
  assert.equal(gemini.split("void persistAnswer(").length - 1, 1);
  assert.equal(gemini.split("await writeCachedAnswer(").length - 1, 1, "الكتابةُ داخل persistAnswer وحدها");
  assert.match(gemini, /const SAVE_ATTEMPTS = 3;/);
  assert.match(gemini, /vector = await embedQuestion\(normalizeQuestion\(entry\.question\)\)/);
  // والصورةُ التي لم تُقرأ لها مفتاحٌ ببصمتها.
  assert.match(gemini, /createHash\("sha256"\)\.update\(image\.data\)/);
  assert.equal(imageKeyText("abc123", ""), "صوره abc123");
  assert.equal(imageKeyText("abc123", "احسب المحيط"), "صوره abc123 احسب المحيط");
});
