import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../services/demo_mode.dart';
import '../services/duel_voice_recorder.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import '../widgets/chat_voice.dart';

/// دردشةُ الزائر: محادثةٌ مع حسابٍ افتراضيّ («منار») على الجهاز وحده.
///
/// لا خادمَ ولا زملاء: يكتب الزائرُ رسالتين ويرسل مقطعين صوتيين، فيردّ منار
/// على كلٍّ منها — ليعرف كيف تعمل الدردشة. والصورُ مغلقةٌ برسالةٍ تشرح أنها
/// للمشتركين. وما يُكتب هنا لا يغادر الجهاز.
class DemoChatScreen extends StatefulWidget {
  const DemoChatScreen({super.key, this.recorder, this.playBytes, this.onGetAccount});

  /// للاختبار: المسجّل، والمشغّل.
  final DuelVoiceRecorder? recorder;
  final Future<void> Function(Uint8List bytes)? playBytes;

  /// «احصل على حساب رسمي».
  final VoidCallback? onGetAccount;

  @override
  State<DemoChatScreen> createState() => DemoChatScreenState();
}

class _DemoMessage {
  _DemoMessage({required this.mine, this.text, this.voice, this.durationMs = 0});

  final bool mine;
  final String? text;
  final Uint8List? voice;
  final int durationMs;
}

class DemoChatScreenState extends State<DemoChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final DuelVoiceRecorder _recorder =
      widget.recorder ?? DuelVoiceRecorder(maxDuration: const Duration(seconds: 15), maxBytes: chatVoiceMaxBytes);
  AudioPlayer? _ownPlayer;
  final List<_DemoMessage> _messages = [];
  int _texts = 0;
  int _voices = 0;
  bool _recording = false;
  int? _playing;
  final _clock = Stopwatch();

  @visibleForTesting
  int get textsSent => _texts;
  @visibleForTesting
  int get voicesSent => _voices;
  @visibleForTesting
  int get messageCount => _messages.length;

  static const _replies = [
    'أهلاً! أنا منار 👋 سعيدٌ بالحديث معك.',
    'رائع! في الحساب الرسمي تراسل زملاءك ومعلّمك أيضاً ✨',
  ];
  static const _voiceReplies = [
    'وصلني صوتُك واضحاً 🎤 جميل!',
    'صوتٌ رائع! المشتركون يرسلون صوتاً وصوراً وملفّات 📎',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(_DemoMessage(mine: false, text: tr('demo.chat.welcome')));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _ownPlayer?.dispose();
    if (_recording) unawaited(_recorder.cancel());
    super.dispose();
  }

  void _toast(String text) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));
  }

  void _reply(String text) {
    Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _messages.add(_DemoMessage(mine: false, text: text)));
      _scrollDown();
    });
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _sendText() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    if (_texts >= DemoMode.chatTexts) {
      _toast(tr('demo.chat.textLimit'));
      return;
    }
    StudentSoundService.instance.playTap();
    setState(() {
      _messages.add(_DemoMessage(mine: true, text: text));
      _input.clear();
    });
    _reply(_replies[math.min(_texts, _replies.length - 1)]);
    _texts++;
    _scrollDown();
  }

  Future<void> _toggleVoice() async {
    if (!_recording && _voices >= DemoMode.chatVoices) {
      _toast(tr('demo.chat.voiceLimit'));
      return;
    }
    if (!_recording) {
      final began = await _recorder.start();
      if (!mounted) return;
      if (!began) {
        _toast(tr('demo.chat.noMic'));
        return;
      }
      _clock
        ..reset()
        ..start();
      setState(() => _recording = true);
      return;
    }
    final note = await _recorder.stop();
    _clock.stop();
    if (!mounted) return;
    setState(() => _recording = false);
    if (!note.ok) {
      _toast(tr('demo.chat.tooShort'));
      return;
    }
    setState(() => _messages.add(_DemoMessage(mine: true, voice: note.bytes, durationMs: _clock.elapsedMilliseconds)));
    _reply(_voiceReplies[math.min(_voices, _voiceReplies.length - 1)]);
    _voices++;
    _scrollDown();
  }

  Future<void> _play(int index) async {
    final bytes = _messages[index].voice;
    if (bytes == null) return;
    setState(() => _playing = index);
    try {
      if (widget.playBytes != null) {
        await widget.playBytes!(bytes);
      } else {
        final player = _ownPlayer ??= AudioPlayer();
        await player.play(BytesSource(bytes));
        await player.onPlayerComplete.first.timeout(const Duration(seconds: 20), onTimeout: () {});
      }
    } catch (_) {
      // ‏يتعذّر التشغيل: يبقى المقطعُ ظاهراً.
    } finally {
      if (mounted) setState(() => _playing = null);
    }
  }

  void _imagesClosed() {
    StudentSoundService.instance.play(StudentSoundCue.warning);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('demo-chat-images-closed'),
        title: Text('🖼️ ${tr('demo.chat.imagesTitle')}'),
        content: Text(tr('demo.chat.imagesBody')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('demo.ok'))),
          if (widget.onGetAccount != null)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onGetAccount!();
              },
              child: Text(tr('demo.getAccount')),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leftTexts = DemoMode.chatTexts - _texts;
    final leftVoices = DemoMode.chatVoices - _voices;
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Scaffold(
        backgroundColor: StudentSurface.ground(context),
        appBar: AppBar(
          title: Row(children: [
            const CircleAvatar(backgroundColor: Color(0xFFFDE68A), child: Text('🤖')),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('demo.chat.friend'), style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(tr('demo.chat.friendSub'), style: const TextStyle(fontSize: 12)),
              ]),
            ),
          ]),
        ),
        body: SafeArea(
          child: Column(children: [
            Container(
              key: const ValueKey('demo-chat-quota'),
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
              child: Text(
                trf('demo.chat.quota', {'texts': '$leftTexts', 'voices': '$leftVoices'}),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final m = _messages[i];
                  return Align(
                    alignment: m.mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
                    child: Container(
                      key: ValueKey('demo-chat-message-$i'),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      constraints: const BoxConstraints(maxWidth: 320),
                      decoration: BoxDecoration(
                        color: m.mine ? const Color(0xFF2563EB) : StudentSurface.card(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: StudentSurface.outline(context)),
                      ),
                      child: m.voice != null
                          ? ChatVoiceNoteView(
                              seed: 'demo-$i',
                              duration: Duration(milliseconds: m.durationMs),
                              playing: _playing == i,
                              loading: false,
                              mine: m.mine,
                              onTap: () => unawaited(_play(i)),
                            )
                          : Text(
                              m.text ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: m.mine ? Colors.white : StudentSurface.ink(context),
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(children: [
                IconButton(
                  key: const ValueKey('demo-chat-image'),
                  tooltip: tr('demo.chat.imagesTitle'),
                  onPressed: _imagesClosed,
                  icon: const Icon(Icons.image_not_supported_outlined),
                ),
                Expanded(
                  child: TextField(
                    key: const ValueKey('demo-chat-input'),
                    controller: _input,
                    enabled: !_recording,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendText(),
                    decoration: InputDecoration(
                      hintText: tr('demo.chat.hint'),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('demo-chat-voice'),
                  onPressed: () => unawaited(_toggleVoice()),
                  icon: Icon(_recording ? Icons.stop_circle_rounded : Icons.mic_rounded,
                      color: _recording ? const Color(0xFFDC2626) : null),
                ),
                IconButton(
                  key: const ValueKey('demo-chat-send'),
                  onPressed: _sendText,
                  icon: const Icon(Icons.send_rounded),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
