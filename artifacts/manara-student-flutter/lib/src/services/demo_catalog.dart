/// منهجُ الحساب الرسمي نفسُه لوضع الزائر — من نسخةٍ مدمجةٍ في التطبيق.
///
/// ‏الزائرُ يرى المنهجَ الذي يراه طالبُ الروضة أو الصف الرابع الرسمي: موادَّه
/// ‏وفصولَه ووحداتِه ودروسَه واختباراتِه (ومنها «القاعدة النورانية»). وهذا
/// ‏المنهجُ **محلّيٌّ كلُّه**: لا يسأل الزائرُ الخادمَ عن شيءٍ منه، فلا خطأَ
/// ‏خادمٍ ولا انتظار، ويعمل بلا إنترنت من أوّل دخول.
///
/// ‏ومن أين النسخة؟ يكتبها البناءُ نفسُه (`tool/snapshot_demo_catalog.dart`
/// ‏في خطوةٍ قبل `flutter build apk`) من مصادر الحساب الرسمي — `app_kv`
/// ‏و`lesson_configs` و`created_quizzes` — ويختار منها مدخلَ الروضة الرسمي
/// ‏ومدخلَ الصف الرابع ([DemoCatalogBuilder.build]) إلى
/// ‏`assets/demo/catalog_<track>.json`. فكلُّ APK يحمل منهجَ يومِ بنائه.
///
/// ‏وإن خلت النسخةُ (بناءٌ بلا أسرار Supabase) بقي المنهجُ المدمج [DemoContent]
/// ‏بديلاً. ولا يقرأ الزائرُ جدولَ `cinema_videos` ولا يكتب فيه: سينما المعلم
/// ‏شأنُ لوحة التحكم والخادم وحدهما.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/study_games.dart';
import 'demo_catalog_data.dart';

export 'demo_catalog_data.dart';

abstract final class DemoCatalog {
  /// منهجُ الزائر الحالي، أو `null` فيُعرض [DemoContent].
  static DemoCatalogData? current;

  /// مسارُ النسخة المدمجة لـ[track].
  static String assetFor(String track) => 'assets/demo/catalog_$track.json';

  /// قارئُ الملفّات المدمجة — يُستبدل في الاختبارات.
  @visibleForTesting
  static Future<String> Function(String path) readAsset = rootBundle.loadString;

  /// يحمّل منهجَ [track] من النسخة المدمجة وحدها، بلا أيّ طلبٍ للخادم.
  static Future<DemoCatalogData?> load(String track) async {
    try {
      final data = DemoCatalogData.fromJson(jsonDecode(await readAsset(assetFor(track))));
      return current = data != null && data.track == track ? data : null;
    } catch (_) {
      return current = null;
    }
  }

  static void clear() => current = null;

  /// يختار من البيانات الخامّ منهجَ صفّ [track] — انظر [DemoCatalogBuilder.build].
  @visibleForTesting
  static DemoCatalogData? build({
    required String track,
    required Object? hierarchy,
    Object? lessonRows,
    Object? quizRows,
    Object? legacyQuestions,
    Object? deletedQuizIds,
    Object? videos,
    Object? deletedVideoIds,
  }) =>
      DemoCatalogBuilder.build(
        track: track,
        hierarchy: hierarchy,
        lessonRows: lessonRows,
        quizRows: quizRows,
        legacyQuestions: legacyQuestions,
        deletedQuizIds: deletedQuizIds,
        videos: videos,
        deletedVideoIds: deletedVideoIds,
      );

  static bool matchesTrack(String grade, String track) => DemoCatalogBuilder.matchesTrack(grade, track);

  /// أسئلةُ درسٍ رسمي من اختباراته: `{question, options, answer}`.
  static List<Map<String, dynamic>> questionsFor(String lessonId) {
    final data = current;
    if (data == null) return const [];
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
    return questions;
  }

  /// لعبةُ «المقلاع» لدرسٍ رسمي: أسئلةُ اختباراته في المنهج نفسه.
  static StudyGamesPack? studyGames(String lessonId) {
    final questions = questionsFor(lessonId);
    if (questions.isEmpty) return null;
    final data = current!;
    final row = data.lessonRows.where((r) => _text(r['id']) == lessonId || _text(_map(r['data'])['lessonId']) == lessonId);
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

  static String _norm(Object? v) => _text(v).toLowerCase().replaceAll(RegExp(r's+'), ' ');
}

String _text(Object? v) => v == null ? '' : '$v'.trim();
List<Object?> _list(Object? v) => v is List ? v : const [];
Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _maps(Object? v) => [for (final e in _list(v)) if (e is Map) Map<String, dynamic>.from(e)];
