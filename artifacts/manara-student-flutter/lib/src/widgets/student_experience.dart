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