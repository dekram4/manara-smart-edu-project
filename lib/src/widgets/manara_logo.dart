import 'package:flutter/material.dart';

class ManaraLogo extends StatelessWidget {
  const ManaraLogo({
    this.size = 96,
    super.key,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/manara-logo-mark-transparent.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF0B8693),
          borderRadius: BorderRadius.circular(size / 3),
        ),
        child: Icon(
          Icons.menu_book_rounded,
          color: Colors.white,
          size: size * 0.52,
        ),
      ),
    );
  }
}