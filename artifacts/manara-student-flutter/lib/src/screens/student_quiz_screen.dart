import 'package:flutter/material.dart';

import '../models/academic_context.dart';
import '../models/student_assessment.dart';
import '../models/student_profile.dart';
import '../models/student_gamification.dart';
import '../services/student_content_service.dart';

class StudentQuizScreen extends StatefulWidget {
  const StudentQuizScreen({
    required this.profile,
    required this.contentService,
    this.academicContext,
    super.key,
  });

  final StudentProfile profile;
  final StudentContentService contentService;
  final AcademicContext? academicContext;

  @override
  State<StudentQuizScreen> createState() => _StudentQuizScreenState();
}

class _StudentQuizScreenState extends State<StudentQuizScreen> {
  List<Map<String, dynamic>> _quizzes = const [];
  List<Map<String, dynamic>> _results = const [];
  Map<String, dynamic>? _activeQuiz;
  List<Map<String, dynamic>> _questions = const [];
  final Map<String, String> _answers = {};
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _shownResult;
  int _questionIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        widget.contentService.fetchAvailableQuizzes(
          widget.profile,
          academicContext: widget.academicContext,
        ),
        widget.contentService.fetchQuizResults(widget.profile),
      ]);
      if (!mounted) return;
      var quizzes = values[0] as List<Map<String, dynamic>>;
      if (!quizzes.any((quiz) => !StudentAssessmentRules.isTeacherQuiz(quiz))) {
        final fallback = _periodicFallbackQuiz();
        if (fallback != null) quizzes = [...quizzes, fallback];
      }
      setState(() {
        _quizzes = quizzes;
        _results = values[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الاختبارات: $error';
      });
    }
  }

  Map<String, dynamic>? _periodicFallbackQuiz() {
    final lesson = widget.academicContext?.selectedLesson;
    if (lesson == null) return null;
    final text = lesson.lessonText?.trim() ?? '';
    if (text.isEmpty) return null;
    final sentences = text
        .split(RegExp(r'[.!؟?\n]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(10)
        .toList();
    if (sentences.isEmpty) return null;
    final questions = sentences.asMap().entries.map((entry) {
      final sentence = entry.value;
      final correct = sentence.length > 80 ? '${sentence.substring(0, 80)}...' : sentence;
      final options = <String>[
        correct,
        'فكرة رئيسية',
        'معلومة إضافية',
        'لا توجد علاقة بالموضوع',
      ];
      return <String, dynamic>{
        'id': 'periodic_fallback_${lesson.id}_${entry.key}',
        'question': 'اختر الفكرة الأكثر ملاءمة للنص الآتي: "$sentence"',
        'options': options,
        'correctAnswer': correct,
        'quizType': 'periodic',
        'quizId': 'periodic_fallback_${lesson.id}',
        'grade': widget.academicContext?.grade ?? widget.profile.grade ?? '',
        'atram': widget.academicContext?.atram ?? widget.profile.atram ?? '',
        'subject': widget.academicContext?.subject ?? widget.profile.subject ?? '',
        'term': widget.academicContext?.term ?? widget.profile.term ?? '',
        'unit': widget.academicContext?.unit ?? widget.profile.unit ?? '',
      };
    }).toList();
    return {
      'id': 'periodic_fallback_${lesson.id}',
      'title': 'الاختبار الدوري',
      'quizType': 'periodic',
      'questions': questions,
      'questionCount': questions.length,
      'questionsPerAttempt': questions.length,
      'isActive': true,
      'grade': widget.academicContext?.grade ?? widget.profile.grade ?? '',
      'atram': widget.academicContext?.atram ?? widget.profile.atram ?? '',
      'subject': widget.academicContext?.subject ?? widget.profile.subject ?? '',
      'term': widget.academicContext?.term ?? widget.profile.term ?? '',
      'unit': widget.academicContext?.unit ?? widget.profile.unit ?? '',
      'createdBy': 'supervisor',
    };
  }

  bool _isTeacherQuiz(Map<String, dynamic> quiz) =>
      StudentAssessmentRules.isTeacherQuiz(quiz);

  List<Map<String, dynamic>> _quizQuestions(Map<String, dynamic> quiz) =>
      StudentAssessmentRules.questionsForStudent(quiz, studentId: widget.profile.id);

  void _openQuiz(Map<String, dynamic> quiz) {
    final quizId = _text(quiz['id']);
    Map<String, dynamic>? previous;
    for (final result in _results) {
      if (_text(result['quizId']) == quizId &&
          StudentAssessmentRules.isTeacherQuiz(result)) {
        previous = result;
        break;
      }
    }
    if (_isTeacherQuiz(quiz) && previous != null) {
      setState(() => _shownResult = previous);
      return;
    }
    final questions = _quizQuestions(quiz);
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد أسئلة صالحة في هذا الاختبار بعد.')),
      );
      return;
    }
    setState(() {
      _activeQuiz = quiz;
      _questions = questions;
      _answers.clear();
      _questionIndex = 0;
      _shownResult = null;
    });
  }

  Future<void> _submit() async {
    final quiz = _activeQuiz;
    if (quiz == null || _submitting) return;
    if (_answers.length != _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أجب عن جميع الأسئلة قبل إرسال الاختبار.')),
      );
      return;
    }
    setState(() => _submitting = true);
    final score = _questions.asMap().entries.where((entry) {
      return StudentAssessmentRules.isAnswerCorrect(
        entry.value,
        _answers[_questionId(entry.value, entry.key)] ?? '',
      );
    }).length;
    final percentage = ((score / _questions.length) * 100).round();
    final now = DateTime.now().toIso8601String();
    final result = <String, dynamic>{
      'id': 'result_${widget.profile.id}_${DateTime.now().microsecondsSinceEpoch}',
      'studentId': widget.profile.id,
      'studentName': widget.profile.name,
      'quizId': _text(quiz['id']),
      'quizType': StudentAssessmentRules.quizTypeValue(quiz['quizType']),
      'quizTitle': _text(quiz['title']).isEmpty ? 'اختبار منارة' : _text(quiz['title']),
      'subject': _text(quiz['subject']),
      'unit': _text(quiz['unit']),
      'grade': _text(quiz['grade']),
      'atram': _text(quiz['atram']),
      'term': _text(quiz['term']),
      'teacherId': StudentAssessmentRules.ownerId(quiz),
      'periodicNumber': quiz['periodicNumber'],
      'score': score,
      'total': _questions.length,
      'percentage': percentage,
      'level': percentage >= 90 ? 'ممتاز' : percentage >= 70 ? 'جيد جداً' : percentage >= 50 ? 'جيد' : 'يحتاج تحسين',
      'feedback': percentage >= 60
          ? 'أحسنت! واصل التعلم والتقدم.'
          : 'بداية جيدة، راجع الدرس ثم حاول في اختبار جديد.',
      'details': _questions.asMap().entries.map((entry) {
        final question = entry.value;
        final answer = _answers[_questionId(question, entry.key)] ?? '';
        return {
          'questionId': _questionId(question, entry.key),
          'question': _text(question['question']),
          'userAnswer': answer,
          'correctAnswer': StudentAssessmentRules.correctAnswerText(question),
          'isCorrect': StudentAssessmentRules.isAnswerCorrect(question, answer),
        };
      }).toList(),
      'createdAt': now,
      'attemptNumber': _results.where((item) => _text(item['quizId']) == _text(quiz['id'])).length + 1,
      'isRetake': !_isTeacherQuiz(quiz) &&
          _results.any((item) => _text(item['quizId']) == _text(quiz['id'])),
    };
    try {
      final savedResult = await widget.contentService.saveQuizResult(
        profile: widget.profile,
        result: result,
      );
      RewardResult? reward;
      try {
        reward = await widget.contentService.rewardActivity(
          profile: widget.profile,
          activityType: 'quiz',
          activityId: _text(quiz['id']),
          correctAnswers: score,
          quizTotal: _questions.length,
        );
      } catch (_) {
        // The saved assessment remains visible if reward sync is offline.
      }
      if (!mounted) return;
      setState(() {
        _results = [savedResult, ..._results];
        _shownResult = savedResult;
        _activeQuiz = null;
        _questions = const [];
        _answers.clear();
        _questionIndex = 0;
        _submitting = false;
      });
      if (reward != null) {
        final message = reward.alreadyRewarded
            ? 'تم حفظ النتيجة؛ لا توجد مكافأة إضافية لإعادة الاختبار.'
            : 'أحسنت! +${reward.xp} XP و +${reward.gems} جوهرة'
                '${reward.levelUp ? ' • ارتقيت إلى المستوى ${reward.snapshot.level}!' : ''}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } on TeacherQuizAlreadySubmittedException catch (error) {
      if (!mounted) return;
      setState(() {
        _results = [error.result, ..._results];
        _shownResult = error.result;
        _activeQuiz = null;
        _questions = const [];
        _answers.clear();
        _questionIndex = 0;
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر حفظ النتيجة الآن. تحقق من الاتصال ثم أعد المحاولة.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FF),
        appBar: AppBar(
          title: Text(_activeQuiz == null ? 'مركز الاختبارات' : _text(_activeQuiz!['title'])),
          actions: [
            if (_activeQuiz != null)
              IconButton(
                onPressed: () => setState(() {
                  _activeQuiz = null;
                  _questions = const [];
                  _answers.clear();
                }),
                tooltip: 'العودة للاختبارات',
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : _shownResult != null
                    ? _QuizResultView(
                        result: _shownResult!,
                        onBack: () => setState(() => _shownResult = null),
                      )
                    : _activeQuiz != null
                        ? _QuestionList(
                            questions: _questions,
                            answers: _answers,
                             questionIndex: _questionIndex,
                            submitting: _submitting,
                            onAnswer: (id, value) => setState(() => _answers[id] = value),
                             onPrevious: _questionIndex == 0
                                 ? null
                                 : () => setState(() => _questionIndex--),
                             onNext: _questionIndex >= _questions.length - 1 ||
                                     !_answers.containsKey(
                                       _questionId(
                                         _questions[_questionIndex],
                                         _questionIndex,
                                       ),
                                     )
                                 ? null
                                 : () => setState(() => _questionIndex++),
                            onSubmit: _submit,
                          )
                        : _QuizCatalog(
                            quizzes: _quizzes,
                            results: _results,
                            onOpen: _openQuiz,
                            isTeacherQuiz: _isTeacherQuiz,
                          ),
      ),
    );
  }
}

class _QuizCatalog extends StatelessWidget {
  const _QuizCatalog({
    required this.quizzes,
    required this.results,
    required this.onOpen,
    required this.isTeacherQuiz,
  });

  final List<Map<String, dynamic>> quizzes;
  final List<Map<String, dynamic>> results;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final bool Function(Map<String, dynamic>) isTeacherQuiz;

  @override
  Widget build(BuildContext context) {
    if (quizzes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.quiz_outlined, size: 58, color: Color(0xFF0B8693)),
              SizedBox(height: 14),
              Text('لا توجد اختبارات مضافة لمسارك الآن.', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: quizzes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final quiz = quizzes[index];
        final quizResults = results
            .where((item) => _text(item['quizId']) == _text(quiz['id']))
            .toList();
        final taken = quizResults.isNotEmpty;
        final teacher = isTeacherQuiz(quiz);
        final questionCount = StudentAssessmentRules.questionsForStudent(
          quiz,
          studentId: '',
        ).length;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(teacher ? Icons.school_rounded : Icons.event_note_rounded,
                        color: const Color(0xFF0B8693)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _text(quiz['title']).isEmpty ? 'اختبار منارة' : _text(quiz['title']),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (taken) const Icon(Icons.check_circle_rounded, color: Color(0xFF0B9A67)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  teacher
                      ? 'اختبار المعلم • محاولة واحدة'
                      : '${StudentAssessmentRules.quizTypeLabel(quiz)} • ${taken ? '${quizResults.length} محاولات' : 'يمكنك الإعادة'}',
                  style: const TextStyle(color: Color(0xFF49617C), fontWeight: FontWeight.w700),
                ),
                if (questionCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$questionCount أسئلة',
                    style: const TextStyle(color: Color(0xFF49617C)),
                  ),
                ],
                const SizedBox(height: 14),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton(
                    onPressed: () => onOpen(quiz),
                    child: Text(teacher && taken ? 'عرض نتيجتي' : 'بدء الاختبار'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuestionList extends StatelessWidget {
  const _QuestionList({
    required this.questions,
    required this.answers,
    required this.questionIndex,
    required this.submitting,
    required this.onAnswer,
    required this.onPrevious,
    required this.onNext,
    required this.onSubmit,
  });

  final List<Map<String, dynamic>> questions;
  final Map<String, String> answers;
  final int questionIndex;
  final bool submitting;
  final void Function(String id, String value) onAnswer;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) return const SizedBox.shrink();
    final question = questions[questionIndex];
    final id = _questionId(question, questionIndex);
    final options = (question['options'] as List).map(_text).toList();
    final selected = answers[id];
    final isLast = questionIndex == questions.length - 1;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'السؤال ${questionIndex + 1} من ${questions.length}',
          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF49617C)),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: (questionIndex + 1) / questions.length,
            minHeight: 9,
            color: const Color(0xFFF59E0B),
            backgroundColor: const Color(0xFFE5EDF5),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(question['question']),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
                ),
                const SizedBox(height: 12),
                ...options.map(
                  (option) => RadioListTile<String>(
                    value: option,
                    groupValue: selected,
                    onChanged: submitting || option.isEmpty
                        ? null
                        : (value) => onAnswer(id, value!),
                    title: Text(option),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: submitting ? null : onPrevious,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('السابق'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: isLast
                  ? FilledButton.icon(
                      onPressed: submitting || selected == null ? null : onSubmit,
                      icon: submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.assignment_turned_in_rounded),
                      label: Text(submitting ? 'جارٍ الحفظ...' : 'تسليم الاختبار'),
                    )
                  : FilledButton.icon(
                      onPressed: submitting ? null : onNext,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('التالي'),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuizResultView extends StatelessWidget {
  const _QuizResultView({required this.result, required this.onBack});

  final Map<String, dynamic> result;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final percentage = int.tryParse('${result['percentage'] ?? ''}') ?? 0;
    final details = result['details'] is List
        ? (result['details'] as List)
            .whereType<Map>()
            .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
            .toList()
        : const <Map<String, dynamic>>[];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  percentage >= 60 ? Icons.emoji_events_rounded : Icons.menu_book_rounded,
                  size: 62,
                  color: percentage >= 60 ? const Color(0xFFF59E0B) : const Color(0xFF0B8693),
                ),
                const SizedBox(height: 12),
                Text(_text(result['quizTitle']).isEmpty ? 'نتيجتك' : _text(result['quizTitle']),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text('$percentage%', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900)),
                Text('${result['score'] ?? 0} من ${result['total'] ?? 0} إجابات صحيحة'),
                const SizedBox(height: 14),
                Text(_text(result['feedback']), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(onPressed: onBack, child: const Text('العودة للاختبارات')),
              ],
            ),
          ),
        ),
        if (details.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: ExpansionTile(
              initiallyExpanded: true,
              title: const Text(
                'تفاصيل الإجابات',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              children: details.asMap().entries.map((entry) {
                final detail = entry.value;
                final correct = detail['isCorrect'] == true;
                return ListTile(
                  leading: Icon(
                    correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: correct ? const Color(0xFF0B9A67) : const Color(0xFFB42318),
                  ),
                  title: Text('${entry.key + 1}. ${_text(detail['question'])}'),
                  subtitle: Text(
                    'إجابتك: ${_text(detail['userAnswer']).isEmpty ? '—' : _text(detail['userAnswer'])}\n'
                    'الصحيحة: ${_text(detail['correctAnswer'])}',
                  ),
                  isThreeLine: true,
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 54),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
}

String _text(Object? value) => value?.toString().trim() ?? '';

String _questionId(Map<String, dynamic> question, int index) =>
    StudentAssessmentRules.questionId(question, index);