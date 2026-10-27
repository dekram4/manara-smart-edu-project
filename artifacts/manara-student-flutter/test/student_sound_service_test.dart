import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/services/student_sound_service.dart';

void main() {
  test('sound gate prevents immediate duplicate cues', () {
    var now = DateTime(2026, 8, 25, 12);
    final gate = StudentSoundGate(now: () => now);

    expect(gate.allow(StudentSoundCue.navigation), isTrue);
    expect(gate.allow(StudentSoundCue.navigation), isFalse);

    now = now.add(const Duration(milliseconds: 221));
    expect(gate.allow(StudentSoundCue.navigation), isTrue);
  });

  test('different sound cues can be played independently', () {
    final gate = StudentSoundGate(now: () => DateTime(2026, 8, 25, 12));

    expect(gate.allow(StudentSoundCue.navigation), isTrue);
    expect(gate.allow(StudentSoundCue.success), isTrue);
  });

  group('التشجيع ثم التصفيق', () {
    test('كلُّ عبارة تشجيعٍ ملفٌّ داخل assets/audio/encouragement/', () {
      expect(StudentSoundService.encouragementClips, hasLength(4));
      for (final clip in StudentSoundService.encouragementClips) {
        expect(clip, startsWith('audio/encouragement/'));
        expect(File('assets/$clip').existsSync(), isTrue, reason: clip);
      }
      expect(File('assets/audio/clap2.mp3').existsSync(), isTrue);
      expect(File('assets/audio/clap.mp3').existsSync(), isTrue);
    });

    test('العبارةُ لا تتكرّر مرّتين متتاليتين، وكلُّها تُسمع', () {
      final random = math.Random(7);
      String? last;
      final heard = <String>{};
      for (var i = 0; i < 200; i++) {
        final clip = StudentSoundService.pickEncouragementClip(last, random);
        expect(clip, isNot(last));
        heard.add(clip);
        last = clip;
      }
      expect(heard, StudentSoundService.encouragementClips.toSet());
    });
  });
}