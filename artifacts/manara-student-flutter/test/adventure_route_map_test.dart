import 'dart:io';

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
import 'package:manara_student/src/widgets/adventure_route_map.dart';
import 'package:manara_student/src/widgets/student_avatar_view.dart';

/// خريطةُ المغامرة في شاشة اختيار المسار: صورُها وأصواتُها، وسيرُ خطواتها.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('الصورُ والأصوات', () {
    test('لكلّ مادةٍ صورتُها بأيّ همزةٍ أو تاءٍ كُتبت', () {
      expect(RouteArt.subject('القرآن الكريم'), 'assets/images/routes/subject_quran.png');
      expect(RouteArt.subject('القران الكريم'), 'assets/images/routes/subject_quran.png');
      expect(RouteArt.subject('القاعدة النورانية'), 'assets/images/subjects/noorani.png');
      expect(RouteArt.subject('الحروف العربية'), 'assets/images/subjects/ar_letters.png');
      expect(RouteArt.subject('اللغة العربية'), 'assets/images/subjects/ar_letters.png');
      expect(RouteArt.subject('الحروف الإنجليزية'), 'assets/images/routes/subject_en_letters.png');
      expect(RouteArt.subject('الأرقام الإنجليزية'), 'assets/images/routes/subject_en_numbers.png');
      expect(RouteArt.subject('الأرقام العربية'), 'assets/images/subjects/ar_digits_1.png');
      expect(RouteArt.subject('اللغة الإنجليزية'), 'assets/images/subjects/en_subj_1.png');
      expect(RouteArt.subject('الرياضيات'), 'assets/images/subjects/math_1.png');
      expect(RouteArt.subject('العلوم'), 'assets/images/routes/subject_science.png');
      expect(RouteArt.subject('الثقافة العامة'), 'assets/images/subjects/general_1.png');
    });

    test('لا خيارَ بلا صورة: مادةٌ لا تُعرف تأخذ من الثقافة العامة، ثابتةً لاسمها', () {
      final art = RouteArt.subject('التربية الفنية');
      expect(RouteArt.general, contains(art));
      expect(RouteArt.subject('التربية الفنية'), art);
    });

    test('صورةُ الدرس من اسمه: السورةُ مصحفٌ لا حروف، والجمعُ علاماتُ الحساب', () {
      final surahs = RouteArt.assign('القرآن الكريم', ['سورة الفاتحة', 'سورة الناس', 'سورة الفلق', 'سورة الإخلاص']);
      for (final art in surahs) {
        expect(art, isNot(contains('ar_letters')), reason: 'صورةُ حروفٍ على سورة: $art');
        expect(RouteArt.quran, contains(art));
      }
      expect(RouteArt.assign('الرياضيات', ['الجمع']).single, 'assets/images/subjects/math_5.png');
      expect(RouteArt.assign('الرياضيات', ['الأشكال الهندسية']).single, 'assets/images/subjects/math_2.png');
      expect(RouteArt.assign('العلوم', ['جسم الإنسان']).single, 'assets/images/subjects/science_4.png');
      expect(RouteArt.assign('الحروف العربية', ['حرف الباء']).single, contains('ar_letters_'));
    });

    test('الأرقامُ العربية بأرقامها (١٢٣): لا مكعّباتُ 1 2 3 ولا الفرجارُ وأدواتُ الهندسة', () {
      final art = RouteArt.assign('الأرقام العربية', [for (var i = 1; i <= 8; i++) 'الدرس $i']);
      for (final image in art) {
        expect(image, contains('ar_digits_'), reason: image);
      }
      expect(RouteArt.arabicNumbers, isNot(contains('assets/images/subjects/math_2.png')));
      expect(RouteArt.arabicNumbers, isNot(contains('assets/images/subjects/ar_numbers_conv.png')));
    });

    test('لا تتكرّر صورةٌ في قائمةٍ ما بقيت صورةٌ لم تُستعمل', () {
      for (final subject in ['الرياضيات', 'العلوم', 'اللغة الإنجليزية', 'الحروف العربية', 'الأرقام العربية', 'القرآن الكريم']) {
        final count = RouteArt.pool(subject).length - 1;
        final shown = RouteArt.assign(subject, [for (var i = 1; i <= count; i++) 'الوحدة $i']);
        expect(shown.toSet(), hasLength(count), reason: subject);
      }
    });

    test('الأرقامُ عربية', () {
      expect(arabicDigits(1), '١');
      expect(arabicDigits(12), '١٢');
    });

    test('بوابتان تتناوبان على الصفوف، وشمسٌ ومطرٌ على الفصول', () {
      expect(RouteArt.gate(0), endsWith('gate_1.png'));
      expect(RouteArt.gate(1), endsWith('gate_2.png'));
      expect(RouteArt.gate(2), endsWith('gate_1.png'));
      expect(RouteArt.term(0), endsWith('term_1.png'));
      expect(RouteArt.term(1), endsWith('term_2.png'));
    });

    test('كلُّ صورةٍ وصوتٍ في الخريطة داخل assets/ بمسارٍ نسبيّ', () {
      final images = {
        RouteArt.background,
        RouteArt.gate(0),
        RouteArt.gate(1),
        RouteArt.term(0),
        RouteArt.term(1),
        for (final pool in [
          RouteArt.quran,
          RouteArt.noorani,
          RouteArt.arabicLetters,
          RouteArt.arabicNumbers,
          RouteArt.englishLetters,
          RouteArt.englishNumbers,
          RouteArt.english,
          RouteArt.math,
          RouteArt.science,
          RouteArt.general,
          RouteArt.arabicNumbers,
        ])
          ...pool,
      };
      for (final image in images) {
        expect(image, startsWith('assets/images/'));
        expect(File(image).existsSync(), isTrue, reason: image);
      }
      for (final prompt in [
        RouteArt.selectGrade,
        RouteArt.selectSubject,
        RouteArt.selectTerm,
        RouteArt.selectUnit,
        RouteArt.selectLesson,
      ]) {
        expect(prompt, startsWith('audio/prompts/'));
        expect(File('assets/$prompt').existsSync(), isTrue, reason: prompt);
      }
    });
  });

  group('سيرُ الخطوات', () {
    late StudentAuthService authService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      StudentSettings.resetForTest();
      authService = StudentAuthService(
        SupabaseClient('http://127.0.0.1:1', 'test-key'),
        apiBaseUrl: '',
      );
    });

    LessonContent lesson(String grade, String subject, String term, String unit, String name) => LessonContent(
          id: '$grade$subject$term$unit$name',
          lessonId: '$grade$subject$term$unit$name',
          grade: grade,
          subject: subject,
          term: term,
          unit: unit,
          lessonName: name,
          createdAt: '2026-01-01',
          videos: const [],
          games: const [],
        );

    const kg = 'روضة منارة المعرفة';
    final lessons = [
      lesson(kg, 'القرآن الكريم', 'الفصل الأول', 'الوحدة الأولى', 'سورة الفاتحة'),
      lesson(kg, 'العلوم', 'الفصل الأول', 'الوحدة الأولى', 'النبات'),
      lesson(kg, 'العلوم', 'الفصل الثاني', 'الوحدة الأولى', 'الماء'),
      lesson('الصف الأول', 'العلوم', 'الفصل الأول', 'الوحدة الأولى', 'الخلية'),
    ];
    final data = AcademicSelectionData(
      paths: [
        for (final l in lessons) AcademicPath(grade: l.grade, subject: l.subject, term: l.term, unit: l.unit),
      ],
      lessons: lessons,
    );

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: AcademicSelectionScreen(
          profile: const StudentProfile(id: 's1', name: 'طالب', username: 'student', role: 'student'),
          authService: authService,
          apiBaseUrl: '',
          initialData: data,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));
    }

    String valueAt(WidgetTester tester, int station) =>
        tester.widget<Text>(find.byKey(ValueKey('adventure-value-$station'))).data!;

    testWidgets('الخلفيةُ المجرّة، والصفوفُ بواباتٌ أوّلاً مع سؤالها', (tester) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('adventure-background')), findsOneWidget);
      expect(find.text(tr('route.pickGrade')), findsOneWidget);
      expect(find.byKey(const ValueKey('adventure-option-0-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('adventure-option-0-1')), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        expect(find.byKey(ValueKey('adventure-station-$i')), findsOneWidget);
      }
    });

    testWidgets('لمسُ خيارٍ يختاره وينتقل بالطفل إلى الخطوة التالية', (tester) async {
      await pump(tester);
      // الصفُّ: الروضة.
      await tester.tap(find.byKey(const ValueKey('adventure-option-0-0')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(tr('route.pickSubject')), findsOneWidget);
      expect(valueAt(tester, 0), kg);

      // المادةُ: العلوم — الثانيةُ في القائمة.
      await tester.tap(find.byKey(const ValueKey('adventure-option-1-1')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(tr('route.pickTerm')), findsOneWidget);
      expect(valueAt(tester, 1), 'العلوم');

      // الفصلُ الثاني، ثم الوحدة، ثم الدرس.
      await tester.tap(find.byKey(const ValueKey('adventure-option-2-1')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(tr('route.pickUnit')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('adventure-option-3-0')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(tr('route.pickLesson')), findsOneWidget);
      expect(valueAt(tester, 4), 'الماء');

      // والزرُّ جاهز.
      final start = tester.widget<GestureDetector>(find.byKey(const ValueKey('path-start')));
      expect(start.onTap, isNotNull);
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('لحظةَ الدخول والمسارُ يُقرأ: شخصيةُ الطالب على خلفية الخريطة، بلا عبارة ترحيب', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: AcademicSelectionScreen(
          profile: const StudentProfile(id: 's1', name: 'سارة', username: 'sara', role: 'student'),
          authService: authService,
          apiBaseUrl: '',
        ),
      ));
      // ‏الإطارُ الأوّل: الترحيبُ والمسارُ لم يصل بعد.
      expect(find.byKey(const ValueKey('path-welcome-panel')), findsOneWidget);
      expect(find.text('سارة'), findsNothing);
      expect(find.byType(StudentAvatarView), findsWidgets);
      expect(find.byKey(const ValueKey('adventure-background')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('لا عبارةَ ترحيبٍ على الخريطة ولا في «تغيير الدرس»', (tester) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('path-welcome')), findsNothing);
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('«تغيير الدرس»: الخريطةُ نفسُها، والرجوعُ بلا تغيير، والبدءُ يعود بالمسار', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final results = <AcademicContext?>[];
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              results.add(await Navigator.of(context).push<AcademicContext>(
                MaterialPageRoute(
                  builder: (_) => AcademicSelectionScreen(
                    profile: const StudentProfile(id: 's1', name: 'طالب', username: 'student', role: 'student'),
                    authService: authService,
                    apiBaseUrl: '',
                    initialData: data,
                    pickOnly: true,
                  ),
                ),
              ));
            },
            child: const Text('غيّر'),
          ),
        ),
      ));
      await tester.tap(find.text('غيّر'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      // ‏لا خروجَ من الحساب هنا: رجوعٌ إلى اللوحة.
      expect(find.byKey(const ValueKey('path-back')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('path-back')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(results, [null]);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('غيّر'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('adventure-option-0-0')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('path-start')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(results, hasLength(2));
      expect(results.last?.grade, kg);
      expect(results.last?.selectedLesson, isNotNull);
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('لمسُ محطّةٍ يعود بالطفل إليها', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('adventure-option-0-0')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(tr('route.pickSubject')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('adventure-station-0')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(tr('route.pickGrade')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
