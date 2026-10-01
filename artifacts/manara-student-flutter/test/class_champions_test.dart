import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/models/student_content.dart';
import 'package:manara_student/src/services/student_leaderboard_service.dart';

LeaderboardEntry mate(String id, {int xp = 0, int gems = 0, String? name}) =>
    LeaderboardEntry(
      id: id,
      name: name ?? id,
      gems: gems,
      xp: xp,
      level: 1,
      rank: 0,
      isMe: false,
    );

void main() {
  group('أبطال الصف', () {
    test('الترتيبُ بمجموع الخبرة والجواهر تنازلياً', () {
      final rows = rankChampions([
        mate('a', xp: 10, gems: 0),
        mate('b', xp: 5, gems: 30),
        mate('c', xp: 20, gems: 5),
        mate('d', xp: 1, gems: 1),
      ]);
      expect(rows.map((r) => r.entry.id), ['b', 'c', 'a', 'd']);
      expect(rows.map((r) => r.score), [35, 25, 10, 2]);
      expect(rows.map((r) => r.rank), [1, 2, 3, 4]);
    });

    test('الأوّل 🥇 والثاني 🥈 والثالث 🥉، وبقيةُ الصفّ بلا وسام', () {
      final rows = rankChampions([
        for (var i = 0; i < 5; i++) mate('s$i', xp: 100 - i),
      ]);
      expect(rows.map((r) => r.medal), ['🥇', '🥈', '🥉', null, null]);
    });

    test('المتساويان في المجموع يشتركان في المركز، والذي يليهما بعددِ من سبقه',
        () {
      final rows = rankChampions([
        mate('a', xp: 10, gems: 10),
        mate('b', xp: 15, gems: 5),
        mate('c', xp: 1),
      ]);
      expect(rows.map((r) => r.rank), [1, 1, 3]);
      expect(rows.map((r) => r.medal), ['🥇', '🥇', '🥉']);
    });

    test('التساوي ثابت: الجواهرُ ثم الخبرةُ ثم الاسمُ — بأيّ ترتيبٍ وصل', () {
      final input = [
        mate('z', xp: 10, gems: 10, name: 'ب'),
        mate('y', xp: 5, gems: 15, name: 'ج'),
        mate('x', xp: 10, gems: 10, name: 'أ'),
      ];
      final once = rankChampions(input).map((r) => r.entry.id).toList();
      final again =
          rankChampions(input.reversed).map((r) => r.entry.id).toList();
      expect(once, ['y', 'x', 'z']);
      expect(again, once);
    });

    test('صفٌّ فارغ: لا أبطال', () {
      expect(rankChampions(const []), isEmpty);
    });
  });

  group('أسماءُ الألعاب', () {
    test('الأسماءُ العامّة تُعرف لتُستبدل', () {
      for (final title in [
        'لعبة تعليمية',
        'اللعبة 3',
        'لعبة ٢',
        'لعبة',
        'Game 2',
        'learning game',
        'Lesson game',
        '  لعبة   تفاعلية  ',
      ]) {
        expect(isGenericGameTitle(title), isTrue, reason: title);
      }
    });

    test('اسمٌ سمّاه المعلّمُ يبقى', () {
      for (final title in [
        'لعبة الكسور العجيبة',
        'مطابقة الحيوانات',
        'تحدي الأبطال',
        'Fraction Hunters',
        'Game of fractions',
      ]) {
        expect(isGenericGameTitle(title), isFalse, reason: title);
      }
    });
  });
}
