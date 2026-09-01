import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/config/supabase_config.dart';
import 'src/screens/login_screen.dart';
import 'src/services/student_auth_service.dart';
import 'src/services/student_sound_service.dart';

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
  try {
    MediaKit.ensureInitialized();
  } catch (e) {
    initializationError = 'خطأ في MediaKit: $e';
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
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0B8693),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF3F8F9),
      textTheme: GoogleFonts.tajawalTextTheme(),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'منارة المعرفة',
      theme: baseTheme.copyWith(
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFD7E3EF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF0B8693), width: 2),
          ),
        ),
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: LoginScreen(
        authService: client == null
            ? null
            : StudentAuthService(client!, apiBaseUrl: apiBaseUrl),
        initializationError: initializationError,
        apiBaseUrl: apiBaseUrl,
      ),
    );
  }
}