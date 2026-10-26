import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/models/student_gamification.dart';
import 'package:manara_student/src/models/study_games.dart';
import 'package:manara_student/src/widgets/study_games.dart';

/// إعادةُ «أجب ومرِّر»: أسئلةٌ جديدة تتجنّب ما رآه الطالب؛ وحروفُ الروضة هي هي.
StudyGame _quiz(String suffix) => StudyGame.fromMap({
      'id': 'tracing',
      'game_type': 'tracing',
      'title': 'أجب وتتبّع!',
      'instructions': 'مرّر',
      'items': {
        'tracing': [
          for (var i = 0; i < 6; i++)
            {
              'text': 'جواب$i',
              'kind': 'answer',
              'lang': 'ar',
              'prompt': 'سؤال $i$suffix؟',
              'options': ['جواب$i', 'خطأ$i', 'غلط$i'],
            },
        ],
      },
      'gems_reward': 6,
      'points_reward': 30,
    })!;

StudyGame _letters() => StudyGame.fromMap({
      'id': 'tracing',
      'game_type': 'tracing',
      'title': 'تتبّع واكتب!',
      'instructions': 'مرّر',
      'items': {
        'tracing': [
          for (final l in ['ا', 'ب', 'ت']) {'text': l, 'kind': 'letter', 'lang': 'ar'},
        ],
      },
      'gems_reward': 6,
      'points_reward': 30,
    })!;

Future<void> _settle(WidgetTester tester) async {
  // نبضُ لوحة التتبّع لا يسكن، فلا `pumpAndSettle`.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _openFromShelf(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await _settle(tester);
}

Future<void> _backToShelf(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.grid_view_rounded));
  await _settle(tester);
}

Widget _host(StudyGame base, Future<StudyGame> Function(StudyGame, List<String>) fresh,
        {StudyGameWin? onWin}) =>
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        body: StudyGamesTab(
          load: () async => StudyGamesPack(lessonId: 'L1', games: [base]),
          onWin: onWin ?? (_, {correct, total}) async => null,
          seenKey: 'study.seen.s1.L1',
          fresh: fresh,
        ),
      ),
    );

void main() {
  testWidgets('كلُّ إعادةٍ أسئلةٌ جديدة، ومعها ما رآه الطالب من قبل', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final calls = <List<String>>[];
    var round = 0;
    await tester.binding.setSurfaceSize(const Size(900, 700));
    await tester.pumpWidget(_host(_quiz(''), (base, exclude) async {
      calls.add(exclude);
      round += 1;
      return _quiz('-$round');
    }));
    await _settle(tester);

    await _openFromShelf(tester, 'أجب وتتبّع!');
    expect(calls, isEmpty, reason: 'أوّلُ مرّة: أسئلةُ الحزمة');
    expect(find.text('سؤال 0؟'), findsOneWidget);

    await _backToShelf(tester);
    await _openFromShelf(tester, 'أجب وتتبّع!');
    expect(calls, hasLength(1));
    expect(calls.single, containsAll(['سؤال 0؟', 'سؤال 5؟']), reason: 'بنصّ السؤال لا الجواب');
    expect(find.text('سؤال 0-1؟'), findsOneWidget);
  });

  testWidgets('حروفُ الروضة لا تُطلب لها نسخةٌ جديدة', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var calls = 0;
    await tester.binding.setSurfaceSize(const Size(900, 700));
    await tester.pumpWidget(_host(_letters(), (base, exclude) async {
      calls += 1;
      return base;
    }));
    await _settle(tester);
    await _openFromShelf(tester, 'تتبّع واكتب!');
    await _backToShelf(tester);
    await _openFromShelf(tester, 'تتبّع واكتب!');
    expect(calls, 0);
  });

  testWidgets('الخادمُ سجّل الجولة: الإعادةُ تُعرض تدريباً بلا جواهر', (tester) async {
    SharedPreferences.setMockInitialValues({'study.seen.s1.L1.rewarded.tracing': true});
    await tester.binding.setSurfaceSize(const Size(900, 700));
    await tester.pumpWidget(_host(
      _quiz(''),
      (base, exclude) async => base,
      onWin: (_, {correct, total}) async => const RewardResult(
        xp: 0,
        gems: 0,
        alreadyRewarded: true,
        levelUp: false,
        newAchievements: [],
        snapshot: StudentGamification(),
      ),
    ));
    await _settle(tester);
    await _openFromShelf(tester, 'أجب وتتبّع!');
    expect(find.text('💎 0'), findsNothing, reason: 'لا جوهرةَ تُعرض في جولةٍ لا تمنحها');
  });
}
