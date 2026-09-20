import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/models/student_content.dart';
import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/services/student_content_service.dart';

/// One unit holds many lessons, and the student picked exactly one of them.
///
/// Before the sixth level reached this far, the unit collapsed to whichever
/// lesson happened to be newest — so a student who chose "الدرس الأول" could
/// open "شرح الدرس" and be shown the second lesson's video. These pin the
/// rule that ends that: the chosen lesson, or nothing.
void main() {
  const profile = StudentProfile(
    id: 's1',
    name: 'طالب',
    username: 'student',
    role: 'student',
    teacherId: 't1',
  );

  LessonContent lesson(
    String id,
    String name, {
    String createdAt = '2026-01-01',
    String? ownerId = 't1',
  }) => LessonContent(
    id: id,
    lessonId: id,
    grade: 'الصف الرابع',
    subject: 'العلوم',
    term: 'الفصل الثاني',
    unit: 'الوحدة الأولى',
    lessonName: name,
    createdAt: createdAt,
    ownerId: ownerId,
    videos: const [],
    games: const [],
  );

  test('the chosen lesson wins over a newer sibling in the same unit', () {
    final result = StudentContentService.preferredLessonsForStudent(
      [
        lesson('a', 'الدرس الأول', createdAt: '2026-01-01'),
        lesson('b', 'الدرس الثاني', createdAt: '2026-05-01'),
      ],
      profile,
      pinnedLessonId: 'a',
      pinnedLessonName: 'الدرس الأول',
    );

    expect(result.map((l) => l.id), ['a']);
  });

  test('no sibling leaks in alongside the chosen lesson', () {
    // The screen reads the head of this list, but it also renders the rest.
    // Handing back the whole unit is how two lessons ended up mixed on one
    // card, so the list itself has to be the single lesson.
    final result = StudentContentService.preferredLessonsForStudent(
      [
        lesson('a', 'الدرس الأول'),
        lesson('b', 'الدرس الثاني'),
        lesson('c', 'الدرس الثالث'),
      ],
      profile,
      pinnedLessonId: 'b',
      pinnedLessonName: 'الدرس الثاني',
    );

    expect(result.length, 1);
    expect(result.single.lessonName, 'الدرس الثاني');
  });

  test('a lesson that exists only in the settings tree resolves by name', () {
    // Its id is a placeholder that matches no `lesson_configs` row. The name
    // is the only handle on it, and content published under that name later
    // has to attach to it rather than to a sibling.
    final result = StudentContentService.preferredLessonsForStudent(
      [
        lesson('row-1', 'الدرس الأول', createdAt: '2026-05-01'),
        lesson('row-2', 'الدرس الثاني'),
      ],
      profile,
      pinnedLessonId: 'declared:...|الدرس الثاني',
      pinnedLessonName: 'الدرس الثاني',
    );

    expect(result.single.id, 'row-2');
  });

  test('a chosen lesson with no content yet yields nothing, not a sibling', () {
    final result = StudentContentService.preferredLessonsForStudent(
      [lesson('a', 'الدرس الأول'), lesson('b', 'الدرس الثاني')],
      profile,
      pinnedLessonId: 'declared:...|الدرس الثالث',
      pinnedLessonName: 'الدرس الثالث',
    );

    expect(result, isEmpty);
  });

  test("the student's own teacher outranks a supervisor's copy", () {
    final result = StudentContentService.preferredLessonsForStudent(
      [
        lesson('sup', 'الدرس الأول', createdAt: '2026-09-01', ownerId: 'admin'),
        lesson('own', 'الدرس الأول', createdAt: '2026-01-01'),
      ],
      profile,
      pinnedLessonName: 'الدرس الأول',
    );

    expect(result.single.id, 'own');
  });

  test('with nothing pinned the unit still collapses to one lesson', () {
    // The browse path is unchanged: no academic context means no choice to
    // honour, and the newest lesson in the unit is still the answer.
    final result = StudentContentService.preferredLessonsForStudent(
      [
        lesson('a', 'الدرس الأول', createdAt: '2026-01-01'),
        lesson('b', 'الدرس الثاني', createdAt: '2026-05-01'),
      ],
      profile,
    );

    expect(result.map((l) => l.id), ['b']);
  });
}
