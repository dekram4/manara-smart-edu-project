import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/l10n/student_strings.dart';

import 'package:manara_student/src/models/student_gamification.dart';
import 'package:manara_student/src/models/study_games.dart';
import 'package:manara_student/src/widgets/quiz_games.dart';
import 'package:manara_student/src/widgets/study_games.dart';

/// ألعابُ بطاقة المذاكرة: الألعابُ الأربع وحدها، بأسئلةٍ من نصّ الدرس ومن
/// أزواج التصنيف والمطابقة، وشريطٌ ثابتٌ للتنقّل بينها، والفوزُ مرّةً واحدة.
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

Future<StudyGamesPack> _pump(WidgetTester tester, StudyGameWin onWin) async {
  for (final channel in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
  }
  tester.view.physicalSize = const Size(1024, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
          body: SingleChildScrollView(child: StudyGamesTab(load: () async => pack, onWin: onWin)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return pack;
}

Future<void> _wait(WidgetTester tester, [int steps = 30]) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const _styles = ['balloons', 'fishing', 'train', 'slingshot', 'basket'];

/// مقدّمةُ اللعبة ظاهرة، ثم «هيا نلعب!».
Future<void> _start(WidgetTester tester) async {
  expect(find.byKey(const ValueKey('game-intro-start')), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('game-intro-start')));
  await _wait(tester, 10);
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
    expect(pack.games.last.questions, hasLength(5));
    expect(pack.games.last.questions.last.kind, StudyQuestionKind.trueFalse);
    expect(StudyGamesPack.fromMap({'games': []}), isNull);
  });

  test('أسئلةُ الألعاب: أسئلةُ الدرس ومعها أسئلةٌ من أزواج التصنيف والمطابقة', () {
    final pack = StudyGamesPack.fromMap(_packJson())!;
    final arcade = arcadeGameOf(pack)!;
    expect(arcade.id, 'endless_quiz', reason: 'المكافأةُ مكافأةُ أسئلة الدرس');
    // ‏خمسةٌ من السباق، واثنان من التصنيف، واثنان من المطابقة، وسؤالا جمعٍ للسلّة.
    expect(arcade.questions, hasLength(5 + 2 + 2 + 2));
    final collect = arcade.questions.where((q) => q.kind == StudyQuestionKind.collect).toList();
    expect(collect, hasLength(2));
    expect(collect.first.question, trf('study.games.ask.collect', {'item': 'حيوان'}));
    expect(collect.first.answers, ['القط']);
    expect(collect.first.isCorrect('النخلة'), isFalse);
    final cat = arcade.questions.firstWhere((q) => q.question == trf('study.games.ask.sort', {'item': 'القط'}));
    expect(cat.answer, 'حيوان');
    expect(cat.options, containsAll(['حيوان', 'نبات']));
    final root = arcade.questions.firstWhere((q) => q.question == trf('study.games.ask.match', {'item': 'الجذر'}));
    expect(root.answer, 'يمتص الماء');
    // ‏درسٌ بلا أسئلة سباق: تُلعب أسئلةُ الأزواج وحدها.
    final json = _packJson();
    json['games'] = [
      for (final game in json['games']! as List)
        if ((game as Map)['game_type'] != 'endless_quiz') game,
    ];
    expect(arcadeGameOf(StudyGamesPack.fromMap(json)!)!.questions, hasLength(6));
  });

  testWidgets('الرفُّ أربعةُ أغلفةٍ وحدها: لا سحبَ ولا مطابقةَ ولا سباق', (tester) async {
    await _pump(tester, (_) async => null);
    for (final style in _styles) {
      expect(find.byKey(ValueKey('arcade-$style')), findsOneWidget);
    }
    expect(find.text('صنّف الكائنات'), findsNothing);
    expect(find.text('صِل'), findsNothing);
    expect(find.text('سباق'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final style in _styles) {
    testWidgets('لعبةُ $style: إصابةُ الجولة كلِّها فوزٌ مرّةً واحدة', (tester) async {
      final won = <String>[];
      final pack = await _pump(tester, (game) async {
        won.add(game.id);
        return _reward(5, 15);
      });
      await tester.ensureVisible(find.byKey(ValueKey('arcade-$style')));
      await tester.tap(find.byKey(ValueKey('arcade-$style')));
      await _wait(tester, 10);
      await _start(tester);
      final questions = arcadeGameOf(pack)!.questions;
      // ‏تسعةُ أسئلة: الجولةُ ثمانية.
      for (var round = 0; round < 8; round++) {
        final shown = questions.firstWhere((q) => find.text(q.question).evaluate().isNotEmpty);
        // ‏السلّة تُملأ بالصحيحة كلِّها، وغيرُها بلمسة الصحيحة.
        for (final answer in style == 'basket' ? shown.answers : [shown.answer]) {
          await tester.tap(find.text(answer).last);
          await _wait(tester, 3);
        }
        await _wait(tester);
      }
      await _wait(tester, 12);
      expect(won, ['endless_quiz']);
      expect(find.text(trf('study.games.arcade.result', {'n': 8, 'total': 8})), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('الشريطُ العلويّ الثابت: لمسةٌ تنقل إلى القطار بلا رجوع', (tester) async {
    await _pump(tester, (_) async => null);
    await tester.ensureVisible(find.byKey(const ValueKey('arcade-balloons')));
    await tester.tap(find.byKey(const ValueKey('arcade-balloons')));
    await _wait(tester, 10);
    // ‏مقدّمةٌ قبل اللعبة، لا دخولٌ مفاجئ.
    expect(find.byKey(const ValueKey('balloon-0')), findsNothing);
    await _start(tester);
    expect(find.byKey(const ValueKey('balloon-0')), findsOneWidget);
    for (final style in _styles) {
      expect(find.byKey(ValueKey('switch-$style')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('switch-train')));
    await _wait(tester, 10);
    expect(find.byKey(const ValueKey('balloon-0')), findsNothing);
    expect(find.byKey(const ValueKey('wagon-0')), findsNothing, reason: 'مقدّمةُ القطار أوّلاً');
    await _start(tester);
    expect(find.byKey(const ValueKey('wagon-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('switch-slingshot')));
    await _wait(tester, 10);
    await _start(tester);
    expect(find.byKey(const ValueKey('target-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('لا تبدأ اللعبةُ وحدها: تنتظر «هيا نلعب!»', (tester) async {
    await _pump(tester, (_) async => null);
    await tester.ensureVisible(find.byKey(const ValueKey('arcade-fishing')));
    await tester.tap(find.byKey(const ValueKey('arcade-fishing')));
    await _wait(tester, 10);
    // ‏لمسةٌ على الخلفية لا تبدأها، ولا مرورُ الوقت.
    await tester.tapAt(const Offset(60, 400));
    await _wait(tester, 100);
    expect(find.byKey(const ValueKey('fish-0')), findsNothing);
    expect(find.byKey(const ValueKey('game-intro-start')), findsOneWidget);
    await _start(tester);
    expect(find.byKey(const ValueKey('fish-0')), findsOneWidget);
  });

  testWidgets('أسئلةُ الدرس تتوزّع على الألعاب: الانتقالُ يبدأ بما لم يُسأل', (tester) async {
    final pack = await _pump(tester, (_) async => null);
    await tester.ensureVisible(find.byKey(const ValueKey('arcade-balloons')));
    await tester.tap(find.byKey(const ValueKey('arcade-balloons')));
    await _wait(tester, 10);
    await _start(tester);
    final questions = arcadeGameOf(pack)!.questions;
    final asked = <String>{};
    for (var round = 0; round < 3; round++) {
      final shown = questions.firstWhere((q) => find.text(q.question).evaluate().isNotEmpty);
      asked.add(shown.question);
      await tester.tap(find.text(shown.answer).last);
      await _wait(tester);
    }
    await tester.tap(find.byKey(const ValueKey('switch-train')));
    await _wait(tester, 10);
    await _start(tester);
    final next = questions.firstWhere((q) => find.text(q.question).evaluate().isNotEmpty);
    expect(asked, isNot(contains(next.question)));
  });

  test('لكل لعبةٍ عبارةُ مقدّمتها في الحزمة', () {
    for (final style in QuizGameStyle.values) {
      expect(File('assets/${QuizGameArt.intro(style)}').existsSync(), isTrue, reason: style.name);
    }
  });
}
