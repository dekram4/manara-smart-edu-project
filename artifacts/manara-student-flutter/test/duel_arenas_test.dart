import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/services/student_duel_service.dart';
import 'package:manara_student/src/widgets/duel_arenas.dart';

/// ألعابُ «تحدَّ زملاءك» الأربع: كلُّ نقطةٍ تُرى — قفزةٌ فوق حاجز، وثمرةٌ
/// تسقط في السلّة، وصاروخٌ يجمع نجمة، ومكعّبٌ يسقط في البرج — ثم تهدأ،
/// ولا تُغيّر شيئاً من النتيجة نفسها.
void main() {
  Widget arena(
    DuelGame game, {
    required int mine,
    required int theirs,
    bool finished = false,
    bool still = false,
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
            ),
          ),
        ),
      ),
    );
  }

  Finder byType(String name) =>
      find.byWidgetPredicate((w) => w.runtimeType.toString() == name);

  for (final game in DuelGame.values) {
    testWidgets('${game.name}: نقطةٌ لي ثم له، والحركةُ تنتهي بلا أثر', (tester) async {
      await tester.pumpWidget(arena(game, mine: 0, theirs: 0));
      await tester.pumpWidget(arena(game, mine: 1, theirs: 0));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'الحركةُ تُرى');
      await tester.pumpAndSettle();
      await tester.pumpWidget(arena(game, mine: 1, theirs: 1));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('1/5'), findsNWidgets(2));
    });

    testWidgets('${game.name}: «تقليل الحركة» يحترم', (tester) async {
      await tester.pumpWidget(arena(game, mine: 0, theirs: 0, still: true));
      await tester.pumpWidget(arena(game, mine: 1, theirs: 0, still: true));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${game.name}: التاجُ للفائز وحده، ولا تاجَ في التعادل', (tester) async {
      await tester.pumpWidget(arena(game, mine: 4, theirs: 2, finished: true));
      await tester.pumpAndSettle();
      expect(find.textContaining('👑'), findsOneWidget);
      await tester.pumpWidget(arena(game, mine: 3, theirs: 3, finished: true));
      await tester.pumpAndSettle();
      expect(find.textContaining('👑'), findsNothing);
    });

    testWidgets('${game.name}: التحدي الجماعي بمساراتٍ مرقّمة', (tester) async {
      await tester.pumpWidget(arena(
        game,
        mine: 0,
        theirs: 0,
        players: const [
          ArenaRacer(name: 'أنا', at: 2, me: true),
          ArenaRacer(name: 'سارة', at: 1),
          ArenaRacer(name: 'ريم', at: 3),
        ],
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final lane in ['1', '2', '3']) {
        expect(find.text(lane), findsOneWidget, reason: 'المسار $lane');
      }
      expect(find.text('2/5'), findsOneWidget);
      expect(find.text('1/5'), findsOneWidget);
      expect(find.text('3/5'), findsOneWidget);
    });

    for (final size in const [Size(360, 740), Size(800, 380)]) {
      testWidgets('${game.name}: غرفةٌ كاملة — ستّةُ لاعبين بستّة مسارات (${size.width > size.height ? 'أفقي' : 'رأسي'})',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final players = [
          const ArenaRacer(name: 'أنا', at: 2, me: true),
          for (var i = 1; i <= 5; i++) ArenaRacer(name: 'زميل $i', at: i % 5),
        ];
        await tester.pumpWidget(arena(game, mine: 0, theirs: 0, players: players, size: size));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'لا فيضانَ ولا تداخل');
        for (var lane = 1; lane <= 6; lane++) {
          expect(find.text('$lane'), findsOneWidget, reason: 'المسار $lane');
        }
        // وكلُّ مسارٍ في موضعٍ لا يركب غيرَه: أرقامُ المسارات لا تتطابق مواضعُها.
        final centers = [for (var lane = 1; lane <= 6; lane++) tester.getCenter(find.text('$lane'))];
        for (var a = 0; a < centers.length; a++) {
          for (var b = a + 1; b < centers.length; b++) {
            expect((centers[a] - centers[b]).distance, greaterThan(20));
          }
        }
        // ونقاطُ كل لاعب: 2/5 لي، و1..4 و0 لزملائي.
        expect(find.text('2/5'), findsNWidgets(2));
      });


      testWidgets('${game.name}: بلا فيضانٍ في ${size.width > size.height ? 'الأفقي' : 'الرأسي'}',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(arena(game, mine: 5, theirs: 4, finished: true, size: size));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('سباق الحواجز: خمسةُ حواجز، وعلامةُ الصحّ مع القفزة ثم تختفي', (tester) async {
    await tester.pumpWidget(arena(DuelGame.sprint, mine: 0, theirs: 0));
    await tester.pumpWidget(arena(DuelGame.sprint, mine: 1, theirs: 0));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('⭐'), findsNWidgets(3));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.text('🏁'), findsNWidgets(2));
  });

  testWidgets('بستان الأرقام: الثمرةُ تسقط في السلّة وتلمع', (tester) async {
    await tester.pumpWidget(arena(DuelGame.balloons, mine: 0, theirs: 0));
    // لكل شجرةٍ خمسُ ثمار، ولا شيء في السلّتين.
    expect(byType('_Fruit'), findsNWidgets(10));
    await tester.pumpWidget(arena(DuelGame.balloons, mine: 1, theirs: 0));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('✨'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('✨'), findsNothing);
    // الثمرةُ انتقلت من الشجرة إلى السلّة: العددُ نفسه.
    expect(byType('_Fruit'), findsNWidgets(10));
  });

  testWidgets('مغامرة الفضاء: النجومُ المجموعة بعدد النقاط', (tester) async {
    await tester.pumpWidget(arena(DuelGame.tug, mine: 0, theirs: 0));
    await tester.pumpWidget(arena(DuelGame.tug, mine: 2, theirs: 1));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(7));
    expect(find.text('🚀'), findsNWidgets(2));
  });

  testWidgets('أبراج التحدي: مكعّبٌ يسقط في مكانه، والرايةُ عند الاكتمال', (tester) async {
    await tester.pumpWidget(arena(DuelGame.gems, mine: 0, theirs: 0));
    expect(byType('_Block'), findsNothing);
    await tester.pumpWidget(arena(DuelGame.gems, mine: 1, theirs: 0));
    await tester.pump(const Duration(milliseconds: 200));
    expect(byType('_Block'), findsOneWidget, reason: 'في الهواء');
    await tester.pumpAndSettle();
    expect(byType('_Block'), findsOneWidget, reason: 'في مكانه');
    await tester.pumpWidget(arena(DuelGame.gems, mine: 5, theirs: 1));
    await tester.pumpAndSettle();
    expect(byType('_Block'), findsNWidgets(6));
    expect(find.text('🚩'), findsOneWidget);
  });
}
