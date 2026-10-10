import { Router, type Request, type Response } from "express";
import rateLimit from "express-rate-limit";
import { getContentActor } from "../middleware/adminAuth";
import { requireStudentSession } from "../middleware/studentAuth";
import { forwardedClientKey } from "../middleware/rateLimiter";
import { logger } from "../lib/logger";
import { listStudents, type StudentActor } from "../lib/studentAccess";
import { scopeKey } from "../lib/cinema";
import {
  STUDENT_CARDS,
  classRuleId,
  effectiveCards,
  ruleFromRecord,
  ruleToTableRow,
  sanitizeCards,
  studentRuleId,
  type CardRule,
  type StudentCardId,
} from "../lib/cardPermissions";
import {
  asRecords,
  listTeachers,
  readKv,
  rest,
  storeConfig,
  teacherIdentities,
  withTableFallback,
  writeKv,
  type StoreConfig,
} from "../lib/supabaseStore";

/**
 * صلاحيات بطاقات الطالب: يضبطها المعلم لطلابه والمشرف للجميع، ويقرؤها التطبيق.
 *
 * المصدر جدول `student_card_permissions`، وإن لم يُنشأ بعد فمفتاح
 * `app_kv/smartEdu_cardPermissions` — انظر `lib/supabaseStore.ts`.
 */
const router = Router();

const TABLE = "student_card_permissions";
const KV_KEY = "smartEdu_cardPermissions";

const RATE_LIMIT_SHARED = {
  windowMs: 60_000,
  standardHeaders: "draft-8" as const,
  legacyHeaders: false,
  keyGenerator: (req: Request) => forwardedClientKey(req),
  message: { error: "تجاوزت الحد المسموح به من الطلبات. يرجى الانتظار دقيقة." },
};
const readLimit = rateLimit({ ...RATE_LIMIT_SHARED, limit: 120 });
const writeLimit = rateLimit({ ...RATE_LIMIT_SHARED, limit: 60 });

/** سببُ الفشل كما قاله Supabase، مختصراً — للمعلم والمشرف وحدهما. */
function failureDetail(error: unknown): string {
  return error instanceof Error ? error.message.slice(0, 300) : "";
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * القواعد من الجدول ومن مفتاح `app_kv` معاً، والجدول يغلب عند تكرار المعرّف.
 *
 * لا أحدهما وحده: جدولٌ بالاسم نفسه وبنيةٍ أخرى يُقرأ بلا خطأ ويرفض الكتابة،
 * فتُحفظ القواعد في المفتاح — ولو قُرئ الجدولُ وحده لضاع ما حُفظ هناك.
 * وصفوفُ تلك البنية الأخرى لا تُفهم قاعدةً فتسقط في `ruleFromRecord`.
 */
async function loadRules(config: StoreConfig): Promise<CardRule[]> {
  const [table, kv] = await Promise.all([
    withTableFallback(
      TABLE,
      async () => asRecords(await rest(config, `${TABLE}?select=*&limit=10000`)),
      async () => [] as Record<string, unknown>[],
    ),
    readKv(config, KV_KEY).then(asRecords),
  ]);
  const byId = new Map<string, CardRule>();
  for (const record of [...kv, ...table.value]) {
    const rule = ruleFromRecord(record);
    if (rule) byId.set(rule.id, rule);
  }
  return Array.from(byId.values());
}

async function removeFromKv(config: StoreConfig, id: string): Promise<void> {
  const records = asRecords(await readKv(config, KV_KEY));
  const kept = records.filter((item) => text(item.id) !== id);
  if (kept.length !== records.length) await writeKv(config, KV_KEY, kept);
}

async function saveRule(config: StoreConfig, rule: CardRule): Promise<"table" | "kv"> {
  const { storage } = await withTableFallback(
    TABLE,
    async () => {
      await rest(config, `${TABLE}?on_conflict=id`, {
        method: "POST",
        headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
        body: JSON.stringify(ruleToTableRow(rule)),
      });
    },
    async () => undefined,
  );
  // ── ونسخةٌ في `app_kv` دائماً، لا عند غياب الجدول وحده ──
  // تطبيقُ الطالب يقرأ `app_kv` مباشرةً من Supabase بمفتاح anon حين لا يصل
  // إلى هذا الخادم — وهو ما وقع فعلاً: نسخةٌ من التطبيق بُنيت بعنوان الخادم
  // القديم، فلم تسأل هنا قطّ، وبقيت البطاقاتُ المقفلة عندها مفتوحة. والجدولُ
  // لا يقرؤه anon (RLS)، فالمفتاحُ هو الطريق الذي لا يتوقّف على العنوان.
  await upsertKv(config, rule);
  return storage;
}

async function upsertKv(config: StoreConfig, rule: CardRule): Promise<void> {
  const records = asRecords(await readKv(config, KV_KEY)).filter((item) => text(item.id) !== rule.id);
  records.push(ruleToTableRow(rule));
  await writeKv(config, KV_KEY, records);
}

async function deleteRule(config: StoreConfig, id: string): Promise<void> {
  await withTableFallback(
    TABLE,
    async () => {
      await rest(config, `${TABLE}?id=eq.${encodeURIComponent(id)}`, {
        method: "DELETE",
        headers: { Prefer: "return=minimal" },
      });
    },
    async () => undefined,
  );
  // والمفتاح دائماً: القاعدة قد تكون فيه وإن كان الجدول موجوداً.
  await removeFromKv(config, id);
}

/**
 * هل البطاقة مفتوحة لهذا الطالب؟ للمسارات التي تفرض الصلاحية في الخادم
 * (السينما)، لا في الواجهة وحدها.
 *
 * وإن تعذّرت قراءة القواعد تُعدّ مفتوحة: خللٌ في التخزين لا يُغلق على
 * الطلاب ما لم يغلقه أحد.
 */
export async function isCardOpenForStudent(
  config: StoreConfig,
  student: StudentActor,
  identities: Set<string>,
  card: StudentCardId,
): Promise<boolean> {
  try {
    const rules = await loadRules(config);
    return effectiveCards(rules, {
      id: student.id,
      ids: [student.rowId],
      grade: student.grade,
      teacherIdentities: identities,
    })[card];
  } catch (error) {
    logger.warn({ err: error }, "[card-permissions] rules unavailable; card left open");
    return true;
  }
}

/** طلابٌ يديرهم الفاعل: المشرف كلّهم، والمعلم من يحمل أحدَ أسمائه. */
function manageableStudents(
  students: StudentActor[],
  actor: NonNullable<ReturnType<typeof getContentActor>>,
  identities: Set<string>,
): StudentActor[] {
  if (actor.role === "admin") return students;
  return students.filter((student) => identities.has(scopeKey(student.teacherId)));
}

function ruleIsManageable(
  rule: CardRule,
  actor: NonNullable<ReturnType<typeof getContentActor>>,
  identities: Set<string>,
  studentIds: Set<string>,
): boolean {
  if (actor.role === "admin") return true;
  if (rule.scope === "student") return studentIds.has(text(rule.studentId));
  return identities.has(scopeKey(rule.teacherId));
}

// ── لوحة المعلم والمشرف ─────────────────────────────────────────────────

router.use("/card-permissions", readLimit);

/**
 * ما تحتاجه شاشة الصلاحيات كلُّه في طلبٍ واحد: البطاقات، والطلاب، والقواعد.
 */
router.get("/card-permissions", async (req: Request, res: Response) => {
  const actor = getContentActor(req);
  if (!actor) {
    res.status(401).json({ error: "يجب تسجيل الدخول كمعلم أو مشرف" });
    return;
  }
  const config = storeConfig();
  if (!config) {
    res.status(503).json({ error: "Supabase غير مُعدّ على الخادم" });
    return;
  }
  try {
    const identities = actor.role === "teacher"
      ? await teacherIdentities(config, actor.teacherId)
      : new Set<string>();
    const [allStudents, rules, teachers] = await Promise.all([
      listStudents(),
      loadRules(config),
      actor.role === "admin" ? listTeachers(config) : Promise.resolve([]),
    ]);
    const students = manageableStudents(allStudents, actor, identities);
    const studentIds = new Set(students.map((student) => student.id));
    res.json({
      cards: STUDENT_CARDS,
      teachers,
      students: students.map((student) => ({
        id: student.id,
        name: student.name,
        grade: student.grade,
        teacherId: student.teacherId,
      })),
      rules: rules.filter((rule) => ruleIsManageable(rule, actor, identities, studentIds)),
    });
  } catch (error) {
    logger.error({ err: error }, "[card-permissions] list failed");
    res.status(502).json({ error: "تعذر تحميل صلاحيات البطاقات", detail: failureDetail(error) });
  }
});

/**
 * يحفظ قاعدةً واحدة: لصفٍّ (`teacherId` + `gradeId`) أو لطالبٍ (`studentId`).
 */
router.put("/card-permissions", writeLimit, async (req: Request, res: Response) => {
  const actor = getContentActor(req);
  if (!actor) {
    res.status(401).json({ error: "يجب تسجيل الدخول كمعلم أو مشرف" });
    return;
  }
  const config = storeConfig();
  if (!config) {
    res.status(503).json({ error: "Supabase غير مُعدّ على الخادم" });
    return;
  }
  const body = (req.body && typeof req.body === "object" ? req.body : {}) as Record<string, unknown>;
  const scope = body.scope === "class" || body.scope === "student" ? body.scope : null;
  if (!scope) {
    res.status(400).json({ error: "نطاق الصلاحية غير صالح" });
    return;
  }
  const cards = sanitizeCards(body.cards);
  const updatedBy = actor.role === "admin" ? "admin" : actor.teacherId;

  try {
    const identities = actor.role === "teacher"
      ? await teacherIdentities(config, actor.teacherId)
      : new Set<string>();
    let rule: CardRule;

    if (scope === "student") {
      const studentId = text(body.studentId);
      const student = manageableStudents(await listStudents(), actor, identities)
        .find((item) => item.id === studentId || item.rowId === studentId);
      if (!student) {
        res.status(403).json({ error: "لا يمكنك تعديل صلاحيات هذا الطالب" });
        return;
      }
      rule = {
        id: studentRuleId(student.id),
        scope,
        studentId: student.id,
        teacherId: student.teacherId || updatedBy,
        gradeId: student.grade || null,
        cards,
        updatedBy,
        updatedAt: new Date().toISOString(),
      };
    } else {
      const gradeId = text(body.gradeId);
      const teacherId = actor.role === "admin" ? text(body.teacherId) : actor.teacherId;
      if (!gradeId || !teacherId) {
        res.status(400).json({ error: "يرجى تحديد المعلم والصف الدراسي" });
        return;
      }
      if (actor.role === "teacher" && text(body.teacherId) &&
          !identities.has(scopeKey(body.teacherId))) {
        res.status(403).json({ error: "لا يمكن للمعلم تعديل صلاحيات صف معلم آخر" });
        return;
      }
      rule = {
        id: classRuleId(teacherId, gradeId),
        scope,
        studentId: null,
        teacherId,
        gradeId,
        cards,
        updatedBy,
        updatedAt: new Date().toISOString(),
      };
    }

    const storage = await saveRule(config, rule);
    res.json({ storage, rule });
  } catch (error) {
    logger.error({ err: error }, "[card-permissions] save failed");
    res.status(502).json({ error: "تعذر حفظ صلاحيات البطاقات", detail: failureDetail(error) });
  }
});

/** يحذف قاعدة، فيعود الطالب إلى قاعدة صفّه أو الصفّ إلى الافتراضي (الكل مفتوح). */
router.delete("/card-permissions/:id", writeLimit, async (req: Request, res: Response) => {
  const actor = getContentActor(req);
  if (!actor) {
    res.status(401).json({ error: "يجب تسجيل الدخول كمعلم أو مشرف" });
    return;
  }
  const config = storeConfig();
  if (!config) {
    res.status(503).json({ error: "Supabase غير مُعدّ على الخادم" });
    return;
  }
  const id = text(req.params.id);
  if (!id || id.length > 400) {
    res.status(400).json({ error: "معرّف القاعدة غير صالح" });
    return;
  }
  try {
    const identities = actor.role === "teacher"
      ? await teacherIdentities(config, actor.teacherId)
      : new Set<string>();
    const rules = await loadRules(config);
    const rule = rules.find((item) => item.id === id);
    if (!rule) {
      res.status(204).end();
      return;
    }
    const studentIds = new Set(
      manageableStudents(await listStudents(), actor, identities).map((student) => student.id),
    );
    if (!ruleIsManageable(rule, actor, identities, studentIds)) {
      res.status(403).json({ error: "لا يمكنك حذف هذه الصلاحية" });
      return;
    }
    await deleteRule(config, id);
    res.status(204).end();
  } catch (error) {
    logger.error({ err: error }, "[card-permissions] delete failed");
    res.status(502).json({ error: "تعذر حذف صلاحيات البطاقات", detail: failureDetail(error) });
  }
});

// ── تطبيق الطالب ─────────────────────────────────────────────────────────

router.get(
  "/student/card-permissions",
  readLimit,
  requireStudentSession,
  async (_req: Request, res: Response) => {
    const student = res.locals.student as StudentActor;
    const config = storeConfig();
    if (!config) {
      res.status(503).json({ error: "Supabase غير مُعدّ على الخادم" });
      return;
    }
    try {
      const identities = await teacherIdentities(config, student.teacherId);
      const rules = await loadRules(config);
      res.json({
        cards: effectiveCards(rules, {
          id: student.id,
          ids: [student.rowId],
          grade: student.grade,
          teacherIdentities: identities,
        }),
      });
    } catch (error) {
      logger.error({ err: error }, "[card-permissions] student read failed");
      res.status(502).json({ error: "تعذر تحميل صلاحيات البطاقات", detail: failureDetail(error) });
    }
  },
);

export default router;
