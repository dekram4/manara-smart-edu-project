import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/academic_context.dart';
import '../models/student_assessment.dart';
import '../models/student_content.dart';
import '../l10n/student_strings.dart';
import '../models/student_profile.dart';
import '../models/student_gamification.dart';
import 'student_auth_service.dart';

class TeacherQuizAlreadySubmittedException implements Exception {
  const TeacherQuizAlreadySubmittedException(this.result);

  final Map<String, dynamic> result;

  @override
  String toString() => tr('svc.quizAlreadyDone');
}

class StudentContentService {
  StudentContentService(this.client, {this.baseUrl = '', this.authService});

  final SupabaseClient client;
  final String baseUrl;

  /// يلزم لكتابات التقدّم وحدها؛ القراءات تمرّ بـ Supabase مباشرةً.
  ///
  /// اختياري لأن أغلب مواضع الإنشاء تقرأ فقط، لكن أي استدعاء لكتابة بلا
  /// خدمة مصادقة يفشل صراحةً بدل أن يكتب في فراغ.
  final StudentAuthService? authService;

  static const _requestTimeout = Duration(seconds: 15);

  // ── كتابات التقدّم ─────────────────────────────────────────────────────
  //
  // لم تعد تمرّ بـ Supabase. مفتاح anon لا يستطيع الكتابة بعد تشديد RLS،
  // وهذا مقصود: لا توجد `auth.uid()` في مسار دخول الطالب، فأي سماح لدور
  // anon كان سماحاً لكل حامل للمفتاح بتعديل درجات كل طالب.
  //
  // الخادم يأخذ هوية الطالب من الرمز الموقَّع، ويحسب المكافأة بنفسه. ما
  // يُرسَل هنا وصفٌ لما جرى، لا نتيجةٌ مطلوب حفظها.

  Uri _progressEndpoint(String route) {
    var base = baseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    if (base.isEmpty) {
      final current = Uri.base;
      if (current.scheme == 'http' || current.scheme == 'https') {
        base = current.host == 'localhost' || current.host == '127.0.0.1'
            ? 'http://localhost:8080'
            : current.origin;
      }
    }
    if (base.isEmpty) throw StateError(tr('auth.serviceUnreachable'));
    return Uri.parse('$base/api/student/progress/$route');
  }

  /// يرسل كتابة تقدّم واحدة، ويجدّد الجلسة مرة واحدة إن كانت قد انتهت.
  ///
  /// رمز الجلسة يعيش 12 ساعة، وجلسة الطالب قد تمتدّ أطول. فبدل أن يرى
  /// الطفل فشلاً لأن الرمز انتهى بين نشاطين، نُجدّده ونعيد المحاولة مرة
  /// واحدة — ومرةً واحدة فقط، كي لا يتحوّل الرفض الدائم إلى حلقة.
  Future<Map<String, dynamic>> _postProgress(
    String route,
    Map<String, dynamic> body,
  ) async {
    final auth = authService;
    if (auth == null) throw StateError(tr('svc.noSession'));

    Future<http.Response> send(String token) => http
        .post(
          _progressEndpoint(route),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);

    var token = auth.apiSessionToken?.trim();
    if (token == null || token.isEmpty) {
      token = (await auth.ensureApiSession())?.trim();
    }
    if (token == null || token.isEmpty) throw StateError(tr('svc.noSession'));

    var response = await send(token);
    if (response.statusCode == 401) {
      auth.clearApiSession();
      final refreshed = (await auth.ensureApiSession())?.trim();
      if (refreshed == null || refreshed.isEmpty) {
        throw StateError(tr('svc.noSession'));
      }
      response = await send(refreshed);
    }

    final decoded = response.body.trim().isEmpty
        ? const <String, dynamic>{}
        : _asMap(jsonDecode(response.body));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    if (response.statusCode == 409) {
      throw TeacherQuizAlreadySubmittedException(_asMap(decoded['result']));
    }
    final message = _text(decoded['error']);
    // `detail` carries what the database actually said — a permissions
    // refusal, a missing column, a value the table would not take. Without
    // it every failed write reached the student as the same sentence, and
    // there was nothing to act on.
    final detail = _text(decoded['detail']);
    final headline = message.isEmpty ? tr('auth.serviceUnreachable') : message;
    throw StateError(detail.isEmpty ? headline : '$headline — $detail');
  }

  RewardResult _rewardFromResponse(Map<String, dynamic> payload) {
    final achievements = payload['newAchievements'];
    return RewardResult(
      xp: _number(payload['xp']),
      gems: _number(payload['gems']),
      alreadyRewarded: payload['alreadyRewarded'] == true,
      levelUp: payload['levelUp'] == true,
      newAchievements: achievements is List
          ? achievements
                .whereType<Map>()
                .map((item) => StudentAchievement.fromMap(_asMap(item)))
                .where((item) => item.id.isNotEmpty)
                .toList()
          : const [],
      snapshot: StudentGamification.fromMap(payload['snapshot']),
    );
  }

  Future<StudentGamification> fetchGamification(StudentProfile profile) async {
    final row = await client
        .from('students')
        .select('id,data')
        .eq('id', profile.id)
        .maybeSingle()
        .timeout(_requestTimeout);
    return StudentGamification.fromMap(_asMap(row?['data'])['gamification']);
  }

  /// يطلب من الخادم تطبيق مكافأة نشاط واحد.
  ///
  /// الحساب كلّه انتقل إلى `studentProgress.ts`: النوع والمعرّف والنتيجة
  /// تصف ما جرى، والخادم هو من يقرّر الجواهر والخبرة والإنجازات ويكتبها.
  /// سجلّ الأنشطة هناك يجعل الإعادة بلا أثر.
  Future<RewardResult> rewardActivity({
    required StudentProfile profile,
    required String activityType,
    required String activityId,
    String? rewardId,
    int? correctAnswers,
    int? quizTotal,
  }) async {
    if (activityId.trim().isEmpty) {
      throw ArgumentError(tr('svc.noActivityId'));
    }
    final payload = await _postProgress('reward', {
      'activityType': activityType.trim().toLowerCase(),
      'activityId': activityId.trim(),
      if (rewardId != null && rewardId.trim().isNotEmpty)
        'rewardId': rewardId.trim(),
      if (correctAnswers != null) 'correctAnswers': correctAnswers,
      if (quizTotal != null) 'quizTotal': quizTotal,
    });
    return _rewardFromResponse(payload);
  }

  /// يطلب من الخادم تسجيل يوم اليوم في سلسلة الأيام المتتالية.
  ///
  /// اليوم يُحسب بساعة الخادم لا بساعة الجهاز: كان بالإمكان تقديم ساعة
  /// الهاتف لتسجيل أيام متتالية في جلسة واحدة.
  Future<RewardResult> checkStreak(StudentProfile profile) async {
    final payload = await _postProgress('streak', const <String, dynamic>{});
    return _rewardFromResponse(payload);
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

    final identities = await _teacherIdentities(profile);

    final response = await client
        .from('lesson_configs')
        .select('id,data')
        .limit(500)
        .timeout(_requestTimeout);
    final matchingLessons = response
        .whereType<Map>()
        .map(
          (row) =>
              parseLessonContent(row, baseUrl: baseUrl, storageClient: client),
        )
        .where((lesson) => _ownerAllowed(lesson.ownerId ?? '', identities))
        .toList();

    final paths = academicPaths(
      hierarchyValue: hierarchyValue,
      hierarchyUnavailable: hierarchyUnavailable,
      lessons: matchingLessons,
      profile: profile,
      identities: identities,
    );

    return AcademicSelectionData(
      paths: paths,
      lessons: matchingLessons,
      hierarchyUnavailable: hierarchyUnavailable,
      declaredLessons:
          declaredLessonsFromHierarchy(hierarchyValue, profile, identities),
    );
  }

  /// The paths a student may choose between.
  ///
  /// Every grade/subject/chapter/unit the teacher has configured in the
  /// hierarchy tree is shown, whether or not a lesson has been published
  /// under it yet — a branch with no lesson simply shows its own "no lessons
  /// yet" state at the final step (see `_EmptyStageMessage` in
  /// `academic_selection_screen.dart`) instead of being hidden upstream.
  ///
  /// **The tree decides, whenever it can be read.** Paths used to be the
  /// tree *plus* whatever `lesson_configs` still mentioned, and that is why
  /// an academic setting deleted by the teacher stayed on the student's
  /// screen: the lessons filed under it were still there, and each one put
  /// its own grade/subject/term back into the list. Lessons only supply
  /// paths when there is no tree to read — an unreachable `app_kv`, or a
  /// deployment that never wrote one — so those installations keep working
  /// while a deletion now reaches the student on the next load.
  @visibleForTesting
  static List<AcademicPath> academicPaths({
    required Object? hierarchyValue,
    required bool hierarchyUnavailable,
    required List<LessonContent> lessons,
    required StudentProfile profile,
    Set<String> identities = const {},
  }) {
    final fromTree = _pathsFromHierarchy(hierarchyValue, profile, identities);
    final treeIsAuthoritative = !hierarchyUnavailable && hierarchyValue != null;
    if (treeIsAuthoritative) return _uniquePaths(fromTree);
    return _uniquePaths(<AcademicPath>[
      ...fromTree,
      ...lessons.where(_hasCompleteAcademicPath).map(
            (lesson) => AcademicPath(
              grade: lesson.grade,
              subject: lesson.subject,
              term: lesson.term,
              unit: lesson.unit,
            ),
          ),
    ]);
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
          (row) =>
              parseLessonContent(row, baseUrl: baseUrl, storageClient: client),
        )
        .where(
          (lesson) => _matchesStudentPath(
            lesson,
            profile,
            academicContext: academicContext,
          ),
        )
        .toList();

    return preferredLessonsForStudent(
      lessons,
      profile,
      // The lesson the student actually chose wins over every rule below.
      // Without this, a unit collapsed to whichever lesson had the newest
      // createdAt — so a teacher who edited the video on the chosen
      // lesson saw nothing change on the student's card, because the card
      // was never showing that lesson in the first place.
      pinnedLessonId: academicContext?.lessonId,
      // A lesson that lives only in the settings tree has a placeholder id
      // that matches no row, so its name is the only handle on it.
      pinnedLessonName: academicContext?.lesson,
    );
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
          (row) =>
              parseLessonContent(row, baseUrl: baseUrl, storageClient: client),
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
        .where((lesson) => _matchesExactTutorPath(lesson, academicContext))
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
    final selected =
        teacherSelection ??
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
          title: _text(map['title']).isEmpty
              ? tr('svc.defaultGame')
              : _text(map['title']),
          subtitle: _text(map['subtitle']).isEmpty
              ? tr('svc.defaultGameSub')
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
    final deletedIds = _asList(
      rows[1]?['value'],
    ).map(_text).where((id) => id.isNotEmpty).toSet();
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
          title: _text(data['title']).isEmpty
              ? tr('svc.defaultCinemaVideo')
              : _text(data['title']),
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
        'id': _text(rowMap['id']).isEmpty
            ? _text(data['id'])
            : _text(rowMap['id']),
        'updatedAt': _text(rowMap['updated_at'] ?? data['updatedAt']),
      });
    }

    final quizMetadata = await Future.wait([
      _fetchLegacyQuizQuestions(),
      _fetchDeletedQuizIds(),
    ]);
    return StudentAssessmentRules.selectAvailableQuizzes(
      createdQuizzes: createdQuizzes,
      legacyQuestions: quizMetadata[0] as List<Map<String, dynamic>>,
      deletedQuizIds: quizMetadata[1] as Set<String>,
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
    return response
        .whereType<Map>()
        .map((row) {
          final rowMap = _asMap(row);
          final data = _asMap(rowMap['data']);
          return <String, dynamic>{
            ...data,
            'id': _text(rowMap['id']).isEmpty
                ? _text(data['id'])
                : _text(rowMap['id']),
          };
        })
        .where((result) => _text(result['studentId']) == profile.id)
        .toList();
  }

  /// يرسل نتيجة الاختبار إلى الخادم ليحفظها.
  ///
  /// `studentId` و`studentName` لم يعودا يُرسَلان: الخادم يكتبهما من
  /// الجلسة. وبغير ذلك كان بإمكان الطالب تسجيل نتيجة باسم زميله. وفحص
  /// «سبق التسليم» لاختبار المعلم صار هناك أيضاً، فلا يتخطّاه عميل معدَّل.
  Future<Map<String, dynamic>> saveQuizResult({
    required StudentProfile profile,
    required Map<String, dynamic> result,
  }) async {
    final id = _text(result['id']);
    if (id.isEmpty) {
      throw ArgumentError(tr('svc.noResultId'));
    }
    final payload = await _postProgress('quiz-result', {
      'result': <String, dynamic>{
        ...result,
        'id': id,
        'quizType': StudentAssessmentRules.quizTypeValue(result['quizType']),
        'lesson': _text(result['lesson']),
      },
    });
    return _asMap(payload['result']);
  }

  Future<void> saveAppearance({
    required StudentProfile profile,
    required Map<String, dynamic> appearance,
  }) async {
    await _postProgress('appearance', {'appearance': appearance});
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
    await _postProgress('interaction', {
      'type': 'virtual_teacher',
      'question': question,
      'answer': answer,
    });
  }

  /// حقول النطاق (المعلم والصف والمادة…) لم تعد تُرسَل: الخادم يأخذها من
  /// سجلّ الطالب، فلا يمكن دسّ تفاعل في صفّ معلم آخر.
  Future<void> saveProblemSolverInteraction({
    required StudentProfile profile,
    required String lessonId,
    required String question,
  }) async {
    await _postProgress('interaction', {
      'type': 'problem_solver',
      'lessonId': lessonId,
      'question': question,
    });
  }

  Future<List<Map<String, dynamic>>> _fetchLegacyQuizQuestions() async {
    try {
      final row = await client
          .from('app_kv')
          .select('value')
          .eq('key', 'smartEdu_quizQuestions')
          .maybeSingle()
          .timeout(_requestTimeout);
      return _asList(
        row?['value'],
      ).map(_asMap).where((item) => item.isNotEmpty).toList();
    } catch (_) {
      // The modern quiz table remains usable when older installations do not
      // expose the historical app_kv key to the student role.
      return const [];
    }
  }

  /// The web dashboard stores deleted quiz IDs separately so stale copies on
  /// another device cannot be reintroduced during sync. Apply the same shared
  /// tombstones in Flutter before presenting the student assessment list.
  Future<Set<String>> _fetchDeletedQuizIds() async {
    try {
      final row = await client
          .from('app_kv')
          .select('value')
          .eq('key', 'smartEdu_deletedQuizzes')
          .maybeSingle()
          .timeout(_requestTimeout);
      return _asList(
        row?['value'],
      ).map(_text).where((id) => id.isNotEmpty).toSet();
    } catch (_) {
      // A missing historical key must not block visible active assessments.
      return const <String>{};
    }
  }

  /// Everything the student's teacher is known by: the id their record
  /// carries, and the id, username and name on the teacher's own row.
  ///
  /// One teacher is written down in more than one way across this system —
  /// a record may carry `teacher_1699…`, the username, or the display name,
  /// depending on which screen created it. Matching on the student's stored
  /// value alone therefore hid a teacher's own lessons from their own
  /// student whenever the two records disagreed about which of those to
  /// use. Resolving the teacher's row once and accepting any of its names
  /// removes that whole class of failure without widening who can be seen:
  /// only this student's teacher is ever resolved.
  Future<Set<String>> _teacherIdentities(StudentProfile profile) {
    final stored = _normalize(profile.teacherId);
    if (stored.isEmpty) return Future.value(const <String>{});
    return _identities ??= () async {
      final identities = <String>{stored};
      try {
        final rows = await client
            .from('teachers')
            .select('id,data')
            .limit(500)
            .timeout(_requestTimeout);
        for (final row in rows.whereType<Map>()) {
          final data = _asMap(row['data']);
          final names = <String>{
            _normalize(row['id']),
            _normalize(data['id']),
            _normalize(data['username']),
            _normalize(data['name']),
            _normalize(data['fullName']),
          }..removeWhere((name) => name.isEmpty);
          if (names.contains(stored)) identities.addAll(names);
        }
      } catch (_) {
        // The teachers table is unreadable on this deployment: fall back to
        // the single value the student's record carries.
      }
      return identities;
    }();
  }

  Future<Set<String>>? _identities;

  static bool _ownerAllowed(String ownerId, Set<String> identities) {
    final owner = _normalize(ownerId);
    if (owner.isEmpty || owner == 'admin' || owner == 'supervisor') return true;
    return identities.contains(owner);
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
    final subject = academicContext?.subject ?? profile.subject;
    final term = academicContext?.term ?? profile.term;
    final unit = academicContext?.unit ?? profile.unit;
    return _matchesOwner(lesson, profile) &&
        _matches(lesson.grade, grade) &&
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
    final subject = academicContext?.subject ?? profile.subject;
    final term = academicContext?.term ?? profile.term;
    final unit = academicContext?.unit ?? profile.unit;
    // The manager now tags every new cinema video with the lesson it belongs
    // to, so the sixth level is filtered like the other five. It stays
    // permissive on an empty value: videos published before the lesson level
    // existed carry none, and those belong to the whole unit rather than to
    // no-one.
    final lesson = academicContext?.lesson;
    return _matches(_text(video['grade']), grade) &&
        _matches(_text(video['subject']), subject) &&
        _matches(_text(video['term']), term) &&
        _matches(_text(video['unit']), unit) &&
        _matches(_text(video['lesson']), lesson);
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
    final configured =
        lessons
            .where((lesson) => _experienceUrl(lesson, type).trim().isNotEmpty)
            .toList()
          ..sort((a, b) {
            final timestamp = b.createdAt.compareTo(a.createdAt);
            return timestamp != 0 ? timestamp : b.id.compareTo(a.id);
          });
    return configured.isEmpty ? null : configured.first;
  }

  /// Picks one lesson per academic scope.
  ///
  /// The order of authority is deliberate:
  ///
  /// 1. [pinnedLessonId] — the lesson the student explicitly chose. A
  ///    choice the student made must not be overridden by a heuristic.
  /// 2. The student's own teacher's copy, over a supervisor's template.
  /// 3. The most recently created of whatever is left.
  ///
  /// Step 1 is new, and it is what fixes "the teacher changed the video
  /// and the student still sees the old one". A unit can hold several
  /// lessons; the rule below used to hand back whichever was newest,
  /// which is frequently not the lesson the student is sitting in.
  @visibleForTesting
  static List<LessonContent> preferredLessonsForStudent(
    List<LessonContent> lessons,
    StudentProfile profile, {
    String? pinnedLessonId,
    String? pinnedLessonName,
  }) {
    final pinnedId = _normalize(pinnedLessonId);
    final pinnedName = _normalize(pinnedLessonName);

    // The student named one lesson out of the unit, so no other lesson in
    // that unit is an answer to it. The name is checked alongside the id
    // because a lesson that so far exists only in the settings tree carries
    // a placeholder id that belongs to no `lesson_configs` row — and before
    // this, such a unit quietly fell back to a *different* lesson's videos
    // and text, which is exactly the cross-lesson mixing being ruled out.
    //
    // When nothing matches, an empty list is the honest answer: the chosen
    // lesson has no content yet, and the screen says so.
    if (pinnedId.isNotEmpty || pinnedName.isNotEmpty) {
      final exact = lessons
          .where(
            (lesson) =>
                (pinnedId.isNotEmpty && _normalize(lesson.id) == pinnedId) ||
                (pinnedName.isNotEmpty &&
                    _normalize(lesson.lessonName) == pinnedName),
          )
          .toList();
      if (exact.isNotEmpty) {
        final studentTeacher = _normalize(profile.teacherId);
        final teacherOwned = studentTeacher.isEmpty
            ? const <LessonContent>[]
            : exact
                  .where(
                    (lesson) => _normalize(lesson.ownerId) == studentTeacher,
                  )
                  .toList();
        final pool = teacherOwned.isNotEmpty ? teacherOwned : exact;
        pool.sort((a, b) {
          // The id the student actually chose outranks every heuristic.
          final aPinned = pinnedId.isNotEmpty && _normalize(a.id) == pinnedId;
          final bPinned = pinnedId.isNotEmpty && _normalize(b.id) == pinnedId;
          if (aPinned != bPinned) return aPinned ? -1 : 1;
          final timestamp = b.createdAt.compareTo(a.createdAt);
          return timestamp != 0 ? timestamp : b.id.compareTo(a.id);
        });
        return [pool.first];
      }
      return const [];
    }

    final grouped = <String, List<LessonContent>>{};
    for (final lesson in lessons) {
      final key = [
        lesson.grade,
        lesson.subject,
        lesson.term,
        lesson.unit,
      ].map(_normalize).join('|');
      grouped.putIfAbsent(key, () => []).add(lesson);
    }

    // Nothing is pinned past this point — the branch above owns that case
    // and returns from it — so this is the browse view: one lesson per unit.
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

/// The subjects a grade teaches, straight from its own `subjects` list.
///
/// The tree used to carry a level between the grade and the subject — the
/// one shown as «الترم» — and it is gone: a grade now holds its subjects,
/// each subject its chapters, each chapter its units. A settings blob
/// written before that (`atrams: [{atram, subjects: [...]}]`) is still read,
/// with every atram's subjects flattened into the grade, so a device that
/// updates before the stored tree is migrated still shows a course rather
/// than an empty screen.
List<Map<String, dynamic>> _subjectsOfGrade(Map<String, dynamic> config) {
  final subjects = config['subjects'];
  if (subjects is List) return subjects.map(_asMap).toList();

  final legacy = config['atrams'];
  if (legacy is! List) return const [];
  final flattened = <Map<String, dynamic>>[];
  for (final rawAtram in legacy) {
    final nested = _asMap(rawAtram)['subjects'];
    if (nested is List) flattened.addAll(nested.map(_asMap));
  }
  return flattened;
}

List<AcademicPath> _pathsFromHierarchy(
  Object? value,
  StudentProfile profile, [
  Set<String> identities = const {},
]) {
  if (value is! List) return const [];

  final paths = <AcademicPath>[];
  for (final rawConfig in value) {
    final config = _asMap(rawConfig);
    if (!_matchesConfigOwner(config, profile, identities)) continue;

    final grade = _value(config, ['grade', 'class', 'schoolGrade']);
    if (grade.isEmpty) continue;

    for (final subject in _subjectsOfGrade(config)) {
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
              subject: subjectName,
              term: termName,
              unit: unit,
            ),
          );
        }
      }
    }
  }
  return paths;
}

/// The lesson names the teacher typed into the academic settings tree.
///
/// Stored as `term.lessons`, a map keyed by unit name rather than nested
/// inside `units` — the shape the dashboard writes, chosen there so that
/// settings saved before the lesson field existed stay readable without a
/// migration. A term with no map, or a unit with no entry, simply yields
/// nothing here.
@visibleForTesting
List<DeclaredLesson> declaredLessonsFromHierarchy(
  Object? value,
  StudentProfile profile, [
  Set<String> identities = const {},
]) {
  if (value is! List) return const [];

  final declared = <DeclaredLesson>[];
  final seen = <String>{};

  for (final rawConfig in value) {
    final config = _asMap(rawConfig);
    if (!_matchesConfigOwner(config, profile, identities)) continue;

    final grade = _value(config, ['grade', 'class', 'schoolGrade']);
    if (grade.isEmpty) continue;

    for (final subject in _subjectsOfGrade(config)) {
      final subjectName = _value(subject, ['subject', 'course']);
      final terms = subject['terms'];
      if (subjectName.isEmpty || terms is! List) continue;

      for (final rawTerm in terms) {
        final term = _asMap(rawTerm);
        final termName = _value(term, ['term', 'chapter', 'name']);
        final lessonsByUnit = term['lessons'];
        if (termName.isEmpty || lessonsByUnit is! Map) continue;

        for (final entry in lessonsByUnit.entries) {
          final unit = _text(entry.key);
          final names = entry.value;
          if (unit.isEmpty || names is! List) continue;

          for (final rawName in names) {
            final name = _text(rawName);
            if (name.isEmpty) continue;
            final path = AcademicPath(
              grade: grade,
              subject: subjectName,
              term: termName,
              unit: unit,
            );
            final lesson = DeclaredLesson(path: path, name: name);
            if (!seen.add(lesson.placeholderId)) continue;
            declared.add(lesson);
          }
        }
      }
    }
  }
  return declared;
}

List<AcademicPath> _uniquePaths(Iterable<AcademicPath> paths) {
  final unique = <AcademicPath>[];
  final seen = <String>{};
  for (final path in paths) {
    if (!_hasPathValues(path)) continue;
    final key = [
      path.grade,
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
      subject: lesson.subject,
      term: lesson.term,
      unit: lesson.unit,
    ),
  );
}

bool _hasPathValues(AcademicPath path) {
  return [
    path.grade,
    path.subject,
    path.term,
    path.unit,
  ].every((value) => value.trim().isNotEmpty);
}


bool _matchesConfigOwner(
  Map<String, dynamic> config,
  StudentProfile profile, [
  Set<String> identities = const {},
]) {
  final owner = _normalize(
    config['teacherId'] ?? config['teacher_id'] ?? config['createdBy'],
  );
  if (owner.isEmpty || owner == 'admin' || owner == 'supervisor') return true;
  final teacher = _normalize(profile.teacherId);
  if (teacher.isNotEmpty && owner == teacher) return true;
  // The same teacher, written down under another of their names.
  return identities.contains(owner);
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
  final lessonRecordId = _text(row['id']).isEmpty
      ? _value(data, ['lesson_id', 'lessonId', 'id'])
      : _text(row['id']);
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
          id: _text(item['id']).isEmpty
              ? '$lessonRecordId:video:$index'
              : _text(item['id']),
          url: url,
          sourceType: _videoType(item['sourceType'], url),
          title: _text(item['title']).isEmpty
              ? trf('svc.lessonVideoN', {'n': index + 1})
              : _text(item['title']),
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
        id: '$lessonRecordId:legacy-video',
        url: legacyUrl,
        sourceType: _videoType(data['explanationVideoType'], legacyUrl),
        title: tr('svc.lessonVideo'),
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
    subject: _text(data['subject']),
    term: _text(data['term']),
    unit: _text(data['unit']),
    lessonName: _value(data, [
      'lesson',
      'lessonName',
      'lessonTitle',
      'currentLesson',
      'name',
    ]),
    createdAt: _text(data['updatedAt'] ?? data['createdAt']),
    ownerId: _nullableText(
      data['teacherId'] ?? data['teacher_id'] ?? data['createdBy'],
    ),
    lessonText: _nullableText(data['lessonContent']),
    avatarInteractionUrl: _nullableText(data['avatarInteractionUrl']),
    liveMeetingUrl: _nullableText(data['liveMeetingUrl']),
    videos: videos,
    games: games,
  );
}

List<HtmlGame> _parseGames(Map<String, dynamic> data, {String baseUrl = ''}) {
  final games = <HtmlGame>[];
  final rawGames =
      data['games'] ?? data['html5Games'] ?? data['entertainmentGames'];
  if (rawGames is List) {
    for (var index = 0; index < rawGames.length; index++) {
      final item = rawGames[index];
      final map = item is String
          ? <String, dynamic>{'url': item}
          : _asMap(item);
      final url = _resolveUrl(_text(map['url'] ?? map['gameUrl']), baseUrl);
      if (!_isSafeUrl(url)) continue;
      games.add(
        HtmlGame(
          id: _text(map['id']).isEmpty ? 'game-$index' : _text(map['id']),
          url: url,
          title: _text(map['title']).isEmpty
              ? trf('svc.gameN', {'n': index + 1})
              : _text(map['title']),
          subtitle: _text(map['subtitle']).isEmpty
              ? tr('svc.html5Game')
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
        title: tr('svc.lessonGame'),
        subtitle: tr('svc.lessonGameSub'),
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
  final entries = [
    (
      id: 'd4a3629101574bc39bd8f9d1888ca58e',
      title: tr('svc.adventure'),
      subtitle: tr('svc.adventureSub'),
      requiredLevel: 0,
    ),
    (
      id: '172e0bd0c40442dbae3d4adb42a98433',
      title: tr('svc.knowledge'),
      subtitle: tr('svc.knowledgeSub'),
      requiredLevel: 2,
    ),
  ];
  return entries.map((entry) {
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
  }).toList();
}

VideoSourceType _videoType(Object? value, String url) {
  final normalizedUrl = url.toLowerCase();
  final isDirectVideo =
      RegExp(r'\.(mp4|m4v|mov|webm|m3u8)(?:$|[?#])').hasMatch(normalizedUrl) ||
      normalizedUrl.contains('/storage/v1/object/public/');
  if (value?.toString().toLowerCase() == 'mp4' || isDirectVideo) {
    return VideoSourceType.mp4;
  }
  return VideoSourceType.embed;
}

String _normalize(Object? value) =>
    value?.toString().trim().toLowerCase() ?? '';

String _text(Object? value) => value?.toString().trim() ?? '';

int _number(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

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
  if (raw.isEmpty ||
      raw.startsWith('javascript:') ||
      raw.startsWith('data:') ||
      raw.startsWith('blob:')) {
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
      if (!RegExp(
        r'\.(mp4|m4v|mov|webm|m3u8)$',
        caseSensitive: false,
      ).hasMatch(candidate)) {
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
