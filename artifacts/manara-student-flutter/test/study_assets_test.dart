import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/widgets/portal_watermark.dart';

/// أصولُ بطاقة المذاكرة: موجودةٌ في الحزمة فعلاً، لا في المجلّد وحده.
///
/// ── لماذا اختبارٌ لا فحصٌ بالعين ──
/// ملفٌّ في `assets/` لا يعني ملفاً في التطبيق: يلزم أن يشمله قيدٌ في
/// `pubspec.yaml`. وقيدُ المجلّد لا يشمل مجلّداته الفرعية، فملفٌّ في
/// `assets/audio/voice/` لا يدخل بقيد `assets/audio/`.
///
/// وإن لم يدخل فلا خطأ يظهر: `playClip` تُمسك الاستثناء فتُفتح الشاشة
/// صامتة، و`Image.asset` ترسم مربّعاً فارغاً. فالعطبُ يُسمع ولا يُقرأ في
/// سجلّ، ولا يوقفه تحليلٌ ولا بناء.
///
/// فيُقرأ بيانُ الأصول — وهو ما يقرؤه التطبيق نفسه — ويُسأل عن كل ملف.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Set<String> bundled;

  setUpAll(() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    bundled = manifest.listAssets().toSet();
  });

  test('وترحيبُ إقلاع التطبيق في الحزمة', () {
    // أوّلُ ما في سلسلة `_playWelcomeVoice` في شاشة البدء، وأوّلُ ما
    // تُرجّحه `_supplied` لترحيب المحور. وغيابُه لا يُسقط شيئاً — السلسلةُ
    // ترتدّ إلى ما قبله — لكنّ الطفل يسمع الترحيبَ القديم ولا يُعرف لماذا.
    expect(
      bundled,
      contains('assets/audio/tarheeeeeeeb.mp3'),
      reason: 'ترحيبُ الإقلاع ليس في الحزمة — سيُسمع القديم',
    );
  });

  test('المقطعُ الترحيبي في الحزمة', () {
    // المسارُ نفسه الذي تستدعيه الشاشة في `initState`. فلو نُقل الملفُّ
    // أو أُعيدت تسميتُه سقط هذا الاختبار بدل أن تُفتح الشاشة صامتة.
    expect(
      bundled,
      contains('assets/audio/booksound.mp3'),
      reason: 'booksound.mp3 ليس في الحزمة — ستُفتح البطاقة صامتة',
    );
  });

  test('وصورةُ البطاقة وخلفيّةُ شاشتها', () {
    expect(bundled, contains('assets/images/book.png'));
    expect(
      bundled,
      contains(PortalBackgrounds.study),
      reason: 'خلفيةُ الشاشة غائبة — تُرسم فراغاً',
    );
  });

  test('وكلُّ خلفيّةِ بوابةٍ مُعلنةٍ موجودةٌ فعلاً', () {
    // الحرسُ يتّسع إلى الجميع: خلفيةٌ تُعلَن ولا تُشمل تُرسم فراغاً بلا
    // خطأ، وهي غلطةُ نسخٍ تتكرّر مع كل بطاقةٍ جديدة.
    for (final asset in <String>[
      PortalBackgrounds.lesson,
      PortalBackgrounds.games,
      PortalBackgrounds.cinema,
      PortalBackgrounds.personality,
      PortalBackgrounds.tutor,
      PortalBackgrounds.liveMeeting,
      PortalBackgrounds.quiz,
      PortalBackgrounds.problemSolver,
      PortalBackgrounds.chat,
      PortalBackgrounds.endlessReader,
      PortalBackgrounds.study,
    ]) {
      expect(bundled, contains(asset), reason: asset);
    }
  });
}
