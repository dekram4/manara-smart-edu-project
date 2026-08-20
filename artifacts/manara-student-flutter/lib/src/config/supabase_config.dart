class SupabaseConfig {
  const SupabaseConfig({
    required this.url,
    required this.anonKey,
    this.apiBaseUrl = '',
  });

  const SupabaseConfig.fromEnvironment()
      : url = const String.fromEnvironment(
          'SUPABASE_URL',
          defaultValue: 'https://kpqlotlyniomssnzcgqn.supabase.co',
        ),
        anonKey = const String.fromEnvironment(
          'SUPABASE_ANON_KEY',
          defaultValue:
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIs'
              'InJlZiI6ImtwcWxvdGx5bmlvbXNzbnpjZ3FuIiwicm9sZSI6ImFub24iLCJpYXQi'
              'OjE3ODcxMzcxNjIsImV4cCI6MjEwMjcxMzE2Mn0.AHZ5vsoBNQ6cemiswQksEe91'
              'M1IQRU3RsAtDINNymkg',
        ),
        apiBaseUrl = const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: '',
        );

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