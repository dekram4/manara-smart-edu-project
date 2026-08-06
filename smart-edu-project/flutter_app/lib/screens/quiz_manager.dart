import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../models/academic_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'quiz_screen.dart';

class QuizManager extends StatelessWidget {
  const QuizManager({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الاختبارات', style: TextStyle(fontWeight: FontWeight.w900))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateQuizScreen())),
        backgroundColor: ManaraColors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('اختبار جديد'),
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          final quizzes = state.quizzesForCurrentRole;
          return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
          itemCount: quizzes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) {
            final quiz = quizzes[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: quiz.questions.isEmpty
                    ? null
                    : () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(quiz: quiz))),
                child: Row(
                children: [
                  const CircleAvatar(backgroundColor: Color(0xFFFFF0E2), child: Text('🧠')),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(quiz.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text('${quiz.subject} • ${quiz.grade} • ${quiz.questionCount} أسئلة', style: const TextStyle(color: ManaraColors.muted, fontSize: 12)),
                  ])),
                  IconButton(
                    onPressed: () => _confirmDelete(context, () => state.removeQuiz(quiz.id)),
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  ),
                ],
                ),
              ),
            );
          },
        );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, VoidCallback action) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الاختبار؟'),
        content: const Text('سيتم حذف الاختبار من قائمة الإدارة المحلية.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              action();
              Navigator.pop(context);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

class CreateQuizScreen extends StatefulWidget {
  const CreateQuizScreen({super.key});

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final title = TextEditingController();
  final subject = TextEditingController();
  final grade = TextEditingController(text: 'الصف الرابع');
  final atram = TextEditingController();
  final term = TextEditingController();
  final unit = TextEditingController();
  final count = TextEditingController(text: '10');
  QuizType type = QuizType.unit;
  final questionControllers = <TextEditingController>[];
  final optionControllers = <List<TextEditingController>>[];
  final answerControllers = <TextEditingController>[];

  @override
  void dispose() {
    title.dispose();
    subject.dispose();
    grade.dispose();
    atram.dispose();
    term.dispose();
    unit.dispose();
    count.dispose();
    for (final controller in questionControllers) {
      controller.dispose();
    }
    for (final options in optionControllers) {
      for (final controller in options) {
        controller.dispose();
      }
    }
    for (final controller in answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('إنشاء اختبار', style: TextStyle(fontWeight: FontWeight.w900))),
        body: Consumer<AppState>(
          builder: (context, state, _) => ListView(
          padding: const EdgeInsets.all(22),
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان الاختبار *')),
            const SizedBox(height: 14),
            ..._academicSelectors(state),
            const SizedBox(height: 14),
            DropdownButtonFormField<QuizType>(
              value: type,
              decoration: const InputDecoration(labelText: 'نوع الاختبار'),
              items: const [
                DropdownMenuItem(value: QuizType.unit, child: Text('اختبار وحدة')),
                DropdownMenuItem(value: QuizType.term, child: Text('اختبار ترم')),
                DropdownMenuItem(value: QuizType.finalExam, child: Text('اختبار نهائي')),
              ],
              onChanged: (value) => setState(() => type = value ?? QuizType.unit),
            ),
            const SizedBox(height: 14),
            TextField(controller: count, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد الأسئلة')),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _addQuestion,
              icon: const Icon(Icons.add),
              label: const Text('إضافة سؤال'),
            ),
            ...List.generate(questionControllers.length, _questionEditor),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('حفظ الاختبار')),
          ],
        ),
        ),
      );

  Iterable<AcademicUnit> _paths(AppState state) sync* {
    yield* state.academicUnits;
    for (final config in state.hierarchicalConfigs) {
      for (final atramItem in config.atrams) {
        for (final subjectItem in atramItem.subjects) {
          for (final termItem in subjectItem.terms) {
            for (final unitItem in termItem.units) {
              yield AcademicUnit(
                grade: config.grade,
                atram: atramItem.atram,
                subject: subjectItem.subject,
                term: termItem.term,
                unit: unitItem,
                createdBy: config.createdBy,
                createdByName: config.createdByName,
              );
            }
          }
        }
      }
    }
  }

  List<String> _unique(Iterable<String> values, String current) {
    final result = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (current.trim().isNotEmpty) result.add(current.trim());
    return result.toList()..sort();
  }

  List<Widget> _academicSelectors(AppState state) {
    final paths = _paths(state).toList();
    final grades = _unique(paths.map((item) => item.grade), grade.text);
    final atrams = _unique(paths.where((item) => item.grade == grade.text).map((item) => item.atram), atram.text);
    final subjects = _unique(paths.where((item) => item.grade == grade.text && item.atram == atram.text).map((item) => item.subject), subject.text);
    final terms = _unique(paths.where((item) => item.grade == grade.text && item.atram == atram.text && item.subject == subject.text).map((item) => item.term), term.text);
    final units = _unique(paths.where((item) => item.grade == grade.text && item.atram == atram.text && item.subject == subject.text && item.term == term.text).map((item) => item.unit), unit.text);
    return [
      _select('الصف *', grade, grades, () {
        atram.clear();
        subject.clear();
        term.clear();
        unit.clear();
      }),
      _select('الفصل / الأترم *', atram, atrams, () {
        subject.clear();
        term.clear();
        unit.clear();
      }),
      _select('المادة *', subject, subjects, () {
        term.clear();
        unit.clear();
      }),
      _select('الترم *', term, terms, unit.clear),
      _select('الوحدة *', unit, units, () {}),
    ];
  }

  Widget _select(
    String label,
    TextEditingController controller,
    List<String> values,
    VoidCallback clearChildren,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: values.contains(controller.text) ? controller.text : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: values.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
        onChanged: values.isEmpty
            ? null
            : (value) => setState(() {
                  controller.text = value ?? '';
                  clearChildren();
                }),
      ),
    );
  }

  void _save() {
    if (title.text.trim().isEmpty || subject.text.trim().isEmpty || grade.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل العنوان والمادة والصف')));
      return;
    }
    final questions = <QuizQuestion>[];
    for (var i = 0; i < questionControllers.length; i++) {
      final question = questionControllers[i].text.trim();
      final options = optionControllers[i].map((item) => item.text.trim()).where((item) => item.isNotEmpty).toList();
      final answer = answerControllers[i].text.trim();
      if (question.isEmpty || options.length < 2 || answer.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل نص السؤال وخياراته وإجابته الصحيحة')));
        return;
      }
      questions.add(QuizQuestion(question: question, options: options, correctAnswer: answer));
    }
    context.read<AppState>().addQuiz(
          title: title.text.trim(),
          subject: subject.text.trim(),
          grade: grade.text.trim(),
          atram: atram.text.trim(),
          term: term.text.trim(),
          unit: unit.text.trim(),
          type: type,
          questionCount: questions.isEmpty ? (int.tryParse(count.text) ?? 10) : questions.length,
          questions: questions,
        );
    Navigator.pop(context);
  }

  void _addQuestion() {
    setState(() {
      questionControllers.add(TextEditingController());
      optionControllers.add(List.generate(4, (_) => TextEditingController()));
      answerControllers.add(TextEditingController());
    });
  }

  Widget _questionEditor(int index) {
    final options = optionControllers[index];
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Text('السؤال ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900)),
          TextField(controller: questionControllers[index], decoration: const InputDecoration(labelText: 'نص السؤال')),
          ...List.generate(options.length, (optionIndex) => TextField(
                controller: options[optionIndex],
                decoration: InputDecoration(labelText: 'الخيار ${optionIndex + 1}'),
              )),
          TextField(controller: answerControllers[index], decoration: const InputDecoration(labelText: 'الإجابة الصحيحة (بنفس نص الخيار)')),
        ]),
      ),
    );
  }
}