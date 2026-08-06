import 'package:flutter/material.dart';
import '../models/app_models.dart';

class ManaraColors {
  static const primary = Color(0xFFFF6B35);
  static const primaryLight = Color(0xFFFF9A6B);
  static const primaryDark = Color(0xFFE85520);
  static const secondary = Color(0xFFF59E0B);
  static const secondaryLight = Color(0xFFFBBF24);
  static const secondaryDark = Color(0xFFD97706);
  static const accent = Color(0xFFFB7185);
  static const accentLight = Color(0xFFFDA4AF);
  static const accentDark = Color(0xFFE11D48);
  static const admin = Color(0xFFA78BFA);
  static const adminLight = Color(0xFFC4B5FD);
  static const adminDark = Color(0xFF7C3AED);
  static const teal = Color(0xFF4ECDC4);
  static const green = Color(0xFF4ADE80);
  static const blue = Color(0xFF60A5FA);
  static const yellow = Color(0xFFFFE66D);
  static const pink = Color(0xFFFF6B9D);
  static const red = Color(0xFFEF4444);
  static const purple = adminDark;
  static const deepPurple = Color(0xFF43218A);
  static const lavender = Color(0xFFF4EEFF);
  static const orange = primaryLight;
  static const mint = teal;
  static const ink = Color(0xFF2D3748);
  static const muted = Color(0xFF718096);
  static const cream = Color(0xFFFFF8F0);
  static const backgroundAlt = Color(0xFFFFF0E6);
  static const border = Color(0xFFFFE8D6);

  static Color rolePrimary(UserRole? role) {
    switch (role) {
      case UserRole.teacher:
        return secondary;
      case UserRole.guardian:
        return accent;
      case UserRole.admin:
        return admin;
      case UserRole.student:
      case null:
        return primary;
    }
  }

  static Color rolePrimaryDark(UserRole? role) {
    switch (role) {
      case UserRole.teacher:
        return secondaryDark;
      case UserRole.guardian:
        return accentDark;
      case UserRole.admin:
        return adminDark;
      case UserRole.student:
      case null:
        return primaryDark;
    }
  }

  static Color roleBackground(UserRole? role) {
    switch (role) {
      case UserRole.teacher:
        return const Color(0xFFFFFBF0);
      case UserRole.guardian:
        return const Color(0xFFFFF5F7);
      case UserRole.admin:
        return const Color(0xFFF9F7FF);
      case UserRole.student:
      case null:
        return const Color(0xFFFFF5EE);
    }
  }

  static List<Color> roleGradient(UserRole? role) {
    switch (role) {
      case UserRole.teacher:
        return const [secondary, Color(0xFFFB923C), primary];
      case UserRole.guardian:
        return const [accent, Color(0xFFF472B6), admin];
      case UserRole.admin:
        return const [admin, Color(0xFF818CF8), Color(0xFF6366F1)];
      case UserRole.student:
      case null:
        return const [primary, pink, admin];
    }
  }
}

ThemeData buildManaraTheme({UserRole? role}) {
  final primary = ManaraColors.rolePrimary(role);
  final background = ManaraColors.roleBackground(role);
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      surface: background,
    ),
    fontFamily: 'Tajawal',
    appBarTheme: const AppBarTheme(
      backgroundColor: ManaraColors.cream,
      foregroundColor: ManaraColors.ink,
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
        borderSide: const BorderSide(color: Color(0xFFE9E4F5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 22),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: primary.withOpacity(.16),
      labelTextStyle: const MaterialStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
}