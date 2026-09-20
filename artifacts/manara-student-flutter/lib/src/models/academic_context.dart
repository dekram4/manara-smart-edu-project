import 'student_content.dart';

class AcademicContext {
  const AcademicContext({
    required this.grade,
    required this.subject,
    required this.term,
    required this.unit,
    required this.selectedLesson,
  });

  final String grade;
  final String subject;
  final String term;
  final String unit;
  final LessonContent selectedLesson;

  String get lesson => selectedLesson.lessonName;
  String get lessonId => selectedLesson.id;

  /// The tutor and live-meeting experiences must never guess a partial scope.
  /// Requiring every path level keeps links from another class or unit hidden.
  bool get hasCompletePath => [grade, subject, term, unit]
      .every((value) => value.trim().isNotEmpty);

  String get label => [grade, subject, term, unit, lesson]
      .where((value) => value.trim().isNotEmpty)
      .join(' • ');
}

/// A lesson named in the academic settings tree, with the path it sits on.
///
/// Distinct from [AcademicPath] because that type is what unique-path
/// collapsing is keyed on, and two lessons in the same unit share a path.
class DeclaredLesson {
  const DeclaredLesson({
    required this.path,
    required this.name,
  });

  final AcademicPath path;
  final String name;

  /// A stable id for the placeholder built from this, so selecting a
  /// declared lesson and coming back reaches the same entry. Prefixed so
  /// it can never collide with a real `lesson_configs` row id.
  String get placeholderId => 'declared:'
      '${path.grade}|${path.subject}|${path.term}|${path.unit}|$name';
}

class AcademicPath {
  const AcademicPath({
    required this.grade,
    required this.subject,
    required this.term,
    required this.unit,
  });

  final String grade;
  final String subject;
  final String term;
  final String unit;

  bool matches({
    String? grade,
    String? subject,
    String? term,
    String? unit,
  }) {
    return _matches(this.grade, grade) &&
        _matches(this.subject, subject) &&
        _matches(this.term, term) &&
        _matches(this.unit, unit);
  }

  static bool _matches(String value, String? expected) {
    if (expected == null || expected.trim().isEmpty) return true;
    return _normalize(value) == _normalize(expected);
  }
}

class AcademicSelectionData {
  const AcademicSelectionData({
    required this.paths,
    required this.lessons,
    this.hierarchyUnavailable = false,
    this.declaredLessons = const [],
  });

  final List<AcademicPath> paths;
  final List<LessonContent> lessons;
  final bool hierarchyUnavailable;

  /// Lessons the teacher named in the academic settings but has not
  /// published content for yet.
  ///
  /// The settings tree is already the source of truth for which grades,
  /// subjects, chapters and units exist — a branch with no lesson shows its
  /// own empty state rather than being hidden. The lesson level now works
  /// the same way: a lesson named in the settings is offered to the
  /// student the moment it is saved, and opening it shows the same "no
  /// content yet" state. Without this the lesson field would be a box a
  /// teacher types into that changes nothing the student can see until a
  /// separate lesson record happens to be published under the same name.
  ///
  /// Optional and defaulted, so every existing caller is unaffected.
  final List<DeclaredLesson> declaredLessons;

  /// A teacher who has named lessons in the settings but not published
  /// content for any of them still has a usable course: the paths and the
  /// lesson names are there to pick through. Counting only published
  /// lessons here sent that teacher's students to the "no courses at all"
  /// screen, which is the opposite of what the settings tree says.
  bool get isEmpty =>
      paths.isEmpty || (lessons.isEmpty && declaredLessons.isEmpty);

  List<String> get grades => _values(paths.map((path) => path.grade));

  /// Every subject taught in a grade.
  List<String> subjectsFor({required String grade}) => _values(
        paths
            .where((path) => path.matches(grade: grade))
            .map((path) => path.subject),
      );

  List<String> termsFor({
    required String grade,
    required String subject,
  }) =>
      _values(
        paths
            .where((path) => path.matches(grade: grade, subject: subject))
            .map((path) => path.term),
      );

  List<String> unitsFor({
    required String grade,
    required String subject,
    required String term,
  }) =>
      _values(
        paths
            .where(
              (path) => path.matches(
                grade: grade,
                subject: subject,
                term: term,
              ),
            )
            .map((path) => path.unit),
      );

  List<LessonContent> lessonsFor({
    required String grade,
    required String subject,
    required String term,
    required String unit,
  }) {
    final published = lessons
        .where(
          (lesson) =>
              _matches(lesson.grade, grade) &&
              _matches(lesson.subject, subject) &&
              _matches(lesson.term, term) &&
              _matches(lesson.unit, unit),
        )
        .toList();

    if (declaredLessons.isEmpty) return published;

    // Published content always wins over a bare name from the settings
    // tree: a lesson the teacher has actually filled in must keep its
    // videos, text and games rather than being shadowed by the empty
    // placeholder that carries the same title.
    final publishedNames = published
        .map((lesson) => lesson.lessonName.trim().toLowerCase())
        .toSet();

    for (final declared in declaredLessons) {
      if (!_matches(declared.path.grade, grade) ||
          !_matches(declared.path.subject, subject) ||
          !_matches(declared.path.term, term) ||
          !_matches(declared.path.unit, unit)) {
        continue;
      }
      if (publishedNames.contains(declared.name.trim().toLowerCase())) continue;
      published.add(
        LessonContent(
          id: declared.placeholderId,
          lessonId: declared.placeholderId,
          grade: declared.path.grade,
          subject: declared.path.subject,
          term: declared.path.term,
          unit: declared.path.unit,
          lessonName: declared.name,
          createdAt: '',
          videos: const [],
          games: const [],
        ),
      );
    }
    return published;
  }

  static List<String> _values(Iterable<String> values) {
    final unique = <String>[];
    for (final value in values) {
      final clean = value.trim();
      if (clean.isNotEmpty && !unique.any((item) => _normalize(item) == _normalize(clean))) {
        unique.add(clean);
      }
    }
    return unique;
  }

  static bool _matches(String value, String expected) {
    return _normalize(value) == _normalize(expected);
  }
}

String _normalize(Object? value) => value?.toString().trim().toLowerCase() ?? '';

class StudentAcademicValues {
  const StudentAcademicValues({
    this.grade,
    this.term,
    this.subject,
    this.unit,
    this.lesson,
  });

  final String? grade;
  final String? term;
  final String? subject;
  final String? unit;
  final String? lesson;
}