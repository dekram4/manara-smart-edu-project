import 'package:flutter/material.dart';

import '../models/academic_context.dart';
import '../models/student_content.dart';
import '../models/student_profile.dart';
import '../services/student_auth_service.dart';
import '../services/student_sound_service.dart';
import '../services/student_content_service.dart';
import '../theme/student_theme.dart';
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
  bool _isEntering = false;
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
    _playSelectionFeedback();
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
    _playSelectionFeedback();
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
    _playSelectionFeedback();
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
    _playSelectionFeedback();
  }

  void _selectUnit(String? unit) {
    if (unit == null) return;
    setState(() {
      _unit = unit;
      _lesson = _lessonsForSelection().firstOrNull;
    });
    _playSelectionFeedback();
  }

  void _playSelectionFeedback() {
    StudentSoundService.instance.play(StudentSoundCue.answerSelected);
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
    if (selection == null || _isEntering) return;
    StudentSoundService.instance.playTap();
    setState(() => _isEntering = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        StudentPageRoute<void>(
          builder: (_) => StudentHomeScreen(
            profile: widget.profile,
            authService: widget.authService,
            apiBaseUrl: widget.apiBaseUrl,
            academicContext: selection,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isEntering = false);
    }
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
      backgroundColor: StudentPalette.canvas,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Color(0xFFF3F7FF),
                    Color(0xFFEFF6FF),
                    Color(0xFFF5F3FF),
                  ],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: StudentLearningWorld()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 660),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              ManaraLogo(size: 52),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'مَنارة',
                                    style: TextStyle(
                                      color: StudentPalette.ink,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'MANARA SMART EDU',
                                    textDirection: TextDirection.ltr,
                                    style: TextStyle(
                                      color: StudentPalette.indigo,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0xB3FFFCF3),
                              borderRadius: BorderRadius.all(Radius.circular(16)),
                            ),
                            child: StudentSoundToggle(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      StudentEntrance(
                        child: Column(
                          children: [
                            const StudentCompanion(size: 108, showLabel: false),
                            const SizedBox(height: 6),
                            Text(
                              'أهلًا ${widget.profile.name}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: StudentPalette.indigo,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'اختر رحلتك التعليمية',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: StudentPalette.ink,
                                fontSize: 31,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 7),
                            const Text(
                              'حدّد خطواتك التالية، وسنجهّز لك الدروس المناسبة.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF71827F),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      StudentAnimatedCard(
                        delay: const Duration(milliseconds: 120),
                        child: Student3DCard(
                          child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: [Color(0xFFFFFDF8), Color(0xFFEFF6FF)],
                            ),
                            borderRadius: StudentShapes.playfulCard,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x29183047),
                                blurRadius: 34,
                                offset: Offset(0, 18),
                              ),
                              BoxShadow(
                                color: Color(0x1A147D83),
                                blurRadius: 5,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _AcademicPathProgress(),
                              const SizedBox(height: 22),
                              const Text(
                                'المسار الأكاديمي',
                                style: TextStyle(
                                  color: Color(0xFF183047),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'اختر كل خطوة لتظهر لك الخيارات التالية.',
                                style: TextStyle(
                                  color: Color(0xFF71827F),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_loadError != null) ...[
                                const SizedBox(height: 14),
                                _InfoBanner(message: _loadError!),
                              ],
                              const SizedBox(height: 18),
                              if (_loading)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 38),
                                  child: Center(
                                    child: StudentRiveLoading(
                                      size: 118,
                                      label: 'جارٍ تحميل المسار الأكاديمي',
                                    ),
                                  ),
                                )
                              // Each stage of the world map has its own theme
                              // color, running indigo → sky → teal → violet →
                              // amber → rose down the path — purely
                              // presentational; the selection state and API
                              // calls below are untouched.
                              else ...[
                                _AcademicDropdown(
                                  step: 1,
                                  label: 'الصف الدراسي',
                                  icon: Icons.school_rounded,
                                  accent: const Color(0xFF4F46E5),
                                  value: _grade,
                                  options: data?.grades ?? const [],
                                  onChanged: _selectGrade,
                                ),
                                _AcademicDropdown(
                                  step: 2,
                                  label: 'الفصل الدراسي / الترم',
                                  icon: Icons.calendar_month_rounded,
                                  accent: const Color(0xFF0EA5E9),
                                  value: _atram,
                                  options: atrams,
                                  onChanged: atrams.isEmpty ? null : _selectAtram,
                                ),
                                _AcademicDropdown(
                                  step: 3,
                                  label: 'المادة الدراسية',
                                  icon: Icons.menu_book_rounded,
                                  accent: const Color(0xFF0D9488),
                                  value: _subject,
                                  options: subjects,
                                  onChanged: subjects.isEmpty ? null : _selectSubject,
                                ),
                                _AcademicDropdown(
                                  step: 4,
                                  label: 'الفصل أو الباب',
                                  icon: Icons.account_tree_rounded,
                                  accent: const Color(0xFF8B5CF6),
                                  value: _term,
                                  options: terms,
                                  onChanged: terms.isEmpty ? null : _selectTerm,
                                ),
                                _AcademicDropdown(
                                  step: 5,
                                  label: 'الوحدة التعليمية',
                                  icon: Icons.view_list_rounded,
                                  accent: const Color(0xFFF59E0B),
                                  value: _unit,
                                  options: units,
                                  onChanged: units.isEmpty ? null : _selectUnit,
                                ),
                                _LessonDropdown(
                                  step: 6,
                                  accent: const Color(0xFFE05A86),
                                  value: _lesson?.id,
                                  lessons: lessons,
                                  onChanged: lessons.isEmpty
                                      ? null
                                      : (lessonId) {
                                          setState(
                                            () => _lesson = lessons.firstWhere(
                                              (lesson) => lesson.id == lessonId,
                                            ),
                                          );
                                          _playSelectionFeedback();
                                        },
                                ),
                                if (_selection != null) ...[
                                  const SizedBox(height: 2),
                                  StudentSelectionBadge(
                                    label: 'مسارك المختار',
                                    subtitle: _selection!.label,
                                  ),
                                ],
                                const SizedBox(height: 18),
                                StudentPressScale(
                                  child: StudentEmbossedShell(
                                    color: const Color(0xFF147D83),
                                    borderRadius: 19,
                                    child: FilledButton.icon(
                                    onPressed: _selection == null || _isEntering
                                        ? null
                                        : _enterDashboard,
                                    icon: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 180),
                                      child: _isEntering
                                          ? const SizedBox(
                                              key: ValueKey('entering'),
                                              width: 19,
                                              height: 19,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.arrow_back_rounded,
                                              key: ValueKey('continue'),
                                            ),
                                    ),
                                    label: Text(
                                      _isEntering
                                          ? 'نجهّز رحلتك...'
                                          : 'الدخول إلى لوحة الطالب',
                                    ),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(58),
                                      backgroundColor: const Color(0xFF147D83),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      textStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(19),
                                      ),
                                    ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AcademicPathProgress extends StatelessWidget {
  const _AcademicPathProgress();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E8),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFEAD8A0)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 9, color: Color(0xFFE9AC3E)),
              SizedBox(width: 6),
              Text(
                'خطوة ١ من ٢',
                style: TextStyle(
                  color: Color(0xFF80652C),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        const Text(
          'رحلتك تبدأ الآن',
          style: TextStyle(
            color: Color(0xFF758683),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _AcademicDropdown extends StatelessWidget {
  const _AcademicDropdown({
    required this.step,
    required this.label,
    required this.icon,
    required this.accent,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final int step;
  final String label;
  final IconData icon;
  final Color accent;
  final String? value;
  final List<String> options;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value != null && value!.isNotEmpty;
    return _AcademicStepSurface(
      step: step,
      label: label,
      icon: icon,
      accent: accent,
      isLast: step == 6,
      selectedValue: selected ? value : null,
      selected: selected,
      child: StudentPressScale(
        child: DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          menuMaxHeight: 320,
          onChanged: onChanged,
          hint: Text(options.isEmpty ? 'لا توجد خيارات متاحة' : 'اختر $label'),
          icon: const Icon(Icons.expand_more_rounded),
          decoration: _academicDropdownDecoration,
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(
                    option,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _LessonDropdown extends StatelessWidget {
  const _LessonDropdown({
    required this.step,
    required this.accent,
    required this.value,
    required this.lessons,
    required this.onChanged,
  });

  final int step;
  final Color accent;
  final String? value;
  final List<LessonContent> lessons;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedLesson = lessons.where((lesson) => lesson.id == value).firstOrNull;
    return _AcademicStepSurface(
      step: step,
      label: 'الدرس الحالي',
      icon: Icons.play_lesson_rounded,
      accent: accent,
      isLast: true,
      selectedValue: selectedLesson?.lessonName,
      selected: selectedLesson != null,
      child: StudentPressScale(
        child: DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          menuMaxHeight: 320,
          onChanged: onChanged,
          hint: Text(lessons.isEmpty ? 'لا توجد دروس في هذه الوحدة' : 'اختر الدرس'),
          icon: const Icon(Icons.expand_more_rounded),
          decoration: _academicDropdownDecoration,
          items: lessons
              .map(
                (lesson) => DropdownMenuItem<String>(
                  value: lesson.id,
                  child: Text(
                    lesson.lessonName.isEmpty ? 'درس بدون عنوان' : lesson.lessonName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

const _academicDropdownDecoration = InputDecoration(
  isDense: true,
  filled: true,
  fillColor: Color(0xFFFBFAF5),
  contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 13),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
    borderSide: BorderSide(color: Color(0xFFE1E7E1)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
    borderSide: BorderSide(color: Color(0xFFE1E7E1)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
    borderSide: BorderSide(color: Color(0xFF147D83), width: 1.8),
  ),
);

class _AcademicStepSurface extends StatelessWidget {
  const _AcademicStepSurface({
    required this.step,
    required this.label,
    required this.icon,
    required this.accent,
    required this.selectedValue,
    required this.selected,
    required this.child,
    this.isLast = false,
  });

  final int step;
  final String label;
  final IconData icon;
  final Color accent;
  final String? selectedValue;
  final bool selected;
  final bool isLast;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 12 : 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StudentFocusGlow(
            isSelected: selected,
            borderRadius: StudentShapes.playfulCardTight,
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    accent.withOpacity(selected ? 0.16 : 0.08),
                    Colors.white,
                  ],
                ),
                borderRadius: StudentShapes.playfulCardTight,
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.16),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? accent : accent.withOpacity(0.16),
                          shape: BoxShape.circle,
                        ),
                        child: selected
                            ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                            : Text(
                                '$step',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(icon, color: accent, size: 21),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                color: Color(0xFF284658),
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (selectedValue != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                selectedValue!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  child,
                ],
              ),
            ),
          ),
          if (!isLast) _StagePathConnector(color: accent),
        ],
      ),
    );
  }
}

/// A short dotted trail between two world-map stage cards, roughly under
/// where each stage's numbered badge sits.
class _StagePathConnector extends StatelessWidget {
  const _StagePathConnector({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 27, top: 3, bottom: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: color.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
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