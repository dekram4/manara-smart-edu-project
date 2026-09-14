import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/models/academic_context.dart';
import 'package:manara_student/src/models/student_assessment.dart';
import 'package:manara_student/src/models/student_content.dart';
import 'package:manara_student/src/models/student_profile.dart';

/// Quizzes gained the sixth level, and the rule has two halves that pull in
/// opposite directions:
///
///  * a quiz tied to a lesson must not appear on a different lesson;
///  * a quiz with no lesson is a whole-unit quiz — a legitimate choice in the
///    dashboard — and must keep appearing on every lesson in that unit.
///
/// Getting only the first half right would hide every unit-wide quiz; getting
/// only the second right would put every lesson's quiz on every other lesson.
void main() {
  const profile = StudentProfile(
    id: 's1',
    name: 'طالب',
    username: 'student',
    role: 'student',
    teacherId: 't1',
  );

  AcademicContext contextFor(String lessonName) => AcademicContext(
    grade: 'الصف الرابع',
    atram: 'الترم الأول',
    subject: 'العلوم',
    term: 'الفصل الثاني',
    unit: 'الوحدة الأولى',
    selectedLesson: LessonContent(
      id: 'row-$lessonName',
      lessonId: 'row-$lessonName',
      grade: 'الصف الرابع',
      atram: 'الترم الأول',
      subject: 'العلوم',
      term: 'الفصل الثاني',
      unit: 'الوحدة الأولى',
      lessonName: lessonName,
      createdAt: '2026-01-01',
      videos: const [],
      games: const [],
    ),
  );

  Map<String, dynamic> quiz({String? lesson}) => <String, dynamic>{
    'id': 'q1',
    'grade': 'الصف الرابع',
    'atram': 'الترم الأول',
    'subject': 'العلوم',
    'term': 'الفصل الثاني',
    'unit': 'الوحدة الأولى',
    if (lesson != null) 'lesson': lesson,
    'teacherId': 't1',
  };

  test('a quiz tied to a lesson shows on that lesson', () {
    expect(
      StudentAssessmentRules.matchesAcademicScope(
        quiz(lesson: 'الدرس الأول'),
        profile,
        academicContext: contextFor('الدرس الأول'),
      ),
      isTrue,
    );
  });

  test('a quiz tied to a lesson is hidden on a sibling lesson', () {
    expect(
      StudentAssessmentRules.matchesAcademicScope(
        quiz(lesson: 'الدرس الأول'),
        profile,
        academicContext: contextFor('الدرس الثاني'),
      ),
      isFalse,
    );
  });

  test('a quiz with no lesson covers every lesson in its unit', () {
    // The dashboard leaves the lesson empty on purpose for a periodic quiz
    // over the whole unit. Treating that as "belongs to no lesson" would make
    // such quizzes unreachable.
    for (final name in ['الدرس الأول', 'الدرس الثاني', 'الدرس الثالث']) {
      expect(
        StudentAssessmentRules.matchesAcademicScope(
          quiz(),
          profile,
          academicContext: contextFor(name),
        ),
        isTrue,
        reason: 'the unit-wide quiz vanished on $name',
      );
    }
  });

  test('the other five levels still gate the quiz', () {
    final foreign = quiz(lesson: 'الدرس الأول')..['unit'] = 'وحدة أخرى';
    expect(
      StudentAssessmentRules.matchesAcademicScope(
        foreign,
        profile,
        academicContext: contextFor('الدرس الأول'),
      ),
      isFalse,
    );
  });
}
