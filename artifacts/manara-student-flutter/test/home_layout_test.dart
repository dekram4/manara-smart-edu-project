import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/screens/home_layout.dart';

/// يحرس فصلَ الترتيب البصري عن المنطقيّ.
///
/// موزّعُ البطاقات يفتح الشاشةَ بالموضع، والرفُّ يعرض بترتيبٍ آخر. فخللٌ
/// في هذه القائمة لا يرفع خطأً ولا يُرى في تحليل: موضعٌ ساقطٌ يعني بطاقةً
/// لا تظهر أصلاً — أضافها أحدٌ إلى الجدول ونسي هذه — وموضعٌ مكرَّرٌ يعني
/// بطاقتين تفتحان شاشةً واحدة.
void main() {
  test('الترتيبُ البصري يعرض كلَّ بطاقة، مرّةً واحدة', () {
    expect(homeVisualOrder.length, homeModuleCount);
    expect(homeVisualOrder.toSet().length, homeModuleCount,
        reason: 'موضعٌ مكرَّر: بطاقتان تفتحان الشاشة نفسها');
    for (var module = 0; module < homeModuleCount; module += 1) {
      expect(homeVisualOrder, contains(module),
          reason: 'الموضع $module لا يُعرض في الرفّ — بطاقةٌ لا يراها الطفل');
    }
  });

  test('ولا موضعَ خارج الجدول', () {
    for (final module in homeVisualOrder) {
      expect(module, greaterThanOrEqualTo(0));
      expect(module, lessThan(homeModuleCount));
    }
  });

  test('وبطاقتا الروضة بجانب شرح الدرس، ثم المذاكرةُ الذكية', () {
    // شرحُ الدرس الموضعُ صفر، وبطاقتا الروضة ١١ و١٢ — لا تظهر منهما إلا
    // واحدةٌ في درسها — ثم المذاكرةُ العاشر.
    expect(homeVisualOrder.first, 0, reason: 'شرحُ الدرس أوّل الرفّ');
    expect(homeVisualOrder.sublist(1, 3).toSet(), kindergartenModules,
        reason: 'بطاقتا الروضة تليانه');
    expect(homeVisualOrder[3], 10, reason: 'ثم المذاكرةُ الذكية');
  });
}
