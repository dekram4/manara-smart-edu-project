class StudentAchievement {
  const StudentAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final String icon;

  factory StudentAchievement.fromMap(Map<String, dynamic> map) => StudentAchievement(
        id: _text(map['id']),
        title: _text(map['title']),
        description: _text(map['description'] ?? map['desc']),
        icon: _text(map['icon']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'icon': icon,
      };
}

class StudentGamification {
  const StudentGamification({
    this.xp = 0,
    this.gems = 0,
    this.level = 0,
    this.streak = 0,
    this.totalQuizzes = 0,
    this.totalLessons = 0,
    this.totalGames = 0,
    this.averageScore = 0,
    this.lastQuizAt,
    this.lastQuizPercentage,
    this.achievements = const [],
    this.completedActivities = const [],
    this.updatedAt,
  });

  final int xp;
  final int gems;
  final int level;
  final int streak;
  final int totalQuizzes;
  final int totalLessons;
  final int totalGames;
  final int averageScore;
  final String? lastQuizAt;
  final int? lastQuizPercentage;
  final List<StudentAchievement> achievements;
  /// IDs are namespaced by activity type. Quiz rewards use the web-compatible
  /// quiz_reward:<type>:<quizId> key; older quiz:<quizId> entries are retained.
  final List<String> completedActivities;
  final String? updatedAt;

  int get levelProgress => xp % 100;
  int get xpToNextLevel => 100 - levelProgress;
  int get achievementsCount => achievements.length;

  factory StudentGamification.fromMap(Object? value) {
    final map = value is Map
        ? value.map((key, item) => MapEntry(key.toString(), item))
        : <String, dynamic>{};
    final rawAchievements = map['achievements'];
    final rawActivities = map['completedActivities'];
    return StudentGamification(
      xp: _number(map['xp']),
      gems: _number(map['gems']),
      // The web dashboard derives the level from XP. Retain that invariant
      // even when an older saved snapshot has a stale level field.
      level: _number(map['xp']) ~/ 100,
      streak: _number(map['streak']),
      totalQuizzes: _number(map['totalQuizzes']),
      totalLessons: _number(map['totalLessons']),
      totalGames: _number(map['totalGames']),
      averageScore: _number(map['averageScore']),
      lastQuizAt: _nullableText(map['lastQuizAt']),
      lastQuizPercentage: map['lastQuizPercentage'] == null ? null : _number(map['lastQuizPercentage']),
      achievements: rawAchievements is List
          ? rawAchievements.whereType<Map>().map((item) => StudentAchievement.fromMap(
                item.map((key, value) => MapEntry(key.toString(), value)),
              )).where((item) => item.id.isNotEmpty).toList()
          : const [],
      completedActivities: rawActivities is List
          ? rawActivities.map((item) => item.toString()).where((item) => item.isNotEmpty).toList()
          : const [],
      updatedAt: _nullableText(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'xp': xp,
        'gems': gems,
        'level': level,
        'levelProgress': levelProgress,
        'streak': streak,
        'totalQuizzes': totalQuizzes,
        'totalLessons': totalLessons,
        'totalGames': totalGames,
        'achievementsCount': achievementsCount,
        'achievements': achievements.map((item) => item.toMap()).toList(),
        'completedActivities': completedActivities,
        'averageScore': averageScore,
        if (lastQuizAt != null) 'lastQuizAt': lastQuizAt,
        if (lastQuizPercentage != null) 'lastQuizPercentage': lastQuizPercentage,
        'updatedAt': updatedAt ?? DateTime.now().toIso8601String(),
      };

  StudentGamification copyWith({
    int? xp,
    int? gems,
    int? streak,
    int? totalQuizzes,
    int? totalLessons,
    int? totalGames,
    int? averageScore,
    String? lastQuizAt,
    int? lastQuizPercentage,
    List<StudentAchievement>? achievements,
    List<String>? completedActivities,
  }) => StudentGamification(
        xp: xp ?? this.xp,
        gems: gems ?? this.gems,
        level: (xp ?? this.xp) ~/ 100,
        streak: streak ?? this.streak,
        totalQuizzes: totalQuizzes ?? this.totalQuizzes,
        totalLessons: totalLessons ?? this.totalLessons,
        totalGames: totalGames ?? this.totalGames,
        averageScore: averageScore ?? this.averageScore,
        lastQuizAt: lastQuizAt ?? this.lastQuizAt,
        lastQuizPercentage: lastQuizPercentage ?? this.lastQuizPercentage,
        achievements: achievements ?? this.achievements,
        completedActivities: completedActivities ?? this.completedActivities,
        updatedAt: DateTime.now().toIso8601String(),
      );
}

class RewardResult {
  const RewardResult({
    required this.xp,
    required this.gems,
    required this.alreadyRewarded,
    required this.levelUp,
    required this.newAchievements,
    required this.snapshot,
  });

  final int xp;
  final int gems;
  final bool alreadyRewarded;
  final bool levelUp;
  final List<StudentAchievement> newAchievements;
  final StudentGamification snapshot;
}

int _number(Object? value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
String _text(Object? value) => value?.toString().trim() ?? '';
String? _nullableText(Object? value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}