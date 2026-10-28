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

  testWidgets('داخل البطاقة: لا تصفيقَ ولا جواهر، وفي الواجهة الاحتفالُ كاملاً', (tester) async {
    final sound = StudentSoundService.instance;
    sound.enterCard();
    expect(sound.insideCard, isTrue);
    // التشجيعُ الفوريّ وخلفه التصفيقُ الهادئ: العبارةُ والتصفيقُ معاً، والتصفيقُ أخفض.
    final layers = StudentSoundService.cheerLayers(StudentSoundService.encouragementClips.first);
    expect(layers.map((l) => l.$1), contains(StudentSoundService.clapping));
    expect(layers.last.$2, lessThan(layers.first.$2));
    sound.playCheer();
    // والحصيلةُ وصوتُ الجواهر للواجهة وحدها.
    expect(sound.playCelebration(gems: true), isFalse);
    sound.leaveCard();
    expect(sound.insideCard, isFalse);
    expect(sound.playCelebration(gems: true), isTrue);
    sound.stopEffects();
    await tester.pump(const Duration(seconds: 1));
  });

  group('التشجيع ثم التصفيق', () {
    test('كلُّ عبارة تشجيعٍ ملفٌّ داخل assets/audio/encouragement/', () {
      expect(StudentSoundService.encouragementClips, hasLength(4));
      for (final clip in StudentSoundService.encouragementClips) {
        expect(clip, startsWith('audio/encouragement/'));
        expect(File('assets/$clip').existsSync(), isTrue, reason: clip);
      }
      expect(File('assets/${StudentSoundService.clapping}').existsSync(), isTrue);
    });

    test('العبارةُ والتصفيقُ معاً، والتصفيقُ خلفها أخفض — بلا نغمةٍ ولا لحن', () {
      const phrase = 'audio/encouragement/encouragement_rai.mp3';
      final layers = StudentSoundService.cheerLayers(phrase);
      expect(layers.map((c) => c.$1), [phrase, 'audio/encouragement/clapping.mp3']);
      expect(layers[1].$2, lessThan(layers[0].$2));
      expect(layers[1].$2, lessThanOrEqualTo(0.4));
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