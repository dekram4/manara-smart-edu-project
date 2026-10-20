import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/models/card_permissions.dart';
import 'package:manara_student/src/models/student_content.dart';
import 'package:manara_student/src/models/study_games.dart';
import 'package:manara_student/src/widgets/arcade_game_card.dart';
import 'package:manara_student/src/widgets/study_games.dart';

/// قواعدُ دائمة: إعادةُ اللعب لا تكرّر الأسئلة، وصورةُ كلِّ لعبةٍ تلقائية،
/// وقرارُ المعلم الأحدث يصل كلَّ طلابه.
StudyGame _match(String suffix) => StudyGame.fromMap({
      'id': 'matching',
      'game_type': 'matching',
      'title': 'صِل $suffix',
      'instructions': 'صل',
      'items': {
        'drag_items': ['أ$suffix', 'ب$suffix'],
        'drop_targets': ['١$suffix', '٢$suffix'],
        'correct_pairs': [
          {'item': 'أ$suffix', 'target': '١$suffix'},
          {'item': 'ب$suffix', 'target': '٢$suffix'},
        ],
      },
      'gems_reward': 5,
      'points_reward': 20,
    })!;

void main() {
  testWidgets('أوّلُ لعبٍ من الحزمة، وكلُّ إعادةٍ نسخةٌ جديدة تتجنّب ما رآه الطالب',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final base = _match('');
    final calls = <List<String>>[];
    var version = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: StudyGamesTab(
            load: () async => StudyGamesPack(lessonId: 'L1', games: [base]),
            onWin: (_) async => null,
            seenKey: 'study.seen.s1.L1',
            fresh: (b, exclude) async {
              calls.add(exclude);
              version += 1;
              return _match('-$version');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // أوّلُ مرّة: الحزمةُ المحفوظة، بلا طلب.
    await tester.tap(find.text('صِل'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(find.text('أ'), findsOneWidget);

    // العودة ثم الإعادة: نسخةٌ جديدة، ومعها ما رآه.
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('صِل'));
    await tester.pumpAndSettle();
    expect(calls, hasLength(1));
    expect(calls.single, containsAll(['أ', 'ب']));
    expect(find.text('أ-1'), findsOneWidget);

    // والثالثة تتجنّب الأولى والثانية معاً — محفوظةً على الجهاز.
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('صِل'));
    await tester.pumpAndSettle();
    expect(calls.last, containsAll(['أ', 'ب', 'أ-1', 'ب-1']));
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
