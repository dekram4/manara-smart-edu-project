import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// رسمٌ حيّ: صورةُ خلفيةٍ تتحرّك عناصرُها كلٌّ على حدة — على طريقة «لمسة».
///
/// ── كيف، بلا أصولٍ جديدة ──
/// • ما ينفصل في الرسم (طائرٌ وسمكةٌ حول المنارة، ساعةٌ وفنجان، قبّعةٌ
///   طائرة) يُفصل عند التحميل من بكسلات الصورة نفسها — مكوّناتٌ متّصلة —
///   فيطير حرّاً، ومكانُه في الأصل فارغٌ أصلاً.
/// • وما يلتصق بغيره (الكرة، اللعبة، النبتة) يتنفّس ويتمايل ويقفز داخل
///   قناعٍ بيضاويّ ناعم الحوافّ. الحركةُ تكبيرٌ لا يقلّ عن ١ من نقطة
///   ارتكازه، فالقطعةُ المتحرّكة تغطّي أصلها دائماً: لا ظلَّ مكرّراً ولا
///   شقّ.
/// • ونجيماتٌ تلمع فوق الرسم، وشعاعُ المنارة يجول من مصباحها.
///
/// ── الأداء ──
/// الفصلُ مرّةً واحدة في خيطٍ جانبيّ ويُحفظ؛ والرسمُ محرّكٌ واحد ورسّامٌ
/// واحد خلف [RepaintBoundary]؛ والمحرّكُ يتوقّف حين تغطّي الشاشةَ شاشةٌ
/// أخرى ([TickerMode]). ومع «تقليل الحركة»، أو قبل اكتمال الفصل، أو إن
/// تعذّر: الصورةُ الأصلية نفسها، ساكنة.
class LivingArt extends StatefulWidget {
  const LivingArt({
    required this.asset,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.resolution = 1.0,
    super.key,
  });

  final String asset;
  final BoxFit fit;
  final Alignment alignment;

  /// نسبةُ دقّة الفكّ إلى ما تعرضه الشاشة: العلامةُ المائية الباهتة لا
  /// تحتاج دقّةً كاملة.
  final double resolution;

  /// الصور المفصولة الأخيرة، تُعاد عند الرجوع إلى الشاشة بلا فصلٍ جديد.
  static final _cache = <String, Future<_Art?>>{};
  static const _cacheSize = 4;

  @visibleForTesting
  static void clearCache() => _cache.clear();

  @override
  State<LivingArt> createState() => _LivingArtState();
}

class _LivingArtState extends State<LivingArt> with SingleTickerProviderStateMixin {
  _Art? _art;
  String? _requested;

  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 9000));
  }

  bool get _reduced => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LivingArt old) {
    super.didUpdateWidget(old);
    if (old.asset != widget.asset) {
      _art = null;
      _requested = null;
    }
    _sync();
  }

  void _sync() {
    if (_reduced) {
      _loop.stop();
      return;
    }
    final media = MediaQuery.maybeOf(context);
    final longest = media == null ? 1000.0 : media.size.longestSide * media.devicePixelRatio;
    // مضاعفاتُ ١٢٨: شاشاتٌ متقاربة تتشارك فصلاً واحداً محفوظاً.
    final width = ((longest * widget.resolution).clamp(512.0, 1280.0) / 128).round() * 128;
    final key = '${widget.asset}@$width';
    if (_requested == key) return;
    _requested = key;
    final future = LivingArt._cache.remove(key) ?? _Art.load(widget.asset, width);
    LivingArt._cache[key] = future; // الأحدثُ آخراً
    while (LivingArt._cache.length > LivingArt._cacheSize) {
      LivingArt._cache.remove(LivingArt._cache.keys.first);
    }
    unawaited(future.then((art) {
      if (!mounted || _requested != key || art == null) return;
      setState(() => _art = art);
      if (!_reduced && !_loop.isAnimating) _loop.repeat();
    }));
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = _art;
    if (art == null || _reduced) {
      return Image.asset(
        widget.asset,
        fit: widget.fit,
        alignment: widget.alignment,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ArtPainter(
          art: art,
          spec: LivingArtSpecs.of(widget.asset),
          fit: widget.fit,
          alignment: widget.alignment,
          loop: _loop,
        ),
      ),
    );
  }
}

/// كيف يتحرّك عنصرٌ ملتصق.
enum ArtMove {
  /// يتنفّس: يكبر ويعود.
  breathe,

  /// يقفز: يتمدّد صعوداً من قاعدته ويعود.
  hop,

  /// يتمايل يمنةً ويسرة على قاعدته.
  sway,

  /// كرةٌ أرضية: تتمايل ويعبرها بريقٌ كأنها تدور.
  globe,
}

/// عنصرٌ ملتصق في الرسم: [area] مستطيلُه بكسور عرض الصورة وارتفاعها،
/// و[pivot] نقطةُ ارتكازه (أسفلُ وسطِه إن لم تُعطَ).
@immutable
class ArtPart {
  const ArtPart(this.area, this.move, {this.pivot, this.amp = 1, this.phase = 0, this.cycles = 1});

  final Rect area;
  final ArtMove move;
  final Offset? pivot;
  final double amp;
  final double phase;

  /// كم مرّةً يتحرّك في الدورة الواحدة (عددٌ صحيح، فتلتفّ الدورة بلا قفزة).
  final int cycles;

  Offset get anchor => pivot ?? Offset(area.center.dx, area.bottom);
}

@immutable
class ArtSpec {
  const ArtSpec({this.parts = const [], this.beacon, this.sparkles = 8});

  final List<ArtPart> parts;

  /// مصباحُ المنارة، إن كان في الرسم منارة.
  final Offset? beacon;
  final int sparkles;
}

/// عناصرُ كلّ خلفية، مقيسةً على رسمها.
class LivingArtSpecs {
  const LivingArtSpecs._();

  static ArtSpec of(String asset) => _specs[asset.split('/').last] ?? const ArtSpec();

  static const _specs = <String, ArtSpec>{
    'lighthouse_main_bg.png': ArtSpec(
      beacon: Offset(0.535, 0.172),
      sparkles: 10,
      parts: [
        ArtPart(Rect.fromLTRB(0.700, 0.515, 0.845, 0.665), ArtMove.globe, pivot: Offset(0.773, 0.70), amp: 1.2),
        ArtPart(Rect.fromLTRB(0.440, 0.025, 0.635, 0.235), ArtMove.hop, phase: 1.1, amp: 0.7),
        ArtPart(Rect.fromLTRB(0.585, 0.820, 0.735, 0.960), ArtMove.hop, phase: 2.0, cycles: 2),
        ArtPart(Rect.fromLTRB(0.055, 0.810, 0.175, 0.930), ArtMove.sway, phase: 0.4, amp: 1.3),
        ArtPart(Rect.fromLTRB(0.755, 0.835, 0.905, 0.945), ArtMove.hop, phase: 3.3),
        ArtPart(Rect.fromLTRB(0.175, 0.405, 0.345, 0.700), ArtMove.sway, pivot: Offset(0.29, 0.70), phase: 4.2, amp: 0.6),
        ArtPart(Rect.fromLTRB(0.360, 0.450, 0.445, 0.600), ArtMove.hop, phase: 5.0, cycles: 2),
        ArtPart(Rect.fromLTRB(0.270, 0.690, 0.410, 0.830), ArtMove.breathe, phase: 2.6),
      ],
    ),
    'back_game.png': ArtSpec(parts: [
      ArtPart(Rect.fromLTRB(0.080, 0.520, 0.370, 0.810), ArtMove.sway, amp: 1.2),
      ArtPart(Rect.fromLTRB(0.715, 0.530, 0.860, 0.665), ArtMove.hop, phase: 1.4, cycles: 2),
      ArtPart(Rect.fromLTRB(0.100, 0.170, 0.405, 0.490), ArtMove.sway, phase: 2.2, amp: 0.7),
      ArtPart(Rect.fromLTRB(0.620, 0.180, 0.915, 0.520), ArtMove.breathe, phase: 3.1, amp: 0.7),
      ArtPart(Rect.fromLTRB(0.580, 0.670, 0.915, 0.835), ArtMove.sway, phase: 4.0, amp: 0.8),
      ArtPart(Rect.fromLTRB(0.475, 0.610, 0.605, 0.750), ArtMove.breathe, pivot: Offset(0.54, 0.68), phase: 5.1),
    ]),
    'back_teach2.png': ArtSpec(parts: [
      ArtPart(Rect.fromLTRB(0.080, 0.110, 0.280, 0.620), ArtMove.sway, amp: 0.6),
      ArtPart(Rect.fromLTRB(0.720, 0.160, 0.890, 0.410), ArtMove.sway, phase: 1.3, amp: 1.2),
      ArtPart(Rect.fromLTRB(0.640, 0.210, 0.720, 0.370), ArtMove.hop, phase: 2.4, cycles: 2),
      ArtPart(Rect.fromLTRB(0.420, 0.400, 0.560, 0.660), ArtMove.hop, phase: 3.6),
      ArtPart(Rect.fromLTRB(0.270, 0.380, 0.390, 0.530), ArtMove.sway, phase: 4.5, amp: 1.2),
      ArtPart(Rect.fromLTRB(0.180, 0.690, 0.720, 0.940), ArtMove.breathe, phase: 5.4, amp: 0.4),
    ]),
    'back_teach.png': ArtSpec(parts: [
      ArtPart(Rect.fromLTRB(0.700, 0.480, 0.840, 0.730), ArtMove.sway, amp: 1.3),
      ArtPart(Rect.fromLTRB(0.230, 0.330, 0.420, 0.450), ArtMove.hop, phase: 1.5, cycles: 2),
      ArtPart(Rect.fromLTRB(0.150, 0.450, 0.220, 0.550), ArtMove.hop, phase: 2.7),
      ArtPart(Rect.fromLTRB(0.450, 0.610, 0.620, 0.800), ArtMove.hop, phase: 3.9, amp: 0.6),
      ArtPart(Rect.fromLTRB(0.330, 0.460, 0.700, 0.620), ArtMove.breathe, phase: 4.8, amp: 0.4),
    ]),
    'back_quez.png': _quiz,
    'back_endless.png': _quiz,
    'back_hal.png': ArtSpec(parts: [
      ArtPart(Rect.fromLTRB(0.180, 0.050, 0.600, 0.420), ArtMove.sway, amp: 0.8),
      ArtPart(Rect.fromLTRB(0.550, 0.090, 0.680, 0.400), ArtMove.sway, phase: 1.2, amp: 1.1),
      ArtPart(Rect.fromLTRB(0.320, 0.350, 0.640, 0.680), ArtMove.globe, phase: 2.1),
      ArtPart(Rect.fromLTRB(0.050, 0.550, 0.470, 0.830), ArtMove.hop, phase: 3.0, amp: 0.7),
      ArtPart(Rect.fromLTRB(0.470, 0.530, 0.910, 0.900), ArtMove.breathe, phase: 4.1, amp: 0.5),
      ArtPart(Rect.fromLTRB(0.640, 0.340, 0.780, 0.490), ArtMove.breathe, phase: 5.2, cycles: 2),
    ]),
    'back_cinema.png': _desk,
    'back_chat.png': _desk,
    'back_avatar.png': ArtSpec(parts: [
      ArtPart(Rect.fromLTRB(0.130, 0.360, 0.220, 0.560), ArtMove.sway, amp: 1.3),
      ArtPart(Rect.fromLTRB(0.170, 0.410, 0.225, 0.520), ArtMove.sway, phase: 1.6, amp: 1.3),
      ArtPart(Rect.fromLTRB(0.465, 0.255, 0.525, 0.450), ArtMove.sway, phase: 2.5, amp: 1.2),
      ArtPart(Rect.fromLTRB(0.780, 0.440, 0.835, 0.650), ArtMove.sway, phase: 3.4, amp: 1.2),
      ArtPart(Rect.fromLTRB(0.465, 0.515, 0.585, 0.635), ArtMove.hop, phase: 4.3, cycles: 2),
      ArtPart(Rect.fromLTRB(0.570, 0.480, 0.630, 0.580), ArtMove.hop, phase: 5.2),
    ]),
    'back_meet.png': ArtSpec(parts: [
      ArtPart(Rect.fromLTRB(0.065, 0.445, 0.245, 0.635), ArtMove.globe, pivot: Offset(0.17, 0.72), amp: 1.2),
      ArtPart(Rect.fromLTRB(0.450, 0.390, 0.650, 0.610), ArtMove.hop, phase: 1.5),
      ArtPart(Rect.fromLTRB(0.730, 0.300, 0.940, 0.580), ArtMove.sway, phase: 2.8, amp: 0.9),
      ArtPart(Rect.fromLTRB(0.710, 0.600, 0.820, 0.750), ArtMove.sway, phase: 4.1, amp: 1.4),
    ]),
    'back_book.webp': ArtSpec(parts: [
      ArtPart(Rect.fromLTRB(0.180, 0.150, 0.370, 0.620), ArtMove.sway, amp: 0.8),
      ArtPart(Rect.fromLTRB(0.350, 0.250, 0.600, 0.530), ArtMove.breathe, phase: 2.0, amp: 0.6),
      ArtPart(Rect.fromLTRB(0.510, 0.470, 0.610, 0.670), ArtMove.sway, pivot: Offset(0.53, 0.66), phase: 3.5, amp: 1.4),
    ]),
  };

  static const _quiz = ArtSpec(parts: [
    ArtPart(Rect.fromLTRB(0.090, 0.200, 0.540, 0.580), ArtMove.sway, amp: 0.8),
    ArtPart(Rect.fromLTRB(0.560, 0.150, 0.830, 0.220), ArtMove.breathe, phase: 1.3, cycles: 2),
    ArtPart(Rect.fromLTRB(0.190, 0.610, 0.340, 0.750), ArtMove.hop, phase: 2.5, cycles: 2),
    ArtPart(Rect.fromLTRB(0.390, 0.620, 0.530, 0.750), ArtMove.breathe, phase: 3.7),
    ArtPart(Rect.fromLTRB(0.590, 0.570, 0.790, 0.760), ArtMove.hop, phase: 4.9),
  ]);

  static const _desk = ArtSpec(parts: [
    ArtPart(Rect.fromLTRB(0.320, 0.000, 0.770, 0.250), ArtMove.sway, amp: 0.8),
    ArtPart(Rect.fromLTRB(0.240, 0.270, 0.330, 0.450), ArtMove.hop, phase: 1.4, cycles: 2),
    ArtPart(Rect.fromLTRB(0.620, 0.470, 0.690, 0.600), ArtMove.hop, phase: 2.6),
    ArtPart(Rect.fromLTRB(0.730, 0.250, 0.830, 0.570), ArtMove.breathe, phase: 3.8, amp: 0.6),
    ArtPart(Rect.fromLTRB(0.080, 0.580, 0.190, 0.710), ArtMove.sway, phase: 5.0, amp: 1.2),
  ]);
}

// ── الفصل ──

/// قطعةٌ حرّة: صورتُها ومستطيلُها بكسور الصورة الكاملة.
class _Flyer {
  _Flyer(this.image, this.rect);
  final ui.Image image;
  final Rect rect;
}

class _Art {
  _Art(this.base, this.flyers, this.content);

  /// الصورةُ بلا القطع الحرّة.
  final ui.Image base;
  final List<_Flyer> flyers;

  /// حدودُ الرسم الفعليّ بكسور الصورة: فيه تلمع النجيمات.
  final Rect content;

  static Future<_Art?> load(String asset, int width) async {
    try {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
      final image = (await codec.getNextFrame()).image;
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bytes == null) return null;
      final split = await compute(splitArt, SplitInput(bytes.buffer.asUint8List(), image.width, image.height));
      if (split.flyers.isEmpty) {
        return _Art(image, const [], split.content);
      }
      image.dispose();
      final base = await _fromPixels(split.base, split.width, split.height);
      final flyers = <_Flyer>[];
      for (final f in split.flyers) {
        flyers.add(_Flyer(
          await _fromPixels(f.pixels, f.width, f.height),
          Rect.fromLTWH(
            f.left / split.width,
            f.top / split.height,
            f.width / split.width,
            f.height / split.height,
          ),
        ));
      }
      return _Art(base, flyers, split.content);
    } catch (_) {
      return null; // تبقى الصورةُ الأصلية ساكنة — لا شيء ينكسر.
    }
  }

  static Future<ui.Image> _fromPixels(Uint8List pixels, int width, int height) {
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, width, height, ui.PixelFormat.rgba8888, done.complete);
    return done.future;
  }
}

@visibleForTesting
class SplitInput {
  const SplitInput(this.rgba, this.width, this.height);
  final Uint8List rgba;
  final int width;
  final int height;
}

@visibleForTesting
class SplitPiece {
  const SplitPiece(this.pixels, this.left, this.top, this.width, this.height);
  final Uint8List pixels;
  final int left;
  final int top;
  final int width;
  final int height;
}

@visibleForTesting
class SplitResult {
  const SplitResult(this.base, this.width, this.height, this.flyers, this.content);
  final Uint8List base;
  final int width;
  final int height;
  final List<SplitPiece> flyers;
  final Rect content;
}

/// يفصل الجزرَ الصغيرة المنفصلة عن الرسم الأكبر: مكوّناتٌ متّصلة (جيرةٌ
/// ثمانية) على البكسلات الظاهرة، ثم تُضمّ إلى كلّ قطعةٍ حافّتُها الشفيفة
/// كي لا تبقى هالتُها في مكانها حين تطير.
@visibleForTesting
SplitResult splitArt(SplitInput input) {
  final w = input.width, h = input.height;
  final px = input.rgba;
  final n = w * h;
  const solid = 24;
  final labels = Int32List(n);
  final queue = Int32List(n);
  final areas = <int>[0];
  final boxes = <List<int>>[<int>[]];
  var next = 0;
  for (var s = 0; s < n; s++) {
    if (labels[s] != 0 || px[s * 4 + 3] < solid) continue;
    final id = ++next;
    var head = 0, tail = 0, area = 0;
    var minX = w, minY = h, maxX = 0, maxY = 0;
    queue[tail++] = s;
    labels[s] = id;
    while (head < tail) {
      final i = queue[head++];
      area++;
      final x = i % w, y = i ~/ w;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
      for (var dy = -1; dy <= 1; dy++) {
        final yy = y + dy;
        if (yy < 0 || yy >= h) continue;
        for (var dx = -1; dx <= 1; dx++) {
          final xx = x + dx;
          if (xx < 0 || xx >= w || (dx == 0 && dy == 0)) continue;
          final j = yy * w + xx;
          if (labels[j] != 0 || px[j * 4 + 3] < solid) continue;
          labels[j] = id;
          queue[tail++] = j;
        }
      }
    }
    areas.add(area);
    boxes.add([minX, minY, maxX, maxY]);
  }

  var largest = 0;
  for (var id = 1; id <= next; id++) {
    if (areas[id] > areas[largest]) largest = id;
  }
  final ids = [
    for (var id = 1; id <= next; id++)
      if (id != largest && areas[id] >= n * 0.0012 && areas[id] <= n * 0.25) id,
  ]..sort((a, b) => areas[b] - areas[a]);
  final flyerIds = ids.take(5).toSet();

  // الحافّةُ الشفيفة (ظلٌّ ناعم، تنعيمُ حواف) تتبع القطعةَ التي تجاورها.
  for (var pass = 0; pass < 3; pass++) {
    for (var i = 0; i < n; i++) {
      if (labels[i] != 0 || px[i * 4 + 3] == 0) continue;
      final x = i % w;
      var l = 0;
      if (x > 0 && labels[i - 1] > 0) l = labels[i - 1];
      if (l == 0 && x < w - 1 && labels[i + 1] > 0) l = labels[i + 1];
      if (l == 0 && i >= w && labels[i - w] > 0) l = labels[i - w];
      if (l == 0 && i < n - w && labels[i + w] > 0) l = labels[i + w];
      if (l != 0) labels[i] = -l; // سالبٌ في هذه الجولة كي لا يمتدّ بها مرّتين
    }
    for (var i = 0; i < n; i++) {
      if (labels[i] < 0) labels[i] = -labels[i];
    }
  }

  final base = Uint8List.fromList(px);
  final flyers = <SplitPiece>[];
  for (final id in flyerIds) {
    final b = boxes[id];
    final left = math.max(0, b[0] - 3), top = math.max(0, b[1] - 3);
    final right = math.min(w - 1, b[2] + 3), bottom = math.min(h - 1, b[3] + 3);
    final fw = right - left + 1, fh = bottom - top + 1;
    final out = Uint8List(fw * fh * 4);
    for (var y = top; y <= bottom; y++) {
      for (var x = left; x <= right; x++) {
        final i = y * w + x;
        if (labels[i] != id) continue;
        final o = ((y - top) * fw + (x - left)) * 4;
        for (var c = 0; c < 4; c++) {
          out[o + c] = px[i * 4 + c];
          base[i * 4 + c] = 0;
        }
      }
    }
    flyers.add(SplitPiece(out, left, top, fw, fh));
  }

  var cx0 = w, cy0 = h, cx1 = 0, cy1 = 0;
  for (var id = 1; id <= next; id++) {
    if (areas[id] < n * 0.0005) continue;
    final b = boxes[id];
    cx0 = math.min(cx0, b[0]);
    cy0 = math.min(cy0, b[1]);
    cx1 = math.max(cx1, b[2]);
    cy1 = math.max(cy1, b[3]);
  }
  final content = cx1 > cx0 && cy1 > cy0
      ? Rect.fromLTRB(cx0 / w, cy0 / h, (cx1 + 1) / w, (cy1 + 1) / h)
      : const Rect.fromLTRB(0, 0, 1, 1);
  return SplitResult(flyers.isEmpty ? px : base, w, h, flyers, content);
}

// ── الرسم ──

class _ArtPainter extends CustomPainter {
  _ArtPainter({
    required this.art,
    required this.spec,
    required this.fit,
    required this.alignment,
    required this.loop,
  }) : super(repaint: loop);

  final _Art art;
  final ArtSpec spec;
  final BoxFit fit;
  final Alignment alignment;
  final Animation<double> loop;

  static final _imagePaint = Paint()..filterQuality = FilterQuality.medium;
  static final _layerPaint = Paint();
  static const _twoPi = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final base = art.base;
    final imageSize = Size(base.width.toDouble(), base.height.toDouble());
    final fitted = applyBoxFit(fit, imageSize, size);
    final dest = alignment.inscribe(fitted.destination, Offset.zero & size);
    final src = alignment.inscribe(fitted.source, Offset.zero & imageSize);
    // الكسورُ مقيسةٌ على الصورة كاملة؛ فإن قُصّت ([BoxFit.cover]) امتدّ
    // إطارُها خارج الشاشة بقدر ما قُصّ.
    final sx = dest.width / src.width, sy = dest.height / src.height;
    final frame = Rect.fromLTWH(
      dest.left - src.left * sx,
      dest.top - src.top * sy,
      imageSize.width * sx,
      imageSize.height * sy,
    );
    Offset at(Offset f) => Offset(frame.left + f.dx * frame.width, frame.top + f.dy * frame.height);
    Rect area(Rect f) => Rect.fromPoints(at(f.topLeft), at(f.bottomRight));

    final t = loop.value;
    final theta = t * _twoPi;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // الرسمُ كلُّه يطفو طفواً خفيفاً.
    canvas.translate(
      math.sin(theta) * frame.width * 0.004,
      (1 - math.cos(theta * 2)) / 2 * frame.height * 0.008,
    );

    final whole = Offset.zero & imageSize;
    canvas.drawImageRect(base, whole, frame, _imagePaint);

    for (final part in spec.parts) {
      _part(canvas, part, area(part.area), at(part.anchor), frame, theta);
    }
    for (var i = 0; i < art.flyers.length; i++) {
      _flyer(canvas, art.flyers[i], area(art.flyers[i].rect), theta, i);
    }
    final beacon = spec.beacon;
    if (beacon != null) _beacon(canvas, at(beacon), frame, theta);
    _sparkles(canvas, area(art.content), theta);
    canvas.restore();
  }

  void _part(Canvas canvas, ArtPart part, Rect r, Offset pivot, Rect frame, double theta) {
    final th = theta * part.cycles + part.phase;
    final w = (1 - math.cos(th)) / 2; // ٠ في الراحة، ١ في الذروة
    final a = part.amp;
    var scaleX = 1.0, scaleY = 1.0, rot = 0.0;
    switch (part.move) {
      case ArtMove.breathe:
        scaleX = scaleY = 1 + 0.055 * a * w;
      case ArtMove.hop:
        scaleX = 1 + 0.025 * a * w;
        scaleY = 1 + 0.10 * a * w;
      case ArtMove.sway:
      case ArtMove.globe:
        scaleX = scaleY = 1 + 0.045 * a * w;
        // الميلُ يتبع التكبير فيزولان معاً: في الراحة القطعةُ فوق أصلها تماماً.
        rot = 0.075 * a * math.sin(th) * w;
    }

    // القناعُ أوسعُ من العنصر: قلبُه يغطّيه كلَّه، وحافّتُه الناعمة خارجه.
    final mask = Rect.fromCenter(center: r.center, width: r.width * 1.3, height: r.height * 1.3);
    canvas.saveLayer(mask.inflate(mask.longestSide * 0.12), _layerPaint);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(rot);
    canvas.scale(scaleX, scaleY);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.clipRect(mask);
    canvas.drawImageRect(art.base, Offset.zero & Size(art.base.width.toDouble(), art.base.height.toDouble()), frame,
        _imagePaint);
    if (part.move == ArtMove.globe) _shine(canvas, r, th);
    canvas.drawRect(
      mask,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = RadialGradient(
          colors: const [Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
          stops: const [0, 0.8, 1],
          transform: _ellipse(mask),
        ).createShader(mask),
    );
    canvas.restore();
  }

  /// يمطّ التدرّجَ الدائريّ إلى بيضاويٍّ يملأ [r].
  static GradientTransform _ellipse(Rect r) => _EllipseTransform(r);

  /// بريقٌ يعبر الكرة كأنها تدور.
  void _shine(Canvas canvas, Rect r, double th) {
    final sweep = (th / _twoPi) % 1.0;
    if (sweep > 0.6) return;
    final p = sweep / 0.6;
    final x = r.left - r.width * 0.3 + r.width * 1.6 * p;
    canvas.save();
    canvas.clipPath(Path()..addOval(r));
    final band = Rect.fromCenter(center: Offset(x, r.center.dy), width: r.width * 0.35, height: r.height * 1.2);
    canvas.drawOval(
      band,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.45), Colors.white.withValues(alpha: 0)],
        ).createShader(band),
    );
    canvas.restore();
  }

  void _flyer(Canvas canvas, _Flyer f, Rect r, double theta, int index) {
    final p = index * 2.3;
    final dx = math.sin(theta + p) * r.width * 0.14;
    final dy = -(1 - math.cos(theta * 2 + p)) / 2 * r.height * 0.35;
    final rot = math.sin(theta * 2 + p + 1) * 0.12;
    final c = r.center;
    canvas.save();
    canvas.translate(c.dx + dx, c.dy + dy);
    canvas.rotate(rot);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawImageRect(f.image, Offset.zero & Size(f.image.width.toDouble(), f.image.height.toDouble()), r,
        _imagePaint);
    canvas.restore();
  }

  /// مصباحُ المنارة ينبض، وشعاعُه يدور: يطول جهةً ثم يقصر ثم يطول جهةً أخرى.
  void _beacon(Canvas canvas, Offset lamp, Rect frame, double theta) {
    final pulse = 0.5 + 0.5 * math.sin(theta * 4);
    final glowR = frame.width * (0.06 + 0.02 * pulse);
    canvas.drawCircle(
      lamp,
      glowR,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFFFFF1A8).withValues(alpha: 0.55 + 0.25 * pulse),
          const Color(0x00FFF1A8),
        ]).createShader(Rect.fromCircle(center: lamp, radius: glowR)),
    );
    final c = math.cos(theta * 2);
    final reach = frame.width * 0.48 * math.sqrt(c.abs());
    if (reach < 4) return;
    final dir = c >= 0 ? 1.0 : -1.0;
    final spread = frame.width * (0.035 + 0.035 * c.abs());
    final end = lamp + Offset(dir * reach, 0);
    final beam = Path()
      ..moveTo(lamp.dx, lamp.dy - frame.width * 0.008)
      ..lineTo(end.dx, end.dy - spread)
      ..lineTo(end.dx, end.dy + spread)
      ..lineTo(lamp.dx, lamp.dy + frame.width * 0.008)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..shader = ui.Gradient.linear(lamp, end, [
          const Color(0xFFFFF3B0).withValues(alpha: 0.30 + 0.30 * c.abs()),
          const Color(0x00FFF3B0),
        ]),
    );
  }

  /// نجيماتٌ تلمع وتخبو بأطوارٍ متفاوتة، في مواضعَ ثابتةٍ لكلّ رسم.
  void _sparkles(Canvas canvas, Rect content, double theta) {
    final count = spec.sparkles;
    if (count == 0) return;
    final rnd = math.Random(content.hashCode ^ count);
    final unit = content.shortestSide;
    for (var i = 0; i < count; i++) {
      final pos = Offset(
        content.left + content.width * (0.05 + 0.9 * rnd.nextDouble()),
        content.top + content.height * (0.05 + 0.9 * rnd.nextDouble()),
      );
      final k = 1 + rnd.nextInt(3);
      final p = rnd.nextDouble() * _twoPi;
      final s = math.sin(theta * k + p);
      if (s <= 0.05) continue;
      final v = math.pow(s, 3).toDouble();
      final r = unit * (0.012 + 0.018 * v);
      canvas.drawCircle(
        pos,
        r * 1.6,
        Paint()..color = const Color(0xFFFFD86B).withValues(alpha: 0.30 * v),
      );
      final star = Path()
        ..moveTo(pos.dx, pos.dy - r * 1.4)
        ..quadraticBezierTo(pos.dx, pos.dy, pos.dx + r * 1.4, pos.dy)
        ..quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy + r * 1.4)
        ..quadraticBezierTo(pos.dx, pos.dy, pos.dx - r * 1.4, pos.dy)
        ..quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy - r * 1.4)
        ..close();
      canvas.drawPath(star, Paint()..color = Colors.white.withValues(alpha: 0.95 * v));
    }
  }

  @override
  bool shouldRepaint(covariant _ArtPainter old) =>
      old.art != art || old.spec != spec || old.fit != fit || old.alignment != alignment;
}

class _EllipseTransform extends GradientTransform {
  const _EllipseTransform(this.rect);
  final Rect rect;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final c = bounds.center;
    final short = bounds.shortestSide;
    return Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(bounds.width / short, bounds.height / short, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }
}
