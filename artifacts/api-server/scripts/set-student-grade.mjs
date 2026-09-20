#!/usr/bin/env node
/**
 * يضبط صفّ طالب في `students` مباشرةً، ويقرأ الصفّ بعدها للتأكيد.
 *
 * `students` جدول `(id text, data jsonb)`: الصفّ داخل `data` لا في عمود،
 * فلا وجود لخلاف بين اسم حقل واسم عمود. يكتب هذا السكربت الحقلين معاً —
 * `grade` و`primaryGrade` — لأن الشاشات القديمة تقرأ أحدهما والتطبيق يقرأ
 * الآخر، ويترك بقية السجلّ كما هو.
 *
 * يُستعمل حين يعلق تعديل في متصفّح ولم يصل: إصلاح مباشر لا ينتظر مزامنة.
 *
 * التشغيل:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
 *     node scripts/set-student-grade.mjs --student <id|username> --grade "الصف الرابع الابتدائي"
 *
 * وبـ `--dry-run` يعرض ما سيتغيّر بلا كتابة.
 */

const args = process.argv.slice(2);
const flag = (name) => {
  const at = args.indexOf(name);
  return at === -1 ? null : args[at + 1] ?? null;
};
const WANTED = flag('--student');
const GRADE = flag('--grade');
const SUBJECT = flag('--subject');
const DRY_RUN = args.includes('--dry-run');

const SUPABASE_URL = process.env.SUPABASE_URL?.trim().replace(/\/+$/, '');
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

const headers = () => ({
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  'Content-Type': 'application/json',
});

const norm = (value) =>
  typeof value === 'string' ? value.trim().toLowerCase()
    : value == null ? '' : String(value).trim().toLowerCase();

/** السجلّ بعد ضبط الصفّ، بلا مساس ببقيته. */
export function withGrade(data, grade, subject) {
  const next = { ...(data ?? {}), grade, primaryGrade: grade };
  if (subject) next.subject = subject;
  // تسجيلات الصف تحمل اسمه أيضاً، فتتبعه.
  if (Array.isArray(next.gradeEnrollments)) {
    next.gradeEnrollments = next.gradeEnrollments.map((entry) => ({
      ...entry,
      grade: entry?.grade ? grade : entry?.grade,
    }));
  }
  next.lastActivity = new Date().toISOString();
  return next;
}

async function readJson(url) {
  const response = await fetch(url, { headers: headers() });
  if (!response.ok) {
    throw new Error(`GET ${url} → ${response.status} ${(await response.text()).slice(0, 200)}`);
  }
  return response.json();
}

async function main() {
  if (!SUPABASE_URL || !SERVICE_KEY) {
    console.error('SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY مطلوبان.');
    process.exit(1);
  }
  if (!WANTED || !GRADE) {
    console.error('الاستعمال: node scripts/set-student-grade.mjs --student <id|username> --grade "اسم الصف"');
    process.exit(1);
  }

  const rows = await readJson(`${SUPABASE_URL}/rest/v1/students?select=id,data&limit=5000`);
  const match = (Array.isArray(rows) ? rows : []).find((row) => {
    const data = row?.data ?? {};
    return [row.id, data.id, data.username, data.studentIdNumber, data.name]
      .some((value) => norm(value) === norm(WANTED));
  });
  if (!match) {
    console.error(`لا يوجد طالب بهذا المعرّف: ${WANTED}`);
    process.exit(1);
  }

  const before = match.data ?? {};
  console.log(`الطالب: ${before.name ?? '—'}  (id: ${match.id})`);
  console.log(`   الصف الآن: ${before.grade ?? '—'} / ${before.primaryGrade ?? '—'}`);
  console.log(`   الصف بعد التعديل: ${GRADE}${SUBJECT ? `   المادة: ${SUBJECT}` : ''}`);

  if (DRY_RUN) {
    console.log('\nعرض فقط — لم يُكتب شيء.');
    return;
  }

  const next = withGrade(before, GRADE, SUBJECT);
  const response = await fetch(
    `${SUPABASE_URL}/rest/v1/students?id=eq.${encodeURIComponent(match.id)}`,
    {
      method: 'PATCH',
      headers: { ...headers(), Prefer: 'return=minimal' },
      body: JSON.stringify({ data: next, updated_at: new Date().toISOString() }),
    },
  );
  if (!response.ok) {
    throw new Error(`PATCH students → ${response.status} ${(await response.text()).slice(0, 300)}`);
  }

  // القراءة بعد الكتابة: لا يُعلَن النجاح إلا عمّا وصل فعلاً.
  const after = await readJson(
    `${SUPABASE_URL}/rest/v1/students?select=id,data&id=eq.${encodeURIComponent(match.id)}`,
  );
  const stored = Array.isArray(after) && after.length > 0 ? after[0].data : {};
  if (norm(stored.grade) === norm(GRADE) && norm(stored.primaryGrade) === norm(GRADE)) {
    console.log('\n✅ حُفظ في قاعدة البيانات وتأكّد بالقراءة.');
  } else {
    console.error(`\n⚠️ الكتابة لم تُرفض، لكن القراءة تعيد: ${stored.grade ?? '—'}`);
    process.exit(1);
  }
}

if (process.argv[1] && process.argv[1].endsWith('set-student-grade.mjs')) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
