import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/screens/academic_selection_screen.dart';
import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_settings.dart';

/// The path screen pins its controls onto a books illustration at fixed
/// fractions of the artwork, and each control's text is scaled to fit its
/// book. That makes it the screen where raising a font size is most likely
/// to silently do nothing — or to overflow a slot.
///
/// The login screen has had a size sweep like this for a while; this one
/// did not, which is why the type there could drift without anything
/// noticing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StudentAuthService authService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
    // Unreachable on purpose: the screen's own fetch fails into its error
    // state, and the scene still lays out.
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

  const sizes = <String, Size>{
    'portrait small phone 360x740': Size(360, 740),
    'portrait phone 393x851': Size(393, 851),
    'portrait tablet 4:3 768x1024': Size(768, 1024),
    'portrait tablet 16:10 800x1280': Size(800, 1280),
    'landscape phone 851x393': Size(851, 393),
    'landscape small phone 740x360': Size(740, 360),
    'landscape tablet 4:3 1024x768': Size(1024, 768),
    'landscape desktop 1280x720': Size(1280, 720),
  };

  for (final entry in sizes.entries) {
    testWidgets('the path scene lays out without overflow on ${entry.key}',
        (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: AcademicSelectionScreen(
            profile: profile,
            authService: authService,
            apiBaseUrl: '',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // takeException catches the RenderFlex/RenderBox overflow errors the
      // framework raises when a slot cannot hold what was put in it.
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the scene survives the larger type in English too',
      (tester) async {
    // Arabic is more compact than English at the same point size, so an
    // English label is the one that overflows first.
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await StudentSettings.setLocale(StudentSettings.english);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => Directionality(
          textDirection: StudentSettings.direction,
          child: child!,
        ),
        home: AcademicSelectionScreen(
          profile: profile,
          authService: authService,
          apiBaseUrl: '',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
  });

  testWidgets('the scene survives the larger type in dark mode',
      (tester) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: AcademicSelectionScreen(
          profile: profile,
          authService: authService,
          apiBaseUrl: '',
        ),
      ),
    );
    // pump, not pumpAndSettle: the characters float on a repeating
    // controller, so nothing on this screen ever settles.
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
  });
}
