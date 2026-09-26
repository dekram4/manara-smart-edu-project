import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/services/student_leaderboard_service.dart';

/// The board arrives ranked from the server; these cover what the client
/// still decides — reading the shape, and splitting podium from the rest.
void main() {
  Map<String, Object?> person(
    String id,
    String name,
    int gems,
    int rank, {
    bool me = false,
  }) =>
      {
        'id': id,
        'name': name,
        'gems': gems,
        'xp': gems * 10,
        'level': gems ~/ 10,
        'rank': rank,
        'isMe': me,
        'appearance': {'shape': 'fox'},
      };

  group('Leaderboard.fromJson', () {
    test('reads the board the server sent', () {
      final board = Leaderboard.fromJson({
        'entries': [
          person('a', 'أحمد', 50, 1),
          person('b', 'جوري', 30, 2, me: true),
        ],
        'myRank': 2,
        'total': 2,
        'topGems': 50,
        'gemsToNext': 20,
        'listed': true,
      })!;

      expect(board.entries, hasLength(2));
      expect(board.myRank, 2);
      expect(board.total, 2);
      expect(board.gemsToNext, 20);
      expect(board.listed, isTrue);
      expect(board.me?.name, 'جوري');
      expect(board.entries.first.shape, 'fox');
    });

    test('drops an entry with no id rather than showing a blank row', () {
      final board = Leaderboard.fromJson({
        'entries': [
          {'name': 'بلا معرّف', 'gems': 99},
          person('a', 'أحمد', 10, 1),
        ],
        'total': 1,
      })!;
      expect(board.entries, hasLength(1));
      expect(board.entries.single.name, 'أحمد');
    });

    test('survives a payload that is not a board at all', () {
      expect(Leaderboard.fromJson('nonsense'), isNull);
      expect(Leaderboard.fromJson({})!.entries, isEmpty);
    });
  });

  group('podium and rest', () {
    List<Map<String, Object?>> classOf(int n) => [
          for (var index = 0; index < n; index += 1)
            person('s$index', 'طالب $index', 100 - index, index + 1),
        ];

    test('the podium is the first three and the rest is everyone after', () {
      final board = Leaderboard.fromJson({'entries': classOf(15)})!;
      expect(board.podium, hasLength(3));
      expect(board.rest, hasLength(12));
      expect(board.podium.first.name, 'طالب 0');
      expect(board.rest.first.name, 'طالب 3');
    });

    test('a class smaller than a podium does not invent steps', () {
      // فصلٌ فيه طالبان: منصّةٌ بدرجتين، لا ثالثةٌ فارغة.
      final board = Leaderboard.fromJson({'entries': classOf(2)})!;
      expect(board.podium, hasLength(2));
      expect(board.rest, isEmpty);
    });

    test('nobody is me when the server marked nobody', () {
      final board = Leaderboard.fromJson({'entries': classOf(5)})!;
      expect(board.me, isNull);
    });
  });
}
