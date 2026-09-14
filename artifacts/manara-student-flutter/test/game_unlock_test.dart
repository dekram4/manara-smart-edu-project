import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/models/student_content.dart';
import 'package:manara_student/src/models/student_gamification.dart';

/// اللعبة رقم N تُفتح عند المستوى N.
///
/// قاعدة تنزلق بمقدار واحد بسهولة، وانزلاقها لا يظهر في الاستعمال العادي:
/// كل لعبة تُفتح قبل أوانها أو بعده بمستوى واحد، ولا شيء يشتكي. الحدود هنا
/// هي ما يثبّتها — وأهمها المستوى 0، إذ كانت اللعبة الأولى تُفتح عنده قبل
/// هذا التغيير.
void main() {
  group('حدود الفتح', () {
    test('المستوى 0: كل الألعاب مقفلة', () {
      expect(GameUnlockRule.unlockedCount(0), 0);
      for (var i = 0; i < 5; i++) {
        expect(GameUnlockRule.isUnlocked(i, 0), isFalse,
            reason: 'اللعبة رقم ${i + 1} يجب أن تكون مقفلة عند المستوى 0');
      }
    });

    test('المستوى 1: الأولى فقط', () {
      expect(GameUnlockRule.unlockedCount(1), 1);
      expect(GameUnlockRule.isUnlocked(0, 1), isTrue);
      expect(GameUnlockRule.isUnlocked(1, 1), isFalse);
    });

    test('المستوى 2: الأولى والثانية', () {
      expect(GameUnlockRule.unlockedCount(2), 2);
      expect(GameUnlockRule.isUnlocked(0, 2), isTrue);
      expect(GameUnlockRule.isUnlocked(1, 2), isTrue);
      expect(GameUnlockRule.isUnlocked(2, 2), isFalse);
    });

    test('المستوى 3: الثلاث الأولى', () {
      expect(GameUnlockRule.unlockedCount(3), 3);
      expect(
        [0, 1, 2].map((i) => GameUnlockRule.isUnlocked(i, 3)).toList(),
        [true, true, true],
      );
      expect(GameUnlockRule.isUnlocked(3, 3), isFalse);
    });

    test('اللعبة رقم N تحتاج المستوى N', () {
      for (var index = 0; index < 8; index++) {
        expect(GameUnlockRule.requiredLevelFor(index), index + 1);
        // مقفلة عند المستوى الذي قبله، مفتوحة عنده بالضبط.
        expect(GameUnlockRule.isUnlocked(index, index), isFalse);
        expect(GameUnlockRule.isUnlocked(index, index + 1), isTrue);
      }
    });
  });

  group('الوصل بنقاط الخبرة', () {
    test('صفر خبرة يعني صفر ألعاب', () {
      final stats = StudentGamification.fromMap({'xp': 0});
      expect(stats.level, 0);
      expect(GameUnlockRule.unlockedCount(stats.level), 0);
      expect(GameUnlockRule.isUnlocked(0, stats.level), isFalse);
    });

    test('100 نقطة تفتح اللعبة الأولى ولا تفتح الثانية', () {
      final stats = StudentGamification.fromMap({'xp': 100});
      expect(stats.level, 1);
      expect(GameUnlockRule.isUnlocked(0, stats.level), isTrue);
      expect(GameUnlockRule.isUnlocked(1, stats.level), isFalse);
    });

    test('99 نقطة لا تفتح شيئاً — الحدّ عند 100 لا قبله', () {
      final stats = StudentGamification.fromMap({'xp': 99});
      expect(stats.level, 0);
      expect(GameUnlockRule.unlockedCount(stats.level), 0);
    });

    test('جوري: 50 جوهرة و100 نقطة ⇒ لعبة واحدة مفتوحة', () {
      // القيم المضبوطة يدوياً في قاعدة البيانات، لتبقى متسقة مع ما يراه
      // الطالب في شاشة الألعاب.
      final stats = StudentGamification.fromMap({'xp': 100, 'gems': 50});
      expect(stats.level, 1);
      expect(GameUnlockRule.unlockedCount(stats.level), 1);
    });
  });

  test('مستوى سالب لا يُنتج عدداً سالباً', () {
    // لا يقع عملياً، لكن العدد يُستعمل فهرساً في قائمة الألعاب.
    expect(GameUnlockRule.unlockedCount(-3), 0);
  });
}
