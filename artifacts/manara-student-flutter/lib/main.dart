import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/config/supabase_config.dart';
import 'src/screens/login_screen.dart';
import 'src/services/student_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  const config = SupabaseConfig.fromEnvironment();
  SupabaseClient? client;
  String? initializationError;

  if (config.isConfigured) {
    try {
      await Supabase.initialize(
        url: config.url,
        anonKey: config.anonKey,
        authOptions: const FlutterAuthClientOptions(),
      );
      client = Supabase.instance.client;
    } catch (error) {
      initializationError = 'تعذر تهيئة اتصال Supabase: ${error.toString()}';
    }
  } else {
    initializationError = config.configurationMessage;
  }

  runApp(
    ManaraStudentApp(
      client: client,
      initializationError: initializationError,
      apiBaseUrl: config.apiBaseUrl,
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
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: LoginScreen(
          authService: client == null
              ? null
              : StudentAuthService(client!, apiBaseUrl: apiBaseUrl),
          initializationError: initializationError,
          apiBaseUrl: apiBaseUrl,
        ),
      ),
    );
  }
}