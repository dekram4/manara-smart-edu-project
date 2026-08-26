import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/student_sound_service.dart';

class StudentPageRoute<T> extends PageRouteBuilder<T> {
  StudentPageRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) : super(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
            final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curve,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.035, 0.025),
                  end: Offset.zero,
                ).animate(curve),
                child: child,
              ),
            );
          },
        );
}

class StudentEntrance extends StatelessWidget {
  const StudentEntrance({
    required this.child,
    this.delay = Duration.zero,
    this.offset = 0.055,
    super.key,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    return child
        .animate(delay: delay)
        .fadeIn(duration: 320.ms, curve: Curves.easeOut)
        .slideY(begin: offset, end: 0, duration: 380.ms, curve: Curves.easeOutCubic);
  }
}

/// Gives student-facing cards a clearly visible arrival motion. This is kept
/// separate from page navigation so sections, games and reward cards feel
/// responsive even when the user stays on the same screen.
class StudentAnimatedCard extends StatelessWidget {
  const StudentAnimatedCard({
    required this.child,
    this.delay = Duration.zero,
    super.key,
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    return child
        .animate(delay: delay)
        .fadeIn(duration: 420.ms, curve: Curves.easeOut)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: 520.ms,
          curve: Curves.easeOutBack,
        );
  }
}

/// Subtle decorative light spots for student-facing entry screens.
///
/// They stay behind the content and stop animating when the device asks for
/// reduced motion.
class StudentAmbientOrbs extends StatelessWidget {
  const StudentAmbientOrbs({super.key});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final topOrb = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF5EEAD4).withOpacity(0.12),
      ),
    );
    final bottomOrb = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF818CF8).withOpacity(0.14),
      ),
    );

    Widget animate(Widget child, {required bool reverse}) {
      if (reduceMotion) return child;
      return child
          .animate(onPlay: (controller) => controller.repeat(reverse: reverse))
          .moveY(
            begin: reverse ? -8 : 8,
            end: reverse ? 8 : -8,
            duration: 3200.ms,
            curve: Curves.easeInOut,
          )
          .fade(
            begin: 0.68,
            end: 1,
            duration: 2400.ms,
            curve: Curves.easeInOut,
          );
    }

    return IgnorePointer(
      child: Stack(
        children: [
          PositionedDirectional(
            top: -72,
            end: -48,
            child: SizedBox(
              width: 210,
              height: 210,
              child: animate(topOrb, reverse: false),
            ),
          ),
          PositionedDirectional(
            bottom: -88,
            start: -54,
            child: SizedBox(
              width: 230,
              height: 230,
              child: animate(bottomOrb, reverse: true),
            ),
          ),
        ],
      ),
    );
  }
}

/// A quiet visual map for the student entry screens. The painter keeps the
/// background light and dimensional without turning the screen into a game
/// scene or competing with the form.
class StudentLearningWorld extends StatelessWidget {
  const StudentLearningWorld({super.key});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final sparkle = const Icon(
      Icons.auto_awesome_rounded,
      color: Color(0xFFF5C95D),
      size: 16,
    );

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _LearningWorldPainter()),
          PositionedDirectional(
            top: 42,
            start: 28,
            child: _FloatingWorldBadge(
              child: const Icon(
                Icons.menu_book_rounded,
                color: Color(0xFF0B6977),
                size: 20,
              ),
              duration: const Duration(milliseconds: 4200),
              delay: const Duration(milliseconds: 120),
              reduceMotion: reduceMotion,
            ),
          ),
          PositionedDirectional(
            top: 116,
            end: 28,
            child: _FloatingWorldBadge(
              child: sparkle,
              duration: const Duration(milliseconds: 3600),
              delay: const Duration(milliseconds: 360),
              reduceMotion: reduceMotion,
            ),
          ),
          PositionedDirectional(
            bottom: 44,
            end: 42,
            child: _FloatingWorldBadge(
              child: const Icon(
                Icons.star_rounded,
                color: Color(0xFFE27962),
                size: 18,
              ),
              duration: const Duration(milliseconds: 3900),
              delay: const Duration(milliseconds: 220),
              reduceMotion: reduceMotion,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingWorldBadge extends StatelessWidget {
  const _FloatingWorldBadge({
    required this.child,
    required this.duration,
    required this.delay,
    required this.reduceMotion,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF3).withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE3D5A9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A274E76),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (reduceMotion) return badge;
    return badge
        .animate(delay: delay, onPlay: (controller) => controller.repeat(reverse: true))
        .moveY(begin: 0, end: -9, duration: duration, curve: Curves.easeInOut);
  }
}

class _LearningWorldPainter extends CustomPainter {
  const _LearningWorldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final wash = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Color(0xFFFFF6DD),
          Color(0xFFF6F7F0),
          Color(0xFFE8F3F0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);

    final tealRing = Paint()
      ..color = const Color(0xFF147D83).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22;
    canvas.drawCircle(
      Offset(size.width * 0.02, size.height * 0.14),
      size.shortestSide * 0.24,
      tealRing,
    );

    final lilac = Paint()
      ..color = const Color(0xFF7663C7).withOpacity(0.09)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.96, size.height * 0.9),
      size.shortestSide * 0.25,
      lilac,
    );

    final dots = Paint()..color = const Color(0xFF183047).withOpacity(0.11);
    for (var row = 0; row < 7; row++) {
      for (var column = 0; column < 9; column++) {
        final point = Offset(
          size.width * 0.08 + column * 22,
          size.height * 0.08 + row * 22,
        );
        canvas.drawCircle(point, 1.1, dots);
      }
    }

    final path = Paint()
      ..color = const Color(0xFFE2B85E).withOpacity(0.17)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final curve = Path()
      ..moveTo(size.width * 0.08, size.height * 0.78)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.62,
        size.width * 0.44,
        size.height * 0.94,
        size.width * 0.64,
        size.height * 0.74,
      )
      ..cubicTo(
        size.width * 0.77,
        size.height * 0.6,
        size.width * 0.87,
        size.height * 0.68,
        size.width * 1.04,
        size.height * 0.52,
      );
    canvas.drawPath(curve, path);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The student-facing character used as a visual anchor on entry screens.
class StudentCompanion extends StatelessWidget {
  const StudentCompanion({
    this.size = 190,
    this.showLabel = true,
    super.key,
  });

  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final imageSize = size * 0.83;
    return Semantics(
      label: 'رفيق منارة التعليمي',
      image: true,
      child: SizedBox(
        width: size,
        height: size + (showLabel ? 34 : 0),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              bottom: 10,
              child: Container(
                width: size * 0.76,
                height: size * 0.22,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B2D3D).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0B2D3D).withOpacity(0.14),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateZ(-0.035),
              child: Image.asset(
                'assets/images/manara-student-login-companion-cutout.png',
                width: imageSize,
                height: imageSize,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: imageSize * 0.72,
                  height: imageSize * 0.72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1C664),
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x3D0B2D3D),
                        blurRadius: 16,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Color(0xFF173B50),
                    size: 58,
                  ),
                ),
              ),
            ),
            if (showLabel)
              Positioned(
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEE),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE4D39A)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F183047),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Text(
                    'أنا معك في الرحلة',
                    style: TextStyle(
                      color: Color(0xFF6F5729),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Highlights controls when they contain the current choice or own focus.
class StudentFocusGlow extends StatefulWidget {
  const StudentFocusGlow({
    required this.child,
    this.isSelected = false,
    this.hasError = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    super.key,
  });

  final Widget child;
  final bool isSelected;
  final bool hasError;
  final BorderRadius borderRadius;

  @override
  State<StudentFocusGlow> createState() => _StudentFocusGlowState();
}

class _StudentFocusGlowState extends State<StudentFocusGlow> {
  var _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final emphasized = _hasFocus || widget.isSelected;
    final color = widget.hasError
        ? const Color(0xFFF43F5E)
        : emphasized
            ? const Color(0xFF0B8693)
            : const Color(0xFFD7E3EF);

    return Focus(
      onFocusChange: (hasFocus) {
        if (mounted && _hasFocus != hasFocus) setState(() => _hasFocus = hasFocus);
      },
      child: AnimatedScale(
        scale: reduceMotion || !_hasFocus ? 1 : 1.012,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            border: Border.all(color: color, width: emphasized || widget.hasError ? 1.5 : 1),
            boxShadow: _hasFocus || widget.hasError
                ? [
                    BoxShadow(
                      color: color.withOpacity(widget.hasError ? 0.18 : 0.16),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// A compact selection summary that makes the current academic path obvious.
class StudentSelectionBadge extends StatelessWidget {
  const StudentSelectionBadge({
    required this.label,
    required this.subtitle,
    super.key,
  });

  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final content = Semantics(
      label: '$label. $subtitle',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF6EE7B7)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A059669),
              blurRadius: 16,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 19,
              backgroundColor: Color(0xFF059669),
              child: Icon(Icons.check_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF065F46),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF047857),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (reduceMotion) return content;
    return content
        .animate(key: ValueKey('$label-$subtitle'))
        .fadeIn(duration: 220.ms)
        .slideY(begin: 0.08, end: 0, duration: 280.ms, curve: Curves.easeOutCubic)
        .scale(begin: const Offset(0.96, 0.96), duration: 260.ms, curve: Curves.easeOutBack);
  }
}

/// Adds a visible but lightweight press response without owning the tap.
/// Existing InkWell buttons inside the child continue to receive the action.
class StudentPressScale extends StatefulWidget {
  const StudentPressScale({required this.child, super.key});

  final Widget child;

  @override
  State<StudentPressScale> createState() => _StudentPressScaleState();
}

class _StudentPressScaleState extends State<StudentPressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return widget.child;
    }
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.965 : 1,
        duration: const Duration(milliseconds: 120),
        curve: _pressed ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

/// A calm continuous reward cue for XP, gems and completed achievements.
class StudentRewardPulse extends StatelessWidget {
  const StudentRewardPulse({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    return child
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1.045, 1.045),
          duration: 1400.ms,
          curve: Curves.easeInOut,
        );
  }
}

class StudentSoundToggle extends StatelessWidget {
  const StudentSoundToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final sound = StudentSoundService.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: sound.muted,
      builder: (context, isMuted, _) => IconButton(
        onPressed: sound.toggleMuted,
        tooltip: isMuted ? 'تشغيل الأصوات' : 'كتم الأصوات',
        icon: Icon(isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
      ),
    );
  }
}

class StudentCelebration extends StatelessWidget {
  const StudentCelebration({required this.controller, super.key});

  final ConfettiController controller;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: controller,
          blastDirectionality: BlastDirectionality.explosive,
          emissionFrequency: 0.08,
          numberOfParticles: 42,
          maxBlastForce: 28,
          minBlastForce: 7,
          gravity: 0.16,
          colors: const [
            Color(0xFF0B8693),
            Color(0xFFF59E0B),
            Color(0xFF6D28D9),
            Color(0xFFF43F5E),
          ],
        ),
      ),
    );
  }
}