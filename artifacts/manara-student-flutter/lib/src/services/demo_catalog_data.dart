/// منهجُ الحساب الرسمي لوضع الزائر — البياناتُ واختيارُها، بلا Flutter.
///
/// ‏يستعمله التطبيقُ ليقرأ النسخةَ المدمجة (`assets/demo/`)، وتستعمله أداةُ
/// ‏البناء `tool/snapshot_demo_catalog.dart` لتكتبها: الاختيارُ نفسُه في
/// ‏الموضعين، فلا يفترق ما يُكتب عمّا يُقرأ.
library;

import 'tracing_scope.dart';

class DemoCatalogData {
  const DemoCatalogData({
    required this.track,
    required this.grade,
    required this.owner,
    required this.hierarchy,
    required this.lessonRows,
    this.quizRows = const [],
    this.legacyQuestions = const [],
    this.deletedQuizIds = const [],
    this.videos = const [],
    this.deletedVideoIds = const [],
  });

  /// `kg` أو `grade4`.
  final String track;

  /// اسمُ الصفّ كما في الحساب الرسمي.
  final String grade;

  /// معرّفُ المعلّم الذي يُعرض منهجُه.
  final String owner;

  /// إعداداتُ هذا الصفّ من `smartEdu_hierarchicalConfigs`.
  final List<Object?> hierarchy;
  final List<Map<String, dynamic>> lessonRows;
  final List<Map<String, dynamic>> quizRows;
  final List<Map<String, dynamic>> legacyQuestions;
  final List<String> deletedQuizIds;

  /// رفُّ «سينما منارة» القديم (`smartEdu_videos`) — ما يقرؤه الحسابُ الرسمي
  /// حين لا تصله واجهةُ السينما.
  final List<Map<String, dynamic>> videos;
  final List<String> deletedVideoIds;

  Map<String, dynamic> toJson() => {
        'track': track,
        'grade': grade,
        'owner': owner,
        'hierarchy': hierarchy,
        'lessonRows': lessonRows,
        'quizRows': quizRows,
        'legacyQuestions': legacyQuestions,
        'deletedQuizIds': deletedQuizIds,
        'videos': videos,
        'deletedVideoIds': deletedVideoIds,
      };

  static DemoCatalogData? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final grade = '${raw['grade'] ?? ''}'.trim();
    final owner = '${raw['owner'] ?? ''}'.trim();
    final hierarchy = raw['hierarchy'];
    if (grade.isEmpty || owner.isEmpty || hierarchy is! List) return null;
    return DemoCatalogData(
      track: '${raw['track'] ?? ''}',
      grade: grade,
      owner: owner,
      hierarchy: hierarchy,
      lessonRows: _maps(raw['lessonRows']),
      quizRows: _maps(raw['quizRows']),
      legacyQuestions: _maps(raw['legacyQuestions']),
      deletedQuizIds: [for (final id in _list(raw['deletedQuizIds'])) '$id'],
      videos: _maps(raw['videos']),
      deletedVideoIds: [for (final id in _list(raw['deletedVideoIds'])) '$id'],
    );
  }
}

abstract final class DemoCatalogBuilder {
  /// يختار من البيانات الخامّ منهجَ صفّ [track] كما يراه طالبُه الرسمي.
  static DemoCatalogData? build({
    required String track,
    required Object? hierarchy,
    Object? lessonRows,
    Object? quizRows,
    Object? legacyQuestions,
    Object? deletedQuizIds,
    Object? videos,
    Object? deletedVideoIds,
  }) {
    final configs = [for (final c in _list(hierarchy)) if (c is Map) Map<String, dynamic>.from(c)];
    final rows = _maps(lessonRows);

    // ‏المعلّمُ صاحبُ أكبر منهجٍ لهذا الصف: وحداتُ شجرته ودروسُه المنشورة.
    final score = <String, int>{};
    final gradeOf = <String, String>{};
    for (final config in configs) {
      final grade = _text(config['grade'] ?? config['class'] ?? config['schoolGrade']);
      final owner = _owner(config);
      if (!matchesTrack(grade, track) || owner.isEmpty || _isStaff(owner)) continue;
      gradeOf.putIfAbsent(_norm(owner), () => grade);
      score[_norm(owner)] = (score[_norm(owner)] ?? 0) + 1 + _unitCount(config);
    }
    for (final row in rows) {
      final data = _map(row['data']);
      final owner = _norm(_owner(data));
      if (score.containsKey(owner) && matchesTrack(_text(data['grade']), track)) score[owner] = score[owner]! + 1;
    }
    if (score.isEmpty) return null;
    final best = score.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    final owner = _owner(configs.firstWhere((c) => _norm(_owner(c)) == best));
    final grade = gradeOf[best]!;

    bool mine(Map<String, dynamic> data) {
      final o = _norm(_owner(data));
      final g = _text(data['grade'] ?? data['gradeId']);
      return (o.isEmpty || o == best || _isStaff(o)) && (g.isEmpty || _norm(g) == _norm(grade));
    }

    return DemoCatalogData(
      track: track,
      grade: grade,
      owner: owner,
      hierarchy: [for (final c in configs) if (_norm(_owner(c)) == best) c],
      lessonRows: [for (final r in rows) if (mine(_map(r['data']))) r],
      quizRows: [for (final r in _maps(quizRows)) if (mine(_map(r['data']))) r],
      legacyQuestions: [for (final q in _maps(legacyQuestions)) if (mine(q)) q],
      deletedQuizIds: [for (final id in _list(deletedQuizIds)) if (_text(id).isNotEmpty) _text(id)],
      videos: [for (final v in _maps(videos)) if (mine(v)) v],
      deletedVideoIds: [for (final id in _list(deletedVideoIds)) if (_text(id).isNotEmpty) _text(id)],
    );
  }

  /// صفُّ الروضة الرسمي، أو أيُّ صفٍّ رابع.
  static bool matchesTrack(String grade, String track) {
    if (grade.trim().isEmpty) return false;
    if (track == 'grade4') return RegExp('الرابع|grade ?4|fourth').hasMatch(_norm(grade));
    return isKindergartenGrade(grade);
  }

  static int _unitCount(Map<String, dynamic> config) {
    var n = 0;
    final subjects = config['subjects'] ?? config['atrams'];
    for (final s in _list(subjects)) {
      final nested = _map(s)['subjects'];
      for (final subject in nested is List ? nested : [s]) {
        for (final term in _list(_map(subject)['terms'])) {
          n += _list(_map(term)['units']).length;
        }
      }
    }
    return n;
  }

  static String _owner(Map<String, dynamic> data) =>
      _text(data['teacherId'] ?? data['teacher_id'] ?? data['createdBy']);
  static bool _isStaff(String owner) => const {'admin', 'supervisor'}.contains(_norm(owner));
  static String _norm(Object? v) => _text(v).toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String _text(Object? v) => v == null ? '' : '$v'.trim();
List<Object?> _list(Object? v) => v is List ? v : const [];
Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _maps(Object? v) => [for (final e in _list(v)) if (e is Map) Map<String, dynamic>.from(e)];
