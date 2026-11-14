import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// رسوماتُ «لوحة الألوان السحرية»: خطوطٌ سوداء ومناطقُ مغلقة يلوّنها الطفل.
///
/// ── لماذا مساراتٌ لا صور ──
/// صورةٌ نقطيّة لا تعرف أين تنتهي أذنُ القطّة وأين يبدأ رأسُها، فالتعبئةُ فيها
/// تتسرّب من أيّ ثغرةٍ في الخط، والفرشاةُ تخرج عن الحدود. وكلُّ رسمةٍ هنا قائمةُ
/// مناطقَ مغلقة ([ColoringDrawing.regions]) مرتّبةٍ من الخلف إلى الأمام: لمسةُ
/// الدلو تملأ المنطقةَ العليا تحت الإصبع، وخطُّ الفرشاة يُقصّ على المنطقة التي
/// بدأ فيها — فلا يخرج لونُ طفلٍ عن الخطّ مهما اضطربت يده.
///
/// والإحداثيّاتُ في مربّعٍ ثابت [coloringCanvasSize]، تُكبَّر إلى حجم الشاشة.
///
/// ── والتجديد ──
/// إلى جانب الرسومات المرسومة باليد، مولّدان ([mandala] و[shapeGarden]) يصنعان
/// من بذرةٍ عشوائية رسمةً لم تُرَ من قبل — فكلُّ دخولٍ يأتي بجديد.
const double coloringCanvasSize = 300;

enum ColoringCategory { animals, nature, characters, shapes, objects, magic }

class ColoringDrawing {
  const ColoringDrawing({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.category,
    required this.regions,
    this.details = const [],
  });

  /// معرّفٌ يُحفظ مع اللوحة: اسمُ الرسمة، أو `mandala:<بذرة>` للمولَّدة.
  final String id;
  final String titleAr;
  final String titleEn;
  final ColoringCategory category;

  /// المناطقُ المغلقة من الخلف إلى الأمام — المتأخّرةُ تغطّي ما تحتها.
  final List<Path> regions;

  /// خطوطٌ تُرسم فوق كلّ شيء ولا تُلوَّن: شواربُ، وابتسامات، وخيوط.
  final List<Path> details;

  /// المنطقةُ العليا تحت [point] (بإحداثيّات الرسمة)، أو `-1` للخلفية.
  int regionAt(Offset point) {
    for (var i = regions.length - 1; i >= 0; i--) {
      if (regions[i].contains(point)) return i;
    }
    return -1;
  }
}

// ── أدواتُ الرسم ─────────────────────────────────────────────────────

Path _circle(double x, double y, double r) =>
    Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));

Path _oval(double x, double y, double rx, double ry) =>
    Path()..addOval(Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2));

Path _rect(double l, double t, double w, double h, [double r = 0]) =>
    Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), Radius.circular(r)));

Path _poly(List<double> xy) {
  final path = Path()..moveTo(xy[0], xy[1]);
  for (var i = 2; i < xy.length; i += 2) {
    path.lineTo(xy[i], xy[i + 1]);
  }
  return path..close();
}

Path _line(List<double> xy) {
  final path = Path()..moveTo(xy[0], xy[1]);
  for (var i = 2; i < xy.length; i += 2) {
    path.lineTo(xy[i], xy[i + 1]);
  }
  return path;
}

Path _curve(double x1, double y1, double cx, double cy, double x2, double y2) =>
    Path()
      ..moveTo(x1, y1)
      ..quadraticBezierTo(cx, cy, x2, y2);

/// [path] مُداراً بزاوية [angle] حول ([cx], [cy]).
Path _rotate(Path path, double cx, double cy, double angle) {
  final c = math.cos(angle);
  final s = math.sin(angle);
  final matrix = Float64List.fromList([
    c, s, 0, 0, //
    -s, c, 0, 0,
    0, 0, 1, 0,
    cx - c * cx + s * cy, cy - s * cx - c * cy, 0, 1,
  ]);
  return path.transform(matrix);
}

Path _rotOval(double x, double y, double rx, double ry, double angle) =>
    _rotate(_oval(x, y, rx, ry), x, y, angle);

Path _star(double cx, double cy, double outer, double inner, int points, [double rotation = -math.pi / 2]) {
  final xy = <double>[];
  for (var i = 0; i < points * 2; i++) {
    final r = i.isEven ? outer : inner;
    final a = rotation + i * math.pi / points;
    xy
      ..add(cx + r * math.cos(a))
      ..add(cy + r * math.sin(a));
  }
  return _poly(xy);
}

Path _polygon(double cx, double cy, double r, int sides, [double rotation = -math.pi / 2]) {
  final xy = <double>[];
  for (var i = 0; i < sides; i++) {
    final a = rotation + i * 2 * math.pi / sides;
    xy
      ..add(cx + r * math.cos(a))
      ..add(cy + r * math.sin(a));
  }
  return _poly(xy);
}

Path _heart(double cx, double cy, double s) => Path()
  ..moveTo(cx, cy + 0.9 * s)
  ..cubicTo(cx - 1.6 * s, cy - 0.2 * s, cx - 0.6 * s, cy - 1.3 * s, cx, cy - 0.45 * s)
  ..cubicTo(cx + 0.6 * s, cy - 1.3 * s, cx + 1.6 * s, cy - 0.2 * s, cx, cy + 0.9 * s)
  ..close();

Path _union(List<Path> paths) =>
    paths.skip(1).fold(paths.first, (a, b) => Path.combine(PathOperation.union, a, b));

Path _cloud(double x, double y, double s) => _union([
      _circle(x - 22 * s, y + 4 * s, 20 * s),
      _circle(x, y - 8 * s, 26 * s),
      _circle(x + 24 * s, y + 4 * s, 20 * s),
      _rect(x - 22 * s, y + 4 * s, 46 * s, 20 * s, 8 * s),
    ]);

/// نصفُ دائرةٍ علويّ مغلقٌ بقطره.
Path _semi(double cx, double cy, double r) => Path()
  ..moveTo(cx - r, cy)
  ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r), math.pi, math.pi, false)
  ..close();

// ── الرسوماتُ المرسومة باليد ──────────────────────────────────────────

ColoringDrawing _cat() => ColoringDrawing(
      id: 'cat',
      titleAr: 'القطة اللطيفة',
      titleEn: 'Cute Cat',
      category: ColoringCategory.animals,
      regions: [
        _rotOval(222, 205, 14, 50, 0.6),
        _oval(150, 215, 58, 55),
        _oval(150, 230, 32, 32),
        _oval(122, 266, 17, 10),
        _oval(178, 266, 17, 10),
        _poly([98, 100, 106, 38, 142, 80]),
        _poly([202, 100, 194, 38, 158, 80]),
        _poly([108, 88, 111, 56, 132, 80]),
        _poly([192, 88, 189, 56, 168, 80]),
        _circle(150, 118, 55),
        _oval(128, 110, 10, 13),
        _oval(172, 110, 10, 13),
        _circle(131, 106, 3.5),
        _circle(175, 106, 3.5),
        _poly([142, 130, 158, 130, 150, 139]),
      ],
      details: [
        _curve(150, 139, 145, 150, 136, 148),
        _curve(150, 139, 155, 150, 164, 148),
        _line([118, 135, 82, 128]),
        _line([118, 141, 84, 146]),
        _line([182, 135, 218, 128]),
        _line([182, 141, 216, 146]),
      ],
    );

ColoringDrawing _fish() => ColoringDrawing(
      id: 'fish',
      titleAr: 'السمكة الملوّنة',
      titleEn: 'Rainbow Fish',
      category: ColoringCategory.animals,
      regions: [
        _poly([82, 150, 32, 102, 46, 150, 32, 198]),
        _poly([135, 102, 172, 60, 205, 106]),
        _poly([148, 196, 168, 232, 192, 194]),
        _oval(160, 150, 85, 55),
        _oval(122, 150, 10, 44),
        _oval(155, 150, 10, 50),
        _oval(188, 150, 10, 46),
        _circle(214, 136, 12),
        _circle(217, 136, 5),
        _circle(258, 78, 10),
        _circle(272, 46, 7),
        _circle(248, 28, 5),
      ],
      details: [
        _curve(232, 162, 240, 168, 246, 160),
        _curve(200, 120, 192, 150, 200, 180),
      ],
    );

ColoringDrawing _butterfly() => ColoringDrawing(
      id: 'butterfly',
      titleAr: 'الفراشة الجميلة',
      titleEn: 'Pretty Butterfly',
      category: ColoringCategory.animals,
      regions: [
        _rotOval(98, 108, 56, 44, -0.5),
        _rotOval(202, 108, 56, 44, 0.5),
        _rotOval(110, 192, 42, 34, 0.5),
        _rotOval(190, 192, 42, 34, -0.5),
        _circle(94, 104, 17),
        _circle(206, 104, 17),
        _circle(110, 196, 12),
        _circle(190, 196, 12),
        _circle(70, 128, 8),
        _circle(230, 128, 8),
        _oval(150, 158, 12, 66),
        _circle(150, 84, 16),
        _circle(124, 40, 6),
        _circle(176, 40, 6),
      ],
      details: [
        _curve(145, 70, 138, 50, 126, 44),
        _curve(155, 70, 162, 50, 174, 44),
      ],
    );

ColoringDrawing _turtle() => ColoringDrawing(
      id: 'turtle',
      titleAr: 'السلحفاة الصبورة',
      titleEn: 'Patient Turtle',
      category: ColoringCategory.animals,
      regions: [
        _poly([68, 168, 38, 180, 68, 186]),
        _oval(102, 218, 20, 16),
        _oval(198, 218, 20, 16),
        _oval(246, 160, 30, 23),
        _oval(150, 165, 85, 58),
        _polygon(150, 165, 26, 6, 0),
        _polygon(100, 165, 18, 6, 0),
        _polygon(200, 165, 18, 6, 0),
        _polygon(122, 128, 15, 6, 0),
        _polygon(178, 128, 15, 6, 0),
        _polygon(122, 202, 15, 6, 0),
        _polygon(178, 202, 15, 6, 0),
        _circle(256, 152, 5),
      ],
      details: [
        _curve(250, 170, 260, 176, 270, 166),
      ],
    );

ColoringDrawing _owl() => ColoringDrawing(
      id: 'owl',
      titleAr: 'البومة الحكيمة',
      titleEn: 'Wise Owl',
      category: ColoringCategory.animals,
      regions: [
        _poly([95, 108, 98, 58, 132, 96]),
        _poly([205, 108, 202, 58, 168, 96]),
        _oval(150, 172, 70, 86),
        _oval(150, 200, 45, 55),
        _rotOval(84, 186, 20, 50, 0.2),
        _rotOval(216, 186, 20, 50, -0.2),
        _rect(36, 252, 228, 16, 8),
        _oval(128, 254, 14, 9),
        _oval(172, 254, 14, 9),
        _circle(122, 134, 26),
        _circle(178, 134, 26),
        _circle(122, 137, 12),
        _circle(178, 137, 12),
        _poly([140, 158, 160, 158, 150, 178]),
      ],
      details: [
        _line([132, 196, 140, 204, 148, 196]),
        _line([152, 196, 160, 204, 168, 196]),
        _line([142, 218, 150, 226, 158, 218]),
      ],
    );

ColoringDrawing _bunny() => ColoringDrawing(
      id: 'bunny',
      titleAr: 'الأرنب والجزرة',
      titleEn: 'Bunny & Carrot',
      category: ColoringCategory.animals,
      regions: [
        _oval(125, 68, 16, 48),
        _oval(175, 68, 16, 48),
        _oval(125, 72, 8, 36),
        _oval(175, 72, 8, 36),
        _oval(150, 232, 56, 50),
        _oval(150, 240, 30, 30),
        _circle(150, 142, 48),
        _oval(132, 132, 6, 8),
        _oval(168, 132, 6, 8),
        _circle(120, 156, 8),
        _circle(180, 156, 8),
        _heart(150, 152, 7),
        _rect(143, 166, 14, 11, 3),
        _poly([222, 282, 240, 196, 262, 202]),
        _poly([246, 198, 238, 170, 254, 194]),
        _poly([254, 200, 270, 176, 262, 204]),
      ],
      details: [
        _line([150, 160, 150, 166]),
        _line([116, 148, 88, 142]),
        _line([184, 148, 212, 142]),
        _line([234, 222, 248, 226]),
        _line([230, 246, 244, 250]),
      ],
    );

ColoringDrawing _flower() {
  final petals = [
    for (var i = 0; i < 8; i++)
      _rotOval(
        150 + 46 * math.cos(i * math.pi / 4),
        112 + 46 * math.sin(i * math.pi / 4),
        26,
        15,
        i * math.pi / 4,
      ),
  ];
  return ColoringDrawing(
    id: 'flower',
    titleAr: 'زهرة الحديقة',
    titleEn: 'Garden Flower',
    category: ColoringCategory.nature,
    regions: [
      _rect(144, 150, 12, 100, 6),
      _rotOval(118, 212, 28, 12, -0.5),
      _rotOval(182, 200, 28, 12, 0.5),
      ...petals,
      _circle(150, 112, 26),
      _poly([108, 252, 192, 252, 180, 294, 120, 294]),
      _rect(100, 240, 100, 16, 4),
    ],
  );
}

ColoringDrawing _sun() => ColoringDrawing(
      id: 'sun',
      titleAr: 'الشمس الضاحكة',
      titleEn: 'Smiling Sun',
      category: ColoringCategory.nature,
      regions: [
        for (var i = 0; i < 12; i++)
          _poly([
            150 + 60 * math.cos(i * math.pi / 6 - 0.16),
            120 + 60 * math.sin(i * math.pi / 6 - 0.16),
            150 + 96 * math.cos(i * math.pi / 6),
            120 + 96 * math.sin(i * math.pi / 6),
            150 + 60 * math.cos(i * math.pi / 6 + 0.16),
            120 + 60 * math.sin(i * math.pi / 6 + 0.16),
          ]),
        _circle(150, 120, 58),
        _circle(124, 136, 9),
        _circle(176, 136, 9),
        _circle(130, 108, 7),
        _circle(170, 108, 7),
        _cloud(64, 248, 1),
        _cloud(236, 256, 0.85),
      ],
      details: [
        _curve(128, 140, 150, 166, 172, 140),
      ],
    );

ColoringDrawing _tree() => ColoringDrawing(
      id: 'tree',
      titleAr: 'شجرة التفاح',
      titleEn: 'Apple Tree',
      category: ColoringCategory.nature,
      regions: [
        _oval(150, 286, 150, 14),
        _poly([134, 288, 166, 288, 160, 168, 140, 168]),
        _union([
          _circle(150, 102, 56),
          _circle(104, 136, 40),
          _circle(196, 136, 40),
          _circle(150, 152, 44),
        ]),
        _oval(150, 232, 7, 11),
        _circle(120, 104, 10),
        _circle(176, 94, 10),
        _circle(150, 146, 10),
        _circle(198, 142, 9),
        _circle(104, 150, 9),
        _circle(262, 36, 22),
      ],
    );

ColoringDrawing _house() => ColoringDrawing(
      id: 'house',
      titleAr: 'بيتي الجميل',
      titleEn: 'My Home',
      category: ColoringCategory.objects,
      regions: [
        _rect(0, 258, 300, 42),
        _poly([130, 258, 170, 258, 186, 300, 114, 300]),
        _rect(194, 58, 24, 52),
        _poly([58, 132, 150, 56, 242, 132]),
        _rect(76, 132, 148, 126),
        _rect(130, 190, 40, 68, 6),
        _rect(90, 150, 32, 30, 3),
        _rect(178, 150, 32, 30, 3),
        _circle(162, 226, 3.5),
        _circle(214, 40, 9),
        _circle(230, 22, 11),
        _circle(150, 104, 12),
      ],
      details: [
        _line([106, 150, 106, 180]),
        _line([90, 165, 122, 165]),
        _line([194, 150, 194, 180]),
        _line([178, 165, 210, 165]),
      ],
    );

ColoringDrawing _rainbow() => ColoringDrawing(
      id: 'rainbow',
      titleAr: 'قوس قزح',
      titleEn: 'Rainbow',
      category: ColoringCategory.nature,
      regions: [
        for (var i = 0; i < 6; i++)
          Path.combine(
            PathOperation.difference,
            _semi(150, 214, 132.0 - i * 14),
            _semi(150, 214, 118.0 - i * 14),
          ),
        _semi(150, 214, 48),
        _cloud(48, 222, 1.0),
        _cloud(252, 222, 1.0),
        _star(150, 60, 14, 6, 5),
        _star(60, 60, 10, 4, 5),
        _star(240, 70, 10, 4, 5),
      ],
    );

ColoringDrawing _mushroom() => ColoringDrawing(
      id: 'mushroom',
      titleAr: 'بيت الفطر',
      titleEn: 'Mushroom House',
      category: ColoringCategory.nature,
      regions: [
        _rect(0, 262, 300, 38),
        _rect(114, 166, 72, 100, 18),
        Path()
          ..moveTo(44, 176)
          ..arcTo(Rect.fromCenter(center: const Offset(150, 176), width: 212, height: 172), math.pi, math.pi, false)
          ..close(),
        _circle(100, 136, 14),
        _circle(150, 110, 17),
        _circle(202, 140, 13),
        _circle(124, 162, 8),
        _circle(178, 164, 8),
        _rect(135, 214, 30, 52, 14),
        _circle(150, 192, 9),
        _circle(40, 250, 10),
        _circle(262, 250, 10),
      ],
      details: [
        _line([40, 260, 40, 274]),
        _line([262, 260, 262, 274]),
      ],
    );

ColoringDrawing _robot() => ColoringDrawing(
      id: 'robot',
      titleAr: 'الروبوت الذكي',
      titleEn: 'Smart Robot',
      category: ColoringCategory.characters,
      regions: [
        _circle(150, 36, 9),
        _rect(90, 80, 12, 24, 3),
        _rect(198, 80, 12, 24, 3),
        _rect(100, 54, 100, 80, 14),
        _circle(128, 88, 13),
        _circle(172, 88, 13),
        _circle(128, 88, 5),
        _circle(172, 88, 5),
        _rect(124, 110, 52, 12, 4),
        _rect(138, 134, 24, 14),
        _rect(84, 146, 132, 100, 16),
        _rect(114, 164, 72, 44, 8),
        _heart(150, 184, 12),
        _circle(128, 226, 7),
        _circle(150, 226, 7),
        _circle(172, 226, 7),
        _rect(54, 154, 28, 76, 12),
        _rect(218, 154, 28, 76, 12),
        _rect(104, 246, 32, 42, 6),
        _rect(164, 246, 32, 42, 6),
      ],
      details: [
        _line([150, 45, 150, 54]),
      ],
    );

ColoringDrawing _hero() => ColoringDrawing(
      id: 'hero',
      titleAr: 'البطل الصغير',
      titleEn: 'Little Hero',
      category: ColoringCategory.characters,
      regions: [
        _poly([66, 300, 96, 204, 204, 204, 234, 300]),
        _rect(96, 198, 108, 102, 30),
        _star(150, 250, 24, 10, 5),
        _oval(150, 118, 80, 76),
        _circle(86, 140, 14),
        _circle(214, 140, 14),
        _circle(150, 136, 64),
        _union([
          _circle(104, 88, 24),
          _circle(130, 74, 25),
          _circle(162, 72, 25),
          _circle(192, 84, 24),
          _circle(204, 106, 16),
        ]),
        _oval(128, 134, 8, 10),
        _oval(172, 134, 8, 10),
        _circle(114, 160, 10),
        _circle(186, 160, 10),
        Path()
          ..moveTo(130, 164)
          ..arcTo(Rect.fromCenter(center: const Offset(150, 164), width: 40, height: 32), 0, math.pi, false)
          ..close(),
      ],
      details: [
        _curve(116, 118, 128, 112, 138, 118),
        _curve(162, 118, 172, 112, 184, 118),
      ],
    );

ColoringDrawing _snowman() => ColoringDrawing(
      id: 'snowman',
      titleAr: 'رجل الثلج',
      titleEn: 'Snowman',
      category: ColoringCategory.characters,
      regions: [
        _circle(150, 236, 58),
        _circle(150, 156, 45),
        _circle(150, 90, 32),
        _rect(122, 14, 56, 44, 4),
        _rect(122, 44, 56, 9),
        _rect(108, 56, 84, 10, 4),
        _poly([150, 90, 186, 96, 150, 100]),
        _circle(138, 82, 4),
        _circle(162, 82, 4),
        _rect(114, 116, 72, 14, 7),
        _rect(160, 120, 16, 40, 6),
        _circle(150, 150, 6),
        _circle(150, 172, 6),
        _circle(150, 222, 7),
        _star(46, 44, 11, 4, 6),
        _star(256, 40, 10, 4, 6),
        _star(262, 150, 8, 3, 6),
      ],
      details: [
        _line([106, 152, 58, 122]),
        _line([72, 130, 62, 112]),
        _line([194, 152, 242, 122]),
        _line([228, 130, 238, 112]),
        _curve(138, 104, 150, 112, 162, 104),
      ],
    );

ColoringDrawing _stars() => ColoringDrawing(
      id: 'stars',
      titleAr: 'نجمة الأبطال',
      titleEn: 'Hero Star',
      category: ColoringCategory.shapes,
      regions: [
        _star(150, 156, 112, 46, 5),
        _star(150, 156, 52, 22, 5),
        _circle(150, 156, 11),
        _star(40, 40, 20, 8, 5),
        _star(262, 44, 18, 8, 5),
        _star(44, 262, 18, 8, 5),
        _star(258, 262, 20, 8, 5),
      ],
    );

ColoringDrawing _hearts() => ColoringDrawing(
      id: 'hearts',
      titleAr: 'قلوب المحبة',
      titleEn: 'Loving Hearts',
      category: ColoringCategory.shapes,
      regions: [
        _heart(150, 150, 88),
        _heart(150, 150, 52),
        _heart(150, 150, 20),
        _heart(40, 42, 16),
        _heart(262, 46, 14),
        _heart(46, 262, 14),
        _heart(258, 258, 16),
      ],
    );

ColoringDrawing _shapesMix() => ColoringDrawing(
      id: 'shapes',
      titleAr: 'عالم الأشكال',
      titleEn: 'World of Shapes',
      category: ColoringCategory.shapes,
      regions: [
        _circle(82, 82, 50),
        _rect(172, 36, 92, 92, 6),
        _poly([36, 272, 88, 170, 140, 272]),
        _poly([216, 162, 266, 216, 216, 270, 166, 216]),
        _polygon(150, 158, 22, 6),
        _circle(82, 82, 22),
        _rect(200, 64, 36, 36, 4),
        _circle(216, 216, 14),
        _poly([74, 252, 88, 222, 102, 252]),
      ],
    );

ColoringDrawing _car() => ColoringDrawing(
      id: 'car',
      titleAr: 'السيارة السريعة',
      titleEn: 'Fast Car',
      category: ColoringCategory.objects,
      regions: [
        _rect(0, 238, 300, 62),
        _rect(20, 264, 50, 8, 4),
        _rect(125, 264, 50, 8, 4),
        _rect(230, 264, 50, 8, 4),
        _poly([84, 152, 110, 100, 196, 100, 226, 152]),
        _rect(40, 150, 220, 62, 18),
        _poly([98, 146, 117, 108, 147, 108, 147, 146]),
        _poly([157, 146, 157, 108, 190, 108, 212, 146]),
        _circle(246, 172, 8),
        _rect(42, 166, 10, 14, 3),
        _circle(96, 212, 28),
        _circle(204, 212, 28),
        _circle(96, 212, 11),
        _circle(204, 212, 11),
        _circle(40, 50, 22),
      ],
      details: [
        _line([152, 150, 152, 200]),
        _line([118, 168, 132, 168]),
        _line([170, 168, 184, 168]),
      ],
    );

ColoringDrawing _rocket() => ColoringDrawing(
      id: 'rocket',
      titleAr: 'صاروخ الفضاء',
      titleEn: 'Space Rocket',
      category: ColoringCategory.objects,
      regions: [
        _poly([128, 236, 150, 296, 172, 236]),
        _poly([140, 236, 150, 276, 160, 236]),
        _poly([116, 176, 84, 246, 120, 236]),
        _poly([184, 176, 216, 246, 180, 236]),
        Path()
          ..moveTo(116, 240)
          ..lineTo(116, 124)
          ..cubicTo(116, 84, 136, 50, 150, 32)
          ..cubicTo(164, 50, 184, 84, 184, 124)
          ..lineTo(184, 240)
          ..close(),
        _rect(116, 194, 68, 14),
        _circle(150, 124, 22),
        _circle(150, 124, 14),
        _star(50, 66, 14, 6, 5),
        _star(256, 96, 12, 5, 5),
        _star(58, 196, 10, 4, 5),
        _circle(248, 228, 24),
        _circle(240, 220, 5),
        _circle(256, 236, 4),
      ],
    );

ColoringDrawing _iceCream() => ColoringDrawing(
      id: 'icecream',
      titleAr: 'الآيس كريم',
      titleEn: 'Ice Cream',
      category: ColoringCategory.objects,
      regions: [
        _poly([104, 150, 196, 150, 150, 286]),
        _circle(124, 136, 36),
        _circle(176, 136, 36),
        _circle(150, 92, 40),
        _circle(150, 42, 12),
        _circle(132, 88, 5),
        _circle(166, 78, 5),
        _circle(158, 104, 5),
        _circle(116, 132, 5),
        _circle(186, 130, 5),
      ],
      details: [
        _curve(150, 30, 154, 18, 164, 14),
        _line([122, 178, 168, 222]),
        _line([134, 166, 182, 198]),
        _line([178, 178, 132, 222]),
        _line([166, 166, 118, 198]),
      ],
    );

ColoringDrawing _boat() => ColoringDrawing(
      id: 'boat',
      titleAr: 'المركب الشراعي',
      titleEn: 'Sailboat',
      category: ColoringCategory.objects,
      regions: [
        _circle(56, 56, 26),
        _poly([60, 198, 240, 198, 212, 248, 88, 248]),
        _circle(112, 220, 8),
        _circle(150, 220, 8),
        _circle(188, 220, 8),
        _rect(146, 40, 8, 158),
        _poly([156, 66, 156, 190, 236, 190]),
        _poly([144, 82, 144, 190, 80, 190]),
        _poly([154, 40, 182, 50, 154, 60]),
        Path()
          ..moveTo(0, 240)
          ..quadraticBezierTo(25, 228, 50, 240)
          ..quadraticBezierTo(75, 252, 100, 240)
          ..quadraticBezierTo(125, 228, 150, 240)
          ..quadraticBezierTo(175, 252, 200, 240)
          ..quadraticBezierTo(225, 228, 250, 240)
          ..quadraticBezierTo(275, 252, 300, 240)
          ..lineTo(300, 300)
          ..lineTo(0, 300)
          ..close(),
      ],
      details: [
        _curve(220, 70, 230, 60, 240, 70),
        _curve(240, 70, 250, 60, 260, 70),
        _curve(30, 120, 40, 110, 50, 120),
      ],
    );

ColoringDrawing _balloons() => ColoringDrawing(
      id: 'balloons',
      titleAr: 'بالونات الحفلة',
      titleEn: 'Party Balloons',
      category: ColoringCategory.objects,
      regions: [
        _oval(98, 96, 38, 46),
        _oval(202, 92, 38, 46),
        _oval(150, 136, 40, 48),
        _poly([94, 141, 102, 141, 98, 150]),
        _poly([198, 137, 206, 137, 202, 146]),
        _poly([146, 183, 154, 183, 150, 192]),
        _rect(110, 236, 80, 56, 4),
        _rect(145, 236, 10, 56),
        _circle(138, 230, 10),
        _circle(162, 230, 10),
      ],
      details: [
        _curve(98, 150, 110, 200, 146, 228),
        _curve(202, 146, 190, 200, 154, 228),
        _line([150, 192, 150, 222]),
      ],
    );

/// الرسوماتُ المرسومة باليد كلُّها، بأسمائها.
final Map<String, ColoringDrawing Function()> handDrawnDrawings = {
  'cat': _cat,
  'fish': _fish,
  'butterfly': _butterfly,
  'turtle': _turtle,
  'owl': _owl,
  'bunny': _bunny,
  'flower': _flower,
  'sun': _sun,
  'tree': _tree,
  'rainbow': _rainbow,
  'mushroom': _mushroom,
  'robot': _robot,
  'hero': _hero,
  'snowman': _snowman,
  'stars': _stars,
  'hearts': _hearts,
  'shapes': _shapesMix,
  'house': _house,
  'car': _car,
  'rocket': _rocket,
  'icecream': _iceCream,
  'boat': _boat,
  'balloons': _balloons,
};

// ── الرسوماتُ المولَّدة ───────────────────────────────────────────────

/// ماندالا من بذرة: حلقاتٌ من البتلات والدوائر والنجوم، لا تتكرّر.
ColoringDrawing mandala(int seed) {
  final random = math.Random(seed);
  final n = const [6, 8, 10, 12][random.nextInt(4)];
  const c = 150.0;
  final regions = <Path>[_circle(c, c, 136)];
  final step = 2 * math.pi / n;
  final twist = random.nextBool() ? step / 2 : 0.0;

  // البتلاتُ الكبيرة.
  final outerLen = 34.0 + random.nextInt(10);
  for (var i = 0; i < n; i++) {
    final a = i * step;
    regions.add(_rotOval(c + 98 * math.cos(a), c + 98 * math.sin(a), outerLen, 15.0 + random.nextInt(6), a));
  }
  // حلقةٌ وسطى: دوائرُ أو نجومٌ أو قلوب.
  final middle = random.nextInt(3);
  for (var i = 0; i < n; i++) {
    final a = i * step + twist;
    final x = c + 62 * math.cos(a);
    final y = c + 62 * math.sin(a);
    regions.add(switch (middle) {
      0 => _circle(x, y, 13),
      1 => _star(x, y, 16, 7, 5, a),
      _ => _rotate(_heart(x, y, 12), x, y, a + math.pi / 2),
    });
  }
  // بتلاتٌ صغيرة حول القلب.
  regions.add(_circle(c, c, 40));
  for (var i = 0; i < n; i++) {
    final a = i * step;
    regions.add(_rotOval(c + 26 * math.cos(a), c + 26 * math.sin(a), 12, 6, a));
  }
  regions.add(random.nextBool() ? _star(c, c, 15, 7, n ~/ 2 + 2) : _circle(c, c, 12));
  return ColoringDrawing(
    id: 'mandala:$seed',
    titleAr: 'الماندالا السحرية',
    titleEn: 'Magic Mandala',
    category: ColoringCategory.magic,
    regions: regions,
  );
}

/// حديقةُ أشكالٍ من بذرة: نجومٌ وقلوبٌ ودوائرُ وزهورٌ متناثرة لا تتداخل.
ColoringDrawing shapeGarden(int seed) {
  final random = math.Random(seed);
  final regions = <Path>[];
  final placed = <(double, double, double)>[];
  var attempts = 0;
  while (placed.length < 11 && attempts < 400) {
    attempts++;
    final r = 18.0 + random.nextInt(26);
    final x = r + 6 + random.nextDouble() * (coloringCanvasSize - 2 * r - 12);
    final y = r + 6 + random.nextDouble() * (coloringCanvasSize - 2 * r - 12);
    final clash = placed.any((p) {
      final dx = p.$1 - x;
      final dy = p.$2 - y;
      return math.sqrt(dx * dx + dy * dy) < p.$3 + r + 6;
    });
    if (clash) continue;
    placed.add((x, y, r));
    switch (random.nextInt(6)) {
      case 0:
        regions
          ..add(_circle(x, y, r))
          ..add(_circle(x, y, r * 0.45));
      case 1:
        regions.add(_star(x, y, r, r * 0.45, 5, -math.pi / 2 + random.nextDouble()));
      case 2:
        regions.add(_heart(x, y + r * 0.1, r * 0.82));
      case 3:
        regions.add(_polygon(x, y, r, 3 + random.nextInt(4), random.nextDouble()));
      case 4:
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3;
          regions.add(_circle(x + r * 0.55 * math.cos(a), y + r * 0.55 * math.sin(a), r * 0.42));
        }
        regions.add(_circle(x, y, r * 0.4));
      default:
        regions
          ..add(_rect(x - r * 0.8, y - r * 0.8, r * 1.6, r * 1.6, r * 0.3))
          ..add(_circle(x, y, r * 0.35));
    }
  }
  return ColoringDrawing(
    id: 'garden:$seed',
    titleAr: 'حديقة الأشكال',
    titleEn: 'Shape Garden',
    category: ColoringCategory.magic,
    regions: regions,
  );
}

/// الرسمةُ بمعرّفها — لوحةٌ محفوظةٌ تُفتح من جديد.
ColoringDrawing? coloringDrawingById(String id) {
  final colon = id.indexOf(':');
  if (colon > 0) {
    final seed = int.tryParse(id.substring(colon + 1));
    if (seed == null) return null;
    return switch (id.substring(0, colon)) {
      'mandala' => mandala(seed),
      'garden' => shapeGarden(seed),
      _ => null,
    };
  }
  return handDrawnDrawings[id]?.call();
}

/// مجموعةُ رسوماتٍ لجلسةٍ جديدة.
///
/// [recent] ما عُرض في الجلسات السابقة: لا يعود قبل أن تُعرض الرسوماتُ الأخرى.
/// والمجموعةُ تتنوّع بين الفئات (حيوانٌ وطبيعةٌ وشخصيّةٌ وأشكالٌ وأشياء)،
/// وفي آخرها رسمتان مولَّدتان من بذرةٍ جديدة — لم تُرَيا قط.
List<String> pickColoringSet(math.Random random, {List<String> recent = const [], int handDrawn = 6}) {
  final ids = handDrawnDrawings.keys.toList()..shuffle(random);
  final fresh = ids.where((id) => !recent.contains(id)).toList();
  final pool = fresh.length >= handDrawn ? fresh : [...fresh, ...ids.where((id) => !fresh.contains(id))];
  final picked = <String>[];
  final usedCategories = <ColoringCategory>{};
  // جولةٌ أولى: فئةٌ مختلفةٌ لكل رسمة.
  for (final id in pool) {
    if (picked.length >= handDrawn) break;
    final category = handDrawnDrawings[id]!().category;
    if (usedCategories.add(category)) picked.add(id);
  }
  for (final id in pool) {
    if (picked.length >= handDrawn) break;
    if (!picked.contains(id)) picked.add(id);
  }
  picked
    ..add('mandala:${random.nextInt(1 << 30)}')
    ..add('garden:${random.nextInt(1 << 30)}');
  return picked;
}
