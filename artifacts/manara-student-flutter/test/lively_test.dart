import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/widgets/lively.dart';

/// حركاتُ «لمسة» في البطاقات وشاشة الدخول: ما يقع مع حدثٍ يهدأ بعده، ولا
/// يغيّر شيءٌ منها مقاساً، وتُطفأ كلُّها مع «تقليل الحركة».
void main() {
  Widget host(Widget child, {bool still = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: const Size(400, 800), disableAnimations: still),
          child: Scaffold(body: Center(child: child)),
        ),
      );

  const box = SizedBox(key: ValueKey('box'), width: 120, height: 80);

  testWidgets('الظهورُ المتتابع يتحرّك ثم يهدأ، ولا يغيّر المقاس', (tester) async {
    await tester.pumpWidget(host(const LivelyStagger(index: 2, child: box)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('box'))), const Size(120, 80));
    expect(find.byType(Opacity), findsNothing, reason: 'انتهى: الطفلُ كما هو');
  });

  testWidgets('تموّجُ اللمسة يظهر مع الإصبع ثم يختفي، واللمسةُ تصل لما تحته', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(LivelyTouch(
      child: GestureDetector(onTap: () => taps++, child: Container(width: 160, height: 100, color: Colors.teal)),
    )));
    await tester.tap(find.byType(GestureDetector));
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter.runtimeType.toString() == '_RipplePainter'),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter.runtimeType.toString() == '_RipplePainter'),
      findsNothing,
    );
    expect(taps, 1);
  });

  testWidgets('التوهّجُ عند الاختيار والاهتزازُ عند الخطأ: مرّةً ثم يهدآن', (tester) async {
    Widget answer({required bool right, required bool wrong}) => host(
          LivelyShake(active: wrong, child: LivelyGlow(active: right, child: box)),
        );
    await tester.pumpWidget(answer(right: false, wrong: false));
    await tester.pumpWidget(answer(right: true, wrong: false));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(DecoratedBox), findsOneWidget, reason: 'هالةُ التوهّج');
    await tester.pumpAndSettle();
    expect(find.byType(DecoratedBox), findsNothing);

    await tester.pumpWidget(answer(right: false, wrong: true));
    await tester.pump(const Duration(milliseconds: 60));
    final shaken = tester.getTopLeft(find.byKey(const ValueKey('box')));
    await tester.pumpAndSettle();
    final rest = tester.getTopLeft(find.byKey(const ValueKey('box')));
    expect(shaken.dx, isNot(rest.dx), reason: 'اهتزّ');
    expect(tester.takeException(), isNull);
  });

  testWidgets('تقليلُ الحركة: لا شيء يتحرّك', (tester) async {
    await tester.pumpWidget(host(
      const Column(mainAxisSize: MainAxisSize.min, children: [
        LivelyStagger(index: 3, child: Text('أ')),
        LivelyBob(child: Text('ب')),
        LivelyPulseGlow(child: Text('ج')),
        SizedBox(width: 300, height: 200, child: LoginAmbience()),
      ]),
      still: true,
    ));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  for (final size in const [Size(390, 844), Size(844, 390)]) {
    testWidgets('خلفيةُ الدخول ترسم في ${size.width > size.height ? 'الأفقي' : 'الرأسي'} بلا خطأ', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LoginAmbience())));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 700));
      }
      expect(tester.takeException(), isNull);
      // ولا تستقبل لمسة: ما تحتها يُلمس.
      expect(find.byType(IgnorePointer), findsWidgets);
    });
  }
}
