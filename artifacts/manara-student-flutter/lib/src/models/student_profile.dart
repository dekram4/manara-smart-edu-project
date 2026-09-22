import 'academic_context.dart';
import 'student_gamification.dart';

/// أسماء نظيفة من قيمة قد تكون قائمة أو نصاً مفصولاً بفواصل.
List<String> _asNameList(Object? value) {
  final raw = value is List
      ? value
      : value is String
          ? value.split(',')
          : const [];
  final names = <String>[];
  for (final item in raw) {
    final name = item?.toString().trim() ?? '';
    if (name.isNotEmpty) names.add(name);
  }
  return names;
}

class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    this.grade,
    this.subject,
    this.term,
    this.unit,
    this.teacherId,
    this.studentIdNumber,
    this.appearance,
    this.canAccessChat = true,
    this.canAccessLiveMeeting = true,
    this.assignedSubjects = const [],
    this.gamification = const StudentGamification(),
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
      subject: _asText(data['subject']),
      term: _asText(data['term']),
      unit: _asText(data['unit']),
      teacherId: _asText(data['teacherId']) ?? _asText(data['teacher_id']),
      studentIdNumber: _asText(data['studentIdNumber']),
      appearance: _asMap(data['appearance']),
      canAccessChat: _asBool(data['canAccessChat'], fallback: true),
      canAccessLiveMeeting: _asBool(data['canAccessLiveMeeting'], fallback: true),
      assignedSubjects: _asNameList(data['assignedSubjects']),
      gamification: StudentGamification.fromMap(data['gamification']),
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
      subject: _asText(profile['subject']),
      term: _asText(profile['term']),
      unit: _asText(profile['unit']),
      teacherId: _asText(profile['teacher_id']) ?? _asText(profile['teacherId']),
      studentIdNumber: _asText(profile['student_id_number']),
      canAccessChat: _asBool(profile['can_access_chat'] ?? profile['canAccessChat'],
          fallback: true),
      canAccessLiveMeeting: _asBool(
        profile['can_access_live_meeting'] ?? profile['canAccessLiveMeeting'],
        fallback: true,
      ),
      // ‏بالاسمين: جدول `profiles` يكتب بالشرطة السفلية وسجلّ الطالب
      // ‏بالسنام. وإغفاله هنا كان يعني قائمةً فارغة تُقرأ «كل المواد»،
      // ‏فينفتح للطالب ما قُيّد عنه — والخطأ في اتجاه التوسيع لا يُرى.
      assignedSubjects: _asNameList(
        profile['assignedSubjects'] ?? profile['assigned_subjects'],
      ),
      gamification: StudentGamification.fromMap(profile['gamification']),
    );
  }

  final String id;
  final String username;
  final String name;
  final String role;
  final String? grade;
  final String? subject;
  final String? term;
  final String? unit;
  final String? teacherId;
  final String? studentIdNumber;
  final Map<String, dynamic>? appearance;
  final bool canAccessChat;
  final bool canAccessLiveMeeting;

  /// المواد التي يُسمح لهذا الطالب بدخولها، من مواد معلّمه.
  ///
  /// قائمة فارغة تعني «كل المواد» — وهي حال كل طالب سُجِّل قبل وجود هذا
  /// الحقل. فالسجلّات القديمة تبقى مفتوحة كما كانت، ولا يُغلَق باب كان
  /// مفتوحاً لطفل لمجرّد أن حقلاً أُضيف إلى النظام.
  final List<String> assignedSubjects;

  /// هل هذه المادة من نصيب هذا الطالب؟
  ///
  /// نقطة واحدة يسألها كل من يعرض المواد — شاشة المسار وورقة تغيير
  /// الدرس — فلا تفترق القاعدة بين موضع وآخر فيرى الطالب في إحداهما ما
  /// مُنع منه في الأخرى.
  bool allowsSubject(String subject) {
    if (assignedSubjects.isEmpty) return true;
    final wanted = subject.trim().toLowerCase();
    return assignedSubjects.any((item) => item.trim().toLowerCase() == wanted);
  }

  final StudentGamification gamification;

  StudentAcademicValues get academicValues => StudentAcademicValues(
        grade: grade,
        term: term,
        subject: subject,
        unit: unit,
      );

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

bool _asBool(Object? value, {required bool fallback}) {
  if (value is bool) return value;
  final normalized = _asText(value)?.toLowerCase();
  if (normalized == 'true' || normalized == '1') return true;
  if (normalized == 'false' || normalized == '0') return false;
  return fallback;
}