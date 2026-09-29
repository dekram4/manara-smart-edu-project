import '../l10n/student_strings.dart';

class SupabaseConfig {
  const SupabaseConfig({
    required this.url,
    required this.anonKey,
    this.apiBaseUrl = '',
  });

  /// يُقرأ من بيئة البناء وحدها — بلا قيمة افتراضية مكتوبة في الشيفرة.
  ///
  /// كان المفتاح مكتوباً هنا صراحةً كـ `defaultValue`، والمستودع عام، فكان
  /// منشوراً للجميع وصالحاً حتى 2036. حذفُه يمنع تسرّب المفتاح التالي.
  ///
  /// ولا يُغني حذفُه عن تشديد RLS: مفتاح anon يُستخرَج من أي APK بفكّ ضغطه،
  /// فهو معلوم للمهاجم في كل الأحوال. حمايته الحقيقية أن يكون عديم الأثر —
  /// وذلك ما يفعله `scripts/harden-rls.sql`، لا الإخفاء.
  ///
  /// التمرير عند البناء:
  ///   flutter build apk --release \
  ///     --dart-define=SUPABASE_URL=... \
  ///     --dart-define=SUPABASE_ANON_KEY=...
  const SupabaseConfig.fromEnvironment()
      : url = const String.fromEnvironment('SUPABASE_URL'),
        anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY'),
        apiBaseUrl = const String.fromEnvironment(
          'API_BASE_URL',
          // عنوان الخادم المعتمد، مكتوبٌ هنا لا متروكاً فارغاً.
          //
          // فلولا قيمةٌ هنا لخرج APK بلا عنوان خادم ولَما وصل طلبٌ واحد.
          // وفي الويب وحده يُستعاض عنها بأصل الموقع حين تُترك فارغة؛ وفي
          // APK لا أصلَ يُستعاض به، فهذه هي كلّ ما هناك.
          //
          // ── ولماذا نطاقُ النشر لا نطاقُ مساحة العمل ──
          // كان هذا عنوانَ مساحة العمل التطويرية (`*.replit.dev`)، وهي لا
          // تعمل إلا ما دامت المساحةُ مشتغلة. وكان سرُّ `API_BASE_URL` غيرَ
          // مضبوط في المستودع، فلا يمرّره البناء — فكلُّ APK خرج يكلّم
          // التطوير، وكان ذلك يبدو عطباً في الخادم كلّما أُطفئت المساحة.
          //
          // والسرُّ مضبوطٌ الآن ويُمرَّر في كل بناء، فهذه القيمة احتياطٌ لا
          // مسار: تعمل في بناءٍ محليٍّ بلا تعريفات، وتحرس من أن يعود الأمرُ
          // إلى ما كان لو حُذف السرُّ يوماً.
          //
          // وليست سرّاً: عنوانٌ عامّ يُستخرج من أي APK بفكّ ضغطه، وما
          // يحميه المصادقةُ على كل مسار لا إخفاءُ العنوان.
          //
          // وتُتجاوز عند البناء بـ:
          //   --dart-define=API_BASE_URL=<عنوان الخادم>
          defaultValue: 'https://manara-smart-edu-project.replit.app',
        );

  final String url;
  final String anonKey;
  final String apiBaseUrl;

  bool get isConfigured => url.trim().isNotEmpty && anonKey.trim().isNotEmpty;

  String get configurationMessage {
    if (url.trim().isEmpty && anonKey.trim().isEmpty) {
      return tr('boot.noSupabase');
    }
    if (url.trim().isEmpty) {
      return tr('boot.noSupabaseUrl');
    }
    return tr('boot.noSupabaseKey');
  }

}