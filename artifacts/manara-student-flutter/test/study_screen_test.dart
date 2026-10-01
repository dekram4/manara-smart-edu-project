import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/academic_context.dart';
import 'package:manara_student/src/models/interactive_study.dart';
import 'package:manara_student/src/models/student_content.dart';
import 'package:manara_student/src/models/student_gamification.dart';
import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/screens/student_study_screen.dart';
import 'package:manara_student/src/services/student_content_service.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:manara_student/src/services/student_study_service.dart';

import 'interactive_study_test.dart' as data;

/// شاشةُ المذاكرة بتصميمها الجديد: مسارُ محطات، ومبدّلٌ، وتحدٍّ بمراحله.
class FakeStudy implements StudentStudyService {
  @override
  Future<StudyPack> fetch({required String lessonId}) async =>
      StudyPack.fromMap(data.pack())!;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeContent implements StudentContentService {
  final List<int?> rewarded = [];
  int gems = 6;

  @override
  Future<RewardResult> rewardActivity({
    required StudentProfile profile,
    required String activityType,
    required String activityId,
    String? rewardId,
    int? correctAnswers,
    int? quizTotal,
  }) async {
    rewarded.add(correctAnswers);
    return RewardResult(
      xp: 0,
      gems: gems,
      alreadyRewarded: gems == 0,
      levelUp: false,
      newAchievements: const [],
      snapshot: const StudentGamification(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const profile = StudentProfile(id: 's1', username: 's1', name: 'طالب', role: 'student');

final context = AcademicContext(
  grade: '4',
  subject: 'العلوم',
  term: 'الأول',
  unit: 'النبات',
  selectedLesson: const LessonContent(
    id: 'L1',
    lessonId: 'L1',
    grade: '4',
    subject: 'العلوم',
    term: 'الأول',
    unit: 'النبات',
    lessonName: 'أجزاء النبات',
    createdAt: '2026-01-01T00:00:00Z',
    ownerId: 't1',
    videos: [],
    games: [],
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  Future<FakeContent> pump(WidgetTester tester, {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final content = FakeContent();
    await tester.pumpWidget(
      MaterialApp(
        home: StudentStudyScreen(
          profile: profile,
          studyService: FakeStudy(),
          contentService: content,
          academicContext: context,
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return content;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('الخريطةُ مسارُ محطاتٍ مرقّمة، والدرسُ في الرأس', (tester) async {
    await pump(tester);
    expect(find.text('أجزاء النبات'), findsOneWidget);
    expect(find.text('النبات'), findsWidgets);
    for (final title in ['الجذر', 'الساق', 'الورقة']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text(trf('study.mapIntro', {'n': '3'})), findsOneWidget);
    // الشرحُ مطويٌّ حتى يُطلب.
    expect(find.text('يمتصّ الماء'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('المحطةُ تنفتح بشرحها وزرّ تحدّيها', (tester) async {
    await pump(tester);
    await tester.tap(find.text('الجذر'));
    await settle(tester);
    expect(find.text('يمتصّ الماء'), findsOneWidget);
    expect(find.text(tr('study.challengeBranch')), findsOneWidget);
  });

  testWidgets('تحدّي المحطة يفتح التحدي، والمبدّلُ يتبعه', (tester) async {
    await pump(tester);
    await tester.tap(find.text('الجذر'));
    await settle(tester);
    await tester.tap(find.text(tr('study.challengeBranch')));
    await settle(tester);
    // الموقفُ الأوّل من مغامرة الجذر، وشريطُ التقدّم «١ من ٣».
    expect(find.text('مغامرة البستان'), findsOneWidget);
    expect(find.text(trf('study.step', {'n': '1', 'total': '3'})), findsOneWidget);
  });

  testWidgets('قرارٌ صحيح: لوحةٌ خضراءُ وشارةُ جواهر، ثم التالي', (tester) async {
    await pump(tester);
    await tester.tap(find.text(tr('study.tabStory')));
    await settle(tester);
    expect(find.text(tr('study.storyTitle')), findsOneWidget);
    expect(find.text(tr('study.chipGems')), findsOneWidget);
    await tester.tap(find.text(tr('study.start')));
    await settle(tester);
    await tester.tap(find.text('بوّابة الماء'));
    await settle(tester);
    expect(find.text(tr('study.feedbackRight')), findsOneWidget);
    expect(find.text('النبات يحتاج الماء'), findsOneWidget);
    expect(find.text(trf('study.gemNow', {'gems': '2'})), findsOneWidget);
    expect(find.text(tr('study.next')), findsOneWidget);
  });

  testWidgets('قرارٌ خاطئ: «فكرة مفيدة» لا عقاب', (tester) async {
    await pump(tester);
    await tester.tap(find.text(tr('study.tabStory')));
    await settle(tester);
    await tester.tap(find.text(tr('study.start')));
    await settle(tester);
    await tester.tap(find.text('بوّابة الرمل'));
    await settle(tester);
    expect(find.text(tr('study.feedbackLearn')), findsOneWidget);
  });

  testWidgets('لا تجاوزَ على شاشةٍ ضيّقةٍ ولا عريضة', (tester) async {
    for (final size in const [Size(320, 640), Size(1280, 720)]) {
      await pump(tester, size: size);
      await tester.tap(find.text('الساق'));
      await settle(tester);
      expect(tester.takeException(), isNull, reason: '$size map');
      await tester.tap(find.text(tr('study.tabStory')));
      await settle(tester);
      await tester.tap(find.text(tr('study.start')));
      await settle(tester);
      expect(tester.takeException(), isNull, reason: '$size story');
      // يُنزع بين المقاسين: الشاشةُ نفسها في الموضع نفسه تحفظ حالَها.
      await tester.pumpWidget(const SizedBox());
    }
  });
}
