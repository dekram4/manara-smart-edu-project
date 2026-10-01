import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/student_theme.dart';
import 'portal_watermark.dart';
import 'student_avatar_view.dart';

/// قطعُ ساحة التحدي: خلفيةٌ، وزرٌّ مجسّم، وخياراتٌ على طراز Kahoot، وعدّادٌ،
/// ومشهدُ المواجهة.
///
/// ── لغةٌ واحدةٌ للعمق ──
/// كلُّ ما يُضغط هنا يقف على حافّةٍ أغمق منه ويغوص فيها بالضغط — كبطاقة
/// «تحدَّ زملاءك» في الرفّ. فيعرف الطفلُ ما يُضغط بنظرة، ويُحسّ الضغطة.

/// خلفيةُ الساحة: خلفيةُ بطاقة التحدي نفسها، على أرضية التطبيق.
///
/// ── ولماذا لا لونٌ واحدٌ ثابت ──
/// كانت ليلاً بنفسجياً واحداً في كل حال: يبتلع الوضعَ الفاتح، ويجعل الساحةَ
/// غريبةً عن بطاقتها في الرفّ. والآن أرضيةُ التطبيق — فاتحةٌ أو داكنة بإعداد
/// الطالب — وعليها رسمُ بطاقة التحدي، فتكون الساحةُ استمراراً للبطاقة.
class ArenaBackdrop extends StatelessWidget {
  const ArenaBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: StudentSurface.ground(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PortalWatermark(
            asset: PortalBackgrounds.endlessReader,
            opacity: StudentSurface.isDark(context) ? 0.12 : 0.22,
          ),
          child,
        ],
      ),
    );
  }
}

/// زرٌّ مجسّم: وجهٌ على حافّة، يغوص فيها بالضغط.
class Arena3DButton extends StatefulWidget {
  const Arena3DButton({
    required this.child,
    required this.onPressed,
    this.color = const Color(0xFF7C3AED),
    this.ledgeColor,
    this.radius = 18,
    this.ledge = 6,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    this.greyWhenDisabled = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onPressed;

  /// المعطّلُ رماديٌّ عادةً. وخيارُ السؤال يلوّن نفسه بحاله — الصحيحُ أخضرُ
  /// والخاطئُ باهتٌ بعد الكشف — وكلُّها معطّلةٌ حينها، فلا يُمحى لونُها.
  final bool greyWhenDisabled;
  final Color color;
  final Color? ledgeColor;
  final double radius;
  final double ledge;
  final EdgeInsetsGeometry padding;

  @override
  State<Arena3DButton> createState() => _Arena3DButtonState();
}

class _Arena3DButtonState extends State<Arena3DButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final face = enabled || !widget.greyWhenDisabled
        ? widget.color
        : const Color(0xFF6B7280);
    final ledge = widget.ledgeColor ??
        Color.lerp(face, Colors.black, 0.35)!;
    final sink = _down && enabled ? widget.ledge : 0.0;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: Padding(
          padding: EdgeInsets.only(top: sink),
          child: Container(
            decoration: BoxDecoration(
              color: ledge,
              borderRadius: BorderRadius.circular(widget.radius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: Offset(0, 4 + widget.ledge - sink),
                ),
              ],
            ),
            padding: EdgeInsets.only(bottom: widget.ledge - sink),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 70),
              padding: widget.padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.radius),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(face, Colors.white, 0.18)!, face],
                ),
              ),
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
                child: Center(widthFactor: 1, child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// حالُ خيارٍ في السؤال.
enum AnswerTileState {
  /// مفتوحٌ للاختيار.
  idle,

  /// اخترتُه، والخادمُ لم يردّ بعد.
  picked,

  /// الجوابُ الصحيح، بعد الكشف.
  correct,

  /// اخترتُه وكان خاطئاً.
  wrong,

  /// غيرُه — يخفت بعد الكشف أو بعد اختياري.
  dimmed,
}

/// خيارٌ على طراز Kahoot: لونٌ وشكلٌ لكل موضع، فيُعرف بالنظر قبل القراءة.
///
/// ── ولماذا شكلٌ مع اللون ──
/// طفلٌ لا يميّز الأحمر من الأخضر يرى المثلّثَ والمربّع. واللونُ وحده يجعل
/// خيارين متشابهين عنده.
class AnswerTile extends StatelessWidget {
  const AnswerTile({
    required this.index,
    required this.label,
    required this.state,
    required this.onPressed,
    super.key,
  });

  final int index;
  final String label;
  final AnswerTileState state;
  final VoidCallback? onPressed;

  static const colors = [
    Color(0xFFE21B3C),
    Color(0xFF1368CE),
    Color(0xFFD89E00),
    Color(0xFF26890C),
  ];
  static const shapes = [
    Icons.change_history_rounded,
    Icons.diamond_rounded,
    Icons.circle,
    Icons.square_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final base = colors[index % colors.length];
    final color = switch (state) {
      AnswerTileState.correct => const Color(0xFF16A34A),
      AnswerTileState.dimmed => Color.lerp(base, const Color(0xFF374151), 0.7)!,
      AnswerTileState.wrong => Color.lerp(base, const Color(0xFF374151), 0.45)!,
      _ => base,
    };
    final trailing = switch (state) {
      AnswerTileState.correct =>
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 26),
      AnswerTileState.wrong =>
        const Icon(Icons.cancel_rounded, color: Colors.white, size: 26),
      AnswerTileState.picked => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
        ),
      _ => null,
    };
    return AnimatedScale(
      scale: state == AnswerTileState.correct ? 1.04 : 1,
      duration: const Duration(milliseconds: 180),
      child: Arena3DButton(
        color: color,
        onPressed: onPressed,
        greyWhenDisabled: false,
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icon(shapes[index % shapes.length], color: Colors.white, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ],
        ),
      ),
    );
  }
}

/// عدّادُ السؤال: حلقةٌ تنقص ورقمٌ في وسطها، وتحمرّ في ثوانيها الأخيرة.
class ArenaTimerRing extends StatelessWidget {
  const ArenaTimerRing({
    required this.left,
    required this.window,
    this.size = 64,
    super.key,
  });

  final Duration left;
  final Duration window;
  final double size;

  @override
  Widget build(BuildContext context) {
    final total = window.inMilliseconds;
    // نافذةٌ صفرٌ لا تُقسم عليها.
    final share =
        total <= 0 ? 0.0 : (left.inMilliseconds / total).clamp(0.0, 1.0);
    final seconds = (left.inMilliseconds / 1000).ceil();
    final urgent = left.inMilliseconds <= 3000;
    final color = urgent ? const Color(0xFFF43F5E) : const Color(0xFFF59E0B);
    return Semantics(
      label: '$seconds',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            share: share,
            color: color,
            disc: StudentSurface.card(context),
            track: StudentSurface.track(context),
          ),
          child: Center(
            child: AnimatedScale(
              scale: urgent ? 1.15 : 1,
              duration: const Duration(milliseconds: 160),
              child: Text(
                '$seconds',
                style: TextStyle(
                  color: color,
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.share,
    required this.color,
    required this.disc,
    required this.track,
  });

  final double share;
  final Color color;
  final Color disc;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.11;
    final rect = Offset.zero & size;
    final inner = rect.deflate(stroke / 2);
    canvas.drawCircle(
      rect.center,
      size.shortestSide / 2,
      Paint()..color = disc,
    );
    canvas.drawArc(
      inner,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    canvas.drawArc(
      inner,
      -math.pi / 2,
      math.pi * 2 * share,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.share != share || old.color != color || old.disc != disc || old.track != track;
}

/// مشهدُ المواجهة: الشخصيتان على الطرفين، وVS بينهما، وتحتها العدُّ أو الانتظار.
class ArenaVersus extends StatelessWidget {
  const ArenaVersus({
    required this.myName,
    required this.rivalName,
    required this.myAppearance,
    required this.rivalAppearance,
    required this.footer,
    this.rivalPresent = true,
    super.key,
  });

  final String myName;
  final String rivalName;
  final Map<String, dynamic>? myAppearance;
  final Map<String, dynamic>? rivalAppearance;
  final Widget footer;

  /// الزميلُ لم يدخل بعد: صورتُه شاحبةٌ حتى يدخل.
  final bool rivalPresent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final avatar = (constraints.maxWidth * 0.26).clamp(72.0, 140.0);
        Widget side(String name, Map<String, dynamic>? look, bool present) =>
            Expanded(
              child: AnimatedOpacity(
                opacity: present ? 1 : 0.35,
                duration: const Duration(milliseconds: 300),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StudentAvatarView(size: avatar, appearance: look),
                    const SizedBox(height: 10),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: StudentSurface.ink(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                side(myName, myAppearance, true),
                const _VsBadge(),
                side(rivalName, rivalAppearance, rivalPresent),
              ],
            ),
            const SizedBox(height: 28),
            footer,
          ],
        );
      },
    );
  }
}

class _VsBadge extends StatelessWidget {
  const _VsBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFFDE68A), Color(0xFFF59E0B), Color(0xFFEA580C)],
        ),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x99F97316), blurRadius: 22, spreadRadius: 2),
        ],
      ),
      child: const Text(
        'VS',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Color(0x88000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
      ),
    );
  }
}

/// نقطةٌ خضراء تنبض: متصلٌ الآن.
class OnlinePulse extends StatefulWidget {
  const OnlinePulse({this.size = 12, super.key});

  final double size;

  @override
  State<OnlinePulse> createState() => _OnlinePulseState();
}

class _OnlinePulseState extends State<OnlinePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (still) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF22C55E),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF22C55E)
                  .withValues(alpha: 0.6 * (1 - _pulse.value)),
              blurRadius: 2,
              spreadRadius: widget.size * 0.6 * _pulse.value,
            ),
          ],
        ),
      ),
    );
  }
}
