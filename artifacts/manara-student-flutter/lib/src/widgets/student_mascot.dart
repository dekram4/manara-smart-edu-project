import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/student_sound_service.dart';

/// The student's one illustrated character — `assets/images/student_mascot.png`
/// — instead of a hand-drawn composition of Flutter shapes. Always rendered
/// with [BoxFit.contain] inside a fixed-aspect box, so it's never cropped
/// regardless of how small or large a caller sizes it, plus a soft ground
/// shadow and (via [StudentInteractiveMascot]) a light floating animation.
class StudentMascot extends StatelessWidget {
  const StudentMascot({
    this.size = 140,
    this.tint,
    super.key,
  });

  final double size;

  /// Optional color wash over the illustration — used only where picking a
  /// color should visibly affect the preview (the personality/appearance
  /// screen). Left null everywhere else so the mascot shows its real colors.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/student_mascot.png',
      width: size,
      fit: BoxFit.contain,
      cacheWidth: 520,
      errorBuilder: (_, __, ___) => Icon(
        Icons.emoji_people_rounded,
        size: size * 0.6,
        color: const Color(0xFF16A085),
      ),
    );

    return SizedBox(
      width: size,
      height: size * 1.05,
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
            child: tint == null
                ? image
                : ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      tint!.withOpacity(0.32),
                      BlendMode.srcATop,
                    ),
                    child: image,
                  ),
          ),
        ],
      ),
    );
  }
}

/// The animated, tappable version of [StudentMascot] used wherever the
/// student can actually interact with their character: a gentle idle bob,
/// and a squash-bounce (plus [StudentSoundService.playTap]) on tap.
class StudentInteractiveMascot extends StatefulWidget {
  const StudentInteractiveMascot({
    this.size = 160,
    this.onTapped,
    super.key,
  });

  final double size;
  final VoidCallback? onTapped;

  @override
  State<StudentInteractiveMascot> createState() => _StudentInteractiveMascotState();
}

class _StudentInteractiveMascotState extends State<StudentInteractiveMascot> {
  int _bounceTicket = 0;

  void _onTap() {
    StudentSoundService.instance.playTap();
    widget.onTapped?.call();
    setState(() => _bounceTicket++);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final mascot = StudentMascot(size: widget.size);

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
