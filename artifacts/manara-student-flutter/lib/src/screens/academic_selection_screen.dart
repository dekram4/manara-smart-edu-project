import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/academic_context.dart';
import '../models/student_content.dart';
import '../models/student_gamification.dart';
import '../models/student_profile.dart';
import '../services/student_auth_service.dart';
import '../services/student_sound_service.dart';
import '../services/student_content_service.dart';
import '../widgets/manara_logo.dart';
import '../widgets/student_experience.dart';
import '../widgets/student_mascot.dart';
import 'student_home_screen.dart';

/// One selectable option in the current step of the academic path (a grade,
/// a term, a subject, a chapter, a unit, or a lesson) — rendered as a card
/// in the horizontal carousel.
typedef _StageOption = ({String id, String label});

/// Theme color + Arabic label for each of the six steps in the academic
/// path. Purely presentational — the underlying selection data always comes
/// from [AcademicSelectionData] via the exact same getters the old dropdown
/// UI used.
const _stepAccents = <Color>[
  Color(0xFF4F46E5), // grade
  Color(0xFF0EA5E9), // atram/term
  Color(0xFF0D9488), // subject
  Color(0xFF8B5CF6), // chapter
  Color(0xFFF59E0B), // unit
  Color(0xFFE05A86), // lesson
];
const _stepLabels = <String>[
  'اختر الصف الدراسي',
  'اختر الفصل الدراسي / الترم',
  'اختر المادة الدراسية',
  'اختر الفصل أو الباب',
  'اختر الوحدة التعليمية',
  'اختر الدرس',
];

/// A distinctive icon per card, cycled by its index within the current
/// step's option list so neighbouring cards always look different.
const _stageIcons = <IconData>[
  Icons.flag_rounded,
  Icons.star_rounded,
  Icons.auto_awesome_rounded,
  Icons.emoji_events_rounded,
  Icons.rocket_launch_rounded,
  Icons.local_fire_department_rounded,
  Icons.favorite_rounded,
  Icons.bolt_rounded,
];

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

  /// Which of the six steps (grade..lesson) the carousel is currently
  /// showing. Jumping between steps (back, forward, or via a breadcrumb
  /// chip) never clears the selections already made — same behavior the
  /// old dropdowns had when you changed an earlier value.
  int _stepIndex = 0;
  StudentGamification _gamification = const StudentGamification();
  int _mascotBounceTicket = 0;

  /// The current step's real options, and the carousel driving them. Built
  /// fresh (new controller, new list) every time the step changes via
  /// [_refreshStageOptions] — recreated rather than mutated so its
  /// `initialPage` always lands exactly on whatever was already picked for
  /// that step.
  List<_StageOption> _stageOptions = const [];
  PageController? _pageController;

  bool get _ready => !_loading && _data != null && !_data!.isEmpty;

  @override
  void initState() {
    super.initState();
    _contentService = StudentContentService(
      widget.authService.client,
      baseUrl: widget.apiBaseUrl,
    );
    _loadSelectionData();
    _loadGamification();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _loadGamification() async {
    try {
      final snapshot = await _contentService.fetchGamification(widget.profile);
      if (mounted) setState(() => _gamification = snapshot);
    } catch (_) {
      // The gems HUD chip just keeps showing 0 if this is unavailable —
      // never blocks picking an academic path.
    }
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
      if (_ready) _refreshStageOptions();
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

  /// The value already picked for the current step, if any — so the
  /// carousel can open on it and highlight its card (e.g. after going
  /// back).
  String? get _currentStepSelectedId => switch (_stepIndex) {
    0 => _grade,
    1 => _atram,
    2 => _subject,
    3 => _term,
    4 => _unit,
    _ => _lesson?.id,
  };

  /// Drives the breadcrumb trail — but only for steps the student has
  /// actually reached (`index <= _stepIndex`); later steps show as pending
  /// ("…") even though [_applyInitialSelection] already picked smart
  /// defaults for them internally (so "ادخل رحلتك!" can work immediately).
  /// The breadcrumb must read as the student's real progress, not a form
  /// pre-filled ahead of anything they chose.
  List<String?> get _breadcrumbValues {
    final actual = [_grade, _atram, _subject, _term, _unit, _lesson?.lessonName];
    return [for (var i = 0; i < actual.length; i++) i <= _stepIndex ? actual[i] : null];
  }

  /// The options to show for the current [_stepIndex], read from exactly
  /// the same [AcademicSelectionData] getters the dropdown UI used — the
  /// real academic hierarchy (grade -> atram -> subject -> term -> unit ->
  /// lesson), never a flat/blind list.
  List<_StageOption> _currentStageOptions() {
    final data = _data;
    if (data == null) return const [];
    switch (_stepIndex) {
      case 0:
        return data.grades.map((value) => (id: value, label: value)).toList();
      case 1:
        final options = _grade == null ? const <String>[] : data.atramsFor(_grade!);
        return options.map((value) => (id: value, label: value)).toList();
      case 2:
        final options = _grade == null || _atram == null
            ? const <String>[]
            : data.subjectsFor(grade: _grade!, atram: _atram!);
        return options.map((value) => (id: value, label: value)).toList();
      case 3:
        final options = _grade == null || _atram == null || _subject == null
            ? const <String>[]
            : data.termsFor(grade: _grade!, atram: _atram!, subject: _subject!);
        return options.map((value) => (id: value, label: value)).toList();
      case 4:
        final options =
            _grade == null || _atram == null || _subject == null || _term == null
                ? const <String>[]
                : data.unitsFor(
                    grade: _grade!,
                    atram: _atram!,
                    subject: _subject!,
                    term: _term!,
                  );
        return options.map((value) => (id: value, label: value)).toList();
      default:
        return _lessonsForSelection()
            .map(
              (lesson) => (
                id: lesson.id,
                label: lesson.lessonName.isEmpty ? 'درس بدون عنوان' : lesson.lessonName,
              ),
            )
            .toList();
    }
  }

  /// Rebuilds the carousel for the current step: a fresh option list and a
  /// fresh [PageController] opened exactly on whatever was already picked
  /// for this step (or its first option, if nothing was picked yet).
  void _refreshStageOptions() {
    final options = _currentStageOptions();
    final selectedId = _currentStepSelectedId;
    var initialPage = options.indexWhere((option) => option.id == selectedId);
    if (initialPage < 0) initialPage = 0;
    final oldController = _pageController;
    setState(() {
      _stageOptions = options;
      _pageController = PageController(viewportFraction: 0.62, initialPage: initialPage);
    });
    oldController?.dispose();
  }

  /// Applies a chosen option to the real selection state via the exact
  /// same `_select*` methods the dropdowns called — passing on exactly the
  /// id the student picked, unchanged, so it reaches [StudentAuthService]
  /// / [AcademicContext] downstream precisely as before — then advances to
  /// the next step (unless this was the last one, the lesson pick), with a
  /// zoom transition and a small mascot bounce celebrating the pick.
  void _commitStageOption(String optionId) {
    switch (_stepIndex) {
      case 0:
        _selectGrade(optionId);
      case 1:
        _selectAtram(optionId);
      case 2:
        _selectSubject(optionId);
      case 3:
        _selectTerm(optionId);
      case 4:
        _selectUnit(optionId);
      default:
        final match = _lessonsForSelection().where((lesson) => lesson.id == optionId).firstOrNull;
        if (match != null) {
          setState(() => _lesson = match);
          _playSelectionFeedback();
        }
    }
    setState(() => _mascotBounceTicket++);
    if (_stepIndex < 5) {
      setState(() => _stepIndex++);
    }
    _refreshStageOptions();
  }

  /// Jumps the whole screen straight to [index] — used by the back chip and
  /// by tapping a breadcrumb chip. Safe at any time: every step already
  /// holds a valid (if default) selection right after the data loads, via
  /// [_applyInitialSelection].
  void _goToStep(int index) {
    if (index == _stepIndex || index < 0 || index > 5) return;
    StudentSoundService.instance.playTap();
    setState(() => _stepIndex = index);
    _refreshStageOptions();
  }

  /// The option index the carousel is currently settled/focused on — used
  /// only to decide the arrow buttons' start point; picking an option now
  /// always goes through each card's own "انطلق" button instead of an
  /// implicit "tap when centered" rule, so a child can never select a card
  /// by mistake while just browsing past it.
  int _focusedOptionIndex() {
    final controller = _pageController;
    if (controller == null) return 0;
    if (controller.hasClients && controller.position.haveDimensions) {
      return (controller.page ?? controller.initialPage.toDouble()).round();
    }
    return controller.initialPage;
  }

  void _centerCard(int index) {
    StudentSoundService.instance.playTap();
    _pageController?.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
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
    final accent = _stepAccents[_stepIndex];
    return Scaffold(
      backgroundColor: const Color(0xFF6C8CF5),
      body: Stack(
        children: [
          Positioned.fill(child: _AcademicBackdrop(accent: _ready ? accent : const Color(0xFF6C8CF5))),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Row(
                    children: [
                      if (_ready && _stepIndex > 0)
                        _HudChip(onTap: () => _goToStep(_stepIndex - 1), child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18))
                      else
                        const SizedBox(width: 40),
                      const SizedBox(width: 8),
                      if (_ready)
                        Expanded(
                          child: Text(
                            _stepLabels[_stepIndex],
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              shadows: [Shadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1))],
                            ),
                          ),
                        )
                      else
                        const Expanded(
                          child: Row(
                            children: [
                              ManaraLogo(size: 34),
                              SizedBox(width: 8),
                              Text(
                                'مَنارة',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (_ready)
                        _HudChip(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.diamond_rounded, color: Color(0xFF5EEAD4), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${_gamification.gems}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0x33FFFFFF),
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        child: StudentSoundToggle(),
                      ),
                    ],
                  ),
                ),
                if (_ready)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: _BreadcrumbTrail(
                      values: _breadcrumbValues,
                      current: _stepIndex,
                      onSelect: _goToStep,
                    ),
                  ),
                if (!_ready)
                  Expanded(
                    child: Center(
                      child: _loading
                          ? StudentEntrance(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const StudentMascot(size: 110),
                                  const SizedBox(height: 10),
                                  Text(
                                    'أهلًا ${widget.profile.name}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const StudentRiveLoading(
                                    size: 84,
                                    label: 'جارٍ تحميل المسار الأكاديمي',
                                  ),
                                ],
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(24),
                              child: _InfoBanner(
                                message: _loadError ?? 'لا توجد مسارات أكاديمية متاحة حاليًا.',
                              ),
                            ),
                    ),
                  ),
                if (_ready && _loadError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _InfoBanner(message: _loadError!),
                  ),
                if (_ready)
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 380),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.86, end: 1).animate(animation),
                          child: child,
                        ),
                      ),
                      child: _stageOptions.isEmpty
                          ? const _EmptyStageMessage(key: ValueKey('empty'))
                          : KeyedSubtree(
                              key: ValueKey(_stepIndex),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 108,
                                    child: Center(
                                      child: _PathMascotGuide(
                                        size: 104,
                                        bounceTicket: _mascotBounceTicket,
                                        onTap: _stageOptions.isEmpty
                                            ? null
                                            : () => _commitStageOption(
                                                _stageOptions[_focusedOptionIndex()].id,
                                              ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        // Free drag/swipe only — no side arrows — plus each
                                        // card's own body tap to center it or the mascot/"Go"
                                        // button to pick it.
                                        Expanded(
                                          child: PageView.builder(
                                            controller: _pageController,
                                            itemCount: _stageOptions.length,
                                            onPageChanged: (_) => StudentSoundService.instance.playTap(),
                                            itemBuilder: (context, index) {
                                              final option = _stageOptions[index];
                                              return _CarouselCardSlot(
                                                controller: _pageController!,
                                                index: index,
                                                child: _StageCard(
                                                  label: option.label,
                                                  icon: _stageIcons[index % _stageIcons.length],
                                                  accent: accent,
                                                  selected: option.id == _currentStepSelectedId,
                                                  stageNumber: index + 1,
                                                  onBodyTap: () => _centerCard(index),
                                                  onGo: () => _commitStageOption(option.id),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        if (_stageOptions.length > 1)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                                            child: _PageDots(controller: _pageController!, count: _stageOptions.length),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                if (_ready && _selection != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: StudentPressScale(
                      child: StudentEmbossedShell(
                        color: const Color(0xFF16A085),
                        borderRadius: 24,
                        child: FilledButton.icon(
                          onPressed: _isEntering ? null : _enterDashboard,
                          icon: _isEntering
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.celebration_rounded),
                          label: Text(_isEntering ? 'نجهّز رحلتك...' : 'ادخل رحلتك!'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF16A085),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The screen's permanent backdrop — a gradient tinted by the current
/// step's accent color plus Smart Edu floating particles.
class _AcademicBackdrop extends StatelessWidget {
  const _AcademicBackdrop({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final top = Color.lerp(const Color(0xFF6C8CF5), accent, 0.4)!;
    final bottom = Color.lerp(const Color(0xFFB794F6), accent, 0.3)!;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [top, bottom],
            ),
          ),
        ),
        const SmartEduFloatingBackground(),
      ],
    );
  }
}

/// The interactive breadcrumb: one chip per step (الصف > الترم > المادة >
/// الوحدة/الباب > الدرس), each showing the value already picked for it
/// (every step already has one, even if only a default, as soon as the
/// screen is ready). The current step's chip is enlarged and gold; tapping
/// any chip jumps straight to that step. Horizontally scrollable so it
/// never clips on a narrow tablet even with long Arabic labels.
class _BreadcrumbTrail extends StatelessWidget {
  const _BreadcrumbTrail({required this.values, required this.current, required this.onSelect});

  final List<String?> values;
  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (context, _) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Icon(Icons.chevron_left_rounded, color: Colors.white54, size: 16),
        ),
        itemBuilder: (context, index) {
          final value = values[index];
          final label = (value == null || value.isEmpty) ? '…' : value;
          return _BreadcrumbChip(
            label: label,
            active: index == current,
            onTap: () => onSelect(index),
          );
        },
      ),
    );
  }
}

class _BreadcrumbChip extends StatelessWidget {
  const _BreadcrumbChip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        constraints: const BoxConstraints(maxWidth: 130),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFE08A) : Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(12),
          border: active ? Border.all(color: Colors.white, width: 1.4) : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active ? const Color(0xFF1F2937) : Colors.white,
            fontSize: 11.5,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// The traveling guide standing beside the carousel — full-size, never
/// cropped (see [PathMascot]'s own `BoxFit.contain`) — with a continuous
/// idle float plus a short celebratory bounce every time [bounceTicket]
/// changes (i.e. every time the student commits a pick).
class _PathMascotGuide extends StatelessWidget {
  const _PathMascotGuide({required this.size, required this.bounceTicket, this.onTap});

  final double size;
  final int bounceTicket;

  /// Tapping the character herself commits whichever card is currently
  /// centered in the carousel — she is the one who makes the pick, not
  /// just a decoration standing beside it. Null while there is nothing to
  /// pick (the step's option list is empty).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final mascot = PathMascot(size: size);
    final idle = reduceMotion
        ? mascot
        : mascot
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .moveY(begin: 0, end: -8, duration: 1500.ms, curve: Curves.easeInOut);

    final withBounce = reduceMotion
        ? idle
        : idle
            .animate(key: ValueKey(bounceTicket))
            .scaleXY(begin: 1, end: 1.16, duration: 140.ms, curve: Curves.easeOut)
            .then()
            .scaleXY(end: 1, duration: 240.ms, curve: Curves.elasticOut);

    return Semantics(
      button: true,
      label: 'اضغط على شخصيتك لتختار البطاقة الحالية',
      child: GestureDetector(onTap: onTap, child: withBounce),
    );
  }
}

/// Applies the "carousel" scale/fade/tilt treatment to [child] based on how
/// far its [index] is from the [controller]'s current page — the card at
/// the focused page reads full-size (scaled up slightly for emphasis) and
/// flat; neighbours shrink, fade slightly, and tilt inward in perspective
/// like a shelf of game portals.
class _CarouselCardSlot extends StatelessWidget {
  const _CarouselCardSlot({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, cardChild) {
        var page = controller.initialPage.toDouble();
        if (controller.hasClients && controller.position.haveDimensions) {
          page = controller.page ?? page;
        }
        final delta = (index - page).clamp(-1.0, 1.0);
        final t = delta.abs();
        // The focused card (t == 0) reads noticeably bigger than its
        // resting size, per the "portal" look; side cards shrink instead.
        final scale = 1.15 - t * 0.39;
        return Opacity(
          opacity: (1 - t * 0.55).clamp(0.4, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0014)
              ..rotateY(delta * 0.22),
            child: Transform.scale(scale: scale, child: cardChild),
          ),
        );
      },
      // PageView always hands each page tight constraints matching its own
      // full cross-axis extent (i.e. the entire carousel row's height, and
      // most of a wide desktop/tablet window's width) — without capping
      // the card itself here, it stretches to fill that whole slot instead
      // of reading as a compact portal card.
      // No GestureDetector wraps `child` here on purpose: `_StageCard`
      // itself puts one only around its body (icon + label), as a sibling
      // of — never an ancestor of — its own "انطلق" button's GestureDetector.
      // Nesting a tap detector around one that's already inside another
      // lets a single physical tap fire both callbacks; keeping them as
      // non-overlapping siblings makes that impossible regardless of hit
      // order.
      // A chunky, portrait-oriented game card (~275x360, the spec'd game
      // card proportions) — clamped down from that target size only when
      // the actual slot is smaller, so it never hard-overflows a short
      // window. `_StageCard` centers its own content regardless of the
      // exact size it ends up with.
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite
                ? math.min(275.0, constraints.maxWidth - 16)
                : 275.0;
            final height = constraints.maxHeight.isFinite
                ? math.min(360.0, constraints.maxHeight - 16)
                : 360.0;
            return SizedBox(
              width: width > 0 ? width : 275,
              height: height > 0 ? height : 360,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A floating 3D "game portal" card — a thick beveled crystal/stone frame
/// around a glowing gradient face, a numbered badge, a big icon, the
/// option's label, and its own embossed "انطلق" button so picking it never
/// depends on it happening to be the centered card.
class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.stageNumber,
    required this.onBodyTap,
    required this.onGo,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;
  final int stageNumber;

  /// Tapping the icon/label area (anywhere on the card except the "انطلق"
  /// button) just centers this card in the carousel — a sibling
  /// GestureDetector to the button's own, never its ancestor, so a single
  /// tap can never fire both.
  final VoidCallback onBodyTap;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    // The whole card is itself a StudentEmbossedShell — the same chunky
    // "ledge" 3D-button technique already used for "ادخل رحلتك!" below,
    // just applied to the full card instead of just a button — which is
    // exactly what a wide dark extrusion base under a raised board needs:
    // a darker copy of the card offset a few px down, peeking out beneath
    // the actual (slightly upward-shifted) face on top.
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: StudentEmbossedShell(
        color: accent,
        depth: 10,
        borderRadius: 26,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(accent, Colors.white, 0.4)!,
                accent,
                Color.lerp(accent, Colors.black, 0.12)!,
              ],
              stops: const [0, 0.5, 1],
            ),
            border: Border.all(
              color: selected ? const Color(0xFFFFE08A) : const Color(0xFFFFF3D0),
              width: 4,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // A soft specular highlight streak near the top fakes a
              // glossy, lit-from-above crystal/board surface.
              Positioned(
                top: 8,
                left: 20,
                right: 20,
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [Colors.white.withOpacity(0.55), Colors.white.withOpacity(0)],
                    ),
                  ),
                ),
              ),
              Positioned(top: 10, right: 10, child: _NumberBadge3D(number: stageNumber, color: accent)),
              if (selected) const Positioned(top: 10, left: 10, child: _CheckBadge3D()),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 24, 14, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onBodyTap,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // The big floating stage icon — its own shadow and
                          // white rim make it read as a separate 3D piece
                          // sitting just above the card's surface.
                          Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.white, accent],
                              ),
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 8)),
                              ],
                            ),
                            child: Icon(icon, color: Colors.white, size: 50),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    StudentPressScale(
                      child: StudentEmbossedShell(
                        color: selected ? const Color(0xFF16A085) : const Color(0xFFF6C95D),
                        depth: 4,
                        borderRadius: 16,
                        child: GestureDetector(
                          onTap: onGo,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  selected ? Icons.check_circle_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  selected ? 'مُختار' : 'انطلق',
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberBadge3D extends StatelessWidget {
  const _NumberBadge3D({required this.number, required this.color});

  final int number;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 25,
      height: 25,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, color]),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Text(
        '$number',
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _CheckBadge3D extends StatelessWidget {
  const _CheckBadge3D();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 25,
      height: 25,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: const Icon(Icons.check_rounded, size: 16, color: Color(0xFF16A085)),
    );
  }
}

/// A small "game level" page-dot strip under the carousel — no side
/// arrows, just free drag/swipe plus this readout of which of the step's
/// options is currently centered. The active dot is enlarged and gold.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.controller, required this.count});

  final PageController controller;
  final int count;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        var page = controller.initialPage.toDouble();
        if (controller.hasClients && controller.position.haveDimensions) {
          page = controller.page ?? page;
        }
        final active = page.round().clamp(0, count - 1);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == active ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == active ? const Color(0xFFFFE08A) : Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: i == active
                      ? const [BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1))]
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EmptyStageMessage extends StatelessWidget {
  const _EmptyStageMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: _InfoBanner(message: 'لا توجد خيارات متاحة لهذه الخطوة بعد.'),
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xB3071425),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: child,
    );
    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, child: chip);
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
