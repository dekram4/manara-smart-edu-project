import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:manara_student/src/models/academic_context.dart';
import 'package:manara_student/src/models/student_content.dart';
import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/screens/kindergarten_card_screens.dart';
import 'package:manara_student/src/screens/student_home_screen.dart';
import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_content_service.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:manara_student/src/services/tracing_sets.dart';

/// بطاقتا الروضة المستقلّتان: «أبطال تسميع القرآن» و«قلمي السحري».
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AcademicContext context({
    String grade = 'روضة منارة المعرفة',
    required String subject,
    String lesson = 'درس',
  }) =>
      AcademicContext(
        grade: grade,
        subject: subject,
        term: 'الفصل الأول',
        unit: 'الوحدة الأولى',
        selectedLesson: LessonContent(
          id: 'L1',
          lessonId: 'L1',
          grade: grade,
          subject: subject,
          term: 'الفصل الأول',
          unit: 'الوحدة الأولى',
          lessonName: lesson,
          createdAt: '2026-01-01T00:00:00Z',
          ownerId: 't1',
          videos: const [],
          games: const [],
        ),
      );

  group('مجموعاتُ الكتابة على الجهاز — كما يصرف لها الخادم', () {
    test('الحروفُ العربية: ثمانيةٌ وعشرون باسمائها', () {
      final game = writingGameFor(grade: 'روضة منارة المعرفة', subject: 'الحروف العربية')!;
      expect(game.id, 'tracing');
      expect(game.tracing, hasLength(28));
      expect(game.tracing.first.text, 'ا');
      expect(game.tracing[1].speech, 'باء');
    });

    test('الحروفُ الإنجليزية: Aa إلى Zz', () {
      final items = writingGameFor(grade: 'روضة منارة المعرفة', subject: 'الحروف الإنجليزية')!.tracing;
      expect(items, hasLength(26));
      expect(items.first.text, 'Aa');
      expect(items.last.text, 'Zz');
      expect(items.first.speech, 'A');
    });

    test('الأرقام: من الصفر إلى المئة، بأرقامها وكلماتها', () {
      final ar = writingGameFor(grade: 'روضة منارة المعرفة', subject: 'الأرقام العربية')!.tracing;
      expect(ar, hasLength(101));
      expect(ar[25].text, '٢٥');
      expect(ar[25].speech, 'خمسة وعشرون');
      expect(ar[100].speech, 'مئة');
      final en = writingGameFor(grade: 'روضة منارة المعرفة', subject: 'الأرقام الإنجليزية')!.tracing;
      expect(en[25].text, '25');
      expect(en[25].speech, 'twenty five');
    });

    test('وخارج الروضة أو موادّها: لا لعبة', () {
      expect(writingGameFor(grade: 'الصف الأول', subject: 'الحروف العربية'), isNull);
      expect(writingGameFor(grade: 'روضة منارة المعرفة', subject: 'القرآن الكريم'), isNull);
    });
  });

  group('في الواجهة: بجانب شرح الدرس، وفي نطاقها وحده', () {
    late StudentAuthService authService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      StudentSettings.resetForTest();
      authService = StudentAuthService(
        SupabaseClient('http://127.0.0.1:1', 'test-key'),
        apiBaseUrl: '',
      );
    });

    Future<List<String>> railFor(WidgetTester tester, AcademicContext? academic) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: StudentHomeScreen(
          profile: const StudentProfile(id: 's1', name: 'طالب', username: 'student', role: 'student'),
          authService: authService,
          apiBaseUrl: '',
          academicContext: academic,
        ),
      ));
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      final keys = [
        for (final e in find
            .byWidgetPredicate((w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('portal-tile-'))
            .evaluate())
          (e.widget.key! as ValueKey<String>).value.replaceFirst('portal-tile-', ''),
      ];
      await tester.pumpWidget(const SizedBox());
      return keys;
    }

    testWidgets('درسُ الحروف: «قلمي السحري» يلي شرحَ الدرس', (tester) async {
      final rail = await railFor(tester, context(subject: 'الحروف العربية', lesson: 'الحروف العربية'));
      expect(rail.take(2), ['portal.lesson', 'portal.write']);
      expect(rail, isNot(contains('portal.recite')));
    });

    testWidgets('درسُ السور القصيرة: «أبطال تسميع القرآن» يلي شرحَ الدرس', (tester) async {
      final rail = await railFor(
        tester,
        context(subject: 'القرآن الكريم', lesson: 'تعلم وحفظ السور القصيرة'),
      );
      expect(rail.take(2), ['portal.lesson', 'portal.recite']);
      expect(rail, isNot(contains('portal.write')));
    });

    testWidgets('وأيُّ درسٍ آخر: لا تظهر أيٌّ منهما', (tester) async {
      for (final academic in [
        null,
        context(grade: 'الصف الأول', subject: 'الحروف العربية'),
        context(subject: 'القرآن الكريم', lesson: 'سورة الفيل'),
      ]) {
        final rail = await railFor(tester, academic);
        expect(rail, isNot(contains('portal.write')));
        expect(rail, isNot(contains('portal.recite')));
        expect(rail.take(2), ['portal.lesson', 'portal.study']);
      }
    });
  });

  group('البطاقتان تُفتحان على لعبتيهما مباشرةً', () {
    late StudentAuthService authService;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      StudentSettings.resetForTest();
      authService = StudentAuthService(
        SupabaseClient('http://127.0.0.1:1', 'test-key'),
        apiBaseUrl: '',
      );
    });

    StudentContentService service() => StudentContentService(
          authService.client,
          baseUrl: '',
          authService: authService,
        );
    const profile = StudentProfile(id: 's1', name: 'طالب', username: 'student', role: 'student');

    testWidgets('«قلمي السحري» على لعبة الكتابة بلا انتظار خادم', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: WritingCardScreen(
          profile: profile,
          contentService: service(),
          academicContext: context(subject: 'الحروف العربية'),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('writing-game')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('«أبطال تسميع القرآن» على قائمة السور', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: QuranRecitationCardScreen(
          profile: profile,
          contentService: service(),
          academicContext: context(subject: 'القرآن الكريم', lesson: 'تعلم وحفظ السور القصيرة'),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('quran-game')), findsOneWidget);
      expect(find.byKey(const ValueKey('quran-picker')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  test('مقطعا الترحيب داخل الأصول، بمساراتٍ نسبيّة', () {
    for (final clip in [writingWelcomeClip, recitationWelcomeClip]) {
      expect(clip, startsWith('audio/encouragement/'));
    }
  });
}
