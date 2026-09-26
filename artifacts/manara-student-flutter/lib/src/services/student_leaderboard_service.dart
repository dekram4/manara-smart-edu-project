import 'dart:convert';

import 'package:http/http.dart' as http;

import 'student_auth_service.dart';

/// One classmate on the gem leaderboard.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.id,
    required this.name,
    required this.gems,
    required this.xp,
    required this.level,
    required this.rank,
    required this.isMe,
    this.appearance,
  });

  final String id;
  final String name;
  final int gems;
  final int xp;
  final int level;
  final int rank;
  final bool isMe;

  /// كامل ما اختاره هذا الزميل في «شخصيتي»: الشكل ولونه، والأفاتار
  /// المختار، والصورة المبنيّة إن بناها.
  ///
  /// تُمرَّر كما هي لا مُنتقاةً: الشاشة ترسمها بويدجت الأفاتار نفسه الذي
  /// يرسم شخصية صاحب الجهاز، فما يفهمه ذلك الويدجت اليوم أو غداً يصل
  /// إليه بلا وسيطٍ يُسقط حقلاً لم يكن موجوداً حين كُتب.
  final Map<String, dynamic>? appearance;

  static LeaderboardEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = _text(raw['id']);
    if (id.isEmpty) return null;
    final look = raw['appearance'];
    return LeaderboardEntry(
      id: id,
      name: _text(raw['name']),
      gems: _int(raw['gems']),
      xp: _int(raw['xp']),
      level: _int(raw['level']),
      rank: _int(raw['rank']),
      isMe: raw['isMe'] == true,
      appearance: look is Map
          ? look.map((key, value) => MapEntry(key.toString(), value))
          : null,
    );
  }

  static String _text(Object? value) => (value ?? '').toString().trim();
  static int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse(_text(value)) ?? 0;
}

/// The whole board, as the server ranked it.
///
/// Ranking is the server's job, not the screen's: two children looking at
/// the same class must see the same order, and a tie broken differently on
/// each device would show them different places.
class Leaderboard {
  const Leaderboard({
    required this.entries,
    required this.myRank,
    required this.total,
    required this.topGems,
    required this.gemsToNext,
    required this.listed,
  });

  final List<LeaderboardEntry> entries;
  final int myRank;
  final int total;
  final int topGems;

  /// Gems between this student and the place above — not the leader.
  final int gemsToNext;

  /// Whether this student appears on the board at all.
  final bool listed;

  LeaderboardEntry? get me {
    for (final entry in entries) {
      if (entry.isMe) return entry;
    }
    return null;
  }

  List<LeaderboardEntry> get podium => entries.take(3).toList();
  List<LeaderboardEntry> get rest => entries.skip(3).toList();

  static Leaderboard? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final list = raw['entries'];
    final entries = <LeaderboardEntry>[];
    if (list is List) {
      for (final item in list) {
        final entry = LeaderboardEntry.fromJson(item);
        if (entry != null) entries.add(entry);
      }
    }
    return Leaderboard(
      entries: entries,
      myRank: LeaderboardEntry._int(raw['myRank']),
      total: LeaderboardEntry._int(raw['total']),
      topGems: LeaderboardEntry._int(raw['topGems']),
      gemsToNext: LeaderboardEntry._int(raw['gemsToNext']),
      listed: raw['listed'] == true,
    );
  }
}

/// Reads the class leaderboard from the API server.
class StudentLeaderboardService {
  StudentLeaderboardService({
    required this.apiBaseUrl,
    required this.authService,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiBaseUrl;
  final StudentAuthService authService;
  final http.Client _client;

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
    return base.isEmpty
        ? null
        : Uri.tryParse('$base/api/student/progress/leaderboard');
  }

  /// نتيجةُ الطلب: لوحةٌ أو سببُ تعذّرها.
  ///
  /// كانت تُعيد `null` في خمس حالاتٍ مختلفة — لا عنوانَ خادم، ولا جلسة،
  /// ورفضٌ من الخادم، وانقطاعٌ في الشبكة، وردٌّ لا يُفكّ — فيُخفي القسمُ
  /// نفسَه في كلها. والإخفاء يقول للطفل «لا صدارة» ويقول للمطوّر لا شيء،
  /// فيُظنّ أن الميزة لم تُبنَ أصلاً.
  Future<LeaderboardResult> fetch() async {
    final target = endpoint;
    if (target == null) {
      return const LeaderboardResult.failed(LeaderboardProblem.noService);
    }
    final token = await authService.ensureApiSession();
    if (token == null || token.isEmpty) {
      return LeaderboardResult.failed(
        LeaderboardProblem.noSession,
        detail: authService.apiSessionError,
      );
    }
    try {
      final response = await _client.get(
        target,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 404) {
        // المسار غير منشور على الخادم — وهي حالةٌ تُشخَّص من الرمز
        // وحده، فتُسمّى بدل أن تُخلط بانقطاع الشبكة.
        return const LeaderboardResult.failed(LeaderboardProblem.notDeployed);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String? message;
        try {
          final payload = jsonDecode(response.body);
          if (payload is Map) message = payload['error']?.toString().trim();
        } catch (_) {
          message = null;
        }
        return LeaderboardResult.failed(
          LeaderboardProblem.refused,
          detail: message == null || message.isEmpty
              ? '${response.statusCode}'
              : message,
        );
      }
      final board = Leaderboard.fromJson(jsonDecode(response.body));
      if (board == null) {
        return const LeaderboardResult.failed(LeaderboardProblem.badResponse);
      }
      return LeaderboardResult.ready(board);
    } catch (_) {
      return const LeaderboardResult.failed(LeaderboardProblem.offline);
    }
  }
}


/// لماذا تعذّرت اللوحة. يُعرض للطفل بعبارةٍ واحدة، ويُقرأ في السجلّ.
enum LeaderboardProblem {
  /// لا عنوان خادمٍ في هذا البناء.
  noService,

  /// لم تُفتح جلسةٌ مع الخادم.
  noSession,

  /// الخادم ردّ 404: المسار ليس منشوراً عليه بعد.
  notDeployed,

  /// الخادم ردّ برفضٍ مفهوم.
  refused,

  /// ردٌّ لا يُفكّ.
  badResponse,

  /// لم يصل ردٌّ أصلاً.
  offline,
}

/// لوحةٌ جاهزة، أو سببُ تعذّرها.
class LeaderboardResult {
  const LeaderboardResult.ready(Leaderboard this.board)
      : problem = null,
        detail = null;

  const LeaderboardResult.failed(this.problem, {this.detail}) : board = null;

  final Leaderboard? board;
  final LeaderboardProblem? problem;

  /// ما قاله الخادم، حين قال شيئاً.
  final String? detail;

  bool get ok => board != null;
}
