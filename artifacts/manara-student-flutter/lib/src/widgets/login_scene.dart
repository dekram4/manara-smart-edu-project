import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// مشهدُ السبورة في شاشة الدخول، والكتبُ والكرةُ الأرضية فيه حيّة.
///
/// ── لماذا ثلاثُ صور ──
/// السبورةُ والحامل والكتبُ والكرة رسمٌ واحد (`board_login_bg.png`)، فلا
/// يتحرّك جزءٌ منه وحده. ففُصلت المجموعتان عنه بكسلاً بكسلاً — ما اتّصل من
/// البكسلات المرئية ببذور المجموعة داخل حدودها — في أصولٍ جاهزة تحت
/// `assets/images/login_scene/`:
///
///   • `base.png`   الرسمُ بلا المجموعتين.
///   • `globe.png`  الكرةُ وكتبُها.
///   • `books.png`  الكتبُ وكوبُ الأقلام والحقيبة.
///
/// وفي السكون تُركَّب الثلاثُ فتطابق الأصلَ بكسلاً بكسلاً. ولا يُفصل شيءٌ على
/// الجهاز: يُفكّ ثلاثُ صورٍ ويُرسم، فلا عملَ عند فتح الشاشة.
///
/// ── والحركة حول نقطة التلاقي ──
/// كلُّ مجموعةٍ تمسّ شيئاً ساكناً في موضعٍ واحد — الكتبُ إطارَ السبورة،
/// والرصّةُ أصيصَ الصبّار. فتدور وتتنفّس حول ذلك الموضع: يكاد لا يتحرّك،
/// فلا تنفتح بينها وبين ما تمسّه فجوة، وطرفُها البعيد يتمايل ظاهراً.
///
/// وفي السكون — قبل أن تُفكّ الصور، أو مع «تقليل الحركة» — تُعرض الصورةُ
/// الأصلية كما هي، فلا يتغيّر شيءٌ في التخطيط.
class LivingLoginScene extends StatefulWidget {
  const LivingLoginScene({super.key});

  static const asset = 'assets/images/board_login_bg.png';
  static const baseAsset = 'assets/images/login_scene/base.png';
  static const globeAsset = 'assets/images/login_scene/globe.png';
  static const booksAsset = 'assets/images/login_scene/books.png';

  @override
  State<LivingLoginScene> createState() => _LivingLoginSceneState();
}

/// مواضعُ المجموعتين بنِسَبٍ من الصورة المربّعة — كما أخرجها مولّدُ الأصول.
class SceneLayout {
  const SceneLayout._();

  static const globeRect = Rect.fromLTRB(0.02393, 0.47705, 0.25488, 0.74854);
  static const booksRect = Rect.fromLTRB(0.65234, 0.54102, 0.96777, 0.86035);

  /// نقطةُ التلاقي: حيث تمسّ الكتبُ تحت الكرة إطارَ السبورة وساقَ الحامل.
  static const globePivot = Offset(0.20, 0.64);

  /// بين حافّة الكوب على الإطار وأطراف الكتب عند الأصيص.
  static const booksPivot = Offset(0.70, 0.70);

  /// كرةُ الخريطة: يمرّ عليها بريقٌ كأنها تدور.
  static const sphereCenter = Offset(0.1265, 0.580);
  static const sphereRadius = 0.0775;

  /// مساحتا اللمس — داخل المجموعتين، بعيداً عن السبورة والحقول.
  static const globeTouch = Rect.fromLTRB(0.03, 0.48, 0.20, 0.75);
  static const booksTouch = Rect.fromLTRB(0.74, 0.55, 0.96, 0.86);
}

class _SceneImages {
  const _SceneImages(this.base, this.globe, this.books);

  final ui.Image base;
  final ui.Image globe;
  final ui.Image books;

  void dispose() {
    base.dispose();
    globe.dispose();
    books.dispose();
  }
}

class _LivingLoginSceneState extends State<LivingLoginScene> with TickerProviderStateMixin {
  _SceneImages? _images;
  bool _loading = false;
  bool _disposed = false;

  /// النَّفَسُ المستمرّ: دورةٌ واحدة يقرأ منها الكلّ بأطوارٍ مختلفة.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5600),
  );

  /// الظهور: المجموعتان تقفزان إلى حجمهما تباعاً.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  late final AnimationController _pokeGlobe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  late final AnimationController _pokeBooks = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  bool get _reduced => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduced) {
      _loop.stop();
      return;
    }
    if (!_loading && _images == null) {
      _loading = true;
      final media = MediaQuery.maybeOf(context);
      // دقّةُ الفكّ على قدر ما يُرسم: لا أكثر من ضعف ما تعرضه الشاشة.
      final target = media == null
          ? 1400
          : (media.size.longestSide * media.devicePixelRatio).clamp(900, 2048).round();
      unawaited(_load(target));
    }
    if (!_loop.isAnimating) _loop.repeat();
  }

  Future<ui.Image> _decode(String asset, int width) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    return (await codec.getNextFrame()).image;
  }

  Future<void> _load(int target) async {
    try {
      final images = await Future.wait([
        _decode(LivingLoginScene.baseAsset, target),
        _decode(LivingLoginScene.globeAsset, (target * SceneLayout.globeRect.width).round()),
        _decode(LivingLoginScene.booksAsset, (target * SceneLayout.booksRect.width).round()),
      ]);
      final scene = _SceneImages(images[0], images[1], images[2]);
      if (_disposed) {
        scene.dispose();
        return;
      }
      setState(() => _images = scene);
      _intro.forward(from: 0);
    } catch (_) {
      // أصلٌ لا يُفكّ: تبقى الصورةُ الأصلية ساكنة — لا شيء ينكسر.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _loop.dispose();
    _intro.dispose();
    _pokeGlobe.dispose();
    _pokeBooks.dispose();
    _images?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    if (images == null || _reduced) {
      return Image.asset(
        LivingLoginScene.asset,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        Rect scaled(Rect f) =>
            Rect.fromLTRB(f.left * size.width, f.top * size.height, f.right * size.width, f.bottom * size.height);
        return Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _ScenePainter(
                    images: images,
                    loop: _loop,
                    intro: _intro,
                    pokeGlobe: _pokeGlobe,
                    pokeBooks: _pokeBooks,
                  ),
                ),
              ),
            ),
            // اللمسُ على المجموعتين وحدهما — تحت السبورة في ترتيب الطبقات،
            // فلا يأخذ شيئاً من الحقول ولا من زرّ الدخول.
            Positioned.fromRect(
              rect: scaled(SceneLayout.globeTouch),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (_) => _pokeGlobe.forward(from: 0),
              ),
            ),
            Positioned.fromRect(
              rect: scaled(SceneLayout.booksTouch),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (_) => _pokeBooks.forward(from: 0),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.images,
    required this.loop,
    required this.intro,
    required this.pokeGlobe,
    required this.pokeBooks,
  }) : super(repaint: Listenable.merge([loop, intro, pokeGlobe, pokeBooks]));

  final _SceneImages images;
  final Animation<double> loop;
  final Animation<double> intro;
  final Animation<double> pokeGlobe;
  final Animation<double> pokeBooks;

  static final _imagePaint = Paint()..filterQuality = FilterQuality.medium;

  @override
  void paint(Canvas canvas, Size size) {
    Rect scaled(Rect f) =>
        Rect.fromLTRB(f.left * size.width, f.top * size.height, f.right * size.width, f.bottom * size.height);
    Offset at(Offset f) => Offset(f.dx * size.width, f.dy * size.height);
    Rect whole(ui.Image image) => Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());

    canvas.drawImageRect(images.base, whole(images.base), Offset.zero & size, _imagePaint);

    final phase = loop.value * 2 * math.pi;

    // ── الكرةُ وكتبُها ──
    final gPoke = pokeGlobe.value;
    final gWobble = math.sin(gPoke * math.pi * 4) * 0.06 * (1 - gPoke);
    final gTilt = math.sin(phase) * 0.022 + gWobble;
    final gScale = _pop(intro.value, 0) * (1 + math.sin(gPoke * math.pi) * 0.06);
    canvas.save();
    _pivot(canvas, at(SceneLayout.globePivot), gTilt, gScale, squash: math.sin(phase * 2) * 0.008);
    canvas.drawImageRect(images.globe, whole(images.globe), scaled(SceneLayout.globeRect), _imagePaint);
    _shine(canvas, at(SceneLayout.sphereCenter), SceneLayout.sphereRadius * size.width, loop.value, gPoke);
    canvas.restore();

    // ── الكتبُ وكوبُ الأقلام والحقيبة ──
    final bPoke = pokeBooks.value;
    final breath = math.sin(phase + 1.3);
    final bTilt = breath * 0.012 + math.sin(bPoke * math.pi * 3) * 0.04 * (1 - bPoke);
    final bScale = _pop(intro.value, 0.25) * (1 + math.sin(bPoke * math.pi) * 0.05);
    canvas.save();
    _pivot(canvas, at(SceneLayout.booksPivot), bTilt, bScale, squash: breath * 0.012);
    canvas.drawImageRect(images.books, whole(images.books), scaled(SceneLayout.booksRect), _imagePaint);
    canvas.restore();
  }

  /// الظهور: من ٠٫٨٥ إلى ١ بارتدادٍ مطّاطيّ، بعد [delay] من مدّته.
  double _pop(double value, double delay) {
    final t = ((value - delay) / (1 - delay)).clamp(0.0, 1.0);
    if (t >= 1) return 1;
    return 0.85 + 0.15 * Curves.elasticOut.transform(t);
  }

  void _pivot(Canvas canvas, Offset pivot, double tilt, double scale, {double squash = 0}) {
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(tilt);
    canvas.scale(scale * (1 + squash * 0.5), scale * (1 - squash));
    canvas.translate(-pivot.dx, -pivot.dy);
  }

  /// بريقٌ يعبر الكرة من جانبٍ إلى جانب، فتبدو تدور. ومع اللمس يعبر مرّتين.
  void _shine(Canvas canvas, Offset center, double radius, double t, double poke) {
    final sweep = poke > 0 ? (poke * 2) % 1.0 : (t * 1.6) % 1.0;
    if (poke == 0 && sweep > 0.55) return; // استراحةٌ بين مرّتين
    final p = poke > 0 ? sweep : sweep / 0.55;
    final x = center.dx - radius * 1.4 + radius * 2.8 * p;
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    final band = Rect.fromCenter(center: Offset(x, center.dy), width: radius * 0.7, height: radius * 2.4);
    canvas.drawOval(
      band,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.38), Colors.white.withValues(alpha: 0)],
        ).createShader(band),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => old.images != images;
}
