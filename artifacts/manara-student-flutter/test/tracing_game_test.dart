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

StudyGame _game(
  List<String> texts, {
  int rewardAfter = 0,
  int start = 0,
  List<Map<String, Object>>? entries,
}) =>
    StudyGame.fromMap({
      'id': 'tracing',
      'game_type': 'tracing',
      'title': 'تتبّع واكتب!',
      'instructions': 'مرّر إصبعك',
      'items': {
        'drag_items': [],
        'drop_targets': [],
        'correct_pairs': [],
        'tracing': entries ??
            [
              for (final text in texts)
                {'text': text, 'kind': 'letter', 'lang': 'ar', 'speech': 'اسم $text'},
            ],
        'reward_after': rewardAfter,
        'start': start,
      },
      'gems_reward': 6,
      'points_reward': 30,
    })!;

void main() {
  late ui.Image image;
  late List<String> spoken;

  Future<void> boot(WidgetTester tester, StudyGame game, {required VoidCallback onWin}) async {
    spoken = [];
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
            speak: (text, lang) async => spoken.add('$lang:$text'),
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

  /// يكتب العنصرَ الحالي كلَّه: جسمَ الحرف ثم نقطتَه، وينتظر الانتقال.
  Future<void> completeItem(WidgetTester tester) async {
    final plan = stateOf(tester).plan!;
    await traceStroke(tester, plan.strokes[0]);
    await tester.tapAt(onScreen(tester, plan.strokes[1].points.single));
    await tester.pump();
    expect(find.text('رائع! ✨'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('تُكتب الجرّةُ من بدايتها بالترتيب، ثم النقطة، ثم العنصرُ التالي، ثم المكافأة',
      (tester) async {
    var won = 0;
    await boot(tester, _game(['ب', 'ت']), onWin: () => won++);
    expect(stateOf(tester).plan!.strokes, hasLength(2));
    expect(find.text('0 من 2'), findsOneWidget);

    await completeItem(tester);
    expect(find.text('1 من 2'), findsOneWidget);
    expect(won, 0);
    await completeItem(tester);
    expect(won, 1);
    expect(find.text('أنهيت التتبّع كلّه! 🎉'), findsOneWidget);
  });

  testWidgets('كلُّ حرفٍ يُنطق باسمه حين يظهر، وبزرّ السمّاعة', (tester) async {
    await boot(tester, _game(['ب', 'ت']), onWin: () {});
    expect(spoken, ['ar:اسم ب']);
    await tester.tap(find.byKey(const ValueKey('tracing-speak')));
    await tester.pump();
    expect(spoken.last, 'ar:اسم ب');
    await completeItem(tester);
    expect(spoken.last, 'ar:اسم ت');
  });

  testWidgets('المجموعةُ كاملة: تبدأ من حرف الدرس، ويُقفز إلى أيّها، والمكافأةُ بعد خمسة لا بعد آخرها',
      (tester) async {
    const letters = [
      'ا', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ذ', 'ر', 'ز', 'س', 'ش', 'ص',
      'ض', 'ط', 'ظ', 'ع', 'غ', 'ف', 'ق', 'ك', 'ل', 'م', 'ن', 'ه', 'و', 'ي',
    ];
    var won = 0;
    await boot(tester, _game(letters, rewardAfter: 5, start: 1), onWin: () => won++);
    expect(find.text('0 من 28'), findsOneWidget);
    expect(spoken.single, 'ar:اسم ب', reason: 'يفتح على حرف الدرس');
    expect(find.byKey(const ValueKey('tracing-strip')), findsOneWidget);

    // قفزٌ إلى الألف من الشريط.
    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('tracing-strip')),
      matching: find.text('ا'),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(spoken.last, 'ar:اسم ا');

    for (var i = 0; i < 4; i++) {
      await completeItem(tester);
    }
    expect(won, 0);
    await completeItem(tester);
    expect(won, 1, reason: 'بعد خمسة');
    expect(find.text('5 من 28'), findsOneWidget);
    expect(find.text('أنهيت التتبّع كلّه! 🎉'), findsNothing, reason: 'يتابع بعد المكافأة');
    await completeItem(tester);
    expect(won, 1, reason: 'مرّةً واحدة');
  });

  testWidgets('أجب وتتبّع: الخطأُ تنبيه، والصوابُ يُنطق ويفتح التتبّع', (tester) async {
    var won = 0;
    await boot(
      tester,
      _game(const [], entries: [
        {
          'text': 'الشمس',
          'kind': 'answer',
          'lang': 'ar',
          'prompt': 'ما مصدر الضوء في النهار؟',
          'options': ['القمر', 'الشمس', 'النجوم'],
        },
      ]),
      onWin: () => won++,
    );
    expect(find.text('ما مصدر الضوء في النهار؟'), findsOneWidget);
    expect(spoken.single, 'ar:ما مصدر الضوء في النهار؟', reason: 'السؤالُ يُقرأ للطفل');
    expect(find.byKey(const ValueKey('tracing-board')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tracing-option-القمر')));
    await tester.pump();
    expect(find.text('محاولات خاطئة: 1'), findsOneWidget);
    expect(find.text('ليست هذه، حاول مرة أخرى 💪'), findsOneWidget);
    expect(find.byKey(const ValueKey('tracing-board')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tracing-option-الشمس')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(spoken.last, 'ar:الشمس');
    expect(find.byKey(const ValueKey('tracing-board')), findsOneWidget);

    await completeItem(tester);
    expect(won, 1);
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
