class AcademicContext {
  const AcademicContext({
    required this.grade,
    required this.term,
    required this.subject,
    required this.unit,
    required this.lesson,
  });

  final String grade;
  final String term;
  final String subject;
  final String unit;
  final String lesson;

  String get label => [grade, term, subject, unit, lesson]
      .where((value) => value.trim().isNotEmpty)
      .join(' • ');
}

class AcademicOptions {
  const AcademicOptions({
    required this.grades,
    required this.terms,
    required this.subjects,
    required this.units,
    required this.lessons,
  });

  factory AcademicOptions.defaults(StudentAcademicValues values) {
    return AcademicOptions(
      grades: _withValue(const ['الصف الأول'], values.grade),
      terms: _withValue(const ['الفصل الدراسي الأول'], values.term),
      subjects: _withValue(const ['المادة الدراسية'], values.subject),
      units: _withValue(const ['الوحدة الأولى'], values.unit),
      lessons: _withValue(const ['الدرس الأول'], values.lesson),
    );
  }

  final List<String> grades;
  final List<String> terms;
  final List<String> subjects;
  final List<String> units;
  final List<String> lessons;

  AcademicOptions merge(AcademicOptions other) {
    return AcademicOptions(
      grades: _merge(grades, other.grades),
      terms: _merge(terms, other.terms),
      subjects: _merge(subjects, other.subjects),
      units: _merge(units, other.units),
      lessons: _merge(lessons, other.lessons),
    );
  }

  static List<String> _withValue(List<String> defaults, String? value) {
    return _merge(defaults, [if (value != null) value]);
  }

  static List<String> _merge(Iterable<String> first, Iterable<String> second) {
    final values = <String>[];
    for (final value in [...first, ...second]) {
      final clean = value.trim();
      if (clean.isNotEmpty && !values.contains(clean)) values.add(clean);
    }
    return values;
  }
}

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
