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
          // Flutter Web's development server runs on a random localhost port,
          // but the protected API is served by the Replit API workflow. Using
          // its public development origin keeps chat and Gemini reachable
          // from Chrome, while release builds can override this with
          // --dart-define=API_BASE_URL=<their API origin>.
          defaultValue:
              'https://3daed49c-74e9-464a-89fa-0dd61cae7661-00-1r2hrmhp8fjuc.sisko.replit.dev',
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