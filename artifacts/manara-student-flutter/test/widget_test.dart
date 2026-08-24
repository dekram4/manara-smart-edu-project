import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/models/academic_context.dart';
import 'package:manara_student/src/models/student_content.dart';

void main() {
  test('academic context reports whether its path is complete', () {
    final lesson = LessonContent(
      id: 'lesson-1',
      lessonId: 'lesson-1',
      grade: 'السادس',
      atram: 'الفصل الأول',
      subject: 'الرياضيات',
      term: 'الترم الأول',
      unit: 'الوحدة الأولى',
      lessonName: 'الكسور',
      createdAt: '2026-01-01T00:00:00Z',
      videos: const [],
      games: const [],
    );

    final complete = AcademicContext(
      grade: 'السادس',
      atram: 'الفصل الأول',
      subject: 'الرياضيات',
      term: 'الترم الأول',
      unit: 'الوحدة الأولى',
      selectedLesson: lesson,
    );
    final partial = AcademicContext(
      grade: 'السادس',
      atram: '',
      subject: 'الرياضيات',
      term: 'الترم الأول',
      unit: 'الوحدة الأولى',
      selectedLesson: lesson,
    );

    expect(complete.hasCompletePath, isTrue);
    expect(partial.hasCompletePath, isFalse);
  });
}
