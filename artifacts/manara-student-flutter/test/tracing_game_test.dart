import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/models/student_gamification.dart';
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
  int start = 0,
  List<Map<String, Object>>? entries,
}) =>
    StudyGame.fromMap({
      'id': 'tracing',
      'game_type': 'tracing',
      'title': 'تتبّع واكتب!',
      'instructions': 'المس حرفاً',
      'items': {
        'tracing': entries ??
            [
              for (final text in texts)
                {'text': text, 'kind': 'letter', 'lang': 'ar', 'speech': 'اسم $text'},
            ],
        'start': start,
      },
      'gems_reward': 1,
      'points_reward': 1,
    })!;

RewardResult _reward(int gems) => RewardResult(
      xp: gems,
      gems: gems,
      alreadyRewarded: gems == 0,
      levelUp: false,
      newAchievements: const [],
      snapshot: const StudentGamification(),
    );

void main() {
  late List<String> spoken;
  late List<String> clips;
  late List<String> traced;
  late int builds;

  /// الخادمُ مزيّفاً: جوهرةٌ لأوّل كتابةٍ لكل حرف، وصفرٌ لما بعدها.
  late Set<String> rewardedLetters;

  Future<void> boot(WidgetTester tester, StudyGame game, {bool shapes = true, TracePlan? plan}) async {
    spoken = [];
    clips = [];
    traced = [];
    builds = 0;
    rewardedLetters = {};
    final shapePlan = plan ?? TracePlanner.plan(_baShape(), rtl: true);
    await tester.binding.setSurfaceSize(const Size(900, 640));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TracingGame(
            game: game,
            onTraced: (item) async {
              traced.add(item.text);
              return _reward(rewardedLetters.add(item.text) ? 1 : 0);
            },
            shapeBuilder: (item) async {
              builds++;
              return shapes ? TracingShape(crop: const Rect.fromLTWH(0, 0, 90, 60), plan: shapePlan) : null;
            },
            speak: (text, lang) async => spoken.add('$lang:$text'),
            playClip: (asset) async => clips.add(asset),
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

  Future<void> traceStroke(WidgetTester tester, TraceStroke stroke, {Offset shift = Offset.zero}) async {
    final gesture = await tester.startGesture(onScreen(tester, stroke.points.first) + shift);
    for (final point in stroke.points.skip(1)) {
      await gesture.moveTo(onScreen(tester, point) + shift);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();
  }

  final cheer = find.byKey(const ValueKey('tracing-cheer'));
  final gem = find.byKey(const ValueKey('tracing-gem'));

  /// يكتب العنصرَ المفتوح كلَّه: جسمَ الحرف ثم نقطتَه.
  Future<void> writeOpen(WidgetTester tester) async {
    final plan = stateOf(tester).plan!;
    await traceStroke(tester, plan.strokes[0]);
    await tester.tapAt(onScreen(tester, plan.strokes[1].points.single));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// ينتظر العودةَ إلى الشبكة بعد التشجيع.
  Future<void> backToGrid(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1900));
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
          {'text': 'ب', 'kind': 'letter', 'lang': 'ar', 'speech': 'باء'},
          {'text': '٥', 'kind': 'number', 'lang': 'ar', 'speech': 'خمسة'},
          {'text': '', 'kind': 'letter', 'lang': 'ar'},
        ],
      },
    })!;
    expect(game.type, StudyGameType.tracing);
    expect(game.tracing.map((item) => item.text), ['ب', '٥']);
    expect(game.tracing.first.rtl, isTrue);
    expect(game.tracing.last.rtl, isFalse);
  });

  group('الأصواتُ المسجّلة', () {
    test('لكل حرفٍ عربيٍّ تسجيلُه، ولا شيءَ لغيره', () {
      expect(arabicLetterClips, hasLength(28));
      for (final letter in _letters) {
        expect(arabicLetterClips[letter], startsWith('audio/ar/letter_'), reason: letter);
      }
      expect(arabicLetterClips.values.toSet(), hasLength(28), reason: 'لا ملفَّ لحرفين');
      expect(recordedClipFor(const TracingItem(text: 'ب', kind: 'letter', lang: 'ar')), 'audio/ar/letter_ba.mp3');
      expect(recordedClipFor(const TracingItem(text: 'Bb', kind: 'letter', lang: 'en')), isNull);
      expect(recordedClipFor(const TracingItem(text: '٥', kind: 'number', lang: 'ar')), isNull);
    });

    testWidgets('لمسُ حرفٍ عربيٍّ يشغّل تسجيلَه — لا محرّكَ النطق', (tester) async {
      await boot(tester, _game(_letters));
      await openTile(tester, 1);
      expect(clips, ['audio/ar/letter_ba.mp3']);
      expect(spoken, isEmpty);
      await tester.tap(find.byKey(const ValueKey('tracing-speak')));
      await tester.pump();
      expect(clips, ['audio/ar/letter_ba.mp3', 'audio/ar/letter_ba.mp3']);
    });

    testWidgets('الإنجليزيةُ والأعدادُ بمحرّك النطق', (tester) async {
      await boot(
        tester,
        _game(const [], entries: [
          {'text': 'Bb', 'kind': 'letter', 'lang': 'en', 'speech': 'B'},
        ]),
      );
      await openTile(tester, 0);
      expect(spoken, ['en:B']);
      expect(clips, isEmpty);
    });
  });

  group('الروضة: شبكةٌ ثم لوحة', () {
    testWidgets('تُفتح على شبكةٍ من ستّة بلا تحميلٍ ولا شريطٍ علوي', (tester) async {
      await boot(tester, _game(_letters));
      expect(find.byKey(const ValueKey('tracing-grid')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      for (var i = 0; i < 6; i++) {
        expect(find.byKey(ValueKey('tracing-tile-$i')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('tracing-tile-6')), findsNothing, reason: 'ستّةٌ في الصفحة');
      expect(find.text('صفحة 1 من 5'), findsOneWidget);
      expect(builds, 0, reason: 'لا شكلَ يُحضَّر قبل أن يُختار حرف');
    });

    testWidgets('كلُّ حرفٍ يُكتب: تشجيعٌ وجوهرةٌ في الحال، بلا حدٍّ ولا نافذة احتفال', (tester) async {
      await boot(tester, _game(_letters));
      for (var i = 0; i < 7; i++) {
        await openTile(tester, i % 6);
        if (i == 6) {
          // الحرفُ الأوّل مرّةً ثانية: يُلعب بحرّية، ولا جوهرةَ جديدة.
          await writeOpen(tester);
          expect(cheer, findsOneWidget);
          expect(gem, findsNothing, reason: 'كُتب في هذا الدرس من قبل');
          await backToGrid(tester);
          break;
        }
        await writeOpen(tester);
        expect(cheer, findsOneWidget, reason: 'عبارةُ تشجيعٍ فور الإكمال');
        expect(gem, findsOneWidget, reason: '+1 💎 لأوّل كتابة');
        await backToGrid(tester);
        expect(find.byKey(const ValueKey('tracing-grid')), findsOneWidget, reason: 'يعود إلى الشبكة');
      }
      expect(traced, ['ا', 'ب', 'ت', 'ث', 'ج', 'ح', 'ا'], reason: 'كلُّ حرفٍ يُرسل للخادم');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('الجلسةُ مفتوحة: آخرُ حرفٍ لا يُنهيها', (tester) async {
      await boot(tester, _game(['ب', 'ت']));
      await openTile(tester, 0);
      await writeOpen(tester);
      await backToGrid(tester);
      await openTile(tester, 1);
      await writeOpen(tester);
      await backToGrid(tester);
      expect(find.byKey(const ValueKey('tracing-grid')), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
      await openTile(tester, 0);
      expect(find.byKey(const ValueKey('tracing-board')), findsOneWidget, reason: 'يُعاد بحرّية');
    });

    testWidgets('تُقلَّب الصفحات، وتبدأ من صفحة حرف الدرس', (tester) async {
      await boot(tester, _game(_letters, start: 7));
      expect(find.byKey(const ValueKey('tracing-tile-7')), findsOneWidget, reason: 'الذال في الصفحة الثانية');
      expect(find.text('صفحة 2 من 5'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tracing-page-next')));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byKey(const ValueKey('tracing-tile-12')), findsOneWidget);
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
  });

  group('اللوحة: لمسٌ سلس', () {
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
      expect(cheer, findsNothing);
    });

    testWidgets('رفعُ الإصبع في منتصف الجرّة لا يعيدها: يكمل من حيث توقّف', (tester) async {
      await boot(tester, _game(['ب']));
      await openTile(tester, 0);
      final plan = stateOf(tester).plan!;
      final points = plan.strokes.first.points;
      final half = points.length ~/ 2;

      var gesture = await tester.startGesture(onScreen(tester, points.first));
      for (final p in points.sublist(1, half + 1)) {
        await gesture.moveTo(onScreen(tester, p));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump();
      expect(find.text('أكمل من حيث توقّفت 👆'), findsOneWidget);
      expect(find.text('محاولات خاطئة: 1'), findsNothing, reason: 'الرفعُ ليس خطأ');

      gesture = await tester.startGesture(onScreen(tester, points[half]));
      for (final p in points.sublist(half + 1)) {
        await gesture.moveTo(onScreen(tester, p));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump();
      await tester.tapAt(onScreen(tester, plan.strokes[1].points.single));
      await tester.pump();
      expect(cheer, findsOneWidget);
      await backToGrid(tester);
    });

    testWidgets('تمريرٌ سريع بقفزاتٍ واسعة يكمل الحرف ولا يُعدّ خروجاً', (tester) async {
      await boot(tester, _game(['ب']));
      await openTile(tester, 0);
      final plan = stateOf(tester).plan!;
      final points = plan.strokes.first.points;
      // من البداية إلى النهاية بثلاث حركاتٍ فقط — إصبعٌ سريعٌ بين إطارين.
      final gesture = await tester.startGesture(onScreen(tester, points.first));
      for (final p in [points[points.length ~/ 3], points[2 * points.length ~/ 3], points.last]) {
        await gesture.moveTo(onScreen(tester, p));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump();
      expect(find.text('محاولات خاطئة: 1'), findsNothing);
      await tester.tapAt(onScreen(tester, plan.strokes[1].points.single));
      await tester.pump();
      expect(cheer, findsOneWidget);
      await backToGrid(tester);
    });

    testWidgets('إصبعٌ بجانب الخطّ قليلاً يكمل الحرف', (tester) async {
      await boot(tester, _game(['ب']));
      await openTile(tester, 0);
      final plan = stateOf(tester).plan!;
      await traceStroke(tester, plan.strokes.first, shift: const Offset(0, 28));
      await tester.tapAt(onScreen(tester, plan.strokes[1].points.single) + const Offset(20, 0));
      await tester.pump();
      expect(cheer, findsOneWidget);
      expect(find.text('محاولات خاطئة: 1'), findsNothing);
      await backToGrid(tester);
    });

    testWidgets('حرفٌ يلتقي آخرُه بأوّله لا يُغلَق قبل آخر نقطة', (tester) async {
      // حلقةٌ آخرُ نقاطها عند أوّلها — كالهاء والخمسة.
      final ring = TracePlan(
        strokes: [
          TraceStroke([
            for (var i = 0; i <= 12; i++)
              TracePoint(
                0.5 + 0.4 * math.cos(2 * math.pi * i / 12),
                0.5 + 0.4 * math.sin(2 * math.pi * i / 12),
              ),
          ]),
        ],
        width: 90,
        height: 60,
        inkWidth: 0.08,
      );
      await boot(tester, _game(['ه']), plan: ring);
      await openTile(tester, 0);
      final points = stateOf(tester).plan!.strokes.single.points;
      // يبدأ، ويتقدّم نقطتين، ثم يعود إلى البداية — حيث آخرُ نقطة.
      final gesture = await tester.startGesture(onScreen(tester, points.first));
      await gesture.moveTo(onScreen(tester, points[1]));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(onScreen(tester, points[2]));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(onScreen(tester, points[1]));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(onScreen(tester, points.last));
      await tester.pump(const Duration(milliseconds: 16));
      expect(cheer, findsNothing, reason: 'لم يمرّ بالحلقة كلّها');
      await gesture.up();
      await tester.pump();
    });

    testWidgets('الابتعادُ كثيراً عن الخطّ يُعيد الجرّةَ من أوّلها', (tester) async {
      await boot(tester, _game(['ب']));
      await openTile(tester, 0);
      final stroke = stateOf(tester).plan!.strokes.first;
      final gesture = await tester.startGesture(onScreen(tester, stroke.points.first));
      await gesture.moveTo(onScreen(tester, stroke.points[1]));
      await tester.pump();
      await gesture.moveTo(onScreen(tester, stroke.points[1]) + const Offset(0, 450));
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

  group('التقدّمُ يتبع الإصبعَ بالضبط — على شاشة تابلت وحرفٍ حقيقي', () {
    // هذا ما كان يفشل على الجهاز: على شاشةٍ كبيرة وحرفٍ عريض كان نصفُ قطر
    // القرب ~١٤٥ بكسلاً والنقاطُ متباعدةً ~٦٥، فيسبق التلوينُ الإصبعَ ويكتمل
    // الحرفُ وهو في منتصفه. والاختباراتُ السابقة بأشكالٍ صغيرة لم تُظهره.
    const ba = TracingItem(text: 'ب', kind: 'letter', lang: 'ar');

    Future<TracePolyline> bootTablet(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TracingGame(
              game: _game(const ['ب']),
              onTraced: (_) async => null,
              shapeBuilder: (item) async => precomputedTracingShape(ba),
              speak: (_, __) async {},
              playClip: (_) async {},
            ),
          ),
        ),
      );
      await tester.pump();
      await openTile(tester, 0);
      final state = stateOf(tester);
      final origin = tester.getTopLeft(find.byKey(const ValueKey('tracing-board')));
      return TracePolyline([
        for (final p in state.plan!.strokes.first.points) origin + state.toCanvas(p),
      ]);
    }

    testWidgets('التلوينُ لا يسبق الإصبعَ في أيّ لحظة', (tester) async {
      final line = await bootTablet(tester);
      expect(line.total, greaterThan(400), reason: 'حرفٌ بحجمه على تابلت');
      final gesture = await tester.startGesture(line.at(0));
      for (var along = 6.0; along < line.total * 0.6; along += 6) {
        await gesture.moveTo(line.at(along));
        await tester.pump(const Duration(milliseconds: 16));
        final progress = stateOf(tester).progress;
        expect(progress, lessThanOrEqualTo(along + 1), reason: 'سبق الإصبعَ عند $along');
        expect(progress, greaterThan(along - 12), reason: 'تخلّف عن الإصبع عند $along');
      }
      expect(cheer, findsNothing, reason: 'في منتصف الحرف لا يكتمل');
      await gesture.up();
    });

    testWidgets('يقف الإصبعُ قبل الآخر بقليل: لا يكتمل، ثم يكتمل عند آخر نقطة', (tester) async {
      final line = await bootTablet(tester);
      final gesture = await tester.startGesture(line.at(0));
      for (var along = 6.0; along <= line.total - 40; along += 6) {
        await gesture.moveTo(line.at(along));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(stateOf(tester).progress, lessThan(line.total - 30));
      expect(stateOf(tester).plan!.strokes, hasLength(2));
      // الجرّةُ الأولى ما زالت مفتوحة: نقطةُ الباء لا تُلمس بعد.
      expect(find.text('محاولات خاطئة: 1'), findsNothing);
      // ثم إلى آخر نقطةٍ بالضبط.
      for (var along = line.total - 34; along <= line.total; along += 6) {
        await gesture.moveTo(line.at(along));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.moveTo(line.points.last);
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(stateOf(tester).progress, -1, reason: 'اكتملت الجرّة وانتقل إلى النقطة');
    });

    testWidgets('إصبعٌ ساكنٌ لا يتقدّم معه شيء', (tester) async {
      final line = await bootTablet(tester);
      final gesture = await tester.startGesture(line.at(0));
      await gesture.moveTo(line.at(30));
      await tester.pump();
      final before = stateOf(tester).progress;
      for (var i = 0; i < 5; i++) {
        await gesture.moveTo(line.at(30) + const Offset(0.5, 0.5));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(stateOf(tester).progress, closeTo(before, 2));
      await gesture.up();
    });
  });

  group('TracePolyline', () {
    final line = TracePolyline(const [Offset(0, 0), Offset(100, 0), Offset(100, 100)]);

    test('الطولُ والموضع', () {
      expect(line.total, 200);
      expect(line.at(50), const Offset(50, 0));
      expect(line.at(150), const Offset(100, 50));
      expect(line.at(999), const Offset(100, 100));
    });

    test('الإسقاطُ داخل النافذة وحدها', () {
      final near = line.project(const Offset(40, 10), from: 0, to: 200);
      expect(near.along, closeTo(40, 0.001));
      expect(near.distance, closeTo(10, 0.001));
      // نافذةٌ تنتهي عند ٢٠: لا يُسقط أبعد منها ولو كان الإصبعُ هناك.
      final capped = line.project(const Offset(90, 0), from: 0, to: 20);
      expect(capped.along, closeTo(20, 0.001));
    });

    test('النقاطُ المعبورة', () {
      expect(line.passed(0), 0);
      expect(line.passed(99), 0);
      expect(line.passed(100), 1);
      expect(line.passed(200), 2);
    });
  });

  group('الحرفُ المرسوم هو نقاطُه', () {
    test('مسلكُ الحرف يمرّ بكل نقطة تتبّعٍ عينها', () {
      final shape = precomputedTracingShape(const TracingItem(text: 'ج', kind: 'letter', lang: 'ar'))!;
      const dest = Rect.fromLTWH(40, 30, 500, 520);
      for (final stroke in shape.plan.strokes.where((s) => !s.isDot)) {
        final points = [
          for (final p in stroke.points) Offset(dest.left + p.x * dest.width, dest.top + p.y * dest.height),
        ];
        final path = tracingLanePath(points);
        final samples = <Offset>[];
        for (final metric in path.computeMetrics()) {
          for (var d = 0.0; d <= metric.length; d += 0.5) {
            samples.add(metric.getTangentForOffset(d)!.position);
          }
        }
        for (final p in points) {
          final nearest = samples.map((q) => (q - p).distance).reduce((a, b) => a < b ? a : b);
          expect(nearest, lessThan(1.0), reason: 'المسلكُ يمرّ بالنقطة $p');
        }
      }
    });
  });

  group('النطقُ والصوتُ الحقيقيان — بلا مزيّف', () {
    // هذا ما يجري على الجهاز: لا نطقَ ولا تشغيلَ مزيّف. كان النطقُ الافتراضيُّ
    // يرمي `NoSuchMethodError` مع كل لمسة فيعلّق اللعبة، ولم يمرّ به اختبار.
    testWidgets('لمسُ حرفٍ يفتح لوحتَه، لا شاشةً بيضاء ولا تحميلاً', (tester) async {
      final plan = TracePlanner.plan(_baShape(), rtl: true);
      await tester.binding.setSurfaceSize(const Size(900, 640));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TracingGame(
              game: _game(_letters),
              onTraced: (_) async => null,
              shapeBuilder: (item) async =>
                  TracingShape(crop: const Rect.fromLTWH(0, 0, 90, 60), plan: plan),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('tracing-tile-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('tracing-board')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(stateOf(tester).plan, isNotNull);
    });
  });

  group('الأرقامُ من ٠ إلى ١٠٠', () {
    testWidgets('اثنا عشر في الصفحة، ولمسُ عددٍ ينطقه كلماتٍ ويفتحه', (tester) async {
      final numbers = _game(const [], entries: [
        for (var n = 0; n <= 100; n++)
          {'text': arabicIndicDigits('$n'), 'kind': 'number', 'lang': 'ar', 'speech': 'عدد $n'},
      ]);
      await boot(tester, numbers);
      expect(find.byKey(const ValueKey('tracing-tile-11')), findsOneWidget);
      expect(find.byKey(const ValueKey('tracing-tile-12')), findsNothing);
      expect(find.text('صفحة 1 من 9'), findsOneWidget);
      await openTile(tester, 7);
      expect(spoken, ['ar:عدد 7']);
      expect(clips, isEmpty);
      expect(find.text('كل الأرقام'), findsOneWidget);
    });
  });

  group('الأشكالُ المحسوبةُ مسبقاً', () {
    test('حروفُ الروضة كلُّها وأرقامُها من ٠ إلى ١٠٠ بالنظامين محسوبة', () {
      expect(kindergartenTracingItems, hasLength(28 + 26 + 101 + 101));
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
  });
}
