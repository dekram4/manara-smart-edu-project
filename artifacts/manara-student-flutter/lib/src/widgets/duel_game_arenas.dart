import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/student_theme.dart';
import 'student_avatar_view.dart';

/// ألعابُ «تحدَّ زملاءك» الأربع — على آلية «لمسة»: كل إجابةٍ صحيحة حركةٌ
/// تُرى، ومؤثّرٌ يفرح به الطفل، وتقدّمٌ لا يُخطئه النظر.
///
/// ── والمنطقُ واحدٌ للأربع ──
/// كلُّ لاعبٍ له عددُ ما أصاب من خمسة (`at` من `total`)، يحسمه الخادم: أوّلُ
/// إجابةٍ صحيحة تأخذ السؤال، فالأسرعُ الصحيحُ هو من يتقدّم. وهذه الحلباتُ
/// تُري ذلك وحده — لا تحسب شيئاً ولا تخترع نقطة.
///
///   • سباقُ الحواجز: مساراتٌ مرقّمة، والعدّاءُ يقفز حاجزاً بكل نقطة.
///   • بستانُ الأرقام: الشخصيةُ تصعد الشجرة، وثمرةٌ تسقط في سلّتها.
///   • مغامرةُ الفضاء: الصاروخُ يمضي في مسارٍ متعرّج ويجمع نجومه.
///   • أبراجُ التحدي: مكعّبٌ يسقط في مكانه فيعلو البرج.
///
/// والحركةُ تقع مع النقطة وتنتهي — لا حلقةٌ لا تنتهي — فتهدأ الشاشةُ بين
/// الأسئلة، وتُطفأ كلُّها مع «تقليل الحركة».

/// لاعبٌ في الحلبة.
class ArenaRacer {
  const ArenaRacer({
    required this.name,
    required this.at,
    this.appearance,
    this.me = false,
    this.badge,
  });

  final String name;

  /// ما أصاب من الأسئلة.
  final int at;
  final Map<String, dynamic>? appearance;
  final bool me;

  /// حالٌ تحت الاسم («يلعب الآن» مثلاً).
  final String? badge;
}

const _mineTint = Color(0xFF16A34A);
const _rivalTints = [Color(0xFFDC2626), Color(0xFF2563EB), Color(0xFF9333EA), Color(0xFFEA580C)];

Color _tintOf(List<ArenaRacer> racers, int index) {
  if (racers[index].me) return _mineTint;
  final rivals = [for (var i = 0; i < racers.length; i++) if (!racers[i].me) i];
  return _rivalTints[rivals.indexOf(index) % _rivalTints.length];
}

bool _still(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// الفائزُ إن حُسمت المباراة وتقدّم واحدٌ وحده.
int? _winnerOf(List<ArenaRacer> racers, bool finished) {
  if (!finished || racers.isEmpty) return null;
  final best = racers.map((r) => r.at).reduce(math.max);
  final leaders = [for (var i = 0; i < racers.length; i++) if (racers[i].at == best) i];
  return leaders.length == 1 ? leaders.single : null;
}

/// رأسُ لاعب: رقمُ مساره، واسمُه، وحالُه، ونتيجتُه — والتاجُ للفائز.
class _RacerHeader extends StatelessWidget {
  const _RacerHeader({
    required this.racer,
    required this.lane,
    required this.total,
    required this.tint,
    required this.crowned,
    this.compact = false,
  });

  final ArenaRacer racer;
  final int lane;
  final int total;
  final Color tint;
  final bool crowned;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final number = Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
      child: Text(
        '$lane',
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
    final name = Text(
      racer.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: StudentSurface.ink(context)),
    );
    final score = Text(
      '${racer.at}/$total',
      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: tint),
    );
    if (compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [number, if (crowned) const Text(' 👑')]),
          const SizedBox(height: 2),
          name,
          score,
        ],
      );
    }
    return Row(
      children: [
        number,
        const SizedBox(width: 6),
        Expanded(child: name),
        if (racer.badge != null)
          Flexible(
            child: Text(
              racer.badge!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: StudentSurface.mutedInk(context)),
            ),
          ),
        if (crowned) const Text(' 👑', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        score,
      ],
    );
  }
}

/// يُشغّل [controller] من أوّله حين يزيد [now] على [before].
void _playOnGain(AnimationController controller, int before, int now, BuildContext context) {
  if (now <= before || _still(context)) return;
  controller.forward(from: 0);
}

// ═══════════════════════════════════════════════════════════════════════
// ١) سباقُ الحواجز
// ═══════════════════════════════════════════════════════════════════════

class HurdleRaceArena extends StatelessWidget {
  const HurdleRaceArena({required this.racers, required this.total, this.finished = false, super.key});

  final List<ArenaRacer> racers;
  final int total;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final winner = _winnerOf(racers, finished);
    return Column(
      children: [
        for (var i = 0; i < racers.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _HurdleLane(
            racer: racers[i],
            lane: i + 1,
            total: total,
            tint: _tintOf(racers, i),
            crowned: winner == i,
          ),
        ],
      ],
    );
  }
}

class _HurdleLane extends StatefulWidget {
  const _HurdleLane({
    required this.racer,
    required this.lane,
    required this.total,
    required this.tint,
    required this.crowned,
  });

  final ArenaRacer racer;
  final int lane;
  final int total;
  final Color tint;
  final bool crowned;

  @override
  State<_HurdleLane> createState() => _HurdleLaneState();
}

class _HurdleLaneState extends State<_HurdleLane> with SingleTickerProviderStateMixin {
  /// خطوةٌ واحدة: ركضٌ وقفزةٌ فوق الحاجز وهبوطٌ وعلامةُ الصحّ.
  late final AnimationController _stride = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  );

  @override
  void didUpdateWidget(_HurdleLane old) {
    super.didUpdateWidget(old);
    _playOnGain(_stride, old.racer.at, widget.racer.at, context);
  }

  @override
  void dispose() {
    _stride.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = _still(context);
    final total = math.max(1, widget.total);
    final fraction = (widget.racer.at / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RacerHeader(
          racer: widget.racer,
          lane: widget.lane,
          total: widget.total,
          tint: widget.tint,
          crowned: widget.crowned,
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, box) {
            const runnerWidth = 38.0;
            const height = 78.0;
            final span = math.max(0.0, box.maxWidth - runnerWidth - 18);
            return SizedBox(
              height: height,
              child: AnimatedBuilder(
                animation: _stride,
                builder: (context, _) {
                  final t = _stride.value;
                  final running = _stride.isAnimating;
                  // قفزةٌ فوق الحاجز في منتصف الخطوة.
                  final lift = running ? math.sin(math.pi * t) * 18 : 0.0;
                  // ساقان تدوران ثلاث دورات في الخطوة، وواقفتان بعدها.
                  final legPhase = running ? t * 3 : 0.0;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // المضمار: أرضٌ حمراء وخطّا المسار.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 22,
                        child: CustomPaint(
                          painter: _TrackPainter(
                            hurdles: total,
                            cleared: widget.racer.at,
                            tint: widget.tint,
                            runnerWidth: runnerWidth,
                            rtl: Directionality.of(context) == TextDirection.rtl,
                          ),
                        ),
                      ),
                      const PositionedDirectional(
                        end: 0,
                        bottom: 6,
                        child: Text('🏁', style: TextStyle(fontSize: 22)),
                      ),
                      AnimatedPositionedDirectional(
                        duration: still ? Duration.zero : const Duration(milliseconds: 700),
                        curve: Curves.easeInOutCubic,
                        start: span * fraction,
                        bottom: 10 + lift,
                        child: _Runner(
                          appearance: widget.racer.appearance,
                          phase: legPhase,
                          tint: widget.tint,
                        ),
                      ),
                      // علامةُ الصحّ الخضراء ونجومٌ تتطاير — مع الخطوة وحدها.
                      if (running)
                        PositionedDirectional(
                          start: span * fraction + 4,
                          top: -6,
                          child: _CheckBurst(t: t),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

/// عدّاءٌ: رأسُ الشخصية على جسمٍ يركض — قميصٌ بلون اللاعب، وذراعان وساقان
/// تتأرجحان بالطور [phase]، وحذاءان. واقفاً تتباعد ساقاه قليلاً فلا تُرى خطّاً.
class _Runner extends StatelessWidget {
  const _Runner({required this.appearance, required this.phase, required this.tint});

  final Map<String, dynamic>? appearance;
  final double phase;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 58,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomPaint(painter: _RunnerBodyPainter(phase: phase, tint: tint)),
          ),
          StudentAvatarView(size: 30, appearance: appearance, showRing: false),
        ],
      ),
    );
  }
}

class _RunnerBodyPainter extends CustomPainter {
  _RunnerBodyPainter({required this.phase, required this.tint});

  final double phase;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    // واقفاً: زاويةٌ ثابتةٌ تُباعد الساقين. راكضاً: تأرجحٌ كامل.
    final swing = phase == 0 ? 0.32 : math.sin(phase * 2 * math.pi) * 0.75;
    final cx = size.width / 2;
    final shoulderY = size.height * 0.04;
    final hipY = size.height * 0.40;
    final limb = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    final leg = size.height * 0.58;
    final arm = size.height * 0.36;

    // الذراعان خلف القميص، تعاكسان الساقين.
    for (final side in [1.0, -1.0]) {
      final a = -swing * side;
      final elbow = Offset(cx, shoulderY + 3) + Offset(math.sin(a) * arm * 0.55, math.cos(a) * arm * 0.55);
      final hand = elbow + Offset(math.sin(a + 0.8) * arm * 0.45, math.cos(a + 0.8) * arm * 0.45);
      canvas.drawLine(Offset(cx, shoulderY + 3), elbow, limb);
      canvas.drawLine(elbow, hand, limb);
    }
    // الساقان: تنثني الركبةُ في الخلفية منهما، وحذاءٌ في آخر كلٍّ.
    for (final side in [1.0, -1.0]) {
      final a = swing * side;
      final hip = Offset(cx + side * 2, hipY);
      final knee = hip + Offset(math.sin(a) * leg * 0.5, math.cos(a) * leg * 0.5);
      final bend = a < 0 ? 0.7 : 0.1;
      final foot = knee + Offset(math.sin(a - bend) * leg * 0.48, math.cos(a - bend) * leg * 0.48);
      canvas.drawLine(hip, knee, limb);
      canvas.drawLine(knee, foot, limb);
      canvas.drawOval(
        Rect.fromCenter(center: foot + const Offset(2, 0), width: 7, height: 4),
        Paint()..color = const Color(0xFF111827),
      );
    }
    // القميص فوق كل شيء: جسمٌ لا خطّ.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - 7, shoulderY, cx + 7, hipY + 3),
        const Radius.circular(5),
      ),
      Paint()..color = tint,
    );
  }

  @override
  bool shouldRepaint(covariant _RunnerBodyPainter old) => old.phase != phase || old.tint != tint;
}

/// الأرضُ الحمراء والحواجز: ما قُفز يبهت، وما بقي قائمٌ أبيضُ وأحمر.
class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.hurdles,
    required this.cleared,
    required this.tint,
    required this.runnerWidth,
    required this.rtl,
  });

  final int hurdles;
  final int cleared;
  final Color tint;
  final double runnerWidth;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final ground = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8));
    canvas.drawRRect(ground, Paint()..color = const Color(0xFFE2725B));
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(0, 3), Offset(size.width, 3), line);
    canvas.drawLine(Offset(0, size.height - 3), Offset(size.width, size.height - 3), line);
    // ما قُطع من المسار يتلوّن بلون اللاعب.
    final span = math.max(0.0, size.width - runnerWidth - 18);
    final done = span * (cleared / math.max(1, hurdles)) + runnerWidth / 2;
    final doneRect = rtl
        ? Rect.fromLTWH(size.width - done, size.height / 2 - 2, done, 4)
        : Rect.fromLTWH(0, size.height / 2 - 2, done, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(doneRect, const Radius.circular(2)),
      Paint()..color = tint.withValues(alpha: 0.75),
    );
    for (var i = 0; i < hurdles; i++) {
      final along = span * (i + 0.5) / hurdles + runnerWidth / 2;
      final x = rtl ? size.width - along : along;
      final knocked = i < cleared;
      // قائمتان داكنتان تُريان فوق الأرض وفوق البطاقة البيضاء معاً.
      final post = Paint()
        ..color = knocked ? const Color(0x66334155) : const Color(0xFF334155)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x - 7, 4), Offset(x - 7, -15), post);
      canvas.drawLine(Offset(x + 7, 4), Offset(x + 7, -15), post);
      // العارضةُ حمراءُ بوسطٍ أبيض، وما قُفز فوقه يميل ويبهت.
      canvas.save();
      canvas.translate(x, -17);
      if (knocked) canvas.rotate(rtl ? 0.35 : -0.35);
      final bar = Rect.fromCenter(center: Offset.zero, width: 20, height: 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(2)),
        Paint()..color = knocked ? const Color(0x88DC2626) : const Color(0xFFDC2626),
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 6, height: 6),
        Paint()..color = Colors.white.withValues(alpha: knocked ? 0.5 : 1),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _TrackPainter old) =>
      old.cleared != cleared || old.hurdles != hurdles || old.tint != tint || old.rtl != rtl;
}

/// علامةُ صحٍّ خضراء تكبر ثم تبهت، ونجومٌ تتطاير حولها.
class _CheckBurst extends StatelessWidget {
  const _CheckBurst({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final grow = Curves.easeOutBack.transform(math.min(1.0, t * 2.2));
    final fade = t < 0.65 ? 1.0 : (1 - (t - 0.65) / 0.35).clamp(0.0, 1.0);
    return IgnorePointer(
      child: Opacity(
        opacity: fade,
        child: SizedBox(
          width: 60,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Transform.scale(
                scale: grow,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                ),
              ),
              for (var i = 0; i < 3; i++)
                Positioned(
                  left: 10 + math.cos(-0.4 - i * 0.9) * 26 * t,
                  top: 6 + math.sin(-0.4 - i * 0.9) * 22 * t,
                  child: Text('⭐', style: TextStyle(fontSize: 10 + 4 * (1 - t))),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ٢) بستانُ الأرقام
// ═══════════════════════════════════════════════════════════════════════

const _fruitColors = [
  Color(0xFFEF4444),
  Color(0xFFF59E0B),
  Color(0xFFEAB308),
  Color(0xFFA855F7),
  Color(0xFFEC4899),
  Color(0xFF22C55E),
];

class NumberOrchardArena extends StatelessWidget {
  const NumberOrchardArena({required this.racers, required this.total, this.finished = false, super.key});

  final List<ArenaRacer> racers;
  final int total;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final winner = _winnerOf(racers, finished);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < racers.length; i++)
          Expanded(
            child: _OrchardTree(
              racer: racers[i],
              lane: i + 1,
              total: total,
              tint: _tintOf(racers, i),
              crowned: winner == i,
              compact: racers.length > 2,
            ),
          ),
      ],
    );
  }
}

class _OrchardTree extends StatefulWidget {
  const _OrchardTree({
    required this.racer,
    required this.lane,
    required this.total,
    required this.tint,
    required this.crowned,
    required this.compact,
  });

  final ArenaRacer racer;
  final int lane;
  final int total;
  final Color tint;
  final bool crowned;
  final bool compact;

  @override
  State<_OrchardTree> createState() => _OrchardTreeState();
}

class _OrchardTreeState extends State<_OrchardTree> with SingleTickerProviderStateMixin {
  /// ثمرةٌ تسقط في السلّة، والشخصيةُ تصعد درجة.
  late final AnimationController _pick = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  );

  @override
  void didUpdateWidget(_OrchardTree old) {
    super.didUpdateWidget(old);
    _playOnGain(_pick, old.racer.at, widget.racer.at, context);
  }

  @override
  void dispose() {
    _pick.dispose();
    super.dispose();
  }

  /// موضعُ الثمرة [i] في التاج، نسبةً من عرض العمود وارتفاعه.
  Offset _fruitSpot(int i, Size size) {
    final count = math.max(1, widget.total);
    final angle = math.pi * (0.15 + 0.7 * (i + 0.5) / count);
    final rx = math.min(size.width * 0.30, 56.0);
    return Offset(
      size.width / 2 - math.cos(angle) * rx,
      50 - math.sin(angle) * 24 + (i.isEven ? 6 : -4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final still = _still(context);
    final total = math.max(1, widget.total);
    final at = widget.racer.at.clamp(0, total);
    return Column(
      children: [
        _RacerHeader(
          racer: widget.racer,
          lane: widget.lane,
          total: widget.total,
          tint: widget.tint,
          crowned: widget.crowned,
          compact: true,
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, box) {
            final size = Size(box.maxWidth, 200);
            final trunkTop = 64.0;
            final trunkBottom = size.height - 44;
            final climbY = trunkBottom - (trunkBottom - trunkTop) * (at / total) - 30;
            final basket = Offset(size.width / 2, size.height - 20);
            return SizedBox(
              width: size.width,
              height: size.height,
              child: AnimatedBuilder(
                animation: _pick,
                builder: (context, _) {
                  final t = _pick.value;
                  final falling = _pick.isAnimating && at > 0;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // الجذعُ والتاج.
                      Positioned(
                        left: size.width / 2 - 7,
                        top: trunkTop,
                        width: 14,
                        height: trunkBottom - trunkTop,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5A2B),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      // التاجُ بعرضٍ أقصى، فلا يصير شريطاً في الشاشة العريضة.
                      Positioned(
                        left: size.width / 2 - math.min(size.width * 0.38, 76.0),
                        width: math.min(size.width * 0.76, 152.0),
                        top: 14,
                        height: 72,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFF22A06B),
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: const [BoxShadow(color: Color(0x3322A06B), blurRadius: 10)],
                          ),
                        ),
                      ),
                      // ثمارٌ لم تُقطف بعد.
                      for (var i = at; i < total; i++)
                        Positioned(
                          left: _fruitSpot(i, size).dx - 8,
                          top: _fruitSpot(i, size).dy - 8,
                          child: _Fruit(color: _fruitColors[i % _fruitColors.length]),
                        ),
                      // السلّة وما فيها.
                      Positioned(
                        left: basket.dx - 30,
                        top: basket.dy - 18,
                        width: 60,
                        height: 34,
                        child: _Basket(
                          count: falling ? at - 1 : at,
                          sparkle: falling && t > 0.75 ? (t - 0.75) / 0.25 : 0,
                        ),
                      ),
                      // الثمرةُ الساقطة: من مكانها في التاج إلى السلّة، تدور.
                      if (falling)
                        Builder(builder: (context) {
                          final from = _fruitSpot(at - 1, size);
                          final p = Curves.easeIn.transform(math.min(1.0, t / 0.8));
                          final x = from.dx + (basket.dx - from.dx) * p;
                          final y = from.dy + (basket.dy - 14 - from.dy) * p - math.sin(p * math.pi) * 14;
                          return Positioned(
                            left: x - 8,
                            top: y - 8,
                            child: Transform.rotate(
                              angle: p * math.pi * 2,
                              child: _Fruit(color: _fruitColors[(at - 1) % _fruitColors.length]),
                            ),
                          );
                        }),
                      // الشخصيةُ على الجذع، تصعد درجةً بكل ثمرة.
                      AnimatedPositioned(
                        duration: still ? Duration.zero : const Duration(milliseconds: 600),
                        curve: Curves.easeOutBack,
                        left: size.width / 2 - 15,
                        top: climbY,
                        child: StudentAvatarView(size: 30, appearance: widget.racer.appearance),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Fruit extends StatelessWidget {
  const _Fruit({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 18,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.4, -0.4),
                colors: [Color.lerp(color, Colors.white, 0.45)!, color],
              ),
            ),
          ),
          const Positioned(
            top: 0,
            child: SizedBox(
              width: 6,
              height: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFF15803D), borderRadius: BorderRadius.all(Radius.circular(3))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Basket extends StatelessWidget {
  const _Basket({required this.count, required this.sparkle});

  final int count;
  final double sparkle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        // الثمارُ المجموعة فوق حافّة السلّة.
        Positioned(
          bottom: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < math.min(count, 5); i++)
                Transform.translate(
                  offset: Offset(0, i.isEven ? 0 : -3),
                  child: Transform.scale(scale: 0.7, child: _Fruit(color: _fruitColors[i % _fruitColors.length])),
                ),
            ],
          ),
        ),
        Container(
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFFC08A4B),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12), top: Radius.circular(4)),
            border: Border.all(color: const Color(0xFF8B5A2B), width: 1.5),
          ),
        ),
        if (sparkle > 0)
          Positioned(
            top: -12 - sparkle * 10,
            child: Opacity(
              opacity: (1 - sparkle).clamp(0.0, 1.0),
              child: Transform.scale(scale: 0.8 + sparkle, child: const Text('✨', style: TextStyle(fontSize: 16))),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ٣) مغامرةُ الفضاء
// ═══════════════════════════════════════════════════════════════════════

class SpaceVoyageArena extends StatelessWidget {
  const SpaceVoyageArena({required this.racers, required this.total, this.finished = false, super.key});

  final List<ArenaRacer> racers;
  final int total;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final winner = _winnerOf(racers, finished);
    return Column(
      children: [
        for (var i = 0; i < racers.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _VoyageLane(
            racer: racers[i],
            lane: i + 1,
            total: total,
            tint: _tintOf(racers, i),
            crowned: winner == i,
          ),
        ],
      ],
    );
  }
}

class _VoyageLane extends StatefulWidget {
  const _VoyageLane({
    required this.racer,
    required this.lane,
    required this.total,
    required this.tint,
    required this.crowned,
  });

  final ArenaRacer racer;
  final int lane;
  final int total;
  final Color tint;
  final bool crowned;

  @override
  State<_VoyageLane> createState() => _VoyageLaneState();
}

class _VoyageLaneState extends State<_VoyageLane> with SingleTickerProviderStateMixin {
  late final AnimationController _thrust = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// من أين انطلق الصاروخ في هذه الدفعة.
  double _from = 0;

  @override
  void didUpdateWidget(_VoyageLane old) {
    super.didUpdateWidget(old);
    if (widget.racer.at > old.racer.at) {
      _from = old.racer.at / math.max(1, old.total);
    }
    _playOnGain(_thrust, old.racer.at, widget.racer.at, context);
  }

  @override
  void dispose() {
    _thrust.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, widget.total);
    final target = (widget.racer.at / total).clamp(0.0, 1.0);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RacerHeader(
          racer: widget.racer,
          lane: widget.lane,
          total: widget.total,
          tint: widget.tint,
          crowned: widget.crowned,
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, box) {
            final size = Size(box.maxWidth, 78);
            return SizedBox(
              width: size.width,
              height: size.height,
              child: AnimatedBuilder(
                animation: _thrust,
                builder: (context, _) {
                  final moving = _thrust.isAnimating;
                  final t = Curves.easeInOutCubic.transform(_thrust.value);
                  final p = moving ? _from + (target - _from) * t : target;
                  final point = _pathPoint(p, size, rtl);
                  final ahead = _pathPoint(math.min(1.0, p + 0.01), size, rtl);
                  final angle = math.atan2(ahead.dy - point.dy, ahead.dx - point.dx);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _SpacePainter(
                            total: total,
                            collected: widget.racer.at,
                            progress: p,
                            tint: widget.tint,
                            rtl: rtl,
                          ),
                        ),
                      ),
                      Positioned(
                        left: _pathPoint(1, size, rtl).dx - 12,
                        top: _pathPoint(1, size, rtl).dy - 14,
                        child: const Text('🪐', style: TextStyle(fontSize: 22)),
                      ),
                      // نجومُ المحطات: المجموعةُ ذهبيةٌ مضيئة، وما يُجمع الآن ينبض.
                      for (var i = 0; i < total; i++)
                        Builder(builder: (context) {
                          final spot = _pathPoint((i + 1) / total * 0.94, size, rtl);
                          final got = i < widget.racer.at && (i + 1) / total * 0.94 <= p + 0.001;
                          final popping = moving && i == widget.racer.at - 1 && got;
                          final scale = popping ? 1 + math.sin(_thrust.value * math.pi) * 0.8 : 1.0;
                          return Positioned(
                            left: spot.dx - 9,
                            top: spot.dy - 22,
                            child: Transform.scale(
                              scale: scale,
                              child: Icon(
                                got ? Icons.star_rounded : Icons.star_border_rounded,
                                size: 18,
                                color: got ? const Color(0xFFFACC15) : Colors.white54,
                              ),
                            ),
                          );
                        }),
                      // الصاروخ — يميل مع المسار — وصاحبُه بجانبه.
                      Positioned(
                        left: point.dx - 14,
                        top: point.dy - 14,
                        child: Transform.rotate(
                          // الرمزُ 🚀 مائلٌ أصلاً إلى أعلى اليمين (‎-45°).
                          angle: angle + math.pi / 4,
                          child: const Text('🚀', style: TextStyle(fontSize: 22)),
                        ),
                      ),
                      // صاحبُ الصاروخ تحته، أو فوقه حين يكون الصاروخُ في
                      // النصف الأسفل — فلا يخرج من حافّة المسار.
                      Positioned(
                        left: point.dx - 11,
                        top: point.dy > size.height * 0.55 ? point.dy - 36 : point.dy + 8,
                        child: StudentAvatarView(size: 22, appearance: widget.racer.appearance, showRing: false),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

/// نقطةٌ على المسار المتعرّج عند [p] من 0 إلى 1.
Offset _pathPoint(double p, Size size, bool rtl) {
  const pad = 16.0;
  final along = pad + (size.width - pad * 2 - 12) * p;
  final x = rtl ? size.width - along : along;
  final y = size.height * 0.55 + math.sin(p * math.pi * 3) * size.height * 0.22;
  return Offset(x, y);
}

class _SpacePainter extends CustomPainter {
  _SpacePainter({
    required this.total,
    required this.collected,
    required this.progress,
    required this.tint,
    required this.rtl,
  });

  final int total;
  final int collected;
  final double progress;
  final Color tint;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)),
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)]).createShader(Offset.zero & size),
    );
    // نجومٌ صغيرة ثابتةُ المواضع.
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (var i = 0; i < 26; i++) {
      final x = (i * 73 % 100) / 100 * size.width;
      final y = (i * 37 % 100) / 100 * size.height;
      canvas.drawCircle(Offset(x, y), (i % 3) * 0.5 + 0.6, dot);
    }
    // المسارُ كلُّه منقّطاً، وما قُطع منه بلون اللاعب.
    final dash = Paint()
      ..color = Colors.white30
      ..strokeWidth = 2;
    for (var i = 0; i < 60; i += 2) {
      canvas.drawLine(_pathPoint(i / 60, size, rtl), _pathPoint((i + 1) / 60, size, rtl), dash);
    }
    final trail = Paint()
      ..color = tint.withValues(alpha: 0.9)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final steps = (progress * 60).floor();
    for (var i = 0; i < steps; i++) {
      canvas.drawLine(_pathPoint(i / 60, size, rtl), _pathPoint((i + 1) / 60, size, rtl), trail);
    }
  }

  @override
  bool shouldRepaint(covariant _SpacePainter old) =>
      old.progress != progress || old.collected != collected || old.tint != tint || old.rtl != rtl;
}

// ═══════════════════════════════════════════════════════════════════════
// ٤) أبراجُ التحدي
// ═══════════════════════════════════════════════════════════════════════

const _blockColors = [
  Color(0xFF3B82F6),
  Color(0xFFF97316),
  Color(0xFF22C55E),
  Color(0xFFEAB308),
  Color(0xFFA855F7),
  Color(0xFFEF4444),
];

class ChallengeTowersArena extends StatelessWidget {
  const ChallengeTowersArena({required this.racers, required this.total, this.finished = false, super.key});

  final List<ArenaRacer> racers;
  final int total;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final winner = _winnerOf(racers, finished);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < racers.length; i++)
          Expanded(
            child: _Tower(
              racer: racers[i],
              lane: i + 1,
              total: total,
              tint: _tintOf(racers, i),
              crowned: winner == i,
            ),
          ),
      ],
    );
  }
}

class _Tower extends StatefulWidget {
  const _Tower({
    required this.racer,
    required this.lane,
    required this.total,
    required this.tint,
    required this.crowned,
  });

  final ArenaRacer racer;
  final int lane;
  final int total;
  final Color tint;
  final bool crowned;

  @override
  State<_Tower> createState() => _TowerState();
}

class _TowerState extends State<_Tower> with SingleTickerProviderStateMixin {
  /// مكعّبٌ يسقط في مكانه، يرتدّ، ويستقرّ.
  late final AnimationController _drop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 780),
  );

  @override
  void didUpdateWidget(_Tower old) {
    super.didUpdateWidget(old);
    _playOnGain(_drop, old.racer.at, widget.racer.at, context);
  }

  @override
  void dispose() {
    _drop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, widget.total);
    final at = widget.racer.at.clamp(0, total);
    const height = 210.0;
    const ground = 18.0;
    final blockH = ((height - 70) / total).clamp(16.0, 30.0).toDouble();
    return Column(
      children: [
        _RacerHeader(
          racer: widget.racer,
          lane: widget.lane,
          total: widget.total,
          tint: widget.tint,
          crowned: widget.crowned,
          compact: true,
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth;
            final blockW = math.min(width * 0.62, 70.0);
            final left = (width - blockW) / 2;
            double slotTop(int i) => height - ground - blockH * (i + 1);
            return SizedBox(
              width: width,
              height: height,
              child: AnimatedBuilder(
                animation: _drop,
                builder: (context, _) {
                  final t = _drop.value;
                  final dropping = _drop.isAnimating && at > 0;
                  final settled = dropping ? at - 1 : at;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // الأرض.
                      Positioned(
                        left: left - 10,
                        width: blockW + 20,
                        top: height - ground,
                        height: 10,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFF94A3B8),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                      // مواضعُ المكعّبات الباقية: خطوطٌ منقّطة تقول كم بقي.
                      for (var i = at; i < total; i++)
                        Positioned(
                          left: left,
                          top: slotTop(i),
                          width: blockW,
                          height: blockH - 2,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: widget.tint.withValues(alpha: 0.25), width: 1.2),
                            ),
                          ),
                        ),
                      for (var i = 0; i < settled; i++)
                        Positioned(
                          left: left,
                          top: slotTop(i),
                          width: blockW,
                          height: blockH - 2,
                          child: _Block(color: _blockColors[i % _blockColors.length]),
                        ),
                      // المكعّبُ الساقط: يهبط ثم يرتدّ وينضغط عند الملامسة.
                      if (dropping)
                        Builder(builder: (context) {
                          final fall = Curves.bounceOut.transform(t);
                          final top = -blockH * 2 + (slotTop(at - 1) + blockH * 2) * fall;
                          final squash = t > 0.35 && t < 0.55 ? math.sin((t - 0.35) / 0.2 * math.pi) * 0.12 : 0.0;
                          return Positioned(
                            left: left - blockW * squash / 2,
                            top: top + (blockH - 2) * squash,
                            width: blockW * (1 + squash),
                            height: (blockH - 2) * (1 - squash),
                            child: _Block(color: _blockColors[(at - 1) % _blockColors.length]),
                          );
                        }),
                      // البرجُ اكتمل: رايةٌ في قمّته.
                      if (at >= total)
                        Positioned(
                          left: width / 2 - 10,
                          top: slotTop(total - 1) - 26,
                          child: const Text('🚩', style: TextStyle(fontSize: 20)),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.25)!, color],
        ),
        border: Border.all(color: Color.lerp(color, Colors.black, 0.25)!, width: 1.4),
        boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 2), blurRadius: 2)],
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), shape: BoxShape.circle),
        ),
      ),
    );
  }
}
