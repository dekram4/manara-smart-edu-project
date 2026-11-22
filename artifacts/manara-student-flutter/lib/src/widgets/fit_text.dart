import 'package:flutter/material.dart';

/// نصٌّ يظهر كاملاً في مكانه: يُجرَّب من [maxFont] نزولاً حتى يتّسع في
/// [maxLines] أسطرٍ بعرض المكان وارتفاعه — فلا يُقصّ سطرُه الثاني ولا يختفي.
///
/// يُقاس بمكبّر النصّ في الجهاز ([MediaQuery.textScalerOf])، فمن كبّر خطَّ
/// جواله يرى الكلمةَ كاملةً أيضاً. وإن لم يتّسع حتى بـ[minFont] (اسمٌ طويلٌ
/// جدّاً في بطاقةٍ صغيرة) يُعرض بها في أسطره، لا بنقاطٍ تخفي آخرَه.
class FitText extends StatelessWidget {
  const FitText(
    this.text, {
    super.key,
    required this.style,
    this.maxFont = 18,
    this.minFont = 10,
    this.maxLines = 2,
    this.textAlign = TextAlign.center,
    this.textKey,
  });

  final String text;
  final TextStyle style;
  final double maxFont;
  final double minFont;
  final int maxLines;
  final TextAlign textAlign;

  /// مفتاحُ النصّ الداخليّ، للاختبار.
  final Key? textKey;

  /// أكبرُ خطٍّ يتّسع به [text] في [box].
  static double fontFor({
    required String text,
    required TextStyle style,
    required BoxConstraints box,
    required TextDirection direction,
    TextScaler scaler = TextScaler.noScaling,
    double maxFont = 18,
    double minFont = 10,
    int maxLines = 2,
    TextAlign textAlign = TextAlign.center,
  }) {
    if (!box.hasBoundedWidth) return maxFont;
    for (var size = maxFont; size > minFont; size -= 0.5) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style.copyWith(fontSize: size)),
        maxLines: maxLines,
        textDirection: direction,
        textAlign: textAlign,
        textScaler: scaler,
      )..layout(maxWidth: box.maxWidth);
      final fits = !painter.didExceedMaxLines && (!box.hasBoundedHeight || painter.height <= box.maxHeight + 0.5);
      painter.dispose();
      if (fits) return size;
    }
    return minFont;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final size = fontFor(
          text: text,
          style: style,
          box: box,
          direction: Directionality.of(context),
          scaler: MediaQuery.textScalerOf(context),
          maxFont: maxFont,
          minFont: minFont,
          maxLines: maxLines,
          textAlign: textAlign,
        );
        return Text(
          text,
          key: textKey,
          maxLines: maxLines,
          softWrap: true,
          textAlign: textAlign,
          overflow: TextOverflow.visible,
          style: style.copyWith(fontSize: size),
        );
      });
}
