/// «النسخة المفتوحة» من تطبيق الطالب: تُبنى بـ
///
/// ```
/// flutter build apk --dart-define=MANARA_EDITION=open \
///   --dart-define=SUPABASE_URL=<manara-open-app> \
///   --dart-define=SUPABASE_ANON_KEY=<مفتاحها العام> \
///   --dart-define=API_BASE_URL=<خادم النسخة المفتوحة>
/// ```
///
/// وفيها يدخل الطالبُ باسمه وحده: يُنشئ له الخادمُ حساباً في صفّ المعلم الوحيد
/// ويحفظه التطبيقُ في مخزنه المشفّر، فيعود إليه كلَّ مرّةٍ بلا كلمة مرور.
///
/// ── والتطبيقُ الحالي كما هو ──
/// بلا هذا التعريف (كلُّ بناءٍ حاليّ) [isOpenEdition] خطأٌ ثابتٌ عند البناء،
/// فلا يُبنى سطرٌ من مسار النسخة المفتوحة في التطبيق الحالي أصلاً.
library;

const String manaraEdition = String.fromEnvironment('MANARA_EDITION');

const bool isOpenEdition = manaraEdition == 'open';

/// النسخةُ المفتوحة فعلاً: [isOpenEdition]، أو ما يضبطه اختبارٌ بـ
/// [debugOverrideOpenEdition].
bool get openEditionActive => _openEditionOverride ?? isOpenEdition;

bool? _openEditionOverride;

/// للاختبار وحده: يشغّل سلوكَ النسخة المفتوحة (أو يطفئه) بلا إعادة بناء،
/// و`null` يعيده إلى [isOpenEdition].
void debugOverrideOpenEdition(bool? value) => _openEditionOverride = value;

/// بطاقاتُ واجهة الطالب المخفيّة في النسخة المفتوحة (بمعرّفها: ما بعد `portal.`):
/// حلُّ المسائل، والدردشة، والمعلم الافتراضي، واللقاء المباشر، وتحدَّ زملاءك.
///
/// تُخفى من العرض وحده: شاشاتُها ومنطقُها ومساراتُها في الكود كما هي، وفي
/// النسخة العادية تظهر وتعمل كما كانت.
const Set<String> openEditionHiddenCards = {'solver', 'chat', 'tutor', 'meeting', 'challenge'};

/// هل تُخفى البطاقة [cardId] في هذه النسخة؟
bool cardHiddenByEdition(String cardId, {bool? openEdition}) =>
    (openEdition ?? openEditionActive) && openEditionHiddenCards.contains(cardId);
