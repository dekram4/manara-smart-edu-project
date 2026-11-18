import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/widgets/arena_widgets.dart';
import 'package:manara_student/src/widgets/duel_tug_of_war.dart';
import 'package:manara_student/src/widgets/duel_versus.dart';

/// مؤثّراتُ حلبة «تحدَّ زملاءك»: تنتهي ولا تدور بلا نهاية، ولا تكسر مقاساً،
/// وشخصياتُها من أصول التطبيق الموجودة فعلاً.
Widget _host(Widget child, {bool still = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: still),
      child: MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 360, child: child)))),
    );

void main() {
  testWidgets('شريطُ الوقت: لونُ ما بقي، وينبض في الثواني الأخيرة ثم يسكن', (tester) async {
    await tester.pumpWidget(_host(const ArenaTimeBar(left: Duration(seconds: 9), window: Duration(seconds: 10))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('arena-beat-9')), findsNothing, reason: 'لا نبضَ والوقتُ واسع');

    await tester.pumpWidget(_host(const ArenaTimeBar(left: Duration(seconds: 2), window: Duration(seconds: 10))));
    expect(find.byKey(const ValueKey('arena-beat-2')), findsOneWidget);
    // ‏النبضةُ تنتهي بانتهاء ثانيتها: لا دورةَ تمنع السكون.
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_host(const ArenaTimeBar(left: Duration(seconds: 1), window: Duration(seconds: 10)), still: true));
    expect(find.byKey(const ValueKey('arena-beat-1')), findsNothing, reason: 'تقليلُ الحركة');
  });

  test('ألوانُ الوقت: أخضرُ في أوّله، وأحمرُ في ثوانيه الأخيرة', () {
    expect(ArenaTimerRing.colorFor(1, urgent: false), const Color(0xFF22C55E));
    expect(ArenaTimerRing.colorFor(0.2, urgent: true), const Color(0xFFF43F5E));
    expect(ArenaTimerRing.colorFor(0.3, urgent: false), isNot(const Color(0xFF22C55E)));
  });

  testWidgets('النقاطُ تصعد و«+N» تطفو فوقها ثم تختفي', (tester) async {
    await tester.pumpWidget(_host(const DuelPointsCounter(points: 10)));
    await tester.pumpAndSettle();
    expect(find.textContaining('+'), findsNothing, reason: 'لا كسبَ عند أوّل رسم');
    await tester.pumpWidget(_host(const DuelPointsCounter(points: 24)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('+14'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('+14'), findsNothing);
    expect(find.text('24'), findsOneWidget);
  });

  testWidgets('شريطُ الزخم: في المنتصف عند التعادل، ويميل إلى المتقدّم', (tester) async {
    expect(DuelMomentumBar.shareOf(0, 0), 0.5);
    expect(DuelMomentumBar.shareOf(30, 10), 0.75);
    await tester.pumpWidget(_host(const DuelMomentumBar(myPoints: 30, rivalPoints: 10)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('duel-momentum')), findsOneWidget);
  });

  testWidgets('موكبُ الشخصيات وشراراتُ الصحيح: حركةٌ واحدةٌ ثم سكون', (tester) async {
    await tester.pumpWidget(_host(const Column(children: [
      ArenaCrowd(),
      SizedBox(height: 60, width: 200, child: ArenaBurst()),
    ])));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNWidgets(ArenaCrowd.defaultAssets.length));
    expect(tester.takeException(), isNull);
  });

  test('شخصياتُ الموكب من أصول التطبيق الموجودة', () {
    for (final asset in ArenaCrowd.defaultAssets) {
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
  });

  testWidgets('الخيارُ الصحيح يتوهّج وتنفجر منه الشرارات، والخاطئُ بلا شرارات', (tester) async {
    await tester.pumpWidget(_host(const AnswerTile(index: 0, label: 'أ', state: AnswerTileState.correct, onPressed: null)));
    expect(find.byType(ArenaBurst), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(const AnswerTile(index: 1, label: 'ب', state: AnswerTileState.wrong, onPressed: null)));
    expect(find.byType(ArenaBurst), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('مشهدُ المواجهة بالموكب: لا تجاوزَ في هاتفٍ ضيّق', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ArenaVersus(
            myName: 'أنت',
            rivalName: 'روبوت منارة',
            myAppearance: {'avatarId': 'a9'},
            rivalAppearance: {'avatarId': 'a2'},
            rivalPresent: false,
            showCrowd: true,
            footer: Text('…'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(ArenaCrowd), findsOneWidget);
    expect(find.byType(ArenaVsBadge), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('شدُّ الحبل: الرايةُ في المنتصف عند التعادل، وتسير إلى المتقدّم حتى خطّ الفوز', () {
    expect(DuelTugOfWar.shiftOf(0, 0), 0);
    expect(DuelTugOfWar.shiftOf(30, 10), greaterThan(0));
    expect(DuelTugOfWar.shiftOf(10, 30), lessThan(0));
    expect(DuelTugOfWar.shiftOf(40, 0), closeTo(DuelTugOfWar.maxShift, 1e-9));
  });

  Future<double> flagX(WidgetTester tester) async =>
      tester.getCenter(find.byKey(const ValueKey('duel-tug-flag'))).dx;

  testWidgets('شدُّ الحبل: الإجابةُ الصحيحة شدّةٌ تجرّ الرايةَ إلى جهتي ثم تسكن', (tester) async {
    Widget tug(int mine, int theirs) => _host(Directionality(
          textDirection: TextDirection.rtl,
          child: DuelTugOfWar(myPoints: mine, rivalPoints: theirs),
        ));
    await tester.pumpWidget(tug(0, 0));
    await tester.pumpAndSettle();
    final centre = await flagX(tester);
    expect(find.byKey(const ValueKey('duel-tug-me')), findsOneWidget);
    expect(find.byKey(const ValueKey('duel-tug-rival')), findsOneWidget);

    await tester.pumpWidget(tug(14, 0));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('duel-tug-dust-1')), findsOneWidget, reason: 'غبارُ الشدّة');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('duel-tug-dust-1')), findsNothing);
    // جهتي في العربية هي اليمين.
    expect(await flagX(tester), greaterThan(centre));

    await tester.pumpWidget(tug(14, 40));
    await tester.pumpAndSettle();
    expect(await flagX(tester), lessThan(centre));
    expect(tester.takeException(), isNull);
  });

  testWidgets('شدُّ الحبل مع «تقليل الحركة»: لا غبارَ ولا شدّة، والرايةُ في موضعها', (tester) async {
    await tester.pumpWidget(_host(const DuelTugOfWar(myPoints: 0, rivalPoints: 0), still: true));
    await tester.pumpWidget(_host(const DuelTugOfWar(myPoints: 10, rivalPoints: 0), still: true));
    await tester.pump();
    expect(find.byKey(const ValueKey('duel-tug-dust-1')), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
