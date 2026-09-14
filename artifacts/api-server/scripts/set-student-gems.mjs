#!/usr/bin/env node
/**
 * يضبط رصيد جواهر طالب، ويعيد اشتقاق نقاط الخبرة والمستوى من المعادلة
 * المعتمدة في تطبيق الطالب — لا بقيم مكتوبة يدوياً.
 *
 * المعادلة (من `student_content_service.dart` و`student_gamification.dart`):
 *   • كل 10 جواهر تمنح 20 نقطة خبرة   →  xp = (gems ÷ 10) × 20
 *   • المستوى يُشتقّ من الخبرة          →  level = (xp ÷ 100) + 1
 *
 * فمثلاً 10 جواهر ⇒ 20 XP ⇒ المستوى 1.
 *
 * ولماذا لا يُكتب المستوى يدوياً: `StudentGamification.fromMap` تعيد اشتقاقه
 * من الـ XP عند كل قراءة وتتجاهل أي قيمة محفوظة مخالفة. فكتابة مستوى لا
 * يوافق المعادلة تضيع صامتةً عند أول تحميل.
 *
 * التشغيل:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
 *     node scripts/set-student-gems.mjs --name "جوري داود" --gems 10
 *
 * وبلا كتابة (معاينة):
 *   ... node scripts/set-student-gems.mjs --name "جوري داود" --gems 10 --dry-run
 */

const args = process.argv.slice(2);
const flag = (name, fallback = '') => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};
const DRY_RUN = args.includes('--dry-run');
const NAME = flag('name');
const STUDENT_ID = flag('id');
const GEMS = Number(flag('gems', 'NaN'));

if ((!NAME && !STUDENT_ID) || !Number.isFinite(GEMS) || GEMS < 0) {
  console.error(
    'الاستعمال: node scripts/set-student-gems.mjs --name "اسم الطالب" --gems 10 [--dry-run]\n' +
      '           أو --id <معرّف الطالب> بدل الاسم.',
  );
  process.exit(1);
}

const SUPABASE_URL = process.env.SUPABASE_URL?.trim().replace(/\/+$/, '');
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY مطلوبان.');
  process.exit(1);
}

const headers = {
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  'Content-Type': 'application/json',
};

/** المعادلة المعتمدة، مستنسخة حرفياً من منطق التطبيق. */
export function deriveRewards(gems) {
  const xp = Math.floor(gems / 10) * 20;
  const level = Math.floor(xp / 100) + 1;
  return { gems, xp, level };
}

const text = (v) => (typeof v === 'string' ? v.trim() : v == null ? '' : String(v).trim());
const normalize = (v) => text(v).replace(/\s+/g, ' ').toLowerCase();

async function main() {
  const url = new URL('/rest/v1/students', SUPABASE_URL);
  url.searchParams.set('select', 'id,data');
  const response = await fetch(url, { headers });
  if (!response.ok) {
    throw new Error(`تعذّر قراءة الطلاب: ${response.status} ${await response.text()}`);
  }
  const rows = await response.json();

  const matches = rows.filter((row) => {
    const data = row?.data && typeof row.data === 'object' ? row.data : {};
    if (STUDENT_ID) return text(data.id) === STUDENT_ID || text(row.id) === STUDENT_ID;
    return normalize(data.name) === normalize(NAME);
  });

  if (matches.length === 0) {
    console.error(`لم يُعثر على طالب بهذا ${STUDENT_ID ? 'المعرّف' : 'الاسم'}: ${STUDENT_ID || NAME}`);
    process.exit(1);
  }
  if (matches.length > 1) {
    // لا يُخمَّن: تعديل رصيد الطالب الخطأ يصعب اكتشافه لاحقاً.
    console.error(`الاسم «${NAME}» يطابق ${matches.length} طلاب. أعد التشغيل بـ --id لتحديد المقصود:`);
    matches.forEach((row) => {
      const d = row.data || {};
      console.error(`  • ${text(d.id) || text(row.id)}  —  ${text(d.name)}  —  ${text(d.grade) || 'بلا صف'}`);
    });
    process.exit(1);
  }

  const row = matches[0];
  const data = row.data && typeof row.data === 'object' ? row.data : {};
  const before = data.gamification && typeof data.gamification === 'object' ? data.gamification : {};
  const derived = deriveRewards(GEMS);

  console.log('──────── الطالب ────────');
  console.log(`الاسم   : ${text(data.name)}`);
  console.log(`المعرّف : ${text(data.id) || text(row.id)}`);
  console.log(`الصف    : ${text(data.grade) || '—'}`);
  console.log('');
  console.log('القيم قبل :', JSON.stringify({ gems: before.gems ?? 0, xp: before.xp ?? 0, level: before.level ?? 1 }));
  console.log('القيم بعد :', JSON.stringify(derived));
  console.log(`(المعادلة: xp = ⌊${GEMS}/10⌋ × 20 = ${derived.xp}؛ level = ⌊${derived.xp}/100⌋ + 1 = ${derived.level})`);

  if (DRY_RUN) {
    console.log('\n(معاينة فقط — لم يُكتب شيء)');
    return;
  }

  // يُحافَظ على بقية حقول التلعيب (الإنجازات، السلسلة، سجل الأنشطة) كما هي:
  // الطلب ضبط الرصيد لا مسح تاريخ الطالب.
  const nextData = {
    ...data,
    gamification: {
      ...before,
      gems: derived.gems,
      xp: derived.xp,
      level: derived.level,
      levelProgress: derived.xp % 100,
      updatedAt: new Date().toISOString(),
    },
  };

  const patchUrl = new URL('/rest/v1/students', SUPABASE_URL);
  patchUrl.searchParams.set('id', `eq.${text(row.id)}`);
  const patch = await fetch(patchUrl, {
    method: 'PATCH',
    headers: { ...headers, Prefer: 'return=minimal' },
    body: JSON.stringify({ data: nextData, updated_at: new Date().toISOString() }),
  });
  if (!patch.ok) {
    throw new Error(`تعذّر التحديث: ${patch.status} ${await patch.text()}`);
  }
  console.log('\n✅ تم التحديث.');

  // تحقّق بعدي: يُقرأ الصف من جديد ويُقارن بالمشتقّ.
  const verifyUrl = new URL('/rest/v1/students', SUPABASE_URL);
  verifyUrl.searchParams.set('select', 'id,data');
  verifyUrl.searchParams.set('id', `eq.${text(row.id)}`);
  const check = await (await fetch(verifyUrl, { headers })).json();
  const saved = check?.[0]?.data?.gamification ?? {};
  const okAll =
    saved.gems === derived.gems && saved.xp === derived.xp && saved.level === derived.level;
  console.log(
    okAll
      ? `✅ تحقّق: الجواهر ${saved.gems}، الخبرة ${saved.xp}، المستوى ${saved.level}.`
      : `❌ التحقّق فشل — المحفوظ: ${JSON.stringify(saved)}`,
  );
  if (!okAll) process.exit(1);
}

main().catch((error) => {
  console.error('فشل:', error.message);
  process.exit(1);
});
