import 'dart:async';
import 'dart:convert';
import 'dart:io' show gzip;

import 'package:clock/clock.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/student_profile.dart';
import '../l10n/student_strings.dart';
import '../services/coloring_canvas.dart';
import '../services/image_compress.dart';
import '../services/duel_voice_recorder.dart';
import '../services/student_auth_service.dart';
import '../services/student_media_permissions.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import '../widgets/chat_voice.dart';
import '../widgets/portal_watermark.dart';
import '../widgets/student_experience.dart';

/// نتيجةُ حفظ صورةٍ في استوديو الجهاز.
enum PhotoSaveResult { saved, denied, failed }

/// أقصى حجمٍ لصورةٍ تُرسل — السقفُ في الخادم ستّمئة كيلوبايت (`parseChatImage`).
const chatImageMaxBytes = 590 * 1024;

/// أقصى حجمٍ لملفٍّ أو مستند — كسقف الخادم (`CHAT_FILE_MAX_BYTES`).
const chatFileMaxBytes = 1500 * 1024;

/// أقصى ما يُرفع بعد الضغط (`CHAT_FILE_MAX_STORED_BYTES`).
const chatFileMaxStoredBytes = 1100 * 1024;

/// ما يُرسل من الملفّات: مستنداتٌ ونصوصٌ وصور — والخادمُ يفحص نوعَها من بايتاتها.
const chatFileExtensions = [
  'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'ods', 'odp',
  'rtf', 'txt', 'csv', 'md', 'json', 'png', 'jpg', 'jpeg', 'webp', 'gif',
];

/// ملفٌّ اختاره الطالبُ من جهازه.
class PickedChatFile {
  const PickedChatFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

/// يضغط الملفَّ gzip إن صغُر به عُشراً على الأقل — وإلا يُرسل كما هو.
@visibleForTesting
(Uint8List, bool) packChatFile(Uint8List bytes) {
  if (bytes.length < 512) return (bytes, false);
  final packed = Uint8List.fromList(gzip.encode(bytes));
  return packed.length < bytes.length * 0.9 ? (packed, true) : (bytes, false);
}

String _sizeLabel(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB'
    : '${(bytes / 1024).ceil()} KB';

String _fileEmoji(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'pdf' => '📕',
    'doc' || 'docx' || 'odt' || 'rtf' => '📘',
    'xls' || 'xlsx' || 'ods' || 'csv' => '📗',
    'ppt' || 'pptx' || 'odp' => '📙',
    'png' || 'jpg' || 'jpeg' || 'webp' || 'gif' => '🖼️',
    _ => '📄',
  };
}

class StudentChatScreen extends StatefulWidget {
  const StudentChatScreen({
    required this.profile,
    required this.apiBaseUrl,
    required this.authService,
    @visibleForTesting this.httpClient,
    @visibleForTesting this.recorder,
    @visibleForTesting this.micAccess,
    @visibleForTesting this.loadArtworks,
    @visibleForTesting this.renderArtwork,
    @visibleForTesting this.pickDeviceImage,
    @visibleForTesting this.saveToPhotos,
    @visibleForTesting this.pickDeviceFile,
    @visibleForTesting this.saveFile,
    super.key,
  });

  final StudentProfile profile;
  final String apiBaseUrl;
  final StudentAuthService authService;

  /// منافذُ للاختبار: الشبكةُ والمسجّلُ وإذنُ الميكروفون.
  final http.Client? httpClient;
  final DuelVoiceRecorder? recorder;
  final Future<MicAccess> Function()? micAccess;

  /// «لوحاتي» ورسمُ اللوحة صورةً. وبلا قيمة: [ColoringGallery.load] بمعرّف الطالب
  /// و[renderColoringPng].
  final Future<List<ColoringArtwork>> Function()? loadArtworks;
  final Future<Uint8List?> Function(ColoringArtwork artwork)? renderArtwork;

  /// صورةٌ من استوديو الجهاز. وبلا قيمة: [ImagePicker].
  final Future<Uint8List?> Function()? pickDeviceImage;

  /// يحفظ صورةً في استوديو الجهاز ويعيد النتيجة. وبلا قيمة: [Gal].
  final Future<PhotoSaveResult> Function(Uint8List bytes)? saveToPhotos;

  /// ملفٌّ من الجهاز. وبلا قيمة: [FilePicker].
  final Future<PickedChatFile?> Function()? pickDeviceFile;

  /// يحفظ ملفّاً وصله على الجهاز. وبلا قيمة: نافذةُ «حفظ باسم» من [FilePicker].
  final Future<bool> Function(String name, Uint8List bytes)? saveFile;

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

  // ── اللوحات ──
  bool _sendingImage = false;

  /// هل على الخادم مسارُ الصور؟ `null` حتى يُعرف. خادمٌ أقدمُ من التطبيق يردّ
  /// 404 `not_found` — فيُقال ذلك عند الإرفاق مرّةً، بلا ضغطٍ ولا رفعٍ يضيع.
  bool? _imagesDeployed;

  /// اللوحاتُ التي جُلبت أو أُرسلت في هذه الزيارة — في الذاكرة وحدها، لا على القرص.
  final Map<String, Uint8List> _images = {};
  String? _imageLoadingId;

  /// ما شاهده الطالبُ من لوحات زملائه في هذه الزيارة: تختفي حين يخرج.
  final Set<String> _viewedImages = {};

  // ── الملفّات ──
  bool _sendingFile = false;
  final Map<String, Uint8List> _files = {};
  String? _fileLoadingId;
  final Set<String> _viewedFiles = {};

  // ── المعلّمُ وقفلُ الدردشة ──
  /// المعلّمُ قفل الدردشة: الإرسالُ متوقّف، والقراءةُ باقية.
  bool _locked = false;

  /// خادمٌ يعرف محادثةَ المعلّم: ردُّه على الرسائل فيه حالةُ القفل. وخادمٌ
  /// أقدمُ لا يذكرها، فلا يُقال للطالب «لا معلّمَ لصفّك» والعلّةُ في الخادم.
  bool _teacherChatDeployed = true;

  /// قائمةُ «معلّمي» مفتوحة — منفصلةً عن الأصدقاء: محادثتُه وحدها.
  bool _teacherMode = false;

  List<_ChatPeer> get _teachers => _peers.where((p) => p.isTeacher).toList();
  List<_ChatPeer> get _friends => _peers.where((p) => !p.isTeacher).toList();

  /// ما يُعرض: محادثةُ المعلّم في قائمته، وما سواها في قائمة الأصدقاء.
  List<_ChatMessage> get _shown => [
        for (final m in _messages)
          if (m.withTeacher == _teacherMode) m,
      ];

  bool get _busy => _sending || _sendingVoice || _sendingImage || _sendingFile;

  /// قفل المعلّمُ الدردشة: يُقال للطالب ذلك ولا يُرسل شيء.
  bool _blockedByLock() {
    if (!_locked) return false;
    StudentSoundService.instance.play(StudentSoundCue.warning);
    _toast(tr('chat.locked'));
    return true;
  }

  // ── رسائلُ تختفي بعد قراءتها ──
  /// الخادمُ يدعم الاختفاءَ والحفظ (جدولُ الإيصالات منشأ).
  bool _ephemeral = false;

  /// ما قرأه الطالبُ في هذه الزيارة: النصوصُ التي عُرضت له، ورسائلُه، والمقاطعُ
  /// التي سمعها. تُبلَّغ حين يغادر فلا تعود له.
  final Set<String> _readNow = {};
  final Set<String> _reported = {};

  /// رسائلي التي أبلغتُ أني رأيتُها بعد أن قرأها الجميع — فتُستهلك عندي.
  final Set<String> _reportedAllRead = {};

  /// بدايةُ هذه الزيارة كما أعادها الخادم: ما استُهلك قبلها لا يُعرض، وما استُهلك
  /// أثناءها يبقى حتى أخرج.
  String? _visit;

  /// تحديثٌ هادئٌ دوري: يصل الجديد، ويظهر لمن أرسل أنّ رسالتَه قُرئت.
  Timer? _poll;

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
    _poll = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted ||
          _loading ||
          _sending ||
          _sendingVoice ||
          _sendingImage ||
          _sendingFile ||
          !_chatEnabled) {
        return;
      }
      unawaited(_refresh(silent: true));
    });
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
    _poll?.cancel();
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

  Future<void> _refresh({bool silent = false}) async {
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
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final visit = _visit;
      final messagesUri = _endpoint('messages')!.replace(
        queryParameters: visit == null ? null : {'visit': visit},
      );
      final responses = await Future.wait([
        _client.get(messagesUri, headers: _headers),
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
      _locked = messageData['locked'] == true;
      _teacherChatDeployed = messageData.containsKey('locked');
      if (_imagesDeployed == null) unawaited(_probeImages());
      _visit ??= messageData['visit'] is String
          ? messageData['visit'] as String
          : null;
      for (final message in messages) {
        // النصُّ يُقرأ بعرضه، والمقطعُ بسماعه، واللوحةُ بمشاهدتها — ورسائلي
        // قرأتُها حين كتبتُها.
        if ((!message.isVoice && !message.isImage && !message.isFile) ||
            message.from == widget.profile.id) {
          _readNow.add(message.id);
        }
        // ── رسالتي قرأها الجميع، ورأيتُ ذلك ──
        // يُبلَّغ مرّةً أخرى بعد اكتمال القراءة: فتُستهلك عندي وتختفي حين أعود.
        if (message.from == widget.profile.id &&
            message.readByAll &&
            _reportedAllRead.add(message.id)) {
          _reported.remove(message.id);
        }
      }
      // يُبلَّغ ما قُرئ فوراً — لا عند المغادرة وحدها — فيرى المرسِلُ أنّ رسالتَه قُرئت.
      unawaited(_reportRead());
      setState(() {
        _messages = messages;
        _peers = peers;
        if (_recipient != 'all' &&
            !peers.any((peer) => peer.id == _recipient)) {
          _recipient = 'all';
        }
        if (_teacherMode && !_recipient.startsWith('teacher:')) {
          final teachers = _teachers;
          if (teachers.isEmpty) {
            _teacherMode = false;
          } else {
            _recipient = teachers.first.id;
          }
        }
      });
    } catch (error) {
      // التحديثُ الهادئ لا يُزعج بخطأ: الشبكةُ تعود في النبضة التالية.
      if (mounted && !silent) setState(() => _error = _safeError(error));
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
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
    if (_blockedByLock()) return;
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
    if (_blockedByLock()) return;
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

  // ── لوحاتُ «لوحاتي» في الدردشة ──────────────────────────────────


  /// يسأل الخادمَ عن صورةٍ لا وجود لها: المسارُ القائمُ يقول «غير موجودة»، والغائبُ
  /// يقول `not_found` بلا مسار. ولا يُعرف شيءٌ إن لم يُجب — فيُحاوَل عند الإرسال.
  Future<void> _probeImages() async {
    final endpoint = _endpoint('image/chatimage_probe_00000000');
    if (endpoint == null || _token == null) return;
    try {
      final response = await _client
          .get(endpoint, headers: _headers)
          .timeout(const Duration(seconds: 10));
      final missing = response.statusCode == 404 && _decode(response)['code'] == 'not_found';
      if (mounted) setState(() => _imagesDeployed = !missing);
    } catch (_) {
      // الشبكة: يبقى غيرَ معروف.
    }
  }

  /// زرُّ الإرفاق: صورةٌ من «لوحاتي»، أو من استوديو الجهاز.
  Future<void> _attach() async {
    if (_busy || _recording) return;
    if (_blockedByLock()) return;
    if (_imagesDeployed == false) {
      StudentSoundService.instance.play(StudentSoundCue.warning);
      _toast(tr('chat.art.notDeployed'));
      return;
    }
    StudentSoundService.instance.playTap();
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => Directionality(
        textDirection: StudentSettings.direction,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr('chat.attach.title'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                ListTile(
                  key: const ValueKey('chat-attach-art'),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFCE7F3),
                    child: Text('🎨', style: TextStyle(fontSize: 22)),
                  ),
                  title: Text(tr('chat.attach.myArt'),
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(tr('chat.attach.myArtSub')),
                  onTap: () => Navigator.of(sheet).pop('art'),
                ),
                ListTile(
                  key: const ValueKey('chat-attach-device'),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0F2FE),
                    child: Text('🖼️', style: TextStyle(fontSize: 22)),
                  ),
                  title: Text(tr('chat.attach.device'),
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(tr('chat.attach.deviceSub')),
                  onTap: () => Navigator.of(sheet).pop('device'),
                ),
                ListTile(
                  key: const ValueKey('chat-attach-file'),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFDCFCE7),
                    child: Text('📎', style: TextStyle(fontSize: 22)),
                  ),
                  title: Text(tr('chat.attach.file'),
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(tr('chat.attach.fileSub')),
                  onTap: () => Navigator.of(sheet).pop('file'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'art') {
      await _pickArtwork();
    } else if (choice == 'file') {
      await _pickFile();
    } else {
      await _pickFromDevice();
    }
  }

  // ── الملفّاتُ والمستندات ──────────────────────────────────────────

  /// ملفٌّ من الجهاز: الصورةُ تُضغط وتُرسل صورة، وما سواها يُضغط gzip إن صغُر به.
  Future<void> _pickFile() async {
    PickedChatFile? picked;
    try {
      picked = await (widget.pickDeviceFile ??
          () async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: chatFileExtensions,
              withData: true,
            );
            final file = result?.files.single;
            final bytes = file?.bytes;
            return file == null || bytes == null ? null : PickedChatFile(file.name, bytes);
          })();
    } catch (error) {
      debugPrint('[chat] file not picked: $error');
      if (mounted) _toast(tr('chat.attach.pickFailed'));
      return;
    }
    if (!mounted || picked == null || picked.bytes.isEmpty) return;
    final ext = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : '';
    if (!chatFileExtensions.contains(ext)) {
      _toast(tr('chat.file.unsupported'));
      return;
    }
    // ‏صورةٌ اختيرت ملفّاً: تُضغط وتُرسل صورةً تُعرض في مكانها.
    if (const ['png', 'jpg', 'jpeg', 'webp'].contains(ext)) {
      setState(() => _sendingImage = true);
      final bytes = await compressForUpload(picked.bytes);
      if (!mounted) return;
      setState(() => _sendingImage = false);
      if (bytes.length > chatImageMaxBytes) {
        _toast(tr('chat.attach.tooBig'));
        return;
      }
      await _sendImage(bytes);
      return;
    }
    if (picked.bytes.length > chatFileMaxBytes) {
      _toast(tr('chat.file.tooBig'));
      return;
    }
    final (payload, packed) = packChatFile(picked.bytes);
    if (payload.length > chatFileMaxStoredBytes) {
      _toast(tr('chat.file.tooBig'));
      return;
    }
    await _sendFile(picked.name, picked.bytes, payload, packed);
  }

  Future<void> _sendFile(String name, Uint8List original, Uint8List payload, bool packed) async {
    final endpoint = _endpoint('file');
    if (endpoint == null) return;
    setState(() {
      _sendingFile = true;
      _error = null;
    });
    try {
      final token = await widget.authService.ensureApiSession();
      if (token == null || token.isEmpty) {
        throw ChatRequestFailure(401, widget.authService.apiSessionError ?? tr('chat.sessionFailed'));
      }
      final response = await _client
          .post(
            endpoint,
            headers: _headers,
            body: jsonEncode({'file': base64Encode(payload), 'name': name, 'gzip': packed, 'to': _recipient}),
          )
          .timeout(const Duration(seconds: 45));
      final data = _decode(response);
      if (response.statusCode != 201) {
        throw _failure(response, fallbackKey: 'chat.file.sendFailed', missingKey: 'chat.art.notDeployed');
      }
      final sent = data['message'];
      if (sent is Map && sent['fileId'] is String) _files['${sent['fileId']}'] = original;
      StudentSoundService.instance.playTap();
      await _refresh();
    } catch (error) {
      StudentSoundService.instance.play(StudentSoundCue.warning);
      if (mounted) setState(() => _error = _safeError(error));
    } finally {
      if (mounted) setState(() => _sendingFile = false);
    }
  }

  Future<bool> _saveFile(String name, Uint8List bytes) async {
    try {
      final saved = await (widget.saveFile ??
          (name, bytes) async =>
              await FilePicker.platform.saveFile(fileName: name, bytes: bytes) != null)(name, bytes);
      if (saved) StudentSoundService.instance.playTap();
      return saved;
    } catch (error) {
      debugPrint('[chat] file not saved: $error');
      return false;
    }
  }

  /// يفتح الملفّ: معاينةٌ للنصّ والصورة، وزرُّ «احفظ على جهازي».
  Future<void> _viewFile(_ChatMessage message) async {
    final id = message.fileId;
    if (id.isEmpty || _fileLoadingId != null) return;
    StudentSoundService.instance.playTap();
    var bytes = _files[id];
    if (bytes == null) {
      setState(() => _fileLoadingId = id);
      try {
        final endpoint = _endpoint('file/$id');
        if (endpoint == null || _token == null) throw ChatRequestFailure(0, tr('chat.sessionFailed'));
        final response = await _client.get(endpoint, headers: _headers).timeout(const Duration(seconds: 45));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          throw _failure(response, fallbackKey: 'chat.file.loadFailed', missingKey: 'chat.art.notDeployed');
        }
        bytes = response.bodyBytes;
        _files[id] = bytes;
      } catch (error) {
        if (mounted) {
          _toast(error is ChatRequestFailure
              ? error.message
              : error is TimeoutException
                  ? tr('chat.timeout')
                  : tr('chat.file.loadFailed'));
        }
        return;
      } finally {
        if (mounted) setState(() => _fileLoadingId = null);
      }
    }
    if (!mounted) return;
    _readNow.add(message.id);
    unawaited(_reportRead());
    setState(() => _viewedFiles.add(message.id));
    final isText = message.mime.startsWith('text/') || message.mime == 'application/json';
    final isImage = message.mime.startsWith('image/');
    String? preview;
    if (isText) {
      final text = utf8.decode(bytes, allowMalformed: true);
      preview = text.length > 4000 ? '${text.substring(0, 4000)}…' : text;
    }
    final data = bytes;
    String? result;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => Directionality(
        textDirection: StudentSettings.direction,
        child: StatefulBuilder(
          builder: (sheet, setSheet) => SafeArea(
            child: ConstrainedBox(
              key: const ValueKey('chat-file-viewer'),
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${_fileEmoji(message.fileName)} ${message.fileName}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    Text('${_sizeLabel(data.length)} · ${message.from == widget.profile.id ? tr('chat.you') : message.name}',
                        style: TextStyle(color: StudentSurface.mutedInk(sheet), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    if (preview != null)
                      Flexible(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: StudentSurface.card(sheet),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: StudentSurface.outline(sheet)),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(preview, key: const ValueKey('chat-file-preview')),
                          ),
                        ),
                      )
                    else if (isImage)
                      Flexible(child: Image.memory(data, fit: BoxFit.contain))
                    else
                      Text(tr('chat.file.saveHint'), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    if (result != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(result!, key: const ValueKey('chat-file-result'),
                            style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          key: const ValueKey('chat-file-save'),
                          onPressed: () async {
                            final ok = await _saveFile(message.fileName, data);
                            setSheet(() => result = tr(ok ? 'chat.file.saved' : 'chat.file.notSaved'));
                          },
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                          icon: const Icon(Icons.download_rounded),
                          label: Text(tr('chat.file.save'), style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                        if (isImage && message.from != widget.profile.id)
                          _SaveToPhotosButton(onSave: () => _saveToPhotos(data)),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(sheet).pop(),
                          icon: const Icon(Icons.close_rounded),
                          label: Text(tr('chat.art.close')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// صورةٌ من استوديو الجهاز، مصغّرةٌ قبل الإرسال: صورةُ كاميرا بحجمها الكامل
  /// أثقلُ من سقف الخادم بكثير.
  Future<void> _pickFromDevice() async {
    Uint8List? bytes;
    try {
      bytes = await (widget.pickDeviceImage ??
          () async {
            final file = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 1280,
              maxHeight: 1280,
              imageQuality: 75,
            );
            return file?.readAsBytes();
          })();
    } catch (error) {
      debugPrint('[chat] device image not picked: $error');
      if (mounted) _toast(tr('chat.attach.pickFailed'));
      return;
    }
    if (!mounted || bytes == null || bytes.isEmpty) return;
    // ‏ضغطٌ على الجهاز: صورةُ كاميرا تصير بضعَ مئاتٍ من الكيلوبايتات.
    setState(() => _sendingImage = true);
    bytes = await compressForUpload(bytes);
    if (!mounted) return;
    setState(() => _sendingImage = false);
    if (bytes.length > chatImageMaxBytes) {
      _toast(tr('chat.attach.tooBig'));
      return;
    }
    await _sendImage(bytes);
  }

  /// يحفظ الصورةَ التي وصلته في استوديو الجهاز (الصور في iOS، والمعرض في أندرويد).
  Future<PhotoSaveResult> _saveToPhotos(Uint8List bytes) async {
    final result = await (widget.saveToPhotos ??
        (bytes) async {
          try {
            if (!await Gal.hasPermission() && !await Gal.requestPermission()) {
              return PhotoSaveResult.denied;
            }
            await Gal.putImageBytes(bytes,
                name: 'manara_${DateTime.now().millisecondsSinceEpoch}');
            return PhotoSaveResult.saved;
          } on GalException catch (error) {
            debugPrint('[chat] photo not saved: ${error.type}');
            return error.type == GalExceptionType.permissionDenied
                ? PhotoSaveResult.denied
                : PhotoSaveResult.failed;
          } catch (error) {
            debugPrint('[chat] photo not saved: $error');
            return PhotoSaveResult.failed;
          }
        })(bytes);
    if (result == PhotoSaveResult.saved) StudentSoundService.instance.playTap();
    return result;
  }

  /// يختار الطالبُ لوحةً من «لوحاتي» فتُرسل إلى من اختاره في «أرسل إلى».
  Future<void> _pickArtwork() async {
    if (_busy || _recording) return;
    StudentSoundService.instance.playTap();
    final artworks =
        await (widget.loadArtworks ??
            () => ColoringGallery.load(owner: widget.profile.id))();
    if (!mounted) return;
    if (artworks.isEmpty) {
      _toast(tr('chat.art.none'));
      return;
    }
    final to = _recipient == 'all'
        ? tr('chat.classmates')
        : _peers
            .firstWhere((p) => p.id == _recipient,
                orElse: () => _ChatPeer(_recipient, tr('chat.student')))
            .label;
    final chosen = await showModalBottomSheet<ColoringArtwork>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => Directionality(
        textDirection: StudentSettings.direction,
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheet).height * 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🎨 ${tr('chat.art.pick')}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  trf('chat.art.pickHint', {'to': to}),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: StudentSurface.mutedInk(sheet)),
                ),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 150,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: artworks.length,
                    itemBuilder: (_, i) => GestureDetector(
                      key: ValueKey('chat-art-$i'),
                      onTap: () => Navigator.of(sheet).pop(artworks[i]),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFFF9A8D4), width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CustomPaint(
                              painter: artworks[i].painter(outline: 4)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    final rendered = await (widget.renderArtwork ?? (a) => a.toPng())(chosen);
    final bytes = rendered == null ? null : await compressForUpload(rendered);
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      _toast(tr('chat.art.sendFailed'));
      return;
    }
    await _sendImage(bytes);
  }

  Future<void> _sendImage(Uint8List bytes) async {
    final endpoint = _endpoint('image');
    if (endpoint == null) return;
    setState(() {
      _sendingImage = true;
      _error = null;
    });
    try {
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
            body: jsonEncode({'image': base64Encode(bytes), 'to': _recipient}),
          )
          .timeout(const Duration(seconds: 30));
      final data = _decode(response);
      if (response.statusCode != 201) {
        if (response.statusCode == 404 && data['code'] == 'not_found') _imagesDeployed = false;
        throw _failure(
          response,
          fallbackKey: 'chat.art.sendFailed',
          missingKey: 'chat.art.notDeployed',
        );
      }
      final sent = data['message'];
      if (sent is Map && sent['imageId'] is String) {
        // المرسِلُ يرى لوحتَه بلا تنزيل: هي عنده.
        _images['${sent['imageId']}'] = bytes;
      }
      StudentSoundService.instance.playTap();
      await _refresh();
    } catch (error) {
      StudentSoundService.instance.play(StudentSoundCue.warning);
      if (mounted) setState(() => _error = _safeError(error));
    } finally {
      if (mounted) setState(() => _sendingImage = false);
    }
  }

  /// يفتح اللوحةَ ملءَ الشاشة. مشاهدتُها قراءتُها: تُبلَّغ، فتختفي عند الخروج.
  Future<void> _viewImage(_ChatMessage message) async {
    final id = message.imageId;
    if (id.isEmpty || _imageLoadingId != null) return;
    StudentSoundService.instance.playTap();
    var bytes = _images[id];
    if (bytes == null) {
      setState(() => _imageLoadingId = id);
      try {
        final endpoint = _endpoint('image/$id');
        if (endpoint == null || _token == null) {
          throw ChatRequestFailure(0, tr('chat.sessionFailed'));
        }
        final response = await _client
            .get(endpoint, headers: _headers)
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          throw _failure(
            response,
            fallbackKey: 'chat.art.loadFailed',
            missingKey: 'chat.art.notDeployed',
          );
        }
        bytes = response.bodyBytes;
        _images[id] = bytes;
      } catch (error) {
        debugPrint('[chat] image load failed: $error');
        if (mounted) {
          _toast(error is ChatRequestFailure
              ? error.message
              : error is TimeoutException
                  ? tr('chat.timeout')
                  : tr('chat.art.loadFailed'));
        }
        return;
      } finally {
        if (mounted) setState(() => _imageLoadingId = null);
      }
    }
    if (!mounted) return;
    _readNow.add(message.id);
    unawaited(_reportRead());
    setState(() => _viewedImages.add(message.id));
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (dialog) => Dialog(
        key: const ValueKey('chat-image-viewer'),
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.from == widget.profile.id
                  ? tr('chat.you')
                  : '🎨 ${message.name}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Image.memory(bytes!,
                      fit: BoxFit.contain, gaplessPlayback: true),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                // ‏لمن وصلته الصورة: يحفظها في استوديو جهازه.
                if (message.from != widget.profile.id)
                  _SaveToPhotosButton(
                      onSave: () => _saveToPhotos(bytes!)),
                FilledButton.icon(
                  onPressed: () => Navigator.of(dialog).pop(),
                  icon: const Icon(Icons.close_rounded),
                  label: Text(tr('chat.art.close'),
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
      unawaited(_reportRead());
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
    // رمزٌ منتهٍ: يُترك ليُجدَّد في المحاولة التالية، لا يُعاد إرسالُه أبداً.
    if (status == 401) widget.authService.expireApiSession();
    final data = _decode(response);
    final said = _responseError(data)?.trim();
    final code = data['code']?.toString();
    final body = response.body;
    debugPrint(
      '[chat] ${response.request?.method} ${response.request?.url.path} → '
      '$status ${body.length > 300 ? body.substring(0, 300) : body}',
    );
    // ‏قفل المعلّمُ الدردشة: الجملةُ كما هي، بلا رمز خطأ.
    if (status == 423 || code == 'chat_locked') {
      if (mounted) setState(() => _locked = true);
      return ChatRequestFailure(status, tr('chat.locked'), code: 'chat_locked');
    }
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
                              if (_locked)
                                Container(
                                  key: const ValueKey('chat-locked-banner'),
                                  width: double.infinity,
                                  margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFF59E0B)),
                                  ),
                                  child: Row(children: [
                                    const Text('🔒', style: TextStyle(fontSize: 20)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(tr('chat.locked'),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w900, color: Color(0xFF92400E))),
                                    ),
                                  ]),
                                ),
                              _conversationTabs(),
                              if (_error != null) _ChatError(text: _error!),
                              Expanded(
                                child: _loading
                                    ? Center(
                                        child: StudentRiveLoading(
                                          label: tr('chat.loading'),
                                        ),
                                      )
                                    : _shown.isEmpty
                                        ? _ChatStatus(
                                            icon: _teacherMode
                                                ? Icons.school_rounded
                                                : Icons.forum_outlined,
                                            message: tr(_teacherMode
                                                ? 'chat.teacher.empty'
                                                : 'chat.empty'),
                                          )
                                        : ListView.builder(
                                            physics:
                                                const BouncingScrollPhysics(),
                                            padding: const EdgeInsets.all(14),
                                            itemCount: _shown.length,
                                            itemBuilder: (_, index) =>
                                                StudentEntrance(
                                              delay: Duration(
                                                  milliseconds: index < 15
                                                      ? index * 30
                                                      : 0),
                                              child: _MessageBubble(
                                                message: _shown[index],
                                                mine: _shown[index].from ==
                                                    widget.profile.id,
                                                canSave: _ephemeral,
                                                saving: _savingId ==
                                                    _shown[index].id,
                                                onLongPress: () => unawaited(
                                                    _messageActions(
                                                        _shown[index])),
                                                onTogglePin: () => unawaited(
                                                    _toggleSave(
                                                        _shown[index])),
                                                voice: _shown[index].isFile
                                                    ? _ChatFileTile(
                                                        message: _shown[index],
                                                        mine: _shown[index].from == widget.profile.id,
                                                        viewed: _viewedFiles.contains(_shown[index].id),
                                                        loading: _fileLoadingId == _shown[index].fileId,
                                                        onTap: () => unawaited(_viewFile(_shown[index])),
                                                      )
                                                    : _shown[index].isImage
                                                    ? _ChatImageTile(
                                                        mine: _shown[index]
                                                                .from ==
                                                            widget.profile.id,
                                                        viewed: _viewedImages
                                                            .contains(
                                                                _shown[index]
                                                                    .id),
                                                        loading:
                                                            _imageLoadingId ==
                                                                _shown[index]
                                                                    .imageId,
                                                        onTap: () => unawaited(
                                                            _viewImage(
                                                                _messages[
                                                                    index])),
                                                      )
                                                    : _shown[index].isVoice
                                                    ? ChatVoiceNoteView(
                                                        seed: _shown[index]
                                                            .voiceId,
                                                        duration: Duration(
                                                          milliseconds:
                                                              _shown[index]
                                                                  .durationMs,
                                                        ),
                                                        playing: _playingId ==
                                                            _shown[index]
                                                                .voiceId,
                                                        loading: _loadingId ==
                                                            _shown[index]
                                                                .voiceId,
                                                        mine: _shown[index]
                                                                .from ==
                                                            widget.profile.id,
                                                        onTap: () => unawaited(
                                                          _toggleVoice(
                                                              _shown[index]),
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

  /// «أصدقائي» و«معلّمي»: قائمتان منفصلتان، ولكلٍّ محادثتُها.
  Widget _conversationTabs() {
    final teachers = _teachers;
    Widget tab(String key, String label, bool selected, VoidCallback onTap, {int unread = 0}) => Expanded(
          child: GestureDetector(
            key: ValueKey(key),
            onTap: _busy || _recording ? null : onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF1B3A6B) : StudentSurface.card(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected ? Colors.white : StudentSurface.outline(context)),
              ),
              alignment: Alignment.center,
              child: Text(
                unread > 0 ? '$label  ($unread)' : label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : StudentSurface.ink(context),
                ),
              ),
            ),
          ),
        );
    final fromTeacher = _messages.where((m) => m.withTeacher && m.from != widget.profile.id).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(children: [
        tab('chat-tab-friends', '👫 ${tr('chat.tab.friends')}', !_teacherMode, () {
          StudentSoundService.instance.playTap();
          setState(() {
            _teacherMode = false;
            if (_recipient.startsWith('teacher:')) _recipient = 'all';
          });
        }),
        const SizedBox(width: 8),
        tab('chat-tab-teacher', '👩‍🏫 ${tr('chat.tab.teacher')}', _teacherMode, () {
          StudentSoundService.instance.playTap();
          if (teachers.isEmpty) {
            _toast(tr(_teacherChatDeployed ? 'chat.teacher.none' : 'chat.teacher.serverOld'));
            return;
          }
          setState(() {
            _teacherMode = true;
            if (!_recipient.startsWith('teacher:')) _recipient = teachers.first.id;
          });
        }, unread: _teacherMode ? 0 : fromTeacher),
      ]),
    );
  }

  /// قائمةُ «معلّمي»: معلّمُ الصفّ (ومن يُضاف لاحقاً) — يُختار ليُراسَل.
  Widget _teacherPicker() => SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final teacher in _teachers)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  key: ValueKey('chat-teacher-${teacher.id}'),
                  avatar: const Text('👩‍🏫'),
                  label: Text(teacher.name.isEmpty ? tr('chat.teacher') : teacher.name,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  selected: _recipient == teacher.id,
                  onSelected: _busy || _recording ? null : (_) => setState(() => _recipient = teacher.id),
                ),
              ),
          ],
        ),
      );

  Widget _composer() => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          color: StudentSurface.card(context),
          child: Column(children: [
            if (_teacherMode)
              _teacherPicker()
            else
              DropdownButtonFormField<String>(
                key: ValueKey('chat-friends-${_friends.length}'),
                initialValue: _recipient.startsWith('teacher:') ? 'all' : _recipient,
                decoration:
                    InputDecoration(labelText: tr('chat.sendTo'), isDense: true),
                items: [
                  DropdownMenuItem(
                      value: 'all', child: Text(tr('chat.classmates'))),
                  ..._friends.map((peer) =>
                      DropdownMenuItem(value: peer.id, child: Text(peer.label))),
                ],
                onChanged: _busy || _recording
                    ? null
                    : (value) => setState(() => _recipient = value ?? 'all'),
              ),
            const SizedBox(height: 8),
            if (_sendingVoice || _sendingImage || _sendingFile)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text(
                    tr(_sendingFile
                        ? 'chat.file.sending'
                        : _sendingImage
                            ? 'chat.art.sending'
                            : 'chat.voice.sending'),
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: StudentSurface.mutedInk(context)),
                  ),
                ]),
              ),
            Row(children: [
              if (!_recording) ...[
                IconButton.filledTonal(
                  key: const ValueKey('chat-send-art'),
                  tooltip: tr('chat.attach.title'),
                  onPressed: _busy ? null : () => unawaited(_attach()),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFCE7F3),
                    foregroundColor: const Color(0xFFDB2777),
                  ),
                  icon: const Icon(Icons.attach_file_rounded),
                ),
                const SizedBox(width: 6),
              ],
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
    this.imageId = '',
    this.fileId = '',
    this.fileName = '',
    this.fileSize = 0,
    this.mime = '',
    this.durationMs = 0,
    this.savedUntil,
    this.readBy = const [],
    this.readByAll = false,
    this.recipients = 0,
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
      imageId: '${map['imageId'] ?? ''}',
      fileId: '${map['fileId'] ?? ''}',
      fileName: '${map['fileName'] ?? ''}',
      fileSize: map['fileSize'] is num ? (map['fileSize'] as num).toInt() : 0,
      mime: '${map['mime'] ?? ''}',
      durationMs: duration is num ? duration.round() : 0,
      savedUntil: DateTime.tryParse('${map['savedUntil'] ?? ''}')?.toLocal(),
      readBy: [
        for (final name
            in map['readBy'] is List ? map['readBy'] as List : const [])
          if ('$name'.trim().isNotEmpty) '$name'.trim(),
      ],
      readByAll: map['readByAll'] == true,
      recipients:
          map['recipients'] is num ? (map['recipients'] as num).toInt() : 0,
    );
  }

  /// لرسائلي وحدها: من قرأها/استمع إليها بأسمائهم، وهل قرأها كلُّ من أُرسلت إليه.
  final List<String> readBy;
  final bool readByAll;
  final int recipients;
  final String id, from, name, to, message, time, kind, voiceId, imageId;
  final String fileId, fileName, mime;
  final int durationMs, fileSize;

  /// من محادثة المعلّم: منه أو إليه.
  bool get withTeacher => from.startsWith('teacher:') || to.startsWith('teacher:');

  /// محفوظةٌ لي حتى هذا الوقت، أو `null`.
  final DateTime? savedUntil;

  bool get isVoice => kind == 'voice' && voiceId.isNotEmpty;
  bool get isImage => kind == 'image' && imageId.isNotEmpty;
  bool get isFile => kind == 'file' && fileId.isNotEmpty;
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
        imageId: imageId,
        fileId: fileId,
        fileName: fileName,
        fileSize: fileSize,
        mime: mime,
        durationMs: durationMs,
        savedUntil: until,
        readBy: readBy,
        readByAll: readByAll,
        recipients: recipients,
      );
}

class _ChatPeer {
  const _ChatPeer(this.id, this.name);

  /// معلّمُ الصفّ: `teacher:<معرّفه>` — تصله الرسائلُ في بوابته.
  bool get isTeacher => id.startsWith('teacher:');

  String get label => isTeacher ? '👩‍🏫 ${tr('chat.teacher')}' : name;
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
                  color: mine
                      ? (message.readByAll
                          ? const Color(0xFF4338CA)
                          : const Color(0xFF0B8693))
                      : Colors.white,
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
                    if (mine) _ReadReceipt(message: message),
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
            Icon(icon, size: 58, color: StudentSurface.vivid(context, const Color(0xFF0B8693))),
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

/// تحت رسالتي: من قرأها أو استمع إليها.
///
/// خاصّة: «✓✓ قرأتها روز» — وفقاعتُها بلونٍ آخر. وللصفّ: «👁️ شاهدها: روز، سارة»
/// حتى يشاهدها الجميع. ولم يقرأها أحدٌ بعد: «✓ أُرسلت».
class _ReadReceipt extends StatelessWidget {
  const _ReadReceipt({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final voice = message.isVoice;
    final names = message.readBy.join('، ');
    final String text;
    if (message.readBy.isEmpty) {
      text = tr('chat.read.sent');
    } else if (message.readByAll && message.recipients <= 1) {
      text = trf(voice ? 'chat.read.listenedBy' : 'chat.read.readBy',
          {'names': names});
    } else if (message.readByAll) {
      text = trf(voice ? 'chat.read.allListened' : 'chat.read.allSeen',
          {'names': names});
    } else {
      text = trf(voice ? 'chat.read.listenedSome' : 'chat.read.seenSome',
          {'names': names});
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: message.readByAll
              ? const Color(0xFFBEF264)
              : Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

/// لوحةٌ في الدردشة: مغطّاةٌ حتى تُضغط — تُشاهد ثم تختفي كالرسائل الأخرى.
class _ChatImageTile extends StatelessWidget {
  const _ChatImageTile({
    required this.mine,
    required this.viewed,
    required this.loading,
    required this.onTap,
  });

  final bool mine;
  final bool viewed;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: tr('chat.art.label'),
        child: InkWell(
          key: const ValueKey('chat-image-tile'),
          borderRadius: BorderRadius.circular(14),
          onTap: loading ? null : onTap,
          child: Container(
            width: 230,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: viewed
                    ? const [Color(0xFF9CA3AF), Color(0xFFD1D5DB)]
                    : const [
                        Color(0xFFF97316),
                        Color(0xFFEC4899),
                        Color(0xFF8B5CF6)
                      ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5))
                      : Text(viewed ? '✓' : '🎨',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF17233A))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('chat.art.label'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(
                        tr(mine
                            ? 'chat.art.mine'
                            : viewed
                                ? 'chat.art.viewed'
                                : 'chat.art.tapToView'),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.visibility_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      );
}

/// ملفٌّ في الدردشة: اسمُه وحجمُه، ويُفتح بلمسة.
class _ChatFileTile extends StatelessWidget {
  const _ChatFileTile({
    required this.message,
    required this.mine,
    required this.viewed,
    required this.loading,
    required this.onTap,
  });

  final _ChatMessage message;
  final bool mine;
  final bool viewed;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        key: const ValueKey('chat-file-tile'),
        borderRadius: BorderRadius.circular(14),
        onTap: loading ? null : onTap,
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: viewed
                  ? const [Color(0xFF9CA3AF), Color(0xFFD1D5DB)]
                  : const [Color(0xFF0EA5E9), Color(0xFF22C55E)],
            ),
          ),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text(_fileEmoji(message.fileName), style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(message.fileName.isEmpty ? tr('chat.file.label') : message.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  '${message.fileSize > 0 ? '${_sizeLabel(message.fileSize)} · ' : ''}'
                  '${tr(mine ? 'chat.file.mine' : viewed ? 'chat.art.viewed' : 'chat.file.tapToOpen')}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ]),
            ),
            const Icon(Icons.folder_open_rounded, color: Colors.white),
          ]),
        ),
      );
}

/// «احفظ في الاستوديو» داخل عارض الصورة: يقول نتيجتَه في مكانه — لا في شريطٍ
/// يختفي خلف ظلّ العارض.
class _SaveToPhotosButton extends StatefulWidget {
  const _SaveToPhotosButton({required this.onSave});

  final Future<PhotoSaveResult> Function() onSave;

  @override
  State<_SaveToPhotosButton> createState() => _SaveToPhotosButtonState();
}

class _SaveToPhotosButtonState extends State<_SaveToPhotosButton> {
  bool _saving = false;
  PhotoSaveResult? _result;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _result = null;
    });
    final result = await widget.onSave();
    if (mounted) {
      setState(() {
        _saving = false;
        _result = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = _result == PhotoSaveResult.saved;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          key: const ValueKey('chat-image-save'),
          style: FilledButton.styleFrom(
            backgroundColor:
                saved ? const Color(0xFF15803D) : const Color(0xFF16A34A),
            disabledBackgroundColor: const Color(0xFF15803D),
            disabledForegroundColor: Colors.white,
          ),
          onPressed: _saving || saved ? null : () => unawaited(_save()),
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Icon(saved ? Icons.check_circle_rounded : Icons.download_rounded),
          label: Text(
              tr(saved ? 'chat.art.savedToPhotos' : 'chat.art.saveToPhotos'),
              style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        if (_result == PhotoSaveResult.denied ||
            _result == PhotoSaveResult.failed)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              tr(_result == PhotoSaveResult.denied
                  ? 'chat.art.saveDenied'
                  : 'chat.art.saveToPhotosFailed'),
              key: const ValueKey('chat-image-save-problem'),
              style: const TextStyle(
                  color: Color(0xFFFECACA), fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }
}
