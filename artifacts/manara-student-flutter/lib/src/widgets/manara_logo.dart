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
                  const Color(0xFFF4C96B).withValues(alpha: .3),
                  const Color(0xFF58C9BE).withValues(alpha: .08),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6BD4C8).withValues(alpha: .22),
                  blurRadius: size * .28,
                  spreadRadius: size * .04,
                ),
              ],
            ),
          ),
          // شعارُ المنصّة المعتمد بألوانه: المنارةُ على الكتاب في قوسها.
          // كانت هنا العلامةُ القديمة صورةً ظلّيةً بالأزرق؛ والجديدةُ بيضاءُ
          // من داخل قوسها، فالظلُّ الواحد كان يمحو المنارة كلَّها.
          Image.asset(
            'assets/images/manara-logo-emblem.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: const Color(0xFF0B8693),
                borderRadius: BorderRadius.circular(size / 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF4C96B).withValues(alpha: .28),
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