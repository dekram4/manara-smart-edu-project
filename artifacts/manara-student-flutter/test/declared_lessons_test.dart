import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/models/academic_context.dart';
import 'package:manara_student/src/models/student_content.dart';

/// The lesson level of the academic settings tree, as the student sees it.
///
/// A teacher types a lesson name into the dashboard long before they
/// publish any video or text under it. Until that field reached this far,
/// typing it changed nothing a student could see — which made it a box
/// that did nothing. These pin the two halves of the contract: a named
/// lesson is offered, and a published one is never shadowed by the bare
/// name that shares its title.
void main() {
  const path = AcademicPath(
    grade: 'الصف الرابع',
    atram: 'الترم الأول',
    subject: 'العلوم',
    term: 'الفصل الثاني',
    unit: 'الوحدة الأولى',
  );

  LessonContent published(String name) => LessonContent(
        id: 'row-$name',
        lessonId: 'row-$name',
        grade: path.grade,
        atram: path.atram,
        subject: path.subject,
        term: path.term,
        unit: path.unit,
        lessonName: name,
        createdAt: '2026-01-01',
        videos: const [],
        games: const [],
        lessonText: 'نص الدرس',
      );

  List<LessonContent> lessonsIn(AcademicSelectionData data) => data.lessonsFor(
        grade: path.grade,
        atram: path.atram,
        subject: path.subject,
        term: path.term,
        unit: path.unit,
      );

  test('a lesson named in the settings is offered to the student', () {
    final data = AcademicSelectionData(
      paths: const [path],
      lessons: const [],
      declaredLessons: const [DeclaredLesson(path: path, name: 'الخلية')],
    );

    final names = lessonsIn(data).map((lesson) => lesson.lessonName).toList();
    expect(names, ['الخلية']);
  });

  test('a published lesson keeps its content and is not shadowed', () {
    // Same title on both sides. The row with the teacher's text has to
    // win, or filling a lesson in would appear to empty it.
    final data = AcademicSelectionData(
      paths: const [path],
      lessons: [published('الخلية')],
      declaredLessons: const [DeclaredLesson(path: path, name: 'الخلية')],
    );

    final found = lessonsIn(data);
    expect(found.length, 1);
    expect(found.single.lessonText, 'نص الدرس');
    expect(found.single.id, 'row-الخلية');
  });

  test('published and declared lessons appear side by side', () {
    final data = AcademicSelectionData(
      paths: const [path],
      lessons: [published('الخلية')],
      declaredLessons: const [DeclaredLesson(path: path, name: 'الذرة')],
    );

    final names = lessonsIn(data).map((lesson) => lesson.lessonName).toSet();
    expect(names, {'الخلية', 'الذرة'});
  });

  test('a declared lesson on another unit is not offered here', () {
    const elsewhere = AcademicPath(
      grade: 'الصف الرابع',
      atram: 'الترم الأول',
      subject: 'العلوم',
      term: 'الفصل الثاني',
      unit: 'الوحدة الثانية',
    );
    final data = AcademicSelectionData(
      paths: const [path, elsewhere],
      lessons: const [],
      declaredLessons: const [DeclaredLesson(path: elsewhere, name: 'الذرة')],
    );

    expect(lessonsIn(data), isEmpty);
  });

  test('declared lessons alone are a usable course, not an empty one', () {
    // Counting only published lessons sent this teacher's students to the
    // "no courses at all" screen while their settings tree said otherwise.
    final data = AcademicSelectionData(
      paths: const [path],
      lessons: const [],
      declaredLessons: const [DeclaredLesson(path: path, name: 'الخلية')],
    );
    expect(data.isEmpty, isFalse);
  });

  test('no paths is still empty, whatever else is declared', () {
    final data = AcademicSelectionData(
      paths: const [],
      lessons: const [],
      declaredLessons: const [DeclaredLesson(path: path, name: 'الخلية')],
    );
    expect(data.isEmpty, isTrue);
  });

  test('the placeholder id is stable and cannot collide with a real row', () {
    const lesson = DeclaredLesson(path: path, name: 'الخلية');
    const same = DeclaredLesson(path: path, name: 'الخلية');
    expect(lesson.placeholderId, same.placeholderId);
    expect(lesson.placeholderId, startsWith('declared:'));
  });

  test('existing callers that pass no declared lessons are unaffected', () {
    // The field is additive; every call site written before it must behave
    // exactly as it did.
    final data = AcademicSelectionData(
      paths: const [path],
      lessons: [published('الخلية')],
    );
    expect(data.declaredLessons, isEmpty);
    expect(lessonsIn(data).single.id, 'row-الخلية');
  });
}
