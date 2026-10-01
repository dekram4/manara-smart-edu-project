import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../models/duel_chat.dart';
import '../services/duel_voice_recorder.dart';
import '../services/student_duel_service.dart';
import '../services/student_sound_service.dart';
import 'duel_chat.dart';

/// الدردشةُ داخل المباراة: نصٌّ وإيموجي ومقاطعُ صوت، وكتمٌ، وفقاعاتٌ فوق
/// الشخصيتين، وسجلٌّ يُقرأ.
///
/// ── ولماذا مزيجٌ لا شاشة ──
/// الدردشةُ تعيش في المباراة وحدها — لا في الساحة — لكنّ منطقها كلَّه (الفاصل
/// بين الرسائل، والكتم، والتسجيل بالضغط المطوّل، والبثّ والحفظ معاً) لا شأنَ له
/// بالأسئلة. فيُكتب مرّةً هنا، وتلبسه شاشةُ المباراة.
mixin DuelChatMixin<T extends StatefulWidget> on State<T> {
  StudentDuelService get chatService;
  String get chatMyId;
  String get chatMatchId;
  Map<String, dynamic>? get chatMyAppearance;
  Map<String, dynamic>? get chatRivalAppearance;

  DuelChatMuteState _mute = const DuelChatMuteState();

  final _cooldown = DuelChatCooldown();
  final ValueNotifier<Duration> _cooldownLeft = ValueNotifier(Duration.zero);
  Timer? _cooldownTick;

  late final DuelVoiceRecorder _recorder = DuelVoiceRecorder();
  final ValueNotifier<bool> _recording = ValueNotifier(false);

  /// سجلُّ المحادثة: ما قُرئ من الخادم وما جرى في هذه الجلسة.
  final List<DuelChatMessage> _transcript = [];
  bool _loadingChat = false;

  /// آخرُ ما أرسلتُه وآخرُ ما وصلني، وكلٌّ يعيش ثلاثَ ثوانٍ فوق الشخصية.
  DuelChatMessage? _myBubble;
  DuelChatMessage? _theirBubble;
  Timer? _myBubbleTimer;
  Timer? _theirBubbleTimer;

  bool _playingTheirs = false;
  bool _unread = false;
  bool _sheetOpen = false;

  Future<void> _loadChat() async {
    setState(() => _loadingChat = true);
    try {
      final stored = await chatService.messages(chatMatchId);
      if (!mounted) return;
      setState(() {
        _transcript
          ..clear()
          ..addAll(stored);
        _loadingChat = false;
        // ── ونقطةٌ إن تُرك لي شيء ──
        // المبارزةُ المؤجَّلةُ يفتحها الطفلُ فيجد رسالةً من أمسِ: بلا نقطةٍ
        // لا يعرف أنّ هناك ما يُقرأ، فلا يفتح النافذةَ أبداً.
        _unread = stored.any((message) => message.senderId != chatMyId);
      });
      // وتُشغَّل آخرُ رسالةٍ صوتيةٍ تُركت لي، مرّةً واحدة.
      final mine = chatMyId;
      for (final message in stored.reversed) {
        if (message.senderId != mine && message.isVoice) {
          _playVoice(message);
          break;
        }
      }
    } catch (_) {
      if (!mounted) return;
      // سجلٌّ لم يُقرأ لا يُسقط مباراة: تُفتح الدردشةُ فارغةً وتعمل.
      setState(() => _loadingChat = false);
    }
  }

  void _toggleMute() {
    final next = !_mute.isChatMuted;
    setState(() {
      _mute = _mute.copyWith(isChatMuted: next);
      if (next) {
        _theirBubble = null;
        _playingTheirs = false;
        _unread = false;
      }
    });
    _theirBubbleTimer?.cancel();
    if (next) {
      unawaited(StudentSoundService.instance.stopSpeaking());
      unawaited(_endHold(cancelled: true));
    }
    chatService.sendChatMute(myId: chatMyId, muted: next);
    _say(tr(next ? 'duel.chat.mutedOn' : 'duel.chat.mutedOff'));
  }

  void _onRivalMute(String studentId, bool muted) {
    if (!mounted || studentId == chatMyId) return;
    final was = _mute.isRivalMuted;
    setState(() => _mute = _mute.copyWith(isRivalMuted: muted));
    if (muted && !was && _mute.warnsRivalMuted) _say(tr('duel.chat.rivalMuted'));
  }

  void _onChat(DuelChatMessage message) {
    if (!mounted) return;
    if (message.senderId == chatMyId) return;
    if (!_mute.showsIncoming) {
      chatService.sendChatMute(myId: chatMyId, muted: true);
      return;
    }
    // ── والبثُّ يُضاف إلى السجلّ أيضاً ──
    // الخادم يحفظها، لكنّ إعادةَ قراءةِ السجلّ لكل رسالةٍ تصل طلبٌ في كل
    // إيموجي. فتُضاف هنا، ويُعرف تكرارُها بمعرّفها إن أُعيدت القراءة.
    setState(() => _transcript.add(message));
    _showBubble(message, mine: false);
    if (!_sheetOpen) setState(() => _unread = true);
    if (message.isVoice && _mute.playsIncomingVoice) _playVoice(message);
  }

  void _playVoice(DuelChatMessage message) {
    final audio = message.audio;
    if (audio == null || !_mute.playsIncomingVoice) return;
    setState(() => _playingTheirs = true);
    unawaited(
      StudentSoundService.instance.playVoiceNote(
        audio,
        onDone: () {
          if (mounted) setState(() => _playingTheirs = false);
        },
      ),
    );
  }

  void _showBubble(DuelChatMessage message, {required bool mine}) {
    setState(() {
      if (mine) {
        _myBubble = message;
      } else {
        _theirBubble = message;
      }
    });
    final timer = Timer(duelBubbleLife, () {
      if (!mounted) return;
      setState(() {
        if (mine) {
          _myBubble = null;
        } else {
          _theirBubble = null;
          _playingTheirs = false;
        }
      });
    });
    if (mine) {
      _myBubbleTimer?.cancel();
      _myBubbleTimer = timer;
    } else {
      _theirBubbleTimer?.cancel();
      _theirBubbleTimer = timer;
    }
  }

  bool _send(DuelChatMessage message) {
    if (!_mute.canSend) {
      _say(tr('duel.chat.mutedSelf'));
      return false;
    }
    if (!_cooldown.claim()) {
      _startCooldownTick();
      return false;
    }
    // ── والبثُّ والحفظُ معاً، وسقوطُ أحدهما لا يُسقط الآخر ──
    // البثُّ للحاضر الآن، والحفظُ لمن يفتح لاحقاً. ورسالةٌ وصلت ولم تُحفظ
    // خيرٌ من لا شيء، ورسالةٌ حُفظت ولم تُبثّ تُقرأ عند الفتح.
    chatService.sendChat(message);
    unawaited(
      chatService.saveMessage(
        matchId: chatMatchId,
        message: message,
      ),
    );
    setState(() => _transcript.add(message));
    _showBubble(message, mine: true);
    _startCooldownTick();
    if (_mute.warnsRivalMuted) _say(tr('duel.chat.rivalMuted'));
    return true;
  }

  void _startCooldownTick() {
    _cooldownTick?.cancel();
    void beat() {
      final left = _cooldown.remaining;
      _cooldownLeft.value = left;
      if (left == Duration.zero) _cooldownTick?.cancel();
    }

    beat();
    _cooldownTick =
        Timer.periodic(const Duration(milliseconds: 250), (_) => beat());
  }

  Future<void> _startHold() async {
    if (_recording.value) return;
    if (!_mute.canSend) {
      _say(tr('duel.chat.mutedSelf'));
      return;
    }
    if (!_cooldown.ready) {
      _startCooldownTick();
      _say(tr('duel.chat.notSent'));
      return;
    }
    final began = await _recorder.start();
    if (!mounted) return;
    if (!began) {
      _say(tr('duel.chat.noMic'));
      return;
    }
    _recording.value = true;
  }

  Future<void> _endHold({required bool cancelled}) async {
    if (!_recording.value) return;
    _recording.value = false;
    if (cancelled) {
      await _recorder.cancel();
      return;
    }
    final note = await _recorder.stop();
    if (!mounted) return;
    if (!note.ok) {
      _say(switch (note.problem) {
        VoiceNoteProblem.tooShort => tr('duel.chat.tooShort'),
        VoiceNoteProblem.tooBig => tr('duel.chat.tooBig'),
        VoiceNoteProblem.noPermission => tr('duel.chat.noMic'),
        _ => tr('duel.chat.notSent'),
      });
      return;
    }
    _send(
      DuelChatMessage(
        senderId: chatMyId,
        kind: DuelChatKind.voice,
        audio: note.bytes,
      ),
    );
  }

  void _openChat() {
    setState(() {
      _sheetOpen = true;
      _unread = false;
    });
    _startCooldownTick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DuelChatSheet(
        recording: _recording,
        cooldownLeft: _cooldownLeft,
        muted: _mute.isChatMuted,
        onUnmute: () {
          Navigator.of(context).pop();
          _toggleMute();
        },
        transcript: _transcript,
        myId: chatMyId,
        loadingTranscript: _loadingChat,
        onPlay: _playVoice,
        onSendText: (text) => _send(
          DuelChatMessage(
            senderId: chatMyId,
            kind: DuelChatKind.text,
            text: text,
          ),
        ),
        onHoldStart: () => unawaited(_startHold()),
        onHoldEnd: ({required cancelled}) =>
            unawaited(_endHold(cancelled: cancelled)),
      ),
    ).whenComplete(() {
      unawaited(_endHold(cancelled: true));
      if (mounted) setState(() => _sheetOpen = false);
    });
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// يُستدعى من initState في الشاشة.
  void initChat() {
    unawaited(_loadChat());
    _recorder.onAutoStop = () => _endHold(cancelled: false);
  }

  /// يُستدعى من dispose في الشاشة.
  void disposeChat() {
    _cooldownTick?.cancel();
    _myBubbleTimer?.cancel();
    _theirBubbleTimer?.cancel();
    _cooldownLeft.dispose();
    _recording.dispose();
    unawaited(_recorder.dispose());
  }

  /// يمرّ بها البثُّ: رسالةٌ وصلت، وكتمٌ أعلنه الزميل.
  void onChatMessage(DuelChatMessage message) => _onChat(message);
  void onRivalMute(String studentId, bool muted) => _onRivalMute(studentId, muted);

  /// زرّا الدردشة والكتم، والفقاعتان فوق الشخصيتين.
  Widget chatButtons() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DuelMuteToggle(muted: _mute.isChatMuted, onPressed: _toggleMute),
          const SizedBox(height: 10),
          DuelChatButton(
            onPressed: _openChat,
            unread: _unread,
            muted: _mute.isChatMuted,
          ),
        ],
      );

  Widget chatBubbles() => IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DuelSpeechBubble(
                message: _myBubble,
                appearance: chatMyAppearance,
                mine: true,
                speaking: false,
              ),
              const Spacer(),
              DuelSpeechBubble(
                message: _theirBubble,
                appearance: chatRivalAppearance,
                mine: false,
                speaking: _playingTheirs,
              ),
            ],
          ),
        ),
      );
}
