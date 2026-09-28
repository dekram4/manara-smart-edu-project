import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/services/student_voice_service.dart';

/// ما يُسلَّم لمحرّك النطق.
///
/// الدالة نقيّة ومفصولةٌ عن الخدمة لهذا السبب: أثرُها لا يُرى في اختبار
/// ويدجت ولا في تحليلٍ ساكن — يُسمع على جهازٍ حقيقيّ بعد بناء APK. فما
/// لا يُختبر هنا لا يُكتشف إلا بطفلٍ يسمع «نجمة نجمة».
void main() {
  test('الإيموجي لا تُنطق', () {
    expect(speakableText('أحسنت! 🎉👏 الجواب ٥'), 'أحسنت! الجواب ٥');
    expect(speakableText('💎 جوهرتان'), 'جوهرتان');
  });

  test('علاماتُ Markdown تسقط ويبقى ما بينها', () {
    expect(speakableText('**الخطوة الأولى**'), 'الخطوة الأولى');
    expect(speakableText('# عنوان'), 'عنوان');
    expect(speakableText('- أوّلاً'), 'أوّلاً');
    expect(speakableText('`x + y`'), 'x + y');
  });

  test('الرموزُ التي لا معنى لها في شرحٍ تسقط', () {
    expect(speakableText('الناتج ☢ ★ ← ٧'), 'الناتج ٧');
    expect(speakableText('الجواب | ١٢ |'), 'الجواب ١٢');
  });

  test('علاماتُ الحساب تبقى، فهي جزءٌ من الجواب', () {
    expect(speakableText('٥ + ٣ = ٨'), '٥ + ٣ = ٨');
    expect(speakableText('١٢ / ٤ = ٣'), '١٢ / ٤ = ٣');
    expect(speakableText('٥٠%'), '٥٠%');
  });

  test('علاماتُ الوقف تبقى واحدةً ولا تُسبق بمسافة', () {
    // المحرّك يقرؤها صمتاً بين الجمل؛ وحذفُها يجعل الشرح نَفَساً واحداً.
    expect(speakableText('ما هذا ؟؟'), 'ما هذا؟');
    expect(speakableText('أحسنت !!'), 'أحسنت!');
    expect(speakableText('أوّلاً، ثم ثانياً.'), 'أوّلاً، ثم ثانياً.');
  });

  test('الروابطُ وسياجُ الشيفرة لا يُقرآن حرفاً حرفاً', () {
    expect(speakableText('انظر https://example.com/a?b=1 هنا'), 'انظر هنا');
    // وقفةُ فقرةٍ مكان الشيفرة المحذوفة، لا سطرٌ فارغ يُقرأ.
    expect(speakableText('قبل\n```\ncode();\n```\nبعد'), 'قبل\n\nبعد');
  });

  test('نصٌّ لا يحمل إلا رموزاً يصير فارغاً فلا يُنطق', () {
    // و`speak` تُغادر عند الفارغ، فلا يُفتح المحرّك على لا شيء.
    expect(speakableText('🎉🎉🎉'), '');
    expect(speakableText('   '), '');
  });
}
