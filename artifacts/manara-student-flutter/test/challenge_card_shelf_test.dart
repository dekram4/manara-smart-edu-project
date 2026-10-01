import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/screens/home_layout.dart';
import 'package:manara_student/src/services/student_settings.dart';

/// بطاقةُ «تحدَّ زملاءك» في رفّ الواجهة.
///
/// كانت هنا اختباراتُ الألعاب الأربع (السباق والبالونات وشدّ الحبل والجواهر).
/// وقد صارت المبارزةُ لعبةً واحدةً حيّةً بخياراتٍ على طراز Kahoot — انظر
/// `duel_live_controller_test.dart` و`arena_widgets_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  group('رفُّ الواجهة بعد الدمج', () {
    test('بطاقةٌ واحدةٌ للتحدي لا اثنتان', () {
      // أُضيفت للحلبة بطاقةٌ ثانية في الموضع ١١، فصار في الرفّ موضعان
      // يقولان «تحدّ» ولا يفرّق بينهما طفلٌ بالاسم.
      expect(homeModuleCount, 11);
      expect(homeVisualOrder, hasLength(11));
      expect(homeVisualOrder.toSet(), hasLength(11));
      expect(homeVisualOrder, isNot(contains(11)));
    });

    test('واسمُ البطاقة صار «تحدَّ زملاءك» ومفتاحُها كما كان', () async {
      // ── والمفتاحُ هو ما يحمل الصوتَ والخلفية ──
      // `portal.challenge` هو ما تُقرأ به `challenge_ar.mp3` وصورةُ البطاقة.
      // فتغييرُه إلى `portal.duel` كان سيُفقدها صوتَها بلا خطأٍ يظهر.
      await StudentSettings.setLocale(StudentSettings.arabic);
      expect(tr('portal.challenge'), 'تحدَّ زملاءك');
      expect(StudentStrings.has('portal.challenge.voice'), isTrue);
      // ولا تبقى مفاتيحُ البطاقة المحذوفة.
      expect(StudentStrings.has('portal.duel'), isFalse);
    });
  });
}
