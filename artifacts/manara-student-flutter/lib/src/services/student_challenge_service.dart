import 'dart:convert';

import 'package:http/http.dart' as http;

import 'student_auth_service.dart';

/// جولةٌ حركية واحدة، كما يرسلها الخادم من بنك الدرس.
///
/// ثلاثة أنواع لا رابع: اسحب الكلمة إلى فراغها، وافرز العناصر في
/// مجموعاتها، وطابق المصطلح بتعريفه. وليس فيها سؤالُ اختيارٍ من متعدّد:
/// ذاك امتحانٌ مصغّر، وهذه لعبة — والإفلات الخاطئ فيها يرتدّ ولا يُحسب
/// خطأً، فلا عقوبةَ على المحاولة.
sealed class RemoteRound {
  const RemoteRound();

  /// يبني جولةً من JSON، أو `null` إن كان شكلُها غير ما يُنتظر.
  ///
  /// الخادم يصفّي قبلها؛ وهذه بوّابةٌ ثانية، لأن عميلاً يثق بشكلٍ لم
  /// يفحصه يعرض على طفلٍ لوحةً لا تُلعب حين يتغيّر العقد.
  static RemoteRound? fromJson(Object? raw) {
    if (raw is! Map) return null;
    switch (_text(raw['kind'])) {
      case 'fill':
        final answer = _text(raw['answer']);
        final distractors = _list(raw['distractors']);
        if (answer.isEmpty || distractors.length < 2) return null;
        return RemoteFill(
          before: _text(raw['before']),
          after: _text(raw['after']),
          answer: answer,
          distractors: distractors,
        );
      case 'classify':
        final buckets = _list(raw['buckets']);
        final rawItems = raw['items'];
        if (buckets.length < 2 || rawItems is! Map) return null;
        final items = <String, String>{};
        for (final entry in rawItems.entries) {
          final name = _text(entry.key);
          final bucket = _text(entry.value);
          if (name.isEmpty || !buckets.contains(bucket)) continue;
          items[name] = bucket;
        }
        if (items.length < 3) return null;
        return RemoteClassify(
          prompt: _text(raw['prompt']),
          buckets: buckets,
          items: items,
        );
      case 'match':
        final pairs = <({String term, String meaning})>[];
        for (final entry in _rawList(raw['pairs'])) {
          if (entry is! Map) continue;
          final term = _text(entry['term']);
          final meaning = _text(entry['meaning']);
          if (term.isEmpty || meaning.isEmpty) continue;
          pairs.add((term: term, meaning: meaning));
        }
        if (pairs.length < 2) return null;
        return RemoteMatch(pairs: pairs);
      default:
        return null;
    }
  }

  static String _text(Object? value) => (value ?? '').toString().trim();
  static List<Object?> _rawList(Object? value) =>
      value is List ? value : const [];
  static List<String> _list(Object? value) => _rawList(value)
      .map(_text)
      .where((item) => item.isNotEmpty)
      .toList();
}

/// اسحب الكلمة الناقصة إلى فراغها في جملة الدرس.
class RemoteFill extends RemoteRound {
  const RemoteFill({
    required this.before,
    required this.after,
    required this.answer,
    required this.distractors,
  });

  final String before;
  final String after;
  final String answer;
  final List<String> distractors;
}

/// افرز عناصر الدرس في مجموعاتها.
class RemoteClassify extends RemoteRound {
  const RemoteClassify({
    required this.prompt,
    required this.buckets,
    required this.items,
  });

  final String prompt;
  final List<String> buckets;
  final Map<String, String> items;
}

/// طابق كل مصطلحٍ بتعريفه.
class RemoteMatch extends RemoteRound {
  const RemoteMatch({required this.pairs});
  final List<({String term, String meaning})> pairs;
}

/// Why a round could not be fetched, in words the screen can show.
class ChallengeFailure implements Exception {
  const ChallengeFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Fetches a fresh round of challenge questions from the API server.
///
/// ── Why a round is fetched and not stored ──
/// A saved bank is right for a quiz: fixed questions, comparable between
/// students. The challenge is a game that gets replayed, and replaying it
/// on the same questions turns it from thinking into remembering the
/// order of the buttons. So each round is generated, and the questions the
/// player has just seen travel with the request so they do not come back.
class StudentChallengeService {
  StudentChallengeService({
    required this.apiBaseUrl,
    required this.authService,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiBaseUrl;
  final StudentAuthService authService;
  final http.Client _client;

  /// The endpoint, resolved the way the problem solver resolves its own:
  /// an explicit base when the build has one, else the origin the web
  /// build is served from.
  Uri? get endpoint {
    var base = apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    if (base.isEmpty) {
      final current = Uri.base;
      if (current.scheme == 'http' || current.scheme == 'https') {
        base = current.host == 'localhost' || current.host == '127.0.0.1'
            ? 'http://localhost:8080'
            : current.origin;
      }
    }
    return base.isEmpty ? null : Uri.tryParse('$base/api/gemini/challenge');
  }

  /// جولاتُ لعبةٍ واحدة لهذا الدرس، أو [ChallengeFailure] بسببها.
  Future<List<RemoteRound>> fetchRound({
    required String lessonId,
    int count = 6,
    String? seed,
  }) async {
    final target = endpoint;
    if (target == null) throw const ChallengeFailure('noService');
    final token = await authService.ensureApiSession();
    if (token == null || token.isEmpty) {
      throw ChallengeFailure(authService.apiSessionError ?? 'sessionFailed');
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
            body: jsonEncode({
              'lessonId': lessonId,
              'count': count,
              // البذرة تتغيّر مع كل جولة فيتغيّر المخرَج، والمُستبعَد هو
              // ما رآه اللاعب قبل قليل.
              'seed': seed ??
                  DateTime.now().microsecondsSinceEpoch.toRadixString(36),
            }),
          )
          // الخادم له ميزانية خمسين ثانية يجرّب فيها أكثر من نموذج، فقطعُ
          // الخيط قبلها يُسقط جولةً كانت في طريقها.
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw const ChallengeFailure('offline');
    }

    Object? payload;
    try {
      payload = response.body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(response.body);
    } on FormatException {
      throw const ChallengeFailure('badResponse');
    }

    if (response.statusCode == 404) {
      // المسار غير منشور على الخادم. يُسمّى من الرمز وحده، فلا يُخلط
      // بانقطاع شبكةٍ ولا برفضٍ مفهوم.
      throw const ChallengeFailure('notDeployed');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          payload is Map ? (payload['error']?.toString().trim() ?? '') : '';
      throw ChallengeFailure(message.isEmpty ? 'serviceSilent' : message);
    }

    final list = payload is Map && payload['rounds'] is List
        ? payload['rounds'] as List
        : const [];
    final rounds = <RemoteRound>[];
    for (final item in list) {
      final round = RemoteRound.fromJson(item);
      if (round != null) rounds.add(round);
    }
    if (rounds.isEmpty) throw const ChallengeFailure('empty');
    return rounds;
  }
}
