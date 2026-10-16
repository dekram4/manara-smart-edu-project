import { Router, type Request, type Response } from "express";
import rateLimit from "express-rate-limit";
import { requireStudentSession } from "../middleware/studentAuth";
import { forwardedClientKey } from "../middleware/rateLimiter";
import { logger } from "../lib/logger";
import { safeStudentData, studentRecord, type StudentActor } from "../lib/studentAccess";
import { asRecords, rest, storeConfig, teacherIdentities } from "../lib/supabaseStore";

/**
 * ملفُّ الطالب لتطبيقه — بديلُ قراءة جدولَي `students` و`teachers` بالمفتاح العام.
 *
 * كان التطبيق يقرأ صفَّه من `students` (ومعه كلمةُ المرور والهوية وجوال وليّ
 * الأمر) وجدولَ `teachers` كاملاً ليعرف أسماء معلّمه. فكان على المفتاح العام —
 * وهو داخل كل APK — أن يقرأ الجدولين، فقرأهما كلُّ من يملكه. الآن يقرأ الطالبُ
 * صفَّه وحده، بلا حقوله الخاصة، بعد التحقّق من رمزه.
 */
const router = Router();

const readLimit = rateLimit({
  windowMs: 60_000,
  limit: 120,
  standardHeaders: "draft-8",
  legacyHeaders: false,
  keyGenerator: (req: Request) => forwardedClientKey(req),
  message: { error: "تجاوزت الحد المسموح به من الطلبات. يرجى الانتظار دقيقة." },
});

router.get("/student/me", readLimit, requireStudentSession, async (_req: Request, res: Response) => {
  const student = res.locals.student as StudentActor;
  try {
    const record = await studentRecord(student);
    if (!record) {
      res.status(404).json({ error: "لم يُعثر على حساب الطالب" });
      return;
    }
    const config = storeConfig();
    // أسماءُ المعلّم كلُّها (معرّفه واسم دخوله واسمه): سجلُّ الطالب قد يحمل
    // أيّاً منها، ودروسُ المعلم تُطابق بأيٍّ منها.
    const identities = config && student.teacherId
      ? [...(await teacherIdentities(config, student.teacherId))]
      : [];
    res.json({
      student: { id: record.id, data: safeStudentData(record.data) },
      teacherIdentities: identities,
    });
  } catch (error) {
    logger.error({ err: error }, "[student] profile read failed");
    res.status(503).json({ error: "تعذّر قراءة حسابك الآن" });
  }
});

/** صفوفُ هذا الطالب وحده من جدولٍ يحمل `data->>studentId`. */
async function ownRows(
  table: "quiz_results" | "interactions",
  student: StudentActor,
  query: string,
): Promise<Record<string, unknown>[]> {
  const config = storeConfig();
  if (!config) throw new Error("Supabase is not configured");
  const ids = [...new Set([student.id, student.rowId].filter(Boolean))]
    .map((id) => `"${id.replace(/"/g, '\\"')}"`)
    .join(",");
  const rows = asRecords(
    await rest(config, `${table}?select=id,data,updated_at&data->>studentId=in.(${encodeURIComponent(ids)})&${query}`),
  );
  return rows;
}

/**
 * نتائجُ اختبارات الطالب — كانت تُقرأ من `quiz_results` بالمفتاح العام،
 * فكانت نتائجُ الطلاب كلِّهم مقروءةً لكل من يملكه.
 */
router.get("/student/quiz-results", readLimit, requireStudentSession, async (_req: Request, res: Response) => {
  const student = res.locals.student as StudentActor;
  try {
    const rows = await ownRows("quiz_results", student, "order=updated_at.desc&limit=100");
    res.json({
      results: rows.map((row) => {
        const data = (row.data && typeof row.data === "object" ? row.data : {}) as Record<string, unknown>;
        return { ...data, id: typeof row.id === "string" && row.id ? row.id : data.id };
      }),
    });
  } catch (error) {
    logger.error({ err: error }, "[student] quiz results read failed");
    res.status(503).json({ error: "تعذّر قراءة نتائجك الآن" });
  }
});

/** محادثاتُ الطالب مع المعلّم الافتراضي — كانت من `interactions` بالمفتاح العام. */
router.get("/student/tutor-history", readLimit, requireStudentSession, async (_req: Request, res: Response) => {
  const student = res.locals.student as StudentActor;
  try {
    const rows = await ownRows("interactions", student, "order=updated_at.asc&limit=60");
    res.json({
      history: rows
        .map((row) => (row.data && typeof row.data === "object" ? row.data : {}) as Record<string, unknown>)
        .filter((data) => data.type === "virtual_teacher"),
    });
  } catch (error) {
    logger.error({ err: error }, "[student] tutor history read failed");
    res.status(503).json({ error: "تعذّر قراءة محادثاتك الآن" });
  }
});

export default router;
