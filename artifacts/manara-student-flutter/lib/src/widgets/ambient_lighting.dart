import 'dart:math' as math;

import 'package:flutter/material.dart';

/// نوعُ مصدر الضوء في المشهد.
enum AmbientKind {
  /// هالةٌ ملوّنة ناعمة تتنفّس.
  orb,

  /// فانوسٌ دافئ: هالةٌ بقلبٍ ساطع ترتجف قليلاً كاللهب.
  lantern,

  /// مصباحُ مكتب: قرصٌ مضيء وضوءٌ مخروطيّ ينسكب إلى أسفل.
  lamp,

  /// كشّافٌ من أعلى: مخروطٌ أعرض وبقعةُ ضوءٍ على الأرض.
  spotlight,

  /// ساعةٌ مضيئة تعرض الوقتَ الحقيقيّ.
  clock,
}

/// مصدرُ ضوءٍ واحد، موضعُه نسبةٌ من الشاشة وحجمُه نسبةٌ من ضلعها الأقصر.
class AmbientLight {
  const AmbientLight(
    this.kind,
    this.at,
    this.color, {
    this.size = 0.4,
    this.phase = 0,
    this.strength = 1,
  });

  final AmbientKind kind;
  final Offset at;
  final Color color;
  final double size;

  /// إزاحةٌ في دورة التنفّس (٠–١) كي لا تنبض الأضواءُ معاً.
  final double phase;
  final double strength;
}

/// إضاءةُ كلِّ بوابةٍ في الوضع الداكن، على قدر مشهدها: فانوسٌ للمحادثة،
/// ساعةٌ للاختبار، كشّافُ عرضٍ للسينما، أضواءُ حفلٍ للألعاب...
class AmbientScenes {
  const AmbientScenes._();

  static const _warm = Color(0xFFFFC46B);
  static const _amber = Color(0xFFFFA94D);
  static const _cream = Color(0xFFFFF1CF);

  static List<AmbientLight> of(String asset) =>
      _scenes[asset.split('/').last] ?? _fallback;

  static const _fallback = [
    AmbientLight(AmbientKind.orb, Offset(0.86, 0.12), _warm, size: 0.55),
    AmbientLight(AmbientKind.orb, Offset(0.10, 0.92), Color(0xFF7C9CFF),
        size: 0.45, phase: 0.5, strength: 0.7),
  ];

  static const _clockScene = [
    AmbientLight(AmbientKind.clock, Offset(0.90, 0.17), _cream, size: 0.24),
    AmbientLight(AmbientKind.orb, Offset(0.08, 0.88), Color(0xFF8B7CFF),
        size: 0.5, phase: 0.4, strength: 0.7),
  ];

  static const _scenes = <String, List<AmbientLight>>{
    // الدرس: مصباحُ مكتبٍ دافئ في الزاوية، وتوهّجٌ هادئٌ عند السبّورة.
    'back_teach2.png': [
      AmbientLight(AmbientKind.lamp, Offset(0.86, 0.02), _warm, size: 0.42),
      AmbientLight(AmbientKind.orb, Offset(0.14, 0.30), Color(0xFF7FD3FF),
          size: 0.42, phase: 0.45, strength: 0.6),
    ],
    // الألعاب: أضواءُ حفلٍ ملوّنة تتناوب.
    'back_game.png': [
      AmbientLight(AmbientKind.orb, Offset(0.12, 0.18), Color(0xFFB57BFF),
          size: 0.5),
      AmbientLight(AmbientKind.orb, Offset(0.88, 0.30), Color(0xFF4FE3E8),
          size: 0.48, phase: 0.33),
      AmbientLight(AmbientKind.orb, Offset(0.55, 0.96), Color(0xFFFF6FB5),
          size: 0.5, phase: 0.66, strength: 0.8),
    ],
    // السينما: شعاعُ جهاز العرض من أعلى.
    'back_cinema.png': [
      AmbientLight(AmbientKind.spotlight, Offset(0.5, -0.04), Color(0xFFBFD8FF),
          size: 0.55),
      AmbientLight(AmbientKind.orb, Offset(0.92, 0.85), _amber,
          size: 0.35, phase: 0.5, strength: 0.6),
    ],
    // الشخصيّة: فانوسٌ دافئ.
    'back_teach.png': [
      AmbientLight(AmbientKind.lantern, Offset(0.88, 0.18), _amber, size: 0.42),
      AmbientLight(AmbientKind.orb, Offset(0.10, 0.85), Color(0xFF9C8CFF),
          size: 0.45, phase: 0.5, strength: 0.6),
    ],
    // المعلّم الافتراضيّ: كشّافُ مسرحٍ على المعلّم.
    'back_avatar.png': [
      AmbientLight(AmbientKind.spotlight, Offset(0.5, -0.04), _cream,
          size: 0.5),
      AmbientLight(AmbientKind.orb, Offset(0.08, 0.20), Color(0xFF6FD6FF),
          size: 0.38, phase: 0.5, strength: 0.6),
    ],
    // اللقاء المباشر: وهجُ شاشةٍ زرقاء ومصباحٌ دافئ.
    'back_meet.png': [
      AmbientLight(AmbientKind.orb, Offset(0.5, 0.28), Color(0xFF5CC8FF),
          size: 0.6, strength: 0.8),
      AmbientLight(AmbientKind.lamp, Offset(0.12, 0.02), _warm,
          size: 0.36, phase: 0.5),
    ],
    // الاختبار والتحدّي: ساعةٌ مضيئة.
    'back_quez.png': _clockScene,
    'back_endless.png': _clockScene,
    // حلّ المسائل: مصباحُ فكرةٍ أصفر يرتجف.
    'back_hal.png': [
      AmbientLight(AmbientKind.lantern, Offset(0.86, 0.14), Color(0xFFFFE066),
          size: 0.4),
      AmbientLight(AmbientKind.orb, Offset(0.12, 0.88), Color(0xFF6FE3B0),
          size: 0.42, phase: 0.5, strength: 0.6),
    ],
    // المحادثة: فانوسٌ دافئ.
    'back_chat.png': [
      AmbientLight(AmbientKind.lantern, Offset(0.12, 0.18), _amber, size: 0.42),
      AmbientLight(AmbientKind.orb, Offset(0.9, 0.88), Color(0xFF7FB2FF),
          size: 0.4, phase: 0.5, strength: 0.6),
    ],
    // المذاكرة: مصباحُ قراءةٍ فوق الكتاب.
    'back_book.webp': [
      AmbientLight(AmbientKind.lamp, Offset(0.84, 0.02), _warm, size: 0.45),
      AmbientLight(AmbientKind.orb, Offset(0.12, 0.85), Color(0xFF8FD3FF),
          size: 0.4, phase: 0.5, strength: 0.6),
    ],
  };
}

/// طبقةُ إضاءةٍ ناعمة فوق خلفية البوابة في الوضع الداكن.
///
/// محرّكٌ واحد ورسّامٌ واحد خلف [RepaintBoundary]، ولا يلتقط اللمس.
/// ومع «تقليل الحركة» تثبت الأضواء في منتصف نَفَسها.
class AmbientLighting extends StatefulWidget {
  const AmbientLighting({required this.lights, super.key});

  final List<AmbientLight> lights;

  @override
  State<AmbientLighting> createState() => _AmbientLightingState();
}

class _AmbientLightingState extends State<AmbientLighting>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _cycle
        ..stop()
        ..value = 0.25;
    } else if (!_cycle.isAnimating) {
      _cycle.repeat();
    }
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ‏مقصوصةٌ على حدودها: الهالاتُ أوسعُ من الشاشة ولا تفيض على ما حولها.
    return IgnorePointer(
      child: ClipRect(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _AmbientPainter(widget.lights, _cycle),
          ),
        ),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.lights, this.cycle) : super(repaint: cycle);

  final List<AmbientLight> lights;
  final Animation<double> cycle;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final t = cycle.value;
    for (final light in lights) {
      final c = Offset(light.at.dx * size.width, light.at.dy * size.height);
      final breath = 0.5 + 0.5 * math.sin(2 * math.pi * (t + light.phase));
      var k = light.strength * (0.78 + 0.22 * breath);
      if (light.kind == AmbientKind.lantern) {
        // ارتجافُ لهبٍ خفيف: موجتان سريعتان فوق النَّفَس.
        k *= 1 +
            0.07 * math.sin(2 * math.pi * (t * 9 + light.phase)) +
            0.05 * math.sin(2 * math.pi * (t * 17));
      }
      final r = s * light.size;
      switch (light.kind) {
        case AmbientKind.orb:
          _halo(canvas, c, r, light.color, 0.42 * k);
        case AmbientKind.lantern:
          _halo(canvas, c, r, light.color, 0.46 * k);
          _halo(canvas, c, r * 0.22, const Color(0xFFFFF4DA), 0.65 * k);
        case AmbientKind.lamp:
          _cone(canvas, c, r * 0.9, r * 2.4, light.color, 0.30 * k);
          _halo(canvas, c, r * 0.55, light.color, 0.52 * k);
          _halo(canvas, c, r * 0.14, const Color(0xFFFFF6E0), 0.7 * k);
        case AmbientKind.spotlight:
          _cone(canvas, c, r * 1.15, size.height * 0.95, light.color, 0.24 * k);
          _pool(canvas, Offset(c.dx, size.height * 0.9), r * 1.3, r * 0.32,
              light.color, 0.20 * k);
          _halo(canvas, c, r * 0.4, light.color, 0.48 * k);
        case AmbientKind.clock:
          _clock(canvas, c, r, light.color, k);
      }
    }
  }

  void _halo(Canvas canvas, Offset c, double r, Color color, double a) {
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: a.clamp(0.0, 1.0)),
            color.withValues(alpha: (a * 0.38).clamp(0.0, 1.0)),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect),
    );
  }

  /// ضوءٌ مخروطيّ من [c] إلى أسفل، يتلاشى مع المسافة وحوافُّه ناعمة.
  void _cone(Canvas canvas, Offset c, double halfWidth, double length,
      Color color, double a) {
    final path = Path()
      ..moveTo(c.dx - halfWidth * 0.12, c.dy)
      ..lineTo(c.dx + halfWidth * 0.12, c.dy)
      ..lineTo(c.dx + halfWidth, c.dy + length)
      ..lineTo(c.dx - halfWidth, c.dy + length)
      ..close();
    final rect =
        Rect.fromLTRB(c.dx - halfWidth, c.dy, c.dx + halfWidth, c.dy + length);
    canvas.drawPath(
      path,
      Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, halfWidth * 0.18)
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: a.clamp(0.0, 1.0)),
            color.withValues(alpha: (a * 0.35).clamp(0.0, 1.0)),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );
  }

  /// بقعةُ ضوءٍ بيضويّة حيث يقع الكشّاف.
  void _pool(
      Canvas canvas, Offset c, double rx, double ry, Color color, double a) {
    final rect = Rect.fromCenter(center: c, width: rx * 2, height: ry * 2);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(colors: [
          color.withValues(alpha: a.clamp(0.0, 1.0)),
          color.withValues(alpha: 0),
        ]).createShader(rect),
    );
  }

  /// ساعةٌ مضيئة: هالةٌ وإطارٌ متوهّج وعلاماتٌ وعقربان على الوقت الحقيقيّ.
  void _clock(Canvas canvas, Offset c, double size, Color color, double k) {
    final r = size * 0.5;
    _halo(canvas, c, r * 2.6, const Color(0xFFFFC46B), 0.26 * k);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: (0.55 * k).clamp(0.0, 1.0));
    final soft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.22
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12)
      ..color =
          const Color(0xFFFFC46B).withValues(alpha: (0.35 * k).clamp(0.0, 1.0));
    canvas.drawCircle(c, r, soft);
    canvas.drawCircle(c, r, glow..strokeWidth = r * 0.07);
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final dir = Offset(math.sin(angle), -math.cos(angle));
      canvas.drawCircle(
        c + dir * (r * 0.8),
        r * (i % 3 == 0 ? 0.06 : 0.035),
        Paint()..color = color.withValues(alpha: (0.6 * k).clamp(0.0, 1.0)),
      );
    }
    final now = DateTime.now();
    final minute = (now.minute + now.second / 60) / 60 * 2 * math.pi;
    final hour = ((now.hour % 12) + now.minute / 60) / 12 * 2 * math.pi;
    void hand(double angle, double length, double width) {
      canvas.drawLine(
        c,
        c + Offset(math.sin(angle), -math.cos(angle)) * length,
        glow..strokeWidth = width,
      );
    }

    hand(hour, r * 0.45, r * 0.09);
    hand(minute, r * 0.68, r * 0.06);
    canvas.drawCircle(c, r * 0.07,
        Paint()..color = color.withValues(alpha: (0.8 * k).clamp(0.0, 1.0)));
  }

  @override
  bool shouldRepaint(_AmbientPainter old) => old.lights != lights;
}
