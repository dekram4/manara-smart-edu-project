import 'dart:math' as math;

import 'package:flutter/material.dart';

/// افتتاحيةُ شاشة البداية — على خطّ زمن مواصفة الحركة (§3)، بعناصر منارة.
///
/// | الزمن      | ما يحدث                                                         |
/// |------------|-----------------------------------------------------------------|
/// | 0.0 – 1.8  | أيقوناتُ بطاقات منارة تهبط من الأعلى نحو الوسط، تدور وتتراكب   |
/// | 0.0 – 2.2  | ضربةُ فرشاةٍ فيروزية-ذهبية تنمو عمودياً خلفها                  |
/// | 1.8 – 2.2  | الأيقوناتُ تصغر وتخرج إلى الأسفل                                |
/// | 2.2 – 2.7  | الضربةُ تستقرّ في مكان الشعار، والشعارُ الأصليّ يقفز            |
/// | 2.7 – 3.2  | اسمُ منارة يُكتب من اليمين إلى اليسار                           |
/// | 3.2 – 4.4  | البطلُ يهبط، وقصاصاتٌ ملوّنة تنفجر حوله وتتلاشى                |
///
/// الشعارُ والاسمُ والبطلُ والصوتُ هي عناصرُ الشاشة الأصلية كما هي؛ هذه الطبقة
/// تضيف ما قبلها وما حولها فقط، وتُرسم بنِسَبٍ من المساحة المتاحة فتصلح للوضعين.
class SplashIntroTimeline {
  const SplashIntroTimeline._();

  static const total = Duration(milliseconds: 4400);

  static const iconsInEnd = 1.8;
  static const strokeEnd = 2.2;
  static const settleEnd = 2.7;
  static const wordmarkEnd = 3.2;
  static const confettiEnd = 4.4;

  /// متى يقفز الشعار ويُكتب الاسم ويبدأ البطل — مِن أوّل إطار.
  static const logoAt = Duration(milliseconds: 2200);
  static const wordmarkAt = Duration(milliseconds: 2700);
  static const wordmarkFor = Duration(milliseconds: 500);

  /// البطلُ يطير 1.55 ثانية قبل أن يهبط، فيبدأ ليهبط عند 3.75 تقريباً —
  /// وسط نافذة «قفز الشخصيات» (3.2 – 3.7).
  static const heroAt = Duration(milliseconds: 2200);

  /// يبدأ الخروجُ الأصلي (الدوران بعيداً) بعد انتهاء القصاصات.
  static const spinOutAt = Duration(milliseconds: 4600);

  /// قيمةُ مرحلةٍ بين [from] و[to] ثانية، من 0 إلى 1، بمنحنى.
  static double phase(
    double seconds,
    double from,
    double to, [
    Curve curve = Curves.linear,
  ]) {
    if (seconds <= from) return 0;
    if (seconds >= to) return 1;
    return curve.transform((seconds - from) / (to - from));
  }
}

/// أيقوناتُ البطاقات التي تهبط في الافتتاحية — رسومُ منارة نفسها.
const _stormIcons = <String>[
  'assets/images/icon_teacher.png',
  'assets/images/icon_cinema.png',
  'assets/images/icon_game.png',
  'assets/images/icon_quez.png',
  'assets/images/icon_ai.png',
  'assets/images/icon_meet.png',
  'assets/images/icon_chat.png',
  'assets/images/book.png',
];

/// الطبقةُ الخلفية: الأيقوناتُ الهابطة وضربةُ الفرشاة.
class SplashIconStorm extends StatelessWidget {
  const SplashIconStorm({required this.animation, super.key});

  /// من 0 إلى 1 على [SplashIntroTimeline.total].
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final shortest = size.shortestSide;
        final iconSize = (shortest * 0.17).clamp(48.0, 118.0).toDouble();
        final center = Offset(size.width / 2, size.height * 0.40);

        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final s = animation.value * SplashIntroTimeline.total.inMilliseconds / 1000;
            if (s >= SplashIntroTimeline.settleEnd) return const SizedBox.shrink();

            final exit = SplashIntroTimeline.phase(
              s,
              SplashIntroTimeline.iconsInEnd,
              SplashIntroTimeline.strokeEnd,
              Curves.easeInCubic,
            );

            final icons = <Widget>[];
            for (var i = 0; i < _stormIcons.length; i++) {
              // كلُّ أيقونةٍ تتأخّر عن سابقتها قليلاً، وتصل قبل 1.8.
              final start = i * 0.11;
              final arrive = SplashIntroTimeline.phase(
                s,
                start,
                start + 0.95,
                Curves.easeOutBack,
              );
              if (arrive == 0) continue;
              // تنتشر حول المركز في حلقةٍ صغيرة فتتراكب ولا تتطابق.
              final angle = i / _stormIcons.length * math.pi * 2;
              final rest = center +
                  Offset(math.cos(angle), math.sin(angle)) * shortest * 0.13;
              final from = Offset(
                size.width * (0.12 + 0.76 * ((i * 37) % 8) / 7),
                -iconSize * 1.5,
              );
              final position = Offset.lerp(from, rest, arrive)! +
                  Offset(0, exit * size.height * 0.35);
              final spin = (1 - arrive) * (i.isEven ? 1 : -1) * math.pi * 1.6 +
                  math.sin(s * 3 + i) * 0.12;
              final scale = (0.55 + 0.45 * arrive) * (1 - exit);
              icons.add(Positioned(
                left: position.dx - iconSize / 2,
                top: position.dy - iconSize / 2,
                child: Opacity(
                  opacity: (1 - exit).clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: spin,
                    child: Transform.scale(
                      scale: scale,
                      child: Image.asset(
                        _stormIcons[i],
                        width: iconSize,
                        height: iconSize,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            SizedBox(width: iconSize, height: iconSize),
                      ),
                    ),
                  ),
                ),
              ));
            }

            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BrushStrokePainter(seconds: s, center: center, shortest: shortest),
                  ),
                ),
                ...icons,
              ],
            );
          },
        );
      },
    );
  }
}

/// ضربةُ الفرشاة: تنمو من الأسفل إلى الأعلى حتى 2.2، ثم تنكمش في مكان الشعار.
class _BrushStrokePainter extends CustomPainter {
  _BrushStrokePainter({
    required this.seconds,
    required this.center,
    required this.shortest,
  });

  final double seconds;
  final Offset center;
  final double shortest;

  @override
  void paint(Canvas canvas, Size size) {
    final grow = SplashIntroTimeline.phase(
      seconds,
      0,
      SplashIntroTimeline.strokeEnd,
      const Cubic(0.2, 0.0, 0.0, 1.0),
    );
    final settle = SplashIntroTimeline.phase(
      seconds,
      SplashIntroTimeline.strokeEnd,
      SplashIntroTimeline.settleEnd,
      Curves.easeInOutCubic,
    );
    if (grow == 0) return;

    final fullLength = shortest * 0.62;
    final length = fullLength * grow * (1 - settle * 0.85);
    final width = shortest * 0.11 * (1 - settle * 0.6);
    // تستقرّ في مكانها: تنكمش نحو منتصفها وتبهت، والشعارُ يقفز في الموضع نفسه.
    // أثناء النموّ قاعدتُها ثابتة أسفل المركز؛ وأثناء الاستقرار تنتقل إلى
    // حيث يتوسّطها المركز.
    final bottom = Offset(
      center.dx,
      center.dy + (fullLength / 2) * (1 - settle) + (length / 2) * settle,
    );
    final top = bottom - Offset(0, length);

    // منحنٍ قليلاً كضربة يد، لا عمودٌ مسطور.
    final path = Path()
      ..moveTo(bottom.dx, bottom.dy)
      ..quadraticBezierTo(
        bottom.dx + width * 0.9,
        (bottom.dy + top.dy) / 2,
        top.dx,
        top.dy,
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFF0B8693).withValues(alpha: 1 - settle),
          const Color(0xFFF2B84B).withValues(alpha: 1 - settle),
        ],
      ).createShader(Rect.fromPoints(top - Offset(width, 0), bottom + Offset(width, 0)));
    canvas.drawPath(path, paint);

  }

  @override
  bool shouldRepaint(covariant _BrushStrokePainter old) =>
      old.seconds != seconds || old.center != center || old.shortest != shortest;
}

/// قصاصاتٌ ملوّنة تنفجر حول البطل بين 3.2 و4.4 ثم تتلاشى.
class SplashConfettiBurst extends StatelessWidget {
  const SplashConfettiBurst({required this.animation, super.key});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final s = animation.value * SplashIntroTimeline.total.inMilliseconds / 1000;
          final t = SplashIntroTimeline.phase(
            s,
            SplashIntroTimeline.wordmarkEnd,
            SplashIntroTimeline.confettiEnd,
          );
          if (t == 0 || t == 1) return const SizedBox.shrink();
          return CustomPaint(painter: _ConfettiPainter(t), size: Size.infinite);
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);

  final double t;

  static const _colors = [
    Color(0xFF0B8693),
    Color(0xFFF2B84B),
    Color(0xFFE05A86),
    Color(0xFF8B5CF6),
    Color(0xFF16A085),
    Color(0xFF1394D2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    final origin = Offset(size.width / 2, size.height * 0.56);
    final ease = Curves.easeOutCubic.transform(t);
    final fade = 1 - Curves.easeInQuad.transform(t);
    const count = 42;
    for (var i = 0; i < count; i++) {
      // ثابتةٌ لكل قصاصة: الاتجاهُ والسرعةُ من رقمها لا من عشوائيٍّ يتغيّر كل إطار.
      final angle = i / count * math.pi * 2 + (i % 3) * 0.17;
      final speed = shortest * (0.28 + 0.22 * ((i * 53) % 10) / 9);
      final gravity = shortest * 0.32 * t * t;
      final p = origin +
          Offset(math.cos(angle), math.sin(angle)) * speed * ease +
          Offset(0, gravity);
      final w = shortest * (0.012 + 0.010 * (i % 3));
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(angle + t * (i.isEven ? 9 : -7));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: w * 1.8),
          Radius.circular(w * 0.3),
        ),
        Paint()..color = _colors[i % _colors.length].withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

/// كتابةُ الاسم: يُكشف من اليمين إلى اليسار (اتجاه العربية) بحافّةٍ ناعمة.
class SplashWordmarkWipe extends StatelessWidget {
  const SplashWordmarkWipe({required this.progress, required this.child, super.key});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (progress >= 1) return child;
    // قبل دوره لا يُرى منه حرف: الحافّةُ الناعمة كانت تُبدي أوّلَه قبل أن يبدأ.
    if (progress <= 0) return Opacity(opacity: 0, child: child);
    final rtl = Directionality.maybeOf(context) != TextDirection.ltr;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        // الحافّةُ الناعمة خلفَ موضع الكتابة لا أمامه: من 0 إلى 1.1 فتكتمل.
        final edge = progress * 1.1;
        return LinearGradient(
          begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
          end: rtl ? Alignment.centerLeft : Alignment.centerRight,
          colors: const [Colors.white, Colors.white, Colors.transparent, Colors.transparent],
          stops: [
            0,
            (edge - 0.1).clamp(0.0, 1.0),
            edge.clamp(0.0, 1.0),
            1,
          ],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}
