import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/services/student_duel_service.dart';
import 'package:manara_student/src/widgets/duel_arenas.dart';
import 'package:manara_student/src/widgets/duel_game_scene.dart';

/// حلبةُ «تحدَّ زملاءك»: المشهدُ المتحرّكُ هو الحلبة، ويجيب كلَّ جواب —
/// يقفز ويُشدّ ويجمع ويبني مع الصحيح، ويتعثّر مع الخطأ أو السبق — ثم يهدأ،
/// ولا يُغيّر شيئاً من النتيجة نفسها.
void main() {
  Widget arena(
    DuelGame game, {
    required int mine,
    required int theirs,
    bool finished = false,
    bool still = false,
    int? missAt,
    List<ArenaRacer>? players,
    Size size = const Size(400, 800),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: still),
        child: Scaffold(
          body: SingleChildScrollView(
            child: DuelArena(
              game: game,
              mine: mine,
              theirs: theirs,
              total: 5,
              live: !finished,
              finished: finished,
              myAppearance: null,
              theirAppearance: null,
              opponentName: 'سارة',
              players: players,
              missAt: missAt,
            ),
          ),
        ),
      ),
    );
  }

  Finder beat(DuelGame game, DuelBeat kind) => find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('duel-beat-${game.id}-${kind.name}-'),
      );

  String upLabel(DuelGame game) => switch (game) {
        DuelGame.sprint => tr('arena.beat.sprintUp'),
        DuelGame.tug => tr('arena.beat.tugUp'),
        DuelGame.balloons => tr('arena.beat.fruitUp'),
        DuelGame.gems => tr('arena.beat.wallUp'),
      };

  String downLabel(DuelGame game) => switch (game) {
        DuelGame.sprint => tr('arena.beat.sprintDown'),
        DuelGame.tug => tr('arena.beat.tugDown'),
        DuelGame.balloons => tr('arena.beat.fruitDown'),
        DuelGame.gems => tr('arena.beat.wallDown'),
      };

  group('ما يُقرأ من النتائج', () {
    test('نقطتي زادت: نجاح — ولو زادت نقطةُ غيري معها', () {
      expect(duelBeatOf(myBefore: 0, myNow: 1, othersBefore: 0, othersNow: 0, missBefore: null, missNow: null), DuelBeat.success);
    });
    test('اخترتُ خطأً في سؤالٍ جديد: خطأ', () {
      expect(duelBeatOf(myBefore: 1, myNow: 1, othersBefore: 0, othersNow: 0, missBefore: null, missNow: 2), DuelBeat.wrong);
      expect(duelBeatOf(myBefore: 1, myNow: 1, othersBefore: 0, othersNow: 0, missBefore: 2, missNow: 2), isNull,
          reason: 'الخطأُ نفسُه لا يُعاد');
    });
    test('زادت نقطةُ زميلٍ ولم تزد نقطتي: سبقني', () {
      expect(duelBeatOf(myBefore: 1, myNow: 1, othersBefore: 2, othersNow: 3, missBefore: null, missNow: null), DuelBeat.beaten);
    });
    test('لا شيء تغيّر: هدوء', () {
      expect(duelBeatOf(myBefore: 1, myNow: 1, othersBefore: 2, othersNow: 2, missBefore: null, missNow: null), isNull);
    });
  });

  for (final game in DuelGame.values) {
    testWidgets('${game.name}: الجوابُ الصحيح حركةُ نجاحٍ في المشهد، ثم تهدأ', (tester) async {
      await tester.pumpWidget(arena(game, mine: 0, theirs: 0));
      await tester.pumpWidget(arena(game, mine: 1, theirs: 0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(beat(game, DuelBeat.success), findsOneWidget);
      expect(find.text(upLabel(game)), findsOneWidget);
      // ‏والمشهدُ يجري: لا وقوفَ مع النجاح.
      final ticker = tester.widget<TickerMode>(
          find.ancestor(of: find.byType(Image), matching: find.byType(TickerMode)).first);
      expect(ticker.enabled, isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(beat(game, DuelBeat.success), findsNothing);
      expect(find.text('1/5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${game.name}: الخطأ تعثّرٌ يوقف المشهدَ لحظة ثم يعود', (tester) async {
      await tester.pumpWidget(arena(game, mine: 0, theirs: 0));
      await tester.pumpWidget(arena(game, mine: 0, theirs: 0, missAt: 0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(beat(game, DuelBeat.wrong), findsOneWidget);
      expect(find.text(downLabel(game)), findsOneWidget);
      TickerMode ticker() => tester.widget<TickerMode>(
          find.ancestor(of: find.byType(Image), matching: find.byType(TickerMode)).first);
      expect(ticker().enabled, isFalse, reason: 'المشهدُ يقف لحظةَ التعثّر');
      await tester.pump(const Duration(seconds: 2));
      expect(beat(game, DuelBeat.wrong), findsNothing);
      expect(ticker().enabled, isTrue, reason: 'ثم يعود يجري');
    });

    testWidgets('${game.name}: سبقني زميلٌ بالصحيح: تعثّرٌ بكلمة «سبقك»', (tester) async {
      await tester.pumpWidget(arena(game, mine: 1, theirs: 0));
      await tester.pumpWidget(arena(game, mine: 1, theirs: 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(beat(game, DuelBeat.beaten), findsOneWidget);
      expect(find.textContaining(tr('arena.beat.beaten')), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(beat(game, DuelBeat.beaten), findsNothing);
    });

    testWidgets('${game.name}: أخطأتُ ثم سبقني زميل: تعثّرٌ واحدٌ لا اثنان', (tester) async {
      await tester.pumpWidget(arena(game, mine: 0, theirs: 0));
      await tester.pumpWidget(arena(game, mine: 0, theirs: 0, missAt: 0));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(arena(game, mine: 0, theirs: 1, missAt: 0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(beat(game, DuelBeat.wrong), findsOneWidget);
      expect(beat(game, DuelBeat.beaten), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('${game.name}: «تقليل الحركة» يحترم', (tester) async {
      await tester.pumpWidget(arena(game, mine: 0, theirs: 0, still: true));
      await tester.pumpWidget(arena(game, mine: 1, theirs: 0, still: true));
      await tester.pump();
      expect(beat(game, DuelBeat.success), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${game.name}: التاجُ للفائز وحده، ولا تاجَ في التعادل', (tester) async {
      await tester.pumpWidget(arena(game, mine: 4, theirs: 2, finished: true));
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('👑'), findsOneWidget);
      await tester.pumpWidget(arena(game, mine: 3, theirs: 3, finished: true));
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('👑'), findsNothing);
    });

    testWidgets('${game.name}: الحلبةُ مشهدُ اللعبة وحده — لا رسومٌ قديمة', (tester) async {
      await tester.pumpWidget(arena(game, mine: 0, theirs: 0));
      expect(find.byType(DuelGameScene), findsOneWidget);
      for (final old in ['_HurdleLane', '_OrchardTree', '_VoyageLane', '_Tower', 'DuelTugOfWar']) {
        expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == old), findsNothing, reason: old);
      }
    });

    for (final size in const [Size(360, 740), Size(800, 380), Size(1024, 768), Size(768, 1024)]) {
      testWidgets('${game.name}: غرفةٌ كاملة — ستّةُ لاعبين بأرقامهم (${size.width.toInt()}×${size.height.toInt()})',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final players = [
          const ArenaRacer(name: 'أنا', at: 2, me: true),
          for (var i = 1; i <= 5; i++) ArenaRacer(name: 'زميل $i', at: i % 5),
        ];
        await tester.pumpWidget(arena(game, mine: 0, theirs: 0, players: players, size: size));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull, reason: 'لا فيضانَ ولا تداخل');
        for (var lane = 1; lane <= 6; lane++) {
          expect(find.text('$lane'), findsOneWidget, reason: 'اللاعب $lane');
        }
        final centers = [for (var lane = 1; lane <= 6; lane++) tester.getCenter(find.text('$lane'))];
        for (var a = 0; a < centers.length; a++) {
          for (var b = a + 1; b < centers.length; b++) {
            expect((centers[a] - centers[b]).distance, greaterThan(20));
          }
        }
        expect(find.text('2/5'), findsNWidgets(2));
        // ‏والمشهدُ بعدد من في الغرفة (أقربُ مشهد: خمسة).
        final image = tester.widget<Image>(find.byType(Image));
        final provider = image.image;
        final asset = (provider is ResizeImage ? provider.imageProvider : provider) as AssetImage;
        expect(asset.assetName, duelGameScene(game, 6));
      });

      testWidgets('${game.name}: النتيجةُ بلا فيضان (${size.width.toInt()}×${size.height.toInt()})', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(arena(game, mine: 5, theirs: 4, finished: true, size: size));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
