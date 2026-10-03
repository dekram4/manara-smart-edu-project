import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/student_strings.dart';
import '../models/duel_chat.dart';
import '../services/duel_voice_recorder.dart';
import '../services/student_duel_service.dart';
import '../services/student_sound_service.dart';
import 'duel_chat.dart';

/// التواصلُ داخل النزال: رسالةٌ صوتيةٌ بالضغط المطوّل، وتفاعلاتٌ سريعةٌ تطير على
/// شاشات الجميع، وفقاعةٌ فوق الشخصية لما يصل، وكتم.
///
/// ── ولا دردشةَ كتابية ──
/// الكتابةُ تشغل الطفلَ عن السؤال وهو في مباراةٍ بالثواني، ولا رقيبَ على ما يُكتب
/// فيها. فالصوتُ والتفاعلاتُ وحدهما: يُرسلان بضغطة، ويُفهمان بنظرة.
mixin DuelChatMixin<T extends StatefulWidget> on State<T> {
  StudentDuelService get chatService;
  String get chatMyId;
  String get chatMatchId;
  Map<String, dynamic>? get chatMyAppearance;
  Map<String, dynamic>? get chatRivalAppearance;

  /// شخصيةُ من أرسل — في تحدٍّ جماعي ليس المنافسَ الأوّلَ دائماً.
  Map<String, dynamic>? chatAppearanceOf(String studentId) =>
      chatRivalAppearance;

  /// اسمُ من أرسل، يُكتب تحت تفاعله الطائر.
  String chatNameOf(String studentId) => '';

  DuelChatMuteState _mute = const DuelChatMuteState();

  final _cooldown = DuelChatCooldown();

  late final DuelVoiceRecorder _recorder = DuelVoiceRecorder();
  final ValueNotifier<bool> _recording = ValueNotifier(false);

  /// آخرُ ما أرسلتُه وآخرُ ما وصلني، وكلٌّ يعيش ثلاثَ ثوانٍ فوق الشخصية.
  DuelChatMessage? _myBubble;
  DuelChatMessage? _theirBubble;
  Timer? _myBubbleTimer;
  Timer? _theirBubbleTimer;

  bool _playingTheirs = false;

  /// التفاعلاتُ الطائرة.
  final DuelReactionController reactions = DuelReactionController();

  /// آخرُ تفاعلٍ أرسلتُه: ضغطٌ متتابعٌ لا يُغرق الغرفة.
  DateTime _lastReaction = DateTime.fromMillisecondsSinceEpoch(0);
  static const _reactionGap = Duration(milliseconds: 450);

  void _toggleMute() {
    final next = !_mute.isChatMuted;
    setState(() {
      _mute = _mute.copyWith(isChatMuted: next);
      if (next) {
        _theirBubble = null;
        _playingTheirs = false;
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
    if (muted && !was && _mute.warnsRivalMuted) {
      _say(tr('duel.chat.rivalMuted'));
    }
  }

  /// رسالةٌ وصلت. والصوتُ يُشغَّل فوراً.
  void _onChat(DuelChatMessage message) {
    if (!mounted) return;
    if (message.senderId == chatMyId) return;
    if (!_mute.showsIncoming) {
      chatService.sendChatMute(myId: chatMyId, muted: true);
      return;
    }
    _showBubble(message, mine: false);
    if (message.isVoice && _mute.playsIncomingVoice) _playVoice(message);
  }

  /// تفاعلٌ وصل: يطير على الشاشة باسم صاحبه.
  void _onReaction(String studentId, String emoji) {
    if (!mounted || studentId == chatMyId || !_mute.showsIncoming) return;
    reactions.pop(emoji, who: chatNameOf(studentId));
  }

  /// أضغط تفاعلاً: يطير عندي فوراً، ويُبثّ إلى الجميع.
  void _react(String emoji) {
    if (!_mute.canSend) {
      _say(tr('duel.chat.mutedSelf'));
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastReaction) < _reactionGap) return;
    _lastReaction = now;
    HapticFeedback.selectionClick();
    reactions.pop(emoji, who: tr('duel.you'), mine: true);
    chatService.sendReaction(myId: chatMyId, emoji: emoji);
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
      _say(tr('duel.chat.notSent'));
      return false;
    }
    // يُبثّ لمن في الغرفة الآن، ويُحفظ في سجلّ المباراة.
    chatService.sendChat(message);
    unawaited(chatService.saveMessage(matchId: chatMatchId, message: message));
    _showBubble(message, mine: true);
    if (_mute.warnsRivalMuted) _say(tr('duel.chat.rivalMuted'));
    return true;
  }

  Future<void> _startHold() async {
    if (_recording.value) return;
    if (!_mute.canSend) {
      _say(tr('duel.chat.mutedSelf'));
      return;
    }
    if (!_cooldown.ready) {
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

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// يُستدعى من initState في الشاشة.
  void initChat() {
    _recorder.onAutoStop = () => _endHold(cancelled: false);
  }

  /// يُستدعى من dispose في الشاشة.
  void disposeChat() {
    _myBubbleTimer?.cancel();
    _theirBubbleTimer?.cancel();
    _recording.dispose();
    reactions.dispose();
    unawaited(_recorder.dispose());
  }

  /// يمرّ بها البثُّ: رسالةٌ وصلت، وتفاعل، وكتمٌ أعلنه زميل.
  void onChatMessage(DuelChatMessage message) => _onChat(message);
  void onReaction(String studentId, String emoji) =>
      _onReaction(studentId, emoji);
  void onRivalMute(String studentId, bool muted) =>
      _onRivalMute(studentId, muted);

  /// زرُّ الكتم العائم.
  Widget chatButtons() =>
      DuelMuteToggle(muted: _mute.isChatMuted, onPressed: _toggleMute);

  /// زرُّ الرسالة الصوتية — تحت الخيارات.
  Widget voiceButton() => DuelVoiceButton(
        recording: _recording,
        onHoldStart: () => unawaited(_startHold()),
        onHoldEnd: ({required bool cancelled}) =>
            unawaited(_endHold(cancelled: cancelled)),
      );

  /// شريطُ التفاعلات السريعة.
  Widget reactionBar() => DuelReactionBar(onReact: _react);

  /// الطبقةُ التي تطير فيها التفاعلات.
  Widget reactionLayer() => DuelReactionLayer(controller: reactions);

  /// الفقاعتان فوق الشخصيتين.
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
                appearance: _theirBubble == null
                    ? chatRivalAppearance
                    : chatAppearanceOf(_theirBubble!.senderId),
                mine: false,
                speaking: _playingTheirs,
              ),
            ],
          ),
        ),
      );
}
