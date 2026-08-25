import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/academic_context.dart';
import '../models/student_content.dart';
import '../models/student_profile.dart';
import '../services/student_auth_service.dart';
import '../services/student_sound_service.dart';
import '../services/student_content_service.dart';
import '../widgets/manara_logo.dart';
import '../widgets/student_experience.dart';
import 'student_home_screen.dart';

class AcademicSelectionScreen extends StatefulWidget {
  const AcademicSelectionScreen({
    required this.profile,
    required this.authService,
    required this.apiBaseUrl,
    super.key,
  });

  final StudentProfile profile;
  final StudentAuthService authService;
  final String apiBaseUrl;

  @override
  State<AcademicSelectionScreen> createState() => _AcademicSelectionScreenState();
}

class _AcademicSelectionScreenState extends State<AcademicSelectionScreen> {
  late final StudentContentService _contentService;
  AcademicSelectionData? _data;
  String? _grade;
  String? _atram;
  String? _subject;
  String? _term;
  String? _unit;
  LessonContent? _lesson;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _contentService = StudentContentService(
      widget.authService.client,
      baseUrl: widget.apiBaseUrl,
    );
    _loadSelectionData();
  }

  Future<void> _loadSelectionData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final data = await _contentService.fetchAcademicSelectionData(widget.profile);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        if (data.isEmpty) {
          _loadError =
              'لا توجد مسارات أكاديمية مكتملة مرتبطة بدروس متاحة لحسابك حاليًا.';
          _clearSelection();
          return;
        }
        _applyInitialSelection(data);
        if (data.hierarchyUnavailable) {
          _loadError =
              'تعذر قراءة إعدادات الشجرة؛ تم عرض المسارات المكتملة من الدروس المتاحة فقط.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _data = null;
        _clearSelection();
        _loadError = 'تعذر تحميل البيانات الأكاديمية من Supabase: $error';
      });
    }
  }

  void _clearSelection() {
    _grade = null;
    _atram = null;
    _subject = null;
    _term = null;
    _unit = null;
    _lesson = null;
  }

  void _applyInitialSelection(AcademicSelectionData data) {
    final grade = _pick(data.grades, widget.profile.grade);
    final atram = _pick(data.atramsFor(grade), widget.profile.atram);
    final subject = _pick(
      data.subjectsFor(grade: grade, atram: atram),
      widget.profile.subject,
    );
    final term = _pick(
      data.termsFor(grade: grade, atram: atram, subject: subject),
      widget.profile.term,
    );
    final unit = _pick(
      data.unitsFor(
        grade: grade,
        atram: atram,
        subject: subject,
        term: term,
      ),
      widget.profile.unit,
    );
    final lessons = data.lessonsFor(
      grade: grade,
      atram: atram,
      subject: subject,
      term: term,
      unit: unit,
    );

    _grade = grade;
    _atram = atram;
    _subject = subject;
    _term = term;
    _unit = unit;
    _lesson = lessons.isEmpty ? null : lessons.first;
  }

  String _pick(List<String> values, String? preferred) {
    if (values.isEmpty) return '';
    final matched = values.where(
      (value) => _normalized(value) == _normalized(preferred),
    );
    return matched.isEmpty ? values.first : matched.first;
  }

  void _selectGrade(String? grade) {
    final data = _data;
    if (data == null || grade == null) return;
    setState(() {
      _grade = grade;
      _atram = _pick(data.atramsFor(grade), null);
      _subject = _pick(
        data.subjectsFor(grade: _grade!, atram: _atram!),
        null,
      );
      _term = _pick(
        data.termsFor(
          grade: _grade!,
          atram: _atram!,
          subject: _subject!,
        ),
        null,
      );
      _unit = _pick(
        data.unitsFor(
          grade: _grade!,
          atram: _atram!,
          subject: _subject!,
          term: _term!,
        ),
        null,
      );
      _lesson = _lessonsForSelection().firstOrNull;
    });
  }

  void _selectAtram(String? atram) {
    final data = _data;
    if (data == null || _grade == null || atram == null) return;
    setState(() {
      _atram = atram;
      _subject = _pick(data.subjectsFor(grade: _grade!, atram: atram), null);
      _term = _pick(
        data.termsFor(
          grade: _grade!,
          atram: _atram!,
          subject: _subject!,
        ),
        null,
      );
      _unit = _pick(
        data.unitsFor(
          grade: _grade!,
          atram: _atram!,
          subject: _subject!,
          term: _term!,
        ),
        null,
      );
      _lesson = _lessonsForSelection().firstOrNull;
    });
  }

  void _selectSubject(String? subject) {
    final data = _data;
    if (data == null || _grade == null || _atram == null || subject == null) return;
    setState(() {
      _subject = subject;
      _term = _pick(
        data.termsFor(grade: _grade!, atram: _atram!, subject: subject),
        null,
      );
      _unit = _pick(
        data.unitsFor(
          grade: _grade!,
          atram: _atram!,
          subject: _subject!,
          term: _term!,
        ),
        null,
      );
      _lesson = _lessonsForSelection().firstOrNull;
    });
  }

  void _selectTerm(String? term) {
    final data = _data;
    if (data == null ||
        _grade == null ||
        _atram == null ||
        _subject == null ||
        term == null) {
      return;
    }
    setState(() {
      _term = term;
      _unit = _pick(
        data.unitsFor(
          grade: _grade!,
          atram: _atram!,
          subject: _subject!,
          term: term,
        ),
        null,
      );
      _lesson = _lessonsForSelection().firstOrNull;
    });
  }

  void _selectUnit(String? unit) {
    if (unit == null) return;
    setState(() {
      _unit = unit;
      _lesson = _lessonsForSelection().firstOrNull;
    });
  }

  List<LessonContent> _lessonsForSelection() {
    final data = _data;
    if (data == null ||
        _grade == null ||
        _atram == null ||
        _subject == null ||
        _term == null ||
        _unit == null) {
      return const [];
    }
    return data.lessonsFor(
      grade: _grade!,
      atram: _atram!,
      subject: _subject!,
      term: _term!,
      unit: _unit!,
    );
  }

  AcademicContext? get _selection {
    final lesson = _lesson;
    if (lesson == null ||
        _grade == null ||
        _atram == null ||
        _subject == null ||
        _term == null ||
        _unit == null) {
      return null;
    }
    return AcademicContext(
      grade: _grade!,
      atram: _atram!,
      subject: _subject!,
      term: _term!,
      unit: _unit!,
      selectedLesson: lesson,
    );
  }

  Future<void> _enterDashboard() async {
    final selection = _selection;
    if (selection == null) return;
    StudentSoundService.instance.play(StudentSoundCue.navigation);
    await Navigator.of(context).pushReplacement(
      StudentPageRoute<void>(
        builder: (_) => StudentDashboardScreen(
          profile: widget.profile,
          authService: widget.authService,
          apiBaseUrl: widget.apiBaseUrl,
          academicContext: selection,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final atrams = data == null || _grade == null
        ? const <String>[]
        : data.atramsFor(_grade!);
    final subjects = data == null || _grade == null || _atram == null
        ? const <String>[]
        : data.subjectsFor(grade: _grade!, atram: _atram!);
    final terms = data == null || _grade == null || _atram == null || _subject == null
        ? const <String>[]
        : data.termsFor(
            grade: _grade!,
            atram: _atram!,
            subject: _subject!,
          );
    final units =
        data == null || _grade == null || _atram == null || _subject == null || _term == null
            ? const <String>[]
            : data.unitsFor(
                grade: _grade!,
                atram: _atram!,
                subject: _subject!,
                term: _term!,
              );
    final lessons = _lessonsForSelection();

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF07272E), Color(0xFF0E1B2A), Color(0xFF274E76)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: IconTheme(
                        data: IconThemeData(color: Colors.white),
                        child: StudentSoundToggle(),
                      ),
                    ),
                    const ManaraLogo(size: 84),
                    const SizedBox(height: 12),
                    const Text(
                      'اختر رحلتك التعليمية',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
                    const SizedBox(height: 6),
                    Text(
                      'أهلًا ${widget.profile.name}، حدّد الدرس الذي تريد البدء به',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF9EEBEA),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Card(
                      elevation: 18,
                      shadowColor: Colors.black54,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'المسار الأكاديمي',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Color(0xFF0E1B2A),
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'تظهر كل قائمة بعد اختيار المستوى السابق لها.',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_loadError != null) ...[
                              const SizedBox(height: 12),
                              _InfoBanner(message: _loadError!),
                            ],
                            const SizedBox(height: 18),
                            if (_loading)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 32),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF0B8693),
                                  ),
                                ),
                              )
                            else ...[
                              _AcademicDropdown(
                                label: 'الصف الدراسي',
                                icon: Icons.school_rounded,
                                value: _grade,
                                options: data?.grades ?? const [],
                                onChanged: _selectGrade,
                              ),
                              _AcademicDropdown(
                                label: 'الفصل الدراسي / الترم',
                                icon: Icons.calendar_month_rounded,
                                value: _atram,
                                options: atrams,
                                onChanged: atrams.isEmpty ? null : _selectAtram,
                              ),
                              _AcademicDropdown(
                                label: 'المادة الدراسية',
                                icon: Icons.menu_book_rounded,
                                value: _subject,
                                options: subjects,
                                onChanged: subjects.isEmpty ? null : _selectSubject,
                              ),
                              _AcademicDropdown(
                                label: 'الفصل أو الباب',
                                icon: Icons.account_tree_rounded,
                                value: _term,
                                options: terms,
                                onChanged: terms.isEmpty ? null : _selectTerm,
                              ),
                              _AcademicDropdown(
                                label: 'الوحدة التعليمية',
                                icon: Icons.view_list_rounded,
                                value: _unit,
                                options: units,
                                onChanged: units.isEmpty ? null : _selectUnit,
                              ),
                              _LessonDropdown(
                                value: _lesson?.id,
                                lessons: lessons,
                                onChanged: lessons.isEmpty
                                    ? null
                                    : (lessonId) => setState(
                                          () => _lesson = lessons.firstWhere(
                                            (lesson) => lesson.id == lessonId,
                                          ),
                                        ),
                              ),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: _selection == null ? null : _enterDashboard,
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: const Text('الدخول إلى لوحة الطالب'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56),
                                  backgroundColor: const Color(0xFF0B8693),
                                  foregroundColor: Colors.white,
                                  textStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(17),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.1),
                    if (_selection != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        '${_selection!.label}\nمعرّف الدرس: ${_selection!.lessonId}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AcademicDropdown extends StatelessWidget {
  const _AcademicDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String? value;
  final List<String> options;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        onChanged: onChanged,
        hint: Text(options.isEmpty ? 'لا توجد خيارات متاحة' : 'اختر $label'),
        icon: const Icon(Icons.expand_more_rounded),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF0B8693)),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _LessonDropdown extends StatelessWidget {
  const _LessonDropdown({
    required this.value,
    required this.lessons,
    required this.onChanged,
  });

  final String? value;
  final List<LessonContent> lessons;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        onChanged: onChanged,
        hint: Text(lessons.isEmpty ? 'لا توجد دروس في هذه الوحدة' : 'اختر الدرس'),
        icon: const Icon(Icons.expand_more_rounded),
        decoration: const InputDecoration(
          labelText: 'الدرس الحالي',
          prefixIcon: Icon(Icons.play_lesson_rounded, color: Color(0xFF0B8693)),
        ),
        items: lessons
            .map(
              (lesson) => DropdownMenuItem<String>(
                value: lesson.id,
                child: Text(
                  lesson.lessonName.isEmpty ? 'درس بدون عنوان' : lesson.lessonName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF92400E),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

String _normalized(Object? value) => value?.toString().trim().toLowerCase() ?? '';