/**
 * مساراتُ «النسخة المفتوحة» وحارسُها — انظر `lib/edition.ts`.
 *
 * يُركَّب هذا الموجّهُ أوّلَ الموجّهات، فيرى كلَّ طلبٍ قبل غيره:
 *   • في النسخة العادية (`MANARA_EDITION` غائب): الحارسُ يمرّر فوراً، و
 *     `/api/edition` يقول `standard`، و`/api/open/student` يُردّ 404.
 *   • في النسخة المفتوحة: بوابتا المشرف ووليّ الأمر مغلقتان، ودخولُ المعلم
 *     للحساب الوحيد، والطالبُ يُنشئ حسابَه باسمه وحده.
 */

import { Router, type IRouter } from "express";
import {
  buildOpenStudent,
  cleanStudentName,
  editionOf,
  isOpenEdition,
  isTeacherLoginPath,
  openEditionBlock,
  openGradesFrom,
  openTeacherId,
  teacherLoginAllowed,
  type OpenTeacher,
} from "../lib/edition";
import { hashPassword } from "../lib/passwords";
import { logger } from "../lib/logger";
import { readKv, rest, storeConfig } from "../lib/supabaseStore";
import { HIERARCHY_KEY } from "../lib/teacherScope";
import { createRateLimit } from "../middleware/rateLimiter";

const router: IRouter = Router();

// ── الحارس ─────────────────────────────────────────────────────────────
router.use((req, res, next) => {
  if (!isOpenEdition()) return next();
  const blocked = openEditionBlock(req.method, req.path);
  if (blocked) return res.status(404).json({ error: blocked, code: "open_edition" });
  if (isTeacherLoginPath(req.method, req.path) && !teacherLoginAllowed(req.body?.username)) {
    return res.status(401).json({ error: "بيانات دخول المعلم غير صحيحة" });
  }
  return next();
});

// ── المعلمُ الوحيد وصفوفه (تُحفظ دقيقةً: تُقرأ مع كل فتحٍ للتطبيق) ──────────
type OpenSetup = { teacher: OpenTeacher; grades: string[] };
let cached: { at: number; value: OpenSetup | null } | null = null;
const CACHE_MS = 60_000;

async function openSetup(): Promise<OpenSetup | null> {
  if (cached && Date.now() - cached.at < CACHE_MS) return cached.value;
  const config = storeConfig();
  const id = openTeacherId();
  if (!config || !id) return null;
  const rows = await rest(config, `teachers?select=id,data&id=eq.${encodeURIComponent(id)}`);
  const row = Array.isArray(rows) ? (rows[0] as { id?: string; data?: Record<string, unknown> } | undefined) : undefined;
  if (!row) {
    cached = { at: Date.now(), value: null };
    return null;
  }
  const name = typeof row.data?.name === "string" && row.data.name.trim() ? row.data.name.trim() : "معلم منارة";
  const grades = openGradesFrom(await readKv(config, HIERARCHY_KEY), id);
  const value = { teacher: { id, name }, grades };
  cached = { at: Date.now(), value };
  return value;
}

/** للاختبارات وحدها. */
export function resetOpenSetupCache(): void {
  cached = null;
}

router.get("/edition", async (_req, res) => {
  res.setHeader("Cache-Control", "no-store");
  if (!isOpenEdition()) return res.json({ edition: editionOf() });
  try {
    const setup = await openSetup();
    return res.json({
      edition: "open",
      ready: Boolean(setup && setup.grades.length),
      teacherName: setup?.teacher.name ?? null,
      grades: setup?.grades ?? [],
    });
  } catch (error) {
    logger.warn({ err: error }, "Open edition setup lookup failed");
    return res.json({ edition: "open", ready: false, teacherName: null, grades: [] });
  }
});

// ── تسجيلُ الطالب الذاتي ────────────────────────────────────────────────
// ‏خمسُ حساباتٍ في الدقيقة لكل عنوان: صفٌّ كاملٌ يدخل على مدى دقائق، ومن
// ‏يكرّر الطلبَ آلياً لا يملأ الجدول.
const joinLimit = createRateLimit(5);

router.post("/open/student", joinLimit, async (req, res) => {
  if (!isOpenEdition()) return res.status(404).json({ error: "غير موجود" });
  const name = cleanStudentName(req.body?.name);
  if (!name) return res.status(400).json({ error: "اكتب اسمك أولاً", code: "name_required" });
  const config = storeConfig();
  if (!config) return res.status(503).json({ error: "الخادم غير مُعدّ بعد", code: "not_configured" });
  try {
    const setup = await openSetup();
    if (!setup || !setup.grades.length) {
      return res.status(503).json({ error: "النسخة المفتوحة غير مُعدّة بعد", code: "open_not_ready" });
    }
    const wanted = typeof req.body?.grade === "string" ? req.body.grade.trim() : "";
    const grade = setup.grades.includes(wanted) ? wanted : setup.grades[0];
    const student = buildOpenStudent({
      name,
      grade,
      teacher: setup.teacher,
      gender: req.body?.gender,
      hash: hashPassword,
    });
    await rest(config, "students", {
      method: "POST",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({ id: student.id, data: student.data }),
    });
    return res.status(201).json({
      studentId: student.id,
      username: student.username,
      password: student.password,
      grade,
    });
  } catch (error) {
    logger.error({ err: error }, "Open edition student registration failed");
    return res.status(503).json({ error: "تعذّر إنشاء حسابك الآن. حاول مرة أخرى." });
  }
});

export default router;
