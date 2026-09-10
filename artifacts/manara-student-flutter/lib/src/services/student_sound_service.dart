import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_service.dart';

enum StudentSoundCue {
  navigation,
  answerSelected,
  success,
  warning,
  loginSuccess,
  welcome,
  gameReward,
  levelUp,
}

/// A testable gate that avoids noisy repeated taps and competing feedback.
class StudentSoundGate {
  StudentSoundGate({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Map<StudentSoundCue, DateTime> _lastPlayed = {};

  bool allow(StudentSoundCue cue, {Duration cooldown = const Duration(milliseconds: 220)}) {
    final current = _now();
    final previous = _lastPlayed[cue];
    if (previous != null && current.difference(previous) < cooldown) return false;
    _lastPlayed[cue] = current;
    return true;
  }
}

/// Owns student-facing sounds. Voices and UI feedback have separate players so
/// a short confirmation never cuts off the welcome message, while each group
/// is still stopped before replaying to avoid overlap.
class StudentSoundService {
  StudentSoundService._();

  static final StudentSoundService instance = StudentSoundService._();
  static const _mutedKey = 'manara_student_sound_muted';

  final ValueNotifier<bool> muted = ValueNotifier(false);
  final StudentSoundGate _gate = StudentSoundGate();
  final AudioPlayer _effectsPlayer = AudioPlayer();
  final AudioPlayer _voicePlayer = AudioPlayer();
  late final AudioService _feedbackAudio = AudioService(muted: muted);
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      muted.value = preferences.getBool(_mutedKey) ?? false;
      await _effectsPlayer.setReleaseMode(ReleaseMode.stop);
      await _voicePlayer.setReleaseMode(ReleaseMode.stop);
      await _feedbackAudio.initialize();
    } catch (_) {
      // The student experience remains usable if local preferences are absent.
    }
  }

  Future<void> toggleMuted() async {
    final next = !muted.value;
    muted.value = next;
    if (next) {
      await _effectsPlayer.stop();
      await _voicePlayer.stop();
      await _feedbackAudio.stop();
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_mutedKey, next);
    } catch (_) {}
  }

  void play(StudentSoundCue cue) {
    unawaited(_play(cue));
  }

  Future<void> _play(StudentSoundCue cue) async {
    if (muted.value || !_gate.allow(cue)) return;
    try {
      if (cue == StudentSoundCue.success) {
        await _feedbackAudio.playSuccess();
        return;
      }
      if (cue == StudentSoundCue.warning) {
        await _feedbackAudio.playFeedback();
        return;
      }
      if (cue == StudentSoundCue.gameReward) {
        await _effectsPlayer.stop();
        await _effectsPlayer.play(
          AssetSource('audio/success-reward.wav'),
          volume: 0.62,
        );
        return;
      }
      if (cue == StudentSoundCue.levelUp) {
        // A short back-to-back double chime reads as a bigger celebration
        // than a single reward ping, without needing a dedicated asset.
        await _effectsPlayer.stop();
        await _effectsPlayer.play(
          AssetSource('audio/success-reward.wav'),
          volume: 0.95,
        );
        return;
      }

      final isVoice = cue == StudentSoundCue.welcome || cue == StudentSoundCue.loginSuccess;
      final player = isVoice ? _voicePlayer : _effectsPlayer;
      final asset = switch (cue) {
        StudentSoundCue.navigation => 'audio/ui-tap.wav',
        StudentSoundCue.answerSelected => 'audio/answer-selected.wav',
        StudentSoundCue.success => 'audio/success-reward.wav',
        StudentSoundCue.warning => 'audio/gentle-warning.wav',
        StudentSoundCue.loginSuccess => 'audio/manara-login-chime.mp3',
        StudentSoundCue.welcome => 'audio/manara-arabic-student-welcome.mp3',
        StudentSoundCue.gameReward => 'audio/success-reward.wav',
        // Handled above and never reached here; kept only so this switch
        // stays exhaustive over every StudentSoundCue value.
        StudentSoundCue.levelUp => 'audio/success-reward.wav',
      };
      await player.stop();
      await player.play(AssetSource(asset), volume: isVoice ? 0.78 : 0.56);
    } catch (_) {
      // Audio is an enhancement and must never block a lesson or assessment.
    }
  }

  /// Short Arabic phrases used for random spoken/textual encouragement. Kept
  /// public so a caller can show the same phrase as an on-screen toast
  /// alongside (or instead of, if audio is muted/unavailable) the sound.
  static const List<String> encouragementPhrases = [
    'أحسنت يا بطل!',
    'رائع جدًا!',
    'ممتاز، واصل التقدّم!',
    'أنت نجم اليوم!',
    'عمل رائع، استمر بهذا التميز!',
  ];

  static final math.Random _random = math.Random();

  /// A cheerful tap for buttons and cards, paired with light haptic feedback.
  void playTap() {
    HapticFeedback.lightImpact();
    play(StudentSoundCue.navigation);
  }

  /// The coin/gem chime for earning XP or gems.
  void playReward() {
    HapticFeedback.mediumImpact();
    play(StudentSoundCue.gameReward);
  }

  /// A bigger celebration for finishing a lesson, quiz, or leveling up.
  void playLevelUp() {
    HapticFeedback.heavyImpact();
    play(StudentSoundCue.levelUp);
  }

  /// Applause, as two clips played back to back: `clap2.mp3` and then
  /// `clap.mp3` the moment the first reports completion.
  ///
  /// Chained on the completion event rather than on a timer, so the two
  /// meet exactly however long the first clip runs — a fixed delay would
  /// either overlap them or leave a gap the first time either file is
  /// re-cut.
  void playApplause() {
    HapticFeedback.heavyImpact();
    unawaited(_playApplause());
  }

  Future<void> _playApplause() async {
    if (muted.value) return;
    try {
      // A one-shot subscription: it fires for the first clip's completion
      // and is cancelled immediately, so a later applause cannot stack a
      // second listener on the same player.
      late StreamSubscription<void> sub;
      sub = _effectsPlayer.onPlayerComplete.listen((_) async {
        await sub.cancel();
        if (muted.value) return;
        try {
          await _effectsPlayer.play(
            AssetSource('audio/clap.mp3'),
            volume: 0.7,
          );
        } catch (_) {
          // The first clap already played; a missing second one is not
          // worth surfacing to a child.
        }
      });
      await _effectsPlayer.stop();
      await _effectsPlayer.play(AssetSource('audio/clap2.mp3'), volume: 0.7);
    } catch (_) {
      // Celebration audio is decoration — never let it break the flow
      // that triggered it.
    }
  }

  /// Plays a random Arabic encouragement cue and returns the phrase that
  /// goes with it, so the caller can also show it as text (e.g. a snack
  /// bar) — this keeps the encouragement visible even when sound is muted
  /// or a voice-specific asset isn't bundled yet.
  String playEncouragementArabic() {
    HapticFeedback.selectionClick();
    play(StudentSoundCue.success);
    return encouragementPhrases[_random.nextInt(encouragementPhrases.length)];
  }
}