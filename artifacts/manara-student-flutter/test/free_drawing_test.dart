import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/screens/magic_coloring_screen.dart';
import 'package:manara_student/src/services/coloring_canvas.dart';
import 'package:manara_student/src/services/free_drawing.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// «الرسمُ الحرّ»: يرسم الطفلُ خطوطَه، ويملأ ما أغلقه بالدلو، ويحفظ ويرسل.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  group('الدلو على صورة', () {
    /// ورقةٌ بيضاء ١٠×١٠ عليها خطٌّ أسود عموديّ عند العمود ٥.
    Uint8List sheet() {
      final p = Uint8List(10 * 10 * 4);
      for (var i = 0; i < 100; i++) {
        final black = i % 10 == 5;
        p[i * 4] = black ? 0 : 255;
        p[i * 4 + 1] = black ? 0 : 255;
        p[i * 4 + 2] = black ? 0 : 255;
        p[i * 4 + 3] = 255;
      }
      return p;
    }

    int red(Uint8List p, int x, int y) => p[(y * 10 + x) * 4];
    int green(Uint8List p, int x, int y) => p[(y * 10 + x) * 4 + 1];

    test('يملأ حتى الخطّ ولا يعبره', () {
      final p = sheet();
      expect(floodFill(p, 10, 10, 1, 1, const Color(0xFFFF0000)), isTrue);
      for (var y = 0; y < 10; y++) {
        for (var x = 0; x < 5; x++) {
          expect((red(p, x, y), green(p, x, y)), (255, 0), reason: '$x,$y');
        }
        expect(red(p, 5, y), 0, reason: 'الخطُّ باقٍ');
        expect((red(p, 7, y), green(p, 7, y)), (255, 255), reason: 'ما وراء الخطّ أبيض');
      }
    });

    test('اللونُ نفسه أو خارجُ الصورة: لا شيء', () {
      final p = sheet();
      expect(floodFill(p, 10, 10, 1, 1, const Color(0xFFFFFFFF)), isFalse);
      expect(floodFill(p, 10, 10, 20, 1, const Color(0xFFFF0000)), isFalse);
    });
  });

  testWidgets('خطٌّ ثم دلو، ثم حفظٌ واستعادةٌ كما كانت', (tester) async {
    await tester.runAsync(() async {
      final c = FreeDrawingController();
      expect(c.isEmpty, isTrue);
      expect(c.artworkId, startsWith(FreeDrawingController.idPrefix));

      // ‏مربّعٌ مغلقٌ بخطٍّ أسود، ثم الدلوُ في وسطه.
      c
        ..beginStroke(const Offset(100, 100), color: const Color(0xFF111827), width: 6)
        ..extendStroke(const Offset(200, 100))
        ..extendStroke(const Offset(200, 200))
        ..extendStroke(const Offset(100, 200))
        ..extendStroke(const Offset(100, 100))
        ..endStroke();
      expect(await c.fillAtAsync(const Offset(150, 150), const Color(0xFFEF4444)), isTrue);

      Future<List<int>> pixel(FreeDrawingController d, double x, double y) async {
        final data = await d.raster.toByteData();
        final i = ((y * 2).round() * FreeDrawingController.rasterSize + (x * 2).round()) * 4;
        return data!.buffer.asUint8List().sublist(i, i + 3);
      }

      expect(await pixel(c, 150, 150), [0xEF, 0x44, 0x44], reason: 'الداخلُ أحمر');
      expect(await pixel(c, 40, 40), [255, 255, 255], reason: 'الخارجُ أبيض');

      final restored = ColoringArtwork.fromJson(jsonDecode(jsonEncode(c.toJson()))) as FreeDrawingController;
      await restored.ready;
      expect(restored.artworkId, c.artworkId);
      expect(restored.isEmpty, isFalse);
      expect(await pixel(restored, 150, 150), [0xEF, 0x44, 0x44]);

      // ‏التراجعُ في المستعادة: تُعاد رسماً بلا الدلو.
      restored.undo();
      await restored.ready;
      expect(await pixel(restored, 150, 150), [255, 255, 255]);

      final png = await c.toPng(size: 120);
      expect(png!.sublist(1, 4), 'PNG'.codeUnits);
      c.dispose();
      restored.dispose();
    });
  });

  testWidgets('من شاشة الاختيار: رسمٌ حرٌّ يُرسم ويُحفظ في «لوحاتي»', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final events = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: MagicColoringScreen(
        random: math.Random(2),
        playIntro: () {},
        cheer: () async => events.add('cheer'),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    final state = tester.state<MagicColoringScreenState>(find.byType(MagicColoringScreen));

    await tester.tap(find.byKey(const ValueKey('coloring-mode-free')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.mode, ColoringMode.free);
    expect(state.controller, isA<FreeDrawingController>());

    // ‏القلمُ في اليد من البداية: سحبةٌ ترسم خطّاً.
    await tester.drag(find.byKey(const ValueKey('coloring-board')), const Offset(120, 60));
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.controller!.isEmpty, isFalse);

    await tester.tap(find.byKey(const ValueKey('coloring-save')));

    for (var i = 0; i < 6; i++) {

      await tester.pump(const Duration(milliseconds: 100));

    }
    await tester.tap(find.byKey(const ValueKey('coloring-save-device')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(state.celebrating, isTrue);
    expect(events, ['cheer']);
    final saved = (await SharedPreferences.getInstance()).getStringList(ColoringGallery.keyFor('guest'))!;
    expect(jsonDecode(saved.single)['id'], startsWith(FreeDrawingController.idPrefix));

    // ‏«رسمة جديدة» في الرسم الحرّ: ورقةٌ بيضاءُ أخرى.
    await tester.tap(find.byKey(const ValueKey('coloring-next')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.controller, isA<FreeDrawingController>());
    expect(state.controller!.isEmpty, isTrue);

    // ‏الرجوعُ من اللوح إلى شاشة الاختيار.
    await tester.tap(find.byKey(const ValueKey('coloring-back')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.controller, isNull);
    expect(state.mode, isNull);

    // ‏والرسمةُ الحرّة في «لوحاتي» بزرّ حذفٍ ظاهر: يسأل ثم يمحوها من الجهاز.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('coloring-art-delete-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('coloring-art-delete-0')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('coloring-delete-confirm')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect((await SharedPreferences.getInstance()).getStringList(ColoringGallery.keyFor('guest')), isEmpty);
    expect(find.byKey(const ValueKey('coloring-art-delete-0')), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });
}
