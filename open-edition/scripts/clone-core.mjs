/**
 * منطقُ الاستنساخ بلا شبكة: من صفوف القاعدة القديمة إلى صفوف القاعدة الجديدة.
 * يُختبر وحده (`open-edition/scripts/clone-core.test.mjs`).
 *
 * ── القاعدة ──
 * يُنسخ ما يملكه المعلمُ وحده — بمعرّفه أو اسمه أو اسم دخوله في أيٍّ من حقول
 * المالك — ثم تُستبدل هويّتُه في كل موضع: المعرّفُ القديم بالجديد (ولو جزءاً
 * من نصٍّ مثل `class:<id>:<grade>`)، واسمُه بالاسم الجديد حين يكون القيمةَ كلَّها.
 * ومعرّفاتُ الدروس والاختبارات تبقى كما هي: القاعدةُ الجديدة لا تشارك القديمةَ
 * شيئاً، فلا تصادم، وتبقى روابطُ الدروس بأسئلتها سليمة.
 */

/** تسويةُ المالك كما في الخادم (`teacherScope.normalizeOwner`). */
export function normalizeOwner(value) {
  return String(value ?? "")
    .trim()
    .toLowerCase()
    .replace(/[ً-ْٰـ]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/\s+/g, " ")
    .trim();
}

const OWNER_FIELDS = ["teacher_id", "teacherId", "createdBy", "created_by", "teacher_name", "teacherName", "createdByName", "ownerId", "owner"];

/** هل يملك المعلمُ هذا السجل؟ [ids] هوياتُه مسوّاة. */
export function ownedBy(record, ids) {
  if (!record || typeof record !== "object") return false;
  return OWNER_FIELDS.some((field) => {
    const value = record[field];
    return typeof value === "string" && ids.has(normalizeOwner(value));
  });
}

/** يستبدل هويةَ المعلم في كل قيمةٍ نصّيةٍ من [value]، عمقاً. */
export function rewriteIdentity(value, { fromId, toId, fromName, toName }) {
  if (typeof value === "string") {
    if (fromName && value.trim() === fromName) return toName;
    return fromId && value.includes(fromId) ? value.split(fromId).join(toId) : value;
  }
  if (Array.isArray(value)) return value.map((item) => rewriteIdentity(item, { fromId, toId, fromName, toName }));
  if (value && typeof value === "object") {
    const out = {};
    for (const [key, item] of Object.entries(value)) {
      out[rewriteIdentity(key, { fromId, toId, fromName: null, toName: null })] = rewriteIdentity(item, { fromId, toId, fromName, toName });
    }
    return out;
  }
  return value;
}

const text = (v) => (typeof v === "string" ? v.trim() : "");
const unique = (values) => [...new Set(values.map(text).filter(Boolean))];

/** القوائمُ المسطّحة من شجرة المعلم — كما يشتقّها الخادم (`teacherScope.flatFrom`). */
export function flatLists(configs) {
  const subjects = configs.flatMap((c) => (Array.isArray(c.subjects) ? c.subjects : []));
  const subjectRecords = subjects.filter((s) => s && typeof s === "object");
  const terms = subjectRecords.flatMap((s) => (Array.isArray(s.terms) ? s.terms : [])).filter((t) => t && typeof t === "object");
  return {
    smartEdu_grades: unique(configs.map((c) => c.grade)),
    smartEdu_subjects: unique(subjects.map((s) => (typeof s === "string" ? s : s?.subject))),
    smartEdu_terms: unique(terms.map((t) => t.term)),
    smartEdu_units: unique(terms.flatMap((t) => (Array.isArray(t.units) ? t.units : []))),
  };
}

/** مفاتيحُ `app_kv` التي سجلّاتُها بمالك: يُنسخ منها ما يملكه المعلم. */
export const OWNED_KV_KEYS = [
  "smartEdu_hierarchicalConfigs",
  "smartEdu_gradeConfigs",
  "smartEdu_quizQuestions",
  "smartEdu_videos",
  "smartEdu_videoNotifications",
  "smartEdu_cardPermissions",
];

/** إعداداتٌ عامّة تُنسخ كما هي: بدونها تعمل الميزاتُ بقيمٍ افتراضيةٍ غير ما اعتاده المعلم. */
export const SHARED_KV_KEYS = ["smartEdu_adminSettings", "smartEdu_permissions", "smartEdu_contentEpoch"];

/**
 * يبني ما يُكتب في القاعدة الجديدة.
 *
 * [old] صفوفُ القاعدة القديمة: { teacher, lessonConfigs, createdQuizzes, kv (key→value),
 *       cinemaVideos, entertainmentGames, duelQuestions }.
 * [target] { id, name }.
 */
export function buildClone(old, target) {
  const teacher = old.teacher;
  if (!teacher?.id || !teacher?.data) throw new Error("صفُّ المعلم المصدر مفقود");
  const fromId = teacher.id;
  const fromName = text(teacher.data.name);
  const ids = new Set([fromId, text(teacher.data.id), text(teacher.data.teacherId), fromName, text(teacher.data.username)].filter(Boolean).map(normalizeOwner));
  const swap = { fromId, toId: target.id, fromName, toName: target.name };
  const rw = (v) => rewriteIdentity(v, swap);
  const mine = (r) => ownedBy(r, ids);

  const teacherData = rw({ ...teacher.data });
  teacherData.id = target.id;
  teacherData.teacherId = target.id;
  teacherData.name = target.name;
  teacherData.clonedFrom = { id: fromId, name: fromName, at: old.now ?? new Date().toISOString() };

  const rows = {
    teachers: [{ id: target.id, data: teacherData }],
    lesson_configs: old.lessonConfigs.filter((r) => mine(r.data)).map((r) => ({ id: r.id, data: rw(r.data) })),
    created_quizzes: old.createdQuizzes.filter((r) => mine(r.data)).map((r) => ({ id: r.id, data: rw(r.data) })),
    cinema_videos: (old.cinemaVideos || []).filter(mine).map((r) => rw(r)),
    entertainment_games: (old.entertainmentGames || []).filter(mine).map((r) => rw(r)),
    duel_questions: (old.duelQuestions || [])
      .filter((r) => !text(r.teacher_id) || ids.has(normalizeOwner(r.teacher_id)))
      .map((r) => rw(r)),
  };

  const kv = {};
  for (const key of OWNED_KV_KEYS) {
    const value = old.kv[key];
    if (Array.isArray(value)) kv[key] = value.filter(mine).map(rw);
  }
  const configs = kv.smartEdu_hierarchicalConfigs || [];
  Object.assign(kv, flatLists(configs));
  for (const key of SHARED_KV_KEYS) if (old.kv[key] !== undefined) kv[key] = old.kv[key];
  const packageId = text(teacher.data.permissionPackageId);
  if (packageId && Array.isArray(old.kv.smartEdu_permissionPackages)) {
    kv.smartEdu_permissionPackages = old.kv.smartEdu_permissionPackages.filter((p) => text(p?.id) === packageId);
  }
  rows.app_kv = Object.entries(kv).map(([key, value]) => ({ key, value }));
  return rows;
}

/** ملخّصٌ يُطبع ويُقارن: عددُ ما يُنسخ من كل جدول. */
export function summarize(rows) {
  return Object.fromEntries(Object.entries(rows).map(([table, list]) => [table, list.length]));
}

// ─────────────────────────────────────────────────────────────────────
// SQL
// ─────────────────────────────────────────────────────────────────────

const TAG = "$manara_open$";

function literal(json) {
  const body = JSON.stringify(json);
  if (body.includes(TAG)) throw new Error("محتوى يحوي وسمَ الاقتباس — غيّر TAG");
  return `${TAG}${body}${TAG}::jsonb`;
}

const sqlString = (v) => `'${String(v).replace(/'/g, "''")}'`;

const quoteIdent = (name) => `"${String(name).replace(/"/g, '""')}"`;

/** جداولُ الكيانات: (id, data). */
const ENTITY_TABLES = new Set(["teachers", "lesson_configs", "created_quizzes"]);

/**
 * ملفُّ SQL يُلصق في محرّر Supabase لمشروع `manara-open-app`: معاملةٌ واحدة،
 * وكلُّ صفٍّ upsert — فتشغيلُه مرّةً ثانية يحدّث ولا يكرّر.
 */
export function renderSeedSql(rows, meta) {
  const out = [];
  out.push("-- مولَّدٌ بـ open-edition/scripts/clone-teacher.mjs — لا يُعدَّل باليد.");
  out.push("-- ⚠️ يُشغَّل في مشروع manara-open-app وحده (SQL Editor)، بعد sql/01-schema.sql.");
  out.push(`-- المصدر: ${meta.fromName} (${meta.fromId}) ← الهدف: ${meta.toName} (${meta.toId})`);
  out.push(`-- ${JSON.stringify(summarize(rows))}`);
  out.push("");
  out.push("begin;");
  out.push("");
  for (const [table, list] of Object.entries(rows)) {
    if (!list.length) continue;
    out.push(`-- ── ${table} (${list.length}) ──`);
    for (const row of list) {
      if (table === "app_kv") {
        out.push(`insert into public.app_kv (key, value) values (${sqlString(row.key)}, ${literal(row.value)})`);
        out.push("  on conflict (key) do update set value = excluded.value, updated_at = now();");
      } else if (ENTITY_TABLES.has(table)) {
        out.push(`insert into public.${table} (id, data) values (${sqlString(row.id)}, ${literal(row.data)})`);
        out.push("  on conflict (id) do update set data = excluded.data, updated_at = now();");
      } else {
        const cols = Object.keys(row).filter((c) => c !== "id");
        out.push(`insert into public.${table} select * from jsonb_populate_record(null::public.${table}, ${literal(row)})`);
        out.push(`  on conflict (id) do update set ${cols.map((c) => `${quoteIdent(c)} = excluded.${quoteIdent(c)}`).join(", ") || "id = excluded.id"};`);
      }
    }
    out.push("");
  }
  out.push("commit;");
  out.push("");
  out.push("-- ── التحقّق ──");
  out.push("select");
  out.push("  (select count(*) from public.teachers) as teachers_expected_1,");
  out.push(`  (select count(*) from public.lesson_configs) as lesson_configs_expected_${rows.lesson_configs.length},`);
  out.push(`  (select count(*) from public.created_quizzes) as created_quizzes_expected_${rows.created_quizzes.length},`);
  out.push(`  (select data->>'name' from public.teachers where id = ${sqlString(meta.toId)}) as teacher_name;`);
  return out.join("\n") + "\n";
}
