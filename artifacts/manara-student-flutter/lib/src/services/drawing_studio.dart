import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coloring_canvas.dart';
import 'coloring_drawings.dart';

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
enum StudioBrush { inkPen, pencil, inking, sketch, calligraphy, oil, watercolor, softBrush, airbrush, crayon, neon, marker, eraser }

/// مزجُ الطبقة بما تحتها، كما في برامج الرسم: عادي، وضرب، وتفتيح، وتراكب،
/// وإضافة، وتغميق، وتفتيحُ الأفتح.
enum StudioBlend { normal, multiply, screen, overlay, add, darken, lighten }

const studioBlendModes = <StudioBlend, BlendMode>{
  StudioBlend.normal: BlendMode.srcOver,
  StudioBlend.multiply: BlendMode.multiply,
  StudioBlend.screen: BlendMode.screen,
  StudioBlend.overlay: BlendMode.overlay,
  StudioBlend.add: BlendMode.plus,
  StudioBlend.darken: BlendMode.darken,
  StudioBlend.lighten: BlendMode.lighten,
};

/// الأشكالُ الحرّة: تُسحب من زاويةٍ إلى زاوية.
enum StudioShape { line, rectangle, ellipse, triangle, star, hexagon, arrow }

/// [template]: خطوطُ قالبٍ جاهز من المكتبة. [fill]: دلوٌ يملأ منطقةً من قالب.
enum StudioOpKind { stroke, shape, gradient, template, fill }

// ── مكتبةُ القوالب ─────────────────────────────────────────────────────

/// قالبٌ في المكتبة: معرّفُ رسمته وقسمُه.
class StudioTemplate {
  const StudioTemplate(this.id, this.section);

  final String id;

  /// `characters` أو `animals` أو `things`.
  final String section;
}

/// المكتبة بأقسامها: شخصيات، وحيوانات، وأشياءُ ومشاهد.
const studioTemplates = <StudioTemplate>[
  StudioTemplate('girl', 'characters'),
  StudioTemplate('boy', 'characters'),
  StudioTemplate('anime_twintails', 'characters'),
  StudioTemplate('anime_princess', 'characters'),
  StudioTemplate('anime_bob', 'characters'),
  StudioTemplate('anime_ponytail', 'characters'),
  StudioTemplate('anime_fairy', 'characters'),
  StudioTemplate('anime_ninja', 'characters'),
  StudioTemplate('anime_cap', 'characters'),
  StudioTemplate('anime_glasses', 'characters'),
  StudioTemplate('anime_soccer', 'characters'),
  StudioTemplate('anime_wizard', 'characters'),
  StudioTemplate('hero', 'characters'),
  StudioTemplate('robot', 'characters'),
  StudioTemplate('snowman', 'characters'),
  StudioTemplate('cat', 'animals'),
  StudioTemplate('bunny', 'animals'),
  StudioTemplate('lion', 'animals'),
  StudioTemplate('dinosaur', 'animals'),
  StudioTemplate('butterfly', 'animals'),
  StudioTemplate('owl', 'animals'),
  StudioTemplate('turtle', 'animals'),
  StudioTemplate('fish', 'animals'),
  StudioTemplate('castle', 'things'),
  StudioTemplate('car', 'things'),
  StudioTemplate('rocket', 'things'),
  StudioTemplate('bouquet', 'things'),
  StudioTemplate('flower', 'things'),
  StudioTemplate('house', 'things'),
  StudioTemplate('icecream', 'things'),
  StudioTemplate('boat', 'things'),
  StudioTemplate('balloons', 'things'),
];

final Map<String, ColoringDrawing?> _templateCache = {};

/// رسمةُ القالب [id] — من المكتبة الجديدة أو من رسومات التلوين. ثابتةٌ في
/// الشيفرة، فما يرسمه الطالبُ فوقها لا يمسّها.
ColoringDrawing? studioTemplateDrawing(String? id) {
  if (id == null) return null;
  return _templateCache.putIfAbsent(id, () => (studioTemplateDrawings[id] ?? handDrawnDrawings[id])?.call());
}

/// القالبُ بوحدات الاستوديو: مربّعُ الرسمة (٣٠٠) يملأ اللوحة (١٠٠٠).
const double studioTemplateScale = studioSize / coloringCanvasSize;

final Map<String, Path> _visibleRegions = {};

/// ما يُرى من المنطقة [index] في القالب: هي ناقصاً ما فوقها من مناطق — فالدلو
/// يملأ ما تراه العينُ وحده. و`-1` الخلفيةُ: اللوحةُ ناقصاً كلَّ المناطق.
Path studioVisibleRegion(ColoringDrawing drawing, int index) =>
    _visibleRegions.putIfAbsent('${drawing.id}:$index', () {
      final above = index < 0 ? drawing.regions : drawing.regions.sublist(index + 1);
      final base = index < 0
          ? (Path()..addRect(const Rect.fromLTWH(0, 0, coloringCanvasSize, coloringCanvasSize)))
          : drawing.regions[index];
      if (above.isEmpty) return base;
      final cover = above.skip(1).fold(above.first, (a, b) => Path.combine(PathOperation.union, a, b));
      return Path.combine(PathOperation.difference, base, cover);
    });

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
    this.mirror = false,
    this.template,
    this.region = -1,
  });

  final StudioOpKind kind;

  /// القالبُ: لعمليّة [StudioOpKind.template] و[StudioOpKind.fill].
  final String? template;

  /// منطقةُ القالب التي يملؤها الدلو (`-1` الخلفية).
  final int region;

  /// مسطرةُ التماثل: يُرسم مرّةً ثانيةً معكوساً حول منتصف اللوحة.
  final bool mirror;

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
        mirror: mirror,
        template: template,
        region: region,
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
        if (mirror) 'm': 1,
        if (template != null) 't': template,
        if (kind == StudioOpKind.fill) 'ri': region,
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
      mirror: json['m'] == 1,
      template: json['t'] is String ? json['t'] as String : null,
      region: (json['ri'] as num?)?.toInt() ?? -1,
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
    this.blend = StudioBlend.normal,
    this.locked = false,
  });

  final int id;
  final String name;
  final double opacity;
  final bool visible;
  final List<StudioOp> ops;
  final StudioBlend blend;

  /// طبقةٌ مقفلة لا يُرسم عليها — تحفظ ما أُنجز من الخطأ.
  final bool locked;

  StudioLayer copyWith({
    String? name,
    double? opacity,
    bool? visible,
    List<StudioOp>? ops,
    StudioBlend? blend,
    bool? locked,
  }) =>
      StudioLayer(
        id: id,
        name: name ?? this.name,
        opacity: opacity ?? this.opacity,
        visible: visible ?? this.visible,
        ops: ops ?? this.ops,
        blend: blend ?? this.blend,
        locked: locked ?? this.locked,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'n': name,
        if (opacity < 1) 'o': double.parse(opacity.toStringAsFixed(2)),
        if (!visible) 'h': 1,
        if (blend != StudioBlend.normal) 'b': blend.name,
        if (locked) 'l': 1,
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
      blend: StudioBlend.values.where((b) => b.name == json['b']).firstOrNull ?? StudioBlend.normal,
      locked: json['l'] == 1,
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
    this.stabilizer = 0,
    this.mirror = false,
  });

  /// مثبّتُ الخطّ: من صفر (بلا تنعيم) إلى ٠٫٩ (خطٌّ ناعمٌ جدّاً يتبع اليدَ بتأنٍّ).
  final double stabilizer;

  /// مسطرةُ التماثل العمودية.
  final bool mirror;

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
      mirror: pen.mirror,
    );
    _ruler = pen.ruler;
    _stabilizer = pen.stabilizer.clamp(0.0, 0.9);
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
      // ‏المثبّت: النقطةُ الجديدة بين ما سبق وموضعِ الإصبع، فتذوب رجفةُ اليد.
      final target = _stabilizer > 0 ? Offset.lerp(p, points.last, _stabilizer)! : p;
      if ((points.last - target).distance < 0.8) return;
      points.add(target);
    }
    notifyListeners();
  }

  /// يُلغي الخطَّ الجاري بلا أثر: لمسةُ إصبعٍ ثانٍ، أو ضغطةٌ مطوّلة للقطّارة.
  void cancel() {
    if (_live == null) return;
    _live = null;
    notifyListeners();
  }

  double _stabilizer = 0;

  /// الطبقةُ النشطة مقفلة: لا يبدأ عليها رسم.
  bool get activeLocked => activeLayer.locked;

  void end() {
    final live = _live;
    _live = null;
    if (live == null) return;
    if (activeLayer.locked) {
      notifyListeners();
      return;
    }
    final pointsNeeded = live.kind == StudioOpKind.stroke ? 1 : 2;
    if (live.points.length < pointsNeeded ||
        (live.kind != StudioOpKind.stroke && (live.points[1] - live.points[0]).distance < 2)) {
      notifyListeners();
      return;
    }
    _commit(live.frozen());
  }

  void _commit(StudioOp op) {
    _remember();
    final layer = activeLayer;
    final next = layer.copyWith(ops: List.unmodifiable([...layer.ops, op]));
    _extendPicture(layer, next, op);
    _layers[_active] = next;
    notifyListeners();
  }

  /// القالبُ المفتوح في اللوحة، إن كان.
  String? get templateId {
    for (final layer in _layers.reversed) {
      for (final op in layer.ops) {
        if (op.kind == StudioOpKind.template) return op.template;
      }
    }
    return null;
  }

  /// الدلو: يملأ منطقةَ القالب التي تحت [p] كما تُرى — لا تتسرّب من خطوطها.
  /// يعيد `false` بلا قالب، أو والطبقةُ مقفلة.
  bool fillAt(Offset p, Color color, {double opacity = 1}) {
    final drawing = studioTemplateDrawing(templateId);
    if (drawing == null || activeLayer.locked) return false;
    final region = drawing.regionAt(p / studioTemplateScale);
    _commit(StudioOp(
      kind: StudioOpKind.fill,
      points: List.unmodifiable([p]),
      color: color,
      opacity: opacity,
      template: drawing.id,
      region: region,
    ));
    return true;
  }

  /// لوحةٌ جديدةٌ من القالب [id]: طبقةُ تلوينٍ في الأسفل نشطة، وفوقها طبقةُ
  /// الخطوط مقفلةً بمزج «ضرب» — بياضُها شفّافٌ على الألوان وخطوطُها فوقها،
  /// كما في برامج الرسم. ونسخةُ الطالب تُحفظ وحدها؛ القالبُ في الشيفرة لا يتغيّر.
  static StudioController? fromTemplate(String id, {String colorLayer = '1', String lineLayer = '2'}) {
    if (studioTemplateDrawing(id) == null) return null;
    return StudioController(layers: [
      StudioLayer(id: 1, name: colorLayer),
      StudioLayer(
        id: 2,
        name: lineLayer,
        blend: StudioBlend.multiply,
        locked: true,
        ops: List.unmodifiable([
          StudioOp(kind: StudioOpKind.template, points: const [Offset.zero], color: const Color(0xFF2B2B3A), template: id),
        ]),
      ),
    ]);
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

  void setBlend(int index, StudioBlend blend) {
    if (_layers[index].blend == blend) return;
    _remember();
    _layers[index] = _layers[index].copyWith(blend: blend);
    notifyListeners();
  }

  void toggleLocked(int index) {
    _remember();
    _layers[index] = _layers[index].copyWith(locked: !_layers[index].locked);
    notifyListeners();
  }

  /// يدمج الطبقةَ النشطة في التي تحتها. تُدمج كما هي حين تكون عاديّةً تامّة
  /// الظهور؛ وإلا فلا — كي لا يتغيّر شكلُ الرسمة بالدمج.
  bool mergeDown() {
    if (_active == 0) return false;
    final top = activeLayer;
    final below = _layers[_active - 1];
    if (top.opacity < 1 || top.blend != StudioBlend.normal || !top.visible) return false;
    _remember();
    _layers[_active - 1] = below.copyWith(ops: List.unmodifiable([...below.ops, ...top.ops]));
    _layers.removeAt(_active);
    _active--;
    notifyListeners();
    return true;
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
      canvas.saveLayer(
        bounds,
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, layer.opacity)
          ..blendMode = studioBlendModes[layer.blend]!,
      );
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
    _paintOnce(canvas, op);
    if (op.mirror) {
      canvas
        ..save()
        ..translate(studioSize, 0)
        ..scale(-1, 1);
      _paintOnce(canvas, op);
      canvas.restore();
    }
  }

  static void _paintOnce(Canvas canvas, StudioOp op) {
    switch (op.kind) {
      case StudioOpKind.stroke:
        _paintStroke(canvas, op);
      case StudioOpKind.shape:
        _paintShape(canvas, op);
      case StudioOpKind.gradient:
        _paintGradient(canvas, op);
      case StudioOpKind.template:
        _paintTemplate(canvas, op);
      case StudioOpKind.fill:
        final drawing = studioTemplateDrawing(op.template);
        if (drawing == null) return;
        canvas
          ..save()
          ..scale(studioTemplateScale)
          ..drawPath(
            studioVisibleRegion(drawing, op.region),
            Paint()
              ..isAntiAlias = true
              ..color = op.color.withValues(alpha: op.color.a * op.opacity),
          )
          ..restore();
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
      case StudioBrush.calligraphy:
        // ‏ريشةٌ عريضةٌ مائلة: الخطُّ يغلظ ويرقّ باتجاهه.
        final nib = Offset(math.cos(math.pi / 4), -math.sin(math.pi / 4)) * (w * 0.6);
        final fill = Paint()
          ..color = color
          ..isAntiAlias = true;
        if (points.length == 1) {
          canvas.drawLine(points.first - nib, points.first + nib, _line(color, 1.5));
          break;
        }
        for (var i = 1; i < points.length; i++) {
          final a = points[i - 1], b = points[i];
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
      case StudioBrush.softBrush:
        // ‏فرشاةٌ ناعمة الحوافّ للتظليل والإضاءة.
        canvas.drawPath(smoothPath(points), _line(color, w)..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.35));
      case StudioBrush.crayon:
        // ‏خيوطٌ متجاورة متفاوتة: ملمسُ الطباشير الملوّنة.
        final path = smoothPath(points);
        for (var k = 0; k < 5; k++) {
          final dx = (k - 2) * w * 0.16;
          final dy = ((k * 37) % 5 - 2) * w * 0.12;
          canvas.drawPath(path.shift(Offset(dx, dy)), _line(color.withValues(alpha: color.a * 0.4), w * 0.42));
        }
      case StudioBrush.neon:
        final path = smoothPath(points);
        canvas.drawPath(path, _line(color.withValues(alpha: 0.75), w * 1.5)..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.7));
        canvas.drawPath(path, _line(color, w * 0.7));
        canvas.drawPath(path, _line(const Color(0xD9FFFFFF), w * 0.25));
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

  /// خطوطُ القالب: كلُّ منطقةٍ بيضاءُ بحدٍّ أسود من الخلف إلى الأمام، فما
  /// يغطّيه غيرُه لا يظهر حدُّه — ثم التفاصيل.
  static void _paintTemplate(Canvas canvas, StudioOp op) {
    final drawing = studioTemplateDrawing(op.template);
    if (drawing == null) return;
    final paper = Paint()..color = const Color(0xFFFFFFFF);
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..color = op.color;
    canvas
      ..save()
      ..scale(studioTemplateScale);
    for (final region in drawing.regions) {
      canvas
        ..drawPath(region, paper)
        ..drawPath(region, ink);
    }
    for (final detail in drawing.details) {
      canvas.drawPath(detail, ink..strokeWidth = 2.6);
    }
    canvas.restore();
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

/// رسمةُ «استوديو الرسم» في «لوحاتي»: تُحفظ بالمخزن والصيغة اللذين تحفظ بهما
/// «لوحة الألوان» لوحاتِها ([ColoringGallery])، فتراها الدردشةُ وترسلها، ويراها
/// معرضُ «لوحاتي» بصورتها المصغّرة.
///
/// ── للعرض والإرسال، والتعديلُ في الاستوديو ──
/// طبقاتُها وأدواتُها في الاستوديو وحده، فأدواتُ لوحة الألوان (الدلو والفرشاة
/// والممحاة) لا تمسّها هنا. والمشروعُ نفسُه بطبقاته باقٍ في [StudioProjects]،
/// ويُفتح منه للتعديل.
class StudioArtwork extends ColoringArtwork {
  StudioArtwork(this.studio);

  /// معرّفُ رسمات الاستوديو: `studio:<وقت>` — كما يصنعه [StudioController].
  static const idPrefix = 'studio:';

  final StudioController studio;

  static StudioArtwork? fromJson(Object? json) {
    final studio = StudioController.fromJson(json);
    return studio == null ? null : StudioArtwork(studio);
  }

  @override
  String get artworkId => studio.id;

  @override
  String title({required bool arabic}) => arabic ? 'رسمتي في الاستوديو' : 'My Studio Drawing';

  @override
  bool get isEmpty => studio.isEmpty;
  @override
  bool get canUndo => false;
  @override
  bool get canRedo => false;

  @override
  void fillAt(Offset point, Color color) {}
  @override
  void beginStroke(
    Offset point, {
    required Color? color,
    required double width,
    BrushStyle brush = BrushStyle.pen,
    ShapeKind? shape,
    bool filled = false,
    int? magic,
  }) {}
  @override
  void extendStroke(Offset point) {}
  @override
  void endStroke() {}
  @override
  void eraseAt(Offset point) {}
  @override
  void undo() {}
  @override
  void redo() {}
  @override
  void clear() {}

  @override
  Map<String, Object?> toJson() => studio.toJson();

  @override
  CustomPainter painter({double outline = 3.2}) => StudioPainter(studio);

  @override
  Future<Uint8List?> toPng({int size = 600}) => studio.toPng(size: size);

  @override
  void dispose() {
    studio.dispose();
    super.dispose();
  }
}
