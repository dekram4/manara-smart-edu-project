#!/usr/bin/env node
/**
 * يحذف إعدادات الشجرة المعلّقة: ما لا يملكه معلّم قائم ولا المشرف.
 *
 * ── ما يُحذف وما يُترك ──
 * يُترك: كل إعداد يملكه معلّم موجود في جدول `teachers`، وكل إعداد يملكه
 * المشرف (`admin`/`supervisor`) — فشجرة المشرف قالب يعتمد عليه المعلمون
 * في «نسخ إلى إعداداتي»، وحذفها يُفقدهم نقطة البداية.
 *
 * يُحذف: الإعداد بلا مالك أصلاً، والإعداد الذي يحمل معرّف معلّم لم يعد
 * في الجدول — حسابٌ حُذف وبقيت شجرته. هذان لا يراهما أحد بعد اليوم:
 * تطبيق الطالب صار يقرأ شجرة معلّمه وحدها، فيبقيان وزناً في `app_kv`
 * وضجيجاً في كل قراءة بلا أن يخدما أحداً.
 *
 * ── الضمانة ──
 * لا يُحذف إعداد يملكه معلّم قائم مهما بدا فارغاً، ولا إعداد المشرف. ويُجرد
 * ما سيُحذف ويُعرض بالاسم قبل الكتابة، ثم يُقرأ المخزون بعدها للتحقّق.
 *
 * التشغيل:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
 *     node scripts/prune-unowned-configs.mjs --dry-run
 *
 * ثم بلا العلم للتنفيذ.
 */

const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');

const SUPABASE_URL = process.env.SUPABASE_URL?.trim().replace(/\/+$/, '');
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

const HIERARCHY_KEY = 'smartEdu_hierarchicalConfigs';

const headers = () => ({
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  'Content-Type': 'application/json',
});

const norm = (value) =>
  typeof value === 'string' ? value.trim().toLowerCase()
    : value == null ? '' : String(value).trim().toLowerCase();

const ownerOf = (config) =>
  norm(config?.teacherId ?? config?.teacher_id ?? config?.createdBy);

/** أسماء يُعرف بها المعلم: معرّفه واسم دخوله واسمه المكتوب. */
export function teacherIdentities(teachers) {
  const names = new Set();
  for (const teacher of teachers) {
    const data = teacher?.data ?? teacher ?? {};
    for (const value of [teacher?.id, data.id, data.username, data.name]) {
      const name = norm(value);
      if (name) names.add(name);
    }
  }
  return names;
}

/** هل لهذا الإعداد مالكٌ قائم؟ المشرف مالكٌ قائم دائماً. */
export function hasLivingOwner(config, identities) {
  const owner = ownerOf(config);
  if (!owner) return false;
  if (owner === 'admin' || owner === 'supervisor') return true;
  return identities.has(owner);
}

/** يفرز الشجرة إلى ما يبقى وما يُحذف، ومعه سبب الحذف. */
export function partitionConfigs(configs, identities) {
  const kept = [];
  const dropped = [];
  for (const config of Array.isArray(configs) ? configs : []) {
    if (!config || typeof config !== 'object') {
      dropped.push({ config, reason: 'ليس كائناً' });
      continue;
    }
    if (hasLivingOwner(config, identities)) {
      kept.push(config);
      continue;
    }
    dropped.push({
      config,
      reason: ownerOf(config) ? `معلّم غير موجود: ${ownerOf(config)}` : 'بلا مالك',
    });
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
    console.error('SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY مطلوبان.');
    process.exit(1);
  }

  const teachers = await readJson('/rest/v1/teachers?select=id,data&limit=2000');
  const identities = teacherIdentities(Array.isArray(teachers) ? teachers : []);
  console.log(`معلّمون قائمون: ${Array.isArray(teachers) ? teachers.length : 0}`);

  const rows = await readJson(
    `/rest/v1/app_kv?select=key,value&key=eq.${encodeURIComponent(HIERARCHY_KEY)}`,
  );
  const configs = rows?.[0]?.value;
  if (!Array.isArray(configs)) {
    console.log('لا شجرة مخزّنة — لا شيء ليُحذف.');
    return;
  }

  const { kept, dropped } = partitionConfigs(configs, identities);
  const adminKept = kept.filter((config) =>
    ['admin', 'supervisor'].includes(ownerOf(config)),
  );

  console.log(`\nالمدخلات        : ${configs.length}`);
  console.log(`تبقى            : ${kept.length}`);
  console.log(`  منها للمشرف   : ${adminKept.length}  ← قالب «نسخ إلى إعداداتي»`);
  console.log(`تُحذف           : ${dropped.length}`);

  if (dropped.length > 0) {
    console.log('\nالمحذوفة:');
    for (const item of dropped) {
      console.log(`  • ${item.config?.grade ?? '—'} — ${item.reason}`);
    }
  }

  // شجرة المشرف هي نقطة البداية لكل معلم جديد؛ اختفاؤها عطلٌ لا تنظيف.
  if (adminKept.length === 0) {
    console.log('\nℹ️ لا يوجد إعداد باسم المشرف أصلاً في هذه الشجرة.');
  }

  if (dropped.length === 0) {
    console.log('\n✅ لا سجلّات معلّقة — لا حاجة للكتابة.');
    return;
  }
  if (DRY_RUN) {
    console.log('\n(معاينة فقط — لم يُكتب شيء)');
    return;
  }

  const response = await fetch(`${SUPABASE_URL}/rest/v1/app_kv?on_conflict=key`, {
    method: 'POST',
    headers: { ...headers(), Prefer: 'resolution=merge-duplicates,return=minimal' },
    body: JSON.stringify({
      key: HIERARCHY_KEY,
      value: kept,
      updated_at: new Date().toISOString(),
    }),
  });
  if (!response.ok) {
    throw new Error(`تعذّرت الكتابة: ${response.status} ${(await response.text()).slice(0, 300)}`);
  }

  // التحقّق من المخزون نفسه، لا من الذاكرة.
  const after = await readJson(
    `/rest/v1/app_kv?select=key,value&key=eq.${encodeURIComponent(HIERARCHY_KEY)}`,
  );
  const saved = after?.[0]?.value;
  if (!Array.isArray(saved) || saved.length !== kept.length) {
    console.error('\n❌ التحقّق فشل: ما قُرئ بعد الكتابة لا يطابق ما أُرسل.');
    process.exit(1);
  }
  const savedAdmin = saved.filter((config) =>
    ['admin', 'supervisor'].includes(ownerOf(config)),
  ).length;
  if (savedAdmin !== adminKept.length) {
    console.error('\n❌ التحقّق فشل: عدد إعدادات المشرف تغيّر.');
    process.exit(1);
  }
  console.log(`\n✅ حُذف ${dropped.length}، وبقي ${saved.length} منها ${savedAdmin} للمشرف.`);
}

if (process.argv[1] && process.argv[1].endsWith('prune-unowned-configs.mjs')) {
  main().catch((error) => {
    console.error('فشل التنظيف:', error.message);
    process.exit(1);
  });
}
