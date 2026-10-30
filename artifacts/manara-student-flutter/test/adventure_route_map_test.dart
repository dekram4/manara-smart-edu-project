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
      expect(RouteArt.subject('الأرقام العربية'), 'assets/images/subjects/ar_numbers_conv.png');
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

    test('الوحداتُ والدروس من صور مادّتها، تدور عليها ولا تبدأ بصورة المادة', () {
      expect(RouteArt.item('الرياضيات', 0), 'assets/images/subjects/math_2.png');
      expect(RouteArt.item('الرياضيات', 5), 'assets/images/subjects/math_1.png');
      expect(RouteArt.item('العلوم', 0), 'assets/images/subjects/science_1.png');
      // مادةٌ بصورةٍ واحدة: الصورةُ نفسُها، لا فراغ.
      expect(RouteArt.item('الحروف العربية', 3), 'assets/images/subjects/ar_letters.png');
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
        ])
          ...pool,
      };
      for (final image in images) {
        expect(image, matches(RegExp(r'^assets/images/(routes|subjects)/')));
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
      final start = tester.widget<FilledButton>(find.byType(FilledButton).first);
      expect(start.onPressed, isNotNull);
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
