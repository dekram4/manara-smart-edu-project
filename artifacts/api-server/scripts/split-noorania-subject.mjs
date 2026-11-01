#!/usr/bin/env node
/**
 * يُخرج «القاعدة النورانية» من «القرآن الكريم» في روضة منارة المعرفة مادّةً
 * مستقلّة — بلا أن يضيع شيءٌ من محتواها.
 *
 * ── ما كان ──
 * «القرآن الكريم» في الروضة فصلان، ثانيهما «تعليم القاعدة النورانية».
 *
 * ── ما يصير ──
 *   المادّة: القاعدة النورانية
 *     الفصل: القاعدة النورانية
 *       الوحدة: تعليم القراءة
 *         الدرس: القاعدة النورانية   (إن كان في الفصل درسٌ واحد؛ وإن كانت
 *                                    دروساً بقيت أسماؤها كما هي — لا يُدمج
 *                                    محتوى درسين في درسٍ فيضيع أحدهما)
 *
 * ── لماذا لا يضيع شيء ──
 * محتوى الدرس كلُّه (النصّ، والأسئلة، والصوت، والروابط، والألعاب، وبنكُ
 * التحدّي) في `lesson_configs.data`، ومعرّفُ الصفّ (`id`) لا يتغيّر: يُكتب
 * السجلُّ كاملاً ولا يُبدَّل فيه إلا مسارُه (المادّة والفصل والوحدة واسم
 * الدرس). فكلُّ ما يُربط بالمعرّف — تقدّمُ الطلاب ومكافآتُهم، وألعابُ الدرس
 * المولَّدة، وسجلُّ المشاهدة — يبقى مربوطاً كما هو.
 *
 * وما يُربط بالأسماء يُحدَّث معه:
 *   • الشجرة (`app_kv.smartEdu_hierarchicalConfigs`): يُنزع الفصلُ من القرآن
 *     وتُضاف المادّةُ الجديدة لصاحب الفصل نفسه.
 *   • الاختبارات المنشأة (`created_quizzes`) لدروس ذلك الفصل.
 *   • الطلاب (`students.data`): من أُسندت إليه «القرآن الكريم» تُسند إليه
 *     المادّةُ الجديدة أيضاً، وآخرُ مسارٍ محفوظٍ له في الفصل القديم يُنقل.
 *   • المعلّمون (`teachers.data`): من كانت له «القرآن الكريم» في موادّه.
 *   • قائمةُ الموادّ المسطّحة (`smartEdu_subjects`) إن كانت مخزونة، وختمُ
 *     المحتوى ليأخذ كلُّ جهازٍ النسخةَ الجديدة.
 *
 * ── الأمان ──
 * المعاينةُ أوّلاً ولا كتابة فيها. وقبل أيّ كتابةٍ تُحفظ نسخةٌ كاملة من كلّ
 * صفٍّ سيُمسّ في `backups/` — للرجوع إليها. والتنفيذُ يعيد القراءة ويتحقّق.
 *
 * التشغيل — المعاينة:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
 *     node scripts/split-noorania-subject.mjs
 * ثم أضف --execute للتنفيذ.
 */

import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export const GRADE = "روضة منارة المعرفة";
export const OLD_SUBJECT = "القرآن الكريم";
export const NEW_SUBJECT = "القاعدة النورانية";
export const NEW_TERM = "القاعدة النورانية";
export const NEW_UNIT = "تعليم القراءة";
export const NEW_LESSON = "القاعدة النورانية";

const HIERARCHY_KEY = "smartEdu_hierarchicalConfigs";
const SUBJECTS_KEY = "smartEdu_subjects";
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
/** الفصلُ المقصود: «تعليم القاعدة النورانية» أو ما فيه «نوراني». */
export const isNooraniaTerm = (term) => norm(term).includes("نوراني");

const ownerOf = (record) =>
  norm(record?.teacher_id ?? record?.teacherId ?? record?.createdBy) || "admin";

/**
 * الشجرةُ بعد الفصل: يُنزع فصلُ النورانية من «القرآن الكريم» في الروضة،
 * وتُضاف — لصاحب المدخل نفسه — مادّةُ «القاعدة النورانية» بفصلٍ واحد ووحدةٍ
 * واحدة، فيها دروسُ الفصل القديم. وما سوى ذلك لا يُمسّ.
 *
 * يعيد `{configs, moved}`: الشجرةَ الجديدة، ولكل مدخلٍ مُسّ: صاحبُه، واسمُ
 * الفصل القديم، ودروسُه، وما صارت إليه أسماؤها.
 */
export function splitTree(configs) {
  const moved = [];
  const next = configs.map((config) => {
    if (!config || typeof config !== "object" || !isKg(config.grade) || !Array.isArray(config.subjects)) {
      return config;
    }
    const quran = config.subjects.find((s) => s && isQuran(s.subject));
    const terms = Array.isArray(quran?.terms) ? quran.terms : [];
    const old = terms.filter((t) => t && isNooraniaTerm(t.term));
    if (!old.length) return config;

    const lessons = [];
    for (const term of old) {
      const units = Array.isArray(term.units) ? term.units : [];
      const byUnit = term.lessons && typeof term.lessons === "object" ? term.lessons : {};
      for (const unit of [...units, ...Object.keys(byUnit).filter((u) => !units.includes(u))]) {
        for (const lesson of Array.isArray(byUnit[unit]) ? byUnit[unit] : []) {
          if (!lessons.some((l) => norm(l.lesson) === norm(lesson) && norm(l.unit) === norm(unit))) {
            lessons.push({ term: text(term.term), unit: text(unit), lesson: text(lesson) });
          }
        }
      }
    }
    const single = lessons.length <= 1;
    const renamed = lessons.map((l) => ({ ...l, to: single ? NEW_LESSON : l.lesson }));
    const newLessons = single ? [NEW_LESSON] : renamed.map((l) => l.to);

    const subjects = config.subjects.map((s) =>
      s === quran ? { ...s, terms: terms.filter((t) => !old.includes(t)) } : s,
    );
    const existing = subjects.find((s) => s && norm(s.subject) === norm(NEW_SUBJECT));
    const subject = {
      subject: NEW_SUBJECT,
      terms: [{ term: NEW_TERM, units: [NEW_UNIT], lessons: { [NEW_UNIT]: newLessons } }],
    };
    if (existing) {
      // ‏شُغّل من قبل: يُضمّ إليه ولا يُكرَّر.
      const term = (existing.terms ??= []).find((t) => norm(t.term) === norm(NEW_TERM));
      if (!term) {
        existing.terms.push(subject.terms[0]);
      } else {
        term.units = [...new Set([...(term.units ?? []), NEW_UNIT])];
        term.lessons ??= {};
        const have = term.lessons[NEW_UNIT] ?? [];
        term.lessons[NEW_UNIT] = [...have, ...newLessons.filter((l) => !have.some((h) => norm(h) === norm(l)))];
      }
    } else {
      // ‏بعد «القرآن الكريم» مباشرة: جارتُه في القائمة.
      subjects.splice(config.subjects.indexOf(quran) + 1, 0, subject);
    }
    moved.push({ owner: ownerOf(config), terms: old.map((t) => text(t.term)), lessons: renamed });
    return { ...config, subjects };
  });
  return { configs: next, moved };
}

/**
 * مسارُ درسٍ في فصل النورانية بعد النقل، أو `null` إن لم يكن منه.
 * [renames]: الاسمُ القديم ← الجديد (درسٌ واحد يصير «القاعدة النورانية»).
 */
export function movedPath(data, renames) {
  if (!data || !isKg(data.grade) || !isQuran(data.subject) || !isNooraniaTerm(data.term)) return null;
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
  if ("chapter" in data && isNooraniaTerm(data.chapter)) next.chapter = path.term;
  return next;
}

/**
 * سجلُّ طالب: تُسند إليه المادّةُ الجديدة إن كانت له «القرآن الكريم»، ويُنقل
 * مسارُه المحفوظ إن كان في فصل النورانية. `null` إن لم يتغيّر فيه شيء.
 */
export function updateStudent(data, renames) {
  if (!data || typeof data !== "object") return null;
  let changed = false;
  const next = { ...data };
  for (const key of ["assignedSubjects", "assigned_subjects"]) {
    const list = data[key];
    if (Array.isArray(list) && list.some((s) => isQuran(typeof s === "string" ? s : s?.name ?? s?.subject))) {
      const names = list.map((s) => (typeof s === "string" ? s : s?.name ?? s?.subject));
      if (!names.some((s) => norm(s) === norm(NEW_SUBJECT))) {
        next[key] = [...list, typeof list[0] === "string" || !list.length ? NEW_SUBJECT : { ...list[0], name: NEW_SUBJECT, subject: NEW_SUBJECT }];
        changed = true;
      }
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

/** سجلُّ معلّم: من كانت له «القرآن الكريم» تُضاف إليه المادّةُ الجديدة. */
export function updateTeacher(data) {
  if (!data || typeof data !== "object") return null;
  for (const key of ["subjects", "assignedSubjects"]) {
    const list = data[key];
    if (!Array.isArray(list)) continue;
    const names = list.map((s) => (typeof s === "string" ? s : s?.name ?? s?.subject));
    if (names.some(isQuran) && !names.some((s) => norm(s) === norm(NEW_SUBJECT))) {
      return { ...data, [key]: [...list, typeof list[0] === "string" ? NEW_SUBJECT : { name: NEW_SUBJECT, subject: NEW_SUBJECT }] };
    }
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────
// التشغيل
// ─────────────────────────────────────────────────────────────────────

const args = process.argv.slice(2);
const EXECUTE = args.includes("--execute");
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

async function main() {
  if (!SUPABASE_URL || !SERVICE_KEY) {
    console.error("يلزم SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY.");
    process.exit(1);
  }
  line(EXECUTE ? "التنفيذ: ستُكتب التغييرات." : "معاينةٌ فقط — لا كتابة. أضف --execute للتنفيذ.");

  head("القراءة");
  const kv = await readJson(`/rest/v1/app_kv?select=key,value&key=in.(${[HIERARCHY_KEY, SUBJECTS_KEY].map(encodeURIComponent).join(",")})`);
  const treeRow = kv.find((r) => r.key === HIERARCHY_KEY);
  const subjectsRow = kv.find((r) => r.key === SUBJECTS_KEY);
  const configs = asArray(treeRow?.value);
  const lessons = await readJson("/rest/v1/lesson_configs?select=id,data&limit=20000");
  const quizzes = await readOptional("/rest/v1/created_quizzes?select=id,data&limit=20000");
  const students = await readOptional("/rest/v1/students?select=id,data&limit=20000");
  const teachers = await readOptional("/rest/v1/teachers?select=id,data&limit=5000");
  line(`الشجرة: ${configs.length} مدخلاً. الدروس: ${lessons.length}. الاختبارات: ${quizzes.length}. الطلاب: ${students.length}. المعلّمون: ${teachers.length}.`);

  head("الشجرة");
  const { configs: nextConfigs, moved } = splitTree(configs);
  if (!moved.length) {
    line(`لا فصلَ «نورانية» تحت «${OLD_SUBJECT}» في الروضة — لا شيء يُنقل (أو نُقل من قبل).`);
  }
  const renames = new Map();
  for (const entry of moved) {
    line(`صاحبُ المدخل: ${entry.owner}. الفصل: ${entry.terms.join("، ")}.`);
    for (const l of entry.lessons) {
      line(`  • ${l.unit} / ${l.lesson}  ←  ${NEW_UNIT} / ${l.to}`);
      renames.set(norm(l.lesson), l.to);
    }
  }

  head("الدروس (lesson_configs)");
  const lessonChanges = [];
  const candidates = lessons.filter((row) => movedPath(row.data, renames));
  for (const row of candidates) {
    const path = movedPath(row.data, renames);
    // ‏درسٌ في الجدول لم تذكره الشجرة: يصير «القاعدة النورانية» إن كان وحده
    // ‏في الفصل، وإلا بقي اسمُه — لا يُسمّى درسان باسمٍ واحد.
    if (!renames.has(norm(path.from))) path.lesson = candidates.length === 1 ? NEW_LESSON : path.from;
    lessonChanges.push({ row, next: withPath(row.data, path) });
    const keys = Object.keys(row.data ?? {}).length;
    line(`  • ${row.id}: «${path.from}» ← «${path.lesson}» (${keys} حقلاً تبقى كما هي)`);
  }
  line(`سيُنقل ${lessonChanges.length} درساً.`);

  head("الاختبارات (created_quizzes)");
  const quizChanges = [];
  const movedIds = new Set(lessonChanges.map((c) => c.row.id));
  for (const row of quizzes) {
    const data = row.data ?? {};
    const byId = movedIds.has(text(data.lessonId ?? data.lesson_id));
    const path = movedPath(data, renames);
    if (!path && !byId) continue;
    const target = path ?? { subject: NEW_SUBJECT, term: NEW_TERM, unit: NEW_UNIT, lesson: text(data.lesson) || NEW_LESSON, from: text(data.lesson) };
    quizChanges.push({ row, next: withPath(data, target) });
  }
  line(`سيُحدَّث ${quizChanges.length} اختباراً.`);

  head("الطلاب والمعلّمون");
  const studentChanges = students
    .map((row) => ({ row, next: updateStudent(row.data, renames) }))
    .filter((c) => c.next);
  const teacherChanges = teachers
    .map((row) => ({ row, next: updateTeacher(row.data) }))
    .filter((c) => c.next);
  line(`طلابٌ تُسند إليهم المادّةُ أو يُنقل مسارُهم: ${studentChanges.length}. معلّمون: ${teacherChanges.length}.`);

  const flat = asArray(subjectsRow?.value);
  const flatNext = flat.length && !flat.some((s) => norm(s) === norm(NEW_SUBJECT)) ? [...flat, NEW_SUBJECT] : null;

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
        tree: treeRow ?? null,
        subjects: subjectsRow ?? null,
        lessons: lessonChanges.map((c) => c.row),
        quizzes: quizChanges.map((c) => c.row),
        students: studentChanges.map((c) => c.row),
        teachers: teacherChanges.map((c) => c.row),
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
  if (!moved.length && !lessonChanges.length) return;

  head("الكتابة");
  // ‏الدروسُ أوّلاً: لو انقطع التنفيذُ بعدها لبقيت الشجرةُ القديمة ترى دروسها
  // ‏تحت مسارٍ جديد — ويُعيد التشغيلُ الثاني الشجرةَ وحدها.
  for (const c of lessonChanges) await patchRow("lesson_configs", c.row.id, c.next, stamp);
  line(`نُقل ${lessonChanges.length} درساً.`);
  for (const c of quizChanges) await patchRow("created_quizzes", c.row.id, c.next, stamp);
  line(`حُدّث ${quizChanges.length} اختباراً.`);
  if (moved.length) await putKv(HIERARCHY_KEY, nextConfigs, stamp);
  line("كُتبت الشجرة.");
  if (flatNext) await putKv(SUBJECTS_KEY, flatNext, stamp);
  for (const c of studentChanges) await patchRow("students", c.row.id, c.next, stamp);
  for (const c of teacherChanges) await patchRow("teachers", c.row.id, c.next, stamp);
  line(`حُدّث ${studentChanges.length} طالباً و${teacherChanges.length} معلّماً.`);
  await putKv(EPOCH_KEY, stamp, stamp);
  line(`رُفع ختم المحتوى: ${stamp}`);

  head("التحقّق");
  const after = await readJson("/rest/v1/lesson_configs?select=id,data&limit=20000");
  const left = after.filter((r) => isKg(r.data?.grade) && isQuran(r.data?.subject) && isNooraniaTerm(r.data?.term));
  const landed = after.filter((r) => movedIds.has(r.id) && norm(r.data?.subject) === norm(NEW_SUBJECT));
  for (const c of lessonChanges) {
    const now = after.find((r) => r.id === c.row.id);
    const before = Object.keys(c.row.data ?? {}).filter((k) => !["subject", "term", "unit", "lesson", "lessonName", "title", "chapter"].includes(k));
    const lost = before.filter((k) => JSON.stringify(now?.data?.[k]) !== JSON.stringify(c.row.data[k]));
    if (lost.length) throw new Error(`الدرس ${c.row.id}: تغيّرت حقولٌ ما كان يجب أن تتغيّر: ${lost.join("، ")}`);
  }
  line(`دروسٌ بقيت تحت الفصل القديم: ${left.length}. دروسٌ في المادّة الجديدة: ${landed.length} من ${lessonChanges.length}.`);
  line("كلُّ حقول المحتوى كما كانت.");
  if (left.length || landed.length !== lessonChanges.length) process.exit(2);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
