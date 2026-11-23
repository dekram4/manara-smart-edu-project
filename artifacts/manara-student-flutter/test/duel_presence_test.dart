import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/services/student_duel_service.dart';

/// حضورُ الصفّ («متصلون الآن»): قناةٌ سقطت تُعاد، ولا تبقى معلّقة.
void main() {
  test('منضمّة: تُنعش ولا تُعاد — لا يخرج الطالبُ من الحضور لحظةً', () {
    expect(presenceRepair(joined: true, joining: false), PresenceRepair.refresh);
  });

  test('تنضمّ الآن: تُترك حتى تردّ', () {
    expect(presenceRepair(joined: false, joining: true), PresenceRepair.wait);
  });

  test('مهلةٌ أو خطأٌ أو انقطاع: تُبنى من جديد — لا «لا أحد متصل» إلى الأبد', () {
    expect(presenceRepair(joined: false, joining: false), PresenceRepair.rejoin);
  });

  test('إعادةُ الانضمام: مهلةٌ تطول مع كل تعذّر، ولا تتجاوز نصفَ دقيقة', () {
    expect(presenceRetryDelay(0), const Duration(seconds: 2));
    expect(presenceRetryDelay(1), const Duration(seconds: 4));
    expect(presenceRetryDelay(2), const Duration(seconds: 8));
    expect(presenceRetryDelay(3), const Duration(seconds: 16));
    expect(presenceRetryDelay(4), const Duration(seconds: 30));
    expect(presenceRetryDelay(40), const Duration(seconds: 30));
  });
}
