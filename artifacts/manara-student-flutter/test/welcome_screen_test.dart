import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/screens/student_startup_screen.dart';

/// The welcome splash has to survive every shipping aspect ratio in both
/// orientations without overflowing, and it has to leave for the login
/// screen when tapped — the skip is the only exit a student controls.
const _sizes = <String, Size>{
  'landscape desktop 1280x720': Size(1280, 720),
  'landscape tablet 4:3 1024x768': Size(1024, 768),
  'landscape phone 851x393': Size(851, 393),
  'portrait tablet 4:3 768x1024': Size(768, 1024),
  'portrait phone 393x851': Size(393, 851),
  'portrait small phone 360x740': Size(360, 740),
};

Widget _app() => const MaterialApp(
      home: StudentStartupScreen(
        authService: null,
        initializationError: null,
        apiBaseUrl: '',
      ),
    );

void main() {
  for (final entry in _sizes.entries) {
    testWidgets('welcome splash lays out without overflow on ${entry.key}',
        (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      // Through the pop-in and into the looping bounce.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 1200));

      expect(tester.takeException(), isNull);
      expect(find.text('منارة المعرفة التعليمية'), findsOneWidget);

      // The looping bounce would keep pumpAndSettle spinning forever, so
      // leave the screen on a discrete pump instead.
      await tester.tap(find.byType(StudentStartupScreen));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tapping the splash moves on to the login screen',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    // Past every staged delay (the last is the skip hint at 1400ms) so no
    // animation timer is left armed when the screen is replaced.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.byType(StudentStartupScreen), findsOneWidget);

    await tester.tap(find.byType(StudentStartupScreen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    // With no auth service the destination is the login screen, and the
    // splash must be gone rather than stacked behind it.
    expect(find.byType(StudentStartupScreen), findsNothing);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });
}
