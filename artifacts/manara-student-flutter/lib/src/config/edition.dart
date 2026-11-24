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
