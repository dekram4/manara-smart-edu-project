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
          emissionFrequency: 0.045,
          numberOfParticles: 18,
          maxBlastForce: 17,
          minBlastForce: 5,
          gravity: 0.18,
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