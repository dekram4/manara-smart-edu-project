import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/models/academic_context.dart';
import 'package:manara_student/src/models/student_content.dart';
import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/services/student_avatar_store.dart';
import 'package:manara_student/src/services/student_content_service.dart';

/// What a student may still choose after the teacher has deleted something.
///
/// The reported fault: an academic setting removed from the teacher's
/// dashboard stayed on the student's path screen. The lessons filed under
/// it were still in `lesson_configs`, and each one used to contribute its
/// own grade/subject/term back into the list, so the deletion never
/// reached the student.
void main() {
  const profile = StudentProfile(
    id: 's1',
    name: 'طالب',
    username: 'student',
    role: 'student',
    teacherId: 't1',
  );

  List<Object?> treeWith(String subject) => [
        {
          'grade': 'الصف الرابع',
          'createdBy': 't1',
          'atrams': [
            {
              'atram': 'الترم الأول',
              'subjects': [
                {
                  'subject': subject,
                  'terms': [
                    {
                      'term': 'الفصل الثاني',
                      'units': ['الوحدة الأولى'],
                    },
                  ],
                },
              ],
            },
          ],
        },
      ];

  LessonContent lesson(String subject) => LessonContent(
        id: 'l-$subject',
        lessonId: 'l-$subject',
        grade: 'الصف الرابع',
        atram: 'الترم الأول',
        subject: subject,
        term: 'الفصل الثاني',
        unit: 'الوحدة الأولى',
        lessonName: 'درس',
        createdAt: '2026-01-01T00:00:00Z',
        ownerId: 't1',
        videos: const [],
        games: const [],
      );

  List<String> subjectsOf(List<AcademicPath> paths) =>
      paths.map((path) => path.subject).toList();

  test('a subject deleted from the tree leaves the student, lesson or not',
      () {
    final paths = StudentContentService.academicPaths(
      hierarchyValue: treeWith('العلوم'),
      hierarchyUnavailable: false,
      // Still filed under the deleted subject, as a real deletion leaves it.
      lessons: [lesson('العلوم'), lesson('الرياضيات')],
      profile: profile,
    );

    expect(subjectsOf(paths), ['العلوم']);
    expect(subjectsOf(paths), isNot(contains('الرياضيات')),
        reason: 'a leftover lesson must not put a deleted subject back');
  });

  test('an empty tree leaves the student nothing to choose', () {
    // The teacher deleted everything. Read successfully, and empty.
    final paths = StudentContentService.academicPaths(
      hierarchyValue: const <Object?>[],
      hierarchyUnavailable: false,
      lessons: [lesson('العلوم')],
      profile: profile,
    );

    expect(paths, isEmpty);
  });

  test('lessons still carry the paths when there is no tree to read', () {
    // An unreachable app_kv, or a deployment that never wrote a tree: the
    // student keeps working from the lessons themselves.
    for (final unreadable in [
      (value: null, unavailable: true),
      (value: null, unavailable: false),
    ]) {
      final paths = StudentContentService.academicPaths(
        hierarchyValue: unreadable.value,
        hierarchyUnavailable: unreadable.unavailable,
        lessons: [lesson('العلوم')],
        profile: profile,
      );

      expect(subjectsOf(paths), ['العلوم']);
    }
  });

  group('the chosen character travels with the profile', () {
    // It used to live only in this device's preferences, so signing out —
    // or signing in anywhere else — brought back the default character.
    test('a profile that records a pick is followed', () {
      expect(
        StudentAvatars.idFromAppearance({
          'shape': 'circle',
          StudentAvatars.appearanceKey: 'h2',
        }),
        'h2',
      );
    });

    test('a profile with no pick yet leaves this device alone', () {
      expect(StudentAvatars.idFromAppearance(null), isNull);
      expect(StudentAvatars.idFromAppearance(const {'shape': 'circle'}), isNull);
      expect(
        StudentAvatars.idFromAppearance({StudentAvatars.appearanceKey: '  '}),
        isNull,
      );
    });

    test('an unknown character falls back rather than showing nothing', () {
      expect(StudentAvatars.byId('nope').id, StudentAvatars.fallback.id);
    });
  });
}
