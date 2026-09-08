import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// The shared "Space Game" visual identity for [LoginScreen] and
/// [AcademicSelectionScreen]: a deep purple/violet space gradient, a field
/// of independently twinkling stars, and (optionally) a few softly bobbing
/// floating rock islands scattered near the edges.
class SpaceGameBackdrop extends StatefulWidget {
  const SpaceGameBackdrop({this.rocks = true, super.key});

  /// Whether to scatter a few small decorative floating rocks near the
  /// edges. The academic path screen draws its own, larger, interactive
  /// islands for its stations, so it turns this off to avoid clutter.
  final bool rocks;

  @override
  State<SpaceGameBackdrop> createState() => _SpaceGameBackdropState();
}

class _SpaceGameBackdropState extends State<SpaceGameBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B0A33), Color(0xFF381363), Color(0xFF5A1E8A)],
            ),
          ),
        ),
        if (reduceMotion)
          CustomPaint(painter: _StarFieldPainter(0), size: Size.infinite)
        else
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) =>
                CustomPaint(painter: _StarFieldPainter(_controller.value), size: Size.infinite),
          ),
        if (widget.rocks) ...[
          const Positioned(left: 18, bottom: 44, child: SpaceFloatingRock(size: 74, delay: 0)),
          const Positioned(right: 30, top: 96, child: SpaceFloatingRock(size: 50, delay: 400)),
          const Positioned(right: 64, bottom: 96, child: SpaceFloatingRock(size: 42, delay: 800)),
        ],
      ],
    );
  }
}

/// A field of small white dots, each pulsing opacity on its own phase — a
/// cheap (one CustomPainter, one shared AnimationController) twinkling
/// starfield rather than dozens of individually-animated widgets.
class _StarFieldPainter extends CustomPainter {
  _StarFieldPainter(this.t);

  final double t;

  static const _count = 42;
  static final List<Offset> _fractions = List.generate(_count, (i) {
    final rnd = math.Random(i * 97 + 11);
    return Offset(rnd.nextDouble(), rnd.nextDouble() * 0.8);
  });
  static final List<double> _phases =
      List.generate(_count, (i) => math.Random(i * 53 + 7).nextDouble() * math.pi * 2);
  static final List<double> _radii =
      List.generate(_count, (i) => 1.0 + math.Random(i * 71 + 3).nextDouble() * 1.7);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _fractions.length; i++) {
      final position = Offset(_fractions[i].dx * size.width, _fractions[i].dy * size.height);
      final twinkle = (math.sin(t * 2 * math.pi + _phases[i]) + 1) / 2; // 0..1
      canvas.drawCircle(
        position,
        _radii[i],
        Paint()..color = Colors.white.withOpacity(0.2 + twinkle * 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) => oldDelegate.t != t;
}

/// A small, decorative, non-interactive floating rock — used to scatter a
/// few "islands" near the edges of the space backdrop. See
/// [SpaceIslandStation] for the bigger, tappable version used for actual
/// path stations.
class SpaceFloatingRock extends StatelessWidget {
  const SpaceFloatingRock({required this.size, this.delay = 0, super.key});

  final double size;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final rock = Container(
      width: size,
      height: size * 0.68,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.4),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B6BAE), Color(0xFF3E2560)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 8)),
        ],
      ),
    );
    if (reduceMotion) return rock;
    return rock
        .animate(onPlay: (c) => c.repeat(reverse: true), delay: delay.ms)
        .moveY(begin: 0, end: -10, duration: 2400.ms, curve: Curves.easeInOut);
  }
}

/// One rocky floating island a mission/lesson station stands on — a bigger,
/// glowing, tappable relative of [SpaceFloatingRock]. Bobs continuously;
/// gets a bright gold glow ring when [selected].
class SpaceIslandStation extends StatelessWidget {
  const SpaceIslandStation({
    required this.size,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.phaseMs = 0,
    super.key,
  });

  final double size;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int phaseMs;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final island = GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size * 1.35,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (selected)
                  Container(
                    width: size * 1.18,
                    height: size * 0.92,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(size * 0.42),
                      color: const Color(0xFFFFE08A).withOpacity(0.35),
                      boxShadow: const [BoxShadow(color: Color(0x99FFE08A), blurRadius: 24, spreadRadius: 2)],
                    ),
                  ),
                Container(
                  width: size,
                  height: size * 0.76,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.4),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFB08CD6), Color(0xFF5A1E8A)],
                    ),
                    border: Border.all(
                      color: selected ? const Color(0xFFFFE08A) : Colors.white.withOpacity(0.6),
                      width: selected ? 3 : 1.6,
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 16, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: size * 0.4),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                shadows: const [Shadow(color: Color(0xE6000000), blurRadius: 6)],
              ),
            ),
          ],
        ),
      ),
    );
    if (reduceMotion) return island;
    return island
        .animate(onPlay: (c) => c.repeat(reverse: true), delay: phaseMs.ms)
        .moveY(begin: 0, end: -8, duration: 1700.ms, curve: Curves.easeInOut);
  }
}

/// The glowing dashed line connecting one station to the next along the
/// zig-zag path — drawn under the stations.
class ZigzagPathPainter extends CustomPainter {
  ZigzagPathPainter(this.points);

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.22);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.85);
    for (var i = 0; i < points.length - 1; i++) {
      _drawDashedSegment(canvas, points[i], points[i + 1], glow);
      _drawDashedSegment(canvas, points[i], points[i + 1], line);
    }
  }

  void _drawDashedSegment(Canvas canvas, Offset a, Offset b, Paint paint) {
    final total = (b - a).distance;
    if (total <= 0) return;
    const dashLen = 10.0;
    const gapLen = 9.0;
    final dir = (b - a) / total;
    var covered = 0.0;
    while (covered < total) {
      final start = a + dir * covered;
      final end = a + dir * math.min(covered + dashLen, total);
      canvas.drawLine(start, end, paint);
      covered += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(covariant ZigzagPathPainter oldDelegate) => oldDelegate.points != points;
}
