import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/student_character.dart';
import '../services/student_avatar_store.dart';

/// The student's own character, drifting gently up and down over the
/// dashboard background.
///
/// It renders whichever character the student selected — a Ready Player Me
/// portrait if they built one, otherwise the character they picked on the
/// personality screen, otherwise [StudentCharacters.fallback]. It never
/// renders nothing.
class StudentFloatingCharacter extends StatefulWidget {
  const StudentFloatingCharacter({
    required this.appearance,
    required this.size,
    this.onTap,
    this.showLabel = true,
    this.bob = 9,
    super.key,
  });

  /// The `appearance` map from the student's profile.
  final Map<String, dynamic>? appearance;
  final double size;
  final VoidCallback? onTap;

  /// Whether to print the character's name under it. Off when the widget
  /// sits inline beside text that already names the student.
  final bool showLabel;

  /// How far the drift travels, in logical pixels.
  final double bob;

  @override
  State<StudentFloatingCharacter> createState() =>
      _StudentFloatingCharacterState();
}

class _StudentFloatingCharacterState extends State<StudentFloatingCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final character = StudentCharacters.fromAppearance(widget.appearance);
    final portrait = StudentCharacters.avatarImageUrl(widget.appearance);
    final size = widget.size;

    final medallion = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.92),
            character.color.withOpacity(0.34),
          ],
        ),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: character.color.withOpacity(0.38),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipOval(
        child: portrait == null
            // The picked character is the student's picture everywhere,
            // so this renders it rather than the emoji stand-in. The emoji
            // remains only as the fallback for a Ready Player Me portrait
            // that fails to load.
            ? ValueListenableBuilder<StudentAvatar>(
                valueListenable: StudentAvatars.selected,
                builder: (context, avatar, _) => Padding(
                  padding: EdgeInsets.all(size * 0.07),
                  child: Image.asset(
                    avatar.asset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        character.emoji,
                        style: TextStyle(fontSize: size * 0.52),
                      ),
                    ),
                  ),
                ),
              )
            : Image.network(
                portrait,
                fit: BoxFit.cover,
                // A portrait that fails to load must not leave a hole —
                // fall back to the emoji character.
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    character.emoji,
                    style: TextStyle(fontSize: size * 0.52),
                  ),
                ),
              ),
      ),
    );

    final labelled = !widget.showLabel
        ? medallion
        : Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        medallion,
        SizedBox(height: size * 0.06),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.9)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              StudentAvatars.selected.value.label,
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xFF0E1B2A),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );

    final tappable = widget.onTap == null
        ? labelled
        : GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: labelled,
          );

    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return tappable;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset:
            Offset(0, math.sin(_controller.value * 2 * math.pi) * widget.bob),
        child: child,
      ),
      child: tappable,
    );
  }
}
