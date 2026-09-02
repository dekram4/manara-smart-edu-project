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
      grades: _fallback(const [], values.grade, 'الصف الأول'),
      terms: _fallback(const [], values.term, 'الفصل الدراسي الأول'),
      subjects: _fallback(const [], values.subject, 'المادة الدراسية'),
      units: _fallback(const [], values.unit, 'الوحدة الأولى'),
      lessons: _fallback(const [], values.lesson, 'الدرس الأول'),
    );
  }

  const AcademicOptions.empty()
      : grades = const [],
        terms = const [],
        subjects = const [],
        units = const [],
        lessons = const [];

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

  AcademicOptions withFallback(StudentAcademicValues values) {
    return AcademicOptions(
      grades: _fallback(grades, values.grade, 'الصف الأول'),
      terms: _fallback(terms, values.term, 'الفصل الدراسي الأول'),
      subjects: _fallback(subjects, values.subject, 'المادة الدراسية'),
      units: _fallback(units, values.unit, 'الوحدة الأولى'),
      lessons: _fallback(lessons, values.lesson, 'الدرس الأول'),
    );
  }

  static List<String> _fallback(
    List<String> values,
    String? profileValue,
    String fallback,
  ) {
    final configured = _merge(values, const []);
    if (configured.isNotEmpty) return configured;
    return _merge([if (profileValue != null) profileValue, fallback], const []);
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
