import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/student_strings.dart';
import '../models/study_games.dart';

/// بطاقةُ «تتبّع واكتب» على رفّ ألعاب الدرس — تدعو الطفلَ إليها من النظرة الأولى.
///
/// ── ما فيها ──
/// - تدرّجٌ بنفسجيٌّ ورديٌّ ذهبيّ، وإطارٌ متوهّجٌ ينبض.
/// - شارةٌ متمايلة في الزاوية: «✨ العب واكسب جواهر!».
/// - رسمٌ حيّ: قلمٌ يمرّ على نقاط حرفٍ فيكتبه، وحروفٌ تطفو، ونجومٌ تتلألأ.
/// - جوهرةٌ ونقاطُ خبرةٍ تلمعان بمقدار المكافأة.
/// - لمسةٌ تُصغّر البطاقة قليلاً وتهتزّ بها اليد، ثم تعود.
///
/// ── ساعةٌ واحدة لكل الحركة ──
/// النبضُ والتوهّجُ والطفوُ والقلمُ والنجوم مراحلُ من [AnimationController]
/// واحد يدور: رفُّ ألعابٍ فيه أربعُ بطاقات لا يحتاج عشرين مؤقّتاً.
///
/// ── ومن طلب الثبات ──
/// «تقليل الحركة» في الجهاز يوقف الساعة: تبقى البطاقةُ بألوانها وشارتها
/// ورسمها كاملاً، ساكنةً — كما يفعل `_Bouncing` في الرفّ نفسه.
class TracingShelfCard extends StatefulWidget {
  const TracingShelfCard({
    required this.game,
    required this.onTap,
    this.index = 0,
    super.key,
  });

  final StudyGame game;
  final VoidCallback onTap;

  /// موضعُها في الرفّ: دخولُها يتأخّر بقدره كبقيّة البطاقات.
  final int index;

  @override
  State<TracingShelfCard> createState() => _TracingShelfCardState();
}

class _TracingShelfCardState extends State<TracingShelfCard>
    with SingleTickerProviderStateMixin {
  static const violet = Color(0xFF7C3AED);
  static const pink = Color(0xFFEC4899);
  static const gold = Color(0xFFF59E0B);

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  bool _pressed = false;
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_still) {
      _clock
        ..stop()
        ..value = 0.35; // لقطةٌ يظهر فيها نصفُ الحرف مكتوباً.
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _down() {
    HapticFeedback.selectionClick();
    setState(() => _pressed = true);
  }

  void _release() {
    if (_pressed) setState(() => _pressed = false);
  }

  void _tap() {
    HapticFeedback.lightImpact();
    _release();
    widget.onTap();
  }

  /// ‎0..1 ذهاباً وإياباً، من ساعةٍ تدور — بإزاحة [phase] من دورتها.
  double _wave(double phase) =>
      0.5 - 0.5 * math.cos(2 * math.pi * ((_clock.value + phase) % 1.0));

  @override
  Widget build(BuildContext context) {
    final en = widget.game.tracing.isNotEmpty && widget.game.tracing.first.lang == 'en';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + widget.index * 140),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 30 * (1 - t)), child: child),
      ),
      child: Padding(
        // متّسعٌ فوقها للشارة البارزة من حافّتها.
        padding: const EdgeInsets.only(top: 12, bottom: 16),
        child: Semantics(
          button: true,
          label: '${widget.game.title} — ${tr('study.trace.badge')}',
          child: GestureDetector(
            onTapDown: (_) => _down(),
            onTapUp: (_) => _tap(),
            onTapCancel: _release,
            child: AnimatedScale(
              scale: _pressed ? 0.94 : 1.0,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutBack,
              child: AnimatedBuilder(
                animation: _clock,
                builder: (context, _) => _card(context, en),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, bool en) {
    final pulse = _still ? 0.0 : _wave(0);
    final glow = 14 + 14 * pulse;
    return Transform.scale(
      scale: 1 + 0.025 * pulse,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // الإطارُ المتوهّج: تدرّجٌ ذهبيٌّ أبيض حول البطاقة، وظلٌّ ملوّنٌ ينبض.
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: SweepGradient(
                colors: const [gold, Colors.white, pink, gold],
                transform: GradientRotation(2 * math.pi * _clock.value),
              ),
              boxShadow: [
                BoxShadow(
                  color: pink.withValues(alpha: 0.35 + 0.25 * pulse),
                  blurRadius: glow,
                  spreadRadius: 1 + 2 * pulse,
                ),
                BoxShadow(
                  color: violet.withValues(alpha: 0.30),
                  blurRadius: glow * 1.6,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: const LinearGradient(
                  colors: [violet, pink, gold],
                  stops: [0.0, 0.58, 1.0],
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Stack(
                  children: [
                    ..._sparkles(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
                      child: Row(
                        children: [
                          SizedBox(width: 104, height: 112, child: _illustration(en)),
                          const SizedBox(width: 12),
                          Expanded(child: _text(context)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          PositionedDirectional(top: -14, end: 14, child: _badge()),
        ],
      ),
    );
  }

  /// نجومٌ متناثرةٌ تتلألأ كلٌّ في وقتها — مرسومةً لا حروفاً: «✦» ليست في
  /// كل خطوط الأجهزة، فتظهر مربّعاتٍ فارغة. ولا تأخذ من حجم البطاقة شيئاً.
  List<Widget> _sparkles() => [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _SparklePainter(
                twinkle: [for (final phase in _SparklePainter.phases) _still ? 0.6 : _wave(phase)],
              ),
            ),
          ),
        ),
      ];

  /// قلمٌ يكتب حرفاً على نقاطه، وحروفٌ صغيرةٌ تطفو حوله.
  Widget _illustration(bool en) {
    final float = _still ? 0.0 : _wave(0.25);
    final letters = en ? const ['A', 'b', '3'] : const ['ب', 'ج', '٣'];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 2),
            ),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: CustomPaint(painter: _DottedLetterPainter(progress: _clock.value)),
          ),
        ),
        for (var i = 0; i < letters.length; i++)
          PositionedDirectional(
            start: [-8.0, 74.0, 66.0][i],
            top: [-6.0, -10.0, 84.0][i] - 6 * (_still ? 0 : _wave(i * 0.33)),
            child: Transform.rotate(
              angle: [-0.25, 0.2, -0.1][i],
              child: Text(
                letters[i],
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: [const Color(0xFFFFF176), Colors.white, const Color(0xFF7DD3FC)][i],
                  shadows: const [Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 3)],
                ),
              ),
            ),
          ),
        // القلمُ يتبع رأسَ الخطّ المكتوب.
        Builder(builder: (context) {
          final tip = _DottedLetterPainter.tipAt(_clock.value, const Size(76, 84));
          return Positioned(
            left: 14 + tip.dx - 6,
            top: 14 + tip.dy - 30 - 3 * float,
            child: const Text('✏️', style: TextStyle(fontSize: 30)),
          );
        }),
      ],
    );
  }

  Widget _text(BuildContext context) {
    final gems = widget.game.gemsReward;
    final points = widget.game.pointsReward;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.game.title,
          style: const TextStyle(
            fontSize: 23,
            height: 1.15,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 4)],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.game.instructions,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _rewardChip('💎', '+$gems', const Color(0xFF22D3EE), 0.0),
            _rewardChip('⭐', '+$points XP', const Color(0xFFFDE047), 0.5),
            _playButton(),
          ],
        ),
      ],
    );
  }

  /// جوهرةٌ أو نجمةٌ تلمع بمقدارها.
  Widget _rewardChip(String emoji, String label, Color shine, double phase) {
    final glint = _still ? 0.0 : _wave(phase);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(color: shine.withValues(alpha: 0.55 * glint), blurRadius: 10 * glint),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.scale(
            scale: 1 + 0.25 * glint,
            child: Transform.rotate(
              angle: 0.25 * (glint - 0.5),
              child: Text(emoji, style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _playButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 3), blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr('study.trace.play'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: violet),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.play_arrow_rounded, color: violet, size: 20),
        ],
      ),
    );
  }

  /// الشارةُ في الزاوية: تتمايل وتكبر قليلاً لتُرى.
  Widget _badge() {
    final swing = _still ? 0.5 : _wave(0.1);
    return Transform.rotate(
      angle: 0.07 * (swing - 0.5) * 2,
      child: Transform.scale(
        scale: 1 + 0.06 * swing,
        child: Container(
          key: const ValueKey('tracing-badge'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFDE047), gold]),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: gold.withValues(alpha: 0.6),
                blurRadius: 8 + 6 * swing,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            tr('study.trace.badge'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF7C2D12)),
          ),
        ),
      ),
    );
  }
}

/// نجومٌ رباعيةُ الأطراف في مواضعَ ثابتةٍ من البطاقة، يكبر كلٌّ ويضيء بقدر [twinkle].
class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.twinkle});

  /// لكلّ نجمةٍ: موضعُها نسبةً إلى البطاقة، وحجمُها، وإزاحتُها في الدورة.
  static const spots = [
    (0.42, 0.10, 7.0),
    (0.20, 0.25, 5.5),
    (0.03, 0.55, 8.0),
    (0.33, 0.93, 5.0),
    (0.96, 0.92, 6.0),
    (0.58, 0.80, 4.5),
  ];
  static const phases = [0.0, 0.3, 0.55, 0.8, 0.45, 0.15];

  final List<double> twinkle;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < spots.length; i++) {
      final (fx, fy, radius) = spots[i];
      final glow = twinkle[i];
      final r = radius * (0.7 + 0.6 * glow);
      // ‎fx من بداية السطر: في العربية من اليمين.
      final c = Offset(size.width * (1 - fx), size.height * fy);
      final paint = Paint()..color = Colors.white.withValues(alpha: 0.3 + 0.7 * glow);
      final star = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
        ..close();
      canvas.drawPath(star, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => true;
}

/// حرفٌ منقّطٌ يُكتب: نقاطُ مسارٍ منحنٍ، وما مرّ عليه القلمُ خطٌّ أبيض.
class _DottedLetterPainter extends CustomPainter {
  _DottedLetterPainter({required this.progress});

  /// موضعُ الساعة في دورتها: الكتابةُ في أوّل ٧٠٪ منها، ثم يبقى الحرفُ مكتوباً.
  final double progress;

  static double _drawn(double progress) => (progress / 0.7).clamp(0.0, 1.0);

  /// منحنى يشبه الباء: نزولٌ قصير، ثم قاعٌ عريض، ثم صعود.
  static Offset _point(double t, Size size) {
    final x = size.width * (0.92 - 0.84 * t);
    final dip = math.sin(math.pi * t);
    final y = size.height * (0.30 + 0.42 * dip);
    return Offset(x, y);
  }

  static Offset tipAt(double progress, Size size) => _point(_drawn(progress), size);

  @override
  void paint(Canvas canvas, Size size) {
    const samples = 14;
    final drawn = _drawn(progress);
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.75);
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      if (t <= drawn) continue;
      canvas.drawCircle(_point(t, size), 3.2, dot);
    }
    if (drawn > 0) {
      final path = Path();
      const steps = 40;
      for (var i = 0; i <= steps; i++) {
        final p = _point(drawn * i / steps, size);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    // نقطةُ الحرف تظهر بعد أن يكتمل جسمُه.
    if (drawn >= 1) {
      canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.93), 6, Paint()..color = Colors.white);
    }
    // نقطةُ البداية الخضراء، كما في اللعبة نفسها.
    canvas.drawCircle(_point(0, size), 7, Paint()..color = const Color(0xFF22C55E));
    canvas.drawCircle(
      _point(0, size),
      7,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_DottedLetterPainter old) => old.progress != progress;
}
