import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/widgets/dealt_card_entrance.dart';

/// The rail is a `ListView`, so it destroys cards scrolled out of view and
/// rebuilds them on the way back. These pin down that a card rebuilt that way
/// comes back already at rest — the flicker where cards vanished mid-drag and
/// spiralled in again.
void main() {
  Widget rail(DealEntranceTracker tracker, ScrollController controller) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 200,
          // Built eagerly, exactly as the hub's rail is. A `ListView.builder`
          // here would only construct the cards near the viewport, and the
          // tests below are about the ones that are not.
          child: SingleChildScrollView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < 12; index++)
                  SizedBox(
                    width: 200,
                    child: DealtCardEntrance(
                      index: index,
                      tracker: tracker,
                      sound: false,
                      child: Center(child: Text('card $index')),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Runs the clock in small steps so timer-started animations advance.
  Future<void> settle(WidgetTester tester, int ms) async {
    for (var i = 0; i * 100 < ms; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The opacity the entrance is painting this card at. 1.0 means arrived.
  double opacityOf(WidgetTester tester, String label) {
    final opacity = find.ancestor(
      of: find.text(label),
      matching: find.byType(Opacity),
    );
    return tester.widget<Opacity>(opacity.first).opacity;
  }

  /// The scale the entrance is painting, read off the matrix it builds.
  double scaleOf(WidgetTester tester, String label) {
    final transform = find.ancestor(
      of: find.text(label),
      matching: find.byType(Transform),
    );
    return tester
        .widget<Transform>(transform.first)
        .transform
        .getMaxScaleOnAxis();
  }

  testWidgets('an unarmed rail deals nothing at all', (tester) async {
    final tracker = DealEntranceTracker();
    final controller = ScrollController();
    addTearDown(controller.dispose);

    // Deliberately not armed. The hub arms the rail only once the spoken
    // greeting has actually finished, so until then the screen stays empty —
    // nine card sounds under a spoken sentence made neither audible.
    await tester.pumpWidget(rail(tracker, controller));
    await settle(tester, 2000);

    expect(opacityOf(tester, 'card 0'), 0.0);
    expect(opacityOf(tester, 'card 1'), 0.0);
  });

  testWidgets('arming deals every card, not only the visible ones',
      (tester) async {
    final tracker = DealEntranceTracker();
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(rail(tracker, controller));
    tracker.arm();
    // Long enough for all twelve turns: 11 * 280ms + 800ms.
    await settle(tester, 4200);

    // Card 11 is far off the right edge and was never scrolled to. With a
    // lazily-built rail it would not even exist yet, which is why the later
    // cards used to appear only when the student dragged looking for them.
    expect(opacityOf(tester, 'card 11'), 1.0);
  });

  testWidgets('a card overshoots its size before settling on it',
      (tester) async {
    final tracker = DealEntranceTracker();
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(rail(tracker, controller));
    tracker.arm();

    var peak = 0.0;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      peak = peak > scaleOf(tester, 'card 0') ? peak : scaleOf(tester, 'card 0');
    }

    // Out past its own size on the way in — the pop — and exactly its own
    // size once it has settled.
    expect(peak, greaterThan(1.5), reason: 'the card never overshot');
    expect(scaleOf(tester, 'card 0'), closeTo(1.0, 0.01));
  });

  testWidgets('a card scrolled away and back does not deal itself again',
      (tester) async {
    final tracker = DealEntranceTracker();
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(rail(tracker, controller));
    tracker.arm();
    // Stepped: the deal runs off timers, and one long pump would fire them
    // all at its end with no time left for the animations to advance.
    await settle(tester, 3000);
    expect(opacityOf(tester, 'card 0'), 1.0);

    // Drag well past card 0 so the list disposes it, then come back.
    controller.jumpTo(1400);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    controller.jumpTo(0);
    await tester.pump();

    // The very next frame: no fade, no spiral, no gap. Before the tracker
    // this read 0.0 here and climbed back up over the next half second.
    expect(
      opacityOf(tester, 'card 0'),
      1.0,
      reason: 'the card dealt itself in again after scrolling back',
    );
  });

  testWidgets('a card never yet seen still deals in when first reached',
      (tester) async {
    final tracker = DealEntranceTracker();
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(rail(tracker, controller));
    tracker.arm();
    await settle(tester, 300);

    // Card 11 is far off-screen and its turn is many seconds away, so it has
    // not been built yet. Jumping to it must still give it its entrance —
    // the fix must not turn the animation off wholesale.
    controller.jumpTo(2000);
    await tester.pump();
    expect(opacityOf(tester, 'card 11'), lessThan(1.0));
  });
}
