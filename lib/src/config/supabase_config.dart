class SupabaseConfig {
  const SupabaseConfig({
    required this.url,
    required this.anonKey,
    this.apiBaseUrl = '',
  });

  const SupabaseConfig.fromEnvironment()
      : url = const String.fromEnvironment('SUPABASE_URL'),
        anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY'),
        apiBaseUrl = const String.fromEnvironment('API_BASE_URL');

  final String url;
  final String anonKey;
  final String apiBaseUrl;

  bool get isConfigured => url.trim().isNotEmpty && anonKey.trim().isNotEmpty;

  String get configurationMessage {
    if (url.trim().isEmpty && anonKey.trim().isEmpty) {
      return 'لم يتم إعداد اتصال Supabase. شغّل التطبيق مع SUPABASE_URL و SUPABASE_ANON_KEY.';
    }
    if (url.trim().isEmpty) {
      return 'قيمة SUPABASE_URL غير موجودة في إعدادات تشغيل التطبيق.';
    }
    return 'قيمة SUPABASE_ANON_KEY غير موجودة في إعدادات تشغيل التطبيق.';
  }
}