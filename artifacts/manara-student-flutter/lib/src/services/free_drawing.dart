import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'coloring_canvas.dart';
import 'coloring_drawings.dart';

/// «الرسمُ الحرّ»: ورقةٌ بيضاء يرسم عليها الطفلُ خطوطَه بنفسه ثم يلوّنها.
///
/// ── لماذا صورةٌ نقطيّة لا مناطق ──
/// في التلوين الجاهز تُعرف المناطقُ مسبقاً، فيملؤها الدلوُ بمساراتها. أمّا هنا
/// فالمناطقُ هي ما رسمه الطفل: دائرةٌ أغلقها بإصبعه. فاللوحةُ صورةٌ بضلع
/// [rasterSize]، كلُّ خطٍّ يُرسم عليها، والدلوُ يملأ ما حول نقطة اللمس من
/// النقاط المتشابهة حتى يصطدم بخطّ — كما في أيّ برنامج رسم.
///
/// ── والحفظ ──
/// تُحفظ العملياتُ لا الصورة: خطوطٌ ونقاطُ تعبئة، بضعةُ كيلوبايتات بدل صورةٍ
/// كاملة. وتُعاد اللوحةُ بإعادة رسمها بالترتيب نفسه ([ready]).
class FreeDrawingController extends ColoringArtwork {
  FreeDrawingController({String? id}) : _id = id ?? '$idPrefix${DateTime.now().millisecondsSinceEpoch}' {
    _raster = _blank();
  }

  static const idPrefix = 'free:';

  /// ضلعُ الصورة: ضعفُ وحدات اللوحة، فتبقى الخطوطُ ناعمةً على شاشة تابلت.
  static const int rasterSize = 600;
  static const double _scale = rasterSize / coloringCanvasSize;

  /// ما يُعدّ «اللونَ نفسه» حين يملأ الدلو: مجموعُ فروق القنوات الثلاث. يعبر
  /// الحوافَّ الناعمة للخطّ ولا يعبر الخطَّ نفسه.
  static const int fillTolerance = 96;

  /// أقصى خطوات التراجع المحفوظة صوراً.
  static const maxUndo = 25;

  final String _id;
  final List<_FreeOp> _ops = [];
  late ui.Image _raster;
  ColoringStroke? _active;
  final List<(ui.Image, List<_FreeOp>)> _history = [];
  bool _busy = false;
  bool _disposed = false;
  Completer<void>? _replaying;

  /// صورةُ اللوحة الآن (بلا الخطّ الجاري).
  ui.Image get raster => _raster;
  ColoringStroke? get activeStroke => _active;

  /// تكتمل حين تُعاد لوحةٌ محفوظةٌ رسماً.
  Future<void> get ready => _replaying?.future ?? Future<void>.value();

  @override
  String get artworkId => _id;

  @override
  String title({required bool arabic}) => arabic ? 'رسمتي الحرّة' : 'My Drawing';

  @override
  bool get isEmpty => _ops.isEmpty;

  @override
  bool get canUndo => _history.isNotEmpty || _ops.isNotEmpty;

  @override
  CustomPainter painter({double outline = 3.2}) => FreeDrawingPainter(this);

  ui.Image _blank() {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 600, 600),
      Paint()..color = ColoringPainter.paper,
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(rasterSize, rasterSize);
    picture.dispose();
    return image;
  }

  void _remember() {
    _history.add((_raster.clone(), List.of(_ops)));
    while (_history.length > maxUndo) {
      _history.removeAt(0).$1.dispose();
    }
  }

  void _replaceRaster(ui.Image next) {
    final old = _raster;
    _raster = next;
    old.dispose();
  }

  /// يرسم [stroke] فوق الصورة الحالية — متزامناً.
  ui.Image _withStroke(ui.Image base, ColoringStroke stroke) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawImage(base, Offset.zero, Paint());
    canvas.scale(_scale);
    ColoringPainter.paintStroke(canvas, stroke);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(rasterSize, rasterSize);
    picture.dispose();
    return image;
  }

  @override
  void beginStroke(Offset point, {required Color? color, required double width}) {
    if (_busy) return;
    _active = ColoringStroke(region: -1, color: color, width: width, points: [point]);
    notifyListeners();
  }

  @override
  void extendStroke(Offset point) {
    final active = _active;
    if (active == null) return;
    if ((active.points.last - point).distance < 1.2) return;
    active.points.add(point);
    notifyListeners();
  }

  @override
  void endStroke() {
    final active = _active;
    if (active == null) return;
    _active = null;
    _remember();
    _replaceRaster(_withStroke(_raster, active));
    _ops.add(_FreeOp.stroke(active));
    notifyListeners();
  }

  /// الدلو: يملأ ما حول [point] حتى الخطوط. غيرُ متزامن — يقرأ نقاطَ الصورة.
  @override
  void fillAt(Offset point, Color color) {
    if (_busy) return;
    unawaited(fillAtAsync(point, color));
  }

  Future<bool> fillAtAsync(Offset point, Color color) async {
    if (_busy || _disposed) return false;
    _busy = true;
    try {
      final next = await _filled(_raster, point, color);
      if (next == null || _disposed) {
        next?.dispose();
        return false;
      }
      _remember();
      _replaceRaster(next);
      _ops.add(_FreeOp.fill(point, color));
      notifyListeners();
      return true;
    } finally {
      _busy = false;
    }
  }

  /// صورةٌ جديدةٌ بعد التعبئة، أو `null` إن كانت النقطةُ باللون نفسه.
  static Future<ui.Image?> _filled(ui.Image base, Offset point, Color color) async {
    final data = await base.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    final pixels = data.buffer.asUint8List();
    final changed = floodFill(
      pixels,
      rasterSize,
      rasterSize,
      (point.dx * _scale).floor(),
      (point.dy * _scale).floor(),
      color,
      tolerance: fillTolerance,
    );
    if (!changed) return null;
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, rasterSize, rasterSize, ui.PixelFormat.rgba8888, done.complete);
    return done.future;
  }

  @override
  void undo() {
    if (_busy) return;
    if (_history.isNotEmpty) {
      final (image, ops) = _history.removeLast();
      _replaceRaster(image);
      _ops
        ..clear()
        ..addAll(ops);
      _active = null;
      notifyListeners();
      return;
    }
    // ‏لوحةٌ أُعيدت من «لوحاتي» بلا صورٍ للتراجع: تُعاد رسماً بلا آخر خطوة.
    if (_ops.isEmpty) return;
    final keep = _ops.sublist(0, _ops.length - 1);
    unawaited(_replay(keep));
  }

  @override
  void clear() {
    if (isEmpty || _busy) return;
    _remember();
    _replaceRaster(_blank());
    _ops.clear();
    notifyListeners();
  }

  Future<void> _replay(List<_FreeOp> ops) async {
    _busy = true;
    final done = _replaying = Completer<void>();
    try {
      var image = _blank();
      for (final op in ops) {
        if (_disposed) break;
        if (op.stroke != null) {
          final next = _withStroke(image, op.stroke!);
          image.dispose();
          image = next;
        } else {
          final next = await _filled(image, op.at!, op.color!);
          if (next != null) {
            image.dispose();
            image = next;
          }
        }
      }
      if (_disposed) {
        image.dispose();
        return;
      }
      _replaceRaster(image);
      _ops
        ..clear()
        ..addAll(ops);
      notifyListeners();
    } catch (error) {
      debugPrint('[free-drawing] replay failed: $error');
    } finally {
      _busy = false;
      done.complete();
    }
  }

  @override
  Map<String, Object?> toJson() => {
        'id': _id,
        'o': [for (final op in _ops) op.toJson()],
      };

  static FreeDrawingController? fromJson(Map json) {
    final id = json['id'];
    if (id is! String || !id.startsWith(idPrefix)) return null;
    final raw = json['o'];
    final ops = <_FreeOp>[
      if (raw is List)
        for (final item in raw)
          if (_FreeOp.fromJson(item) case final op?) op,
    ];
    final controller = FreeDrawingController(id: id);
    if (ops.isNotEmpty) unawaited(controller._replay(ops));
    return controller;
  }

  @override
  Future<Uint8List?> toPng({int size = 600}) async {
    try {
      await ready;
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        _raster,
        Rect.fromLTWH(0, 0, rasterSize.toDouble(), rasterSize.toDouble()),
        Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        Paint()..filterQuality = FilterQuality.medium,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      picture.dispose();
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (error) {
      debugPrint('[free-drawing] render failed: $error');
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final (image, _) in _history) {
      image.dispose();
    }
    _history.clear();
    _raster.dispose();
    super.dispose();
  }
}

/// خطوةٌ في الرسم الحرّ: خطٌّ، أو تعبئةٌ عند نقطة.
class _FreeOp {
  _FreeOp.stroke(ColoringStroke this.stroke)
      : at = null,
        color = null;
  _FreeOp.fill(Offset this.at, Color this.color) : stroke = null;

  final ColoringStroke? stroke;
  final Offset? at;
  final Color? color;

  Map<String, Object?> toJson() => stroke != null
      ? {'t': 's', ...stroke!.toJson()}
      : {'t': 'f', 'x': (at!.dx * 4).round(), 'y': (at!.dy * 4).round(), 'c': color!.toARGB32()};

  static _FreeOp? fromJson(Object? json) {
    if (json is! Map) return null;
    if (json['t'] == 'f') {
      final x = json['x'], y = json['y'], c = json['c'];
      if (x is! num || y is! num || c is! int) return null;
      return _FreeOp.fill(Offset(x / 4, y / 4), Color(c));
    }
    final stroke = ColoringStroke.fromJson(json);
    return stroke == null || stroke.points.isEmpty ? null : _FreeOp.stroke(stroke);
  }
}

/// يملأ [pixels] (RGBA) من ([x], [y]) بـ[color]: كلُّ نقطةٍ متّصلةٍ بها وقريبةٍ
/// من لونها في حدود [tolerance]. يعيد `false` إن لم يتغيّر شيء.
///
/// بخطوط المسح (scanline): يملأ الصفَّ يميناً ويساراً ثم ينظر فوقه وتحته —
/// أسرعُ بكثيرٍ من نقطةٍ نقطة، ولا ينفد فيه المكدّسُ على لوحةٍ كبيرة.
@visibleForTesting
bool floodFill(Uint8List pixels, int width, int height, int x, int y, Color color, {int tolerance = 96}) {
  if (x < 0 || y < 0 || x >= width || y >= height) return false;
  final start = (y * width + x) * 4;
  final sr = pixels[start], sg = pixels[start + 1], sb = pixels[start + 2];
  final argb = color.toARGB32();
  final nr = (argb >> 16) & 0xFF, ng = (argb >> 8) & 0xFF, nb = argb & 0xFF;
  if ((sr - nr).abs() + (sg - ng).abs() + (sb - nb).abs() <= 6) return false;

  final visited = Uint8List(width * height);
  bool matches(int index) {
    if (visited[index] == 1) return false;
    final i = index * 4;
    return (pixels[i] - sr).abs() + (pixels[i + 1] - sg).abs() + (pixels[i + 2] - sb).abs() <= tolerance;
  }

  void paint(int index) {
    visited[index] = 1;
    final i = index * 4;
    pixels[i] = nr;
    pixels[i + 1] = ng;
    pixels[i + 2] = nb;
    pixels[i + 3] = 255;
  }

  final queue = Queue<int>()..add(y * width + x);
  while (queue.isNotEmpty) {
    final index = queue.removeFirst();
    if (!matches(index)) continue;
    final row = index ~/ width;
    var left = index % width;
    var right = left;
    while (left > 0 && matches(row * width + left - 1)) {
      left--;
    }
    while (right < width - 1 && matches(row * width + right + 1)) {
      right++;
    }
    for (var cx = left; cx <= right; cx++) {
      paint(row * width + cx);
      if (row > 0 && matches((row - 1) * width + cx)) queue.add((row - 1) * width + cx);
      if (row < height - 1 && matches((row + 1) * width + cx)) queue.add((row + 1) * width + cx);
    }
  }
  return true;
}

/// يرسم الصورةَ بحجم اللوح، والخطَّ الجاري فوقها.
class FreeDrawingPainter extends CustomPainter {
  FreeDrawingPainter(this.controller) : super(repaint: controller);

  final FreeDrawingController controller;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final raster = controller.raster;
    canvas.drawImageRect(
      raster,
      Rect.fromLTWH(0, 0, raster.width.toDouble(), raster.height.toDouble()),
      Rect.fromLTWH(0, 0, side, side),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final active = controller.activeStroke;
    if (active != null) {
      canvas
        ..save()
        ..scale(side / coloringCanvasSize);
      ColoringPainter.paintStroke(canvas, active);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(FreeDrawingPainter old) => old.controller != controller;
}
