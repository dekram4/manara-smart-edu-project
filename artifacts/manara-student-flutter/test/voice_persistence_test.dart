import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/services/student_sound_service.dart';
import 'package:manara_student/src/services/student_voice_service.dart';

/// يحرس العطب المُبلَّغ: ينقطع الصوت بمجرّد تدوير الهاتف.
///
/// ── لماذا اختبارٌ بلا جهاز ──
/// الدوران لا يُحاكى في اختبارٍ نقيّ، ومحرّكا النطق والصوت لا يعملان في
/// بيئة الاختبار. ولكنّ الانقطاع لم يكن في الدوران نفسه، بل في قاعدتين
/// يُقرآن بلا جهاز:
///
///   ١. من يملك محرّكَ النطق: شاشةٌ يُسقطها الدوران، أم التطبيق.
///   ٢. وماذا يعني `inactive` — وهو ما يرِد عند الدوران كما يرِد عند
///      إطفاء الشاشة.
///
/// فهما ما يُختبر هنا.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('محرّكُ النطق لا تملكه شاشة', () {
    test('الخدمةُ مفردةٌ: النداءُ الثاني هو الكائن الأول', () {
      // لو كانت نسخةً لكل شاشة لعاد كلُّ بناءٍ بمحرّكٍ آخر — فينقطع ما
      // كان يُنطق، أو يُترك ناطقاً في الخلفية بلا من يوقفه.
      expect(
        StudentVoiceService.instance,
        same(StudentVoiceService.instance),
      );
    });

    test('ولا تُغلق: إغلاقُها من شاشةٍ يُسكت التطبيق كلَّه', () async {
      // شاشةٌ تُغلقها في `State.dispose` تُغلقها في كل إسقاطٍ لـ`State` —
      // ودورانُ الشاشة أحدُها. فالإغلاقُ خطأُ استدعاءٍ يُقال في وقت
      // التطوير، والمطلوبُ عند المغادرة `stopSpeaking`.
      //
      // و`dispose` غير متزامنة، فخطؤها يُسلَّم في `Future` لا يُرفع
      // مباشرة — فيُنتظر.
      await expectLater(
        StudentVoiceService.instance.dispose(),
        throwsA(isA<AssertionError>()),
      );
    });

    test('والنسخةُ المملوكة تُغلق، فالاختباراتُ لا تتعلّق بالمفردة', () async {
      await expectLater(StudentVoiceService().dispose(), completes);
    });
  });

  group('إعداداتُ النطق', () {
    test('اللهجةُ مثبّتةٌ على ar-SA', () {
      // و`_setBestArabic` تتدرّج منها إلى `ar` إن لم تكن على الجهاز، فلا
      // يصمت النطقُ حيث لا تُوجد اللهجة. وهذا يحرس المطلوبَ لا المتاح.
      expect(StudentVoiceService.preferredLocale, 'ar-SA');
    });

    test('والسرعةُ متّزنةٌ: لا مُهملةً ولا متقطّعة', () {
      // ٠٫٤٥ كانت تُسمع كلمةً كلمةً فيضيع إيقاعُ الجملة، وافتراضيُّ
      // المحرّك أسرع من أن يلحقه طفلٌ يسمع الشرح أوّل مرّة.
      expect(StudentVoiceService.speechRate, greaterThanOrEqualTo(0.5));
      expect(StudentVoiceService.speechRate, lessThanOrEqualTo(0.55));
    });
  });

  group('دورانُ الشاشة لا يُسكت الصوت', () {
    test('«inactive» لا تُسكت في الحال', () {
      // هذا العطبُ بعينه: الدوران يرِد `inactive` ثم `resumed` في إطارٍ
      // أو إطارين، وكان الإسكاتُ يقع على الأولى — فينقطع الشرح على طفلٍ
      // قلب هاتفه ولم يمسّ شيئاً.
      expect(
        quietActionFor(AppLifecycleState.inactive),
        StudentQuietAction.afterGrace,
      );
    });

    test('و«resumed» تُلغي إسكاتاً معلَّقاً', () {
      expect(
        quietActionFor(AppLifecycleState.resumed),
        StudentQuietAction.cancel,
      );
    });

    test('وما لا يرِد إلا عند مغادرةٍ حقيقية يُسكت في الحال', () {
      // القاعدةُ الأصلية تبقى: جهازٌ في حافظةٍ لا يُكمل الشرح. وإطفاءُ
      // الشاشة يمرّ بـ`inactive` إلى `paused`/`hidden` في أجزاءٍ من
      // الثانية، فهذه هي التي تُسكت.
      for (final state in <AppLifecycleState>[
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.detached,
      ]) {
        expect(quietActionFor(state), StudentQuietAction.now, reason: '$state');
      }
    });
  });
}
