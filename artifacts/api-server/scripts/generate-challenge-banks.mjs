#!/usr/bin/env node
/**
 * يولّد بنك جولات التحدي لكل درسٍ له نصّ، ويحفظه مع الدرس.
 *
 * ── لماذا مرّةً واحدة لا عند كل فتحة ──
 * التوليد عند الفتح يُجلس طفلاً أمام انتظارٍ عشر ثوانٍ ويُسقط البطاقة
 * إن تعثّر النموذج. والبنك يُولَّد هنا مرّةً ويُحفظ في `data.challengeBank`،
 * فتُسحب منه خمسُ جولاتٍ فوراً، وإعادةُ التحدي تسحب غيرها.
 *
 * ── وما يفعله الخادم بعده ──
 * درسٌ لا بنك له يُولَّد بنكُه عند أوّل فتحةٍ ويُحفظ — فهذا السكربت
 * يعجّل الأمر لكل الدروس دفعةً واحدة، ولا يكون شرطاً لعملها.
 *
 * ── يُستأنف ولا يُعيد ──
 * ما كان بنكُه بالصيغة الحالية يُتخطّى، فالانقطاع في المنتصف لا يُعيد
 * العمل من أوّله ولا يُنفق على درسٍ مرّتين. و`--force` يُعيد الكلّ.
 *
 * التشغيل — الخطة أولاً:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... GEMINI_API_KEY=... \
 *     node scripts/generate-challenge-banks.mjs
 *
 * ثم أضف --execute للتوليد والحفظ.
 */

import { existsSync, rmSync } from "node:fs";
import nodePath from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath, pathToFileURL } from "node:url";

const args = process.argv.slice(2);
const EXECUTE = args.includes("--execute");
const FORCE = args.includes("--force");
const flag = (name, fallback = null) => {
  const at = args.indexOf(name);
  return at === -1 ? fallback : args[at + 1] ?? fallback;
};
const ONLY = flag("--only");
const LIMIT = Number(flag("--limit", "0")) || 0;

const SUPABASE_URL = process.env.SUPABASE_URL?.trim().replace(/\/+$/, "");
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
const GEMINI_KEY = process.env.GEMINI_API_KEY?.trim();

const EPOCH_KEY = "smartEdu_contentEpoch";

const text = (value) => (value == null ? "" : String(value).trim());

const norm = (value) =>
  text(value)
    .toLowerCase()
    .replace(/[ً-ْٰـ]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/\s+/g, " ")
    .trim();

const detectSubject = (subject) => {
  const wanted = norm(subject);
  if (wanted.includes("انجليز") || wanted.includes("english")) return "english";
  if (wanted.includes("رياضيات") || wanted.includes("math")) return "math";
  if (wanted.includes("علوم") || wanted.includes("science")) return "science";
  return "other";
};

const headers = () => ({
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  "Content-Type": "application/json",
});

async function readJson(path) {
  const response = await fetch(`${SUPABASE_URL}${path}`, { headers: headers() });
  if (!response.ok) {
    throw new Error(`GET ${path} → ${response.status} ${(await response.text()).slice(0, 200)}`);
  }
  return response.json();
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const MODELS = [
  process.env.GEMINI_MODEL?.trim().replace(/^models\//, ""),
  "gemini-flash-lite-latest",
  "gemini-2.5-flash-lite",
  "gemini-flash-latest",
  "gemini-2.5-flash",
].filter(Boolean);

async function askGemini(prompt, { tries = 3 } = {}) {
  let lastError = null;
  for (let round = 0; round < tries; round += 1) {
    for (const model of MODELS) {
      try {
        const response = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(GEMINI_KEY)}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              contents: [{ parts: [{ text: prompt }] }],
              generationConfig: {
                temperature: 0.9,
                maxOutputTokens: 32000,
                responseMimeType: "application/json",
              },
            }),
            signal: AbortSignal.timeout(120_000),
          },
        );
        if (!response.ok) {
          lastError = new Error(`${model} → ${response.status}`);
          if (response.status === 404 || response.status === 400) continue;
          await sleep(3000 * (round + 1));
          continue;
        }
        const data = await response.json();
        return data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
      } catch (error) {
        lastError = error;
        await sleep(2000 * (round + 1));
      }
    }
  }
  throw lastError ?? new Error("تعذّر التوليد");
}

/**
 * يحمّل وحدة قواعد القبول — وحدةَ الخادم نفسها لا نسخةً منها.
 *
 * تكرارُ القواعد هنا يجعل تصفيةَ الدفعة تفترق عن تصفية المسار عند أوّل
 * تعديلٍ في إحداهما، فيُحفظ في البنك ما يردّه الخادم عند العرض.
 *
 * ── ثلاثة مسالك، بالترتيب ──
 * ١. `dist/lib/challengeBank.mjs` — ما صار `npm run build` يُخرجه.
 * ٢. `.js` — احتياطاً لبناءٍ بامتدادٍ آخر.
 * ٣. ترجمةٌ عابرة بـ esbuild من المصدر مباشرةً.
 *
 * والثالث هو ما يجعله يعمل بلا بناءٍ أصلاً: الوحدة نقيّةٌ بلا استيراد،
 * فترجمتُها سطر. وكان السكربت يقف عند المسلك الأول وحده ويطلب بناءً
 * يحزم كل شيء في `dist/index.mjs` ولا يُخرج هذا الملف — فلا يعمل أبداً.
 */
async function loadBankRules() {
  const here = nodePath.dirname(fileURLToPath(import.meta.url));
  for (const candidate of [
    "../dist/lib/challengeBank.mjs",
    "../dist/lib/challengeBank.js",
  ]) {
    const target = nodePath.resolve(here, candidate);
    if (!existsSync(target)) continue;
    try {
      return await import(pathToFileURL(target).href);
    } catch {
      // ملفٌّ موجودٌ لا يُستورد: جرّب ما بعده.
    }
  }

  const source = nodePath.resolve(here, "../src/lib/challengeBank.ts");
  if (!existsSync(source)) {
    console.error("لا `src/lib/challengeBank.ts` ولا نسخةٌ مبنيّة منه.");
    process.exit(1);
  }
  try {
    const { build } = await import("esbuild");
    const out = nodePath.join(tmpdir(), `challengeBank.${process.pid}.mjs`);
    await build({
      entryPoints: [source],
      outfile: out,
      format: "esm",
      platform: "node",
      target: "node20",
      bundle: false,
      logLevel: "silent",
    });
    // يُحذف عند الخروج مهما كان سببه، فلا يتراكم في مجلّد المؤقّتات.
    process.on("exit", () => {
      try {
        rmSync(out, { force: true });
      } catch {
        /* لا يضرّ بقاؤه */
      }
    });
    return await import(pathToFileURL(out).href);
  } catch (error) {
    console.error(
      "تعذّر تحميل قواعد القبول. شغّل `npm run build` أولاً، أو ثبّت " +
        `التبعيات ليتوفّر esbuild. السبب: ${error.message}`,
    );
    process.exit(1);
  }
}

const line = (t = "") => console.log(t);
const head = (t) => {
  line();
  line(`════ ${t} ════`);
};

async function main() {
  if (!SUPABASE_URL || !SERVICE_KEY) {
    console.error("SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY مطلوبان.");
    process.exit(1);
  }
  if (EXECUTE && !GEMINI_KEY) {
    console.error("GEMINI_API_KEY مطلوب للتوليد. ضعه في البيئة لا في سطر الأمر.");
    process.exit(1);
  }

  const { BANK_SIZE, BANK_VERSION, bankPrompt, parseBank, readBank } =
      await loadBankRules();

  line(EXECUTE ? "✍️ توليد وحفظ." : "🔍 الخطة وحدها — لا استدعاء نموذج ولا كتابة.");

  head("الخطة");
  const rows = await readJson("/rest/v1/lesson_configs?select=id,data&limit=10000");
  const all = Array.isArray(rows) ? rows : [];

  const candidates = all.filter((row) => {
    const data = row?.data ?? {};
    if (!text(data.lessonContent) && !text(data.lessonText)) return false;
    if (ONLY && !norm(data.subject).includes(norm(ONLY))) return false;
    return true;
  });

  const done = FORCE
    ? []
    : candidates.filter((row) => readBank(row?.data?.challengeBank) != null);
  const todo = candidates.filter((row) => !done.includes(row));

  line(`دروسٌ في الجدول: ${all.length}`);
  line(`منها بنصّ: ${candidates.length}`);
  line(`لها بنكٌ بالصيغة الحالية: ${done.length}${FORCE ? " (يُعاد: --force)" : " — تُتخطّى"}`);
  line(`سيُولَّد الآن: ${todo.length}`);

  const bySubject = new Map();
  for (const row of todo) {
    const subject = text(row?.data?.subject) || "—";
    bySubject.set(subject, (bySubject.get(subject) ?? 0) + 1);
  }
  for (const [subject, count] of [...bySubject].sort((a, b) => b[1] - a[1])) {
    line(`  • ${subject}: ${count}`);
  }

  const work = LIMIT > 0 ? todo.slice(0, LIMIT) : todo;
  if (LIMIT > 0) line(`محدودٌ بـ --limit ${LIMIT}`);

  if (!EXECUTE) {
    line();
    line("(الخطة فقط — أضف --execute للتوليد والحفظ)");
    return;
  }

  head("التوليد");
  const stats = { saved: 0, failed: 0, rounds: 0, short: 0, reasons: new Map() };
  const failures = [];

  for (const [index, row] of work.entries()) {
    const data = row.data ?? {};
    const label = `[${index + 1}/${work.length}] ${text(data.subject)} ▸ ${text(data.lesson)}`;
    try {
      const subject = detectSubject(data.subject);
      const raw = await askGemini(
        bankPrompt({
          subject: text(data.subject),
          unit: text(data.unit),
          lesson: text(data.lesson),
          lessonText: text(data.lessonContent) || text(data.lessonText),
        }),
      );
      const { rounds, rejected } = parseBank(raw, subject);
      for (const [why, count] of Object.entries(rejected)) {
        stats.reasons.set(why, (stats.reasons.get(why) ?? 0) + count);
      }

      // بنكٌ دون النصف لا يُحفظ: خمسُ جولاتٍ تُسحب منه، وبنكٌ من تسعٍ
      // يُعيد الجولات نفسها في المحاولة الثانية — وهو ما جاء البنك
      // ليمنعه.
      if (rounds.length < BANK_SIZE / 2) {
        stats.failed += 1;
        failures.push(`${label}: ${rounds.length} جولة من ${BANK_SIZE}`);
        line(`  ✖ ${label} — ${rounds.length}/${BANK_SIZE}، لم يُحفظ.`);
        continue;
      }
      if (rounds.length < BANK_SIZE) stats.short += 1;

      const bank = {
        version: BANK_VERSION,
        generatedAt: new Date().toISOString(),
        subject: text(data.subject),
        rounds,
      };

      const response = await fetch(
        `${SUPABASE_URL}/rest/v1/lesson_configs?id=eq.${encodeURIComponent(row.id)}`,
        {
          method: "PATCH",
          headers: { ...headers(), Prefer: "return=minimal" },
          body: JSON.stringify({
            // السجلّ كاملاً ومعه البنك: `PATCH` على `data` يستبدلها،
            // فكتابةُ البنك وحده تمحو نصّ الدرس ومساره.
            data: { ...data, challengeBank: bank },
            updated_at: new Date().toISOString(),
          }),
        },
      );
      if (!response.ok) {
        throw new Error(`PATCH → ${response.status} ${(await response.text()).slice(0, 200)}`);
      }

      stats.saved += 1;
      stats.rounds += rounds.length;
      const kinds = rounds.reduce((tally, round) => {
        tally[round.kind] = (tally[round.kind] ?? 0) + 1;
        return tally;
      }, {});
      line(
        `  ✅ ${label} — ${rounds.length} جولة ` +
          `(سحب ${kinds.fill ?? 0}، فرز ${kinds.classify ?? 0}، مطابقة ${kinds.match ?? 0})`,
      );
    } catch (error) {
      stats.failed += 1;
      failures.push(`${label}: ${error.message}`);
      line(`  ✖ ${label} — ${error.message}`);
    }
    await sleep(1200);
  }

  if (stats.saved > 0) {
    const stamp = new Date().toISOString();
    await fetch(`${SUPABASE_URL}/rest/v1/app_kv?on_conflict=key`, {
      method: "POST",
      headers: { ...headers(), Prefer: "resolution=merge-duplicates,return=minimal" },
      body: JSON.stringify({ key: EPOCH_KEY, value: stamp, updated_at: stamp }),
    });
    line();
    line(`رُفع ختم المحتوى: ${stamp}`);
  }

  head("الإحصاء");
  line(`  بنوكٌ حُفظت: ${stats.saved}`);
  line(`  جولاتٌ حُفظت: ${stats.rounds}`);
  line(`  بنوكٌ نقصت عن ${BANK_SIZE} لكنها قُبلت: ${stats.short}`);
  line(`  دروسٌ فشلت: ${stats.failed}`);
  for (const failure of failures) line(`      ✖ ${failure}`);
  if (stats.reasons.size) {
    line();
    line("  أسباب ردّ الجولات:");
    for (const [why, count] of [...stats.reasons].sort((a, b) => b[1] - a[1])) {
      line(`      • ${why}: ${count}`);
    }
  }

  if (stats.failed > 0) {
    line();
    line("أعد التشغيل بالأمر نفسه: ما نجح يُتخطّى، وما فشل يُحاوَل من جديد.");
    process.exit(1);
  }
}

main().catch((error) => {
  console.error("فشل:", error.message);
  process.exit(1);
});
