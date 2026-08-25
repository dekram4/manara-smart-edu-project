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
}