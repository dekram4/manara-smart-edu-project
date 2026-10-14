import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/widgets/login_scene.dart';

/// مشهدُ الدخول الحيّ: أصولُه المفصولة تطابق الرسمَ الأصلي في السكون، ويبقى
/// الرسمُ الأصلي حيث لا حركة، وكلفةُ الإطار خفيفة.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ui.Image> decode(String asset, int width) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    return (await codec.getNextFrame()).image;
  }

  Future<Uint8List> rgbaOf(ui.Image image) async =>
      (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();

  test('الأصلُ = الأساسُ + الكرةُ + الكتب، في السكون', () async {
    const size = 1024;
    final original = await decode(LivingLoginScene.asset, size);
    final base = await decode(LivingLoginScene.baseAsset, size);
    final globe = await decode(LivingLoginScene.globeAsset, (size * SceneLayout.globeRect.width).round());
    final books = await decode(LivingLoginScene.booksAsset, (size * SceneLayout.booksRect.width).round());

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final full = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
    Rect whole(ui.Image i) => Rect.fromLTWH(0, 0, i.width.toDouble(), i.height.toDouble());
    Rect scaled(Rect f) => Rect.fromLTRB(f.left * size, f.top * size, f.right * size, f.bottom * size);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    canvas.drawImageRect(base, whole(base), full, paint);
    canvas.drawImageRect(globe, whole(globe), scaled(SceneLayout.globeRect), paint);
    canvas.drawImageRect(books, whole(books), scaled(SceneLayout.booksRect), paint);
    final composed = await recorder.endRecording().toImage(size, size);

    final a = await rgbaOf(original);
    final b = await rgbaOf(composed);
    var diff = 0.0;
    var visible = 0;
    for (var i = 0; i < a.length; i += 4) {
      if (a[i + 3] == 0 && b[i + 3] == 0) continue;
      visible++;
      diff += (a[i] - b[i]).abs() + (a[i + 1] - b[i + 1]).abs() + (a[i + 2] - b[i + 2]).abs() + (a[i + 3] - b[i + 3]).abs();
    }
    final perChannel = diff / (visible * 4);
    // فرقٌ من إعادة التحجيم وحدها (الأصولُ بـ٢٠٤٨ والأصلُ بـ٣٠٠٠) لا من القصّ.
    expect(perChannel, lessThan(3.0), reason: 'متوسّطُ الفرق لكل قناة: $perChannel');
  });

  testWidgets('قبل فكّ الأصول: الرسمُ الأصليّ نفسُه', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox(width: 400, height: 400, child: LivingLoginScene())));
    expect(
      find.byWidgetPredicate((w) =>
          w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == LivingLoginScene.asset),
      findsOneWidget,
    );
  });

  testWidgets('«تقليل الحركة»: الرسمُ الأصليّ ولا حركة', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: SizedBox(width: 400, height: 400, child: LivingLoginScene()),
      ),
    ));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('بعد الفكّ: مشهدٌ يتحرّك، ولمسُ المجموعة يُفرحها، والإطارُ خفيف', (tester) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SizedBox(width: 800, height: 800, child: LivingLoginScene())),
    ));
    for (var i = 0; i < 30 && find.byType(Image).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
    }
    expect(find.byType(Image), findsNothing, reason: 'المشهدُ الحيّ حلّ محلّ الصورة');
    await tester.pump(const Duration(milliseconds: 1100));

    // لمسةٌ على الكرة وأخرى على الكتب: لا خطأ، والحركةُ قائمة.
    await tester.tapAt(const Offset(0.10 * 800, 0.60 * 800));
    await tester.tapAt(const Offset(0.85 * 800, 0.72 * 800));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(tester.hasRunningAnimations, isTrue);

    // الأداء: ١٢٠ إطاراً — بناءٌ وتخطيطٌ ورسمٌ — بمتوسّطٍ بعيدٍ عن ١٦ جزءاً.
    final watch = Stopwatch()..start();
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    watch.stop();
    final perFrame = watch.elapsedMicroseconds / 120 / 1000;
    expect(perFrame, lessThan(12), reason: 'متوسّطُ الإطار $perFrame ms');
    await tester.pumpWidget(const SizedBox());
  });
}
