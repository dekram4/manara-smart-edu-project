import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// «استوديو الرسم»: رسمٌ حرٌّ بطبقات — منفصلٌ عن ألعاب التلوين.
///
/// ── كيف يُحفظ الرسم ──
/// خطواتٌ لا صور: كلُّ طبقةٍ قائمةُ عمليّات ([StudioOp]) — خطُّ فرشاة، أو شكل،
/// أو تدرّج. والطبقةُ قيمةٌ ثابتة: كلُّ تعديلٍ يصنع طبقةً جديدة تشارك القديمةَ
/// قائمتَها، فالتراجعُ والإعادةُ صورٌ للقائمة لا للبكسلات — سريعان ولا يثقلان.
///
/// ── كيف يُرسم ──
/// لكلّ طبقةٍ صورةٌ مسجّلة ([ui.Picture]) تُبنى مرّةً وتُمدّ بالعمليّة الجديدة
/// وحدها، فالرسمُ الجاري لا يعيد رسمَ ما قبله. وكلُّ طبقةٍ تُركَّب بشفافيتها في
/// `saveLayer` خاصٍّ بها: الممحاةُ تمحو طبقتَها وحدها، والورقُ تحتها باقٍ.

/// ضلعُ اللوحة بوحداتها: مربّعٌ يُكبَّر أو يُصغَّر على أيّ شاشة.
const double studioSize = 1000;

/// الفرش: قلمُ حبرٍ يرقّ بالسرعة، وقلمُ رصاص، وقلمُ تحبيرٍ مدبّبُ الطرفين،
/// وفرشاةٌ زيتية بشعيراتها، وألوانٌ مائية، وبخّاخ، وقلمُ تحديد، وممحاة.
enum StudioBrush { inkPen, pencil, inking, sketch, oil, watercolor, airbrush, marker, eraser }

/// الأشكالُ الحرّة: تُسحب من زاويةٍ إلى زاوية.
enum StudioShape { line, rectangle, ellipse, triangle, star, hexagon, arrow }

enum StudioOpKind { stroke, shape, gradient }

/// عمليّةٌ واحدة على طبقة.
class StudioOp {
  StudioOp({
    required this.kind,
    required this.points,
    required this.color,
    this.color2 = const Color(0x00FFFFFF),
    this.size = 8,
    this.opacity = 1,
    this.brush = StudioBrush.inkPen,
    this.shape = StudioShape.line,
    this.filled = false,
    this.radial = false,
  });

  final StudioOpKind kind;

  /// الخطّ: نقاطُه. الشكلُ والتدرّج: نقطتان — البدايةُ والنهاية.
  final List<Offset> points;
  final Color color;

  /// اللونُ الثاني للتدرّج.
  final Color color2;
  final double size;
  final double opacity;
  final StudioBrush brush;
  final StudioShape shape;
  final bool filled;
  final bool radial;

  StudioOp frozen() => StudioOp(
        kind: kind,
        points: List.unmodifiable(points),
        color: color,
        color2: color2,
        size: size,
        opacity: opacity,
        brush: brush,
        shape: shape,
        filled: filled,
        radial: radial,
      );

  Map<String, Object?> toJson() => {
        'k': kind.name,
        // ‏أنصافُ الوحدة أعداداً صحيحة.
        'p': [for (final p in points) ...[(p.dx * 2).round(), (p.dy * 2).round()]],
        'c': color.toARGB32(),
        if (kind == StudioOpKind.gradient) 'c2': color2.toARGB32(),
        's': double.parse(size.toStringAsFixed(1)),
        if (opacity < 1) 'o': double.parse(opacity.toStringAsFixed(2)),
        if (kind == StudioOpKind.stroke) 'b': brush.name,
        if (kind == StudioOpKind.shape) 'g': shape.name,
        if (filled) 'f': 1,
        if (radial) 'r': 1,
      };

  static StudioOp? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = StudioOpKind.values.where((k) => k.name == json['k']).firstOrNull;
    final raw = json['p'];
    if (kind == null || raw is! List) return null;
    final points = <Offset>[];
    for (var i = 0; i + 1 < raw.length; i += 2) {
      final x = raw[i], y = raw[i + 1];
      if (x is num && y is num) points.add(Offset(x / 2, y / 2));
    }
    if (points.isEmpty) return null;
    final c = json['c'], c2 = json['c2'];
    return StudioOp(
      kind: kind,
      points: List.unmodifiable(points),
      color: Color(c is int ? c : 0xFF000000),
      color2: Color(c2 is int ? c2 : 0x00FFFFFF),
      size: (json['s'] as num?)?.toDouble() ?? 8,
      opacity: ((json['o'] as num?)?.toDouble() ?? 1).clamp(0.02, 1.0),
      brush: StudioBrush.values.where((b) => b.name == json['b']).firstOrNull ?? StudioBrush.inkPen,
      shape: StudioShape.values.where((s) => s.name == json['g']).firstOrNull ?? StudioShape.line,
      filled: json['f'] == 1,
      radial: json['r'] == 1,
    );
  }
}

/// طبقة: اسمُها، وشفافيتُها، وظهورُها، وعمليّاتُها.
@immutable
class StudioLayer {
  const StudioLayer({
    required this.id,
    required this.name,
    this.opacity = 1,
    this.visible = true,
    this.ops = const [],
  });

  final int id;
  final String name;
  final double opacity;
  final bool visible;
  final List<StudioOp> ops;

  StudioLayer copyWith({String? name, double? opacity, bool? visible, List<StudioOp>? ops}) => StudioLayer(
        id: id,
        name: name ?? this.name,
        opacity: opacity ?? this.opacity,
        visible: visible ?? this.visible,
        ops: ops ?? this.ops,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'n': name,
        if (opacity < 1) 'o': double.parse(opacity.toStringAsFixed(2)),
        if (!visible) 'h': 1,
        'ops': [for (final op in ops) op.toJson()],
      };

  static StudioLayer? fromJson(Object? json) {
    if (json is! Map) return null;
    final raw = json['ops'];
    return StudioLayer(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['n'] is String ? json['n'] as String : '',
      opacity: ((json['o'] as num?)?.toDouble() ?? 1).clamp(0.0, 1.0),
      visible: json['h'] != 1,
      ops: List.unmodifiable([
        if (raw is List)
          for (final item in raw)
            if (StudioOp.fromJson(item) case final op?) op,
      ]),
    );
  }
}

/// ما بيد الرسّام الآن: الأداةُ وإعداداتُها.
class StudioPen {
  const StudioPen({
    this.brush = StudioBrush.inkPen,
    this.color = const Color(0xFF111827),
    this.color2 = const Color(0xFFFFFFFF),
    this.size = 8,
    this.opacity = 1,
    this.shape,
    this.filled = false,
    this.gradient = false,
    this.radial = false,
    this.ruler = false,
  });

  final StudioBrush brush;
  final Color color;
  final Color color2;
  final double size;
  final double opacity;

  /// شكلٌ يُسحب بدل الفرشاة.
  final StudioShape? shape;
  final bool filled;

  /// أداةُ التدرّج: تُسحب من نقطةٍ إلى نقطة فتُلوَّن الطبقةُ كلُّها.
  final bool gradient;
  final bool radial;

  /// المسطرة: الخطُّ مستقيمٌ من أوّل لمسةٍ إلى الإصبع، بزوايا كلَّ ١٥°.
  final bool ruler;
}

typedef _Snapshot = ({List<StudioLayer> layers, int active});

/// اللوحةُ وطبقاتُها، مع التراجع والإعادة.
class StudioController extends ChangeNotifier {
  StudioController({String? id, List<StudioLayer>? layers, int active = 0})
      : id = id ?? 'studio:${DateTime.now().millisecondsSinceEpoch}',
        _layers = layers == null || layers.isEmpty
            ? [const StudioLayer(id: 1, name: '1')]
            : List.of(layers),
        _active = 0 {
    _active = active.clamp(0, _layers.length - 1);
  }

  final String id;
  List<StudioLayer> _layers;
  int _active;
  StudioOp? _live;
  final List<_Snapshot> _history = [];
  final List<_Snapshot> _future = [];

  static const maxLayers = 8;
  static const maxUndo = 80;

  List<StudioLayer> get layers => List.unmodifiable(_layers);
  int get active => _active;
  StudioLayer get activeLayer => _layers[_active];
  StudioOp? get liveOp => _live;
  bool get canUndo => _history.isNotEmpty;
  bool get canRedo => _future.isNotEmpty;
  bool get isEmpty => _layers.every((l) => l.ops.isEmpty);

  _Snapshot get _now => (layers: List.of(_layers), active: _active);

  void _remember() {
    _history.add(_now);
    if (_history.length > maxUndo) _history.removeAt(0);
    _future.clear();
  }

  void _restore(_Snapshot s) {
    _layers = List.of(s.layers);
    _active = s.active.clamp(0, _layers.length - 1);
    _live = null;
    notifyListeners();
  }

  void undo() {
    if (_history.isEmpty) return;
    _future.add(_now);
    _restore(_history.removeLast());
  }

  void redo() {
    if (_future.isEmpty) return;
    _history.add(_now);
    _restore(_future.removeLast());
  }

  // ── الرسم ──

  void begin(Offset p, StudioPen pen) {
    final kind = pen.gradient
        ? StudioOpKind.gradient
        : pen.shape != null
            ? StudioOpKind.shape
            : StudioOpKind.stroke;
    _live = StudioOp(
      kind: kind,
      points: [p],
      color: pen.color,
      color2: pen.color2,
      size: pen.size,
      opacity: pen.opacity,
      brush: pen.brush,
      shape: pen.shape ?? StudioShape.line,
      filled: pen.filled,
      radial: pen.radial,
    );
    _ruler = pen.ruler;
    notifyListeners();
  }

  bool _ruler = false;

  /// زاويةٌ مقرّبةٌ إلى أقرب ١٥° من [from]، بالطول نفسه.
  static Offset snapAngle(Offset from, Offset to) {
    final d = to - from;
    if (d.distance < 0.001) return to;
    const step = math.pi / 12;
    final angle = (d.direction / step).round() * step;
    return from + Offset.fromDirection(angle, d.distance);
  }

  void move(Offset p) {
    final live = _live;
    if (live == null) return;
    final points = live.points;
    if (live.kind != StudioOpKind.stroke || _ruler) {
      final end = live.kind == StudioOpKind.stroke ? snapAngle(points.first, p) : p;
      if (points.length < 2) {
        points.add(end);
      } else {
        points[1] = end;
      }
    } else {
      if ((points.last - p).distance < 0.8) return;
      points.add(p);
    }
    notifyListeners();
  }

  /// يُلغي الخطَّ الجاري بلا أثر: لمسةُ إصبعٍ ثانٍ، أو ضغطةٌ مطوّلة للقطّارة.
  void cancel() {
    if (_live == null) return;
    _live = null;
    notifyListeners();
  }

  void end() {
    final live = _live;
    _live = null;
    if (live == null) return;
    final pointsNeeded = live.kind == StudioOpKind.stroke ? 1 : 2;
    if (live.points.length < pointsNeeded ||
        (live.kind != StudioOpKind.stroke && (live.points[1] - live.points[0]).distance < 2)) {
      notifyListeners();
      return;
    }
    _remember();
    final layer = activeLayer;
    final op = live.frozen();
    final next = layer.copyWith(ops: List.unmodifiable([...layer.ops, op]));
    _extendPicture(layer, next, op);
    _layers[_active] = next;
    notifyListeners();
  }

  // ── الطبقات ──

  void selectLayer(int index) {
    if (index < 0 || index >= _layers.length || index == _active) return;
    _active = index;
    notifyListeners();
  }

  bool addLayer() {
    if (_layers.length >= maxLayers) return false;
    _remember();
    final id = _layers.map((l) => l.id).fold(0, math.max) + 1;
    _layers.insert(_active + 1, StudioLayer(id: id, name: '$id'));
    _active++;
    notifyListeners();
    return true;
  }

  void duplicateLayer() {
    if (_layers.length >= maxLayers) return;
    _remember();
    final id = _layers.map((l) => l.id).fold(0, math.max) + 1;
    final source = activeLayer;
    _layers.insert(_active + 1, StudioLayer(id: id, name: '${source.name}+', opacity: source.opacity, ops: source.ops));
    _active++;
    notifyListeners();
  }

  void removeLayer() {
    if (_layers.length <= 1) {
      clearLayer();
      return;
    }
    _remember();
    _layers.removeAt(_active);
    _active = _active.clamp(0, _layers.length - 1);
    notifyListeners();
  }

  /// يرفع الطبقةَ النشطة فوق ما فوقها ([delta] = 1) أو تحت ما تحتها (-1).
  void moveLayer(int delta) {
    final to = _active + delta;
    if (to < 0 || to >= _layers.length) return;
    _remember();
    final layer = _layers.removeAt(_active);
    _layers.insert(to, layer);
    _active = to;
    notifyListeners();
  }

  void clearLayer() {
    if (activeLayer.ops.isEmpty) return;
    _remember();
    _layers[_active] = activeLayer.copyWith(ops: const []);
    notifyListeners();
  }

  void toggleVisible(int index) {
    _remember();
    _layers[index] = _layers[index].copyWith(visible: !_layers[index].visible);
    notifyListeners();
  }

  /// يبدأ تغييرُ الشفافية بالمنزلق: خطوةُ تراجعٍ واحدة له كلِّه.
  void beginOpacityChange() => _remember();

  void setOpacity(int index, double value) {
    _layers[index] = _layers[index].copyWith(opacity: value.clamp(0.0, 1.0));
    notifyListeners();
  }

  // ── الصور المسجّلة لكل طبقة ──

  static final Expando<ui.Picture> _pictures = Expando('studio-layer-picture');

  static ui.Picture pictureOf(StudioLayer layer) {
    final cached = _pictures[layer];
    if (cached != null) return cached;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (final op in layer.ops) {
      paintOp(canvas, op);
    }
    return _pictures[layer] = recorder.endRecording();
  }

  /// صورةُ [next] من صورة [previous] والعمليّة الجديدة وحدها.
  static void _extendPicture(StudioLayer previous, StudioLayer next, StudioOp op) {
    final old = _pictures[previous];
    if (old == null) return;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawPicture(old);
    paintOp(canvas, op);
    _pictures[next] = recorder.endRecording();
  }

  /// يرسم اللوحةَ كلَّها بوحداتها على ورقٍ أبيض.
  void paintDocument(Canvas canvas) {
    const bounds = Rect.fromLTWH(0, 0, studioSize, studioSize);
    canvas.drawRect(bounds, Paint()..color = const Color(0xFFFFFFFF));
    for (var i = 0; i < _layers.length; i++) {
      final layer = _layers[i];
      if (!layer.visible || layer.opacity <= 0) continue;
      canvas.saveLayer(bounds, Paint()..color = Color.fromRGBO(0, 0, 0, layer.opacity));
      canvas.drawPicture(pictureOf(layer));
      if (i == _active && _live != null) paintOp(canvas, _live!);
      canvas.restore();
    }
  }

  // ── رسمُ العمليّات ──

  static Path smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) return path..lineTo(points.first.dx + 0.01, points.first.dy);
    for (var i = 1; i < points.length - 1; i++) {
      final mid = Offset.lerp(points[i], points[i + 1], 0.5)!;
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    return path..lineTo(points.last.dx, points.last.dy);
  }

  static Iterable<Offset> _along(List<Offset> points, double gap) sync* {
    yield points.first;
    var carry = 0.0;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final length = (b - a).distance;
      var t = gap - carry;
      while (t <= length) {
        yield Offset.lerp(a, b, t / length)!;
        t += gap;
      }
      carry = length - (t - gap);
    }
  }

  static Paint _line(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true
    ..color = c;

  static void paintOp(Canvas canvas, StudioOp op) {
    switch (op.kind) {
      case StudioOpKind.stroke:
        _paintStroke(canvas, op);
      case StudioOpKind.shape:
        _paintShape(canvas, op);
      case StudioOpKind.gradient:
        _paintGradient(canvas, op);
    }
  }

  static void _paintStroke(Canvas canvas, StudioOp op) {
    final points = op.points;
    final w = op.size;
    if (op.brush == StudioBrush.eraser) {
      canvas.drawPath(
        smoothPath(points),
        _line(Color.fromRGBO(0, 0, 0, op.opacity), w)..blendMode = BlendMode.dstOut,
      );
      return;
    }
    // ‏الشفافيةُ للخطّ كلِّه لا لكل قطعة: ما يتراكب منه لا يغمق.
    final layered = op.opacity < 1 && op.brush != StudioBrush.airbrush;
    if (layered) canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, op.opacity));
    final color = layered ? op.color : op.color.withValues(alpha: op.color.a * op.opacity);
    switch (op.brush) {
      case StudioBrush.inkPen:
        // ‏يرقّ بسرعة اليد ويغلظ ببطئها، كالريشة على الورق.
        if (points.length < 3) {
          canvas.drawPath(smoothPath(points), _line(color, w));
          break;
        }
        var width = w;
        for (var i = 1; i < points.length; i++) {
          final speed = (points[i] - points[i - 1]).distance;
          final target = w * (0.35 + 0.65 * math.exp(-speed / 14));
          width = width * 0.6 + target * 0.4;
          canvas.drawLine(points[i - 1], points[i], _line(color, width));
        }
      case StudioBrush.pencil:
        final path = smoothPath(points);
        canvas.drawPath(path, _line(color.withValues(alpha: color.a * 0.75), math.max(1, w * 0.5)));
        canvas.drawPath(path.shift(const Offset(0.5, 0.4)), _line(color.withValues(alpha: color.a * 0.35), math.max(0.8, w * 0.35)));
      case StudioBrush.inking:
        // ‏مدبّبُ الطرفين: يبدأ رفيعاً ويغلظ ثم يرقّ في آخره.
        final n = points.length;
        if (n < 3) {
          canvas.drawPath(smoothPath(points), _line(color, w * 0.6));
          break;
        }
        final taper = math.min(10, n ~/ 2);
        for (var i = 1; i < n; i++) {
          final edge = math.min(i, n - 1 - i);
          final f = edge >= taper ? 1.0 : 0.2 + 0.8 * edge / taper;
          canvas.drawLine(points[i - 1], points[i], _line(color, w * f)..strokeCap = StrokeCap.round);
        }
      case StudioBrush.oil:
        // ‏شعيراتٌ متجاورة بدرجاتٍ متفاوتة فوق طبقةٍ أساس: ملمسُ الفرشاة الزيتية.
        final path = smoothPath(points);
        canvas.drawPath(path, _line(color.withValues(alpha: color.a * 0.85), w));
        final hsl = HSLColor.fromColor(color);
        for (var k = 0; k < 7; k++) {
          final offset = (k - 3) * w * 0.13;
          final shade = hsl.withLightness((hsl.lightness + ((k * 37) % 7 - 3) * 0.035).clamp(0.0, 1.0)).toColor();
          canvas.drawPath(path.shift(Offset(offset * 0.7, offset)), _line(shade.withValues(alpha: color.a * 0.6), w * 0.16));
        }
      case StudioBrush.watercolor:
        // ‏غسلةٌ ناعمةُ الحوافّ لا تغمق على نفسها، وحافّةٌ أدكن قليلاً كما تجفّ الألوانُ المائية.
        final path = smoothPath(points);
        canvas.saveLayer(null, Paint()..color = const Color.fromRGBO(0, 0, 0, 0.45));
        canvas.drawPath(path, _line(color, w * 1.3)..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.22));
        canvas.drawPath(path, _line(color, w * 0.55)..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.1));
        canvas.restore();
      case StudioBrush.airbrush:
        // ‏رذاذٌ ناعم يتراكم كلّما مرّت اليدُ عليه.
        final dot = Paint()
          ..color = color.withValues(alpha: (0.05 + 0.12 * op.opacity).clamp(0.0, 1.0))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.45);
        for (final p in _along(points, math.max(1.5, w * 0.22))) {
          canvas.drawCircle(p, w * 0.7, dot);
        }
      case StudioBrush.sketch:
        // ‏قلمُ التخطيط: خطوطٌ رفيعةٌ متقاربةٌ خفيفة، كمن يرسم الهيكلَ قبل التحبير.
        final path = smoothPath(points);
        for (var k = 0; k < 3; k++) {
          final j = (k - 1) * math.max(0.6, w * 0.18).toDouble();
          canvas.drawPath(
            path.shift(Offset(j, -j * 0.6)),
            _line(color.withValues(alpha: color.a * 0.45), math.max(0.8, w * 0.3)),
          );
        }
      case StudioBrush.marker:
        canvas.drawPath(
          smoothPath(points),
          _line(color.withValues(alpha: color.a * 0.55), w * 1.4)..strokeCap = StrokeCap.square,
        );
      case StudioBrush.eraser:
        break;
    }
    if (layered) canvas.restore();
  }

  static Path shapePath(StudioShape shape, Offset a, Offset b) {
    final rect = Rect.fromPoints(a, b);
    final c = rect.center;
    switch (shape) {
      case StudioShape.line:
        return Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy);
      case StudioShape.rectangle:
        return Path()..addRect(rect);
      case StudioShape.ellipse:
        return Path()..addOval(rect);
      case StudioShape.triangle:
        return Path()
          ..moveTo(c.dx, rect.top)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..close();
      case StudioShape.star:
      case StudioShape.hexagon:
        final star = shape == StudioShape.star;
        final count = star ? 10 : 6;
        final path = Path();
        for (var i = 0; i < count; i++) {
          final r = star && i.isOdd ? 0.42 : 1.0;
          final angle = -math.pi / 2 + i * 2 * math.pi / count;
          final p = Offset(c.dx + math.cos(angle) * rect.width / 2 * r, c.dy + math.sin(angle) * rect.height / 2 * r);
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        return path..close();
      case StudioShape.arrow:
        final d = b - a;
        final head = math.min(d.distance * 0.35, 60.0);
        final back = d.direction + math.pi;
        final p1 = b + Offset.fromDirection(back - 0.5, head);
        final p2 = b + Offset.fromDirection(back + 0.5, head);
        return Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..moveTo(p1.dx, p1.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(p2.dx, p2.dy);
    }
  }

  static void _paintShape(Canvas canvas, StudioOp op) {
    if (op.points.length < 2) return;
    final open = op.shape == StudioShape.line || op.shape == StudioShape.arrow;
    final paint = _line(op.color.withValues(alpha: op.color.a * op.opacity), op.size)
      ..style = op.filled && !open ? PaintingStyle.fill : PaintingStyle.stroke;
    canvas.drawPath(shapePath(op.shape, op.points[0], op.points[1]), paint);
  }

  static void _paintGradient(Canvas canvas, StudioOp op) {
    if (op.points.length < 2) return;
    final a = op.points[0], b = op.points[1];
    final shader = op.radial
        ? ui.Gradient.radial(a, math.max(1, (b - a).distance), [op.color, op.color2])
        : ui.Gradient.linear(a, b, [op.color, op.color2]);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, studioSize, studioSize),
      Paint()
        ..shader = shader
        ..color = Color.fromRGBO(0, 0, 0, op.opacity),
    );
  }

  // ── القطّارة والتصدير ──

  /// لونُ اللوحة المركّبة تحت [p] (بوحدات اللوحة) — للقطّارة.
  Future<Color?> sampleAt(Offset p) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..translate(-p.dx, -p.dy);
      paintDocument(canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(1, 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      picture.dispose();
      image.dispose();
      if (data == null) return null;
      return Color.fromARGB(255, data.getUint8(0), data.getUint8(1), data.getUint8(2));
    } catch (error) {
      debugPrint('[studio] sample failed: $error');
      return null;
    }
  }

  Future<Uint8List?> toPng({int size = 1200}) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(size / studioSize);
      paintDocument(canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      picture.dispose();
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (error) {
      debugPrint('[studio] export failed: $error');
      return null;
    }
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'v': 1,
        'a': _active,
        'layers': [for (final l in _layers) l.toJson()],
      };

  static StudioController? fromJson(Object? json) {
    if (json is! Map || json['id'] is! String) return null;
    final raw = json['layers'];
    final layers = <StudioLayer>[
      if (raw is List)
        for (final item in raw)
          if (StudioLayer.fromJson(item) case final layer?) layer,
    ];
    if (layers.isEmpty) return null;
    return StudioController(id: json['id'] as String, layers: layers, active: (json['a'] as num?)?.toInt() ?? 0);
  }
}

/// يرسم اللوحةَ بأيّ حجم: للّوح وللصور المصغّرة.
class StudioPainter extends CustomPainter {
  StudioPainter(this.controller) : super(repaint: controller);

  final StudioController controller;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..scale(size.shortestSide / studioSize);
    controller.paintDocument(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(StudioPainter old) => old.controller != controller;
}

/// مشاريعُ الاستوديو على الجهاز، لكل طالبٍ وحده — الأحدثُ أوّلاً.
class StudioProjects {
  static const maxProjects = 12;
  static String keyFor(String owner) => 'studio.projects.$owner';

  static Future<List<StudioController>> load(String owner) async {
    final prefs = await SharedPreferences.getInstance();
    return [
      for (final raw in prefs.getStringList(keyFor(owner)) ?? const <String>[])
        if (_decode(raw) case final c?) c,
    ];
  }

  static StudioController? _decode(String raw) {
    try {
      return StudioController.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  /// يحفظ [controller] — يحلّ محلّ نسخته السابقة بالمعرّف نفسه.
  static Future<void> save(String owner, StudioController controller) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(keyFor(owner)) ?? <String>[];
    list.removeWhere((raw) => _decode(raw)?.id == controller.id);
    list.insert(0, jsonEncode(controller.toJson()));
    await prefs.setStringList(keyFor(owner), list.take(maxProjects).toList());
  }

  static Future<void> remove(String owner, String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(keyFor(owner)) ?? <String>[];
    list.removeWhere((raw) => _decode(raw)?.id == id);
    await prefs.setStringList(keyFor(owner), list);
  }
}

/// ألوانُ الطالب المحفوظة.
class StudioColors {
  static const maxColors = 24;
  static String keyFor(String owner) => 'studio.colors.$owner';

  static Future<List<Color>> load(String owner) async {
    final prefs = await SharedPreferences.getInstance();
    return [
      for (final raw in prefs.getStringList(keyFor(owner)) ?? const <String>[])
        if (int.tryParse(raw) case final v?) Color(v),
    ];
  }

  static Future<List<Color>> add(String owner, Color color) async {
    final colors = await load(owner);
    colors
      ..removeWhere((c) => c.toARGB32() == color.toARGB32())
      ..insert(0, color);
    final kept = colors.take(maxColors).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(keyFor(owner), [for (final c in kept) '${c.toARGB32()}']);
    return kept;
  }
}
