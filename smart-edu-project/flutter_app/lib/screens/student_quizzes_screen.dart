import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'quiz_screen.dart';
import '../models/app_models.dart';

class StudentQuizzesScreen extends StatelessWidget {
  const StudentQuizzesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final available =
        state.quizzesForCurrentRole.where((quiz) => quiz.active).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('اختباراتي', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
        children: [
          _GeneratedQuizCard(
            lessons: state.lessonsForCurrentRole,
            onGenerate: (lesson, count) => _generate(context, lesson, count),
          ),
          const SizedBox(height: 18),
          if (available.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('لا توجد اختبارات منشورة حالياً. أنشئ اختباراً من أحد دروسك.',
                  textAlign: TextAlign.center),
            ),
          ...available.map((quiz) {
          final results = state.quizResultsForCurrentRole
              .where((item) => item.quizId == quiz.id)
              .toList();
          return InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(quiz: quiz))),
            borderRadius: BorderRadius.circular(21),
            child: Ink(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21)),
              child: Row(children: [
                const CircleAvatar(radius: 27, backgroundColor: ManaraColors.lavender, child: Text('🧠', style: TextStyle(fontSize: 23))),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(quiz.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  Text('${quiz.subject} • ${quiz.grade} • ${quiz.questionCount} أسئلة', style: const TextStyle(color: ManaraColors.muted, fontSize: 12)),
                  if (results.isNotEmpty) Text('آخر نتيجة: ${results.last.score}/${results.last.total}', style: const TextStyle(color: ManaraColors.purple, fontWeight: FontWeight.bold, fontSize: 12)),
                ])),
                const Icon(Icons.play_circle_outline, color: ManaraColors.purple, size: 30),
              ]),
            ),
          );
          }),
        ],
      ),
    );
  }

  Future<void> _generate(
    BuildContext context,
    Lesson lesson,
    int count,
  ) async {
    final state = context.read<AppState>();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(child: Text('جاري إعداد أسئلة مناسبة للدرس...')),
        ]),
      ),
    );
    final questions = await state.learningAssistant.generateQuestions(
      lesson: lesson.content,
      count: count,
      grade: lesson.grade,
      subject: lesson.subject,
      unit: lesson.unit,
    );
    if (context.mounted) Navigator.pop(context);
    if (questions.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد محتوى كافٍ لإنشاء الاختبار')),
        );
      }
      return;
    }
    final generated = QuizDefinition(
      id: 'generated-${DateTime.now().millisecondsSinceEpoch}',
      title: 'اختبار ${lesson.title}',
      subject: lesson.subject,
      grade: lesson.grade,
      questionCount: questions.length,
      active: true,
      unit: lesson.unit,
      lessonId: lesson.id,
      questions: questions,
    );
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => QuizScreen(quiz: generated)),
      );
    }
  }
}

class _GeneratedQuizCard extends StatefulWidget {
  const _GeneratedQuizCard({required this.lessons, required this.onGenerate});
  final List<Lesson> lessons;
  final void Function(Lesson lesson, int count) onGenerate;

  @override
  State<_GeneratedQuizCard> createState() => _GeneratedQuizCardState();
}

class _GeneratedQuizCardState extends State<_GeneratedQuizCard> {
  Lesson? selected;
  int count = 5;

  @override
  Widget build(BuildContext context) {
    selected ??= widget.lessons.isNotEmpty ? widget.lessons.first : null;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ManaraColors.deepPurple, ManaraColors.purple],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('أنشئ اختباراً من درس ✨',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text('يعمل تلقائياً من محتوى الدرس، حتى عند عدم وجود اختبار منشور.',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 13),
          DropdownButtonFormField<Lesson>(
            value: selected,
            dropdownColor: ManaraColors.deepPurple,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'اختر الدرس',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white38),
              ),
            ),
            items: widget.lessons
                .map((lesson) => DropdownMenuItem(
                      value: lesson,
                      child: Text(lesson.title),
                    ))
                .toList(),
            onChanged: (value) => setState(() => selected = value),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: count,
            dropdownColor: ManaraColors.deepPurple,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'عدد الأسئلة',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white38),
              ),
            ),
            items: [5, 10, 15]
                .map((value) => DropdownMenuItem(value: value, child: Text('$value أسئلة')))
                .toList(),
            onChanged: (value) => setState(() => count = value ?? 5),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: selected == null ? null : () => widget.onGenerate(selected!, count),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('ابدأ الاختبار'),
          ),
        ],
      ),
    );
  }
}