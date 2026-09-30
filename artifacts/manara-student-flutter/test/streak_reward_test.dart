import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/models/student_streak.dart';

/// ما تُوعد به الشاشة يجب أن يكون ما يصرفه الخادم.
///
/// الرقمان مكتوبان في موضعين: `STREAK_MILESTONE` و`GEMS.streakBonus` في
/// `artifacts/api-server/src/routes/studentProgress.ts`، وهنا. ولو
/// افترقا لوعدت الشاشةُ بما لا يُصرَف — يقرأ الطفل «باقٍ لك يومان» فيدخل
/// يومين فلا يجد شيئاً، ولا في الشاشة ما يقول لماذا.
void main() {
  test('الرقمان هما ما في الخادم', () {
    expect(StudentStreak.milestone, 5);
    expect(StudentStreak.bonusGems, 20);
  });

  test('الباقي يعدّ تنازلياً إلى الخامس', () {
    expect(StudentStreak.daysToBonus(1), 4);
    expect(StudentStreak.daysToBonus(2), 3);
    expect(StudentStreak.daysToBonus(3), 2);
    expect(StudentStreak.daysToBonus(4), 1);
  });

  test('والمكافأةُ دوريّة: بعد الخامس ينتظر خمسةً لا يوماً', () {
    // هذا هو الشرط المطلوب بعينه: ٥ و١٠ و١٥، ولا شيء بينها.
    expect(StudentStreak.daysToBonus(5), 5);
    expect(StudentStreak.daysToBonus(6), 4);
    expect(StudentStreak.daysToBonus(7), 3);
    expect(StudentStreak.daysToBonus(8), 2);
    expect(StudentStreak.daysToBonus(9), 1);
    expect(StudentStreak.daysToBonus(10), 5);
    expect(StudentStreak.daysToBonus(14), 1);
    expect(StudentStreak.daysToBonus(15), 5);
  });

  test('ولا يُقال لطفلٍ «باقٍ لك صفر»', () {
    for (var streak = 0; streak <= 40; streak += 1) {
      final left = StudentStreak.daysToBonus(streak);
      expect(left, greaterThanOrEqualTo(1), reason: 'streak=$streak');
      expect(left, lessThanOrEqualTo(StudentStreak.milestone));
    }
  });

  test('ويومُ المكافأة يُعرَف ليُهنَّأ', () {
    expect(StudentStreak.earnedToday(5), isTrue);
    expect(StudentStreak.earnedToday(10), isTrue);
    expect(StudentStreak.earnedToday(15), isTrue);
    for (final streak in [0, 1, 4, 6, 9, 11, 14]) {
      expect(StudentStreak.earnedToday(streak), isFalse, reason: '$streak');
    }
  });

  test('والشريطُ يُعرض تامّاً في يوم المكافأة لا فارغاً', () {
    // من أكمل الخامس يستحقّ أن يراه تامّاً قبل أن يبدأ من جديد — ولو
    // حُسب بالباقي وحده لعاد إلى الصفر في اللحظة التي يُكافأ فيها.
    expect(StudentStreak.progress(5), 1);
    expect(StudentStreak.progress(10), 1);
    expect(StudentStreak.progress(0), 0);
    expect(StudentStreak.progress(1), 0.2);
    expect(StudentStreak.progress(3), closeTo(0.6, 0.0001));
    expect(StudentStreak.progress(7), closeTo(0.4, 0.0001));
  });

  test('وعددٌ سالبٌ لا يُسقط الحساب', () {
    // لا يصل من الخادم، لكنّ شاشةً تنهار على بيانٍ معطوب أسوأ من شاشةٍ
    // تعرض صفراً.
    expect(StudentStreak.daysToBonus(-3), StudentStreak.milestone);
    expect(StudentStreak.progress(-3), 0);
    expect(StudentStreak.earnedToday(-5), isFalse);
  });
}
