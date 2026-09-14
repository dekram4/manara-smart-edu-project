#!/usr/bin/env node
/**
 * يدمج مدخلات الهيكل الأكاديمي المكرّرة داخل `app_kv`.
 *
 * ── أين يقع التكرار بالضبط ──
 * `app_kv` مفتاحها `key text primary key`، فلا يمكن أن يوجد صفّان لنفس
 * المفتاح إطلاقاً. التكرار داخل **قيمة** المفتاح: المصفوفة المخزّنة تحت
 * `smartEdu_hierarchicalConfigs` تحوي أكثر من مدخل لنفس الصف والمالك —
 * وهي النتيجة الطبيعية لدمج المزامنة (`mergeArrayRecords` يُلحق السجل
 * المحلي غير الموجود عن بُعد بدل أن يوحّده).
 *
 * والأثر: كل شاشة تحلّ المسار بـ `.find()` تقع على أوّل مدخل مطابق، فإن
 * كانت خريطة الدروس على الثاني عادت قائمة الدروس فارغة.
 *
 * الواجهة تعالج ذلك بالدمج **عند القراءة** (`readHierarchicalConfigs`)،
 * فالعطل غير ضارّ الآن. هذا السكريبت يعالج المخزون نفسه مرة واحدة.
 *
 * ── الضمانة ──
 * لا يُفقَد درس. الدمج يوحّد الأسماء ويضمّ خرائط الدروس من كل نسخة، ولا
 * يستبدل نسخة بأخرى. ويتحقّق السكريبت من ذلك بعد الكتابة: كل درس كان
 * موجوداً قبل الدمج يجب أن يبقى بعده، وإلا فشل وخرج بحالة خطأ.
 *
 * التشغيل:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
 *     node scripts/dedupe-academic-kv.mjs --dry-run
 *
 * ثم بلا العلم للتنفيذ.
 */

const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');

const SUPABASE_URL = process.env.SUPABASE_URL?.trim().replace(/\/+$/, '');
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

// الفحص داخل `main` لا في أعلى الوحدة: الوحدة تُستورَد في اختبار التطابق،
// وخروجٌ عند الاستيراد يُسقط الاختبار قبل أن يبدأ.
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

/** مفاتيح الهيكل الأكاديمي في `app_kv`. */
const ACADEMIC_KEYS = ['smartEdu_hierarchicalConfigs'];

// ─────────────────────────────────────────────────────────────
// منطق الدمج — منقول حرفياً عن `dedupeHierarchicalConfigs`
// في artifacts/manara/src/utils/academic.ts
//
// أي انحراف بين النسختين يعني أن السكريبت يكتب شجرةً تقرأها الواجهة
// بشكل مختلف. اختبار التطابق في المستودع يقارنهما على حالات متعدّدة.
// ─────────────────────────────────────────────────────────────
const cleanName = (value) => String(value ?? '').trim();
const normalizeScopeValue = (value) =>
  typeof value === 'string' ? value.trim().toLowerCase()
    : value == null ? '' : String(value).trim().toLowerCase();

const getRecordTeacherId = (record) => {
  if (!record || typeof record !== 'object') return '';
  return normalizeScopeValue(record.teacher_id) ||
    normalizeScopeValue(record.teacherId) ||
    normalizeScopeValue(record.createdBy);
};

const uniqueNames = (values) => {
  const seen = new Set();
  const result = [];
  values.forEach((value) => {
    const name = cleanName(value);
    const key = normalizeScopeValue(name);
    if (!name || seen.has(key)) return;
    seen.add(key);
    result.push(name);
  });
  return result;
};

export function dedupeHierarchicalConfigs(value) {
  if (!Array.isArray(value)) return [];

  const grouped = new Map();
  value.forEach((rawConfig) => {
    if (!rawConfig || typeof rawConfig !== 'object') return;
    const grade = cleanName(rawConfig.grade);
    if (!grade) return;

    const owner = getRecordTeacherId(rawConfig);
    const key = `${owner || 'admin'}::${normalizeScopeValue(grade)}`;
    if (!grouped.has(key)) {
      grouped.set(key, { ...rawConfig, grade, atrams: [] });
    }

    const target = grouped.get(key);
    const atrams = Array.isArray(rawConfig.atrams) ? rawConfig.atrams : [];
    const targetAtrams = Array.isArray(target.atrams) ? target.atrams : [];

    atrams.forEach((rawAtram) => {
      const atramName = cleanName(rawAtram?.atram);
      if (!atramName) return;
      let targetAtram = targetAtrams.find(
        (item) => normalizeScopeValue(item.atram) === normalizeScopeValue(atramName),
      );
      if (!targetAtram) {
        targetAtram = { atram: atramName, subjects: [] };
        targetAtrams.push(targetAtram);
      }

      const subjects = Array.isArray(rawAtram?.subjects) ? rawAtram.subjects : [];
      const targetSubjects = Array.isArray(targetAtram.subjects) ? targetAtram.subjects : [];
      subjects.forEach((rawSubject) => {
        const subjectName = cleanName(rawSubject?.subject);
        if (!subjectName) return;
        let targetSubject = targetSubjects.find(
          (item) => normalizeScopeValue(item.subject) === normalizeScopeValue(subjectName),
        );
        if (!targetSubject) {
          targetSubject = { subject: subjectName, terms: [] };
          targetSubjects.push(targetSubject);
        }

        const terms = Array.isArray(rawSubject?.terms) ? rawSubject.terms : [];
        const targetTerms = Array.isArray(targetSubject.terms) ? targetSubject.terms : [];
        terms.forEach((rawTerm) => {
          const termName = cleanName(rawTerm?.term);
          if (!termName) return;
          let targetTerm = targetTerms.find(
            (item) => normalizeScopeValue(item.term) === normalizeScopeValue(termName),
          );
          if (!targetTerm) {
            targetTerm = { term: termName, units: [] };
            targetTerms.push(targetTerm);
          }
          targetTerm.units = uniqueNames([
            ...(targetTerm.units || []),
            ...(Array.isArray(rawTerm?.units) ? rawTerm.units : []),
          ]);

          // الدروس تُضمّ ولا تُستبدل — هذه هي الضمانة التي يقوم عليها
          // السكريبت كله.
          const incomingLessons =
            rawTerm?.lessons && typeof rawTerm.lessons === 'object' ? rawTerm.lessons : null;
          if (incomingLessons) {
            const mergedLessons = { ...(targetTerm.lessons ?? {}) };
            Object.entries(incomingLessons).forEach(([unit, value]) => {
              const unitName = cleanName(unit);
              if (!unitName) return;
              const names = uniqueNames([
                ...(mergedLessons[unitName] ?? []),
                ...(Array.isArray(value) ? value : []),
              ]);
              if (names.length > 0) mergedLessons[unitName] = names;
            });
            if (Object.keys(mergedLessons).length > 0) {
              targetTerm.lessons = mergedLessons;
            }
          }
        });
        targetSubject.terms = targetTerms;
      });
      targetAtram.subjects = targetSubjects;
    });

    target.atrams = targetAtrams;
  });

  return Array.from(grouped.values());
}

// ─────────────────────────────────────────────────────────────
// جرد: كل درس في الشجرة بمساره الكامل — للمقارنة قبل/بعد
// ─────────────────────────────────────────────────────────────
export function collectLessonPaths(configs) {
  const paths = new Set();
  (Array.isArray(configs) ? configs : []).forEach((config) => {
    const owner = getRecordTeacherId(config) || 'admin';
    const grade = normalizeScopeValue(config?.grade);
    (config?.atrams || []).forEach((atram) => {
      (atram?.subjects || []).forEach((subject) => {
        (subject?.terms || []).forEach((term) => {
          const lessons = term?.lessons && typeof term.lessons === 'object' ? term.lessons : {};
          Object.entries(lessons).forEach(([unit, names]) => {
            (Array.isArray(names) ? names : []).forEach((name) => {
              if (!cleanName(name)) return;
              paths.add([
                owner, grade,
                normalizeScopeValue(atram?.atram),
                normalizeScopeValue(subject?.subject),
                normalizeScopeValue(term?.term),
                normalizeScopeValue(unit),
                normalizeScopeValue(name),
              ].join(' ▸ '));
            });
          });
        });
      });
    });
  });
  return paths;
}

/** عدد المدخلات المكرّرة: الفرق بين عدد المدخلات وعدد المجموعات الفريدة. */
function countDuplicates(configs) {
  const keys = new Map();
  (Array.isArray(configs) ? configs : []).forEach((config) => {
    if (!config || typeof config !== 'object') return;
    const grade = cleanName(config.grade);
    if (!grade) return;
    const key = `${getRecordTeacherId(config) || 'admin'}::${normalizeScopeValue(grade)}`;
    keys.set(key, (keys.get(key) || 0) + 1);
  });
  let duplicates = 0;
  for (const count of keys.values()) if (count > 1) duplicates += count - 1;
  return { groups: keys.size, duplicates, entries: Array.from(keys.entries()) };
}

async function readKey(key) {
  const url = new URL('/rest/v1/app_kv', SUPABASE_URL);
  url.searchParams.set('select', 'key,value');
  url.searchParams.set('key', `eq.${key}`);
  const response = await fetch(url, { headers: headers() });
  if (!response.ok) {
    throw new Error(`تعذّر قراءة ${key}: ${response.status} ${await response.text()}`);
  }
  const rows = await response.json();
  return rows[0]?.value ?? null;
}

async function writeKey(key, value) {
  const url = new URL('/rest/v1/app_kv', SUPABASE_URL);
  url.searchParams.set('on_conflict', 'key');
  const response = await fetch(url, {
    method: 'POST',
    headers: { ...headers(), Prefer: 'resolution=merge-duplicates,return=minimal' },
    body: JSON.stringify({ key, value, updated_at: new Date().toISOString() }),
  });
  if (!response.ok) {
    throw new Error(`تعذّر كتابة ${key}: ${response.status} ${await response.text()}`);
  }
}

async function main() {
  requireCredentials();
  let totalBefore = 0;
  let totalAfter = 0;
  let touched = 0;

  for (const key of ACADEMIC_KEYS) {
    const value = await readKey(key);
    console.log(`\n════════ ${key} ════════`);
    if (value === null) {
      console.log('المفتاح غير موجود — لا شيء ليُدمج.');
      continue;
    }
    if (!Array.isArray(value)) {
      console.log(`القيمة ليست مصفوفة (${typeof value}) — تُترك كما هي.`);
      continue;
    }

    const before = countDuplicates(value);
    const merged = dedupeHierarchicalConfigs(value);
    const after = countDuplicates(merged);

    const lessonsBefore = collectLessonPaths(value);
    const lessonsAfter = collectLessonPaths(merged);
    const lost = [...lessonsBefore].filter((p) => !lessonsAfter.has(p));

    totalBefore += value.length;
    totalAfter += merged.length;

    console.log(`المدخلات قبل الدمج    : ${value.length}`);
    console.log(`المدخلات بعد الدمج    : ${merged.length}`);
    console.log(`مجموعات فريدة        : ${before.groups}`);
    console.log(`مدخلات مكرّرة         : ${before.duplicates}`);
    console.log(`دروس قبل / بعد       : ${lessonsBefore.size} / ${lessonsAfter.size}`);

    if (before.duplicates > 0) {
      console.log('\nالمدخلات المكرّرة:');
      before.entries
        .filter(([, count]) => count > 1)
        .forEach(([groupKey, count]) => console.log(`  • ${groupKey} — ${count} نسخ`));
    }

    // الضمانة: لا يُفقَد درس. تُفحَص قبل الكتابة لا بعدها.
    if (lost.length > 0) {
      console.error(`\n❌ الدمج كان سيُسقط ${lost.length} درساً — أُلغيت العملية:`);
      lost.slice(0, 10).forEach((p) => console.error(`  • ${p}`));
      process.exit(1);
    }

    if (before.duplicates === 0) {
      console.log('\n✅ لا تكرار — لا حاجة للكتابة.');
      continue;
    }
    if (DRY_RUN) {
      console.log('\n(معاينة فقط — لم يُكتب شيء)');
      continue;
    }

    await writeKey(key, merged);
    touched++;
    console.log('\n✅ كُتبت الشجرة المدموجة.');

    // تحقّق بعدي من المخزون نفسه لا من الذاكرة.
    const saved = await readKey(key);
    const savedCount = countDuplicates(saved);
    const savedLessons = collectLessonPaths(saved);
    const stillLost = [...lessonsBefore].filter((p) => !savedLessons.has(p));
    if (savedCount.duplicates !== 0 || stillLost.length > 0) {
      console.error(
        `❌ التحقّق فشل — مكرّرات باقية: ${savedCount.duplicates}، دروس مفقودة: ${stillLost.length}`,
      );
      process.exit(1);
    }
    console.log(`✅ تحقّق: ${savedCount.groups} مدخلاً فريداً، ${savedLessons.size} درساً سليماً.`);
  }

  console.log('\n──────── الإجمالي ────────');
  console.log(`المدخلات قبل : ${totalBefore}`);
  console.log(`المدخلات بعد : ${totalAfter}`);
  console.log(`مفاتيح كُتبت  : ${DRY_RUN ? 0 : touched}${DRY_RUN ? ' (معاينة)' : ''}`);
}

// يُشغَّل فقط عند الاستدعاء المباشر، فيبقى قابلاً للاستيراد في الاختبار.
const invokedDirectly = process.argv[1] && import.meta.url.endsWith(
  process.argv[1].replace(/\\/g, '/').split('/').pop(),
);
if (invokedDirectly) {
  main().catch((error) => {
    console.error('فشل الدمج:', error.message);
    process.exit(1);
  });
}
