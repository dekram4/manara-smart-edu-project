import 'package:flutter/material.dart';

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
          Image.asset(
            'assets/images/manara-logo-mark-transparent.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            color: Colors.white.withOpacity(.04),
            colorBlendMode: BlendMode.plus,
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