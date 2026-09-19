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
    for (final spot in MasarPathLayout.cheerSpots) {
      expect(spot.right, lessThanOrEqualTo(MasarPathLayout.wallLeft));
      expect(spot.right, lessThan(MasarPathLayout.windowLeft));
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
    test('the bubble is joined to its speaker on ${entry.key}', () {
      final size = entry.value;
      final bubble = MasarPathLayout.bubbleFor(size);
      final headTop = MasarPathLayout.headTopFor(size);

      // Negative is the requirement, not merely tolerated: the bubble has to
      // lap over the head. A positive number here is a band of sky between a
      // character and the thing they are supposedly saying, which is exactly
      // what portrait used to show.
      final gap = headTop - bubble.bottom;
      expect(gap, lessThanOrEqualTo(0.0),
          reason: 'a ${gap.round()}px gap opened above the speaker');

      // But not swallowing them: the bubble must not reach past the head into
      // the body.
      expect(bubble.bottom - headTop, lessThan(size.height * 0.08),
          reason: 'the bubble sat too far down over the character');

      // And it still must not climb into the plaque above it.
      expect(bubble.top,
          greaterThanOrEqualTo(MasarPathLayout.lowestSign.bottom * size.height),
          reason: 'the bubble rose into the "تحدَّ واكسب!" sign');
    });
  }
}
