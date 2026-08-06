import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../models/app_models.dart';
import '../services/learning_assistant_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.lessonContent = '',
    this.subject = 'العلوم',
    this.grade = '',
    this.unit = '',
  });

  final String lessonContent;
  final String subject;
  final String grade;
  final String unit;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const _questionsPerRound = 10;
  static const _secondsPerQuestion = 15;

  final _assistant = const LearningAssistantService();
  late final ConfettiController confetti;
  List<QuizQuestion> questions = const [];
  Timer? timer;
  int question = 0;
  int correctCount = 0;
  int points = 0;
  int combo = 0;
  int secondsLeft = _secondsPerQuestion;
  bool completed = false;
  bool loading = true;
  bool showingResult = false;
  String? selectedAnswer;

  @override
  void initState() {
    super.initState();
    confetti = ConfettiController(duration: const Duration(seconds: 2));
    _loadQuestions();
  }

  @override
  void dispose() {
    timer?.cancel();
    confetti.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    final generated = await _assistant.generateQuestions(
      lesson: widget.lessonContent,
      count: _questionsPerRound,
      grade: widget.grade,
      subject: widget.subject,
      unit: widget.unit,
    );
    if (!mounted) return;
    final source = generated.isNotEmpty ? generated : _fallbackQuestions;
    setState(() {
      questions = List.generate(
        _questionsPerRound,
        (index) => source[index % source.length],
      );
      loading = false;
      secondsLeft = _secondsPerQuestion;
    });
    _startTimer();
  }

  void _startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || loading || completed || showingResult) return;
      if (secondsLeft <= 1) {
        answer(null);
        return;
      }
      setState(() => secondsLeft--);
    });
  }

  void answer(String? value) {
    if (loading || completed || showingResult || question >= questions.length) {
      return;
    }
    final current = questions[question];
    final isCorrect = value != null && value == current.correctAnswer;
    final nextCorrectCount = correctCount + (isCorrect ? 1 : 0);
    final nextCombo = isCorrect ? combo + 1 : 0;
    final nextPoints = points +
        (isCorrect ? 10 + (secondsLeft ~/ 3) + combo : 0);
    setState(() {
      selectedAnswer = value;
      showingResult = true;
      correctCount = nextCorrectCount;
      combo = nextCombo;
      points = nextPoints;
    });
    final state = context.read<AppState>();
    if (state.soundEnabled) {
      if (isCorrect) {
        state.audio.playSuccess();
      } else {
        state.audio.playError();
      }
    }
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (question == questions.length - 1) {
        _finishRound(nextCorrectCount, nextPoints);
      } else {
        setState(() {
          question++;
          secondsLeft = _secondsPerQuestion;
          selectedAnswer = null;
          showingResult = false;
        });
      }
    });
  }

  void _finishRound(int finalCorrectCount, int finalPoints) {
    if (!mounted || completed) return;
    setState(() {
      completed = true;
      showingResult = false;
    });
    context.read<AppState>().completeGame(
          gameType: 'speed',
          perfect: finalCorrectCount == questions.length,
          score: finalCorrectCount,
          total: questions.length,
        );
    confetti.play();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Stack(
        alignment: Alignment.topCenter,
        children: [
          AlertDialog(
            title: const Text('انتهى التحدي 🎉'),
            content: Text(
              'أجبت عن $finalCorrectCount من ${questions.length} بشكل صحيح\n'
              'مجموع النقاط: $finalPoints',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.popUntil(
                  context,
                  (route) => route.isFirst,
                ),
                child: const Text('العودة للمغامرات'),
              ),
            ],
          ),
          ConfettiWidget(
            confettiController: confetti,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            emissionFrequency: .08,
            numberOfParticles: 18,
            gravity: .25,
            colors: const [
              ManaraColors.purple,
              ManaraColors.orange,
              ManaraColors.mint,
              ManaraColors.blue,
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'تحدي السرعة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final current = questions[question];
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تحدي السرعة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: (question + 1) / questions.length,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(10),
                  color: ManaraColors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '⏱ $secondsLeft',
                style: TextStyle(
                  color: secondsLeft <= 5
                      ? Colors.redAccent
                      : ManaraColors.muted,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 34),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: Text(
              current.question,
              key: ValueKey(question),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'السؤال ${question + 1} من ${questions.length} • $points نقطة',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ManaraColors.muted,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          ...current.options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton(
                onPressed: showingResult ? null : () => answer(option),
                style: FilledButton.styleFrom(
                  backgroundColor: _optionColor(current, option),
                  foregroundColor: _optionTextColor(current, option),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  option,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          if (combo > 1)
            Text(
              '🔥 سلسلة صحيحة ×$combo',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: ManaraColors.orange,
              ),
            ),
        ]),
      ),
    );
  }

  Color _optionColor(QuizQuestion current, String option) {
    if (!showingResult) return ManaraColors.lavender;
    if (option == current.correctAnswer) return ManaraColors.mint;
    if (option == selectedAnswer) return Colors.red.shade100;
    return Colors.grey.shade200;
  }

  Color _optionTextColor(QuizQuestion current, String option) {
    if (!showingResult) return ManaraColors.deepPurple;
    if (option == current.correctAnswer) return Colors.green.shade900;
    if (option == selectedAnswer) return Colors.red.shade900;
    return ManaraColors.muted;
  }

  static const _fallbackQuestions = [
    QuizQuestion(
      question: 'ما الجهاز الذي يساعدنا على التنفس؟',
      options: ['الجهاز التنفسي', 'الجهاز الهضمي', 'الجهاز العضلي', 'الجهاز العصبي'],
      correctAnswer: 'الجهاز التنفسي',
    ),
    QuizQuestion(
      question: 'كم يساوي 3 × 4؟',
      options: ['7', '10', '12', '15'],
      correctAnswer: '12',
    ),
    QuizQuestion(
      question: 'أي كلمة تدل على شيء نراه؟',
      options: ['كتاب', 'يكتب', 'جميل', 'بسرعة'],
      correctAnswer: 'كتاب',
    ),
  ];
}