import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/models/card_permissions.dart';

/// القواعد كما يحفظها الخادم في `app_kv/smartEdu_cardPermissions` —
/// منسوخةً من السجلّ الحيّ للطالبة التي عطّل معلّمها بطاقتين.
const _rules = [
  {
    'id': 'class:teacher_1786033127503:الصف الرابع الابتدائي',
    'scope': 'class',
    'teacher_id': 'teacher_1786033127503',
    'grade_id': 'الصف الرابع الابتدائي',
    'student_id': null,
    'cards': {'tutor': false, 'meeting': false, 'cinema': true},
  },
  {
    'id': 'student:1786033254035',
    'scope': 'student',
    'teacher_id': 'teacher_1786033127503',
    'student_id': '1786033254035',
    'cards': {'tutor': false, 'meeting': false, 'chat': false},
  },
];

void main() {
  final teacher = {'teacher_1786033127503'};

  test('المعلم الافتراضي واللقاء المباشر مقفلان للطالبة', () {
    final access = CardPermissionRules.effective(
      rules: _rules,
      studentIds: {'1786033254035'},
      grade: 'الصف الرابع الابتدائي',
      teacherIdentities: teacher,
    );
    expect(access['tutor'], isFalse);
    expect(access['meeting'], isFalse);
    expect(access['chat'], isFalse);
    expect(access['lesson'], isTrue);
    expect(access.length, CardPermissionRules.cardIds.length);
  });

  test('زميلةُ الصف تتبع قاعدة الصف وحدها', () {
    final access = CardPermissionRules.effective(
      rules: _rules,
      studentIds: {'other'},
      // همزةٌ مختلفة في اسم الصف: الصفّ نفسه.
      grade: 'الصف الرابع الإبتدائي',
      teacherIdentities: teacher,
    );
    expect(access['tutor'], isFalse);
    expect(access['chat'], isTrue);
  });

  test('طالبٌ لمعلمٍ آخر لا يتأثر', () {
    final access = CardPermissionRules.effective(
      rules: _rules,
      studentIds: {'x'},
      grade: 'الصف الرابع الابتدائي',
      teacherIdentities: {'teacher_2'},
    );
    expect(access.values.every((open) => open), isTrue);
  });

  test('قاعدة الطالب تُطابق أيّ معرّفٍ له', () {
    final access = CardPermissionRules.effective(
      rules: _rules,
      studentIds: {'row-id', '1786033254035'},
      grade: null,
      teacherIdentities: const {},
    );
    expect(access['meeting'], isFalse);
  });
}
