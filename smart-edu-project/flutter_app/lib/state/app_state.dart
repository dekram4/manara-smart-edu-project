import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../models/app_models.dart';
import '../services/auth_service.dart';
import '../models/academic_models.dart';
import '../services/audio_service.dart';
import '../services/data_repository.dart';
import '../services/gamification_engine.dart';
import '../models/gamification_models.dart';
import '../services/learning_assistant_service.dart';
import '../services/speech_service.dart';
import '../services/password_service.dart';

class AppState extends ChangeNotifier {
  AppState({this.remoteRepository}) {
    _restoreSession();
  }

  static const _defaultXp = 680;
  static const _defaultGems = 42;
  static const _defaultStreak = 7;

  UserRole? role;
  UserRole? selectedRole;
  bool ready = false;
  Timer? _foregroundRefreshTimer;
  bool _refreshInFlight = false;
  int _sessionEpoch = 0;
  String displayName = '';
  int xp = _defaultXp;
  int gems = _defaultGems;
  int streak = _defaultStreak;
  int level = 4;
  int selectedTab = 0;
  bool soundEnabled = true;
  String avatar = '🧑‍🚀';
  final Set<String> unlockedAvatars = {'🧑‍🚀'};
  static const Map<String, int> avatarCosts = {
    '🧑‍🚀': 0,
    '👩‍🎨': 20,
    '🧙‍♂️': 35,
    '🦸‍♀️': 50,
    '🧑‍🔬': 65,
    '🧚‍♀️': 80,
    '🐼': 100,
    '🦊': 120,
  };
  bool chatEnabled = true;
  bool allowGradeChange = false;
  double passingScore = 60;
  int maxChildren = 5;
  String adminContact = '';
  int totalQuizzes = 0;
  int totalLessons = 0;
  int totalGames = 0;
  final Set<String> unlockedAchievementTitles = {};
  final Set<String> completedQuests = {};
  final Set<String> completedLessonIds = {};
  final ManaraAuthService auth = const ManaraAuthService();
  final ManaraAudioService audio = ManaraAudioService.instance;
  final ManaraSpeechService speech = ManaraSpeechService.instance;
  final LearningAssistantService learningAssistant =
      const LearningAssistantService();
  final PasswordService passwordService = const PasswordService();
  String adminPasswordHash = '';
  final ManaraRepository? remoteRepository;
  StudentProfile? student;
  TeacherProfile? teacher;
  GuardianProfile? guardian;
  String? userId;

  bool get videoStorageConfigured =>
      remoteRepository?.videoStorageConfigured == true;

  Future<String?> uploadVideoFile({
    required String fileName,
    required List<int> bytes,
    required String contentType,
  }) async {
    final repository = remoteRepository;
    if ((role != UserRole.admin && role != UserRole.teacher) ||
        repository == null ||
        !repository.videoStorageConfigured) {
      return null;
    }
    try {
      return await repository.uploadVideo(
        ownerId: userId ?? role?.name ?? 'admin',
        fileName: fileName,
        bytes: bytes,
        contentType: contentType,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> resolveVideoUrl(String? value) async {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final repository = remoteRepository;
    if (repository == null) return raw;
    try {
      return await repository.resolveVideoUrl(raw);
    } catch (_) {
      return null;
    }
  }
  final List<StudentProfile> students = [
    const StudentProfile(
      id: 'student-1',
      name: 'سلمان أحمد',
      username: 'salman',
      primaryGrade: 'الصف الرابع',
      password:
          '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92',
      enrollments: [
        Enrollment(subject: 'العلوم', atram: 'الفصل الأول', term: 'الترم الأول', unit: 'الوحدة الأولى'),
      ],
    ),
    const StudentProfile(
      id: 'student-2',
      name: 'ليان محمد',
      username: 'layan',
      primaryGrade: 'الصف الثالث',
      password:
          '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92',
      enrollments: [
        Enrollment(subject: 'الرياضيات', atram: 'الفصل الأول', term: 'الترم الأول', unit: 'الوحدة الثانية'),
      ],
    ),
  ];
  final List<TeacherProfile> teachers = [
    const TeacherProfile(
      id: 'teacher-1',
      name: 'أحمد المعلم',
      username: 'ahmad',
      teacherId: 'T-1001',
      subject: 'العلوم',
      password:
          '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92',
    ),
    const TeacherProfile(
      id: 'teacher-2',
      name: 'فاطمة المعلمة',
      username: 'fatima',
      teacherId: 'T-1002',
      subject: 'اللغة العربية',
      password:
          '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92',
    ),
  ];
  final List<GuardianProfile> guardians = [
    const GuardianProfile(
      id: 'guardian-1',
      name: 'ولي الأمر التجريبي',
      username: 'parent',
      phoneNumber: '0500000000',
      childIds: ['student-1'],
      password:
          '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92',
    ),
  ];
  final List<QuizDefinition> quizzes = [
    const QuizDefinition(
      id: 'quiz-1',
      title: 'مراجعة العلوم - الوحدة الأولى',
      subject: 'العلوم',
      grade: 'الصف الرابع',
      questionCount: 10,
      active: true,
    ),
    const QuizDefinition(
      id: 'quiz-2',
      title: 'اختبار الجمع والطرح',
      subject: 'الرياضيات',
      grade: 'الصف الرابع',
      questionCount: 8,
      active: true,
    ),
  ];
  final List<AcademicUnit> academicUnits = [
    const AcademicUnit(grade: 'الصف الرابع', atram: 'الفصل الأول', subject: 'العلوم', term: 'الترم الأول', unit: 'الوحدة الأولى'),
    const AcademicUnit(grade: 'الصف الرابع', atram: 'الفصل الأول', subject: 'الرياضيات', term: 'الترم الأول', unit: 'الوحدة الثانية'),
    const AcademicUnit(grade: 'الصف الثالث', atram: 'الفصل الأول', subject: 'اللغة العربية', term: 'الترم الثاني', unit: 'الوحدة الأولى'),
  ];
  final List<HierarchicalConfig> hierarchicalConfigs = [];
  final List<CertificateRecord> certificates = [];
  final List<QuizResult> quizResults = [];
  final List<InteractionRecord> interactions = [];
  final Map<String, Map<String, bool>> rolePermissions = {
    'teacher': {
      'canManageAcademicSettings': true,
      'canEditGeneralSettings': true,
      'canManageContent': true,
      'canCreateParents': true,
      'canEditParents': true,
      'canDeleteParents': true,
      'canCreateStudents': true,
      'canEditStudents': true,
      'canDeleteStudents': true,
      'canViewReports': true,
      'canManageQuizzes': true,
    },
    'parent': {
      'canCreateStudents': true,
      'canEditStudents': true,
      'canDeleteStudents': false,
      'canViewReports': true,
      'canChangeGrade': false,
      'canChatWithSupport': true,
    },
    'student': {
      'canChangeGrade': false,
      'canAccessChat': true,
      'canAccessLiveMeeting': true,
      'canRetakeQuiz': true,
      'canViewSolutions': true,
      'canDownloadCertificates': true,
    },
  };
  final Map<String, bool> permissions = {
    'manageContent': true,
    'createStudents': true,
    'editStudents': true,
    'deleteStudents': false,
    'createGuardians': true,
    'manageTeachers': true,
    'manageQuizzes': true,
    'viewReports': true,
    'issueCertificates': true,
    'privateChat': true,
  };

  final quests = const [
    Quest(title: 'مهمة اليوم', subtitle: 'أكمل درساً واحداً', icon: '📚', reward: 25),
    Quest(title: 'تحدي السرعة', subtitle: 'أجب عن 5 أسئلة', icon: '⚡', reward: 40),
    Quest(title: 'شاهد وتعلم', subtitle: 'شاهد فيديو العلوم', icon: '🎬', reward: 30),
  ];

  final List<VideoLesson> videos = [
    const VideoLesson(id: 'video-science-1', title: 'رحلة داخل جسم الإنسان', subject: 'العلوم', emoji: '🧬', duration: '08:24', url: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4', isNew: true),
    const VideoLesson(id: 'video-math-1', title: 'الجمع بطريقة ممتعة', subject: 'الرياضيات', emoji: '🔢', duration: '06:12'),
    const VideoLesson(id: 'video-arabic-1', title: 'قصص من لغتنا الجميلة', subject: 'اللغة العربية', emoji: '📖', duration: '10:05'),
  ];
  final List<String> videoNotifications = [];

  List<Achievement> get achievements => ManaraGamificationEngine.achievements
      .map((achievement) => Achievement(
            title: achievement.title,
            icon: achievement.icon,
            description: achievement.description,
            unlocked: unlockedAchievementTitles.contains(achievement.title),
          ))
      .toList();

  final List<Lesson> lessons = [
    const Lesson(
      id: 'lesson-science-1',
      title: 'رحلة داخل جسم الإنسان',
      grade: 'الصف الرابع',
      subject: 'العلوم',
      unit: 'الوحدة الأولى',
      content: 'نتعرف في هذا الدرس على أجهزة الجسم ووظيفة كل جهاز بطريقة ممتعة.',
    ),
    const Lesson(
      id: 'lesson-math-1',
      title: 'الجمع بطريقة ممتعة',
      grade: 'الصف الرابع',
      subject: 'الرياضيات',
      unit: 'الوحدة الثانية',
      content: 'نتعلم استراتيجيات الجمع ونحل مسائل قصيرة خطوة بخطوة.',
    ),
  ];

  List<Lesson> get lessonsForCurrentRole {
    if (role == null) return const [];
    if (role == UserRole.admin) return lessons;
    if (role == UserRole.teacher && teacher != null) {
      final teacherSubject = teacher!.subject?.trim().toLowerCase() ?? '';
      return lessons.where((lesson) {
        final hasExplicitTeacher = lesson.teacherId != null;
        final owned = lesson.teacherId == teacher!.id ||
            lesson.teacherId == teacher!.username ||
            lesson.teacherId == teacher!.teacherId ||
            (!hasExplicitTeacher && lesson.createdBy == teacher!.id) ||
            (!hasExplicitTeacher && lesson.createdBy == teacher!.username) ||
            (!hasExplicitTeacher && lesson.createdByName == teacher!.name);
        final legacySubject = !hasExplicitTeacher &&
            lesson.createdBy == 'admin' &&
            teacherSubject.isNotEmpty &&
            lesson.subject.trim().toLowerCase() == teacherSubject;
        return owned || legacySubject;
      }).toList();
    }
    if (role == UserRole.teacher) return const [];
    if (role != UserRole.student && role != UserRole.guardian) {
      return const [];
    }
    final scopedStudents = _studentsInCurrentScope;
    if (scopedStudents.isEmpty) return const [];
    return lessons.where((lesson) {
      return scopedStudents.any(
        (student) => _lessonMatchesStudent(lesson, student),
      );
    }).toList();
  }

  List<StudentProfile> get _studentsInCurrentScope {
    if (role == UserRole.student) {
      return student == null ? const [] : [student!];
    }
    if (role == UserRole.guardian) {
      final childIds = guardian?.childIds ?? const [];
      return students.where((item) => childIds.contains(item.id)).toList();
    }
    return const [];
  }

  List<AcademicUnit> get academicPathsForCurrentRole {
    final paths = <AcademicUnit>[];

    void addPath({
      required String grade,
      required String atram,
      required String subject,
      required String term,
      required String unit,
      String createdBy = 'admin',
      String createdByName = 'المشرف',
    }) {
      if (grade.trim().isEmpty && subject.trim().isEmpty) return;
      final exists = paths.any(
        (path) =>
            path.grade == grade &&
            path.atram == atram &&
            path.subject == subject &&
            path.term == term &&
            path.unit == unit,
      );
      if (!exists) {
        paths.add(AcademicUnit(
          grade: grade,
          atram: atram,
          subject: subject,
          term: term,
          unit: unit,
          createdBy: createdBy,
          createdByName: createdByName,
        ));
      }
    }

    for (final lesson in lessonsForCurrentRole) {
      addPath(
        grade: lesson.grade,
        atram: lesson.atram,
        subject: lesson.subject,
        term: lesson.term,
        unit: lesson.unit,
        createdBy: lesson.createdBy,
        createdByName: lesson.createdByName,
      );
    }
    for (final video in videosForCurrentRole) {
      addPath(
        grade: video.grade,
        atram: video.atram,
        subject: video.subject,
        term: video.term,
        unit: video.unit,
        createdBy: video.createdBy,
        createdByName: video.createdByName,
      );
    }

    for (final scopedStudent in _studentsInCurrentScope) {
      final defaultGrade = scopedStudent.primaryGrade;
      for (final enrollment in [
        ...scopedStudent.enrollments,
        ...scopedStudent.gradeEnrollments.expand((group) => group.enrollments),
      ]) {
        addPath(
          grade: defaultGrade,
          atram: enrollment.atram,
          subject: enrollment.subject,
          term: enrollment.term,
          unit: enrollment.unit,
        );
      }
    }
    return paths;
  }

  List<VideoLesson> get videosForCurrentRole {
    if (role == null) return const [];
    if (role == UserRole.teacher && teacher != null) {
      final teacherSubject = teacher!.subject?.trim().toLowerCase() ?? '';
      return videos.where((video) {
        final hasExplicitTeacher = video.teacherId != null;
        final owned = video.teacherId == teacher!.id ||
            video.teacherId == teacher!.username ||
            video.teacherId == teacher!.teacherId ||
            (!hasExplicitTeacher && video.createdBy == teacher!.id) ||
            (!hasExplicitTeacher && video.createdBy == teacher!.username) ||
            (!hasExplicitTeacher && video.createdByName == teacher!.name);
        final legacySubject = !hasExplicitTeacher &&
            video.createdBy == 'admin' &&
            teacherSubject.isNotEmpty &&
            video.subject.trim().toLowerCase() == teacherSubject;
        return owned || legacySubject;
      }).toList();
    }
    if (role == UserRole.admin) {
      return videos;
    }
    final scopedStudents = _studentsInCurrentScope;
    final standalone = videos.where((video) {
      return scopedStudents.any((student) => _videoMatchesStudent(video, student));
    }).toList();
    final lessonVideos = lessonsForCurrentRole
        .where((lesson) => _lessonVideoUrl(lesson).isNotEmpty)
        .map(_videoFromLesson)
        .whereType<VideoLesson>()
        .where((video) => !standalone.any(
              (existing) =>
                  existing.id == video.id ||
                  (existing.url ?? '').trim() == (video.url ?? '').trim(),
            ))
        .toList();
    return [...standalone, ...lessonVideos];
  }

  String _lessonVideoUrl(Lesson lesson) {
    final direct = lesson.videoUrl?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    return lesson.explanationVideoUrl.trim();
  }

  VideoLesson _videoFromLesson(Lesson lesson) {
    return VideoLesson(
      id: 'lesson-video-${lesson.id}',
      title: lesson.title,
      subject: lesson.subject,
      emoji: '🎬',
      duration: 'فيديو الدرس',
      url: _lessonVideoUrl(lesson),
      description: lesson.content,
      grade: lesson.grade,
      atram: lesson.atram,
      term: lesson.term,
      unit: lesson.unit,
      createdBy: lesson.createdBy,
      teacherId: lesson.teacherId,
      createdByName: lesson.createdByName,
    );
  }

  bool _lessonMatchesStudent(Lesson lesson, StudentProfile student) {
    final lessonGrade = lesson.grade.trim().toLowerCase();
    final studentGrade = student.primaryGrade.trim().toLowerCase();
    if (lessonGrade.isNotEmpty &&
        studentGrade.isNotEmpty &&
        lessonGrade != studentGrade) {
      return false;
    }

    final enrollments = <Enrollment>[
      ...student.enrollments,
      ...student.gradeEnrollments.expand((group) => group.enrollments),
    ];
    if (enrollments.isNotEmpty &&
        !enrollments.any((enrollment) => _academicValuesMatch(
              lesson.subject,
              lesson.atram,
              lesson.term,
              lesson.unit,
              enrollment,
            ))) {
      return false;
    }
    if (lesson.teacherId != null && lesson.teacherId!.trim().isEmpty) {
      return false;
    }
    return _recordOwnerMatchesStudent(
      lesson.teacherId ?? lesson.createdBy,
      student,
      enrollments,
    );
  }

  bool _videoMatchesStudent(VideoLesson video, StudentProfile student) {
    final videoGrade = video.grade.trim().toLowerCase();
    final studentGrade = student.primaryGrade.trim().toLowerCase();
    if (videoGrade.isNotEmpty &&
        studentGrade.isNotEmpty &&
        videoGrade != studentGrade) {
      return false;
    }

    final enrollments = <Enrollment>[
      ...student.enrollments,
      ...student.gradeEnrollments.expand((group) => group.enrollments),
    ];
    if (enrollments.isNotEmpty &&
        !enrollments.any((enrollment) => _academicValuesMatch(
              video.subject,
              video.atram,
              video.term,
              video.unit,
              enrollment,
            ))) {
      return false;
    }
    if (video.teacherId != null && video.teacherId!.trim().isEmpty) {
      return false;
    }
    return _recordOwnerMatchesStudent(
      video.teacherId ?? video.createdBy,
      student,
      enrollments,
    );
  }

  bool _academicValuesMatch(
    String subject,
    String atram,
    String term,
    String unit,
    Enrollment enrollment,
  ) {
    bool matches(String recordValue, String enrollmentValue) {
      final left = recordValue.trim().toLowerCase();
      final right = enrollmentValue.trim().toLowerCase();
      return left.isEmpty || right.isEmpty || left == right;
    }

    return matches(subject, enrollment.subject) &&
        matches(atram, enrollment.atram) &&
        matches(term, enrollment.term) &&
        matches(unit, enrollment.unit);
  }

  bool _recordOwnerMatchesStudent(
    String rawOwner,
    StudentProfile student,
    List<Enrollment> enrollments,
  ) {
    final owner = rawOwner.trim().toLowerCase();
    if (owner.isEmpty || owner == 'admin') return true;

    // An explicit teacher assignment is authoritative. Do not fall back to
    // another teacher's subject when the assignment is intentionally empty.
    final assignedTeacher = student.teacherId?.trim() ?? '';
    if (student.teacherId != null) {
      if (assignedTeacher.isEmpty) return false;
      final assigned = assignedTeacher.toLowerCase();
      final teacher = teachers.cast<TeacherProfile?>().firstWhere(
            (item) =>
                item?.id.toLowerCase() == assigned ||
                item?.username.toLowerCase() == assigned ||
                item?.teacherId.toLowerCase() == assigned,
            orElse: () => null,
          );
      return assigned == owner ||
          teacher?.id.toLowerCase() == owner ||
          teacher?.username.toLowerCase() == owner ||
          teacher?.teacherId.toLowerCase() == owner;
    }
    if (student.createdBy?.trim().toLowerCase() == owner) return true;
    final ownerTeacher = teachers.cast<TeacherProfile?>().firstWhere(
          (item) =>
              item?.id.toLowerCase() == owner ||
              item?.username.toLowerCase() == owner ||
              item?.teacherId.toLowerCase() == owner,
          orElse: () => null,
        );
    final ownerSubject = ownerTeacher?.subject?.trim().toLowerCase() ?? '';
    return ownerSubject.isNotEmpty &&
        enrollments.any(
          (enrollment) =>
              enrollment.subject.trim().toLowerCase() == ownerSubject,
        );
  }

  List<StudentProfile> get studentsForCurrentTeacher {
    if (role == UserRole.admin) return students;
    if (role != UserRole.teacher || teacher == null) return const [];
    final teacherSubject = teacher!.subject?.trim().toLowerCase() ?? '';
    return students.where((student) {
      final assignedTeacher = student.teacherId?.trim() ?? '';
      final enrollments = <Enrollment>[
        ...student.enrollments,
        ...student.gradeEnrollments.expand((group) => group.enrollments),
      ];
      return student.teacherId == teacher!.id ||
          student.teacherId == teacher!.teacherId ||
          (assignedTeacher.isEmpty &&
              teacherSubject.isNotEmpty &&
              enrollments.any(
        (enrollment) =>
            enrollment.subject.trim().toLowerCase() == teacherSubject,
      ));
    }).toList();
  }

  List<StudentProfile> get studentsForCurrentRole {
    switch (role) {
      case UserRole.admin:
        return students;
      case UserRole.teacher:
        return studentsForCurrentTeacher;
      case UserRole.guardian:
        final childIds = guardian?.childIds ?? const [];
        return students.where((item) => childIds.contains(item.id)).toList();
      case UserRole.student:
        return student == null ? const [] : [student!];
      case null:
        return const [];
    }
  }

  List<GuardianProfile> get guardiansForCurrentRole {
    switch (role) {
      case UserRole.admin:
        return guardians;
      case UserRole.teacher:
        final visibleIds =
            studentsForCurrentTeacher.map((item) => item.id).toSet();
        return guardians
            .where((item) => item.childIds.any(visibleIds.contains))
            .toList();
      case UserRole.guardian:
        return guardian == null ? const [] : [guardian!];
      case UserRole.student:
      case null:
        return const [];
    }
  }

  List<TeacherProfile> get teachersForCurrentRole {
    switch (role) {
      case UserRole.admin:
        return teachers;
      case UserRole.teacher:
        return teacher == null ? const [] : [teacher!];
      case UserRole.student:
        final subjects = student?.enrollments
                .map((item) => item.subject.trim().toLowerCase())
                .where((item) => item.isNotEmpty)
                .toSet() ??
            const <String>{};
        return teachers.where((item) {
          final subject = item.subject?.trim().toLowerCase() ?? '';
          return subject.isEmpty || subjects.contains(subject);
        }).toList();
      case UserRole.guardian:
        final childIds = guardian?.childIds ?? const [];
        final subjects = students
            .where((item) => childIds.contains(item.id))
            .expand((item) => item.enrollments)
            .map((item) => item.subject.trim().toLowerCase())
            .where((item) => item.isNotEmpty)
            .toSet();
        return teachers.where((item) {
          final subject = item.subject?.trim().toLowerCase() ?? '';
          return subject.isEmpty || subjects.contains(subject);
        }).toList();
      case null:
        return const [];
    }
  }

  List<String> get _visibleStudentIds {
    switch (role) {
      case UserRole.student:
        return [userId ?? student?.id ?? ''];
      case UserRole.guardian:
        return guardian?.childIds ?? const [];
      case UserRole.teacher:
        return studentsForCurrentTeacher.map((item) => item.id).toList();
      case UserRole.admin:
        return students.map((item) => item.id).toList();
      case null:
        return const [];
    }
  }

  List<QuizResult> get quizResultsForCurrentRole {
    if (role == UserRole.admin) return quizResults;
    if (role == null) return const [];
    final ids = _visibleStudentIds.toSet();
    return quizResults.where((result) => ids.contains(result.studentId)).toList();
  }

  List<InteractionRecord> get interactionsForCurrentRole {
    if (role == UserRole.admin) return interactions;
    if (role == null) return const [];
    final ids = _visibleStudentIds.toSet();
    return interactions.where((item) => ids.contains(item.studentId)).toList();
  }

  List<QuizDefinition> get quizzesForCurrentRole {
    if (role == null) return const [];
    if (role == UserRole.teacher && teacher != null) {
      final teacherSubject = teacher!.subject?.trim().toLowerCase() ?? '';
      return quizzes.where((quiz) {
        return quiz.createdBy == teacher!.id ||
            quiz.createdBy == teacher!.username ||
            (teacherSubject.isNotEmpty &&
                quiz.subject.trim().toLowerCase() == teacherSubject);
      }).toList();
    }
    if (role == UserRole.admin) {
      return quizzes;
    }
    final scopedStudents = _studentsInCurrentScope;
    if (scopedStudents.isEmpty) return const [];
    final allowedSubjects = scopedStudents
        .expand((item) => item.enrollments)
        .map((item) => item.subject.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
    final allowedGrades = scopedStudents
        .map((item) => item.primaryGrade.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
    return quizzes.where((quiz) {
      final subject = quiz.subject.trim().toLowerCase();
      final grade = quiz.grade.trim().toLowerCase();
      return (subject.isEmpty || allowedSubjects.contains(subject)) &&
          (grade.isEmpty || allowedGrades.contains(grade));
    }).toList();
  }

  List<CertificateRecord> get certificatesForCurrentRole {
    if (role == UserRole.admin) return certificates;
    if (role == null) return const [];
    final visibleIds = _visibleStudentIds.toSet();
    if (role == UserRole.teacher) {
      return certificates.where((item) {
        return item.teacherId == teacher?.id ||
            item.teacherId == teacher?.teacherId ||
            visibleIds.contains(item.studentId);
      }).toList();
    }
    return certificates
        .where((item) => visibleIds.contains(item.studentId))
        .toList();
  }

  List<ChatMessage> get messagesForCurrentRole {
    if (role == UserRole.admin) return messages;
    if (role == null) return const [];
    final activeId = userId ?? '';
    return messages.where((message) {
      if (message.conversationId == 'classroom') return true;
      if (activeId.isEmpty) return false;
      return message.senderId == activeId || message.recipientId == activeId;
    }).toList();
  }

  String privateConversationId(String otherUserId) {
    final ids = [userId ?? '', otherUserId]
        .where((id) => id.isNotEmpty)
        .toList()
      ..sort();
    return 'private-${ids.join('-')}';
  }

  int get unreadMessagesForCurrentRole {
    final activeId = userId ?? '';
    return messagesForCurrentRole.where((message) {
      if (message.read) return false;
      if (message.conversationId == 'classroom') {
        return role == UserRole.admin ||
            message.recipientId.isEmpty ||
            message.recipientId == activeId;
      }
      return message.recipientId == activeId;
    }).length;
  }

  void markConversationRead(String conversationId) {
    final activeId = userId ?? '';
    if (activeId.isEmpty) return;
    var changed = false;
    for (var index = 0; index < messages.length; index++) {
      final message = messages[index];
      if (message.conversationId == conversationId &&
          message.recipientId == activeId &&
          !message.read) {
        messages[index] = ChatMessage(
          id: message.id,
          senderName: message.senderName,
          message: message.message,
          timestamp: message.timestamp,
          conversationId: message.conversationId,
          senderId: message.senderId,
          recipientId: message.recipientId,
          read: true,
        );
        changed = true;
      }
    }
    if (changed) {
      _persistCollections();
      notifyListeners();
    }
  }

  final quizQuestions = const [
    QuizQuestion(
      question: 'ما الجهاز الذي يساعدنا على التنفس؟',
      options: ['الجهاز الهضمي', 'الجهاز التنفسي', 'الجهاز العضلي', 'الجهاز العصبي'],
      correctAnswer: 'الجهاز التنفسي',
    ),
    QuizQuestion(
      question: 'كم يساوي 3 × 4؟',
      options: ['7', '10', '12', '15'],
      correctAnswer: '12',
    ),
    QuizQuestion(
      question: 'أي كلمة تدل على شيء نراه؟',
      options: ['كتاب', 'يكتب', 'جميل', 'بسرعة'],
      correctAnswer: 'كتاب',
    ),
  ];

  final List<ChatMessage> messages = [
    ChatMessage(
      id: 'welcome',
      senderName: 'منارة المعرفة',
      message: 'أهلاً بك! اكتب سؤالك وسيتابع معك معلمك.',
      timestamp: DateTime(2026, 1, 1),
    ),
  ];

  Future<void> _restoreSession() async {
    await speech.init();
    final prefs = await SharedPreferences.getInstance();
    adminPasswordHash = prefs.getString('manara_admin_password') ??
        passwordService.hash('123');
    final savedRole = prefs.getString('manara_role');
    if (savedRole != null) {
      for (final candidate in UserRole.values) {
        if (candidate.name == savedRole) {
          role = candidate;
          break;
        }
      }
      if (role != null) {
        displayName = prefs.getString('manara_display_name') ?? (role == UserRole.student ? 'سلمان' : role!.label);
        userId = prefs.getString('manara_user_id');
      }
    }
    soundEnabled = prefs.getBool('manara_sound_enabled') ?? true;
    speech.enabled = soundEnabled;
    _restoreSystemSettings(prefs);
    _restoreCollections(prefs);
    _restoreAcademicConfigs(prefs.getString('manara_hierarchical_configs'));
    final hasPendingSync = _hasPendingSync(prefs);
    if (!hasPendingSync) {
      await _hydrateRemoteCollections();
    }
    _restoreActiveProfile();
    await _restoreScopedProgress(prefs);
    _restoreAvatar(prefs);
    if (!hasPendingSync) {
      await _hydrateRemoteProgress();
    }
    await _retryPendingSync();
    _startForegroundRefresh();
    ready = true;
    notifyListeners();
  }

  void _startForegroundRefresh() {
    _foregroundRefreshTimer?.cancel();
    if (remoteRepository == null) return;
    _foregroundRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => refreshRemoteData(),
    );
  }

  bool _hasPendingSync(SharedPreferences prefs) =>
      prefs.getBool('manara_sync_pending') == true ||
      (prefs.getStringList('manara_pending_deletes') ?? const []).isNotEmpty;

  String get _progressStorageKey =>
      'manara_progress:${role?.name ?? 'anonymous'}:${userId ?? 'anonymous'}';

  void _restoreSystemSettings(SharedPreferences prefs) {
    chatEnabled = prefs.getBool('admin_chat_enabled') ?? true;
    allowGradeChange = prefs.getBool('admin_allow_grade_change') ?? false;
    passingScore = prefs.getDouble('admin_quiz_passing_score') ?? 60;
    maxChildren = prefs.getInt('admin_max_children') ?? 5;
    adminContact = prefs.getString('admin_contact') ?? '';
  }

  Future<void> saveSystemSettings({
    required bool chatEnabled,
    required bool allowGradeChange,
    required double passingScore,
    required int maxChildren,
    required String adminContact,
  }) async {
    this.chatEnabled = chatEnabled;
    this.allowGradeChange = allowGradeChange;
    this.passingScore = passingScore.clamp(0, 100).toDouble();
    this.maxChildren = maxChildren < 1 ? 1 : maxChildren;
    this.adminContact = adminContact.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('admin_chat_enabled', this.chatEnabled);
    await prefs.setBool('admin_allow_grade_change', this.allowGradeChange);
    await prefs.setDouble('admin_quiz_passing_score', this.passingScore);
    await prefs.setInt('admin_max_children', this.maxChildren);
    await prefs.setString('admin_contact', this.adminContact);
    notifyListeners();
  }

  void _resetActiveUserState() {
    xp = _defaultXp;
    gems = _defaultGems;
    streak = _defaultStreak;
    level = ManaraGamificationEngine.levelFor(xp);
    totalQuizzes = 0;
    totalLessons = 0;
    totalGames = 0;
    unlockedAchievementTitles.clear();
    completedQuests.clear();
    completedLessonIds.clear();
    avatar = '🧑‍🚀';
    unlockedAvatars
      ..clear()
      ..add('🧑‍🚀');
  }

  Future<void> _restoreScopedProgress(SharedPreferences prefs) async {
    _resetActiveUserState();
    if (role == null || userId == null) return;
    final raw = prefs.getString(_progressStorageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return;
      xp = int.tryParse(data['xp']?.toString() ?? '') ?? xp;
      gems = int.tryParse(data['gems']?.toString() ?? '') ?? gems;
      streak = int.tryParse(data['streak']?.toString() ?? '') ?? streak;
      totalQuizzes =
          int.tryParse(data['totalQuizzes']?.toString() ?? '') ?? totalQuizzes;
      totalLessons =
          int.tryParse(data['totalLessons']?.toString() ?? '') ?? totalLessons;
      totalGames =
          int.tryParse(data['totalGames']?.toString() ?? '') ?? totalGames;
      level = ManaraGamificationEngine.levelFor(xp);
      final achievements = data['unlockedAchievements'];
      if (achievements is List) {
        unlockedAchievementTitles.addAll(achievements.map((item) => item.toString()));
      }
      final quests = data['completedQuests'];
      if (quests is List) {
        completedQuests.addAll(quests.map((item) => item.toString()));
      }
      final completed = data['completedLessonIds'];
      if (completed is List) {
        completedLessonIds.addAll(completed.map((item) => item.toString()));
      }
      final avatars = data['unlockedAvatars'];
      if (avatars is List) {
        unlockedAvatars.addAll(avatars.map((item) => item.toString()));
      }
    } catch (_) {
      _resetActiveUserState();
    }
  }

  void _restoreAvatar(SharedPreferences prefs) {
    final saved = prefs.getString('manara_avatar:$_progressStorageKey');
    avatar = saved != null && unlockedAvatars.contains(saved) ? saved : '🧑‍🚀';
  }

  void _restoreActiveProfile() {
    student = null;
    teacher = null;
    guardian = null;
    final activeUserId = userId;
    if (role == null || activeUserId == null) return;
    final prefix = '${role!.name}-';
    final username = activeUserId.startsWith(prefix)
        ? activeUserId.substring(prefix.length).toLowerCase()
        : '';

    switch (role!) {
      case UserRole.student:
        student = students.cast<StudentProfile?>().firstWhere(
              (item) =>
                  item!.id == activeUserId ||
                  (username.isNotEmpty &&
                      item.username.toLowerCase() == username),
              orElse: () => null,
            );
        break;
      case UserRole.teacher:
        teacher = teachers.cast<TeacherProfile?>().firstWhere(
              (item) =>
                  item!.id == activeUserId ||
                  (username.isNotEmpty &&
                      item.username.toLowerCase() == username),
              orElse: () => null,
            );
        break;
      case UserRole.guardian:
        guardian = guardians.cast<GuardianProfile?>().firstWhere(
              (item) =>
                  item!.id == activeUserId ||
                  (username.isNotEmpty &&
                      item.username.toLowerCase() == username),
              orElse: () => null,
            );
        break;
      case UserRole.admin:
        break;
    }
  }

  Future<void> _hydrateRemoteCollections() async {
    final repository = remoteRepository;
    if (repository == null) return;
    final epoch = _sessionEpoch;
    try {
      final remote = await repository.loadCollections();
      if (epoch != _sessionEpoch) return;
      final remoteAcademicUnits = await repository.loadKeyValue('academic_units');
      if (epoch != _sessionEpoch) return;
      if (remoteAcademicUnits is List) {
        academicUnits
          ..clear()
          ..addAll(remoteAcademicUnits.whereType<Map>().map((data) => AcademicUnit(
                grade: data['grade']?.toString() ?? '',
                atram: data['atram']?.toString() ?? '',
                subject: data['subject']?.toString() ?? '',
                term: data['term']?.toString() ?? '',
                unit: data['unit']?.toString() ?? '',
                createdBy: data['createdBy']?.toString() ?? 'admin',
                createdByName: data['createdByName']?.toString() ?? 'المشرف',
              )));
      }
      final remoteHierarchies =
          await repository.loadKeyValue('hierarchical_configs');
      if (epoch != _sessionEpoch) return;
      if (remoteHierarchies is List) {
        _restoreAcademicConfigs(jsonEncode(remoteHierarchies));
      }
      final remoteRolePermissions =
          await repository.loadKeyValue('role_permissions');
      if (epoch != _sessionEpoch) return;
      if (remoteRolePermissions is Map) {
        for (final entry in remoteRolePermissions.entries) {
          if (entry.value is Map) {
            rolePermissions[entry.key.toString()] = (entry.value as Map).map(
              (key, value) => MapEntry(key.toString(), value == true),
            );
          }
        }
      }
      final remoteVideos = await repository.loadKeyValue('videos');
      if (epoch != _sessionEpoch) return;
      if (remoteVideos is List) {
        videos
          ..clear()
          ..addAll(remoteVideos.whereType<Map>().map((data) {
            final url = data['url']?.toString().trim() ?? '';
            return url.isEmpty
                ? null
                : VideoLesson(
                    id: data['id']?.toString() ?? 'video-${data['title']}',
                    title: data['title']?.toString() ?? 'فيديو',
                    subject: data['subject']?.toString() ?? '',
                    emoji: data['emoji']?.toString() ?? '🎬',
                    duration: data['duration']?.toString() ?? '',
                    url: url,
                    description: data['description']?.toString() ?? '',
                    grade: data['grade']?.toString() ?? '',
                    atram: data['atram']?.toString() ?? '',
                    term: data['term']?.toString() ?? '',
                    unit: data['unit']?.toString() ?? '',
                    isNew: data['isNew'] == true,
                    teacherId: data['teacherId']?.toString(),
                    createdBy: data['createdBy']?.toString() ?? 'admin',
                    createdByName:
                        data['createdByName']?.toString() ?? 'المشرف',
                  );
          }).whereType<VideoLesson>());
      }
      final remoteVideoNotifications =
          await repository.loadKeyValue('video_notifications');
      if (epoch != _sessionEpoch) return;
      if (remoteVideoNotifications is List) {
        videoNotifications
          ..clear()
          ..addAll(remoteVideoNotifications.map((item) => item.toString()));
      }
      final remoteStudents = remote['students'] ?? const [];
      if (remoteStudents is List) {
        students
          ..clear()
          ..addAll(remoteStudents.map((data) => StudentProfile(
                id: data['id'].toString(),
                name: data['name']?.toString() ?? '',
                username: data['username']?.toString() ?? '',
                primaryGrade: data['primaryGrade']?.toString() ??
                    data['grade']?.toString() ??
                    '',
                parentId: data['parentId']?.toString(),
                teacherId: data['teacherId']?.toString(),
                password: data['password']?.toString() ?? '',
                parentPhoneNumber: data['parentPhoneNumber']?.toString() ?? '',
                studentIdNumber: data['studentIdNumber']?.toString() ?? '',
                nationalId: data['nationalId']?.toString() ?? '',
                canChangeGrade: data['canChangeGrade'] == true,
                createdBy: data['createdBy']?.toString(),
                lastActivity: data['lastActivity']?.toString() ?? '',
                enrollments: ((data['gradeEnrollments'] as List?) ?? const [])
                    .map((enrollment) => Enrollment(
                          subject: enrollment['subject']?.toString() ?? '',
                          atram: enrollment['atram']?.toString() ?? '',
                          term: enrollment['term']?.toString() ?? '',
                          unit: enrollment['unit']?.toString() ?? '',
                        ))
                    .toList(),
                gradeEnrollments:
                    ((data['gradeEnrollmentGroups'] as List?) ?? const [])
                        .whereType<Map>()
                        .map((grade) => GradeEnrollment(
                              grade: grade['grade']?.toString() ?? '',
                              enrollments:
                                  ((grade['enrollments'] as List?) ?? const [])
                                      .whereType<Map>()
                                      .map((enrollment) => Enrollment(
                                            subject: enrollment['subject']
                                                    ?.toString() ??
                                                '',
                                            atram: enrollment['atram']
                                                    ?.toString() ??
                                                '',
                                            term: enrollment['term']?.toString() ??
                                                '',
                                            unit: enrollment['unit']?.toString() ??
                                                '',
                                          ))
                                      .toList(),
                            ))
                        .toList(),
                createdAt: data['createdAt']?.toString() ?? '',
              )));
      }
      final remoteTeachers = remote['teachers'] ?? const [];
      if (remoteTeachers is List) {
        teachers
          ..clear()
          ..addAll(remoteTeachers.map((data) => TeacherProfile(
                id: data['id'].toString(),
                name: data['name']?.toString() ?? '',
                username: data['username']?.toString() ?? '',
                teacherId: data['teacherId']?.toString() ?? '',
                subject: data['subject']?.toString(),
                password: data['password']?.toString() ?? '',
                createdBy: data['createdBy']?.toString() ?? 'admin',
                mustChangePassword: data['mustChangePassword'] == true,
                lastActivity: data['lastActivity']?.toString() ?? '',
              )));
      }
      final remoteParents = remote['parents'] ?? const [];
      if (remoteParents is List) {
        guardians
          ..clear()
          ..addAll(remoteParents.map((data) => GuardianProfile(
                id: data['id'].toString(),
                name: data['name']?.toString() ?? '',
                username: data['username']?.toString() ?? '',
                phoneNumber: data['phoneNumber']?.toString() ?? '',
                nationalId: data['nationalId']?.toString() ?? '',
                password: data['password']?.toString() ?? '',
                childIds: ((data['childIds'] as List?) ?? const [])
                    .map((id) => id.toString())
                    .toList(),
                createdBy: data['createdBy']?.toString() ?? 'admin',
                createdByName: data['createdByName']?.toString() ?? 'المشرف',
                mustChangePassword: data['mustChangePassword'] == true,
              )));
      }
      final remoteLessons = remote['lesson_configs'] ?? const [];
      if (remoteLessons is List) {
        lessons
          ..clear()
          ..addAll(remoteLessons.map((data) => Lesson(
                id: data['id'].toString(),
                title: data['title']?.toString() ?? 'درس',
                grade: data['grade']?.toString() ?? '',
                subject: data['subject']?.toString() ?? '',
                unit: data['unit']?.toString() ?? '',
                content: data['lessonContent']?.toString() ??
                    data['content']?.toString() ??
                    '',
                videoUrl: ((data['videoUrl'] ?? data['explanationVideoUrl'])
                        ?.toString()
                        .trim()
                        .isEmpty ??
                    true)
                    ? null
                    : (data['videoUrl'] ?? data['explanationVideoUrl'])
                        .toString()
                        .trim(),
                atram: data['atram']?.toString() ?? '',
                term: data['term']?.toString() ?? '',
                explanationVideoUrl:
                    data['explanationVideoUrl']?.toString() ?? '',
                avatarInteractionUrl:
                    data['avatarInteractionUrl']?.toString() ?? '',
                liveMeetingUrl: data['liveMeetingUrl']?.toString() ?? '',
                teacherId: data['teacherId']?.toString(),
                createdBy: data['createdBy']?.toString() ?? 'admin',
                createdByName:
                    data['createdByName']?.toString() ?? 'المشرف',
              )));
      }
      final remoteResults = remote['quiz_results'] ?? const [];
      if (remoteResults is List) {
        quizResults
          ..clear()
          ..addAll(remoteResults.map((data) => QuizResult(
                id: data['id'].toString(),
                quizId: data['quizId']?.toString() ?? '',
                quizTitle: data['quizTitle']?.toString() ?? '',
                studentId: data['studentId']?.toString() ?? '',
                studentName: data['studentName']?.toString() ?? '',
                score: int.tryParse(data['score'].toString()) ?? 0,
                total: int.tryParse(data['total'].toString()) ?? 0,
                percentage:
                    double.tryParse(data['percentage'].toString()) ?? 0,
                quizType: data['quizType']?.toString() ?? '',
                subject: data['subject']?.toString() ?? '',
                unit: data['unit']?.toString() ?? '',
                grade: data['grade']?.toString() ?? '',
                level: data['level']?.toString() ?? '',
                feedback: data['feedback']?.toString() ?? '',
                date: data['createdAt']?.toString() ?? '',
                details: ((data['details'] as List?) ?? const [])
                    .map((detail) => QuizAnswerDetail(
                          question: detail['question']?.toString() ?? '',
                          userAnswer: detail['userAnswer']?.toString() ?? '',
                          correctAnswer:
                              detail['correctAnswer']?.toString() ?? '',
                          isCorrect: detail['isCorrect'] == true,
                        ))
                    .toList(),
              )));
      }
      final remoteQuizzes = remote['created_quizzes'] ?? const [];
      if (remoteQuizzes is List) {
        quizzes
          ..clear()
          ..addAll(remoteQuizzes.map((data) => QuizDefinition(
                id: data['id'].toString(),
                title: data['title']?.toString() ?? '',
                subject: data['subject']?.toString() ?? '',
                grade: data['grade']?.toString() ?? '',
                questionCount:
                    int.tryParse(data['questionCount'].toString()) ?? 0,
                active: data['isActive'] != false,
                type: QuizType.values.firstWhere(
                  (value) => value.name == data['quizType']?.toString(),
                  orElse: () => QuizType.unit,
                ),
                atram: data['atram']?.toString() ?? '',
                term: data['term']?.toString() ?? '',
                unit: data['unit']?.toString() ?? '',
                createdBy: data['createdBy']?.toString() ?? 'admin',
                questions: ((data['questions'] as List?) ?? const [])
                    .map((question) => QuizQuestion(
                          id: question['id']?.toString() ?? '',
                          question: question['question']?.toString() ?? '',
                          options: ((question['options'] as List?) ?? const [])
                              .map((option) => option.toString())
                              .toList(),
                          correctAnswer:
                              question['correctAnswer']?.toString() ?? '',
                          lessonId: question['lessonId']?.toString() ?? '',
                          grade: question['grade']?.toString() ?? '',
                          subject: question['subject']?.toString() ?? '',
                          atram: question['atram']?.toString() ?? '',
                          term: question['term']?.toString() ?? '',
                          unit: question['unit']?.toString() ?? '',
                          source: question['source']?.toString() ?? '',
                          variation:
                              int.tryParse(question['variation'].toString()) ??
                                  0,
                        ))
                    .toList(),
              )));
      }
      final remoteInteractions = remote['interactions'] ?? const [];
      if (remoteInteractions is List) {
        interactions
          ..clear()
          ..addAll(remoteInteractions.map((data) => InteractionRecord(
                id: data['id'].toString(),
                studentId: data['studentId']?.toString() ?? '',
                studentName: data['studentName']?.toString() ?? '',
                action: data['action']?.toString() ?? 'other',
                timestamp: data['timestamp']?.toString() ?? '',
                lessonId: data['lessonId']?.toString(),
                grade: data['grade']?.toString(),
                subject: data['subject']?.toString(),
                unit: data['unit']?.toString(),
              )));
      }
      final remoteMessages = [
        ...(remote['public_messages'] ?? const []),
        ...(remote['private_messages'] ?? const []),
      ];
      if (remoteMessages is List) {
        messages
          ..clear()
          ..addAll(remoteMessages.map((data) => ChatMessage(
                id: data['id'].toString(),
                senderName: data['senderName']?.toString() ?? '',
                message: data['message']?.toString() ?? '',
                timestamp:
                    DateTime.tryParse(data['timestamp']?.toString() ?? '') ??
                        DateTime.now(),
                conversationId:
                    data['conversationId']?.toString() ?? 'classroom',
                senderId: data['senderId']?.toString() ?? '',
                recipientId: data['recipientId']?.toString() ?? '',
                read: data['read'] == true,
              )));
      }
      final remoteCertificates = remote['certificates'] ?? const [];
      if (remoteCertificates is List) {
        certificates
          ..clear()
          ..addAll(remoteCertificates.map((data) => CertificateRecord(
                id: data['id'].toString(),
                studentId: data['studentId']?.toString() ?? '',
                studentName: data['studentName']?.toString() ?? '',
                teacherId: data['teacherId']?.toString() ?? '',
                teacherName: data['teacherName']?.toString() ?? '',
                type: CertificateType.values.firstWhere(
                  (value) => value.name == data['type']?.toString(),
                  orElse: () => CertificateType.participation,
                ),
                subject: data['subject']?.toString() ?? '',
                grade: data['grade']?.toString() ?? '',
                atram: data['atram']?.toString() ?? '',
                term: data['term']?.toString() ?? '',
                date: data['date']?.toString() ?? '',
                average: int.tryParse(data['average'].toString()) ?? 0,
                note: data['note']?.toString() ?? '',
              )));
      }
    } catch (_) {
      // Offline-first: keep the hydrated SharedPreferences cache.
    }
  }

  Future<void> _hydrateRemoteProgress() async {
    if (remoteRepository == null ||
        role != UserRole.student ||
        userId == null) {
      return;
    }
    final epoch = _sessionEpoch;
    final sessionKey = _progressStorageKey;
    final prefs = await SharedPreferences.getInstance();
    try {
      final remoteProgress = await remoteRepository!.loadProgress(userId!);
      if (epoch != _sessionEpoch || sessionKey != _progressStorageKey) return;
      if (remoteProgress == null) return;
      final remoteXp = int.tryParse(remoteProgress['xp']?.toString() ?? '');
      final remoteGems =
          int.tryParse(remoteProgress['gems']?.toString() ?? '');
      if (remoteXp != null) {
        xp = remoteXp;
        level = ManaraGamificationEngine.levelFor(xp);
      }
      if (remoteGems != null) gems = remoteGems;
      final remoteCompleted = remoteProgress['completedLessonIds'];
      if (remoteCompleted is List) {
        completedLessonIds.addAll(
          remoteCompleted.map((item) => item.toString()),
        );
      }
      final remoteAvatars = remoteProgress['unlockedAvatars'];
      if (remoteAvatars is List) {
        unlockedAvatars.addAll(
          remoteAvatars
              .map((item) => item.toString())
              .where(avatarCosts.containsKey),
        );
      }
      _restoreAvatar(prefs);
      await _persistProgress();
    } catch (_) {
      // Keep the local progress when the device is offline.
    }
  }

  /// Refreshes remote data when the app returns to the foreground.
  ///
  /// Pending local writes remain authoritative until they are synced, so a
  /// foreground refresh cannot overwrite offline changes in progress.
  Future<void> refreshRemoteData() async {
    if (remoteRepository == null || !ready || _refreshInFlight) return;
    _refreshInFlight = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_hasPendingSync(prefs)) {
        await _retryPendingSync();
        return;
      }
      await _hydrateRemoteCollections();
      await _hydrateRemoteProgress();
      _restoreActiveProfile();
      notifyListeners();
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<void> handleAppResumed() async {
    if (role != null && userId != null) {
      _checkDailyStreak();
    }
    await refreshRemoteData();
  }

  @override
  void dispose() {
    _foregroundRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> chooseRole(UserRole value) async {
    // اختيار البوابة لا يعني تسجيل الدخول بعد؛ لا نحفظ الدور إلا بعد نجاح
    // المصادقة حتى لا تظهر لوحة الحساب عند الرجوع من نموذج دخول فاشل.
    selectedRole = value;
    notifyListeners();
  }

  Future<bool> signIn(UserRole selectedRole, String username, String password) async {
    final loginEpoch = ++_sessionEpoch;
    this.selectedRole = selectedRole;
    role = selectedRole;
    student = null;
    teacher = null;
    guardian = null;
    userId = null;
    _resetActiveUserState();
    final normalizedUsername = username.trim().toLowerCase();
    if (selectedRole == UserRole.admin) {
      final valid = normalizedUsername == 'dekram' &&
          passwordService.matches(password, adminPasswordHash);
      if (!valid) {
        role = null;
        displayName = '';
        return false;
      }
      displayName = 'المشرف العام';
      userId = 'admin';
      final prefs = await SharedPreferences.getInstance();
      if (loginEpoch != _sessionEpoch) return false;
      await _restoreScopedProgress(prefs);
      _restoreAvatar(prefs);
      if (loginEpoch != _sessionEpoch) return false;
      _checkDailyStreak();
      await prefs.setString('manara_role', selectedRole.name);
      await prefs.setString('manara_user_id', 'admin');
      await prefs.setString('manara_display_name', displayName);
      notifyListeners();
      return true;
    }
    final matchingStudent = selectedRole == UserRole.student
        ? students.cast<StudentProfile?>().firstWhere(
              (item) =>
                  item!.username.toLowerCase() == normalizedUsername ||
                  item.studentIdNumber.toLowerCase() == normalizedUsername,
              orElse: () => null,
            )
        : null;
    final matchingTeacher = selectedRole == UserRole.teacher
        ? teachers.cast<TeacherProfile?>().firstWhere(
              (item) => item!.username.toLowerCase() == normalizedUsername,
              orElse: () => null,
            )
        : null;
    final matchingGuardian = selectedRole == UserRole.guardian
        ? guardians.cast<GuardianProfile?>().firstWhere(
              (item) => item!.username.toLowerCase() == normalizedUsername,
              orElse: () => null,
            )
        : null;
    final storedPassword = matchingStudent?.password ??
        matchingTeacher?.password ??
        matchingGuardian?.password ??
        '';
    if (storedPassword.isEmpty ||
        !passwordService.matches(password, storedPassword)) {
      role = null;
      displayName = '';
      return false;
    }
    final session = await auth.signIn(
      role: selectedRole,
      username: normalizedUsername,
      password: password,
      knownUsernames: selectedRole == UserRole.student
          ? {
              ...students.map((item) => item.username.toLowerCase()),
              ...students
                  .map((item) => item.studentIdNumber.trim().toLowerCase())
                  .where((value) => value.isNotEmpty),
            }
          : selectedRole == UserRole.teacher
              ? teachers.map((item) => item.username.toLowerCase()).toSet()
              : selectedRole == UserRole.guardian
                  ? guardians.map((item) => item.username.toLowerCase()).toSet()
                  : const {},
      knownDisplayNames: selectedRole == UserRole.student
          ? {
              for (final item in students) item.username.toLowerCase(): item.name,
              for (final item in students)
                if (item.studentIdNumber.trim().isNotEmpty)
                  item.studentIdNumber.trim().toLowerCase(): item.name,
            }
          : selectedRole == UserRole.teacher
              ? {for (final item in teachers) item.username.toLowerCase(): item.name}
                   : {for (final item in guardians) item.username.toLowerCase(): item.name},
    );
    if (session == null) {
      role = null;
      displayName = '';
      return false;
    }
    if (loginEpoch != _sessionEpoch) return false;
    displayName = session.displayName;
    if (role == UserRole.student) {
      student = matchingStudent;
      userId = matchingStudent?.id ?? session.userId;
    } else if (role == UserRole.teacher) {
      teacher = matchingTeacher;
      userId = matchingTeacher?.id ?? session.userId;
    } else if (role == UserRole.guardian) {
      guardian = matchingGuardian;
      userId = matchingGuardian?.id ?? session.userId;
    }
    if (loginEpoch != _sessionEpoch) return false;
    _checkDailyStreak();
    final prefs = await SharedPreferences.getInstance();
    if (loginEpoch != _sessionEpoch) return false;
    await _restoreScopedProgress(prefs);
    _restoreAvatar(prefs);
    if (remoteRepository != null && role == UserRole.student) {
      try {
        if (!_hasPendingSync(prefs)) {
          final remoteProgress =
              await remoteRepository!.loadProgress(userId!);
          if (loginEpoch != _sessionEpoch) return false;
          final remoteXp =
              int.tryParse(remoteProgress?['xp']?.toString() ?? '');
          final remoteGems =
              int.tryParse(remoteProgress?['gems']?.toString() ?? '');
          if (remoteXp != null) {
            xp = remoteXp;
            level = ManaraGamificationEngine.levelFor(xp);
          }
          if (remoteGems != null) gems = remoteGems;
          final remoteCompleted = remoteProgress?['completedLessonIds'];
          if (remoteCompleted is List) {
            completedLessonIds.addAll(
              remoteCompleted.map((item) => item.toString()),
            );
          }
          final remoteAvatars = remoteProgress?['unlockedAvatars'];
          if (remoteAvatars is List) {
            unlockedAvatars.addAll(
              remoteAvatars
                  .map((item) => item.toString())
                  .where(avatarCosts.containsKey),
            );
          }
          _restoreAvatar(prefs);
        }
        final remoteVideos = await remoteRepository!.videosForStudent(userId!);
        if (loginEpoch != _sessionEpoch) return false;
        if (remoteVideos.isNotEmpty) {
          videos
            ..clear()
            ..addAll(remoteVideos);
        }
      } catch (_) {
        // Keep the local cache when the device is offline.
      }
    }
    if (loginEpoch != _sessionEpoch) return false;
    await prefs.setString('manara_user_id', userId!);
    await prefs.setString('manara_display_name', session.displayName);
    await _persistCollections(prefs);
    if (loginEpoch != _sessionEpoch) return false;
    notifyListeners();
    return true;
  }

  Future<bool> changeAdminPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  }) async {
    if (role != UserRole.admin ||
        newPassword.length < 6 ||
        newPassword != confirmation ||
        !passwordService.matches(currentPassword, adminPasswordHash)) {
      return false;
    }
    adminPasswordHash = passwordService.hash(newPassword);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('manara_admin_password', adminPasswordHash);
    return true;
  }

  Future<bool> completeGuardianSetup({
    required String guardianId,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) return false;
    final index = guardians.indexWhere((item) => item.id == guardianId);
    if (index < 0) return false;
    final old = guardians[index];
    guardians[index] = GuardianProfile(
      id: old.id,
      name: old.name,
      username: old.username,
      phoneNumber: old.phoneNumber,
      nationalId: old.nationalId,
      password: passwordService.hash(newPassword),
      childIds: old.childIds,
      createdBy: old.createdBy,
      createdByName: old.createdByName,
      mustChangePassword: false,
    );
    guardian = guardians[index];
    _persistCollections();
    notifyListeners();
    return true;
  }

  Future<bool> completeTeacherSetup({
    required String teacherId,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) return false;
    final index = teachers.indexWhere((item) => item.id == teacherId);
    if (index < 0) return false;
    final old = teachers[index];
    teachers[index] = TeacherProfile(
      id: old.id,
      name: old.name,
      username: old.username,
      teacherId: old.teacherId,
      subject: old.subject,
      password: passwordService.hash(newPassword),
      createdBy: old.createdBy,
      mustChangePassword: false,
      lastActivity: old.lastActivity,
    );
    teacher = teachers[index];
    await _persistCollections();
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _sessionEpoch++;
    role = null;
    selectedRole = null;
    userId = null;
    student = null;
    teacher = null;
    guardian = null;
    selectedTab = 0;
    _resetActiveUserState();
    avatar = '🧑‍🚀';
    unlockedAvatars
      ..clear()
      ..add('🧑‍🚀');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('manara_role');
    await prefs.remove('manara_user_id');
    await prefs.remove('manara_display_name');
    notifyListeners();
  }

  void setTab(int value) {
    selectedTab = value;
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool value) async {
    soundEnabled = value;
    speech.enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('manara_sound_enabled', value);
    notifyListeners();
  }

  void reward(int amount) {
    xp += amount;
    gems += (amount / 10).round();
    level = ManaraGamificationEngine.levelFor(xp);
    if (soundEnabled) {
      if (amount >= 20) {
        audio.playReward();
      } else {
        audio.playTap();
      }
    }
    _persistProgress();
    notifyListeners();
  }

  double get levelProgress => ManaraGamificationEngine.levelProgressFor(xp);

  void awardReward(RewardAmount reward) {
    xp += reward.xp;
    gems += reward.gems;
    level = ManaraGamificationEngine.levelFor(xp);
    if (soundEnabled && reward.xp > 0) audio.playReward();
    if (level >= 5) unlockAchievement('المستوى 5');
    if (gems >= 50) unlockAchievement('جامع الجواهر');
    _persistProgress();
    notifyListeners();
  }

  void awardProblemSolved() {
    awardReward(ManaraGamificationEngine.problemSolved);
    unlockAchievement('حلال الرياضيات');
    _persistProgress();
    notifyListeners();
  }

  void unlockAchievement(String title) {
    if (unlockedAchievementTitles.add(title)) {
      xp += 25;
      gems += 10;
      level = ManaraGamificationEngine.levelFor(xp);
      if (soundEnabled) audio.playReward();
      _persistProgress();
      notifyListeners();
    }
  }

  void recordInteraction({
    required String action,
    String? lessonId,
    String? grade,
    String? subject,
    String? unit,
  }) {
    interactions.add(InteractionRecord(
      id: 'interaction-${DateTime.now().microsecondsSinceEpoch}',
      studentId: userId ?? student?.id ?? '',
      studentName: displayName,
      action: action,
      timestamp: DateTime.now().toIso8601String(),
      lessonId: lessonId,
      grade: grade,
      subject: subject,
      unit: unit,
    ));
    _persistCollections();
    notifyListeners();
  }

  void _checkDailyStreak() {
    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
    final yesterday = now
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    final epoch = _sessionEpoch;
    final sessionKey = _progressStorageKey;
    SharedPreferences.getInstance().then((prefs) {
      if (epoch != _sessionEpoch || sessionKey != _progressStorageKey) return;
      final lastLogin = prefs.getString('manara_last_login:$sessionKey');
      if (lastLogin == today) return;
      if (lastLogin == yesterday) {
        streak += 1;
        if (streak % 3 == 0) {
          awardReward(ManaraGamificationEngine.streakBonus);
        }
      } else {
        streak = 1;
      }
      if (streak >= 3) unlockAchievement('3 أيام متواصل');
      if (streak >= 7) unlockAchievement('أسبوع متواصل');
      awardReward(ManaraGamificationEngine.dailyLogin);
      if (epoch != _sessionEpoch || sessionKey != _progressStorageKey) return;
      prefs.setString('manara_last_login:$sessionKey', today);
      notifyListeners();
    });
  }

  void completeLesson({String? lessonId, String? subject, String? unit}) {
    final normalizedLessonId = lessonId?.trim() ?? '';
    if (normalizedLessonId.isNotEmpty &&
        !completedLessonIds.add(normalizedLessonId)) {
      return;
    }
    totalLessons++;
    awardReward(ManaraGamificationEngine.lessonComplete);
    recordInteraction(
      action: 'lesson_complete',
      lessonId: lessonId,
      subject: subject,
      unit: unit,
    );
    if (totalLessons == 1) unlockAchievement('أول درس');
    if (totalLessons >= 10) unlockAchievement('سيد الدروس');
    _persistProgress();
  }

  bool isLessonCompleted(String lessonId) =>
      completedLessonIds.contains(lessonId.trim());

  void completeGame({
    String gameType = '',
    bool perfect = false,
    int? score,
    int? total,
  }) {
    totalGames++;
    awardReward(
      perfect
          ? ManaraGamificationEngine.gamePerfect
          : ManaraGamificationEngine.gameWin,
    );
    recordInteraction(
      action: 'game_complete',
      subject: gameType.isEmpty ? null : gameType,
      unit: score == null || total == null ? null : '$score/$total',
    );
    if (totalGames >= 5) unlockAchievement('سيد الألعاب');
    if (gameType == 'memory') unlockAchievement('سيد الذاكرة');
    if (gameType == 'speed') unlockAchievement('سريع كالبرق');
    if (gameType == 'truefalse' && perfect) {
      unlockAchievement('عقل صافي');
    }
    _persistProgress();
  }

  Future<void> completeQuest(int index) async {
    final key = 'quest-$index';
    if (completedQuests.contains(key)) return;
    completedQuests.add(key);
    reward(quests[index].reward);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _progressStorageKey,
      jsonEncode({
        'xp': xp,
        'gems': gems,
        'streak': streak,
        'totalQuizzes': totalQuizzes,
        'totalLessons': totalLessons,
        'totalGames': totalGames,
        'unlockedAchievements': unlockedAchievementTitles.toList(),
        'completedQuests': completedQuests.toList(),
        'completedLessonIds': completedLessonIds.toList(),
        'unlockedAvatars': unlockedAvatars.toList(),
      }),
    );
    notifyListeners();
  }

  Future<bool> setAvatar(String value) async {
    final cost = avatarCosts[value];
    if (cost == null) return false;
    if (!unlockedAvatars.contains(value)) {
      if (gems < cost) return false;
      gems -= cost;
      unlockedAvatars.add(value);
    }
    avatar = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('manara_avatar:$_progressStorageKey', value);
    await _persistProgress();
    notifyListeners();
    return true;
  }

  void sendMessage(String text, {String conversationId = 'classroom', String recipientId = ''}) {
    if (text.trim().isEmpty) return;
    if (conversationId == 'classroom' &&
        !chatEnabled &&
        role != UserRole.admin) {
      return;
    }
    if (conversationId != 'classroom') {
      final activeId = userId ?? '';
      var allowedRecipient = false;
      if (role == UserRole.teacher) {
        allowedRecipient = guardians.any((item) => item.id == recipientId) ||
            studentsForCurrentTeacher.any((item) => item.id == recipientId);
      } else if (role == UserRole.student || role == UserRole.guardian) {
        allowedRecipient = teachers.any((item) => item.id == recipientId);
      } else if (role == UserRole.admin) {
        allowedRecipient = teachers.any((item) => item.id == recipientId) ||
            guardians.any((item) => item.id == recipientId);
      }
      if (activeId.isEmpty || recipientId.trim().isEmpty || !allowedRecipient) {
        return;
      }
    }
    messages.add(ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      senderName: displayName,
      message: text.trim(),
      timestamp: DateTime.now(),
      conversationId: conversationId,
      senderId: userId ?? '',
      recipientId: recipientId,
      read: true,
    ));
    _persistCollections();
    awardReward(ManaraGamificationEngine.chatMessage);
    recordInteraction(action: 'chat_message');
  }

  void addStudent({
    required String name,
    required String username,
    required String grade,
    String? parentId,
    String? teacherId,
    String password = '',
    String parentPhoneNumber = '',
    String studentIdNumber = '',
    String nationalId = '',
    bool canChangeGrade = false,
  }) {
    if (role != UserRole.admin &&
        role != UserRole.teacher &&
        role != UserRole.guardian) {
      return;
    }
    if (role == UserRole.teacher && teacher == null) return;
    if (role == UserRole.guardian && guardian == null) return;
    if (role == UserRole.guardian && parentId != guardian!.id) return;
    if (role == UserRole.guardian &&
        studentsForCurrentRole.length >= maxChildren) {
      return;
    }
    final normalizedUsername = username.trim().toLowerCase();
    if (name.trim().isEmpty ||
        normalizedUsername.isEmpty ||
        students.any((item) => item.username.toLowerCase() == normalizedUsername)) {
      return;
    }
    final studentId = 'student-${DateTime.now().millisecondsSinceEpoch}';
    final effectiveTeacherId = role == UserRole.teacher
        ? teacher!.id
        : (teacherId?.trim().isEmpty == true ? null : teacherId?.trim());
    final availableEnrollments = academicUnits
        .where((item) => item.grade == grade)
        .map((item) => Enrollment(
              subject: item.subject,
              atram: item.atram,
              term: item.term,
              unit: item.unit,
            ))
        .toList();
    final enrollments = availableEnrollments.isEmpty
        ? (role == UserRole.teacher && teacher?.subject?.trim().isNotEmpty == true
            ? [
                Enrollment(
                  subject: teacher!.subject!.trim(),
                  atram: '',
                  term: '',
                  unit: '',
                ),
              ]
            : const <Enrollment>[])
        : availableEnrollments;
    students.add(StudentProfile(
      id: studentId,
      name: name,
      username: normalizedUsername,
      primaryGrade: grade,
      parentId: parentId,
      teacherId: effectiveTeacherId,
      createdBy: role == UserRole.teacher
          ? teacher!.id
          : role == UserRole.admin
              ? 'admin'
              : null,
      password: passwordService.ensureHashed(password),
      parentPhoneNumber: parentPhoneNumber,
      studentIdNumber: studentIdNumber,
      nationalId: nationalId,
      canChangeGrade: canChangeGrade,
      createdAt: DateTime.now().toIso8601String(),
      enrollments: enrollments,
      gradeEnrollments: [
        GradeEnrollment(grade: grade, enrollments: enrollments),
      ],
    ));
    if (parentId != null) {
      final index = guardians.indexWhere((guardian) => guardian.id == parentId);
      if (index >= 0) {
        final parent = guardians[index];
        guardians[index] = GuardianProfile(
          id: parent.id,
          name: parent.name,
          username: parent.username,
          phoneNumber: parent.phoneNumber,
          nationalId: parent.nationalId,
          password: parent.password,
          childIds: {...parent.childIds, studentId}.toList(),
           createdBy: parent.createdBy,
           createdByName: parent.createdByName,
           mustChangePassword: parent.mustChangePassword,
        );
        if (guardian?.id == parentId) {
          guardian = guardians[index];
        }
      }
    }
    _persistCollections();
    notifyListeners();
  }

  void updateStudent({
    required String id,
    required String name,
    required String username,
    required String grade,
    String? parentId,
    String? teacherId,
    String password = '',
    String parentPhoneNumber = '',
    String studentIdNumber = '',
    String nationalId = '',
    bool canChangeGrade = false,
  }) {
    final index = students.indexWhere((item) => item.id == id);
    if (index < 0) return;
    if (!_canManageStudent(students[index])) return;
    if (grade.trim() != students[index].primaryGrade.trim() &&
        role != UserRole.admin &&
        (!allowGradeChange || !students[index].canChangeGrade)) {
      return;
    }
    if (role == UserRole.guardian && parentId != guardian?.id) return;
    if (role == UserRole.teacher &&
        parentId != null &&
        !guardiansForCurrentRole.any((item) => item.id == parentId)) {
      return;
    }
    final effectiveTeacherId = teacherId?.trim().isEmpty == true
        ? null
        : teacherId?.trim();
    students[index] = StudentProfile(
      id: id,
      name: name,
      username: username,
      primaryGrade: grade,
      parentId: parentId,
      teacherId: teacherId == null
          ? students[index].teacherId
          : effectiveTeacherId,
      password: password.isEmpty
          ? students[index].password
          : passwordService.ensureHashed(password),
      parentPhoneNumber: parentPhoneNumber,
      studentIdNumber: studentIdNumber,
      nationalId: nationalId,
      canChangeGrade: canChangeGrade,
      createdAt: students[index].createdAt,
      enrollments: students[index].enrollments,
      gradeEnrollments: students[index].gradeEnrollments,
      createdBy: students[index].createdBy,
    );
    _persistCollections();
    notifyListeners();
  }

  void removeStudent(String id) {
    final target = students.cast<StudentProfile?>().firstWhere(
          (item) => item!.id == id,
          orElse: () => null,
        );
    if (target == null || !_canManageStudent(target)) return;
    students.removeWhere((item) => item.id == id);
    _deleteRemoteRecord('students', id);
    _persistCollections();
    notifyListeners();
  }

  bool usernameAvailable(String username, {String? exceptId}) {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    final all = <String>[
      ...students.where((item) => item.id != exceptId).map((item) => item.username),
      ...teachers.where((item) => item.id != exceptId).map((item) => item.username),
      ...guardians.where((item) => item.id != exceptId).map((item) => item.username),
      'admin',
    ];
    return !all.any((item) => item.toLowerCase() == normalized);
  }

  bool identityAvailable(String identity, {String? exceptId}) {
    final normalized = identity.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    final all = <String>[
      ...students.where((item) => item.id != exceptId).expand((item) => [item.studentIdNumber, item.nationalId]),
      ...teachers.where((item) => item.id != exceptId).map((item) => item.teacherId),
      ...guardians.where((item) => item.id != exceptId).map((item) => item.nationalId),
    ];
    return !all.any((item) => item.trim().toLowerCase() == normalized);
  }

  void addGuardian({
    required String name,
    required String username,
    required String phoneNumber,
    required String nationalId,
    required String password,
    List<String> childIds = const [],
    String createdBy = 'admin',
    String createdByName = 'المشرف',
  }) {
    if (role != UserRole.admin) return;
    guardians.add(GuardianProfile(
      id: 'guardian-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      username: username,
      phoneNumber: phoneNumber,
      nationalId: nationalId,
      password: passwordService.ensureHashed(password),
      childIds: childIds,
      createdBy: createdBy,
      createdByName: createdByName,
      mustChangePassword: true,
    ));
    _linkChildrenToGuardian(childIds, guardians.last.id);
    _persistCollections();
    notifyListeners();
  }

  void updateGuardian({
    required String id,
    required String name,
    required String username,
    required String phoneNumber,
    required String nationalId,
    required String password,
    required List<String> childIds,
  }) {
    if (role != UserRole.admin) return;
    final index = guardians.indexWhere((item) => item.id == id);
    if (index < 0) return;
    guardians[index] = GuardianProfile(
      id: id,
      name: name,
      username: username,
      phoneNumber: phoneNumber,
      nationalId: nationalId,
      password: password.isEmpty
          ? guardians[index].password
          : passwordService.ensureHashed(password),
      childIds: childIds,
      createdBy: guardians[index].createdBy,
      createdByName: guardians[index].createdByName,
      mustChangePassword: guardians[index].mustChangePassword,
    );
    _linkChildrenToGuardian(childIds, id);
    _persistCollections();
    notifyListeners();
  }

  void _linkChildrenToGuardian(List<String> childIds, String guardianId) {
    for (var i = 0; i < students.length; i++) {
      final student = students[i];
      final shouldLink = childIds.contains(student.id);
      if (shouldLink || student.parentId == guardianId) {
        students[i] = StudentProfile(
          id: student.id,
          name: student.name,
          username: student.username,
          primaryGrade: student.primaryGrade,
          enrollments: student.enrollments,
          parentId: shouldLink ? guardianId : null,
          teacherId: student.teacherId,
          createdBy: student.createdBy,
          password: student.password,
          parentPhoneNumber: student.parentPhoneNumber,
          studentIdNumber: student.studentIdNumber,
          nationalId: student.nationalId,
          canChangeGrade: student.canChangeGrade,
          lastActivity: student.lastActivity,
        );
      }
    }
  }

  void removeGuardian(String id) {
    if (role != UserRole.admin) return;
    guardians.removeWhere((item) => item.id == id);
    for (var i = 0; i < students.length; i++) {
      if (students[i].parentId == id) {
        students[i] = StudentProfile(
          id: students[i].id,
          name: students[i].name,
          username: students[i].username,
          primaryGrade: students[i].primaryGrade,
          enrollments: students[i].enrollments,
          createdBy: students[i].createdBy,
          teacherId: students[i].teacherId,
          password: students[i].password,
          parentPhoneNumber: students[i].parentPhoneNumber,
          studentIdNumber: students[i].studentIdNumber,
          nationalId: students[i].nationalId,
          canChangeGrade: students[i].canChangeGrade,
          lastActivity: students[i].lastActivity,
        );
      }
    }
    _deleteRemoteRecord('parents', id);
    _persistCollections();
    notifyListeners();
  }

  void addTeacher({
    required String name,
    required String username,
    required String subject,
    String password = '',
    String teacherId = '',
    String createdBy = 'admin',
  }) {
    if (role != UserRole.admin) return;
    teachers.add(TeacherProfile(
      id: 'teacher-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      username: username,
      teacherId: teacherId.isEmpty ? 'T-${teachers.length + 1001}' : teacherId,
      subject: subject,
      password: passwordService.ensureHashed(password),
      createdBy: createdBy,
      mustChangePassword: true,
    ));
    _persistCollections();
    notifyListeners();
  }

  void removeTeacher(String id) {
    if (role != UserRole.admin) return;
    teachers.removeWhere((item) => item.id == id);
    _deleteRemoteRecord('teachers', id);
    _persistCollections();
    notifyListeners();
  }

  void updateTeacher({
    required String id,
    required String name,
    required String username,
    required String subject,
    required String teacherId,
    String password = '',
  }) {
    if (role != UserRole.admin) return;
    final index = teachers.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final old = teachers[index];
    teachers[index] = TeacherProfile(
      id: id,
      name: name,
      username: username,
      teacherId: teacherId,
      subject: subject,
      password: password.isEmpty
          ? old.password
          : passwordService.ensureHashed(password),
      createdBy: old.createdBy,
      mustChangePassword: old.mustChangePassword,
      lastActivity: old.lastActivity,
    );
    _persistCollections();
    notifyListeners();
  }

  void resetTeacherPassword(String id, String password) {
    if (role != UserRole.admin) return;
    final index = teachers.indexWhere((item) => item.id == id);
    if (index < 0 || password.trim().isEmpty) return;
    final old = teachers[index];
    teachers[index] = TeacherProfile(
      id: old.id,
      name: old.name,
      username: old.username,
      teacherId: old.teacherId,
      subject: old.subject,
      password: passwordService.ensureHashed(password.trim()),
      createdBy: old.createdBy,
      mustChangePassword: true,
      lastActivity: old.lastActivity,
    );
    _persistCollections();
    notifyListeners();
  }

  bool _canManageStudent(StudentProfile target) {
    if (role == UserRole.admin) return true;
    if (role == UserRole.teacher) {
      return studentsForCurrentTeacher.any((item) => item.id == target.id);
    }
    if (role == UserRole.guardian) {
      return guardian?.childIds.contains(target.id) == true;
    }
    return false;
  }

  void addLesson({
    required String title,
    required String subject,
    required String content,
    String grade = 'الصف الرابع',
    String atram = '',
    String term = '',
    String unit = 'وحدة جديدة',
    String explanationVideoUrl = '',
    String avatarInteractionUrl = '',
    String liveMeetingUrl = '',
    String? createdBy,
    String? createdByName,
  }) {
    if (role != UserRole.admin && role != UserRole.teacher) return;
    if (role == UserRole.teacher && !_teacherSubjectMatches(subject)) return;
    final effectiveCreatedBy = createdBy ??
        (role == UserRole.teacher ? teacher?.id ?? 'admin' : 'admin');
    final effectiveCreatedByName = createdByName ??
        (role == UserRole.teacher ? teacher?.name ?? 'المعلم' : 'المشرف');
    lessons.add(Lesson(
      id: 'lesson-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      grade: grade,
      subject: subject,
      unit: unit,
      content: content,
      atram: atram,
      term: term,
      explanationVideoUrl: explanationVideoUrl,
      avatarInteractionUrl: avatarInteractionUrl,
      liveMeetingUrl: liveMeetingUrl,
      teacherId: role == UserRole.teacher ? teacher?.id : createdBy,
      createdBy: effectiveCreatedBy,
      createdByName: effectiveCreatedByName,
    ));
    _persistCollections();
    notifyListeners();
  }

  void updateLesson({
    required String id,
    required String title,
    required String grade,
    required String atram,
    required String subject,
    required String term,
    required String unit,
    required String content,
    String explanationVideoUrl = '',
    String avatarInteractionUrl = '',
    String liveMeetingUrl = '',
  }) {
    final index = lessons.indexWhere((item) => item.id == id);
    if (index < 0) return;
    if (role != UserRole.admin && role != UserRole.teacher) return;
    if (role == UserRole.teacher && !_teacherSubjectMatches(subject)) return;
    final old = lessons[index];
    if (role == UserRole.teacher && !_teacherOwnsLesson(old)) return;
    lessons[index] = Lesson(
      id: id,
      title: title,
      grade: grade,
      atram: atram,
      subject: subject,
      term: term,
      unit: unit,
      content: content,
      explanationVideoUrl: explanationVideoUrl,
      avatarInteractionUrl: avatarInteractionUrl,
      liveMeetingUrl: liveMeetingUrl,
      teacherId: old.teacherId,
      createdBy: old.createdBy,
      createdByName: old.createdByName,
    );
    _persistCollections();
    notifyListeners();
  }

  void removeLesson(String id) {
    if (role != UserRole.admin && role != UserRole.teacher) return;
    if (role == UserRole.teacher) {
      final lesson = lessons.cast<Lesson?>().firstWhere(
            (item) => item!.id == id,
            orElse: () => null,
          );
      if (lesson == null || !_teacherOwnsLesson(lesson)) return;
    }
    lessons.removeWhere((item) => item.id == id);
    _deleteRemoteRecord('lesson_configs', id);
    _persistCollections();
    notifyListeners();
  }

  bool _teacherOwnsLesson(Lesson lesson) {
    final currentTeacher = teacher;
    if (currentTeacher == null) return false;
    final subject = currentTeacher.subject?.trim().toLowerCase() ?? '';
    final hasExplicitTeacher = lesson.teacherId != null;
    return lesson.teacherId == currentTeacher.id ||
        lesson.teacherId == currentTeacher.username ||
        lesson.teacherId == currentTeacher.teacherId ||
        (!hasExplicitTeacher && lesson.createdBy == currentTeacher.id) ||
        (!hasExplicitTeacher && lesson.createdBy == currentTeacher.username) ||
        (!hasExplicitTeacher && lesson.createdByName == currentTeacher.name) ||
        (!hasExplicitTeacher &&
            lesson.createdBy == 'admin' &&
            subject.isNotEmpty &&
            lesson.subject.trim().toLowerCase() == subject);
  }

  bool _teacherSubjectMatches(String subject) {
    if (role != UserRole.teacher) return true;
    final teacherSubject = teacher?.subject?.trim().toLowerCase() ?? '';
    return teacherSubject.isNotEmpty &&
        subject.trim().toLowerCase() == teacherSubject;
  }

  void addVideo({
    required String title,
    required String subject,
    required String duration,
    String url = '',
    String description = '',
    String grade = '',
    String atram = '',
    String term = '',
    String unit = '',
    String? teacherId,
    String? teacherName,
  }) {
    if (role != UserRole.admin && role != UserRole.teacher) return;
    if (role == UserRole.teacher && !_teacherSubjectMatches(subject)) return;
    final owner = role == UserRole.teacher
        ? teacher
        : teachers.cast<TeacherProfile?>().firstWhere(
            (item) => item?.id == teacherId || item?.username == teacherId,
            orElse: () => null,
          );
    if (owner == null && role == UserRole.admin) return;
    videos.add(VideoLesson(
      id: 'video-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      subject: subject,
      emoji: '🎬',
      duration: duration,
      url: url.trim().isEmpty ? null : url.trim(),
      description: description,
      grade: grade,
      atram: atram,
      term: term,
      unit: unit,
      isNew: true,
      teacherId: owner?.id ?? teacherId,
      createdBy: owner?.id ?? teacherId ?? 'admin',
      createdByName: owner?.name ?? teacherName ?? 'المشرف',
    ));
    videoNotifications.insert(
      0,
      'تمت إضافة فيديو جديد: $title • $subject',
    );
    _persistCollections();
    notifyListeners();
  }

  void clearVideoNotifications() {
    videoNotifications.clear();
    _persistCollections();
    notifyListeners();
  }

  void updateVideo({
    required String id,
    required String title,
    required String subject,
    required String duration,
    String url = '',
    String description = '',
    String grade = '',
    String atram = '',
    String term = '',
    String unit = '',
    String? teacherId,
    String? teacherName,
  }) {
    if (role != UserRole.admin && role != UserRole.teacher) return;
    final index = videos.indexWhere((item) => item.id == id);
    if (index < 0 || !_canManageVideo(videos[index])) return;
    if (role == UserRole.teacher && !_teacherSubjectMatches(subject)) return;
    final old = videos[index];
    final selectedTeacher = role == UserRole.teacher
        ? teacher
        : teachers.cast<TeacherProfile?>().firstWhere(
            (item) => item?.id == teacherId || item?.username == teacherId,
            orElse: () => null,
          );
    if (role == UserRole.admin && selectedTeacher == null) return;
    videos[index] = VideoLesson(
      id: old.id,
      title: title,
      subject: subject,
      emoji: old.emoji,
      duration: duration,
      url: url.trim().isEmpty ? null : url.trim(),
      description: description,
      grade: grade,
      atram: atram,
      term: term,
      unit: unit,
      isNew: old.isNew,
      teacherId: selectedTeacher?.id ?? teacherId ?? old.teacherId,
      createdBy: selectedTeacher?.id ?? old.createdBy,
      createdByName: selectedTeacher?.name ?? old.createdByName,
    );
    _persistCollections();
    notifyListeners();
  }

  void removeVideo(String id) {
    if (role != UserRole.admin && role != UserRole.teacher) return;
    final video = videos.cast<VideoLesson?>().firstWhere(
          (item) => item!.id == id,
          orElse: () => null,
        );
    if (video == null || !_canManageVideo(video)) return;
    videos.removeWhere((item) => item.id == id);
    final asset = video.url?.trim() ?? '';
    if (asset.isNotEmpty && !asset.startsWith('http://') && !asset.startsWith('https://')) {
      remoteRepository?.deleteVideoAsset(asset);
    }
    _persistCollections();
    notifyListeners();
  }

  bool _canManageVideo(VideoLesson video) {
    if (role == UserRole.admin) return true;
    if (role != UserRole.teacher || teacher == null) return false;
    final subject = teacher!.subject?.trim().toLowerCase() ?? '';
    final hasExplicitTeacher = video.teacherId != null;
    return video.teacherId == teacher!.id ||
        video.teacherId == teacher!.username ||
        video.teacherId == teacher!.teacherId ||
        (!hasExplicitTeacher && video.createdBy == teacher!.id) ||
        (!hasExplicitTeacher && video.createdBy == teacher!.username) ||
        (!hasExplicitTeacher && video.createdByName == teacher!.name) ||
        (!hasExplicitTeacher &&
            video.createdBy == 'admin' &&
            subject.isNotEmpty &&
            video.subject.trim().toLowerCase() == subject);
  }

  void addAcademicUnit({required String grade, required String atram, required String subject, required String term, required String unit, String createdBy = 'admin', String createdByName = 'المشرف'}) {
    academicUnits.add(AcademicUnit(grade: grade, atram: atram, subject: subject, term: term, unit: unit, createdBy: createdBy, createdByName: createdByName));
    _mergeAcademicUnitIntoHierarchy(
      grade: grade,
      atram: atram,
      subject: subject,
      term: term,
      unit: unit,
      createdBy: createdBy,
      createdByName: createdByName,
    );
    _persistCollections();
    notifyListeners();
  }

  void _mergeAcademicUnitIntoHierarchy({
    required String grade,
    required String atram,
    required String subject,
    required String term,
    required String unit,
    required String createdBy,
    required String createdByName,
  }) {
    final configIndex = hierarchicalConfigs.indexWhere(
      (item) => item.grade == grade && item.createdBy == createdBy,
    );
    final current = configIndex >= 0
        ? hierarchicalConfigs[configIndex]
        : HierarchicalConfig(
            grade: grade,
            createdBy: createdBy,
            createdByName: createdByName,
            createdAt: DateTime.now().toIso8601String(),
            createdByAdmin: createdBy == 'admin',
            atrams: const [],
          );
    final atrams = current.atrams.map((item) => AcademicAtram(
          atram: item.atram,
          subjects: item.subjects
              .map((subjectItem) => AcademicSubject(
                    subject: subjectItem.subject,
                    terms: subjectItem.terms
                        .map((termItem) => AcademicTermUnits(
                              term: termItem.term,
                              units: List<String>.from(termItem.units),
                            ))
                        .toList(),
                  ))
              .toList(),
        )).toList();
    final atramIndex = atrams.indexWhere((item) => item.atram == atram);
    if (atramIndex < 0) {
      atrams.add(AcademicAtram(
        atram: atram,
        subjects: [
          AcademicSubject(
            subject: subject,
            terms: [AcademicTermUnits(term: term, units: [unit])],
          ),
        ],
      ));
    } else {
      final subjects = atrams[atramIndex].subjects.toList();
      final subjectIndex = subjects.indexWhere((item) => item.subject == subject);
      if (subjectIndex < 0) {
        subjects.add(AcademicSubject(
          subject: subject,
          terms: [AcademicTermUnits(term: term, units: [unit])],
        ));
      } else {
        final terms = subjects[subjectIndex].terms.toList();
        final termIndex = terms.indexWhere((item) => item.term == term);
        if (termIndex < 0) {
          terms.add(AcademicTermUnits(term: term, units: [unit]));
        } else if (!terms[termIndex].units.contains(unit)) {
          terms[termIndex] = AcademicTermUnits(
            term: term,
            units: [...terms[termIndex].units, unit],
          );
        }
        subjects[subjectIndex] =
            AcademicSubject(subject: subject, terms: terms);
      }
      atrams[atramIndex] =
          AcademicAtram(atram: atram, subjects: subjects);
    }
    final updated = HierarchicalConfig(
      grade: current.grade,
      atrams: atrams,
      createdBy: current.createdBy,
      createdByName: current.createdByName,
      createdAt: current.createdAt,
      createdByAdmin: current.createdByAdmin,
      copiedFrom: current.copiedFrom,
      copiedFromName: current.copiedFromName,
    );
    if (configIndex >= 0) {
      hierarchicalConfigs[configIndex] = updated;
    } else {
      hierarchicalConfigs.add(updated);
    }
  }

  void addHierarchicalConfig({
    required String grade,
    required List<AcademicAtram> atrams,
    String createdBy = 'admin',
    String createdByName = 'المشرف',
    bool createdByAdmin = false,
    String? copiedFrom,
    String? copiedFromName,
  }) {
    final config = HierarchicalConfig(
      grade: grade,
      atrams: atrams,
      createdBy: createdBy,
      createdByName: createdByName,
      createdAt: DateTime.now().toIso8601String(),
      createdByAdmin: createdByAdmin,
      copiedFrom: copiedFrom,
      copiedFromName: copiedFromName,
    );
    hierarchicalConfigs.removeWhere(
      (item) => item.grade == grade && item.createdBy == createdBy,
    );
    hierarchicalConfigs.add(config);
    _persistCollections();
    notifyListeners();
  }

  bool copyAcademicConfigForTeacher({
    required String grade,
    required String teacherId,
    required String teacherName,
  }) {
    final source = hierarchicalConfigs.firstWhere(
      (item) => item.grade == grade && item.createdBy == 'admin',
      orElse: () => const HierarchicalConfig(grade: '', atrams: []),
    );
    if (source.grade.isEmpty) return false;
    addHierarchicalConfig(
      grade: source.grade,
      atrams: source.atrams,
      createdBy: teacherId,
      createdByName: teacherName,
      copiedFrom: source.createdBy,
      copiedFromName: source.createdByName,
    );
    return true;
  }

  void removeHierarchicalConfig(String grade, String createdBy) {
    hierarchicalConfigs.removeWhere(
      (item) => item.grade == grade && item.createdBy == createdBy,
    );
    _persistCollections();
    notifyListeners();
  }

  void removeAcademicUnit(AcademicUnit item) {
    academicUnits.remove(item);
    final configIndex = hierarchicalConfigs.indexWhere(
      (config) => config.grade == item.grade && config.createdBy == item.createdBy,
    );
    if (configIndex >= 0) {
      final config = hierarchicalConfigs[configIndex];
      final atrams = <AcademicAtram>[];
      for (final atram in config.atrams) {
        final subjects = <AcademicSubject>[];
        for (final subject in atram.subjects) {
          final terms = subject.terms
              .map((term) => AcademicTermUnits(
                    term: term.term,
                    units: term.term == item.term &&
                            atram.atram == item.atram &&
                            subject.subject == item.subject
                        ? term.units.where((unit) => unit != item.unit).toList()
                        : List<String>.from(term.units),
                  ))
              .where((term) => term.units.isNotEmpty)
              .toList();
          if (terms.isNotEmpty) {
            subjects.add(AcademicSubject(subject: subject.subject, terms: terms));
          }
        }
        if (subjects.isNotEmpty) {
          atrams.add(AcademicAtram(atram: atram.atram, subjects: subjects));
        }
      }
      if (atrams.isEmpty) {
        hierarchicalConfigs.removeAt(configIndex);
      } else {
        hierarchicalConfigs[configIndex] = HierarchicalConfig(
          grade: config.grade,
          atrams: atrams,
          createdBy: config.createdBy,
          createdByName: config.createdByName,
          createdAt: config.createdAt,
          createdByAdmin: config.createdByAdmin,
          copiedFrom: config.copiedFrom,
          copiedFromName: config.copiedFromName,
        );
      }
    }
    _persistCollections();
    notifyListeners();
  }

  void issueCertificate({
    required String studentId,
    required String studentName,
    required String teacherId,
    required String teacherName,
    required CertificateType type,
    required String subject,
    required String grade,
    required String atram,
    required String term,
    String note = '',
  }) {
    if (role != UserRole.admin && role != UserRole.teacher) return;
    if (role == UserRole.teacher) {
      final currentTeacher = teacher;
      final canIssueForStudent = studentsForCurrentTeacher
          .any((item) => item.id == studentId);
      final teacherMatches = currentTeacher != null &&
          (teacherId == currentTeacher.id ||
              teacherId == currentTeacher.teacherId);
      if (!canIssueForStudent || !teacherMatches) return;
    }
    final duplicate = certificates.any((item) =>
        item.studentId == studentId &&
        item.type == type &&
        item.subject == subject &&
        item.grade == grade &&
        item.term == term);
    if (duplicate) return;
    certificates.add(CertificateRecord(
      id: 'certificate-${DateTime.now().millisecondsSinceEpoch}',
      studentId: studentId,
      studentName: studentName,
      teacherId: teacherId,
      teacherName: teacherName,
      type: type,
      subject: subject,
      grade: grade,
      atram: atram,
      term: term,
      date: DateTime.now().toIso8601String(),
       average: _performanceAverageForStudent(
         studentId: studentId,
         subject: subject,
       ),
      note: note,
    ));
    _persistCollections();
    notifyListeners();
  }

  int _performanceAverageForStudent({
    required String studentId,
    required String subject,
  }) {
    final normalizedSubject = subject.trim().toLowerCase();
    final studentResults = quizResults.where((result) {
      return result.studentId == studentId &&
          (normalizedSubject.isEmpty ||
              result.subject.trim().toLowerCase() == normalizedSubject);
    }).toList();
    if (studentResults.isNotEmpty) {
      final average = studentResults
              .map((result) => result.percentage)
              .reduce((a, b) => a + b) /
          studentResults.length;
    return average.round().clamp(0, 100).toInt();
    }

    final targetLessons = lessons.where((lesson) {
      return normalizedSubject.isEmpty ||
          lesson.subject.trim().toLowerCase() == normalizedSubject;
    }).toList();
    if (targetLessons.isEmpty) return 0;
    final targetLessonIds = targetLessons.map((lesson) => lesson.id).toSet();
    final completedCount = interactions.where((interaction) {
      if (interaction.studentId != studentId ||
          interaction.action != 'lesson_complete') {
        return false;
      }
      return interaction.lessonId != null &&
          targetLessonIds.contains(interaction.lessonId);
    }).length;
    return ((completedCount / targetLessons.length) * 100)
        .round()
        .clamp(0, 100)
        .toInt();
  }

  void removeCertificate(String id) {
    if (role != UserRole.admin) {
      final certificate = certificates.firstWhere(
        (item) => item.id == id,
        orElse: () => const CertificateRecord(
          id: '',
          studentId: '',
          studentName: '',
          teacherId: '',
          teacherName: '',
          type: CertificateType.participation,
          subject: '',
          grade: '',
          atram: '',
          term: '',
          date: '',
          average: 0,
        ),
      );
      final teacherOwns = role == UserRole.teacher &&
          (certificate.teacherId == teacher?.id ||
              certificate.teacherId == teacher?.teacherId);
      if (!teacherOwns) return;
    }
    certificates.removeWhere((item) => item.id == id);
    _deleteRemoteRecord('certificates', id);
    _persistCollections();
    notifyListeners();
  }

  void addQuiz({
    required String title,
    required String subject,
    required int questionCount,
    String grade = 'الصف الرابع',
    QuizType type = QuizType.unit,
    String atram = '',
    String term = '',
    String unit = '',
    String? lessonId,
    List<QuizQuestion> questions = const [],
    String? createdBy,
  }) {
    if (role != UserRole.admin && role != UserRole.teacher) return;
    if (role == UserRole.teacher && !_teacherSubjectMatches(subject)) return;
    final effectiveCreatedBy = createdBy ??
        (role == UserRole.teacher ? teacher?.id ?? 'admin' : 'admin');
    quizzes.add(QuizDefinition(
      id: 'quiz-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      subject: subject,
      grade: grade,
      questionCount: questionCount,
      active: true,
      type: type,
      atram: atram,
      term: term,
      unit: unit,
      lessonId: lessonId,
      createdBy: effectiveCreatedBy,
      questions: questions,
    ));
    _persistCollections();
    notifyListeners();
  }

  void removeQuiz(String id) {
    if (role != UserRole.admin && role != UserRole.teacher) return;
    if (role == UserRole.teacher) {
      final quiz = quizzes.firstWhere(
        (item) => item.id == id,
        orElse: () => const QuizDefinition(
          id: '',
          title: '',
          subject: '',
          grade: '',
          questionCount: 0,
          active: false,
        ),
      );
      final ownsQuiz = teacher != null &&
          (quiz.createdBy == teacher!.id ||
              quiz.createdBy == teacher!.username);
      if (!ownsQuiz) return;
    }
    quizzes.removeWhere((quiz) => quiz.id == id);
    _deleteRemoteRecord('created_quizzes', id);
    _persistCollections();
    notifyListeners();
  }

  Future<void> _deleteRemoteRecord(String table, String id) async {
    final repository = remoteRepository;
    if (id.trim().isEmpty) return;
    if (repository == null) {
      await _queueRemoteDelete(table, id);
      return;
    }
    try {
      await repository.deleteRecord(table, id);
    } catch (_) {
      await _queueRemoteDelete(table, id);
    }
  }

  Future<void> _queueRemoteDelete(String table, String id) async {
    final prefs = await SharedPreferences.getInstance();
    final queued = prefs.getStringList('manara_pending_deletes') ?? <String>[];
    final entry = '$table::$id';
    if (!queued.contains(entry)) {
      queued.add(entry);
      await prefs.setStringList('manara_pending_deletes', queued);
    }
  }

  Future<void> _retryPendingSync() async {
    if (remoteRepository == null) return;
    await _syncRemoteCollections();
    await _syncRemoteProgress();
    final prefs = await SharedPreferences.getInstance();
    final queued = prefs.getStringList('manara_pending_deletes') ?? <String>[];
    if (queued.isEmpty) return;
    final remaining = <String>[];
    for (final entry in queued) {
      final separator = entry.indexOf('::');
      if (separator <= 0 || separator >= entry.length - 2) continue;
      final table = entry.substring(0, separator);
      final id = entry.substring(separator + 2);
      try {
        await remoteRepository!.deleteRecord(table, id);
      } catch (_) {
        remaining.add(entry);
      }
    }
    await prefs.setStringList('manara_pending_deletes', remaining);
  }

  Future<void> _syncRemoteProgress() async {
    if (remoteRepository == null ||
        role != UserRole.student ||
        userId == null) {
      return;
    }
    try {
      await remoteRepository!.saveProgress(
        userId!,
        xp,
        gems,
        completedLessonIds: completedLessonIds.toList(),
        unlockedAvatars: unlockedAvatars.toList(),
      );
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('manara_sync_pending', true);
    }
  }

  void saveQuizResult({
    required String quizId,
    required String quizTitle,
    required int score,
    required int total,
    String quizType = '',
    String subject = '',
    String unit = '',
    String grade = '',
    List<QuizAnswerDetail> details = const [],
  }) {
    final percentage = total == 0 ? 0.0 : score / total * 100;
    final passed = percentage >= passingScore;
    final reward = ManaraGamificationEngine.quizReward(
      score: score,
      total: total,
      passingScore: passingScore,
    );
    quizResults.add(QuizResult(
      id: 'result-${DateTime.now().millisecondsSinceEpoch}',
      quizId: quizId,
      quizTitle: quizTitle,
      studentId: userId ?? student?.id ?? '',
      score: score,
      total: total,
      date: DateTime.now().toIso8601String(),
      studentName: displayName,
      quizType: quizType,
      subject: subject,
      unit: unit,
      grade: grade,
      percentage: percentage,
       level: percentage >= 90
           ? 'ممتاز'
           : passed
               ? 'جيد'
               : 'بحاجة للمراجعة',
       feedback: passed
           ? 'أحسنت، استمر في التعلم!'
           : 'راجع الدرس وحاول مرة أخرى.',
      details: details,
    ));
    totalQuizzes++;
    awardReward(reward);
    if (totalQuizzes == 1) unlockAchievement('أول اختبار');
    if (totalQuizzes >= 10) unlockAchievement('مقاتل الاختبارات');
    if (percentage == 100) unlockAchievement('نتيجة مثالية');
    _persistCollections();
    notifyListeners();
  }

  void setPermission(String key, bool value) {
    permissions[key] = value;
    _persistCollections();
    notifyListeners();
  }

  bool hasRolePermission(UserRole targetRole, String key) {
    return rolePermissions[targetRole == UserRole.guardian ? 'parent' : targetRole.name]?[key] ?? false;
  }

  void setRolePermission(String roleName, String key, bool value) {
    rolePermissions.putIfAbsent(roleName, () => {})[key] = value;
    _persistCollections();
    notifyListeners();
  }

  Future<void> _persistProgress() async {
    final epoch = _sessionEpoch;
    final sessionKey = _progressStorageKey;
    final snapshot = {
      'xp': xp,
      'gems': gems,
      'streak': streak,
      'totalQuizzes': totalQuizzes,
      'totalLessons': totalLessons,
      'totalGames': totalGames,
      'unlockedAchievements': unlockedAchievementTitles.toList(),
      'completedQuests': completedQuests.toList(),
      'completedLessonIds': completedLessonIds.toList(),
      'unlockedAvatars': unlockedAvatars.toList(),
    };
    final snapshotUserId = userId;
    final snapshotRole = role;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(sessionKey, jsonEncode(snapshot));
    if (epoch != _sessionEpoch || sessionKey != _progressStorageKey) return;
    if (remoteRepository != null &&
        snapshotUserId != null &&
        snapshotRole == UserRole.student) {
      try {
        await remoteRepository!.saveProgress(
          snapshotUserId,
          snapshot['xp'] as int,
          snapshot['gems'] as int,
          completedLessonIds:
              (snapshot['completedLessonIds'] as List).cast<String>(),
          unlockedAvatars:
              (snapshot['unlockedAvatars'] as List).cast<String>(),
        );
      } catch (_) {
        // Keep local progress authoritative until the next retry.
        if (epoch == _sessionEpoch && sessionKey == _progressStorageKey) {
          await prefs.setBool('manara_sync_pending', true);
        }
      }
    }
  }

  Future<void> _persistCollections([SharedPreferences? existing]) async {
    final prefs = existing ?? await SharedPreferences.getInstance();
    await prefs.setString('manara_students', jsonEncode(students.map((item) => {
          'id': item.id,
          'name': item.name,
          'username': item.username,
          'grade': item.primaryGrade,
          'parentId': item.parentId,
           'teacherId': item.teacherId,
          'createdBy': item.createdBy,
          'password': item.password,
          'parentPhoneNumber': item.parentPhoneNumber,
          'studentIdNumber': item.studentIdNumber,
          'nationalId': item.nationalId,
          'canChangeGrade': item.canChangeGrade,
           'createdAt': item.createdAt,
           'gradeEnrollments': item.gradeEnrollments.map((grade) => {
             'grade': grade.grade,
             'enrollments': grade.enrollments.map((enrollment) => {
               'subject': enrollment.subject,
               'atram': enrollment.atram,
               'term': enrollment.term,
               'unit': enrollment.unit,
             }).toList(),
           }).toList(),
        }).toList()));
    await prefs.setString('manara_teachers', jsonEncode(teachers.map((item) => {
          'id': item.id,
          'name': item.name,
          'username': item.username,
          'teacherId': item.teacherId,
          'subject': item.subject,
           'password': item.password,
           'createdBy': item.createdBy,
           'mustChangePassword': item.mustChangePassword,
           'lastActivity': item.lastActivity,
        }).toList()));
    await prefs.setString('manara_guardians', jsonEncode(guardians.map((item) => {
          'id': item.id,
          'name': item.name,
          'username': item.username,
          'phoneNumber': item.phoneNumber,
          'nationalId': item.nationalId,
          'password': item.password,
          'childIds': item.childIds,
           'createdBy': item.createdBy,
           'createdByName': item.createdByName,
           'mustChangePassword': item.mustChangePassword,
        }).toList()));
    await prefs.setString('manara_lessons', jsonEncode(lessons.map((item) => {
          'id': item.id,
          'title': item.title,
          'grade': item.grade,
          'subject': item.subject,
          'unit': item.unit,
          'content': item.content,
          'videoUrl': item.videoUrl,
           'atram': item.atram,
           'term': item.term,
           'explanationVideoUrl': item.explanationVideoUrl,
           'avatarInteractionUrl': item.avatarInteractionUrl,
           'liveMeetingUrl': item.liveMeetingUrl,
           'teacherId': item.teacherId,
           'createdBy': item.createdBy,
           'createdByName': item.createdByName,
        }).toList()));
    await prefs.setString('manara_videos', jsonEncode(videos.map((item) => {
          'id': item.id,
          'title': item.title,
          'subject': item.subject,
          'emoji': item.emoji,
          'duration': item.duration,
          'url': item.url,
           'description': item.description,
           'grade': item.grade,
           'atram': item.atram,
           'term': item.term,
           'unit': item.unit,
          'isNew': item.isNew,
          'teacherId': item.teacherId,
          'createdBy': item.createdBy,
          'createdByName': item.createdByName,
        }).toList()));
    await prefs.setStringList('video_notifications', videoNotifications);
    await prefs.setString('manara_academic_units', jsonEncode(academicUnits.map((item) => {
          'grade': item.grade,
          'atram': item.atram,
          'subject': item.subject,
          'term': item.term,
          'unit': item.unit,
          'createdBy': item.createdBy,
          'createdByName': item.createdByName,
        }).toList()));
    await prefs.setString('manara_messages', jsonEncode(messages.map((item) => {
          'id': item.id,
          'senderName': item.senderName,
          'message': item.message,
          'timestamp': item.timestamp.toIso8601String(),
           'conversationId': item.conversationId,
           'senderId': item.senderId,
           'recipientId': item.recipientId,
           'read': item.read,
        }).toList()));
    await prefs.setString('manara_quizzes', jsonEncode(quizzes.map((item) => {
          'id': item.id,
          'title': item.title,
          'subject': item.subject,
          'grade': item.grade,
          'questionCount': item.questionCount,
          'active': item.active,
           'type': item.type.name,
           'atram': item.atram,
           'term': item.term,
           'unit': item.unit,
           'lessonId': item.lessonId,
           'createdBy': item.createdBy,
           'questions': item.questions.map((question) => {
             'question': question.question,
             'options': question.options,
             'correctAnswer': question.correctAnswer,
             'points': question.points,
           }).toList(),
        }).toList()));
    await prefs.setString('manara_certificates', jsonEncode(certificates.map((item) => {
          'id': item.id,
          'studentId': item.studentId,
          'studentName': item.studentName,
          'teacherId': item.teacherId,
          'teacherName': item.teacherName,
          'type': item.type.name,
          'subject': item.subject,
          'grade': item.grade,
          'atram': item.atram,
          'term': item.term,
          'date': item.date,
          'average': item.average,
          'note': item.note,
        }).toList()));
    await prefs.setString('manara_permissions', jsonEncode(permissions));
    await prefs.setString('manara_quiz_results', jsonEncode(quizResults.map((item) => {
          'id': item.id,
          'quizId': item.quizId,
          'quizTitle': item.quizTitle,
          'studentId': item.studentId,
          'score': item.score,
          'total': item.total,
          'date': item.date,
           'studentName': item.studentName,
           'quizType': item.quizType,
           'subject': item.subject,
           'unit': item.unit,
           'grade': item.grade,
           'percentage': item.percentage,
           'level': item.level,
           'feedback': item.feedback,
           'details': item.details.map((detail) => {
             'question': detail.question,
             'userAnswer': detail.userAnswer,
             'correctAnswer': detail.correctAnswer,
             'isCorrect': detail.isCorrect,
           }).toList(),
        }).toList()));
    await prefs.setString('manara_interactions', jsonEncode(interactions.map((item) => {
          'id': item.id,
          'studentId': item.studentId,
          'studentName': item.studentName,
          'action': item.action,
          'timestamp': item.timestamp,
          'lessonId': item.lessonId,
          'grade': item.grade,
          'subject': item.subject,
          'unit': item.unit,
        }).toList()));
    await prefs.setString('manara_role_permissions', jsonEncode(rolePermissions));
    await prefs.setString(
      'manara_hierarchical_configs',
      jsonEncode(hierarchicalConfigs.map((config) => {
        'grade': config.grade,
        'createdBy': config.createdBy,
        'createdByName': config.createdByName,
        'createdAt': config.createdAt,
        'createdByAdmin': config.createdByAdmin,
        'copiedFrom': config.copiedFrom,
        'copiedFromName': config.copiedFromName,
        'atrams': config.atrams.map((atram) => {
          'atram': atram.atram,
          'subjects': atram.subjects.map((subject) => {
            'subject': subject.subject,
            'terms': subject.terms.map((term) => {
              'term': term.term,
              'units': term.units,
            }).toList(),
          }).toList(),
        }).toList(),
      }).toList()),
    );
    await prefs.setBool('manara_sync_pending', true);
    _syncRemoteCollections();
  }

  void _restoreAcademicConfigs(String? raw) {
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      hierarchicalConfigs
        ..clear()
        ..addAll(decoded.whereType<Map>().map((data) => HierarchicalConfig(
              grade: data['grade']?.toString() ?? '',
              createdBy: data['createdBy']?.toString() ?? 'admin',
              createdByName: data['createdByName']?.toString() ?? 'المشرف',
              createdAt: data['createdAt']?.toString() ?? '',
              createdByAdmin: data['createdByAdmin'] == true,
              copiedFrom: data['copiedFrom']?.toString(),
              copiedFromName: data['copiedFromName']?.toString(),
              atrams: ((data['atrams'] as List?) ?? const [])
                  .whereType<Map>()
                  .map((atram) => AcademicAtram(
                        atram: atram['atram']?.toString() ?? '',
                        subjects: ((atram['subjects'] as List?) ?? const [])
                            .whereType<Map>()
                            .map((subject) => AcademicSubject(
                                  subject: subject['subject']?.toString() ?? '',
                                  terms: ((subject['terms'] as List?) ?? const [])
                                      .whereType<Map>()
                                      .map((term) => AcademicTermUnits(
                                            term: term['term']?.toString() ?? '',
                                            units: ((term['units'] as List?) ?? const [])
                                                .map((unit) => unit.toString())
                                                .toList(),
                                          ))
                                      .toList(),
                                ))
                            .toList(),
                      ))
                  .toList(),
            )));
    } catch (_) {
      // Ignore malformed legacy cache and keep the local defaults.
    }
  }

  Future<void> _syncRemoteCollections() async {
    final repository = remoteRepository;
    if (repository == null) return;
    try {
      await repository.syncCollections({
        'students': students.map((item) => {
          'id': item.id,
          'name': item.name,
          'username': item.username,
          'password': item.password,
          'parentPhoneNumber': item.parentPhoneNumber,
          'parentId': item.parentId,
          'teacherId': item.teacherId,
          'nationalId': item.nationalId,
          'primaryGrade': item.primaryGrade,
          'gradeEnrollments': item.enrollments.map((enrollment) => {
            'subject': enrollment.subject,
            'atram': enrollment.atram,
            'term': enrollment.term,
            'unit': enrollment.unit,
          }).toList(),
          'gradeEnrollmentGroups': item.gradeEnrollments.map((grade) => {
            'grade': grade.grade,
            'enrollments': grade.enrollments.map((enrollment) => {
              'subject': enrollment.subject,
              'atram': enrollment.atram,
              'term': enrollment.term,
              'unit': enrollment.unit,
            }).toList(),
          }).toList(),
          'studentIdNumber': item.studentIdNumber,
          'createdAt': item.createdAt,
          'lastActivity': item.lastActivity,
          'canChangeGrade': item.canChangeGrade,
          'createdBy': item.createdBy,
        }).toList(),
        'parents': guardians.map((item) => {
          'id': item.id,
          'name': item.name,
          'username': item.username,
          'password': item.password,
          'phoneNumber': item.phoneNumber,
          'nationalId': item.nationalId,
          'childIds': item.childIds,
          'mustChangePassword': item.mustChangePassword,
          'createdBy': item.createdBy,
          'createdByName': item.createdByName,
        }).toList(),
        'teachers': teachers.map((item) => {
          'id': item.id,
          'name': item.name,
          'username': item.username,
          'password': item.password,
          'teacherId': item.teacherId,
          'subject': item.subject,
          'createdBy': item.createdBy,
          'lastActivity': item.lastActivity,
          'mustChangePassword': item.mustChangePassword,
        }).toList(),
        'lesson_configs': lessons.map((item) => {
          'id': item.id,
          'grade': item.grade,
          'subject': item.subject,
          'atram': item.atram,
          'term': item.term,
          'unit': item.unit,
          'lessonContent': item.content,
           'videoUrl': item.videoUrl ?? item.explanationVideoUrl,
          'explanationVideoUrl': item.explanationVideoUrl,
          'avatarInteractionUrl': item.avatarInteractionUrl,
          'liveMeetingUrl': item.liveMeetingUrl,
          'teacherId': item.teacherId,
          'createdBy': item.createdBy,
          'createdByName': item.createdByName,
        }).toList(),
        'created_quizzes': quizzes.map((item) => {
          'id': item.id,
          'title': item.title,
          'grade': item.grade,
          'subject': item.subject,
          'atram': item.atram,
          'term': item.term,
          'unit': item.unit,
          'quizType': item.type.name,
          'questionCount': item.questionCount,
          'isActive': item.active,
          'questions': item.questions.map((question) => {
            'id': question.id,
            'question': question.question,
            'options': question.options,
            'correctAnswer': question.correctAnswer,
            'lessonId': question.lessonId,
            'grade': question.grade,
            'subject': question.subject,
            'atram': question.atram,
            'term': question.term,
            'unit': question.unit,
            'source': question.source,
            'variation': question.variation,
          }).toList(),
          'createdBy': item.createdBy,
        }).toList(),
        'quiz_results': quizResults.map((item) => {
          'id': item.id,
          'studentId': item.studentId,
          'studentName': item.studentName,
          'quizId': item.quizId,
          'quizType': item.quizType,
          'subject': item.subject,
          'unit': item.unit,
          'grade': item.grade,
          'score': item.score,
          'total': item.total,
          'percentage': item.percentage,
          'level': item.level,
          'feedback': item.feedback,
          'details': item.details.map((detail) => {
            'question': detail.question,
            'userAnswer': detail.userAnswer,
            'correctAnswer': detail.correctAnswer,
            'isCorrect': detail.isCorrect,
          }).toList(),
          'createdAt': item.date,
        }).toList(),
        'interactions': interactions.map((item) => {
          'id': item.id,
          'studentId': item.studentId,
          'studentName': item.studentName,
          'lessonId': item.lessonId,
          'grade': item.grade,
          'subject': item.subject,
          'unit': item.unit,
          'action': item.action,
          'timestamp': item.timestamp,
        }).toList(),
        'public_messages': messages
            .where((item) => item.conversationId == 'classroom')
            .map((item) => {
              'id': item.id,
              'senderId': item.senderId,
              'senderName': item.senderName,
              'message': item.message,
              'timestamp': item.timestamp.toIso8601String(),
              'conversationId': item.conversationId,
              'recipientId': item.recipientId,
              'read': item.read,
            }).toList(),
        'private_messages': messages
            .where((item) => item.conversationId != 'classroom')
            .map((item) => {
              'id': item.id,
              'senderId': item.senderId,
              'senderName': item.senderName,
              'message': item.message,
              'timestamp': item.timestamp.toIso8601String(),
              'conversationId': item.conversationId,
              'recipientId': item.recipientId,
              'read': item.read,
            }).toList(),
        'certificates': certificates.map((item) => {
          'id': item.id,
          'studentId': item.studentId,
          'studentName': item.studentName,
          'teacherId': item.teacherId,
          'teacherName': item.teacherName,
          'type': item.type.name,
          'subject': item.subject,
          'grade': item.grade,
          'atram': item.atram,
          'term': item.term,
          'date': item.date,
          'average': item.average,
          'note': item.note,
        }).toList(),
      });
      await repository.syncKeyValue(
        'academic_units',
        academicUnits.map((item) => {
          'grade': item.grade,
          'atram': item.atram,
          'subject': item.subject,
          'term': item.term,
          'unit': item.unit,
          'createdBy': item.createdBy,
          'createdByName': item.createdByName,
        }).toList(),
      );
      await repository.syncKeyValue(
        'hierarchical_configs',
        hierarchicalConfigs.map((config) => {
          'grade': config.grade,
          'createdBy': config.createdBy,
          'createdByName': config.createdByName,
          'createdAt': config.createdAt,
          'createdByAdmin': config.createdByAdmin,
          'copiedFrom': config.copiedFrom,
          'copiedFromName': config.copiedFromName,
          'atrams': config.atrams.map((atram) => {
            'atram': atram.atram,
            'subjects': atram.subjects.map((subject) => {
              'subject': subject.subject,
              'terms': subject.terms.map((term) => {
                'term': term.term,
                'units': term.units,
              }).toList(),
            }).toList(),
          }).toList(),
        }).toList(),
      );
      await repository.syncKeyValue(
        'videos',
        videos.map((item) => {
          'id': item.id,
          'title': item.title,
          'subject': item.subject,
          'emoji': item.emoji,
          'duration': item.duration,
          'url': item.url,
           'description': item.description,
           'grade': item.grade,
           'atram': item.atram,
           'term': item.term,
           'unit': item.unit,
          'isNew': item.isNew,
          'teacherId': item.teacherId,
          'createdBy': item.createdBy,
          'createdByName': item.createdByName,
        }).toList(),
      );
      await repository.syncKeyValue(
        'video_notifications',
        videoNotifications,
      );
      await repository.syncKeyValue('role_permissions', rolePermissions);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('manara_sync_pending', false);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('manara_sync_pending', true);
    }
  }

  void _restoreCollections(SharedPreferences prefs) {
    _readList(prefs, 'manara_students', (item) {
      students
        ..clear()
        ..addAll(item.map((data) => StudentProfile(
              id: data['id'].toString(),
              name: data['name'].toString(),
              username: data['username'].toString(),
              primaryGrade: data['grade'].toString(),
              parentId: data['parentId']?.toString(),
              teacherId: data['teacherId']?.toString(),
              createdBy: data['createdBy']?.toString(),
              password: data['password']?.toString() ?? '',
              parentPhoneNumber: data['parentPhoneNumber']?.toString() ?? '',
              studentIdNumber: data['studentIdNumber']?.toString() ?? '',
              nationalId: data['nationalId']?.toString() ?? '',
              canChangeGrade: data['canChangeGrade'] == true,
              enrollments: const [],
            )));
    });
    _readList(prefs, 'manara_teachers', (item) {
      teachers
        ..clear()
        ..addAll(item.map((data) => TeacherProfile(
              id: data['id'].toString(),
              name: data['name'].toString(),
              username: data['username'].toString(),
              teacherId: data['teacherId'].toString(),
              subject: data['subject']?.toString(),
              password: data['password']?.toString() ?? '',
              createdBy: data['createdBy']?.toString() ?? 'admin',
              mustChangePassword: data['mustChangePassword'] == true,
              lastActivity: data['lastActivity']?.toString() ?? '',
            )));
    });
    _readList(prefs, 'manara_guardians', (item) {
      guardians
        ..clear()
        ..addAll(item.map((data) => GuardianProfile(
              id: data['id'].toString(),
              name: data['name'].toString(),
              username: data['username'].toString(),
              phoneNumber: data['phoneNumber']?.toString() ?? '',
              nationalId: data['nationalId']?.toString() ?? '',
              password: data['password']?.toString() ?? '',
              createdBy: data['createdBy']?.toString() ?? 'admin',
              createdByName: data['createdByName']?.toString() ?? 'المشرف',
              mustChangePassword: data['mustChangePassword'] == true,
              childIds: (data['childIds'] as List? ?? const []).map((value) => value.toString()).toList(),
            )));
    });
    _readList(prefs, 'manara_lessons', (item) {
      lessons
        ..clear()
        ..addAll(item.map((data) => Lesson(
              id: data['id'].toString(),
              title: data['title'].toString(),
              grade: data['grade'].toString(),
              subject: data['subject'].toString(),
              unit: data['unit'].toString(),
              content: data['content'].toString(),
              videoUrl: ((data['videoUrl'] ?? data['explanationVideoUrl'])
                          ?.toString()
                          .trim()
                          .isEmpty ??
                      true)
                  ? null
                  : (data['videoUrl'] ?? data['explanationVideoUrl'])
                      .toString()
                      .trim(),
              atram: data['atram']?.toString() ?? '',
              term: data['term']?.toString() ?? '',
              explanationVideoUrl: data['explanationVideoUrl']?.toString() ?? '',
              avatarInteractionUrl: data['avatarInteractionUrl']?.toString() ?? '',
              liveMeetingUrl: data['liveMeetingUrl']?.toString() ?? '',
              teacherId: data['teacherId']?.toString(),
              createdBy: data['createdBy']?.toString() ?? 'admin',
              createdByName: data['createdByName']?.toString() ?? 'المشرف',
            )));
    });
    _readList(prefs, 'manara_videos', (item) {
      videos
        ..clear()
        ..addAll(item.map((data) => VideoLesson(
              id: data['id']?.toString() ?? 'video-${data['title']}',
              title: data['title'].toString(),
              subject: data['subject'].toString(),
              emoji: data['emoji']?.toString() ?? '🎬',
              duration: data['duration'].toString(),
              url: data['url']?.toString(),
              description: data['description']?.toString() ?? '',
              grade: data['grade']?.toString() ?? '',
              atram: data['atram']?.toString() ?? '',
              term: data['term']?.toString() ?? '',
              unit: data['unit']?.toString() ?? '',
              isNew: data['isNew'] == true,
              teacherId: data['teacherId']?.toString(),
              createdBy: data['createdBy']?.toString() ?? 'admin',
              createdByName: data['createdByName']?.toString() ?? 'المشرف',
            )));
    });
    videoNotifications
      ..clear()
      ..addAll(prefs.getStringList('video_notifications') ?? const []);
    _readList(prefs, 'manara_academic_units', (item) {
      academicUnits
        ..clear()
        ..addAll(item.map((data) => AcademicUnit(
              grade: data['grade'].toString(),
              atram: data['atram']?.toString() ?? '',
              subject: data['subject'].toString(),
              term: data['term'].toString(),
              unit: data['unit'].toString(),
              createdBy: data['createdBy']?.toString() ?? 'admin',
              createdByName: data['createdByName']?.toString() ?? 'المشرف',
            )));
    });
    _readList(prefs, 'manara_messages', (item) {
      messages
        ..clear()
        ..addAll(item.map((data) => ChatMessage(
              id: data['id'].toString(),
              senderName: data['senderName'].toString(),
              message: data['message'].toString(),
              timestamp: DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now(),
              conversationId: data['conversationId']?.toString() ?? 'classroom',
              senderId: data['senderId']?.toString() ?? '',
              recipientId: data['recipientId']?.toString() ?? '',
              read: data['read'] == true,
            )));
    });
    _readList(prefs, 'manara_quizzes', (item) {
      quizzes
        ..clear()
        ..addAll(item.map((data) => QuizDefinition(
              id: data['id'].toString(),
              title: data['title'].toString(),
              subject: data['subject'].toString(),
              grade: data['grade'].toString(),
              questionCount: int.tryParse(data['questionCount'].toString()) ?? 0,
              active: data['active'] == true,
              type: QuizType.values.firstWhere(
                (value) => value.name == data['type']?.toString(),
                orElse: () => QuizType.unit,
              ),
              atram: data['atram']?.toString() ?? '',
              term: data['term']?.toString() ?? '',
              unit: data['unit']?.toString() ?? '',
              lessonId: data['lessonId']?.toString(),
              createdBy: data['createdBy']?.toString() ?? 'admin',
              questions: ((data['questions'] as List?) ?? const []).map((question) => QuizQuestion(
                question: question['question'].toString(),
                options: (question['options'] as List? ?? const []).map((item) => item.toString()).toList(),
                correctAnswer: question['correctAnswer'].toString(),
                points: int.tryParse(question['points'].toString()) ?? 1,
              )).toList(),
            )));
    });
    final savedPermissions = prefs.getString('manara_permissions');
    if (savedPermissions != null) {
      final decoded = jsonDecode(savedPermissions);
      if (decoded is Map) {
        permissions.addAll(decoded.map((key, value) => MapEntry(key.toString(), value == true)));
      }
    }
    _readList(prefs, 'manara_quiz_results', (item) {
      quizResults
        ..clear()
        ..addAll(item.map((data) => QuizResult(
              id: data['id'].toString(),
              quizId: data['quizId'].toString(),
              quizTitle: data['quizTitle'].toString(),
              studentId: data['studentId']?.toString() ?? '',
              score: int.tryParse(data['score'].toString()) ?? 0,
              total: int.tryParse(data['total'].toString()) ?? 0,
              date: data['date'].toString(),
               studentName: data['studentName']?.toString() ?? '',
               quizType: data['quizType']?.toString() ?? '',
               subject: data['subject']?.toString() ?? '',
               unit: data['unit']?.toString() ?? '',
               grade: data['grade']?.toString() ?? '',
               percentage: double.tryParse(data['percentage'].toString()) ?? 0,
               level: data['level']?.toString() ?? '',
               feedback: data['feedback']?.toString() ?? '',
               details: ((data['details'] as List?) ?? const []).map((detail) => QuizAnswerDetail(
                 question: detail['question']?.toString() ?? '',
                 userAnswer: detail['userAnswer']?.toString() ?? '',
                 correctAnswer: detail['correctAnswer']?.toString() ?? '',
                 isCorrect: detail['isCorrect'] == true,
               )).toList(),
            )));
    });
    _readList(prefs, 'manara_interactions', (item) {
      interactions
        ..clear()
        ..addAll(item.map((data) => InteractionRecord(
              id: data['id']?.toString() ?? '',
              studentId: data['studentId']?.toString() ?? '',
              studentName: data['studentName']?.toString() ?? '',
              action: data['action']?.toString() ?? 'other',
              timestamp: data['timestamp']?.toString() ?? '',
              lessonId: data['lessonId']?.toString(),
              grade: data['grade']?.toString(),
              subject: data['subject']?.toString(),
              unit: data['unit']?.toString(),
            )));
    });
    final savedRolePermissions = prefs.getString('manara_role_permissions');
    if (savedRolePermissions != null) {
      try {
        final decoded = jsonDecode(savedRolePermissions);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.value is Map) {
              rolePermissions[entry.key.toString()] = (entry.value as Map).map(
                (key, value) => MapEntry(key.toString(), value == true),
              );
            }
          }
        }
      } catch (_) {}
    }
    _readList(prefs, 'manara_certificates', (item) {
      certificates
        ..clear()
        ..addAll(item.map((data) => CertificateRecord(
              id: data['id'].toString(),
              studentId: data['studentId'].toString(),
              studentName: data['studentName'].toString(),
              teacherId: data['teacherId'].toString(),
              teacherName: data['teacherName'].toString(),
              type: CertificateType.values.firstWhere(
                (value) => value.name == data['type'].toString(),
                orElse: () => CertificateType.participation,
              ),
              subject: data['subject'].toString(),
              grade: data['grade'].toString(),
              atram: data['atram'].toString(),
              term: data['term'].toString(),
              date: data['date'].toString(),
              average: int.tryParse(data['average'].toString()) ?? 0,
              note: data['note']?.toString() ?? '',
            )));
    });
  }

  void _readList(SharedPreferences prefs, String key, void Function(List<Map<String, dynamic>>) apply) {
    final raw = prefs.getString(key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        apply(decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList());
      }
    } catch (_) {
      // البيانات المحلية القديمة/التالفة لا تمنع تشغيل التطبيق.
    }
  }
}