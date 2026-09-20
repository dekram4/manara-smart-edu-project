#!/usr/bin/env node
/**
 * يكشف دروس `lesson_configs` التي لم يعد لمسارها وجود في الشجرة الأكاديمية.
 *
 * ── كيف يصير الدرس يتيماً ──
 * حذف المشرف أو المعلم لمادة أو فصل أو وحدة من الإعدادات الأكاديمية يحذف
 * العقدة من الشجرة، ولا يمسّ الدروس المنشورة تحتها. وكانت تلك الدروس تعيد
 * مسارها إلى شاشة الطالب؛ صار الطالب يقرأ الشجرة وحدها، فلم تعد تظهر له،
 * لكنها باقية في الجدول.
 *
 * ── ما الذي يُعدّ يتيماً ──
 * الدرس الذي لا يوجد مسارُه (صف ← مادة ← فصل ← وحدة) في **أي** إعداد في
 * الشجرة، أياً كان صاحبه. القاعدة متحفّظة عمداً: ما دام أحدٌ ما يعلن هذا
 * المسار، لا يُمسّ الدرس.
 *
 * والدرس الذي ينقصه مستوىً من مساره (صفّ بلا وحدة مثلاً) يُعدّ ناقصاً لا
 * يتيماً، ويُذكر في تقرير منفصل بلا حذف: أصله غالباً سجلّ قديم، وحذفُه
 * قرارٌ لا يتّخذه سكريبت.
 *
 * ── التشغيل ──
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
 *     node scripts/prune-orphan-lessons.mjs            # عرض فقط
 *     node scripts/prune-orphan-lessons.mjs --apply    # وسْم deleted: true
 *     node scripts/prune-orphan-lessons.mjs --hard     # حذف الصفوف نهائياً
 *
 * `--apply` قابل للتراجع: يضع `deleted: true` في `data` فيختفي الدرس من
 * التطبيق ويبقى صفُّه. `--hard` لا رجعة فيه — خذ نسخة احتياطية أولاً.
 */

const args = process.argv.slice(2);
const APPLY = args.includes('--apply');
const HARD = args.includes('--hard');

const SUPABASE_URL = process.env.SUPABASE_URL?.trim().replace(/\/+$/, '');
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

function requireCredentials() {
  if (!SUPABASE_URL || !SERVICE_KEY) {
    console.error('SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY مطلوبان.');
    process.exit(1);
  }
}

const headers = () => ({
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  'Content-Type': 'application/json',
});

const HIERARCHY_KEY = 'smartEdu_hierarchicalConfigs';

const normalize = (value) =>
  typeof value === 'string' ? value.trim().toLowerCase()
    : value == null ? '' : String(value).trim().toLowerCase();

/** مواد الصف، ومنها تُقرأ الشجرة قبل الترحيل وبعده. */
function subjectsOfConfig(config) {
  if (Array.isArray(config?.subjects)) return config.subjects;
  if (!Array.isArray(config?.atrams)) return [];
  return config.atrams.flatMap((atram) =>
    Array.isArray(atram?.subjects) ? atram.subjects : [],
  );
}

/** كل مسار وحدة تعلنه الشجرة: `صف|مادة|فصل|وحدة`. */
export function declaredUnitPaths(configs) {
  const paths = new Set();
  (Array.isArray(configs) ? configs : []).forEach((config) => {
    const grade = normalize(config?.grade);
    if (!grade) return;
    subjectsOfConfig(config).forEach((subject) => {
      const subjectName = normalize(subject?.subject);
      if (!subjectName) return;
      (Array.isArray(subject?.terms) ? subject.terms : []).forEach((term) => {
        const termName = normalize(term?.term);
        if (!termName) return;
        (Array.isArray(term?.units) ? term.units : []).forEach((unit) => {
          const unitName = normalize(unit);
          if (unitName) paths.add([grade, subjectName, termName, unitName].join('|'));
        });
      });
    });
  });
  return paths;
}

/** مسار الدرس كما هو مخزّن، أو `null` إن نقص منه مستوى. */
export function lessonPath(data) {
  const parts = [
    normalize(data?.grade),
    normalize(data?.subject),
    normalize(data?.term),
    normalize(data?.unit),
  ];
  return parts.every((part) => part !== '') ? parts.join('|') : null;
}

const isAlreadyDeleted = (data) =>
  data?.deleted === true ||
  data?.isDeleted === true ||
  ['deleted', 'removed'].includes(normalize(data?.status));

/** يقسّم الدروس إلى: مطابقة، ويتيمة، وناقصة المسار. */
export function classify(rows, declared) {
  const orphans = [];
  const incomplete = [];
  let matched = 0;
  (Array.isArray(rows) ? rows : []).forEach((row) => {
    const data = row?.data && typeof row.data === 'object' ? row.data : {};
    if (isAlreadyDeleted(data)) return;
    const path = lessonPath(data);
    if (!path) {
      incomplete.push(row);
      return;
    }
    if (declared.has(path)) matched += 1;
    else orphans.push(row);
  });
  return { orphans, incomplete, matched };
}

async function readJson(url) {
  const response = await fetch(url, { headers: headers() });
  if (!response.ok) {
    throw new Error(`GET ${url} → ${response.status} ${(await response.text()).slice(0, 200)}`);
  }
  return response.json();
}

function describe(row) {
  const data = row?.data ?? {};
  const name = data.lesson || data.lessonName || '(بلا اسم)';
  return `${row.id}  ${data.grade ?? '—'} ▸ ${data.subject ?? '—'} ▸ ${data.term ?? '—'} ▸ ${data.unit ?? '—'} ▸ ${name}`;
}

async function main() {
  requireCredentials();
  if (HARD && !APPLY) {
    console.error('--hard يلزمه --apply معه، تأكيداً للنيّة.');
    process.exit(1);
  }

  const kv = await readJson(
    `${SUPABASE_URL}/rest/v1/app_kv?select=value&key=eq.${encodeURIComponent(HIERARCHY_KEY)}`,
  );
  const configs = Array.isArray(kv) && kv.length > 0 ? kv[0].value : [];
  const declared = declaredUnitPaths(configs);
  if (declared.size === 0) {
    console.error('توقّف: الشجرة الأكاديمية فارغة أو غير مقروءة — كل درس سيبدو يتيماً.');
    process.exit(1);
  }

  const rows = await readJson(`${SUPABASE_URL}/rest/v1/lesson_configs?select=id,data&limit=10000`);
  const { orphans, incomplete, matched } = classify(rows, declared);

  console.log(`الشجرة تعلن ${declared.size} وحدة.`);
  console.log(`الدروس: ${matched} مطابقة، ${orphans.length} يتيمة، ${incomplete.length} ناقصة المسار.`);
  if (incomplete.length > 0) {
    console.log('\nناقصة المسار (لا تُحذف):');
    incomplete.slice(0, 20).forEach((row) => console.log(`   ${describe(row)}`));
  }
  if (orphans.length === 0) {
    console.log('\nلا يوجد درس يتيم.');
    return;
  }
  console.log('\nيتيمة:');
  orphans.forEach((row) => console.log(`   ${describe(row)}`));

  if (!APPLY) {
    console.log('\nعرض فقط. أضف --apply للوسْم، أو --apply --hard للحذف النهائي.');
    return;
  }

  for (const row of orphans) {
    if (HARD) {
      const response = await fetch(
        `${SUPABASE_URL}/rest/v1/lesson_configs?id=eq.${encodeURIComponent(row.id)}`,
        { method: 'DELETE', headers: headers() },
      );
      if (!response.ok) {
        throw new Error(`DELETE ${row.id} → ${response.status} ${(await response.text()).slice(0, 200)}`);
      }
    } else {
      const response = await fetch(
        `${SUPABASE_URL}/rest/v1/lesson_configs?id=eq.${encodeURIComponent(row.id)}`,
        {
          method: 'PATCH',
          headers: { ...headers(), Prefer: 'return=minimal' },
          body: JSON.stringify({
            data: { ...row.data, deleted: true, deletedReason: 'orphan: path not in academic tree' },
            updated_at: new Date().toISOString(),
          }),
        },
      );
      if (!response.ok) {
        throw new Error(`PATCH ${row.id} → ${response.status} ${(await response.text()).slice(0, 200)}`);
      }
    }
  }
  console.log(`\n${HARD ? 'حُذف' : 'وُسم'} ${orphans.length} درساً.`);
}

// يُستورَد في الاختبارات بلا تنفيذ.
if (process.argv[1] && process.argv[1].endsWith('prune-orphan-lessons.mjs')) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
