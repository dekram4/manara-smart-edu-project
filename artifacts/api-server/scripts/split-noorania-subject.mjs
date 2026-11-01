#!/usr/bin/env node
/**
 * يُثبّت «القاعدة النورانية» مادّةً مستقلّة في روضة منارة المعرفة، للمعلّم
 * داود سيد اكرام، وينقل إليها محتواها من «القرآن الكريم» — بلا أن يضيع شيء.
 *
 * ── ما كان ──
 * «القرآن الكريم» في الروضة فيه فصل «تعليم القاعدة النورانية» (ووحدة
 * «القاعدة النورانية»، ودرس «تعليم القراءة والقاعدة النورانية»). وأنشأ المعلّم
 * من حسابه مادّةً باسم «القاعدة النورانية» فلم تظهر في «إدارة المحتوى» ولا
 * «الإعدادات الأكاديمية».
 *
 * ── لماذا لا تظهر ──
 * الشاشتان تعرضان من الشجرة ما مالكُه (`teacher_id ?? teacherId ?? createdBy`)
 * يساوي معرّفَ المعلّم حرفياً. فمادّةٌ تحت مدخلٍ مالكُه اسمُه لا معرّفُه، أو
 * تحت صفٍّ آخر، أو في القائمة المسطّحة وحدها، أو بلا فصلٍ ولا درس — لا تُرى.
 * والمعاينةُ تطبع أين وُجدت بالضبط.
 *
 * ── ما يصير ──
 *   مدخلُ الروضة الذي مالكُه معرّفُ داود (تُدمج فيه مدخلاتُه الأخرى للصفّ نفسه)
 *     المادّة: القاعدة النورانية   (ما أنشأه المعلّم فيها يبقى)
 *       الفصل: القاعدة النورانية
 *         الوحدة: تعليم القراءة
 *           الدرس: القاعدة النورانية   (إن كان المنقولُ درساً واحداً؛ وإن كانت
 *                                      دروساً بقيت أسماؤها — لا يُدمج درسان)
 *   ويُنزع الفصلُ (أو الوحدة) من «القرآن الكريم» في كل مدخلٍ للروضة.
 *
 * ── لماذا لا يضيع شيء ──
 * محتوى الدرس كلُّه (النصّ، والأسئلة، والصوت، والروابط، والألعاب، وبنكُ
 * التحدّي) في `lesson_configs.data`، ومعرّفُ الصفّ (`id`) لا يتغيّر: يُكتب
 * السجلُّ كاملاً ولا يُبدَّل فيه إلا مسارُه ومالكُه. فكلُّ ما يُربط بالمعرّف —
 * تقدّمُ الطلاب ومكافآتُهم، وألعابُ الدرس، وسجلُّ المشاهدة — يبقى كما هو.
 *
 * وما يُربط بالأسماء يُحدَّث معه:
 *   • الشجرة (`app_kv.smartEdu_hierarchicalConfigs`).
 *   • القوائم المسطّحة (`smartEdu_subjects` و`smartEdu_terms` و`smartEdu_units`)
 *     إن كانت مخزونة: تُضاف الأسماءُ الجديدة، ويُحذف القديمُ الذي لم يبقَ له أثر.
 *   • الدروس والاختبارات المنشأة: المسار، والمالكُ معرّفُ داود.
 *   • الطلاب: طالبُ الروضة الذي أُسندت إليه «القرآن الكريم» تُسند إليه المادّة،
 *     ويُنقل مسارُه المحفوظ.
 *   • سجلُّ المعلّم داود: تُضاف المادّةُ إلى موادّه.
 *   • ختمُ المحتوى، ليأخذ كلُّ جهازٍ النسخةَ الجديدة.
 * والمشرفُ يرى الشجرةَ كلَّها أصلاً، فلا يحتاج ربطاً.
 *
 * ── الأمان ──
 * المعاينةُ أوّلاً ولا كتابة فيها. وقبل أيّ كتابةٍ تُحفظ نسخةٌ كاملة من كلّ
 * صفٍّ سيُمسّ في `backups/`. والتنفيذُ يعيد القراءة ويتحقّق. وتشغيلُه مرّتين
 * لا يكرّر شيئاً.
 *
 * التشغيل — المعاينة:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
 *     node scripts/split-noorania-subject.mjs
 * ثم أضف --execute للتنفيذ. وإن تعدّد من اسمُه «داود سيد اكرام» فـ
 *   --teacher-id=<المعرّف>
 */

import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export const GRADE = "روضة منارة المعرفة";
export const TEACHER_NAME = "داود سيد اكرام";
export const OLD_SUBJECT = "القرآن الكريم";
export const NEW_SUBJECT = "القاعدة النورانية";
export const NEW_TERM = "القاعدة النورانية";
export const NEW_UNIT = "تعليم القراءة";
export const NEW_LESSON = "القاعدة النورانية";

const HIERARCHY_KEY = "smartEdu_hierarchicalConfigs";
const SUBJECTS_KEY = "smartEdu_subjects";
const TERMS_KEY = "smartEdu_terms";
const UNITS_KEY = "smartEdu_units";
const EPOCH_KEY = "smartEdu_contentEpoch";

const text = (value) => (value == null ? "" : String(value).trim());

/** تسويةٌ عربية للمقارنة وحدها — كما في `rebuild-academic-tree.mjs`. */
export function norm(value) {
  return text(value)
    .toLowerCase()
    .replace(/[ً-ْٰـ]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/\s+/g, " ")
    .trim();
}

/** المقارنةُ التي تجريها شاشاتُ الويب (`normalizeScopeValue`): حرفيّةٌ إلا الحالة. */
const scope = (value) => text(value).toLowerCase();

export function asArray(value) {
  if (Array.isArray(value)) return value;
  if (value && typeof value === "object" && Array.isArray(value.value)) return value.value;
  if (typeof value === "string" && value.trim()) {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
  return [];
}

export const isKg = (grade) => norm(grade) === norm(GRADE) || norm(grade).includes("روضه");
export const isQuran = (subject) => norm(subject) === norm(OLD_SUBJECT);
export const isNew = (subject) => norm(subject) === norm(NEW_SUBJECT);
/** فصلٌ أو وحدةٌ للنورانية: «تعليم القاعدة النورانية» أو ما فيه «نوراني». */
export const isNoorania = (name) => norm(name).includes("نوراني");

/** المالكُ كما تقرؤه شاشات الويب: `teacher_id ?? teacherId ?? createdBy`. */
const rawOwner = (record) => text(record?.teacher_id ?? record?.teacherId ?? record?.createdBy);
const ownerOf = (record) => norm(rawOwner(record)) || "admin";

// ─────────────────────────────────────────────────────────────────────
// المعلّم
// ─────────────────────────────────────────────────────────────────────

/**
 * داود من جدول المعلّمين: `{id, name, identities, row}` — المعرّفُ الذي
 * تقارن به شاشاتُه، وكلُّ ما يُعرف به (المعرّف، واسم الدخول، والاسم) مسوّىً.
 * يرمي إن لم يوجد أو تعدّد، إلا أن يُعطى [teacherId].
 */
export function findTeacher(rows, teacherId = "") {
  const all = rows.map((row) => {
    const data = row?.data && typeof row.data === "object" ? row.data : {};
    const id = text(data.id) || text(row?.id);
    const names = [row?.id, data.id, data.username, data.name].map(norm).filter(Boolean);
    return { id, name: text(data.name) || id, identities: new Set(names), row };
  });
  const matches = teacherId
    ? all.filter((t) => t.identities.has(norm(teacherId)))
    : all.filter((t) => norm(t.name).includes(norm(TEACHER_NAME)));
  if (matches.length === 1) return matches[0];
  if (!matches.length) throw new Error(`لم يوجد المعلّم «${teacherId || TEACHER_NAME}» في جدول المعلّمين.`);
  throw new Error(
    `أكثرُ من معلّمٍ يطابق «${TEACHER_NAME}»: ${matches.map((t) => `${t.id} (${t.name})`).join("، ")}. حدّد واحداً بـ --teacher-id=`,
  );
}

const isTeachers = (teacher) => (record) => teacher.identities.has(ownerOf(record));
/** مالكُه داود بالمعرّف الذي تقارن به شاشاتُه — فيُرى فيها. */
const isCanonical = (teacher) => (record) => scope(rawOwner(record)) === scope(teacher.id);

/** السجلُّ مملوكاً لداود بمعرّفه — `null` إن كان كذلك من قبل. */
export function withOwner(data, teacher) {
  if (isCanonical(teacher)(data)) return null;
  const next = { ...data, teacher_id: teacher.id };
  if ("teacherId" in data) next.teacherId = teacher.id;
  return next;
}

// ─────────────────────────────────────────────────────────────────────
// الشجرة
// ─────────────────────────────────────────────────────────────────────

const unitsOf = (term) => {
  const units = Array.isArray(term?.units) ? term.units.map(text).filter(Boolean) : [];
  const byUnit = term?.lessons && typeof term.lessons === "object" ? term.lessons : {};
  return [...units, ...Object.keys(byUnit).filter((u) => !units.includes(u))];
};
const lessonsOf = (term, unit) => (Array.isArray(term?.lessons?.[unit]) ? term.lessons[unit].map(text).filter(Boolean) : []);
const lessonCount = (subject) =>
  (subject?.terms ?? []).reduce((n, term) => n + unitsOf(term).reduce((m, u) => m + lessonsOf(term, u).length, 0), 0);

function addLessons(term, unit, lessons) {
  const name = term.units.find((u) => norm(u) === norm(unit)) ?? unit;
  if (!term.units.some((u) => norm(u) === norm(unit))) term.units.push(name);
  const have = term.lessons[name] ?? [];
  term.lessons[name] = [...have, ...lessons.filter((l) => !have.some((h) => norm(h) === norm(l)))];
}

/** يضمّ [from] إلى [into] (مادّتين باسمٍ واحد): الفصولُ والوحداتُ والدروسُ اتّحاداً. */
function mergeSubject(into, from) {
  into.terms ??= [];
  for (const term of from?.terms ?? []) {
    if (!term || !text(term.term)) continue;
    let target = into.terms.find((t) => norm(t.term) === norm(term.term));
    if (!target) into.terms.push((target = { ...term, term: text(term.term), units: [], lessons: {} }));
    target.units = Array.isArray(target.units) ? target.units : [];
    target.lessons = target.lessons && typeof target.lessons === "object" ? target.lessons : {};
    for (const unit of unitsOf(term)) addLessons(target, unit, lessonsOf(term, unit));
  }
}

/**
 * الشجرةُ بعد التثبيت والنقل. لا تُغيّر [input].
 *
 * يعيد `{configs, moved, notes}`:
 *   moved  ما نُزع من «القرآن الكريم»: مالكُه وصفُّه ودروسُه وما صارت إليه.
 *   notes  ما يستحقّ نظرَ صاحب البيانات (مدخلاتٌ دُمجت، مالكٌ صُحّح، نسخٌ
 *          نُقلت، نسخٌ فيها محتوى لغيره بقيت مكانها).
 */
export function splitTree(input, teacher) {
  const configs = structuredClone(input);
  const notes = [];
  const moved = [];
  const mine = isTeachers(teacher);
  const canonical = isCanonical(teacher);
  const valid = (c) => c && typeof c === "object" && Array.isArray(c.subjects);

  // ١. يُنزع ما للنورانية من «القرآن الكريم» في كل مدخلٍ للروضة — أيّاً كان مالكه.
  let quranGrade = "";
  for (const config of configs) {
    if (!valid(config) || !isKg(config.grade)) continue;
    for (const quran of config.subjects.filter((s) => s && isQuran(s.subject))) {
      const terms = Array.isArray(quran.terms) ? quran.terms : [];
      const lessons = [];
      const keep = [];
      for (const term of terms) {
        if (term && isNoorania(term.term)) {
          for (const unit of unitsOf(term)) for (const lesson of lessonsOf(term, unit)) lessons.push({ term: text(term.term), unit, lesson });
          continue;
        }
        // ‏وحدةُ نورانيةٍ تحت فصلٍ آخر من القرآن: تُنزع الوحدةُ وحدها.
        for (const unit of unitsOf(term).filter(isNoorania)) {
          for (const lesson of lessonsOf(term, unit)) lessons.push({ term: text(term.term), unit, lesson });
          term.units = (term.units ?? []).filter((u) => norm(u) !== norm(unit));
          if (term.lessons) delete term.lessons[unit];
          lessons.touched = true;
        }
        keep.push(term);
      }
      if (lessons.length || lessons.touched || keep.length !== terms.length) {
        quran.terms = keep;
        quranGrade ||= text(config.grade);
        moved.push({ owner: ownerOf(config), grade: text(config.grade), lessons: [...lessons] });
      }
    }
  }

  const all = moved.flatMap((m) => m.lessons);
  const unique = all.filter((l, i) => all.findIndex((o) => norm(o.lesson) === norm(l.lesson)) === i);
  const single = unique.length <= 1;
  for (const l of all) l.to = single ? NEW_LESSON : l.lesson;

  // ٢. مدخلُ داود للروضة: الذي مالكُه معرّفُه — وإلا أوّلُ مدخلٍ له بأيّ اسم، وإلا جديد.
  const kgOfTeacher = configs.filter((c) => valid(c) && isKg(c.grade) && mine(c));
  const preferGrade = (list) => list.find((c) => norm(c.grade) === norm(GRADE)) ?? list[0];
  let target = preferGrade(kgOfTeacher.filter(canonical)) ?? preferGrade(kgOfTeacher);
  if (target && !canonical(target)) {
    notes.push(`مدخلُ «${text(target.grade)}» لداود مالكُه «${rawOwner(target)}» لا معرّفُه — صار «${teacher.id}» ليظهر في شاشاته.`);
    target.teacher_id = teacher.id;
    if ("teacherId" in target) target.teacherId = teacher.id;
  }
  if (!target) {
    target = {
      grade: quranGrade || GRADE,
      subjects: [],
      teacher_id: teacher.id,
      createdBy: teacher.id,
      createdByName: teacher.name,
      createdAt: new Date().toISOString(),
    };
    configs.push(target);
    notes.push(`لا مدخلَ لداود في الروضة — أُنشئ له «${target.grade}».`);
  }

  // ‏مادّةٌ كانت في مدخله من قبل تبقى في موضعها؛ وما سواها بعد «القرآن الكريم».
  const placed = target.subjects.some((s) => s && isNew(s.subject));

  // ‏مدخلاتُه الأخرى للصفّ نفسه (بمالكٍ آخر يدلّ عليه): تُدمج فيه، فلا يبقى
  // ‏شيءٌ له مخفيّاً عن شاشاته.
  const sameGrade = kgOfTeacher.filter((c) => c !== target && norm(c.grade) === norm(target.grade));
  for (const other of sameGrade) {
    for (const subject of other.subjects) {
      if (!subject || !text(subject.subject)) continue;
      let into = target.subjects.find((s) => s && norm(s.subject) === norm(subject.subject));
      if (!into) target.subjects.push((into = { subject: text(subject.subject), terms: [] }));
      mergeSubject(into, subject);
    }
    notes.push(`دُمج مدخلُ «${text(other.grade)}» بمالكه «${rawOwner(other)}» في مدخل داود.`);
  }

  // ٣. نسخُ «القاعدة النورانية» خارج مدخل داود: تُضمّ إليه إن كانت لداود في
  // ‏الروضة أو فارغة؛ وما فيه محتوى لغيره يبقى ويُذكر.
  const collected = [];
  const emptied = [];
  for (const config of configs) {
    if (!valid(config) || config === target || sameGrade.includes(config)) continue;
    const copies = config.subjects.filter((s) => s && isNew(s.subject));
    if (!copies.length) continue;
    const take = copies.filter((s) => (isKg(config.grade) && mine(config)) || lessonCount(s) === 0);
    for (const s of copies.filter((c) => !take.includes(c))) {
      notes.push(`«${NEW_SUBJECT}» في «${text(config.grade)}» لـ«${rawOwner(config) || "admin"}» فيها ${lessonCount(s)} درساً — بقيت مكانها.`);
    }
    if (!take.length) continue;
    collected.push(...take);
    config.subjects = config.subjects.filter((s) => !take.includes(s));
    notes.push(`نُقلت «${NEW_SUBJECT}» من «${text(config.grade)}» (${rawOwner(config) || "admin"}) إلى مدخل داود.`);
    if (mine(config) && !config.subjects.length) emptied.push(config);
  }
  const drop = new Set([...sameGrade, ...emptied]);

  // ٤. المادّة في مدخل داود: بعد «القرآن الكريم» إن كانت جديدة.
  let subject = target.subjects.find((s) => s && isNew(s.subject)) ?? { subject: NEW_SUBJECT, terms: [] };
  if (!placed) {
    target.subjects = target.subjects.filter((s) => s !== subject);
    const quran = target.subjects.findIndex((s) => s && isQuran(s.subject));
    target.subjects.splice(quran >= 0 ? quran + 1 : target.subjects.length, 0, subject);
  }
  for (const copy of collected) mergeSubject(subject, copy);
  subject.terms ??= [];
  // ‏مادّةٌ بلا فصلٍ لا يُضاف لها درسٌ من شاشة المحتوى: تأخذ الفصلَ والوحدة
  // ‏ولو لم يكن ما يُنقل.
  if (all.length || !subject.terms.length) {
    let term = subject.terms.find((t) => norm(t.term) === norm(NEW_TERM));
    if (!term) subject.terms.push((term = { term: NEW_TERM, units: [], lessons: {} }));
    term.units = Array.isArray(term.units) ? term.units : [];
    term.lessons = term.lessons && typeof term.lessons === "object" ? term.lessons : {};
    addLessons(term, NEW_UNIT, all.length ? (single ? [NEW_LESSON] : unique.map((l) => l.to)) : []);
  }

  return { configs: configs.filter((c) => !drop.has(c)), moved, notes };
}

/** أسماءُ الشجرة كلّها، مسوّاة: الموادّ والفصول والوحدات. */
export function namesIn(configs) {
  const subjects = new Set();
  const terms = new Set();
  const units = new Set();
  for (const config of configs) {
    for (const s of Array.isArray(config?.subjects) ? config.subjects : []) {
      subjects.add(norm(s?.subject));
      for (const t of s?.terms ?? []) {
        terms.add(norm(t?.term));
        for (const u of unitsOf(t)) units.add(norm(u));
      }
    }
  }
  return { subjects, terms, units };
}

/**
 * قائمةٌ مسطّحة بعد التحديث: يُضاف [add]، ويُحذف منها اسمُ نورانيةٍ قديم لم
 * يبقَ في الشجرة ([present]). `null` إن لم تتغيّر.
 */
export function updateFlat(list, add, present) {
  if (!Array.isArray(list)) return null;
  const kept = list.filter((name) => typeof name !== "string" || !isNoorania(name) || norm(name) === norm(add) || present.has(norm(name)));
  const next = kept.some((name) => norm(name) === norm(add)) ? kept : [...kept, add];
  return JSON.stringify(next) === JSON.stringify(list) ? null : next;
}

// ─────────────────────────────────────────────────────────────────────
// الدروس والطلاب والمعلّم
// ─────────────────────────────────────────────────────────────────────

/**
 * مسارُ درسٍ من نورانية «القرآن الكريم» بعد النقل، أو `null` إن لم يكن منها.
 * [renames]: الاسمُ القديم (مسوّىً) ← الجديد.
 */
export function movedPath(data, renames) {
  if (!data || !isKg(data.grade) || !isQuran(data.subject)) return null;
  if (!isNoorania(data.term) && !isNoorania(data.unit)) return null;
  const lesson = text(data.lesson ?? data.lessonName);
  const to = renames.get(norm(lesson)) ?? lesson;
  return { subject: NEW_SUBJECT, term: NEW_TERM, unit: NEW_UNIT, lesson: to, from: lesson };
}

/** السجلُّ كاملاً بمساره الجديد — `PATCH` على `data` يستبدلها كلَّها. */
export function withPath(data, path) {
  const next = { ...data, subject: path.subject, term: path.term, unit: path.unit };
  if ("lesson" in data) next.lesson = path.lesson;
  if ("lessonName" in data) next.lessonName = path.lesson;
  // ‏حقولٌ أخرى تحمل الاسمَ نفسه (عنوانٌ يساوي اسمَ الدرس القديم) تتبعه.
  if (text(data.title) && norm(data.title) === norm(path.from)) next.title = path.lesson;
  if ("chapter" in data && isNoorania(data.chapter)) next.chapter = path.term;
  return next;
}

/**
 * سجلُّ طالب: طالبُ الروضة (أو بلا صفٍّ مسجّل) الذي أُسندت إليه «القرآن
 * الكريم» تُسند إليه المادّةُ الجديدة، ويُنقل مسارُه المحفوظ إن كان في
 * النورانية. `null` إن لم يتغيّر فيه شيء.
 */
export function updateStudent(data, renames) {
  if (!data || typeof data !== "object") return null;
  let changed = false;
  const next = { ...data };
  const kgStudent = !text(data.grade) || isKg(data.grade);
  for (const key of ["assignedSubjects", "assigned_subjects"]) {
    const list = data[key];
    if (!kgStudent || !Array.isArray(list)) continue;
    const names = list.map((s) => (typeof s === "string" ? s : s?.name ?? s?.subject));
    if (names.some(isQuran) && !names.some(isNew)) {
      next[key] = [...list, typeof list[0] === "string" ? NEW_SUBJECT : { ...list[0], name: NEW_SUBJECT, subject: NEW_SUBJECT }];
      changed = true;
    }
  }
  const last = data.lastPath;
  if (last && typeof last === "object") {
    const path = movedPath(last, renames);
    if (path) {
      next.lastPath = withPath(last, path);
      changed = true;
    }
  }
  // ‏المسارُ في جذر السجلّ (subject/term/unit) كما يحفظه بعضُ المعلّمين.
  const root = movedPath({ ...data, lesson: data.lesson ?? "" }, renames);
  if (root) {
    next.subject = root.subject;
    next.term = root.term;
    next.unit = root.unit;
    if (text(data.lesson)) next.lesson = root.lesson;
    changed = true;
  }
  return changed ? next : null;
}

/** سجلُّ داود: تُضاف المادّةُ إلى قوائم موادّه. `null` إن كانت فيها. */
export function updateTeacher(data) {
  if (!data || typeof data !== "object") return null;
  let next = null;
  for (const key of ["subjects", "assignedSubjects"]) {
    const list = data[key];
    if (!Array.isArray(list)) continue;
    const names = list.map((s) => (typeof s === "string" ? s : s?.name ?? s?.subject));
    if (names.some(isNew)) continue;
    next ??= { ...data };
    next[key] = [...list, list.length && typeof list[0] !== "string" ? { name: NEW_SUBJECT, subject: NEW_SUBJECT } : NEW_SUBJECT];
  }
  return next;
}

// ─────────────────────────────────────────────────────────────────────
// التشغيل
// ─────────────────────────────────────────────────────────────────────

const args = process.argv.slice(2);
const EXECUTE = args.includes("--execute");
const TEACHER_ID = text(args.find((a) => a.startsWith("--teacher-id="))?.slice("--teacher-id=".length));
const SUPABASE_URL = process.env.SUPABASE_URL?.trim().replace(/\/+$/, "");
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

const headers = () => ({
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  "Content-Type": "application/json",
});

async function readJson(path) {
  const response = await fetch(`${SUPABASE_URL}${path}`, { headers: headers() });
  if (!response.ok) throw new Error(`GET ${path} → ${response.status} ${(await response.text()).slice(0, 200)}`);
  return response.json();
}

async function readOptional(path) {
  try {
    return await readJson(path);
  } catch (error) {
    console.log(`  (تُرك: ${String(error.message).slice(0, 120)})`);
    return [];
  }
}

async function putKv(key, value, stamp) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/app_kv?on_conflict=key`, {
    method: "POST",
    headers: { ...headers(), Prefer: "resolution=merge-duplicates,return=minimal" },
    body: JSON.stringify({ key, value, updated_at: stamp }),
  });
  if (!response.ok) throw new Error(`POST ${key} → ${response.status} ${(await response.text()).slice(0, 300)}`);
}

async function patchRow(table, id, data, stamp) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${table}?id=eq.${encodeURIComponent(id)}`, {
    method: "PATCH",
    headers: { ...headers(), Prefer: "return=minimal" },
    body: JSON.stringify({ data, updated_at: stamp }),
  });
  if (!response.ok) {
    // ‏جدولٌ بلا عمود `updated_at`: بالبيانات وحدها.
    const retry = await fetch(`${SUPABASE_URL}/rest/v1/${table}?id=eq.${encodeURIComponent(id)}`, {
      method: "PATCH",
      headers: { ...headers(), Prefer: "return=minimal" },
      body: JSON.stringify({ data }),
    });
    if (!retry.ok) throw new Error(`PATCH ${table}/${id} → ${retry.status} ${(await retry.text()).slice(0, 300)}`);
  }
}

const line = (t = "") => console.log(t);
const head = (t) => {
  line();
  line(`════ ${t} ════`);
};

/** أين «القاعدة النورانية» الآن — ولماذا لا تظهر. */
function diagnose(configs, flat, teacher) {
  let found = 0;
  for (const config of configs) {
    for (const s of Array.isArray(config?.subjects) ? config.subjects : []) {
      if (!s || !isNew(s.subject)) continue;
      found++;
      const where = isCanonical(teacher)(config)
        ? "معرّفُ داود: تراها شاشاتُه"
        : isTeachers(teacher)(config)
          ? "اسمٌ آخر لداود: لا تراها شاشاتُه"
          : "ليس داود";
      line(`  • في «${text(config.grade)}» — المالك «${rawOwner(config) || "admin"}» (${where}) — ${(s.terms ?? []).length} فصلاً، ${lessonCount(s)} درساً.`);
    }
  }
  if (!found) line("  • ليست في الشجرة أصلاً.");
  if (flat.some(isNew)) line(`  • في القائمة المسطّحة ${SUBJECTS_KEY}.`);
  const kg = configs.filter((c) => isKg(c?.grade) && isTeachers(teacher)(c));
  line(`  مدخلاتُ داود للروضة: ${kg.map((c) => `«${text(c.grade)}» بمالك «${rawOwner(c)}»`).join("، ") || "لا شيء"}.`);
}

async function main() {
  if (!SUPABASE_URL || !SERVICE_KEY) {
    console.error("يلزم SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY.");
    process.exit(1);
  }
  line(EXECUTE ? "التنفيذ: ستُكتب التغييرات." : "معاينةٌ فقط — لا كتابة. أضف --execute للتنفيذ.");

  head("القراءة");
  const keys = [HIERARCHY_KEY, SUBJECTS_KEY, TERMS_KEY, UNITS_KEY];
  const kv = await readJson(`/rest/v1/app_kv?select=key,value&key=in.(${keys.map(encodeURIComponent).join(",")})`);
  const row = (key) => kv.find((r) => r.key === key);
  const configs = asArray(row(HIERARCHY_KEY)?.value);
  const lessons = await readJson("/rest/v1/lesson_configs?select=id,data&limit=20000");
  const quizzes = await readOptional("/rest/v1/created_quizzes?select=id,data&limit=20000");
  const students = await readOptional("/rest/v1/students?select=id,data&limit=20000");
  const teachers = await readJson("/rest/v1/teachers?select=id,data&limit=5000");
  line(`الشجرة: ${configs.length} مدخلاً. الدروس: ${lessons.length}. الاختبارات: ${quizzes.length}. الطلاب: ${students.length}. المعلّمون: ${teachers.length}.`);

  const teacher = findTeacher(teachers, TEACHER_ID);
  line(`المعلّم: ${teacher.name} — المعرّف «${teacher.id}» (يُعرف أيضاً بـ: ${[...teacher.identities].join("، ")}).`);

  head(`أين «${NEW_SUBJECT}» الآن`);
  diagnose(configs, asArray(row(SUBJECTS_KEY)?.value), teacher);

  head("الشجرة");
  const { configs: nextConfigs, moved, notes } = splitTree(configs, teacher);
  const renames = new Map();
  if (!moved.length) line(`لا نورانيةَ تحت «${OLD_SUBJECT}» في الروضة (أو نُقلت من قبل).`);
  for (const entry of moved) {
    line(`من «${OLD_SUBJECT}» في «${entry.grade}» (المالك ${entry.owner}):`);
    for (const l of entry.lessons) {
      line(`  • ${l.term} / ${l.unit} / ${l.lesson}  ←  ${NEW_SUBJECT} / ${NEW_TERM} / ${NEW_UNIT} / ${l.to}`);
      renames.set(norm(l.lesson), l.to);
    }
  }
  for (const note of notes) line(`  ◦ ${note}`);
  const treeChanged = JSON.stringify(nextConfigs) !== JSON.stringify(configs);

  head("الدروس (lesson_configs)");
  const lessonChanges = [];
  const candidates = lessons.filter((r) => movedPath(r.data, renames));
  for (const r of candidates) {
    const path = movedPath(r.data, renames);
    // ‏درسٌ في الجدول لم تذكره الشجرة: يصير «القاعدة النورانية» إن كان وحده،
    // ‏وإلا بقي اسمُه — لا يُسمّى درسان باسمٍ واحد.
    if (!renames.has(norm(path.from))) path.lesson = candidates.length === 1 ? NEW_LESSON : path.from;
    const next = withPath(r.data, path);
    lessonChanges.push({ row: r, next: withOwner(next, teacher) ?? next });
    line(`  • ${r.id}: «${path.from}» ← «${path.lesson}» — المالك «${rawOwner(r.data) || "admin"}» ← «${teacher.id}»`);
  }
  // ‏دروسُ المادّة التي أنشأها داود بنفسه، بمالكٍ لا تراه شاشاتُه.
  for (const r of lessons) {
    if (!isKg(r.data?.grade) || !isNew(r.data?.subject) || !isTeachers(teacher)(r.data)) continue;
    const next = withOwner(r.data, teacher);
    if (!next) continue;
    lessonChanges.push({ row: r, next });
    line(`  • ${r.id}: «${text(r.data.lesson)}» — المالك «${rawOwner(r.data)}» ← «${teacher.id}»`);
  }
  line(`سيُحدَّث ${lessonChanges.length} درساً.`);
  for (const r of lessons) {
    if (isKg(r.data?.grade) && isQuran(r.data?.subject) && !movedPath(r.data, renames) && isNoorania(r.data?.lesson ?? r.data?.lessonName)) {
      line(`  ⚠ ${r.id}: «${text(r.data.lesson)}» تحت «${text(r.data.term)}» من القرآن — اسمُه نورانيّ وفصلُه لا؛ لم يُنقل.`);
    }
  }

  head("الاختبارات (created_quizzes)");
  const quizChanges = [];
  const movedIds = new Set(lessonChanges.map((c) => c.row.id));
  for (const r of quizzes) {
    const data = r.data ?? {};
    const byId = movedIds.has(text(data.lessonId ?? data.lesson_id));
    const path = movedPath(data, renames);
    if (!path && !byId) continue;
    const target =
      path ??
      (isQuran(data.subject)
        ? { subject: NEW_SUBJECT, term: NEW_TERM, unit: NEW_UNIT, lesson: renames.get(norm(data.lesson)) ?? (text(data.lesson) || NEW_LESSON), from: text(data.lesson) }
        : null);
    const next = target ? withPath(data, target) : data;
    const owned = withOwner(next, teacher) ?? next;
    if (owned !== data) quizChanges.push({ row: r, next: owned });
  }
  line(`سيُحدَّث ${quizChanges.length} اختباراً.`);

  head("الطلاب والمعلّم");
  const studentChanges = students.map((r) => ({ row: r, next: updateStudent(r.data, renames) })).filter((c) => c.next);
  const teacherNext = updateTeacher(teacher.row.data);
  line(`طلابُ روضةٍ تُسند إليهم المادّةُ أو يُنقل مسارُهم: ${studentChanges.length}.`);
  line(teacherNext ? `تُضاف «${NEW_SUBJECT}» إلى موادّ ${teacher.name}.` : `موادُّ ${teacher.name}: لا تغيير.`);

  head("القوائم المسطّحة");
  const present = namesIn(nextConfigs);
  const flatChanges = [
    [SUBJECTS_KEY, NEW_SUBJECT, present.subjects],
    [TERMS_KEY, NEW_TERM, present.terms],
    [UNITS_KEY, NEW_UNIT, present.units],
  ]
    .filter(([key]) => row(key))
    .map(([key, add, names]) => ({ key, before: asArray(row(key).value), next: updateFlat(asArray(row(key).value), add, names) }))
    .filter((c) => c.next);
  for (const c of flatChanges) line(`  • ${c.key}: ${JSON.stringify(c.before)} ← ${JSON.stringify(c.next)}`);
  if (!flatChanges.length) line("لا تغيير (أو غيرُ مخزونة — تُشتقّ من الشجرة).");

  // ── النسخة الاحتياطية — دائماً، وقبل أيّ كتابة ──
  const stamp = new Date().toISOString();
  const dir = join(dirname(fileURLToPath(import.meta.url)), "backups");
  mkdirSync(dir, { recursive: true });
  const file = join(dir, `split-noorania-${stamp.replace(/[:.]/g, "-")}.json`);
  writeFileSync(
    file,
    JSON.stringify(
      {
        stamp,
        kv,
        lessons: lessonChanges.map((c) => c.row),
        quizzes: quizChanges.map((c) => c.row),
        students: studentChanges.map((c) => c.row),
        teacher: teacher.row,
      },
      null,
      2,
    ),
  );
  head("النسخة الاحتياطية");
  line(file);

  if (!EXECUTE) {
    line();
    line("انتهت المعاينة. راجع ما سبق، ثم أعد التشغيل مع --execute.");
    return;
  }
  if (!treeChanged && !lessonChanges.length && !quizChanges.length && !studentChanges.length && !teacherNext && !flatChanges.length) {
    line("لا شيء يُكتب — كلُّ شيءٍ في مكانه.");
    return;
  }

  head("الكتابة");
  // ‏الدروسُ أوّلاً: لو انقطع التنفيذُ بعدها أكمل التشغيلُ الثاني الباقي.
  for (const c of lessonChanges) await patchRow("lesson_configs", c.row.id, c.next, stamp);
  line(`حُدّث ${lessonChanges.length} درساً.`);
  for (const c of quizChanges) await patchRow("created_quizzes", c.row.id, c.next, stamp);
  line(`حُدّث ${quizChanges.length} اختباراً.`);
  if (treeChanged) await putKv(HIERARCHY_KEY, nextConfigs, stamp);
  line("كُتبت الشجرة.");
  for (const c of flatChanges) await putKv(c.key, c.next, stamp);
  for (const c of studentChanges) await patchRow("students", c.row.id, c.next, stamp);
  if (teacherNext) await patchRow("teachers", teacher.row.id, teacherNext, stamp);
  line(`حُدّث ${studentChanges.length} طالباً${teacherNext ? " وسجلُّ المعلّم" : ""}.`);
  await putKv(EPOCH_KEY, stamp, stamp);
  line(`رُفع ختم المحتوى: ${stamp}`);

  head("التحقّق");
  const problems = [];
  const [treeAfter] = await readJson(`/rest/v1/app_kv?select=value&key=eq.${encodeURIComponent(HIERARCHY_KEY)}`);
  const configsAfter = asArray(treeAfter?.value);
  const home = configsAfter.find((c) => isKg(c?.grade) && isCanonical(teacher)(c) && (c.subjects ?? []).some((s) => isNew(s?.subject)));
  if (!home) problems.push(`لا «${NEW_SUBJECT}» في مدخل روضةٍ مالكُه «${teacher.id}».`);
  const term = home?.subjects.find((s) => isNew(s?.subject))?.terms?.find((t) => norm(t.term) === norm(NEW_TERM));
  for (const l of moved.flatMap((m) => m.lessons)) {
    if (!lessonsOf(term, NEW_UNIT).some((x) => norm(x) === norm(l.to))) problems.push(`الدرس «${l.to}» ليس تحت ${NEW_TERM} / ${NEW_UNIT}.`);
  }
  const quranLeft = configsAfter.some(
    (c) => isKg(c?.grade) && (c.subjects ?? []).some((s) => isQuran(s?.subject) && (s.terms ?? []).some((t) => isNoorania(t.term) || unitsOf(t).some(isNoorania))),
  );
  if (quranLeft) problems.push(`ما زال للنورانية أثرٌ تحت «${OLD_SUBJECT}» في الروضة.`);
  const after = await readJson("/rest/v1/lesson_configs?select=id,data&limit=20000");
  const pathKeys = ["subject", "term", "unit", "lesson", "lessonName", "title", "chapter", "teacher_id", "teacherId"];
  for (const c of lessonChanges) {
    const now = after.find((r) => r.id === c.row.id);
    if (!now) {
      problems.push(`الدرس ${c.row.id} لم يعد موجوداً!`);
      continue;
    }
    const lost = Object.keys(c.row.data ?? {}).filter((k) => !pathKeys.includes(k) && JSON.stringify(now.data?.[k]) !== JSON.stringify(c.row.data[k]));
    if (lost.length) problems.push(`الدرس ${c.row.id}: تغيّرت حقولٌ ما كان يجب أن تتغيّر: ${lost.join("، ")}`);
    if (!isCanonical(teacher)(now.data)) problems.push(`الدرس ${c.row.id}: مالكُه ليس «${teacher.id}».`);
  }
  const left = after.filter((r) => isKg(r.data?.grade) && isQuran(r.data?.subject) && (isNoorania(r.data?.term) || isNoorania(r.data?.unit)));
  if (left.length) problems.push(`${left.length} درساً بقي تحت نورانية القرآن.`);
  if (problems.length) {
    for (const p of problems) line(`  ✗ ${p}`);
    line(`النسخة الاحتياطية: ${file}`);
    process.exit(2);
  }
  line(`✓ «${NEW_SUBJECT}» في مدخل داود للروضة، ودروسُها بمسارها ومالكها، وكلُّ حقول المحتوى كما كانت.`);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((error) => {
    console.error(error?.message ?? error);
    process.exit(1);
  });
}
