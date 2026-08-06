import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_repository.dart';

class AppBootstrap {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  // Keep the bucket private. Video paths are stored in lesson_configs and
  // resolved to one-hour signed URLs only when a permitted user plays them.
  static const supabaseVideoBucket =
      String.fromEnvironment('SUPABASE_VIDEO_BUCKET');

  static Future<SupabaseManaraRepository?> initializeSupabase() async {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) return null;
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    return SupabaseManaraRepository(Supabase.instance.client);
  }
}