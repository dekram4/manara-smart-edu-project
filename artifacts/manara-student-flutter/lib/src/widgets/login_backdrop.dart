import 'package:flutter/material.dart';

import 'fitted_art_backdrop.dart';

/// خلفيةُ شاشة الدخول: سماءٌ ومرجٌ وكتب (`assets/images/auth/login_bg_custom.png`)
/// تنجرف ببطءٍ شديد تحت غشاءٍ أبيضَ خفيف — حيّةٌ ولا تزاحم السبورة أمامها.
///
/// الصورةُ رأسيّة: رأسياً تملأ الشاشة، وأفقياً تُعرض كاملةً في الوسط
/// ([FittedArtBackdrop]). ومع «تقليل الحركة» تسكن.
class LoginBackdrop extends StatefulWidget {
  const LoginBackdrop({super.key});

  static const asset = 'assets/images/auth/login_bg_custom.png';

  @override
  State<LoginBackdrop> createState() => _LoginBackdropState();
}

class _LoginBackdropState extends State<LoginBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _drift
        ..stop()
        ..value = 0.5;
    } else if (!_drift.isAnimating) {
      _drift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedArtBackdrop(
            asset: LoginBackdrop.asset,
            drift: _drift,
            imageKey: const ValueKey('login-backdrop'),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x40FFFFFF), Color(0x26FFFFFF), Color(0x4DFFFFFF)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
