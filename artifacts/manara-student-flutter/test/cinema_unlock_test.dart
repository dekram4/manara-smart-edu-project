import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/models/cinema_unlock.dart';

void main() {
  test('كل 5 جواهر تفتح فيديو واحداً بالترتيب', () {
    expect(CinemaUnlockRules.unlockedCount(0), 0);
    expect(CinemaUnlockRules.unlockedCount(4), 0);
    expect(CinemaUnlockRules.unlockedCount(5), 1);
    expect(CinemaUnlockRules.unlockedCount(14), 2);
    expect(CinemaUnlockRules.unlockedCount(-3), 0);

    expect(CinemaUnlockRules.isUnlocked(0, 5), isTrue);
    expect(CinemaUnlockRules.isUnlocked(1, 5), isFalse);
    expect(CinemaUnlockRules.isUnlocked(1, 10), isTrue);
  });

  test('ما يحتاجه كل فيديو وما ينقص الطالب', () {
    expect(CinemaUnlockRules.requiredGems(0), 5);
    expect(CinemaUnlockRules.requiredGems(2), 15);
    // معه 7: الثاني يحتاج 10، فينقصه 3 — لا «5» ثابتة.
    expect(CinemaUnlockRules.missingGems(1, 7), 3);
    expect(CinemaUnlockRules.missingGems(2, 7), 8);
    // المفتوح لا ينقصه شيء.
    expect(CinemaUnlockRules.missingGems(0, 7), 0);
  });
}
