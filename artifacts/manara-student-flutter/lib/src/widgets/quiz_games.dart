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

/// رسومُ الألعاب الأربع، داخل `assets/images/games/` ومعلنةٌ في pubspec.
class QuizGameArt {
  static const fishingBg = 'assets/images/games/fishing_bg.png';
  static const fish = 'assets/images/games/fish_item.png';
  static const balloonBg = 'assets/images/games/balloon_bg.png';
  static const balloon = 'assets/images/games/balloon_item.png';
  static const slingshotBg = 'assets/images/games/slingshot_bg.png';
  static const trainBg = 'assets/images/games/train_bg.png';
  static const train = 'assets/images/games/train_item.png';

  /// الخلفيةُ لكل لعبة — وهي غلافُ بطاقتها أيضاً.
  static String background(QuizGameStyle style) => switch (style) {
        QuizGameStyle.balloons => balloonBg,
        QuizGameStyle.fishing => fishingBg,
        QuizGameStyle.train => trainBg,
        QuizGameStyle.slingshot => slingshotBg,
      };

  /// عبارةُ مقدّمة كل لعبةٍ بصوتها المسجّل.
  static String intro(QuizGameStyle style) => switch (style) {
        QuizGameStyle.balloons => 'audio/games/intro_balloons.mp3',
        QuizGameStyle.fishing => 'audio/games/intro_fishing.mp3',
        QuizGameStyle.train => 'audio/games/intro_train.mp3',
        QuizGameStyle.slingshot => 'audio/games/intro_slingshot.mp3',
      };

  /// أبعادُ الخلفيات الأربع (١٢٨٠×٧٢٠).
  static const backgroundSize = Size(1280, 720);
}

/// ما يُعرض من السؤال في اللعبة، والإجابةُ الصحيحة تُعرف بـ[isCorrect].
///
/// الاختيارُ الأوّل هو الإجابة ([onAnswered]): اللعبةُ تُريه أصاب أم أخطأ في
/// لحظته — بالونٌ ينفجر أو سمكةٌ تُصطاد — ثم تُبلغ الجولةَ بما اختار.
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

/// زمنُ ما بين الاختيار وإبلاغ الجولة: يرى فيه الطفلُ النتيجة.
const quizGameReveal = Duration(milliseconds: 1100);

void _celebrate(bool correct) {
  if (correct) {
    StudentSoundService.instance.playCheer();
  } else {
    HapticFeedback.lightImpact();
    StudentSoundService.instance.play(StudentSoundCue.warning);
  }
}

bool _still(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

const _palette = [
  Color(0xFFEF4444),
  Color(0xFF3B82F6),
  Color(0xFF22C55E),
  Color(0xFFF59E0B),
  Color(0xFFA855F7),
  Color(0xFFEC4899),
];

const _ink = Color(0xFF1E293B);
const _right = Color(0xFF16A34A);
const _wrong = Color(0xFFDC2626);
const _gold = Color(0xFFFFC83D);

/// حالُ كلِّ خيارٍ بعد الاختيار.
enum _Mark { idle, right, wrong, reveal }

_Mark _markOf(String option, String? picked, bool Function(String) isCorrect) {
  if (picked == null) return _Mark.idle;
  if (option == picked) return isCorrect(option) ? _Mark.right : _Mark.wrong;
  // ‏أخطأ: يُرى الصحيحُ متوهّجاً فيتعلّم.
  return isCorrect(option) && !isCorrect(picked) ? _Mark.reveal : _Mark.idle;
}

/// تدويرُ الألوان [degrees] درجةً — بالونٌ واحدٌ مرسوم يصير بالوناتٍ بألوانٍ
/// شتّى، بلمعته وظلاله.
ColorFilter _hue(double degrees) {
  final a = degrees * math.pi / 180;
  final c = math.cos(a);
  final s = math.sin(a);
  return ColorFilter.matrix(<double>[
    0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928, 0, 0, //
    0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283, 0, 0,
    0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072, 0, 0,
    0, 0, 0, 1, 0,
  ]);
}

/// موضعُ نقطةٍ من الخلفية ([frac] من عرضها وارتفاعها) بعد رسمها بـ`BoxFit.cover`
/// بمحاذاة [align] في [box] — ليقف القطارُ على السكّة والسمكُ تحت الماء.
Offset _artPoint(Size box, Alignment align, Offset frac) {
  const art = QuizGameArt.backgroundSize;
  final scale = math.max(box.width / art.width, box.height / art.height);
  final drawn = Size(art.width * scale, art.height * scale);
  final dx = (box.width - drawn.width) * (align.x + 1) / 2;
  final dy = (box.height - drawn.height) * (align.y + 1) / 2;
  return Offset(dx + frac.dx * drawn.width, dy + frac.dy * drawn.height);
}

class _Backdrop extends StatelessWidget {
  const _Backdrop(this.asset, {this.alignment = Alignment.center});

  final String asset;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      alignment: alignment,
      cacheWidth: 1280,
      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFBAE6FD)),
    );
  }
}

/// السؤالُ بخطٍّ كبيرٍ جداً فوق اللعبة — لطفل الروضة.
class _Prompt extends StatelessWidget {
  const _Prompt(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = (box.maxWidth / 22).clamp(24.0, 38.0).toDouble();
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _gold, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 5))],
        ),
        child: Text(
          text,
          key: const ValueKey('quiz-prompt'),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: const Color(0xFF1E3A5F), height: 1.3),
        ),
      );
    });
  }
}

/// كبسولةُ الإجابة: بيضاءُ ناصعة بخطٍّ عريضٍ داكن، وحافّتُها تقول النتيجة.
class _Capsule extends StatelessWidget {
  const _Capsule(this.text, {required this.fontSize, required this.maxWidth, this.mark = _Mark.idle, this.glowing = false});

  final String text;
  final double fontSize;
  final double maxWidth;
  final _Mark mark;

  /// فوق جسمٍ ملوّنٍ متحرّك (السمكة): حدٌّ داكنٌ سميك وهالةٌ بيضاء مضيئة،
  /// فلا تذوب الإجابةُ في لون السمكة ولا في زرقة الماء.
  final bool glowing;

  @override
  Widget build(BuildContext context) {
    final edge = switch (mark) {
      _Mark.right => _right,
      _Mark.wrong => _wrong,
      _Mark.reveal => _gold,
      _Mark.idle => glowing ? const Color(0xFF0F172A) : Colors.white,
    };
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: math.max(maxWidth, fontSize * 2)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: fontSize * 0.55, vertical: fontSize * 0.18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: edge, width: mark == _Mark.idle ? (glowing ? 3.5 : 2) : 4),
          boxShadow: [
            if (glowing && mark == _Mark.idle) const BoxShadow(color: Color(0xEEFFFFFF), blurRadius: 16, spreadRadius: 4),
            BoxShadow(
              color: mark == _Mark.reveal ? _gold.withValues(alpha: 0.9) : const Color(0x40000000),
              blurRadius: mark == _Mark.reveal ? 18 : 6,
              spreadRadius: mark == _Mark.reveal ? 3 : 0,
              offset: mark == _Mark.reveal ? Offset.zero : const Offset(0, 3),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mark == _Mark.right || mark == _Mark.wrong) ...[
                Icon(mark == _Mark.right ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: mark == _Mark.right ? _right : _wrong, size: fontSize),
                SizedBox(width: fontSize * 0.2),
              ],
              Text(
                text,
                maxLines: 1,
                style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: glowing ? Colors.black : _ink, height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// السؤالُ فوق مسرح اللعبة.
class _Frame extends StatelessWidget {
  const _Frame({required this.prompt, required this.stage});

  final String prompt;
  final Widget stage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Prompt(prompt),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 6))],
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(23), child: stage),
          ),
        ),
      ],
    );
  }
}

/// قصاصاتٌ ملوّنة تنطلق من [origin] ثم تسقط بالجاذبية وتدور.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.origin, {this.count = 34, this.spread = 1});

  final double t;
  final Offset origin;
  final int count;
  final double spread;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final fade = t < 0.75 ? 1.0 : (1 - t) / 0.25;
    final reach = size.shortestSide * 0.55 * spread;
    for (var i = 0; i < count; i++) {
      final a = -math.pi / 2 + (i / count - 0.5) * math.pi * 1.9 + (i % 3) * 0.07;
      final speed = reach * (0.55 + (i * 37 % 10) / 20);
      final p = origin + Offset(math.cos(a), math.sin(a)) * speed * t + Offset(0, reach * 1.1 * t * t);
      final paint = Paint()..color = _palette[i % _palette.length].withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(a + t * (6 + i % 5));
      if (i % 4 == 0) {
        canvas.drawCircle(Offset.zero, 4.5, paint);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -3, 12, 6), const Radius.circular(1.5)), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t || old.origin != origin;
}

// ═══════════════════════════════════════════════════════════════════════
// البالونات
// ═══════════════════════════════════════════════════════════════════════

/// «البالونات المتفجّرة»: بالوناتٌ مستقلّةٌ ملوّنة تطير بحركةٍ تموّجية فوق
/// المرج، والإجابةُ كبيرةٌ واضحةٌ داخل كلٍّ منها. الصحيحةُ تنفجر بصوت الفقع
/// وقصاصاتٍ ملوّنة، والخاطئةُ تهتزّ وتذبل ويتوهّج الصحيح.
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
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 5));
  late final AnimationController _rise = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
  String? _picked;
  Timer? _report;

  /// ألوانُ البالونات: الأحمرُ المرسوم، ثم أزرقُ وأخضرُ وذهبيٌّ وبنفسجيٌّ ووردي.
  static const _hues = [0.0, 215.0, 120.0, 275.0, 48.0, 320.0];

  @override
  void initState() {
    super.initState();
    _picked = widget.answered;
    if (_picked != null) _pop.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still(context)) {
      _float.stop();
      _rise.value = 1;
    } else {
      if (!_float.isAnimating) _float.repeat();
      if (_rise.value == 0 && !_rise.isAnimating) _rise.forward();
    }
  }

  @override
  void dispose() {
    _report?.cancel();
    _float.dispose();
    _rise.dispose();
    _pop.dispose();
    super.dispose();
  }

  void _tap(String option) {
    if (_picked != null || option.isEmpty) return;
    final correct = widget.isCorrect(option);
    setState(() => _picked = option);
    if (correct) StudentSoundService.instance.playGameEffect(StudentSoundService.balloonPop);
    _celebrate(correct);
    _pop.forward(from: 0);
    _report = Timer(quizGameReveal, () {
      if (mounted) widget.onAnswered(option);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _Frame(
      prompt: widget.prompt,
      stage: Stack(
        fit: StackFit.expand,
        children: [
          const _Backdrop(QuizGameArt.balloonBg),
          LayoutBuilder(builder: (context, box) => _balloons(box.biggest)),
        ],
      ),
    );
  }

  Widget _balloons(Size stage) {
    final options = widget.options;
    final count = options.length;
    final wide = stage.width >= stage.height * 1.05;
    final columns = wide ? math.min(count, 4) : math.min(count, 2);
    final rows = (count / columns).ceil();
    final cellW = stage.width / columns;
    final cellH = stage.height / rows;
    // ‏البالونُ المرسوم ٢٩٣×٦١٥: جسمُه النصفُ الأعلى وخيطُه ما تحته.
    const aspect = 293 / 615;
    // ‏فسحةٌ لانجرافه يميناً ويساراً، فلا يُقصّ عند الحافّة.
    final h = math.min(cellH * 0.94, cellW * 0.72 / aspect);
    final w = h * aspect;
    final font = (w * 0.2).clamp(17.0, 34.0).toDouble();
    return AnimatedBuilder(
      animation: Listenable.merge([_float, _rise, _pop]),
      builder: (context, _) {
        final rise = Curves.easeOutBack.transform(_rise.value);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < count; i++) _balloon(i, stage, cellW, cellH, w, h, font, rise, columns),
          ],
        );
      },
    );
  }

  Widget _balloon(int i, Size stage, double cellW, double cellH, double w, double h, double font, double rise, int columns) {
    final option = widget.options[i];
    final mark = _markOf(option, _picked, widget.isCorrect);
    final phase = i * 0.29;
    final t = _float.value;
    // ‏تموّجٌ: صعودٌ وهبوطٌ وانجرافٌ جانبيٌّ بطورٍ مختلفٍ لكل بالون.
    final bob = math.sin((t + phase) * 2 * math.pi) * h * 0.035;
    final drift = math.sin((t * 2 + phase * 1.7) * 2 * math.pi) * w * 0.12;
    final tilt = math.sin((t * 2 + phase) * 2 * math.pi) * 0.07;
    final p = _pop.value;
    var dx = drift;
    var dy = bob + (1 - rise) * (stage.height + h) * (0.8 + i * 0.12);
    var scale = 1.0;
    var balloonOpacity = 1.0;
    if (mark == _Mark.right) {
      // ‏ينتفخ لحظةً ثم يختفي، وتبقى إجابتُه بعلامة الصواب.
      scale = 1 + math.min(p / 0.12, 1) * 0.18;
      balloonOpacity = p < 0.12 ? 1 : 0;
    } else if (mark == _Mark.wrong) {
      dx += math.sin(p * math.pi * 9) * (1 - p) * 12;
      scale = 1 - p * 0.22;
      dy += p * h * 0.12;
      balloonOpacity = 1 - p * 0.45;
    }
    final column = i % columns;
    final row = i ~/ columns;
    final left = column * cellW + (cellW - w) / 2 + dx;
    final top = row * cellH + (cellH - h) / 2 + dy;
    final body = Offset(left + w / 2, top + h * 0.27);
    return Positioned(
      left: left - w * 0.4,
      top: top - h * 0.2,
      width: w * 1.8,
      height: h * 1.4,
      child: GestureDetector(
        key: ValueKey('balloon-$i'),
        behavior: HitTestBehavior.translucent,
        onTap: () => _tap(option),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (mark == _Mark.reveal)
              Positioned(
                left: w * 0.4 - w * 0.2,
                top: h * 0.2 - w * 0.1,
                width: w * 1.4,
                height: w * 1.4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.75), blurRadius: 40, spreadRadius: 6)],
                  ),
                ),
              ),
            Positioned(
              left: w * 0.4,
              top: h * 0.2,
              width: w,
              height: h,
              child: Opacity(
                opacity: balloonOpacity.clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: tilt,
                  alignment: Alignment.bottomCenter,
                  child: Transform.scale(
                    scale: scale,
                    alignment: const Alignment(0, -0.45),
                    child: ColorFiltered(
                      colorFilter: _hue(_hues[i % _hues.length]),
                      child: Image.asset(QuizGameArt.balloon, fit: BoxFit.contain, cacheWidth: 300),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: h * 0.2 + h * 0.27 - font * 0.95,
              child: Center(
                child: Transform.translate(
                  offset: Offset(math.sin(tilt) * h * 0.25, mark == _Mark.right ? -p * h * 0.08 : 0),
                  child: _Capsule(option, fontSize: font, maxWidth: w * 1.25, mark: mark),
                ),
              ),
            ),
            if (mark == _Mark.right)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ConfettiPainter(p, body - Offset(left - w * 0.4, top - h * 0.2), count: 40, spread: 1.4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// الصيد البحري
// ═══════════════════════════════════════════════════════════════════════

/// «الصيد البحري»: الطالبُ بشخصيته على الرصيف بصنّارة، والأسماكُ تسبح في
/// الأعماق تحمل الإجاباتِ في كبسولاتٍ ناصعة. يلمس سمكةً فتنزل السنّارةُ
/// إليها: الصحيحةُ تُرفع من الماء برذاذٍ وفقاعات، والخاطئةُ تفلت وتهرب.
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
  late final AnimationController _swim = AnimationController(vsync: this, duration: const Duration(seconds: 10));
  late final AnimationController _cast = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  int? _target;
  Timer? _report;

  /// ألوانُ الأسماك: البرتقاليةُ المرسومة، ثم زرقاءُ وورديةٌ وخضراء.
  static const _hues = [0.0, 185.0, 300.0, 95.0, 235.0, 40.0];

  /// سطحُ الماء وقاعُه في رسمة البحر (من ارتفاعها).
  static const _surface = 0.47;
  static const _sand = 0.84;

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
    if (_target == null && !_still(context)) {
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
    final correct = widget.isCorrect(option);
    _cast.forward(from: 0);
    // ‏النتيجةُ لحظةَ تعضّ السمكةُ الطُّعم.
    Future<void>.delayed(const Duration(milliseconds: 560), () {
      if (mounted) _celebrate(correct);
    });
    _report = Timer(const Duration(milliseconds: 1700), () {
      if (mounted) widget.onAnswered(option);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _Frame(
      prompt: widget.prompt,
      stage: LayoutBuilder(builder: (context, box) {
        final size = box.biggest;
        final surfaceY = _artPoint(size, Alignment.center, const Offset(0, _surface)).dy.clamp(size.height * 0.25, size.height * 0.5).toDouble();
        final floorY = math.min(_artPoint(size, Alignment.center, const Offset(0, _sand)).dy, size.height - 8);
        final count = widget.options.length;
        // ‏شاشةٌ عريضة: الأسماكُ في سربين جنباً إلى جنب، فتكبر وتُقرأ إجاباتُها.
        final columns = size.width > size.height * 1.2 && count > 2 ? 2 : 1;
        final lanes = (count / columns).ceil();
        final top = surfaceY + (floorY - surfaceY) * 0.06;
        final laneH = (floorY - top) / lanes;
        final fishH = math.min(laneH * 0.96, size.width / columns * 0.5 / 2.476).clamp(34.0, 130.0).toDouble();
        final fishW = fishH * 2.476;
        final avatar = (surfaceY * 0.62).clamp(44.0, 104.0).toDouble();
        final pierW = math.max(size.width * 0.2, avatar * 1.6);
        final pierY = surfaceY - avatar * 0.12;
        final tip = Offset(pierW + size.width * 0.06, pierY - avatar * 1.05);
        final font = (fishH * 0.5).clamp(22.0, 38.0).toDouble();
        return AnimatedBuilder(
          animation: Listenable.merge([_swim, _cast]),
          builder: (context, _) {
            final target = _target;
            final c = _cast.value;
            Offset? hook;
            Offset? splash;
            double splashT = 0;
            var lifted = Offset.zero;
            if (target != null && target >= 0) {
              final fish = _fishAt(target, size, top, laneH, fishW, fishH, columns) + Offset(fishW / 2, fishH * 0.35);
              final down = Curves.easeOut.transform((c / 0.35).clamp(0.0, 1.0));
              final up = Curves.easeInOut.transform(((c - 0.42) / 0.4).clamp(0.0, 1.0));
              final correct = widget.isCorrect(widget.options[target]);
              hook = Offset.lerp(tip, fish, down)!;
              if (correct && c > 0.42) {
                // ‏تُرفع مع الصنّارة إلى فوق الرصيف.
                final air = Offset(pierW + fishW * 0.15, surfaceY - avatar * 0.9);
                hook = Offset.lerp(fish, air, up)!;
                lifted = hook - fish;
                splash = Offset(fish.dx + lifted.dx * 0.4, surfaceY);
                splashT = ((c - 0.55) / 0.45).clamp(0.0, 1.0);
              } else if (!correct && c > 0.42) {
                hook = Offset.lerp(fish, tip, up)!;
              }
            }
            return Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(child: _Backdrop(QuizGameArt.fishingBg)),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _SeaLifePainter(
                        t: _swim.value + c,
                        surfaceY: surfaceY,
                        floorY: floorY,
                        pier: Rect.fromLTWH(0, pierY, pierW, 16),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: pierW * 0.5 - avatar * 0.5,
                  top: pierY - avatar * 0.98,
                  width: avatar,
                  height: avatar,
                  child: const FittedBox(child: StudentAvatarView(size: 96, showRing: false)),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _RodPainter(
                        hand: Offset(pierW * 0.5 + avatar * 0.32, pierY - avatar * 0.45),
                        tip: tip,
                        hook: hook,
                        sway: math.sin(_swim.value * 2 * math.pi * 3) * 3,
                      ),
                    ),
                  ),
                ),
                for (var i = 0; i < count; i++) _fish(i, size, top, laneH, fishW, fishH, columns, font, lifted),
                if (splash != null)
                  Positioned.fill(
                    child: IgnorePointer(child: CustomPaint(painter: _SplashPainter(splashT, splash, fishW))),
                  ),
                if (target != null && target >= 0 && widget.isCorrect(widget.options[target]) && c > 0.85)
                  PositionedDirectional(
                    top: 10,
                    end: 14,
                    child: Text(
                      tr('quiz.game.caught'),
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 8)]),
                    ),
                  ),
              ],
            );
          },
        );
      }),
    );
  }

  /// موضعُ السمكة [i]: حارةٌ لكلّ سمكة في سربها، تسبح فيها ذهاباً وإياباً بتموّج.
  Offset _fishAt(int i, Size stage, double top, double laneH, double fishW, double fishH, int columns) {
    final lanes = (widget.options.length / columns).ceil();
    final lane = i % lanes;
    final band = stage.width / columns;
    final phase = i * 0.31;
    final t = _swim.value;
    final travel = math.max(0.0, band - fishW - 16) * 0.5 * (1 + math.sin((t + phase) * 2 * math.pi));
    final wave = math.sin((t * 6 + phase) * 2 * math.pi) * fishH * 0.06;
    return Offset(band * (i ~/ lanes) + 8 + travel, top + laneH * lane + (laneH - fishH) / 2 + wave);
  }

  bool _facingRight(int i) => math.cos((_swim.value + i * 0.31) * 2 * math.pi) > 0;

  Widget _fish(int i, Size stage, double top, double laneH, double fishW, double fishH, int columns, double font, Offset lifted) {
    final option = widget.options[i];
    final target = _target;
    final c = _cast.value;
    final picked = target == i;
    final correct = widget.isCorrect(option);
    final escape = picked && !correct ? ((c - 0.42) / 0.5).clamp(0.0, 1.0) : 0.0;
    final mark = target == null || target < 0 ? _Mark.idle : _markOf(option, widget.options[target], widget.isCorrect);
    final at = _fishAt(i, stage, top, laneH, fishW, fishH, columns);
    var offset = picked && correct ? lifted : Offset(stage.width * 0.9 * Curves.easeIn.transform(escape), -escape * fishH * 0.4);
    if (picked && !correct && c > 0.3 && c < 0.5) offset += Offset(math.sin(c * 120) * 6, 0);
    final facingRight = target != null ? (picked && !correct ? true : _facingRight(i)) : _facingRight(i);
    final wag = math.sin((_swim.value * 30 + i) * 2 * math.pi) * 0.05;
    final hanging = picked && correct && c > 0.42;
    return Positioned(
      left: at.dx + offset.dx,
      top: at.dy + offset.dy,
      width: fishW,
      height: fishH,
      child: Opacity(
        opacity: (1 - escape * 0.9).clamp(0.0, 1.0),
        child: GestureDetector(
          key: ValueKey('fish-$i'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _tap(i),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (mark == _Mark.reveal)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.elliptical(fishW / 2, fishH / 2)),
                      boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.85), blurRadius: 30, spreadRadius: 4)],
                    ),
                  ),
                ),
              Positioned.fill(
                child: Transform.rotate(
                  angle: hanging ? -math.pi / 2 * 0.9 : wag,
                  child: Transform.flip(
                    flipX: !facingRight,
                    child: ColorFiltered(
                      colorFilter: _hue(_hues[i % _hues.length]),
                      child: Image.asset(QuizGameArt.fish, fit: BoxFit.contain, cacheWidth: 520),
                    ),
                  ),
                ),
              ),
              _Capsule(option, fontSize: font, maxWidth: fishW * 0.92, mark: mark, glowing: true),
            ],
          ),
        ),
      ),
    );
  }
}

/// حياةُ البحر فوق الرسمة: فقاعاتٌ تصعد، وموجٌ يلمع على السطح، والرصيفُ
/// الخشبيّ بأعمدته في الماء.
class _SeaLifePainter extends CustomPainter {
  _SeaLifePainter({required this.t, required this.surfaceY, required this.floorY, required this.pier});

  final double t;
  final double surfaceY;
  final double floorY;
  final Rect pier;

  @override
  void paint(Canvas canvas, Size size) {
    final bubble = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: 0.7);
    for (var i = 0; i < 16; i++) {
      final x = size.width * ((i * 0.137 + 0.05) % 1) + math.sin((t * 3 + i) * 2 * math.pi) * 6;
      final y = floorY - (floorY - surfaceY) * ((t * (0.8 + (i % 3) * 0.3) + i * 0.067) % 1);
      canvas.drawCircle(Offset(x, y), 3 + (i % 4).toDouble(), bubble);
    }
    // ‏لمعانُ الموج على السطح.
    final glint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final x = size.width * ((i * 0.19 + t * 0.6) % 1);
      final y = surfaceY + math.sin((t * 4 + i) * 2 * math.pi) * 3;
      canvas.drawLine(Offset(x, y), Offset(x + 16, y), glint);
    }
    // ‏الرصيف: ألواحٌ خشبيّة على أعمدة.
    final wood = Paint()..color = const Color(0xFF8B5A2B);
    final dark = Paint()..color = const Color(0xFF5C3A1A);
    for (final x in [pier.left + 10, pier.center.dx, pier.right - 14]) {
      canvas.drawRect(Rect.fromLTWH(x, pier.top, 9, surfaceY - pier.top + 34), dark);
    }
    canvas.drawRRect(RRect.fromRectAndRadius(pier, const Radius.circular(4)), wood);
    for (var x = pier.left + 18; x < pier.right; x += 22) {
      canvas.drawLine(Offset(x, pier.top + 2), Offset(x, pier.bottom - 2), dark..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(_SeaLifePainter old) => old.t != t || old.surfaceY != surfaceY || old.pier != pier;
}

class _RodPainter extends CustomPainter {
  _RodPainter({required this.hand, required this.tip, required this.sway, this.hook});
  final Offset hand;
  final Offset tip;
  final double sway;
  final Offset? hook;

  @override
  void paint(Canvas canvas, Size size) {
    final top = tip + Offset(0, sway);
    canvas.drawLine(
      hand,
      top,
      Paint()
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF78350F),
    );
    final end = hook ?? top + const Offset(0, 46);
    canvas.drawLine(top, end, Paint()..strokeWidth = 2..color = const Color(0xFF1E293B));
    // ‏العوّامةُ والخطّاف.
    if (hook == null) canvas.drawCircle(end - const Offset(0, 10), 6, Paint()..color = const Color(0xFFEF4444));
    canvas.drawArc(Rect.fromCircle(center: end + const Offset(0, 6), radius: 7), 0, math.pi, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = const Color(0xFF475569));
  }

  @override
  bool shouldRepaint(_RodPainter old) => old.hook != hook || old.tip != tip || old.hand != hand || old.sway != sway;
}

/// رذاذٌ وحلقاتٌ حين تخرج السمكةُ من الماء.
class _SplashPainter extends CustomPainter {
  _SplashPainter(this.t, this.at, this.width);
  final double t;
  final Offset at;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final fade = (1 - t).clamp(0.0, 1.0);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: fade * 0.9);
    for (var k = 0; k < 2; k++) {
      final r = width * (0.25 + t * 0.6) * (1 - k * 0.35);
      canvas.drawOval(Rect.fromCenter(center: at, width: r * 2, height: r * 0.5), ring);
    }
    final drop = Paint()..color = const Color(0xFFE0F2FE).withValues(alpha: fade);
    for (var i = 0; i < 14; i++) {
      final a = -math.pi * (0.15 + 0.7 * i / 13);
      final v = width * (0.45 + (i % 3) * 0.12);
      final p = at + Offset(math.cos(a) * v * t, math.sin(a) * v * t + width * 0.9 * t * t);
      canvas.drawCircle(p, 4 + (i % 3).toDouble(), drop);
    }
  }

  @override
  bool shouldRepaint(_SplashPainter old) => old.t != t || old.at != at;
}

// ═══════════════════════════════════════════════════════════════════════
// قطار الإجابات السعيد
// ═══════════════════════════════════════════════════════════════════════

/// «قطار الإجابات السعيد»: يدخل القطارُ المحطةَ الريفية بدخانه وصافرته،
/// والإجاباتُ مثبّتةٌ على عرباته. يختار الطالبُ العربةَ الصحيحة فتمتلئ
/// بالهدايا وينطلق القطار؛ والخاطئةُ تهتزّ وتتوهّج الصحيحة.
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

/// قطعُ القطار المرسوم (١٤٠٠×٤٣٦): ثلاثُ عرباتٍ ثم القاطرة، بأجزاءٍ من عرضه.
class _TrainSprite {
  static const width = 1400.0;
  static const height = 436.0;
  static const wagons = [(0.0, 334.0), (334.0, 646.0), (646.0, 953.0)];
  static const engine = (953.0, 1400.0);

  /// المدخنةُ في القاطرة (من عرضها وارتفاعها).
  static const chimney = Offset(0.7, 0.16);
}

class _TrainQuizQuestionState extends State<TrainQuizQuestion> with TickerProviderStateMixin {
  late final AnimationController _arrive = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final AnimationController _smoke = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final AnimationController _load = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final AnimationController _depart = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  int? _picked;
  final List<Timer> _timers = [];

  /// سكّةُ المحطة في الرسمة (من ارتفاعها): عليها تقف العجلات.
  static const _rail = 0.705;

  @override
  void initState() {
    super.initState();
    final answered = widget.answered;
    if (answered != null) {
      _picked = widget.options.indexOf(answered);
      _arrive.value = 1;
      _load.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still(context)) {
      _arrive.value = 1;
      _smoke.stop();
      return;
    }
    if (!_smoke.isAnimating) _smoke.repeat();
    if (_arrive.value == 0 && !_arrive.isAnimating) {
      _rumble();
      _arrive.forward();
    }
  }

  /// صوتُ محرّك السكّة والقطارُ يدخل المحطة: «صوت القطار» ثم «صوت القطار2»
  /// يبدأ قبل أن ينتهي الأوّل، فيتداخلان صوتاً واحداً متّصلاً.
  void _rumble() {
    final sound = StudentSoundService.instance;
    sound.playGameEffect(StudentSoundService.trainMove.first);
    _timers.add(Timer(const Duration(milliseconds: 1200), () {
      if (mounted) sound.playGameEffect(StudentSoundService.trainMove.last);
    }));
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _arrive.dispose();
    _smoke.dispose();
    _load.dispose();
    _depart.dispose();
    super.dispose();
  }

  void _tap(int index) {
    final option = widget.options[index];
    if (_picked != null || option.isEmpty) return;
    final correct = widget.isCorrect(option);
    setState(() => _picked = index);
    _arrive.value = 1;
    _celebrate(correct);
    _load.forward(from: 0);
    if (correct) {
      _timers.add(Timer(const Duration(milliseconds: 650), () {
        if (!mounted) return;
        // ‏ينطلق بالمقطع الطويل من صوت المحرّك.
        StudentSoundService.instance.playGameEffect(StudentSoundService.trainMove.last);
        if (!_still(context)) _depart.forward();
      }));
    }
    _timers.add(Timer(quizGameReveal + const Duration(milliseconds: 600), () {
      if (mounted) widget.onAnswered(option);
    }));
  }

  @override
  Widget build(BuildContext context) {
    return _Frame(
      prompt: widget.prompt,
      stage: LayoutBuilder(builder: (context, box) {
        final size = box.biggest;
        final n = widget.options.length;
        final wagonPx = [for (var i = 0; i < n; i++) _wagonSlice(i).$2 - _wagonSlice(i).$1];
        final enginePx = _TrainSprite.engine.$2 - _TrainSprite.engine.$1;
        final totalPx = wagonPx.fold<double>(enginePx, (a, b) => a + b);
        final railY = _artPoint(size, Alignment.center, const Offset(0, _rail)).dy.clamp(size.height * 0.45, size.height - 6).toDouble();
        final h = math.min(size.width * 0.97 * _TrainSprite.height / totalPx, railY * 0.8);
        final k = h / _TrainSprite.height;
        final trainW = totalPx * k;
        final font = (h * 0.19).clamp(15.0, 32.0).toDouble();
        return AnimatedBuilder(
          animation: Listenable.merge([_arrive, _smoke, _load, _depart]),
          builder: (context, _) {
            final arrive = Curves.easeOutCubic.transform(_arrive.value);
            final stop = (size.width - trainW) / 2;
            final x = stop - (1 - arrive) * (stop + trainW + 20) + Curves.easeInCubic.transform(_depart.value) * (size.width - stop + 20);
            final moving = _arrive.value < 1 || _depart.value > 0;
            final jiggle = moving ? math.sin(_smoke.value * 2 * math.pi * 10) * 1.6 : 0.0;
            final top = railY - h + jiggle;
            // ‏العرباتُ من اليسار، والأولى ملاصقةٌ للقاطرة يمينَها.
            final parts = <Widget>[];
            var left = x;
            for (var i = n - 1; i >= 0; i--) {
              final w = wagonPx[i] * k;
              parts.add(_wagon(i, left, top, w, h, font));
              left += w;
            }
            final engineW = enginePx * k;
            parts.add(Positioned(
              left: left,
              top: top,
              width: engineW,
              height: h,
              child: _Slice(from: _TrainSprite.engine.$1, to: _TrainSprite.engine.$2),
            ));
            final chimney = Offset(left + engineW * _TrainSprite.chimney.dx, top + h * _TrainSprite.chimney.dy);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(child: _Backdrop(QuizGameArt.trainBg)),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _SmokePainter(_smoke.value, chimney, h, busy: moving)),
                  ),
                ),
                ...parts,
                if (_arrive.value < 1 || (_depart.value > 0 && _depart.value < 0.6))
                  Positioned(
                    left: chimney.dx - 30,
                    top: math.max(4, chimney.dy - h * 0.75),
                    child: IgnorePointer(
                      child: Transform.rotate(
                        angle: -0.12,
                        child: Text(
                          tr('quiz.game.toot'),
                          style: TextStyle(
                            fontSize: (h * 0.16).clamp(14.0, 26.0).toDouble(),
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: const [Shadow(color: Color(0xAA1E293B), blurRadius: 6)],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      }),
    );
  }

  (double, double) _wagonSlice(int i) => _TrainSprite.wagons[i % _TrainSprite.wagons.length];

  Widget _wagon(int i, double left, double top, double w, double h, double font) {
    final option = widget.options[i];
    final picked = _picked;
    final mark = picked == null || picked < 0 ? _Mark.idle : _markOf(option, widget.options[picked], widget.isCorrect);
    final l = _load.value;
    final shake = mark == _Mark.wrong ? math.sin(l * math.pi * 10) * (1 - l) * 8 : 0.0;
    final bounce = mark == _Mark.right ? math.sin(l * math.pi) * -h * 0.06 : 0.0;
    final slice = _wagonSlice(i);
    Widget art = _Slice(from: slice.$1, to: slice.$2);
    // ‏عربةٌ رابعةٌ فأكثر: الرسمةُ نفسُها بلونٍ آخر.
    if (i >= _TrainSprite.wagons.length) art = ColorFiltered(colorFilter: _hue(150.0 * (i ~/ 3)), child: art);
    return Positioned(
      left: left + shake,
      top: top + bounce - h * 0.55,
      width: w,
      height: h * 1.55,
      child: GestureDetector(
        key: ValueKey('wagon-$i'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _tap(i),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (mark == _Mark.reveal)
              Positioned(
                left: w * 0.05,
                right: w * 0.05,
                top: h * 0.6,
                bottom: h * 0.1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(h * 0.2),
                    boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.75), blurRadius: 26)],
                  ),
                ),
              ),
            Positioned(left: 0, right: 0, bottom: 0, height: h, child: art),
            // ‏الهدايا تسقط في العربة الصحيحة وتبقى فوقها.
            if (mark == _Mark.right)
              for (var g = 0; g < 3; g++)
                Positioned(
                  left: w * (0.12 + g * 0.27),
                  top: h * 0.55 * Curves.bounceOut.transform(((l - g * 0.12) / 0.7).clamp(0.0, 1.0)) - h * 0.05,
                  child: Opacity(
                    opacity: l > g * 0.12 ? 1 : 0,
                    child: Text(const ['🎁', '⭐', '🎈'][g], style: TextStyle(fontSize: (h * 0.22).clamp(14.0, 40.0).toDouble())),
                  ),
                ),
            Positioned(
              left: 0,
              right: 0,
              top: h * 0.55 + h * 0.3,
              child: Center(child: _Capsule(option, fontSize: font, maxWidth: w * 0.94, mark: mark)),
            ),
          ],
        ),
      ),
    );
  }
}

/// جزءٌ من رسمة القطار بين [from] و[to] (بالبكسل من عرضها).
class _Slice extends StatelessWidget {
  const _Slice({required this.from, required this.to});

  final double from;
  final double to;

  @override
  Widget build(BuildContext context) {
    final fraction = (to - from) / _TrainSprite.width;
    final x = fraction >= 1 ? 0.0 : -1 + 2 * (from / _TrainSprite.width) / (1 - fraction);
    return LayoutBuilder(builder: (context, box) {
      final full = box.maxWidth / fraction;
      return ClipRect(
        child: OverflowBox(
          minWidth: full,
          maxWidth: full,
          alignment: Alignment(x, 0),
          child: Image.asset(QuizGameArt.train, width: full, height: box.maxHeight, fit: BoxFit.fill, cacheWidth: 1400),
        ),
      );
    });
  }
}

/// دخانٌ يتصاعد من المدخنة كتلاً بيضاء تكبر وتبهت — أكثفُ والقطارُ يسير.
class _SmokePainter extends CustomPainter {
  _SmokePainter(this.t, this.at, this.scale, {required this.busy});
  final double t;
  final Offset at;
  final double scale;
  final bool busy;

  @override
  void paint(Canvas canvas, Size size) {
    final puffs = busy ? 6 : 3;
    for (var i = 0; i < puffs; i++) {
      final p = (t + i / puffs) % 1;
      final r = scale * (0.05 + p * 0.12);
      final c = at + Offset(-p * scale * (busy ? 0.5 : 0.15) + math.sin(p * 6 + i) * 4, -p * scale * 0.7);
      canvas.drawCircle(c, r, Paint()..color = Colors.white.withValues(alpha: (1 - p) * 0.85));
    }
  }

  @override
  bool shouldRepaint(_SmokePainter old) => old.t != t || old.at != at || old.busy != busy;
}

// ═══════════════════════════════════════════════════════════════════════
// المقلاع الذكي
// ═══════════════════════════════════════════════════════════════════════

/// «المقلاع الذكي»: يسحب الطالبُ خيطَ المقلاع بإصبعه فيظهر خطُّ مسارٍ تنبّؤيٌّ
/// منقّط، ويُفلته فتنطلق الحصاةُ نحو الأهداف الطافية في الهواء. وتكفي لمسةُ
/// الهدف أيضاً: تُصوَّب الحصاةُ إليه وحدها — لطفلٍ لم تتعوّد يدُه السحبَ بعد.
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
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  late final AnimationController _flight = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  late final AnimationController _hit = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _snap = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  /// الخلفيةُ محاذاةً لليسار: فيها المقلاعُ المرسوم، فلا يقصّه هاتفٌ رأسيّ.
  static const _align = Alignment(-0.85, 0);

  /// شدُّ الخيطين على شعبتي المقلاع في الرسمة، ومستقرُّ الحصاة بينهما.
  static const _leftBand = Offset(0.139, 0.483);
  static const _rightBand = Offset(0.197, 0.476);

  /// عدّةُ الطيران: الجاذبيةُ والسرعةُ نسبةً إلى ارتفاع المسرح.
  static const _gravity = 1.7;
  static const _power = 5.2;
  static const _aimTime = 0.75;

  String? _picked;
  int? _hitIndex;
  Offset? _pull;
  Offset? _launchFrom;
  Offset _velocity = Offset.zero;
  int? _aimed;
  bool _missed = false;
  Timer? _report;
  Timer? _missTimer;

  /// هندسةُ المسرح من آخر رسم — يقرؤها مستمعُ الطيران ليعرف ما أصاب.
  Size _stage = Size.zero;

  @override
  void initState() {
    super.initState();
    _picked = widget.answered;
    if (_picked != null) _hit.value = 1;
    _flight.addListener(_onFlight);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still(context)) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat();
    }
  }

  @override
  void dispose() {
    _report?.cancel();
    _missTimer?.cancel();
    _float.dispose();
    _flight.dispose();
    _hit.dispose();
    _snap.dispose();
    super.dispose();
  }

  Offset get _rest {
    final a = _artPoint(_stage, _align, _leftBand);
    final b = _artPoint(_stage, _align, _rightBand);
    return Offset.lerp(a, b, 0.5)! + Offset(0, _stage.height * 0.01);
  }

  double get _maxPull => _stage.height * 0.26;

  double get _targetRadius => (math.min(_stage.width, _stage.height) * 0.085).clamp(26.0, 62.0).toDouble();

  Offset _targetAt(int i) {
    final n = widget.options.length;
    final xs = _stage.width * (0.42 + 0.5 * (n == 1 ? 0.5 : i / (n - 1)));
    final bandTop = _stage.height * 0.14;
    final bandH = _stage.height * 0.42;
    final y = bandTop + bandH * (i.isEven ? 0.15 : 0.75) + math.sin((_float.value + i * 0.27) * 2 * math.pi) * _stage.height * 0.03;
    return Offset(xs.clamp(_targetRadius * 1.2, _stage.width - _targetRadius * 1.2).toDouble(), y);
  }

  Offset _stoneAt(double seconds) =>
      _launchFrom! + _velocity * seconds + Offset(0, 0.5 * _gravity * _stage.height * seconds * seconds);

  bool get _flying => _flight.isAnimating;

  bool get _locked => _picked != null || _flying;

  // ── السحب ──

  void _onPanStart(DragStartDetails details) {
    if (_locked) return;
    if ((details.localPosition - _rest).distance > _stage.shortestSide * 0.22) return;
    HapticFeedback.selectionClick();
    setState(() {
      _missed = false;
      _pull = _rest;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_pull == null || _locked) return;
    var d = details.localPosition - _rest;
    if (d.distance > _maxPull) d = d / d.distance * _maxPull;
    setState(() => _pull = _rest + d);
  }

  void _onPanEnd(DragEndDetails details) {
    final pull = _pull;
    if (pull == null || _locked) return;
    final d = _rest - pull;
    if (d.distance < _maxPull * 0.18) {
      // ‏شدٌّ خفيف: يرجع الخيطُ بلا رمية.
      setState(() => _pull = null);
      return;
    }
    _fire(pull, d * _power * (_stage.height / _maxPull) / 2.6);
  }

  /// لمسةُ الهدف: الحصاةُ تُصوَّب إليه وتصيبه.
  void _aim(int i) {
    if (_locked || widget.options[i].isEmpty) return;
    final from = _rest;
    final to = _targetAt(i);
    const t = _aimTime;
    final g = _gravity * _stage.height;
    _aimed = i;
    _fire(from, Offset((to.dx - from.dx) / t, (to.dy - from.dy - 0.5 * g * t * t) / t));
  }

  void _fire(Offset from, Offset velocity) {
    HapticFeedback.mediumImpact();
    setState(() {
      _missed = false;
      _pull = null;
      _launchFrom = from;
      _velocity = velocity;
    });
    _snap.forward(from: 0);
    _flight.forward(from: 0);
  }

  void _onFlight() {
    if (_launchFrom == null || _picked != null || !_flight.isAnimating) return;
    final seconds = _flight.value * _flight.duration!.inMilliseconds / 1000;
    final stone = _stoneAt(seconds);
    final aimed = _aimed;
    if (aimed != null) {
      if (seconds >= _aimTime) _strike(aimed);
      return;
    }
    final r = _targetRadius * 1.15;
    for (var i = 0; i < widget.options.length; i++) {
      if ((stone - _targetAt(i)).distance <= r) {
        _strike(i);
        return;
      }
    }
    if (stone.dx > _stage.width + 30 || stone.dy > _stage.height + 30 || stone.dx < -30) {
      _flight.stop();
      _miss();
    }
  }

  void _strike(int i) {
    _flight.stop();
    final option = widget.options[i];
    final correct = widget.isCorrect(option);
    setState(() {
      _picked = option;
      _hitIndex = i;
      _aimed = null;
    });
    if (correct) StudentSoundService.instance.playGameEffect(StudentSoundService.balloonPop);
    _celebrate(correct);
    _hit.forward(from: 0);
    _report = Timer(quizGameReveal, () {
      if (mounted) widget.onAnswered(option);
    });
  }

  void _miss() {
    setState(() {
      _missed = true;
      _launchFrom = null;
      _aimed = null;
    });
    _missTimer?.cancel();
    _missTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _missed = false);
    });
  }

  /// نقاطُ المسار المتوقَّع من الشدّ الحاليّ.
  List<Offset> _prediction(Offset pull) {
    final v = (_rest - pull) * _power * (_stage.height / _maxPull) / 2.6;
    final g = _gravity * _stage.height;
    return [
      for (var s = 0.06; s < 1.4; s += 0.06)
        if (pull.dx + v.dx * s >= -10 && pull.dx + v.dx * s <= _stage.width + 10 && pull.dy + v.dy * s + 0.5 * g * s * s <= _stage.height)
          pull + v * s + Offset(0, 0.5 * g * s * s),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return _Frame(
      prompt: widget.prompt,
      stage: LayoutBuilder(builder: (context, box) {
        _stage = box.biggest;
        final font = (_targetRadius * 0.62).clamp(16.0, 30.0).toDouble();
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: AnimatedBuilder(
            animation: Listenable.merge([_float, _flight, _hit, _snap]),
            builder: (context, _) {
              final rest = _rest;
              final pull = _pull;
              final stoneR = (_stage.shortestSide * 0.028).clamp(8.0, 16.0).toDouble();
              Offset? stone;
              if (_launchFrom != null && _hitIndex == null && (_flying || _flight.value < 1)) {
                stone = _stoneAt(_flight.value * _flight.duration!.inMilliseconds / 1000);
              } else if (_picked == null && !_flying) {
                stone = pull ?? rest;
              }
              final pouch = pull ?? Offset.lerp(rest, rest + const Offset(0, 4), _snap.value)!;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned.fill(child: _Backdrop(QuizGameArt.slingshotBg, alignment: _align)),
                  // ‏موضعُ الجِراب: منه يبدأ السحب.
                  Positioned(
                    key: const ValueKey('sling-pouch'),
                    left: rest.dx - 24,
                    top: rest.dy - 24,
                    width: 48,
                    height: 48,
                    child: const IgnorePointer(child: SizedBox.expand()),
                  ),
                  for (var i = 0; i < widget.options.length; i++) _target(i, font),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _SlingPainter(
                          left: _artPoint(_stage, _align, _leftBand),
                          right: _artPoint(_stage, _align, _rightBand),
                          pouch: pouch,
                          stone: stone,
                          stoneRadius: stoneR,
                          path: pull == null ? const [] : _prediction(pull),
                        ),
                      ),
                    ),
                  ),
                  if (_picked == null && pull == null && !_flying)
                    Positioned(
                      left: math.max(6, rest.dx - 90),
                      top: rest.dy + _stage.height * 0.2,
                      width: 180,
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: (_missed ? const Color(0xFFEA580C) : const Color(0xFF1E293B)).withValues(alpha: 0.82),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              tr(_missed ? 'quiz.game.missed' : 'quiz.game.pull'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      }),
    );
  }

  Widget _target(int i, double font) {
    final option = widget.options[i];
    final mark = _markOf(option, _picked, widget.isCorrect);
    final at = _targetAt(i);
    final r = _targetRadius;
    final h = _hit.value;
    final struck = _hitIndex == i;
    final wobble = mark == _Mark.wrong ? math.sin(h * math.pi * 8) * (1 - h) * 0.35 : 0.0;
    final scale = mark == _Mark.right ? 1 + math.sin(h * math.pi) * 0.25 : 1.0;
    return Positioned(
      left: at.dx - r * 2,
      top: at.dy - r * 1.2,
      width: r * 4,
      height: r * 2.4 + font * 2.2,
      child: GestureDetector(
        key: ValueKey('target-$i'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _aim(i),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: r * 0.2,
              child: Transform.rotate(
                angle: wobble,
                child: Transform.scale(
                  scale: scale,
                  child: SizedBox(
                    width: r * 2,
                    height: r * 2,
                    child: CustomPaint(painter: _TargetPainter(glow: mark == _Mark.reveal)),
                  ),
                ),
              ),
            ),
            Positioned(
              top: r * 2.3,
              child: _Capsule(option, fontSize: font, maxWidth: r * 3.8, mark: mark),
            ),
            if (struck && mark == _Mark.right)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _ConfettiPainter(h, Offset(r * 2, r * 1.2), count: 30)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// هدفٌ بحلقاتٍ حمراءَ وبيضاء على عمودٍ صغيرٍ طافٍ بجناحين من غيم.
class _TargetPainter extends CustomPainter {
  _TargetPainter({required this.glow});
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    if (glow) canvas.drawCircle(c, r * 1.2, Paint()..color = _gold.withValues(alpha: 0.55)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawCircle(c + const Offset(0, 4), r, Paint()..color = const Color(0x33000000));
    const rings = [Color(0xFFDC2626), Colors.white, Color(0xFFDC2626), Colors.white, Color(0xFFFACC15)];
    for (var k = 0; k < rings.length; k++) {
      canvas.drawCircle(c, r * (1 - k * 0.19), Paint()..color = rings[k]);
    }
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = const Color(0xFF7F1D1D));
  }

  @override
  bool shouldRepaint(_TargetPainter old) => old.glow != glow;
}

/// الخيطان من شعبتي المقلاع إلى الجِراب، والحصاة، وخطُّ المسار المنقّط.
class _SlingPainter extends CustomPainter {
  _SlingPainter({
    required this.left,
    required this.right,
    required this.pouch,
    required this.stone,
    required this.stoneRadius,
    required this.path,
  });

  final Offset left;
  final Offset right;
  final Offset pouch;
  final Offset? stone;
  final double stoneRadius;
  final List<Offset> path;

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = Colors.white;
    final rim = Paint()..color = const Color(0x661E293B);
    for (var i = 0; i < path.length; i++) {
      final r = math.max(2.0, 6.0 - i * 0.18);
      canvas.drawCircle(path[i], r + 1.5, rim);
      canvas.drawCircle(path[i], r, dot);
    }
    final band = Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF5B2C0F);
    canvas.drawLine(right, pouch, band);
    final s = stone;
    if (s != null && (s - pouch).distance < 1) {
      _stone(canvas, s);
      canvas.drawLine(left, pouch, band);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: pouch, width: stoneRadius * 2.6, height: stoneRadius * 1.6), Radius.circular(stoneRadius)),
        Paint()..color = const Color(0xFF7C3A12),
      );
      _stone(canvas, s);
    } else {
      canvas.drawLine(left, pouch, band);
      if (s != null) _stone(canvas, s);
    }
  }

  void _stone(Canvas canvas, Offset at) {
    canvas.drawCircle(at, stoneRadius, Paint()..color = const Color(0xFF64748B));
    canvas.drawCircle(at - Offset(stoneRadius * 0.3, stoneRadius * 0.3), stoneRadius * 0.35, Paint()..color = const Color(0xFFCBD5E1));
  }

  @override
  bool shouldRepaint(_SlingPainter old) =>
      old.pouch != pouch || old.stone != stone || old.path.length != path.length || old.left != left || old.right != right;
}

// ═══════════════════════════════════════════════════════════════════════
// أغلفةُ الألعاب
// ═══════════════════════════════════════════════════════════════════════

/// بطلُ اللعبة على غلافها في بطاقة المذاكرة: ثلاثُ بالوناتٍ ملوّنة، أو
/// سمكة، أو القطار، أو هدفٌ وحصاة — من رسوم اللعبة نفسها.
class QuizGameCoverArt extends StatelessWidget {
  const QuizGameCoverArt({required this.style, super.key});

  final QuizGameStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final h = box.maxHeight;
      return switch (style) {
        QuizGameStyle.balloons => FittedBox(
            child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (hue, lift, angle) in const [(215.0, 0.12, -0.14), (0.0, 0.0, 0.0), (120.0, 0.16, 0.14)])
                Padding(
                  padding: EdgeInsets.only(top: h * lift),
                  child: Transform.rotate(
                    angle: angle,
                    child: ColorFiltered(
                      colorFilter: _hue(hue),
                      child: Image.asset(QuizGameArt.balloon, height: h * (1 - lift), cacheWidth: 160),
                    ),
                  ),
                ),
            ],
          ),
          ),
        QuizGameStyle.fishing => Center(
            child: Transform.rotate(
              angle: -0.18,
              child: Image.asset(QuizGameArt.fish, height: h * 0.62, cacheWidth: 400),
            ),
          ),
        QuizGameStyle.train => Align(
            alignment: Alignment.bottomCenter,
            child: Image.asset(QuizGameArt.train, height: h * 0.62, cacheWidth: 700),
          ),
        QuizGameStyle.slingshot => Center(
            child: SizedBox(
              width: h * 0.82,
              height: h * 0.82,
              child: CustomPaint(painter: _TargetPainter(glow: true)),
            ),
          ),
      };
    });
  }
}
