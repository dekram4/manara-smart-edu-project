import { Router, type Request, type Response } from "express";
import { requireAdmin, requireContentManager, type WriteActor } from "../middleware/adminAuth";
import {
  allLessonRows,
  duelDomainReady,
  refreshDuelDomainQuestions,
  type DomainRunSummary,
} from "../lib/duelDomainJob";
import { logger } from "../lib/logger";
import {
  canSeeQuestion,
  canToggleQuestion,
  disabledByOf,
  duelSubjectKey,
  lessonOwner,
  ownerKey,
} from "../lib/duelDomainBank";

/**
 * مراجعةُ بنك أسئلة المبارزة: يستعرضه المعلمُ والمشرف، ويعطّلان منه ويفعّلان.
 *
 * ── من يرى ماذا ──
 * المشرفُ كلَّ شيء. والمعلمُ ما وُلّد من دروسه، والمشتركَ في موادّه — وهو ما
 * يلعبه طلّابه فعلاً.
 *
 * ── ومن يعطّل ماذا ──
 * المشرفُ كلَّ سؤال، والمعلمُ ما وُلّد من دروسه وحدها. والقرارُ في
 * `canToggleQuestion` لا هنا، فيُختبر وحده.
 *
 * والبنكُ لا يقرؤه anon أصلاً — فيه الأجوبة — فالقراءةُ هنا بدور الخدمة، وكلُّ
 * ما يُعاد مفحوصٌ بصلاحية الفاعل.
 */
const router = Router();

const QUESTIONS = "duel_questions";
const PAGE_MAX = 200;

type Config = { url: string; key: string };

function config(): Config | null {
  const url = process.env.SUPABASE_URL?.trim().replace(/\/+$/, "");
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  return url && key ? { url, key } : null;
}

async function rest(path: string, init: RequestInit = {}): Promise<unknown> {
  const settings = config();
  if (!settings) throw new Error("Supabase is not configured");
  const response = await fetch(`${settings.url}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: settings.key,
      Authorization: `Bearer ${settings.key}`,
      Accept: "application/json",
      ...(init.body ? { "Content-Type": "application/json" } : {}),
      ...(init.headers as Record<string, string> | undefined),
    },
  });
  const body = await response.text();
  if (!response.ok) throw new Error(body || `Supabase ${response.status}`);
  return body ? JSON.parse(body) : null;
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function records(value: unknown): Record<string, unknown>[] {
  return Array.isArray(value)
    ? value.filter((item): item is Record<string, unknown> => Boolean(item) && typeof item === "object")
    : [];
}

/** قيمةٌ في مرشّح PostgREST: بين علامتي تنصيص، فلا تكسره فاصلةٌ أو قوس. */
function quoted(value: string): string {
  return `"${value.replace(/["\\]/g, "")}"`;
}

interface LessonInfo {
  title: string;
  subject: string;
  grade: string;
  unit: string;
  owner: string;
}

/**
 * الدروسُ بعناوينها ومالكيها — بلا نصوصها: سجلُّ الدرس فيه الشرحُ كاملاً، وهذه
 * القائمةُ تحتاج اسمَه وحده.
 */
async function lessons(): Promise<Map<string, LessonInfo>> {
  const rows = records(await rest(
    "lesson_configs?select=id," +
      "lesson:data->>lesson,subject:data->>subject,grade:data->>grade,unit:data->>unit," +
      "teacher_id:data->>teacher_id,teacherId:data->>teacherId,createdBy:data->>createdBy",
  ));
  const map = new Map<string, LessonInfo>();
  for (const row of rows) {
    const id = text(row.id);
    if (!id) continue;
    map.set(id, {
      title: text(row.lesson) || text(row.unit),
      subject: text(row.subject),
      grade: text(row.grade),
      unit: text(row.unit),
      owner: lessonOwner(row),
    });
  }
  return map;
}

/** موادُّ المعلم بمفاتيحها، من دروسه. */
function subjectsOf(
  actor: WriteActor,
  lessonMap: Map<string, LessonInfo>,
): Set<string> {
  const subjects = new Set<string>();
  if (actor.role !== "teacher") return subjects;
  const me = ownerKey(actor.teacherId);
  for (const lesson of lessonMap.values()) {
    if (ownerKey(lesson.owner) !== me) continue;
    const key = duelSubjectKey(lesson.subject);
    if (key !== "other") subjects.add(key);
  }
  return subjects;
}

function toJson(
  row: Record<string, unknown>,
  actor: WriteActor,
  lessonMap: Map<string, LessonInfo>,
) {
  const lessonId = text(row.lesson_id);
  const lesson = lessonId ? lessonMap.get(lessonId) : undefined;
  return {
    id: text(row.id),
    subjectKey: text(row.subject_key),
    unit: text(row.unit),
    gradeBand: text(row.grade_band),
    category: text(row.category),
    prompt: text(row.prompt),
    choices: Array.isArray(row.choices) ? row.choices.map(text) : [],
    source: text(row.source),
    active: row.active === true,
    disabledBy: text(row.disabled_by) || null,
    disabledAt: text(row.disabled_at) || null,
    lessonId: lessonId || null,
    lessonTitle: lesson?.title ?? null,
    teacherId: text(row.teacher_id) || null,
    createdAt: text(row.created_at),
    canToggle: canToggleQuestion(actor, {
      teacher_id: text(row.teacher_id),
      subject_key: text(row.subject_key),
    }),
  };
}

/**
 * قائمةُ الأسئلة بمرشّحاتها.
 *
 *   subject  مفتاحُ المادة، أو `*` للعامّ.
 *   source   seed | ai | teacher
 *   status   active | disabled — وبلا قيمةٍ الكلّ.
 *   q        بحثٌ في نصّ السؤال.
 *   mine     1: ما وُلّد من دروسي وحدها (للمعلم).
 *   limit, offset
 */
router.get("/duel-questions", requireContentManager, async (req: Request, res: Response) => {
  const actor = res.locals.contentActor as WriteActor;
  if (!config()) {
    return res.status(503).json({ error: "Supabase غير مهيّأ على الخادم" });
  }
  const limit = Math.min(PAGE_MAX, Math.max(1, Number(req.query.limit) || 50));
  const offset = Math.max(0, Number(req.query.offset) || 0);

  try {
    const lessonMap = await lessons();
    const subjects = subjectsOf(actor, lessonMap);

    const filters: string[] = [];
    const subject = text(req.query.subject);
    if (subject) filters.push(`subject_key=eq.${encodeURIComponent(subject)}`);
    const source = text(req.query.source);
    if (["seed", "ai", "teacher"].includes(source)) filters.push(`source=eq.${source}`);
    const status = text(req.query.status);
    if (status === "active") filters.push("active=is.true");
    if (status === "disabled") filters.push("active=is.false");
    const search = text(req.query.q).replace(/[*,()"\\]/g, " ").trim();
    if (search) filters.push(`prompt=ilike.${encodeURIComponent(`*${search}*`)}`);

    // ── والمعلمُ يُضيَّق في القاعدة قبل أن يُفحص هنا ──
    // بلا ذلك تُقرأ آلافُ أسئلة المدارس كلّها لتُرمى إلا عشرات.
    if (actor.role === "teacher") {
      // ilike: معرّفُ المعلم في السجلّ قد يختلف عن جلسته في حالة الحروف. وما يزيد
      // به المرشّحُ تردّه `canSeeQuestion` بعده.
      const mine = `teacher_id.ilike.${quoted(actor.teacherId)}`;
      if (text(req.query.mine) === "1") {
        filters.push(`or=(${encodeURIComponent(mine)})`);
      } else {
        const shared = ["*", ...subjects].map(quoted).join(",");
        filters.push(`or=(${encodeURIComponent(`${mine},subject_key.in.(${shared})`)})`);
      }
    }

    // سطرٌ زائدٌ يقول إن بعد الصفحة صفحة، بلا عدٍّ كاملٍ للجدول.
    const rows = records(await rest(
      `${QUESTIONS}?select=*&${filters.join("&")}` +
        `&order=created_at.desc,id.asc&limit=${limit + 1}&offset=${offset}`,
    ));
    const visible = rows.filter((row) =>
      canSeeQuestion(
        actor,
        { teacher_id: text(row.teacher_id), subject_key: text(row.subject_key) },
        subjects,
      ),
    );
    return res.json({
      role: actor.role,
      subjects: [...subjects],
      questions: visible.slice(0, limit).map((row) => toJson(row, actor, lessonMap)),
      hasMore: rows.length > limit,
      // ما فحصه الخادمُ من القاعدة لا ما عرضه: `canSeeQuestion` قد تردّ صفّاً،
      // فعددُ المعروض موضعٌ خاطئٌ للصفحة التالية.
      nextOffset: offset + Math.min(rows.length, limit),
    });
  } catch (error) {
    logger.error({ err: error }, "[duel-questions] list failed");
    return res.status(503).json({ error: "تعذّر قراءة بنك الأسئلة الآن" });
  }
});

/**
 * تعطيلُ سؤالٍ أو تفعيلُه. الجسم: `{ "active": false }`.
 *
 * والتعطيلُ يكتب من عطّل ومتى، والتفعيلُ يمحوهما: سؤالٌ مفعّلٌ عليه «عطّله
 * فلان» يُقرأ معطّلاً بنظرةٍ سريعة.
 */
router.post(
  "/duel-questions/:id/active",
  requireContentManager,
  async (req: Request, res: Response) => {
    const actor = res.locals.contentActor as WriteActor;
    const id = text(req.params.id);
    const active = req.body?.active;
    if (!id) return res.status(400).json({ error: "معرّف السؤال ناقص" });
    if (typeof active !== "boolean") {
      return res.status(400).json({ error: "active يجب أن يكون true أو false" });
    }
    if (!config()) {
      return res.status(503).json({ error: "Supabase غير مهيّأ على الخادم" });
    }
    try {
      const found = records(await rest(
        `${QUESTIONS}?select=id,teacher_id,subject_key&id=eq.${encodeURIComponent(id)}&limit=1`,
      ))[0];
      if (!found) return res.status(404).json({ error: "السؤال غير موجود" });
      if (!canToggleQuestion(actor, {
        teacher_id: text(found.teacher_id),
        subject_key: text(found.subject_key),
      })) {
        return res.status(403).json({
          error: "هذا سؤالٌ مشترك بين الصفوف — يعطّله المشرف",
          code: "shared_question",
        });
      }
      const updated = records(await rest(
        `${QUESTIONS}?id=eq.${encodeURIComponent(id)}`,
        {
          method: "PATCH",
          headers: { Prefer: "return=representation" },
          body: JSON.stringify(
            active
              ? { active: true, disabled_by: null, disabled_at: null }
              : {
                  active: false,
                  disabled_by: disabledByOf(actor),
                  disabled_at: new Date().toISOString(),
                },
          ),
        },
      ))[0];
      logger.info(
        { id, active, by: disabledByOf(actor) },
        "[duel-questions] toggled",
      );
      return res.json({
        question: updated ? toJson(updated, actor, new Map()) : null,
      });
    } catch (error) {
      logger.error({ err: error, id }, "[duel-questions] toggle failed");
      return res.status(503).json({ error: "تعذّر حفظ التغيير الآن" });
    }
  },
);

// ── توليدُ الأسئلة لكل الدروس — زرُّ المشرف ──

/**
 * حالُ التشغيلة الشاملة.
 *
 * في ذاكرة الخادم لا في القاعدة: هي حالُ عمليةٍ جاريةٍ في هذا الخادم، تُقرأ
 * لشريط التقدّم وتنتهي بانتهائها. وإن أُعيد تشغيلُ الخادم في منتصفها ضاعت
 * الحالُ ولم يضع شيءٌ مما كُتب — والضغطُ من جديد يكمل من حيث توقّفت، لأنّ
 * ما وُلّد يُتخطّى.
 */
interface GenerateJob {
  running: boolean;
  startedAt: string | null;
  finishedAt: string | null;
  summary: DomainRunSummary | null;
  error: string | null;
}

const job: GenerateJob = {
  running: false,
  startedAt: null,
  finishedAt: null,
  summary: null,
  error: null,
};

/** حالُ التشغيلة، لشريط التقدّم. */
router.get("/duel-questions/generate-all", requireAdmin, (_req: Request, res: Response) => {
  res.json({ job, ready: duelDomainReady() });
});

/**
 * يبدأ التوليدَ لكل الدروس ويردّ فوراً (202): التشغيلةُ دقائقُ — نداءٌ للنموذج
 * لكل درس — ولا يُبقى المتصفّحُ معلّقاً عليها. والتقدّمُ يُقرأ من GET.
 *
 * وتشغيلتان معاً لا تكونان: الثانيةُ تولّد للدروس نفسها قبل أن تكتب الأولى
 * بصماتِها، فيُدفع لكل درسٍ مرّتين.
 */
router.post("/duel-questions/generate-all", requireAdmin, (_req: Request, res: Response) => {
  if (job.running) {
    return res.status(409).json({ error: "التوليد يعمل الآن", code: "running", job });
  }
  if (!duelDomainReady()) {
    return res.status(503).json({
      error: "التوليد غير مهيّأ على الخادم: يلزم GEMINI_API_KEY وSupabase",
      code: "not_ready",
    });
  }
  job.running = true;
  job.startedAt = new Date().toISOString();
  job.finishedAt = null;
  job.summary = null;
  job.error = null;

  void (async () => {
    try {
      const rows = await allLessonRows();
      job.summary = await refreshDuelDomainQuestions(rows, (summary) => {
        job.summary = summary;
      });
      logger.info({ summary: job.summary }, "[duel-questions] generate-all finished");
    } catch (error) {
      job.error = error instanceof Error ? error.message : String(error);
      logger.error({ err: error }, "[duel-questions] generate-all failed");
    } finally {
      job.running = false;
      job.finishedAt = new Date().toISOString();
    }
  })();

  return res.status(202).json({ job });
});

export default router;
