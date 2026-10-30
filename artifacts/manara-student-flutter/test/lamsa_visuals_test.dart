import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/widgets/living_tile_art.dart';

/// الرسومُ الحيّة: تعمل في الوضعين بلا فيضان.
void main() {
  const shapes = {
    'هاتف رأسي': Size(390, 844),
    'هاتف أفقي': Size(844, 390),
    'لوح أفقي': Size(1280, 800),
  };

  for (final entry in shapes.entries) {
    testWidgets('كل حركات الرسوم الحيّة (${entry.key})', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final side = entry.value.shortestSide * 0.3;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Wrap(children: [
            for (final motion in TileArtMotion.values)
              SizedBox(
                width: side,
                height: side,
                child: LivingTileArt(
                  motion: motion,
                  accent: Colors.teal,
                  index: motion.index,
                  child: const ColoredBox(color: Colors.amber),
                ),
              ),
          ]),
        ),
      ));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 450));
      }
      expect(tester.takeException(), isNull);

      // اللمس يقفز بالرسمة ويُديرها ثم يُعيدها.
      await tester.tap(find.byType(LivingTileArt).first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });
  }

  test('لكل بوابةٍ حركتُها', () {
    expect(tileArtMotionFor('portal.cinema'), TileArtMotion.sway);
    expect(tileArtMotionFor('portal.games'), TileArtMotion.hop);
    expect(tileArtMotionFor('portal.meeting'), TileArtMotion.broadcast);
    expect(tileArtMotionFor('portal.study'), TileArtMotion.flip);
    expect(tileArtMotionFor('portal.tutor'), TileArtMotion.nod);
  });

  testWidgets('حركةٌ أقلّ: الرسمةُ ثابتةٌ كما هي', (tester) async {
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: LivingTileArt(
          motion: TileArtMotion.hop,
          accent: Colors.teal,
          child: Text('رسمة'),
        ),
      ),
    ));
    expect(tester.hasRunningAnimations, isFalse);
    expect(
      find.descendant(of: find.byType(LivingTileArt), matching: find.byType(Transform)),
      findsNothing,
    );
  });
}
