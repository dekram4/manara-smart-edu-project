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

  test('the deal is strictly serial and quick: 320ms a card, the next at 340ms',
      () {
    // Asked for by name: a card may only leave once the one before it has
    // stopped. That holds exactly when the step is longer than the flight.
    expect(DealtCardEntrance.defaultDuration,
        const Duration(milliseconds: 320));
    expect(DealtCardEntrance.defaultStagger,
        const Duration(milliseconds: 340));
    expect(DealtCardEntrance.defaultStagger,
        greaterThanOrEqualTo(DealtCardEntrance.defaultDuration));
    // And quick, which was asked for just as plainly: the last of the ten
    // portals lands 3.38s after the rail is armed, not 17 as it once did.
    expect(DealtCardEntrance.dealSpanFor(10),
        const Duration(milliseconds: 9 * 340 + 320));
    expect(DealtCardEntrance.defaultStartDelay,
        lessThanOrEqualTo(const Duration(seconds: 1)));
  });

  testWidgets('never two cards in the air at once', (tester) async {
    final tracker = DealEntranceTracker();
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(rail(tracker, controller));
    tracker.arm();

    // A card is in flight once it has begun to show and until it is back at
    // its own size. Not yet dealt is invisible; dealt is opaque at 1.0.
    bool inFlight(int index) {
      final opacity = opacityOf(tester, 'card $index');
      final scale = scaleOf(tester, 'card $index');
      return opacity > 0.0 && (opacity < 1.0 || scale > 1.0005);
    }

    // Sampled finer than the 20ms beat between one card landing and the
    // next leaving, so a card that set off early cannot hide between frames.
    const step = 10;
    final span = DealtCardEntrance.defaultStagger.inMilliseconds * 4 + 200;
    final landed = <int>{};
    for (var frame = 0; frame * step < span; frame++) {
      await tester.pump(const Duration(milliseconds: step));
      final flying = [
        for (var i = 0; i < 4; i++)
          if (inFlight(i)) i,
      ];
      for (var i = 0; i < 4; i++) {
        if (opacityOf(tester, 'card $i') == 1.0 && !inFlight(i)) landed.add(i);
      }
      expect(flying.length, lessThanOrEqualTo(1),
          reason: 'cards $flying were moving together at ${frame * step}ms');
      // And each one leaves only after every card before it has landed.
      for (final i in flying) {
        for (var before = 0; before < i; before++) {
          expect(landed, contains(before),
              reason: 'card $i left before card $before had settled');
        }
      }
    }
    expect(landed, containsAll(<int>[0, 1, 2, 3]));
  });

  testWidgets('an unarmed rail deals nothing at all', (tester) async {
    final tracker = DealEntranceTracker();
    final controller = ScrollController();
    addTearDown(controller.dispose);

    // Deliberately not armed. The hub arms the rail itself, a beat after it
    // opens; until then the cards must not move on their own.
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
    // Derived, not written down: the deal has been re-timed several times and
    // a hardcoded wait here goes stale silently — it did, the first time this
    // ran against a slower pace.
    await settle(
      tester,
      DealtCardEntrance.dealSpanFor(12).inMilliseconds + 400,
    );

    // Card 11 is far off the right edge and was never scrolled to. With a
    // lazily-built rail it would not even exist yet, which is why the later
    // cards used to appear only when the student dragged looking for them.
    expect(opacityOf(tester, 'card 11'), 1.0);
  });

  testWidgets('a card arrives huge and shrinks the whole way to its own size',
      (tester) async {
    final tracker = DealEntranceTracker();
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(rail(tracker, controller));
    tracker.arm();

    final samples = <double>[];
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      samples.add(scaleOf(tester, 'card 0'));
    }

    // It starts near 2.9 — from the front of the scene, not from nothing. The
    // first sample is a frame in, so it has already lost a little.
    expect(samples.first, greaterThan(2.5),
        reason: 'the card did not arrive from the front of the scene');
    expect(samples.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(2.91));

    // And it only ever shrinks. This is the whole shape of the motion in one
    // assertion: no growth, and so no overshoot past its own size on the way
    // to rest — the card stops where it stops. A tolerance because the samples
    // are frames, not exact curve values.
    for (var i = 1; i < samples.length; i++) {
      expect(samples[i], lessThanOrEqualTo(samples[i - 1] + 0.001),
          reason: 'the card grew between samples ${i - 1} and $i');
    }

    expect(scaleOf(tester, 'card 0'), closeTo(1.0, 0.01));
  });

  testWidgets('a card never turns far enough to show its back', (tester) async {
    final tracker = DealEntranceTracker();
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(rail(tracker, controller));
    tracker.arm();

    // Flutter does no backface culling: rotate a widget past 90° on Y and it
    // simply paints mirrored — artwork and Arabic text reversed. That shows up
    // in the projected transform as the 2x2 in-plane block flipping sign, so
    // that sign is the invariant to hold, whatever the rotation is tuned to.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      final matrix = tester
          .widget<Transform>(
            find
                .ancestor(
                  of: find.text('card 0'),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform;
      final inPlane = matrix.entry(0, 0) * matrix.entry(1, 1) -
          matrix.entry(0, 1) * matrix.entry(1, 0);
      expect(inPlane, greaterThan(0.0),
          reason: 'the card was painting mirrored at frame $i');
    }
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
