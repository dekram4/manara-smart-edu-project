#!/usr/bin/env node
/**
 * يقول لماذا لا يرى طالبٌ بعينه درساً بعينه.
 *
 * يطبع سجلّ الطالب، والشجرة الأكاديمية التي تخصّه، وكل صفّ في
 * `lesson_configs` — ومع كل درس **سبب** ظهوره أو حجبه، بنفس القواعد التي
 * يطبّقها التطبيق حرفاً:
 *
 *   1. المالك: درس أنشأه معلم لا يراه إلا طلابه. ودرس بلا مالك، أو
 *      مالكه `admin`/`supervisor`، يراه الجميع. فطالبٌ بلا `teacherId`
 *      لا يرى دروس أي معلم — وهذا أكثر أسباب «الدرس لا يظهر» شيوعاً.
 *   2. الحذف: `deleted` أو `isDeleted` أو `status: deleted/removed`.
 *   3. المسار: الصف والمادة والفصل والوحدة يجب أن تكون معلَنة في الشجرة،
 *      وإلا فالدرس يتيم لا مسار له يُفتح منه.
 *
 * التشغيل:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
 *     node scripts/diagnose-student-visibility.mjs --student <اسم المستخدم>
 *
 * لا يكتب شيئاً إطلاقاً: قراءة فقط.
 */

const args = process.argv.slice(2);
const flag = (name) => {
  const at = args.indexOf(name);
  return at === -1 ? null : args[at + 1] ?? null;
};
const WANTED = flag('--student');

const SUPABASE_URL = process.env.SUPABASE_URL?.trim().replace(/\/+$/, '');
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

const headers = () => ({
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  'Content-Type': 'application/json',
});

const HIERARCHY_KEY = 'smartEdu_hierarchicalConfigs';

const norm = (value) =>
  typeof value === 'string' ? value.trim().toLowerCase()
    : value == null ? '' : String(value).trim().toLowerCase();

const ownerOf = (record) =>
  norm(record?.teacherId ?? record?.teacher_id ?? record?.createdBy);

const isDeleted = (data) =>
  data?.deleted === true ||
  data?.isDeleted === true ||
  ['deleted', 'removed'].includes(norm(data?.status));

function subjectsOfConfig(config) {
  if (Array.isArray(config?.subjects)) return config.subjects;
  if (!Array.isArray(config?.atrams)) return [];
  return config.atrams.flatMap((atram) =>
    Array.isArray(atram?.subjects) ? atram.subjects : [],
  );
}

/** قاعدة الملكية في التطبيق، حرفاً. */
export function ownerAllows(recordOwner, studentTeacherId) {
  if (!recordOwner || recordOwner === 'admin' || recordOwner === 'supervisor') return true;
  if (!studentTeacherId) return false;
  return recordOwner === studentTeacherId;
}

/** مسارات الوحدات المعلَنة في شجرة يراها الطالب. */
export function declaredPaths(configs, studentTeacherId) {
  const paths = new Set();
  (Array.isArray(configs) ? configs : []).forEach((config) => {
    if (!ownerAllows(ownerOf(config), studentTeacherId)) return;
    const grade = norm(config?.grade);
    if (!grade) return;
    subjectsOfConfig(config).forEach((subject) => {
      const subjectName = norm(subject?.subject);
      (Array.isArray(subject?.terms) ? subject.terms : []).forEach((term) => {
        const termName = norm(term?.term);
        (Array.isArray(term?.units) ? term.units : []).forEach((unit) => {
          if (subjectName && termName && norm(unit)) {
            paths.add([grade, subjectName, termName, norm(unit)].join('|'));
          }
        });
      });
    });
  });
  return paths;
}

/** سبب الحجب، أو `null` إن كان الدرس ظاهراً. */
export function hiddenReason(lesson, studentTeacherId, paths) {
  if (isDeleted(lesson)) return 'موسوم بالحذف';
  const owner = ownerOf(lesson);
  if (!ownerAllows(owner, studentTeacherId)) {
    return studentTeacherId
      ? `مالكه معلم آخر (${owner}) والطالب تابع لـ (${studentTeacherId})`
      : `مالكه معلم (${owner}) والطالب بلا teacherId`;
  }
  const parts = [norm(lesson.grade), norm(lesson.subject), norm(lesson.term), norm(lesson.unit)];
  if (parts.some((part) => part === '')) return 'مساره ناقص (حقل فارغ)';
  if (!paths.has(parts.join('|'))) return 'مساره غير موجود في الشجرة الأكاديمية';
  return null;
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
  if (!WANTED) {
    console.error('الاستعمال: node scripts/diagnose-student-visibility.mjs --student <اسم المستخدم>');
    process.exit(1);
  }

  const students = await readJson(`${SUPABASE_URL}/rest/v1/students?select=id,data&limit=5000`);
  const match = (Array.isArray(students) ? students : []).find((row) => {
    const data = row?.data ?? {};
    return [data.username, data.studentIdNumber, data.name, data.id, row.id]
      .some((value) => norm(value) === norm(WANTED));
  });
  if (!match) {
    console.error(`لا يوجد طالب بهذا المعرّف: ${WANTED}`);
    process.exit(1);
  }
  const student = match.data ?? {};
  const studentTeacherId = ownerOf(student);

  console.log('── سجلّ الطالب ──');
  console.log(`   id: ${student.id ?? match.id}`);
  console.log(`   الاسم: ${student.name ?? '—'}   المستخدم: ${student.username ?? '—'}`);
  console.log(`   الصف: ${student.grade ?? student.primaryGrade ?? '—'}`);
  console.log(`   teacherId: ${studentTeacherId || '(فارغ)'}`);
  if (!studentTeacherId) {
    console.log('   ⚠️  بلا معلم: لن يرى إلا الدروس والإعدادات التي أنشأها المشرف.');
  }

  const kv = await readJson(
    `${SUPABASE_URL}/rest/v1/app_kv?select=value&key=eq.${encodeURIComponent(HIERARCHY_KEY)}`,
  );
  const configs = Array.isArray(kv) && kv.length > 0 ? kv[0].value : [];
  const mine = (Array.isArray(configs) ? configs : []).filter((config) =>
    ownerAllows(ownerOf(config), studentTeacherId),
  );
  const paths = declaredPaths(configs, studentTeacherId);

  console.log('\n── الشجرة الأكاديمية ──');
  console.log(`   ${Array.isArray(configs) ? configs.length : 0} إعداداً، يرى الطالب منها ${mine.length}.`);
  mine.forEach((config) => {
    console.log(`   • ${config.grade}  (المالك: ${ownerOf(config) || 'admin'})`);
    subjectsOfConfig(config).forEach((subject) => {
      const terms = (subject.terms || []).map((term) => term.term).join('، ');
      console.log(`       ${subject.subject}: ${terms || '(بلا فصول)'}`);
    });
  });
  console.log(`   مسارات الوحدات المعلَنة: ${paths.size}`);

  const lessons = await readJson(`${SUPABASE_URL}/rest/v1/lesson_configs?select=id,data&limit=10000`);
  console.log('\n── الدروس ──');
  let visible = 0;
  (Array.isArray(lessons) ? lessons : []).forEach((row) => {
    const lesson = row?.data ?? {};
    const reason = hiddenReason(lesson, studentTeacherId, paths);
    const path = `${lesson.grade ?? '—'} ▸ ${lesson.subject ?? '—'} ▸ ${lesson.term ?? '—'} ▸ ${lesson.unit ?? '—'} ▸ ${lesson.lesson ?? '(بلا اسم)'}`;
    if (reason) {
      console.log(`   ✖ ${path}\n        السبب: ${reason}`);
    } else {
      visible += 1;
      console.log(`   ✔ ${path}`);
    }
  });
  console.log(`\n   يرى الطالب ${visible} درساً من أصل ${Array.isArray(lessons) ? lessons.length : 0}.`);
  if (visible === 0) {
    console.log('\n   الخلاصة: لا يوجد درس ظاهر لهذا الطالب. السبب مكتوب أمام كل درس أعلاه.');
  }
}

if (process.argv[1] && process.argv[1].endsWith('diagnose-student-visibility.mjs')) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
