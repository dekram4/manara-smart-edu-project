import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:manara_student/src/widgets/student_display_toggles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  group('display settings', () {
    test('an unconfigured install opens Arabic and light', () async {
      await StudentSettings.restore();
      expect(StudentSettings.isArabic, isTrue);
      expect(StudentSettings.isDark, isFalse);
      expect(StudentSettings.direction, TextDirection.rtl);
    });

    test('direction follows the language, not a fixed rule', () async {
      await StudentSettings.setLocale(StudentSettings.english);
      expect(StudentSettings.direction, TextDirection.ltr);
      await StudentSettings.setLocale(StudentSettings.arabic);
      expect(StudentSettings.direction, TextDirection.rtl);
    });

    test('both choices survive a relaunch', () async {
      await StudentSettings.setDark(true);
      await StudentSettings.setLocale(StudentSettings.english);

      // Simulate a relaunch: drop the in-memory values, then restore.
      StudentSettings.resetForTest();
      expect(StudentSettings.isDark, isFalse, reason: 'reset worked');

      await StudentSettings.restore();
      expect(StudentSettings.isDark, isTrue);
      expect(StudentSettings.isArabic, isFalse);
    });

    test('toggles flip and persist', () async {
      await StudentSettings.toggleTheme();
      expect(StudentSettings.isDark, isTrue);
      await StudentSettings.toggleLocale();
      expect(StudentSettings.isArabic, isFalse);

      StudentSettings.resetForTest();
      await StudentSettings.restore();
      expect(StudentSettings.isDark, isTrue);
      expect(StudentSettings.isArabic, isFalse);
    });
  });

  group('translations', () {
    test('every Arabic key has an English counterpart', () {
      // A missing key would silently show Arabic inside an English
      // sentence — readable, but not what was intended, and invisible
      // without a check like this one.
      final missing = StudentStrings.keys
          .where((key) => !StudentStrings.englishKeys.contains(key))
          .toList();
      expect(missing, isEmpty, reason: 'no English for: $missing');
    });

    test('English has no keys Arabic lacks', () {
      final extra = StudentStrings.englishKeys
          .where((key) => !StudentStrings.keys.contains(key))
          .toList();
      expect(extra, isEmpty, reason: 'orphan English keys: $extra');
    });

    test('lookup follows the chosen language', () async {
      await StudentSettings.setLocale(StudentSettings.arabic);
      expect(tr('login.submit'), 'تسجيل الدخول');
      await StudentSettings.setLocale(StudentSettings.english);
      expect(tr('login.submit'), 'Sign in');
    });

    test('an unknown key returns itself rather than throwing', () {
      expect(tr('nope.not.here'), 'nope.not.here');
    });
  });

  group('the toggles', () {
    testWidgets('theme toggle flips the app and shows the state it offers',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: StudentThemeToggle())),
        ),
      );

      // Light: offers the moon.
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(StudentSettings.isDark, isTrue);
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
    });

    testWidgets('language toggle switches immediately, without a restart',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: StudentLanguageToggle())),
        ),
      );

      expect(find.text('EN'), findsOneWidget);
      await tester.tap(find.byType(InkResponse));
      await tester.pump();

      expect(StudentSettings.isArabic, isFalse);
      expect(find.text('ع'), findsOneWidget);
    });
  });
}
