import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StudentSoundCue {
  navigation,
  answerSelected,
  success,
  warning,
  loginSuccess,
  welcome,
  gameReward,
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
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      muted.value = preferences.getBool(_mutedKey) ?? false;
      await _effectsPlayer.setReleaseMode(ReleaseMode.stop);
      await _voicePlayer.setReleaseMode(ReleaseMode.stop);
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
      if (cue == StudentSoundCue.gameReward) {
        // Flame Audio is reserved for game moments so native Flame games can
        // use the same audio asset catalog as the surrounding student app.
        await FlameAudio.play('success-reward.wav', volume: 0.62);
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
      };
      await player.stop();
      await player.play(AssetSource(asset), volume: isVoice ? 0.78 : 0.56);
    } catch (_) {
      // Audio is an enhancement and must never block a lesson or assessment.
    }
  }
}