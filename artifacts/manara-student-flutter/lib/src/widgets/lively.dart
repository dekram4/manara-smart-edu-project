import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// حركاتٌ حيّة على طريقة «لمسة»، تُلبَس بها البطاقاتُ والواجهات.
///
/// ── قاعدتان ──
/// • لا تغيّر مقاساً ولا موضعاً: كلُّها تحويلاتٌ وطبقاتٌ فوق ما تلبسه، فلا
///   يتحرّك تخطيطٌ حسبته الشاشةُ بعناية (شاشة الدخول وحقولها فوق الكيبورد).
/// • ما يقع مع حدثٍ ينتهي: الظهورُ واللمسةُ والاختيارُ والاهتزاز تهدأ بعد
///   لحظتها. والمستمرُّ — خلفيةُ الدخول ونبضُ زرّها وتمايلُ شعارها — في
///   شاشة الدخول وحدها، بمحرّكٍ واحدٍ لكلٍّ منها.
///
/// وكلُّها تُطفأ مع «تقليل الحركة».

bool _reduce(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

// ═══════════════════════════════════════════════════════════════════════
// الظهورُ المتتابع
// ═══════════════════════════════════════════════════════════════════════

/// يظهر العنصرُ ذو الموضع [index] بعد سابقه بـ ٦٠ جزءاً من الألف: يرتفع
/// قليلاً، ويكبر من ٠٫٩٤ بارتدادٍ خفيف، ويتّضح.
class LivelyStagger extends StatelessWidget {
  const LivelyStagger({required this.index, required this.child, super.key});

  final int index;
  final Widget child;

  static const _step = Duration(milliseconds: 60);
  static const _maxDelay = Duration(milliseconds: 540);
  static const _length = Duration(milliseconds: 320);

  @override
  Widget build(BuildContext context) {
    if (_reduce(context)) return child;
    final delay = _step * index > _maxDelay ? _maxDelay : _step * index;
    final total = delay + _length;
    final wait = delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, raw, child) {
        final v = raw <= wait ? 0.0 : ((raw - wait) / (1 - wait)).clamp(0.0, 1.0);
        if (v >= 1) return child!;
        final pop = MotionCurves.backOut.transform(v);
        return Opacity(
          opacity: math.min(1.0, v * 1.6),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 14),
            child: Transform.scale(scale: 0.94 + 0.06 * pop, child: child),
          ),
        );
      },
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// تموّجُ اللمسة
// ═══════════════════════════════════════════════════════════════════════

/// حلقةٌ تتّسع من موضع الإصبع وتبهت، ونجيماتٌ تتطاير منها — في ٤٥٠ جزءاً.
///
/// ترى اللمسةَ ولا تأخذها: ما تحتها (زرٌّ أو بطاقةٌ تُفتح) يستقبلها كما كان.
class LivelyTouch extends StatefulWidget {
  const LivelyTouch({
    required this.child,
    this.color = const Color(0xFFFFFFFF),
    super.key,
  });

  final Widget child;
  final Color color;

  @override
  State<LivelyTouch> createState() => _LivelyTouchState();
}

class _LivelyTouchState extends State<LivelyTouch> with SingleTickerProviderStateMixin {
  late final AnimationController _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  Offset _at = Offset.zero;

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduce(context)) return widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _at = event.localPosition;
        _ripple.forward(from: 0);
      },
      child: AnimatedBuilder(
        animation: _ripple,
        child: widget.child,
        builder: (context, child) {
          if (!_ripple.isAnimating) return child!;
          return CustomPaint(
            foregroundPainter: _RipplePainter(
              center: _at,
              t: _ripple.value,
              color: widget.color,
            ),
            child: child,
          );
        },
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({required this.center, required this.t, required this.color});

  final Offset center;
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final ease = Curves.easeOutCubic.transform(t);
    final reach = size.shortestSide * 0.45 + 24;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)));
    canvas.drawCircle(
      center,
      reach * ease,
      Paint()..color = color.withValues(alpha: 0.22 * (1 - t)),
    );
    canvas.drawCircle(
      center,
      reach * ease,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - t) + 0.5
        ..color = color.withValues(alpha: 0.75 * (1 - t)),
    );
    canvas.restore();
    // نجيماتٌ أربع تتطاير من موضع اللمسة.
    for (var i = 0; i < 4; i++) {
      final a = -math.pi / 2 + (i - 1.5) * 0.7;
      final p = center + Offset(math.cos(a), math.sin(a)) * (14 + 30 * ease);
      _star(canvas, p, 4 * (1 - t) + 1, const Color(0xFFFACC15).withValues(alpha: 1 - t));
    }
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) => old.t != t || old.center != center;
}

// ═══════════════════════════════════════════════════════════════════════
// توهّجُ الاختيار واهتزازُ الخطأ
// ═══════════════════════════════════════════════════════════════════════

/// حين يصير [active] صحيحاً: نبضةُ توهّجٍ بلون [color] تتّسع وتبهت، وقفزةٌ
/// صغيرة — مرّةً واحدة لكل اختيار.
class LivelyGlow extends StatefulWidget {
  const LivelyGlow({
    required this.active,
    required this.child,
    this.color = const Color(0xFF16A34A),
    this.radius = 16,
    super.key,
  });

  final bool active;
  final Widget child;
  final Color color;
  final double radius;

  @override
  State<LivelyGlow> createState() => _LivelyGlowState();
}

class _LivelyGlowState extends State<LivelyGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  @override
  void didUpdateWidget(LivelyGlow old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !_reduce(context)) _pulse.forward(from: 0);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      child: widget.child,
      builder: (context, child) {
        if (!_pulse.isAnimating) return child!;
        final t = _pulse.value;
        final bounce = math.sin(t * math.pi) * 0.04;
        return Transform.scale(
          scale: 1 + bounce,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.55 * (1 - t)),
                  blurRadius: 6 + 22 * t,
                  spreadRadius: 1 + 8 * t,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// حين يصير [active] صحيحاً: اهتزازٌ أفقيٌّ قصير يقول «لا» بلا كلمة.
class LivelyShake extends StatefulWidget {
  const LivelyShake({required this.active, required this.child, super.key});

  final bool active;
  final Widget child;

  @override
  State<LivelyShake> createState() => _LivelyShakeState();
}

class _LivelyShakeState extends State<LivelyShake> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(LivelyShake old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !_reduce(context)) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shake,
      child: widget.child,
      builder: (context, child) {
        if (!_shake.isAnimating) return child!;
        final t = _shake.value;
        final dx = math.sin(t * math.pi * 6) * 9 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// المستمرّ — لشاشة الدخول
// ═══════════════════════════════════════════════════════════════════════

/// تمايلٌ هادئ: يعلو ويهبط [amplitude] نقطة، ويميل قليلاً، دورةً كل [period].
class LivelyBob extends StatefulWidget {
  const LivelyBob({
    required this.child,
    this.amplitude = 4,
    this.tilt = 0.03,
    this.period = const Duration(milliseconds: 3200),
    super.key,
  });

  final Widget child;
  final double amplitude;
  final double tilt;
  final Duration period;

  @override
  State<LivelyBob> createState() => _LivelyBobState();
}

class _LivelyBobState extends State<LivelyBob> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduce(context)) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduce(context)) return widget.child;
    return AnimatedBuilder(
      animation: _loop,
      child: widget.child,
      builder: (context, child) {
        final a = _loop.value * 2 * math.pi;
        return Transform.translate(
          offset: Offset(0, -math.sin(a) * widget.amplitude),
          child: Transform.rotate(angle: math.sin(a * 0.5) * widget.tilt, child: child),
        );
      },
    );
  }
}

/// هالةٌ تنبض حول الزرّ — ظلٌّ يتّسع ويضيق، فلا يتغيّر مقاسُ الزرّ ولا موضعُه.
class LivelyPulseGlow extends StatefulWidget {
  const LivelyPulseGlow({
    required this.child,
    this.color = const Color(0xFFF59E0B),
    this.radius = 18,
    super.key,
  });

  final Widget child;
  final Color color;
  final double radius;

  @override
  State<LivelyPulseGlow> createState() => _LivelyPulseGlowState();
}

class _LivelyPulseGlowState extends State<LivelyPulseGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduce(context)) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduce(context)) return widget.child;
    return AnimatedBuilder(
      animation: _loop,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_loop.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.18 + 0.32 * t),
                blurRadius: 8 + 16 * t,
                spreadRadius: 1 + 3 * t,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}

/// خلفيةُ الدخول الحيّة: حروفٌ وأرقامٌ ونجومٌ وفقاعاتٌ ملوّنة تطفو ببطء
/// وتتمايل — صفٌّ مدرسيٌّ يلعب خلف السبورة. محرّكٌ واحد ورسامٌ واحد، ولا
/// تستقبل لمسة.
class LoginAmbience extends StatefulWidget {
  const LoginAmbience({super.key});

  @override
  State<LoginAmbience> createState() => _LoginAmbienceState();
}

class _LoginAmbienceState extends State<LoginAmbience> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduce(context)) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _loop,
        builder: (context, _) => CustomPaint(
          painter: _AmbiencePainter(t: _reduce(context) ? 0.25 : _loop.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _AmbiencePainter extends CustomPainter {
  _AmbiencePainter({required this.t});

  final double t;

  static const _glyphs = ['أ', 'ب', '١', '٢', '+', '★', 'ت', '٣', '=', '✦', 'ج', '٥'];
  static const _colors = [
    Color(0xFF0B8693),
    Color(0xFFF59E0B),
    Color(0xFFE05A86),
    Color(0xFF8B5CF6),
    Color(0xFF16A085),
    Color(0xFF1394D2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    // فقاعاتٌ ناعمة تصعد، وكلُّ واحدةٍ بسرعتها.
    for (var i = 0; i < 9; i++) {
      final speed = 1 + (i % 3);
      final phase = (t * speed + i / 9) % 1.0;
      final x = size.width * ((i * 37 % 100) / 100) + math.sin((t + i) * 2 * math.pi) * 18;
      final y = size.height * (1.1 - phase * 1.25);
      final r = unit * (0.025 + 0.02 * (i % 3));
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = _colors[i % _colors.length].withValues(alpha: 0.10),
      );
    }
    // وحروفٌ وأرقامٌ تطفو وتدور ببطء، بشفافيةٍ لا تنافس السبورة.
    for (var i = 0; i < _glyphs.length; i++) {
      final phase = (t + i / _glyphs.length) % 1.0;
      final x = size.width * (0.05 + 0.9 * ((i * 53 % 100) / 100));
      final y = size.height * (0.08 + 0.84 * ((i * 29 % 100) / 100)) +
          math.sin(phase * 2 * math.pi) * unit * 0.03;
      final painter = _glyph(i, unit);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.sin(phase * 2 * math.pi) * 0.25);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }
  }

  /// الحرفُ مقيساً مرّةً لكل مقاس، لا في كل إطار: قياسُ النصّ أغلى ما في
  /// الرسم، والخلفيةُ ترسم ستّين مرّةً في الثانية.
  static final Map<String, TextPainter> _cache = {};

  static TextPainter _glyph(int i, double unit) {
    final key = '$i:${unit.round()}';
    return _cache.putIfAbsent(key, () {
      if (_cache.length > 96) _cache.clear();
      return TextPainter(
        text: TextSpan(
          text: _glyphs[i],
          style: TextStyle(
            fontSize: unit * (0.05 + 0.02 * (i % 3)),
            fontWeight: FontWeight.w900,
            color: _colors[i % _colors.length].withValues(alpha: 0.16),
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
    });
  }

  @override
  bool shouldRepaint(covariant _AmbiencePainter old) => old.t != t;
}
