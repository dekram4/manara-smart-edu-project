import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/services/student_duel_service.dart';
import 'package:manara_student/src/widgets/duel_arenas.dart';
import 'package:manara_student/src/widgets/student_avatar_view.dart';

/// حركاتُ الحلبات: كلُّ نقطةٍ تُرى — قفزةٌ وفرقعةٌ وشدٌّ وجوهرةٌ تطير — ولا
/// تُغيّر شيئاً من النتيجة نفسها.
void main() {
  Widget arena(
    DuelGame game, {
    required int mine,
    required int theirs,
    bool finished = false,
    bool still = false,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          disableAnimations: still,
        ),
        child: Scaffold(
          body: Center(
            child: DuelArena(
              game: game,
              mine: mine,
              theirs: theirs,
              total: 5,
              live: !finished,
              finished: finished,
              myAppearance: null,
              theirAppearance: null,
              opponentName: 'سارة',
            ),
          ),
        ),
      ),
    );
  }

  for (final game in DuelGame.values) {
    testWidgets('${game.name}: نقطةٌ لي ثم له، والحركةُ تنتهي بلا أثر',
        (tester) async {
      await tester.pumpWidget(arena(game, mine: 0, theirs: 0));
      await tester.pumpWidget(arena(game, mine: 1, theirs: 0));
      // في منتصف الحركة: ما زالت تتحرّك.
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'الحركةُ تُرى');
      await tester.pumpAndSettle();
      await tester.pumpWidget(arena(game, mine: 1, theirs: 1));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('1/5'), findsNWidgets(2));
    });

    testWidgets('${game.name}: «تقليل الحركة» يحترم', (tester) async {
      await tester.pumpWidget(arena(game, mine: 0, theirs: 0, still: true));
      await tester.pumpWidget(arena(game, mine: 1, theirs: 0, still: true));
      await tester.pumpAndSettle();
      expect(find.text('💨'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  double knotX(WidgetTester tester) => tester.getCenter(find.text('🪢')).dx;

  testWidgets('شدُّ الحبل: النهايةُ تسحبه كلَّه إلى الفائز', (tester) async {
    await tester.pumpWidget(arena(DuelGame.tug, mine: 3, theirs: 2));
    await tester.pumpAndSettle();
    final avatars = find.byType(StudentAvatarView);
    final me = tester.getCenter(avatars.at(0)).dx;
    final rival = tester.getCenter(avatars.at(1)).dx;
    final during = knotX(tester);
    // متقدّمٌ بنقطة: أقربُ إليّ، لكن لم يُحسم.
    expect((during - me).abs(), lessThan((during - rival).abs()));

    await tester
        .pumpWidget(arena(DuelGame.tug, mine: 3, theirs: 2, finished: true));
    await tester.pumpAndSettle();
    final end = knotX(tester);
    expect((end - me).abs(), lessThan((during - me).abs()),
        reason: 'سُحب كلُّه نحوي');
    expect(find.text('👑'), findsOneWidget);
  });

  testWidgets('شدُّ الحبل: فاز زميلي فيُسحب إليه', (tester) async {
    await tester
        .pumpWidget(arena(DuelGame.tug, mine: 1, theirs: 4, finished: true));
    await tester.pumpAndSettle();
    final avatars = find.byType(StudentAvatarView);
    final me = tester.getCenter(avatars.at(0)).dx;
    final rival = tester.getCenter(avatars.at(1)).dx;
    final end = knotX(tester);
    expect((end - rival).abs(), lessThan((end - me).abs()));
  });

  testWidgets('شدُّ الحبل: التعادلُ في المنتصف بلا تاج', (tester) async {
    await tester
        .pumpWidget(arena(DuelGame.tug, mine: 2, theirs: 2, finished: true));
    await tester.pumpAndSettle();
    final avatars = find.byType(StudentAvatarView);
    final me = tester.getCenter(avatars.at(0)).dx;
    final rival = tester.getCenter(avatars.at(1)).dx;
    expect(knotX(tester), moreOrLessEquals((me + rival) / 2, epsilon: 2));
    expect(find.text('👑'), findsNothing);
  });

  testWidgets('الجواهر: الجوهرةُ تطير ثم تختفي', (tester) async {
    await tester.pumpWidget(arena(DuelGame.gems, mine: 0, theirs: 0));
    await tester.pumpWidget(arena(DuelGame.gems, mine: 0, theirs: 1));
    await tester.pump(const Duration(milliseconds: 200));
    // واحدةٌ في جرّته، وواحدةٌ في الهواء.
    expect(find.text('💎'), findsNWidgets(2));
    await tester.pumpAndSettle();
    expect(find.text('💎'), findsOneWidget);
  });

  testWidgets('البالونات: الشظايا تتطاير ثم تهدأ', (tester) async {
    await tester.pumpWidget(arena(DuelGame.balloons, mine: 0, theirs: 0));
    await tester.pumpWidget(arena(DuelGame.balloons, mine: 1, theirs: 0));
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.byWidgetPredicate((w) =>
          w is CustomPaint &&
          w.painter.runtimeType.toString() == '_PopPainter'),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(find.text('💥'), findsOneWidget);
  });
}
