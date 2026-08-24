import 'student_content.dart';

class AcademicContext {
  const AcademicContext({
    required this.grade,
    required this.atram,
    required this.subject,
    required this.term,
    required this.unit,
    required this.selectedLesson,
  });

  final String grade;
  final String atram;
  final String subject;
  final String term;
  final String unit;
  final LessonContent selectedLesson;

  String get lesson => selectedLesson.lessonName;
  String get lessonId => selectedLesson.id;

  /// The tutor and live-meeting experiences must never guess a partial scope.
  /// Requiring every path level keeps links from another class or unit hidden.
  bool get hasCompletePath => [grade, atram, subject, term, unit]
      .every((value) => value.trim().isNotEmpty);

  String get label => [grade, atram, subject, term, unit, lesson]
      .where((value) => value.trim().isNotEmpty)
      .join(' • ');
}

class AcademicPath {
  const AcademicPath({
    required this.grade,
    required this.atram,
    required this.subject,
    required this.term,
    required this.unit,
  });

  final String grade;
  final String atram;
  final String subject;
  final String term;
  final String unit;

  bool matches({
    String? grade,
    String? atram,
    String? subject,
    String? term,
    String? unit,
  }) {
    return _matches(this.grade, grade) &&
        _matches(this.atram, atram) &&
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
  });

  final List<AcademicPath> paths;
  final List<LessonContent> lessons;
  final bool hierarchyUnavailable;

  bool get isEmpty => paths.isEmpty || lessons.isEmpty;

  List<String> get grades => _values(paths.map((path) => path.grade));

  List<String> atramsFor(String grade) => _values(
        paths
            .where((path) => path.matches(grade: grade))
            .map((path) => path.atram),
      );

  List<String> subjectsFor({
    required String grade,
    required String atram,
  }) =>
      _values(
        paths
            .where((path) => path.matches(grade: grade, atram: atram))
            .map((path) => path.subject),
      );

  List<String> termsFor({
    required String grade,
    required String atram,
    required String subject,
  }) =>
      _values(
        paths
            .where(
              (path) => path.matches(
                grade: grade,
                atram: atram,
                subject: subject,
              ),
            )
            .map((path) => path.term),
      );

  List<String> unitsFor({
    required String grade,
    required String atram,
    required String subject,
    required String term,
  }) =>
      _values(
        paths
            .where(
              (path) => path.matches(
                grade: grade,
                atram: atram,
                subject: subject,
                term: term,
              ),
            )
            .map((path) => path.unit),
      );

  List<LessonContent> lessonsFor({
    required String grade,
    required String atram,
    required String subject,
    required String term,
    required String unit,
  }) {
    return lessons
        .where(
          (lesson) =>
              _matches(lesson.grade, grade) &&
              _matches(lesson.atram, atram) &&
              _matches(lesson.subject, subject) &&
              _matches(lesson.term, term) &&
              _matches(lesson.unit, unit),
        )
        .toList();
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