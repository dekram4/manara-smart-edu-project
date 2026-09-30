import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/models/interactive_study.dart';

/// قراءةُ حزمة المذاكرة في التطبيق، وأنماطُ تحدّياتها.
///
/// ── لماذا تُختبر وقد تحقّق منها الخادم ──
/// الخادم يردّ ما لا يصلح، وهذا صحيح. لكنّ الحزمةَ قد تكون مخزَّنةً في سجلّ
/// الدرس من نسخةٍ أقدم، أو يصل الردُّ منقوصاً على شبكةٍ ضعيفة. وشاشةٌ
/// تنهار على حقلٍ غائب أسوأ من شاشةٍ تقول «تعذّر التحضير».
Map<String, Object?> pathSituation({int answer = 0}) => {
      'type': 'avatar_path',
      'prompt': 'أمامك بوّابتان، أيّهما تعبر؟',
      'options': ['بوّابة الماء', 'بوّابة الرمل'],
      'answer': answer,
      'because': 'النبات يحتاج الماء',
    };

Map<String, Object?> swipeSituation({int answer = 0}) => {
      'type': 'swipe_fact',
      'prompt': 'الجذر يمتصّ الماء من التربة',
      'options': <String>[],
      'answer': answer,
      'because': 'وهذا ما في الدرس',
    };

Map<String, Object?> imposterSituation({int answer = 2}) => {
      'type': 'spot_imposter',
      'prompt': 'أيّها متسلّلة؟',
      'options': ['الورقة تصنع الغذاء', 'الساق ينقل الغذاء', 'الجذر يطير'],
      'answer': answer,
      'because': 'الجذر لا يطير',
    };

Map<String, Object?> scenario(String title, {String branch = 'الجذر'}) => {
      'title': title,
      'branch': branch,
      'situations': [pathSituation(), swipeSituation(), imposterSituation()],
    };

Map<String, Object?> pack() => {
      'mindMap': {
        'title': 'النبات',
        'branches': [
          {'icon': '🌱', 'title': 'الجذر', 'summary': 'يمتصّ الماء'},
          {'icon': '🌿', 'title': 'الساق', 'summary': 'ينقل الغذاء'},
          {'icon': '🍃', 'title': 'الورقة', 'summary': 'تصنع الغذاء'},
        ],
      },
      'scenarios': [
        scenario('مغامرة البستان'),
        scenario('مغامرة الصحراء', branch: 'الورقة'),
      ],
    };

void main() {
  test('الحزمةُ الصالحة تُقرأ كاملة', () {
    final parsed = StudyPack.fromMap(pack());
    expect(parsed, isNotNull);
    expect(parsed!.mindMap.title, 'النبات');
    expect(parsed.mindMap.branches.length, 3);
    expect(parsed.mindMap.branches.first.icon, '🌱');
    expect(parsed.scenarios.length, 2);
    expect(parsed.scenarios.first.situations.length, 3);
  });

  test('والأنماطُ الثلاثة تُقرأ بأسمائها', () {
    final parsed = StudyPack.fromMap(pack())!;
    expect(
      parsed.scenarios.first.situations.map((item) => item.type).toList(),
      [
        StudyChallengeType.avatarPath,
        StudyChallengeType.swipeFact,
        StudyChallengeType.spotImposter,
      ],
    );
  });

  test('ونمطٌ مجهولٌ يُردّ إلى المسار لا يُسقط الحزمة', () {
    // حزمةٌ محفوظةٌ من نسخةٍ أقدم لا تحمل نمطاً. وشاشةٌ لا ترسم شيئاً أسوأ
    // من شاشةٍ ترسم بوّابتين.
    final raw = pathSituation()..remove('type');
    expect(StudySituation.fromMap(raw)?.type, StudyChallengeType.avatarPath);
    expect(
      StudySituation.fromMap(pathSituation()..['type'] = 'quiz')?.type,
      StudyChallengeType.avatarPath,
    );
  });

  test('ومجموعُ المواقف هو سقفُ ما يُكافأ عليه', () {
    expect(StudyPack.fromMap(pack())!.totalSituations, 6);
  });

  test('والموقفُ يعرف جوابه', () {
    final one = StudySituation.fromMap(imposterSituation())!;
    expect(one.isCorrect(2), isTrue);
    expect(one.isCorrect(0), isFalse);
  });

  // ── تحدّي الفرع ──

  test('تحدّي فرعٍ بعينه يعود بمغامراته وحدها', () {
    // العطبُ الذي يحرسه: ضغطُ الفرع كان يفتح تحدياً عامّاً، فتصير قراءةُ
    // الفرع بلا أثر.
    final parsed = StudyPack.fromMap(pack())!;
    final scoped = parsed.forBranch('الورقة');
    expect(scoped.length, 1);
    expect(scoped.first.title, 'مغامرة الصحراء');
  });

  test('وفرعٌ لا تحدّيَ له يرتدّ إلى الحزمة كلِّها', () {
    // زرٌّ لا يفعل شيئاً أسوأ من تحدٍّ عامّ: حزمةٌ قديمةٌ لا تحمل أسماءَ
    // الفروع، أو نموذجٌ سمّى فرعاً بغير ما في الخريطة.
    final parsed = StudyPack.fromMap(pack())!;
    expect(parsed.forBranch('الساق').length, 2);
    expect(parsed.forBranch('').length, 2);
    expect(parsed.forBranch('   ').length, 2);
  });

  // ── وما يُردّ بلا أن يرفع خطأ ──

  test('وعددُ الخيارات يتبع النمط', () {
    // بوّابتان في المسار، وثلاثٌ في الرادار، ولا خيارَ في السحب. وعددٌ لا
    // يوافق نمطَه لا تعرف الشاشةُ كيف ترسمه.
    expect(
      StudySituation.fromMap(pathSituation()..['options'] = ['أ', 'ب', 'ج']),
      isNull,
    );
    expect(
      StudySituation.fromMap(imposterSituation()..['options'] = ['أ', 'ب']),
      isNull,
    );
    // والسحبُ جوابُه صفرٌ أو واحد.
    expect(StudySituation.fromMap(swipeSituation(answer: 1)), isNotNull);
    expect(StudySituation.fromMap(swipeSituation(answer: 2)), isNull);
  });

  test('وجوابٌ خارج القائمة يُسقط الموقف', () {
    expect(StudySituation.fromMap(pathSituation(answer: 7)), isNull);
    expect(StudySituation.fromMap(pathSituation(answer: -1)), isNull);
  });

  test('وموقفٌ معطوبٌ يُسقط مغامرتَه كلَّها', () {
    final raw = pack();
    (raw['scenarios'] as List)[0] = {
      'title': 'معطوبة',
      'branch': 'الجذر',
      'situations': [pathSituation(), pathSituation(answer: 9)],
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

  test('وما ليس خريطةً أصلاً يعود null', () {
    for (final bad in <Object?>[null, 'نص', 42, <Object?>[], <String, Object?>{}]) {
      expect(StudyPack.fromMap(bad), isNull, reason: '$bad');
    }
  });
}
