import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/academic_context.dart';
import 'package:manara_student/src/models/student_content.dart';
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

  /// A complete six-level course, so the books and the start button all
  /// render and can be measured against one another.
  const path = AcademicPath(
    grade: 'الصف الرابع',
    atram: 'الترم الأول',
    subject: 'العلوم',
    term: 'الفصل الثاني',
    unit: 'الوحدة الأولى',
  );

  final seeded = AcademicSelectionData(
    paths: const [path],
    lessons: [
      LessonContent(
        id: 'l1',
        lessonId: 'l1',
        grade: path.grade,
        atram: path.atram,
        subject: path.subject,
        term: path.term,
        unit: path.unit,
        lessonName: 'الخلية ووظائفها',
        createdAt: '2026-01-01',
        videos: const [],
        games: const [],
      ),
    ],
  );

  Future<void> pumpReady(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: AcademicSelectionScreen(
          profile: profile,
          authService: authService,
          apiBaseUrl: '',
          initialData: seeded,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('every one of the six levels gets a book', (tester) async {
    await pumpReady(tester, const Size(768, 1024));

    // The chapter used to share the red book with the unit, and only when
    // the teacher had configured more than one — so with a single chapter
    // a level they had filled in was not shown at all.
    for (final label in [
      tr('path.grade'),
      tr('path.atram'),
      tr('path.subject'),
      tr('path.term'),
      tr('path.unit'),
      tr('path.lesson'),
    ]) {
      expect(find.text(label), findsOneWidget, reason: '$label has no book');
    }
  });

  testWidgets('the chosen value is printed at its full size, unsquashed',
      (tester) async {
    await pumpReady(tester, const Size(768, 1024));

    // Both lines used to sit in a FittedBox inside a fixed book band,
    // which made the source font size irrelevant — it was scaled down to
    // whatever half the band would take. Comparing the laid-out height
    // against the transformed height is what catches that coming back.
    final value = find.text('الصف الرابع');
    expect(value, findsOneWidget);

    final laidOut = tester.getSize(value).height;
    final onScreen = tester.getRect(value).height;
    expect(
      onScreen / laidOut,
      greaterThan(0.98),
      reason: 'something is scaling the book text down again',
    );
    expect(laidOut, greaterThan(22), reason: 'the value is under 22sp');
  });

  for (final entry in const <String, Size>{
    'landscape phone 851x393': Size(851, 393),
    'landscape small phone 740x360': Size(740, 360),
    'landscape tablet 4:3 1024x768': Size(1024, 768),
  }.entries) {
    testWidgets('the start button covers no book on ${entry.key}',
        (tester) async {
      await pumpReady(tester, entry.value);

      final buttonRect = tester.getRect(find.byType(FilledButton).first);

      // A full-width band across the foot of a short landscape window
      // landed on the lowest book and on the guide beside it. Every book
      // control is checked, not just the last one.
      for (final label in [
        tr('path.grade'),
        tr('path.atram'),
        tr('path.subject'),
        tr('path.term'),
        tr('path.unit'),
        tr('path.lesson'),
      ]) {
        final book = find.text(label);
        if (book.evaluate().isEmpty) continue;
        expect(
          buttonRect.overlaps(tester.getRect(book).deflate(1)),
          isFalse,
          reason: 'the start button covers the $label book',
        );
      }
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
