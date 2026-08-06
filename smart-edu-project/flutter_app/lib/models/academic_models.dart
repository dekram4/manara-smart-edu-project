class AcademicUnit {
  const AcademicUnit({
    required this.grade,
    this.atram = '',
    required this.subject,
    required this.term,
    required this.unit,
    this.createdBy = 'admin',
    this.createdByName = 'المشرف',
  });

  final String grade;
  final String atram;
  final String subject;
  final String term;
  final String unit;
  final String createdBy;
  final String createdByName;
}

/// The legacy platform's canonical hierarchy:
/// grade -> atram -> subject -> term -> units.
class HierarchicalConfig {
  const HierarchicalConfig({
    required this.grade,
    required this.atrams,
    this.createdBy = 'admin',
    this.createdByName = 'المشرف',
    this.createdAt = '',
    this.createdByAdmin = false,
    this.copiedFrom,
    this.copiedFromName,
  });

  final String grade;
  final List<AcademicAtram> atrams;
  final String createdBy;
  final String createdByName;
  final String createdAt;
  final bool createdByAdmin;
  final String? copiedFrom;
  final String? copiedFromName;
}

class AcademicAtram {
  const AcademicAtram({required this.atram, required this.subjects});
  final String atram;
  final List<AcademicSubject> subjects;
}

class AcademicHierarchy {
  const AcademicHierarchy({
    required this.grade,
    required this.terms,
    this.createdBy = 'admin',
    this.createdByName = 'المشرف',
  });

  final String grade;
  final List<AcademicTerm> terms;
  final String createdBy;
  final String createdByName;
}

class AcademicTerm {
  const AcademicTerm({required this.atram, required this.subjects});

  final String atram;
  final List<AcademicSubject> subjects;
}

class AcademicSubject {
  const AcademicSubject({required this.subject, required this.terms});

  final String subject;
  final List<AcademicTermUnits> terms;
}

class AcademicTermUnits {
  const AcademicTermUnits({required this.term, required this.units});

  final String term;
  final List<String> units;
}