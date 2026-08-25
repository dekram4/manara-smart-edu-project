import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/academic_context.dart';
import '../models/student_assessment.dart';
import '../models/student_content.dart';
import '../models/student_profile.dart';
import '../services/student_content_service.dart';
import '../services/student_auth_service.dart';

class StudentProblemSolverScreen extends StatefulWidget {
  const StudentProblemSolverScreen({
    required this.lessons,
    required this.apiBaseUrl,
    required this.profile,
    required this.contentService,
    required this.authService,
    this.academicContext,
    super.key,
  });

  final List<LessonContent> lessons;
  final String apiBaseUrl;
  final StudentProfile profile;
  final StudentContentService contentService;
  final StudentAuthService authService;
  final AcademicContext? academicContext;

  @override
  State<StudentProblemSolverScreen> createState() => _StudentProblemSolverScreenState();
}

class _StudentProblemSolverScreenState extends State<StudentProblemSolverScreen> {
  final _questionController = TextEditingController();
  LessonContent? _selectedLesson;
  bool _sending = false;
  String? _answer;
  String? _error;

  List<LessonContent> get _supportedLessons => widget.lessons
      .where((lesson) => (lesson.lessonText ?? '').trim().isNotEmpty)
      .where(_isAvailableToStudent)
      .toList();

  bool _isAvailableToStudent(LessonContent lesson) {
    final owner = StudentAssessmentRules.ownerId({
      'teacherId': lesson.ownerId,
    });
    final teacher = widget.profile.teacherId?.trim().toLowerCase() ?? '';
    final allowedOwner =
        owner.isEmpty || owner == 'admin' || owner == 'supervisor' || owner == teacher;
    if (!allowedOwner) return false;
    return StudentAssessmentRules.matchesAcademicScope(
      {
        'grade': lesson.grade,
        'atram': lesson.atram,
        'subject': lesson.subject,
        'term': lesson.term,
        'unit': lesson.unit,
      },
      widget.profile,
      academicContext: widget.academicContext,
    );
  }

  @override
  void initState() {
    super.initState();
    final supported = _supportedLessons;
    final activeLessonId = widget.academicContext?.selectedLesson.id;
    final activeLessons =
        supported.where((lesson) => lesson.id == activeLessonId).toList();
    _selectedLesson = activeLessons.isNotEmpty
        ? activeLessons.first
        : (supported.isEmpty ? null : supported.first);
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Uri? get _answerEndpoint {
    var base = widget.apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    if (base.isEmpty) {
      final current = Uri.base;
      if (current.scheme == 'http' || current.scheme == 'https') {
        base = current.host == 'localhost' || current.host == '127.0.0.1'
            ? 'http://localhost:8080'
            : current.origin;
      }
    }
    return base.isEmpty ? null : Uri.tryParse('$base/api/gemini/answer');
  }

  Future<void> _ask() async {
    final lesson = _selectedLesson;
    final question = _questionController.text.trim();
    final endpoint = _answerEndpoint;
    if (lesson == null) {
      setState(() => _error = 'لا توجد مادة تعليمية صالحة للمساعدة فيها الآن.');
      return;
    }
    if (question.isEmpty) {
      setState(() => _error = 'اكتب سؤالك أولًا.');
      return;
    }
    if (endpoint == null) {
      setState(() => _error = 'لم يتم إعداد اتصال خدمة المساعد في هذا التطبيق.');
      return;
    }
    final token = await widget.authService.ensureApiSession();
    if (token == null || token.isEmpty) {
      setState(() => _error = 'انتهت جلسة الطالب الآمنة. سجّل الدخول مرة أخرى للمتابعة.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
      _answer = null;
    });
    try {
      final response = await http.post(
        endpoint,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'lessonId': lesson.id, 'question': question}),
      ).timeout(const Duration(seconds: 25));
       Object? payload;
       try {
         payload = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
       } on FormatException {
         throw Exception('استجابة الخدمة غير صالحة. حاول مرة أخرى.');
       }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = payload is Map ? payload['error']?.toString() : null;
        throw Exception(message?.trim().isNotEmpty == true ? message : 'تعذر الحصول على إجابة.');
      }
      final answer = payload is Map ? payload['answer']?.toString().trim() : null;
      if (answer == null || answer.isEmpty) {
        throw Exception('لم تصل إجابة صالحة. حاول مرة أخرى.');
      }
      if (!mounted) return;
      setState(() => _answer = answer);
    } catch (error) {
      if (!mounted) return;
       setState(() => _error = _studentSafeError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supported = _supportedLessons;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FF),
        appBar: AppBar(title: const Text('حلّ المسائل'), centerTitle: true),
        body: supported.isEmpty
            ? const _SolverEmptyState()
            : ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  const Text(
                    'اسأل عن درسك',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'سيجيب المساعد من محتوى الدرس الذي اختاره معلمك.',
                    style: TextStyle(color: Color(0xFF49617C), fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _questionController,
                    enabled: !_sending,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'اكتب مسألتك أو سؤالك',
                      hintText: 'مثال: كيف نحل هذه المسألة؟',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FilledButton.icon(
                    onPressed: _sending ? null : _ask,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(_sending ? 'جارٍ التفكير...' : 'ساعدني في الحل'),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _MessageCard(
                      icon: Icons.error_outline_rounded,
                      color: const Color(0xFFB42318),
                      text: _error!,
                    ),
                  ],
                  if (_answer != null) ...[
                    const SizedBox(height: 16),
                    _MessageCard(
                      icon: Icons.lightbulb_rounded,
                      color: const Color(0xFF0B8693),
                      text: _answer!,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _SolverEmptyState extends StatelessWidget {
  const _SolverEmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined, size: 60, color: Color(0xFF0B8693)),
              SizedBox(height: 14),
              Text(
                'لم يُضف المعلم محتوى نصيًا لهذا الدرس بعد، لذلك لا يستطيع المساعد الإجابة بأمان.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: color.withAlpha(100)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: SelectableText(
                text,
                style: const TextStyle(height: 1.65, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

String _studentSafeError(Object error) {
  final message = error.toString().replaceFirst('Exception: ', '').trim();
  if (message.contains('استجابة الخدمة غير صالحة')) return message;
  if (message.contains('لم تصل إجابة صالحة')) return message;
  if (message.contains('تعذر الحصول على إجابة')) return message;
  return 'تعذر حل السؤال الآن. تحقق من الاتصال ثم حاول مرة أخرى.';
}