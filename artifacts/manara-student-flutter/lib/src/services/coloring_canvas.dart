import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coloring_drawings.dart';

/// خطُّ فرشاةٍ واحد: لونُه (أو قوسُ قزحٍ إن كان `null`)، وعرضُه، ونقاطُه
/// بإحداثيّات الرسمة، والمنطقةُ التي بدأ فيها — يُقصّ عليها فلا يخرج عنها.
class ColoringStroke {
  ColoringStroke({required this.region, required this.color, required this.width, List<Offset>? points})
      : points = points ?? <Offset>[];

  final int region;

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
    return ColoringStroke(
      region: (json['r'] as num?)?.toInt() ?? -1,
      color: c is int ? Color(c) : null,
      width: (json['w'] as num?)?.toDouble() ?? 10,
      points: points,
    );
  }
}

/// حالُ لوحةٍ واحدة: ألوانُ المناطق وخطوطُ الفرشاة، مع التراجع.
///
/// ‏`-1` هي الخلفية: تُلوَّن كأيّ منطقة.
class ColoringController extends ChangeNotifier {
  ColoringController(this.drawing);

  final ColoringDrawing drawing;

  final Map<int, Color> _fills = {};
  final List<ColoringStroke> _strokes = [];
  ColoringStroke? _active;
  final List<(Map<int, Color>, List<ColoringStroke>)> _history = [];

  /// أقصى خطواتِ التراجع المحفوظة.
  static const maxUndo = 40;

  Map<int, Color> get fills => Map.unmodifiable(_fills);
  List<ColoringStroke> get strokes => List.unmodifiable(_strokes);
  ColoringStroke? get activeStroke => _active;

  bool get canUndo => _history.isNotEmpty;

  /// هل لوّن الطفلُ شيئاً بعد؟
  bool get isEmpty => _fills.isEmpty && _strokes.isEmpty;

  void _remember() {
    _history.add((Map.of(_fills), List.of(_strokes)));
    if (_history.length > maxUndo) _history.removeAt(0);
  }

  /// يملأ المنطقةَ تحت [point] بـ[color]، ويمحو خطوطَ الفرشاة فيها — دلوٌ
  /// جديدٌ يبدأ المنطقةَ من جديد. يعيد رقمَ المنطقة.
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
  void beginStroke(Offset point, {required Color? color, required double width}) {
    _active = ColoringStroke(region: drawing.regionAt(point), color: color, width: width, points: [point]);
    notifyListeners();
  }

  void extendStroke(Offset point) {
    final active = _active;
    if (active == null) return;
    // ‏نقاطٌ متلاصقة لا تزيد الخطَّ إلا ثقلاً.
    if ((active.points.last - point).distance < 1.2) return;
    active.points.add(point);
    notifyListeners();
  }

  void endStroke() {
    final active = _active;
    if (active == null) return;
    _active = null;
    _remember();
    _strokes.add(active);
    notifyListeners();
  }

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

  void clear() {
    if (isEmpty) return;
    _remember();
    _fills.clear();
    _strokes.clear();
    notifyListeners();
  }

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
          _paintStroke(canvas, s);
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

  static void _paintStroke(Canvas canvas, ColoringStroke s) {
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

  @override
  bool shouldRepaint(ColoringPainter oldDelegate) =>
      oldDelegate.controller != controller || oldDelegate.outline != outline;
}

/// «لوحاتي»: آخرُ ما حفظه الطفلُ من لوحات، على الجهاز.
class ColoringGallery {
  ColoringGallery._();

  static const _galleryKey = 'coloring.gallery.v1';
  static const _recentKey = 'coloring.recent.v1';

  /// أقصى ما يُحفظ — الأقدمُ يخرج.
  static const maxArtworks = 12;

  static Future<List<ColoringController>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_galleryKey) ?? const [];
      return [
        for (final item in raw)
          if (_decode(item) case final controller?) controller,
      ];
    } catch (error) {
      debugPrint('[coloring] gallery not loaded: $error');
      return const [];
    }
  }

  static ColoringController? _decode(String item) {
    try {
      return ColoringController.fromJson(jsonDecode(item));
    } catch (_) {
      return null;
    }
  }

  /// يحفظ [controller] في أوّل «لوحاتي». [replacing] لوحةٌ فُتحت من المعرض
  /// فعُدّلت: تحلّ النسخةُ الجديدة محلّها لا بجانبها.
  static Future<bool> save(ColoringController controller, {int? replacing}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = List.of(prefs.getStringList(_galleryKey) ?? const <String>[]);
      if (replacing != null && replacing >= 0 && replacing < list.length) list.removeAt(replacing);
      list.insert(0, jsonEncode(controller.toJson()));
      while (list.length > maxArtworks) {
        list.removeLast();
      }
      return prefs.setStringList(_galleryKey, list);
    } catch (error) {
      debugPrint('[coloring] artwork not saved: $error');
      return false;
    }
  }

  /// يمحو اللوحةَ ذات الموضع [index] من «لوحاتي» على الجهاز نهائياً.
  static Future<bool> delete(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = List.of(prefs.getStringList(_galleryKey) ?? const <String>[]);
      if (index < 0 || index >= list.length) return false;
      list.removeAt(index);
      return prefs.setStringList(_galleryKey, list);
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
