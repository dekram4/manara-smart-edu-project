import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

/// دورةُ مغامرات المذاكرة: لا تُعاد مغامرةٌ حتى تُلعب أخواتُها كلُّها.
///
/// ── لماذا يُحفظ ما لُعب ──
/// الاختيارُ كان عشوائياً يتجنّب السابقةَ وحدها. فطفلٌ يعود إلى درسه غداً
/// قد يقع على مغامرةٍ لعبها أمس وأمامه أخرياتٌ لم يرها. والآن تُحفظ عناوينُ
/// ما لُعب لكل طالبٍ في كل درس، فيُختار ممّا لم يُلعب أوّلاً، وحين تنفد
/// تبدأ دورةٌ جديدة — والحزمةُ تغتني في الخادم مع الوقت، فما يُضاف يدخل
/// الدورةَ من فوره.
///
/// ولكل درسٍ مفتاحُه: ما لُعب في مخطّطٍ لا يمسّ مخطّطاً آخر.
class StudyRotation {
  StudyRotation._(this._prefs, this._key, this._played);

  final SharedPreferences? _prefs;
  final String _key;
  final Set<String> _played;

  /// ما لُعب من هذا الدرس، للعرض والاختبار.
  Set<String> get played => Set.unmodifiable(_played);

  static String keyFor(String studentId, String lessonId) =>
      'study.played.$studentId.$lessonId';

  static Future<StudyRotation> load({
    required String studentId,
    required String lessonId,
  }) async {
    final key = keyFor(studentId, lessonId);
    try {
      final prefs = await SharedPreferences.getInstance();
      return StudyRotation._(prefs, key, {...?prefs.getStringList(key)});
    } catch (_) {
      // تخزينٌ لا يُقرأ: دورةٌ في الذاكرة لهذه الجلسة وحدها.
      return StudyRotation._(null, key, <String>{});
    }
  }

  /// للاختبار: دورةٌ بلا تخزين.
  factory StudyRotation.inMemory([Iterable<String> played = const []]) =>
      StudyRotation._(null, '', {...played});

  /// يختار من [titles] ما لم يُلعب، ولا يكون [current] ما أمكن، ويسجّله.
  ///
  /// وإن لُعبت كلُّها بدأت دورةٌ جديدة لهذه المجموعة وحدها — فروعٌ أخرى
  /// تبقى على ما لُعب منها.
  String? pick(
    List<String> titles, {
    String? current,
    math.Random? random,
  }) {
    if (titles.isEmpty) return null;
    final rng = random ?? math.Random();
    var fresh = titles.where((t) => !_played.contains(t) && t != current).toList();
    if (fresh.isEmpty) {
      _played.removeAll(titles);
      fresh = titles.where((t) => t != current).toList();
      if (fresh.isEmpty) fresh = [...titles];
    }
    final chosen = fresh[rng.nextInt(fresh.length)];
    _played.add(chosen);
    _save();
    return chosen;
  }

  void _save() {
    final prefs = _prefs;
    if (prefs == null) return;
    // آخرُ ٢٠٠ عنوانٍ تكفي أكبرَ حزمة، ولا يكبر المفتاحُ بلا حدّ.
    final list = _played.toList();
    final kept = list.length > 200 ? list.sublist(list.length - 200) : list;
    prefs.setStringList(_key, kept).catchError((_) => false);
  }
}
