/**
 * فئاتُ الاشتراك وما تفتحه من بطاقات، وطلباتُ الانضمام — بلا قاعدة بيانات.
 *
 * ── أين تُطبَّق ──
 * باقةُ الطالب (`subscriptionPlan` في سجلّه) هي الحالةُ الابتدائية للبطاقات،
 * ثم تأتي قواعدُ «صلاحيات البطاقات» فوقها كما كانت (`effectiveCards`): ما
 * يفتحه المشرفُ أو يغلقه يدوياً لطالبٍ أو صفّ يغلب الباقةَ دائماً.
 *
 * وحسابٌ بلا باقة (كلُّ الحسابات قبل هذا النظام) يبقى مفتوحاً كما كان.
 */
import type { CardMap, StudentCardId } from "./cardPermissions";

export const PLAN_IDS = [
  "demo",
  "individual",
  "family",
  "school_small",
  "school_medium",
  "school_large",
] as const;

export type PlanId = (typeof PLAN_IDS)[number];

/** بطاقاتٌ تُدار بالصلاحيات، كما في `STUDENT_CARDS`. */
const ALL_CARDS: StudentCardId[] = [
  "lesson", "cinema", "games", "personality", "tutor", "quiz", "solver", "meeting", "chat", "challenge", "study",
];

/** ما لا تشمله الباقةُ الفردية. */
const INDIVIDUAL_LOCKED: StudentCardId[] = ["chat", "challenge", "meeting", "tutor", "solver"];
/** ما لا تشمله باقةُ المجموعات والعائلة. */
const FAMILY_LOCKED: StudentCardId[] = ["meeting", "tutor", "solver"];

export type PlanInfo = {
  id: PlanId;
  name: string;
  group: "demo" | "individual" | "family" | "school";
  /** أقصى عدد طلاب للفئة المؤسسية؛ `null` مفتوح. */
  seats: number | null;
  minSeats?: number;
};

export const PLANS: PlanInfo[] = [
  { id: "demo", name: "وضع الزائر", group: "demo", seats: null },
  { id: "individual", name: "الباقة الفردية", group: "individual", seats: 1 },
  { id: "family", name: "باقة المجموعات والعائلة", group: "family", seats: null, minSeats: 3 },
  { id: "school_small", name: "المؤسسية — روضة/مدرسة مصغّرة", group: "school", seats: 25 },
  { id: "school_medium", name: "المؤسسية — روضة/مدرسة متوسطة", group: "school", seats: 50 },
  { id: "school_large", name: "المؤسسية — روضة/مدرسة شاملة", group: "school", seats: null, minSeats: 100 },
];

export function isPlanId(value: unknown): value is PlanId {
  return typeof value === "string" && (PLAN_IDS as readonly string[]).includes(value);
}

/** باقةُ سجلّ الطالب، أو `null` لحسابٍ قبل نظام الباقات. */
export function planOf(data: Record<string, unknown> | null | undefined): PlanId | null {
  const value = data?.subscriptionPlan ?? data?.subscription_plan;
  return isPlanId(value) ? value : null;
}

/**
 * الحالةُ الابتدائية لبطاقات باقة. الزائرُ يدخل البطاقاتِ كلَّها (والتطبيقُ
 * يقيّد ما بداخلها ويعرض رسالةَ البطاقات المدفوعة)، والمؤسسيةُ مفتوحةٌ كلُّها.
 */
export function planCards(plan: PlanId | null): CardMap {
  const open = (locked: StudentCardId[]): CardMap =>
    Object.fromEntries(ALL_CARDS.map((card) => [card, !locked.includes(card)])) as CardMap;
  switch (plan) {
    case "individual":
      return open(INDIVIDUAL_LOCKED);
    case "family":
      return open(FAMILY_LOCKED);
    default:
      return open([]);
  }
}

// ── وضعُ الزائر ──────────────────────────────────────────────────────────

/** اسما دخول حسابَي العرض: من البيئة، وإلا الافتراضيّان. */
export function demoUsernames(env: Record<string, string | undefined> = process.env): Record<"kg" | "grade4", string> {
  return {
    kg: env.DEMO_KG_USERNAME?.trim() || "demo_kg",
    grade4: env.DEMO_GRADE4_USERNAME?.trim() || "demo_grade4",
  };
}

/** حسابُ عرضٍ يشاركه كلُّ الزوّار: لا تُحفظ فيه مكافآتٌ ولا تقدّمٌ ولا شخصية. */
export function isDemoStudent(student: { username?: string; plan?: string | null }): boolean {
  if (student.plan === "demo") return true;
  const names = Object.values(demoUsernames());
  return Boolean(student.username) && names.includes(student.username!.trim());
}

// ── طلباتُ الانضمام ─────────────────────────────────────────────────────

export const JOIN_REQUEST_TYPE = "join_request";
export const JOIN_STATUSES = ["new", "contacted", "activated", "rejected"] as const;
export type JoinStatus = (typeof JOIN_STATUSES)[number];

export type JoinRequest = {
  plan: Exclude<PlanId, "demo">;
  name: string;
  grade: string;
  students: number | null;
  phone: string;
  note: string;
  status: JoinStatus;
  createdAt: string;
};

function text(value: unknown, max: number): string {
  return typeof value === "string" ? value.trim().replace(/\s+/g, " ").slice(0, max) : "";
}

/** يتحقّق من طلبٍ قادمٍ من التطبيق؛ يعيد نصَّ الخطأ أو الطلب. */
export function parseJoinRequest(body: unknown, now = new Date()): JoinRequest | { error: string } {
  const input = (body && typeof body === "object" ? body : {}) as Record<string, unknown>;
  const plan = input.plan;
  if (!isPlanId(plan) || plan === "demo") return { error: "اختر باقةً صحيحة" };
  const name = text(input.name, 120);
  if (name.length < 2) return { error: "اكتب اسم الطالب أو الجهة" };
  const phone = text(input.phone, 30).replace(/[^\d+]/g, "");
  if (phone.replace(/\D/g, "").length < 8) return { error: "اكتب رقم جوالٍ صحيحاً" };
  const rawStudents = Number(input.students);
  const students = Number.isFinite(rawStudents) && rawStudents > 0 ? Math.min(Math.floor(rawStudents), 100000) : null;
  const info = PLANS.find((p) => p.id === plan)!;
  if (info.minSeats && (students ?? 0) < info.minSeats && plan === "family") {
    return { error: `باقة المجموعات لـ ${info.minSeats} طلاب على الأقل` };
  }
  return {
    plan,
    name,
    grade: text(input.grade, 80),
    students,
    phone,
    note: text(input.note, 500),
    status: "new",
    createdAt: now.toISOString(),
  };
}

/** الفئةُ المؤسسية المناسبة لعدد [students]. */
export function schoolTierFor(students: number): PlanId {
  if (students <= 25) return "school_small";
  if (students <= 50) return "school_medium";
  return "school_large";
}
