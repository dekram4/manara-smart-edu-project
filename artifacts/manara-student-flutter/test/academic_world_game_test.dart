import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/screens/game_world/academic_world_game.dart';

void main() {
  testWidgets(
    'showStations() called before the GameWidget has ever laid out does not throw',
    (tester) async {
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

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 700,
            child: GameWidget(game: game),
          ),
        ),
      );
      // Let Flame's own load/layout/first-frame cycle run.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // No exception should have been recorded by the test binding.
      expect(tester.takeException(), isNull);
      expect(game.hasLayout, isTrue);

      // A genuine resize after layout is established must also stay safe.
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 250,
            height: 500,
            child: GameWidget(game: game),
          ),
        ),
      );
      await tester.pump();
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
}
