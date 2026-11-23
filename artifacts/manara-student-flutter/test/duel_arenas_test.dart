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

  group('الحبل', () {
    const me = ArenaRacer(name: 'أنا', at: 0, me: true);
    test('حصّةُ الحبل: بيني وبين أقوى المنافسين', () {
      expect(duelRopeShift(const [me, ArenaRacer(name: 'س', at: 0)], 5), 0);
      expect(duelRopeShift(const [ArenaRacer(name: 'أنا', at: 3, me: true), ArenaRacer(name: 'س', at: 1)], 5), closeTo(0.4, 1e-9));
      expect(duelRopeShift(const [me, ArenaRacer(name: 'س', at: 1), ArenaRacer(name: 'ر', at: 4)], 5), closeTo(-0.8, 1e-9));
      expect(duelRopeShift(const [ArenaRacer(name: 'أنا', at: 9, me: true), ArenaRacer(name: 'س', at: 0)], 5), 1.0);
    });
    test('البناءُ يكتمل بكل طوبه', () {
      expect(duelBuildingComplete(const [ArenaRacer(name: 'أنا', at: 5, me: true)], 5), isTrue);
      expect(duelBuildingComplete(const [ArenaRacer(name: 'أنا', at: 4, me: true), ArenaRacer(name: 'س', at: 5)], 5), isFalse);
    });
  });

  group('تفاعلُ كل لعبة', () {
    List<ArenaRacer> party(int me, int sara, int reem) => [
          ArenaRacer(name: 'أنا', at: me, me: true),
          ArenaRacer(name: 'سارة', at: sara),
          ArenaRacer(name: 'ريم', at: reem),
        ];
    Finder key(String k) => find.byKey(ValueKey(k));
    double dxOf(WidgetTester tester, String k) => tester.getCenter(key(k)).dx;

    testWidgets('شدّ الحبل: أسبقُ فيُشدّ نحوي، ويسبقني زميلٌ فيُشدّ نحوهم', (tester) async {
      await tester.pumpWidget(arena(DuelGame.tug, mine: 0, theirs: 0));
      expect(key('duel-tug-rope'), findsOneWidget);
      expect(key('duel-tug-me'), findsOneWidget);
      expect(key('duel-tug-rivals-1'), findsOneWidget);
      final middle = dxOf(tester, 'duel-tug-flag');
      final myEnd = dxOf(tester, 'duel-tug-me');
      await tester.pumpWidget(arena(DuelGame.tug, mine: 2, theirs: 0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(key('duel-tug-pull-me'), findsOneWidget, reason: 'سهمُ الشدّ نحوي');
      await tester.pump(const Duration(seconds: 2));
      final mineAhead = dxOf(tester, 'duel-tug-flag');
      expect((mineAhead - myEnd).abs(), lessThan((middle - myEnd).abs()), reason: 'الرايةُ اقتربت من طرفي');
      await tester.pumpWidget(arena(DuelGame.tug, mine: 2, theirs: 4));
      await tester.pump(const Duration(milliseconds: 300));
      expect(key('duel-tug-pull-them'), findsOneWidget, reason: 'سبقني: يُشدّ نحوهم');
      expect(key('duel-tug-pull-me'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect((dxOf(tester, 'duel-tug-flag') - myEnd).abs(), greaterThan((middle - myEnd).abs()), reason: 'الرايةُ عند المنافس');
    });

    testWidgets('شدّ الحبل أمام ثلاثة: أنا في طرف وهم الثلاثةُ في الطرف المقابل', (tester) async {
      List<ArenaRacer> four(int reem) => [
            const ArenaRacer(name: 'أنا', at: 0, me: true),
            const ArenaRacer(name: 'سارة', at: 0),
            ArenaRacer(name: 'ريم', at: reem),
            const ArenaRacer(name: 'خالد', at: 0),
          ];
      await tester.pumpWidget(arena(DuelGame.tug, mine: 0, theirs: 0, players: four(0)));
      expect(key('duel-tug-rivals-3'), findsOneWidget);
      expect(find.textContaining(trf('arena.tug.rivals', {'n': '3'})), findsOneWidget);
      final me = tester.getCenter(key('duel-tug-me')).dx;
      final them = tester.getCenter(key('duel-tug-rivals-3')).dx;
      expect((me - them).abs(), greaterThan(150), reason: 'طرفان متقابلان');
      // ‏سبقتني ريم: الحبلُ نحوهم، ويُعرف من سبق.
      await tester.pumpWidget(arena(DuelGame.tug, mine: 0, theirs: 0, players: four(1)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(key('duel-tug-pull-them'), findsOneWidget);
      expect(find.textContaining(trf('arena.beat.beatenBy', {'name': 'ريم'})), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('سباق الحواجز: أصيبُ فيقفز عدّائي، وأخطئ فيسقط، ويسبقني زميلٌ فيقفز عدّاؤه', (tester) async {
      await tester.pumpWidget(arena(DuelGame.sprint, mine: 0, theirs: 0, players: party(0, 0, 0)));
      await tester.pumpWidget(arena(DuelGame.sprint, mine: 0, theirs: 0, players: party(1, 0, 0)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(key('duel-runner-jump'), findsOneWidget);
      expect(key('duel-runner-fall'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(key('duel-runner-jump'), findsNothing);
      await tester.pumpWidget(arena(DuelGame.sprint, mine: 0, theirs: 0, players: party(1, 1, 0)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(key('duel-runner-fall'), findsOneWidget, reason: 'سبقتني سارة: أتعثّر');
      expect(key('duel-runner-rival-jump'), findsOneWidget, reason: 'وعدّاؤها يقفز');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(arena(DuelGame.sprint, mine: 0, theirs: 0, players: party(1, 1, 0), missAt: 3));
      await tester.pump(const Duration(milliseconds: 400));
      expect(key('duel-runner-fall'), findsOneWidget, reason: 'أخطأتُ: أتعثّر');
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('بناء الجدار: طوبةٌ مع كل صحيح، وطوبةٌ تسقط مع الخطأ، والبناءُ يكتمل', (tester) async {
      await tester.pumpWidget(arena(DuelGame.gems, mine: 0, theirs: 0));
      expect(key('duel-wall-brick'), findsNothing);
      await tester.pumpWidget(arena(DuelGame.gems, mine: 1, theirs: 0));
      await tester.pump(const Duration(milliseconds: 200));
      expect(key('duel-wall-brick'), findsOneWidget, reason: 'تهبط إلى مكانها');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(arena(DuelGame.gems, mine: 3, theirs: 0));
      await tester.pump(const Duration(seconds: 2));
      expect(key('duel-wall-brick'), findsNWidgets(3));
      await tester.pumpWidget(arena(DuelGame.gems, mine: 3, theirs: 0, missAt: 4));
      await tester.pump(const Duration(milliseconds: 300));
      expect(key('duel-wall-fall'), findsOneWidget, reason: 'أخطأتُ: طوبةٌ تسقط');
      await tester.pump(const Duration(seconds: 2));
      expect(key('duel-wall-fall'), findsNothing);
      expect(key('duel-wall-complete'), findsNothing);
      await tester.pumpWidget(arena(DuelGame.gems, mine: 5, theirs: 0, missAt: 4));
      await tester.pump(const Duration(seconds: 2));
      expect(key('duel-wall-brick'), findsNWidgets(5));
      expect(key('duel-wall-complete'), findsOneWidget, reason: 'اكتمل البناء');
      await tester.pumpWidget(arena(DuelGame.gems, mine: 5, theirs: 3, finished: true));
      await tester.pump(const Duration(seconds: 1));
      expect(key('duel-wall-complete'), findsOneWidget, reason: 'ويبقى مكتملاً في النتيجة');
    });

    testWidgets('جمع الفواكه: ثمرةٌ في السلّة، أو تسقط على الأرض ويجمعها من سبق', (tester) async {
      await tester.pumpWidget(arena(DuelGame.balloons, mine: 0, theirs: 0, players: party(0, 0, 0)));
      expect(key('duel-basket-me'), findsOneWidget);
      await tester.pumpWidget(arena(DuelGame.balloons, mine: 0, theirs: 0, players: party(1, 0, 0)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(key('duel-fruit-in'), findsOneWidget);
      expect(key('duel-fruit-ground'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.descendant(of: key('duel-basket-me'), matching: find.text('🍎×1')), findsOneWidget);
      await tester.pumpWidget(arena(DuelGame.balloons, mine: 0, theirs: 0, players: party(1, 1, 0)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(key('duel-fruit-ground'), findsOneWidget, reason: 'سبقتني سارة: ثمرتي على الأرض');
      expect(key('duel-fruit-rival-catch'), findsOneWidget, reason: 'وسلّتُها تمتلئ');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(arena(DuelGame.balloons, mine: 0, theirs: 0, players: party(1, 1, 0), missAt: 2));
      await tester.pump(const Duration(milliseconds: 300));
      expect(key('duel-fruit-ground'), findsOneWidget, reason: 'أخطأتُ: تسقط');
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('أمام زميلٍ واحد: كلُّ لعبةٍ تُري السبقَ باسم من سبق', (tester) async {
      for (final game in DuelGame.values) {
        await tester.pumpWidget(arena(game, mine: 0, theirs: 0));
        await tester.pumpWidget(arena(game, mine: 0, theirs: 1));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.textContaining(trf('arena.beat.beatenBy', {'name': 'سارة'})), findsOneWidget, reason: game.name);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpWidget(const SizedBox());
      }
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
      expect(find.textContaining(trf('arena.beat.beatenBy', {'name': 'سارة'})), findsOneWidget, reason: 'يُعرف من سبق');
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
        final board = find.byKey(const ValueKey('duel-racer-board'));
        Finder lane(int n) => find.descendant(of: board, matching: find.text('$n'));
        for (var n = 1; n <= 6; n++) {
          expect(lane(n), findsOneWidget, reason: 'اللاعب $n');
        }
        final centers = [for (var n = 1; n <= 6; n++) tester.getCenter(lane(n))];
        for (var a = 0; a < centers.length; a++) {
          for (var b = a + 1; b < centers.length; b++) {
            expect((centers[a] - centers[b]).distance, greaterThan(20));
          }
        }
        expect(find.descendant(of: board, matching: find.text('2/5')), findsNWidgets(2));
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
