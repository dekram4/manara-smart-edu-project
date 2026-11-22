import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/services/duel_voice_answer.dart';

/// جوابُ «تحدَّ زملاءك» بالصوت: يُقبل بمعناه وبما يقوله الطفلُ في البيت، لا
/// بحرف الخيار.
void main() {
  const animals = ['القطة', 'الكلب', 'البقرة', 'الفيل'];

  test('الرسمُ لا يهمّ: «ال» والتاءُ المربوطة والهمزاتُ والتشكيل', () {
    expect(matchDuelAnswer('القطة', animals), 0);
    expect(matchDuelAnswer('قطه', animals), 0);
    expect(matchDuelAnswer('القِطَّةُ', animals), 0);
    expect(matchDuelAnswer('هي القطة', animals), 0, reason: 'كلماتٌ زائدةٌ لا تحمل الجواب');
    expect(matchDuelAnswer('الفيل', animals), 3);
    expect(matchDuelAnswer('افيال', animals), 3);
  });

  test('ما يقوله الطفلُ في البيت: بسّة، جرو، باص، دكتور، أيوه', () {
    expect(matchDuelAnswer('بسة', animals), 0);
    expect(matchDuelAnswer('جرو', animals), 1);
    const transport = ['الطائرة', 'الحافلة المدرسية', 'القطار', 'السفينة'];
    expect(matchDuelAnswer('الباص', transport), 1);
    expect(matchDuelAnswer('طياره', transport), 0);
    expect(matchDuelAnswer('ترين', transport), 2);
    const jobs = ['الطبيب', 'المعلم', 'الطيار', 'المزارع'];
    expect(matchDuelAnswer('دكتور', jobs), 0);
    expect(matchDuelAnswer('استاذ', jobs), 1);
    expect(matchDuelAnswer('فلاح', jobs), 3);
    expect(matchDuelAnswer('أيوه', ['نعم', 'لا']), 0);
    expect(matchDuelAnswer('لا', ['نعم', 'لا']), 1);
  });

  test('الأعدادُ والمثنّى: «اثنين» و«قدمين» كلاهما «قدمان»', () {
    const feet = ['ثلاثة', 'قدمان', 'أربع', 'واحد'];
    expect(matchDuelAnswer('اثنين', feet), 1);
    expect(matchDuelAnswer('قدمين', feet), 1);
    expect(matchDuelAnswer('٢', feet), 1);
    expect(matchDuelAnswer('اربعة', feet), 2);
    expect(matchDuelAnswer('تلاته', feet), 0);
    const eyes = ['اثنتان', 'خمسة', 'عشرة', 'واحد'];
    expect(matchDuelAnswer('عينين', eyes), 0);
    expect(matchDuelAnswer('عشر', eyes), 2);
  });

  test('الكلمةُ الجوهرية تكفي من جوابٍ طويل', () {
    const manners = ['شكرا', 'مع شخص بالغ مسؤول', 'في سلة المهملات', 'نغسل أيدينا'];
    expect(matchDuelAnswer('مع ماما', manners), 1);
    expect(matchDuelAnswer('بالزبالة', manners), 2);
    expect(matchDuelAnswer('نغسل', manners), 3);
    expect(matchDuelAnswer('مشكور', manners), 0);
    const fire = ['رجل الإطفاء', 'الطبيب', 'الطباخ', 'المعلم'];
    expect(matchDuelAnswer('الاطفائي', fire), 0);
    expect(matchDuelAnswer('شيف', fire), 2);
    const shapes = ['الدائرة', 'الشكل البيضاوي', 'المربع', 'المثلث'];
    expect(matchDuelAnswer('بيضاوي', shapes), 1);
    expect(matchDuelAnswer('مدورة', shapes), 0);
  });

  test('خطأُ سماعٍ بحرفٍ لا يُسقط الجواب', () {
    const options = ['السلحفاة', 'الزرافة', 'الأرنب', 'الأسد'];
    expect(matchDuelAnswer('السلحفا', options), 0);
    expect(matchDuelAnswer('زرافا', options), 1);
    expect(matchDuelAnswer('الارانب', options), 2);
  });

  test('لا يُختار شيءٌ إن تعادل خياران أو لم يُفهم الكلام', () {
    expect(matchDuelAnswer('القطة أو الكلب', animals), isNull);
    expect(matchDuelAnswer('ما أعرف', animals), isNull);
    expect(matchDuelAnswer('', animals), isNull);
    // ‏لكنّ ما قيل حرفاً يفصل تعادلَ المعنى.
    expect(matchDuelAnswer('في الماء', ['الماء', 'في الماء', 'الشمس']), 1);
  });

  test('الكلامُ وهو يُقال: يُؤخذ في لحظته إن غطّى خياراً كاملاً ولم يمسّ غيرَه', () {
    expect(earlyDuelAnswer('القطة', animals), 0);
    expect(earlyDuelAnswer('رجل', ['رجل الإطفاء', 'رجل الأمن', 'الطبيب', 'الطيار']), isNull);
    expect(earlyDuelAnswer('القطة والكلب', animals), isNull);
  });
}
