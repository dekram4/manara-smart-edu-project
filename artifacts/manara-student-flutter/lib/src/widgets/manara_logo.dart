import 'package:flutter/material.dart';

import '../theme/student_theme.dart';

class ManaraLogo extends StatelessWidget {
  const ManaraLogo({
    this.size = 96,
    super.key,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * .82,
            height: size * .82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFF4C96B).withOpacity(.3),
                  const Color(0xFF58C9BE).withOpacity(.08),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6BD4C8).withOpacity(.22),
                  blurRadius: size * .28,
                  spreadRadius: size * .04,
                ),
              ],
            ),
          ),
          // A flat silhouette in the Manara blue, matching the same mark on
          // the splash, the path watermark and the login board. The colour
          // is sampled from this very artwork's own gradient, so the
          // silhouette reads as the logo rather than as a recolouring of
          // it. srcIn replaces the colours and keeps the shape, so the
          // ring, the open book and the arrow all still read.
          Image.asset(
            'assets/images/manara-logo-mark-transparent.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            color: StudentPalette.brandBlue,
            colorBlendMode: BlendMode.srcIn,
            errorBuilder: (_, __, ___) => Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: const Color(0xFF0B8693),
                borderRadius: BorderRadius.circular(size / 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF4C96B).withOpacity(.28),
                    blurRadius: size * .2,
                  ),
                ],
              ),
              child: Icon(
                Icons.menu_book_rounded,
                color: Colors.white,
                size: size * 0.52,
              ),
            ),
          ),
        ],
      ),
    );
  }
}