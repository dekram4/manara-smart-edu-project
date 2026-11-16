import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/academic_context.dart';
import 'package:manara_student/src/screens/demo_chat_screen.dart';
import 'package:manara_student/src/screens/plans_screen.dart';
import 'package:manara_student/src/services/demo_content.dart';
import 'package:manara_student/src/services/demo_mode.dart';
import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_content_service.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:manara_student/src/services/student_study_service.dart';
import 'package:manara_student/src/widgets/demo_ui.dart';

/// وضعُ الزائر يعمل على الجهاز وحده، وواجهاتُه لا تُقصّ على أيّ مقاس.
///
/// الخادمُ هنا عنوانٌ لا يُجيب (`127.0.0.1:1`): أيُّ طلبٍ شبكيّ يفشل —
/// فنجاحُ كلّ قراءةٍ دليلٌ على أنها لم تخرج من الجهاز.
const _deadServer = 'http://127.0.0.1:1';

const _sizes = {
  'جوالٌ صغير': Size(320, 640),
  'جوالٌ كبير': Size(430, 932),
  'جوالٌ أفقيّ': Size(844, 390),
  'تابلت عموديّ': Size(800, 1280),
  'أيباد أفقيّ': Size(1366, 1024),
};

/// إطاراتٌ قصيرة متتالية: الحركاتُ تبدأ في الأوّل وتنتهي بعده.
Future<void> _frames(WidgetTester tester, [int n = 12]) async {
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

  group('بلا خادم', () {
    test('الدخولُ كزائرٍ فوريٌّ على الجهاز، ولا جلسةَ على الخادم', () async {
      final auth = StudentAuthService(SupabaseClient(_deadServer, 'k'), apiBaseUrl: _deadServer);
      final watch = Stopwatch()..start();
      final kg = await auth.signInDemo('kg');
      expect(watch.elapsedMilliseconds, lessThan(500));
      expect(kg.isDemo, isTrue);
      expect(kg.grade, DemoContent.kgGrade);
      expect(kg.gamification.gems, 0);
      expect(await auth.ensureApiSession(), isNull);
      final g4 = await auth.signInDemo('grade4');
      expect(g4.grade, DemoContent.grade4);
      expect(g4.demoTrack, 'grade4');
    });

    test('المسارُ والدروسُ والاختبارُ والسينما والمكافأة: كلُّها من التطبيق', () async {
      final auth = StudentAuthService(SupabaseClient(_deadServer, 'k'), apiBaseUrl: _deadServer);
      final profile = await auth.signInDemo('grade4');
      DemoMode.enterFor(profile);
      final service = StudentContentService(auth.client, baseUrl: _deadServer, authService: auth);

      final selection = await service.fetchAcademicSelectionData(profile).timeout(const Duration(seconds: 2));
      expect(selection.grades, [DemoContent.grade4]);
      expect(selection.subjectsFor(grade: DemoContent.grade4), contains('الرياضيات'));
      expect(
          selection.termsFor(grade: DemoContent.grade4, subject: 'الرياضيات'), [DemoContent.term1, DemoContent.term2]);
      final lessons = selection.lessonsFor(
          grade: DemoContent.grade4, subject: 'الرياضيات', term: DemoContent.term1, unit: DemoContent.unit1);
      expect(lessons, hasLength(4));
      expect(lessons.first.lessonText, isNotEmpty);

      final context = AcademicContext(
        grade: DemoContent.grade4,
        subject: 'الرياضيات',
        term: DemoContent.term1,
        unit: DemoContent.unit1,
        selectedLesson: lessons.first,
      );
      final opened = await service.fetchLessons(profile, academicContext: context);
      expect(opened.first.id, lessons.first.id);
      // ‏مبدّلُ الدروس داخل الشرح لا يصل الدرسين المقفلين.
      expect(opened, hasLength(2));

      final quizzes = await service.fetchAvailableQuizzes(profile, academicContext: context);
      expect(quizzes, hasLength(1));
      expect((quizzes.first['questions'] as List), hasLength(4));

      final videos = await service.fetchCinemaVideos(profile);
      // ‏الرفُّ كاملاً، والأوّلُ مدمجٌ في التطبيق.
      expect(videos.length, greaterThan(1));
      expect(videos.every((v) => v.url.startsWith('asset:')), isTrue);
      expect((await service.fetchGameCatalog()).length, greaterThan(1));
      expect(await service.fetchCardPermissions(profile), isEmpty);
      expect((await service.fetchGamification(profile)).gems, 0);

      final reward = await service.rewardActivity(profile: profile, activityType: 'quiz', activityId: 'x');
      expect(reward.gems, 0);
      final saved = await service.saveQuizResult(profile: profile, result: {'id': 'r1', 'score': 2});
      expect(saved['id'], 'r1');
      expect((await service.fetchQuizResults(profile)).map((r) => r['id']), contains('r1'));

      final study = StudentStudyService(apiBaseUrl: _deadServer, authService: auth);
      final pack = await study.fetchGames(lessonId: lessons.first.id);
      expect(pack.games.single.questions, hasLength(4));
      final fresh =
          await study.fetchFreshGame(lessonId: lessons.first.id, type: pack.games.single.type, exclude: const []);
      expect(fresh.questions, hasLength(4));
    });

    test('الروضة: الموادّ الستّ، ولكلّ درسٍ مفتوحٍ شرحٌ وأسئلةٌ ولعبة', () {
      final profile = DemoContent.profile('kg');
      final selection = DemoContent.selection(profile);
      final subjects = selection.subjectsFor(grade: DemoContent.kgGrade);
      expect(subjects, hasLength(6));
      for (final subject in subjects) {
        final lessons = selection.lessonsFor(
            grade: DemoContent.kgGrade, subject: subject, term: DemoContent.term1, unit: DemoContent.unit1);
        for (final lesson in lessons.take(2)) {
          expect(lesson.hasExplanation, isTrue);
          expect(DemoContent.studyGames(lesson.id), isNotNull, reason: lesson.lessonName);
        }
      }
    });
  });

  group('كلُّ المقاسات', () {
    for (final entry in _sizes.entries) {
      testWidgets('الباقاتُ ونموذجُ الطلب — ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const MaterialApp(home: PlansScreen(apiBaseUrl: '')));
        await _frames(tester);
        expect(tester.takeException(), isNull);
        final tier = find.byKey(const ValueKey('plan-choose-school_large'));
        await tester.ensureVisible(tier);
        await _frames(tester, 2);
        await tester.tap(tier);
        await _frames(tester);
        expect(find.byKey(const ValueKey('plans-form')), findsOneWidget);
        await tester.ensureVisible(find.byKey(const ValueKey('plans-whatsapp')));
        await _frames(tester, 4);
        expect(tester.takeException(), isNull);
      });

      testWidgets('لوحةُ مسار الزائر ونافذتُه — ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        String? picked;
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextButton(
                    key: const ValueKey('open-sheet'),
                    onPressed: () async {
                      picked = await showModalBottomSheet<String>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        constraints: const BoxConstraints(maxWidth: 560),
                        builder: (_) => const DemoTrackSheet(),
                      );
                    },
                    child: const Text('sheet'),
                  ),
                  TextButton(
                    key: const ValueKey('open-dialog'),
                    onPressed: () => showDemoDialog<void>(
                      context: context,
                      emoji: '🧮',
                      title: tr('portal.solver'),
                      body: Text(tr('demo.teaser.solver')),
                      actions: [
                        DemoGradientButton(label: tr('demo.getAccount'), shimmer: true, onPressed: () {}),
                        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('demo.ok'))),
                      ],
                    ),
                    child: const Text('dialog'),
                  ),
                ]),
              ),
            ),
          ),
        ));
        await tester.tap(find.byKey(const ValueKey('open-sheet')));
        await _frames(tester);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byKey(const ValueKey('demo-track-grade4')));
        await _frames(tester, 2);
        await tester.tap(find.byKey(const ValueKey('demo-track-grade4')));
        await _frames(tester);
        expect(picked, 'grade4');

        await tester.tap(find.byKey(const ValueKey('open-dialog')));
        await _frames(tester);
        expect(find.text(tr('demo.teaser.solver')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('دردشةُ الزائر — ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const MaterialApp(home: DemoChatScreen()));
        await _frames(tester);
        await tester.enterText(find.byKey(const ValueKey('demo-chat-input')),
            'مرحباً يا منار، هذه رسالةٌ طويلةٌ قليلاً لنرى أنها تلتفّ ولا تُقصّ');
        await tester.tap(find.byKey(const ValueKey('demo-chat-send')));
        await _frames(tester, 20);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
