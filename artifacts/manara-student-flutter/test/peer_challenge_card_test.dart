import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/services/student_settings.dart';
import 'package:manara_student/src/widgets/peer_challenge_card.dart';

/// بطاقةُ «تحدَّ زملاءك» المجسّمة.
///
/// ما يُختبر هنا ما يكسرها بلا خطأٍ يُرى في التطبيق: تجاوزٌ في مقاسٍ لم يُجرَّب،
/// وشخصيةٌ ممطوطة، وضغطةٌ لا تُحسّ، ومكافأةٌ تعِد بغير ما يُصرف.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  Future<void> pumpCard(
    WidgetTester tester, {
    required Size size,
    TextDirection direction = TextDirection.rtl,
    double press = 0,
    double lift = 0,
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: MaterialApp(
          home: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: PeerChallengeCard(
                    title: 'تحدَّ زملاءك',
                    press: press,
                    lift: lift,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  // ── لا تجاوزَ في أيّ مقاس ──
  // الرفُّ يعطي البطاقةَ بين 150×132 و235×178. وما خارجه — أصغرُ وأكبرُ وأعرضُ —
  // لأنّ «في كل مقاس» وعدٌ لا يُختبر بحدوده وحدها.
  const sizes = [
    Size(150, 132),
    Size(174, 132),
    Size(235, 178),
    Size(200, 160),
    Size(120, 100),
    Size(320, 140),
    Size(140, 220),
    Size(400, 300),
  ];

  for (final direction in TextDirection.values) {
    for (final size in sizes) {
      testWidgets('لا تجاوز: ${size.width.toInt()}×${size.height.toInt()} ${direction.name}',
          (tester) async {
        for (final press in [0.0, 1.0, 1.25]) {
          await pumpCard(tester, size: size, direction: direction, press: press, lift: press);
          expect(tester.takeException(), isNull,
              reason: 'press=$press at $size');
        }
      });
    }
  }

  testWidgets('الضغطُ يُنزل الوجهَ إلى الحافّة، والرفعُ يعيده', (tester) async {
    const size = Size(200, 160);

    double faceTop() {
      // الوجهُ هو `Positioned` الثاني في Stack البطاقة: الأوّلُ الحافّة.
      final positioned = tester
          .widgetList<Positioned>(find.descendant(
            of: find.byType(PeerChallengeCard),
            matching: find.byType(Positioned),
          ))
          .toList();
      return positioned[1].top!;
    }

    await pumpCard(tester, size: size, press: 0);
    final up = faceTop();
    await pumpCard(tester, size: size, press: 1);
    final down = faceTop();
    await pumpCard(tester, size: size, press: 1.25);
    final over = faceTop();

    expect(up, 0);
    expect(down, greaterThan(5), reason: 'الضغطةُ لا تُحسّ');
    expect(over, down, reason: 'تجاوزُ النابض لا يُنزل الوجهَ تحت الحافّة');
  });

  testWidgets('الشخصيتان بنسبة صورتهما: ارتفاعٌ وحده، والعرضُ من الصورة',
      (tester) async {
    await pumpCard(tester, size: const Size(235, 178));
    final images = tester
        .widgetList<Image>(find.byType(Image))
        .where((image) => image.image is AssetImage)
        .toList();
    final assets = images.map((image) => (image.image as AssetImage).assetName).toSet();
    expect(assets, containsAll([
      PeerChallengeCard.challengerAsset,
      PeerChallengeCard.rivalAsset,
    ]));
    for (final image in images) {
      expect(image.fit, BoxFit.contain, reason: 'cover يقصّ، وfill يمطّ');
      expect(image.width, isNull, reason: 'عرضٌ مفروضٌ يكسر النسبة');
    }
    // و`Positioned` كلِّ شخصيةٍ يعطيها ارتفاعاً بلا عرض.
    final holders = tester
        .widgetList<Positioned>(find.ancestor(
          of: find.byType(Image),
          matching: find.byType(Positioned),
        ))
        .where((p) => p.height != null);
    expect(holders, isNotEmpty);
    for (final holder in holders) {
      expect(holder.width, isNull);
    }
  });

  testWidgets('المكافأةُ المعروضة هي ما يصرفه الخادم', (tester) async {
    await pumpCard(tester, size: const Size(235, 178));
    expect(duelWinGems, 1, reason: 'DUEL_WIN_GEMS في api-server/src/lib/duel.ts');
    expect(duelWinXp, (duelWinGems * 1.5).round(), reason: 'xpFromGems في الخادم');
    expect(find.text('+$duelWinGems'), findsOneWidget);
    expect(find.text('+$duelWinXp XP'), findsOneWidget);
  });

  testWidgets('شارةُ «فوري» والتشويقُ والسيفان حاضرة', (tester) async {
    await pumpCard(tester, size: const Size(235, 178));
    expect(find.text('تحدٍّ فوري'), findsOneWidget);
    expect(find.text('مين الأسرع؟ ادخل الحلبة!'), findsOneWidget);
    expect(find.text('⚔️'), findsOneWidget);
  });

  testWidgets('تقليلُ الحركة: لا لمعةَ ولا دورةَ تجري', (tester) async {
    await pumpCard(tester, size: const Size(235, 178), reduceMotion: true);
    // بلا متحكّمٍ يدور لا يبقى إطارٌ مجدول.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('والحركةُ العادية تدور، وتتوقّف بالتخلّص من البطاقة', (tester) async {
    await pumpCard(tester, size: const Size(235, 178));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
