import { HierarchicalConfig } from '../types';
import { getRecordTeacherId, normalizeScopeValue } from './scope';

const cleanName = (value: unknown): string => String(value ?? '').trim();

const uniqueNames = (values: unknown[]): string[] => {
  const seen = new Set<string>();
  const result: string[] = [];
  values.forEach(value => {
    const name = cleanName(value);
    const key = normalizeScopeValue(name);
    if (!name || seen.has(key)) return;
    seen.add(key);
    result.push(name);
  });
  return result;
};

/**
 * مواد الصف، من `subjects` مباشرةً.
 *
 * وكان بين الصف والمادة مستوىً يُعرض باسم «الترم» (`atrams`)، وقد أُزيل.
 * الإعدادات المحفوظة قبل الترحيل ما زالت تحمله، فتُقرأ هنا بتسطيح مواد كل
 * «ترم» تحت الصف — حتى لا تختفي مادة من شاشة معلم لم تُرحَّل بياناته بعد.
 */
export const subjectsOfConfig = (rawConfig: any): any[] => {
  if (Array.isArray(rawConfig?.subjects)) return rawConfig.subjects;
  if (!Array.isArray(rawConfig?.atrams)) return [];
  return rawConfig.atrams.flatMap((rawAtram: any) =>
    Array.isArray(rawAtram?.subjects) ? rawAtram.subjects : [],
  );
};

/**
 * Merge duplicate copies of the same academic configuration without merging
 * separate teacher-owned configurations. This also repairs duplicate nested
 * terms, subjects, and units created by older versions of the settings screen.
 */
export const dedupeHierarchicalConfigs = (value: unknown): HierarchicalConfig[] => {
  if (!Array.isArray(value)) return [];

  const grouped = new Map<string, HierarchicalConfig>();
  value.forEach((rawConfig: any) => {
    if (!rawConfig || typeof rawConfig !== 'object') return;
    const grade = cleanName(rawConfig.grade);
    if (!grade) return;

    const owner = getRecordTeacherId(rawConfig);
    const key = `${owner || 'admin'}::${normalizeScopeValue(grade)}`;
    const existing = grouped.get(key);
    if (!existing) {
      const { atrams: _legacyAtrams, ...rest } = rawConfig;
      grouped.set(key, {
        ...rest,
        grade,
        subjects: [],
      });
    }

    const target = grouped.get(key)!;
    const subjects = subjectsOfConfig(rawConfig);
    const targetSubjects = Array.isArray(target.subjects) ? target.subjects : [];

    subjects.forEach((rawSubject: any) => {
      const subjectName = cleanName(rawSubject?.subject);
      if (!subjectName) return;
      let targetSubject = targetSubjects.find(
        item => normalizeScopeValue(item.subject) === normalizeScopeValue(subjectName),
      );
      if (!targetSubject) {
        targetSubject = { subject: subjectName, terms: [] };
        targetSubjects.push(targetSubject);
      }

      const terms = Array.isArray(rawSubject?.terms) ? rawSubject.terms : [];
      const targetTerms = Array.isArray(targetSubject.terms) ? targetSubject.terms : [];
      terms.forEach((rawTerm: any) => {
        const termName = cleanName(rawTerm?.term);
        if (!termName) return;
        let targetTerm = targetTerms.find(
          item => normalizeScopeValue(item.term) === normalizeScopeValue(termName),
        );
        if (!targetTerm) {
          targetTerm = { term: termName, units: [] };
          targetTerms.push(targetTerm);
        }
        targetTerm.units = uniqueNames([
          ...(targetTerm.units || []),
          ...(Array.isArray(rawTerm?.units) ? rawTerm.units : []),
        ]);

        // الدروس تُدمج مع الوحدات ولا تُسقَط.
        //
        // هذه الدالة تعيد بناء كل فصل من الصفر، وكانت تنسخ `units` فقط —
        // فكل تحميل للإعدادات كان يمحو الدروس التي أدخلها المعلم أو
        // المشرف، ثم يُحفظ المحذوف فوق الأصل. الحقل اختياري، فالإعدادات
        // القديمة التي لا تحمل دروساً تبقى كما هي بلا مفتاح فارغ.
        const incomingLessons =
          rawTerm?.lessons && typeof rawTerm.lessons === 'object'
            ? (rawTerm.lessons as Record<string, unknown>)
            : null;
        if (incomingLessons) {
          const mergedLessons: Record<string, string[]> = {
            ...(targetTerm.lessons ?? {}),
          };
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

    target.subjects = targetSubjects;
  });

  return Array.from(grouped.values());
};
/**
 * يقرأ الشجرة الأكاديمية من التخزين المحلي **مدموجة**.
 *
 * السبب المباشر لوجودها: المصفوفة المخزّنة قد تحوي أكثر من مدخل لنفس الصف
 * والمالك — وهي النتيجة الطبيعية لدمج المزامنة (`mergeArrayRecords` يُلحق
 * السجل المحلي غير الموجود عن بُعد). وكل شاشة كانت تقرأ الخام ثم تحلّ
 * المسار بـ `.find()`، فتقع على **أول** مدخل مطابق. فإن كانت خريطة الدروس
 * على المدخل الثاني عادت قائمة الدروس فارغة.
 *
 * وشاشة «الإعدادات الأكاديمية» وحدها كانت تدمج وتعيد الكتابة، ولهذا كانت
 * زيارتها «تُصلح» القائمة — وهو العَرَض الذي أبلغ عنه المستخدم.
 *
 * القراءة المدموجة تجعل كل الشاشات ترى الشجرة نفسها من أول تحميل، بلا
 * اعتماد على ترتيب الزيارة.
 */
export const readHierarchicalConfigs = (
  storageKey = 'smartEdu_hierarchicalConfigs',
): HierarchicalConfig[] => {
  try {
    return dedupeHierarchicalConfigs(
      JSON.parse(localStorage.getItem(storageKey) || '[]'),
    );
  } catch {
    return [];
  }
};

/**
 * إعدادات الشجرة التي يملكها هذا المستخدم، ومعها إعدادات المشرف العامة.
 *
 * مصدر واحد لكل قائمة صفوف أو مواد في اللوحات. وكانت شاشات الحسابات تقرأ
 * قائمة `smartEdu_grades` المسطّحة، وهي نسخة جانبية لا تُكتب إلا حين يفتح
 * **المشرف** شاشة الإعدادات الأكاديمية — فالمعلم الذي يبني شجرته في شاشته
 * الخاصة لا يكتبها أبداً، فتبقى قائمة الصفوف فارغة عنده وعند طلابه في
 * نموذج الحساب. القراءة من الشجرة تزيل ذلك الوسيط.
 *
 * [teacherId] فارغ يعني مشرفاً: يرى كل الإعدادات.
 */
export const configsForOwner = (teacherId?: string): HierarchicalConfig[] => {
  const all = readHierarchicalConfigs();
  const owner = normalizeScopeValue(teacherId);
  if (!owner || owner === 'admin') return all;
  return all.filter(config => {
    const configOwner = getRecordTeacherId(config);
    return !configOwner || configOwner === 'admin' || configOwner === owner;
  });
};

/** الصفوف التي يملكها هذا المستخدم، بلا تكرار. */
export const gradesForOwner = (teacherId?: string): string[] =>
  Array.from(
    new Map(
      configsForOwner(teacherId).map(config => [
        normalizeScopeValue(config.grade),
        config.grade,
      ]),
    ).values(),
  ).filter(Boolean);

/** مواد صفٍّ بعينه، أو كل المواد إن لم يُحدَّد صف. */
export const subjectsForOwner = (teacherId?: string, grade?: string): string[] => {
  const wanted = normalizeScopeValue(grade);
  return Array.from(
    new Map(
      configsForOwner(teacherId)
        .filter(config => !wanted || normalizeScopeValue(config.grade) === wanted)
        .flatMap(config => subjectsOfConfig(config))
        .map((subject: any) => [
          normalizeScopeValue(subject?.subject),
          String(subject?.subject ?? ''),
        ]),
    ).values(),
  ).filter(Boolean);
};
