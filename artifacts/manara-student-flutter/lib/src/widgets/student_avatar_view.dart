import 'package:flutter/material.dart';

import '../services/student_avatar_store.dart';

/// The student's chosen character, wherever it needs to appear.
///
/// It listens to [StudentAvatars.selected], so every instance in the app —
/// top bar, dashboard, chat, profile — changes together the instant a new
/// character is picked, without the selection being passed down any tree.
class StudentAvatarView extends StatelessWidget {
  const StudentAvatarView({
    required this.size,
    this.showRing = true,
    this.onTap,
    super.key,
  });

  final double size;

  /// The soft ring and shadow. Off for small inline uses that sit inside
  /// something already framed.
  final bool showRing;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
                      Colors.white.withOpacity(0.95),
                      const Color(0xFF9EE7F5).withOpacity(0.55),
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
}
