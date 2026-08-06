import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';

/// نقطة واحدة لكل الأصوات حتى يمكن استبدال الملفات التجريبية بصوت المنصة
/// دون ربط الواجهات بتفاصيل مكتبة الصوت.
class ManaraAudioService {
  ManaraAudioService._();
  static final instance = ManaraAudioService._();
  final AudioPlayer _player = AudioPlayer();
  final Set<String> _unavailableAssets = {};

  Future<void> playTap() async {
    await HapticFeedback.selectionClick();
  }

  Future<void> playReward() async {
    await HapticFeedback.mediumImpact();
  }

  Future<void> playSuccess() async {
    await HapticFeedback.heavyImpact();
  }

  Future<void> playError() async {
    await HapticFeedback.vibrate();
  }

  Future<void> playWelcome({bool forStudent = false}) {
    return _playAsset(
      forStudent ? 'assets/audio/welcome-student.mp3' : 'assets/audio/welcome-adult.mp3',
    );
  }

  Future<void> _playAsset(String asset) async {
    if (_unavailableAssets.contains(asset)) return;
    try {
      await _player.setAsset(asset);
      await _player.play();
    } catch (_) {
      // Assets are optional until the final sound pack is supplied. Remember
      // missing files so offline taps do not repeatedly trigger failed loads.
      _unavailableAssets.add(asset);
    }
  }

  Future<void> dispose() => _player.dispose();
}