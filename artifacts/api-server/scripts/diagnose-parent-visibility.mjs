#!/usr/bin/env node
/**
 * يطبع ما يراه وليّ أمر في لوحته، من قاعدة البيانات مباشرة.
 *
 * لوحة وليّ الأمر تقرأ من نسخة المتصفح، فحين يشكو أنه «لا يرى ابنه» أو
 * «لا يرى نتائجه» يستحيل الفصل بين ثلاثة احتمالات من الشاشة وحدها: بيانات
 * غائبة عن الخادم، أو رابط مكسور بين الابن ووليّه، أو نسخة متصفّح قديمة.
 * هذا السكربت يقطع الشك: كل ما يطبعه مقروء من Supabase في هذه اللحظة،
 * فما ظهر هنا وغاب عن الشاشة فعلّته في المتصفح لا في البيانات.
 *
 * والربط يُقرأ بالقاعدة التي يطبّقها التطبيق حرفاً: الابن يتبع وليّه بـ
 * `student.parentId === parent.id` وحده. مطابقة رقم الجوال ترحيلٌ يجري
 * مرة واحدة، لا قاعدة قراءة — فالطالب الذي يحمل رقم والده ولا يحمل
 * `parentId` لا يظهر في اللوحة إطلاقاً. لذلك يُفرد له هذا التقرير سطراً
 * صريحاً بدل أن يُسقطه صامتاً، فهو أكثر أسباب «ابني غير موجود» شيوعاً.
 *
 * التشغيل:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
 *     node scripts/diagnose-parent-visibility.mjs --parent <اسم المستخدم|رقم الجوال|id>
 *
 * أو بالانطلاق من الابن حين يُعرف اسمه وحده:
 *     node scripts/diagnose-parent-visibility.mjs --student j
 *
 * لا يكتب شيئاً إطلاقاً: قراءة فقط.
 */

const args = process.argv.slice(2);
const flag = (name) => {
  const at = args.indexOf(name);
  return at === -1 ? null : args[at + 1] ?? null;
};
const WANTED_PARENT = flag('--parent');
const WANTED_STUDENT = flag('--student');

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

const isDeleted = (data) =>
  data?.deleted === true ||
  data?.isDeleted === true ||
  ['deleted', 'removed'].includes(norm(data?.status));

/** نسبة النتيجة كما تحسبها الواجهة: النسبة المخزّنة، أو الدرجة على الكلي. */
export function resultPercentage(result) {
  const stored = Number(result?.percentage);
  if (Number.isFinite(stored) && stored > 0) return Math.round(stored);
  const score = Number(result?.score ?? result?.correctAnswers ?? 0);
  const total = Number(result?.totalQuestions ?? result?.total ?? 0);
  if (!Number.isFinite(score) || !Number.isFinite(total) || total <= 0) return null;
  return Math.round((score / total) * 100);
}

/** أبناء وليّ الأمر بالقاعدة التي يطبّقها التطبيق: `parentId` وحده. */
export function childrenOf(students, parentId) {
  const wanted = norm(parentId);
  if (!wanted) return [];
  return students.filter((student) => norm(student?.parentId) === wanted);
}

/**
 * طلاب يحملون رقم جوال هذا الوليّ بلا `parentId` يربطهم به.
 * لا يراهم في لوحته، وهم سبب الشكوى الأشيع.
 */
export function orphansByPhone(students, parent) {
  const phone = norm(parent?.phoneNumber);
  if (!phone) return [];
  return students.filter(
    (student) =>
      norm(student?.parentPhoneNumber) === phone && norm(student?.parentId) === '',
  );
}

async function readAll(table) {
  const url = `${SUPABASE_URL}/rest/v1/${table}?select=id,data&limit=10000`;
  const response = await fetch(url, { headers: headers() });
  if (!response.ok) {
    throw new Error(`GET ${table} → ${response.status} ${(await response.text()).slice(0, 200)}`);
  }
  const rows = await response.json();
  return (Array.isArray(rows) ? rows : []).map((row) => ({
    ...(row?.data ?? {}),
    id: row?.data?.id ?? row?.id,
  }));
}

const line = (text = '') => console.log(text);
const head = (text) => {
  line();
  line(text);
  line('─'.repeat(58));
};

async function main() {
  if (!SUPABASE_URL || !SERVICE_KEY) {
    console.error('SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY مطلوبان.');
    process.exit(1);
  }
  if (!WANTED_PARENT && !WANTED_STUDENT) {
    console.error('الاستعمال: node scripts/diagnose-parent-visibility.mjs --parent <اسم المستخدم> | --student <اسم الطالب>');
    process.exit(1);
  }

  const [parents, students, quizResults, certificates, interactions] = await Promise.all([
    readAll('parents'),
    readAll('students'),
    readAll('quiz_results'),
    readAll('certificates'),
    readAll('interactions'),
  ]);

  // تحديد وليّ الأمر: باسمه أو رقمه أو معرّفه، أو عبر ابنه.
  let parent = null;
  if (WANTED_PARENT) {
    const wanted = norm(WANTED_PARENT);
    parent = parents.find((candidate) =>
      [candidate?.id, candidate?.username, candidate?.phoneNumber, candidate?.name]
        .some((value) => norm(value) === wanted),
    );
    if (!parent) {
      console.error(`لا يوجد وليّ أمر بهذا المعرّف: ${WANTED_PARENT}`);
      process.exit(1);
    }
  } else {
    const wanted = norm(WANTED_STUDENT);
    const student = students.find((candidate) =>
      [candidate?.id, candidate?.username, candidate?.name, candidate?.studentIdNumber]
        .some((value) => norm(value) === wanted),
    );
    if (!student) {
      console.error(`لا يوجد طالب بهذا المعرّف: ${WANTED_STUDENT}`);
      process.exit(1);
    }
    parent = parents.find((candidate) => norm(candidate?.id) === norm(student?.parentId));
    if (!parent) {
      head(`الطالب: ${student.name ?? '—'}  (id: ${student.id})`);
      line(`   parentId المسجَّل: ${student.parentId || '— لا شيء —'}`);
      line(`   جوال وليّ الأمر في سجلّ الطالب: ${student.parentPhoneNumber || '—'}`);
      line();
      line('⛔ هذا الطالب غير مربوط بأي وليّ أمر موجود، فلا لوحة تعرضه.');
      const byPhone = parents.filter(
        (candidate) => norm(candidate?.phoneNumber) === norm(student?.parentPhoneNumber),
      );
      if (byPhone.length === 1) {
        line(`   وفي الجدول وليٌّ برقم الجوال نفسه: «${byPhone[0].name}» (id: ${byPhone[0].id}).`);
        line('   العلاج: اضبط parentId للطالب على هذا المعرّف من لوحة المعلم أو المشرف.');
      } else if (byPhone.length > 1) {
        line(`   ورقم الجوال نفسه مسجَّل لـ ${byPhone.length} أولياء، فلا ربط تلقائي — اختر الصحيح يدوياً.`);
      }
      process.exit(1);
    }
  }

  head(`وليّ الأمر: ${parent.name ?? '—'}`);
  line(`   id: ${parent.id}`);
  line(`   اسم الدخول: ${parent.username ?? '—'}`);
  line(`   الجوال: ${parent.phoneNumber ?? '—'}`);

  const children = childrenOf(students, parent.id);
  const orphans = orphansByPhone(students, parent);

  head(`الأبناء الظاهرون في اللوحة: ${children.length}`);
  if (children.length === 0) {
    line('   ⛔ لا يظهر له أي ابن.');
  }

  for (const child of children) {
    const results = quizResults.filter(
      (result) => norm(result?.studentId) === norm(child.id) && !isDeleted(result),
    );
    const scored = results
      .map((result) => ({ result, percentage: resultPercentage(result) }))
      .filter((entry) => entry.percentage != null);
    const average = scored.length
      ? Math.round(scored.reduce((sum, entry) => sum + entry.percentage, 0) / scored.length)
      : null;
    const certs = certificates.filter(
      (certificate) => norm(certificate?.studentId) === norm(child.id) && !isDeleted(certificate),
    );
    const activity = interactions.filter(
      (item) => norm(item?.studentId) === norm(child.id),
    );

    line();
    line(`  👦 ${child.name ?? '—'}  (id: ${child.id})`);
    line(`     الصف: ${child.primaryGrade || child.grade || '— غير محدّد —'}`);
    line(`     المادة: ${child.subject || '—'}    المعلم: ${child.teacherId || '— غير مربوط —'}`);
    line(`     آخر نشاط: ${child.lastActivity ?? '—'}`);
    line(`     النقاط: ${child.points ?? 0}   الجواهر: ${child.gems ?? 0}   المستوى: ${child.level ?? 1}`);
    line(`     الاختبارات المكتملة: ${results.length}${average == null ? '' : `   المتوسط: ${average}%`}`);

    for (const { result, percentage } of scored.slice(-5)) {
      const when = result?.completedAt || result?.date || result?.createdAt || '—';
      line(`        • ${result?.subject ?? '—'} — ${result?.lessonName ?? result?.quizTitle ?? '—'}: ${percentage}%  (${when})`);
    }
    if (results.length > scored.length) {
      line(`        (و${results.length - scored.length} نتيجة بلا درجة محسوبة)`);
    }

    line(`     نقاط النشاط المسجَّلة: ${activity.length}`);
    line(`     الشهادات: ${certs.length}`);
    for (const certificate of certs) {
      line(`        🏅 ${certificate?.type ?? '—'} — ${certificate?.subject ?? '—'}  (${certificate?.issuedAt ?? certificate?.date ?? '—'})`);
    }

    // ما يراه الأب فارغاً وسببه في البيانات لا في الشاشة.
    if (!child.primaryGrade && !child.grade) {
      line('     ⚠️ بلا صف: شاشات المسار الأكاديمي ستظهر فارغة.');
    }
    if (!child.teacherId) {
      line('     ⚠️ بلا معلم: لن تظهر دروس أي معلم لهذا الابن.');
    }
  }

  if (orphans.length > 0) {
    head(`أبناء برقم جواله لكنهم غير مربوطين: ${orphans.length}`);
    line('   هؤلاء لا يظهرون في لوحته لأن الربط يقرأ parentId وحده.');
    for (const student of orphans) {
      line(`   • ${student.name ?? '—'} (id: ${student.id}) — parentId فارغ`);
    }
    line();
    line(`   العلاج: node scripts/migrate-parent-links.mjs   (يربطهم بـ parentId = ${parent.id})`);
  }

  head('الخلاصة');
  if (children.length === 0 && orphans.length === 0) {
    line('   لا أبناء له في قاعدة البيانات أصلاً — أضفهم من لوحة المعلم.');
  } else if (children.length === 0) {
    line('   البيانات موجودة والربط مفقود. شغّل migrate-parent-links.mjs.');
  } else {
    line('   ما طُبع أعلاه هو ما يجب أن تعرضه اللوحة. إن غاب عنها شيء منه،');
    line('   فالسبب نسخة المتصفح: اللوحة تسحب من الخادم عند الفتح وكل نصف');
    line('   دقيقة وعند العودة إلى التبويب، فتحديث الصفحة يكفي للتأكد.');
  }
  line();
}

if (process.argv[1] && process.argv[1].endsWith('diagnose-parent-visibility.mjs')) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
