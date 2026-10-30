import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/student_strings.dart';
import '../services/student_sound_service.dart';
import 'student_avatar_view.dart';

/// كيف يُجاب سؤالُ الاختبار: لعبةٌ أو قائمة.
enum QuizPlayMode { balloons, fishing, list }

/// ما يُعرض من السؤال في اللعبة، والإجابةُ الصحيحة تُعرف بـ[isCorrect].
///
/// الاختيارُ الأوّل هو الإجابة ([onAnswered]): اللعبةُ تُريه أصاب أم أخطأ في
/// لحظته — بالونٌ ينفجر أو سمكةٌ تُصطاد — ثم تُبلغ الاختبارَ بما اختار، والدرجةُ
/// تُحسب كما تُحسب في القائمة.
abstract class QuizGameQuestion extends StatefulWidget {
  const QuizGameQuestion({
    required this.prompt,
    required this.options,
    required this.isCorrect,
    required this.onAnswered,
    this.answered,
    super.key,
  });

  final String prompt;
  final List<String> options;
  final bool Function(String option) isCorrect;
  final ValueChanged<String> onAnswered;

  /// إجابةٌ سابقةٌ لهذا السؤال (رجع إليه الطالب): تُعرض ولا تُغيَّر.
  final String? answered;
}

/// زمنُ ما بين الاختيار وإبلاغ الاختبار: يرى فيه الطفلُ النتيجة.
const quizGameReveal = Duration(milliseconds: 1100);

void _celebrate(bool correct) {
  if (correct) {
    StudentSoundService.instance.playCheer();
  } else {
    HapticFeedback.lightImpact();
    StudentSoundService.instance.play(StudentSoundCue.warning);
  }
}

const _palette = [
  Color(0xFFEF4444),
  Color(0xFF3B82F6),
  Color(0xFF22C55E),
  Color(0xFFF59E0B),
  Color(0xFFA855F7),
  Color(0xFFEC4899),
];

/// السؤالُ بخطٍّ كبيرٍ فوق اللعبة.
class _Prompt extends StatelessWidget {
  const _Prompt(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E3A5F), height: 1.4),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// البالونات
// ═══════════════════════════════════════════════════════════════════════

/// «البالونات»: الخياراتُ في بالوناتٍ ملوّنة تطفو وتتمايل. الصحيحةُ تنفجر
/// بقصاصاتٍ وتصفيق، والخاطئةُ تهتزّ وتذبل.
class BalloonQuizQuestion extends QuizGameQuestion {
  const BalloonQuizQuestion({
    required super.prompt,
    required super.options,
    required super.isCorrect,
    required super.onAnswered,
    super.answered,
    super.key,
  });

  @override
  State<BalloonQuizQuestion> createState() => _BalloonQuizQuestionState();
}

class _BalloonQuizQuestionState extends State<BalloonQuizQuestion> with TickerProviderStateMixin {
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  late final AnimationController _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  String? _picked;
  Timer? _report;

  @override
  void initState() {
    super.initState();
    _picked = widget.answered;
    if (_picked != null) _burst.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat();
    }
  }

  @override
  void dispose() {
    _report?.cancel();
    _float.dispose();
    _burst.dispose();
    super.dispose();
  }

  void _tap(String option) {
    if (_picked != null || option.isEmpty) return;
    final correct = widget.isCorrect(option);
    setState(() => _picked = option);
    _celebrate(correct);
    _burst.forward(from: 0);
    _report = Timer(quizGameReveal, () {
      if (mounted) widget.onAnswered(option);
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.options;
    return Column(
      children: [
        _Prompt(widget.prompt),
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final count = options.length;
            final columns = count <= 3 ? count : (count / 2).ceil();
            final rows = (count / columns).ceil();
            final width = box.maxWidth / columns;
            final balloon = math.min(width * 0.82, box.maxHeight / rows * 0.7).clamp(70.0, 190.0).toDouble();
            return Stack(
              children: [
                for (var i = 0; i < count; i++)
                  AnimatedBuilder(
                    animation: Listenable.merge([_float, _burst]),
                    builder: (context, _) {
                      final column = i % columns;
                      final row = i ~/ columns;
                      final phase = i * 0.37;
                      final bob = math.sin((_float.value + phase) * 2 * math.pi) * 10;
                      final sway = math.sin((_float.value * 0.5 + phase) * 2 * math.pi) * 0.06;
                      final cellH = box.maxHeight / rows;
                      final left = column * width + (width - balloon) / 2;
                      final top = row * cellH + (cellH - balloon * 1.35) / 2 + bob;
                      return Positioned(
                        left: left,
                        top: top,
                        width: balloon,
                        height: balloon * 1.35,
                        child: Transform.rotate(
                          angle: sway,
                          child: _Balloon(
                            key: ValueKey('balloon-$i'),
                            label: options[i],
                            color: _palette[i % _palette.length],
                            state: _stateOf(options[i]),
                            burst: _burst.value,
                            onTap: () => _tap(options[i]),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            );
          }),
        ),
      ],
    );
  }

  _BalloonState _stateOf(String option) {
    final picked = _picked;
    if (picked == null) return _BalloonState.idle;
    if (option == picked) return widget.isCorrect(option) ? _BalloonState.popped : _BalloonState.wrong;
    // ‏أخطأ: يُرى الصحيحُ متوهّجاً فيتعلّم.
    return widget.isCorrect(option) ? _BalloonState.reveal : _BalloonState.idle;
  }
}

enum _BalloonState { idle, popped, wrong, reveal }

class _Balloon extends StatelessWidget {
  const _Balloon({
    required this.label,
    required this.color,
    required this.state,
    required this.burst,
    required this.onTap,
    super.key,
  });

  final String label;
  final Color color;
  final _BalloonState state;
  final double burst;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final popped = state == _BalloonState.popped;
      final wrong = state == _BalloonState.wrong;
      final shake = wrong ? math.sin(burst * math.pi * 8) * (1 - burst) * 10 : 0.0;
      final body = Opacity(
        opacity: popped ? (1 - burst).clamp(0.0, 1.0) : (wrong ? 1 - burst * 0.55 : 1),
        child: Transform.scale(
          scale: popped ? 1 + burst * 0.5 : (wrong ? 1 - burst * 0.15 : 1),
          child: Column(
            children: [
              Container(
                width: w,
                height: w * 1.12,
                alignment: Alignment.center,
                padding: EdgeInsets.all(w * 0.12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.elliptical(w / 2, w * 0.56)),
                  gradient: RadialGradient(
                    center: const Alignment(-0.35, -0.45),
                    radius: 0.9,
                    colors: [Color.lerp(color, Colors.white, 0.45)!, color, Color.lerp(color, Colors.black, 0.2)!],
                    stops: const [0, 0.55, 1],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (state == _BalloonState.reveal ? const Color(0xFFFFD166) : color).withValues(alpha: 0.5),
                      blurRadius: state == _BalloonState.reveal ? 26 : 12,
                      spreadRadius: state == _BalloonState.reveal ? 4 : 0,
                    ),
                  ],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                    ),
                  ),
                ),
              ),
              Expanded(child: CustomPaint(size: Size(w, double.infinity), painter: _StringPainter(color))),
            ],
          ),
        ),
      );
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Transform.translate(offset: Offset(shake, 0), child: body),
            if (popped && burst < 1)
              Positioned(
                left: -w * 0.5,
                top: -w * 0.4,
                width: w * 2,
                height: w * 2,
                child: IgnorePointer(child: CustomPaint(painter: _BurstPainter(burst, color))),
              ),
            if (popped && burst > 0.5)
              Positioned.fill(
                child: Center(
                  child: Opacity(
                    opacity: ((burst - 0.5) * 2).clamp(0.0, 1.0),
                    child: Icon(Icons.check_circle_rounded, color: const Color(0xFF22C55E), size: w * 0.45),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _StringPainter extends CustomPainter {
  _StringPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final path = Path()..moveTo(x, 0);
    for (var y = 0.0; y < size.height; y += 6) {
      path.lineTo(x + math.sin(y / 9) * 4, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Color.lerp(color, Colors.black, 0.35)!,
    );
  }

  @override
  bool shouldRepaint(_StringPainter old) => old.color != color;
}

/// قصاصاتٌ وشظايا تتطاير من البالون حين ينفجر.
class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final fade = (1 - t).clamp(0.0, 1.0);
    for (var i = 0; i < 18; i++) {
      final a = i * math.pi * 2 / 18;
      final r = size.shortestSide * (0.12 + 0.38 * t) * (0.8 + (i % 3) * 0.15);
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      final paint = Paint()..color = (i.isEven ? _palette[i % _palette.length] : color).withValues(alpha: fade);
      if (i % 3 == 0) {
        canvas.drawCircle(p, 5, paint);
      } else {
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(a + t * 4);
        canvas.drawRect(const Rect.fromLTWH(-5, -2.5, 10, 5), paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

// ═══════════════════════════════════════════════════════════════════════
// الصيد
// ═══════════════════════════════════════════════════════════════════════

/// «الصيد»: الطالبُ (بشخصيته) على الرصيف بصنّارة، والخياراتُ أسماكٌ تسبح في
/// البحر. يلمس سمكةً فتنزل الصنّارةُ إليها: الصحيحةُ تُرفع وتلمع، والخاطئةُ
/// تفلت وتسبح بعيداً.
class FishingQuizQuestion extends QuizGameQuestion {
  const FishingQuizQuestion({
    required super.prompt,
    required super.options,
    required super.isCorrect,
    required super.onAnswered,
    super.answered,
    super.key,
  });

  @override
  State<FishingQuizQuestion> createState() => _FishingQuizQuestionState();
}

class _FishingQuizQuestionState extends State<FishingQuizQuestion> with TickerProviderStateMixin {
  late final AnimationController _swim = AnimationController(vsync: this, duration: const Duration(seconds: 9));
  late final AnimationController _cast = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
  int? _target;
  Timer? _report;

  @override
  void initState() {
    super.initState();
    final answered = widget.answered;
    if (answered != null) {
      _target = widget.options.indexOf(answered);
      _cast.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_target == null && !(MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      if (!_swim.isAnimating) _swim.repeat();
    } else {
      _swim.stop();
    }
  }

  @override
  void dispose() {
    _report?.cancel();
    _swim.dispose();
    _cast.dispose();
    super.dispose();
  }

  void _tap(int index) {
    final option = widget.options[index];
    if (_target != null || option.isEmpty) return;
    _swim.stop();
    setState(() => _target = index);
    HapticFeedback.selectionClick();
    _cast.forward(from: 0).then((_) {
      if (mounted) _celebrate(widget.isCorrect(option));
    });
    _report = Timer(quizGameReveal + const Duration(milliseconds: 500), () {
      if (mounted) widget.onAnswered(option);
    });
  }

  /// موضعُ السمكة [i] في البحر: حارةٌ لكلّ سمكة، تسبح فيها ذهاباً وإياباً.
  Offset _fishAt(int i, Size sea, double fishW) {
    final lanes = widget.options.length;
    final laneH = sea.height / lanes;
    final phase = i * 0.29;
    final travel = (sea.width - fishW) * 0.5 * (1 + math.sin((_swim.value + phase) * 2 * math.pi));
    return Offset(travel, laneH * i + laneH * 0.15);
  }

  bool _facingRight(int i) => math.cos((_swim.value + i * 0.29) * 2 * math.pi) > 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Prompt(widget.prompt),
        const SizedBox(height: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: LayoutBuilder(builder: (context, box) {
              final size = box.biggest;
              final skyH = size.height * 0.3;
              final sea = Size(size.width, size.height - skyH);
              final lanes = widget.options.length;
              final fishH = (sea.height / lanes * 0.7).clamp(36.0, 90.0).toDouble();
              final fishW = (fishH * 2.6).clamp(110.0, size.width * 0.55).toDouble();
              final avatar = (skyH * 0.7).clamp(48.0, 110.0).toDouble();
              final tip = Offset(size.width * 0.5, skyH * 0.12);
              return AnimatedBuilder(
                animation: Listenable.merge([_swim, _cast]),
                builder: (context, _) {
                  final target = _target;
                  Offset? hook;
                  var lifted = Offset.zero;
                  if (target != null && target >= 0) {
                    final fish = _fishAt(target, sea, fishW) + Offset(fishW / 2, skyH + fishH / 2);
                    final down = Curves.easeOut.transform((_cast.value * 2).clamp(0.0, 1.0));
                    final up = Curves.easeInOut.transform(((_cast.value - 0.5) * 2).clamp(0.0, 1.0));
                    final correct = widget.isCorrect(widget.options[target]);
                    hook = Offset.lerp(tip, fish, down)!;
                    if (correct) {
                      // ‏الصحيحةُ تُرفع مع الصنّارة إلى الرصيف.
                      hook = Offset.lerp(fish, tip + Offset(0, skyH * 0.45), up)!;
                      lifted = hook - fish;
                    } else {
                      hook = Offset.lerp(fish, tip, up)!;
                    }
                  }
                  return Stack(
                    children: [
                      // ‏السماءُ والبحر.
                      Positioned.fill(
                        child: CustomPaint(painter: _SeaPainter(skyH: skyH, wave: _swim.value)),
                      ),
                      // ‏الرصيفُ والشخصيةُ والصنّارة.
                      Positioned(
                        left: size.width * 0.5 - avatar * 1.6,
                        top: skyH - avatar * 0.95,
                        width: avatar,
                        height: avatar,
                        child: const FittedBox(child: StudentAvatarView(size: 96, showRing: false)),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _RodPainter(
                              hand: Offset(size.width * 0.5 - avatar * 0.9, skyH - avatar * 0.4),
                              tip: tip,
                              hook: hook,
                            ),
                          ),
                        ),
                      ),
                      for (var i = 0; i < lanes; i++)
                        Builder(builder: (context) {
                          final at = _fishAt(i, sea, fishW) + Offset(0, skyH);
                          final picked = target == i;
                          final correct = widget.isCorrect(widget.options[i]);
                          final escaping = picked && !correct;
                          final reveal = target != null && !picked && correct;
                          final offset = picked && correct
                              ? lifted
                              : escaping
                                  ? Offset(size.width * 0.6 * ((_cast.value - 0.5) * 2).clamp(0.0, 1.0), 0)
                                  : Offset.zero;
                          return Positioned(
                            left: at.dx + offset.dx,
                            top: at.dy + offset.dy,
                            width: fishW,
                            height: fishH,
                            child: Opacity(
                              opacity: escaping ? (1 - ((_cast.value - 0.5) * 2).clamp(0.0, 1.0) * 0.7) : 1,
                              child: _Fish(
                                key: ValueKey('fish-$i'),
                                label: widget.options[i],
                                color: _palette[i % _palette.length],
                                facingRight: target != null ? true : _facingRight(i),
                                glow: reveal || (picked && correct && _cast.value > 0.9),
                                onTap: () => _tap(i),
                              ),
                            ),
                          );
                        }),
                      if (target != null && target >= 0 && widget.isCorrect(widget.options[target]) && _cast.value > 0.9)
                        Positioned(
                          top: 8,
                          right: 12,
                          child: Text(tr('quiz.game.caught'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(color: Colors.black45, blurRadius: 6)])),
                        ),
                    ],
                  );
                },
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _SeaPainter extends CustomPainter {
  _SeaPainter({required this.skyH, required this.wave});
  final double skyH;
  final double wave;

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Rect.fromLTWH(0, 0, size.width, skyH);
    canvas.drawRect(
      sky,
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF7DD3FC), Color(0xFFE0F2FE)]).createShader(sky),
    );
    // ‏الشمس.
    canvas.drawCircle(Offset(size.width * 0.85, skyH * 0.35), skyH * 0.18, Paint()..color = const Color(0xFFFDE047));
    final sea = Rect.fromLTWH(0, skyH, size.width, size.height - skyH);
    canvas.drawRect(
      sea,
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF38BDF8), Color(0xFF0369A1)]).createShader(sea),
    );
    // ‏موجُ السطح.
    final path = Path()..moveTo(0, skyH);
    for (var x = 0.0; x <= size.width; x += 8) {
      path.lineTo(x, skyH + math.sin((x / 40) + wave * 2 * math.pi) * 5);
    }
    path
      ..lineTo(size.width, skyH - 8)
      ..lineTo(0, skyH - 8)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFBAE6FD));
    // ‏الرصيف.
    final dock = Rect.fromLTWH(size.width * 0.5 - skyH * 1.6, skyH - 10, skyH * 1.2, 14);
    canvas.drawRRect(RRect.fromRectAndRadius(dock, const Radius.circular(4)), Paint()..color = const Color(0xFF92400E));
    // ‏فقاعات.
    for (var i = 0; i < 10; i++) {
      final x = size.width * ((i * 0.137 + 0.05) % 1);
      final y = skyH + (size.height - skyH) * (1 - ((wave + i * 0.1) % 1));
      canvas.drawCircle(Offset(x, y), 3 + (i % 3).toDouble(), Paint()..color = Colors.white.withValues(alpha: 0.35));
    }
  }

  @override
  bool shouldRepaint(_SeaPainter old) => old.wave != wave || old.skyH != skyH;
}

class _RodPainter extends CustomPainter {
  _RodPainter({required this.hand, required this.tip, this.hook});
  final Offset hand;
  final Offset tip;
  final Offset? hook;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      hand,
      tip,
      Paint()
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF78350F),
    );
    final end = hook ?? tip + const Offset(0, 40);
    canvas.drawLine(tip, end, Paint()..strokeWidth = 1.6..color = const Color(0xFF334155));
    // ‏الخطّاف.
    canvas.drawArc(Rect.fromCircle(center: end + const Offset(0, 5), radius: 6), 0, math.pi, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0xFF64748B));
  }

  @override
  bool shouldRepaint(_RodPainter old) => old.hook != hook || old.tip != tip || old.hand != hand;
}

class _Fish extends StatelessWidget {
  const _Fish({
    required this.label,
    required this.color,
    required this.facingRight,
    required this.glow,
    required this.onTap,
    super.key,
  });

  final String label;
  final Color color;
  final bool facingRight;
  final bool glow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: LayoutBuilder(builder: (context, box) {
        final h = box.maxHeight;
        final body = Expanded(
          child: Container(
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: h * 0.25),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.elliptical(h * 1.2, h / 2)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(color, Colors.white, 0.35)!, color],
              ),
              boxShadow: [
                BoxShadow(
                  color: (glow ? const Color(0xFFFFD166) : Colors.black).withValues(alpha: glow ? 0.8 : 0.2),
                  blurRadius: glow ? 20 : 6,
                  spreadRadius: glow ? 3 : 0,
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black38, blurRadius: 4)]),
              ),
            ),
          ),
        );
        final tail = SizedBox(width: h * 0.45, height: h * 0.8, child: CustomPaint(painter: _TailPainter(color, pointsRight: !facingRight)));
        return Row(children: facingRight ? [tail, body] : [body, tail]);
      }),
    );
  }
}

class _TailPainter extends CustomPainter {
  _TailPainter(this.color, {required this.pointsRight});
  final Color color;
  final bool pointsRight;

  @override
  void paint(Canvas canvas, Size size) {
    final path = pointsRight
        ? (Path()
          ..moveTo(0, size.height / 2)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, size.height)
          ..close())
        : (Path()
          ..moveTo(size.width, size.height / 2)
          ..lineTo(0, 0)
          ..lineTo(0, size.height)
          ..close());
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color || old.pointsRight != pointsRight;
}
