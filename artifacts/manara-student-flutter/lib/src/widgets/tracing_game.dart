import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../models/study_games.dart';
import '../services/student_sound_service.dart';
import '../services/tracing_path.dart';
import '../theme/student_theme.dart';

/// ما رسمه الخطُّ لعنصرٍ واحد: صورتُه، والجزءُ الذي فيه الحبر، ومساراتُه.
class TracingShape {
  const TracingShape({required this.image, required this.crop, required this.plan});

  final ui.Image image;

  /// موضعُ الحبر في [image]؛ ومنه تُقاس نقاطُ [plan].
  final Rect crop;
  final TracePlan plan;
}

/// يرسم [item] بالخطّ [style] ويبني مساراتِ تتبّعه.
///
/// يُرسم كبيراً ثم يُبنى المسارُ من الصورة نفسها التي تُعرض للطفل، فلا
/// يختلف ما يراه عمّا يُطلب منه — ولو لم يكن خطُّ التطبيق قد نُزّل بعد
/// فرُسم بالخطّ البديل.
Future<TracingShape?> renderTracingShape(TracingItem item, TextStyle style) async {
  final painter = TextPainter(
    text: TextSpan(
      text: item.text,
      style: style.copyWith(
        fontSize: item.kind == 'word' ? 110 : 150,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF000000),
        height: 1.3,
        letterSpacing: 0,
      ),
    ),
    textDirection: item.rtl ? TextDirection.rtl : TextDirection.ltr,
  )..layout();
  const pad = 16.0;
  final width = (painter.width + pad * 2).ceil();
  final height = (painter.height + pad * 2).ceil();
  if (width <= 0 || height <= 0) return null;

  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Offset(pad, pad));
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (bytes == null) return null;

  var minX = width, minY = height, maxX = -1, maxY = -1;
  final ink = List.generate(height, (_) => List<bool>.filled(width, false));
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (bytes.getUint8((y * width + x) * 4 + 3) > 110) {
        ink[y][x] = true;
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0) return null;
  const margin = 3;
  final left = math.max(0, minX - margin);
  final top = math.max(0, minY - margin);
  final right = math.min(width - 1, maxX + margin);
  final bottom = math.min(height - 1, maxY + margin);
  final cropped = [
    for (var y = top; y <= bottom; y++) ink[y].sublist(left, right + 1),
  ];
  final plan = TracePlanner.plan(cropped, rtl: item.rtl, topFirst: item.kind != 'word');
  if (plan.isEmpty) return null;
  return TracingShape(
    image: image,
    crop: Rect.fromLTRB(left.toDouble(), top.toDouble(), right + 1.0, bottom + 1.0),
    plan: plan,
  );
}

/// لعبةُ «تتبّع واكتب» في بطاقة المذاكرة.
///
/// ── كيف تُلعب ──
/// تظهر الكلمةُ باهتةً وعليها نقاطٌ مرقّمة. يضع الطفلُ إصبعه على النقطة
/// الخضراء ويمرّ بالنقاط بترتيبها: النقطةُ التالية وحدها تُحتسب، فلا يتقدّم
/// إلا في اتجاه الكتابة. وإن ابتعد عن الخطّ عادت الجرّةُ من أوّلها بصوت
/// تنبيهٍ لطيف. ونقطةُ الحرف تُلمس لمساً. وكلُّ عنصرٍ يكتمل بصوت نجاح، وآخرُها
/// يصرف المكافأة من الخادم.
class TracingGame extends StatefulWidget {
  const TracingGame({
    required this.game,
    required this.onWin,
    required this.onReplay,
    this.shapeBuilder = renderTracingShape,
    super.key,
  });

  final StudyGame game;
  final Future<void> Function() onWin;
  final VoidCallback onReplay;

  /// يُستبدل في الاختبار وحده.
  final Future<TracingShape?> Function(TracingItem item, TextStyle style) shapeBuilder;

  @override
  State<TracingGame> createState() => TracingGameState();
}

@visibleForTesting
class TracingGameState extends State<TracingGame> with SingleTickerProviderStateMixin {
  static const _color = Color(0xFF16A34A);
  static const _next = Color(0xFFF59E0B);

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  int _index = 0;
  TracingShape? _shape;
  bool _loading = true;
  int _stroke = 0;

  /// آخرُ نقطةٍ بلغها الإصبع في الجرّة الحالية؛ -1 قبل أن تبدأ.
  int _reached = -1;
  List<Offset> _trail = [];
  final List<List<Offset>> _doneTrails = [];
  int _mistakes = 0;
  bool _itemDone = false;
  bool _allDone = false;
  String? _hint;
  Rect _dest = Rect.zero;

  List<TracingItem> get _items => widget.game.tracing;
  TracingItem get _item => _items[_index];

  /// مساراتُ العنصر الحالي، للاختبار.
  @visibleForTesting
  TracePlan? get plan => _shape?.plan;

  /// موضعُ نقطةٍ من المسار على الشاشة، للاختبار.
  @visibleForTesting
  Offset toCanvas(TracePoint p) => _toCanvas(p);

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // مرّةً واحدة: الخطُّ يُقرأ من السمة، وما بعد الأول يطلبه [_advance].
    if (_started) return;
    _started = true;
    unawaited(_load());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final style = Theme.of(context).textTheme.headlineLarge ?? const TextStyle();
    TracingShape? shape;
    try {
      shape = await widget.shapeBuilder(_item, style);
    } catch (error) {
      debugPrint('[tracing] shape failed for "${_item.text}": $error');
    }
    if (!mounted) return;
    if (shape == null) {
      // ما لا يُرسم لا يُطلب: يُتخطّى إلى ما بعده.
      _advance();
      return;
    }
    setState(() {
      _shape = shape;
      _loading = false;
      _stroke = 0;
      _reached = -1;
      _trail = [];
      _doneTrails.clear();
      _itemDone = false;
      _hint = null;
    });
  }

  void _advance() {
    if (_index + 1 >= _items.length) {
      setState(() {
        _allDone = true;
        _loading = false;
      });
      unawaited(widget.onWin());
      return;
    }
    setState(() {
      _index += 1;
      _shape = null;
      _loading = true;
    });
    unawaited(_load());
  }

  void _restartItem() {
    StudentSoundService.instance.playTap();
    setState(() {
      _stroke = 0;
      _reached = -1;
      _trail = [];
      _doneTrails.clear();
      _hint = null;
    });
  }

  // ── الهندسة ──────────────────────────────────────────────────────

  Offset _toCanvas(TracePoint p) =>
      Offset(_dest.left + p.x * _dest.width, _dest.top + p.y * _dest.height);

  /// سُمكُ الخطّ على الشاشة.
  double get _inkPx => (_shape?.plan.inkWidth ?? 0.1) * _dest.height;

  /// كم يقترب الإصبعُ من نقطةٍ لتُحتسب.
  double get _hitRadius => math.max(22, _inkPx * 0.95);

  /// كم يبتعد عن الخطّ قبل أن تُعاد الجرّة.
  double get _offRadius => math.max(38, _inkPx * 1.8);

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final length = ab.distanceSquared;
    if (length == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  // ── اللمس ────────────────────────────────────────────────────────

  TraceStroke? get _current {
    final strokes = _shape?.plan.strokes;
    if (strokes == null || _stroke >= strokes.length) return null;
    return strokes[_stroke];
  }

  void _down(Offset position) {
    final stroke = _current;
    if (stroke == null || _itemDone) return;
    final start = _toCanvas(stroke.points.first);
    final reach = stroke.isDot ? _hitRadius * 1.4 : _hitRadius;
    if ((position - start).distance <= reach) {
      if (stroke.isDot) {
        _completeStroke([position]);
        return;
      }
      setState(() {
        _reached = 0;
        _trail = [position];
        _hint = null;
      });
    } else {
      _miss(stroke.isDot ? tr('study.trace.tapDot') : tr('study.trace.start'));
    }
  }

  void _move(Offset position) {
    final stroke = _current;
    if (stroke == null || _reached < 0) return;
    final points = stroke.points;
    var reached = _reached;
    // النقطةُ التالية وحدها: لا قفزَ إلى ما بعدها، ولا رجوعَ يُحتسب.
    while (reached + 1 < points.length &&
        (position - _toCanvas(points[reached + 1])).distance <= _hitRadius) {
      reached += 1;
    }
    final from = _toCanvas(points[reached]);
    final to = _toCanvas(points[math.min(reached + 1, points.length - 1)]);
    if (_distanceToSegment(position, from, to) > _offRadius) {
      _miss(tr('study.trace.offPath'));
      return;
    }
    if (reached == points.length - 1) {
      _completeStroke([..._trail, position]);
      return;
    }
    setState(() {
      _reached = reached;
      _trail = [..._trail, position];
    });
  }

  void _up() {
    final stroke = _current;
    if (stroke == null || _reached < 0) return;
    // رفع إصبعه قبل نهاية الجرّة: تُعاد بلا عقوبة، بإشارةٍ إلى أين يكمل.
    setState(() {
      _reached = -1;
      _trail = [];
      _hint = tr('study.trace.keepGoing');
    });
  }

  void _miss(String hint) {
    StudentSoundService.instance.play(StudentSoundCue.warning);
    setState(() {
      _mistakes += 1;
      _reached = -1;
      _trail = [];
      _hint = hint;
    });
  }

  void _completeStroke(List<Offset> trail) {
    final strokes = _shape!.plan.strokes;
    final last = _stroke + 1 >= strokes.length;
    setState(() {
      _doneTrails.add(trail);
      _stroke += 1;
      _reached = -1;
      _trail = [];
      _hint = null;
      _itemDone = last;
    });
    if (!last) {
      StudentSoundService.instance.play(StudentSoundCue.answerSelected);
      return;
    }
    StudentSoundService.instance.play(StudentSoundCue.success);
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted && _itemDone) _advance();
    });
  }

  // ── الواجهة ─────────────────────────────────────────────────────

  String _kindLabel(TracingItem item) => switch (item.kind) {
        'letter' => tr('study.trace.letter'),
        'number' => tr('study.trace.number'),
        _ => tr('study.trace.word'),
      };

  @override
  Widget build(BuildContext context) {
    if (_allDone) return _finished(context);
    final item = _item;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _Chip(
                text: trf('study.games.placed', {'done': _index + 1, 'total': _items.length}),
                color: _color,
              ),
              const SizedBox(width: 8),
              _Chip(text: _kindLabel(item), color: _next),
              const Spacer(),
              if (_mistakes > 0)
                Text(
                  trf('study.games.mistakes', {'n': _mistakes}),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: StudentSurface.mutedInk(context),
                  ),
                ),
              IconButton(
                tooltip: tr('study.trace.redo'),
                onPressed: _shape == null || _itemDone ? null : _restartItem,
                icon: const Icon(Icons.replay_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: StudentSurface.card(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: StudentSurface.outline(context)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: _loading || _shape == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 10),
                            Text(tr('study.trace.preparing')),
                          ],
                        ),
                      )
                    : _board(context),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 30,
          child: Center(
            child: Text(
              _itemDone ? tr('study.trace.great') : (_hint ?? tr('study.trace.start')),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _itemDone ? _color : StudentSurface.mutedInk(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _board(BuildContext context) {
    final shape = _shape!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Offset.zero & constraints.biggest;
        final area = box.deflate(math.min(28, box.shortestSide * 0.08));
        final aspect = shape.crop.width / shape.crop.height;
        var w = area.width;
        var h = w / aspect;
        if (h > area.height) {
          h = area.height;
          w = h * aspect;
        }
        _dest = Rect.fromCenter(center: area.center, width: w, height: h);
        return RawGestureDetector(
          key: const ValueKey('tracing-board'),
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
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _TracingPainter(
                shape: shape,
                dest: _dest,
                stroke: _stroke,
                reached: _reached,
                trail: _trail,
                doneTrails: _doneTrails,
                pulse: _pulse.value,
                ink: StudentSurface.ink(context),
                inkPx: _inkPx,
                done: _itemDone,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _finished(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 8),
            Text(
              tr('study.trace.done'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: StudentSurface.ink(context),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.onReplay,
              icon: const Icon(Icons.replay_rounded),
              label: Text(tr('study.games.playAgain')),
              style: FilledButton.styleFrom(backgroundColor: _color),
            ),
          ],
        ),
      );
}

/// يكسب ساحةَ اللمس فور النزول: بدونه تأخذ الصفحاتُ الأفقية في بطاقة
/// المذاكرة كلَّ جرّةٍ أفقية، فينتقل التبويبُ بدل أن يُكتب الحرف.
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
        child: Text(
          text,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: color),
        ),
      );
}

class _TracingPainter extends CustomPainter {
  _TracingPainter({
    required this.shape,
    required this.dest,
    required this.stroke,
    required this.reached,
    required this.trail,
    required this.doneTrails,
    required this.pulse,
    required this.ink,
    required this.inkPx,
    required this.done,
  });

  final TracingShape shape;
  final Rect dest;
  final int stroke;
  final int reached;
  final List<Offset> trail;
  final List<List<Offset>> doneTrails;
  final double pulse;
  final Color ink;
  final double inkPx;
  final bool done;

  static const _start = Color(0xFF16A34A);
  static const _next = Color(0xFFF59E0B);
  static const _drawn = Color(0xFF7C3AED);

  Offset _at(TracePoint p) => Offset(dest.left + p.x * dest.width, dest.top + p.y * dest.height);

  @override
  void paint(Canvas canvas, Size size) {
    // سطرا الكرّاسة.
    final guide = Paint()
      ..color = ink.withValues(alpha: 0.08)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, dest.top), Offset(size.width, dest.top), guide);
    canvas.drawLine(Offset(0, dest.bottom), Offset(size.width, dest.bottom), guide);

    // الشكلُ باهتاً — الصورةُ نفسها التي بُني منها المسار.
    canvas.drawImageRect(
      shape.image,
      shape.crop,
      dest,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = ColorFilter.mode(
          (done ? _start : ink).withValues(alpha: done ? 0.55 : 0.16),
          BlendMode.srcIn,
        ),
    );

    final pen = Paint()
      ..color = _drawn
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(8, inkPx * 0.7);
    for (final line in [...doneTrails, trail]) {
      if (line.length == 1) {
        canvas.drawCircle(line.first, pen.strokeWidth * 0.7, Paint()..color = _drawn);
      } else if (line.length > 1) {
        final path = Path()..moveTo(line.first.dx, line.first.dy);
        for (final p in line.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, pen);
      }
    }
    if (done) return;

    final strokes = shape.plan.strokes;
    final dotR = math.max(5.0, inkPx * 0.18);

    // أرقامُ الجرّات القادمة عند بداياتها: ترتيبُ الكتابة ظاهرٌ من الأول.
    for (var i = stroke + 1; i < strokes.length; i++) {
      _label(canvas, _at(strokes[i].points.first), '${i + 1}', ink.withValues(alpha: 0.35), dotR * 1.6);
    }
    if (stroke >= strokes.length) return;

    final current = strokes[stroke];
    final points = current.points;
    for (var i = 1; i < points.length; i++) {
      final p = _at(points[i]);
      final isNext = i == reached + 1;
      final paint = Paint()
        ..color = i <= reached
            ? _drawn
            : isNext
                ? _next
                : ink.withValues(alpha: 0.30);
      canvas.drawCircle(p, isNext ? dotR * (1.2 + pulse * 0.5) : dotR, paint);
    }

    // البداية: دائرةٌ خضراء نابضة برقم الجرّة، وسهمٌ إلى النقطة التالية.
    final start = _at(points.first);
    final startR = dotR * (2.0 + (reached < 0 ? pulse * 0.6 : 0));
    canvas.drawCircle(start, startR, Paint()..color = _start);
    _label(canvas, start, '${stroke + 1}', Colors.white, startR, fill: false);
    if (points.length > 1 && reached < 0) {
      final toward = _at(points[math.min(2, points.length - 1)]);
      final direction = toward - start;
      if (direction.distance > 0) {
        final unit = direction / direction.distance;
        final tip = start + unit * (startR + dotR * 4);
        final base = start + unit * (startR + dotR * 1.2);
        final arrow = Paint()
          ..color = _start
          ..strokeWidth = math.max(3, dotR * 0.6)
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(base, tip, arrow);
        final normal = Offset(-unit.dy, unit.dx) * dotR * 1.2;
        final back = tip - unit * dotR * 1.4;
        canvas.drawLine(tip, back + normal, arrow);
        canvas.drawLine(tip, back - normal, arrow);
      }
    }
  }

  void _label(Canvas canvas, Offset at, String text, Color color, double radius, {bool fill = true}) {
    if (fill) {
      canvas.drawCircle(at, radius, Paint()..color = color.withValues(alpha: 0.15));
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: radius * 1.1, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_TracingPainter old) => true;
}
