import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'playful_text.dart';

/// Cartoon lettering that dances: pieces tilted, lifted, resized and
/// recoloured so a heading reads as drawn by hand rather than set by a
/// machine.
///
/// ## Why it splits by word in Arabic and by letter elsewhere
///
/// Latin letters stand alone, so each one can be tilted on its own. Arabic
/// letters *join*: a letter takes a different shape depending on what sits
/// beside it, and «أهلاً» is one connected ribbon of ink. Put each character
/// in its own widget and the shaper loses every neighbour — each letter
/// falls back to its isolated form and the word comes apart into أ ه ل ا.
/// It is not a smaller version of the effect; it is a misspelling.
///
/// So the unit of bounce is the largest piece that can move without
/// breaking: a whole word where the script joins, a single character where
/// it does not. Phrases carry several words, which is where the dance
/// actually shows — and a one-word Arabic heading still tilts, colours and
/// bobs as a piece.
///
/// ## Why the variation is computed, not random
///
/// Every tilt and lift comes from the piece's index. `Random()` would draw
/// new values on each rebuild, so the heading would twitch whenever
/// anything above it changed — a scroll, a theme flip, a rebuilt parent.
/// Derived from the index, the arrangement is the same every time: it looks
/// hand-placed because it is, and it holds still because it is a function.
class BouncyText extends StatelessWidget {
  const BouncyText(
    this.text, {
    super.key,
    required this.fontSize,
    this.colors = kStudentCandy,
    this.alignment = WrapAlignment.start,
    this.animate = true,
    this.outlineColor = Colors.white,
    this.maxScale = 1.16,
    this.minScale = 0.9,
  });

  final String text;
  final double fontSize;
  final List<Color> colors;
  final WrapAlignment alignment;

  /// The idle bob. Off for a still frame, and off automatically when the
  /// platform asks for reduced motion.
  final bool animate;

  /// The cartoon rim drawn behind the fill. White by default: it is what
  /// keeps a bright letter legible over a busy or photographic backdrop.
  final Color outlineColor;

  final double maxScale;
  final double minScale;

  /// The pieces, in order, each with the pattern index it bounces on.
  ///
  /// Whitespace is dropped: the `Wrap` supplies the gaps, and keeping space
  /// characters as pieces would give them tilts and colours of their own.
  static List<String> pieces(String text) {
    final out = <String>[];
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      if (_joins(word)) {
        out.add(word);
      } else {
        out.addAll(word.characters);
      }
    }
    return out;
  }

  /// Does this word belong to a script whose letters connect?
  ///
  /// Arabic and its extensions, plus the presentation-form blocks that some
  /// older content still carries. One joining character is enough: a word
  /// mixing scripts must stay whole too, or the Arabic part of it breaks.
  static bool _joins(String word) => word.runes.any((r) =>
      (r >= 0x0600 && r <= 0x08FF) || (r >= 0xFB50 && r <= 0xFEFF));

  @override
  Widget build(BuildContext context) {
    final parts = pieces(text);
    // The platform's reduced-motion switch is a request, not a preference
    // to weigh: a child who gets motion sick from a bobbing headline is not
    // helped by a gentler bob.
    final moving = animate && !MediaQuery.of(context).disableAnimations;

    return Wrap(
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: fontSize * 0.22,
      runSpacing: fontSize * 0.12,
      children: [
        for (var i = 0; i < parts.length; i++)
          _BouncyPiece(
            text: parts[i],
            index: i,
            fontSize: fontSize,
            color: colors[i % colors.length],
            outlineColor: outlineColor,
            scale: i.isEven ? maxScale : minScale,
            moving: moving,
          ),
      ],
    );
  }
}

/// The bright, high-contrast set a child's eye picks out first: sky, mango,
/// bubblegum, sunshine, grass, grape. Ordered so neighbours never share a
/// hue family — adjacent pieces have to read as different colours, not as
/// two shades of the same one.
const List<Color> kStudentCandy = [
  Color(0xFF29B6F6), // sky blue
  Color(0xFFFF8A29), // bright orange
  Color(0xFFFF5D8F), // bubblegum pink
  Color(0xFFFFC61A), // warm yellow
  Color(0xFF3FBF5F), // grass green
  Color(0xFF9B5DE5), // grape
];

/// One word or one letter, tilted and lifted, with a rim and a drop.
class _BouncyPiece extends StatelessWidget {
  const _BouncyPiece({
    required this.text,
    required this.index,
    required this.fontSize,
    required this.color,
    required this.outlineColor,
    required this.scale,
    required this.moving,
  });

  final String text;
  final int index;
  final double fontSize;
  final Color color;
  final Color outlineColor;
  final double scale;
  final bool moving;

  /// Tilt in radians, alternating sides and never the same twice running.
  ///
  /// Four steps rather than two: strict alternation between one angle and
  /// its negative reads as a zigzag pattern, which is a machine again. The
  /// cycle -4°, +3°, -2.5°, +4° keeps the hand-drawn look.
  double get _angle {
    const degrees = [-4.0, 3.0, -2.5, 4.0];
    return degrees[index % degrees.length] * math.pi / 180;
  }

  /// The lift, in the 2–4px the design asks for, scaled with the type so a
  /// small caption does not bounce as far as a headline.
  double get _dy {
    const steps = [-3.0, 2.0, -2.0, 3.0];
    return steps[index % steps.length] * (fontSize / 26).clamp(0.6, 1.6);
  }

  @override
  Widget build(BuildContext context) {
    final size = fontSize * scale;
    final base = StudentPlayfulFont.style(
      fontSize: size,
      fontWeight: FontWeight.w900,
      height: 1.1,
    );

    final piece = Transform.translate(
      offset: Offset(0, _dy),
      child: Transform.rotate(
        angle: _angle,
        child: Stack(
          children: [
            // The rim: the same glyphs drawn as a thick stroke underneath,
            // so the fill on top leaves an even outline all the way round.
            // A `Shadow` cannot do this — a blur is not an edge.
            Text(
              text,
              style: base.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = size * 0.11
                  ..strokeJoin = StrokeJoin.round
                  ..color = outlineColor,
              ),
            ),
            Text(
              text,
              style: base.copyWith(
                color: color,
                shadows: [
                  // A hard offset drop, not a blur: cartoon lettering sits
                  // on its shadow rather than floating over a haze.
                  Shadow(
                    color: Color.lerp(color, Colors.black, 0.45)!,
                    offset: Offset(0, size * 0.055),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!moving) return piece;

    // Each piece starts a little later than the one before it, so the line
    // ripples along instead of heaving as one block. The delay wraps every
    // six pieces to keep a long phrase from starting its tail a second in.
    return piece
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(
          begin: 0,
          end: -2.5,
          duration: 1700.ms,
          delay: (120 * (index % 6)).ms,
          curve: Curves.easeInOut,
        );
  }
}
