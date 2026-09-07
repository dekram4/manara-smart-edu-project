import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/student_gamification.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import 'student_experience.dart';
import 'student_mascot.dart';

/// The student home screen's playful centerpiece: a small pseudo-3D room
/// (tilted back wall + floor meeting at a horizon, like the corner of a
/// bedroom) with an animated character the student can tap to celebrate,
/// sitting above a childish XP progress bar, gems count and daily streak.
class StudentAvatarRoom extends StatelessWidget {
  const StudentAvatarRoom({
    required this.stats,
    this.onCustomize,
    super.key,
  });

  final StudentGamification stats;
  final VoidCallback? onCustomize;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Student3DCard(
      maxTilt: 0.03,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          borderRadius: StudentShapes.playfulCard,
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
                if (onCustomize != null)
                  StudentPressScale(
                    child: TextButton.icon(
                      onPressed: () {
                        StudentSoundService.instance.playTap();
                        onCustomize!();
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
            const SizedBox(height: 6),
            _AvatarRoomScene(reduceMotion: reduceMotion),
            const SizedBox(height: 6),
            const Text(
              'اضغط على شخصيتك لتحيّيك وتحتفل معك!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6F4D63),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            _ChildishStatRow(stats: stats),
          ],
        ),
      ),
    );
  }
}

/// A tilted floor + back wall, like the inside corner of a bedroom, drawn
/// with the same perspective `Transform`/`Matrix4` technique already used
/// elsewhere in the student UI (see `Student3DCard`) rather than a flat
/// gradient rectangle — this is what actually reads as a "room" instead of
/// just another card.
class _AvatarRoomScene extends StatelessWidget {
  const _AvatarRoomScene({required this.reduceMotion});

  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Tall enough that the character (168 tall, sitting 34 up from the
      // floor) never pokes above this box and overlaps the header row
      // above it — keeps the room's own stacking order clean.
      height: 210,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Back wall: tilted away from the viewer (negative rotateX,
          // pinned at its bottom edge) so it visually recedes upward.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 128,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0018)
                  ..rotateX(-0.20),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFD3E7), Color(0xFFE8F0FF)],
                    ),
                  ),
                  child: Stack(
                    children: [
                      PositionedDirectional(
                        top: 10,
                        end: 18,
                        child: _RoomSticker(
                          icon: Icons.wb_sunny_rounded,
                          color: const Color(0xFFF6B93B),
                          size: 26,
                          bobDelay: Duration.zero,
                          reduceMotion: reduceMotion,
                        ),
                      ),
                      PositionedDirectional(
                        top: 30,
                        start: 20,
                        child: _RoomSticker(
                          icon: Icons.star_rounded,
                          color: const Color(0xFF7C3AED),
                          size: 18,
                          bobDelay: const Duration(milliseconds: 250),
                          reduceMotion: reduceMotion,
                        ),
                      ),
                      PositionedDirectional(
                        top: 54,
                        end: 70,
                        child: _RoomSticker(
                          icon: Icons.emoji_events_rounded,
                          color: const Color(0xFF0EA5E9),
                          size: 20,
                          bobDelay: const Duration(milliseconds: 480),
                          reduceMotion: reduceMotion,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Floor: tilted the other way (positive rotateX, pinned at its
          // top edge) so it recedes downward and meets the wall at a
          // horizon line, completing the room-corner illusion.
          Positioned(
            left: -6,
            right: -6,
            bottom: 0,
            height: 78,
            child: Transform(
              alignment: Alignment.topCenter,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0022)
                ..rotateX(0.36),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD9A0), Color(0xFFFFC576)],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22B4530C),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 34,
            child: StudentInteractiveMascot(size: 150, outfitColor: Color(0xFF9B3E68)),
          ),
        ],
      ),
    );
  }
}

class _RoomSticker extends StatelessWidget {
  const _RoomSticker({
    required this.icon,
    required this.color,
    required this.size,
    required this.bobDelay,
    required this.reduceMotion,
  });

  final IconData icon;
  final Color color;
  final double size;
  final Duration bobDelay;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final sticker = Container(
      padding: EdgeInsets.all(size * 0.32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.28), blurRadius: 8),
        ],
      ),
      child: Icon(icon, color: color, size: size),
    );
    if (reduceMotion) return sticker;
    // A different bob delay/period per sticker gives the wall a light
    // parallax feel without any of them ever moving in lockstep.
    return sticker
        .animate(
          delay: bobDelay,
          onPlay: (controller) => controller.repeat(reverse: true),
        )
        .moveY(begin: 0, end: -5, duration: 2200.ms, curve: Curves.easeInOut);
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
