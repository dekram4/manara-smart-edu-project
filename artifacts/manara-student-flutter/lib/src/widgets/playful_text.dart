import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Playful lettering for the child-facing screens: a rounded kids' face and
/// a rainbow sweep across the words.
///
/// The colour is painted as a gradient over the whole line rather than a
/// colour per letter. Arabic joins: «أهلاً» is one connected shape, and
/// splitting it into a span per character breaks the shaping — the letters
/// come apart and the word stops being a word. A shader leaves one run of
/// text and tints what is already drawn, so the joins survive and the
/// rainbow lands anyway.
///
/// The face is Baloo Bhaijaan 2 — rounded, heavy, and one of the few
/// playful families with real Arabic coverage. `google_fonts` falls back to
/// the app's Tajawal when it cannot fetch, so a child offline still reads a
/// sensible headline instead of tofu.
class StudentPlayfulFont {
  const StudentPlayfulFont._();

  static TextStyle style({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w800,
    Color? color,
    double? height,
    List<Shadow>? shadows,
  }) =>
      GoogleFonts.balooBhaijaan2(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        shadows: shadows,
      );
}

/// The bright sweep used for headings a child reads first.
///
/// Warm to cool and back, so no matter where a short word lands on the line
/// it picks up more than one hue — a two-stop gradient leaves a three-letter
/// name looking flatly orange.
const List<Color> kStudentRainbow = [
  Color(0xFFFF4D6D), // strawberry
  Color(0xFFFF9F1C), // mango
  Color(0xFFFFD60A), // sunshine
  Color(0xFF2EC4B6), // mint
  Color(0xFF3A86FF), // sky
  Color(0xFF9B5DE5), // grape
];

/// Text with a rainbow poured across it.
///
/// A soft dark drop sits behind the letters: the gradient is bright, and
/// bright on a bright panel is unreadable. The shadow is drawn from a second
/// copy underneath rather than `TextStyle.shadows`, because a `ShaderMask`
/// tints the shadow too and a rainbow shadow is just a blur.
class RainbowText extends StatelessWidget {
  const RainbowText(
    this.text, {
    super.key,
    required this.fontSize,
    this.colors = kStudentRainbow,
    this.fontWeight = FontWeight.w900,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.shadowed = true,
    this.height,
  });

  final String text;
  final double fontSize;
  final List<Color> colors;
  final FontWeight fontWeight;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool shadowed;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final base = StudentPlayfulFont.style(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: Colors.white,
      height: height,
    );

    final painted = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: colors,
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
      ).createShader(bounds),
      child: Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        style: base,
      ),
    );

    if (!shadowed) return painted;

    return Stack(
      children: [
        // The drop, outside the mask so it stays a plain dark blur.
        Positioned(
          top: 2,
          right: 0,
          left: 0,
          child: Text(
            text,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
            style: base.copyWith(
              color: Colors.transparent,
              shadows: const [
                Shadow(color: Color(0x40000000), blurRadius: 6),
              ],
            ),
          ),
        ),
        painted,
      ],
    );
  }
}
