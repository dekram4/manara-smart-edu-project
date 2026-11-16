/// فئاتُ الاشتراك كما يعرضها التطبيق — مطابقةٌ لـ `subscriptionPlans.ts` في الخادم.
///
/// الخادمُ يطبّق الباقةَ على صلاحيات البطاقات ثم قواعدَ المشرف فوقها، ويقول
/// ذلك بـ`planApplied`. وخادمٌ أقدمُ لا يعرف الباقات: فيطبّقها التطبيقُ هنا
/// ([planAllowsCard]) ويُبقي ما أغلقه الخادم مغلقاً.
library;

enum PlanGroup { demo, individual, family, school }

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.group,
    required this.nameAr,
    required this.nameEn,
    this.seatsAr = '',
    this.seatsEn = '',
    this.locked = const {},
  });

  final String id;
  final PlanGroup group;
  final String nameAr;
  final String nameEn;

  /// عددُ الطلاب الذي تناسبه الفئة.
  final String seatsAr;
  final String seatsEn;

  /// بطاقاتٌ لا تشملها الباقة.
  final Set<String> locked;
}

/// السعرُ يُحدَّد لاحقاً: خانةٌ مرنة تُعرض كما هي.
const planPricePlaceholderAr = 'السعر: يُحدَّد لاحقاً';
const planPricePlaceholderEn = 'Price: to be announced';

const _individualLocked = {'chat', 'challenge', 'meeting', 'tutor', 'solver'};
const _familyLocked = {'meeting', 'tutor', 'solver'};

const subscriptionPlans = <SubscriptionPlan>[
  SubscriptionPlan(
    id: 'individual',
    group: PlanGroup.individual,
    nameAr: 'الباقة الفردية',
    nameEn: 'Individual',
    seatsAr: 'طالبٌ واحد مستقل',
    seatsEn: 'One student',
    locked: _individualLocked,
  ),
  SubscriptionPlan(
    id: 'family',
    group: PlanGroup.family,
    nameAr: 'باقة المجموعات والعائلة',
    nameEn: 'Family & groups',
    seatsAr: '٣ إخوةٍ أو أصدقاء على الأقل',
    seatsEn: 'At least 3 siblings or friends',
    locked: _familyLocked,
  ),
  SubscriptionPlan(
    id: 'school_small',
    group: PlanGroup.school,
    nameAr: 'روضة/مدرسة مصغّرة',
    nameEn: 'Small school / KG',
    seatsAr: 'حتى ٢٥ طالباً (يُحدَّد لاحقاً)',
    seatsEn: 'Up to 25 students (TBA)',
  ),
  SubscriptionPlan(
    id: 'school_medium',
    group: PlanGroup.school,
    nameAr: 'روضة/مدرسة متوسطة',
    nameEn: 'Medium school / KG',
    seatsAr: 'حتى ٥٠ طالباً (يُحدَّد لاحقاً)',
    seatsEn: 'Up to 50 students (TBA)',
  ),
  SubscriptionPlan(
    id: 'school_large',
    group: PlanGroup.school,
    nameAr: 'روضة/مدرسة شاملة',
    nameEn: 'Large school / KG',
    seatsAr: '١٠٠ طالب فأكثر (يُحدَّد لاحقاً)',
    seatsEn: '100+ students (TBA)',
  ),
];

SubscriptionPlan? planById(String? id) {
  for (final plan in subscriptionPlans) {
    if (plan.id == id) return plan;
  }
  return null;
}

/// هل تشمل الباقة [planId] البطاقةَ [card]؟ حسابٌ بلا باقة (أو زائر) يدخل كلَّ البطاقات.
bool planAllowsCard(String? planId, String card) => !(planById(planId)?.locked.contains(card) ?? false);

/// مميزاتُ الباقات كما تُعرض في المقارنة: عنوانٌ، ثم أيُّ الباقات تشمله.
class PlanFeature {
  const PlanFeature(this.ar, this.en, {this.individual = true, this.family = true, this.school = true});

  final String ar;
  final String en;
  final bool individual;
  final bool family;
  final bool school;

  bool includedIn(PlanGroup group) => switch (group) {
        PlanGroup.individual => individual,
        PlanGroup.family => family,
        PlanGroup.school => school,
        PlanGroup.demo => false,
      };
}

const planFeatures = <PlanFeature>[
  PlanFeature('كل الدروس والمواد (على فصلين دراسيين)', 'All lessons and subjects (two terms)'),
  PlanFeature('شرح الدرس', 'Lesson explanations'),
  PlanFeature('قلمي السحري', 'Magic pen'),
  PlanFeature('المذاكرة وألعابها', 'Study games'),
  PlanFeature('سينما منارة', 'Manara cinema'),
  PlanFeature('تعليم القرآن', 'Quran learning'),
  PlanFeature('عالم الترفيه', 'Fun world'),
  PlanFeature('استوديو الرسم', 'Drawing studio'),
  PlanFeature('مركز الاختبارات كاملاً', 'Full quiz centre'),
  PlanFeature('الدردشة', 'Chat', individual: false),
  PlanFeature('تحدَّ زملاءك', 'Challenge friends', individual: false),
  PlanFeature('المعلم الحقيقي والدردشة بالصور', 'Real teacher and picture chat', individual: false, family: false),
  PlanFeature('اللقاءات المباشرة', 'Live meetings', individual: false, family: false),
  PlanFeature('المعلم الافتراضي', 'Virtual teacher', individual: false, family: false),
  PlanFeature('حل المسائل', 'Problem solver', individual: false, family: false),
];
