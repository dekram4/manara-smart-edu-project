import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/academic_context.dart';
import '../models/student_content.dart';
import '../models/student_profile.dart';

class StudentContentService {
  StudentContentService(
    this.client, {
    this.baseUrl = '',
  });

  final SupabaseClient client;
  final String baseUrl;

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
        .limit(500);
    final lessons = response
        .whereType<Map>()
        .map((row) => parseLessonContent(row, baseUrl: baseUrl))
        .where((lesson) => _matchesOwner(lesson, profile))
        .toList();

    final hierarchyPaths = <AcademicPath>[
      ..._pathsFromHierarchy(hierarchyValue, profile),
      ...lessons
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
          (path) => lessons.any((lesson) => _lessonMatchesPath(lesson, path)),
        )
        .toList();

    return AcademicSelectionData(
      paths: paths,
      lessons: lessons,
      hierarchyUnavailable: hierarchyUnavailable,
    );
  }

  Future<List<LessonContent>> fetchLessons() async {
    final response = await client
        .from('lesson_configs')
        .select('id,data')
        .limit(500);

    // The student lesson explanation is a catalogue of the content published
    // through content management. It must not be narrowed to the currently
    // selected academic path; teachers and supervisors may publish lessons
    // outside that selection and the student should still see them.
    final lessons = response
        .whereType<Map>()
        .map((row) => parseLessonContent(row, baseUrl: baseUrl))
        .toList();

    lessons.sort((a, b) => a.id.compareTo(b.id));
    return lessons;
  }

  Future<List<LessonVideo>> fetchCinemaVideos() async {
    final response = await client
        .from('lesson_configs')
        .select('id,data')
        .limit(500);

    // Cinema follows the same visibility rule as lesson explanation: every
    // managed lesson can contribute its safe videos, regardless of the
    // student's current academic selection or teacher assignment.
    final lessons = response
        .whereType<Map>()
        .map((row) => parseLessonContent(row, baseUrl: baseUrl))
        .toList();

    final videos = <LessonVideo>[];
    final seen = <String>{};
    for (final lesson in lessons) {
      for (final video in lesson.videos) {
        final key = '${video.id}|${video.url}';
        if (!seen.add(key)) continue;
        videos.add(
          LessonVideo(
            id: '${lesson.id}:${video.id}',
            url: video.url,
            sourceType: video.sourceType,
            title: lesson.lessonName.trim().isEmpty
                ? video.title
                : '${lesson.lessonName} • ${video.title}',
            description: video.description,
          ),
        );
      }
    }
    return videos;
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

  Future<List<Map<String, dynamic>>> loadTutorHistory(String studentId) async {
    final response = await client
        .from('interactions')
        .select('id,data')
        .eq('data->>studentId', studentId)
        .order('updated_at', ascending: true)
        .limit(60);
    return response.whereType<Map>().map(_asMap).toList();
  }

  Future<void> saveTutorInteraction({
    required String studentId,
    required String question,
    required String answer,
  }) async {
    final id = '${studentId}_${DateTime.now().microsecondsSinceEpoch}';
    await client.from('interactions').upsert({
      'id': id,
      'data': {
        'studentId': studentId,
        'type': 'virtual_teacher',
        'question': question,
        'answer': answer,
        'createdAt': DateTime.now().toIso8601String(),
      },
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  bool _matchesOwner(LessonContent lesson, StudentProfile profile) {
    final owner = _normalize(lesson.ownerId);
    final teacher = _normalize(profile.teacherId);
    if (owner.isEmpty || owner == 'admin' || owner == 'supervisor') return true;
    if (teacher.isEmpty) return false;
    return owner == teacher;
  }

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
}) {
  final data = _asMap(row['data']);
  final videos = <LessonVideo>[];
  final rawVideos = data['explanationVideos'];

  if (rawVideos is List) {
    for (var index = 0; index < rawVideos.length; index++) {
      final item = _asMap(rawVideos[index]);
      final url = _resolveUrl(_text(item['url']), baseUrl);
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

  final legacyUrl = _resolveUrl(_text(data['explanationVideoUrl']), baseUrl);
  if (_isSafeUrl(legacyUrl) && !videos.any((video) => video.url == legacyUrl)) {
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
    ownerId: _nullableText(data['teacherId'] ?? data['teacher_id'] ?? data['createdBy']),
    lessonText: _nullableText(data['lessonContent']),
    avatarInteractionUrl: _nullableText(data['avatarInteractionUrl']),
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
      ),
    );
  }
  return games;
}

VideoSourceType _videoType(Object? value, String url) {
  if (value?.toString().toLowerCase() == 'mp4' || url.toLowerCase().contains('.mp4')) {
    return VideoSourceType.mp4;
  }
  return VideoSourceType.embed;
}

String _normalize(Object? value) => value?.toString().trim().toLowerCase() ?? '';

String _text(Object? value) => value?.toString().trim() ?? '';

bool _isSafeUrl(String value) {
  final raw = value.trim().toLowerCase();
  if (raw.isEmpty || raw.startsWith('javascript:') || raw.startsWith('data:') || raw.startsWith('blob:')) {
    return false;
  }
  final uri = Uri.tryParse(value.trim());
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

String _resolveUrl(String value, String baseUrl) {
  final raw = value.trim();
  if (!raw.startsWith('/') || baseUrl.trim().isEmpty) return raw;
  final base = Uri.tryParse(baseUrl.trim());
  return base == null ? raw : base.resolve(raw).toString();
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