/**
 * فئاتُ الاشتراك كما يراها المشرف — مطابقةٌ لـ `api-server/src/lib/subscriptionPlans.ts`
 * ولـ `subscription_plans.dart` في تطبيق الطالب.
 *
 * الباقةُ هي الحالةُ الابتدائية لبطاقات الطالب، و«صلاحيات البطاقات» اليدوية
 * تغلبها دائماً. وحسابٌ بلا باقة يبقى مفتوحاً كما كان.
 */
export type PlanId = 'demo' | 'individual' | 'family' | 'school_small' | 'school_medium' | 'school_large';

export const PLAN_OPTIONS: { id: PlanId; label: string; detail: string }[] = [
  { id: 'individual', label: 'الباقة الفردية', detail: 'كل الدروس والمواد — بلا دردشة ولا تحدٍّ ولا لقاءات ولا معلم افتراضي ولا حل مسائل' },
  { id: 'family', label: 'باقة المجموعات والعائلة (3+)', detail: 'الفردية + الدردشة + تحدَّ زملاءك' },
  { id: 'school_small', label: 'المؤسسية — مصغّرة (حتى 25 طالباً)', detail: 'كل البطاقات والمميزات' },
  { id: 'school_medium', label: 'المؤسسية — متوسطة (حتى 50 طالباً)', detail: 'كل البطاقات والمميزات' },
  { id: 'school_large', label: 'المؤسسية — شاملة (100+ طالب)', detail: 'كل البطاقات والمميزات' },
];

export const PLAN_LABELS: Record<string, string> = {
  demo: 'وضع الزائر',
  ...Object.fromEntries(PLAN_OPTIONS.map((p) => [p.id, p.label])),
};

export const planLabel = (plan?: string | null) => (plan ? PLAN_LABELS[plan] ?? plan : 'بلا باقة (مفتوح بالكامل)');
