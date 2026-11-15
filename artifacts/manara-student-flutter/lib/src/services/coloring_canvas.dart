import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coloring_drawings.dart';
import 'free_drawing.dart';

/// لوحةٌ في «لوحاتي»: تلوينٌ جاهز ([ColoringController]) أو رسمٌ حرّ
/// ([FreeDrawingController]). ما يحتاجه المعرضُ والدردشةُ ولوحُ الرسم منهما
/// واحد: الأدواتُ نفسُها، والحفظُ، والصورةُ المصغّرة، وصورةُ PNG للإرسال.
abstract class ColoringArtwork extends ChangeNotifier {
  /// يُحفظ مع اللوحة: اسمُ الرسمة، أو `free:<وقت>` للرسم الحرّ.
  String get artworkId;

  /// اسمُ اللوحة كما يُعرض.
  String title({required bool arabic});

  bool get isEmpty;
  bool get canUndo;

  /// الدلو تحت [point] (بإحداثيّات اللوحة).
  void fillAt(Offset point, Color color);
  void beginStroke(
    Offset point, {
    required Color? color,
    required double width,
    BrushStyle brush = BrushStyle.pen,
    ShapeKind? shape,
    bool filled = false,
  });
  void extendStroke(Offset point);
  void endStroke();

  /// الممحاةُ الذكية: تمحو لونَ ما تحت [point] كلَّه بلمسة — منطقةً في الرسمة
  /// الجاهزة، أو ما أغلقته الخطوطُ في الرسم الحرّ — وتُبقي الخطوط.
  void eraseAt(Offset point);
  void undo();
  void clear();

  Map<String, Object?> toJson();

  /// رسّامُ اللوحة بأيّ حجم — للّوح وللصور المصغّرة.
  CustomPainter painter({double outline = 3.2});

  /// صورةُ PNG مربّعةٌ بضلع [size] — لتُرسل في الدردشة أو تُحفظ في الاستوديو.
  Future<Uint8List?> toPng({int size = 600});

  /// يعيد لوحةً محفوظةً بنوعها؛ `null` إن لم تُعرف.
  static ColoringArtwork? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String) return null;
    if (id.startsWith(FreeDrawingController.idPrefix)) return FreeDrawingController.fromJson(json);
    return ColoringController.fromJson(json);
  }
}

/// أنواعُ الفرشاة: قلمٌ ناعم، وقلمُ تحديدٍ شفّاف، وطباشير، وبخّاخ، ونيون
/// متوهّج، ونقاط، وخطُّ الريشة العريضة.
enum BrushStyle { pen, marker, crayon, spray, neon, dotted, calligraphy }

/// الأشكالُ الهندسية: تُسحب من نقطةٍ إلى نقطة.
enum ShapeKind { line, rectangle, circle, triangle, star, heart }

/// خطُّ فرشاةٍ واحد: لونُه (أو قوسُ قزحٍ إن كان `null`)، وعرضُه، ونقاطُه
/// بإحداثيّات الرسمة، والمنطقةُ التي بدأ فيها — يُقصّ عليها فلا يخرج عنها.
class ColoringStroke {
  ColoringStroke({
    required this.region,
    required this.color,
    required this.width,
    List<Offset>? points,
    this.brush = BrushStyle.pen,
    this.shape,
    this.filled = false,
  }) : points = points ?? <Offset>[];

  final int region;

  final BrushStyle brush;

  /// شكلٌ هندسيّ: نقطتان فقط — البدايةُ وموضعُ الإصبع الآن.
  final ShapeKind? shape;

  /// الشكلُ مملوءٌ بلونه لا حدٌّ فقط.
  final bool filled;

  /// يمدّ الخطَّ إلى [point] — أو يحرّك زاويةَ الشكل إليها.
  void extend(Offset point) {
    if (shape != null) {
      if (points.length < 2) {
        points.add(point);
      } else {
        points[1] = point;
      }
      return;
    }
    // ‏نقاطٌ متلاصقة لا تزيد الخطَّ إلا ثقلاً.
    if ((points.last - point).distance < 1.2) return;
    points.add(point);
  }

  /// `null`: فرشاةُ قوس قزح — يتبدّل لونُها على طول الخطّ.
  final Color? color;
  final double width;
  final List<Offset> points;

  Map<String, Object?> toJson() => {
        'r': region,
        'c': color?.toARGB32(),
        'w': width,
        // ‏أرباعُ الوحدة أعداداً صحيحة: دقّةٌ تكفي العين وتُصغّر المحفوظ.
        'p': [for (final p in points) ...[(p.dx * 4).round(), (p.dy * 4).round()]],
        if (brush != BrushStyle.pen) 'b': brush.name,
        if (shape != null) 'g': shape!.name,
        if (filled) 'fl': 1,
      };

  static ColoringStroke? fromJson(Object? json) {
    if (json is! Map) return null;
    final raw = json['p'];
    if (raw is! List) return null;
    final points = <Offset>[];
    for (var i = 0; i + 1 < raw.length; i += 2) {
      final x = raw[i];
      final y = raw[i + 1];
      if (x is num && y is num) points.add(Offset(x / 4, y / 4));
    }
    final c = json['c'];
    final b = json['b'];
    final g = json['g'];
    return ColoringStroke(
      region: (json['r'] as num?)?.toInt() ?? -1,
      color: c is int ? Color(c) : null,
      width: (json['w'] as num?)?.toDouble() ?? 10,
      points: points,
      brush: BrushStyle.values.firstWhere((v) => v.name == b, orElse: () => BrushStyle.pen),
      shape: g is String ? ShapeKind.values.where((v) => v.name == g).firstOrNull : null,
      filled: json['fl'] == 1,
    );
  }
}

/// حالُ لوحةٍ واحدة: ألوانُ المناطق وخطوطُ الفرشاة، مع التراجع.
///
/// ‏`-1` هي الخلفية: تُلوَّن كأيّ منطقة.
class ColoringController extends ColoringArtwork {
  ColoringController(this.drawing);

  final ColoringDrawing drawing;

  @override
  String get artworkId => drawing.id;

  @override
  String title({required bool arabic}) => arabic ? drawing.titleAr : drawing.titleEn;

  @override
  CustomPainter painter({double outline = 3.2}) => ColoringPainter(this, outline: outline);

  @override
  Future<Uint8List?> toPng({int size = 600}) => renderColoringPng(this, size: size);

  final Map<int, Color> _fills = {};
  final List<ColoringStroke> _strokes = [];
  ColoringStroke? _active;
  final List<(Map<int, Color>, List<ColoringStroke>)> _history = [];

  /// أقصى خطواتِ التراجع المحفوظة.
  static const maxUndo = 40;

  Map<int, Color> get fills => Map.unmodifiable(_fills);
  List<ColoringStroke> get strokes => List.unmodifiable(_strokes);
  ColoringStroke? get activeStroke => _active;

  @override
  bool get canUndo => _history.isNotEmpty;

  /// هل لوّن الطفلُ شيئاً بعد؟
  @override
  bool get isEmpty => _fills.isEmpty && _strokes.isEmpty;

  void _remember() {
    _history.add((Map.of(_fills), List.of(_strokes)));
    if (_history.length > maxUndo) _history.removeAt(0);
  }

  /// يملأ المنطقةَ تحت [point] بـ[color]، ويمحو خطوطَ الفرشاة فيها — دلوٌ
  /// جديدٌ يبدأ المنطقةَ من جديد. يعيد رقمَ المنطقة.
  @override
  int fillAt(Offset point, Color color) {
    final region = drawing.regionAt(point);
    final hadStrokes = _strokes.any((s) => s.region == region);
    if (_fills[region] == color && !hadStrokes) return region;
    _remember();
    _fills[region] = color;
    _strokes.removeWhere((s) => s.region == region);
    notifyListeners();
    return region;
  }

  /// يبدأ خطَّ فرشاةٍ في المنطقة التي تحت [point].
  @override
  void beginStroke(
    Offset point, {
    required Color? color,
    required double width,
    BrushStyle brush = BrushStyle.pen,
    ShapeKind? shape,
    bool filled = false,
  }) {
    _active = ColoringStroke(
      region: drawing.regionAt(point),
      color: color,
      width: width,
      points: [point],
      brush: brush,
      shape: shape,
      filled: filled,
    );
    notifyListeners();
  }

  @override
  void extendStroke(Offset point) {
    final active = _active;
    if (active == null) return;
    active.extend(point);
    notifyListeners();
  }

  /// يعيد المنطقةَ تحت [point] بيضاء: يمحو لونَها وخطوطَها.
  @override
  void eraseAt(Offset point) {
    final region = drawing.regionAt(point);
    final hasColor = _fills.containsKey(region) || _strokes.any((s) => s.region == region);
    if (!hasColor) return;
    _remember();
    _fills.remove(region);
    _strokes.removeWhere((s) => s.region == region);
    notifyListeners();
  }

  @override
  void endStroke() {
    final active = _active;
    if (active == null) return;
    _active = null;
    _remember();
    _strokes.add(active);
    notifyListeners();
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final (fills, strokes) = _history.removeLast();
    _fills
      ..clear()
      ..addAll(fills);
    _strokes
      ..clear()
      ..addAll(strokes);
    _active = null;
    notifyListeners();
  }

  @override
  void clear() {
    if (isEmpty) return;
    _remember();
    _fills.clear();
    _strokes.clear();
    notifyListeners();
  }

  @override
  Map<String, Object?> toJson() => {
        'id': drawing.id,
        'f': {for (final e in _fills.entries) '${e.key}': e.value.toARGB32()},
        's': [for (final s in _strokes) s.toJson()],
      };

  /// يعيد لوحةً محفوظة كما كانت؛ `null` إن لم تُعرف رسمتُها.
  static ColoringController? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String) return null;
    final drawing = coloringDrawingById(id);
    if (drawing == null) return null;
    final controller = ColoringController(drawing);
    final fills = json['f'];
    if (fills is Map) {
      for (final e in fills.entries) {
        final region = int.tryParse('${e.key}');
        if (region != null && e.value is int) controller._fills[region] = Color(e.value as int);
      }
    }
    final strokes = json['s'];
    if (strokes is List) {
      for (final s in strokes) {
        final stroke = ColoringStroke.fromJson(s);
        if (stroke != null && stroke.points.isNotEmpty) controller._strokes.add(stroke);
      }
    }
    return controller;
  }
}

/// يرسم اللوحة: لكل منطقةٍ من الخلف إلى الأمام لونُها، ثم خطوطُ الفرشاة فيها
/// مقصوصةً عليها، ثم حدُّها — فما فوقها يغطّي حدودَ ما تحته كما في رسمٍ حقيقيّ.
class ColoringPainter extends CustomPainter {
  ColoringPainter(this.controller, {this.outline = 3.2}) : super(repaint: controller);

  final ColoringController controller;

  /// سُمكُ الخطّ الأسود بوحدات الرسمة.
  final double outline;

  static const ink = Color(0xFF2B2B3A);
  static const paper = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final drawing = controller.drawing;
    final scale = size.shortestSide / coloringCanvasSize;
    canvas
      ..save()
      ..scale(scale);
    final fills = controller.fills;
    final byRegion = <int, List<ColoringStroke>>{};
    for (final s in controller.strokes) {
      (byRegion[s.region] ??= []).add(s);
    }
    final active = controller.activeStroke;
    if (active != null) (byRegion[active.region] ??= []).add(active);

    final fillPaint = Paint()..isAntiAlias = true;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = outline
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = ink;

    const bounds = Rect.fromLTWH(0, 0, coloringCanvasSize, coloringCanvasSize);
    for (var i = -1; i < drawing.regions.length; i++) {
      final region = i < 0 ? (Path()..addRect(bounds)) : drawing.regions[i];
      canvas.drawPath(region, fillPaint..color = fills[i] ?? paper);
      final strokes = byRegion[i];
      if (strokes != null) {
        canvas
          ..save()
          ..clipPath(region);
        for (final s in strokes) {
          paintStroke(canvas, s);
        }
        canvas.restore();
      }
      if (i >= 0) canvas.drawPath(region, edge);
    }
    final detail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = outline * 0.85
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = ink;
    for (final d in drawing.details) {
      canvas.drawPath(d, detail);
    }
    canvas.restore();
  }

  /// خطُّ فرشاةٍ واحد بنوعه: شكلٌ هندسيّ، أو فرشاةٌ بتأثيرها، أو قلمٌ ناعم.
  static void paintStroke(Canvas canvas, ColoringStroke s) {
    if (s.points.isEmpty) return;
    if (s.shape != null) {
      paintShape(canvas, s);
      return;
    }
    if (s.color != null && s.brush != BrushStyle.pen) {
      paintBrush(canvas, s, s.color!);
      return;
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final points = s.points;
    if (points.length == 1) {
      canvas.drawCircle(points.first, s.width / 2,
          Paint()..color = s.color ?? HSVColor.fromAHSV(1, 0, 0.75, 1).toColor());
      return;
    }
    final color = s.color;
    if (color == null) {
      // ‏قوسُ قزح: كلُّ قطعةٍ بلونٍ يلي ما قبله.
      for (var i = 1; i < points.length; i++) {
        paint.color = HSVColor.fromAHSV(1, (i * 7.0) % 360, 0.75, 1).toColor();
        canvas.drawLine(points[i - 1], points[i], paint);
      }
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length - 1; i++) {
      final mid = Offset.lerp(points[i], points[i + 1], 0.5)!;
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(path, paint..color = color);
  }

  static Path _smooth(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) {
      path.lineTo(points.first.dx + 0.01, points.first.dy);
      return path;
    }
    for (var i = 1; i < points.length - 1; i++) {
      final mid = Offset.lerp(points[i], points[i + 1], 0.5)!;
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  /// نقاطٌ على طول الخطّ كلَّ [gap] — للنقاط والبخّاخ.
  static Iterable<Offset> _along(List<Offset> points, double gap) sync* {
    yield points.first;
    var carry = 0.0;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final length = (b - a).distance;
      var t = gap - carry;
      while (t <= length) {
        yield Offset.lerp(a, b, t / length)!;
        t += gap;
      }
      carry = length - (t - gap);
    }
  }

  /// الفرشُ ذواتُ التأثير.
  static void paintBrush(Canvas canvas, ColoringStroke s, Color color) {
    final w = s.width;
    final points = s.points;
    Paint line(Color c, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = c;
    switch (s.brush) {
      case BrushStyle.pen:
        canvas.drawPath(_smooth(points), line(color, w));
      case BrushStyle.marker:
        // ‏شفّافٌ ولا يتراكب على نفسه: مسارٌ واحد يُرسم مرّةً واحدة.
        canvas.drawPath(
          _smooth(points),
          line(color.withValues(alpha: 0.42), w * 1.6)..strokeCap = StrokeCap.square,
        );
      case BrushStyle.crayon:
        // ‏خيوطٌ متجاورة متفاوتة: ملمسُ الطباشير الملوّنة.
        final path = _smooth(points);
        for (var k = 0; k < 5; k++) {
          final dx = (k - 2) * w * 0.16;
          final dy = ((k * 37) % 5 - 2) * w * 0.12;
          canvas.drawPath(path.shift(Offset(dx, dy)), line(color.withValues(alpha: 0.38), w * 0.45));
        }
      case BrushStyle.spray:
        // ‏رذاذٌ ثابتٌ لكل خطّ: يُعاد كما هو عند فتح اللوحة.
        final dots = Paint()..color = color.withValues(alpha: 0.85);
        var seed = points.length * 7919 + (points.first.dx * 13).round();
        double next() {
          seed = (seed * 1103515245 + 12345) & 0x7fffffff;
          return seed / 0x7fffffff;
        }
        for (final p in _along(points, math.max(1.5, w * 0.35))) {
          for (var k = 0; k < 7; k++) {
            final angle = next() * math.pi * 2;
            final r = math.sqrt(next()) * w;
            canvas.drawCircle(p + Offset(math.cos(angle) * r, math.sin(angle) * r), math.max(0.5, w * 0.06), dots);
          }
        }
      case BrushStyle.neon:
        final path = _smooth(points);
        canvas.drawPath(
          path,
          line(color.withValues(alpha: 0.75), w * 1.5)..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.7),
        );
        canvas.drawPath(path, line(color, w * 0.7));
        canvas.drawPath(path, line(const Color(0xFFFFFFFF).withValues(alpha: 0.85), w * 0.25));
      case BrushStyle.dotted:
        final dot = Paint()..color = color;
        for (final p in _along(points, w * 1.9)) {
          canvas.drawCircle(p, w / 2, dot);
        }
      case BrushStyle.calligraphy:
        // ‏ريشةٌ عريضةٌ مائلة: الخطُّ يغلظ ويرقّ باتجاهه.
        final nib = Offset(math.cos(math.pi / 4), -math.sin(math.pi / 4)) * (w * 0.75);
        final fill = Paint()
          ..color = color
          ..isAntiAlias = true;
        if (points.length == 1) {
          canvas.drawLine(points.first - nib, points.first + nib, line(color, 1.5));
          return;
        }
        for (var i = 1; i < points.length; i++) {
          final a = points[i - 1];
          final b = points[i];
          canvas.drawPath(
            Path()
              ..moveTo((a - nib).dx, (a - nib).dy)
              ..lineTo((a + nib).dx, (a + nib).dy)
              ..lineTo((b + nib).dx, (b + nib).dy)
              ..lineTo((b - nib).dx, (b - nib).dy)
              ..close(),
            fill,
          );
        }
    }
  }

  /// مسارُ الشكل بين نقطتين.
  static Path shapePath(ShapeKind shape, Offset a, Offset b) {
    final rect = Rect.fromPoints(a, b);
    switch (shape) {
      case ShapeKind.line:
        return Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy);
      case ShapeKind.rectangle:
        return Path()..addRect(rect);
      case ShapeKind.circle:
        return Path()..addOval(rect);
      case ShapeKind.triangle:
        return Path()
          ..moveTo(rect.center.dx, rect.top)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..close();
      case ShapeKind.star:
        final path = Path();
        final c = rect.center;
        for (var i = 0; i < 10; i++) {
          final r = i.isEven ? 1.0 : 0.45;
          final angle = -math.pi / 2 + i * math.pi / 5;
          final p = Offset(c.dx + math.cos(angle) * rect.width / 2 * r, c.dy + math.sin(angle) * rect.height / 2 * r);
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        return path..close();
      case ShapeKind.heart:
        final w = rect.width;
        final h = rect.height;
        final l = rect.left;
        final t = rect.top;
        return Path()
          ..moveTo(l + w / 2, t + h * 0.3)
          ..cubicTo(l + w * 0.15, t - h * 0.1, l - w * 0.25, t + h * 0.45, l + w / 2, t + h)
          ..moveTo(l + w / 2, t + h * 0.3)
          ..cubicTo(l + w * 0.85, t - h * 0.1, l + w * 1.25, t + h * 0.45, l + w / 2, t + h);
    }
  }

  static void paintShape(Canvas canvas, ColoringStroke s) {
    final a = s.points.first;
    final b = s.points.length > 1 ? s.points[1] : a;
    if ((b - a).distance < 0.5) return;
    final path = shapePath(s.shape!, a, b);
    final color = s.color ?? const Color(0xFFEC4899);
    final paint = Paint()
      ..isAntiAlias = true
      ..color = color
      ..strokeWidth = s.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = s.filled && s.shape != ShapeKind.line ? PaintingStyle.fill : PaintingStyle.stroke;
    if (s.shape == ShapeKind.heart && s.filled) {
      // ‏القلبُ نصفان: يُملأ كلٌّ منهما.
      canvas.drawPath(path..fillType = PathFillType.nonZero, paint);
      final rect = Rect.fromPoints(a, b);
      canvas.drawPath(
        Path()
          ..moveTo(rect.left + rect.width / 2, rect.top + rect.height * 0.3)
          ..lineTo(rect.left + rect.width * 0.12, rect.top + rect.height * 0.42)
          ..lineTo(rect.left + rect.width / 2, rect.bottom)
          ..lineTo(rect.right - rect.width * 0.12, rect.top + rect.height * 0.42)
          ..close(),
        paint,
      );
      return;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ColoringPainter oldDelegate) =>
      oldDelegate.controller != controller || oldDelegate.outline != outline;
}

/// «لوحاتي»: آخرُ ما حفظه الطفلُ من لوحات، على الجهاز.
class ColoringGallery {
  ColoringGallery._();

  /// «لوحاتي» لكلّ طالبٍ وحده: `coloring.gallery.v2.<معرّفه>`.
  ///
  /// ── لماذا بمعرّف الطالب ──
  /// التابلتُ الواحد يتناوبه أكثرُ من طفل (سادن وجوري)، وكانت «لوحاتي» مفتاحاً
  /// واحداً للجهاز كلّه: ترى جوري لوحاتِ سادن وتحذفها. فصار لكلّ معرّفٍ مفتاحُه،
  /// ولا يُقرأ مفتاحُ غيره أبداً. والمفتاحُ القديم (`v1`) لا يُقرأ: لا يُعرف لمن
  /// كان، فلا يُنسب إلى أحد.
  static const _galleryKey = 'coloring.gallery.v2';

  @visibleForTesting
  static String keyFor(String owner) => '$_galleryKey.${owner.trim().isEmpty ? 'guest' : owner.trim()}';
  static const _recentKey = 'coloring.recent.v1';

  /// أقصى ما يُحفظ — الأقدمُ يخرج.
  static const maxArtworks = 12;

  static Future<List<ColoringArtwork>> load({required String owner}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(keyFor(owner)) ?? const [];
      return [
        for (final item in raw)
          if (_decode(item) case final controller?) controller,
      ];
    } catch (error) {
      debugPrint('[coloring] gallery not loaded: $error');
      return const [];
    }
  }

  static ColoringArtwork? _decode(String item) {
    try {
      return ColoringArtwork.fromJson(jsonDecode(item));
    } catch (_) {
      return null;
    }
  }

  /// يحفظ [controller] في أوّل «لوحاتي». [replacing] لوحةٌ فُتحت من المعرض
  /// فعُدّلت: تحلّ النسخةُ الجديدة محلّها لا بجانبها.
  static Future<bool> save(ColoringArtwork controller, {required String owner, int? replacing}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = List.of(prefs.getStringList(keyFor(owner)) ?? const <String>[]);
      if (replacing != null && replacing >= 0 && replacing < list.length) list.removeAt(replacing);
      list.insert(0, jsonEncode(controller.toJson()));
      while (list.length > maxArtworks) {
        list.removeLast();
      }
      return prefs.setStringList(keyFor(owner), list);
    } catch (error) {
      debugPrint('[coloring] artwork not saved: $error');
      return false;
    }
  }

  /// يمحو اللوحةَ ذات الموضع [index] من «لوحاتي» على الجهاز نهائياً.
  static Future<bool> delete(int index, {required String owner}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = List.of(prefs.getStringList(keyFor(owner)) ?? const <String>[]);
      if (index < 0 || index >= list.length) return false;
      list.removeAt(index);
      return prefs.setStringList(keyFor(owner), list);
    } catch (error) {
      debugPrint('[coloring] artwork not deleted: $error');
      return false;
    }
  }

  static Future<List<String>> recent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_recentKey) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// ما عُرض الآن يُضاف إلى «الأخيرة»، ولا يبقى منها إلا ما يُبقي في المجموعة
  /// ما لم يُعرض بعد.
  static Future<void> remember(List<String> shown) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final previous = prefs.getStringList(_recentKey) ?? const <String>[];
      final named = shown.where((id) => !id.contains(':'));
      final next = [...named, ...previous.where((id) => !named.contains(id))];
      final keep = handDrawnDrawings.length - 6;
      await prefs.setStringList(_recentKey, next.take(keep).toList());
    } catch (_) {}
  }
}

/// اللوحةُ صورةَ PNG مربّعةً بضلع [size] — لتُرسل في الدردشة.
///
/// تُرسم بالرسّام نفسه الذي يراه الطفل، فما يصل زميلَه هو ما لوّنه بعينه.
Future<Uint8List?> renderColoringPng(ColoringController controller, {int size = 600}) async {
  try {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    ColoringPainter(controller).paint(canvas, Size.square(size.toDouble()));
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    return data?.buffer.asUint8List();
  } catch (error) {
    debugPrint('[coloring] render failed: $error');
    return null;
  }
}
