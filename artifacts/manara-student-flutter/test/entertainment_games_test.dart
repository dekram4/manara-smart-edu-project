import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:manara_student/src/models/student_content.dart';
import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/services/student_content_service.dart';

/// ألعابُ «عالم الترفيه»: الأربعُ الجديدة، واتجاهُها، ولا خروجَ من التطبيق.
void main() {
  group('الفهرس', () {
    late List<HtmlGame> games;

    setUpAll(() async {
      final service = StudentContentService(
        SupabaseClient('http://127.0.0.1:1', 'test-key'),
      );
      games = await service.fetchGameCatalog();
    });

    HtmlGame byId(String id) => games.firstWhere((game) => game.id == id);

    test('ستُّ ألعاب: القديمتان ثم الأربعُ الجديدة بترتيب فتحها', () {
      expect(games.map((game) => game.id), [
        'd4a3629101574bc39bd8f9d1888ca58e',
        '172e0bd0c40442dbae3d4adb42a98433',
        '73c29ef316be4f0bb6d149d8b5a39ff3',
        '99ba036a4225425794e2c423fbcf9842',
        'd632553ef7264d99aa438310073a6dc3',
        '71b64121c58b4a95b7459e08086dcb00',
      ]);
    });

    test('كلُّ لعبةٍ جديدة بأبعادها الأصلية واتجاهها', () {
      final expected = {
        '73c29ef316be4f0bb6d149d8b5a39ff3': (
          GameOrientation.landscape,
          1280,
          720
        ),
        '99ba036a4225425794e2c423fbcf9842': (
          GameOrientation.portrait,
          1080,
          1920
        ),
        'd632553ef7264d99aa438310073a6dc3': (
          GameOrientation.landscape,
          800,
          600
        ),
        '71b64121c58b4a95b7459e08086dcb00': (
          GameOrientation.landscape,
          960,
          600
        ),
      };
      for (final MapEntry(key: id, value: (orientation, width, height))
          in expected.entries) {
        final game = byId(id);
        expect(game.orientation, orientation, reason: id);
        expect((game.width, game.height), (width, height), reason: id);
      }
      expect(byId('99ba036a4225425794e2c423fbcf9842').aspectRatio,
          closeTo(9 / 16, 1e-9));
      expect(byId('73c29ef316be4f0bb6d149d8b5a39ff3').aspectRatio,
          closeTo(16 / 9, 1e-9));
    });

    test(
        'الأسماءُ حماسيةٌ لا عامّة، والألعابُ من الملفّات لا من صفحة الإعلانات',
        () {
      for (final game in games) {
        expect(isGenericGameTitle(game.title), isFalse, reason: game.title);
        expect(game.title.trim(), isNotEmpty);
        // بلا خادم: ملفُّ اللعبة نفسه — /rvvASMiM/ — لا الغلافُ الإعلاني.
        expect(game.url, contains('/rvvASMiM/${game.id}/index.html'));
      }
    });
  });

  group('النموذج', () {
    test('الاتجاهُ يُقرأ من الخادم، وما لا يُعرف «أيُّ اتجاه»', () {
      expect(GameOrientation.parse('landscape'), GameOrientation.landscape);
      expect(GameOrientation.parse(' portrait '), GameOrientation.portrait);
      expect(GameOrientation.parse(null), GameOrientation.any);
      expect(GameOrientation.parse('sideways'), GameOrientation.any);
    });

    test('النسخةُ تحفظ الاتجاهَ والأبعاد', () {
      const game = HtmlGame(
        id: 'g',
        url: 'u',
        title: 't',
        subtitle: 's',
        orientation: GameOrientation.portrait,
        width: 1080,
        height: 1920,
      );
      final copy = game.copyWith(title: 'x', requiredLevel: 4);
      expect((copy.title, copy.requiredLevel), ('x', 4));
      expect((copy.orientation, copy.width, copy.height),
          (GameOrientation.portrait, 1080, 1920));
      expect(
          const HtmlGame(id: 'g', url: 'u', title: 't', subtitle: 's')
              .aspectRatio,
          isNull);
    });
  });

  group('المستوى وفتح الألعاب', () {
    Map<String, dynamic> row(Map<String, dynamic> data) => {
          'id': 's1',
          'data': {'username': 'joury', 'name': 'جوري', ...data}
        };

    test(
        'المستوى من gamification.xp: 650 → المستوى 6 → الألعابُ الستُّ كلُّها مفتوحة',
        () {
      final profile = StudentProfile.fromStudentRow(row({
        'gamification': {'xp': 650, 'gems': 150, 'level': 6},
      }));
      expect(profile.gamification.level, 6);
      expect(profile.gamification.gems, 150);
      for (var index = 0; index < 6; index++) {
        expect(GameUnlockRule.isUnlocked(index, profile.gamification.level),
            isTrue,
            reason: 'اللعبة ${index + 1}');
      }
      expect(GameUnlockRule.isUnlocked(6, 6), isFalse,
          reason: 'لا لعبةَ سابعة');
    });

    test('حقلُ level لا يُقرأ: المستوى من الخبرة وحدها', () {
      final profile = StudentProfile.fromStudentRow(row({
        'gamification': {'xp': 120, 'level': 6},
      }));
      expect(profile.gamification.level, 1);
    });

    test('level/xp/gems في جذر data — خارج gamification — لا تُقرأ', () {
      final profile = StudentProfile.fromStudentRow(
          row({'level': 6, 'xp': 650, 'gems': 150}));
      expect(profile.gamification.level, 0);
      expect(profile.gamification.xp, 0);
    });
  });
}
