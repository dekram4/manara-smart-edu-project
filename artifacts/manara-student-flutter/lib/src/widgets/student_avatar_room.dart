import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart' as lottie;

import '../models/student_gamification.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import 'student_experience.dart';

/// The student home screen's playful centerpiece: a small pseudo-3D room
/// (tilted back wall + floor meeting at a horizon, like the corner of a
/// bedroom) with an animated character the student can tap to celebrate,
/// sitting above a childish XP progress bar, gems count and daily streak.
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
  int _celebrateTicket = 0;

  void _onTapAvatar() {
    StudentSoundService.instance.playTap();
    setState(() => _celebrateTicket++);
  }

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
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _onTapAvatar,
              child: Semantics(
                button: true,
                label: 'اضغط لتحية شخصيتك والاحتفال معها',
                child: _AvatarRoomScene(
                  celebrateTicket: _celebrateTicket,
                  reduceMotion: reduceMotion,
                ),
              ),
            ),
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
            _ChildishStatRow(stats: widget.stats),
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
  const _AvatarRoomScene({
    required this.celebrateTicket,
    required this.reduceMotion,
  });

  final int celebrateTicket;
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
          Positioned(
            bottom: 34,
            child: _AvatarCharacter(
              celebrateTicket: celebrateTicket,
              reduceMotion: reduceMotion,
            ),
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

class _AvatarCharacter extends StatefulWidget {
  const _AvatarCharacter({
    required this.celebrateTicket,
    required this.reduceMotion,
  });

  final int celebrateTicket;
  final bool reduceMotion;

  @override
  State<_AvatarCharacter> createState() => _AvatarCharacterState();
}

class _AvatarCharacterState extends State<_AvatarCharacter>
    with SingleTickerProviderStateMixin {
  AnimationController? _lottieController;

  // assets/animations/student-avatar-hero.json marks three named segments
  // across its 120-frame (4s @ 30fps) timeline: "idle" (frames 0-40), "wave"
  // (40-80) and "celebrate" (80-120). These are that timeline expressed as
  // the Lottie AnimationController's normalized [0, 1] playback position.
  static const double _idleStart = 0;
  static const double _idleEnd = 40 / 120;
  static const double _celebrateEnd = 1;

  void _handleLoaded(lottie.LottieComposition composition) {
    _lottieController?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: composition.duration,
    );
    _lottieController = controller;
    if (!widget.reduceMotion) {
      controller.repeat(min: _idleStart, max: _idleEnd);
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _AvatarCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.celebrateTicket != oldWidget.celebrateTicket &&
        !widget.reduceMotion) {
      _playCelebrateSegment();
    }
  }

  Future<void> _playCelebrateSegment() async {
    final controller = _lottieController;
    if (controller == null) return;
    // Play forward from wherever the idle loop currently sits, through the
    // file's own wave + celebrate keyframes, all the way to the end — the
    // actual authored celebration, not a synthetic tween — then resume
    // idling from the start.
    controller.stop();
    await controller.animateTo(
      _celebrateEnd,
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeInOut,
    );
    if (!mounted) return;
    controller.repeat(min: _idleStart, max: _idleEnd);
  }

  @override
  void dispose() {
    _lottieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final character = SizedBox(
      width: 148,
      height: 168,
      child: lottie.Lottie.asset(
        'assets/animations/student-avatar-hero.json',
        controller: _lottieController,
        onLoaded: _handleLoaded,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.accessibility_new_rounded,
          size: 120,
          color: Color(0xFF9B3E68),
        ),
      ),
    );

    if (widget.reduceMotion) return character;
    // A short squash-and-shimmer on top of the Lottie's own celebration
    // keeps the tap feeling instant and punchy even before the (slightly
    // slower) authored animation catches up.
    return character
        .animate(key: ValueKey(widget.celebrateTicket))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.1, 0.9),
          duration: 110.ms,
          curve: Curves.easeOut,
        )
        .then()
        .scale(
          begin: const Offset(1.1, 0.9),
          end: const Offset(1, 1),
          duration: 220.ms,
          curve: Curves.elasticOut,
        )
        .shimmer(
          delay: 200.ms,
          duration: 420.ms,
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
