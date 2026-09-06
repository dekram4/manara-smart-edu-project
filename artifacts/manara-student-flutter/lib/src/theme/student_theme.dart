import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class StudentPalette {
  static const indigo = Color(0xFF4F46E5);
  static const deepIndigo = Color(0xFF312E81);
  static const sky = Color(0xFF0EA5E9);
  static const cyan = Color(0xFF22D3EE);
  static const orange = Color(0xFFF59E0B);
  static const success = Color(0xFF10B981);
  static const ink = Color(0xFF172554);
  static const mutedInk = Color(0xFF526581);
  static const canvas = Color(0xFFF3F7FF);
  static const surface = Color(0xFFFDFEFF);
}

abstract final class StudentTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: StudentPalette.indigo,
        primary: StudentPalette.indigo,
        secondary: StudentPalette.sky,
        tertiary: StudentPalette.orange,
        brightness: Brightness.light,
        surface: StudentPalette.surface,
      ),
      scaffoldBackgroundColor: StudentPalette.canvas,
      textTheme: GoogleFonts.tajawalTextTheme(),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: StudentPalette.ink,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: StudentPalette.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: Color(0x1F4F46E5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.92),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0x244F46E5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(
            color: StudentPalette.indigo,
            width: 2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: StudentPalette.indigo,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: StudentPalette.deepIndigo,
        contentTextStyle: GoogleFonts.tajawal(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}