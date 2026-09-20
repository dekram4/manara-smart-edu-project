#!/usr/bin/env node
/**
 * يُزيل مستوى «الترم» (`atram`) من البيانات المخزّنة.
 *
 * ── ما الذي يتغيّر ──
 * الشجرة الأكاديمية كانت: صف → ترم → مادة → فصل → وحدة → درس.
 * وصارت: صف → مادة → فصل → وحدة → درس. أي أن `atrams: [{atram, subjects}]`
 * تُستبدل بـ `subjects: [...]` على الصف مباشرةً، بضمّ مواد كل «ترم» تحت
 * الصف. والمادة المكرّرة بين ترمين تُدمَج: فصولها ووحداتها ودروسها تُضمّ
 * ولا يُستبدل شيء بشيء.
 *
 * وفي بقية الجداول يُحذف الحقل `atram` وحده من `data`:
 *   lesson_configs   ← الدروس المنشورة
 *   created_quizzes  ← الاختبارات وأسئلتها
 *   quiz_results     ← نتائج الطلاب
 *   students         ← حقل الطالب وتسجيلاته
 *   interactions     ← تفاعلات المعلم الافتراضي وحلّ المسائل
 *
 * ── الضمانة ──
 * لا يُفقَد اسم. يُحصى قبل الكتابة كل اسم مادة وفصل ووحدة ودرس في الشجرة،
 * ويُعاد إحصاؤه بعدها؛ فإن نقص شيء توقّف السكريبت بحالة خطأ قبل أن يكتب
 * أي صفّ آخر. وما عدا الشجرة لا يُمسّ فيه إلا مفتاح `atram`.
 *
 * ── التشغيل ──
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
 *     node scripts/drop-atram.mjs --dry-run
 *
 * ثم بلا العلم للتنفيذ. خذ نسخة احتياطية أولاً: هذا السكريبت يكتب فوق
 * البيانات ولا يحتفظ بالشكل القديم.
 */

const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');

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

/** الجداول التي يُحذف منها الحقل وحده، بلا تغيير في الشكل. */
const FIELD_ONLY_TABLES = [
  'lesson_configs',
  'created_quizzes',
  'quiz_results',
  'students',
  'interactions',
];

const cleanName = (value) => String(value ?? '').trim();
const normalize = (value) =>
  typeof value === 'string' ? value.trim().toLowerCase()
    : value == null ? '' : String(value).trim().toLowerCase();

const uniqueNames = (values) => {
  const seen = new Set();
  const result = [];
  values.forEach((value) => {
    const name = cleanName(value);
    const key = normalize(name);
    if (!name || seen.has(key)) return;
    seen.add(key);
    result.push(name);
  });
  return result;
};

/**
 * مواد الصف بعد التسطيح: من `subjects` إن كانت موجودة، وإلا من مواد كل
 * «ترم». الصف المُرحَّل سلفاً يمرّ من هنا بلا تغيير، فالسكريبت يقبل إعادة
 * التشغيل.
 */
export function subjectsOfConfig(config) {
  if (Array.isArray(config?.subjects)) return config.subjects;
  if (!Array.isArray(config?.atrams)) return [];
  return config.atrams.flatMap((atram) =>
    Array.isArray(atram?.subjects) ? atram.subjects : [],
  );
}

/** يدمج فصلين يحملان الاسم نفسه: وحداتهما ودروسهما معاً. */
function mergeTerm(target, incoming) {
  target.units = uniqueNames([
    ...(Array.isArray(target.units) ? target.units : []),
    ...(Array.isArray(incoming?.units) ? incoming.units : []),
  ]);
  const incomingLessons =
    incoming?.lessons && typeof incoming.lessons === 'object' ? incoming.lessons : null;
  if (!incomingLessons) return;
  const merged = { ...(target.lessons ?? {}) };
  Object.entries(incomingLessons).forEach(([unit, names]) => {
    const unitName = cleanName(unit);
    if (!unitName) return;
    const list = uniqueNames([
      ...(merged[unitName] ?? []),
      ...(Array.isArray(names) ? names : []),
    ]);
    if (list.length > 0) merged[unitName] = list;
  });
  if (Object.keys(merged).length > 0) target.lessons = merged;
}

/** الشجرة بلا مستوى «الترم». */
export function dropAtramFromConfigs(value) {
  if (!Array.isArray(value)) return [];
  return value.map((rawConfig) => {
    if (!rawConfig || typeof rawConfig !== 'object') return rawConfig;
    const { atrams: _dropped, ...rest } = rawConfig;
    const subjects = [];
    subjectsOfConfig(rawConfig).forEach((rawSubject) => {
      const subjectName = cleanName(rawSubject?.subject);
      if (!subjectName) return;
      let target = subjects.find(
        (item) => normalize(item.subject) === normalize(subjectName),
      );
      if (!target) {
        target = { subject: subjectName, terms: [] };
        subjects.push(target);
      }
      const terms = Array.isArray(rawSubject?.terms) ? rawSubject.terms : [];
      terms.forEach((rawTerm) => {
        const termName = cleanName(rawTerm?.term);
        if (!termName) return;
        let targetTerm = target.terms.find(
          (item) => normalize(item.term) === normalize(termName),
        );
        if (!targetTerm) {
          targetTerm = { term: termName, units: [] };
          target.terms.push(targetTerm);
        }
        mergeTerm(targetTerm, rawTerm);
      });
    });
    return { ...rest, subjects };
  });
}

/** كل اسم في الشجرة، لمقارنة ما قبل الترحيل بما بعده. */
export function namesIn(configs) {
  const names = new Set();
  (Array.isArray(configs) ? configs : []).forEach((config) => {
    const grade = normalize(config?.grade);
    subjectsOfConfig(config).forEach((subject) => {
      const subjectName = normalize(subject?.subject);
      if (!subjectName) return;
      names.add(`${grade}|${subjectName}`);
      (Array.isArray(subject?.terms) ? subject.terms : []).forEach((term) => {
        const termName = normalize(term?.term);
        if (!termName) return;
        names.add(`${grade}|${subjectName}|${termName}`);
        (Array.isArray(term?.units) ? term.units : []).forEach((unit) => {
          if (normalize(unit)) names.add(`${grade}|${subjectName}|${termName}|${normalize(unit)}`);
        });
        const lessons = term?.lessons && typeof term.lessons === 'object' ? term.lessons : {};
        Object.entries(lessons).forEach(([unit, list]) => {
          (Array.isArray(list) ? list : []).forEach((lesson) => {
            if (normalize(lesson)) {
              names.add(
                `${grade}|${subjectName}|${termName}|${normalize(unit)}|${normalize(lesson)}`,
              );
            }
          });
        });
      });
    });
  });
  return names;
}

/** يحذف `atram` من كائن وكل ما بداخله، ويقول إن كان قد غيّر شيئاً. */
export function stripAtram(value) {
  if (Array.isArray(value)) {
    let changed = false;
    const next = value.map((item) => {
      const result = stripAtram(item);
      if (result.changed) changed = true;
      return result.value;
    });
    return { value: changed ? next : value, changed };
  }
  if (!value || typeof value !== 'object') return { value, changed: false };
  let changed = false;
  const next = {};
  for (const [key, item] of Object.entries(value)) {
    if (key === 'atram') {
      changed = true;
      continue;
    }
    const result = stripAtram(item);
    if (result.changed) changed = true;
    next[key] = result.value;
  }
  return { value: changed ? next : value, changed };
}

async function readJson(url) {
  const response = await fetch(url, { headers: headers() });
  if (!response.ok) {
    throw new Error(`GET ${url} → ${response.status} ${(await response.text()).slice(0, 200)}`);
  }
  return response.json();
}

async function patchRow(table, id, body) {
  const url = `${SUPABASE_URL}/rest/v1/${table}?id=eq.${encodeURIComponent(id)}`;
  const response = await fetch(url, {
    method: 'PATCH',
    headers: { ...headers(), Prefer: 'return=minimal' },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`PATCH ${table} ${id} → ${response.status} ${(await response.text()).slice(0, 200)}`);
  }
}

async function migrateHierarchy() {
  const rows = await readJson(
    `${SUPABASE_URL}/rest/v1/app_kv?select=key,value&key=eq.${encodeURIComponent(HIERARCHY_KEY)}`,
  );
  if (!Array.isArray(rows) || rows.length === 0) {
    console.log('• الشجرة الأكاديمية: لا يوجد مفتاح مخزّن.');
    return;
  }
  const before = rows[0].value;
  const after = dropAtramFromConfigs(before);

  const lost = [...namesIn(before)].filter((name) => !namesIn(after).has(name));
  if (lost.length > 0) {
    console.error('توقّف: الترحيل كان سيُسقط هذه الأسماء:');
    lost.slice(0, 20).forEach((name) => console.error(`   ${name}`));
    process.exit(1);
  }

  const grades = Array.isArray(after) ? after.length : 0;
  const subjects = Array.isArray(after)
    ? after.reduce((total, config) => total + (config?.subjects?.length ?? 0), 0)
    : 0;
  console.log(`• الشجرة الأكاديمية: ${grades} صفاً، ${subjects} مادة بعد التسطيح.`);

  if (DRY_RUN) return;
  const url = `${SUPABASE_URL}/rest/v1/app_kv?key=eq.${encodeURIComponent(HIERARCHY_KEY)}`;
  const response = await fetch(url, {
    method: 'PATCH',
    headers: { ...headers(), Prefer: 'return=minimal' },
    body: JSON.stringify({ value: after, updated_at: new Date().toISOString() }),
  });
  if (!response.ok) {
    throw new Error(`PATCH app_kv → ${response.status} ${(await response.text()).slice(0, 200)}`);
  }
}

async function migrateTable(table) {
  const rows = await readJson(`${SUPABASE_URL}/rest/v1/${table}?select=id,data&limit=10000`);
  if (!Array.isArray(rows)) return;
  let touched = 0;
  for (const row of rows) {
    const { value, changed } = stripAtram(row.data);
    if (!changed) continue;
    touched += 1;
    if (DRY_RUN) continue;
    await patchRow(table, row.id, { data: value, updated_at: new Date().toISOString() });
  }
  console.log(`• ${table}: ${touched} صفاً يحمل الحقل من أصل ${rows.length}.`);
}

async function main() {
  requireCredentials();
  console.log(DRY_RUN ? 'تجربة بلا كتابة (--dry-run)' : 'تنفيذ فعلي — تُكتب البيانات.');
  await migrateHierarchy();
  for (const table of FIELD_ONLY_TABLES) {
    await migrateTable(table);
  }
  console.log(DRY_RUN ? 'لم يُكتب شيء.' : 'تمّ.');
}

// يُستورَد في الاختبارات بلا تنفيذ.
if (process.argv[1] && process.argv[1].endsWith('drop-atram.mjs')) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
