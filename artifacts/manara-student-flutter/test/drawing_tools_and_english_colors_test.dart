import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/models/study_games.dart';
import 'package:manara_student/src/screens/kindergarten_voice_games.dart';
import 'package:manara_student/src/screens/magic_coloring_screen.dart';
import 'package:manara_student/src/services/coloring_canvas.dart';
import 'package:manara_student/src/services/coloring_drawings.dart';
import 'package:manara_student/src/services/kindergarten_voice_quiz.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:manara_student/src/services/tracing_glyphs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// أدواتُ الرسم الاحترافية، ولعبةُ الألوان بالإنجليزية، وأصواتُ الحروف الإنجليزية.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  group('الفرشُ والأشكال', () {
    test('كلُّ فرشاةٍ وكلُّ شكلٍ يُحفظ ويُستعاد بنوعه', () {
      final c = ColoringController(handDrawnDrawings['cat']!());
      for (final brush in BrushStyle.values) {
        c
          ..beginStroke(const Offset(140, 140), color: const Color(0xFF2563EB), width: 8, brush: brush)
          ..extendStroke(const Offset(160, 150))
          ..extendStroke(const Offset(170, 170))
          ..endStroke();
      }
      for (final shape in ShapeKind.values) {
        c
          ..beginStroke(const Offset(120, 120), color: const Color(0xFFEF4444), width: 6, shape: shape, filled: true)
          ..extendStroke(const Offset(140, 140))
          ..extendStroke(const Offset(180, 175))
          ..endStroke();
      }
      final back = ColoringArtwork.fromJson(jsonDecode(jsonEncode(c.toJson()))) as ColoringController;
      expect(back.strokes.map((s) => s.brush).take(BrushStyle.values.length), BrushStyle.values);
      final shapes = back.strokes.skip(BrushStyle.values.length).toList();
      expect(shapes.map((s) => s.shape), ShapeKind.values);
      // ‏الشكلُ نقطتان: البدايةُ وآخرُ موضعٍ للإصبع.
      expect(shapes.first.points, [const Offset(120, 120), const Offset(180, 175)]);
      expect(shapes.every((s) => s.filled), isTrue);

      // ‏ويُرسم كلُّه بلا خطأ.
      final recorder = ui.PictureRecorder();
      back.painter().paint(Canvas(recorder), const Size(300, 300));
      recorder.endRecording().dispose();
    });

    test('الممحاةُ الذكية تعيد المنطقةَ بيضاء بخطوطها، والتراجعُ يعيدها', () {
      final c = ColoringController(handDrawnDrawings['cat']!());
      final region = c.fillAt(const Offset(150, 150), const Color(0xFFF97316));
      c
        ..beginStroke(const Offset(150, 150), color: const Color(0xFF111827), width: 6)
        ..extendStroke(const Offset(152, 156))
        ..endStroke();
      c.eraseAt(const Offset(150, 150));
      expect(c.fills.containsKey(region), isFalse);
      expect(c.strokes.where((s) => s.region == region), isEmpty);
      c.undo();
      expect(c.fills[region], const Color(0xFFF97316));
    });

    test('اللوحةُ الموسّعة: ثمانون لوناً ودرجةً بلا تكرار', () {
      final colors = MagicColoringScreenState.extendedPalette;
      expect(colors.length, greaterThanOrEqualTo(80));
      expect(colors.toSet().length, colors.length);
      expect(MagicColoringScreenState.brushSizes.length, 5);
    });
  });

  testWidgets('من الشاشة: شكلُ نجمةٍ يُسحب، ولونٌ من اللوحة الموسّعة، والممحاةُ الذكية', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
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

    // ‏لونٌ من اللوحة الموسّعة.
    await tester.ensureVisible(find.byKey(const ValueKey('coloring-more-colors')));
    await tester.tap(find.byKey(const ValueKey('coloring-more-colors')));
    await frames();
    expect(find.byKey(const ValueKey('coloring-palette-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('coloring-extended-14')));
    await frames();
    expect(state.color, MagicColoringScreenState.extendedPalette[14]);

    // ‏الأشكال: نجمةٌ مملوءة.
    await tester.ensureVisible(find.byKey(const ValueKey('coloring-tool-shapes')));
    await tester.tap(find.byKey(const ValueKey('coloring-tool-shapes')));
    await frames(2);
    await tester.ensureVisible(find.byKey(const ValueKey('coloring-shape-star')));
    await tester.tap(find.byKey(const ValueKey('coloring-shape-star')));
    await frames(2);
    await tester.ensureVisible(find.byKey(const ValueKey('coloring-shape-filled')));
    await tester.tap(find.byKey(const ValueKey('coloring-shape-filled')));
    await frames(2);
    final board = find.byKey(const ValueKey('coloring-board'));
    await tester.ensureVisible(board);
    await tester.dragFrom(tester.getCenter(board), const Offset(60, 50));
    await frames(2);
    final controller = state.controller! as ColoringController;
    expect(controller.strokes.last.shape, ShapeKind.star);
    expect(controller.strokes.last.filled, isTrue);
    expect(controller.strokes.last.color, MagicColoringScreenState.extendedPalette[14]);

    // ‏فرشاةُ النيون.
    await tester.ensureVisible(find.byKey(const ValueKey('coloring-tool-brush')));
    await tester.tap(find.byKey(const ValueKey('coloring-tool-brush')));
    await frames(2);
    await tester.tap(find.byKey(const ValueKey('coloring-brush-neon')));
    await frames(2);
    await tester.ensureVisible(board);
    await tester.dragFrom(tester.getCenter(board) + const Offset(-40, -40), const Offset(30, 10));
    await frames(2);
    expect(controller.strokes.last.brush, BrushStyle.neon);

    // ‏الممحاةُ الذكية: لمسةٌ تمحو لونَ ما تحتها.
    await tester.ensureVisible(find.byKey(const ValueKey('coloring-tool-fill')));
    await tester.tap(find.byKey(const ValueKey('coloring-tool-fill')));
    await frames(2);
    await tester.ensureVisible(board);
    final spot = tester.getTopLeft(board) + const Offset(20, 20);
    await tester.tapAt(spot);
    await frames(2);
    expect(controller.fills, isNotEmpty);
    await tester.ensureVisible(find.byKey(const ValueKey('coloring-tool-smartEraser')));
    await tester.tap(find.byKey(const ValueKey('coloring-tool-smartEraser')));
    await frames(2);
    expect(find.byKey(const ValueKey('coloring-smart-eraser-hint')), findsOneWidget);
    await tester.ensureVisible(board);
    await tester.tapAt(tester.getTopLeft(board) + const Offset(20, 20));
    await frames(2);
    expect(controller.fills, isEmpty);
    await tester.pump(const Duration(seconds: 3));
  });

  group('لعبةُ الألوان بالإنجليزية', () {
    test('السؤالُ بالعربية، والخياراتُ وما يُقبل بالإنجليزية', () {
      final round = buildKgVoiceRound(KgVoiceGameKind.colors, math.Random(2), language: KgAnswerLanguage.english);
      for (final q in round) {
        expect(q.promptClip, kgQuestionColorClip);
        expect(q.answer.label, kgColorsEnglish[q.answer.id]!.$1);
        expect(q.judge(q.answer.label), isTrue, reason: q.answer.label);
        expect(q.distractors.every((d) => RegExp(r'^[a-z]+$').hasMatch(d.label)), isTrue);
      }
      final gray = round.firstWhere((q) => q.answer.id == 'gray', orElse: () => round.first);
      if (gray.answer.id == 'gray') expect(gray.judge('gray'), isTrue);
      final black = buildKgVoiceRound(KgVoiceGameKind.colors, math.Random(1), count: 11, language: KgAnswerLanguage.english)
          .firstWhere((q) => q.answer.id == 'black');
      expect(black.judge('black'), isTrue);
      expect(black.judge('black and white'), isFalse, reason: 'لونان');
      expect(kgColorsEnglish.keys.toSet(), kgColors.map((c) => c.option.id).toSet());
    });

    testWidgets('شاشةُ «اختار اللغة»: يُسمع صوتُها، والإنجليزيةُ تعرض الخيارات بالإنجليزية', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final clips = <String>[];
      final spoken = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: KgVoiceGameScreen(
          kind: KgVoiceGameKind.colors,
          random: math.Random(5),
          playToEnd: (clip) async => clips.add(clip),
          stopPrompt: () async {},
          ensureMic: (_) async => true,
          cheer: () async {},
          speak: (text) async => spoken.add(text),
          stopListening: () async {},
          listen: ({required onResult, onPartial}) async => false,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(clips, [kgChooseLanguageClip]);
      expect(find.byKey(const ValueKey('kg-voice-choose-language')), findsOneWidget);
      expect(find.byKey(const ValueKey('kg-voice-start')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('kg-voice-start-en')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final state = tester.state<KgVoiceGameScreenState>(find.byType(KgVoiceGameScreen));
      expect(state.language, KgAnswerLanguage.english);
      final q = state.question!;
      expect(find.text(q.answer.label), findsOneWidget);
      expect(RegExp(r'^[a-z]+$').hasMatch(q.answer.label), isTrue);

      // ‏يجيب باللمس.
      await tester.tap(find.byKey(ValueKey('kg-choice-${q.answer.id}')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(state.score, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });

  test('أصواتُ الحروف الإنجليزية: لكلِّ حرفٍ تسجيلُه في الحزمة، كالحروف العربية', () {
    for (var c = 'a'.codeUnitAt(0); c <= 'z'.codeUnitAt(0); c++) {
      final letter = String.fromCharCode(c);
      final clip = recordedClipFor(TracingItem(text: '${letter.toUpperCase()}$letter', kind: 'letter', lang: 'en'));
      expect(clip, 'audio/letters_en/letter_$letter.mp3');
      final file = File('assets/$clip');
      expect(file.existsSync(), isTrue, reason: letter);
      // ‏تسجيلاتٌ حقيقيّة (ID3)، لا الملفّاتُ المولَّدة القصيرة القديمة.
      expect(file.lengthSync(), greaterThan(20000), reason: letter);
    }
    expect(File('assets/$kgChooseLanguageClip').existsSync(), isTrue);
  });
}
