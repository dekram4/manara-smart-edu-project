import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/services/student_content_service.dart';

/// The contract between the dashboard and this app.
///
/// The teacher's six-level tree is written to Supabase as one JSON blob
/// under `app_kv['smartEdu_hierarchicalConfigs']`, and the lessons live in
/// `term.lessons` — a map keyed by unit name rather than nested inside
/// `units`, because that shape keeps settings written before the lesson
/// field existed readable without a migration.
///
/// Nothing in either codebase enforces that agreement at compile time, so
/// these pin it against the literal JSON the dashboard produces. If the
/// panel ever changes where it writes lessons, this fails here rather than
/// showing a student an empty lesson list.
void main() {
  const profile = StudentProfile(
    id: 's1',
    name: 'طالب',
    username: 'student',
    role: 'student',
    teacherId: 't1',
  );

  /// Exactly what the dashboard's writeLessons() produces, teacher-owned.
  List<Object?> hierarchy({Map<String, Object?>? lessons}) => [
        {
          'grade': 'الصف الرابع',
          'createdBy': 't1',
          'atrams': [
            {
              'atram': 'الترم الأول',
              'subjects': [
                {
                  'subject': 'العلوم',
                  'terms': [
                    {
                      'term': 'الفصل الثاني',
                      'units': ['الوحدة الأولى', 'الوحدة الثانية'],
                      if (lessons != null) 'lessons': lessons,
                    },
                  ],
                },
              ],
            },
          ],
        },
      ];

  test('reads every lesson the teacher typed, on its own unit', () {
    final declared = declaredLessonsFromHierarchy(
      hierarchy(lessons: {
        'الوحدة الأولى': ['الخلية', 'الأنسجة'],
        'الوحدة الثانية': ['الذرة'],
      }),
      profile,
    );

    expect(declared.length, 3);
    final first = declared.firstWhere((lesson) => lesson.name == 'الخلية');
    expect(first.path.grade, 'الصف الرابع');
    expect(first.path.atram, 'الترم الأول');
    expect(first.path.subject, 'العلوم');
    expect(first.path.term, 'الفصل الثاني');
    expect(first.path.unit, 'الوحدة الأولى');

    expect(
      declared.firstWhere((lesson) => lesson.name == 'الذرة').path.unit,
      'الوحدة الثانية',
    );
  });

  test('settings written before the lesson field still read cleanly', () {
    // No `lessons` key at all — the shape every existing teacher has.
    expect(declaredLessonsFromHierarchy(hierarchy(), profile), isEmpty);
  });

  test('a unit with an empty lesson list contributes nothing', () {
    final declared = declaredLessonsFromHierarchy(
      hierarchy(lessons: {'الوحدة الأولى': <String>[]}),
      profile,
    );
    expect(declared, isEmpty);
  });

  test('blank and duplicate lesson names are dropped', () {
    final declared = declaredLessonsFromHierarchy(
      hierarchy(lessons: {
        'الوحدة الأولى': ['الخلية', '   ', 'الخلية'],
      }),
      profile,
    );
    // A blank tile cannot be picked, and two identical entries would give
    // the student the same lesson twice.
    expect(declared.map((lesson) => lesson.name).toList(), ['الخلية']);
  });

  test('another teacher\'s tree is not read into this student', () {
    final otherTeacher = [
      {
        'grade': 'الصف الرابع',
        'createdBy': 'someone-else',
        'atrams': [
          {
            'atram': 'الترم الأول',
            'subjects': [
              {
                'subject': 'العلوم',
                'terms': [
                  {
                    'term': 'الفصل الثاني',
                    'units': ['الوحدة الأولى'],
                    'lessons': {
                      'الوحدة الأولى': ['درس ليس له'],
                    },
                  },
                ],
              },
            ],
          },
        ],
      },
    ];
    expect(declaredLessonsFromHierarchy(otherTeacher, profile), isEmpty);
  });

  test('malformed stored data is empty rather than a crash', () {
    // This blob comes off the wire; every one of these has been seen in
    // some form from older writers.
    expect(declaredLessonsFromHierarchy(null, profile), isEmpty);
    expect(declaredLessonsFromHierarchy('not a list', profile), isEmpty);
    expect(declaredLessonsFromHierarchy([null, 42, 'x'], profile), isEmpty);
    expect(
      declaredLessonsFromHierarchy(
        // lessons present but the wrong type
        hierarchy(lessons: {'الوحدة الأولى': 'الخلية'}),
        profile,
      ),
      isEmpty,
    );
  });

  test('the same lesson written twice is only offered once', () {
    final twice = [...hierarchy(lessons: {
      'الوحدة الأولى': ['الخلية'],
    }), ...hierarchy(lessons: {
      'الوحدة الأولى': ['الخلية'],
    })];
    expect(declaredLessonsFromHierarchy(twice, profile).length, 1);
  });
}
