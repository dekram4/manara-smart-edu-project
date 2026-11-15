import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/screens/drawing_studio_screen.dart';
import 'package:manara_student/src/services/drawing_studio.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:manara_student/src/widgets/fit_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// «استوديو الرسم»: الطبقات، والفرش، والأشكال، والمسطرة، والتدرّج، والقطّارة،
/// والألوانُ المحفوظة، والتراجعُ والإعادة — ونصوصُ بطاقات المسار كاملة.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  void stroke(StudioController c, StudioPen pen, List<Offset> points) {
    c.begin(points.first, pen);
    for (final p in points.skip(1)) {
      c.move(p);
    }
    c.end();
  }

  group('المحرّك', () {
    test('طبقاتٌ بشفافيتها وظهورها، وتراجعٌ وإعادة، وتُحفظ وتُستعاد', () {
      final c = StudioController();
      stroke(c, const StudioPen(brush: StudioBrush.oil, size: 20), const [Offset(100, 100), Offset(200, 150), Offset(300, 200)]);
      expect(c.addLayer(), isTrue);
      expect(c.active, 1);
      stroke(c, const StudioPen(brush: StudioBrush.watercolor, color: Color(0xFF2563EB)), const [Offset(50, 50), Offset(400, 400)]);
      c.beginOpacityChange();
      c.setOpacity(1, 0.4);
      c.toggleVisible(0);
      expect(c.layers.map((l) => l.ops.length), [1, 1]);
      expect(c.layers[1].opacity, 0.4);
      expect(c.layers[0].visible, isFalse);

      c.undo(); // الظهور
      expect(c.layers[0].visible, isTrue);
      c.undo(); // الشفافية — خطوةٌ واحدة للمنزلق كلِّه
      expect(c.layers[1].opacity, 1);
      c.redo();
      expect(c.layers[1].opacity, 0.4);

      final back = StudioController.fromJson(jsonDecode(jsonEncode(c.toJson())))!;
      expect(back.id, c.id);
      expect(back.layers.length, 2);
      expect(back.layers[1].opacity, 0.4);
      expect(back.layers[0].ops.single.brush, StudioBrush.oil);
      expect(back.layers[1].ops.single.brush, StudioBrush.watercolor);
    });

    test('المسطرة: خطٌّ مستقيم بزوايا كلَّ ١٥°، والأشكالُ والتدرّج نقطتان', () {
      final c = StudioController();
      stroke(c, const StudioPen(ruler: true), const [Offset(100, 100), Offset(150, 130), Offset(300, 112)]);
      final line = c.layers[0].ops.single;
      expect(line.points, hasLength(2));
      final angle = (line.points[1] - line.points[0]).direction;
      expect((angle / (3.141592653589793 / 12) - (angle / (3.141592653589793 / 12)).round()).abs(), lessThan(1e-9));

      stroke(c, const StudioPen(shape: StudioShape.hexagon, filled: true), const [Offset(10, 10), Offset(80, 90), Offset(120, 140)]);
      expect(c.layers[0].ops.last.points, const [Offset(10, 10), Offset(120, 140)]);
      stroke(c, const StudioPen(gradient: true, radial: true), const [Offset(500, 500), Offset(700, 700)]);
      expect(c.layers[0].ops.last.kind, StudioOpKind.gradient);
      // ‏نقرةٌ بلا سحب لا تترك شكلاً فارغاً.
      stroke(c, const StudioPen(shape: StudioShape.star), const [Offset(5, 5)]);
      expect(c.layers[0].ops.length, 3);
    });

    test('كلُّ فرشاةٍ وكلُّ شكلٍ يُرسم بلا خطأ', () {
      final c = StudioController();
      for (final brush in StudioBrush.values) {
        stroke(c, StudioPen(brush: brush, size: 14, opacity: 0.7), [
          for (var i = 0; i < 30; i++) Offset(100 + i * 8.0, 200 + (i % 5) * 6.0),
        ]);
      }
      for (final shape in StudioShape.values) {
        stroke(c, StudioPen(shape: shape, filled: true), const [Offset(100, 600), Offset(300, 800)]);
      }
      expect(c.layers[0].ops.length, StudioBrush.values.length + StudioShape.values.length);
      final recorder = ui.PictureRecorder();
      StudioPainter(c).paint(Canvas(recorder), const Size(400, 400));
      recorder.endRecording().dispose();
    });

    testWidgets('القطّارة تقرأ اللونَ المركَّب، والممحاةُ تمحو طبقتَها وحدها', (tester) async {
      final c = StudioController();
      stroke(c, const StudioPen(shape: StudioShape.rectangle, filled: true, color: Color(0xFFEF4444)),
          const [Offset(100, 100), Offset(500, 500)]);
      c.addLayer();
      stroke(c, const StudioPen(brush: StudioBrush.eraser, size: 60), const [Offset(300, 300), Offset(301, 301)]);
      await tester.runAsync(() async {
        final red = await c.sampleAt(const Offset(300, 300));
        // ‏الممحاةُ في طبقةٍ فارغة: الأحمرُ تحتها باقٍ.
        expect(red, const Color(0xFFEF4444));
        final paper = await c.sampleAt(const Offset(800, 800));
        expect(paper, const Color(0xFFFFFFFF));
      });
    });
  });

  testWidgets('من الشاشة: فرشاةٌ زيتية، وطبقةٌ جديدة، وقطّارة، وألواني، وحفظ', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final saved = <Uint8List>[];
    await tester.pumpWidget(MaterialApp(
      home: DrawingStudioScreen(saveToPhotos: (png) async {
        saved.add(png);
        return true;
      }),
    ));
    await tester.pump();
    final state = tester.state<DrawingStudioScreenState>(find.byType(DrawingStudioScreen));
    final board = find.byKey(const ValueKey('studio-board'));

    await tester.tap(find.byKey(const ValueKey('studio-brush-oil')));
    await tester.pump();
    await tester.dragFrom(tester.getCenter(board), const Offset(120, 40));
    await tester.pump();
    expect(state.controller.layers[0].ops.single.brush, StudioBrush.oil);

    await tester.ensureVisible(find.byKey(const ValueKey('studio-layer-add')));
    await tester.tap(find.byKey(const ValueKey('studio-layer-add')));
    await tester.pump();
    expect(state.controller.layers, hasLength(2));
    expect(state.controller.active, 1);

    // ‏لونٌ سريع ثم حفظُه في «ألواني».
    await tester.ensureVisible(find.byKey(const ValueKey('studio-quick-3')));
    await tester.tap(find.byKey(const ValueKey('studio-quick-3')));
    await tester.pump();
    expect(state.color, DrawingStudioScreenState.quickColors[3]);
    await tester.ensureVisible(find.byKey(const ValueKey('studio-save-color')));
    await tester.tap(find.byKey(const ValueKey('studio-save-color')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(state.customColors.first, DrawingStudioScreenState.quickColors[3]);

    // ‏التراجعُ والإعادة من الأزرار.
    await tester.tap(find.byKey(const ValueKey('studio-undo')));
    await tester.pump();
    expect(state.controller.layers, hasLength(1));
    await tester.tap(find.byKey(const ValueKey('studio-redo')));
    await tester.pump();
    expect(state.controller.layers, hasLength(2));

    // ‏حفظُ المشروع بطبقاته.
    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('studio-save-project')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    final projects = (await SharedPreferences.getInstance()).getStringList(StudioProjects.keyFor('guest'))!;
    expect(jsonDecode(projects.single)['layers'], hasLength(2));

    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('اللوحةُ الدقيقة: رمزٌ سداسيّ يُكتب فيُستخدم لونُه', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: DrawingStudioScreen()));
    await tester.pump();
    final state = tester.state<DrawingStudioScreenState>(find.byType(DrawingStudioScreen));
    await tester.ensureVisible(find.byKey(const ValueKey('studio-color-picker')));
    await tester.tap(find.byKey(const ValueKey('studio-color-picker')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('studio-picker-sheet')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('studio-picker-hex')), '12AB34');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('studio-picker-use')));
    await tester.tap(find.byKey(const ValueKey('studio-picker-use')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(state.color.toARGB32() & 0xFFFFFF, 0x12AB34);
  });

  group('نصوصٌ كاملة', () {
    testWidgets('اسمُ مادةٍ طويل في بطاقةٍ صغيرة: يظهر كلُّه بلا قصّ', (tester) async {
      const label = 'التربية الإسلامية والوطنية';
      await tester.pumpWidget(const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 92,
            height: 48,
            child: FitText(label, textKey: ValueKey('t'), maxLines: 3, maxFont: 16, style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
      ));
      final text = tester.widget<Text>(find.byKey(const ValueKey('t')));
      final painter = TextPainter(
        text: TextSpan(text: label, style: text.style),
        maxLines: 3,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 92);
      expect(painter.didExceedMaxLines, isFalse);
      expect(painter.height, lessThanOrEqualTo(48.5));
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      painter.dispose();
    });
  });
}
