import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import '../models/app_models.dart';
import 'data_repository.dart';

/// مستودع البيانات الأصلي لـ Flutter.
///
/// يتم تمرير رابط Supabase والمفتاح عبر:
/// `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
/// ولا يتم وضع أي مفاتيح داخل الكود أو داخل المستودع.
class SupabaseManaraRepository implements ManaraRepository {
  SupabaseManaraRepository(this.client);

  final SupabaseClient client;
  static const videoBucket =
      String.fromEnvironment('SUPABASE_VIDEO_BUCKET', defaultValue: '');

  @override
  bool get videoStorageConfigured =>
      videoBucket.trim().isNotEmpty && client.auth.currentSession != null;

  @override
  Future<String?> uploadVideo({
    required String ownerId,
    required String fileName,
    required List<int> bytes,
    required String contentType,
  }) async {
    if (!videoStorageConfigured || bytes.isEmpty) return null;
    final safeOwner = _safePathSegment(ownerId);
    final safeName = _safePathSegment(fileName);
    final path =
        'videos/$safeOwner/${DateTime.now().millisecondsSinceEpoch}-$safeName';
    await client.storage.from(videoBucket).uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );
    return path;
  }

  @override
  Future<String?> resolveVideoUrl(String value) async {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https')) {
      return raw;
    }
    if (!videoStorageConfigured) return null;
    final path = raw.startsWith('storage://') ? raw.substring(10) : raw;
    if (path.trim().isEmpty || path.contains('..')) return null;
    return client.storage.from(videoBucket).createSignedUrl(path, 3600);
  }

  @override
  Future<void> deleteVideoAsset(String value) async {
    if (!videoStorageConfigured) return;
    final raw = value.trim();
    if (raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) return;
    final path = raw.startsWith('storage://') ? raw.substring(10) : raw;
    if (path.isEmpty || path.contains('..')) return;
    await client.storage.from(videoBucket).remove([path]);
  }

  @override
  Future<List<VideoLesson>> videosForStudent(String studentId) async {
    final scope = await _studentScope(studentId);
    if (scope == null) return const [];
    final keyValue = await client
        .from('app_kv')
        .select('value')
        .eq('key', 'videos')
        .maybeSingle();
    final storedVideos = keyValue?['value'];
    if (storedVideos is List) {
      return storedVideos
          .whereType<Map>()
          .map((data) => _videoFromData(Map<String, dynamic>.from(data)))
          .whereType<VideoLesson>()
          .where((video) => _matchesStudentScope({
                'grade': video.grade,
                'subject': video.subject,
                'atram': video.atram,
                'term': video.term,
                'unit': video.unit,
                'teacherId': video.teacherId,
                'createdBy': video.createdBy,
              }, scope))
          .toList();
    }

    // Legacy content records stored their video URL on lesson_configs.
    final rows = await client.from('lesson_configs').select('id,data');
    return rows
        .map<VideoLesson?>((row) {
          final raw = Map<String, dynamic>.from(row);
          final data = raw['data'] is Map
              ? Map<String, dynamic>.from(raw['data'])
              : <String, dynamic>{};
          if (!_matchesStudentScope(data, scope)) return null;
          return _videoFromData({
            ...data,
            'id': data['id'] ?? raw['id'],
            'url': data['url'] ?? data['videoUrl'] ?? data['explanationVideoUrl'],
          });
        })
        .whereType<VideoLesson>()
        .toList();
  }

  VideoLesson? _videoFromData(Map<String, dynamic> data) {
    final url = data['url']?.toString().trim() ??
        data['videoUrl']?.toString().trim() ??
        data['explanationVideoUrl']?.toString().trim() ??
        '';
    if (url.isEmpty) return null;
    return VideoLesson(
      id: (data['id'] ?? 'video-${data['title']}').toString(),
      title: (data['title'] ?? data['lessonTitle'] ?? 'درس تعليمي').toString(),
      subject: (data['subject'] ?? 'عام').toString(),
      emoji: (data['emoji'] ?? '🎬').toString(),
      duration: (data['duration'] ?? '00:00').toString(),
      url: url,
      description: data['description']?.toString() ?? '',
      grade: data['grade']?.toString() ?? '',
      atram: data['atram']?.toString() ?? '',
      term: data['term']?.toString() ?? '',
      unit: data['unit']?.toString() ?? '',
      isNew: data['isNew'] == true,
      teacherId: data['teacherId']?.toString(),
      createdBy: data['createdBy']?.toString() ?? 'admin',
      createdByName: data['createdByName']?.toString() ?? 'المشرف',
    );
  }

  @override
  Future<void> saveProgress(
    String studentId,
    int xp,
    int gems, {
    List<String> completedLessonIds = const [],
    List<String> unlockedAvatars = const [],
  }) async {
    await client.from('app_kv').upsert({
      'key': 'student_progress:$studentId',
      'value': {
        'studentId': studentId,
        'xp': xp,
        'gems': gems,
        'completedLessonIds': completedLessonIds,
        'unlockedAvatars': unlockedAvatars,
      },
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'key');
  }

  @override
  Future<Map<String, dynamic>?> loadProgress(String studentId) async {
    final row = await client
        .from('app_kv')
        .select('value')
        .eq('key', 'student_progress:$studentId')
        .maybeSingle();
    final value = row?['value'];
    return value is Map
        ? Map<String, dynamic>.from(value)
        : null;
  }

  @override
  Future<void> syncKeyValue(String key, dynamic value) async {
    await client.from('app_kv').upsert({
      'key': key,
      'value': value,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'key');
  }

  @override
  Future<dynamic> loadKeyValue(String key) async {
    final row = await client
        .from('app_kv')
        .select('value')
        .eq('key', key)
        .maybeSingle();
    return row?['value'];
  }

  @override
  Future<void> deleteRecord(String table, String id) async {
    await client.from(table).delete().eq('id', id);
  }

  String _safePathSegment(String value) {
    final normalized = value.trim().isEmpty ? 'video' : value.trim();
    return normalized.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  /// Writes the same JSONB row shape used by the legacy React sync layer.
  /// Each map key is a Supabase table name and each item must contain `id`.
  @override
  Future<void> syncCollections(
    Map<String, List<Map<String, dynamic>>> collections,
  ) async {
    for (final entry in collections.entries) {
      final table = entry.key;
      final rows = entry.value;
      final payload = rows
          .map((row) => {
                'id': row['id'].toString(),
                'data': row,
                'updated_at': DateTime.now().toIso8601String(),
              })
          .toList();
      if (payload.isNotEmpty) {
        await client.from(table).upsert(payload, onConflict: 'id');
      }
    }
  }

  @override
  Future<Map<String, List<Map<String, dynamic>>>> loadCollections() async {
    const tables = [
      'students',
      'parents',
      'teachers',
      'lesson_configs',
      'created_quizzes',
      'quiz_results',
      'interactions',
      'private_messages',
      'public_messages',
      'certificates',
    ];
    final result = <String, List<Map<String, dynamic>>>{};
    for (final table in tables) {
      final rows = await client.from(table).select('id,data');
      result[table] = rows.map<Map<String, dynamic>>((row) {
        final raw = Map<String, dynamic>.from(row);
        final data = raw['data'];
        return data is Map
            ? Map<String, dynamic>.from(data)
            : {'id': raw['id'].toString()};
      }).toList();
    }
    return result;
  }

  Future<List<Lesson>> lessonsForStudent(String studentId) async {
    final scope = await _studentScope(studentId);
    if (scope == null) return const [];
    final rows = await client.from('lesson_configs').select('id,data');
    return rows.map<Lesson?>((row) {
      final raw = Map<String, dynamic>.from(row);
      final data = raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'])
          : <String, dynamic>{};
      if (!_matchesStudentScope(data, scope)) return null;
      return Lesson(
        id: (data['id'] ?? raw['id']).toString(),
        title: (data['title'] ?? 'درس').toString(),
        grade: (data['grade'] ?? '').toString(),
        subject: (data['subject'] ?? '').toString(),
        unit: (data['unit'] ?? '').toString(),
        content: (data['lessonContent'] ?? data['content'] ?? '').toString(),
        videoUrl: (data['videoUrl'] ?? data['explanationVideoUrl'])
            ?.toString()
            .trim(),
        atram: data['atram']?.toString() ?? '',
        term: data['term']?.toString() ?? '',
        avatarInteractionUrl: data['avatarInteractionUrl']?.toString() ?? '',
        liveMeetingUrl: data['liveMeetingUrl']?.toString() ?? '',
        teacherId: data['teacherId']?.toString(),
        createdBy: data['createdBy']?.toString() ?? 'admin',
        createdByName: data['createdByName']?.toString() ?? 'المشرف',
      );
    }).whereType<Lesson>().toList();
  }

  Future<_StudentScope?> _studentScope(String studentId) async {
    final rows = await client
        .from('students')
        .select('id,data')
        .eq('id', studentId)
        .limit(1);
    if (rows.isEmpty) return null;
    final raw = Map<String, dynamic>.from(rows.first);
    final data = raw['data'] is Map
        ? Map<String, dynamic>.from(raw['data'])
        : <String, dynamic>{};
    final enrollments = <String>{};
    final owners = <String>{};
    final enrollmentKeys = <String>{};
    final rawEnrollments = data['gradeEnrollments'] ?? data['enrollments'];
    if (rawEnrollments is List) {
      for (final item in rawEnrollments.whereType<Map>()) {
        final directSubject = item['subject']?.toString().trim().toLowerCase();
        if (directSubject != null && directSubject.isNotEmpty) {
          enrollments.add(directSubject);
        }
        _addEnrollmentKey(enrollmentKeys, item);
        final nested = item['enrollments'];
        if (nested is List) {
          for (final enrollment in nested.whereType<Map>()) {
            final subject =
                enrollment['subject']?.toString().trim().toLowerCase();
            if (subject != null && subject.isNotEmpty) enrollments.add(subject);
            _addEnrollmentKey(enrollmentKeys, enrollment);
          }
        }
      }
    }
    final createdBy = data['createdBy']?.toString().trim();
    if (createdBy != null && createdBy.isNotEmpty) owners.add(createdBy);
    for (final key in ['teacherId', 'teacherID', 'assignedTeacherId']) {
      final teacherId = data[key]?.toString().trim();
      if (teacherId != null && teacherId.isNotEmpty) owners.add(teacherId);
    }
    return _StudentScope(
      grade: (data['primaryGrade'] ?? data['grade'] ?? '')
          .toString()
          .trim()
          .toLowerCase(),
      subjects: enrollments,
      enrollmentKeys: enrollmentKeys,
      ownerIds: owners,
    );
  }

  void _addEnrollmentKey(
    Set<String> keys,
    Map<dynamic, dynamic> enrollment,
  ) {
    final values = [
      enrollment['subject'],
      enrollment['atram'],
      enrollment['term'],
      enrollment['unit'],
    ].map((value) => value?.toString().trim().toLowerCase() ?? '').toList();
    if (values.any((value) => value.isNotEmpty)) {
      keys.add(values.join('|'));
    }
  }

  bool _matchesStudentScope(
    Map<String, dynamic> lesson,
    _StudentScope scope,
  ) {
    final subject = (lesson['subject'] ?? '').toString().trim().toLowerCase();
    final grade = (lesson['grade'] ?? '').toString().trim().toLowerCase();
    final subjectVisible =
        subject.isEmpty || scope.subjects.isEmpty || scope.subjects.contains(subject);
    final gradeVisible =
        grade.isEmpty || scope.grade.isEmpty || grade == scope.grade;
    final key = [
      subject,
      (lesson['atram'] ?? '').toString().trim().toLowerCase(),
      (lesson['term'] ?? '').toString().trim().toLowerCase(),
      (lesson['unit'] ?? '').toString().trim().toLowerCase(),
    ].join('|');
    final academicVisible = key == '|||'
        ? true
        : scope.enrollmentKeys.any((enrollment) {
            final values = enrollment.split('|');
            final lessonValues = key.split('|');
            for (var index = 0; index < values.length; index++) {
              if (lessonValues[index].isNotEmpty &&
                  values[index].isNotEmpty &&
                  lessonValues[index] != values[index]) {
                return false;
              }
            }
            return true;
          });
    final rawTeacherId = lesson['teacherId'];
    final hasExplicitTeacher = rawTeacherId != null;
    if (hasExplicitTeacher &&
        rawTeacherId.toString().trim().isEmpty) {
      return false;
    }
    final owner = (hasExplicitTeacher ? rawTeacherId : lesson['createdBy'] ?? '')
        .toString()
        .trim();
    final ownerVisible = owner.isEmpty ||
        owner == 'admin' ||
        scope.ownerIds.contains(owner);
    return subjectVisible && gradeVisible && academicVisible && ownerVisible;
  }
}

class _StudentScope {
  const _StudentScope({
    required this.grade,
    required this.subjects,
    required this.enrollmentKeys,
    required this.ownerIds,
  });

  final String grade;
  final Set<String> subjects;
  final Set<String> enrollmentKeys;
  final Set<String> ownerIds;
}
