import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/models/card_permissions.dart';
import 'package:manara_student/src/models/student_content.dart';
import 'package:manara_student/src/models/study_games.dart';
import 'package:manara_student/src/widgets/arcade_game_card.dart';
import 'package:manara_student/src/widgets/study_games.dart';

/// قواعدُ دائمة: إعادةُ اللعب لا تكرّر الأسئلة، وصورةُ كلِّ لعبةٍ تلقائية،
/// وقرارُ المعلم الأحدث يصل كلَّ طلابه.
StudyGame _quiz(String suffix) => StudyGame.fromMap({
      'id': 'endless_quiz',
      'game_type': 'endless_quiz',
      'title': 'سباق',
      'instructions': 'أجب',
      'items': {
        'drag_items': [],
        'drop_targets': [],
        'correct_pairs': [],
        'questions': [
          for (var i = 0; i < 4; i++)
            {'kind': 'mcq', 'question': 'سؤال $i$suffix', 'options': ['أ$i', 'ب$i'], 'answer': 'أ$i'},
        ],
      },
      'gems_reward': 5,
      'points_reward': 20,
    })!;

void main() {
  testWidgets('أوّلُ لعبٍ من الحزمة، وكلُّ لعبٍ بعده أسئلةٌ جديدة تتجنّب ما رآه الطالب',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    for (final channel in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final base = _quiz('');
    final calls = <List<String>>[];
    var version = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: StudyGamesTab(
              load: () async => StudyGamesPack(lessonId: 'L1', games: [base]),
              onWin: (_) async => null,
              seenKey: 'study.seen.s1.L1',
              fresh: (b, exclude) async {
                calls.add(exclude);
                version += 1;
                return _quiz('-$version');
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> wait() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> open() async {
      await tester.ensureVisible(find.byKey(const ValueKey('arcade-balloons')));
      await tester.tap(find.byKey(const ValueKey('arcade-balloons')));
      await wait();
      await tester.tap(find.byKey(const ValueKey('game-intro-start')));
      await wait();
    }

    // أوّلُ مرّة: الحزمةُ المحفوظة، بلا طلب.
    await open();
    expect(calls, isEmpty);
    expect(find.textContaining('-1'), findsNothing);

    // الرجوع ثم اللعب ثانيةً: أسئلةٌ جديدة، ومعها ما رآه.
    await tester.tap(find.byType(BackButtonIcon));
    await wait();
    await open();
    expect(calls, isNotEmpty);
    expect(calls.first, containsAll(['سؤال 0', 'سؤال 3']));
    expect(find.textContaining('-1'), findsOneWidget);
  });

  test('صورةُ اللعبة تلقائية: من معرّفها أو من رابطها', () {
    HtmlGame game(String id, String url) => HtmlGame(
          id: id,
          url: url,
          title: 't',
          subtitle: 's',
          requiredLevel: 1,
        );
    const gd = 'c3268ff701f74898b0ee4880fb9193ac';
    expect(gameArtUrl(game(gd, 'x')), 'https://img.gamedistribution.com/$gd-512x512.jpg');
    expect(
      gameArtUrl(game('teacher-game-1', 'https://manara.test/api/game-embed/$gd/index.html')),
      'https://img.gamedistribution.com/$gd-512x512.jpg',
    );
    expect(
      gameArtUrl(game('teacher-game-2', 'https://html5.gamedistribution.com/$gd/?ref=x')),
      'https://img.gamedistribution.com/$gd-512x512.jpg',
    );
    expect(gameArtUrl(game('teacher-game-3', 'https://games.example.com/play/')), isNull);
    // ‏صورةٌ محفوظةٌ بامتداد jpeg («Mine&Build»): هي ما يجرّبه الغلافُ ثانياً.
    expect(
      gameArtJpegUrl('https://img.gamedistribution.com/$gd-512x512.jpg'),
      'https://img.gamedistribution.com/$gd-512x512.jpeg',
    );
  });

  test('القرارُ الأحدث يغلب: إغلاقُ المعلم لصفّه يصل طالباً له استثناءٌ أقدم', () {
    final open = {for (final id in CardPermissionRules.cardIds) id: true};
    final result = CardPermissionRules.effective(
      rules: [
        {
          'scope': 'student',
          'student_id': 's1',
          'cards': open,
          'updated_at': '2026-10-19T21:24:12.701Z',
        },
        {
          'scope': 'class',
          'teacher_id': 't1',
          'grade_id': 'روضة',
          'cards': {'tutor': false, 'meeting': false},
          'updated_at': '2026-10-19T23:18:45.429Z',
        },
      ],
      studentIds: {'s1'},
      grade: 'روضة',
      teacherIdentities: {'t1'},
    );
    expect(result['tutor'], isFalse);
    expect(result['meeting'], isFalse);
    expect(result['quiz'], isTrue);
  });
}
