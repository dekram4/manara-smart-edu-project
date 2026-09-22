import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/academic_context.dart';
import '../models/student_assessment.dart';
import '../models/student_content.dart';
import '../models/student_profile.dart';
import '../l10n/student_strings.dart';
import '../services/student_content_service.dart';
import '../services/student_auth_service.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import '../widgets/portal_watermark.dart';
import '../widgets/student_experience.dart';

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
      setState(() => _error = tr('solver.noLesson'));
      return;
    }
    if (question.isEmpty) {
      setState(() => _error = tr('solver.writeFirst'));
      return;
    }
    if (endpoint == null) {
      setState(() => _error = tr('solver.noService'));
      return;
    }
    final token = await widget.authService.ensureApiSession();
    if (token == null || token.isEmpty) {
      setState(
        () => _error = widget.authService.apiSessionError ??
            tr('solver.sessionFailed'),
      );
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
      _answer = null;
    });
    try {
      late http.Response response;
      for (var attempt = 0; attempt < 2; attempt++) {
        response = await http.post(
          endpoint,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'lessonId': lesson.id, 'question': question}),
        ).timeout(const Duration(seconds: 25));
        final transientFailure = response.statusCode == 408 ||
            response.statusCode == 429 ||
            response.statusCode == 500 ||
            response.statusCode == 502 ||
            response.statusCode == 503;
        if (!transientFailure || attempt == 1) break;
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
       Object? payload;
       try {
         payload = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
       } on FormatException {
         throw Exception(tr('solver.badResponse'));
       }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = payload is Map ? payload['error']?.toString().trim() : null;
        // ‏كل ما قاله الخادم يُعرض كما قاله، مهما كان رمز الحالة.
        //
        // ‏كان يُعرض رفض الـ 4xx وحده، ويُبتلع ما سواه في «تعذّر حل
        // ‏السؤال، تحقّق من الاتصال» — وهناك بالضبط تقع أعطال الذكاء
        // ‏الاصطناعي: 502 حين لا تصل إجابة، و500 حين يسقط الطلب إلى
        // ‏Gemini، و503 حين ينقص المفتاح. فتُرسَل الشكوى إلى الشبكة
        // ‏والشبكة سليمة، ولا يُعرف أن الخادم قال شيئاً محدّداً.
        //
        // ‏ولا يبقى للرسالة العامة إلا موضعها الصحيح: انقطاعٌ فعليّ لا
        // ‏يصل معه ردّ أصلاً، فيُرمى من `http.post` قبل بلوغ هذا السطر.
        if (message != null && message.isNotEmpty) {
          throw _ExplainedFailure(message);
        }
        throw _ExplainedFailure(
          '${tr('solver.serviceSilent')} (${response.statusCode})',
        );
      }
      final answer = payload is Map ? payload['answer']?.toString().trim() : null;
      if (answer == null || answer.isEmpty) {
        throw Exception(tr('solver.noAnswer'));
      }
      // السؤال يُسجَّل ولا يُكافأ.
      //
      // كانت البطاقة تمنح جواهر على كل سؤال جديد، وهي بطاقة شرح ومساعدة:
      // الجائزة على السؤال تعلّم الطفل أن يسأل ليكسب لا ليفهم، ويكفي أن
      // يكتب أي كلام جديد ليأخذ جواهره. والتسجيل يبقى لأنه ليس مكافأة:
      // منه يعرف المعلم وولي الأمر بمَ استعان الطفل.
      try {
        await widget.contentService.saveProblemSolverInteraction(
          profile: widget.profile,
          lessonId: lesson.id,
          question: question,
        );
      } catch (_) {
        // The answer itself is still useful when progress sync is temporarily offline.
      }
      if (!mounted) return;
      setState(() => _answer = answer);
      StudentSoundService.instance.playTap();
    } catch (error) {
      StudentSoundService.instance.play(StudentSoundCue.warning);
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
      textDirection: StudentSettings.direction,
      child: Scaffold(
        backgroundColor: StudentSurface.ground(context),
        // Stated rather than inherited: the question box is the point of
        // this screen, and the keyboard must shorten the page rather than
        // sit on top of what the student is typing.
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
            title: Text(tr('solver.title')),
            centerTitle: true,
            actions: const [StudentSoundToggle()]),
        body: Stack(
          children: [
            const PortalWatermark(asset: PortalBackgrounds.problemSolver),
            supported.isEmpty
            ? const StudentEntrance(child: _SolverEmptyState())
            : ListView(
                physics: const BouncingScrollPhysics(),
                // Room under the last card equal to the keyboard, so the
                // field being focused always has somewhere to scroll to.
                // Without it a landscape phone runs out of list before the
                // box clears the keys, and Flutter's own scroll-into-view
                // has nothing left to give.
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  18 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                children: [
                   StudentScreenHero(
                     title: tr('solver.title'),
                     subtitle: tr('solver.blurb'),
                     icon: Icons.auto_awesome_rounded,
                     colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
                  ),
                  const SizedBox(height: 18),
                  StudentEntrance(
                    delay: const Duration(milliseconds: 100),
                    child: TextField(
                      controller: _questionController,
                      enabled: !_sending,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 2000,
                      decoration: InputDecoration(
                        labelText: tr('solver.questionLabel'),
                        hintText: tr('solver.questionHint'),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  StudentEntrance(
                    delay: const Duration(milliseconds: 150),
                    child: _AskButton(sending: _sending, onPressed: _ask),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    StudentEntrance(
                      child: _MessageCard(
                        icon: Icons.error_outline_rounded,
                        color: const Color(0xFFB42318),
                        text: _error!,
                      ),
                    ),
                  ],
                  if (_answer != null) ...[
                    const SizedBox(height: 16),
                    StudentEntrance(
                      child: _MessageCard(
                        icon: Icons.lightbulb_rounded,
                        color: const Color(0xFF0B8693),
                        text: _answer!,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The assistant's call to action, as a raised capsule in Manara's teal
/// rather than a flat default button — it is the one thing on this screen
/// the student is meant to press.
class _AskButton extends StatelessWidget {
  const _AskButton({required this.sending, required this.onPressed});

  final bool sending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const ledge = Color(0xFF075A63);
    return StudentPressScale(
      child: GestureDetector(
        onTap: sending ? null : onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.only(bottom: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: sending ? const Color(0xFF6B7280) : ledge,
            boxShadow: [
              BoxShadow(
                color: (sending ? const Color(0xFF6B7280) : ledge)
                    .withValues(alpha: 0.42),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: sending
                    ? const [Color(0xFF9CA3AF), Color(0xFF6B7280)]
                    : const [Color(0xFF22D3EE), Color(0xFF0B8693)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sending)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                else
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                const SizedBox(width: 10),
                Text(
                  tr(sending ? 'solver.thinking' : 'solver.ask'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: Color(0x55000000), blurRadius: 4)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SolverEmptyState extends StatelessWidget {
  const _SolverEmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined, size: 60, color: Color(0xFF0B8693)),
              SizedBox(height: 14),
              Text(
                tr('solver.noText'),
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

  /// الخلفية والحبر من السمة، لا لونان ثابتان.
  ///
  /// كانت الخلفية بيضاء مكتوبة في الشيفرة، والنصّ بلا لون فيرث لون السمة
  /// — وهو فاتحٌ في الوضع الداكن. فالإجابة تُكتب أبيضَ على أبيض، ولا
  /// تظهر للطفل إلا إن ظلّلها بإصبعه.
  ///
  /// و`StudentSurface` هي ما تقرؤه بقية الشاشات، فيصير هذا الكرت مثلها
  /// في الوضعين بدل أن يكون له لونه الخاص.
  @override
  Widget build(BuildContext context) => Student3DCard(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: StudentSurface.card(context),
            border: Border.all(color: color.withAlpha(100)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الأيقونة تحتفظ بلونها الدالّ — أخضر للإجابة وأحمر للخطأ —
              // لكنها تُفتَّح في الوضع الداكن لئلّا تغرق في الخلفية.
              Icon(
                icon,
                color: StudentSurface.isDark(context)
                    ? Color.lerp(color, Colors.white, 0.45)
                    : color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SelectableText(
                  text,
                  style: TextStyle(
                    color: StudentSurface.ink(context),
                    height: 1.65,
                    fontWeight: FontWeight.w600,
                    fontSize: 15.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

/// رفضٌ شرح الخادمُ سببَه، فيُعرض نصّه بلا تبديل.
class _ExplainedFailure implements Exception {
  const _ExplainedFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

String _studentSafeError(Object error) {
  if (error is _ExplainedFailure) return error.message;
  final message = error.toString().replaceFirst('Exception: ', '').trim();
  // These three are thrown by this screen itself, from the same
  // dictionary the comparison reads, so they match in either language;
  // anything else came off the wire and is replaced with a sentence a
  // child can act on.
  for (final own in const ['solver.badResponse', 'solver.noAnswer', 'solver.serviceSilent']) {
    if (message.contains(tr(own))) return message;
  }
  return tr('solver.failed');
}
