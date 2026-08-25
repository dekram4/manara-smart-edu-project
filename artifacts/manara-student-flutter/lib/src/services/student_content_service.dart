import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/academic_context.dart';
import '../models/student_assessment.dart';
import '../models/student_content.dart';
import '../models/student_profile.dart';
import '../models/student_gamification.dart';

class TeacherQuizAlreadySubmittedException implements Exception {
  const TeacherQuizAlreadySubmittedException(this.result);

  final Map<String, dynamic> result;

  @override
  String toString() => 'تم إكمال اختبار المعلم مسبقًا.';
}

class StudentContentService {
  StudentContentService(
    this.client, {
    this.baseUrl = '',
  });

  final SupabaseClient client;
  final String baseUrl;
  static const _requestTimeout = Duration(seconds: 15);

  Future<StudentGamification> fetchGamification(StudentProfile profile) async {
    final row = await client
        .from('students')
        .select('id,data')
        .eq('id', profile.id)
        .maybeSingle()
        .timeout(_requestTimeout);
    return StudentGamification.fromMap(_asMap(row?['data'])['gamification']);
  }

  /// Applies one web-compatible reward and persists it in the canonical student
  /// row. The activity ledger makes retries and retakes idempotent.
  Future<RewardResult> rewardActivity({
    required StudentProfile profile,
    required String activityType,
    required String activityId,
    int? correctAnswers,
    int? quizTotal,
  }) async {
    if (activityId.trim().isEmpty) {
      throw ArgumentError('لا يمكن منح مكافأة بدون معرف للنشاط.');
    }
    final row = await client
        .from('students')
        .select('id,data')
        .eq('id', profile.id)
        .maybeSingle()
        .timeout(_requestTimeout);
    if (row == null) throw StateError('لم يتم العثور على سجل الطالب.');
    final rowData = _asMap(row['data']);
    final current = StudentGamification.fromMap(rowData['gamification']);
    final key = '${activityType.trim().toLowerCase()}:$activityId';
    if (current.completedActivities.contains(key)) {
      return RewardResult(
        xp: 0,
        gems: 0,
        alreadyRewarded: true,
        levelUp: false,
        newAchievements: const [],
        snapshot: current,
      );
    }

    var xp = 0;
    var gems = 0;
    var quizzes = current.totalQuizzes;
    var lessons = current.totalLessons;
    var games = current.totalGames;
    var average = current.averageScore;
    var perfectQuiz = false;
    int? quizPercentage;
    if (activityType == 'quiz') {
      final score = ((correctAnswers ?? 0).clamp(0, quizTotal ?? 0)).toInt();
      xp = score * 5;
      gems = score;
      quizzes++;
      if (quizTotal != null && quizTotal > 0) {
        final scorePercentage = score * 100 ~/ quizTotal;
        quizPercentage = scorePercentage;
        perfectQuiz = scorePercentage == 100;
        average =
            ((current.averageScore * (quizzes - 1) + scorePercentage) ~/ quizzes);
      }
    } else if (activityType == 'lesson') {
      xp = 25;
      gems = 5;
      lessons++;
    } else if (activityType == 'video' || activityType == 'problem') {
      xp = 5;
      gems = 1;
    } else if (activityType == 'game') {
      xp = 15;
      gems = 3;
      games++;
    }

    final beforeLevel = current.level;
    final nextXp = current.xp + xp;
    final unlocked = _achievementsFor(
      current.copyWith(
        xp: nextXp,
        gems: current.gems + gems,
        totalQuizzes: quizzes,
        totalLessons: lessons,
        totalGames: games,
      ),
      activityType,
      perfectQuiz: perfectQuiz,
      activityId: activityId,
    );
    final knownIds = current.achievements.map((item) => item.id).toSet();
    final newAchievements = unlocked.where((item) => !knownIds.contains(item.id)).toList();
    final next = current.copyWith(
      xp: nextXp,
      gems: current.gems + gems,
      totalQuizzes: quizzes,
      totalLessons: lessons,
      totalGames: games,
      averageScore: average,
      lastQuizAt: activityType == 'quiz'
          ? DateTime.now().toIso8601String()
          : current.lastQuizAt,
      lastQuizPercentage: activityType == 'quiz'
          ? quizPercentage
          : current.lastQuizPercentage,
      achievements: [...current.achievements, ...newAchievements],
      completedActivities: [...current.completedActivities, key],
    );
    await client.from('students').update({
      'data': {...rowData, 'gamification': next.toMap(), 'lastActivity': DateTime.now().toIso8601String()},
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', profile.id).timeout(_requestTimeout);
    return RewardResult(
      xp: xp,
      gems: gems,
      alreadyRewarded: false,
      levelUp: next.level > beforeLevel,
      newAchievements: newAchievements,
      snapshot: next,
    );
  }

  Future<RewardResult> checkStreak(StudentProfile profile) async {
    final current = await fetchGamification(profile);
    final today = DateTime.now();
    final dayKey = '${today.year}-${today.month}-${today.day}';
    final marker = 'streak-day:$dayKey';
    if (current.completedActivities.contains(marker)) {
      return RewardResult(xp: 0, gems: 0, alreadyRewarded: true, levelUp: false, newAchievements: const [], snapshot: current);
    }
    // Keep a compact day ledger; consecutive days are derived from its tail.
    final days = current.completedActivities.where((item) => item.startsWith('streak-day:')).toList();
    var streak = 1;
    if (days.isNotEmpty) {
      final last = DateTime.tryParse(days.last.substring('streak-day:'.length));
      if (last != null && today.difference(DateTime(last.year, last.month, last.day)).inDays == 1) streak = current.streak + 1;
    }
    final bonus = streak % 5 == 0 ? 100 : 0;
    final row = await client.from('students').select('data').eq('id', profile.id).maybeSingle().timeout(_requestTimeout);
    final rowData = _asMap(row?['data']);
    final knownIds = current.achievements.map((item) => item.id).toSet();
    final streakAchievements = <StudentAchievement>[];
    void addAchievement(String id, String title, String description, String icon) {
      if (!knownIds.contains(id)) {
        streakAchievements.add(StudentAchievement(id: id, title: title, description: description, icon: icon));
      }
    }
    if (streak >= 3) addAchievement('streak_3', '3 أيام متواصل', 'تعلم 3 أيام متتالية', '🔥');
    if (streak >= 5) addAchievement('streak_5', '5 أيام متواصل', 'تعلم 5 أيام متتالية واحصل على مكافأة', '🏅');
    if (streak >= 7) addAchievement('streak_7', 'أسبوع متواصل', 'تعلم 7 أيام متتالية', '🔥');
    final next = current.copyWith(
      xp: current.xp + bonus,
      streak: streak,
      achievements: [...current.achievements, ...streakAchievements],
      completedActivities: [...days, marker],
    );
    await client.from('students').update({
      'data': {...rowData, 'gamification': next.toMap(), 'lastActivity': DateTime.now().toIso8601String()},
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', profile.id).timeout(_requestTimeout);
    return RewardResult(xp: bonus, gems: 0, alreadyRewarded: false, levelUp: next.level > current.level, newAchievements: streakAchievements, snapshot: next);
  }

  List<StudentAchievement> _achievementsFor(
    StudentGamification stats,
    String type, {
    bool perfectQuiz = false,
    String activityId = '',
  }) {
    final result = <StudentAchievement>[];
    void add(String id, String title, String description, String icon) {
      result.add(StudentAchievement(id: id, title: title, description: description, icon: icon));
    }
    if (type == 'quiz' && stats.totalQuizzes == 1) add('first_quiz', 'أول اختبار', 'أكمل أول اختبار', '🎯');
    if (type == 'quiz' && stats.totalQuizzes >= 10) add('quiz_warrior', 'مقاتل الاختبارات', 'أكمل 10 اختبارات', '⚔️');
    if (type == 'quiz' && perfectQuiz) add('perfect_quiz', 'نتيجة مثالية', 'حصل على 100% في اختبار', '⭐');
    if (type == 'lesson' && stats.totalLessons == 1) add('first_lesson', 'أول درس', 'أكمل أول درس', '📚');
    if (type == 'lesson' && stats.totalLessons >= 10) add('lesson_master', 'سيد الدروس', 'أكمل 10 دروس', '🏆');
    if (type == 'problem') add('math_solver', 'حلال المسائل', 'حل أول مسألة', '🔢');
    if (type == 'game' && stats.totalGames >= 5) add('game_master', 'سيد الألعاب', 'العب 5 ألعاب', '🎮');
    final normalizedActivity = activityId.toLowerCase();
    if (type == 'game' && normalizedActivity.contains('memory')) {
      add('memory_master', 'سيد الذاكرة', 'انتصر في لعبة الذاكرة', '🧠');
    }
    if (type == 'game' && normalizedActivity.contains('speed')) {
      add('speed_demon', 'سريع كالبرق', 'فوز في الاختبار السريع', '⚡');
    }
    if (stats.level >= 5) add('level_5', 'المستوى 5', 'اوصل إلى المستوى 5', '💪');
    if (stats.gems >= 50) add('gem_collector', 'جامع الجواهر', 'اجمع 50 جوهرة', '💎');
    return result;
  }

  Future<AcademicSelectionData> fetchAcademicSelectionData(
    StudentProfile profile,
  ) async {
    Object? hierarchyValue;
    var hierarchyUnavailable = false;

    try {
      final row = await client
          .from('app_kv')
          .select('value')
          .eq('key', 'smartEdu_hierarchicalConfigs')
          .maybeSingle();
      hierarchyValue = row?['value'];
    } catch (_) {
      hierarchyUnavailable = true;
    }

    final response = await client
        .from('lesson_configs')
        .select('id,data')
        .limit(500)
        .timeout(_requestTimeout);
    final matchingLessons = response
        .whereType<Map>()
        .map(
          (row) => parseLessonContent(
            row,
            baseUrl: baseUrl,
            storageClient: client,
          ),
        )
        .where((lesson) => _matchesOwner(lesson, profile))
        .toList();

    final hierarchyPaths = <AcademicPath>[
      ..._pathsFromHierarchy(hierarchyValue, profile),
      ...matchingLessons
          .where(_hasCompleteAcademicPath)
          .map(
            (lesson) => AcademicPath(
              grade: lesson.grade,
              atram: lesson.atram,
              subject: lesson.subject,
              term: lesson.term,
              unit: lesson.unit,
            ),
          ),
    ];
    final paths = _uniquePaths(hierarchyPaths)
        .where(
          (path) => matchingLessons.any(
            (lesson) => _lessonMatchesPath(lesson, path),
          ),
        )
        .toList();

    return AcademicSelectionData(
      paths: paths,
      lessons: matchingLessons,
      hierarchyUnavailable: hierarchyUnavailable,
    );
  }

  Future<List<LessonContent>> fetchLessons(
    StudentProfile profile, {
    AcademicContext? academicContext,
  }) async {
    final response = await client
        .from('lesson_configs')
        .select('id,data')
        .limit(500)
        .timeout(_requestTimeout);

    final lessons = response
        .whereType<Map>()
        .map(
          (row) => parseLessonContent(
            row,
            baseUrl: baseUrl,
            storageClient: client,
          ),
        )
        .where(
          (lesson) => _matchesStudentPath(
            lesson,
            profile,
            academicContext: academicContext,
          ),
        )
        .toList();

    return _preferredLessonsForStudent(lessons, profile);
  }

  /// Resolves one safe, scoped experience for the student dashboard.
  ///
  /// Unlike general lesson browsing, this deliberately rejects partial academic
  /// selections. A virtual-teacher or meeting URL is sensitive to the assigned
  /// teacher and must never be guessed from a broader profile scope.
  Future<TutorExperienceSelection> fetchTutorExperience(
    StudentProfile profile, {
    required AcademicContext? academicContext,
    required TutorExperienceType type,
  }) async {
    if (academicContext == null || !academicContext.hasCompletePath) {
      return TutorExperienceSelection(
        type: type,
        status: TutorExperienceStatus.missingAcademicContext,
      );
    }

    final response = await client
        .from('lesson_configs')
        .select('id,data')
        .limit(500)
        .timeout(_requestTimeout);
    final lessons = response
        .whereType<Map>()
        .map(
          (row) => parseLessonContent(
            row,
            baseUrl: baseUrl,
            storageClient: client,
          ),
        )
        .toList();

    return resolveTutorExperience(
      lessons: lessons,
      profile: profile,
      academicContext: academicContext,
      type: type,
    );
  }

  /// Pure selection logic kept public for regression tests and for callers
  /// that already hold the scoped lesson records.
  static TutorExperienceSelection resolveTutorExperience({
    required List<LessonContent> lessons,
    required StudentProfile profile,
    required AcademicContext? academicContext,
    required TutorExperienceType type,
  }) {
    if (academicContext == null || !academicContext.hasCompletePath) {
      return TutorExperienceSelection(
        type: type,
        status: TutorExperienceStatus.missingAcademicContext,
      );
    }

    final matchingPath = lessons
        .where(
          (lesson) => _matchesExactTutorPath(lesson, academicContext),
        )
        .toList();
    final studentTeacher = _normalize(profile.teacherId);
    final teacherLessons = studentTeacher.isEmpty
        ? const <LessonContent>[]
        : matchingPath
            .where((lesson) => _normalize(lesson.ownerId) == studentTeacher)
            .toList();
    final administratorLessons = matchingPath
        .where(_isAdministratorOrLegacyLesson)
        .toList();

    final teacherSelection = _latestConfiguredExperience(teacherLessons, type);
    // A configured teacher link is authoritative, even if it is malformed.
    // Falling back in that case could show a different experience than the
    // one explicitly configured for the student's teacher.
    final selected = teacherSelection ??
        _latestConfiguredExperience(administratorLessons, type);
    if (selected == null) {
      return TutorExperienceSelection(
        type: type,
        status: TutorExperienceStatus.unavailable,
      );
    }

    final url = normalizeTutorExperienceUrl(_experienceUrl(selected, type));
    if (url == null) {
      return TutorExperienceSelection(
        type: type,
        status: TutorExperienceStatus.unsafeUrl,
        lesson: selected,
      );
    }
    return TutorExperienceSelection(
      type: type,
      status: TutorExperienceStatus.ready,
      lesson: selected,
      url: url,
    );
  }

  Future<List<HtmlGame>> fetchGameCatalog() async {
    final base = baseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    if (base.isEmpty) return _embeddedGameCatalog('');

    final response = await http.get(Uri.parse('$base/api/game-catalog'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _embeddedGameCatalog(base);
    }

    final decoded = jsonDecode(response.body);
    final rawGames = decoded is Map ? decoded['games'] : decoded;
    if (rawGames is! List) return const [];

    final games = <HtmlGame>[];
    for (var index = 0; index < rawGames.length; index++) {
      final map = _asMap(rawGames[index]);
      final url = _resolveUrl(_text(map['url']), base);
      if (!_isSafeUrl(url)) continue;
      games.add(
        HtmlGame(
          id: _text(map['id']).isEmpty ? 'api-game-$index' : _text(map['id']),
          url: url,
          title: _text(map['title']).isEmpty ? 'لعبة تعليمية' : _text(map['title']),
          subtitle: _text(map['subtitle']).isEmpty
              ? 'لعبة تفاعلية داخل منارة'
              : _text(map['subtitle']),
          requiredLevel: _gameRequiredLevel(map),
        ),
      );
    }
    return games.isEmpty ? _embeddedGameCatalog(base) : games;
  }

  Future<List<LessonVideo>> fetchCinemaVideos(
    StudentProfile profile, {
    AcademicContext? academicContext,
  }) async {
    final rows = await Future.wait([
      client
          .from('app_kv')
          .select('value')
          .eq('key', 'smartEdu_videos')
          .maybeSingle(),
      client
          .from('app_kv')
          .select('value')
          .eq('key', 'smartEdu_deletedVideos')
          .maybeSingle(),
    ]);
    final rawVideos = _asList(rows[0]?['value']);
    final deletedIds = _asList(rows[1]?['value'])
        .map(_text)
        .where((id) => id.isNotEmpty)
        .toSet();
    final videos = <LessonVideo>[];
    final seen = <String>{};
    for (final rawVideo in rawVideos) {
      final data = _asMap(rawVideo);
      final recordId = _text(data['id']);
      if (recordId.isNotEmpty && deletedIds.contains(recordId)) continue;
      if (_isDeletedVideo(data)) continue;
      if (!_matchesCinemaScope(data, profile, academicContext)) continue;

      final url = _resolveVideoUrl(
        _text(data['url']),
        baseUrl: baseUrl,
        storageClient: client,
      );
      if (!_isSafeUrl(url)) continue;
      final id = recordId.isEmpty ? url : recordId;
      final key = '$id|$url';
      if (!seen.add(key)) continue;
      videos.add(
        LessonVideo(
          id: id,
          url: url,
          sourceType: _videoType(data['sourceType'], url),
          title: _text(data['title']).isEmpty ? 'فيديو سينما منارة' : _text(data['title']),
          description: _nullableText(data['description']),
        ),
      );
    }
    return videos;
  }

  /// Loads active assessments from the current manager and the legacy question
  /// bank. Selection is performed by [StudentAssessmentRules] so Flutter uses
  /// the same teacher/public ownership and academic-scope rules everywhere.
  Future<List<Map<String, dynamic>>> fetchAvailableQuizzes(
    StudentProfile profile, {
    AcademicContext? academicContext,
  }) async {
    final response = await client
        .from('created_quizzes')
        .select('id,data,updated_at')
        .limit(300)
        .timeout(_requestTimeout);

    final createdQuizzes = <Map<String, dynamic>>[];
    for (final row in response.whereType<Map>()) {
      final rowMap = _asMap(row);
      final data = _asMap(rowMap['data']);
      if (data.isEmpty) continue;
      createdQuizzes.add(<String, dynamic>{
        ...data,
        'id': _text(rowMap['id']).isEmpty ? _text(data['id']) : _text(rowMap['id']),
        'updatedAt': _text(rowMap['updated_at'] ?? data['updatedAt']),
      });
    }

    final legacyQuestions = await _fetchLegacyQuizQuestions();
    return StudentAssessmentRules.selectAvailableQuizzes(
      createdQuizzes: createdQuizzes,
      legacyQuestions: legacyQuestions,
      profile: profile,
      academicContext: academicContext,
    );
  }

  /// Results are always filtered by student ID before they reach the UI.
  Future<List<Map<String, dynamic>>> fetchQuizResults(
    StudentProfile profile,
  ) async {
    final response = await client
        .from('quiz_results')
        .select('id,data,updated_at')
        .eq('data->>studentId', profile.id)
        .order('updated_at', ascending: false)
        .limit(100)
        .timeout(_requestTimeout);
    return response.whereType<Map>().map((row) {
      final rowMap = _asMap(row);
      final data = _asMap(rowMap['data']);
      return <String, dynamic>{
        ...data,
        'id': _text(rowMap['id']).isEmpty ? _text(data['id']) : _text(rowMap['id']),
      };
    }).where((result) => _text(result['studentId']) == profile.id).toList();
  }

  Future<Map<String, dynamic>> saveQuizResult({
    required StudentProfile profile,
    required Map<String, dynamic> result,
  }) async {
    final id = _text(result['id']);
    if (id.isEmpty) {
      throw ArgumentError('لا يمكن حفظ نتيجة اختبار بدون معرف.');
    }
    final safeResult = <String, dynamic>{
      ...result,
      'id': id,
      'studentId': profile.id,
      'studentName': profile.name,
      'quizType': StudentAssessmentRules.quizTypeValue(result['quizType']),
      'grade': _text(result['grade']).isEmpty ? _text(profile.grade) : _text(result['grade']),
      'atram': _text(result['atram']).isEmpty ? _text(profile.atram) : _text(result['atram']),
      'subject': _text(result['subject']).isEmpty ? _text(profile.subject) : _text(result['subject']),
      'term': _text(result['term']).isEmpty ? _text(profile.term) : _text(result['term']),
      'unit': _text(result['unit']).isEmpty ? _text(profile.unit) : _text(result['unit']),
    };
    if (StudentAssessmentRules.isTeacherQuiz(safeResult)) {
      final existing = await client
          .from('quiz_results')
          .select('id,data,updated_at')
          .eq('data->>studentId', profile.id)
          .eq('data->>quizId', _text(safeResult['quizId']))
          .limit(1)
          .timeout(_requestTimeout);
      for (final row in existing.whereType<Map>()) {
        final rowMap = _asMap(row);
        final stored = _asMap(rowMap['data']);
        if (StudentAssessmentRules.isTeacherQuiz(stored)) {
          throw TeacherQuizAlreadySubmittedException(<String, dynamic>{
            ...stored,
            'id': _text(rowMap['id']).isEmpty ? _text(stored['id']) : _text(rowMap['id']),
          });
        }
      }
    }
    await client.from('quiz_results').upsert({
      'id': id,
      'data': safeResult,
      'updated_at': DateTime.now().toIso8601String(),
    }).timeout(_requestTimeout);
    return safeResult;
  }

  Future<void> saveAppearance({
    required StudentProfile profile,
    required Map<String, dynamic> appearance,
  }) async {
    final current = await client
        .from('students')
        .select('data')
        .eq('id', profile.id)
        .maybeSingle();
    final existing = _asMap(current?['data']);
    final nextData = <String, dynamic>{
      ...existing,
      'appearance': appearance,
      'lastActivity': DateTime.now().toIso8601String(),
    };

    await client
        .from('students')
        .update({
          'data': nextData,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', profile.id);
  }

  Future<List<Map<String, dynamic>>> loadTutorHistory(
    StudentProfile profile,
  ) async {
    final response = await client
        .from('interactions')
        .select('id,data')
        .eq('data->>studentId', profile.id)
        .order('updated_at', ascending: true)
        .limit(60)
        .timeout(_requestTimeout);
    return response
        .whereType<Map>()
        .map((row) => _asMap(row['data']))
        .where((data) => _text(data['studentId']) == profile.id)
        .where((data) => _text(data['type']) == 'virtual_teacher')
        .toList();
  }

  Future<void> saveTutorInteraction({
    required StudentProfile profile,
    required String question,
    required String answer,
  }) async {
    final id = '${profile.id}_${DateTime.now().microsecondsSinceEpoch}';
    await client.from('interactions').upsert({
      'id': id,
      'data': {
        'studentId': profile.id,
        'type': 'virtual_teacher',
        'question': question,
        'answer': answer,
        'createdAt': DateTime.now().toIso8601String(),
      },
      'updated_at': DateTime.now().toIso8601String(),
    }).timeout(_requestTimeout);
  }

  Future<void> saveProblemSolverInteraction({
    required StudentProfile profile,
    required String lessonId,
    required String question,
  }) async {
    final now = DateTime.now();
    await client.from('interactions').upsert({
      'id': '${profile.id}_solver_${now.microsecondsSinceEpoch}',
      'data': {
        'studentId': profile.id,
        'studentName': profile.name,
        'teacherId': profile.teacherId,
        'type': 'problem_solver',
        'lessonId': lessonId,
        'question': question,
        'grade': profile.grade,
        'atram': profile.atram,
        'subject': profile.subject,
        'term': profile.term,
        'unit': profile.unit,
        'createdAt': now.toIso8601String(),
      },
      'updated_at': now.toIso8601String(),
    }).timeout(_requestTimeout);
  }

  Future<List<Map<String, dynamic>>> _fetchLegacyQuizQuestions() async {
    try {
      final row = await client
          .from('app_kv')
          .select('value')
          .eq('key', 'smartEdu_quizQuestions')
          .maybeSingle()
          .timeout(_requestTimeout);
      return _asList(row?['value']).map(_asMap).where((item) => item.isNotEmpty).toList();
    } catch (_) {
      // The modern quiz table remains usable when older installations do not
      // expose the historical app_kv key to the student role.
      return const [];
    }
  }

  bool _matchesOwner(LessonContent lesson, StudentProfile profile) {
    final owner = _normalize(lesson.ownerId);
    final teacher = _normalize(profile.teacherId);
    if (owner.isEmpty || owner == 'admin' || owner == 'supervisor') return true;
    if (teacher.isEmpty) return false;
    return owner == teacher;
  }

  bool _matchesStudentPath(
    LessonContent lesson,
    StudentProfile profile, {
    AcademicContext? academicContext,
  }) {
    final grade = academicContext?.grade ?? profile.grade;
    final atram = academicContext?.atram ?? profile.atram;
    final subject = academicContext?.subject ?? profile.subject;
    final term = academicContext?.term ?? profile.term;
    final unit = academicContext?.unit ?? profile.unit;
    return _matchesOwner(lesson, profile) &&
        _matches(lesson.grade, grade) &&
        _matches(lesson.atram, atram) &&
        _matches(lesson.subject, subject) &&
        _matches(lesson.term, term) &&
        _matches(lesson.unit, unit);
  }

  bool _matchesCinemaScope(
    Map<String, dynamic> video,
    StudentProfile profile,
    AcademicContext? academicContext,
  ) {
    final owner = _normalize(
      video['teacher_id'] ?? video['teacherId'] ?? video['createdBy'],
    );
    final teacher = _normalize(profile.teacherId);
    // Cinema records are created by the teacher/admin manager with an owner.
    // Treat ownerless records as legacy data, not public student content; this
    // prevents obsolete app_kv entries from appearing as "ghost" videos.
    final ownerAllowed =
        owner == 'admin' ||
        owner == 'supervisor' ||
        (teacher.isNotEmpty && owner == teacher);
    if (!ownerAllowed) return false;

    final grade = academicContext?.grade ?? profile.grade;
    final atram = academicContext?.atram ?? profile.atram;
    final subject = academicContext?.subject ?? profile.subject;
    final term = academicContext?.term ?? profile.term;
    final unit = academicContext?.unit ?? profile.unit;
    return _matches(_text(video['grade']), grade) &&
        _matches(_text(video['atram']), atram) &&
        _matches(_text(video['subject']), subject) &&
        _matches(_text(video['term']), term) &&
        _matches(_text(video['unit']), unit);
  }

  bool _matches(String contentValue, String? selectedValue) {
    final content = _normalize(contentValue);
    final selected = _normalize(selectedValue);
    if (content.isEmpty || selected.isEmpty) return true;
    return content == selected;
  }

  static bool _matchesExactTutorPath(
    LessonContent lesson,
    AcademicContext context,
  ) {
    return _normalize(lesson.grade) == _normalize(context.grade) &&
        _normalize(lesson.atram) == _normalize(context.atram) &&
        _normalize(lesson.subject) == _normalize(context.subject) &&
        _normalize(lesson.term) == _normalize(context.term) &&
        _normalize(lesson.unit) == _normalize(context.unit);
  }

  static bool _isAdministratorOrLegacyLesson(LessonContent lesson) {
    final owner = _normalize(lesson.ownerId);
    return owner.isEmpty || owner == 'admin' || owner == 'supervisor';
  }

  static LessonContent? _latestConfiguredExperience(
    List<LessonContent> lessons,
    TutorExperienceType type,
  ) {
    final configured = lessons
        .where((lesson) => _experienceUrl(lesson, type).trim().isNotEmpty)
        .toList()
      ..sort((a, b) {
        final timestamp = b.createdAt.compareTo(a.createdAt);
        return timestamp != 0 ? timestamp : b.id.compareTo(a.id);
      });
    return configured.isEmpty ? null : configured.first;
  }

  List<LessonContent> _preferredLessonsForStudent(
    List<LessonContent> lessons,
    StudentProfile profile,
  ) {
    final grouped = <String, List<LessonContent>>{};
    for (final lesson in lessons) {
      final key = [
        lesson.grade,
        lesson.atram,
        lesson.subject,
        lesson.term,
        lesson.unit,
      ].map(_normalize).join('|');
      grouped.putIfAbsent(key, () => []).add(lesson);
    }

    final studentTeacher = _normalize(profile.teacherId);
    final preferred = <LessonContent>[];
    for (final candidates in grouped.values) {
      final teacherOwned = studentTeacher.isEmpty
          ? const <LessonContent>[]
          : candidates
              .where((lesson) => _normalize(lesson.ownerId) == studentTeacher)
              .toList();
      final pool = teacherOwned.isNotEmpty ? teacherOwned : candidates;
      pool.sort((a, b) {
        final timestamp = b.createdAt.compareTo(a.createdAt);
        return timestamp != 0 ? timestamp : b.id.compareTo(a.id);
      });
      preferred.add(pool.first);
    }
    preferred.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return preferred;
  }

}

String _experienceUrl(LessonContent lesson, TutorExperienceType type) {
  return type == TutorExperienceType.liveMeeting
      ? lesson.liveMeetingUrl ?? ''
      : lesson.avatarInteractionUrl ?? '';
}

/// Accepts only browser-safe HTTPS links before a lesson author’s data reaches
/// the embedded WebView. This is shared by selection and rendering.
String? normalizeTutorExperienceUrl(String? value) {
  if (value == null) return null;
  final raw = value.trim();
  if (raw.isEmpty || RegExp(r'[\s\x00-\x1F\x7F]').hasMatch(raw)) {
    return null;
  }

  var candidate = raw;
  if (candidate.startsWith('//')) {
    candidate = 'https:$candidate';
  } else if (!candidate.contains('://') && !candidate.contains(':')) {
    candidate = 'https://$candidate';
  }

  final uri = Uri.tryParse(candidate);
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri.toString();
}

bool _isDeletedVideo(Map<String, dynamic> data) {
  final status = _text(data['status']).toLowerCase();
  return data['deleted'] == true ||
      data['isDeleted'] == true ||
      status == 'deleted' ||
      status == 'removed';
}

List<AcademicPath> _pathsFromHierarchy(
  Object? value,
  StudentProfile profile,
) {
  if (value is! List) return const [];

  final paths = <AcademicPath>[];
  for (final rawConfig in value) {
    final config = _asMap(rawConfig);
    if (!_matchesConfigOwner(config, profile)) continue;

    final grade = _value(config, ['grade', 'class', 'schoolGrade']);
    final atrams = config['atrams'];
    if (grade.isEmpty || atrams is! List) continue;

    for (final rawAtram in atrams) {
      final atram = _asMap(rawAtram);
      final atramName = _value(atram, ['atram', 'semester', 'term']);
      final subjects = atram['subjects'];
      if (atramName.isEmpty || subjects is! List) continue;

      for (final rawSubject in subjects) {
        final subject = _asMap(rawSubject);
        final subjectName = _value(subject, ['subject', 'course']);
        final terms = subject['terms'];
        if (subjectName.isEmpty || terms is! List) continue;

        for (final rawTerm in terms) {
          final term = _asMap(rawTerm);
          final termName = _value(term, ['term', 'chapter', 'name']);
          final units = term['units'];
          if (termName.isEmpty || units is! List) continue;

          for (final rawUnit in units) {
            final unit = _text(rawUnit);
            if (unit.isEmpty) continue;
            paths.add(
              AcademicPath(
                grade: grade,
                atram: atramName,
                subject: subjectName,
                term: termName,
                unit: unit,
              ),
            );
          }
        }
      }
    }
  }
  return paths;
}

List<AcademicPath> _uniquePaths(Iterable<AcademicPath> paths) {
  final unique = <AcademicPath>[];
  final seen = <String>{};
  for (final path in paths) {
    if (!_hasPathValues(path)) continue;
    final key = [
      path.grade,
      path.atram,
      path.subject,
      path.term,
      path.unit,
    ].map(_normalize).join('|');
    if (seen.add(key)) unique.add(path);
  }
  return unique;
}

bool _hasCompleteAcademicPath(LessonContent lesson) {
  return _hasPathValues(
    AcademicPath(
      grade: lesson.grade,
      atram: lesson.atram,
      subject: lesson.subject,
      term: lesson.term,
      unit: lesson.unit,
    ),
  );
}

bool _hasPathValues(AcademicPath path) {
  return [
    path.grade,
    path.atram,
    path.subject,
    path.term,
    path.unit,
  ].every((value) => value.trim().isNotEmpty);
}

bool _lessonMatchesPath(LessonContent lesson, AcademicPath path) {
  return [
    (lesson.grade, path.grade),
    (lesson.atram, path.atram),
    (lesson.subject, path.subject),
    (lesson.term, path.term),
    (lesson.unit, path.unit),
  ].every((pair) => _normalize(pair.$1) == _normalize(pair.$2));
}

bool _matchesConfigOwner(Map<String, dynamic> config, StudentProfile profile) {
  final owner = _normalize(
    config['teacherId'] ?? config['teacher_id'] ?? config['createdBy'],
  );
  final teacher = _normalize(profile.teacherId);
  if (owner.isEmpty || owner == 'admin' || owner == 'supervisor') return true;
  return teacher.isNotEmpty && owner == teacher;
}

String _value(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

LessonContent parseLessonContent(
  Map row, {
  String baseUrl = '',
  SupabaseClient? storageClient,
}) {
  final data = _asMap(row['data']);
  final videos = <LessonVideo>[];
  final rawVideos = data['explanationVideos'];

  if (rawVideos is List) {
    for (var index = 0; index < rawVideos.length; index++) {
      final item = _asMap(rawVideos[index]);
      final url = _resolveVideoUrl(
        _text(item['url']),
        baseUrl: baseUrl,
        storageClient: storageClient,
      );
      if (!_isSafeUrl(url)) continue;
      videos.add(
        LessonVideo(
          id: _text(item['id']).isEmpty ? 'video-$index' : _text(item['id']),
          url: url,
          sourceType: _videoType(item['sourceType'], url),
          title: _text(item['title']).isEmpty ? 'فيديو الشرح ${index + 1}' : _text(item['title']),
          description: _nullableText(item['description']),
        ),
      );
    }
  }

  final legacyUrl = _resolveVideoUrl(
    _text(data['explanationVideoUrl']),
    baseUrl: baseUrl,
    storageClient: storageClient,
  );
  // explanationVideos is the authoritative structured list. The legacy
  // single-video field can point at a previous upload, so use it only for
  // lessons created before the structured list existed.
  if (videos.isEmpty && _isSafeUrl(legacyUrl)) {
    videos.insert(
      0,
      LessonVideo(
        id: 'legacy-video',
        url: legacyUrl,
        sourceType: _videoType(data['explanationVideoType'], legacyUrl),
        title: 'فيديو الشرح',
      ),
    );
  }

  final games = _parseGames(data, baseUrl: baseUrl);
  return LessonContent(
    id: _text(row['id']).isEmpty ? _text(data['id']) : _text(row['id']),
    lessonId: _value(data, ['lesson_id', 'lessonId', 'id']).isEmpty
        ? _text(row['id'])
        : _value(data, ['lesson_id', 'lessonId', 'id']),
    grade: _text(data['grade']),
    atram: _text(data['atram']),
    subject: _text(data['subject']),
    term: _text(data['term']),
    unit: _text(data['unit']),
    lessonName: _value(
      data,
      ['lesson', 'lessonName', 'lessonTitle', 'currentLesson', 'name'],
    ),
    createdAt: _text(data['updatedAt'] ?? data['createdAt']),
    ownerId: _nullableText(data['teacherId'] ?? data['teacher_id'] ?? data['createdBy']),
    lessonText: _nullableText(data['lessonContent']),
    avatarInteractionUrl: _nullableText(data['avatarInteractionUrl']),
    liveMeetingUrl: _nullableText(data['liveMeetingUrl']),
    videos: videos,
    games: games,
  );
}

List<HtmlGame> _parseGames(Map<String, dynamic> data, {String baseUrl = ''}) {
  final games = <HtmlGame>[];
  final rawGames = data['games'] ?? data['html5Games'] ?? data['entertainmentGames'];
  if (rawGames is List) {
    for (var index = 0; index < rawGames.length; index++) {
      final item = rawGames[index];
      final map = item is String ? <String, dynamic>{'url': item} : _asMap(item);
      final url = _resolveUrl(_text(map['url'] ?? map['gameUrl']), baseUrl);
      if (!_isSafeUrl(url)) continue;
      games.add(
        HtmlGame(
          id: _text(map['id']).isEmpty ? 'game-$index' : _text(map['id']),
          url: url,
          title: _text(map['title']).isEmpty ? 'اللعبة ${index + 1}' : _text(map['title']),
          subtitle: _text(map['subtitle']).isEmpty
              ? 'لعبة HTML5 تفاعلية داخل منارة'
              : _text(map['subtitle']),
          requiredLevel: _gameRequiredLevel(map),
        ),
      );
    }
  }
  final singleGame = _resolveUrl(
    _text(data['gameUrl'] ?? data['html5GameUrl']),
    baseUrl,
  );
  if (_isSafeUrl(singleGame) && !games.any((game) => game.url == singleGame)) {
    games.add(
      HtmlGame(
        id: 'lesson-game',
        url: singleGame,
        title: 'لعبة الدرس',
        subtitle: 'تحدٍ تفاعلي مرتبط بالدرس',
        requiredLevel: _gameRequiredLevel(data),
      ),
    );
  }
  return games;
}

int _gameRequiredLevel(Map<String, dynamic> data) {
  final raw = data['requiredLevel'] ?? data['required_level'] ?? data['level'];
  final level = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
  if (level == null &&
      _text(data['id']) == '172e0bd0c40442dbae3d4adb42a98433') {
    return 2;
  }
  return (level ?? 0).clamp(0, 99).toInt();
}

List<HtmlGame> _embeddedGameCatalog(String baseUrl) {
  const entries = [
    (
      id: 'd4a3629101574bc39bd8f9d1888ca58e',
      title: 'مغامرة التعلم',
      subtitle: 'لعبة تعليمية تفاعلية داخل منارة',
      requiredLevel: 0,
    ),
    (
      id: '172e0bd0c40442dbae3d4adb42a98433',
      title: 'تحدي المعرفة',
      subtitle: 'اختبر مهاراتك بطريقة ممتعة',
      requiredLevel: 2,
    ),
  ];
  return entries
      .map(
        (entry) {
          final apiPath = '/api/game-embed/${entry.id}/index.html';
          // Flutter Web can run in a browser that does not expose the local
          // API service port. Use the public HTML5 game entry point when an
          // API base was not explicitly supplied, so the iframe always loads.
          final url = baseUrl.trim().isEmpty
              ? 'https://html5.gamedistribution.com/rvvASMiM/${entry.id}/index.html'
              : _resolveUrl(apiPath, baseUrl);
          return HtmlGame(
            id: entry.id,
            url: url,
            title: entry.title,
            subtitle: entry.subtitle,
            requiredLevel: entry.requiredLevel,
          );
        },
      )
      .toList();
}

VideoSourceType _videoType(Object? value, String url) {
  final normalizedUrl = url.toLowerCase();
  final isDirectVideo = RegExp(r'\.(mp4|m4v|mov|webm|m3u8)(?:$|[?#])')
          .hasMatch(normalizedUrl) ||
      normalizedUrl.contains('/storage/v1/object/public/');
  if (value?.toString().toLowerCase() == 'mp4' || isDirectVideo) {
    return VideoSourceType.mp4;
  }
  return VideoSourceType.embed;
}

String _normalize(Object? value) => value?.toString().trim().toLowerCase() ?? '';

String _text(Object? value) => value?.toString().trim() ?? '';

List<Object?> _asList(Object? value) {
  if (value is List) return value.cast<Object?>();
  if (value is Map) {
    final map = _asMap(value);
    final nested = map['videos'] ?? map['items'] ?? map['data'];
    if (nested is List) return nested.cast<Object?>();
  }
  return const [];
}

bool _isSafeUrl(String value) {
  final raw = value.trim().toLowerCase();
  if (raw.isEmpty || raw.startsWith('javascript:') || raw.startsWith('data:') || raw.startsWith('blob:')) {
    return false;
  }
  if (RegExp(r'^/api/media/videos/[a-z0-9-]+\.mp4$').hasMatch(raw)) {
    return true;
  }
  if (RegExp(
    r'^/api/game-embed/[a-z0-9-]+/index\.html(?:[?#]|$)',
  ).hasMatch(raw)) {
    return true;
  }
  final uri = Uri.tryParse(value.trim());
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

String _resolveUrl(String value, String baseUrl) {
  final raw = _canonicalLocalVideoPath(value.trim());
  if (!raw.startsWith('/') || baseUrl.trim().isEmpty) return raw;
  final base = Uri.tryParse(baseUrl.trim());
  return base == null ? raw : base.resolve(raw).toString();
}

String _resolveVideoUrl(
  String value, {
  required String baseUrl,
  SupabaseClient? storageClient,
}) {
  final raw = _canonicalLocalVideoPath(value.trim());
  final storagePath = _lessonVideoStoragePath(raw);
  if (storagePath != null && storageClient != null) {
    return storageClient.storage
        .from('lesson-videos')
        .getPublicUrl(storagePath);
  }
  return _resolveUrl(raw, baseUrl);
}

String? _lessonVideoStoragePath(String raw) {
  if (raw.isEmpty) return null;

  final uri = Uri.tryParse(raw);
  if (uri != null && uri.hasScheme) return null;

  var path = raw.split(RegExp(r'[?#]')).first.replaceAll('\\', '/');
  if (path.isEmpty ||
      path.startsWith('/api/') ||
      path.startsWith('/uploads/')) {
    return null;
  }

  final bucketMatch = RegExp(
    r'^/?(?:(?:storage/v1/)?object/public/)?lesson-videos/(.+)$',
  ).firstMatch(path);
  if (bucketMatch != null) {
    path = bucketMatch.group(1)!;
  } else {
    // A leading slash without the bucket name is treated as an API path,
    // except for a recognizable video object key saved by older admin forms.
    if (path.startsWith('/')) {
      final candidate = path.substring(1);
      if (!RegExp(r'\.(mp4|m4v|mov|webm|m3u8)$', caseSensitive: false)
          .hasMatch(candidate)) {
        return null;
      }
      path = candidate;
    }
  }

  try {
    return Uri.decodeComponent(path);
  } on FormatException {
    return path;
  }
}

String _canonicalLocalVideoPath(String value) {
  final legacyMatch = RegExp(
    r'^/uploads/videos/([a-zA-Z0-9-]+\.mp4)$',
  ).firstMatch(value);
  if (legacyMatch == null) return value;
  return '/api/media/videos/${legacyMatch.group(1)}';
}

String? _nullableText(Object? value) {
  final valueText = _text(value);
  return valueText.isEmpty ? null : valueText;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}