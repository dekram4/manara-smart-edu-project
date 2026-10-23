import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:manara_student/src/screens/student_startup_screen.dart';
import 'package:manara_student/src/widgets/living_tile_art.dart';
import 'package:manara_student/src/widgets/splash_intro.dart';

import 'support/fake_video_platform.dart';

/// الافتتاحية والرسومُ الحيّة: تعمل في الوضعين بلا فيضان، وتلتزم خطّ الزمن.
void main() {
  // الافتتاحيةُ المرسومة: ما يُعرض حين لا يُفكّ فيلمُ الترحيب.
  setUp(() => VideoPlayerPlatform.instance = FakeVideoPlatform(fail: true));

  const shapes = {
    'هاتف رأسي': Size(390, 844),
    'هاتف أفقي': Size(844, 390),
    'لوح أفقي': Size(1280, 800),
  };

  test('مراحل خطّ الزمن بأرقام المواصفة', () {
    expect(SplashIntroTimeline.total.inMilliseconds, 4400);
    expect(SplashIntroTimeline.phase(0.9, 0, 1.8), closeTo(0.5, 1e-9));
    expect(SplashIntroTimeline.phase(-1, 0, 1.8), 0);
    expect(SplashIntroTimeline.phase(5, 0, 1.8), 1);
    // الخروجُ الأصلي يبدأ بعد انتهاء القصاصات.
    expect(
      SplashIntroTimeline.spinOutAt.inMilliseconds,
      greaterThanOrEqualTo((SplashIntroTimeline.confettiEnd * 1000).round()),
    );
  });

  for (final entry in shapes.entries) {
    testWidgets('الافتتاحية بمراحلها (${entry.key})', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(
        home: StudentStartupScreen(
          authService: null,
          initializationError: null,
          apiBaseUrl: '',
        ),
      ));
      // إطارٌ يعرف فيه أنّ الفيلمَ لا يُفكّ، فتبدأ الافتتاحية.
      await tester.pump();

      // 1.0s: الأيقوناتُ تهبط.
      await tester.pump(const Duration(milliseconds: 1000));
      expect(tester.takeException(), isNull);
      final icons = find.descendant(
        of: find.byType(SplashIconStorm),
        matching: find.byType(Image),
      );
      expect(icons, findsWidgets);

      // 2.8s: خرجت الأيقونات، والاسمُ يُكتب.
      await tester.pump(const Duration(milliseconds: 1800));
      expect(icons, findsNothing);
      expect(find.byType(SplashWordmarkWipe), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 3.8s: القصاصات حول البطل.
      await tester.pump(const Duration(milliseconds: 1000));
      expect(
        find.descendant(
          of: find.byType(SplashConfettiBurst),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);

      // ثم الخروجُ الأصلي عند السابعة إلى شاشة الدخول.
      await tester.pump(const Duration(milliseconds: 3400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(StudentStartupScreen), findsNothing);
    });

    testWidgets('كل حركات الرسوم الحيّة (${entry.key})', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final side = entry.value.shortestSide * 0.3;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Wrap(children: [
            for (final motion in TileArtMotion.values)
              SizedBox(
                width: side,
                height: side,
                child: LivingTileArt(
                  motion: motion,
                  accent: Colors.teal,
                  index: motion.index,
                  child: const ColoredBox(color: Colors.amber),
                ),
              ),
          ]),
        ),
      ));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 450));
      }
      expect(tester.takeException(), isNull);

      // اللمس يقفز بالرسمة ويُديرها ثم يُعيدها.
      await tester.tap(find.byType(LivingTileArt).first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });
  }

  test('لكل بوابةٍ حركتُها', () {
    expect(tileArtMotionFor('portal.cinema'), TileArtMotion.sway);
    expect(tileArtMotionFor('portal.games'), TileArtMotion.hop);
    expect(tileArtMotionFor('portal.meeting'), TileArtMotion.broadcast);
    expect(tileArtMotionFor('portal.study'), TileArtMotion.flip);
    expect(tileArtMotionFor('portal.tutor'), TileArtMotion.nod);
  });

  testWidgets('حركةٌ أقلّ: الرسمةُ ثابتةٌ كما هي', (tester) async {
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: LivingTileArt(
          motion: TileArtMotion.hop,
          accent: Colors.teal,
          child: Text('رسمة'),
        ),
      ),
    ));
    expect(tester.hasRunningAnimations, isFalse);
    expect(
      find.descendant(of: find.byType(LivingTileArt), matching: find.byType(Transform)),
      findsNothing,
    );
  });
}
