import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/services/student_duel_service.dart';
import 'package:manara_student/src/widgets/duel_arenas.dart';
import 'package:manara_student/src/widgets/duel_game_scene.dart';

/// مشاهدُ ألعاب «تحدَّ زملاءك»: الملفُّ المناسبُ لكل لعبةٍ ولعدد اللاعبين.
void main() {
  test('سباقُ الحواجز وشدُّ الحبل بعدد اللاعبين من ٢ إلى ٥', () {
    for (var n = 2; n <= 5; n++) {
      expect(duelGameScene(DuelGame.sprint, n), 'assets/images/duel_games/hurdle-race-$n-players.webp');
      expect(duelGameScene(DuelGame.tug, n), 'assets/images/duel_games/tug-of-war-$n-players.webp');
    }
  });

  test('البستانُ جمعُ الفواكه، والأبراجُ بناءُ الجدار — أيّاً كان العدد', () {
    for (var n = 1; n <= 6; n++) {
      expect(duelGameScene(DuelGame.balloons, n), 'assets/images/duel_games/fruit-collecting.webp');
      expect(duelGameScene(DuelGame.gems, n), 'assets/images/duel_games/wall-building.webp');
    }
  });

  test('عددٌ خارج النطاق: أقربُ مشهدٍ موجود', () {
    expect(duelGameScene(DuelGame.sprint, 0), endsWith('hurdle-race-2-players.webp'));
    expect(duelGameScene(DuelGame.sprint, 1), endsWith('hurdle-race-2-players.webp'));
    expect(duelGameScene(DuelGame.tug, 6), endsWith('tug-of-war-5-players.webp'));
    expect(duelGameScene(DuelGame.tug, 99), endsWith('tug-of-war-5-players.webp'));
    expect(duelGameScene(DuelGame.tug, -3), endsWith('tug-of-war-2-players.webp'));
  });

  test('كلُّ مشهدٍ WebP متحرّكٌ حقيقيٌّ في الأصول، خفيف، ومجلّدُه معلنٌ في pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('    - assets/images/duel_games/'));
    expect(allDuelGameScenes, hasLength(10));
    for (final path in allDuelGameScenes) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: path);
      final head = file.openSync()..setPositionSync(0);
      final magic = String.fromCharCodes(head.readSync(40));
      head.closeSync();
      expect(magic.substring(0, 4), 'RIFF', reason: '$path ليس WebP');
      expect(magic.substring(8, 12), 'WEBP', reason: '$path ليس WebP');
      expect(magic, contains('ANIM'), reason: '$path ليس متحرّكاً');
      expect(file.lengthSync(), lessThan(1024 * 1024), reason: '$path أثقل من ميغابايت');
    }
    // ‏كانت ٧٤ ميغابايت GIF: لا تعود.
    final total = allDuelGameScenes.fold<int>(0, (sum, path) => sum + File(path).lengthSync());
    expect(total, lessThan(10 * 1024 * 1024));
    expect(Directory('assets/images/duel_games').listSync().where((f) => f.path.endsWith('.gif')), isEmpty,
        reason: 'لا GIF قديمٌ يبقى في الحزمة');
  });

  Widget host(Widget child, {bool still = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: still, size: const Size(800, 600)),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );

  testWidgets('الحلبة: مشهدُ اللعبة بعدد لاعبيها، والمساراتُ تحته كما كانت', (tester) async {
    for (final players in [2, 4, 6]) {
      await tester.pumpWidget(host(DuelArena(
        game: DuelGame.sprint,
        mine: 1,
        theirs: 0,
        total: 5,
        live: true,
        myAppearance: null,
        theirAppearance: null,
        opponentName: 'سارة',
        players: [for (var i = 0; i < players; i++) ArenaRacer(name: 'لاعب $i', at: i % 3, appearance: null, me: i == 0)],
      )));
      await tester.pump(const Duration(milliseconds: 50));
      final image = tester.widget<Image>(find.descendant(of: find.byKey(const ValueKey('duel-scene-sprint')), matching: find.byType(Image)));
      final provider = image.image;
      final asset = (provider is ResizeImage ? provider.imageProvider : provider) as AssetImage;
      expect(asset.assetName, duelGameScene(DuelGame.sprint, players));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('مشهدٌ صغيرٌ يُفكّ صغيراً، والموقوفُ (بطاقةٌ غيرُ مختارة) لا يتحرّك', (tester) async {
    await tester.pumpWidget(host(const SizedBox(width: 120, child: DuelGameScene(game: DuelGame.tug, players: 2, height: 64, paused: true))));
    await tester.pump(const Duration(milliseconds: 50));
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<ResizeImage>());
    expect((image.image as ResizeImage).width, lessThan(duelSceneSourceWidth));
    final ticker = tester.widget<TickerMode>(find.ancestor(of: find.byType(Image), matching: find.byType(TickerMode)).first);
    expect(ticker.enabled, isFalse);
  });

  testWidgets('«تقليل الحركة»: المشهدُ صورةٌ ثابتة', (tester) async {
    for (final still in [false, true]) {
      await tester.pumpWidget(host(const SizedBox(width: 300, child: DuelGameScene(game: DuelGame.gems, players: 3)), still: still));
      await tester.pump(const Duration(milliseconds: 50));
      final ticker = tester.widget<TickerMode>(
        find.ancestor(of: find.byType(Image), matching: find.byType(TickerMode)).first,
      );
      expect(ticker.enabled, !still);
    }
    expect(tester.takeException(), isNull);
  });
}
