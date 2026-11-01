import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/services/voice_match.dart';

/// مطابقةُ كلمات الأطفال المنطوقة مع الأسماء المكتوبة.
void main() {
  test('الرسمُ يتوحّد: تشكيلٌ وهمزاتٌ وتاءٌ مربوطة وأرقامٌ هندية', () {
    expect(normalizeSpoken('القُرْآن الكريمُ'), 'القران الكريم');
    expect(normalizeSpoken('النورانيّة!'), 'النورانيه');
    expect(normalizeSpoken('الصف ١'), 'الصف 1');
  });

  const subjects = ['القرآن الكريم', 'اللغة العربية', 'الحروف الإنجليزية', 'الأرقام الإنجليزية', 'العلوم'];

  test('كلمةٌ واحدة بسيطة تكفي لاختيار المادّة', () {
    expect(matchSpoken('قرآن', subjects), 0);
    expect(matchSpoken('القران', subjects), 0);
    expect(matchSpoken('حروف', subjects), 2);
    expect(matchSpoken('ارقام', subjects), 3);
    expect(matchSpoken('علوم', subjects), 4);
    expect(matchSpoken('أريد العلوم من فضلك', subjects), 4);
  });

  test('مرادفاتُ الأطفال وأخطاءُ السماع الصغيرة', () {
    expect(matchSpoken('القاعدة النورانية', ['القاعدة النورانية', 'سور قصيرة']), 0);
    expect(matchSpoken('نورانيه', ['سور قصيرة', 'النورانية']), 1);
    expect(matchSpoken('الحرووف', subjects), 2, reason: 'حرفٌ زائد');
    expect(matchSpoken('الأول', ['الصف الأول', 'الصف الثاني']), 0);
    expect(matchSpoken('الفصل الثاني', ['الفصل الأول', 'الفصل الثاني']), 1);
    expect(matchSpoken('الروضة', ['روضة منارة المعرفة', 'الصف الأول']), 0);
  });

  test('لا يُختار شيءٌ إن لم يُفهم أو تعادل خياران', () {
    expect(matchSpoken('طائرة', subjects), isNull);
    expect(matchSpoken('', subjects), isNull);
    // ‏«إنجليزي» في مادّتين: يُسأل ثانيةً لا يُؤخذ إلى إحداهما.
    expect(matchSpoken('انجليزي', subjects), isNull);
  });

  test('الأسماء: الاسمُ الأوّل يكفي، ولا كلماتٌ زائدة تُربك', () {
    const accounts = ['جوري داود jory', 'ريم علي reem', 'عبدالله سالم abdullah'];
    expect(matchSpoken('جوري', accounts), 0);
    expect(matchSpoken('انا اسمي ريم', accounts), 1);
    expect(matchSpoken('عبد الله', accounts), 2, reason: 'قالها كلمتين');
    expect(matchSpoken('عبدالله', accounts), 2);
    expect(matchSpoken('سارة', accounts), isNull);
  });
}
