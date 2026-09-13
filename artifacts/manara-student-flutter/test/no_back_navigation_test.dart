import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/screens/academic_selection_screen.dart';
import 'package:manara_student/src/screens/login_screen.dart';
import 'package:manara_student/src/screens/student_home_screen.dart';
import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:manara_student/src/widgets/student_no_back.dart';

/// The three screens a student must not be able to reverse out of.
///
/// Going back from signing in, from choosing the course, or from the hub
/// means either dropping out of the app or landing on a screen already
/// finished with — a dead end a child cannot reason their way out of.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StudentAuthService authService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
    authService = StudentAuthService(
      SupabaseClient('http://127.0.0.1:1', 'test-key'),
      apiBaseUrl: '',
    );
  });

  const profile = StudentProfile(
    id: 's1',
    name: 'طالب',
    username: 'student',
    role: 'student',
  );

  final screens = <String, Widget Function()>{
    'login': () => const LoginScreen(
          authService: null,
          initializationError: null,
          apiBaseUrl: '',
        ),
    'path selection': () => AcademicSelectionScreen(
          profile: profile,
          authService: authService,
          apiBaseUrl: '',
        ),
    'portal hub': () => StudentHomeScreen(
          profile: profile,
          authService: authService,
          apiBaseUrl: '',
        ),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} refuses to pop', (tester) async {
      tester.view.physicalSize = const Size(393, 851);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(home: entry.value()));
      await tester.pump(const Duration(milliseconds: 400));

      final guard = find.descendant(
        of: find.byType(StudentNoBack),
        matching: find.byWidgetPredicate((w) => w is PopScope),
      );
      expect(guard, findsWidgets, reason: '${entry.key} has no back guard');

      // canPop false is what closes both the hardware/gesture back and the
      // iOS edge swipe. Asserting the flag rather than simulating a
      // system back, which the harness routes around the widget tree.
      final scope = tester.widget(guard.first) as PopScope;
      expect(scope.canPop, isFalse, reason: '${entry.key} can still pop');
    });
  }

  testWidgets('the hub draws no back arrow of its own', (tester) async {
    // PopScope closes the gesture and the hardware button, but an AppBar
    // will still draw its own leading arrow — the one way back it does not
    // cover. Login and the path screen have no AppBar at all.
    tester.view.physicalSize = const Size(393, 851);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          profile: profile,
          authService: authService,
          apiBaseUrl: '',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final bar = tester.widget<AppBar>(find.byType(AppBar).first);
    expect(bar.automaticallyImplyLeading, isFalse);
    expect(find.byType(BackButton), findsNothing);
  });
}
