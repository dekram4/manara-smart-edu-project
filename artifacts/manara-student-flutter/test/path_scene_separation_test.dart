import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/widgets/masar_path_board.dart';

/// The path scene is placed by fractions over a single stretched painting, so
/// nothing about it is caught by an overflow check — two elements can sit
/// squarely on top of each other and lay out perfectly. Every collision in this
/// scene so far was found by rendering it and looking, and fixed by hand:
/// foliage growing across the schoolhouse wall, a character standing on the
/// window glass of the "الفصل" square, the speech bubble covering the
/// "تحدَّ واكسب!" plaque, and a wide band of empty sky between the bubble and
/// the characters it belongs to.
///
/// These are those four fixes, written down as the separations they have to
/// keep.
void main() {
  /// The shapes the scene actually has to survive. The bubble's gap is a
  /// function of the window's aspect — it was invisible in landscape and 153px
  /// wide on a portrait tablet — so a single size proves nothing here.
  const shapes = <String, Size>{
    'landscape tablet 1024x768': Size(1024, 768),
    'portrait tablet 768x1024': Size(768, 1024),
    'portrait phone 393x851': Size(393, 851),
    'landscape phone 851x393': Size(851, 393),
  };

  test('nothing on the left of the scene reaches the schoolhouse', () {
    // The wall starts at 0.330 and the window frame at 0.343. The tree patch
    // ran to 0.378 and the right-hand figure to 0.356 — both over the glass.
    expect(MasarPathLayout.childrenPatch.right,
        lessThanOrEqualTo(MasarPathLayout.wallLeft));
    for (final layout in MasarPathLayout.cheerSpotLayouts) {
      for (final spot in layout) {
        expect(spot.right, lessThanOrEqualTo(MasarPathLayout.wallLeft));
        expect(spot.right, lessThan(MasarPathLayout.windowLeft));
        expect(spot.left, greaterThanOrEqualTo(0.0),
            reason: 'a character ran off the left edge of the screen');
      }
    }
  });

  test('on an upright screen the characters are 25-35% larger, feet unmoved',
      () {
    // Upright, the figures are limited by their boxes' width, so the width
    // of the box is the size of the character.
    const portrait = Size(768, 1024);
    const landscape = Size(1024, 768);
    final tall = MasarPathLayout.cheerSpotsFor(portrait);
    final wide = MasarPathLayout.cheerSpotsFor(landscape);
    for (var i = 0; i < tall.length; i++) {
      final growth = tall[i].width / wide[i].width;
      expect(growth, inInclusiveRange(1.25, 1.35),
          reason: 'character $i grew by ${((growth - 1) * 100).round()}%');
      // Standing on the same ground, so the growth goes up and out — never
      // down into the start button across the foot.
      expect(tall[i].bottom, wide[i].bottom);
    }
  });

  test('the speech bubble starts below the lowest hanging sign', () {
    // Its designed top, before any per-size adjustment — and the adjustment
    // only ever pushes it down, never up, which the per-shape test below
    // re-checks against the sign itself.
    expect(MasarPathLayout.speechBubble.top,
        greaterThanOrEqualTo(MasarPathLayout.lowestSign.bottom));
  });

  for (final entry in shapes.entries) {
    test('the bubble clears its speaker but still points at them on '
        '${entry.key}', () {
      final size = entry.value;
      final bubble = MasarPathLayout.bubbleFor(size);
      final headTop = MasarPathLayout.headTopFor(size);
      final signBottom = MasarPathLayout.lowestSign.bottom * size.height;

      // It must never climb into the plaque above it, whatever else gives.
      expect(bubble.top, greaterThanOrEqualTo(signBottom),
          reason: 'the bubble rose into the "تحدَّ واكسب!" sign');

      // Nor sink past the head into the character's body.
      expect(bubble.bottom - headTop, lessThan(size.height * 0.08),
          reason: 'the bubble sat too far down over the character');

      // A short landscape phone leaves only a couple of pixels between the
      // sign and where the bubble would sit, so there is no room to lift it
      // there; the sign wins. Everywhere else it has to clear the head.
      final highestAllowed = MasarPathLayout.speechBubble.top * size.height;
      final pinnedUnderSign = bubble.top <= highestAllowed + 0.5;
      if (pinnedUnderSign) return;

      // Breathing room between the bubble's body and the heads — the bubble
      // used to sit right on them.
      final body = bubble.bottom - bubble.height * MasarPathLayout.tailShare;
      final clearance = headTop - body;
      expect(clearance, greaterThanOrEqualTo(15.0),
          reason: 'only ${clearance.round()}px between bubble and head');

      // But the tail still reaches the head: a bubble floating in the sky
      // with nothing pointing at the speaker belongs to nobody — the gap
      // portrait used to show.
      final tailGap = headTop - bubble.bottom;
      expect(tailGap.abs(), lessThanOrEqualTo(8.0),
          reason: 'the tail stops ${tailGap.round()}px from the head');
    });
  }
}
