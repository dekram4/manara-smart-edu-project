import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/academic_context.dart';
import 'package:manara_student/src/screens/student_quiz_screen.dart';
import 'package:manara_student/src/services/demo_content.dart';
import 'package:manara_student/src/services/demo_curriculum.dart';
import 'package:manara_student/src/services/demo_mode.dart';
import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_content_service.dart';
import 'package:manara_student/src/services/student_settings.dart';

/// اختبارُ الزائر: سؤالان حقيقيّان من الدرس، والباقي مقفلٌ برسالةٍ ذهبية.
const _deadServer = 'http://127.0.0.1:1';

Future<void> _frames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });
  tearDown(DemoMode.exit);

  test('كلُّ درسٍ في المسارين: شرحٌ مكتوب، وثلاثةُ أسئلةٍ على الأقل من محتواه', () {
    for (final subject in [...demoKgCurriculum, ...demoGrade4Curriculum]) {
      expect(subject.lessons, hasLength(10), reason: subject.name);
      for (final lesson in subject.lessons) {
        final where = '${subject.name} / ${lesson.name}';
        expect(lesson.text.length, greaterThan(30), reason: where);
        expect(lesson.questions.length, greaterThanOrEqualTo(3), reason: where);
        for (final q in lesson.questions) {
          expect(q.options, contains(q.answer), reason: '$where: ${q.question}');
          expect(q.options.toSet(), hasLength(q.options.length), reason: '$where: ${q.question}');
          // ‏لا أسئلةَ عامّة عن موضع الدرس في المنهج.
          expect(q.question, isNot(contains('الذي تذاكره الآن')), reason: where);
        }
      }
    }
  });

  test('الخياراتُ مرتّبةٌ للعرض: الصحيحُ ليس أوّلَها دائماً', () {
    final profile = DemoContent.profile('grade4');
    DemoMode.enterFor(profile);
    final firsts = <bool>[];
    for (final lesson in DemoContent.lessons(profile).take(10)) {
      final context = AcademicContext(
          grade: lesson.grade, subject: lesson.subject, term: lesson.term, unit: lesson.unit, selectedLesson: lesson);
      for (final q in DemoContent.quizzes(profile, context).single['questions'] as List) {
        final options = q['options'] as List;
        if (options.length > 2) firsts.add(options.first == q['correctAnswer']);
      }
    }
    expect(firsts, contains(false));
    expect(firsts, contains(true));
  });

  testWidgets('الشاشة: سؤالان فقط، والباقي مقفلٌ برسالةٍ ذهبية — قبل التسليم وبعده', (tester) async {
    for (final channel in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = StudentAuthService(SupabaseClient(_deadServer, 'k'), apiBaseUrl: _deadServer);
    final profile = await auth.signInDemo('grade4');
    DemoMode.enterFor(profile);
    final service = StudentContentService(auth.client, baseUrl: _deadServer, authService: auth);
    final lesson = DemoContent.lessons(profile).first;
    final context = AcademicContext(
        grade: lesson.grade, subject: lesson.subject, term: lesson.term, unit: lesson.unit, selectedLesson: lesson);
    final written = demoGrade4Curriculum.first.lessons.first.questions;

    await tester.pumpWidget(MaterialApp(
      home: StudentQuizScreen(profile: profile, contentService: service, academicContext: context),
    ));
    await _frames(tester, 20);
    expect(find.text('اختبار «${lesson.lessonName}»'), findsOneWidget);
    final start = find.text(tr('quiz.start'));
    await tester.ensureVisible(start.first);
    await tester.tap(start.first);
    await _frames(tester);

    // ‏السؤالُ الظاهر من أسئلة الدرس نفسه (ترتيبُها يتبدّل بين المحاولات)، وعدّادُه «من ٢».
    DemoQ shown() {
      final on = written.where((q) => find.text(q.question).evaluate().isNotEmpty).toList();
      expect(on, hasLength(1), reason: 'سؤالٌ واحدٌ من الدرس على الشاشة');
      return on.single;
    }

    final first = shown();
    expect(find.text(trf('quiz.questionOf', {'n': 1, 'total': 2})), findsOneWidget);
    expect(find.byKey(const ValueKey('demo-quiz-locked')), findsOneWidget);
    final hidden = written.length - DemoMode.quizQuestions;
    expect(find.text(trf('demo.quiz.lockedCount', {'n': hidden})), findsOneWidget);
    expect(find.text(tr('demo.quiz.lockedMore')), findsOneWidget);
    final seen = <String>{first.question};
    for (var i = 0; i < 2; i++) {
      final q = i == 0 ? first : shown();
      seen.add(q.question);
      await tester.tap(find.text(q.answer).first);
      await _frames(tester, 3);
      final next = find.text(i == 0 ? tr('action.next') : tr('quiz.submit'));
      await tester.ensureVisible(next);
      await tester.tap(next);
      await _frames(tester, 15);
    }
    expect(seen, hasLength(2), reason: 'سؤالان مختلفان');
    expect(find.text('100%'), findsOneWidget);
    expect(find.byKey(const ValueKey('demo-quiz-locked')), findsOneWidget, reason: 'الرسالةُ تحت النتيجة أيضاً');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    // ‏مؤقّتُ تجديد الجلسة في عميل الاختبار نفسه — لا طلبَ منه.
    auth.client.auth.stopAutoRefresh();
    await _frames(tester, 60);
  });
}
