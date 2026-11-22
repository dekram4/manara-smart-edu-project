import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'student_auth_service.dart';

/// رسالةٌ وصلت للطالب وهو في مكانٍ آخر من التطبيق.
class ChatArrival {
  const ChatArrival({
    required this.id,
    required this.name,
    required this.kind,
    required this.text,
    required this.fromTeacher,
    this.count = 1,
  });

  final String id;
  final String name;

  /// `text` أو `voice` أو `image` أو `file`.
  final String kind;
  final String text;
  final bool fromTeacher;

  /// كم رسالةً جديدةً يمثّلها هذا التنبيه: أوّلُ فحصٍ يجمع ما كان ينتظر.
  final int count;
}

/// يراقب الدردشةَ والطالبُ خارجها: كم رسالةً تنتظره، وما الذي وصل الآن.
///
/// ── ولا يقرأ شيئاً ──
/// يسأل الخادمَ عن الرسائل كما تسأله شاشةُ الدردشة، بلا إيصال قراءة: فلا تُحسب
/// رسالةٌ مقروءةً لأن التنبيهَ ظهر، ولا تختفي قبل أن يفتحها الطالب.
///
/// ── وما يُعدّ «غير مقروء» ──
/// كلُّ ما يعيده الخادمُ لزيارةٍ تبدأ الآن من غير الطالب نفسه، ولم يحفظه: الخادمُ لا
/// يعيد ما استهلكه الطالبُ في زيارةٍ سابقة.
///
/// ويتوقّف حين تُفتح الدردشة ([pause]) — فهي تعرض الجديد بنفسها — ويعود بعد
/// إغلاقها ([resume]) فيعدّ ما بقي بلا تنبيهٍ لما رآه الطالبُ هناك.
class StudentChatInbox {
  StudentChatInbox({
    required this.apiBaseUrl,
    required this.authService,
    required this.myId,
    http.Client? client,
    this.every = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();

  final String apiBaseUrl;
  final StudentAuthService authService;
  final String myId;
  final Duration every;
  final http.Client _client;

  /// كم رسالةً تنتظر الطالب.
  final ValueNotifier<int> unread = ValueNotifier(0);

  final StreamController<ChatArrival> _arrivals = StreamController.broadcast();

  /// ما وصل منذ آخر فحص — أو، في أوّل فحص، ما كان ينتظره مجتمعاً.
  Stream<ChatArrival> get arrivals => _arrivals.stream;

  final Set<String> _known = {};
  bool _primed = false;
  bool _quietNext = false;
  bool _paused = false;
  bool _checking = false;
  bool _disposed = false;
  Timer? _timer;

  bool get paused => _paused;

  Uri? _endpoint() {
    var base = apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    if (base.isEmpty && kIsWeb) {
      final current = Uri.base;
      if (current.scheme == 'http' || current.scheme == 'https') {
        base = current.host == 'localhost' || current.host == '127.0.0.1'
            ? 'http://localhost:8080'
            : current.origin;
      }
    }
    return base.isEmpty ? null : Uri.tryParse('$base/api/student/chat/messages');
  }

  /// يبدأ المراقبة: فحصٌ الآن، ثم كلّ [every].
  void start() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => unawaited(check()));
    unawaited(check());
  }

  /// التطبيقُ في الخلفية أو الدردشةُ مفتوحة: لا فحص.
  void pause() {
    _paused = true;
    _timer?.cancel();
    _timer = null;
  }

  /// يعود للمراقبة. [quietly]: ما يُرى في الفحص التالي لا يُنبَّه له — الطالبُ
  /// خارجٌ من الدردشة وقد رآه.
  void resume({bool quietly = false}) {
    if (_disposed) return;
    _paused = false;
    if (quietly) _quietNext = true;
    start();
  }

  Future<void> check() async {
    if (_paused || _checking || _disposed) return;
    final endpoint = _endpoint();
    if (endpoint == null) return;
    _checking = true;
    try {
      final token = await authService.ensureApiSession();
      if (token == null || token.isEmpty || _paused || _disposed) return;
      final response = await _client.get(endpoint, headers: {
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 || _paused || _disposed) return;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final list = decoded is Map && decoded['messages'] is List
          ? decoded['messages'] as List
          : const [];
      final waiting = <Map>[
        for (final item in list)
          if (item is Map &&
              '${item['from'] ?? ''}' != myId &&
              '${item['id'] ?? ''}'.isNotEmpty &&
              (item['savedUntil'] == null || '${item['savedUntil']}'.isEmpty))
            item,
      ];
      unread.value = waiting.length;
      final fresh = [
        for (final item in waiting)
          if (!_known.contains('${item['id']}')) item,
      ];
      _known.addAll(fresh.map((item) => '${item['id']}'));
      final quiet = _quietNext;
      _quietNext = false;
      if (quiet || fresh.isEmpty || _arrivals.isClosed) {
        _primed = true;
        return;
      }
      final latest = fresh.last;
      final from = '${latest['from'] ?? ''}';
      _arrivals.add(ChatArrival(
        id: '${latest['id']}',
        name: '${latest['name'] ?? ''}'.trim(),
        kind: '${latest['kind'] ?? 'text'}',
        text: '${latest['message'] ?? ''}'.trim(),
        fromTeacher: from.startsWith('teacher:') || latest['fromTeacher'] == true,
        // ‏أوّلُ فحص: ما كان ينتظر الطالبَ قبل فتح التطبيق، في تنبيهٍ واحد.
        count: _primed ? fresh.length : waiting.length,
      ));
      _primed = true;
    } catch (error) {
      // ‏شبكةٌ متقطّعة: الفحصُ التالي يحاول ثانية، ولا يُزعج الطالب بشيء.
      debugPrint('[chat-inbox] check failed: $error');
    } finally {
      _checking = false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_arrivals.close());
    unread.dispose();
    _client.close();
  }
}
