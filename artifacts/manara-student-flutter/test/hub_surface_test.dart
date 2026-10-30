import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/screens/student_home_screen.dart';
import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_settings.dart';

/// واجهةُ البطاقات: مربّعاتٌ بيضاءُ ناصعة في الفاتح، وإضاءةٌ على رأس
/// المنارة في الداكن وحده.
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

  Future<void> pumpHub(WidgetTester tester, Brightness brightness) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: StudentHomeScreen(
          profile: profile,
          authService: authService,
          apiBaseUrl: '',
        ),
      ),
    );
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// لونُ خلفية كلّ مربّعِ بطاقة في الشريط.
  List<BoxDecoration> tileDecorations(WidgetTester tester) {
    final surfaces = find.byKey(const ValueKey('portal-card-surface'));
    expect(surfaces, findsWidgets);
    return [
      for (final e in surfaces.evaluate())
        (e.widget as Container).decoration! as BoxDecoration,
    ];
  }

  testWidgets('light mode: solid white cards, no tower glow', (tester) async {
    await pumpHub(tester, Brightness.light);
    for (final d in tileDecorations(tester)) {
      expect(d.color, Colors.white);
      expect(d.gradient, isNull);
    }
    expect(find.byKey(const ValueKey('tower-glow')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dark mode: glass cards and a glow on the tower', (tester) async {
    await pumpHub(tester, Brightness.dark);
    for (final d in tileDecorations(tester)) {
      // زجاجٌ يدفأ من أعلى بضوء المنارة.
      final colors = (d.gradient! as LinearGradient).colors;
      expect(colors.last.a, lessThan(1.0));
      expect(colors.first.r, greaterThan(colors.last.r));
    }
    expect(find.byKey(const ValueKey('tower-glow')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no welcome line after login: the hub opens on its cards', (tester) async {
    await pumpHub(tester, Brightness.dark);
    expect(
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_WelcomeCard'),
      findsNothing,
    );
    expect(find.text(tr('hub.welcome')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
