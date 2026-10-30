import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// رسمةُ خلفيةٍ تملأ الشاشة دون أن تتضخّم في الوضع الأفقي.
///
/// ── رأسياً ──
/// تملأ الشاشةَ (`cover`) وتنجرف ببطءٍ شديد.
///
/// ── أفقياً ──
/// كانت تُكبَّر حتى تملأ العرض، فتُقصّ من أعلاها وأسفلها وتبدو متضخّمة —
/// ورسمةُ الدخول رأسيّةٌ أصلاً فكان يُرى منها شريطٌ في وسطها. فتُعرض الآن
/// كاملةً (`contain`) في الوسط بلا تكبير، تطفو طفواً خفيفاً، وما حولها نسخةٌ
/// منها مموّهةٌ تملأ الحوافّ — فلا شرائطَ فارغة ولا قصّ.
class FittedArtBackdrop extends StatelessWidget {
  const FittedArtBackdrop({
    required this.asset,
    required this.drift,
    this.imageKey,
    this.blur = 0,
    super.key,
  });

  final String asset;

  /// من ٠ إلى ١ ذهاباً وإياباً: الانجرافُ رأسياً، والطفوُ أفقياً.
  final Animation<double> drift;
  final Key? imageKey;

  /// تمويهٌ يسير للرسمة نفسها، لتهدأ تحت ما فوقها.
  final double blur;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final width = box.maxWidth.isFinite ? box.maxWidth : 800.0;
      final height = box.maxHeight.isFinite ? box.maxHeight : 600.0;
      final landscape = width > height;
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final cache = (math.max(width, height) * dpr).clamp(360.0, 2200.0).round();

      Widget image(BoxFit fit, {Key? key}) => Image.asset(
            asset,
            key: key,
            fit: fit,
            cacheWidth: cache,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFEFF5FB)),
          );

      Widget soften(Widget child) => blur <= 0
          ? child
          : ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: child);

      if (!landscape) {
        return AnimatedBuilder(
          animation: drift,
          child: soften(image(BoxFit.cover, key: imageKey)),
          builder: (context, child) {
            final t = Curves.easeInOutSine.transform(drift.value);
            return Transform.scale(
              scale: 1.03 + 0.02 * t,
              alignment: Alignment(-0.4 + 0.8 * t, 0),
              child: child,
            );
          },
        );
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          // ‏الحوافُّ: الرسمةُ نفسها مموّهةً بقوّة، فلا يُرى فيها شيءٌ يشتّت.
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: image(BoxFit.cover),
          ),
          AnimatedBuilder(
            animation: drift,
            child: soften(image(BoxFit.contain, key: imageKey)),
            builder: (context, child) {
              final t = Curves.easeInOutSine.transform(drift.value);
              return Transform.translate(offset: Offset(0, -4 + 8 * t), child: child);
            },
          ),
        ],
      );
    });
  }
}
