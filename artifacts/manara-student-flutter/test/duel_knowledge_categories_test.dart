import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/duel_question.dart';

/// أبوابُ المعرفة العامّة في «تحدَّ زملاءكَ»: تصل من الحزمة بأسمائها، ولكلٍّ
/// منها شارةٌ مكتوبة — لا «معلومات عامة» لكل شيء، ولا مفتاحٌ خامٌ على الشاشة.
void main() {
  const categories = ['culture', 'sports', 'geography', 'history', 'science'];

  for (final category in categories) {
    test('بابُ «$category» يبقى كما هو وله اسمٌ يُعرض', () {
      final question = DuelQuestion.fromJson({
        'id': '$category:abc',
        'category': category,
        'prompt': 'ما عاصمة فرنسا؟',
        'options': ['باريس', 'ليون', 'نيس', 'روما'],
        'answerAt': 0,
      });
      expect(question, isNotNull);
      expect(question!.category, category);
      expect(StudentStrings.has(question.categoryKey), isTrue);
      expect(tr(question.categoryKey), isNot(question.categoryKey));
    });
  }

  test('حزمةٌ مختلطة الأبواب تُقرأ كاملة', () {
    final pack = duelPackFrom({
      'questions': [
        for (var i = 0; i < 10; i++)
          {
            'id': 'q$i',
            'category': [...categories, 'domain', 'logic', 'quick', 'general', 'school'][i],
            'prompt': 'سؤالٌ رقم $i',
            'options': ['أ', 'ب', 'ج', 'د'],
            'answerAt': i % 4,
          },
      ],
    });
    expect(pack, isNotNull);
    expect(pack!.length, 10);
    expect(pack.take(5).map((q) => q.category), categories);
  });
}
