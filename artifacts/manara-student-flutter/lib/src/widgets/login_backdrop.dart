import 'package:flutter/material.dart';

/// خلفيةُ شاشة الدخول: سماءٌ ومرجٌ وكتب (`assets/images/auth/login_bg_custom.png`)
/// تنجرف ببطءٍ شديد تحت غشاءٍ أبيضَ خفيف — حيّةٌ ولا تزاحم السبورة أمامها.
///
/// الصورةُ رأسيّة. رأسياً تملأ الشاشةَ كما هي؛ وأفقياً تُقصّ من أعلاها
/// وأسفلها، والانجرافُ يمرّ بين السماء والمرج فيُرى منها ما قُصّ.
/// ومع «تقليل الحركة» تسكن في وسطها.
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
      child: LayoutBuilder(builder: (context, box) {
        final landscape = box.maxWidth > box.maxHeight;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final width = box.maxWidth.isFinite ? box.maxWidth : 800.0;
        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _drift,
              child: Image.asset(
                LoginBackdrop.asset,
                key: const ValueKey('login-backdrop'),
                fit: BoxFit.cover,
                cacheWidth: (width * dpr * 1.08).clamp(360.0, 2000.0).round(),
                errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFE3EEF7)),
              ),
              builder: (context, child) {
                final t = Curves.easeInOutSine.transform(_drift.value);
                return Transform.scale(
                  scale: 1.04 + 0.03 * t,
                  // ‏أفقياً: من السماء إلى المرج؛ ورأسياً: انجرافٌ جانبيٌّ خفيف.
                  alignment: landscape ? Alignment(0, -0.6 + 1.2 * t) : Alignment(-0.4 + 0.8 * t, 0),
                  child: child,
                );
              },
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
        );
      }),
    );
  }
}
