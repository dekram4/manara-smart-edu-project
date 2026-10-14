import 'dart:math' as math;

import 'package:flutter/material.dart';

/// طابعُ حركة رسمة البطاقة — لكل بوابةٍ حركةٌ تشبه ما تفتحه.
enum TileArtMotion {
  /// شرح الدرس / المعلم الافتراضي: إيماءةُ رأسٍ هادئة كمن يشرح.
  nod,

  /// السينما: تمايلٌ ووميضُ عرضٍ ونجومٌ لامعة.
  sway,

  /// الترفيه: قفزةٌ بانضغاطٍ وتمدّد كلعبة نطّاطة.
  hop,

  /// شخصيتي: هزّةٌ مرحة ونبضةُ قلب.
  wiggle,

  /// الاختبارات: نبضٌ واثق.
  pulse,

  /// حلّ المسائل: تأرجحٌ كالبندول مع شرارات.
  rock,

  /// اللقاء المباشر: موجاتُ بثٍّ تتّسع.
  broadcast,

  /// الدردشة: ميلٌ من جانبٍ لآخر كمن يتكلّم.
  chatter,

  /// المذاكرة: صفحةٌ تنقلب.
  flip,
}

/// يحدّد الحركة من مفتاح عنوان البطاقة (`portal.<id>`).
TileArtMotion tileArtMotionFor(String titleKey) {
  switch (titleKey.replaceFirst('portal.', '')) {
    case 'lesson':
    case 'tutor':
      return TileArtMotion.nod;
    case 'cinema':
      return TileArtMotion.sway;
    case 'games':
      return TileArtMotion.hop;
    case 'personality':
      return TileArtMotion.wiggle;
    case 'quiz':
      return TileArtMotion.pulse;
    case 'solver':
      return TileArtMotion.rock;
    case 'meeting':
      return TileArtMotion.broadcast;
    case 'chat':
      return TileArtMotion.chatter;
    case 'study':
      return TileArtMotion.flip;
  }
  return TileArtMotion.pulse;
}

/// رسمةُ بطاقةٍ حيّة: حركةٌ مستمرّة تخصّها، ونجومٌ تلمع حولها، وقفزةٌ مع دورةٍ
/// حين تُلمس.
///
/// ── داخل البطاقة لا مكانها ──
/// البطاقةُ نفسها تتنفّس وتميل تحت الإصبع وتُوزَّع عند الفتح، وهذه كلُّها كما
/// هي. ما يتحرّك هنا هو الرسمةُ داخلها وحدها، فتبدو البوابةُ حيّة لا صورةً
/// ثابتة في إطارٍ متحرّك.
///
/// والرسمةُ نفسُها لا تتغيّر: الحركةُ تحويلاتٌ عليها (إزاحة، دوران، مقياس)،
/// ولا يُعاد رسمها. وكلُّ المقادير نِسَبٌ من مقاسها، فتصلح لبطاقة الهاتف
/// الرأسيّ الصغيرة ولبطاقة اللوح الأفقيّ الكبيرة.
class LivingTileArt extends StatefulWidget {
  const LivingTileArt({
    required this.motion,
    required this.child,
    required this.accent,
    this.index = 0,
    super.key,
  });

  final TileArtMotion motion;
  final Widget child;

  /// لونُ النجوم وموجات البثّ — لونُ البوابة نفسها.
  final Color accent;

  /// يُزيح طورَ كل بطاقة فلا تتحرّك الرسومُ معاً كجسمٍ واحد.
  final int index;

  @override
  State<LivingTileArt> createState() => _LivingTileArtState();
}

class _LivingTileArtState extends State<LivingTileArt>
    with TickerProviderStateMixin {
  /// الحركةُ المستمرّة: دورةٌ بطولٍ يختلف قليلاً من بطاقةٍ لأخرى.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 2400 + (widget.index % 4) * 230),
  );

  /// ردُّ اللمس: قفزةٌ ودورةٌ كاملة، مرةً واحدة.
  late final AnimationController _poke = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reduced) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.value = (widget.index % 7) / 7;
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _poke.dispose();
    super.dispose();
  }

  void _onPoke() {
    if (_reduced) return;
    _poke.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // حركةٌ أقلّ: الرسمةُ كما هي، بلا تحويلٍ ولا نجوم.
    if (_reduced) return widget.child;

    return Listener(
      // يرى اللمسةَ ولا يأخذها: البطاقةُ فوقه هي التي تفتح البوابة.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onPoke(),
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest.isFinite ? box.biggest : const Size(120, 120);
          final unit = size.shortestSide;
          return AnimatedBuilder(
            animation: Listenable.merge([_loop, _poke]),
            child: widget.child,
            builder: (context, child) {
              final t = _loop.value;
              final wave = math.sin(t * 2 * math.pi);
              final m = _motionAt(widget.motion, t, wave, unit);

              // اللمس: قفزةٌ للأعلى ودورةٌ كاملة تنتهي في مكانها.
              final p = _poke.value;
              final pokeLift = math.sin(p * math.pi) * unit * 0.12;
              final pokeSpin = Curves.easeInOutBack.transform(p) * math.pi * 2;
              final pokeScale = 1 + math.sin(p * math.pi) * 0.12;

              final art = Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0015)
                  ..translateByDouble(m.dx, m.dy - pokeLift, 0, 1)
                  ..rotateZ(m.rotation)
                  ..rotateY(m.flipY + (p > 0 && p < 1 ? pokeSpin : 0))
                  ..scaleByDouble(
                    m.scaleX * pokeScale,
                    m.scaleY * pokeScale,
                    1,
                    1,
                  ),
                child: child,
              );

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (widget.motion == TileArtMotion.broadcast)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _BroadcastPainter(t: t, color: widget.accent),
                      ),
                    ),
                  art,
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _SparklePainter(
                          t: t,
                          seed: widget.index,
                          color: widget.accent,
                          burst: p,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ArtMotion {
  const _ArtMotion({
    this.dx = 0,
    this.dy = 0,
    this.rotation = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.flipY = 0,
  });

  final double dx;
  final double dy;
  final double rotation;
  final double scaleX;
  final double scaleY;
  final double flipY;
}

_ArtMotion _motionAt(TileArtMotion motion, double t, double wave, double unit) {
  switch (motion) {
    case TileArtMotion.nod:
      return _ArtMotion(
        dy: -wave.abs() * unit * 0.06,
        rotation: math.sin(t * 4 * math.pi) * 0.10,
      );
    case TileArtMotion.sway:
      return _ArtMotion(
        dx: wave * unit * 0.05,
        rotation: wave * 0.13,
        scaleX: 1 + math.sin(t * 6 * math.pi) * 0.03,
        scaleY: 1 + math.sin(t * 6 * math.pi) * 0.03,
      );
    case TileArtMotion.hop:
      // نصفُ الدورة قفزةٌ ونصفُها راحة؛ ينضغط قبل القفز وعند الهبوط.
      final jump = t < 0.5 ? math.sin(t * 2 * math.pi) : 0.0;
      final squash = t < 0.08
          ? math.sin(t / 0.08 * math.pi) * 0.10
          : (t > 0.46 && t < 0.58 ? math.sin((t - 0.46) / 0.12 * math.pi) * 0.12 : 0.0);
      return _ArtMotion(
        dy: -jump * unit * 0.16,
        scaleX: 1 + squash,
        scaleY: 1 - squash + jump * 0.05,
      );
    case TileArtMotion.wiggle:
      final beat = math.pow(math.max(0.0, math.sin(t * 4 * math.pi)), 6).toDouble();
      return _ArtMotion(
        rotation: math.sin(t * 6 * math.pi) * 0.11,
        scaleX: 1 + beat * 0.11,
        scaleY: 1 + beat * 0.11,
      );
    case TileArtMotion.pulse:
      final s = 1 + (wave * 0.5 + 0.5) * 0.12;
      return _ArtMotion(scaleX: s, scaleY: s, dy: -wave * unit * 0.03);
    case TileArtMotion.rock:
      return _ArtMotion(
        rotation: wave * 0.20,
        dy: -math.cos(t * 4 * math.pi).abs() * unit * 0.04,
      );
    case TileArtMotion.broadcast:
      final s = 1 + math.sin(t * 4 * math.pi) * 0.06;
      return _ArtMotion(scaleX: s, scaleY: s);
    case TileArtMotion.chatter:
      return _ArtMotion(
        rotation: math.sin(t * 8 * math.pi) * 0.09,
        dx: wave * unit * 0.04,
        dy: -math.sin(t * 8 * math.pi).abs() * unit * 0.03,
      );
    case TileArtMotion.flip:
      // صفحةٌ تنقلب على محورها العموديّ مرةً في الدورة، ثم تستقرّ.
      final turn = t < 0.35 ? Curves.easeInOut.transform(t / 0.35) : 1.0;
      return _ArtMotion(
        flipY: turn * math.pi * 2,
        dy: -math.sin(turn * math.pi) * unit * 0.05,
      );
  }
}

/// نجومٌ صغيرة تلمع وتخبو حول الرسمة، وتتوهّج كلُّها لحظةَ اللمس.
class _SparklePainter extends CustomPainter {
  _SparklePainter({
    required this.t,
    required this.seed,
    required this.color,
    required this.burst,
  });

  final double t;
  final int seed;
  final Color color;
  final double burst;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final glow = math.sin(burst * math.pi);
    for (var i = 0; i < 4; i++) {
      // مواضعُ ثابتةٌ لكل بطاقة، على حافّة الرسمة لا فوقها.
      final a = (seed * 1.7 + i * 1.57) % (math.pi * 2);
      final r = unit * (0.40 + 0.06 * (i % 2));
      final center = size.center(Offset.zero) + Offset(math.cos(a), math.sin(a)) * r;
      final twinkle = math.max(0.0, math.sin((t + i * 0.25) * 2 * math.pi));
      final strength = math.max(twinkle, glow);
      if (strength < 0.05) continue;
      final arm = unit * (0.05 + 0.03 * strength + 0.04 * glow);
      final paint = Paint()
        ..color = Color.lerp(color, Colors.white, 0.45)!.withValues(alpha: 0.85 * strength);
      final star = Path()
        ..moveTo(center.dx, center.dy - arm)
        ..quadraticBezierTo(center.dx, center.dy, center.dx + arm, center.dy)
        ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + arm)
        ..quadraticBezierTo(center.dx, center.dy, center.dx - arm, center.dy)
        ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - arm)
        ..close();
      canvas.drawPath(star, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) =>
      old.t != t || old.burst != burst || old.color != color;
}

/// موجاتُ بثٍّ تتّسع من خلف رسمة اللقاء المباشر وتتلاشى.
class _BroadcastPainter extends CustomPainter {
  _BroadcastPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide * 0.55;
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      canvas.drawCircle(
        center,
        maxR * (0.35 + 0.65 * p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.shortestSide * 0.02
          ..color = color.withValues(alpha: (1 - p) * 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BroadcastPainter old) => old.t != t || old.color != color;
}
