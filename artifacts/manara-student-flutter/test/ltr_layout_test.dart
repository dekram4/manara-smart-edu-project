import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/models/student_content.dart';
import 'package:manara_student/src/screens/login_screen.dart';
import 'package:manara_student/src/screens/student_tutor_screen.dart';
import 'package:manara_student/src/services/student_settings.dart';

/// The app was written against a guaranteed right-to-left direction, so
/// flipping it is exactly where a layout is most likely to break. These
/// pump the login board in English at every shipping size and fail on any
/// overflow the flip introduces.
const _sizes = <String, Size>{
  'landscape desktop 1280x720': Size(1280, 720),
  'landscape tablet 4:3 1024x768': Size(1024, 768),
  'landscape phone 851x393': Size(851, 393),
  'portrait tablet 4:3 768x1024': Size(768, 1024),
  'portrait phone 393x851': Size(393, 851),
  'portrait small phone 360x740': Size(360, 740),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  for (final entry in _sizes.entries) {
    testWidgets('login lays out in English (LTR) without overflow on '
        '${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await StudentSettings.setLocale(StudentSettings.english);

      await tester.pumpWidget(
        Directionality(
          textDirection: StudentSettings.direction,
          child: const MaterialApp(
            home: LoginScreen(
              authService: null,
              initializationError: null,
              apiBaseUrl: '',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));

      expect(tester.takeException(), isNull);
      expect(find.text('Sign in'), findsOneWidget);
    });
  }

  group('the fullscreen exit button follows the reading direction', () {
    // A way out pinned to one physical side is correct in exactly one
    // language. These assert which half of the screen it lands in, so a
    // return to a fixed `Alignment` fails here rather than in a student's
    // hands.
    Future<double> exitButtonCenterX(WidgetTester tester, Locale locale) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await StudentSettings.setLocale(locale);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => Directionality(
            textDirection: StudentSettings.direction,
            child: child!,
          ),
          home: const StudentTutorScreen(
            // No URL, so the screen renders its "no link yet" state and
            // never mounts a WebView — the exit button is the same one
            // either way.
            selection: TutorExperienceSelection(
              type: TutorExperienceType.virtualTeacher,
              status: TutorExperienceStatus.unavailable,
            ),
            apiBaseUrl: '',
            fullscreen: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));

      final button = find.byIcon(Icons.fullscreen_exit_rounded);
      expect(button, findsOneWidget);
      return tester.getCenter(button).dx;
    }

    testWidgets('Arabic puts it on the right', (tester) async {
      final x = await exitButtonCenterX(tester, StudentSettings.arabic);
      expect(x, greaterThan(512));
    });

    testWidgets('English puts it on the left', (tester) async {
      final x = await exitButtonCenterX(tester, StudentSettings.english);
      expect(x, lessThan(512));
    });
  });

  testWidgets('the dark theme renders the board without exceptions',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await StudentSettings.setDark(true);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const LoginScreen(
          authService: null,
          initializationError: null,
          apiBaseUrl: '',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
  });
}
