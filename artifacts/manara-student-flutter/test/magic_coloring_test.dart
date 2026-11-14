import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/screens/kg_world_screen.dart';
import 'package:manara_student/src/screens/magic_coloring_screen.dart';
import 'package:manara_student/src/services/coloring_canvas.dart';
import 'package:manara_student/src/services/coloring_drawings.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  group('الرسومات', () {
    test('كلُّ رسمةٍ مرسومةٍ باليد لها مناطقُ داخل اللوحة، وتُعرف بمعرّفها', () {
      const slack = 4.0;
      for (final entry in handDrawnDrawings.entries) {
        final drawing = entry.value();
        expect(drawing.id, entry.key);
        expect(drawing.regions, isNotEmpty, reason: entry.key);
        for (final region in drawing.regions) {
          final b = region.getBounds();
          expect(b.left >= -slack && b.top >= -slack, isTrue, reason: '${entry.key}: $b');
          expect(b.right <= coloringCanvasSize + slack && b.bottom <= coloringCanvasSize + slack, isTrue,
              reason: '${entry.key}: $b');
        }
        expect(coloringDrawingById(entry.key)!.regions.length, drawing.regions.length);
      }
      expect(ColoringCategory.values.where((c) => c != ColoringCategory.magic).every(
            (c) => handDrawnDrawings.values.any((d) => d().category == c),
          ), isTrue, reason: 'حيواناتٌ وطبيعةٌ وشخصيّاتٌ وأشكالٌ وأشياء');
    });

    test('المولَّدةُ تُعاد من بذرتها نفسها، وتختلف ببذرةٍ أخرى', () {
      for (final make in [mandala, shapeGarden]) {
        final a = make(42);
        final again = coloringDrawingById(a.id)!;
        expect(again.regions.length, a.regions.length);
        expect(again.regions.first.getBounds(), a.regions.first.getBounds());
        final other = make(43);
        expect(other.id, isNot(a.id));
      }
      expect(coloringDrawingById('mandala:x'), isNull);
      expect(coloringDrawingById('nothing'), isNull);
    });

    test('المنطقةُ العليا تحت الإصبع: عينُ القطة لا رأسُها', () {
      final cat = handDrawnDrawings['cat']!();
      final head = cat.regionAt(const Offset(150, 150));
      final eye = cat.regionAt(const Offset(128, 116));
      expect(head, greaterThanOrEqualTo(0));
      expect(eye, greaterThan(head));
      expect(cat.regionAt(const Offset(4, 4)), -1, reason: 'الخلفية');
    });
  });

  group('مجموعةُ الجلسة', () {
    test('ستُّ رسوماتٍ متنوّعة واثنتان مولَّدتان', () {
      final set = pickColoringSet(math.Random(1));
      expect(set, hasLength(8));
      final hand = set.where((id) => !id.contains(':')).toList();
      expect(hand.toSet(), hasLength(6));
      final categories = {for (final id in hand) handDrawnDrawings[id]!().category};
      expect(categories.length, greaterThanOrEqualTo(4));
      expect(set.where((id) => id.startsWith('mandala:')), hasLength(1));
      expect(set.where((id) => id.startsWith('garden:')), hasLength(1));
    });

    test('ما عُرض أخيراً لا يعود ما دام غيرُه', () {
      final recent = handDrawnDrawings.keys.take(handDrawnDrawings.length - 6).toList();
      for (var seed = 0; seed < 20; seed++) {
        final set = pickColoringSet(math.Random(seed), recent: recent);
        expect(set.where(recent.contains), isEmpty, reason: 'seed $seed');
      }
    });

    test('وجلستان متتاليتان لا تتشابهان', () async {
      final first = pickColoringSet(math.Random(3));
      await ColoringGallery.remember(first);
      final recent = await ColoringGallery.recent();
      final second = pickColoringSet(math.Random(4), recent: recent);
      expect(second.where((id) => !id.contains(':')).where(first.contains), isEmpty);
    });
  });

  group('اللوحة', () {
    test('الدلو، والفرشاة في منطقتها، والتراجع، والحفظ والاستعادة', () {
      final c = ColoringController(handDrawnDrawings['cat']!());
      expect(c.isEmpty, isTrue);
      final head = c.fillAt(const Offset(150, 150), const Color(0xFFF97316));
      expect(c.fills[head], const Color(0xFFF97316));

      c
        ..beginStroke(const Offset(150, 150), color: const Color(0xFF2563EB), width: 12)
        ..extendStroke(const Offset(160, 152))
        ..extendStroke(const Offset(170, 150))
        ..endStroke();
      expect(c.strokes.single.region, head);
      expect(c.strokes.single.points, hasLength(3));

      // ‏الدلوُ على المنطقة نفسها يبدأها من جديد.
      c.fillAt(const Offset(150, 150), const Color(0xFFFACC15));
      expect(c.strokes, isEmpty);
      c.undo();
      expect(c.strokes, hasLength(1));
      expect(c.fills[head], const Color(0xFFF97316));

      c.beginStroke(const Offset(10, 10), color: null, width: 6);
      c.endStroke();
      final restored = ColoringController.fromJson(jsonDecode(jsonEncode(c.toJson())))!;
      expect(restored.drawing.id, 'cat');
      expect(restored.fills, c.fills);
      expect(restored.strokes, hasLength(2));
      expect(restored.strokes.last.color, isNull, reason: 'قوسُ قزح');
      expect(restored.strokes.first.points.last, const Offset(170, 150));

      c.clear();
      expect(c.isEmpty, isTrue);
      c.undo();
      expect(c.isEmpty, isFalse);
    });

    test('«لوحاتي» تحفظ الأحدثَ أوّلاً ولا تتجاوز حدّها', () async {
      for (var i = 0; i < ColoringGallery.maxArtworks + 3; i++) {
        final c = ColoringController(mandala(i))..fillAt(const Offset(150, 150), const Color(0xFFEF4444));
        expect(await ColoringGallery.save(c), isTrue);
      }
      final gallery = await ColoringGallery.load();
      expect(gallery, hasLength(ColoringGallery.maxArtworks));
      expect(gallery.first.drawing.id, 'mandala:${ColoringGallery.maxArtworks + 2}');
    });
  });

  group('الشاشة', () {
    testWidgets('يختار رسمةً، يلوّنها، يحفظها فيسمع «أحسنت يا بطل»', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final events = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: MagicColoringScreen(
          random: math.Random(5),
          playIntro: () => events.add('intro'),
          cheer: () async => events.add('cheer'),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      expect(events, ['intro']);
      final state = tester.state<MagicColoringScreenState>(find.byType(MagicColoringScreen));
      expect(state.drawingSet, hasLength(8));
      expect(find.byKey(const ValueKey('coloring-pick-0')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('coloring-pick-0')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(state.controller, isNotNull);
      expect(state.controller!.drawing.id, state.drawingSet.first);

      // ‏الحفظُ قبل أيّ لون: تنبيهٌ لا احتفال.
      await tester.tap(find.byKey(const ValueKey('coloring-save')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(state.celebrating, isFalse);
      expect(events, isNot(contains('cheer')));

      await tester.tap(find.byKey(const ValueKey('coloring-board')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.controller!.isEmpty, isFalse);

      await tester.tap(find.byKey(const ValueKey('coloring-tool-brush')));
      await tester.pump();
      await tester.drag(find.byKey(const ValueKey('coloring-board')), const Offset(60, 20));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.controller!.strokes, isNotEmpty);

      await tester.tap(find.byKey(const ValueKey('coloring-save')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.celebrating, isTrue);
      expect(events, contains('cheer'));
      expect(find.text('أحسنت يا بطل!'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('coloring.gallery.v1'), hasLength(1));

      await tester.tap(find.byKey(const ValueKey('coloring-next')));
      await tester.pump(const Duration(seconds: 2));
      expect(state.celebrating, isFalse);
      expect(state.controller!.drawing.id, isNot(state.drawingSet.first));
      expect(state.controller!.isEmpty, isTrue);
      await tester.pump(const Duration(seconds: 2));
    });
  });

  test('حذفُ لوحةٍ من «لوحاتي» يمحوها من الجهاز وحدها', () async {
    for (var i = 0; i < 3; i++) {
      await ColoringGallery.save(ColoringController(mandala(i))..fillAt(const Offset(150, 150), const Color(0xFFEF4444)));
    }
    expect(await ColoringGallery.delete(1), isTrue);
    final left = (await ColoringGallery.load()).map((c) => c.drawing.id).toList();
    expect(left, ['mandala:2', 'mandala:0']);
    expect(await ColoringGallery.delete(9), isFalse);
  });

  testWidgets('اللوحةُ تُرسم صورةَ PNG لتُرسل في الدردشة', (tester) async {
    final c = ColoringController(handDrawnDrawings['fish']!())..fillAt(const Offset(160, 150), const Color(0xFF38BDF8));
    final bytes = await tester.runAsync(() => renderColoringPng(c, size: 200));
    expect(bytes, isNotNull);
    expect(bytes!.sublist(1, 4), 'PNG'.codeUnits);
  });

  testWidgets('زرُّ الحذف في «لوحاتي»: يسأل، ثم يمحو اللوحة', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (var i = 0; i < 2; i++) {
      await ColoringGallery.save(ColoringController(mandala(i))..fillAt(const Offset(150, 150), const Color(0xFFEF4444)));
    }
    await tester.pumpWidget(MaterialApp(
      home: MagicColoringScreen(random: math.Random(1), playIntro: () {}, cheer: () async {}),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('coloring-art-delete-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('coloring-art-delete-1')), findsOneWidget);

    // ‏«إلغاء» لا يمحو شيئاً.
    await tester.tap(find.byKey(const ValueKey('coloring-art-delete-0')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('coloring-delete-cancel')));
    await tester.pump(const Duration(milliseconds: 400));
    expect((await ColoringGallery.load()), hasLength(2));

    await tester.tap(find.byKey(const ValueKey('coloring-art-delete-0')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('coloring-delete-confirm')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    final left = await ColoringGallery.load();
    expect(left.map((c) => c.drawing.id), ['mandala:0']);
    expect(find.byKey(const ValueKey('coloring-art-delete-1')), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('«عالم الحكايات والمغامرات»: خمسُ ألعابٍ في بطاقةٍ واحدة', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: KgWorldScreen()));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('عالم الحكايات والمغامرات'), findsOneWidget);
    for (final key in ['coloring', 'colors', 'shapes', 'math', 'general']) {
      expect(find.byKey(ValueKey('kgworld-$key')), findsOneWidget, reason: key);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
