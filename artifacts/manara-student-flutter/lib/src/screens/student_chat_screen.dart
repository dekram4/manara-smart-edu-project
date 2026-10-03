import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/student_profile.dart';
import '../l10n/student_strings.dart';
import '../services/duel_voice_recorder.dart';
import '../services/student_auth_service.dart';
import '../services/student_media_permissions.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import '../widgets/chat_voice.dart';
import '../widgets/portal_watermark.dart';
import '../widgets/student_experience.dart';

class StudentChatScreen extends StatefulWidget {
  const StudentChatScreen({
    required this.profile,
    required this.apiBaseUrl,
    required this.authService,
    @visibleForTesting this.httpClient,
    @visibleForTesting this.recorder,
    @visibleForTesting this.micAccess,
    super.key,
  });

  final StudentProfile profile;
  final String apiBaseUrl;
  final StudentAuthService authService;

  /// منافذُ للاختبار: الشبكةُ والمسجّلُ وإذنُ الميكروفون.
  final http.Client? httpClient;
  final DuelVoiceRecorder? recorder;
  final Future<MicAccess> Function()? micAccess;

  @override
  State<StudentChatScreen> createState() => _StudentChatScreenState();
}

class _StudentChatScreenState extends State<StudentChatScreen>
    with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  late final http.Client _client = widget.httpClient ?? http.Client();
  late final DuelVoiceRecorder _recorder = widget.recorder ??
      DuelVoiceRecorder(
        maxDuration: chatVoiceMaxDuration,
        maxBytes: chatVoiceMaxBytes,
      );

  // ── التسجيل ──
  bool _recording = false;
  bool _cancelArmed = false;
  bool _sendingVoice = false;

  /// الإصبعُ ما زال على الزرّ. سؤالُ الإذن يأخذ الشاشةَ فيُفلت الطفلُ ليجيب،
  /// ولا يبدأ بعدها تسجيلٌ لم يعد أحدٌ يضغط له.
  bool _pointerHeld = false;
  // من `clock`: يتبع الزمنَ المصطنع في الاختبار.
  final _stopwatch = clock.stopwatch();
  final ValueNotifier<Duration> _elapsed = ValueNotifier(Duration.zero);
  Timer? _tick;

  // ── التشغيل ──
  /// المقاطعُ التي جُلبت: لا يُجلب مقطعٌ مرّتين في الجلسة.
  final Map<String, Uint8List> _clips = {};
  String? _playingId;
  String? _loadingId;

  // ── رسائلُ تختفي بعد قراءتها ──
  /// الخادمُ يدعم الاختفاءَ والحفظ (جدولُ الإيصالات منشأ).
  bool _ephemeral = false;

  /// ما قرأه الطالبُ في هذه الزيارة: النصوصُ التي عُرضت له، ورسائلُه، والمقاطعُ
  /// التي سمعها. تُبلَّغ حين يغادر فلا تعود له.
  final Set<String> _readNow = {};
  final Set<String> _reported = {};

  /// حفظٌ جارٍ لرسالة: لا يُضغط الزرُّ مرّتين.
  String? _savingId;
  List<_ChatMessage> _messages = const [];
  List<_ChatPeer> _peers = const [];
  String _recipient = 'all';
  String? _error;
  bool _loading = true;
  bool _sending = false;
  bool _chatEnabled = true;

  String? get _token {
    final token = widget.authService.apiSessionToken?.trim();
    return token == null || token.isEmpty ? null : token;
  }

  Uri? _endpoint(String route) {
    var base = widget.apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    if (base.isEmpty) {
      final current = Uri.base;
      if (current.scheme == 'http' || current.scheme == 'https') {
        base = current.host == 'localhost' || current.host == '127.0.0.1'
            ? 'http://localhost:8080'
            : current.origin;
      }
    }
    return base.isEmpty ? null : Uri.tryParse('$base/api/student/chat/$route');
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${_token!}',
        'Content-Type': 'application/json',
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // خرج الطفلُ من التطبيق وإصبعُه على الزرّ: لا يُرسل ما لم يقصده.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (_recording) unawaited(_holdEnd(cancelled: true, quiet: true));
      // وخروجٌ من التطبيق مغادرةٌ للدردشة أيضاً: ما قرأه لا يعود.
      unawaited(_reportRead());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _elapsed.dispose();
    if (_playingId != null) {
      unawaited(StudentSoundService.instance.stopSpeaking());
    }
    if (widget.recorder == null) {
      unawaited(_recorder.dispose());
    } else {
      unawaited(_recorder.cancel());
    }
    // يُبلَّغ ما قُرئ قبل أن يُغلق العميل: الطلبُ يُكمل بعد إغلاق الشاشة.
    final report = _reportRead();
    if (widget.httpClient == null) {
      unawaited(report.whenComplete(_client.close));
    } else {
      unawaited(report);
    }
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!widget.profile.canAccessChat || !_chatEnabled) {
      setState(() {
        _loading = false;
        _error = widget.profile.canAccessChat ? null : tr('chat.disabled');
      });
      return;
    }
    final token = await widget.authService.ensureApiSession();
    if (token == null || _endpoint('messages') == null) {
      setState(() {
        _loading = false;
        _error = widget.authService.apiSessionError ?? tr('chat.sessionFailed');
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final responses = await Future.wait([
        _client.get(_endpoint('messages')!, headers: _headers),
        _client.get(_endpoint('peers')!, headers: _headers),
      ]).timeout(const Duration(seconds: 15));
      final messageData = _decode(responses[0]);
      final peerData = _decode(responses[1]);
      if (responses[0].statusCode != 200 || responses[1].statusCode != 200) {
        throw _failure(
          responses[0].statusCode != 200 ? responses[0] : responses[1],
          fallbackKey: 'chat.loadFailed',
        );
      }
      final messages = messageData['messages'] is List
          ? (messageData['messages'] as List)
              .map(_ChatMessage.fromJson)
              .toList()
          : <_ChatMessage>[];
      final peers = peerData['peers'] is List
          ? (peerData['peers'] as List).map(_ChatPeer.fromJson).toList()
          : <_ChatPeer>[];
      if (!mounted) return;
      _ephemeral = messageData['ephemeral'] == true;
      for (final message in messages) {
        // النصُّ يُقرأ بعرضه، والمقطعُ بسماعه — ورسائلي قرأتُها حين كتبتُها.
        if (!message.isVoice || message.from == widget.profile.id) {
          _readNow.add(message.id);
        }
      }
      setState(() {
        _messages = messages;
        _peers = peers;
        if (_recipient != 'all' &&
            !peers.any((peer) => peer.id == _recipient)) {
          _recipient = 'all';
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = _safeError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleChat() async {
    if (!widget.profile.canAccessChat || _sending) return;
    StudentSoundService.instance.playTap();
    final enabled = !_chatEnabled;
    setState(() {
      _chatEnabled = enabled;
      _error = null;
      if (!enabled) {
        _messages = const [];
        _peers = const [];
        _recipient = 'all';
      }
    });
    if (enabled) await _refresh();
  }

  Future<void> _send() async {
    final endpoint = _endpoint('messages');
    final message = _messageController.text.trim();
    if (!_chatEnabled ||
        message.isEmpty ||
        endpoint == null ||
        _token == null ||
        _sending) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final response = await _client
          .post(endpoint,
              headers: _headers,
              body: jsonEncode({'message': message, 'to': _recipient}))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 201) {
        throw _failure(response, fallbackKey: 'chat.sendFailed');
      }
      StudentSoundService.instance.playTap();
      _messageController.clear();
      await _refresh();
    } catch (error) {
      StudentSoundService.instance.play(StudentSoundCue.warning);
      if (mounted) setState(() => _error = _safeError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── الرسائلُ الصوتية ──

  void _toast(String text, {bool settings = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          action: settings
              ? SnackBarAction(
                  label: tr('chat.voice.settings'),
                  onPressed: () =>
                      unawaited(StudentMediaPermissions.openSettings()),
                )
              : null,
        ),
      );
  }

  Future<void> _holdStart() async {
    if (_recording || _sendingVoice || _sending || !_chatEnabled) return;
    _pointerHeld = true;
    final access = await (widget.micAccess ??
        StudentMediaPermissions.microphoneForVoiceNote)();
    if (!mounted) return;
    if (access == MicAccess.blocked) {
      StudentSoundService.instance.play(StudentSoundCue.warning);
      _toast(tr('chat.voice.blocked'), settings: true);
      return;
    }
    if (access == MicAccess.denied) {
      StudentSoundService.instance.play(StudentSoundCue.warning);
      _toast(tr('chat.voice.denied'));
      return;
    }
    if (!_pointerHeld) {
      _toast(tr('chat.voice.hold'));
      return;
    }
    // لا يُسجَّل فوق رسالةٍ تُسمع: يلتقط الميكروفونُ صوتَها.
    if (_playingId != null) {
      await StudentSoundService.instance.stopSpeaking();
      if (mounted) setState(() => _playingId = null);
    }
    final began = await _recorder.start();
    if (!mounted) return;
    if (!began) {
      _toast(tr('chat.voice.noMic'));
      return;
    }
    if (!_pointerHeld) {
      // أفلت قبل أن يجهز المسجّل: ضغطةٌ لا تسجيل.
      await _recorder.cancel();
      _toast(tr('chat.voice.hold'));
      return;
    }
    _recorder.onAutoStop = () => unawaited(_holdEnd(cancelled: false));
    _stopwatch
      ..reset()
      ..start();
    _elapsed.value = Duration.zero;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _elapsed.value = _stopwatch.elapsed;
    });
    setState(() {
      _recording = true;
      _cancelArmed = false;
    });
  }

  void _holdMove(double distance) {
    if (!_recording) return;
    final armed = distance > chatVoiceCancelDistance;
    if (armed != _cancelArmed) setState(() => _cancelArmed = armed);
  }

  Future<void> _holdEnd({required bool cancelled, bool quiet = false}) async {
    _pointerHeld = false;
    if (!_recording) return;
    final dropped = cancelled || _cancelArmed;
    _tick?.cancel();
    _stopwatch.stop();
    final took = _stopwatch.elapsed;
    if (mounted) {
      setState(() {
        _recording = false;
        _cancelArmed = false;
      });
    }
    _elapsed.value = Duration.zero;
    if (dropped) {
      await _recorder.cancel();
      if (!quiet) _toast(tr('chat.voice.cancelled'));
      return;
    }
    if (took < chatVoiceMinDuration) {
      await _recorder.cancel();
      _toast(tr('chat.voice.tooShort'));
      return;
    }
    final note = await _recorder.stop();
    if (!mounted) return;
    if (!note.ok) {
      _toast(switch (note.problem) {
        VoiceNoteProblem.tooShort => tr('chat.voice.tooShort'),
        VoiceNoteProblem.tooBig => tr('chat.voice.tooBig'),
        VoiceNoteProblem.noPermission => tr('chat.voice.denied'),
        _ => tr('chat.voice.noMic'),
      });
      return;
    }
    await _sendVoice(note.bytes!, took);
  }

  Future<void> _sendVoice(Uint8List bytes, Duration took) async {
    final endpoint = _endpoint('voice');
    if (endpoint == null) return;
    setState(() {
      _sendingVoice = true;
      _error = null;
    });
    try {
      // جلسةٌ صالحةٌ قبل رفع المقطع: تسجيلُ ثلاثين ثانيةً قد يتجاوز عمرَها.
      final token = await widget.authService.ensureApiSession();
      if (token == null || token.isEmpty) {
        throw ChatRequestFailure(
          401,
          widget.authService.apiSessionError ?? tr('chat.sessionFailed'),
        );
      }
      final response = await _client
          .post(
            endpoint,
            headers: _headers,
            body: jsonEncode({
              'audio': base64Encode(bytes),
              'durationMs': took.inMilliseconds,
              'to': _recipient,
            }),
          )
          .timeout(const Duration(seconds: 30));
      final data = _decode(response);
      if (response.statusCode != 201) {
        throw _failure(
          response,
          fallbackKey: 'chat.voice.sendFailed',
          missingKey: 'chat.voice.notDeployed',
        );
      }
      final sent = data['message'];
      if (sent is Map && sent['voiceId'] is String) {
        // المرسِلُ يسمع رسالتَه بلا تنزيل: المقطعُ عنده.
        _clips['${sent['voiceId']}'] = bytes;
      }
      StudentSoundService.instance.playTap();
      await _refresh();
    } catch (error) {
      StudentSoundService.instance.play(StudentSoundCue.warning);
      if (mounted) setState(() => _error = _safeError(error));
    } finally {
      if (mounted) setState(() => _sendingVoice = false);
    }
  }

  Future<void> _toggleVoice(_ChatMessage message) async {
    final id = message.voiceId;
    if (id.isEmpty || _recording) return;
    if (_playingId == id) {
      await StudentSoundService.instance.stopSpeaking();
      if (mounted) setState(() => _playingId = null);
      return;
    }
    if (StudentSoundService.instance.muted.value) {
      _toast(tr('chat.voice.muted'));
      return;
    }
    setState(() => _loadingId = id);
    try {
      var bytes = _clips[id];
      if (bytes == null) {
        final endpoint = _endpoint('voice/$id');
        if (endpoint == null || _token == null) {
          throw ChatRequestFailure(0, tr('chat.sessionFailed'));
        }
        final response = await _client
            .get(endpoint, headers: _headers)
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          throw _failure(
            response,
            fallbackKey: 'chat.voice.playFailed',
            missingKey: 'chat.voice.notDeployed',
          );
        }
        bytes = response.bodyBytes;
        _clips[id] = bytes;
      }
      if (!mounted) return;
      _readNow.add(message.id);
      setState(() {
        _loadingId = null;
        _playingId = id;
      });
      await StudentSoundService.instance.playVoiceNote(
        bytes,
        onDone: () {
          if (mounted && _playingId == id) setState(() => _playingId = null);
        },
      );
    } catch (error) {
      debugPrint('[chat] voice play failed: $error');
      if (!mounted) return;
      setState(() {
        if (_loadingId == id) _loadingId = null;
        if (_playingId == id) _playingId = null;
      });
      _toast(error is ChatRequestFailure
          ? error.message
          : error is TimeoutException
              ? tr('chat.timeout')
              : tr('chat.voice.playFailed'));
    }
  }

  /// جسدُ الردّ JSON إن كان JSON، وإلا فارغ.
  ///
  /// كان يرمي على صفحة HTML — «Cannot POST» من خادمٍ لم يُنشر عليه المسار —
  /// فيبتلع الخطأُ رمزَ الردّ، ويرى الطفلُ «تعذّر الوصول» عن خادمٍ وصل إليه.
  /// يُبلغ الخادمَ بما قُرئ في هذه الزيارة، فلا يعود عند الرجوع.
  ///
  /// ولا يرمي: مغادرةٌ لم تُبلَّغ تعني أن تظهر الرسائلُ مرّةً أخرى، لا أن تتعطّل
  /// الشاشة. ويُعاد في المغادرة التالية.
  Future<void> _reportRead() async {
    final ids = _readNow.difference(_reported).toList();
    final endpoint = _endpoint('seen');
    if (!_ephemeral || ids.isEmpty || endpoint == null || _token == null) {
      return;
    }
    _reported.addAll(ids);
    try {
      final response = await _client
          .post(endpoint, headers: _headers, body: jsonEncode({'ids': ids}))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        _reported.removeAll(ids);
        debugPrint('[chat] seen not recorded: ${response.statusCode}');
      }
    } catch (error) {
      _reported.removeAll(ids);
      debugPrint('[chat] seen not recorded: $error');
    }
  }

  /// يحفظ الرسالةَ ٢٤ ساعة، أو يلغي حفظها.
  Future<void> _toggleSave(_ChatMessage message) async {
    final endpoint = _endpoint('save');
    if (!_ephemeral ||
        endpoint == null ||
        _token == null ||
        _savingId != null) {
      return;
    }
    final save = !message.saved;
    setState(() => _savingId = message.id);
    try {
      final response = await _client
          .post(
            endpoint,
            headers: _headers,
            body: jsonEncode({'id': message.id, 'saved': save}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw _failure(response, fallbackKey: 'chat.save.failed');
      }
      final data = _decode(response);
      final until = DateTime.tryParse('${data['savedUntil'] ?? ''}');
      if (!mounted) return;
      StudentSoundService.instance.playTap();
      setState(() {
        _messages = [
          for (final entry in _messages)
            entry.id == message.id
                ? entry.withSavedUntil(until?.toLocal())
                : entry,
        ];
      });
      _toast(tr(save ? 'chat.save.done' : 'chat.save.undone'));
    } catch (error) {
      StudentSoundService.instance.play(StudentSoundCue.warning);
      _toast(
          error is ChatRequestFailure ? error.message : tr('chat.save.failed'));
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  /// خياراتُ الرسالة بضغطةٍ مطوّلة: الحفظُ أو إلغاؤه.
  Future<void> _messageActions(_ChatMessage message) async {
    if (!_ephemeral) return;
    StudentSoundService.instance.playTap();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Text(message.saved ? '📍' : '📌',
                    style: const TextStyle(fontSize: 24)),
                title: Text(
                  tr(message.saved ? 'chat.save.remove' : 'chat.save.action'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(tr(message.saved
                    ? 'chat.save.removeHint'
                    : 'chat.save.actionHint')),
                onTap: () {
                  Navigator.of(sheet).pop();
                  unawaited(_toggleSave(message));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map
          ? decoded.map((key, value) => MapEntry('$key', value))
          : <String, dynamic>{};
    } on FormatException {
      return <String, dynamic>{};
    }
  }

  /// سببُ رفض الخادم كما هو: رسالتُه إن قالها، وإلا جملةٌ بحسب الرمز — ومعها
  /// الرمزُ نفسُه، فيُعرف من لقطة شاشةٍ ما الذي حدث.
  ChatRequestFailure _failure(
    http.Response response, {
    required String fallbackKey,
    String missingKey = 'chat.notDeployed',
  }) {
    final status = response.statusCode;
    final data = _decode(response);
    final said = _responseError(data)?.trim();
    final code = data['code']?.toString();
    final body = response.body;
    debugPrint(
      '[chat] ${response.request?.method} ${response.request?.url.path} → '
      '$status ${body.length > 300 ? body.substring(0, 300) : body}',
    );
    final String reason;
    if (status == 404 && (code == 'not_found' || data.isEmpty)) {
      // المسارُ نفسُه غيرُ موجود: الخادمُ أقدمُ من التطبيق.
      reason = tr(missingKey);
    } else if (said != null && said.isNotEmpty) {
      reason = said;
    } else if (status == 401 || status == 403) {
      reason = tr('chat.sessionExpired');
    } else if (status == 413) {
      reason = tr('chat.voice.tooBig');
    } else if (status == 429) {
      reason = tr('chat.tooMany');
    } else if (status >= 500) {
      reason = tr('chat.serverError');
    } else {
      reason = tr(fallbackKey);
    }
    return ChatRequestFailure(
      status,
      '$reason (${trf('chat.errorCode', {'code': '$status'})})',
      code: code,
    );
  }

  String? _responseError(Map<String, dynamic> data) =>
      data['error']?.toString();

  @override
  Widget build(BuildContext context) {
    final disabled = !widget.profile.canAccessChat;
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Scaffold(
        backgroundColor: StudentSurface.ground(context),
        // Stated rather than inherited: the composer must ride above the
        // keyboard rather than sit under it.
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          // Stated explicitly so the bar never inherits a colour that
          // leaves its own title and buttons hard to read.
          backgroundColor: const Color(0xFF1B3A6B),
          foregroundColor: Colors.white,
          title: Text(
            tr('chat.title'),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900),
          ),
          actions: [
            const StudentSoundToggle(),
            // These were plain TextButtons, so they inherited the theme's
            // primary blue — which is what disappeared against the bar.
            // Each now states its own colours and carries a visible rim.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextButton.icon(
                onPressed: widget.profile.canAccessChat && !_sending
                    ? _toggleChat
                    : null,
                icon: Icon(
                  _chatEnabled
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  size: 18,
                ),
                label: Text(tr(_chatEnabled ? 'chat.on' : 'chat.off')),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white54,
                  backgroundColor: _chatEnabled
                      ? const Color(0xFF15803D)
                      : const Color(0xFF9A3412),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side:
                        BorderSide(color: Colors.white.withValues(alpha: 0.75)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: tr('chat.refresh'),
              onPressed: _loading || !_chatEnabled ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded),
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white38,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextButton(
                onPressed: () {
                  StudentSoundService.instance.playTap();
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF17233A),
                  backgroundColor: const Color(0xFFFFE9A8),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Colors.white),
                  ),
                ),
                child: Text(tr('action.close')),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            const PortalWatermark(asset: PortalBackgrounds.chat),
            disabled
                ? _ChatStatus(
                    icon: Icons.lock_outline_rounded,
                    message: tr('chat.disabled'),
                  )
                : !_chatEnabled
                    ? _ChatStatus(
                        icon: Icons.pause_circle_outline_rounded,
                        message: tr('chat.paused'),
                      )
                    : _token == null
                        ? _ChatStatus(
                            icon: Icons.lock_outline_rounded,
                            message: widget.authService.apiSessionError ??
                                tr('chat.sessionFailed'),
                          )
                        : Column(
                            children: [
                              // The header steps aside while the student is typing.
                              // The keyboard already takes half a landscape phone, and
                              // between it, the header and the composer there was
                              // nothing left for the conversation itself — the point
                              // of the screen. It comes straight back when the
                              // keyboard closes.
                              if (MediaQuery.viewInsetsOf(context).bottom == 0)
                                Padding(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                      14, 12, 14, 0),
                                  child: StudentScreenHero(
                                    title: tr('chat.title'),
                                    subtitle: tr('chat.blurb'),
                                    icon: Icons.forum_rounded,
                                    colors: const [
                                      Color(0xFF1E3A8A),
                                      Color(0xFF2563EB)
                                    ],
                                  ),
                                ),
                              if (_ephemeral &&
                                  MediaQuery.viewInsetsOf(context).bottom == 0)
                                const _EphemeralNotice(),
                              if (_error != null) _ChatError(text: _error!),
                              Expanded(
                                child: _loading
                                    ? Center(
                                        child: StudentRiveLoading(
                                          label: tr('chat.loading'),
                                        ),
                                      )
                                    : _messages.isEmpty
                                        ? _ChatStatus(
                                            icon: Icons.forum_outlined,
                                            message: tr('chat.empty'),
                                          )
                                        : ListView.builder(
                                            physics:
                                                const BouncingScrollPhysics(),
                                            padding: const EdgeInsets.all(14),
                                            itemCount: _messages.length,
                                            itemBuilder: (_, index) =>
                                                StudentEntrance(
                                              delay: Duration(
                                                  milliseconds: index < 15
                                                      ? index * 30
                                                      : 0),
                                              child: _MessageBubble(
                                                message: _messages[index],
                                                mine: _messages[index].from ==
                                                    widget.profile.id,
                                                canSave: _ephemeral,
                                                saving: _savingId ==
                                                    _messages[index].id,
                                                onLongPress: () => unawaited(
                                                    _messageActions(
                                                        _messages[index])),
                                                onTogglePin: () => unawaited(
                                                    _toggleSave(
                                                        _messages[index])),
                                                voice: _messages[index].isVoice
                                                    ? ChatVoiceNoteView(
                                                        seed: _messages[index]
                                                            .voiceId,
                                                        duration: Duration(
                                                          milliseconds:
                                                              _messages[index]
                                                                  .durationMs,
                                                        ),
                                                        playing: _playingId ==
                                                            _messages[index]
                                                                .voiceId,
                                                        loading: _loadingId ==
                                                            _messages[index]
                                                                .voiceId,
                                                        mine: _messages[index]
                                                                .from ==
                                                            widget.profile.id,
                                                        onTap: () => unawaited(
                                                          _toggleVoice(
                                                              _messages[index]),
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                            ),
                                          ),
                              ),
                              StudentEntrance(
                                delay: const Duration(milliseconds: 200),
                                child: _composer(),
                              ),
                            ],
                          ),
          ],
        ),
      ),
    );
  }

  Widget _composer() => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          color: StudentSurface.card(context),
          child: Column(children: [
            DropdownButtonFormField<String>(
              initialValue: _recipient,
              decoration:
                  InputDecoration(labelText: tr('chat.sendTo'), isDense: true),
              items: [
                DropdownMenuItem(
                    value: 'all', child: Text(tr('chat.classmates'))),
                ..._peers.map((peer) =>
                    DropdownMenuItem(value: peer.id, child: Text(peer.name))),
              ],
              onChanged: _sending || _recording || _sendingVoice
                  ? null
                  : (value) => setState(() => _recipient = value ?? 'all'),
            ),
            const SizedBox(height: 8),
            if (_sendingVoice)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text(
                    tr('chat.voice.sending'),
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: StudentSurface.mutedInk(context)),
                  ),
                ]),
              ),
            Row(children: [
              Expanded(
                child: _recording
                    ? ChatRecordingStrip(
                        elapsed: _elapsed, cancelArmed: _cancelArmed)
                    : TextField(
                        controller: _messageController,
                        enabled: !_sending && !_sendingVoice,
                        maxLength: 1000,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                            hintText: tr('chat.hint'), counterText: ''),
                      ),
              ),
              const SizedBox(width: 8),
              // حقلٌ فارغٌ: ميكروفون. وما إن يُكتب حرفٌ يصير زرَّ إرسال — كما
              // في كل تطبيق رسائل. والزرُّ في الموضع نفسه أثناء التسجيل، فلا يضيع
              // الإصبعُ الذي يضغطه.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _messageController,
                builder: (context, value, _) {
                  if (_recording || value.text.trim().isEmpty) {
                    return ChatVoiceMicButton(
                      recording: _recording,
                      cancelArmed: _cancelArmed,
                      onHoldStart: () => unawaited(_holdStart()),
                      onHoldMove: _holdMove,
                      onHoldEnd: ({required bool cancelled}) =>
                          unawaited(_holdEnd(cancelled: cancelled)),
                    );
                  }
                  return IconButton.filled(
                    onPressed: _sending || _sendingVoice ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
                  );
                },
              ),
            ]),
          ]),
        ),
      );
}

class _ChatMessage {
  const _ChatMessage({
    required this.id,
    required this.from,
    required this.name,
    required this.to,
    required this.message,
    required this.time,
    this.kind = 'text',
    this.voiceId = '',
    this.durationMs = 0,
    this.savedUntil,
  });
  factory _ChatMessage.fromJson(dynamic value) {
    final map = value is Map ? value : const <String, dynamic>{};
    final duration = map['durationMs'];
    return _ChatMessage(
      id: '${map['id'] ?? ''}',
      from: '${map['from'] ?? ''}',
      name: '${map['name'] ?? tr('chat.student')}',
      to: '${map['to'] ?? 'all'}',
      message: '${map['message'] ?? ''}',
      time: '${map['time'] ?? ''}',
      kind: '${map['kind'] ?? 'text'}',
      voiceId: '${map['voiceId'] ?? ''}',
      durationMs: duration is num ? duration.round() : 0,
      savedUntil: DateTime.tryParse('${map['savedUntil'] ?? ''}')?.toLocal(),
    );
  }
  final String id, from, name, to, message, time, kind, voiceId;
  final int durationMs;

  /// محفوظةٌ لي حتى هذا الوقت، أو `null`.
  final DateTime? savedUntil;

  bool get isVoice => kind == 'voice' && voiceId.isNotEmpty;
  bool get saved => savedUntil != null && savedUntil!.isAfter(DateTime.now());

  _ChatMessage withSavedUntil(DateTime? until) => _ChatMessage(
        id: id,
        from: from,
        name: name,
        to: to,
        message: message,
        time: time,
        kind: kind,
        voiceId: voiceId,
        durationMs: durationMs,
        savedUntil: until,
      );
}

class _ChatPeer {
  const _ChatPeer(this.id, this.name);
  factory _ChatPeer.fromJson(dynamic value) {
    final map = value is Map ? value : const <String, dynamic>{};
    return _ChatPeer(
        '${map['id'] ?? ''}', '${map['name'] ?? tr('chat.student')}');
  }
  final String id, name;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    this.voice,
    this.canSave = false,
    this.saving = false,
    this.onLongPress,
    this.onTogglePin,
  });
  final _ChatMessage message;
  final bool mine;

  /// مشغّلُ الرسالة إن كانت صوتية، مكانَ نصّها.
  final Widget? voice;

  /// الحفظُ متاح: ضغطةٌ مطوّلة، أو زرُّ الدبّوس.
  final bool canSave;
  final bool saving;
  final VoidCallback? onLongPress;
  final VoidCallback? onTogglePin;

  @override
  Widget build(BuildContext context) => Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: canSave ? onLongPress : null,
          child: Student3DCard(
            maxTilt: 0.035,
            child: Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                  color: mine ? const Color(0xFF0B8693) : Colors.white,
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(
                        child: Text(mine ? tr('chat.you') : message.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: mine
                                    ? Colors.white
                                    : const Color(0xFF0B8693))),
                      ),
                      if (canSave) ...[
                        const SizedBox(width: 6),
                        Semantics(
                          button: true,
                          label: tr(message.saved
                              ? 'chat.save.remove'
                              : 'chat.save.action'),
                          child: InkResponse(
                            onTap: saving ? null : onTogglePin,
                            radius: 18,
                            child: saving
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                // زرٌّ يُرى ويُقرأ: «📌 حفظ» أو «📌 محفوظة» — لا
                                // دبّوسٌ باهتٌ لا يُعرف أنه يُضغط.
                                : Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: message.saved
                                          ? const Color(0xFFF59E0B)
                                          : (mine
                                              ? Colors.white
                                                  .withValues(alpha: 0.22)
                                              : const Color(0xFF0B8693)
                                                  .withValues(alpha: 0.12)),
                                      border: Border.all(
                                        color: message.saved
                                            ? const Color(0xFFB45309)
                                            : (mine
                                                ? Colors.white
                                                    .withValues(alpha: 0.6)
                                                : const Color(0xFF0B8693)
                                                    .withValues(alpha: 0.5)),
                                      ),
                                    ),
                                    child: Text(
                                      tr(message.saved
                                          ? 'chat.save.pinned'
                                          : 'chat.save.pin'),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                        color: message.saved
                                            ? Colors.white
                                            : (mine
                                                ? Colors.white
                                                : const Color(0xFF0B8693)),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    if (voice != null)
                      voice!
                    else
                      Text(message.message,
                          style: TextStyle(
                              height: 1.45,
                              color: mine
                                  ? Colors.white
                                  : const Color(0xFF17233A))),
                    if (message.saved) ...[
                      const SizedBox(height: 6),
                      Text(
                        trf('chat.save.left', {
                          'h':
                              '${message.savedUntil!.difference(DateTime.now()).inHours.clamp(1, 24)}',
                        }),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: mine
                              ? Colors.white.withValues(alpha: 0.85)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ]),
            ),
          ),
        ),
      );
}

/// يقول للطفل كيف تعمل الدردشة: ما يقرؤه يختفي، وما يحفظه يبقى يوماً.
class _EphemeralNotice extends StatelessWidget {
  const _EphemeralNotice();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
        ),
        child: Text(
          tr('chat.ephemeral.notice'),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            height: 1.45,
            color: StudentSurface.ink(context),
          ),
        ),
      );
}

class _ChatStatus extends StatelessWidget {
  const _ChatStatus({required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 58, color: Color(0xFF0B8693)),
            SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    height: 1.6,
                    color: StudentSurface.ink(context)))
          ])));
}

class _ChatError extends StatelessWidget {
  const _ChatError({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(12)),
      child: Text(text,
          style: const TextStyle(
              color: Color(0xFFB42318), fontWeight: FontWeight.w700)));
}

/// رفضٌ من الخادم بسببه الحقيقيّ: رمزُ الردّ، ورسالةٌ تُعرض كما هي.
class ChatRequestFailure implements Exception {
  ChatRequestFailure(this.status, this.message, {this.code});

  final int status;
  final String message;
  final String? code;

  @override
  String toString() => message;
}

String _safeError(Object error) {
  // ما قاله الخادم — أو ما يعنيه رمزُه — يُعرض كما هو.
  if (error is ChatRequestFailure) return error.message;
  if (error is TimeoutException) return tr('chat.timeout');
  debugPrint('[chat] request failed: $error');
  final text = error.toString().replaceFirst('Exception: ', '').trim();
  // These four are thrown by this screen itself, from the same dictionary
  // the comparison reads, so they match in either language. Anything else
  // came off the wire and is replaced with a sentence a child can act on.
  for (final own in const [
    'chat.disabled',
    'chat.loadFailed',
    'chat.sendFailed',
    'chat.sessionFailed',
    'chat.voice.sendFailed',
  ]) {
    if (text.contains(tr(own))) return text;
  }
  // ورفضُ الخادم لمقطعٍ صوتيّ جملةٌ عربيةٌ كتبها هو للطفل.
  if (text.contains('الرسالة الصوتية')) return text;
  return tr('chat.unreachable');
}
