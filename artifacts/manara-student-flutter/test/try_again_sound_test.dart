import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/services/kindergarten_voice_quiz.dart';
import 'package:manara_student/src/services/student_sound_service.dart';

/// «حاول مرة ثانية يا بطل»: صوتٌ واحدٌ لكلّ خطأٍ في أسئلة البطاقات وألعابها.
void main() {
  test('المقطعُ هو مقطعُ ألعاب الروضة نفسُه، وهو في الحزمة', () {
    expect(StudentSoundService.tryAgainClip, kgWrongAnswerClip);
    expect(File('assets/${StudentSoundService.tryAgainClip}').existsSync(), isTrue);
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/audio/kg_games/'));
  });

  test('كلُّ موضعِ خطأٍ في الأسئلة والألعاب يُسمِع «حاول مرة ثانية»', () {
    // ‏ألعابُ الأسئلة (البالون، السلّة، الصيد، المقلاع، القطار…)، والتتبّع
    // ‏(قلمي السحري)، والمنازلة.
    for (final file in const [
      'lib/src/widgets/quiz_games.dart',
      'lib/src/widgets/tracing_game.dart',
      'lib/src/screens/duel_match_screen.dart',
    ]) {
      final source = File(file).readAsStringSync();
      expect(source, contains('playTryAgain()'), reason: file);
    }
    // ‏والخطأُ في ألعاب الأسئلة لا يعود إلى النغمة القديمة.
    final quiz = File('lib/src/widgets/quiz_games.dart').readAsStringSync();
    expect(quiz, isNot(contains('StudentSoundCue.warning')));
    // ‏وألعابُ الروضة الصوتية تنتظر انتهاءه قبل فتح المايك.
    final kg = File('lib/src/screens/kindergarten_voice_games.dart').readAsStringSync();
    expect(kg, contains('_play(kgWrongAnswerClip)'));
  });

  test('لا تتراكب: مهلةٌ بين مرّةٍ والتي بعدها', () {
    expect(StudentSoundService.tryAgainCooldown, greaterThanOrEqualTo(const Duration(seconds: 1)));
    expect(StudentSoundService.tryAgainCooldown, lessThan(const Duration(seconds: 3)));
  });
}
