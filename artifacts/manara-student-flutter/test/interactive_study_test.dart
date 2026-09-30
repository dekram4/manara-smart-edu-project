import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/models/interactive_study.dart';

/// قراءةُ حزمة المذاكرة في التطبيق.
///
/// ── لماذا تُختبر وقد تحقّق منها الخادم ──
/// الخادم يردّ ما لا يصلح، وهذا صحيح. لكنّ الحزمةَ قد تكون مخزَّنةً في
/// سجلّ الدرس من نسخةٍ أقدم، أو يصل الردُّ منقوصاً على شبكةٍ ضعيفة.
/// وشاشةٌ تنهار على حقلٍ غائب أسوأ من شاشةٍ تقول «تعذّر التحضير».
Map<String, Object?> situation({int answer = 1, List<String>? options}) => {
      'prompt': 'ماذا تفعل لو انقطع الماء عن النبات؟',
      'options': options ?? ['أسقيه', 'أتركه', 'أقصّه'],
      'answer': answer,
      'because': 'النبات يحتاج الماء',
    };

Map<String, Object?> scenario(String title) => {
      'title': title,
      'situations': [situation(), situation(answer: 0), situation(answer: 2)],
    };

Map<String, Object?> pack() => {
      'mindMap': {
        'title': 'النبات',
        'branches': [
          {'title': 'الجذر', 'summary': 'يمتصّ الماء'},
          {'title': 'الساق', 'summary': 'ينقل الغذاء'},
          {'title': 'الورقة', 'summary': 'تصنع الغذاء'},
        ],
      },
      'scenarios': [scenario('مغامرة البستان'), scenario('مغامرة الصحراء')],
    };

void main() {
  test('الحزمةُ الصالحة تُقرأ كاملة', () {
    final parsed = StudyPack.fromMap(pack());
    expect(parsed, isNotNull);
    expect(parsed!.mindMap.title, 'النبات');
    expect(parsed.mindMap.branches.length, 3);
    expect(parsed.scenarios.length, 2);
    expect(parsed.scenarios.first.situations.length, 3);
  });

  test('ومجموعُ المواقف هو سقفُ ما يُكافأ عليه', () {
    // الخادم يحصر الجواهر بهذا العدد، فيجب أن يقرأه التطبيق كما يقرؤه.
    expect(StudyPack.fromMap(pack())!.totalSituations, 6);
  });

  test('والموقفُ يعرف جوابه', () {
    final one = StudySituation.fromMap(situation(answer: 2))!;
    expect(one.isCorrect(2), isTrue);
    expect(one.isCorrect(0), isFalse);
  });

  // ── وما يُردّ بلا أن يرفع خطأ ──

  test('جوابٌ خارج قائمة الخيارات يُسقط الموقف', () {
    // موقفٌ لا جوابَ له يعني سؤالاً لا يُصاب، فلا يُعرض على طفل.
    expect(StudySituation.fromMap(situation(answer: 7)), isNull);
    expect(StudySituation.fromMap(situation(answer: -1)), isNull);
  });

  test('وجوابٌ ليس رقماً يُسقط الموقف', () {
    final raw = situation()..['answer'] = 'أسقيه';
    expect(StudySituation.fromMap(raw), isNull);
  });

  test('وموقفٌ معطوبٌ يُسقط مغامرتَه كلَّها', () {
    // لا مغامرةَ بموقفين ونصف: الطفل يصل إلى فراغٍ في منتصف الحكاية.
    final raw = pack();
    (raw['scenarios'] as List)[0] = {
      'title': 'معطوبة',
      'situations': [situation(), situation(answer: 9)],
    };
    final parsed = StudyPack.fromMap(raw);
    expect(parsed, isNotNull);
    expect(parsed!.scenarios.length, 1, reason: 'المعطوبة تُسقط لا تُصلَح');
  });

  test('وخريطةٌ بفرعٍ واحد لا تصلح', () {
    final raw = pack();
    (raw['mindMap'] as Map)['branches'] = [
      {'title': 'الجذر', 'summary': 'يمتصّ الماء'},
    ];
    expect(StudyPack.fromMap(raw), isNull);
  });

  test('وحزمةٌ بلا مغامرةٍ واحدة صالحة لا تصلح', () {
    final raw = pack();
    raw['scenarios'] = [
      {'title': 'فارغة', 'situations': <Object?>[]},
    ];
    expect(StudyPack.fromMap(raw), isNull);
  });

  test('وما ليس خريطةً أصلاً يعود null', () {
    for (final bad in <Object?>[null, 'نص', 42, <Object?>[], <String, Object?>{}]) {
      expect(StudyPack.fromMap(bad), isNull, reason: '$bad');
    }
  });
}
