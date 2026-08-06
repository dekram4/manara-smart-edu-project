import 'app_models.dart';

class RewardAmount {
  const RewardAmount(this.xp, this.gems);
  final int xp;
  final int gems;
}

class DetailedQuizAnswer {
  const DetailedQuizAnswer({
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

class LegacyQuizResult {
  const LegacyQuizResult({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.quizId,
    required this.quizType,
    required this.subject,
    required this.unit,
    required this.grade,
    required this.score,
    required this.total,
    required this.percentage,
    required this.level,
    required this.feedback,
    required this.details,
    required this.createdAt,
  });
  final String id;
  final String studentId;
  final String studentName;
  final String quizId;
  final String quizType;
  final String subject;
  final String unit;
  final String grade;
  final int score;
  final int total;
  final double percentage;
  final String level;
  final String feedback;
  final List<DetailedQuizAnswer> details;
  final String createdAt;
}

class InteractionRecord {
  const InteractionRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.action,
    required this.timestamp,
    this.lessonId,
    this.grade,
    this.subject,
    this.unit,
  });
  final String id;
  final String studentId;
  final String studentName;
  final String action;
  final String timestamp;
  final String? lessonId;
  final String? grade;
  final String? subject;
  final String? unit;
}