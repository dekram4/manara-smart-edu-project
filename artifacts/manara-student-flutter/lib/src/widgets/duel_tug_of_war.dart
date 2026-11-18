import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../theme/student_theme.dart';
import 'arena_widgets.dart';
import 'duel_game_arenas.dart' show ArenaRacer;
import 'duel_versus.dart' show DuelMomentumBar;
import 'student_avatar_view.dart';

/// شدُّ الحبل: شخصيتي وشخصيةُ منافسي يشدّان حبلاً بينهما، والرايةُ الحمراء في
/// وسطه تسير إلى من يتقدّم بالنقاط.
///
/// ── وكلُّ إجابةٍ صحيحةٍ شدّةٌ تُرى ──
/// حين تزيد نقاطُ أحدهما يشدّ شدّةً قويّة: يميل إلى الوراء، ويتطاير الغبارُ
/// من قدميه، ويترنّح الآخرُ إلى الأمام، ثم يستقرّ الحبلُ في موضعه الجديد.
/// والموضعُ نفسُه حصّتي من النقاط ([DuelMomentumBar.shareOf]) — لا حسابَ
/// جديدٌ هنا، بل الرقمُ نفسُه يُرى.
///
/// والحركةُ شدّةٌ واحدةٌ مع كل نقطة ثم سكون، وتُطفأ مع «تقليل الحركة».
class DuelTugOfWar extends StatefulWidget {
  const DuelTugOfWar({
    required this.myPoints,
    required this.rivalPoints,
    this.myAppearance,
    this.rivalAppearance,
    this.height = 78,
    this.steps,
    super.key,
  });

  final int myPoints;
  final int rivalPoints;
  final Map<String, dynamic>? myAppearance;
  final Map<String, dynamic>? rivalAppearance;
  final double height;

  /// عددُ الأسئلة حين تكون [myPoints] و[rivalPoints] إجاباتٍ صحيحة لا نقاطاً:
  /// فتسير الرايةُ بالفرق خطوةً خطوة، وتبلغ خطَّ الفوز بفارق المباراة كلّها.
  final int? steps;

  /// أقصى ما يُزاح الحبلُ من المنتصف، نسبةً إلى العرض.
  static const maxShift = 0.15;

  /// بُعدُ كلِّ شادٍّ عن الراية، نسبةً إلى العرض.
  static const reach = 0.29;

  /// إزاحةُ الراية نحو جهتي (موجبةٌ إن تقدّمتُ)، نسبةً إلى العرض.
  static double shiftOf(int mine, int theirs, {int? steps}) => steps != null && steps > 0
      ? ((mine - theirs) / steps).clamp(-1.0, 1.0) * maxShift
      : (DuelMomentumBar.shareOf(mine, theirs) - 0.5) * 2 * maxShift;

  @override
  State<DuelTugOfWar> createState() => _DuelTugOfWarState();
}

class _DuelTugOfWarState extends State<DuelTugOfWar> with SingleTickerProviderStateMixin {
  late final AnimationController _yank = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  /// من شدّ الشدّةَ الأخيرة: أنا أم هو.
  bool _mineYank = true;

  /// عددُ الشدّات — مفتاحُ الغبار لكل شدّة.
  int _pulls = 0;

  @override
  void didUpdateWidget(DuelTugOfWar old) {
    super.didUpdateWidget(old);
    final mine = widget.myPoints > old.myPoints;
    final theirs = widget.rivalPoints > old.rivalPoints;
    if (!mine && !theirs) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    _mineYank = mine;
    _pulls++;
    _yank.forward(from: 0);
  }

  @override
  void dispose() {
    _yank.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // جهتي هي البداية: يمينُ الشاشة في العربية، كاسمي في شريط المقارنة.
    final meSign = rtl ? 1.0 : -1.0;
    final target = DuelTugOfWar.shiftOf(widget.myPoints, widget.rivalPoints, steps: widget.steps);
    return Semantics(
      label: tr('duel.tug.title'),
      child: SizedBox(
        key: const ValueKey('duel-tug'),
        height: widget.height,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: target),
          duration: still ? Duration.zero : const Duration(milliseconds: 620),
          curve: Curves.easeOutBack,
          builder: (context, shift, _) => AnimatedBuilder(
            animation: _yank,
            builder: (context, _) => LayoutBuilder(
              builder: (context, box) => _scene(box.maxWidth, shift, meSign),
            ),
          ),
        ),
      ),
    );
  }

  Widget _scene(double w, double shift, double meSign) {
    final h = widget.height;
    final t = _yank.value;
    final active = _yank.isAnimating;
    final jerk = active ? math.sin(t * math.pi) : 0.0;
    // الشدّةُ تسحب الحبلَ قليلاً أبعدَ من موضعه ثم يرتدّ إليه.
    final yankSign = _mineYank ? meSign : -meSign;
    final center = w / 2 + shift * meSign * w + yankSign * jerk * w * 0.035;
    final ropeY = h * 0.56;
    final meX = center + meSign * w * DuelTugOfWar.reach;
    final rivalX = center - meSign * w * DuelTugOfWar.reach;
    final myShare = DuelMomentumBar.shareOf(widget.myPoints, widget.rivalPoints);
    // المتقدّمُ يميل إلى الوراء أكثر، ومن شدّ الآن يميل أكثرَ وأكثر.
    double lean(bool me) {
      final share = me ? myShare : 1 - myShare;
      var a = 0.16 + (share - 0.5) * 0.24;
      if (active) a += (_mineYank == me ? 0.22 : -0.2) * jerk;
      return a.clamp(-0.12, 0.5);
    }

    const figure = Size(40, 60);
    final groundTop = h - 11;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _FieldPainter(
              center: center,
              ropeY: ropeY,
              meX: meX,
              rivalX: rivalX,
              groundTop: groundTop,
              meSign: meSign,
              wobble: jerk,
            ),
          ),
        ),
        for (final me in [true, false])
          Positioned(
            left: (me ? meX : rivalX) - figure.width / 2,
            top: groundTop - figure.height + 4,
            width: figure.width,
            height: figure.height,
            child: _Puller(
              key: ValueKey(me ? 'duel-tug-me' : 'duel-tug-rival'),
              appearance: me ? widget.myAppearance : widget.rivalAppearance,
              team: me ? ArenaPalette.me : ArenaPalette.rival,
              // يواجه الراية: من على اليسار يشدّ إلى اليسار.
              pullsLeft: (me ? meX : rivalX) < center,
              lean: lean(me),
              size: figure,
            ),
          ),
        if (active)
          Positioned(
            left: (_mineYank ? meX : rivalX) - 30,
            top: groundTop - 22,
            width: 60,
            height: 26,
            child: IgnorePointer(
              child: CustomPaint(
                key: ValueKey('duel-tug-dust-$_pulls'),
                painter: _DustPainter(t: t, outward: (_mineYank ? meX : rivalX) < center ? -1 : 1),
              ),
            ),
          ),
        // الراية في وسط الحبل، تتأرجح مع الشدّة.
        Positioned(
          left: center - 9,
          top: ropeY - 2,
          child: Transform.rotate(
            alignment: Alignment.topCenter,
            angle: -yankSign * jerk * 0.5,
            child: const _Flag(key: ValueKey('duel-tug-flag')),
          ),
        ),
      ],
    );
  }
}

/// الأرضُ العشبيّة، وخطُّ المنتصف، وخطّا الفوز الذهبيّان، والحبلُ المجدول.
class _FieldPainter extends CustomPainter {
  const _FieldPainter({
    required this.center,
    required this.ropeY,
    required this.meX,
    required this.rivalX,
    required this.groundTop,
    required this.meSign,
    required this.wobble,
  });

  final double center;
  final double ropeY;
  final double meX;
  final double rivalX;
  final double groundTop;
  final double meSign;
  final double wobble;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    // العشب: شريطٌ أخضرُ مستدير، وجهتا اللاعبين بلونيهما خفيفاً.
    final ground = RRect.fromLTRBR(0, groundTop, w, size.height, const Radius.circular(10));
    canvas.drawRRect(
      ground,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4ADE80), Color(0xFF15803D)],
        ).createShader(ground.outerRect),
    );
    final mySide = meSign > 0 ? Rect.fromLTRB(w / 2, groundTop, w, size.height) : Rect.fromLTRB(0, groundTop, w / 2, size.height);
    final rivalSide = meSign > 0 ? Rect.fromLTRB(0, groundTop, w / 2, size.height) : Rect.fromLTRB(w / 2, groundTop, w, size.height);
    canvas.save();
    canvas.clipRRect(ground);
    canvas.drawRect(mySide, Paint()..color = ArenaPalette.me.withValues(alpha: 0.22));
    canvas.drawRect(rivalSide, Paint()..color = ArenaPalette.rival.withValues(alpha: 0.22));
    // خصلاتُ عشب.
    final blade = Paint()
      ..color = const Color(0xFF166534)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var x = 6.0; x < w; x += 13) {
      canvas.drawLine(Offset(x, groundTop + 5), Offset(x + 2, groundTop + 1), blade);
      canvas.drawLine(Offset(x + 3, groundTop + 6), Offset(x + 2, groundTop + 1.5), blade);
    }
    canvas.restore();

    // خطُّ المنتصف الأبيض، وخطّا الفوز الذهبيّان حيث تصل الرايةُ بالتقدّم الكامل.
    final mid = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 2;
    for (var y = 4.0; y < size.height - 2; y += 8) {
      canvas.drawLine(Offset(w / 2, y), Offset(w / 2, y + 4), mid);
    }
    final goal = Paint()
      ..color = ArenaPalette.goldLight.withValues(alpha: 0.75)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (final s in [-1.0, 1.0]) {
      final x = w / 2 + s * w * DuelTugOfWar.maxShift;
      canvas.drawLine(Offset(x, groundTop - 10), Offset(x, size.height - 3), goal);
    }

    // الحبل: يرتخي قليلاً في الوسط ويشتدّ مع الشدّة، بجدائلَ مائلة.
    final sag = 5 * (1 - wobble);
    final rope = Path()
      ..moveTo(math.min(meX, rivalX), ropeY)
      ..quadraticBezierTo(center, ropeY + sag, math.max(meX, rivalX), ropeY);
    canvas.drawPath(
      rope,
      Paint()
        ..color = const Color(0xFF78350F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      rope,
      Paint()
        ..color = const Color(0xFFD97706)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round,
    );
    final twist = Paint()
      ..color = const Color(0xFF92400E)
      ..strokeWidth = 1.3;
    for (final metric in rope.computeMetrics()) {
      for (var d = 4.0; d < metric.length; d += 7) {
        final p = metric.getTangentForOffset(d)!.position;
        canvas.drawLine(p + const Offset(-1.6, -1.8), p + const Offset(1.6, 1.8), twist);
      }
    }
  }

  @override
  bool shouldRepaint(_FieldPainter old) =>
      old.center != center ||
      old.ropeY != ropeY ||
      old.meX != meX ||
      old.rivalX != rivalX ||
      old.groundTop != groundTop ||
      old.meSign != meSign ||
      old.wobble != wobble;
}

/// شادٌّ كرتونيّ: رأسُه شخصيةُ اللاعب، وجسمُه بلون فريقه، يميل إلى الوراء
/// بقدر [lean] حول قدميه، وذراعاه ممدودتان إلى الحبل.
class _Puller extends StatelessWidget {
  const _Puller({
    required this.appearance,
    required this.team,
    required this.pullsLeft,
    required this.lean,
    required this.size,
    super.key,
  });

  final Map<String, dynamic>? appearance;
  final Color team;
  final bool pullsLeft;
  final double lean;
  final Size size;

  @override
  Widget build(BuildContext context) {
    const head = 26.0;
    return Transform.rotate(
      alignment: Alignment.bottomCenter,
      // الميلُ إلى الوراء: عكسَ عقارب الساعة لمن يشدّ إلى اليسار.
      angle: pullsLeft ? -lean : lean,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _BodyPainter(team: team, facingRight: pullsLeft)),
          ),
          Positioned(
            top: 0,
            left: (size.width - head) / 2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: team,
                boxShadow: [BoxShadow(color: team.withValues(alpha: 0.6), blurRadius: 8)],
              ),
              child: StudentAvatarView(size: head - 4, appearance: appearance, showRing: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  const _BodyPainter({required this.team, required this.facingRight});

  final Color team;

  /// يواجه الراية: إلى اليمين لمن يقف على يسارها.
  final bool facingRight;

  @override
  void paint(Canvas canvas, Size size) {
    final f = facingRight ? 1.0 : -1.0;
    final cx = size.width / 2;
    final limb = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final hip = Offset(cx, size.height * 0.7);
    // ساقان مثبّتتان: الأماميةُ ممدودةٌ نحو الراية، والخلفيةُ منثنية.
    canvas.drawPath(
      Path()
        ..moveTo(hip.dx, hip.dy)
        ..lineTo(cx + f * 9, size.height * 0.85)
        ..lineTo(cx + f * 15, size.height - 3),
      limb,
    );
    canvas.drawPath(
      Path()
        ..moveTo(hip.dx, hip.dy)
        ..lineTo(cx - f * 4, size.height * 0.86)
        ..lineTo(cx - f * 9, size.height - 3),
      limb,
    );
    final shoe = Paint()..color = const Color(0xFFF8FAFC);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + f * 17, size.height - 2), width: 10, height: 5), shoe);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - f * 7, size.height - 2), width: 10, height: 5), shoe);
    // الجسم: قميصٌ بلون الفريق مع لمعة.
    final torso = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - 9, size.height * 0.38, cx + 9, size.height * 0.74),
      const Radius.circular(8),
    );
    canvas.drawRRect(torso, Paint()..color = team);
    canvas.drawRRect(
      torso.deflate(3),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
    // الذراعان إلى الحبل، وقبضتان.
    final arm = Paint()
      ..color = Color.lerp(team, Colors.black, 0.25)!
      ..strokeWidth = 4.4
      ..strokeCap = StrokeCap.round;
    final shoulder = Offset(cx + f * 3, size.height * 0.45);
    final hand = Offset(cx + f * size.width * 0.5, size.height * 0.56);
    canvas.drawLine(shoulder, hand, arm);
    canvas.drawLine(shoulder + const Offset(0, 4), hand + Offset(-f * 7, 1), arm);
    final fist = Paint()..color = const Color(0xFFFBBF77);
    canvas.drawCircle(hand, 3.4, fist);
    canvas.drawCircle(hand + Offset(-f * 7, 1), 3.4, fist);
  }

  @override
  bool shouldRepaint(_BodyPainter old) => old.team != team || old.facingRight != facingRight;
}

/// غبارٌ يتطاير من قدمي من شدّ: سحاباتٌ تكبر وتبهت.
class _DustPainter extends CustomPainter {
  const _DustPainter({required this.t, required this.outward});

  final double t;
  final double outward;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final fade = (1 - t).clamp(0.0, 1.0);
    final base = Offset(size.width / 2, size.height - 4);
    for (var i = 0; i < 5; i++) {
      final spread = (i - 2) * 6.0;
      final at = base + Offset(outward * (8 + t * 20) + spread, -t * (6 + i * 2));
      canvas.drawCircle(
        at,
        3 + t * (5 + i),
        Paint()..color = const Color(0xFFD6BCA0).withValues(alpha: 0.75 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_DustPainter old) => old.t != t || old.outward != outward;
}

/// رايةٌ حمراءُ مثلّثةٌ معلّقةٌ في الحبل.
class _Flag extends StatelessWidget {
  const _Flag({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 18,
        height: 26,
        child: CustomPaint(painter: _FlagPainter()),
      );
}

class _FlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pole = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), pole);
    final flag = Path()
      ..moveTo(size.width / 2, size.height * 0.35)
      ..lineTo(0, size.height * 0.62)
      ..lineTo(size.width, size.height * 0.62)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(flag, Paint()..color = const Color(0xFFEF4444));
    canvas.drawCircle(Offset(size.width / 2, 2), 3, Paint()..color = ArenaPalette.goldLight);
  }

  @override
  bool shouldRepaint(_FlagPainter old) => false;
}

/// لعبةُ «شدّ الحبل» في المبارزة بين اثنين: اسمُ كلٍّ ونتيجتُه من الأسئلة فوق
/// الحبل، والتاجُ لمن فاز حين تُحسم. والحبلُ يسير بعدد ما أصاب كلٌّ — كبقيّة
/// الحلبات، لا بحسابٍ خاصٍّ بها.
class TugOfWarArena extends StatelessWidget {
  const TugOfWarArena({required this.racers, required this.total, this.finished = false, super.key});

  final List<ArenaRacer> racers;
  final int total;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final meIndex = racers.indexWhere((r) => r.me);
    final me = racers[meIndex < 0 ? 0 : meIndex];
    final rival = racers.firstWhere((r) => !identical(r, me), orElse: () => racers.last);
    final winner = !finished || me.at == rival.at ? null : (me.at > rival.at ? me : rival);
    Widget side(ArenaRacer r, Color team, CrossAxisAlignment align) => Expanded(
          child: Column(
            crossAxisAlignment: align,
            children: [
              Text(
                '${identical(winner, r) ? '👑 ' : ''}${r.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: StudentSurface.ink(context)),
              ),
              Text(
                '${r.at}/$total',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: team),
              ),
              if (r.badge != null)
                Text(
                  r.badge!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: StudentSurface.mutedInk(context)),
                ),
            ],
          ),
        );
    return Column(
      key: const ValueKey('tug-arena'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            side(me, ArenaPalette.me, CrossAxisAlignment.start),
            const Text('💪', style: TextStyle(fontSize: 18)),
            side(rival, ArenaPalette.rival, CrossAxisAlignment.end),
          ],
        ),
        const SizedBox(height: 4),
        DuelTugOfWar(
          myPoints: me.at,
          rivalPoints: rival.at,
          myAppearance: me.appearance,
          rivalAppearance: rival.appearance,
          height: 92,
          steps: total,
        ),
      ],
    );
  }
}
