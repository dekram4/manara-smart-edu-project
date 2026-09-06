import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/config/supabase_config.dart';
import 'src/screens/student_startup_screen.dart';
import 'src/services/student_auth_service.dart';
import 'src/services/student_sound_service.dart';
import 'src/theme/student_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. التقاط أخطاء الـ UI والـ Flutter Framework
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  // 2. التقاط الأخطاء غير المتوقعة وعرضها على الشاشة
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: SelectionArea(
              child: Text(
                'تفاصيل الخطأ أثناء التشغيل:\n\n${details.exception}\n\n${details.stack}',
                style: const TextStyle(color: Colors.red, fontSize: 13, height: 1.4),
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        ),
      ),
    );
  };

  SupabaseClient? client;
  String? initializationError;
  String apiBaseUrl = '';

  // 3. محاولة تهيئة الخدمات مع التقاط الأخطاء لمنع انحيار التطبيق عند التشغيل
  // media_kit (libmpv) is only used on Windows now — student_video_player.dart
  // plays every MP4/HLS source on Android/iOS/iPadOS through video_player
  // instead (see its `_usesMediaKit`), and this project ships no
  // media_kit_libs_android_video/_ios_video binaries any more. Calling
  // MediaKit.ensureInitialized() there would eagerly try to load a libmpv
  // shared library that was never bundled and always fail, surfacing a
  // confusing "خطأ في MediaKit" banner on every single launch.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    try {
      MediaKit.ensureInitialized();
    } catch (e) {
      initializationError = 'خطأ في MediaKit: $e';
    }
  }

  try {
    await StudentSoundService.instance.initialize();
  } catch (e) {
    initializationError = (initializationError ?? '') + '\nخطأ في الصوت: $e';
  }

  try {
    const config = SupabaseConfig.fromEnvironment();
    apiBaseUrl = config.apiBaseUrl;

    if (config.isConfigured) {
      await Supabase.initialize(
        url: config.url,
        anonKey: config.anonKey,
        authOptions: const FlutterAuthClientOptions(),
      );
      client = Supabase.instance.client;
    } else {
      initializationError = (initializationError ?? '') + '\n' + config.configurationMessage;
    }
  } catch (error) {
    initializationError = (initializationError ?? '') + '\nتعذر تهيئة Supabase: ${error.toString()}';
  }

  runApp(
    ManaraStudentApp(
      client: client,
      initializationError: initializationError,
      apiBaseUrl: apiBaseUrl,
    ),
  );
}

class ManaraStudentApp extends StatelessWidget {
  const ManaraStudentApp({
    required this.client,
    required this.initializationError,
    required this.apiBaseUrl,
    super.key,
  });

  final SupabaseClient? client;
  final String? initializationError;
  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'منارة المعرفة',
      theme: StudentTheme.light(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: StudentStartupScreen(
        authService: client == null
            ? null
            : StudentAuthService(client!, apiBaseUrl: apiBaseUrl),
        initializationError: initializationError,
        apiBaseUrl: apiBaseUrl,
      ),
    );
  }
}