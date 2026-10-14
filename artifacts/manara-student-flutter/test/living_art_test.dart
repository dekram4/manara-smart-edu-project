import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/widgets/living_art.dart';
import 'package:manara_student/src/widgets/lively.dart';
import 'package:manara_student/src/widgets/portal_watermark.dart';

/// الخلفياتُ الحيّة: الجزرُ المنفصلة تُفصل لتطير، وفي السكون الصورةُ
/// الأصلية نفسها، والإطارُ خفيف.
void main() {
  setUp(LivingArt.clearCache);

  test('الفصل: جزيرةٌ صغيرة منفصلة تطير، والرسمُ الأكبر يبقى', () {
    const w = 100, h = 100;
    final px = Uint8List(w * h * 4);
    void fill(int x0, int y0, int x1, int y1) {
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          final i = (y * w + x) * 4;
          px[i] = 200;
          px[i + 3] = 255;
        }
      }
    }

    fill(10, 10, 70, 90); // الرسمُ الأكبر
    fill(80, 20, 90, 30); // طائرٌ صغير بعيدٌ عنه
    final split = splitArt(SplitInput(px, w, h));
    expect(split.flyers, hasLength(1));
    final bird = split.flyers.single;
    expect(bird.left, lessThanOrEqualTo(80));
    expect(bird.left + bird.width, greaterThanOrEqualTo(90));
    // مكانُه في الأساس فارغ، والرسمُ الأكبر كما هو.
    expect(split.base[(25 * w + 85) * 4 + 3], 0);
    expect(split.base[(50 * w + 40) * 4 + 3], 255);
    expect(split.content.left, closeTo(0.10, 0.01));
    expect(split.content.right, closeTo(0.90, 0.01));
  });

  testWidgets('قبل الفصل، ومع «تقليل الحركة»: الصورةُ الأصلية ساكنة', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: SizedBox(width: 300, height: 300, child: LivingArt(asset: PortalBackgrounds.games)),
      ),
    ));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('بعد الفصل: كلُّ خلفيةٍ حيّة، والإطارُ خفيف', (tester) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          Positioned.fill(child: LivingArt(asset: 'assets/images/lighthouse_main_bg.png')),
          Positioned.fill(child: PortalWatermark(asset: PortalBackgrounds.study)),
        ]),
      ),
    ));
    for (var i = 0; i < 60 && find.byType(Image).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
    }
    expect(find.byType(Image), findsNothing, reason: 'الرسمُ الحيّ حلّ محلّ الصورتين');
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);

    final watch = Stopwatch()..start();
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    watch.stop();
    final perFrame = watch.elapsedMicroseconds / 120 / 1000;
    expect(perFrame, lessThan(12), reason: 'متوسّطُ الإطار $perFrame ms');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('طفوُ السبورة: إزاحةٌ لا تتجاوز موضعَ الراحة صعوداً، وتسكن عند الإيقاف', (tester) async {
    const key = ValueKey('board');
    Widget host(bool enabled) => MaterialApp(
          home: LivelyFloatScope(
            enabled: enabled,
            child: const Center(child: LivelyFloating(child: SizedBox(key: key, width: 100, height: 60))),
          ),
        );
    await tester.pumpWidget(host(true));
    final rest = tester.getTopLeft(find.byKey(key));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 400));
      final now = tester.getTopLeft(find.byKey(key));
      expect(now.dy, greaterThanOrEqualTo(rest.dy - 0.001), reason: 'لا يرتفع فوق ما حُسب');
      expect(tester.getSize(find.byKey(key)), const Size(100, 60));
    }
    await tester.pumpWidget(host(false));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(key)), rest);
    expect(tester.hasRunningAnimations, isFalse);
  });
}

