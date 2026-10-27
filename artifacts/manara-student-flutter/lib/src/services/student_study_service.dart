import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/student_strings.dart';
import '../models/interactive_study.dart';
import '../models/study_games.dart';
import 'student_auth_service.dart';

/// سببُ تعذُّر تحضير المذاكرة، بمفتاحِ نصٍّ يُعرض للطفل.
class StudyFailure implements Exception {
  const StudyFailure(this.key);

  final String key;

  String get message => tr('study.error.$key');

  @override
  String toString() => 'StudyFailure($key)';
}

/// يطلب حزمةَ المذاكرة الذكية لدرس من الخادم.
///
/// ── والخادمُ يخزّنها مع الدرس ──
/// فالنداءُ الأول لدرسٍ يولّدها، وما بعده يقرؤها في جزءٍ من الثانية. ولا
/// يُخزَّن شيءٌ هنا: نسخةٌ في التطبيق تعني حزمةً قديمة تبقى بعد أن يُحدّث
/// المعلمُ نصَّ الدرس، ولا سبيلَ للطفل إلى إفراغها.
class StudentStudyService {
  StudentStudyService({
    required this.apiBaseUrl,
    required this.authService,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiBaseUrl;
  final StudentAuthService authService;
  final http.Client _client;

  /// التوليدُ نداءٌ كبير — خريطةٌ وثلاثُ مغامرات — وللخادم ميزانيةُ أربعين
  /// ثانية. فقطعُ الخيط قبلها يُسقط حزمةً كانت في طريقها.
  static const _timeout = Duration(seconds: 95);

  /// عنوانُ المسار، أو `null` إن لم يكن لهذا البناء خادم.
  ///
  /// `Uri.base` تصلح للويب وحده: في APK ليست أصلَ موقعٍ بل مسارَ ملف.
  Uri? get endpoint => _endpointFor('/api/ai/interactive-study');

  /// ألعابُ المذاكرة التفاعلية: مسارُها بجانب مسار الحزمة.
  Uri? get gamesEndpoint => _endpointFor('/api/ai/study-games');

  /// نسخةٌ جديدة من لعبةٍ واحدة عند إعادة اللعب.
  Uri? get freshGameEndpoint => _endpointFor('/api/ai/study-games/fresh');

  Uri? _endpointFor(String path) {
    var base = apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    if (base.isEmpty && kIsWeb) {
      final current = Uri.base;
      if (current.scheme == 'http' || current.scheme == 'https') {
        base = current.host == 'localhost' || current.host == '127.0.0.1'
            ? 'http://localhost:8080'
            : current.origin;
      }
    }
    return base.isEmpty ? null : Uri.tryParse('$base$path');
  }

  Future<StudyPack> fetch({required String lessonId}) async {
    final map = await _post(endpoint, lessonId);
    final pack = StudyPack.fromMap(map['pack']);
    if (pack == null) throw const StudyFailure('badPack');
    await _remember(_packCacheKey(lessonId), map['pack']);
    return pack;
  }

  static String _packCacheKey(String lessonId) => 'study.pack.cache.$lessonId';

  /// خريطةُ الدرس وتحدّيه كما وصلا آخرَ مرّة، محفوظَين على الجهاز — تُفتح
  /// بهما البطاقةُ في لحظتها، ويحلّ محلّهما الجديدُ حين يصل.
  static Future<StudyPack?> cachedPack({required String lessonId}) async {
    final raw = await _recall(_packCacheKey(lessonId));
    return raw == null ? null : StudyPack.fromMap(raw);
  }

  static Future<void> _remember(String key, Object? value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(value));
    } catch (_) {
      // بلا نسخةٍ محفوظة: تُطلب من الخادم في المرّة القادمة كما الآن.
    }
  }

  static Future<Object?> _recall(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      return raw == null ? null : jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  /// ألعابُ الدرس: سحبٌ وإسقاط، ومطابقة، وأسئلةٌ متتالية — يولّدها الخادم
  /// من نصّ الدرس أوّلَ مرّة ويحفظها معه.
  Future<StudyGamesPack> fetchGames({required String lessonId}) async {
    final map = await _post(gamesEndpoint, lessonId);
    final pack = StudyGamesPack.fromMap(map['pack']);
    if (pack == null) throw const StudyFailure('badPack');
    await _remember(_gamesCacheKey(lessonId), map['pack']);
    return pack;
  }

  static String _gamesCacheKey(String lessonId) => 'study.games.cache.$lessonId';

  /// ألعابُ الدرس كما وصلت آخرَ مرّة، محفوظةً على الجهاز.
  ///
  /// ── لماذا ──
  /// الحزمةُ تُطلب من الخادم كلّما فُتح الرفّ، ومن الذكاء الاصطناعي إن لم
  /// تكن محفوظةً هناك — ثوانٍ يرى فيها الطفلُ «جارٍ التحميل». فتُعرض هذه
  /// فوراً، وتحلّ محلّها الجديدةُ حين تصل.
  static Future<StudyGamesPack?> cachedGames({required String lessonId}) async {
    final raw = await _recall(_gamesCacheKey(lessonId));
    final pack = raw == null ? null : StudyGamesPack.fromMap(raw);
    return pack != null && pack.lessonId == lessonId ? pack : null;
  }

  /// نسخةٌ جديدة من لعبةٍ واحدة — يولّدها الخادم من النصّ الكامل للدرس،
  /// متجنّباً ما رآه الطالب ([exclude]). لا تُحفظ: هي لهذه الجولة وحدها.
  Future<StudyGame> fetchFreshGame({
    required String lessonId,
    required StudyGameType type,
    required List<String> exclude,
  }) async {
    final map = await _post(freshGameEndpoint, lessonId, extra: {
      'gameType': type.wire,
      'exclude': exclude,
    });
    final game = StudyGame.fromMap(map['game']);
    if (game == null) throw const StudyFailure('badPack');
    return game;
  }

  Future<Map> _post(
    Uri? target,
    String lessonId, {
    Map<String, Object?> extra = const {},
  }) async {
    if (target == null) throw const StudyFailure('noService');
    final token = await authService.ensureApiSession();
    if (token == null || token.isEmpty) {
      // و`apiSessionError` رسالةٌ جاهزة لا مفتاحُ نصّ: لو بُحث عنها في
      // جدول النصوص لعاد المفتاحُ نفسه فظهرت الرسالةُ خاماً في الشاشة.
      final detail = authService.apiSessionError?.trim() ?? '';
      if (detail.isNotEmpty) throw StudyServerFailure(detail);
      throw const StudyFailure('sessionFailed');
    }

    final http.Response response;
    try {
      response = await _client
          .post(
            target,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'lessonId': lessonId, ...extra}),
          )
          .timeout(_timeout);
    } catch (_) {
      throw const StudyFailure('network');
    }

    Object? payload;
    try {
      payload = jsonDecode(response.body);
    } catch (_) {
      payload = null;
    }
    final map = payload is Map ? payload : const {};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      // ورسالةُ الخادم تُقدَّم على رسالتنا حين يرسلها: هو يعرف السبب —
      // درسٌ بلا نصّ، أو درسٌ خارج مسار الحساب — ونحن لا نعرف إلا أنه ردّ.
      final error = map['error'];
      if (error is String && error.trim().isNotEmpty) {
        throw StudyServerFailure(error.trim());
      }
      throw const StudyFailure('failed');
    }
    return map;
  }
}

/// فشلٌ برسالةٍ جاءت من الخادم نفسه.
///
/// صنفٌ منفصل لأن [StudyFailure] تحمل مفتاحَ نصٍّ محليّاً، وهذه تحمل
/// كلاماً جاهزاً — فلا يُبحث عنه في جدول النصوص ولا يُعرض المفتاح خاماً.
class StudyServerFailure implements Exception {
  const StudyServerFailure(this.message);

  final String message;

  @override
  String toString() => 'StudyFailure(server: $message)';
}
