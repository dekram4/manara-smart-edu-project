import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/services/study_rotation.dart';

/// دورةُ مغامرات المذاكرة: لا تُعاد مغامرةٌ قبل أن تُلعب أخواتُها، ولكل درسٍ دورتُه.
void main() {
  test('لا تتكرّر مغامرةٌ حتى تُلعب كلُّها، ثم تبدأ دورةٌ جديدة', () {
    final rotation = StudyRotation.inMemory();
    final titles = ['أ', 'ب', 'ج', 'د'];
    final rng = math.Random(3);
    final firstCycle = <String>{};
    String? current;
    for (var i = 0; i < titles.length; i++) {
      current = rotation.pick(titles, current: current, random: rng);
      firstCycle.add(current!);
    }
    expect(firstCycle, titles.toSet(), reason: 'الأربعُ في أوّل أربع جولات');
    // الدورةُ الثانية لا تبدأ بالتي انتهت بها الأولى.
    final next = rotation.pick(titles, current: current, random: rng);
    expect(next, isNot(current));
  });

  test('ما لُعب في فرعٍ لا يمسّ فرعاً آخر', () {
    // «أ» و«ب» من الفرع الأول، و«س» من الفرع الثاني — كلُّها لُعبت.
    final rotation = StudyRotation.inMemory(['أ', 'ب', 'س']);
    // مغامرتا الفرع الأول لُعبتا، فتبدأ دورتُه من جديد...
    expect(['أ', 'ب'], contains(rotation.pick(['أ', 'ب'])));
    // ...وما لُعب من الفرع الثاني محفوظٌ كما هو.
    expect(rotation.played, contains('س'));
  });

  test('ولكل درسٍ مفتاحُه، ويُحفظ بين الجلسات', () async {
    SharedPreferences.setMockInitialValues({});
    final one = await StudyRotation.load(studentId: 's1', lessonId: 'lesson-1');
    one.pick(['أ', 'ب', 'ج'], random: math.Random(1));
    await Future<void>.delayed(Duration.zero);
    final again = await StudyRotation.load(studentId: 's1', lessonId: 'lesson-1');
    expect(again.played, hasLength(1));
    final other = await StudyRotation.load(studentId: 's1', lessonId: 'lesson-2');
    expect(other.played, isEmpty, reason: 'مخطّطٌ آخر مستقلّ');
  });
}
