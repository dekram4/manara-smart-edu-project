import 'package:flutter/material.dart';

/// Every portal's own artwork, faded behind that portal's screen.
///
/// Each destination binds one of these once, at the bottom of its body
/// stack. The image is drawn at 20% under a warm light wash so it reads as
/// a watermark and never competes with the lesson text on top of it, and
/// `BoxFit.cover` fills the screen in either orientation rather than
/// letterboxing a faded rectangle in the middle.
///
/// It is wrapped in [IgnorePointer] so it can never intercept a tap, and
/// its `errorBuilder` degrades to the plain wash — a missing background is
/// a cosmetic loss, never a broken screen.
class PortalWatermark extends StatelessWidget {
  const PortalWatermark({
    required this.asset,
    this.opacity = 0.20,
    this.dark = false,
    super.key,
  });

  /// One of the `assets/images/back_*.png` portal backgrounds.
  final String asset;

  /// Kept in the 0.15-0.25 band where the artwork reads without making
  /// body text harder to follow.
  final double opacity;

  /// The cinema and the tutor are deliberately dark rooms. Washing them in
  /// cream would wreck that, so those pass `dark: true` and get a deep
  /// navy wash instead — same watermark, same opacity band, a ground that
  /// still suits the screen.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: dark
                    ? const [
                        Color(0xFF19384F),
                        Color(0xFF17364F),
                        Color(0xFF1C4059),
                      ]
                    : const [
                        Color(0xFFFFF6E7),
                        Color(0xFFFDF2E6),
                        Color(0xFFEFF5FA),
                      ],
              ),
            ),
          ),
          Opacity(
            opacity: opacity,
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

/// The background each portal uses. Keeping the mapping in one place means
/// a screen that serves two portals (the content screen is both the lesson
/// and the games; the tutor screen is both the virtual teacher and the
/// live meeting) picks its background from the same table rather than
/// hard-coding one and getting it wrong for the other.
class PortalBackgrounds {
  const PortalBackgrounds._();

  static const lesson = 'assets/images/back_teach2.png';
  static const games = 'assets/images/back_game.png';
  static const cinema = 'assets/images/back_cinema.png';
  static const personality = 'assets/images/back_teach.png';
  static const tutor = 'assets/images/back_avatar.png';
  static const liveMeeting = 'assets/images/back_meet.png';
  static const quiz = 'assets/images/back_quez.png';
  static const problemSolver = 'assets/images/back_hal.png';
  static const chat = 'assets/images/back_chat.png';
  static const endlessReader = 'assets/images/back_endless.png';
}
