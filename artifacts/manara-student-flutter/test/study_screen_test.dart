import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/academic_context.dart';
import 'package:manara_student/src/models/study_games.dart';
import 'package:manara_student/src/models/student_content.dart';
import 'package:manara_student/src/models/student_gamification.dart';
import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/screens/student_study_screen.dart';
import 'package:manara_student/src/services/student_content_service.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:manara_student/src/services/student_study_service.dart';

/// شاشةُ المذاكرة: ألعابُ الدرس وحدها — لا خريطةَ ولا تحدّيَ قصصيّ.
class FakeStudy implements StudentStudyService {
  int packs = 0;

  @override
  Future<StudyGamesPack> fetchGames({required String lessonId}) async => StudyGamesPack.fromMap({
        'lessonId': lessonId,
        'games': [
          {
            'id': 'endless_quiz',
            'game_type': 'endless_quiz',
            'title': 'سباق',
            'instructions': 'أجب',
            'items': {
              'drag_items': [],
              'drop_targets': [],
              'correct_pairs': [],
              'questions': [
                {'kind': 'mcq', 'question': 'ماذا يمتصّ الجذر؟', 'options': ['الماء', 'الضوء'], 'answer': 'الماء'},
              ],
            },
            'gems_reward': 5,
            'points_reward': 15,
          },
        ],
      })!;

  @override
  Future<Never> fetch({required String lessonId}) async {
    packs += 1;
    throw StateError('الخريطةُ والتحدي لا يُطلبان');
  }

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
    String? tracingItem,
    String? quranSurah,
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

  Future<FakeStudy> pump(WidgetTester tester, {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final study = FakeStudy();
    await tester.pumpWidget(
      MaterialApp(
        home: StudentStudyScreen(
          profile: profile,
          studyService: study,
          contentService: FakeContent(),
          academicContext: context,
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return study;
  }

  testWidgets('ألعابُ الدرس وحدها: لا خريطةَ ولا تحدّيَ قصصيّ', (tester) async {
    final study = await pump(tester);
    expect(find.text('أجزاء النبات'), findsOneWidget);
    expect(find.text(tr('study.tabGames')), findsOneWidget);
    for (final style in ['balloons', 'fishing', 'train', 'slingshot']) {
      expect(find.byKey(ValueKey('arcade-$style')), findsOneWidget);
    }
    expect(find.text(tr('study.tabMap')), findsNothing);
    expect(find.text(tr('study.tabStory')), findsNothing);
    expect(find.text(tr('study.start')), findsNothing);
    expect(study.packs, 0, reason: 'لا يُطلب من الخادم ما لا يُعرض');
    expect(tester.takeException(), isNull);
  });

  testWidgets('لا تجاوزَ على شاشةٍ ضيّقةٍ ولا عريضة', (tester) async {
    for (final size in const [Size(320, 640), Size(1280, 720)]) {
      await pump(tester, size: size);
      expect(tester.takeException(), isNull, reason: '$size');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
