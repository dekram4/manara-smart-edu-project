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
    expect(speakableText('`x + y`'), 'x زائد y');
  });

  test('الرموزُ التي لا معنى لها في شرحٍ تسقط', () {
    expect(speakableText('الناتج ☢ ★ ← ٧'), 'الناتج ٧');
    expect(speakableText('الجواب | ١٢ |'), 'الجواب ١٢');
  });

  test('علاماتُ الحساب تُنطق بأسمائها لا تُتجاهَل', () {
    // «خمسة بلَس ثلاثة» ليست جمعاً يسمعه طفل، والمحرّك يتجاهل العلامة
    // أحياناً فيسمع «خمسة ثلاثة ثمانية» — وهي أسوأ.
    expect(speakableText('٥ + ٣ = ٨'), '٥ زائد ٣ يساوي ٨');
    expect(speakableText('١٢ ÷ ٤'), '١٢ تقسيم ٤');
    expect(speakableText('٦ × ٧'), '٦ ضرب ٧');
    expect(speakableText('٥٠%'), '٥٠ بالمئة');
  });

  test('والملتبِسُ منها بين رقمين وحدهما', () {
    // الشَّرطةُ ناقصٌ في «٧-٣» وواصلةٌ في «أ-ب»؛ فلا تُنطق حيث تحتمل
    // غير العملية.
    expect(speakableText('٧-٣'), '٧ ناقص ٣');
    expect(speakableText('١٢/٤'), '١٢ تقسيم ٤');
    expect(speakableText('٦*٧'), '٦ ضرب ٧');
    // وبقيّةُ إبرازٍ لم يُغلق ليست ضرباً.
    expect(speakableText('**مهم'), 'مهم');
    // ولا علامةُ القائمة جمعاً.
    expect(speakableText('+ أوّلاً'), 'أوّلاً');
  });

  test('معادلاتُ LaTeX تُفكّ ولا تُهجّى', () {
    // ولولا ذلك لبقي «frac 2 3» فنُطق «فراك اثنان ثلاثة».
    expect(speakableText(r'$\frac{2}{3}$'), '2 تقسيم 3');
    expect(speakableText(r'$5 \times 4 = 20$'), '5 ضرب 4 يساوي 20');
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
