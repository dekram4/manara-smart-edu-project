import 'package:flutter/material.dart';

import '../models/academic_context.dart';
import '../models/student_profile.dart';
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
      setState(() {
        _quizzes = values[0] as List<Map<String, dynamic>>;
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

  bool _isTeacherQuiz(Map<String, dynamic> quiz) =>
      '${quiz['quizType'] ?? ''}'.toLowerCase().contains('teacher') ||
      '${quiz['quizType'] ?? ''}'.contains('معلم');

  List<Map<String, dynamic>> _quizQuestions(Map<String, dynamic> quiz) {
    final raw = quiz['questions'];
    if (raw is! List) return const [];
    final questions = raw
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
        .where((item) {
          final options = item['options'];
          return _text(item['question']).isNotEmpty && options is List && options.length >= 2;
        })
        .toList();
    final requested = int.tryParse('${quiz['questionsPerAttempt'] ?? ''}') ??
        int.tryParse('${quiz['questionCount'] ?? ''}') ??
        questions.length;
    final limit = requested.clamp(0, questions.length).toInt();
    final quizId = _text(quiz['id']);
    questions.sort(
      (left, right) => _stableQuestionHash(
        '${widget.profile.id}:$quizId:${_text(left['id'] ?? left['question'])}',
      ).compareTo(
        _stableQuestionHash(
          '${widget.profile.id}:$quizId:${_text(right['id'] ?? right['question'])}',
        ),
      ),
    );
    return questions.take(limit).toList();
  }

  Map<String, dynamic>? _previousResult(String quizId) {
    for (final result in _results) {
      if (_text(result['quizId']) == quizId) return result;
    }
    return null;
  }

  void _openQuiz(Map<String, dynamic> quiz) {
    final quizId = _text(quiz['id']);
    final previous = _previousResult(quizId);
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
      _shownResult = null;
    });
  }

  bool _isCorrect(Map<String, dynamic> question, String answer) {
    final options = (question['options'] as List).map((item) => _text(item)).toList();
    final raw = _text(question['correctAnswer']);
    final normalized = _normalize(raw);
    const latin = ['a', 'b', 'c', 'd'];
    const arabic = ['أ', 'ب', 'ج', 'د'];
    var index = latin.indexOf(normalized);
    if (index < 0) index = arabic.indexOf(raw.trim());
    if (index < 0) {
      final numeric = int.tryParse(normalized);
     if (numeric != null) {
       if (numeric >= 1 && numeric <= options.length) {
         index = numeric - 1;
       } else if (numeric >= 0 && numeric < options.length) {
         index = numeric;
       }
     }
    }
    final correct = index >= 0 && index < options.length ? options[index] : raw;
    return _normalize(answer) == _normalize(correct);
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
      return _isCorrect(entry.value, _answers[_questionId(entry.value, entry.key)] ?? '');
    }).length;
    final percentage = ((score / _questions.length) * 100).round();
    final now = DateTime.now().toIso8601String();
    final result = <String, dynamic>{
      'id': 'result_${widget.profile.id}_${DateTime.now().microsecondsSinceEpoch}',
      'studentId': widget.profile.id,
      'studentName': widget.profile.name,
      'quizId': _text(quiz['id']),
      'quizType': _text(quiz['quizType']).isEmpty ? 'periodic' : _text(quiz['quizType']),
      'quizTitle': _text(quiz['title']).isEmpty ? 'اختبار منارة' : _text(quiz['title']),
      'subject': _text(quiz['subject']),
      'unit': _text(quiz['unit']),
      'grade': _text(quiz['grade']),
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
          'question': _text(question['question']),
          'userAnswer': answer,
          'correctAnswer': _correctAnswerText(question),
          'isCorrect': _isCorrect(question, answer),
        };
      }).toList(),
      'createdAt': now,
      'attemptNumber': _results.where((item) => _text(item['quizId']) == _text(quiz['id'])).length + 1,
      'isRetake': _results.any((item) => _text(item['quizId']) == _text(quiz['id'])),
    };
    try {
       final savedResult = await widget.contentService.saveQuizResult(
         profile: widget.profile,
         result: result,
       );
      if (!mounted) return;
      setState(() {
         _results = [savedResult, ..._results];
         _shownResult = savedResult;
        _activeQuiz = null;
        _questions = const [];
        _answers.clear();
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
                            submitting: _submitting,
                            onAnswer: (id, value) => setState(() => _answers[id] = value),
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
        final taken = results.any((item) => _text(item['quizId']) == _text(quiz['id']));
        final teacher = isTeacherQuiz(quiz);
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
                  teacher ? 'اختبار المعلم • محاولة واحدة' : 'اختبار دوري',
                  style: const TextStyle(color: Color(0xFF49617C), fontWeight: FontWeight.w700),
                ),
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
    required this.submitting,
    required this.onAnswer,
    required this.onSubmit,
  });

  final List<Map<String, dynamic>> questions;
  final Map<String, String> answers;
  final bool submitting;
  final void Function(String id, String value) onAnswer;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...questions.asMap().entries.map((entry) {
            final question = entry.value;
            final id = _questionId(question, entry.key);
            final options = (question['options'] as List).map(_text).toList();
            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${entry.key + 1}. ${_text(question['question'])}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                    const SizedBox(height: 10),
                    ...options.map(
                      (option) => RadioListTile<String>(
                        value: option,
                        groupValue: answers[id],
                        onChanged: submitting || option.isEmpty ? null : (value) => onAnswer(id, value!),
                        title: Text(option),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: submitting ? null : onSubmit,
            icon: submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.assignment_turned_in_rounded),
            label: Text(submitting ? 'جارٍ حفظ نتيجتك...' : 'إرسال الاختبار'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ],
      );
}

class _QuizResultView extends StatelessWidget {
  const _QuizResultView({required this.result, required this.onBack});

  final Map<String, dynamic> result;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final percentage = int.tryParse('${result['percentage'] ?? ''}') ?? 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
      ),
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

String _normalize(Object? value) =>
    _text(value).toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String _questionId(Map<String, dynamic> question, int index) =>
    _text(question['id']).isEmpty ? 'question-$index' : '${_text(question['id'])}-$index';

String _correctAnswerText(Map<String, dynamic> question) {
  final options = (question['options'] as List).map(_text).toList();
  final answer = _text(question['correctAnswer']);
  final lower = answer.toLowerCase();
  const latin = ['a', 'b', 'c', 'd'];
  const arabic = ['أ', 'ب', 'ج', 'د'];
  var index = latin.indexOf(lower);
  if (index < 0) index = arabic.indexOf(answer);
   final numeric = int.tryParse(lower);
   if (index < 0 && numeric != null) {
     if (numeric >= 1 && numeric <= options.length) {
       index = numeric - 1;
     } else if (numeric >= 0 && numeric < options.length) {
       index = numeric;
     }
  }
  return index >= 0 && index < options.length ? options[index] : answer;
}

int _stableQuestionHash(String value) {
  var hash = 2166136261;
  for (final code in value.codeUnits) {
    hash ^= code;
    hash = (hash * 16777619) & 0xffffffff;
  }
  return hash;
}