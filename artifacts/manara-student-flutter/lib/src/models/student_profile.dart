class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    this.grade,
    this.atram,
    this.subject,
    this.term,
    this.unit,
    this.teacherId,
    this.studentIdNumber,
    this.appearance,
  });

  factory StudentProfile.fromStudentRow(Map<String, dynamic> row) {
    final data = _asMap(row['data']);
    final id = _asText(row['id']) ?? _asText(data['id']) ?? '';
    final username = _asText(data['username']) ?? '';

    return StudentProfile(
      id: id,
      username: username,
      name: _asText(data['name']) ?? _asText(data['fullName']) ?? username,
      role: (_asText(data['role']) ?? _asText(data['userRole']) ?? 'student').toLowerCase(),
      grade: _asText(data['primaryGrade']) ?? _asText(data['grade']),
      atram: _asText(data['atram']),
      subject: _asText(data['subject']),
      term: _asText(data['term']),
      unit: _asText(data['unit']),
      teacherId: _asText(data['teacherId']) ?? _asText(data['teacher_id']),
      studentIdNumber: _asText(data['studentIdNumber']),
      appearance: _asMap(data['appearance']),
    );
  }

  factory StudentProfile.fromAuthProfile({
    required String id,
    required Map<String, dynamic> profile,
    required String username,
  }) {
    return StudentProfile(
      id: id,
      username: username,
      name: _asText(profile['full_name']) ?? _asText(profile['name']) ?? username,
      role: (_asText(profile['role']) ?? '').toLowerCase(),
      grade: _asText(profile['grade']),
      atram: _asText(profile['atram']),
      subject: _asText(profile['subject']),
      term: _asText(profile['term']),
      unit: _asText(profile['unit']),
      teacherId: _asText(profile['teacher_id']) ?? _asText(profile['teacherId']),
      studentIdNumber: _asText(profile['student_id_number']),
    );
  }

  final String id;
  final String username;
  final String name;
  final String role;
  final String? grade;
  final String? atram;
  final String? subject;
  final String? term;
  final String? unit;
  final String? teacherId;
  final String? studentIdNumber;
  final Map<String, dynamic>? appearance;

  bool get isStudent => role == 'student';
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

String? _asText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}