import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Short non-verbal effects available to student screens, games, and
/// animations. Their source paths intentionally point to the established
/// audio catalog until new licensed files are added to `assets/sounds/`.
enum AudioEffect {
  success,
  feedback,
}

/// Plays short feedback without affecting narration or lesson audio.
///
/// This service shares the app's mute notifier, treats sound as optional, and
/// safely absorbs platform or missing-asset failures so feedback never blocks
/// a student action.
class AudioService {
  AudioService({
    required ValueListenable<bool> muted,
    AudioPlayer? player,
  })  : _muted = muted,
        _player = player ?? AudioPlayer();

  final ValueListenable<bool> _muted;
  final AudioPlayer _player;
  var _initialized = false;

  static String assetFor(AudioEffect effect) => switch (effect) {
        AudioEffect.success => 'audio/success-reward.wav',
        AudioEffect.feedback => 'audio/gentle-warning.wav',
      };

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
    } catch (_) {
      // The UI remains usable if the platform audio backend is unavailable.
    }
  }

  Future<void> playSuccess() => play(AudioEffect.success);

  Future<void> playFeedback() => play(AudioEffect.feedback);

  Future<void> play(AudioEffect effect) async {
    if (_muted.value) return;
    await initialize();

    try {
      await _player.stop();
      await _player.play(
        AssetSource(assetFor(effect)),
        volume: effect == AudioEffect.success ? 0.56 : 0.48,
      );
    } catch (_) {
      // Missing optional assets must not prevent a student interaction.
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {
      // No action is needed when a player has not started.
    }
  }

  Future<void> dispose() => _player.dispose();
}