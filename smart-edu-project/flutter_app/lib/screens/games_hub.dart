import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/learning_assistant_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'game_screen.dart';

class GamesHub extends StatelessWidget {
  const GamesHub({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lesson = state.lessonsForCurrentRole.isEmpty
        ? null
        : state.lessonsForCurrentRole.first;
    final lessonContent = lesson?.content ?? '';
    final subject = lesson?.subject ?? 'العلوم';
    final grade = lesson?.grade ?? '';
    final unit = lesson?.unit ?? '';
    return Scaffold(
        appBar: AppBar(
          title: const Text(
            'مغامرات وألعاب',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _GameTile(
              icon: '⚡',
              title: 'الاختبار السريع',
              subtitle: 'أجب بسرعة واجمع XP',
              color: ManaraColors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GameScreen(
                    lessonContent: lessonContent,
                    subject: subject,
                    grade: grade,
                    unit: unit,
                  ),
                ),
              ),
            ),
            _GameTile(
              icon: '🧠',
              title: 'لعبة الذاكرة',
              subtitle: 'طابق البطاقات واكتشف الأزواج',
              color: ManaraColors.purple,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MemoryGameScreen())),
            ),
            _GameTile(
              icon: '✅',
              title: 'صح أم خطأ',
              subtitle: 'اختبر معلوماتك في جولة قصيرة',
              color: ManaraColors.mint,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TrueFalseGameScreen(
                    lessonContent: lessonContent,
                    subject: subject,
                    grade: grade,
                    unit: unit,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.all(19),
            decoration: BoxDecoration(color: color.withOpacity(.13), borderRadius: BorderRadius.circular(24)),
            child: Row(children: [
              Text(icon, style: const TextStyle(fontSize: 44)),
              const SizedBox(width: 15),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: ManaraColors.muted)),
              ])),
              Icon(Icons.arrow_back_ios_new, color: color),
            ]),
          ),
        ),
      );
}

class MemoryGameScreen extends StatefulWidget {
  const MemoryGameScreen({super.key});
  @override
  State<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

class _MemoryGameScreenState extends State<MemoryGameScreen> {
  final cards = ['🌟', '🌟', '📚', '📚', '🚀', '🚀', '🧠', '🧠'];
  final revealed = <int>{};
  final matched = <int>{};
  int? first;
  bool locked = false;
  bool completed = false;
  int attempts = 0;

  void tap(int index) async {
    if (locked || matched.contains(index) || revealed.contains(index)) return;
    setState(() => revealed.add(index));
    if (first == null) {
      first = index;
      return;
    }
    final previous = first!;
    first = null;
    locked = true;
    attempts++;
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    if (cards[previous] == cards[index]) {
      setState(() {
        matched.addAll([previous, index]);
        locked = false;
      });
      if (!completed && matched.length == cards.length) {
        completed = true;
        context.read<AppState>().completeGame(
              gameType: 'memory',
              perfect: attempts == cards.length ~/ 2,
              score: matched.length ~/ 2,
              total: cards.length ~/ 2,
            );
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('أكملت لعبة الذاكرة 🎉'),
              content: const Text('أحسنت! حصلت على مكافأة اللعبة.'),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('متابعة'),
                ),
              ],
            ),
          );
        }
      }
    } else {
      setState(() {
        revealed.removeAll([previous, index]);
        locked = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('لعبة الذاكرة', style: TextStyle(fontWeight: FontWeight.w900))),
        body: GridView.builder(
          padding: const EdgeInsets.all(25),
          itemCount: cards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14),
          itemBuilder: (_, index) => InkWell(
            onTap: () => tap(index),
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              decoration: BoxDecoration(
                color: revealed.contains(index) || matched.contains(index) ? ManaraColors.lavender : ManaraColors.deepPurple,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(child: Text(revealed.contains(index) || matched.contains(index) ? cards[index] : '❓', style: const TextStyle(fontSize: 43))),
            ),
          ),
        ),
      );
}

class TrueFalseGameScreen extends StatefulWidget {
  const TrueFalseGameScreen({
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
  State<TrueFalseGameScreen> createState() => _TrueFalseGameScreenState();
}

class _TrueFalseGameScreenState extends State<TrueFalseGameScreen> {
  static const _secondsPerQuestion = 10;
  final _assistant = const LearningAssistantService();
  Timer? timer;
  List<_TrueFalseStatement> statements = const [];
  int index = 0;
  int score = 0;
  int secondsLeft = _secondsPerQuestion;
  bool completed = false;
  bool loading = true;
  bool showingResult = false;
  bool? selected;

  @override
  void initState() {
    super.initState();
    _loadStatements();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatements() async {
    final generated = await _assistant.generateQuestions(
      lesson: widget.lessonContent,
      count: 8,
      grade: widget.grade,
      subject: widget.subject,
      unit: widget.unit,
    );
    if (!mounted) return;

    final sentences = widget.lessonContent
        .split(RegExp(r'[.!؟\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final source = sentences.isNotEmpty
        ? sentences
        : generated
            .map((item) => item.correctAnswer)
            .where((item) => item.trim().isNotEmpty)
            .toList();
    final loadedStatements = source.isEmpty
        ? _fallbackStatements
        : List.generate(8, (item) {
            final sentence = source[item % source.length];
            final isTrue = item.isEven;
            return _TrueFalseStatement(
              text: isTrue ? sentence : 'ليس صحيحاً أن $sentence',
              isTrue: isTrue,
            );
          });

    setState(() {
      statements = loadedStatements;
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

  void answer(bool? value) {
    if (loading || completed || showingResult || index >= statements.length) {
      return;
    }

    final isCorrect = value != null && value == statements[index].isTrue;
    final nextScore = score + (isCorrect ? 1 : 0);
    setState(() {
      selected = value;
      showingResult = true;
      score = nextScore;
    });

    final state = context.read<AppState>();
    if (state.soundEnabled) {
      if (isCorrect) {
        state.audio.playSuccess();
      } else {
        state.audio.playError();
      }
    }

    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (index == statements.length - 1) {
        _finishRound(nextScore);
        return;
      }
      setState(() {
        index++;
        selected = null;
        showingResult = false;
        secondsLeft = _secondsPerQuestion;
      });
    });
  }

  void _finishRound(int finalScore) {
    if (!mounted || completed) return;
    setState(() {
      completed = true;
      showingResult = false;
    });
    context.read<AppState>().completeGame(
          gameType: 'truefalse',
          perfect: finalScore == statements.length,
          score: finalScore,
          total: statements.length,
        );
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('انتهت الجولة 🎉'),
        content: Text(
          'أجبت عن $finalScore من ${statements.length} بشكل صحيح',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.popUntil(
              context,
              (route) => route.isFirst,
            ),
            child: const Text('العودة للألعاب'),
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
            'صح أم خطأ',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final statement = statements[index];
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'صح أم خطأ',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: (index + 1) / statements.length,
                    minHeight: 9,
                    borderRadius: BorderRadius.circular(9),
                    color: ManaraColors.mint,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '⏱ $secondsLeft',
                  style: TextStyle(
                    color: secondsLeft <= 3
                        ? Colors.redAccent
                        : ManaraColors.muted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'السؤال ${index + 1} من ${statements.length} • $score صحيح',
              style: const TextStyle(color: ManaraColors.muted),
            ),
            const SizedBox(height: 30),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Text(
                statement.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: showingResult ? null : () => answer(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: _answerColor(true, statement),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: const Text(
                      'صح',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: showingResult ? null : () => answer(false),
                    style: FilledButton.styleFrom(
                      backgroundColor: _answerColor(false, statement),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: const Text(
                      'خطأ',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _answerColor(bool value, _TrueFalseStatement statement) {
    if (!showingResult) {
      return value ? ManaraColors.mint : Colors.redAccent;
    }
    if (value == statement.isTrue) return ManaraColors.mint;
    if (value == selected) return Colors.red.shade100;
    return Colors.grey.shade300;
  }

  static const _fallbackStatements = [
    _TrueFalseStatement(text: 'الشمس نجم', isTrue: true),
    _TrueFalseStatement(text: '5 + 3 = 10', isTrue: false),
    _TrueFalseStatement(text: 'الماء يتجمد عند صفر درجة', isTrue: true),
    _TrueFalseStatement(
      text: 'اللغة العربية تكتب من اليسار إلى اليمين',
      isTrue: false,
    ),
  ];
}

class _TrueFalseStatement {
  const _TrueFalseStatement({required this.text, required this.isTrue});

  final String text;
  final bool isTrue;
}