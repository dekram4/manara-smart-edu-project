import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/student_sound_service.dart';

/// The student's one drawn character — a complete, front-facing kid mascot
/// built entirely from plain Flutter shapes (no external animation file to
/// fail to parse or render). Every part (head, face, torso, both arms, both
/// legs) is always present and laid out with ordinary Column/Row flow, then
/// the whole thing is scaled to fit its box with [FittedBox] so nothing is
/// ever cropped, however small a caller sizes it.
class StudentMascot extends StatelessWidget {
  const StudentMascot({
    this.size = 140,
    this.waving = false,
    this.outfitColor = const Color(0xFF16A085),
    this.skinTone = const Color(0xFFFFD9AE),
    this.hairColor = const Color(0xFF3B2314),
    super.key,
  });

  final double size;
  final bool waving;
  final Color outfitColor;
  final Color skinTone;
  final Color hairColor;

  @override
  Widget build(BuildContext context) {
    final headSize = size * 0.6;
    final armSize = Size(size * 0.16, size * 0.38);
    final legSize = Size(size * 0.17, size * 0.32);

    return SizedBox(
      width: size,
      height: size * 1.34,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: size * 0.5,
              height: size * 0.05,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.15),
                borderRadius: BorderRadius.circular(40),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: size * 0.03),
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MascotHead(
                    size: headSize,
                    skinTone: skinTone,
                    hairColor: hairColor,
                  ),
                  SizedBox(height: size * 0.015),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Arm(size: armSize, color: outfitColor, handColor: skinTone),
                      SizedBox(width: size * 0.02),
                      _Torso(width: size * 0.46, height: size * 0.42, color: outfitColor),
                      SizedBox(width: size * 0.02),
                      _Arm(
                        size: armSize,
                        color: outfitColor,
                        handColor: skinTone,
                        raised: waving,
                      ),
                    ],
                  ),
                  SizedBox(height: size * 0.01),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Leg(size: legSize),
                      SizedBox(width: size * 0.06),
                      _Leg(size: legSize),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MascotHead extends StatelessWidget {
  const _MascotHead({
    required this.size,
    required this.skinTone,
    required this.hairColor,
  });

  final double size;
  final Color skinTone;
  final Color hairColor;

  @override
  Widget build(BuildContext context) {
    final eyeSize = size * 0.12;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Face.
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: skinTone,
              border: Border.all(color: Colors.white, width: size * 0.045),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: size * 0.12,
                  offset: Offset(0, size * 0.05),
                ),
              ],
            ),
          ),
          // Hair — a rounded cap covering the top of the head.
          Positioned(
            top: -size * 0.06,
            child: ClipPath(
              clipper: _TopHalfClipper(),
              child: Container(
                width: size * 1.02,
                height: size * 0.62,
                decoration: BoxDecoration(
                  color: hairColor,
                  borderRadius: BorderRadius.circular(size * 0.5),
                ),
              ),
            ),
          ),
          // Cheeks.
          Positioned(
            top: size * 0.62,
            left: size * 0.08,
            child: _Cheek(size: size * 0.16),
          ),
          Positioned(
            top: size * 0.62,
            right: size * 0.08,
            child: _Cheek(size: size * 0.16),
          ),
          // Eyes.
          Positioned(
            top: size * 0.42,
            left: size * 0.24,
            child: _Eye(size: eyeSize),
          ),
          Positioned(
            top: size * 0.42,
            right: size * 0.24,
            child: _Eye(size: eyeSize),
          ),
          // Smile.
          Positioned(
            top: size * 0.66,
            child: SizedBox(
              width: size * 0.32,
              height: size * 0.14,
              child: CustomPaint(painter: _SmilePainter(color: const Color(0xFF7A3B2E))),
            ),
          ),
        ],
      ),
    );
  }
}

class _Eye extends StatelessWidget {
  const _Eye({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF20232B),
        shape: BoxShape.circle,
      ),
      child: Align(
        alignment: const Alignment(-0.35, -0.35),
        child: Container(
          width: size * 0.34,
          height: size * 0.34,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _Cheek extends StatelessWidget {
  const _Cheek({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 0.7,
      decoration: BoxDecoration(
        color: const Color(0xFFFF8FA3).withOpacity(0.55),
        borderRadius: BorderRadius.circular(size),
      ),
    );
  }
}

class _SmilePainter extends CustomPainter {
  const _SmilePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.85
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height * 0.15)
      ..quadraticBezierTo(size.width / 2, size.height * 1.55, size.width, size.height * 0.15);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SmilePainter oldDelegate) => oldDelegate.color != color;
}

/// Keeps only the top half (plus a little) of whatever it clips — used to
/// turn a full circle into a rounded "hair cap" shape sitting on the head.
class _TopHalfClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.72));
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _Torso extends StatelessWidget {
  const _Torso({required this.width, required this.height, required this.color});

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(width * 0.32),
        border: Border.all(color: Colors.white, width: width * 0.06),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: width * 0.18,
            offset: Offset(0, width * 0.1),
          ),
        ],
      ),
      alignment: Alignment.topCenter,
      padding: EdgeInsets.only(top: height * 0.18),
      child: Container(
        width: width * 0.4,
        height: height * 0.1,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

class _Arm extends StatelessWidget {
  const _Arm({
    required this.size,
    required this.color,
    required this.handColor,
    this.raised = false,
  });

  final Size size;
  final Color color;
  final Color handColor;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final limb = Column(
      children: [
        Container(
          width: size.width,
          height: size.height * 0.78,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(size.width),
          ),
        ),
        Container(
          width: size.width * 0.86,
          height: size.width * 0.86,
          margin: EdgeInsets.only(top: size.height * 0.02),
          decoration: BoxDecoration(color: handColor, shape: BoxShape.circle),
        ),
      ],
    );
    if (!raised) return limb;
    return Transform.rotate(
      angle: -2.3,
      alignment: Alignment.topCenter,
      child: limb,
    );
  }
}

class _Leg extends StatelessWidget {
  const _Leg({required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: size.width,
          height: size.height * 0.8,
          decoration: BoxDecoration(
            color: const Color(0xFF334155),
            borderRadius: BorderRadius.circular(size.width * 0.4),
          ),
        ),
        Container(
          width: size.width * 1.15,
          height: size.height * 0.22,
          margin: EdgeInsets.only(top: size.height * 0.02),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B),
            borderRadius: BorderRadius.circular(size.width),
          ),
        ),
      ],
    );
  }
}

/// The animated, tappable version of [StudentMascot] used wherever the
/// student can actually interact with their character: a gentle idle bob,
/// and a wave + squash-bounce (plus [StudentSoundService.playTap]) on tap.
class StudentInteractiveMascot extends StatefulWidget {
  const StudentInteractiveMascot({
    this.size = 160,
    this.outfitColor = const Color(0xFF16A085),
    this.onTapped,
    super.key,
  });

  final double size;
  final Color outfitColor;
  final VoidCallback? onTapped;

  @override
  State<StudentInteractiveMascot> createState() => _StudentInteractiveMascotState();
}

class _StudentInteractiveMascotState extends State<StudentInteractiveMascot> {
  bool _waving = false;
  int _bounceTicket = 0;

  Future<void> _onTap() async {
    StudentSoundService.instance.playTap();
    widget.onTapped?.call();
    setState(() {
      _waving = true;
      _bounceTicket++;
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _waving = false);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final mascot = StudentMascot(
      size: widget.size,
      waving: _waving,
      outfitColor: widget.outfitColor,
    );

    final idle = reduceMotion
        ? mascot
        : mascot
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .moveY(begin: 0, end: -6, duration: 1800.ms, curve: Curves.easeInOut);

    final withBounce = reduceMotion
        ? idle
        : idle
            .animate(key: ValueKey(_bounceTicket))
            .scaleXY(begin: 1, end: 1.08, duration: 140.ms, curve: Curves.easeOut)
            .then()
            .scaleXY(end: 1, duration: 220.ms, curve: Curves.elasticOut);

    return Semantics(
      button: true,
      label: 'اضغط لتحية شخصيتك',
      child: GestureDetector(onTap: _onTap, child: withBounce),
    );
  }
}
