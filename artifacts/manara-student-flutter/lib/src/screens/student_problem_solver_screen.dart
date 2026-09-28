import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/academic_context.dart';
import '../models/student_assessment.dart';
import '../models/student_content.dart';
import '../models/student_profile.dart';
import '../l10n/student_strings.dart';
import '../services/student_content_service.dart';
import '../services/student_auth_service.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../services/student_voice_service.dart';
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
    unawaited(_loadQuota());
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

  Uri? get _quotaEndpoint {
    final answer = _answerEndpoint;
    if (answer == null) return null;
    return answer.replace(path: answer.path.replaceFirst('/answer', '/quota'));
  }

  /// يقرأ الحصّة عند فتح الشاشة.
  ///
  /// كان العدّاد لا يظهر حتى يسأل الطفل سؤالاً أوّل، فيرى الحدَّ بعد أن
  /// يستهلك منه — وهو أسوأ وقتٍ لمعرفته.
  Future<void> _loadQuota() async {
    final endpoint = _quotaEndpoint;
    if (endpoint == null) return;
    try {
      final token = await widget.authService.ensureApiSession();
      if (token == null || token.isEmpty) return;
      final response = await http
          .get(endpoint, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final payload = jsonDecode(response.body);
      final quota = _QuotaBadge.fromJson(payload is Map ? payload['quota'] : null);
      if (!mounted || quota == null) return;
      setState(() => _quota = quota);
    } catch (_) {
      // تعذّرت القراءة: تُخفى الشارة ولا يُمنع السؤال. الخادم يحرس
      // الحدّ على كل حال.
    }
  }

  /// ما بقي من أسئلة اليوم، كما قاله الخادم في آخر ردّ.
  _QuotaBadge? _quota;

  late final StudentVoiceService _voice = StudentVoiceService();

  /// صورةُ المسألة، مرمّزةً، إن صوّرها الطفل.
  String? _photo;

  /// هل الميكروفون يسمع الآن؟
  bool _listening = false;

  /// هل يُنطق الجواب الآن؟
  bool _speaking = false;

  /// هل جاءت الإجابة الأخيرة من الذاكرة؟
  ///
  /// تُعرض للطفل شارةً: «من الذاكرة ⚡» تفسّر لماذا وصلت في طرفة عين
  /// ولماذا لم ينقص عدّاده — وبدونها يبدو العدّاد معطوباً.
  bool _fromCache = false;

  /// هل جاء السؤال الأخير بالصوت؟
  ///
  /// من سأل بصوته يُجاب بصوته: نطقُ الإجابة يبدأ من تلقائه له وحده.
  /// ومن كتب سؤاله يقرأ الجواب، ونطقٌ لم يطلبه مفاجأةٌ في صفٍّ صامت.
  bool _askedByVoice = false;

  /// يبدأ الإملاء أو يوقفه.
  Future<void> _toggleListening() async {
    if (_listening) {
      await _voice.stopListening();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final started = await _voice.listen(
      onResult: (heard) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          if (heard.isNotEmpty) {
            _questionController.text = heard;
            _askedByVoice = true;
          }
        });
      },
    );
    if (!mounted) return;
    if (!started) {
      // لا خدمة تعرّفٍ أو رُفض الإذن: يُقال ذلك ويبقى الحقل للكتابة.
      StudentSoundService.instance.play(StudentSoundCue.warning);
      setState(() => _error = tr('solver.micUnavailable'));
      return;
    }
    StudentSoundService.instance.playTap();
    setState(() {
      _listening = true;
      _error = null;
    });
  }

  /// يلتقط صورة المسألة أو يختارها من المعرض.
  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final shot = await picker.pickImage(
        source: source,
        // أبعادٌ تكفي لقراءة خطّ اليد ولا تنفخ الطلب: صورةُ كاميرا
        // كاملة تبلغ عدّة ميغابايتات، وأغلبها تفاصيلُ لا تُقرأ منها
        // مسألة.
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (shot == null) return;
      final bytes = await shot.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = base64Encode(bytes);
        _error = null;
      });
      StudentSoundService.instance.playTap();
    } catch (_) {
      if (!mounted) return;
      StudentSoundService.instance.play(StudentSoundCue.warning);
      setState(() => _error = tr('solver.cameraUnavailable'));
    }
  }

  /// متى أسكتت لمسةٌ على الشاشة النطقَ آخرَ مرّة.
  ///
  /// تُقرأ في [_toggleSpeaking] وحدها، ولها سببٌ واحد: اللمسة على زرّ
  /// النطق نفسه تمرّ بالحارس أوّلاً. الحارس يعمل عند نزول الإصبع والزرّ
  /// عند رفعه، فلو لم يُسجَّل الإسكات لوجد الزرُّ النطقَ متوقّفاً فأعاده
  /// — فيصير زرُّ الإيقاف زرَّ إعادةِ تشغيل.
  DateTime? _hushedAt;

  /// يُسكت النطق عند أوّل لمسةٍ في أي مكانٍ من الشاشة.
  ///
  /// ── لماذا ──
  /// الشرح دقيقتان، والطفل يسمع سطرين ثم يريد أن يكتب سؤالاً آخر أو
  /// يفتح صورةً. فيضغط، والصوت يواصل فوق ما يفعله، ولا زرَّ إيقافٍ في
  /// مرمى إصبعه إلا الذي بدأه. فصارت الشاشة كلُّها زرَّ إيقاف.
  ///
  /// و`Listener` لا `GestureDetector`: الثاني يدخل مسابقة الإيماءات
  /// فيبتلع اللمسة عن الحقل والأزرار تحته. وهذا يسمع نزول الإصبع ولا
  /// ينازع أحداً عليه.
  void _hushOnTap() {
    if (!_speaking && !_voice.speaking) return;
    _hushedAt = DateTime.now();
    unawaited(_voice.stopSpeaking());
    if (mounted) setState(() => _speaking = false);
  }

  /// ينطق الجواب أو يُسكته.
  Future<void> _toggleSpeaking() async {
    final answer = _answer;
    if (answer == null || answer.isEmpty) return;
    // لمسةُ هذا الزرّ نفسه أسكتت النطق قبل لحظة: فهي إيقافٌ تمّ، لا
    // طلبُ تشغيل.
    final hushed = _hushedAt;
    if (hushed != null &&
        DateTime.now().difference(hushed) < const Duration(milliseconds: 700)) {
      _hushedAt = null;
      return;
    }
    if (_speaking) {
      await _voice.stopSpeaking();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    await _voice.speak(answer);
    // المحرّك يُعلمنا بالانتهاء عبر الخدمة؛ وهذه تُبقي الزرّ صادقاً إن
    // لم يصل الإعلام على منصّةٍ ما.
    if (mounted) setState(() => _speaking = _voice.speaking);
  }

  /// هل يوافق الطفل على دفع الجواهر؟
  ///
  /// سؤالٌ لا خصمٌ صامت: الجواهر تُجمع بالدروس والاختبارات، ومن يجدها
  /// نقصت بلا أن يختار يفقد الثقة في العدّاد كلّه.
  Future<bool> _confirmGems(int price, int balance) async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: StudentSettings.direction,
        child: AlertDialog(
          title: Text(tr('solver.gemsTitle')),
          content: Text(
            trf('solver.gemsBody', {'price': '$price', 'gems': '$balance'}),
            style: const TextStyle(height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(tr('action.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(trf('solver.gemsConfirm', {'price': '$price'})),
            ),
          ],
        ),
      ),
    );
    return agreed == true;
  }

  Future<void> _ask({bool payWithGems = false}) async {
    final lesson = _selectedLesson;
    final photo = _photo;
    // صورةٌ بلا سؤالٍ مكتوب تحتاج طلباً: الخادم يردّ الطلب بلا سؤال.
    final question = PhotoQuestion.from(
      typed: _questionController.text,
      base64: photo ?? '',
    ).question;
    final endpoint = _answerEndpoint;
    if (lesson == null) {
      setState(() => _error = tr('solver.noLesson'));
      return;
    }
    if (question.isEmpty || (photo == null && _questionController.text.trim().isEmpty)) {
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
          body: jsonEncode({
            'lessonId': lesson.id,
            'question': question,
            if (photo != null) 'image': photo,
            if (photo != null) 'imageMimeType': 'image/jpeg',
            if (payWithGems) 'payWithGems': true,
          }),
        // ‏دقيقة كاملة: الخادم له ميزانية خمسين ثانية يجرّب فيها أكثر
        // ‏من نموذج، فقطعُ الخيط قبلها يُسقط إجابةً كانت في طريقها —
        // ‏وهو ما جعل البطاقة تجيب أحياناً وتتعذّر أحياناً.
        ).timeout(const Duration(seconds: 60));
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
        // الخادم يطلب إذناً بالدفع: يُسأل الطفل ثم يُعاد الإرسال.
        if (response.statusCode == 402 &&
            payload is Map &&
            payload['code'] == 'confirm_gems' &&
            !payWithGems) {
          final price = payload['gemPrice'] is num
              ? (payload['gemPrice'] as num).toInt()
              : 5;
          final quota = _QuotaBadge.fromJson(payload['quota']);
          if (mounted) {
            setState(() {
              _quota = quota;
              _sending = false;
            });
          }
          if (await _confirmGems(price, quota?.gems ?? 0)) {
            await _ask(payWithGems: true);
          }
          return;
        }
        if (payload is Map && payload['quota'] != null) {
          // ردُّ «انتهت حصّتك» يحمل الحال أيضاً، فتُحدَّث الشارة معه —
          // وإلا بقيت تقول «بقي ١» بعد أن نفد.
          final quota = _QuotaBadge.fromJson(payload['quota']);
          if (mounted) setState(() => _quota = quota);
        }
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
      setState(() {
        _answer = answer;
        _quota = _QuotaBadge.fromJson(payload is Map ? payload['quota'] : null);
        _fromCache = payload is Map && payload['cached'] == true;
        // الصورة تُستهلك بسؤالها: تركُها يجعل السؤال التالي يُرسل معها
        // بلا أن يقصد الطفل.
        _photo = null;
      });
      if (_askedByVoice) {
        _askedByVoice = false;
        unawaited(_toggleSpeaking());
      }
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
    // زرُّ الرجوع يوقف النطق قبل الانتقال.
    //
    // `dispose` تُنادى بعد أن يبدأ الانتقال، وبينهما جزءٌ من ثانية
    // يُسمع فيه آخرُ ما نُطق فوق الشاشة التالية.
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_voice.stopSpeaking());
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _hushOnTap(),
        child: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
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
                  // الحصّة فوق الحقل لا تحته: تُقرأ قبل أن يكتب الطفل
                  // سؤاله، لا بعد أن يُردّ.
                  if (_quota != null) ...[
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _QuotaChip(quota: _quota!),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // الميكروفون والكاميرا فوق الحقل: طريقان إلى السؤال
                  // نفسه، يراهما الطفل قبل أن يبدأ الكتابة لا بعدها.
                  Row(
                    children: [
                      _SolverAction(
                        icon: _listening ? Icons.stop_rounded : Icons.mic_rounded,
                        label: tr(_listening ? 'solver.micStop' : 'solver.mic'),
                        active: _listening,
                        onTap: _sending ? null : _toggleListening,
                      ),
                      const SizedBox(width: 8),
                      _SolverAction(
                        icon: Icons.photo_camera_rounded,
                        label: tr('solver.camera'),
                        active: _photo != null,
                        onTap: _sending ? null : () => _pickPhoto(ImageSource.camera),
                        onLongPress:
                            _sending ? null : () => _pickPhoto(ImageSource.gallery),
                      ),
                    ],
                  ),
                  if (_photo != null) ...[
                    const SizedBox(height: 8),
                    _PhotoStrip(
                      base64: _photo!,
                      onRemove: () => setState(() => _photo = null),
                    ),
                  ],
                  const SizedBox(height: 10),
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
                    const SizedBox(height: 8),
                    // مكبّر الصوت تحت الجواب لا فوقه: يُضغط بعد قراءته
                    // أو بدلاً منها، ولا معنى له قبل أن يصل.
                    Row(
                      children: [
                        _SolverAction(
                          icon: _speaking
                              ? Icons.stop_circle_rounded
                              : Icons.volume_up_rounded,
                          label: tr(_speaking ? 'solver.speakStop' : 'solver.speak'),
                          active: _speaking,
                          onTap: _toggleSpeaking,
                        ),
                        const SizedBox(width: 10),
                        Flexible(child: _SourceBadge(fromCache: _fromCache)),
                      ],
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


/// ما بقي للطفل من أسئلةٍ اليوم، وبكم السؤال بعدها.
///
/// ── لماذا تُعرض ──
/// حدٌّ لا يُرى يبدو عطباً: يسأل الطفل فيُردّ، فيظنّ التطبيق معطّلاً.
/// وعدّادٌ ظاهرٌ يجعل الحدّ قاعدةً يفهمها — ويجعل الجواهر التي يجمعها
/// من الدروس والاختبارات شيئاً يُنفَق على ما يريد.
class _QuotaBadge {
  const _QuotaBadge({
    required this.remainingFree,
    required this.freePerDay,
    required this.gemPrice,
    required this.gems,
    required this.canAsk,
  });

  final int remainingFree;
  final int freePerDay;
  final int gemPrice;
  final int gems;
  final bool canAsk;

  static _QuotaBadge? fromJson(Object? raw) {
    if (raw is! Map) return null;
    int number(Object? value) =>
        value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;
    return _QuotaBadge(
      remainingFree: number(raw['remainingFree']),
      freePerDay: number(raw['freePerDay']),
      gemPrice: number(raw['gemPrice']),
      gems: number(raw['gems']),
      canAsk: raw['canAsk'] != false,
    );
  }

  /// سطرٌ واحد يصف الحال.
  String get line => remainingFree > 0
      ? trf('solver.quotaFree', {'n': '$remainingFree', 'total': '$freePerDay'})
      : trf('solver.quotaGems', {'price': '$gemPrice', 'gems': '$gems'});

  bool get warning => remainingFree == 0;
}

/// شارةُ الحصّة فوق حقل السؤال.
class _QuotaChip extends StatelessWidget {
  const _QuotaChip({required this.quota});
  final _QuotaBadge quota;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: quota.warning
              ? const Color(0xFFFEF3C7)
              : const Color(0xFF0B8693).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: quota.warning
                ? const Color(0xFFF59E0B)
                : const Color(0xFF0B8693).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(quota.warning ? '💎' : '✨', style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                quota.line,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: quota.warning
                      ? const Color(0xFF92400E)
                      : const Color(0xFF0B8693),
                ),
              ),
            ),
          ],
        ),
      );
}


/// زرُّ إجراءٍ في بطاقة حلّ المسائل: أيقونةٌ واسم.
///
/// الاسم مكتوبٌ بجانب الأيقونة لا مخفيٌّ خلف ضغطةٍ طويلة: طفلٌ في
/// الابتدائية لا يعرف ما تعنيه أيقونةٌ لم يرها، والميكروفون والكاميرا
/// يبدوان متشابهين لمن لم يستعملهما.
class _SolverAction extends StatelessWidget {
  const _SolverAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.onLongPress,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final tint = active ? const Color(0xFFB42318) : const Color(0xFF7C3AED);
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: active ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tint.withValues(alpha: 0.45), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: tint),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: tint,
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

/// شريطُ الصورة الملتقطة، ومعه زرُّ إزالتها.
///
/// تُعرض مصغّرةً لأن الطفل يجب أن يرى ما صوّره قبل أن يُرسله: صورةٌ
/// مقلوبةٌ أو مقصوصة تُهدر سؤالاً، ومعرفةُ ذلك قبل الإرسال أرخص.
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.base64, required this.onRemove});

  final String base64;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: StudentSurface.glass(context, 0.86),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                base64Decode(base64),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr('solver.photoReady'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: StudentSurface.ink(context),
                ),
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
              tooltip: tr('solver.photoRemove'),
            ),
          ],
        ),
      );
}


/// من أين جاءت هذه الإجابة.
///
/// ── لماذا تُعرض لطفل ──
/// ليست تفصيلاً تقنياً: هي تفسيرُ ما يراه. إجابةٌ تصل في طرفة عين بينما
/// سابقتُها أخذت عشر ثوانٍ، وعدّادٌ لم ينقص بعد سؤال — بلا هذه الشارة
/// يبدوان عطباً. ومعها يفهم أن سؤاله سُئل من قبل، وأن الإجابة كانت
/// جاهزة.
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.fromCache});
  final bool fromCache;

  @override
  Widget build(BuildContext context) {
    final tint = fromCache ? const Color(0xFF0B8693) : const Color(0xFF7C3AED);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(fromCache ? '⚡' : '🤖', style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              tr(fromCache ? 'solver.fromCache' : 'solver.fromAi'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: tint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
