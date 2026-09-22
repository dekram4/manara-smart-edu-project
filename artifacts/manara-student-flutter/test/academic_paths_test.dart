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
      ];

  LessonContent lesson(String subject) => LessonContent(
        id: 'l-$subject',
        lessonId: 'l-$subject',
        grade: 'الصف الرابع',
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

  group("the student sees their own teacher's tree", () {
    // ‏إعداد المشرف — وكل إعداد بلا مالك — كان يُعرض لكل طالب مهما كان
    // ‏معلّمه. فيظهر في شاشة الطالب صفٌّ لا يعرفه معلّمه ولا يجده في
    // ‏إعداداته حين يبحث عنه، وهو ما وقع فعلاً مع «الصف الأول الابتدائي».
    List<Object?> ownedBy(String owner, String grade) => [
          {
            'grade': grade,
            'createdBy': owner,
            'subjects': [
              {
                'subject': 'العلوم',
                'terms': [
                  {'term': 'الأول', 'units': ['و١']},
                ],
              },
            ],
          },
        ];

    List<String> gradesOf(List<AcademicPath> paths) =>
        paths.map((path) => path.grade).toSet().toList();

    test('a grade from another tree does not reach them', () {
      final paths = StudentContentService.academicPaths(
        hierarchyValue: [
          ...ownedBy('t1', 'الصف الرابع'),
          ...ownedBy('admin', 'الصف الأول الابتدائي'),
        ],
        hierarchyUnavailable: false,
        lessons: const [],
        profile: profile,
      );

      expect(gradesOf(paths), ['الصف الرابع']);
      expect(gradesOf(paths), isNot(contains('الصف الأول الابتدائي')));
    });

    test('an unowned entry is treated the same way', () {
      final paths = StudentContentService.academicPaths(
        hierarchyValue: [
          ...ownedBy('t1', 'الصف الرابع'),
          {
            'grade': 'صفّ قديم بلا مالك',
            'subjects': [
              {
                'subject': 'العلوم',
                'terms': [
                  {'term': 'الأول', 'units': ['و١']},
                ],
              },
            ],
          },
        ],
        hierarchyUnavailable: false,
        lessons: const [],
        profile: profile,
      );

      expect(gradesOf(paths), ['الصف الرابع']);
    });

    test('where the teacher has no tree, the shared one still shows', () {
      // ‏التركيب الذي يكتب فيه المشرف الشجرة وحده: التضييق يجب ألّا
      // ‏يُفرغ شاشة الطالب فيه.
      final paths = StudentContentService.academicPaths(
        hierarchyValue: ownedBy('admin', 'الصف الأول الابتدائي'),
        hierarchyUnavailable: false,
        lessons: const [],
        profile: profile,
      );

      expect(gradesOf(paths), ['الصف الأول الابتدائي']);
    });
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

  group('a course with no lesson in it yet', () {
    // The reported message: a teacher built the tree and the student was
    // told no course was linked to their account, which sent them looking
    // at the wrong thing. The two states are now told apart.
    final path = AcademicPath(
      grade: 'الصف الرابع',
      subject: 'العلوم',
      term: 'الفصل الثاني',
      unit: 'الوحدة الأولى',
    );

    test('has a path, so the board is shown', () {
      final data = AcademicSelectionData(paths: [path], lessons: const []);
      expect(data.hasPaths, isTrue);
      expect(data.hasLessons, isFalse,
          reason: 'nothing has been published or named under it yet');
    });

    test('a lesson named in the settings counts as something to open', () {
      final data = AcademicSelectionData(
        paths: [path],
        lessons: const [],
        declaredLessons: [DeclaredLesson(path: path, name: 'الخلية')],
      );
      expect(data.hasLessons, isTrue);
    });

    test('no path at all is a different state', () {
      const data = AcademicSelectionData(paths: [], lessons: []);
      expect(data.hasPaths, isFalse);
      expect(data.hasLessons, isFalse);
    });
  });

  group('the same teacher, written down under another name', () {
    // A teacher is recorded as an id on one screen and as a username or a
    // display name on another. Matching the student's stored value alone
    // hid a teacher's own course from their own student whenever the two
    // records disagreed about which to use.
    const byUsername = StudentProfile(
      id: 's2',
      name: 'طالب',
      username: 'j',
      role: 'student',
      teacherId: 'test',
    );

    List<Object?> treeOwnedBy(String owner) => [
          {
            'grade': 'الصف الرابع',
            'createdBy': owner,
            'subjects': [
              {
                'subject': 'العلوم',
                'terms': [
                  {
                    'term': 'الفصل الثاني',
                    'units': ['الوحدة الأولى'],
                  },
                ],
              },
            ],
          },
        ];

    test('the id on the record reaches a student who stores the username', () {
      final paths = StudentContentService.academicPaths(
        hierarchyValue: treeOwnedBy('teacher_1699'),
        hierarchyUnavailable: false,
        lessons: const [],
        profile: byUsername,
        // What the teachers table says this teacher is called.
        identities: const {'test', 'teacher_1699', 'أ. تجريبي'},
      );

      expect(paths, hasLength(1));
      expect(paths.single.subject, 'العلوم');
    });

    test('another teacher is still another teacher', () {
      final paths = StudentContentService.academicPaths(
        hierarchyValue: treeOwnedBy('teacher_other'),
        hierarchyUnavailable: false,
        lessons: const [],
        profile: byUsername,
        identities: const {'test', 'teacher_1699'},
      );

      expect(paths, isEmpty);
    });

    test("the supervisor's own settings reach everyone", () {
      final paths = StudentContentService.academicPaths(
        hierarchyValue: treeOwnedBy('admin'),
        hierarchyUnavailable: false,
        lessons: const [],
        profile: byUsername,
        identities: const {},
      );

      expect(paths, hasLength(1));
    });
  });
}
