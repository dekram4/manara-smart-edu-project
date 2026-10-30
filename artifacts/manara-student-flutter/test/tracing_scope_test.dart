import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/services/tracing_scope.dart';

/// «تتبّع واكتب» لروضة منارة المعرفة في موادّها الأربع وحدها.
void main() {
  group('القاعدة', () {
    test('الروضةُ والمادّةُ الأربع معاً', () {
      for (final subject in const [
        'الحروف العربية',
        'الحروف الإنجليزية',
        'الارقام العربية',
        'الارقام الانجليزية',
        'الأرقام الإنجليزية',
      ]) {
        expect(tracingAllowedFor(grade: 'روضة منارة المعرفة', subject: subject), isTrue, reason: subject);
      }
      expect(tracingAllowedFor(grade: 'روضه مناره المعرفه', subject: 'الحروف العربيه'), isTrue);
    });

    test('صفٌّ آخر بالمادّة نفسها: لا', () {
      expect(tracingAllowedFor(grade: 'الصف الأول', subject: 'الحروف العربية'), isFalse);
      expect(tracingAllowedFor(grade: null, subject: 'الأرقام العربية'), isFalse);
    });

    test('الروضةُ بمادّةٍ أخرى: لا', () {
      expect(tracingAllowedFor(grade: 'روضة منارة المعرفة', subject: 'العلوم'), isFalse);
      expect(tracingAllowedFor(grade: 'روضة منارة المعرفة', subject: 'اللغة العربية'), isFalse);
      expect(tracingAllowedFor(grade: 'روضة منارة المعرفة', subject: null), isFalse);
    });
  });
}
