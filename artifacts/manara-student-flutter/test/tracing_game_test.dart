import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/models/study_games.dart';
import 'package:manara_student/src/services/tracing_path.dart';
import 'package:manara_student/src/widgets/tracing_game.dart';

/// خطٌّ أفقيٌّ ونقطةٌ تحته — كالباء — بشبكةٍ صناعية لا بخطٍّ حقيقي.
List<List<bool>> _baShape() => [
      for (var y = 0; y < 60; y++)
        [
          for (var x = 0; x < 90; x++)
            (y >= 10 && y < 18 && x >= 5 && x < 85) ||
                (y >= 38 && y < 46 && x >= 40 && x < 48),
        ],
    ];

StudyGame _game(List<String> texts) => StudyGame.fromMap({
      'id': 'tracing',
      'game_type': 'tracing',
      'title': 'تتبّع واكتب!',
      'instructions': 'مرّر إصبعك',
      'items': {
        'drag_items': [],
        'drop_targets': [],
        'correct_pairs': [],
        'tracing': [
          for (final text in texts) {'text': text, 'kind': 'letter', 'lang': 'ar'},
        ],
      },
      'gems_reward': 6,
      'points_reward': 30,
    })!;

void main() {
  late ui.Image image;

  Future<void> boot(WidgetTester tester, StudyGame game, {required VoidCallback onWin}) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 90, 60), Paint());
      image = await recorder.endRecording().toImage(90, 60);
    });
    final plan = TracePlanner.plan(_baShape(), rtl: true);
    await tester.binding.setSurfaceSize(const Size(800, 600));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TracingGame(
            game: game,
            onWin: () async => onWin(),
            onReplay: () {},
            shapeBuilder: (item, style) async => TracingShape(
              image: image,
              crop: const Rect.fromLTWH(0, 0, 90, 60),
              plan: plan,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  TracingGameState stateOf(WidgetTester tester) =>
      tester.state<TracingGameState>(find.byType(TracingGame));

  Offset onScreen(WidgetTester tester, TracePoint point) {
    final board = find.byKey(const ValueKey('tracing-board'));
    return tester.getTopLeft(board) + stateOf(tester).toCanvas(point);
  }

  Future<void> traceStroke(WidgetTester tester, TraceStroke stroke) async {
    final gesture = await tester.startGesture(onScreen(tester, stroke.points.first));
    for (final point in stroke.points.skip(1)) {
      await gesture.moveTo(onScreen(tester, point));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();
  }

  test('النموذجُ يقرأ عناصرَ التتبّع، والأرقامُ من اليسار', () {
    final game = StudyGame.fromMap({
      'id': 'tracing',
      'game_type': 'tracing',
      'items': {
        'tracing': [
          {'text': 'ب', 'kind': 'letter', 'lang': 'ar'},
          {'text': '٥', 'kind': 'number', 'lang': 'ar'},
          {'text': '', 'kind': 'word', 'lang': 'ar'},
        ],
      },
    })!;
    expect(game.type, StudyGameType.tracing);
    expect(game.tracing.map((item) => item.text), ['ب', '٥']);
    expect(game.tracing.first.rtl, isTrue);
    expect(game.tracing.last.rtl, isFalse);
  });

  test('لعبةُ تتبّعٍ بلا عناصر لا تظهر', () {
    expect(
      StudyGame.fromMap({'id': 'tracing', 'game_type': 'tracing', 'items': {'tracing': []}}),
      isNull,
    );
  });

  testWidgets('تُكتب الجرّةُ من بدايتها بالترتيب، ثم النقطة، ثم العنصرُ التالي، ثم المكافأة',
      (tester) async {
    var won = 0;
    await boot(tester, _game(['ب', 'ت']), onWin: () => won++);
    final plan = stateOf(tester).plan!;
    expect(plan.strokes, hasLength(2));
    expect(find.text('1 من 2'), findsOneWidget);

    for (var item = 0; item < 2; item++) {
      await traceStroke(tester, plan.strokes[0]);
      // الجرّةُ اكتملت؛ والنقطةُ لمسة.
      await tester.tapAt(onScreen(tester, plan.strokes[1].points.single));
      await tester.pump();
      expect(find.text('رائع! ✨'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(won, 1);
    expect(find.text('أنهيت التتبّع كلّه! 🎉'), findsOneWidget);
  });

  testWidgets('البدءُ من نهاية الخطّ لا يُحتسب: الاتجاهُ من نقطة البداية وحدها',
      (tester) async {
    await boot(tester, _game(['ب']), onWin: () {});
    final stroke = stateOf(tester).plan!.strokes.first;
    final gesture = await tester.startGesture(onScreen(tester, stroke.points.last));
    for (final point in stroke.points.reversed.skip(1)) {
      await gesture.moveTo(onScreen(tester, point));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();
    expect(find.text('محاولات خاطئة: 1'), findsOneWidget);
    expect(find.text('رائع! ✨'), findsNothing);
  });

  testWidgets('الابتعادُ عن الخطّ يُعيد الجرّةَ من أوّلها', (tester) async {
    await boot(tester, _game(['ب']), onWin: () {});
    final stroke = stateOf(tester).plan!.strokes.first;
    final gesture = await tester.startGesture(onScreen(tester, stroke.points.first));
    await gesture.moveTo(onScreen(tester, stroke.points[1]));
    await tester.pump();
    await gesture.moveTo(onScreen(tester, stroke.points[1]) + const Offset(0, 220));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(find.text('محاولات خاطئة: 1'), findsOneWidget);
    expect(find.text('ابقَ على الخطّ وحاول مرة أخرى 💪'), findsOneWidget);

    // ثم يكتبها صحيحةً من جديد.
    await traceStroke(tester, stroke);
    expect(find.text('المس النقطة الخضراء'), findsNothing);
  });

  testWidgets('النقطةُ لا تُلمس قبل جسم الحرف', (tester) async {
    await boot(tester, _game(['ب']), onWin: () {});
    final dot = stateOf(tester).plan!.strokes[1];
    await tester.tapAt(onScreen(tester, dot.points.single));
    await tester.pump();
    expect(find.text('محاولات خاطئة: 1'), findsOneWidget);
  });
}
