import '../models/app_models.dart';

/// عقدة البيانات التي تتشاركها شاشات الأدوار.
/// التنفيذ المحلي لا ينشئ بيانات افتراضية؛ مصدر البيانات المحلي هو الكاش
/// الذي تديره AppState، بينما يتولى SupabaseRepository القراءة البعيدة عند
/// توفر الاتصال.
abstract class ManaraRepository {
  bool get videoStorageConfigured;
  Future<String?> uploadVideo({
    required String ownerId,
    required String fileName,
    required List<int> bytes,
    required String contentType,
  });
  Future<String?> resolveVideoUrl(String value);
  Future<void> deleteVideoAsset(String value);
  Future<List<VideoLesson>> videosForStudent(String studentId);
  Future<void> saveProgress(
    String studentId,
    int xp,
    int gems, {
    List<String> completedLessonIds = const [],
    List<String> unlockedAvatars = const [],
  });
  Future<Map<String, dynamic>?> loadProgress(String studentId);
  Future<void> syncCollections(Map<String, List<Map<String, dynamic>>> collections);
  Future<Map<String, List<Map<String, dynamic>>>> loadCollections();
  Future<void> syncKeyValue(String key, dynamic value);
  Future<dynamic> loadKeyValue(String key);
  Future<void> deleteRecord(String table, String id);
}

class LocalManaraRepository implements ManaraRepository {
  const LocalManaraRepository();

  @override
  bool get videoStorageConfigured => false;

  @override
  Future<String?> uploadVideo({
    required String ownerId,
    required String fileName,
    required List<int> bytes,
    required String contentType,
  }) async =>
      null;

  @override
  Future<String?> resolveVideoUrl(String value) async =>
      value.trim().isEmpty ? null : value.trim();

  @override
  Future<void> deleteVideoAsset(String value) async {}

  @override
  Future<List<VideoLesson>> videosForStudent(String studentId) async =>
      const [];

  @override
  Future<void> saveProgress(
    String studentId,
    int xp,
    int gems, {
    List<String> completedLessonIds = const [],
    List<String> unlockedAvatars = const [],
  }) async {}

  @override
  Future<Map<String, dynamic>?> loadProgress(String studentId) async => null;

  @override
  Future<void> syncCollections(Map<String, List<Map<String, dynamic>>> collections) async {}

  @override
  Future<Map<String, List<Map<String, dynamic>>>> loadCollections() async => {};

  @override
  Future<void> syncKeyValue(String key, dynamic value) async {}

  @override
  Future<dynamic> loadKeyValue(String key) async => null;

  @override
  Future<void> deleteRecord(String table, String id) async {}
}