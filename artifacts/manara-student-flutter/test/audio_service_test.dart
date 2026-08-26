import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/services/audio_service.dart';

void main() {
  test('audio service maps the success effect to its established asset', () {
    expect(AudioService.assetFor(AudioEffect.success), 'audio/success-reward.wav');
  });

  test('audio service maps feedback to its established warning asset', () {
    expect(AudioService.assetFor(AudioEffect.feedback), 'audio/gentle-warning.wav');
  });
}