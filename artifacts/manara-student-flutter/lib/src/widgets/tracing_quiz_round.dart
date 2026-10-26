import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/student_strings.dart';
import '../models/study_games.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';

/// جولةُ «أجب ومرِّر»: أسئلةٌ يولّدها الذكاء الاصطناعي من نصّ الدرس، وكلُّ
/// خيارٍ في بطاقته يُمرِّر الطفلُ إصبعه على خطّها ليختاره.
///
/// ── قواعدُ الجولة ──
/// - التمريرُ على الصحيح: درجةٌ — وجوهرةٌ في أوّل جولةٍ للدرس.
/// - التمريرُ على خطأ: لا شيء، ويُكشف الصحيحُ، ثم السؤالُ التالي بلا إعادة.
/// - آخرُ سؤال: تُرسل النتيجةُ إلى الخادم ([onFinish])، وهو يصرف الجواهرَ
///   مرّةً لكل درس. فالإعادةُ تُلعب كاملةً بأسئلةٍ جديدة، بلا جواهر جديدة.
///
/// ── ولماذا خطٌّ تحت الكلمة لا حروفُها ──
/// التمريرُ اختيار، لا كتابة: خطٌّ من أوّل الكلمة إلى آخرها باتجاه الكتابة،
/// بنقاطه المتتالية. ولا يُرسم الخيارُ صورةً ولا يُقرأ من معالج الرسوم —
/// فلا يتعلّق السؤالُ على جهازٍ تتعلّق فيه تلك القراءة.
class TracingQuizRound extends StatefulWidget {
  const TracingQuizRound({
    required this.items,
    required this.onFinish,
    required this.onReplay,
    required this.speak,
    this.alreadyRewarded = false,
    super.key,
  });

  final List<TracingItem> items;

  /// نهايةُ الجولة: الصحيحُ من المجموع.
  final Future<void> Function(int correct, int total) onFinish;
  final VoidCallback onReplay;
  final void Function(String text, String lang) speak;

  /// صُرفت جواهرُ هذا الدرس من قبل: الجولةُ تدريب، ولا تُعرض جوهرةٌ لكل صحيحة.
  final bool alreadyRewarded;

  @override
  State<TracingQuizRound> createState() => _TracingQuizRoundState();
}

class _TracingQuizRoundState extends State<TracingQuizRound> {
  static const _green = Color(0xFF16A34A);
  static const _red = Color(0xFFDC2626);
  static const _amber = Color(0xFFF59E0B);

  /// كم يبقى الكشفُ ظاهراً قبل السؤال التالي.
  static const revealFor = Duration(milliseconds: 1400);

  int _index = 0;
  int _score = 0;
  String? _picked;
  bool _finished = false;

  TracingItem get _item => widget.items[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.speak(_item.prompt ?? _item.text, _item.lang);
    });
  }

  void _choose(String option) {
    if (_picked != null || _finished) return;
    final right = option == _item.text;
    if (right) {
      StudentSoundService.instance.play(StudentSoundCue.success);
      HapticFeedback.lightImpact();
    } else {
      StudentSoundService.instance.play(StudentSoundCue.warning);
      HapticFeedback.mediumImpact();
    }
    setState(() {
      _picked = option;
      if (right) _score += 1;
    });
    // الصحيحُ يُسمع في الحالين: من أصاب يتأكّد، ومن أخطأ يتعلّم.
    widget.speak(_item.speech, _item.lang);
    final index = _index;
    Future.delayed(revealFor, () {
      if (!mounted || _index != index) return;
      if (_index + 1 >= widget.items.length) {
        setState(() => _finished = true);
        unawaited(widget.onFinish(_score, widget.items.length));
        return;
      }
      setState(() {
        _index += 1;
        _picked = null;
      });
      widget.speak(_item.prompt ?? _item.text, _item.lang);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return _summary(context);
    final item = _item;
    final rtl = item.lang != 'en';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _Chip(
                text: trf('study.quiz.question', {'n': _index + 1, 'total': widget.items.length}),
                color: _amber,
              ),
              const SizedBox(width: 8),
              _Chip(text: trf('study.quiz.score', {'n': _score}), color: _green),
              if (!widget.alreadyRewarded) ...[
                const SizedBox(width: 8),
                _Chip(text: '💎 $_score', color: const Color(0xFF0EA5E9)),
              ],
              const Spacer(),
              IconButton(
                key: const ValueKey('tracing-speak'),
                tooltip: tr('study.trace.listen'),
                onPressed: () => widget.speak(item.prompt ?? item.text, item.lang),
                icon: const Icon(Icons.volume_up_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(
            item.prompt ?? '',
            key: const ValueKey('tracing-prompt'),
            textAlign: TextAlign.center,
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(
              fontSize: 20,
              height: 1.45,
              fontWeight: FontWeight.w900,
              color: StudentSurface.ink(context),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Column(
              children: [
                for (final option in item.options)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: SwipeOptionCard(
                        key: ValueKey('tracing-option-$option'),
                        text: option,
                        rtl: rtl,
                        state: _picked == null
                            ? SwipeCardState.open
                            : option == item.text
                                ? SwipeCardState.right
                                : option == _picked
                                    ? SwipeCardState.wrong
                                    : SwipeCardState.locked,
                        onSwiped: () => _choose(option),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 30,
          child: Center(
            child: Text(
              _picked == null
                  ? tr('study.quiz.swipeHint')
                  : _picked == item.text
                      ? (widget.alreadyRewarded ? tr('study.quiz.right') : tr('study.quiz.rightGem'))
                      : tr('study.quiz.wrong'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _picked == null
                    ? StudentSurface.mutedInk(context)
                    : _picked == item.text
                        ? _green
                        : _red,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context) {
    final total = widget.items.length;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_score == total ? '🏆' : '🌟', style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 8),
            Text(
              trf('study.quiz.result', {'n': _score, 'total': total}),
              key: const ValueKey('tracing-quiz-result'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: StudentSurface.ink(context)),
            ),
            const SizedBox(height: 6),
            Text(
              widget.alreadyRewarded ? tr('study.quiz.practice') : trf('study.quiz.gems', {'n': _score}),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: StudentSurface.mutedInk(context)),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('tracing-quiz-replay'),
              onPressed: widget.onReplay,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(tr('study.quiz.newQuestions')),
              style: FilledButton.styleFrom(backgroundColor: _green),
            ),
          ],
        ),
      ),
    );
  }
}

enum SwipeCardState { open, right, wrong, locked }

/// بطاقةُ خيار: نصُّه، وتحته خطٌّ منقّط يُمرَّر عليه من بدايته الخضراء إلى
/// آخره. النقطةُ التالية وحدها تُحتسب، والابتعادُ عن الخطّ يُعيده من أوّله.
class SwipeOptionCard extends StatefulWidget {
  const SwipeOptionCard({
    required this.text,
    required this.rtl,
    required this.state,
    required this.onSwiped,
    super.key,
  });

  final String text;
  final bool rtl;
  final SwipeCardState state;
  final VoidCallback onSwiped;

  /// نقاطُ الخطّ في بطاقةٍ بحجم [size]: من بداية الكتابة إلى آخرها، تحت النصّ.
  static List<Offset> lineFor(Size size, {required bool rtl, int count = 8}) {
    final y = size.height * 0.80;
    final from = size.width * 0.12;
    final to = size.width * 0.88;
    return [
      for (var i = 0; i < count; i++)
        Offset(
          rtl ? to - (to - from) * i / (count - 1) : from + (to - from) * i / (count - 1),
          y,
        ),
    ];
  }

  @override
  State<SwipeOptionCard> createState() => _SwipeOptionCardState();
}

class _SwipeOptionCardState extends State<SwipeOptionCard> {
  Size _size = Size.zero;

  /// آخرُ نقطةٍ بلغها الإصبع؛ -1 قبل أن يبدأ.
  int _reached = -1;

  List<Offset> get _line => SwipeOptionCard.lineFor(_size, rtl: widget.rtl);
  double get _hit => math.max(26, _size.height * 0.22);
  double get _off => math.max(44, _size.height * 0.38);

  bool get _open => widget.state == SwipeCardState.open;

  @override
  void didUpdateWidget(SwipeOptionCard old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state || old.text != widget.text) _reached = -1;
  }

  void _down(Offset p) {
    if (!_open) return;
    if ((p - _line.first).distance <= _hit) {
      setState(() => _reached = 0);
    } else {
      // لمسةٌ في غير موضع البدء لا تُعدّ خطأ: يُنبَّه بلطفٍ إلى النقطة الخضراء.
      StudentSoundService.instance.playTap();
    }
  }

  void _move(Offset p) {
    if (!_open || _reached < 0) return;
    final line = _line;
    var reached = _reached;
    while (reached + 1 < line.length && (p - line[reached + 1]).distance <= _hit) {
      reached += 1;
    }
    if ((p.dy - line.first.dy).abs() > _off) {
      setState(() => _reached = -1);
      return;
    }
    if (reached == line.length - 1) {
      setState(() => _reached = reached);
      widget.onSwiped();
      return;
    }
    if (reached != _reached) setState(() => _reached = reached);
  }

  void _up() {
    if (_reached >= 0 && _reached < _line.length - 1) setState(() => _reached = -1);
  }

  @override
  Widget build(BuildContext context) {
    final (bg, border, ink) = switch (widget.state) {
      SwipeCardState.open => (StudentSurface.card(context), const Color(0xFFF59E0B), StudentSurface.ink(context)),
      SwipeCardState.right => (const Color(0xFFDCFCE7), const Color(0xFF16A34A), const Color(0xFF166534)),
      SwipeCardState.wrong => (const Color(0xFFFEE2E2), const Color(0xFFDC2626), const Color(0xFF991B1B)),
      SwipeCardState.locked => (StudentSurface.card(context), StudentSurface.outline(context), StudentSurface.mutedInk(context)),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            _EagerPanRecognizer: GestureRecognizerFactoryWithHandlers<_EagerPanRecognizer>(
              _EagerPanRecognizer.new,
              (recognizer) => recognizer
                ..dragStartBehavior = DragStartBehavior.down
                ..onStart = (details) {
                  _down(details.localPosition);
                }
                ..onUpdate = (details) {
                  _move(details.localPosition);
                }
                ..onEnd = (_) {
                  _up();
                }
                ..onCancel = _up,
            ),
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border, width: widget.state == SwipeCardState.open ? 2 : 3),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SwipeLinePainter(
                      line: SwipeOptionCard.lineFor(_size, rtl: widget.rtl),
                      reached: widget.state == SwipeCardState.open ? _reached : -1,
                      active: widget.state == SwipeCardState.open,
                      ink: ink,
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, -0.25),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.text,
                        textDirection: widget.rtl ? TextDirection.rtl : TextDirection.ltr,
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: ink),
                      ),
                    ),
                  ),
                ),
                if (widget.state == SwipeCardState.right || widget.state == SwipeCardState.wrong)
                  PositionedDirectional(
                    top: 8,
                    end: 10,
                    child: Icon(
                      widget.state == SwipeCardState.right ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: border,
                      size: 28,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SwipeLinePainter extends CustomPainter {
  _SwipeLinePainter({required this.line, required this.reached, required this.active, required this.ink});

  final List<Offset> line;
  final int reached;
  final bool active;
  final Color ink;

  static const _start = Color(0xFF16A34A);
  static const _drawn = Color(0xFF7C3AED);

  @override
  void paint(Canvas canvas, Size size) {
    if (line.length < 2 || !active) return;
    final dot = math.max(4.0, size.height * 0.035);
    if (reached > 0) {
      final path = Path()..moveTo(line.first.dx, line.first.dy);
      for (final p in line.sublist(1, reached + 1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = _drawn
          ..style = PaintingStyle.stroke
          ..strokeWidth = dot * 2
          ..strokeCap = StrokeCap.round,
      );
    }
    for (var i = 1; i < line.length; i++) {
      canvas.drawCircle(
        line[i],
        dot,
        Paint()..color = i <= reached ? _drawn : ink.withValues(alpha: i == reached + 1 ? 0.6 : 0.25),
      );
    }
    canvas.drawCircle(line.first, dot * 2.2, Paint()..color = _start);
    // سهمٌ صغير باتجاه التمرير.
    final unit = (line[1] - line[0]) / (line[1] - line[0]).distance;
    final tip = line.first + unit * dot * 5;
    final arrow = Paint()
      ..color = _start
      ..strokeWidth = math.max(2.5, dot * 0.7)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(line.first + unit * dot * 2.4, tip, arrow);
    final normal = Offset(-unit.dy, unit.dx) * dot;
    canvas.drawLine(tip, tip - unit * dot * 1.3 + normal, arrow);
    canvas.drawLine(tip, tip - unit * dot * 1.3 - normal, arrow);
  }

  @override
  bool shouldRepaint(_SwipeLinePainter old) =>
      old.reached != reached || old.active != active || old.line.length != line.length || old.ink != ink;
}

/// يكسب ساحةَ اللمس فور النزول: البطاقةُ داخل صفحاتٍ أفقية، والتمريرُ أفقيّ.
class _EagerPanRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: color)),
      );
}
