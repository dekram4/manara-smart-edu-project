enum UserRole { admin, teacher, student, guardian }

extension UserRoleText on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'المشرف';
      case UserRole.teacher:
        return 'المعلم';
      case UserRole.student:
        return 'الطالب';
      case UserRole.guardian:
        return 'ولي الأمر';
    }
  }

  String get icon {
    switch (this) {
      case UserRole.admin:
        return '🛡️';
      case UserRole.teacher:
        return '👩‍🏫';
      case UserRole.student:
        return '🎒';
      case UserRole.guardian:
        return '👨‍👩‍👧';
    }
  }
}

class VideoLesson {
  const VideoLesson({
    this.id = '',
    required this.title,
    required this.subject,
    required this.emoji,
    required this.duration,
    this.url,
    this.description = '',
    this.grade = '',
    this.atram = '',
    this.term = '',
    this.unit = '',
    this.isNew = false,
    this.teacherId,
    this.createdBy = 'admin',
    this.createdByName = 'المشرف',
  });

  final String id;
  final String title;
  final String subject;
  final String emoji;
  final String duration;
  final String? url;
  final String description;
  final String grade;
  final String atram;
  final String term;
  final String unit;
  final bool isNew;
  final String? teacherId;
  final String createdBy;
  final String createdByName;
}

class Enrollment {
  const Enrollment({
    required this.subject,
    required this.atram,
    required this.term,
    required this.unit,
  });

  final String subject;
  final String atram;
  final String term;
  final String unit;
}

class GradeEnrollment {
  const GradeEnrollment({
    required this.grade,
    required this.enrollments,
  });

  final String grade;
  final List<Enrollment> enrollments;
}

class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.primaryGrade,
    required this.enrollments,
    this.parentId,
    this.teacherId,
    this.createdBy,
    this.password = '',
    this.parentPhoneNumber = '',
    this.studentIdNumber = '',
    this.nationalId = '',
    this.canChangeGrade = false,
    this.lastActivity = '',
    this.createdAt = '',
    this.gradeEnrollments = const [],
  });

  final String id;
  final String name;
  final String username;
  final String primaryGrade;
  final List<Enrollment> enrollments;
  final String? parentId;
  final String? teacherId;
  final String? createdBy;
  final String password;
  final String parentPhoneNumber;
  final String studentIdNumber;
  final String nationalId;
  final bool canChangeGrade;
  final String lastActivity;
  final String createdAt;
  final List<GradeEnrollment> gradeEnrollments;
}

class TeacherProfile {
  const TeacherProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.teacherId,
    this.subject,
    this.password = '',
    this.createdBy = 'admin',
    this.mustChangePassword = false,
    this.lastActivity = '',
  });

  final String id;
  final String name;
  final String username;
  final String teacherId;
  final String? subject;
  final String password;
  final String createdBy;
  final bool mustChangePassword;
  final String lastActivity;
}

class GuardianProfile {
  const GuardianProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.childIds,
    this.phoneNumber = '',
    this.nationalId = '',
    this.password = '',
    this.createdBy = 'admin',
    this.createdByName = 'المشرف',
    this.mustChangePassword = false,
  });

  final String id;
  final String name;
  final String username;
  final List<String> childIds;
  final String phoneNumber;
  final String nationalId;
  final String password;
  final String createdBy;
  final String createdByName;
  final bool mustChangePassword;
}

class ProgressReport {
  const ProgressReport({
    required this.subject,
    required this.score,
    required this.completedLessons,
    required this.totalLessons,
    required this.color,
  });

  final String subject;
  final int score;
  final int completedLessons;
  final int totalLessons;
  final int color;
}

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.grade,
    required this.subject,
    required this.unit,
    required this.content,
    this.videoUrl,
    this.atram = '',
    this.term = '',
    this.explanationVideoUrl = '',
    this.avatarInteractionUrl = '',
    this.liveMeetingUrl = '',
    this.teacherId,
    this.createdBy = 'admin',
    this.createdByName = 'المشرف',
  });

  final String id;
  final String title;
  final String grade;
  final String subject;
  final String unit;
  final String content;
  final String? videoUrl;
  final String atram;
  final String term;
  final String explanationVideoUrl;
  final String avatarInteractionUrl;
  final String liveMeetingUrl;
  final String? teacherId;
  final String createdBy;
  final String createdByName;
}

enum CertificateType { excellence, appreciation, participation }

class CertificateRecord {
  const CertificateRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.teacherId,
    required this.teacherName,
    required this.type,
    required this.subject,
    required this.grade,
    required this.atram,
    required this.term,
    required this.date,
    required this.average,
    this.note = '',
  });

  final String id;
  final String studentId;
  final String studentName;
  final String teacherId;
  final String teacherName;
  final CertificateType type;
  final String subject;
  final String grade;
  final String atram;
  final String term;
  final String date;
  final int average;
  final String note;
}

class QuizQuestion {
  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.points = 1,
    this.id = '',
    this.lessonId = '',
    this.grade = '',
    this.subject = '',
    this.atram = '',
    this.term = '',
    this.unit = '',
    this.source = '',
    this.variation = 0,
  });

  final String question;
  final List<String> options;
  final String correctAnswer;
  final int points;
  final String id;
  final String lessonId;
  final String grade;
  final String subject;
  final String atram;
  final String term;
  final String unit;
  final String source;
  final int variation;
}

enum QuizType { unit, term, finalExam }

class QuizDefinition {
  const QuizDefinition({
    required this.id,
    required this.title,
    required this.subject,
    required this.grade,
    required this.questionCount,
    required this.active,
    this.type = QuizType.unit,
    this.atram = '',
    this.term = '',
    this.unit = '',
    this.lessonId,
    this.createdBy = 'admin',
    this.questions = const [],
  });

  final String id;
  final String title;
  final String subject;
  final String grade;
  final int questionCount;
  final bool active;
  final QuizType type;
  final String atram;
  final String term;
  final String unit;
  final String? lessonId;
  final String createdBy;
  final List<QuizQuestion> questions;
}

class QuizResult {
  const QuizResult({
    required this.id,
    required this.quizId,
    required this.quizTitle,
    required this.studentId,
    required this.score,
    required this.total,
    required this.date,
    this.studentName = '',
    this.quizType = '',
    this.subject = '',
    this.unit = '',
    this.grade = '',
    this.percentage = 0,
    this.level = '',
    this.feedback = '',
    this.details = const [],
  });

  final String id;
  final String quizId;
  final String quizTitle;
  final String studentId;
  final int score;
  final int total;
  final String date;
  final String studentName;
  final String quizType;
  final String subject;
  final String unit;
  final String grade;
  final double percentage;
  final String level;
  final String feedback;
  final List<QuizAnswerDetail> details;
}

class QuizAnswerDetail {
  const QuizAnswerDetail({
    required this.question,
    required this.userAnswer,
    required this.correctAnswer,
    required this.isCorrect,
  });
  final String question;
  final String userAnswer;
  final String correctAnswer;
  final bool isCorrect;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderName,
    required this.message,
    required this.timestamp,
    this.conversationId = 'classroom',
    this.senderId = '',
    this.recipientId = '',
    this.read = false,
  });

  final String id;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final String conversationId;
  final String senderId;
  final String recipientId;
  final bool read;
}

class Quest {
  const Quest({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.reward,
    this.completed = false,
  });

  final String title;
  final String subtitle;
  final String icon;
  final int reward;
  final bool completed;
}

class Achievement {
  const Achievement({
    required this.title,
    required this.icon,
    required this.description,
    this.unlocked = false,
  });

  final String title;
  final String icon;
  final String description;
  final bool unlocked;
}