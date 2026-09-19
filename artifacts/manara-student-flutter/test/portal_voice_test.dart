import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/services/student_sound_service.dart';

/// The portal lines are recorded clips, not the device's speech engine — the
/// engine was what read them in a robotic, foreign-sounding voice. These hold
/// the two things that would quietly send a portal back to silence: a clip
/// that was never recorded, and a folder the build does not bundle.
void main() {
  /// Every portal on the hub's rail, by the key its line is stored under.
  const portals = [
    'lesson',
    'cinema',
    'games',
    'personality',
    'tutor',
    'quiz',
    'solver',
    'meeting',
    'chat',
    'challenge',
  ];

  test('every portal has its line recorded in both languages', () {
    for (final portal in [...portals, 'generic']) {
      if (portal != 'generic') {
        // The clip is the recording of this string; a portal with no string
        // has nothing for the script to record.
        expect(StudentStrings.has('portal.$portal.voice'), isTrue,
            reason: 'portal.$portal.voice has no text to record');
      }
      for (final language in ['ar', 'en']) {
        final clip = File('assets/audio/voice/${portal}_$language.mp3');
        expect(clip.existsSync(), isTrue,
            reason: '${clip.path} is missing — run tool/build_portal_voices.py');
        expect(clip.lengthSync(), greaterThan(1000),
            reason: '${clip.path} is empty');
      }
    }
  });

  test('the clips folder is bundled with the app', () {
    // `assets/audio/` alone does not reach into `voice/`: Flutter asset
    // directories are not recursive, and every clip would fail to load.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/audio/voice/'));
  });

  test('a portal plays its own clip when it has one', () {
    const bundled = {
      'assets/audio/voice/lesson_ar.mp3',
      'assets/audio/voice/generic_ar.mp3',
    };
    expect(
      StudentSoundService.portalVoiceAsset('portal.lesson', 'ar', bundled),
      'audio/voice/lesson_ar.mp3',
    );
  });

  test('a portal with no clip yet falls back to the generic line', () {
    const bundled = {'assets/audio/voice/generic_en.mp3'};
    expect(
      StudentSoundService.portalVoiceAsset('portal.brandNew', 'en', bundled),
      'audio/voice/generic_en.mp3',
    );
  });
}
