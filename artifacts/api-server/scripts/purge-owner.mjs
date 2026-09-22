#!/usr/bin/env node
/**
 * يحذف كل ما يملكه اسمٌ قديم لمعلّم: شجرته في `app_kv` ودروسه في
 * `lesson_configs`.
 *
 * ── لماذا يبقى هذا الأثر أصلاً ──
 * ملكية السجلّ تُكتب نصّاً: `teacherId` أو `createdBy` يحمل أحياناً اسم
 * المعلّم لا معرّفه. فإذا أُعيدت تسميته صار لنفس الشخص مالكان في قاعدة
 * البيانات — الجديد والقديم — ويعامل النظام القديم معلّماً آخر: تظهر
 * إعداداته حيث لا ينبغي، ويحتفظ بصفوف حذفها صاحبها.
 *
 * ── الضمانة ──
 * لا يُحذف إلا ما يطابق اسماً مرّرته أنت صراحةً بـ `--owner`، ويُعرض كل
 * سجلّ بالاسم قبل الحذف. ويُرفض الاسم إن كان `admin` أو `supervisor`،
 * فحذف قالب المشرف عطلٌ لا تنظيف. ثم يُقرأ المخزون بعد الكتابة للتحقّق.
 *
 * التشغيل:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
 *     node scripts/purge-owner.mjs --owner "بكر برداوي" --owner "بكر برناوي" --dry-run
 *
 * ثم بلا العلم للتنفيذ.
 */

const args = process.argv.slice(2);
const DRY_RUN = args.includes("--dry-run");

/** كل ما مُرِّر بـ `--owner`، فقد يُعاد الاسم أكثر من مرة. */
const owners = args
  .map((value, index) => (value === "--owner" ? args[index + 1] : null))
  .filter(Boolean);

const SUPABASE_URL = process.env.SUPABASE_URL?.trim().replace(/\/+$/, "");
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

const HIERARCHY_KEY = "smartEdu_hierarchicalConfigs";
const PROTECTED = new Set(["admin", "supervisor"]);

const headers = () => ({
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  "Content-Type": "application/json",
});

/** تسوية عربية، نظيرة ما في `lib/studentAccess.ts`: الهمزة لا تُخفي مالكاً. */
export function norm(value) {
  const raw = value == null ? "" : String(value).trim().toLowerCase();
  return raw
    .replace(/[ً-ْٰـ]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/\s+/g, " ")
    .trim();
}

const ownerOf = (record) =>
  norm(record?.teacherId ?? record?.teacher_id ?? record?.createdBy);

/** يفرز ما يبقى وما يُحذف، بحسب قائمة الأسماء المطلوب محوها. */
export function partition(records, wanted) {
  const targets = new Set(wanted.map(norm));
  const kept = [];
  const dropped = [];
  for (const record of Array.isArray(records) ? records : []) {
    if (record && typeof record === "object" && targets.has(ownerOf(record))) {
      dropped.push(record);
    } else {
      kept.push(record);
    }
  }
  return { kept, dropped };
}

async function readJson(path) {
  const response = await fetch(`${SUPABASE_URL}${path}`, { headers: headers() });
  if (!response.ok) {
    throw new Error(`GET ${path} → ${response.status} ${(await response.text()).slice(0, 200)}`);
  }
  return response.json();
}

async function main() {
  if (!SUPABASE_URL || !SERVICE_KEY) {
    console.error("SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY مطلوبان.");
    process.exit(1);
  }
  if (owners.length === 0) {
    console.error('الاستعمال: node scripts/purge-owner.mjs --owner "الاسم القديم" [--dry-run]');
    process.exit(1);
  }
  for (const owner of owners) {
    if (PROTECTED.has(norm(owner))) {
      console.error(`مرفوض: «${owner}» مالكٌ محمي — قالب المشرف لا يُحذف.`);
      process.exit(1);
    }
  }

  console.log(`الأسماء المطلوب محوها: ${owners.map((o) => `«${o}»`).join("، ")}`);

  // ── الشجرة في app_kv ────────────────────────────────────────────────
  const kvRows = await readJson(
    `/rest/v1/app_kv?select=key,value&key=eq.${encodeURIComponent(HIERARCHY_KEY)}`,
  );
  const tree = kvRows?.[0]?.value;
  let treeKept = null;
  if (Array.isArray(tree)) {
    const { kept, dropped } = partition(tree, owners);
    treeKept = kept;
    console.log(`\n════ الشجرة الأكاديمية ════`);
    console.log(`المدخلات: ${tree.length} → تبقى ${kept.length}، تُحذف ${dropped.length}`);
    for (const record of dropped) {
      console.log(`  • ${record.grade ?? "—"} — مالكه «${record.teacherId ?? record.createdBy ?? "—"}»`);
    }
  } else {
    console.log("\nلا شجرة مخزّنة.");
  }

  // ── الدروس ──────────────────────────────────────────────────────────
  const lessonRows = await readJson("/rest/v1/lesson_configs?select=id,data&limit=5000");
  const lessons = Array.isArray(lessonRows) ? lessonRows : [];
  const doomedLessons = lessons.filter((row) =>
    new Set(owners.map(norm)).has(ownerOf(row?.data)),
  );
  console.log(`\n════ الدروس ════`);
  console.log(`السجلّات: ${lessons.length} → تُحذف ${doomedLessons.length}`);
  for (const row of doomedLessons) {
    const data = row.data ?? {};
    console.log(`  • ${data.grade ?? "—"} ▸ ${data.subject ?? "—"} ▸ ${data.unit ?? "—"} ▸ ${data.lesson ?? "—"}`);
  }

  if ((treeKept === null || treeKept.length === (tree?.length ?? 0)) &&
      doomedLessons.length === 0) {
    console.log("\n✅ لا أثر لهذه الأسماء — لا حاجة للكتابة.");
    return;
  }
  if (DRY_RUN) {
    console.log("\n(معاينة فقط — لم يُكتب شيء)");
    return;
  }

  if (treeKept && treeKept.length !== tree.length) {
    const response = await fetch(`${SUPABASE_URL}/rest/v1/app_kv?on_conflict=key`, {
      method: "POST",
      headers: { ...headers(), Prefer: "resolution=merge-duplicates,return=minimal" },
      body: JSON.stringify({
        key: HIERARCHY_KEY,
        value: treeKept,
        updated_at: new Date().toISOString(),
      }),
    });
    if (!response.ok) {
      throw new Error(`تعذّرت كتابة الشجرة: ${response.status} ${(await response.text()).slice(0, 300)}`);
    }
  }

  for (const row of doomedLessons) {
    const response = await fetch(
      `${SUPABASE_URL}/rest/v1/lesson_configs?id=eq.${encodeURIComponent(row.id)}`,
      { method: "DELETE", headers: { ...headers(), Prefer: "return=minimal" } },
    );
    if (!response.ok) {
      throw new Error(`تعذّر حذف الدرس ${row.id}: ${response.status}`);
    }
  }

  // ── التحقّق من المخزون نفسه ─────────────────────────────────────────
  const afterKv = await readJson(
    `/rest/v1/app_kv?select=key,value&key=eq.${encodeURIComponent(HIERARCHY_KEY)}`,
  );
  const afterTree = afterKv?.[0]?.value;
  const leftInTree = partition(afterTree, owners).dropped.length;
  const afterLessons = await readJson("/rest/v1/lesson_configs?select=id,data&limit=5000");
  const leftInLessons = (Array.isArray(afterLessons) ? afterLessons : []).filter((row) =>
    new Set(owners.map(norm)).has(ownerOf(row?.data)),
  ).length;

  if (leftInTree > 0 || leftInLessons > 0) {
    console.error(`\n❌ التحقّق فشل — بقي في الشجرة ${leftInTree} وفي الدروس ${leftInLessons}.`);
    process.exit(1);
  }
  console.log("\n✅ حُذف كل أثر لهذه الأسماء، وتأكّد بالقراءة.");
}

if (process.argv[1] && process.argv[1].endsWith("purge-owner.mjs")) {
  main().catch((error) => {
    console.error("فشل الحذف:", error.message);
    process.exit(1);
  });
}
