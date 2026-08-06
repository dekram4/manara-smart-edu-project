import 'package:flutter_test/flutter_test.dart';
import 'package:manara_knowledge/models/app_models.dart';
import 'package:manara_knowledge/state/app_state.dart';

void main() {
  test('reward updates XP, gems, and level', () {
    final state = AppState();
    final beforeXp = state.xp;
    final beforeGems = state.gems;

    state.reward(40);

    expect(state.xp, beforeXp + 40);
    expect(state.gems, beforeGems + 4);
    expect(state.level, 1 + (state.xp ~/ 200));
  });

  test('quiz model preserves answers and options', () {
    const question = QuizQuestion(
      question: 'كم يساوي 2 + 2؟',
      options: ['3', '4'],
      correctAnswer: '4',
    );

    expect(question.options, contains(question.correctAnswer));
  });
}