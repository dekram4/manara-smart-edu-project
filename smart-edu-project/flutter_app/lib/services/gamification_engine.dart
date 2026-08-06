import '../models/gamification_models.dart';
import '../models/app_models.dart';

/// Flutter port of utils/gamification.ts.
class ManaraGamificationEngine {
  static const quizCorrect = RewardAmount(10, 1);
  static const quizComplete = RewardAmount(50, 2);
  static const perfectQuiz = RewardAmount(100, 10);
  static const lessonComplete = RewardAmount(50, 2);
  static const gameWin = RewardAmount(30, 3);
  static const gamePerfect = RewardAmount(60, 5);
  static const streakBonus = RewardAmount(20, 5);
  static const dailyLogin = RewardAmount(5, 1);
  static const chatMessage = RewardAmount(2, 0);
  static const problemSolved = RewardAmount(15, 1);

  static const achievements = <Achievement>[
    Achievement(title: 'أول اختبار', icon: '🎯', description: 'أكمل أول اختبار'),
    Achievement(title: 'مقاتل الاختبارات', icon: '⚔️', description: 'أكمل 10 اختبارات'),
    Achievement(title: 'نتيجة مثالية', icon: '⭐', description: 'حصل على 100% في اختبار'),
    Achievement(title: 'أول درس', icon: '📚', description: 'أكمل أول درس'),
    Achievement(title: 'سيد الدروس', icon: '🏆', description: 'أكمل 10 دروس'),
    Achievement(title: 'حلال الرياضيات', icon: '🔢', description: 'حل أول مسألة رياضية'),
    Achievement(title: 'صديق الأفاتار', icon: '🤖', description: 'تفاعل مع الشخصية التعليمية'),
    Achievement(title: 'سيد الألعاب', icon: '🎮', description: 'العب 5 ألعاب'),
    Achievement(title: 'سيد الذاكرة', icon: '🧠', description: 'انتصر في لعبة الذاكرة'),
    Achievement(title: 'سريع كالبرق', icon: '⚡', description: 'فوز في الاختبار السريع'),
    Achievement(title: 'عقل صافي', icon: '✅', description: 'أجب عن جولة صح أو خطأ كاملة بشكل صحيح'),
    Achievement(title: '3 أيام متواصل', icon: '🔥', description: 'تعلم 3 أيام متتالية'),
    Achievement(title: 'أسبوع متواصل', icon: '🔥', description: 'تعلم 7 أيام متتالية'),
    Achievement(title: 'المستوى 5', icon: '💪', description: 'اوصل إلى المستوى 5'),
    Achievement(title: 'جامع الجواهر', icon: '💎', description: 'اجمع 50 جوهرة'),
  ];

  static int levelFor(int xp) => (xp ~/ 500) + 1;
  static double levelProgressFor(int xp) {
    final level = levelFor(xp);
    final base = (level - 1) * 500;
    return ((xp - base) / 500).clamp(0, 1).toDouble();
  }

  static RewardAmount quizReward({
    required int score,
    required int total,
    double passingScore = 60,
  }) {
    if (total <= 0) return const RewardAmount(0, 0);
    final percentage = score / total * 100;
    if (percentage == 100) return perfectQuiz;
    if (percentage >= passingScore) return quizComplete;
    return RewardAmount(quizCorrect.xp * score, quizCorrect.gems * score);
  }
}