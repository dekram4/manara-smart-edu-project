import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/screens/magic_coloring_screen.dart';
import 'package:manara_student/src/services/coloring_canvas.dart';
import 'package:manara_student/src/services/coloring_drawings.dart';
import 'package:manara_student/src/services/free_drawing.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:manara_student/src/widgets/student_welcome_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// شريطُ الترحيب، والتراجعُ والإعادة، والأختامُ والتدرّجاتُ السحرية.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  group('شريطُ الترحيب', () {
    testWidgets('اسمُ الطالب الأوّل وصفُّه، بتحيّة الوقت', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StudentWelcomeBanner(
            name: 'سارة محمد العلي',
            grade: 'الصف الرابع',
            now: DateTime(2026, 11, 15, 8),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      final line = tester.widget<Text>(find.byKey(const ValueKey('home-welcome-name'))).data!;
      expect(line, contains('سارة'));
      expect(line, isNot(contains('العلي')));
      expect(line, startsWith('صباح الخير'));
      expect(find.text('🎒 الصف الرابع'), findsOneWidget);

      // ‏ضغطةٌ تقفز بها، ولا تُسقط شيئاً.
      await tester.tap(find.byKey(const ValueKey('home-welcome-banner')));
      await tester.pump(const Duration(milliseconds: 260));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });

    test('الاسمُ المركّب يبقى كاملاً، والمساءُ تحيّتُه أخرى', () {
      expect(StudentWelcomeBanner.firstName('عبد الله أحمد'), 'عبد الله');
      expect(StudentWelcomeBanner.firstName('  '), '');
      expect(StudentWelcomeBanner.greetingFor(DateTime(2026, 1, 1, 19)), 'أهلاً بك يا');
    });

    testWidgets('بلا صفّ: لا شارةَ صفٍّ فارغة', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: StudentWelcomeBanner(name: 'ليان'))));
      await tester.pump();
      expect(find.byKey(const ValueKey('home-welcome-grade')), findsNothing);
    });
  });

  group('التراجعُ والإعادة', () {
    test('الرسمُ الجاهز: يُعاد ما تُرُوجع عنه، وخطوةٌ جديدةٌ تمحو الإعادة', () {
      final c = ColoringController(handDrawnDrawings['cat']!());
      c
        ..beginStroke(const Offset(150, 150), color: const Color(0xFF2563EB), width: 8)
        ..extendStroke(const Offset(160, 160))
        ..endStroke();
      expect(c.canRedo, isFalse);
      c.undo();
      expect(c.strokes, isEmpty);
      expect(c.canRedo, isTrue);
      c.redo();
      expect(c.strokes, hasLength(1));
      expect(c.canRedo, isFalse);
      c.undo();
      c.fillAt(const Offset(150, 150), const Color(0xFFF97316));
      expect(c.canRedo, isFalse, reason: 'خطوةٌ جديدة');
    });

    testWidgets('الرسمُ الحرّ: تراجعٌ ثم إعادة', (tester) async {
      final c = FreeDrawingController();
      addTearDown(c.dispose);
      c
        ..beginStroke(const Offset(40, 40), color: const Color(0xFF111827), width: 6)
        ..extendStroke(const Offset(90, 90))
        ..endStroke();
      c.undo();
      expect(c.isEmpty, isTrue);
      expect(c.canRedo, isTrue);
      c.redo();
      expect(c.isEmpty, isFalse);
      expect(c.canRedo, isFalse);
    });
  });

  group('التدرّجاتُ السحرية والأختام', () {
    test('خطُّ التدرّج يُحفظ برقمه وتتبدّل ألوانُه من التدرّج نفسه', () {
      final c = ColoringController(handDrawnDrawings['cat']!());
      c.beginStroke(const Offset(140, 140), color: const Color(0xFF000000), width: 8, magic: 2, brush: BrushStyle.glitter);
      for (var i = 1; i < 60; i++) {
        c.extendStroke(Offset(140 + i * 2.0, 140 + math.sin(i / 5) * 10));
      }
      c.endStroke();
      final stroke = c.strokes.single;
      expect(stroke.color, isNull, reason: 'التدرّجُ بدل اللون');
      expect(stroke.magic, 2);
      final back = ColoringArtwork.fromJson(jsonDecode(jsonEncode(c.toJson()))) as ColoringController;
      expect(back.strokes.single.magic, 2);
      expect(back.strokes.single.brush, BrushStyle.glitter);
      final colors = magicGradients[2].$2;
      expect(strokeColorAt(stroke, 0), colors.first);
      expect(strokeColorAt(stroke, 1), colors.last);
      expect(strokeColorAt(stroke, 0.5), isNot(colors.first));

      final recorder = ui.PictureRecorder();
      back.painter().paint(Canvas(recorder), const Size(300, 300));
      recorder.endRecording().dispose();
    });

    testWidgets('من الشاشة: ختمُ زهرةٍ بلمسة، وتدرّجٌ سحريّ للفرشاة، وزرُّ الإعادة', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1300));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: MagicColoringScreen(random: math.Random(3), playIntro: () {}, cheer: () async {}),
      ));
      Future<void> frames([int n = 5]) async {
        for (var i = 0; i < n; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await frames();
      final state = tester.state<MagicColoringScreenState>(find.byType(MagicColoringScreen));
      await tester.tap(find.byKey(const ValueKey('coloring-mode-ready')));
      await frames();
      await tester.tap(find.byKey(const ValueKey('coloring-pick-0')));
      await frames();
      final controller = state.controller! as ColoringController;
      final board = find.byKey(const ValueKey('coloring-board'));

      // ‏الختم.
      await tester.ensureVisible(find.byKey(const ValueKey('coloring-tool-stamps')));
      await tester.tap(find.byKey(const ValueKey('coloring-tool-stamps')));
      await frames(2);
      await tester.ensureVisible(find.byKey(const ValueKey('coloring-stamp-flower')));
      await tester.tap(find.byKey(const ValueKey('coloring-stamp-flower')));
      await frames(2);
      await tester.ensureVisible(board);
      await tester.tapAt(tester.getCenter(board));
      await frames(2);
      expect(controller.strokes.last.shape, ShapeKind.flower);
      expect(controller.strokes.last.filled, isTrue);

      // ‏التدرّجُ السحريّ للفرشاة.
      await tester.ensureVisible(find.byKey(const ValueKey('coloring-magic-4')));
      await tester.tap(find.byKey(const ValueKey('coloring-magic-4')));
      await frames(2);
      expect(state.magic, 4);
      expect(state.tool, ColoringTool.stamps, reason: 'الختمُ يقبل التدرّج فيبقى');
      await tester.ensureVisible(find.byKey(const ValueKey('coloring-tool-brush')));
      await tester.tap(find.byKey(const ValueKey('coloring-tool-brush')));
      await frames(2);
      await tester.ensureVisible(board);
      await tester.dragFrom(tester.getCenter(board) + const Offset(-50, -50), const Offset(60, 30));
      await frames(2);
      expect(controller.strokes.last.magic, 4);
      expect(controller.strokes.last.color, isNull);

      // ‏لونٌ عاديّ يلغي التدرّج.
      await tester.ensureVisible(find.byKey(const ValueKey('coloring-color-1')));
      await tester.tap(find.byKey(const ValueKey('coloring-color-1')));
      await frames(2);
      expect(state.magic, isNull);

      // ‏تراجعٌ ثم إعادة من الأزرار.
      final count = controller.strokes.length;
      await tester.tap(find.byKey(const ValueKey('coloring-undo')));
      await frames(2);
      expect(controller.strokes.length, count - 1);
      await tester.tap(find.byKey(const ValueKey('coloring-redo')));
      await frames(2);
      expect(controller.strokes.length, count);
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
