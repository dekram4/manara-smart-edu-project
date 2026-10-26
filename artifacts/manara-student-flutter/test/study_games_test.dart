import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/models/student_gamification.dart';
import 'package:manara_student/src/models/study_games.dart';
import 'package:manara_student/src/widgets/study_games.dart';

/// ألعابُ بطاقة المذاكرة: قراءةُ الصيغة، واللعبُ بالضغط (بديلُ السحب)،
/// والفوزُ يطلب المكافأة مرّةً ويُظهر الاحتفال.
Map<String, Object?> _packJson() => {
      'lessonId': 'L1',
      'games': [
        {
          'id': 'drag_drop',
          'game_type': 'drag_drop',
          'title': 'صنّف الكائنات',
          'instructions': 'اسحب كل كائن إلى مجموعته',
          'items': {
            'drag_items': ['القط', 'النخلة'],
            'drop_targets': ['حيوان', 'نبات'],
            'correct_pairs': [
              {'item': 'القط', 'target': 'حيوان'},
              {'item': 'النخلة', 'target': 'نبات'},
            ],
          },
          'gems_reward': 8,
          'points_reward': 30,
        },
        {
          'id': 'matching',
          'game_type': 'matching',
          'title': 'صِل',
          'instructions': 'صل كل كلمة بمعناها',
          'items': {
            'drag_items': ['الجذر', 'الورقة'],
            'drop_targets': ['يمتص الماء', 'تصنع الغذاء'],
            'correct_pairs': [
              {'item': 'الجذر', 'target': 'يمتص الماء'},
              {'item': 'الورقة', 'target': 'تصنع الغذاء'},
            ],
          },
          'gems_reward': 6,
          'points_reward': 20,
        },
        {
          'id': 'endless_quiz',
          'game_type': 'endless_quiz',
          'title': 'سباق',
          'instructions': 'أجب بسرعة',
          'items': {
            'drag_items': [],
            'drop_targets': [],
            'correct_pairs': [],
            'questions': [
              for (var i = 0; i < 3; i++)
                {
                  'kind': 'mcq',
                  'question': 'سؤال $i',
                  'options': ['صح $i', 'خطأ $i', 'ربما $i'],
                  'answer': 'صح $i',
                },
              for (var i = 3; i < 5; i++)
                {
                  'kind': 'true_false',
                  'question': 'عبارة $i',
                  'options': ['صح', 'خطأ'],
                  'answer': 'صح',
                },
            ],
          },
          'gems_reward': 5,
          'points_reward': 15,
        },
        // نوعٌ مجهول لا يظهر.
        {'game_type': 'unknown', 'items': {}},
      ],
    };

RewardResult _reward(int gems, int xp) => RewardResult(
      xp: xp,
      gems: gems,
      alreadyRewarded: false,
      levelUp: false,
      newAchievements: const [],
      snapshot: StudentGamification.fromMap(const {}),
    );

Future<List<StudyGame>> _pump(WidgetTester tester, StudyGameWin onWin) async {
  final pack = StudyGamesPack.fromMap(_packJson())!;
  await tester.pumpWidget(
    MaterialApp(
      // الرموزُ القافزة تتكرّر بلا نهاية؛ وتسكن لمن طلب تقليل الحركة.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: StudyGamesTab(load: () async => pack, onWin: onWin),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return pack.games;
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.tap(find.text(text).first);
  await tester.pump(const Duration(milliseconds: 500));
}

/// الاحتفالُ يتحرّك ثانيةً أو أكثر — ورقٌ متناثر وعدّادٌ يعدّ — فيُنتظر بوقتٍ
/// محدّد لا بـ`pumpAndSettle`.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  test('الصيغة: ثلاثُ ألعاب صالحة، والمجهول يسقط', () {
    final pack = StudyGamesPack.fromMap(_packJson())!;
    expect(pack.games.map((g) => g.type), [
      StudyGameType.dragDrop,
      StudyGameType.matching,
      StudyGameType.endlessQuiz,
    ]);
    expect(pack.games.first.targetOf('القط'), 'حيوان');
    expect(pack.games.first.gemsReward, 8);
    expect(pack.games.last.questions, hasLength(5));
    expect(pack.games.last.questions.last.kind, StudyQuestionKind.trueFalse);
    expect(StudyGamesPack.fromMap({'games': []}), isNull);
  });

  testWidgets('السحب والإسقاط بالضغط: خطأٌ لا يُحسب، والصحيحُ يُكمل ويطلب المكافأة',
      (tester) async {
    final won = <String>[];
    await _pump(tester, (game) async {
      won.add(game.id);
      return _reward(8, 30);
    });
    await _tap(tester, 'صنّف الكائنات');
    await tester.pumpAndSettle();

    // القطُّ إلى «نبات»: خطأ.
    await _tap(tester, 'القط');
    await _tap(tester, 'نبات');
    expect(won, isEmpty);
    expect(find.textContaining('1'), findsWidgets);

    await _tap(tester, 'القط');
    await _tap(tester, 'حيوان');
    await _tap(tester, 'النخلة');
    await _tap(tester, 'نبات');
    await _settle(tester);

    expect(won, ['drag_drop']);
    // الاحتفال يعرض ما صرفه الخادم.
    expect(find.text('🏆'), findsOneWidget);
    expect(find.textContaining('8'), findsWidgets);
    expect(find.textContaining('30'), findsWidgets);
  });

  testWidgets('المطابقة بالضغط تُكمل الأزواج وتطلب المكافأة', (tester) async {
    final won = <String>[];
    await _pump(tester, (game) async {
      won.add(game.id);
      return _reward(6, 20);
    });
    await _tap(tester, 'صِل');
    await tester.pumpAndSettle();
    await _tap(tester, 'الجذر');
    await _tap(tester, 'يمتص الماء');
    await _tap(tester, 'الورقة');
    await _tap(tester, 'تصنع الغذاء');
    await _settle(tester);
    expect(won, ['matching']);
  });

  testWidgets('السباق: بلوغُ الهدف فوزٌ مرّةً واحدة', (tester) async {
    final won = <String>[];
    final games = await _pump(tester, (game) async {
      won.add(game.id);
      return _reward(5, 15);
    });
    await _tap(tester, 'سباق');
    await tester.pumpAndSettle();
    final quiz = games.last;
    for (var round = 0; round < 5; round++) {
      final shown = quiz.questions.firstWhere(
        (q) => find.text(q.question).evaluate().isNotEmpty,
      );
      await _tap(tester, shown.answer);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await _settle(tester);
    expect(won, ['endless_quiz']);
  });

  testWidgets('السحب الحقيقي: ضغطةٌ مطوّلة ثم إسقاطٌ في السلّة', (tester) async {
    final won = <String>[];
    await _pump(tester, (game) async {
      won.add(game.id);
      return _reward(8, 30);
    });
    await _tap(tester, 'صنّف الكائنات');
    await tester.pumpAndSettle();

    Future<void> drag(String item, String bin) async {
      final from = tester.getCenter(find.text(item).first);
      final to = tester.getCenter(find.text(bin).first);
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.moveTo(Offset.lerp(from, to, 0.5)!);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(to);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 500));
    }

    await drag('القط', 'حيوان');
    await drag('النخلة', 'نبات');
    await _settle(tester);
    expect(won, ['drag_drop']);
  });
}
