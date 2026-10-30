import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// رسمةُ خلفيةٍ تملأ الشاشة بلا تكبيرٍ زائد.
///
/// ── ملءٌ بلا تكبير ──
/// تملأ الشاشةَ (`cover`) بمقاسها لا أكبر، وما زاد منها عن الشاشة لا يُرمى:
/// تنجرف عليه انجرافاً بطيئاً — جانبياً في الشاشة الرأسية (الزائدُ يمينٌ
/// ويسار)، وعمودياً في الأفقية (الزائدُ أعلى وأسفل) — فيُرى كلُّه مع الوقت.
///
/// ── أو كاملةً في الأفقيّ ──
/// [containInLandscape]: الرسمةُ كاملةً (`contain`) في الوسط، تطفو طفواً
/// خفيفاً، وحولها نسخةٌ منها مموّهةٌ تملأ الحوافّ.
class FittedArtBackdrop extends StatelessWidget {
  const FittedArtBackdrop({
    required this.asset,
    required this.drift,
    this.imageKey,
    this.blur = 0,
    this.containInLandscape = false,
    super.key,
  });

  final bool containInLandscape;

  final String asset;

  /// من ٠ إلى ١ ذهاباً وإياباً: الانجرافُ على ما زاد من الرسمة، أو طفوُها كاملةً.
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

      if (!landscape || !containInLandscape) {
        // ‏`Image` يحاذي ما يُقصّ بمحاذاته: فالانجرافُ تغييرُ المحاذاة لا تكبيرٌ.
        return AnimatedBuilder(
          animation: drift,
          builder: (context, _) {
            final t = Curves.easeInOutSine.transform(drift.value) * 2 - 1;
            return soften(Image.asset(
              asset,
              key: imageKey,
              fit: BoxFit.cover,
              alignment: landscape ? Alignment(0, t * 0.8) : Alignment(t * 0.8, 0),
              cacheWidth: cache,
              errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFEFF5FB)),
            ));
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
