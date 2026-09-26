import 'package:flutter/material.dart';

import '../models/student_character.dart';
import '../services/student_avatar_store.dart';

/// The student's chosen character, wherever it needs to appear.
///
/// It listens to [StudentAvatars.selected], so every instance in the app —
/// top bar, dashboard, chat, profile — changes together the instant a new
/// character is picked, without the selection being passed down any tree.
///
/// Pass [appearance] to draw *someone else's* character instead: a
/// classmate on the leaderboard, whose pick arrives with the board and does
/// not change while it is on screen. The same widget draws both, so a
/// classmate's medallion and the child's own cannot drift apart in size,
/// ring or fallback.
class StudentAvatarView extends StatelessWidget {
  const StudentAvatarView({
    required this.size,
    this.showRing = true,
    this.onTap,
    this.appearance,
    super.key,
  });

  final double size;

  /// The soft ring and shadow. Off for small inline uses that sit inside
  /// something already framed.
  final bool showRing;

  final VoidCallback? onTap;

  /// Another student's saved appearance — the whole map the personality
  /// screen writes: the picked avatar, the emoji shape, its colour, and a
  /// built portrait when there is one. Null means "the student using this
  /// device", which is the original behaviour.
  final Map<String, dynamic>? appearance;

  @override
  Widget build(BuildContext context) {
    if (appearance != null) return _forAppearance(context, appearance!);
    return ValueListenableBuilder<StudentAvatar>(
      valueListenable: StudentAvatars.selected,
      builder: (context, avatar, _) {
        final medallion = Container(
          width: size,
          height: size,
          decoration: showRing
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.95),
                      const Color(0xFF9EE7F5).withValues(alpha: 0.55),
                    ],
                  ),
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2E0B8693),
                      blurRadius: 16,
                      offset: Offset(0, 7),
                    ),
                  ],
                )
              : null,
          child: ClipOval(
            child: Padding(
              padding: EdgeInsets.all(size * 0.06),
              child: Image.asset(
                avatar.asset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.person_rounded,
                  size: size * 0.6,
                  color: const Color(0xFF0B8693),
                ),
              ),
            ),
          ),
        );
        if (onTap == null) return medallion;
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: medallion,
        );
      },
    );
  }

  /// One classmate's medallion, from their saved appearance.
  ///
  /// The order matches what the personality screen lets a child set, most
  /// specific first: a portrait they built, then an avatar they picked from
  /// the gallery, then the emoji shape and colour. Each step falls through
  /// to the next when it is not set or cannot be drawn — a classmate whose
  /// portrait host is unreachable shows their emoji, not a broken box.
  Widget _forAppearance(BuildContext context, Map<String, dynamic> look) {
    final portrait = StudentCharacters.avatarImageUrl(look);
    final avatarId = look[StudentAvatars.appearanceKey]?.toString().trim();
    final character = StudentCharacters.fromAppearance(look);

    Widget inner;
    if (portrait != null) {
      inner = Image.network(
        portrait,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _emoji(character),
      );
    } else if (avatarId != null && avatarId.isNotEmpty) {
      inner = Image.asset(
        StudentAvatars.byId(avatarId).asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _emoji(character),
      );
    } else {
      inner = _emoji(character);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // لون الطفل خلف شخصيته، مخفّفاً: هو اختياره ويُميّزه في صفٍّ
        // كثيرٍ من رفاقه اختاروا الشكل نفسه.
        color: character.color.withValues(alpha: 0.18),
        border: showRing
            ? Border.all(color: Colors.white, width: 2.5)
            : Border.all(color: character.color.withValues(alpha: 0.45), width: 1.5),
        boxShadow: showRing
            ? const [
                BoxShadow(
                  color: Color(0x2E0B8693),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: Padding(
          padding: EdgeInsets.all(size * 0.06),
          child: inner,
        ),
      ),
    );
  }

  Widget _emoji(StudentCharacter character) => Center(
        child: Text(
          character.emoji,
          style: TextStyle(fontSize: size * 0.52),
        ),
      );
}
