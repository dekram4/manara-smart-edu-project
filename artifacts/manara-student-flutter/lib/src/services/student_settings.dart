import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The student's own display choices: light or dark, Arabic or English.
///
/// Built the same way as [StudentAvatars] — plain [ValueNotifier]s read
/// wherever they are needed — so a change reaches every screen at once
/// without a provider threaded through the tree, and so the two stores
/// behave alike rather than each inventing its own mechanism.
///
/// Both settings are restored at launch and written back in the
/// background: the UI must never wait on disk to show a student the
/// theme they just tapped.
class StudentSettings {
  const StudentSettings._();

  static const _themeKey = 'manara_theme_mode';
  static const _localeKey = 'manara_locale';

  /// The languages the app ships. Arabic leads because it is the app's
  /// first language, and it is what an unconfigured install opens in.
  static const arabic = Locale('ar');
  static const english = Locale('en');
  static const supported = <Locale>[arabic, english];

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static final ValueNotifier<Locale> locale = ValueNotifier<Locale>(arabic);

  static bool get isDark => themeMode.value == ThemeMode.dark;
  static bool get isArabic => locale.value.languageCode == 'ar';

  /// The direction the chosen language reads in. Every screen that used
  /// to hard-code RTL asks this instead, so English lays out left to
  /// right without each screen needing to know the rule.
  static TextDirection get direction =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  /// Loads both settings. A storage failure leaves the defaults in place
  /// rather than blocking startup — a student with unreadable prefs gets
  /// the app in Arabic and light, not a crash.
  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedTheme = prefs.getString(_themeKey);
      themeMode.value =
          storedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
      final storedLocale = prefs.getString(_localeKey);
      locale.value = storedLocale == 'en' ? english : arabic;
    } catch (_) {
      themeMode.value = ThemeMode.light;
      locale.value = arabic;
    }
  }

  static Future<void> setDark(bool dark) async {
    themeMode.value = dark ? ThemeMode.dark : ThemeMode.light;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, dark ? 'dark' : 'light');
    } catch (_) {
      // The choice still holds for this session if storage is unavailable.
    }
  }

  static Future<void> toggleTheme() => setDark(!isDark);

  static Future<void> setLocale(Locale value) async {
    locale.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, value.languageCode);
    } catch (_) {
      // As above: the session keeps the choice even if it cannot be saved.
    }
  }

  static Future<void> toggleLocale() =>
      setLocale(isArabic ? english : arabic);

  /// Test seam: puts both settings back to their defaults.
  @visibleForTesting
  static void resetForTest() {
    themeMode.value = ThemeMode.light;
    locale.value = arabic;
  }
}
