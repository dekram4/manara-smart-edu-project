#!/usr/bin/env node
/**
 * مزامنة وتنظيف موجّهة: توحيد اسم معلّم، وإزالة صفٍّ عالق من شجرته
 * ودروسه — بلا مساس بشيء سواه.
 *
 * ── لماذا يلزم هذا أصلاً ──
 * الملكية تُكتب نصّاً في هذا النظام: `teacherId` أو `createdBy` يحمل
 * أحياناً اسم المعلّم لا معرّفه. فإذا أُعيدت تسميته صار لنفس الشخص مالكان
 * في قاعدة البيانات، ويعامل النظام القديم معلّماً آخر — فتبقى صفوفه ولا
 * يملك صاحبها حذفها من شاشته.
 *
 * (وقد عولج المستقبل في الخادم: حفظ المعلّم صار يستبدل ما تحت كل أسمائه.
 * هذا السكربت لما استقرّ في المخزون قبل ذلك.)
 *
 * ── ما لا يفعله ──
 * لا يحذف صفّاً لم تسمِّه بـ `--grade`، ولا يمسّ معلّماً آخر، ولا قوالب
 * المشرف، ولا أي مادة أو وحدة أو درس خارج ذلك الصفّ بعينه. وكل ما سيقع
 * يُطبع بالاسم قبل أن يقع، و`--dry-run` يقف عند الطباعة.
 *
 * التشغيل — المعاينة أولاً دائماً:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
 *     node scripts/sync-db-updates.mjs \
 *       --old-name "بكر برناوي" --old-name "بكر برداوي" \
 *       --teacher test --grade "الصف الأول" --dry-run
 *
 * ثم بلا `--dry-run` للتنفيذ.
 */

const args = process.argv.slice(2);
const DRY_RUN = args.includes("--dry-run");

const flag = (name) => {
  const at = args.indexOf(name);
  return at === -1 ? null : args[at + 1] ?? null;
};
const many = (name) =>
  args.map((value, i) => (value === name ? args[i + 1] : null)).filter(Boolean);

const OLD_NAMES = many("--old-name");
const TEACHER = flag("--teacher");
const GRADES = many("--grade");

const SUPABASE_URL = process.env.SUPABASE_URL?.trim().replace(/\/+$/, "");
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

const HIERARCHY_KEY = "smartEdu_hierarchicalConfigs";
const PROTECTED_OWNERS = new Set(["admin", "supervisor"]);

const headers = () => ({
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  "Content-Type": "application/json",
});

/** تسوية عربية، نظيرة ما في الخادم: الهمزة لا تصنع مالكاً ثانياً. */
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

export const ownerOf = (record) =>
  norm(record?.teacherId ?? record?.teacher_id ?? record?.createdBy);

/**
 * يقرّر مصير كل مدخل في الشجرة.
 *
 * يُحذف المدخل إذا كان صفّه من الصفوف المسمّاة **و** مالكه هذا المعلّم
 * بأحد أسمائه. والشرطان معاً: صفٌّ بالاسم نفسه عند معلّم آخر يبقى له.
 */
export function planTree(configs, { identities, grades }) {
  const wantedGrades = new Set(grades.map(norm));
  const kept = [];
  const dropped = [];
  for (const config of Array.isArray(configs) ? configs : []) {
    if (!config || typeof config !== "object") {
      kept.push(config);
      continue;
    }
    const owner = ownerOf(config);
    const mine = identities.has(owner);
    const doomed = mine && wantedGrades.has(norm(config.grade));
    (doomed ? dropped : kept).push(config);
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

async function patchRow(table, id, body) {
  const response = await fetch(
    `${SUPABASE_URL}/rest/v1/${table}?id=eq.${encodeURIComponent(id)}`,
    { method: "PATCH", headers: { ...headers(), Prefer: "return=minimal" }, body: JSON.stringify(body) },
  );
  if (!response.ok) {
    throw new Error(`PATCH ${table}/${id} → ${response.status} ${(await response.text()).slice(0, 200)}`);
  }
}

const line = (text = "") => console.log(text);
const head = (text) => {
  line();
  line(`════ ${text} ════`);
};

async function main() {
  if (!SUPABASE_URL || !SERVICE_KEY) {
    console.error("SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY مطلوبان.");
    process.exit(1);
  }
  if (!TEACHER) {
    console.error('الاستعمال: node scripts/sync-db-updates.mjs --teacher <اسم الدخول> [--old-name "الاسم القديم"] [--grade "الصف"] [--dry-run]');
    process.exit(1);
  }
  for (const name of [...OLD_NAMES, TEACHER]) {
    if (PROTECTED_OWNERS.has(norm(name))) {
      console.error(`مرفوض: «${name}» مالكٌ محمي.`);
      process.exit(1);
    }
  }

  line(DRY_RUN ? "🔍 معاينة — لن يُكتب شيء." : "✍️ تنفيذ فعلي.");
  line(`المعلّم: «${TEACHER}»`);
  if (OLD_NAMES.length) line(`الأسماء القديمة: ${OLD_NAMES.map((n) => `«${n}»`).join("، ")}`);
  if (GRADES.length) line(`الصفوف المطلوب حذفها: ${GRADES.map((g) => `«${g}»`).join("، ")}`);

  // ── أ) سجلّ المعلّم ──────────────────────────────────────────────────
  head("جدول المعلمين");
  const teachers = await readJson("/rest/v1/teachers?select=id,data&limit=2000");
  const rows = Array.isArray(teachers) ? teachers : [];
  const wantedNames = new Set([...OLD_NAMES, TEACHER].map(norm));

  const matched = rows.filter((row) => {
    const data = row?.data ?? {};
    return [row.id, data.id, data.username, data.name].map(norm).some((n) => n && wantedNames.has(n));
  });

  if (matched.length === 0) {
    line("لا حساب يطابق هذه الأسماء.");
  }
  const identities = new Set();
  for (const row of matched) {
    const data = row?.data ?? {};
    for (const value of [row.id, data.id, data.username, data.name]) {
      const n = norm(value);
      if (n) identities.add(n);
    }
    const needsRename = norm(data.name) !== norm(TEACHER);
    line(`  • id=${row.id}  username=${data.username ?? "—"}  name=${data.name ?? "—"}` +
      (needsRename ? `   ← يصير الاسم «${TEACHER}»` : "   (الاسم صحيح)"));
    if (needsRename && !DRY_RUN) {
      await patchRow("teachers", row.id, {
        data: { ...data, name: TEACHER },
        updated_at: new Date().toISOString(),
      });
    }
  }
  for (const name of wantedNames) identities.add(name);

  // ── ب) الشجرة الأكاديمية ────────────────────────────────────────────
  head("الشجرة الأكاديمية");
  const kvRows = await readJson(
    `/rest/v1/app_kv?select=key,value&key=eq.${encodeURIComponent(HIERARCHY_KEY)}`,
  );
  const tree = kvRows?.[0]?.value;
  let treePlan = null;
  if (!Array.isArray(tree)) {
    line("لا شجرة مخزّنة.");
  } else if (GRADES.length === 0) {
    line("لم يُطلب حذف صف — الشجرة كما هي.");
  } else {
    treePlan = planTree(tree, { identities, grades: GRADES });
    line(`المدخلات: ${tree.length} → تبقى ${treePlan.kept.length}، تُحذف ${treePlan.dropped.length}`);
    for (const config of treePlan.dropped) {
      const subjects = (config.subjects ?? []).map((s) => s?.subject).filter(Boolean);
      line(`  ✖ «${config.grade}» — مالكه «${config.teacherId ?? config.createdBy ?? "—"}»` +
        (subjects.length ? `  (يحمل: ${subjects.join("، ")})` : "  (فارغ)"));
    }
    // ما يبقى للمعلّم نفسه، ليراه صاحبه قبل الكتابة ويطمئنّ.
    const mineKept = treePlan.kept.filter((c) => identities.has(ownerOf(c)));
    line(`  وتبقى له ${mineKept.length} صفاً: ${mineKept.map((c) => `«${c.grade}»`).join("، ") || "—"}`);
    const adminKept = treePlan.kept.filter((c) => PROTECTED_OWNERS.has(ownerOf(c)));
    line(`  وقوالب المشرف: ${adminKept.length} — لا تُمسّ.`);
  }

  // ── ج) الدروس تحت الصفوف المحذوفة ──────────────────────────────────
  head("الدروس");
  const lessonRows = await readJson("/rest/v1/lesson_configs?select=id,data&limit=5000");
  const lessons = Array.isArray(lessonRows) ? lessonRows : [];
  const wantedGrades = new Set(GRADES.map(norm));
  const doomedLessons = GRADES.length === 0
    ? []
    : lessons.filter((row) => {
        const data = row?.data ?? {};
        return identities.has(ownerOf(data)) && wantedGrades.has(norm(data.grade));
      });
  line(`السجلّات: ${lessons.length} → تُحذف ${doomedLessons.length}`);
  for (const row of doomedLessons) {
    const d = row.data ?? {};
    line(`  ✖ ${d.grade ?? "—"} ▸ ${d.subject ?? "—"} ▸ ${d.unit ?? "—"} ▸ ${d.lesson ?? "—"}`);
  }

  if (DRY_RUN) {
    line();
    line("(معاينة فقط — لم يُكتب شيء)");
    return;
  }

  // ── التنفيذ ─────────────────────────────────────────────────────────
  if (treePlan && treePlan.dropped.length > 0) {
    const response = await fetch(`${SUPABASE_URL}/rest/v1/app_kv?on_conflict=key`, {
      method: "POST",
      headers: { ...headers(), Prefer: "resolution=merge-duplicates,return=minimal" },
      body: JSON.stringify({
        key: HIERARCHY_KEY,
        value: treePlan.kept,
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
    if (!response.ok) throw new Error(`تعذّر حذف الدرس ${row.id}: ${response.status}`);
  }

  // ── التحقّق من المخزون نفسه، لا من الذاكرة ──────────────────────────
  head("التحقّق");
  const afterKv = await readJson(
    `/rest/v1/app_kv?select=key,value&key=eq.${encodeURIComponent(HIERARCHY_KEY)}`,
  );
  const afterTree = afterKv?.[0]?.value;
  const leftInTree = GRADES.length === 0
    ? 0
    : planTree(afterTree, { identities, grades: GRADES }).dropped.length;
  const afterLessons = await readJson("/rest/v1/lesson_configs?select=id,data&limit=5000");
  const leftLessons = (Array.isArray(afterLessons) ? afterLessons : []).filter((row) => {
    const data = row?.data ?? {};
    return identities.has(ownerOf(data)) && wantedGrades.has(norm(data.grade));
  }).length;

  if (leftInTree > 0 || leftLessons > 0) {
    console.error(`❌ بقي في الشجرة ${leftInTree} وفي الدروس ${leftLessons}.`);
    process.exit(1);
  }
  if (Array.isArray(afterTree) && treePlan) {
    line(`الشجرة الآن: ${afterTree.length} مدخلاً.`);
  }
  line("✅ تمّ، وتأكّد بالقراءة.");
}

if (process.argv[1] && process.argv[1].endsWith("sync-db-updates.mjs")) {
  main().catch((error) => {
    console.error("فشل:", error.message);
    process.exit(1);
  });
}
