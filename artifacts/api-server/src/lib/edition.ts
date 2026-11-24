/**
 * «النسخة المفتوحة» من منارة: نشرٌ ثانٍ مستقلّ بقاعدته (`manara-open-app`)،
 * يديره حسابُ معلّمٍ واحد، ويدخله الطلابُ بلا اسم مستخدمٍ ولا كلمة مرور.
 *
 * ── لا يتغيّر شيءٌ في النشر الحالي ──
 * كلُّ ما هنا يُفعَّل بمتغيّر البيئة `MANARA_EDITION=open` وحده. وغيابُه — وهو
 * حالُ خدمة Railway الحالية — يعني «النسخة العادية»: الحارسُ يمرّر كلَّ طلب،
 * ومسارُ التسجيل الذاتي غيرُ موجود (404)، و`/api/edition` يقول `standard`.
 *
 * ── والعزلُ من البيئة لا من الكود ──
 * الخادمُ لا يعرف إلا قاعدةً واحدة: `SUPABASE_URL` و`SUPABASE_SERVICE_ROLE_KEY`
 * في خدمته. فخدمةُ النسخة المفتوحة تحمل مفاتيح `manara-open-app` وحدها، ولا
 * سبيلَ لكودها إلى القاعدة القديمة ولو أراد.
 *
 * والمنطقُ هنا بلا شبكةٍ ولا قاعدة، فيُختبر وحده (`edition.test.mjs`).
 */

import crypto from "node:crypto";

export type Edition = "standard" | "open";

type Env = Record<string, string | undefined>;

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/** النسخةُ الجارية. أيُّ قيمةٍ غير `open` (أو غيابُها) هي العادية. */
export function editionOf(env: Env = process.env): Edition {
  return text(env.MANARA_EDITION).toLowerCase() === "open" ? "open" : "standard";
}

export function isOpenEdition(env: Env = process.env): boolean {
  return editionOf(env) === "open";
}

/** معرّفُ المعلم الوحيد في النسخة المفتوحة (صفُّه في جدول `teachers`). */
export function openTeacherId(env: Env = process.env): string {
  return text(env.OPEN_TEACHER_ID);
}

/**
 * اسمُ دخول المعلم الوحيد، إن ضُبط: يُردّ كلُّ دخولِ معلّمٍ باسمٍ غيره — حارسٌ
 * ثانٍ فوق أنّ القاعدةَ الجديدة ليس فيها إلا حسابُه.
 */
export function openTeacherUsername(env: Env = process.env): string {
  return text(env.OPEN_TEACHER_USERNAME);
}

/**
 * ما يُغلق في النسخة المفتوحة: بوابتا المشرف ووليّ الأمر، وحسابا العرض.
 * يعيد سببَ الإغلاق، أو `null` لطلبٍ يمرّ.
 *
 * [path] مسارُ الطلب داخل `/api` (`/auth/admin`، لا `/api/auth/admin`).
 */
export function openEditionBlock(method: string, path: string): string | null {
  const p = path.replace(/\/+$/, "").toLowerCase();
  const m = method.toUpperCase();
  if (m === "POST" && p === "/auth/admin") return "بوابة المشرف غير متاحة في النسخة المفتوحة";
  if (p.startsWith("/auth/parent/")) return "بوابة ولي الأمر غير متاحة في النسخة المفتوحة";
  if (p === "/auth/student/demo") return "النسخة المفتوحة لا تحتاج حساب عرض";
  return null;
}

/** مسارا دخول المعلم اللذان يمرّ بهما اسمُه. */
export function isTeacherLoginPath(method: string, path: string): boolean {
  const p = path.replace(/\/+$/, "").toLowerCase();
  return method.toUpperCase() === "POST" && (p === "/auth/teacher/login" || p === "/auth/teacher/session");
}

/** هل يُقبل دخولُ هذا المعلم؟ بلا اسمٍ مضبوط في البيئة يُقبل كلُّ من في القاعدة. */
export function teacherLoginAllowed(username: unknown, env: Env = process.env): boolean {
  const only = openTeacherUsername(env);
  if (!only) return true;
  return text(username).toLowerCase() === only.toLowerCase();
}

// ─────────────────────────────────────────────────────────────────────
// تسجيلُ الطالب الذاتي
// ─────────────────────────────────────────────────────────────────────

/** أطولُ اسمٍ يُقبل: اسمٌ واسمُ عائلة، لا فقرة. */
export const OPEN_NAME_MAX = 40;

/**
 * اسمُ الطالب كما يُحفظ: بلا رموز تحكّمٍ ولا مسافاتٍ زائدة، وبطولٍ معقول.
 * يعيد `""` لاسمٍ فارغ أو لا حرفَ فيه.
 */
export function cleanStudentName(raw: unknown): string {
  const name = text(raw)
    .replace(/[\u0000-\u001f\u007f<>]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, OPEN_NAME_MAX)
    .trim();
  return /[\p{L}]/u.test(name) ? name : "";
}

type Json = Record<string, unknown>;

/** صفوفُ المعلم من الشجرة الأكاديمية (`smartEdu_hierarchicalConfigs`). */
export function openGradesFrom(hierarchy: unknown, teacherId: string): string[] {
  const id = text(teacherId);
  if (!id || !Array.isArray(hierarchy)) return [];
  const grades: string[] = [];
  for (const config of hierarchy) {
    if (!config || typeof config !== "object") continue;
    const c = config as Json;
    const owner = text(c.teacher_id) || text(c.teacherId) || text(c.createdBy);
    const grade = text(c.grade);
    if (owner === id && grade && !grades.includes(grade)) grades.push(grade);
  }
  return grades;
}

export type OpenTeacher = { id: string; name: string };

export type OpenStudent = {
  /** معرّفُ الصفّ في جدول `students`، وهو نفسُه `data.id`. */
  id: string;
  username: string;
  /** كلمةُ المرور الصريحة: تعود للتطبيق مرّةً ليحفظها في مخزنه المشفّر. */
  password: string;
  data: Json;
};

/**
 * سجلُّ طالبٍ جديد في صفّ المعلم الوحيد — بالحقول نفسها التي تكتبها لوحةُ
 * المعلم حين يضيف طالباً، فيمرّ في كل مسارٍ كأيّ طالب.
 *
 * [hash] دالّةُ تخزين كلمة المرور (`hashPassword`)، تُمرَّر كي يبقى هذا الملفُّ
 * بلا اعتماد. و[random] للاختبار.
 */
export function buildOpenStudent(input: {
  name: string;
  grade: string;
  teacher: OpenTeacher;
  gender?: unknown;
  now?: Date;
  hash: (plain: string) => string;
  random?: (bytes: number) => Buffer;
}): OpenStudent {
  const random = input.random ?? ((n: number) => crypto.randomBytes(n));
  const now = input.now ?? new Date();
  const id = `${now.getTime()}${random(2).readUInt16BE(0).toString().padStart(5, "0")}`;
  const username = `open_${random(5).toString("hex")}`;
  const password = random(18).toString("base64url");
  const gender = text(input.gender) === "female" ? "female" : "male";
  return {
    id,
    username,
    password,
    data: {
      id,
      name: input.name,
      username,
      password: input.hash(password),
      gender,
      grade: input.grade,
      primaryGrade: input.grade,
      subject: "",
      term: "",
      unit: "",
      teacherId: input.teacher.id,
      createdBy: input.teacher.id,
      createdByName: input.teacher.name,
      createdAt: now.toISOString(),
      canChangeGrade: false,
      gradeEnrollments: [],
      assignedSubjects: [],
      selfRegistered: true,
    },
  };
}
