import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/services/student_sound_service.dart';

/// ترحيبُ فتح التطبيق: الملفُّ المورَّد، وترتيبُ الارتداد، وأن يُسمع كاملاً.
///
/// ── لماذا اختبارٌ على السلسلة نفسها ──
/// الترحيبُ يُختار بأوّل موجودٍ في الحزمة. فملفٌّ غاب عن الحزمة — أو قيدٌ
/// نُسي في `pubspec.yaml` — لا يُسقط شيئاً: يرتدّ الاختيارُ إلى القديم فيسمع
/// الطفلُ ترحيباً آخر، ولا خطأَ يظهر في تحليلٍ ولا في بناء. وهو العطبُ
/// المُبلَّغ بعينه: «نسيت استبدال صوت البداية».
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Set<String> bundled;

  setUpAll(() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    bundled = manifest.listAssets().toSet();
  });

  test('المورَّدُ الأحدثُ أوّلُ السلسلة', () {
    expect(StudentSoundService.launchWelcomeClips.first,
        'audio/tarheeeeeeeb.mp3');
  });

  test('وكلُّ مقاطع السلسلة في الحزمة فعلاً', () {
    // لا الأوّلُ وحده: الارتدادُ لا معنى له إن كان ما يُرتدّ إليه غائباً،
    // وقيدُ `assets/audio/` واحدٌ لها كلِّها فسقوطُه يُسقطها معاً.
    for (final clip in StudentSoundService.launchWelcomeClips) {
      expect(bundled, contains('assets/$clip'), reason: clip);
    }
  });

  test('والمختارُ فعلاً هو المورَّد لا ما ارتُدّ إليه', () {
    // ── وهذا هو السؤال الذي يهمّ ──
    // لا «هل الملفُّ موجود» بل «هل هو ما سيُشغَّل». والدالّةُ نفسها تُسأل،
    // على بيان الحزمة الذي يقرؤه التطبيق.
    expect(
      StudentSoundService.launchWelcomeIn(bundled),
      'audio/tarheeeeeeeb.mp3',
      reason: 'الترحيبُ المورَّد ليس هو ما يُشغَّل — سيُسمع القديم',
    );
  });

  test('وارتدادُه إلى ما قبله حين يغيب', () {
    // فسلسلةُ الارتداد تعمل فعلاً: جهازٌ بُني قبل وصول الملف يُرحّب بما
    // عنده لا يصمت — وهو السبب الذي جُعلت له سلسلةً لا ملفاً واحداً.
    expect(
      StudentSoundService.launchWelcomeIn({'assets/audio/tarheeb.mp3'}),
      'audio/tarheeb.mp3',
    );
    // ولا شيءَ في الحزمة: يُرجَع الأصلُ لا `null` — فلا يُنادى تشغيلٌ بلا مقطع.
    expect(
      StudentSoundService.launchWelcomeIn(const {}),
      StudentSoundService.launchWelcomeClips.last,
    );
  });

  test('وخلفيةُ شاشة الدخول في الحزمة', () {
    // تُشغَّل تحت الترحيب على مشغّلٍ ثانٍ. وغيابُها يُفتح شاشةَ الدخول بلا
    // موسيقى، ولا يمسّ الترحيب.
    expect(bundled, contains('assets/audio/signin.mp3'));
  });

  test('وموسيقى مشهد الإقلاع في الحزمة', () {
    expect(bundled, contains('assets/audio/happychild.mp3'));
  });
}
