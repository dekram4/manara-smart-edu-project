import 'dart:math' as math;

import 'package:flutter/material.dart';

/// يلفت نظرَ الطفل إلى زرٍّ لا يجوز أن يفوته («ابدأ المغامرة»، «هيا نلعب!»):
/// هالةٌ مضيئةٌ تتنفّس حوله، وحلقتان من نورٍ تنطلقان منه وتتلاشيان كموجتين،
/// ولمعةٌ تمرّ على وجهه، والزرُّ نفسُه ينبض.
///
/// ومن طلب تقليلَ الحركة يراه ساكناً بهالته وحدها.
class AttentionGlow extends StatefulWidget {
  const AttentionGlow({
    required this.child,
    required this.color,
    this.active = true,
    this.radius = 999,
    super.key,
  });

  final Widget child;
  final Color color;
  final bool active;

  /// استدارةُ الزرّ: ٩٩٩ كبسولةٌ أو دائرة.
  final double radius;

  @override
  State<AttentionGlow> createState() => _AttentionGlowState();
}

class _AttentionGlowState extends State<AttentionGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AttentionGlow old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.active && !still) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      child: widget.child,
      builder: (context, child) {
        final t = _clock.value;
        final breath = 0.5 - 0.5 * math.cos(t * 2 * math.pi);
        final on = widget.active;
        return CustomPaint(
          painter: on ? _RipplePainter(t, widget.color, widget.radius) : null,
          foregroundPainter: on && _clock.isAnimating ? _ShinePainter(t, widget.radius) : null,
          child: Transform.scale(
            scale: on ? 1 + 0.07 * breath : 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.radius),
                boxShadow: on
                    ? [
                        BoxShadow(color: widget.color.withValues(alpha: 0.45 + 0.35 * breath), blurRadius: 16 + 22 * breath, spreadRadius: 2 + 6 * breath),
                        BoxShadow(color: Colors.white.withValues(alpha: 0.35 * breath), blurRadius: 8, spreadRadius: 1),
                      ]
                    : const [],
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// حلقتان من نورٍ تتّسعان من حافّة الزرّ وتبهتان، بفارق نصف دورة.
class _RipplePainter extends CustomPainter {
  _RipplePainter(this.t, this.color, this.radius);
  final double t;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    for (final phase in const [0.0, 0.5]) {
      final p = (t + phase) % 1;
      final grow = size.shortestSide * 0.32 * Curves.easeOut.transform(p);
      final ring = rect.inflate(grow);
      final r = math.min(radius + grow, ring.shortestSide / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(ring, Radius.circular(r)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * (1 - p) + 1
          ..color = color.withValues(alpha: 0.7 * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.t != t || old.color != color;
}

/// لمعةٌ بيضاءُ مائلةٌ تعبر وجهَ الزرّ مرّةً في كل دورة.
class _ShinePainter extends CustomPainter {
  _ShinePainter(this.t, this.radius);
  final double t;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    // ‏تعبر في أوّل ثلثٍ من الدورة، ثم يسكن الوجه.
    final p = t / 0.35;
    if (p >= 1) return;
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(math.min(radius, size.shortestSide / 2))));
    final x = -size.width * 0.4 + p * size.width * 1.8;
    final band = Path()
      ..moveTo(x, 0)
      ..lineTo(x + size.width * 0.18, 0)
      ..lineTo(x + size.width * 0.18 - size.height * 0.5, size.height)
      ..lineTo(x - size.height * 0.5, size.height)
      ..close();
    canvas.drawPath(band, Paint()..color = Colors.white.withValues(alpha: 0.38 * math.sin(p * math.pi)));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShinePainter old) => old.t != t;
}
