import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/student_strings.dart';
import '../services/student_sound_service.dart';
import 'student_avatar_view.dart';

/// ألعابُ أسئلة الدرس: كلُّ لعبةٍ تعرض السؤالَ نفسَه بطريقتها.
enum QuizGameStyle { balloons, fishing, train, slingshot }

/// اللعبةُ [style] لسؤالٍ واحد.
Widget quizGameFor(
  QuizGameStyle style, {
  required String prompt,
  required List<String> options,
  required bool Function(String option) isCorrect,
  required ValueChanged<String> onAnswered,
  Key? key,
}) =>
    switch (style) {
      QuizGameStyle.balloons =>
        BalloonQuizQuestion(key: key, prompt: prompt, options: options, isCorrect: isCorrect, onAnswered: onAnswered),
      QuizGameStyle.fishing =>
        FishingQuizQuestion(key: key, prompt: prompt, options: options, isCorrect: isCorrect, onAnswered: onAnswered),
      QuizGameStyle.train =>
        TrainQuizQuestion(key: key, prompt: prompt, options: options, isCorrect: isCorrect, onAnswered: onAnswered),
      QuizGameStyle.slingshot =>
        SlingshotQuizQuestion(key: key, prompt: prompt, options: options, isCorrect: isCorrect, onAnswered: onAnswered),
    };

/// السماءُ والمرج (خلفيةُ الدخول) والصفّ (خلفيةُ المسار): رسومُ التطبيق نفسها.
const quizSkyArt = 'assets/images/auth/login_bg_custom.png';
const quizClassroomArt = 'assets/images/routes/route_bg_custom.png';

/// خلفيةٌ من رسوم التطبيق نفسها (السماءُ والمرج، أو الصفّ)، باهتةً تحت
/// اللعبة — لا صورٌ جديدةٌ تُكبّر التطبيق.
class _GameBackdrop extends StatelessWidget {
  const _GameBackdrop(this.asset);

  final String asset;

  static const sky = quizSkyArt;
  static const classroom = quizClassroomArt;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          asset,
          fit: BoxFit.cover,
          cacheWidth: 900,
          errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFE0F2FE)),
        ),
        const ColoredBox(color: Color(0x66FFFFFF)),
      ],
    );
  }
}

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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                const Positioned.fill(child: _GameBackdrop(_GameBackdrop.sky)),
                Positioned.fill(child: _balloons(options)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _balloons(List<String> options) {
    return LayoutBuilder(builder: (context, box) {
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
    });
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

// ═══════════════════════════════════════════════════════════════════════
// القطار
// ═══════════════════════════════════════════════════════════════════════

/// «القطار»: الإجاباتُ صناديقُ على الرصيف، والقطارُ — والطالبُ بشخصيته في
/// مقصورته — ينتظر بعربةٍ فارغة. الصندوقُ الصحيحُ يطير إلى العربة وينطلق
/// القطار؛ والخاطئُ يهتزّ ويسقط، والصحيحُ يتوهّج.
class TrainQuizQuestion extends QuizGameQuestion {
  const TrainQuizQuestion({
    required super.prompt,
    required super.options,
    required super.isCorrect,
    required super.onAnswered,
    super.answered,
    super.key,
  });

  @override
  State<TrainQuizQuestion> createState() => _TrainQuizQuestionState();
}

class _TrainQuizQuestionState extends State<TrainQuizQuestion> with TickerProviderStateMixin {
  late final AnimationController _chug = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _go = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  int? _picked;
  final List<Timer> _timers = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _chug.stop();
    } else if (!_chug.isAnimating) {
      _chug.repeat();
    }
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _chug.dispose();
    _go.dispose();
    super.dispose();
  }

  void _tap(int index) {
    final option = widget.options[index];
    if (_picked != null || widget.answered != null || option.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _picked = index);
    final correct = widget.isCorrect(option);
    _go.forward(from: 0);
    // ‏الصحيحُ يُفرح حين يستقرّ في العربة، والخاطئُ في لحظته.
    _timers
      ..add(Timer(Duration(milliseconds: correct ? 650 : 0), () {
        if (mounted) _celebrate(correct);
      }))
      ..add(Timer(quizGameReveal + const Duration(milliseconds: 500), () {
        if (mounted) widget.onAnswered(option);
      }));
  }

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
              final count = widget.options.length;
              final crate = math.min(size.width / (count * 1.1 + 0.4), size.height * 0.26).clamp(56.0, 150.0).toDouble();
              final trackY = size.height * 0.86;
              final carH = (size.height * 0.28).clamp(70.0, 160.0).toDouble();
              final carW = carH * 1.25;
              final trainLeft = size.width * 0.1;
              // ‏حيث يستقرّ الصندوقُ فوق العربة (وهي أوّلُ القطار من الخلف).
              final wagonSlot = Offset(trainLeft + carW / 2 - crate / 2, trackY - carH * 0.806 - crate * 0.66);
              return AnimatedBuilder(
                animation: Listenable.merge([_chug, _go]),
                builder: (context, _) {
                  final picked = _picked;
                  final correctPick = picked != null && widget.isCorrect(widget.options[picked]);
                  final fly = Curves.easeInOut.transform((_go.value / 0.45).clamp(0.0, 1.0));
                  final depart = correctPick ? Curves.easeIn.transform(((_go.value - 0.45) / 0.55).clamp(0.0, 1.0)) : 0.0;
                  final trainShift = depart * size.width;
                  final wheel = _chug.value + depart * 6;
                  final bounce = math.sin(_chug.value * 2 * math.pi) * 2;
                  return Stack(
                    children: [
                      const Positioned.fill(child: _GameBackdrop(_GameBackdrop.classroom)),
                      // ‏الرصيف.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: size.height * 0.08 + crate,
                        height: 12,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFF92400E),
                            boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 4))],
                          ),
                        ),
                      ),
                      // ‏السكّة.
                      Positioned.fill(child: CustomPaint(painter: _TrackPainter(trackY, wheel))),
                      // ‏القطار: العربةُ الفارغة، ثم القاطرةُ والطالبُ فيها.
                      Positioned(
                        left: trainLeft + trainShift,
                        top: trackY - carH + bounce,
                        child: Row(
                          textDirection: TextDirection.ltr,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _Wagon(width: carW, height: carH * 0.62, wheel: wheel),
                            SizedBox(width: carW * 0.12),
                            _Locomotive(width: carW, height: carH, wheel: wheel, smoke: _chug.value),
                          ],
                        ),
                      ),
                      for (var i = 0; i < count; i++)
                        Builder(builder: (context) {
                          final home = Offset(
                            (size.width - count * crate * 1.1) / 2 + i * crate * 1.1 + crate * 0.05,
                            size.height * 0.08,
                          );
                          var at = home;
                          var opacity = 1.0;
                          var angle = 0.0;
                          var scale = 1.0;
                          final mine = picked == i;
                          if (mine && correctPick) {
                            // ‏إلى العربة في قوس، ثم ينطلق معها.
                            final arc = Offset(0, -size.height * 0.18 * math.sin(fly * math.pi));
                            at = Offset.lerp(home, wagonSlot, fly)! + arc + Offset(trainShift, bounce * fly);
                            scale = 1 - 0.2 * fly;
                          } else if (mine) {
                            angle = math.sin(_go.value * math.pi * 10) * (1 - _go.value) * 0.3;
                            final fall = Curves.easeIn.transform(((_go.value - 0.4) / 0.6).clamp(0.0, 1.0));
                            at = home + Offset(0, size.height * 0.5 * fall);
                            opacity = 1 - ((_go.value - 0.5) * 2).clamp(0.0, 1.0);
                          }
                          final glow = picked != null && !mine && widget.isCorrect(widget.options[i]);
                          return Positioned(
                            left: at.dx,
                            top: at.dy,
                            width: crate,
                            height: crate,
                            child: Opacity(
                              opacity: opacity,
                              child: Transform.rotate(
                                angle: angle,
                                child: Transform.scale(
                                  scale: scale,
                                  child: _Crate(
                                    key: ValueKey('crate-$i'),
                                    label: widget.options[i],
                                    color: _palette[i % _palette.length],
                                    glow: glow,
                                    onTap: () => _tap(i),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
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

class _Crate extends StatelessWidget {
  const _Crate({required this.label, required this.color, required this.glow, required this.onTap, super.key});

  final String label;
  final Color color;
  final bool glow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFD97706),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF92400E), width: 3),
          boxShadow: [
            BoxShadow(
              color: (glow ? const Color(0xFFFFD166) : Colors.black).withValues(alpha: glow ? 0.9 : 0.25),
              blurRadius: glow ? 22 : 6,
              spreadRadius: glow ? 4 : 0,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black38, blurRadius: 4)]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Locomotive extends StatelessWidget {
  const _Locomotive({required this.width, required this.height, required this.wheel, required this.smoke});

  final double width;
  final double height;
  final double wheel;
  final double smoke;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ‏الدخان.
          for (var i = 0; i < 3; i++)
            Positioned(
              left: width * 0.66 - i * 10 - smoke * 8,
              top: -height * 0.12 - i * 16 - smoke * 10,
              child: Opacity(
                opacity: (0.75 - i * 0.2 - smoke * 0.2).clamp(0.0, 1.0),
                child: Container(
                  width: 16.0 + i * 8,
                  height: 16.0 + i * 8,
                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                ),
              ),
            ),
          // ‏المدخنة.
          Positioned(
            left: width * 0.68,
            top: height * 0.08,
            width: width * 0.12,
            height: height * 0.26,
            child: Container(
              decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(3)),
            ),
          ),
          // ‏جسمُ القاطرة.
          Positioned(
            left: width * 0.3,
            top: height * 0.3,
            width: width * 0.7,
            height: height * 0.42,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(30), left: Radius.circular(6)),
                border: Border.all(color: const Color(0xFF7F1D1D), width: 2),
              ),
            ),
          ),
          // ‏المقصورةُ وفيها الطالب.
          Positioned(
            left: 0,
            top: height * 0.02,
            width: width * 0.44,
            height: height * 0.7,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF7F1D1D), width: 2),
              ),
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFFBAE6FD), borderRadius: BorderRadius.circular(6)),
                child: const FittedBox(child: StudentAvatarView(size: 64, showRing: false)),
              ),
            ),
          ),
          for (final x in [0.15, 0.5, 0.82])
            Positioned(
              left: width * x - height * 0.15,
              top: height * 0.68,
              child: _Wheel(size: height * 0.3, turn: wheel),
            ),
        ],
      ),
    );
  }
}

class _Wagon extends StatelessWidget {
  const _Wagon({required this.width, required this.height, required this.wheel});

  final double width;
  final double height;
  final double wheel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height * 1.3,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: height,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1E3A8A), width: 2),
              ),
            ),
          ),
          for (final x in [0.22, 0.78])
            Positioned(left: width * x - height * 0.22, top: height * 0.84, child: _Wheel(size: height * 0.44, turn: wheel)),
        ],
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({required this.size, required this.turn});

  final double size;
  final double turn;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: turn * 2 * math.pi,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF9CA3AF), width: 3),
        ),
        child: Center(child: Container(width: size * 0.6, height: 3, color: const Color(0xFF9CA3AF))),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter(this.y, this.shift);
  final double y;
  final double shift;

  @override
  void paint(Canvas canvas, Size size) {
    final sleeper = Paint()..color = const Color(0xFF78350F);
    const gap = 26.0;
    final offset = -(shift * gap) % gap;
    for (var x = offset - gap; x < size.width; x += gap) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y + 2, 14, 12), const Radius.circular(2)), sleeper);
    }
    final rail = Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 4;
    canvas.drawLine(Offset(0, y + 2), Offset(size.width, y + 2), rail);
    canvas.drawLine(Offset(0, y + 13), Offset(size.width, y + 13), rail);
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.shift != shift || old.y != y;
}

// ═══════════════════════════════════════════════════════════════════════
// المقلاع
// ═══════════════════════════════════════════════════════════════════════

/// «المقلاع»: الطالبُ بشخصيته يمسك مقلاعاً، والإجاباتُ أهدافٌ معلّقة تتمايل.
/// يلمس هدفاً فيُشدّ المطاطُ وتنطلق الحصاةُ في قوس: الصحيحُ ينفجر نجوماً،
/// والخاطئُ يترنّح وتسقط الحصاة، والصحيحُ يتوهّج.
class SlingshotQuizQuestion extends QuizGameQuestion {
  const SlingshotQuizQuestion({
    required super.prompt,
    required super.options,
    required super.isCorrect,
    required super.onAnswered,
    super.answered,
    super.key,
  });

  @override
  State<SlingshotQuizQuestion> createState() => _SlingshotQuizQuestionState();
}

class _SlingshotQuizQuestionState extends State<SlingshotQuizQuestion> with TickerProviderStateMixin {
  late final AnimationController _sway = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  late final AnimationController _shot = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  int? _picked;
  final List<Timer> _timers = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _sway.stop();
    } else if (!_sway.isAnimating) {
      _sway.repeat();
    }
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _sway.dispose();
    _shot.dispose();
    super.dispose();
  }

  void _tap(int index) {
    final option = widget.options[index];
    if (_picked != null || widget.answered != null || option.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() => _picked = index);
    _shot.forward(from: 0);
    // ‏الفرحُ أو التنبيهُ حين تصيب الحصاةُ هدفها.
    _timers
      ..add(Timer(const Duration(milliseconds: 975), () {
        if (mounted) _celebrate(widget.isCorrect(option));
      }))
      ..add(Timer(quizGameReveal + const Duration(milliseconds: 600), () {
        if (mounted) widget.onAnswered(option);
      }));
  }

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
              final count = widget.options.length;
              final target = math.min(size.width / (count * 1.15 + 0.2), size.height * 0.32).clamp(56.0, 150.0).toDouble();
              final avatar = (size.height * 0.28).clamp(56.0, 130.0).toDouble();
              final pouch = Offset(size.width / 2 + avatar * 0.35, size.height - avatar * 0.85);
              return AnimatedBuilder(
                animation: Listenable.merge([_sway, _shot]),
                builder: (context, _) {
                  final picked = _picked;
                  final pull = Curves.easeOut.transform((_shot.value / 0.3).clamp(0.0, 1.0));
                  final flight = Curves.easeIn.transform(((_shot.value - 0.3) / 0.45).clamp(0.0, 1.0));
                  final impact = ((_shot.value - 0.75) / 0.25).clamp(0.0, 1.0);

                  Offset centerOf(int i) => Offset(
                        (size.width - count * target * 1.15) / 2 + i * target * 1.15 + target * 0.575,
                        size.height * 0.06 + target / 2 + math.sin((_sway.value + i * 0.3) * 2 * math.pi) * 8,
                      );

                  Offset? stone;
                  if (picked != null) {
                    final goal = centerOf(picked);
                    final start = pouch + Offset(0, 26 * pull);
                    if (_shot.value < 0.3) {
                      stone = start;
                    } else if (impact > 0) {
                      // ‏الخاطئُ تسقط عنه الحصاة، والصحيحُ تختفي فيه.
                      stone = widget.isCorrect(widget.options[picked])
                          ? null
                          : goal + Offset(0, size.height * 0.7 * Curves.easeIn.transform(impact));
                    } else {
                      final control = Offset((start.dx + goal.dx) / 2, math.min(start.dy, goal.dy) - size.height * 0.2);
                      final t = flight;
                      stone = Offset(
                        (1 - t) * (1 - t) * start.dx + 2 * (1 - t) * t * control.dx + t * t * goal.dx,
                        (1 - t) * (1 - t) * start.dy + 2 * (1 - t) * t * control.dy + t * t * goal.dy,
                      );
                    }
                  }
                  return Stack(
                    children: [
                      const Positioned.fill(child: _GameBackdrop(_GameBackdrop.sky)),
                      for (var i = 0; i < count; i++)
                        Builder(builder: (context) {
                          final c = centerOf(i);
                          final mine = picked == i;
                          final correct = widget.isCorrect(widget.options[i]);
                          final hit = mine && correct && impact > 0;
                          final wobble = mine && !correct ? math.sin(impact * math.pi * 6) * (1 - impact) * 0.4 : 0.0;
                          return Positioned(
                            left: c.dx - target / 2,
                            top: c.dy - target / 2,
                            width: target,
                            height: target,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: hit ? (1 - impact * 0.7) : 1,
                                    child: Transform.rotate(
                                      angle: wobble,
                                      child: Transform.scale(
                                        scale: hit ? 1 + impact * 0.3 : 1,
                                        child: _Target(
                                          key: ValueKey('target-$i'),
                                          label: widget.options[i],
                                          glow: picked != null && !mine && correct,
                                          onTap: () => _tap(i),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (hit && impact < 1)
                                  Positioned(
                                    left: -target * 0.5,
                                    top: -target * 0.5,
                                    width: target * 2,
                                    height: target * 2,
                                    child: IgnorePointer(child: CustomPaint(painter: _BurstPainter(impact, const Color(0xFFFBBF24)))),
                                  ),
                                if (hit && impact > 0.3)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: Center(
                                        child: Icon(Icons.check_circle_rounded, color: const Color(0xFF22C55E), size: target * 0.55),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      // ‏الطالبُ والمقلاع.
                      Positioned(
                        left: size.width / 2 - avatar * 0.85,
                        top: size.height - avatar,
                        width: avatar,
                        height: avatar,
                        child: const IgnorePointer(child: FittedBox(child: StudentAvatarView(size: 96, showRing: false))),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _SlingPainter(
                              pouch: pouch,
                              height: avatar,
                              pull: picked != null && _shot.value < 0.3 ? pull : 0,
                              stone: stone,
                              loaded: picked == null,
                            ),
                          ),
                        ),
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

class _Target extends StatelessWidget {
  const _Target({required this.label, required this.glow, required this.onTap, super.key});

  final String label;
  final bool glow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Colors.white, Colors.white, Color(0xFFEF4444), Color(0xFFEF4444), Colors.white, Colors.white, Color(0xFFEF4444)],
            stops: [0, 0.5, 0.5, 0.7, 0.7, 0.86, 0.86],
          ),
          border: Border.all(color: const Color(0xFF7F1D1D), width: 3),
          boxShadow: [
            BoxShadow(
              color: (glow ? const Color(0xFFFFD166) : Colors.black).withValues(alpha: glow ? 0.9 : 0.25),
              blurRadius: glow ? 24 : 6,
              spreadRadius: glow ? 5 : 0,
            ),
          ],
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFF1E3A5F), borderRadius: BorderRadius.circular(10)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }
}

class _SlingPainter extends CustomPainter {
  _SlingPainter({required this.pouch, required this.height, required this.pull, required this.loaded, this.stone});

  final Offset pouch;
  final double height;
  final double pull;
  final bool loaded;
  final Offset? stone;

  @override
  void paint(Canvas canvas, Size size) {
    final wood = Paint()
      ..color = const Color(0xFF92400E)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final base = pouch + Offset(0, height * 0.75);
    final fork = pouch + Offset(0, height * 0.25);
    final left = pouch + Offset(-height * 0.22, -height * 0.05);
    final right = pouch + Offset(height * 0.22, -height * 0.05);
    canvas.drawLine(base, fork, wood);
    canvas.drawLine(fork, left, wood);
    canvas.drawLine(fork, right, wood);
    final band = Paint()
      ..color = const Color(0xFF1F2937)
      ..strokeWidth = 3;
    final held = pouch + Offset(0, 26 * pull);
    canvas.drawLine(left, held, band);
    canvas.drawLine(right, held, band);
    final s = loaded ? held : stone;
    if (s == null) return;
    canvas.drawCircle(s, 9, Paint()..color = const Color(0xFF64748B));
    canvas.drawCircle(s + const Offset(-3, -3), 3, Paint()..color = Colors.white54);
  }

  @override
  bool shouldRepaint(_SlingPainter old) =>
      old.pull != pull || old.stone != stone || old.pouch != pouch || old.loaded != loaded;
}
