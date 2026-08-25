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