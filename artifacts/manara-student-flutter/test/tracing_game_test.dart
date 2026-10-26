import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/models/study_games.dart';
import 'package:manara_student/src/services/tracing_glyphs.dart';
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

const _letters = [
  'ا', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ذ', 'ر', 'ز', 'س', 'ش', 'ص',
  'ض', 'ط', 'ظ', 'ع', 'غ', 'ف', 'ق', 'ك', 'ل', 'م', 'ن', 'ه', 'و', 'ي',
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

const _question = {
  'text': 'الشمس',
  'kind': 'answer',
  'lang': 'ar',
  'prompt': 'ما مصدر الضوء في النهار؟',
  'options': ['القمر', 'الشمس', 'النجوم'],
};

void main() {
  late List<String> spoken;
  late int builds;

  Future<void> boot(
    WidgetTester tester,
    StudyGame game, {
    VoidCallback? onWin,
    bool shapes = true,
  }) async {
    spoken = [];
    builds = 0;
    final plan = TracePlanner.plan(_baShape(), rtl: true);
    await tester.binding.setSurfaceSize(const Size(900, 640));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TracingGame(
            game: game,
            onWin: () async => onWin?.call(),
            onReplay: () {},
            shapeBuilder: (item) async {
              builds++;
              return shapes ? TracingShape(crop: const Rect.fromLTWH(0, 0, 90, 60), plan: plan) : null;
            },
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

  /// يكتب العنصرَ المفتوح كلَّه: جسمَ الحرف ثم نقطتَه، وينتظر الانتقال.
  Future<void> completeOpen(WidgetTester tester) async {
    final plan = stateOf(tester).plan!;
    await traceStroke(tester, plan.strokes[0]);
    await tester.tapAt(onScreen(tester, plan.strokes[1].points.single));
    await tester.pump();
    expect(find.text('رائع! ✨'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> openTile(WidgetTester tester, int index) async {
    await tester.tap(find.byKey(ValueKey('tracing-tile-$index')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
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

  group('الروضة: شبكةٌ ثم لوحة', () {
    testWidgets('تُفتح على شبكةٍ من ستّة بلا تحميلٍ ولا شريطٍ علوي', (tester) async {
      await boot(tester, _game(_letters, rewardAfter: 5));
      expect(find.byKey(const ValueKey('tracing-grid')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      for (var i = 0; i < 6; i++) {
        expect(find.byKey(ValueKey('tracing-tile-$i')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('tracing-tile-6')), findsNothing, reason: 'ستّةٌ في الصفحة');
      expect(find.text('صفحة 1 من 5'), findsOneWidget);
      expect(builds, 0, reason: 'لا شكلَ يُحضَّر قبل أن يُختار حرف');
      expect(spoken, isEmpty);
    });

    testWidgets('لمسُ حرفٍ ينطقه في الحال ويفتح لوحتَه', (tester) async {
      await boot(tester, _game(_letters));
      await openTile(tester, 1);
      expect(spoken, ['ar:اسم ب']);
      expect(find.byKey(const ValueKey('tracing-board')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.byKey(const ValueKey('tracing-speak')));
      await tester.pump();
      expect(spoken.last, 'ar:اسم ب');
    });

    testWidgets('المنجَزُ يعود إلى الشبكة، والمكافأةُ بعد خمسة مرّةً واحدة', (tester) async {
      var won = 0;
      await boot(tester, _game(_letters, rewardAfter: 5), onWin: () => won++);
      for (var i = 0; i < 5; i++) {
        await openTile(tester, i);
        await completeOpen(tester);
        expect(find.byKey(const ValueKey('tracing-grid')), findsOneWidget, reason: 'يعود إلى الشبكة');
      }
      expect(won, 1);
      expect(find.text('5 من 28'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(5));
      await openTile(tester, 5);
      await completeOpen(tester);
      expect(won, 1, reason: 'مرّةً واحدة');
      expect(find.text('أنهيت التتبّع كلّه! 🎉'), findsNothing);
    });

    testWidgets('تُقلَّب الصفحات، وتبدأ من صفحة حرف الدرس', (tester) async {
      await boot(tester, _game(_letters, start: 7));
      expect(find.byKey(const ValueKey('tracing-tile-7')), findsOneWidget, reason: 'الذال في الصفحة الثانية');
      expect(find.text('صفحة 2 من 5'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tracing-page-next')));
      // النبضُ لا يسكن، فلا `pumpAndSettle`: إطاراتٌ تكفي حركةَ الصفحة.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byKey(const ValueKey('tracing-tile-12')), findsOneWidget);
      expect(find.text('صفحة 3 من 5'), findsOneWidget);
    });

    testWidgets('العودةُ إلى الحروف من اللوحة', (tester) async {
      await boot(tester, _game(_letters));
      await openTile(tester, 2);
      await tester.tap(find.byKey(const ValueKey('tracing-back-to-grid')));
      await tester.pump();
      expect(find.byKey(const ValueKey('tracing-grid')), findsOneWidget);
    });

    testWidgets('حرفٌ تعذّر شكلُه: رسالةٌ لا دائرةٌ تدور', (tester) async {
      await boot(tester, _game(_letters), shapes: false);
      await openTile(tester, 0);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('تعذّر عرض هذا الشكل الآن — اختر غيره'), findsOneWidget);
    });

    testWidgets('آخرُ حرفٍ في مجموعةٍ قصيرة يُنهيها', (tester) async {
      var won = 0;
      await boot(tester, _game(['ب', 'ت']), onWin: () => won++);
      await openTile(tester, 0);
      await completeOpen(tester);
      await openTile(tester, 1);
      await completeOpen(tester);
      expect(won, 1);
      expect(find.text('أنهيت التتبّع كلّه! 🎉'), findsOneWidget);
    });
  });

  group('اللوحة', () {
    testWidgets('البدءُ من نهاية الخطّ لا يُحتسب: الاتجاهُ من نقطة البداية وحدها',
        (tester) async {
      await boot(tester, _game(['ب']));
      await openTile(tester, 0);
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
      await boot(tester, _game(['ب']));
      await openTile(tester, 0);
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
    });

    testWidgets('النقطةُ لا تُلمس قبل جسم الحرف', (tester) async {
      await boot(tester, _game(['ب']));
      await openTile(tester, 0);
      final dot = stateOf(tester).plan!.strokes[1];
      await tester.tapAt(onScreen(tester, dot.points.single));
      await tester.pump();
      expect(find.text('محاولات خاطئة: 1'), findsOneWidget);
    });
  });

  group('أجب وتتبّع', () {
    testWidgets('لا شبكة: السؤالُ يُقرأ، والخطأُ تنبيه، والصوابُ يُنطق ثم يُتتبّع', (tester) async {
      var won = 0;
      await boot(tester, _game(const [], entries: [_question]), onWin: () => won++);
      expect(find.byKey(const ValueKey('tracing-grid')), findsNothing);
      expect(find.text('ما مصدر الضوء في النهار؟'), findsOneWidget);
      expect(spoken.single, 'ar:ما مصدر الضوء في النهار؟');

      await tester.tap(find.byKey(const ValueKey('tracing-option-القمر')));
      await tester.pump();
      expect(find.text('محاولات خاطئة: 1'), findsOneWidget);
      expect(find.text('ليست هذه، حاول مرة أخرى 💪'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tracing-option-الشمس')));
      await tester.pump();
      expect(find.text('إجابة صحيحة! 🎉 الآن اكتبها'), findsOneWidget);
      expect(spoken.last, 'ar:الشمس');
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byKey(const ValueKey('tracing-board')), findsOneWidget);

      await completeOpen(tester);
      expect(won, 1);
    });

    testWidgets('شكلُ الإجابة تعذّر: الاختيارُ الصحيح يكفي، ولا تحميلَ معلّق', (tester) async {
      var won = 0;
      await boot(tester, _game(const [], entries: [_question]), onWin: () => won++, shapes: false);
      await tester.tap(find.byKey(const ValueKey('tracing-option-الشمس')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump();
      expect(won, 1);
      expect(find.text('أنهيت التتبّع كلّه! 🎉'), findsOneWidget);
    });
  });

  group('الأشكالُ المحسوبةُ مسبقاً', () {
    test('حروفُ الروضة وأرقامُها الأربعةُ والسبعون كلُّها محسوبة', () {
      expect(kindergartenTracingItems, hasLength(74));
      for (final item in kindergartenTracingItems) {
        final shape = precomputedTracingShape(item);
        expect(shape, isNotNull, reason: item.text);
        expect(shape!.plan.strokes, isNotEmpty, reason: item.text);
      }
    });

    test('تُحمَّل فوراً بلا رسمٍ ولا قراءةٍ من معالج الرسوم', () async {
      const item = TracingItem(text: 'ب', kind: 'letter', lang: 'ar');
      final shape = await loadTracingShape(item);
      expect(identical(shape, precomputedTracingShape(item)), isTrue);
    });

    test('الألفُ من أعلاه، والباءُ من يمينها ثم نقطتُها', () {
      final alif = precomputedTracingShape(const TracingItem(text: 'ا', kind: 'letter', lang: 'ar'))!;
      final points = alif.plan.strokes.first.points;
      expect(points.first.y, lessThan(points.last.y));
      final ba = precomputedTracingShape(const TracingItem(text: 'ب', kind: 'letter', lang: 'ar'))!;
      expect(ba.plan.strokes.first.points.first.x, greaterThan(0.8));
      expect(ba.plan.strokes.last.isDot, isTrue);
    });

    test('ما ليس من الروضة لا جدولَ له', () {
      expect(precomputedTracingShape(const TracingItem(text: 'الشمس', kind: 'answer', lang: 'ar')), isNull);
    });
  });
}
