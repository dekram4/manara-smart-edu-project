import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, this.quiz});
  final QuizDefinition? quiz;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int index = 0;
  int score = 0;
  String? selected;
  bool answered = false;
  bool resultSaved = false;
  final answers = <QuizAnswerDetail>[];

  @override
  void dispose() {
    context.read<AppState>().speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.quiz?.questions.isNotEmpty == true
        ? widget.quiz!.questions
        : context.read<AppState>().quizQuestions;
    if (questions.isEmpty || index >= questions.length) {
      return const SizedBox.shrink();
    }
    final current = questions[index];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quiz?.title ?? 'اختبار سريع', style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [Padding(padding: const EdgeInsetsDirectional.only(end: 18), child: Center(child: Text('${index + 1}/${questions.length}', style: const TextStyle(fontWeight: FontWeight.bold))))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          LinearProgressIndicator(value: (index + 1) / questions.length, minHeight: 9, borderRadius: BorderRadius.circular(9), color: ManaraColors.purple),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: ManaraColors.lavender, borderRadius: BorderRadius.circular(26)),
            child: Text(current.question, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.5)),
          ),
          const SizedBox(height: 22),
          ...current.options.map((option) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AnswerButton(
                  text: option,
                  selected: selected == option,
                  correct: answered && option == current.correctAnswer,
                  wrong: answered && selected == option && option != current.correctAnswer,
                  onTap: answered ? null : () => _answer(current, option),
                ),
              )),
          if (answered) ...[
            const SizedBox(height: 10),
            Text(
              selected == current.correctAnswer ? 'إجابة رائعة! +10 XP ⭐' : 'الإجابة الصحيحة: ${current.correctAnswer}',
              textAlign: TextAlign.center,
              style: TextStyle(color: selected == current.correctAnswer ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _next(questions.length),
              child: Text(index == questions.length - 1 ? 'عرض النتيجة' : 'السؤال التالي'),
            ),
          ],
        ],
      ),
    );
  }

  void _answer(QuizQuestion question, String option) {
    setState(() {
      selected = option;
      answered = true;
      answers.add(QuizAnswerDetail(
        question: question.question,
        userAnswer: option,
        correctAnswer: question.correctAnswer,
        isCorrect: option == question.correctAnswer,
      ));
      if (option == question.correctAnswer) {
        score++;
      } else if (context.read<AppState>().soundEnabled) {
        context.read<AppState>().audio.playError();
      }
    });
    final state = context.read<AppState>();
    if (option == question.correctAnswer) {
      if (state.soundEnabled) state.audio.playSuccess();
      state.speech.success();
    } else {
      state.speech.error();
    }
  }

  void _next(int count) {
    if (index == count - 1) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('انتهى الاختبار 🎉'),
          content: Text('نتيجتك $score من $count'),
          actions: [
            TextButton(
              onPressed: () {
                if (resultSaved) return;
                resultSaved = true;
                if (widget.quiz != null) {
                  context.read<AppState>().saveQuizResult(
                        quizId: widget.quiz!.id,
                        quizTitle: widget.quiz!.title,
                        score: score,
                        total: count,
                        quizType: widget.quiz?.type.name ?? 'unit',
                        subject: widget.quiz?.subject ?? '',
                        unit: widget.quiz?.unit ?? '',
                        grade: widget.quiz?.grade ?? '',
                        details: answers,
                      );
                }
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text('العودة للرئيسية'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() {
      index++;
      selected = null;
      answered = false;
    });
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({required this.text, required this.selected, required this.correct, required this.wrong, required this.onTap});
  final String text;
  final bool selected;
  final bool correct;
  final bool wrong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = correct ? Colors.green : wrong ? Colors.red : selected ? ManaraColors.purple : Colors.white;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: (correct || wrong || selected) ? Colors.white : ManaraColors.ink,
        side: BorderSide(color: correct || wrong || selected ? color : const Color(0xFFE5E0F0), width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Align(alignment: Alignment.centerRight, child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
    );
  }
}