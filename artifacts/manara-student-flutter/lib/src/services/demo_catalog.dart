/// منهجُ الحساب الرسمي نفسُه لوضع الزائر.
///
/// كان الزائرُ يرى منهجاً مكتوباً في التطبيق ([DemoContent]): موادَّ ودروساً
/// بأسماءٍ وأعدادٍ غيرِ ما يراه طالبُ الروضة أو الصف الرابع الحقيقي (لا
/// «القاعدة النورانية» مثلاً). فصار يقرأ الشجرةَ والدروسَ والاختبارات من
/// المصدر الذي يقرأ منه الحسابُ الرسمي — `app_kv` و`lesson_configs`
/// و`created_quizzes`، وكلُّها مقروءةٌ بالمفتاح العام — ويمرّرها في المسار
/// نفسِه الذي يمرّ فيه الحسابُ الرسمي ([StudentContentService]).
///
/// ‏والمعلّمُ الذي يُعرض منهجُه: صاحبُ أكبر شجرةٍ لصفّ الزائر — مدخلُ الروضة
/// الرسمي، أو مدخلُ الصف الرابع.
///
/// ‏ولا يرى الزائرُ خطأَ خادم: تُحفظ آخرُ نسخةٍ على الجهاز فيدخل بها فوراً
/// وتتجدّد في الخلفية، وإن لم تصل نسخةٌ قطّ (أوّلُ دخولٍ بلا إنترنت) بقي
/// المنهجُ المدمج [DemoContent] بديلاً.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/study_games.dart';
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

  Map<String, dynamic> toJson() => {
        'track': track,
        'grade': grade,
        'owner': owner,
        'hierarchy': hierarchy,
        'lessonRows': lessonRows,
        'quizRows': quizRows,
        'legacyQuestions': legacyQuestions,
        'deletedQuizIds': deletedQuizIds,
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
    );
  }
}

abstract final class DemoCatalog {
  /// منهجُ الزائر الحالي، أو `null` فيُعرض [DemoContent].
  static DemoCatalogData? current;

  static const _timeout = Duration(seconds: 8);
  static String _cacheKey(String track) => 'demo.catalog.v1.$track';

  /// يحمّل منهجَ [track]: من النسخة المحفوظة فوراً (وتتجدّد في الخلفية)،
  /// وإلا من الخادم. وإن تعذّر الاثنان بقي `null`.
  static Future<DemoCatalogData?> load(SupabaseClient client, String track) async {
    final cached = await _cached(track);
    if (cached != null) {
      current = cached;
      unawaited(_refresh(client, track).then<void>((_) {}, onError: (Object _) {}));
      return cached;
    }
    try {
      return current = await _refresh(client, track);
    } catch (_) {
      return current = null;
    }
  }

  static void clear() => current = null;

  static Future<DemoCatalogData?> _refresh(SupabaseClient client, String track) async {
    final results = await Future.wait<Object?>([
      _kv(client, 'smartEdu_hierarchicalConfigs'),
      client.from('lesson_configs').select('id,data').limit(500),
      client.from('created_quizzes').select('id,data,updated_at').limit(300),
      _kv(client, 'smartEdu_quizQuestions').catchError((Object _) => null),
      _kv(client, 'smartEdu_deletedQuizzes').catchError((Object _) => null),
    ]).timeout(_timeout);
    final data = build(
      track: track,
      hierarchy: results[0],
      lessonRows: results[1],
      quizRows: results[2],
      legacyQuestions: results[3],
      deletedQuizIds: results[4],
    );
    if (data == null) return null;
    // ‏جلسةُ الزائر ما زالت على المسار نفسه: تُعرض النسخةُ الجديدة من الطلب التالي.
    if (current == null || current!.track == track) current = data;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(track), jsonEncode(data.toJson()));
    } catch (_) {
      // ‏بلا نسخةٍ محفوظة: يُطلب من الخادم في الدخول القادم.
    }
    return data;
  }

  static Future<Object?> _kv(SupabaseClient client, String key) async =>
      (await client.from('app_kv').select('value').eq('key', key).maybeSingle())?['value'];

  static Future<DemoCatalogData?> _cached(String track) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(track));
      final data = raw == null ? null : DemoCatalogData.fromJson(jsonDecode(raw));
      return data != null && data.track == track ? data : null;
    } catch (_) {
      return null;
    }
  }

  /// يختار من البيانات الخامّ منهجَ صفّ [track] كما يراه طالبُه الرسمي.
  @visibleForTesting
  static DemoCatalogData? build({
    required String track,
    required Object? hierarchy,
    Object? lessonRows,
    Object? quizRows,
    Object? legacyQuestions,
    Object? deletedQuizIds,
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
    );
  }

  /// صفُّ الروضة الرسمي، أو أيُّ صفٍّ رابع.
  static bool matchesTrack(String grade, String track) {
    if (grade.trim().isEmpty) return false;
    if (track == 'grade4') return RegExp('الرابع|grade ?4|fourth').hasMatch(_norm(grade));
    return isKindergartenGrade(grade);
  }

  /// لعبةُ «المقلاع» لدرسٍ رسمي: أسئلةُ اختباراته في المنهج نفسه.
  static StudyGamesPack? studyGames(String lessonId) {
    final data = current;
    if (data == null) return null;
    final row = data.lessonRows.where((r) => _text(r['id']) == lessonId || _text(_map(r['data'])['lessonId']) == lessonId);
    final name = row.isEmpty ? '' : _norm(_text(_map(row.first['data'])['lesson'] ?? _map(row.first['data'])['lessonName']));
    final questions = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final quiz in data.quizRows.map((r) => _map(r['data']))) {
      final forLesson = _text(quiz['lessonId']) == lessonId || (name.isNotEmpty && _norm(_text(quiz['lesson'])) == name);
      if (!forLesson) continue;
      for (final q in _maps(quiz['questions'])) {
        final question = _text(q['question'] ?? q['text']);
        final answer = _text(q['correctAnswer'] ?? q['answer']);
        final options = [for (final o in _list(q['options'])) if (_text(o).isNotEmpty) _text(o)];
        if (question.isEmpty || !options.contains(answer) || !seen.add(question)) continue;
        questions.add({
          'kind': options.length == 2 ? 'true_false' : 'mcq',
          'question': question,
          'options': options,
          'answer': answer,
        });
      }
    }
    if (questions.isEmpty) return null;
    return StudyGamesPack.fromMap({
      'lessonId': lessonId,
      'games': [
        {
          'id': 'demo-race-$lessonId',
          'game_type': StudyGameType.endlessQuiz.wire,
          'title': row.isEmpty ? '' : _text(_map(row.first['data'])['lesson']),
          'instructions': 'أصب الإجابة الصحيحة!',
          'items': {'questions': questions},
          'gems_reward': 0,
          'points_reward': 0,
        },
      ],
    });
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
