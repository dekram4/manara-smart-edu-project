import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'lively.dart';

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
///
/// ── وضوءُ الحلبة ──
/// وهجان ساكنان يتقابلان: بنفسجيٌّ من جهة اللاعب وذهبيٌّ من جهة المنافس، كضوءِ
/// ركنين في حلبة. ساكنان عمداً: الساحةُ تتحرّك فيها الأسئلةُ والنقاط، وخلفيةٌ
/// تتحرّك معها تشتّت عينَ الطفل عن خياراته.
class ArenaBackdrop extends StatelessWidget {
  const ArenaBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = StudentSurface.isDark(context);
    return ColoredBox(
      color: StudentSurface.ground(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: DecoratedBox(
              key: const ValueKey('arena-glow'),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.9, -0.85),
                  radius: 1.05,
                  colors: [
                    ArenaPalette.violet.withValues(alpha: dark ? 0.34 : 0.18),
                    ArenaPalette.violet.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.95, 0.9),
                  radius: 1.0,
                  colors: [
                    ArenaPalette.gold.withValues(alpha: dark ? 0.22 : 0.16),
                    ArenaPalette.gold.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          PortalWatermark(
            asset: PortalBackgrounds.endlessReader,
            opacity: dark ? 0.12 : 0.22,
          ),
          child,
        ],
      ),
    );
  }
}

/// ألوانُ الحلبة في موضعٍ واحد: بنفسجُ المنارة وذهبُها، ولونا الطرفين.
abstract final class ArenaPalette {
  static const violet = Color(0xFF7C3AED);
  static const violetDeep = Color(0xFF4C1D95);
  static const gold = Color(0xFFF59E0B);
  static const goldLight = Color(0xFFFDE68A);

  /// جهةُ اللاعب: أزرقُ سماويّ. وجهةُ المنافس: ورديٌّ ناريّ.
  static const me = Color(0xFF38BDF8);
  static const rival = Color(0xFFF43F5E);

  static const right = Color(0xFF16A34A);
  static const wrong = Color(0xFFDC2626);
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
    this.glow,
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

  /// وهجٌ حول الزرّ بهذا اللون (الصحيحُ والخاطئ بعد الاختيار)، أو لا وهج.
  final Color? glow;

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
    final ledge = widget.ledgeColor ?? Color.lerp(face, Colors.black, 0.35)!;
    final sink = _down && enabled ? widget.ledge : 0.0;
    final glow = widget.glow;
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              color: ledge,
              borderRadius: BorderRadius.circular(widget.radius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: Offset(0, 4 + widget.ledge - sink),
                ),
                if (glow != null)
                  BoxShadow(
                    color: glow.withValues(alpha: 0.55),
                    blurRadius: 22,
                    spreadRadius: 2,
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
              // ‏لمعةُ السطح: ضوءٌ أبيضُ على نصفه الأعلى، فيبدو الوجهُ مصقولاً بارزاً.
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.radius),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22), width: 1.2),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.20),
                    Colors.white.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.5],
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
///
/// ── والانتقالُ بين الحالات لونٌ يسيل لا يقفز ──
/// الخيارُ يتحوّل إلى لون حاله في ربع ثانية — أخضرُ يتوهّج للصحيح، وأحمرُ يهتزّ
/// للخاطئ، وباهتٌ لغيرهما — فيرى الطفلُ ما حدث لا أنّ الشاشةَ تبدّلت.
class AnswerTile extends StatelessWidget {
  const AnswerTile({
    required this.index,
    required this.label,
    required this.state,
    required this.onPressed,
    this.badge,
    super.key,
  });

  final int index;
  final String label;
  final AnswerTileState state;
  final VoidCallback? onPressed;

  /// علامةٌ صغيرةٌ في آخر الخيار — من اختاره (🧒، 🤖) — أو لا شيء.
  final String? badge;

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

  /// لونُ الخيار في حاله.
  static Color colorFor(int index, AnswerTileState state) {
    final base = colors[index % colors.length];
    return switch (state) {
      AnswerTileState.correct => ArenaPalette.right,
      AnswerTileState.wrong => ArenaPalette.wrong,
      AnswerTileState.dimmed => Color.lerp(base, const Color(0xFF374151), 0.7)!,
      _ => base,
    };
  }

  @override
  Widget build(BuildContext context) {
    final target = colorFor(index, state);
    final glow = switch (state) {
      AnswerTileState.correct => const Color(0xFF4ADE80),
      AnswerTileState.wrong => const Color(0xFFF87171),
      AnswerTileState.picked => ArenaPalette.goldLight,
      _ => null,
    };
    final trailing = switch (state) {
      AnswerTileState.correct =>
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 26),
      AnswerTileState.wrong =>
        const Icon(Icons.cancel_rounded, color: Colors.white, size: 26),
      AnswerTileState.picked => const SizedBox(
          width: 20,
          height: 20,
          child:
              CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
        ),
      _ => null,
    };
    // الصحيحُ يتوهّج بنبضةٍ خضراء، والخطأُ يهتزّ «لا» — كلاهما لحظةً ثم يهدأ.
    return LivelyShake(
      active: state == AnswerTileState.wrong,
      child: LivelyGlow(
        active: state == AnswerTileState.correct,
        child: AnimatedScale(
          scale: switch (state) {
            AnswerTileState.correct => 1.04,
            AnswerTileState.dimmed => 0.97,
            _ => 1,
          },
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: target),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            builder: (context, color, _) => Arena3DButton(
              color: color ?? target,
              onPressed: onPressed,
              greyWhenDisabled: false,
              radius: 18,
              glow: glow,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  // ‏شكلُ الموضع في قرصٍ زجاجيّ: يُقرأ قبل النصّ.
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.22),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.55),
                          width: 1.4),
                    ),
                    child: Icon(shapes[index % shapes.length],
                        color: Colors.white, size: 20),
                  ),
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
                        shadows: [
                          Shadow(
                              color: Color(0x55000000),
                              blurRadius: 3,
                              offset: Offset(0, 1))
                        ],
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 6),
                    Text(badge!, style: const TextStyle(fontSize: 18)),
                  ],
                  if (trailing != null) ...[const SizedBox(width: 8), trailing],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// عدّادُ السؤال: حلقةٌ تنقص ورقمٌ في وسطها.
///
/// والحلقةُ لونُ ما بقي: خضراءُ في أوّل الوقت، ثم ذهبية، ثم حمراءُ متوهّجة في
/// ثوانيها الأخيرة ويكبر رقمُها — فيُحسّ الوقتُ بطرف العين وعينُ الطفل على
/// خياراته.
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

  /// لونُ ما بقي من [share]: أخضر ← ذهبيّ ← أحمر.
  static Color colorFor(double share, {required bool urgent}) {
    if (urgent) return const Color(0xFFF43F5E);
    if (share >= 0.6) return const Color(0xFF22C55E);
    return Color.lerp(const Color(0xFFF59E0B), const Color(0xFF22C55E),
        (share / 0.6).clamp(0.0, 1.0))!;
  }

  @override
  Widget build(BuildContext context) {
    final total = window.inMilliseconds;
    // نافذةٌ صفرٌ لا تُقسم عليها.
    final share =
        total <= 0 ? 0.0 : (left.inMilliseconds / total).clamp(0.0, 1.0);
    final seconds = (left.inMilliseconds / 1000).ceil();
    final urgent = left.inMilliseconds <= 3000;
    final color = colorFor(share, urgent: urgent);
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
            glow: urgent,
          ),
          child: Center(
            child: AnimatedScale(
              scale: urgent ? 1.18 : 1,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutBack,
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
    this.glow = false,
  });

  final double share;
  final Color color;
  final Color disc;
  final Color track;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.11;
    final rect = Offset.zero & size;
    final inner = rect.deflate(stroke / 2);
    // ‏هالةٌ بلون الوقت حول القرص، أشدُّ في الثواني الأخيرة.
    canvas.drawCircle(
      rect.center,
      size.shortestSide / 2,
      Paint()
        ..color = color.withValues(alpha: glow ? 0.45 : 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, glow ? 9 : 5),
    );
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
    if (share <= 0) return;
    final sweep = math.pi * 2 * share;
    canvas.drawArc(
      inner,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: -math.pi / 2 + math.max(sweep, 0.01),
          colors: [Color.lerp(color, Colors.white, 0.35)!, color],
          transform: const GradientRotation(0),
        ).createShader(inner),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.share != share ||
      old.color != color ||
      old.disc != disc ||
      old.track != track ||
      old.glow != glow;
}

/// مشهدُ المواجهة: الشخصيتان على الطرفين، وVS بينهما، وتحتها العدُّ أو الانتظار.
///
/// ── مشهدُ دخولٍ لا صورتان ──
/// كلُّ شخصيةٍ تدخل من جهتها إلى وسط الحلبة في هالةٍ بلون فريقها — أزرقُ
/// للّاعب وورديٌّ ناريٌّ للمنافس — والشارةُ بينهما تنبثق بعدهما. دخولٌ واحدٌ ثم
/// سكون: المواجهةُ لحظةُ ترقّب، والعينُ تنتقل بعدها إلى العدّ تحتها.
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
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return LayoutBuilder(
      builder: (context, constraints) {
        final avatar = (constraints.maxWidth * 0.26).clamp(72.0, 140.0);
        Widget side(String name, Map<String, dynamic>? look, bool present,
                Color team, double from) =>
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: still ? 1 : 0, end: 1),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutBack,
                builder: (context, t, child) => Transform.translate(
                  offset: Offset(from * (1 - t) * 60, 0),
                  child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
                ),
                child: AnimatedOpacity(
                  opacity: present ? 1 : 0.35,
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ArenaFighter(appearance: look, size: avatar, team: team),
                      const SizedBox(height: 12),
                      ArenaNamePlate(name: name, team: team),
                    ],
                  ),
                ),
              ),
            );
        final rtl = Directionality.of(context) == TextDirection.rtl;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                side(myName, myAppearance, true, ArenaPalette.me, rtl ? 1 : -1),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: still ? 1 : 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: const Interval(0.45, 1, curve: Curves.elasticOut),
                  builder: (context, t, child) =>
                      Transform.scale(scale: t, child: child),
                  child: const ArenaVsBadge(),
                ),
                side(rivalName, rivalAppearance, rivalPresent,
                    ArenaPalette.rival, rtl ? -1 : 1),
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

/// شخصيةٌ في الحلبة: صورتُها في حلقةٍ بلون فريقها، وهالةٌ متوهّجةٌ خلفها.
class ArenaFighter extends StatelessWidget {
  const ArenaFighter({
    required this.appearance,
    required this.size,
    required this.team,
    super.key,
  });

  /// `null`: الطالبُ على هذا الجهاز.
  final Map<String, dynamic>? appearance;
  final double size;
  final Color team;

  @override
  Widget build(BuildContext context) {
    final ring = size * 0.06;
    return Container(
      width: size + ring * 2,
      height: size + ring * 2,
      padding: EdgeInsets.all(ring),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            team,
            Color.lerp(team, Colors.white, 0.55)!,
            team,
            ArenaPalette.gold,
            team
          ],
        ),
        boxShadow: [
          BoxShadow(
              color: team.withValues(alpha: 0.55),
              blurRadius: size * 0.28,
              spreadRadius: size * 0.03),
          const BoxShadow(
              color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 6)),
        ],
      ),
      child: StudentAvatarView(size: size, appearance: appearance),
    );
  }
}

/// اسمُ اللاعب على لوحةٍ بلون فريقه.
class ArenaNamePlate extends StatelessWidget {
  const ArenaNamePlate({required this.name, required this.team, super.key});

  final String name;
  final Color team;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
            colors: [Color.lerp(team, Colors.black, 0.25)!, team]),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.4),
        boxShadow: [
          BoxShadow(
              color: team.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
                color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1))
          ],
        ),
      ),
    );
  }
}

/// شارةُ المواجهة: «VS» على قرصٍ ناريّ، وبرقان على جانبيه.
class ArenaVsBadge extends StatelessWidget {
  const ArenaVsBadge({this.size = 72, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 22,
      height: size + 22,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: Transform.rotate(
              angle: -0.35,
              child: Text('⚡', style: TextStyle(fontSize: size * 0.3)),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Transform.rotate(
              angle: 0.35,
              child: Text('⚡', style: TextStyle(fontSize: size * 0.3)),
            ),
          ),
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFFFDE68A),
                  Color(0xFFF59E0B),
                  Color(0xFFEA580C)
                ],
              ),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x99F97316), blurRadius: 26, spreadRadius: 4),
                BoxShadow(
                    color: Color(0x557C3AED), blurRadius: 40, spreadRadius: 8),
              ],
            ),
            child: Text(
              'VS',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.34,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                shadows: const [
                  Shadow(
                      color: Color(0x88000000),
                      blurRadius: 4,
                      offset: Offset(0, 2))
                ],
              ),
            ),
          ),
        ],
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
