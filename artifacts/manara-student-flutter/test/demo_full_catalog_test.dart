import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/academic_context.dart';
import 'package:manara_student/src/services/demo_content.dart';
import 'package:manara_student/src/services/demo_mode.dart';
import 'package:manara_student/src/services/kindergarten_voice_quiz.dart';
import 'package:manara_student/src/services/quran_recitation.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:manara_student/src/services/tracing_sets.dart';
import 'package:manara_student/src/widgets/study_games.dart';
import 'package:manara_student/src/widgets/tracing_game.dart';

/// وضعُ الزائر يُظهر المنهجَ كلَّه كالحساب العادي، ويفتح أوّلَه وحده:
/// كلُّ مقفلٍ ظاهرٌ بقفلٍ ذهبيّ، ولا طريقَ إليه — لا من القائمة ولا من داخل اللعبة.
Future<void> _frames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _muteAudio(WidgetTester tester) {
  for (final channel in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });
  tearDown(DemoMode.exit);

  group('الروضة', () {
    test('كلُّ المواد ظاهرةٌ ومفتوحة، ومنها القرآنُ والثقافةُ العامة ببطاقتيهما', () {
      final profile = DemoContent.profile('kg');
      DemoMode.enterFor(profile);
      final selection = DemoContent.selection(profile);
      final subjects = selection.subjectsFor(grade: DemoContent.kgGrade);
      expect(subjects, containsAll(['القرآن الكريم', 'الحروف العربية', 'الحروف الإنجليزية', 'الأرقام العربية', 'الأرقام الإنجليزية', 'الثقافة العامة']));

      final quran = selection.lessonsFor(
          grade: DemoContent.kgGrade, subject: 'القرآن الكريم', term: DemoContent.term1, unit: DemoContent.unit1);
      expect(quranRecitationAllowedFor(grade: DemoContent.kgGrade, subject: 'القرآن الكريم', lesson: quran.first.lessonName),
          isTrue,
          reason: 'درسُ حفظ السور القصيرة يُظهر بطاقةَ التسميع');
      expect(kgVoiceGamesAllowedFor(grade: DemoContent.kgGrade, subject: 'الثقافة العامة'), isTrue);
      expect(DemoMode.allowsSurah('سورة الفاتحة'), isTrue);
      expect(DemoMode.allowsSurah('سورة الناس'), isFalse);
    });

    test('شرح الدرس: أربعةُ مقاطع ظاهرة، والأوّلُ وحده يعمل', () {
      final profile = DemoContent.profile('kg');
      DemoMode.enterFor(profile);
      final lesson = DemoContent.lessonsFor(profile, null).first;
      expect(lesson.videos, hasLength(4));
      expect(DemoMode.allowsSegment(0), isTrue);
      expect(DemoMode.allowsSegment(1), isFalse);
      expect(DemoContent.cinema.length, greaterThan(DemoMode.cinemaVideos));
    });

    test('قلمي السحري: كلُّ الحروف والأرقام ظاهرة، وأوّلُ أربعةٍ مفتوحة', () {
      DemoMode.enterFor(DemoContent.profile('kg'));
      final letters = writingGameFor(grade: DemoContent.kgGrade, subject: 'الحروف العربية')!;
      expect(letters.tracing.length, greaterThanOrEqualTo(28));
      final digits = writingGameFor(grade: DemoContent.kgGrade, subject: 'الأرقام الإنجليزية')!;
      expect(digits.tracing.length, greaterThan(10));
      expect(DemoMode.allowsTracing(3), isTrue);
      expect(DemoMode.allowsTracing(4), isFalse);
    });

    testWidgets('قلمي السحري: الحرفُ المقفل يُظهر رسالةَ الاشتراك ولا تُفتح لوحتُه', (tester) async {
      _muteAudio(tester);
      DemoMode.enterFor(DemoContent.profile('kg'));
      await tester.binding.setSurfaceSize(const Size(900, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TracingGame(
            game: writingGameFor(grade: DemoContent.kgGrade, subject: 'الحروف العربية')!,
            onTraced: (_) async => null,
            shapeBuilder: (_) async => null,
            speak: (_, __) async {},
            playClip: (_) async {},
          ),
        ),
      ));
      await _frames(tester);
      // ‏الخامسُ في الصفحة الأولى مقفل.
      await tester.tap(find.byKey(const ValueKey('tracing-lock-4')));
      await _frames(tester, 3);
      expect(find.byKey(const ValueKey('demo-locked')), findsOneWidget);
      expect(find.byKey(const ValueKey('guest-contact-whatsapp')), findsOneWidget);
      expect(find.byKey(const ValueKey('tracing-back-to-grid')), findsNothing);
      await tester.tap(find.text(tr('demo.ok')));
      await _frames(tester, 10);
      await tester.tap(find.byKey(const ValueKey('tracing-tile-0')));
      await _frames(tester, 3);
      expect(find.byKey(const ValueKey('tracing-back-to-grid')), findsOneWidget);
      await _frames(tester, 60);
    });
  });

  group('الصف الرابع', () {
    test('المسارُ كاملٌ كالحساب العادي: كلُّ مادةٍ وفصلٍ ووحدةٍ ودرسٍ له شرحٌ وأسئلةٌ ولعبة', () {
      final profile = DemoContent.profile('grade4');
      DemoMode.enterFor(profile);
      final selection = DemoContent.selection(profile);
      final subjects = selection.subjectsFor(grade: DemoContent.grade4);
      expect(subjects.length, greaterThanOrEqualTo(8));
      for (final subject in subjects) {
        final terms = selection.termsFor(grade: DemoContent.grade4, subject: subject);
        expect(terms, [DemoContent.term1, DemoContent.term2], reason: subject);
        for (final term in terms) {
          for (final unit in selection.unitsFor(grade: DemoContent.grade4, subject: subject, term: term)) {
            final lessons = selection.lessonsFor(grade: DemoContent.grade4, subject: subject, term: term, unit: unit);
            expect(lessons, isNotEmpty, reason: '$subject / $term / $unit');
            for (final lesson in lessons) {
              expect(lesson.videos, hasLength(4));
              expect(lesson.lessonText, isNotEmpty);
              final context = AcademicContext(grade: DemoContent.grade4, subject: subject, term: term, unit: unit, selectedLesson: lesson);
              expect((DemoContent.quizzes(profile, context).single['questions'] as List).length, greaterThanOrEqualTo(3),
                  reason: lesson.lessonName);
              final game = DemoContent.studyGames(lesson.id)!.games.single;
              expect(game.questions.every((q) => q.options.contains(q.answer)), isTrue, reason: lesson.lessonName);
            }
          }
        }
      }
      final units = selection.unitsFor(grade: DemoContent.grade4, subject: 'العلوم', term: DemoContent.term1);
      expect(units, [DemoContent.unit1, DemoContent.unit2]);
      // ‏مبدّلُ الدروس داخل الشرح: دروسُ الوحدة المختارة كلُّها.
      final science = selection.lessonsFor(
          grade: DemoContent.grade4, subject: 'العلوم', term: DemoContent.term1, unit: DemoContent.unit2);
      final ctx = AcademicContext(
          grade: DemoContent.grade4, subject: 'العلوم', term: DemoContent.term1, unit: DemoContent.unit2, selectedLesson: science.last);
      final opened = DemoContent.lessonsFor(profile, ctx);
      expect(opened.first.id, science.last.id);
      expect(opened, hasLength(science.length));
    });
  });

  testWidgets('عالم المذاكرة: شريطُ التبديل داخل اللعبة لا يتجاوز قفلَ «المقلاع»', (tester) async {
    _muteAudio(tester);
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final profile = DemoContent.profile('grade4');
    DemoMode.enterFor(profile);
    final lesson = DemoContent.lessonsFor(profile, null).first;
    final pack = DemoContent.studyGames(lesson.id)!;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(child: StudyGamesTab(load: () async => pack, onWin: (_) async => null)),
        ),
      ),
    ));
    await _frames(tester, 20);

    // ‏على الرفّ: القطارُ مقفل.
    await tester.ensureVisible(find.byKey(const ValueKey('arcade-train')));
    await tester.tap(find.byKey(const ValueKey('arcade-train')), warnIfMissed: false);
    await _frames(tester, 3);
    expect(find.byKey(const ValueKey('demo-locked')), findsOneWidget);
    expect(find.byKey(const ValueKey('game-intro-start')), findsNothing);
    await tester.tap(find.text(tr('demo.ok')));
    await _frames(tester, 10);

    // ‏المقلاعُ يُفتح.
    await tester.ensureVisible(find.byKey(const ValueKey('arcade-slingshot')));
    await tester.tap(find.byKey(const ValueKey('arcade-slingshot')));
    await _frames(tester, 10);
    await tester.tap(find.byKey(const ValueKey('game-intro-start')));
    await _frames(tester, 10);
    expect(find.byKey(const ValueKey('target-0')), findsOneWidget);

    // ‏ومن داخل اللعبة: لمسُ القطار في الشريط رسالةُ قفلٍ، واللعبةُ كما هي.
    await tester.tap(find.byKey(const ValueKey('switch-train')));
    await _frames(tester, 5);
    expect(find.byKey(const ValueKey('demo-locked')), findsOneWidget);
    expect(find.byKey(const ValueKey('target-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('wagon-0')), findsNothing);
    await tester.tap(find.text(tr('demo.ok')));
    await _frames(tester, 10);
    expect(tester.takeException(), isNull);
    await _frames(tester, 60);
  });
}
