import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../services/demo_mode.dart';
import '../services/duel_voice_recorder.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import '../widgets/demo_ui.dart';
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
    if (_playing != null) unawaited(StudentSoundService.instance.stopSpeaking());
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

  /// يشغّل المقطعَ على مشغّل أصوات التطبيق — كما تفعل الدردشةُ الحقيقية.
  ///
  /// ── لماذا لم يكن يُسمع ──
  /// كان لكلّ مقطعٍ مشغّلٌ خاصّ بإعدادات الحزمة الافتراضية: يطلب «تركيزَ الصوت»
  /// وحده بعد أن تركه المسجّلُ في وضع التسجيل، فيصمت أو يخرج من سمّاعة
  /// المكالمات خافتاً. ومشغّلُ التطبيق مُعدٌّ للخلط والسمّاعة الخارجية، ويُخفض
  /// الموسيقى تحت الكلام، ويُنادي بالانتهاء على كلّ حال.
  Future<void> _play(int index) async {
    final bytes = _messages[index].voice;
    if (bytes == null || _recording) return;
    final sound = StudentSoundService.instance;
    // ‏لمسةٌ ثانيةٌ على المقطع الجاري: إيقاف.
    if (_playing == index) {
      await sound.stopSpeaking();
      if (mounted) setState(() => _playing = null);
      return;
    }
    if (widget.playBytes == null && sound.muted.value) {
      _toast(tr('demo.chat.soundMuted'));
      return;
    }
    setState(() => _playing = index);
    try {
      if (widget.playBytes != null) {
        await widget.playBytes!(bytes);
      } else {
        final done = Completer<void>();
        await sound.playVoiceNote(bytes, onDone: () {
          if (!done.isCompleted) done.complete();
        });
        // ‏حدٌّ أعلى: مقطعٌ لا يُنادي بانتهائه لا يُبقي الأيقونةَ نابضة.
        await done.future.timeout(Duration(milliseconds: _messages[index].durationMs + 3000), onTimeout: () {});
      }
    } catch (_) {
      // ‏يتعذّر التشغيل: يبقى المقطعُ ظاهراً.
    } finally {
      if (mounted && _playing == index) setState(() => _playing = null);
    }
  }

  void _imagesClosed() {
    StudentSoundService.instance.play(StudentSoundCue.warning);
    showDemoDialog<void>(
      context: context,
      key: const ValueKey('demo-chat-images-closed'),
      emoji: '🖼️',
      title: tr('demo.chat.imagesTitle'),
      body: Text(tr('demo.chat.imagesBody'), textAlign: TextAlign.center),
      actions: [
        if (widget.onGetAccount != null)
          DemoGradientButton(
            label: tr('demo.getAccount'),
            icon: Icons.workspace_premium_rounded,
            shimmer: true,
            onPressed: () {
              Navigator.pop(context);
              widget.onGetAccount!();
            },
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('demo.ok'))),
      ],
    );
  }

  Widget _roundButton({required Key key, required IconData icon, required VoidCallback onTap, required Gradient gradient, String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: DemoPressable(
        key: key,
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: gradient,
            boxShadow: [BoxShadow(color: gradient.colors.last.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leftTexts = DemoMode.chatTexts - _texts;
    final leftVoices = DemoMode.chatVoices - _voices;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Scaffold(
        backgroundColor: StudentSurface.ground(context),
        appBar: AppBar(
          foregroundColor: Colors.white,
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: DemoPalette.violetGradient)),
          title: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: DemoPalette.goldGradient,
                border: Border.all(color: Colors.white, width: 2),
              ),
              alignment: Alignment.center,
              child: const Text('🤖', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('demo.chat.friend'),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(tr('demo.chat.friendSub'),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ]),
            ),
          ]),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              // ‏على التابلت والأيباد تبقى المحادثةُ في عمودٍ مريحٍ للقراءة.
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(children: [
                Container(
                  key: const ValueKey('demo-chat-quota'),
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: DemoPalette.goldGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: DemoPalette.gold.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Text(
                    trf('demo.chat.quota', {'texts': '$leftTexts', 'voices': '$leftVoices'}),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w900, color: DemoPalette.goldInk),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(builder: (context, box) {
                    final bubbleMax = math.min(420.0, box.maxWidth * 0.78);
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        return Align(
                          alignment: m.mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
                          child: DemoEntrance(
                            index: 0,
                            child: Container(
                              key: ValueKey('demo-chat-message-$i'),
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(maxWidth: bubbleMax),
                              decoration: BoxDecoration(
                                gradient: m.mine ? DemoPalette.violetGradient : null,
                                color: m.mine ? null : (dark ? const Color(0xFF2A1C40) : Colors.white),
                                borderRadius: BorderRadius.circular(20),
                                border: m.mine ? null : Border.all(color: DemoPalette.gold.withValues(alpha: 0.55), width: 1.4),
                                boxShadow: [
                                  BoxShadow(
                                    color: (m.mine ? DemoPalette.violet : DemoPalette.gold).withValues(alpha: 0.18),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
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
                                        height: 1.45,
                                        color: m.mine ? Colors.white : StudentSurface.ink(context),
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF221536) : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: DemoPalette.violet.withValues(alpha: 0.3)),
                    boxShadow: [BoxShadow(color: DemoPalette.violet.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 4))],
                  ),
                  child: Row(children: [
                    IconButton(
                      key: const ValueKey('demo-chat-image'),
                      tooltip: tr('demo.chat.imagesTitle'),
                      onPressed: _imagesClosed,
                      icon: const Icon(Icons.image_not_supported_outlined, color: DemoPalette.violet),
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
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _roundButton(
                      key: const ValueKey('demo-chat-voice'),
                      icon: _recording ? Icons.stop_rounded : Icons.mic_rounded,
                      gradient: _recording
                          ? const LinearGradient(colors: [Color(0xFFF87171), Color(0xFFDC2626)])
                          : DemoPalette.goldGradient,
                      onTap: () => unawaited(_toggleVoice()),
                    ),
                    const SizedBox(width: 6),
                    _roundButton(
                      key: const ValueKey('demo-chat-send'),
                      icon: Icons.send_rounded,
                      gradient: DemoPalette.violetGradient,
                      onTap: _sendText,
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
