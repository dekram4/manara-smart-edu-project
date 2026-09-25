import 'dart:convert';

import 'package:http/http.dart' as http;

import 'student_auth_service.dart';

/// One generated challenge question.
///
/// Plain and immutable so the screen can hold it in a round and a test can
/// build one without a network.
class ChallengeQuestion {
  const ChallengeQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.explanation = '',
  });

  final String question;
  final List<String> options;
  final String correctAnswer;
  final String explanation;

  /// Builds one from the server's JSON, or returns null when the shape is
  /// wrong.
  ///
  /// The server filters already; this is the second gate, because a client
  /// that trusts a shape it did not check shows a child four blank buttons
  /// when the contract drifts.
  static ChallengeQuestion? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final question = _text(raw['question']);
    final options = (raw['options'] is List ? raw['options'] as List : const [])
        .map(_text)
        .where((option) => option.isNotEmpty)
        .toList();
    final answer = _text(raw['correctAnswer']);
    if (question.isEmpty || options.length < 2) return null;
    if (!options.any((option) => option == answer)) return null;
    return ChallengeQuestion(
      question: question,
      options: options,
      correctAnswer: answer,
      explanation: _text(raw['explanation']),
    );
  }

  static String _text(Object? value) => (value ?? '').toString().trim();
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

  /// Questions from earlier rounds in this sitting, newest last.
  ///
  /// Kept here rather than in the screen so a replay carries them without
  /// the screen having to thread them through its own state.
  final List<String> _seen = <String>[];

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

  void forget() => _seen.clear();

  /// One round for [lessonId], or throws [ChallengeFailure] with a reason.
  Future<List<ChallengeQuestion>> fetchRound({
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
              'exclude': _seen.reversed.take(24).toList(),
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

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          payload is Map ? (payload['error']?.toString().trim() ?? '') : '';
      throw ChallengeFailure(message.isEmpty ? 'serviceSilent' : message);
    }

    final list = payload is Map && payload['questions'] is List
        ? payload['questions'] as List
        : const [];
    final questions = <ChallengeQuestion>[];
    for (final item in list) {
      final question = ChallengeQuestion.fromJson(item);
      if (question != null) questions.add(question);
    }
    if (questions.isEmpty) throw const ChallengeFailure('empty');

    for (final question in questions) {
      _seen.add(question.question);
    }
    // ذاكرةٌ قصيرة تكفي: ما يُرسل منها أربعةٌ وعشرون، والاحتفاظ بأكثر
    // يُثقل الجلسة بلا أثر.
    if (_seen.length > 60) _seen.removeRange(0, _seen.length - 60);
    return questions;
  }
}
