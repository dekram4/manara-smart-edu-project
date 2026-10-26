import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/models/study_games.dart';
import 'package:manara_student/src/widgets/study_games.dart';
import 'package:manara_student/src/widgets/tracing_shelf_card.dart';

StudyGame _tracing() => StudyGame.fromMap({
      'id': 'tracing',
      'game_type': 'tracing',
      'title': 'تتبّع واكتب!',
      'instructions': 'مرّر إصبعك على النقاط',
      'items': {
        'tracing': [
          {'text': 'ب', 'kind': 'letter', 'lang': 'ar'},
        ],
      },
      'gems_reward': 6,
      'points_reward': 30,
    })!;

StudyGame _matching() => StudyGame.fromMap({
      'id': 'matching',
      'game_type': 'matching',
      'title': 'صِل',
      'instructions': 'صل',
      'items': {
        'drag_items': ['أ', 'ب'],
        'drop_targets': ['١', '٢'],
        'correct_pairs': [
          {'item': 'أ', 'target': '١'},
          {'item': 'ب', 'target': '٢'},
        ],
      },
      'gems_reward': 5,
      'points_reward': 20,
    })!;

Widget _host(Widget child, {bool still = false}) => MaterialApp(
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: still),
        child: inner!,
      ),
      home: Scaffold(body: ListView(children: [child])),
    );

void main() {
  late List<String> haptics;

  setUp(() {
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add('${call.arguments}');
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('العنوانُ والشارةُ والمكافأةُ ظاهرة', (tester) async {
    await tester.pumpWidget(_host(TracingShelfCard(game: _tracing(), onTap: () {}), still: true));
    await tester.pumpAndSettle();
    expect(find.text('تتبّع واكتب!'), findsOneWidget);
    expect(find.text('✨ العب واكسب جواهر!'), findsOneWidget);
    expect(find.text('+6'), findsOneWidget);
    expect(find.text('+30 XP'), findsOneWidget);
    expect(find.text('هيّا نلعب'), findsOneWidget);
  });

  testWidgets('اللمسةُ تُصغّرها وتهتزّ بها اليد، ثم تفتح اللعبة', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      _host(TracingShelfCard(game: _tracing(), onTap: () => opened++), still: true),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.byType(TracingShelfCard)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 0.94);
    expect(haptics, ['HapticFeedbackType.selectionClick']);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(haptics.last, 'HapticFeedbackType.lightImpact');
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.0);
  });

  testWidgets('تنبض ما دامت الحركةُ مسموحة', (tester) async {
    await tester.pumpWidget(_host(TracingShelfCard(game: _tracing(), onTap: () {})));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('«تقليل الحركة»: ساكنةٌ كاملةُ الرسم', (tester) async {
    await tester.pumpWidget(_host(TracingShelfCard(game: _tracing(), onTap: () {}), still: true));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('✨ العب واكسب جواهر!'), findsOneWidget);
  });

  testWidgets('الرفُّ يعرض التتبّعَ ببطاقته الخاصّة، وغيرَه كما كان', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, inner) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: inner!,
        ),
        home: Scaffold(
          body: StudyGamesTab(
            load: () async => StudyGamesPack(lessonId: 'L1', games: [_matching(), _tracing()]),
            onWin: (_) async => null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TracingShelfCard), findsOneWidget);
    expect(find.text('صِل'), findsOneWidget);
  });
}
