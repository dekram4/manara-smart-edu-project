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

  Future<AcademicOptions> fetchAcademicOptions(StudentProfile profile) async {
    final response = await client
        .from('lesson_configs')
        .select('id,data')
        .limit(500);

    var options = AcademicOptions.defaults(profile.academicValues);
    for (final row in response.whereType<Map>()) {
      final data = _asMap(row['data']);
      final values = AcademicOptions(
        grades: [_value(data, ['grade', 'class', 'schoolGrade'])],
        terms: [_value(data, ['term', 'semester', 'atram'])],
        subjects: [_value(data, ['subject', 'course'])],
        units: [_value(data, ['unit', 'chapter'])],
        lessons: [
          _value(
            data,
            ['lesson', 'lessonName', 'lessonTitle', 'currentLesson', 'name'],
          ),
        ],
      );
      options = options.merge(values);
    }
    return options;
  }

  Future<List<LessonContent>> fetchLessons(
    StudentProfile profile, {
    AcademicContext? academicContext,
  }) async {
    final response = await client
        .from('lesson_configs')
        .select('id,data')
        .limit(500);

    final lessons = response
        .whereType<Map>()
        .map((row) => parseLessonContent(row, baseUrl: baseUrl))
        .where(
          (lesson) => _matchesStudent(
            lesson,
            profile,
            academicContext: academicContext,
          ),
        )
        .toList();

    lessons.sort((a, b) => a.id.compareTo(b.id));
    return lessons;
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

  bool _matchesStudent(
    LessonContent lesson,
    StudentProfile profile, {
    AcademicContext? academicContext,
  }) {
    final grade = academicContext?.grade ?? profile.grade;
    final term = academicContext?.term ?? profile.term;
    final subject = academicContext?.subject ?? profile.subject;
    final unit = academicContext?.unit ?? profile.unit;
    return _matchesOwner(lesson, profile) &&
        _matches(lesson.grade, grade) &&
        _matches(lesson.atram, profile.atram) &&
        _matches(lesson.subject, subject) &&
        _matches(lesson.term, term) &&
        _matches(lesson.unit, unit);
  }

  bool _matchesOwner(LessonContent lesson, StudentProfile profile) {
    final owner = _normalize(lesson.ownerId);
    final teacher = _normalize(profile.teacherId);
    if (owner.isEmpty || owner == 'admin' || owner == 'supervisor') return true;
    if (teacher.isEmpty) return true;
    return owner == teacher;
  }

  bool _matches(String lessonValue, String? studentValue) {
    final lesson = _normalize(lessonValue);
    final student = _normalize(studentValue);
    if (student.isEmpty || lesson.isEmpty) return true;
    return lesson == student;
  }
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
    grade: _text(data['grade']),
    atram: _text(data['atram']),
    subject: _text(data['subject']),
    term: _text(data['term']),
    unit: _text(data['unit']),
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