import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/screens/login_screen.dart';
import 'src/services/student_auth_service.dart';

const String kSupabaseUrl = 'https://kpqlotlyniomssnzcgqn.supabase.co';
const String kSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtwcWxvdGx5bmlvbXNzbnpjZ3FuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcxMzcxNjIsImV4cCI6MjEwMjcxMzE2Mn0.AHZ5vsoBNQ6cemiswQksEe91M1IQRU3RsAtDINNymkg';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SupabaseClient? client;
  String? initializationError;

  try {
    await Supabase.initialize(
      url: kSupabaseUrl,
      anonKey: kSupabaseAnonKey,
      publishableKey: kSupabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(),
    );
    client = Supabase.instance.client;
  } catch (error) {
    initializationError = 'تعذر تهيئة اتصال Supabase: ${error.toString()}';
  }

  runApp(
    ManaraStudentApp(
      client: client,
      initializationError: initializationError,
      apiBaseUrl: '$kSupabaseUrl/rest/v1',
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
          authService: client == null ? null : StudentAuthService(client!),
          initializationError: initializationError,
          apiBaseUrl: apiBaseUrl,
        ),
      ),
    );
  }
}
