import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/theme/motion.dart';

/// مواصفة الحركة (LAMSA_ANIMATION_SPEC.md): الأرقام كما كُتبت، وكلُّ مشهدٍ
/// يعمل في الوضعين الرأسي والأفقي بلا فيضان.
void main() {
  const portrait = Size(390, 844);
  const landscape = Size(844, 390);

  Future<void> pumpAt(WidgetTester tester, Size size, Widget child) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  test('المدد والمنحنيات بأرقام المواصفة', () {
    expect(MotionDurations.morph.inMilliseconds, 260);
    expect(MotionDurations.avatarStagger.inMilliseconds, 80);
    expect(MotionDurations.avatarFade.inMilliseconds, 200);
    expect(MotionDurations.promoIn.inMilliseconds, 220);
    expect(MotionDurations.promoOut.inMilliseconds, 280);
    expect(MotionDurations.pressIn.inMilliseconds, 80);
    expect(MotionDurations.pressOut.inMilliseconds, 140);
    expect(MotionDurations.overlayOut.inMilliseconds, 240);
    expect(MotionDurations.playerCardIn.inMilliseconds, 220);
    expect(MotionDurations.skeletonToArt.inMilliseconds, 90);

    // backOut(1.4): يبدأ من 0 وينتهي عند 1، ويتجاوز 1 قبل النهاية.
    expect(MotionCurves.backOut.transform(0), closeTo(0, 1e-9));
    expect(MotionCurves.backOut.transform(1), closeTo(1, 1e-9));
    final peak = [for (var i = 1; i < 100; i++) MotionCurves.backOut.transform(i / 100)]
        .reduce((a, b) => a > b ? a : b);
    expect(peak, greaterThan(1.0));
  });

  for (final size in [portrait, landscape]) {
    final shape = size.width > size.height ? 'أفقي' : 'رأسي';

    testWidgets('البطاقةُ تُفتح على محتواها فوراً، وشريطٌ رفيعٌ وحده ما دام يُحمَّل ($shape)', (tester) async {
      var ready = false;
      late StateSetter setReady;
      var taps = 0;
      await pumpAt(
        tester,
        size,
        StatefulBuilder(builder: (context, setState) {
          setReady = setState;
          return MotionSectionOverlay(
            ready: ready,
            child: Center(
              child: TextButton(onPressed: () => taps++, child: const Text('المحتوى')),
            ),
          );
        }),
      );
      // لا غطاءَ ولا شخصيتين تدوران: المحتوى ظاهرٌ ويُلمس من الإطار الأوّل.
      expect(find.text('المحتوى'), findsOneWidget);
      expect(find.byKey(const ValueKey('section-loading')), findsOneWidget);
      await tester.tap(find.text('المحتوى'));
      expect(taps, 1);
      expect(tester.takeException(), isNull);

      setReady(() => ready = true);
      await tester.pump();
      expect(find.byKey(const ValueKey('section-loading')), findsNothing);
      expect(find.text('المحتوى'), findsOneWidget);
    });

    testWidgets('النافذة تدخل في 220ms وتخرج في 280ms ($shape)', (tester) async {
      await pumpAt(
        tester,
        size,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showMotionDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(content: Text('نافذة')),
            ),
            child: const Text('افتح'),
          ),
        ),
      );
      await tester.tap(find.text('افتح'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 221));
      expect(find.text('نافذة'), findsOneWidget);
      expect(tester.takeException(), isNull);

      Navigator.of(tester.element(find.text('نافذة'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('نافذة'), findsOneWidget); // ما زال يتلاشى
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('نافذة'), findsNothing);
    });

    testWidgets('المشغّل: أسودُ 0.7s ثم البطاقة ($shape)', (tester) async {
      await pumpAt(
        tester,
        size,
        const MotionPlayerEntrance(child: Center(child: Text('المشغّل'))),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('المشغّل'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('قائمة الاختيار: غيرُ المختار بنصف شفافية ($shape)', (tester) async {
      await pumpAt(
        tester,
        size,
        Wrap(children: [
          for (var i = 0; i < 4; i++)
            MotionStaggeredPick(
              index: i,
              selected: i == 1,
              child: SizedBox(width: 60, height: 60, child: Text('$i')),
            ),
        ]),
      );
      await tester.pump(const Duration(milliseconds: 600));
      final opacities = tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .map((w) => w.opacity)
          .toList();
      expect(opacities, [0.5, 1.0, 0.5, 0.5]);
    });
  }

}
