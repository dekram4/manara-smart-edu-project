import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart' as lottie;

import '../models/student_gamification.dart';
import '../services/student_sound_service.dart';
import 'student_experience.dart';

/// The student home screen's playful centerpiece: an animated character the
/// student can tap to make jump/celebrate, sitting above a childish XP bar,
/// gems count and daily streak. Framed as a small "room" rather than a plain
/// stat card so it reads as somewhere the student's avatar actually lives.
class StudentAvatarRoom extends StatefulWidget {
  const StudentAvatarRoom({
    required this.stats,
    this.onCustomize,
    super.key,
  });

  final StudentGamification stats;
  final VoidCallback? onCustomize;

  @override
  State<StudentAvatarRoom> createState() => _StudentAvatarRoomState();
}

class _StudentAvatarRoomState extends State<StudentAvatarRoom> {
  int _tapTicket = 0;

  void _onTapAvatar() {
    StudentSoundService.instance.playTap();
    setState(() => _tapTicket++);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Student3DCard(
      maxTilt: 0.03,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFFFE7F1), Color(0xFFE6F3FF), Color(0xFFFFF6DD)],
          ),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F9B3E68),
              blurRadius: 26,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.meeting_room_rounded,
                        size: 16,
                        color: Color(0xFF9B3E68),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'غرفة شخصيتي',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: Color(0xFF9B3E68),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (widget.onCustomize != null)
                  StudentPressScale(
                    child: TextButton.icon(
                      onPressed: () {
                        StudentSoundService.instance.playTap();
                        widget.onCustomize!();
                      },
                      icon: const Icon(Icons.brush_rounded, size: 16),
                      label: const Text('تخصيص'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF9B3E68),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            GestureDetector(
              onTap: _onTapAvatar,
              child: Semantics(
                button: true,
                label: 'اضغط لتحية شخصيتك',
                child: SizedBox(
                  height: 168,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        bottom: 8,
                        child: Container(
                          width: 128,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFF9B3E68).withOpacity(0.14),
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                      ),
                      _AvatarCharacter(
                        tapTicket: _tapTicket,
                        reduceMotion: reduceMotion,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'اضغط على شخصيتك لتحيّيك!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6F4D63),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            _ChildishStatRow(stats: widget.stats),
          ],
        ),
      ),
    );
  }
}

class _AvatarCharacter extends StatelessWidget {
  const _AvatarCharacter({required this.tapTicket, required this.reduceMotion});

  final int tapTicket;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final character = SizedBox(
      width: 150,
      height: 150,
      child: lottie.Lottie.asset(
        'assets/animations/student-avatar-hero.json',
        fit: BoxFit.contain,
        repeat: true,
        errorBuilder: (_, __, ___) => const StudentCompanion(
          size: 140,
          showLabel: false,
        ),
      ),
    );

    if (reduceMotion) return character;
    return character
        .animate(key: ValueKey(tapTicket))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.14, 0.88),
          duration: 130.ms,
          curve: Curves.easeOut,
        )
        .then()
        .scale(
          begin: const Offset(1.14, 0.88),
          end: const Offset(0.92, 1.12),
          duration: 160.ms,
          curve: Curves.easeInOut,
        )
        .then()
        .scale(
          begin: const Offset(0.92, 1.12),
          end: const Offset(1, 1),
          duration: 220.ms,
          curve: Curves.elasticOut,
        )
        .shimmer(
          delay: 280.ms,
          duration: 480.ms,
          color: const Color(0x66FFE08A),
        );
  }
}

class _ChildishStatRow extends StatelessWidget {
  const _ChildishStatRow({required this.stats});

  final StudentGamification stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 18),
            const SizedBox(width: 6),
            Text(
              'المستوى ${stats.level}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF6F4D63),
              ),
            ),
            const Spacer(),
            Text(
              'باقي ${stats.xpToNextLevel} XP للمستوى التالي',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8A6B7E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: (stats.levelProgress / 100).clamp(0.0, 1.0),
            minHeight: 14,
            backgroundColor: Colors.white.withOpacity(0.7),
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ChildishChip(
                icon: Icons.diamond_rounded,
                color: const Color(0xFF0EA5E9),
                label: '${stats.gems} جوهرة',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ChildishChip(
                icon: Icons.local_fire_department_rounded,
                color: const Color(0xFFFB7185),
                label: '${stats.streak} يوم متواصل',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChildishChip extends StatelessWidget {
  const _ChildishChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w900, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
