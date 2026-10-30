import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// زرُّ «تغيير الدرس» في رأس الواجهة: كبسولةٌ بتدرّج، وتوهّجٌ يتنفّس بهدوء يدلّ
/// عليه، وتنضغط تحت الإصبع، وتدور أيقونةُ المسار مع الضغطة.
///
/// [narrow] للشريط الضيّق: الأيقونةُ وحدها في دائرة، كما كان — كي لا يفيض الشريط.
class ChangeLessonButton extends StatefulWidget {
  const ChangeLessonButton({
    required this.label,
    required this.onPressed,
    this.narrow = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool narrow;

  @override
  State<ChangeLessonButton> createState() => _ChangeLessonButtonState();
}

class _ChangeLessonButtonState extends State<ChangeLessonButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool _down = false;
  int _turns = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (still) {
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const from = Color(0xFF0E5F6B);
    const to = Color(0xFF14B8A6);
    final icon = AnimatedRotation(
      turns: _turns * 0.5,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      child: Text('🎒', style: TextStyle(fontSize: widget.narrow ? 22 : 20)),
    );
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _turns += 1);
          widget.onPressed();
        },
        child: AnimatedScale(
          scale: _down ? 0.92 : 1,
          duration: const Duration(milliseconds: 130),
          child: AnimatedBuilder(
            animation: _breath,
            builder: (context, child) {
              final glow = Curves.easeInOut.transform(_breath.value);
              return Container(
                padding: widget.narrow
                    ? const EdgeInsets.all(10)
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [from, to]),
                  borderRadius: BorderRadius.circular(widget.narrow ? 999 : 22),
                  boxShadow: [
                    BoxShadow(
                      color: to.withValues(alpha: 0.25 + 0.25 * glow),
                      blurRadius: 8 + 10 * glow,
                      spreadRadius: glow * 1.5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: widget.narrow
                ? icon
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon,
                      const SizedBox(width: 6),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
