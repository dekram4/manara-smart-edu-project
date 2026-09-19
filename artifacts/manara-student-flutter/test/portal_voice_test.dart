import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/services/student_sound_service.dart';

/// The portal lines are recorded clips, not the device's speech engine — the
/// engine was what read them in a robotic, foreign-sounding voice. These hold
/// what would quietly send a portal back to silence (a missing clip, a folder
/// the build does not bundle), and what keeps the supplied recordings in
/// place and at one loudness.
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
        expect(StudentStrings.has('portal.$portal.voice'), isTrue,
            reason: 'portal.$portal.voice has no text');
      }
      for (final language in ['ar', 'en']) {
        final clip = File('assets/audio/voice/${portal}_$language.mp3');
        expect(clip.existsSync(), isTrue, reason: '${clip.path} is missing');
        expect(clip.lengthSync(), greaterThan(1000),
            reason: '${clip.path} is empty');
      }
    }
  });

  test('the path screen has its greeting recorded in both languages', () {
    expect(StudentStrings.has('path.voice'), isTrue);
    for (final language in ['ar', 'en']) {
      final clip = File('assets/audio/voice/path_$language.mp3');
      expect(clip.existsSync(), isTrue, reason: '${clip.path} is missing');
      expect(clip.lengthSync(), greaterThan(1000));
    }
  });

  test('the retired generator cannot overwrite the supplied recordings', () {
    // The Arabic clips are recordings in the hub welcome's voice; an edge-tts
    // render over any of them is exactly the mismatch they replaced.
    final tool = File('tool/build_portal_voices.py').readAsStringSync();
    expect(tool, contains('if "--allow" not in sys.argv[1:]:'));
    for (final name in [
      'path',
      'lesson',
      'tutor',
      'cinema',
      'games',
      'meeting',
      'chat',
      'challenge',
      'solver',
      'quiz',
    ]) {
      expect(tool, contains('"${name}_ar",'),
          reason: '${name}_ar.mp3 is not protected from the generator');
    }
  });

  test('every clip has a measured level', () {
    // A clip with no entry falls back to a guessed volume — a replaced
    // recording has to be re-measured, and this is what says so.
    final clips = Directory('assets/audio/voice')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => name.endsWith('.mp3'));
    for (final clip in clips) {
      final name = clip.substring(0, clip.length - '.mp3'.length);
      expect(StudentSoundService.voiceRms.containsKey(name), isTrue,
          reason: '$clip has no measured level in StudentSoundService.voiceRms');
    }
  });

  test('each line plays at the hub welcome\'s loudness', () {
    const welcome = 0.122 * 0.78;
    StudentSoundService.voiceRms.forEach((name, rms) {
      final volume = StudentSoundService.voiceVolume('audio/voice/$name.mp3');
      expect(volume, inInclusiveRange(0.0, 1.0));
      if (welcome / rms <= 1.0) {
        expect(volume * rms, closeTo(welcome, 0.0001), reason: name);
      } else {
        // Quieter than the welcome even at full volume: as loud as it goes.
        expect(volume, 1.0, reason: name);
      }
    });
    // The loudest recording is turned down furthest.
    expect(
      StudentSoundService.voiceVolume('audio/voice/challenge_ar.mp3'),
      lessThan(StudentSoundService.voiceVolume('audio/voice/cinema_ar.mp3')),
    );
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
