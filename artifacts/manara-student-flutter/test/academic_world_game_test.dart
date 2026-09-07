import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/screens/game_world/academic_world_game.dart';

/// Pins the test binding's viewport to an exact, known logical size.
///
/// A nested `SizedBox` under `MaterialApp.home` does *not* reliably shrink
/// the GameWidget below the test binding's own window size — `home`
/// receives tight constraints from the root, so `game.size` ends up being
/// whatever the test surface actually is (800x600 by default), not the
/// SizedBox's width/height. Controlling the surface itself is what makes
/// station positions (and therefore tap coordinates) deterministic.
void _pinViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'showStations() called before the GameWidget has ever laid out does not throw',
    (tester) async {
      _pinViewport(tester, const Size(400, 700));
      final game = AcademicWorldGame(onStationSelected: (_) {});

      // This is exactly the real crash's shape: the station list arrives
      // (here, synchronously) before the widget tree below has been pumped
      // even once, i.e. before Flame's own onGameResize has ever fired and
      // `hasLayout` is still false. It must be a safe no-op, not a
      // `'size' is not ready yet` assertion failure.
      expect(
        () => game.showStations(
          const [
            WorldStation(id: 'g1', label: 'الصف الأول'),
            WorldStation(id: 'g2', label: 'الصف الثاني'),
            WorldStation(id: 'g3', label: 'الصف الثالث'),
          ],
          stepAccent: const Color(0xFF4F46E5),
        ),
        returnsNormally,
      );

      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      // Let Flame's own load/layout/first-frame cycle run.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // No exception should have been recorded by the test binding.
      expect(tester.takeException(), isNull);
      expect(game.hasLayout, isTrue);
      expect(game.size, Vector2(400, 700));

      // A genuine resize after layout is established must also stay safe.
      // (Not pumpAndSettle: the sky/clouds/islands animate continuously,
      // so frames never stop being scheduled.)
      _pinViewport(tester, const Size(250, 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      // And showing a fresh set of stations for a later step must also
      // never throw, mirroring _refreshStations() after a real tap.
      expect(
        () => game.showStations(
          const [WorldStation(id: 'u1', label: 'الفصل الأول')],
          stepAccent: const Color(0xFF0EA5E9),
          selectedId: 'u1',
        ),
        returnsNormally,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tapping a rendered station reports its id — the mechanics that let '
    'the screen advance to the next step',
    (tester) async {
      _pinViewport(tester, const Size(400, 700));
      final tapped = <String>[];
      final game = AcademicWorldGame(onStationSelected: tapped.add);

      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(game.hasLayout, isTrue);
      expect(game.size, Vector2(400, 700));

      // A single station lays out deterministically: horizontally centered
      // (sin(0) == 0) and vertically centered in the usable band between
      // AcademicWorldGame's fixed top/bottom margins — see _layoutStations.
      game.showStations(
        const [WorldStation(id: 'grade-1', label: 'الصف الأول')],
        stepAccent: const Color(0xFF4F46E5),
      );
      // Component.add() queues the new island; it only actually mounts (and
      // registers its TapCallbacks dispatcher) on a subsequent update tick,
      // so give it a couple of real frames before trying to tap it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);

      const topMargin = 110.0;
      const bottomMargin = 130.0;
      const expectedCenter = Offset(400 / 2, topMargin + (700 - topMargin - bottomMargin) / 2);

      // This is the same gesture a student's finger/mouse click sends —
      // routed through Flutter's normal hit-testing into the GameWidget,
      // then into Flame's own TapCallbacks dispatch on the station
      // component, exactly like on a real device.
      await tester.tapAt(expectedCenter);
      await tester.pump();

      expect(tapped, equals(['grade-1']));
      // The tapped station's own bounce effect must not throw either.
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);

      // A real screen wires this callback into _handleStationTap, which
      // applies the pick via the exact _select* method for the current
      // step and then increments _stepIndex — i.e. receiving exactly one
      // id here is what "the screen advances to the next step" reduces to
      // on the game side of that boundary.
    },
  );
}
