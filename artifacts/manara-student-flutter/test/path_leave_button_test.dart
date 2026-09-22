import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/screens/academic_selection_screen.dart';
import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:manara_student/src/widgets/student_experience.dart';

/// The way out of the path screen.
///
/// The screen is opened with `pushReplacement` straight after signing in, so
/// it is the only route on the stack and `canPop` is false. A button wired
/// to `pop` would drop the child out of the app onto a black screen — the
/// very thing `StudentNoBack` stops the system back gesture from doing.
///
/// So leaving here goes forward, to the cards. These tests hold that: the
/// button exists, and pressing it never empties the navigator.
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
    name: 'جوري',
    username: 'jori',
    role: 'student',
    teacherId: 't1',
  );

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AcademicSelectionScreen(
          profile: profile,
          authService: authService,
          apiBaseUrl: '',
        ),
      ),
    );
    // Fixed pumps, not pumpAndSettle: the screen animates on a repeating
    // controller, so there is no settled state to wait for.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  testWidgets('the way out is offered, and named for where it goes',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text(tr('path.leave')), findsOneWidget);
  });

  testWidgets('pressing it never leaves the child on a black screen',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text(tr('path.leave')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    // Something is still mounted: the navigator was replaced, not emptied.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('it does not sit on top of the sound control', (tester) async {
    await pumpScreen(tester);

    // ‏كلاهما في أعلى الشاشة؛ الزرّ في الجهة المقابلة للشريط، فيجب ألّا
    // ‏يتقاطع مربّعاهما مهما ضاق الهاتف أو تغيّر اتجاه اللغة. والقياس على
    // ‏التقاطع لا على الجهة: الجهة تنقلب مع الاتجاه، والتزاحم لا.
    final leave = tester.getRect(
      find.ancestor(of: find.text(tr('path.leave')), matching: find.byType(Ink)),
    );
    final toggle = tester.getRect(find.byType(StudentSoundToggle));
    expect(leave.overlaps(toggle), isFalse,
        reason: 'the way out overlaps the sound control');
  });
}
