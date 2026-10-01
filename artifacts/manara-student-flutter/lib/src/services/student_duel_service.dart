import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/student_strings.dart';
import '../models/duel_chat.dart';
import 'student_auth_service.dart';

/// الألعابُ الأربع في بطاقة التحدي. أسماؤها هي أسماؤها في الخادم.
enum DuelGame {
  sprint('sprint'),
  balloons('balloons'),
  tug('tug'),
  gems('gems');

  const DuelGame(this.id);
  final String id;

  String get label => tr('duel.game.$id');
}

/// مباراةٌ كما يراها صاحبُ الجهاز: نتيجتي أمام نتيجته.
class DuelMatch {
  const DuelMatch({
    required this.id,
    required this.lessonId,
    required this.game,
    required this.mode,
    required this.status,
    required this.opponentId,
    required this.mine,
    required this.theirs,
    required this.rounds,
    required this.winnerId,
    required this.iWon,
  });

  final String id;
  final String lessonId;
  final String game;
  final String mode;
  final String status;
  final String opponentId;

  /// نتيجتي، أو `null` إن لم ألعب بعد.
  final int? mine;

  /// ونتيجتُه.
  final int? theirs;

  final int rounds;
  final String? winnerId;
  final bool iWon;

  bool get live => mode == 'live';
  bool get settled => status == 'done';

  /// هل الدورُ عليّ؟
  bool get waitingForMe => mine == null;

  /// وهل أنتظره؟
  bool get waitingForThem => mine != null && theirs == null;

  static DuelMatch? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.trim().isEmpty) return null;
    int? score(Object? value) => value is int ? value : null;
    return DuelMatch(
      id: id.trim(),
      lessonId: '${raw['lessonId'] ?? ''}',
      game: '${raw['game'] ?? ''}',
      mode: '${raw['mode'] ?? 'ghost'}',
      status: '${raw['status'] ?? 'pending'}',
      opponentId: '${raw['opponentId'] ?? ''}',
      mine: score(raw['mine']),
      theirs: score(raw['theirs']),
      rounds: score(raw['rounds']) ?? 5,
      winnerId: raw['winnerId'] is String ? raw['winnerId'] as String : null,
      iWon: raw['iWon'] == true,
    );
  }
}

/// ترتيبُ الصفّ بالانتصارات.
class DuelStanding {
  const DuelStanding({
    required this.studentId,
    required this.name,
    required this.wins,
    required this.played,
    required this.rank,
    required this.isMe,
    this.appearance,
  });

  final String studentId;
  final String name;
  final int wins;
  final int played;
  final int rank;
  final bool isMe;
  final Map<String, dynamic>? appearance;

  static DuelStanding? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['studentId'];
    if (id is! String || id.trim().isEmpty) return null;
    int number(Object? value) => value is int ? value : 0;
    return DuelStanding(
      studentId: id.trim(),
      name: '${raw['name'] ?? ''}',
      wins: number(raw['wins']),
      played: number(raw['played']),
      rank: number(raw['rank']),
      isMe: raw['isMe'] == true,
      appearance: raw['appearance'] is Map
          ? Map<String, dynamic>.from(raw['appearance'] as Map)
          : null,
    );
  }
}

/// سببُ تعذُّرِ عملٍ في التحدي، بنصٍّ يُعرض للطفل.
class DuelFailure implements Exception {
  const DuelFailure(this.message);
  final String message;

  @override
  String toString() => 'DuelFailure($message)';
}

/// مبارياتُ التحدي: الدعوةُ والنتيجةُ والحضورُ الحيّ.
///
/// ── والقرارُ في الخادم لا هنا ──
/// هذه الخدمةُ تنقل وتعرض: من فاز، وكم جوهرةً تُصرف، ومن يُسمح له بالدعوة
/// — كلُّها في `api-server`. فلو حُسب شيءٌ منها هنا لكان رصيدُ الجواهر
/// مسألةَ من يُعدّل التطبيق.
///
/// ── والحضورُ زينةٌ لا شرط ──
/// قناةُ الصفّ تقول من متصلٌ الآن، فتُعرض نقطةٌ خضراء وتبدأ المباراةُ
/// تزامناً. وإن سقطت القناةُ — شبكةٌ ضعيفةٌ أو جهازٌ يمنع المقابس — بقيت
/// الدعوةُ تعمل مؤجَّلةً. فالمباراةُ لا تتوقّف على اتصالٍ حيّ.
class StudentDuelService {
  StudentDuelService({
    required this.apiBaseUrl,
    required this.authService,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiBaseUrl;
  final StudentAuthService authService;
  final http.Client _client;

  static const _timeout = Duration(seconds: 20);

  RealtimeChannel? _classChannel;
  RealtimeChannel? _matchChannel;

  /// من في الصفّ متصلٌ الآن، بمعرّفاتهم.
  final ValueNotifier<Set<String>> online = ValueNotifier(const {});

  Uri? _endpoint(String path) {
    var base = apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    if (base.isEmpty && kIsWeb) {
      final current = Uri.base;
      if (current.scheme == 'http' || current.scheme == 'https') {
        base = current.host == 'localhost' || current.host == '127.0.0.1'
            ? 'http://localhost:8080'
            : current.origin;
      }
    }
    return base.isEmpty ? null : Uri.tryParse('$base/api/duel/$path');
  }

  Future<Map<String, Object?>> _send(
    String path, {
    Object? body,
    bool post = false,
  }) async {
    final target = _endpoint(path);
    if (target == null) throw DuelFailure(tr('duel.error.noService'));
    final token = await authService.ensureApiSession();
    if (token == null || token.isEmpty) {
      throw DuelFailure(tr('duel.error.session'));
    }
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final http.Response response;
    try {
      response = await (post
              ? _client.post(target, headers: headers, body: jsonEncode(body ?? {}))
              : _client.get(target, headers: headers))
          .timeout(_timeout);
    } catch (_) {
      throw DuelFailure(tr('duel.error.network'));
    }
    Object? payload;
    try {
      payload = jsonDecode(response.body);
    } catch (_) {
      payload = null;
    }
    final map = payload is Map ? Map<String, Object?>.from(payload) : <String, Object?>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // ورسالةُ الخادم تُقدَّم: هو يعرف السبب — زميلٌ من خارج الصفّ، أو
      // حسابٌ بلا صفّ — ونحن لا نعرف إلا أنه ردّ.
      final error = map['error'];
      throw DuelFailure(
        error is String && error.trim().isNotEmpty
            ? error.trim()
            : tr('duel.error.failed'),
      );
    }
    return map;
  }

  /// يدعو زميلاً إلى مباراة.
  ///
  /// و[live] وصفٌ لا وعد: يُرسل أنّ الزميل كان متصلاً لحظةَ الدعوة، فتعرض
  /// شاشتُه دعوةً فورية. وإن خرج قبل أن يقبل بقيت المباراةُ مؤجَّلةً —
  /// والخادم لا يفرّق بينهما في الحساب.
  Future<DuelMatch> invite({
    required String lessonId,
    required String guestId,
    required DuelGame game,
    required bool live,
  }) async {
    final map = await _send(
      'invite',
      post: true,
      body: {
        'lessonId': lessonId,
        'guestId': guestId,
        'game': game.id,
        'live': live,
      },
    );
    final match = DuelMatch.fromJson(map['match']);
    if (match == null) throw DuelFailure(tr('duel.error.failed'));
    return match;
  }

  /// يسجّل نتيجتي، ويعود بالمباراة كما صارت وبما صُرف لي.
  Future<({DuelMatch? match, int gems, bool draw})> submitScore({
    required String matchId,
    required int score,
  }) async {
    final map = await _send('$matchId/score', post: true, body: {'score': score});
    return (
      match: DuelMatch.fromJson(map['match']),
      gems: map['gems'] is int ? map['gems'] as int : 0,
      draw: map['draw'] == true,
    );
  }

  Future<List<DuelMatch>> inbox() async {
    final map = await _send('inbox');
    final list = map['matches'];
    return [
      for (final entry in list is List ? list : const [])
        if (DuelMatch.fromJson(entry) case final match?) match,
    ];
  }

  Future<List<DuelStanding>> standings() async {
    final map = await _send('standings');
    final list = map['standings'];
    return [
      for (final entry in list is List ? list : const [])
        if (DuelStanding.fromJson(entry) case final standing?) standing,
    ];
  }

  // ── الحضور ──

  /// يعلن حضوري في الصفّ ويتابع من يحضر.
  ///
  /// ويُتجاهل كلُّ تعذّر: الحضورُ يُظهر نقطةً خضراء، وغيابُه يعني أن تبدو
  /// الدعواتُ كلُّها مؤجَّلة — وهي تعمل.
  Future<void> joinClass({
    required String classKey,
    required String myId,
  }) async {
    if (classKey.isEmpty || myId.isEmpty) return;
    try {
      await leaveClass();
      final channel = authService.client.channel(
        'class:$classKey',
        opts: const RealtimeChannelConfig(self: true),
      );
      channel.onPresenceSync((_) => _readPresence(channel));
      channel.onPresenceJoin((_) => _readPresence(channel));
      channel.onPresenceLeave((_) => _readPresence(channel));
      channel.subscribe((status, _) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await channel.track({'id': myId});
        }
      });
      _classChannel = channel;
    } catch (error) {
      debugPrint('[duel] presence unavailable: $error');
    }
  }

  void _readPresence(RealtimeChannel channel) {
    try {
      final seen = <String>{};
      for (final state in channel.presenceState()) {
        for (final presence in state.presences) {
          final id = presence.payload['id'];
          if (id is String && id.trim().isNotEmpty) seen.add(id.trim());
        }
      }
      online.value = seen;
    } catch (_) {
      // حالةٌ لم تُقرأ: تبقى القائمةُ كما كانت.
    }
  }

  Future<void> leaveClass() async {
    final channel = _classChannel;
    _classChannel = null;
    online.value = const {};
    if (channel == null) return;
    try {
      await channel.unsubscribe();
    } catch (_) {}
  }

  // ── قناةُ المباراة ──

  /// يتابع تقدّمَ الخصم في مباراةٍ حيّة.
  ///
  /// ── ولماذا التقدّمُ لا النتيجة ──
  /// النتيجةُ تُحسم في الخادم، وهذه القناةُ للعرض وحده: يرى الطفلُ عدّادَ
  /// خصمه يتحرّك فيستعجل. فلو انقطعت القناةُ توقّف الشريطُ ولم تتوقّف
  /// المباراة — والنتيجةُ تصل من الخادم على كل حال.
  Future<void> watchMatch({
    required String matchId,
    required void Function(String studentId, int progress) onProgress,
    void Function(DuelChatMessage message)? onChat,
  }) async {
    try {
      await leaveMatch();
      final channel = authService.client.channel('match:$matchId');
      channel.onBroadcast(
        event: 'progress',
        callback: (payload) {
          final id = payload['id'];
          final at = payload['at'];
          if (id is String && at is int) onProgress(id, at);
        },
      );
      if (onChat != null) {
        channel.onBroadcast(
          event: 'chat',
          callback: (payload) {
            // وما لا يصلح أن يُعرض يُترك: القراءةُ تفحص كلَّ حقل — انظر
            // `DuelChatMessage.fromPayload` — ولا تُرفع رميةٌ في مستمعِ قناة.
            final message = DuelChatMessage.fromPayload(payload);
            if (message != null) onChat(message);
          },
        );
      }
      channel.subscribe();
      _matchChannel = channel;
    } catch (error) {
      debugPrint('[duel] match channel unavailable: $error');
    }
  }

  /// يبثّ رسالةً في المباراة الجارية: نصّاً أو إيموجي أو مقطعاً صوتياً.
  ///
  /// ويعود بـ`false` إن لم تُرسل، فتقول الشاشةُ ذلك: الدردشةُ لا معنى لها إن
  /// ظنّ الطفلُ أنه أرسل ولم يصل شيء.
  bool sendChat(DuelChatMessage message) {
    final channel = _matchChannel;
    if (channel == null) return false;
    try {
      channel.sendBroadcastMessage(
        event: 'chat',
        payload: message.toPayload(),
      );
      return true;
    } catch (error) {
      debugPrint('[duel] chat not sent: $error');
      return false;
    }
  }

  /// يبثّ تقدّمي في المباراة الجارية.
  void sendProgress({required String myId, required int at}) {
    final channel = _matchChannel;
    if (channel == null) return;
    try {
      channel.sendBroadcastMessage(
        event: 'progress',
        payload: {'id': myId, 'at': at},
      );
    } catch (_) {
      // بثٌّ لم يصل: الخصم لا يرى تقدّمي، والمباراةُ تمضي.
    }
  }

  Future<void> leaveMatch() async {
    final channel = _matchChannel;
    _matchChannel = null;
    if (channel == null) return;
    try {
      await channel.unsubscribe();
    } catch (_) {}
  }

  void dispose() {
    unawaited(leaveClass());
    unawaited(leaveMatch());
    online.dispose();
  }
}
