import 'package:flutter/material.dart';

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
  /// showing. Jumping between steps (back, forward, or via the step dots)
  /// never clears the selections already made — same behavior the old
  /// dropdowns had when you changed an earlier value.
  int _stepIndex = 0;
  StudentGamification _gamification = const StudentGamification();

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

  /// The options to show for the current [_stepIndex], read from exactly
  /// the same [AcademicSelectionData] getters the dropdown UI used.
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
  /// same `_select*` methods the dropdowns called, then advances to the
  /// next step (unless this was the last one, the lesson pick).
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
    if (_stepIndex < 5) {
      setState(() => _stepIndex++);
    }
    _refreshStageOptions();
  }

  /// Jumps the whole screen straight to [index] — used by the back chip and
  /// by tapping a step dot in the navigator. Safe at any time: every step
  /// already holds a valid (if default) selection right after the data
  /// loads, via [_applyInitialSelection].
  void _goToStep(int index) {
    if (index == _stepIndex || index < 0 || index > 5) return;
    StudentSoundService.instance.playTap();
    setState(() => _stepIndex = index);
    _refreshStageOptions();
  }

  /// The option index the carousel is currently settled/focused on —
  /// tapping *that* card commits it, while tapping any other card just
  /// centers it first.
  int _focusedOptionIndex() {
    final controller = _pageController;
    if (controller == null) return 0;
    if (controller.hasClients && controller.position.haveDimensions) {
      return (controller.page ?? controller.initialPage.toDouble()).round();
    }
    return controller.initialPage;
  }

  void _onStageCardTap(int index) {
    if (_focusedOptionIndex() == index) {
      _commitStageOption(_stageOptions[index].id);
      return;
    }
    StudentSoundService.instance.playTap();
    _pageController?.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _nudgePage(int delta) {
    final controller = _pageController;
    if (controller == null || _stageOptions.isEmpty) return;
    final target = (_focusedOptionIndex() + delta).clamp(0, _stageOptions.length - 1);
    StudentSoundService.instance.playTap();
    controller.animateToPage(
      target,
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
                          child: _HudChip(
                            expand: true,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _StepDots(current: _stepIndex, onSelect: _goToStep),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    _stepLabels[_stepIndex],
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
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
                    child: Column(
                      children: [
                        const SizedBox(height: 6),
                        // Standing above the carousel's (always horizontally
                        // centered) active card — normal layout flow, so it
                        // can never clip behind the HUD or overlap a card.
                        const PathMascot(size: 64),
                        Expanded(
                          child: _stageOptions.isEmpty
                              ? const _EmptyStageMessage()
                              : Row(
                                  children: [
                                    _CarouselArrow(
                                      icon: Icons.chevron_right_rounded,
                                      onTap: () => _nudgePage(-1),
                                    ),
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
                                            onTap: () => _onStageCardTap(index),
                                            child: _StageCard(
                                              label: option.label,
                                              icon: _stageIcons[index % _stageIcons.length],
                                              accent: accent,
                                              selected: option.id == _currentStepSelectedId,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    _CarouselArrow(
                                      icon: Icons.chevron_left_rounded,
                                      onTap: () => _nudgePage(1),
                                    ),
                                  ],
                                ),
                        ),
                      ],
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
/// step's accent color plus Smart Edu floating particles. Static (no
/// per-frame animation loop to manage), unlike the old Flame sky, but
/// still visually continuous across steps since the tint itself changes.
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

/// A compact row of step indicators (dot — connector — dot — ...) for all
/// six steps. The current step is enlarged and gold; earlier ones are
/// solid white (already picked, even if only a default); later ones are
/// dim. Tapping any dot jumps straight to that step.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < _stepLabels.length; i++) {
      if (i > 0) {
        final done = i <= current;
        children.add(Container(
          width: 8,
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          color: Colors.white.withOpacity(done ? 0.85 : 0.3),
        ));
      }
      final isCurrent = i == current;
      final isDone = i < current;
      children.add(
        GestureDetector(
          onTap: () => onSelect(i),
          child: Container(
            width: isCurrent ? 14 : 9,
            height: isCurrent ? 14 : 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrent
                  ? const Color(0xFFFFE08A)
                  : (isDone ? Colors.white : Colors.white.withOpacity(0.35)),
              border: isCurrent ? Border.all(color: Colors.white, width: 1.6) : null,
            ),
          ),
        ),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

/// Applies the "carousel" scale/fade/tilt treatment to [child] based on how
/// far its [index] is from the [controller]'s current page — the card at
/// the focused page reads full-size and flat; neighbours shrink, fade
/// slightly, and tilt inward like a shelf of game portals.
class _CarouselCardSlot extends StatelessWidget {
  const _CarouselCardSlot({
    required this.controller,
    required this.index,
    required this.child,
    required this.onTap,
  });

  final PageController controller;
  final int index;
  final Widget child;
  final VoidCallback onTap;

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
        final scale = 1 - t * 0.24;
        return Opacity(
          opacity: (1 - t * 0.55).clamp(0.4, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(delta * 0.18),
            child: Transform.scale(scale: scale, child: cardChild),
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: child,
        ),
      ),
    );
  }
}

/// A single floating 3D "stage card/portal" — a glowing gradient panel with
/// its option's icon and label, brighter and ringed with gold when it's
/// this step's current pick.
class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.95), accent],
        ),
        border: Border.all(
          color: selected ? const Color(0xFFFFE08A) : Colors.white.withOpacity(0.5),
          width: selected ? 3.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.55),
            blurRadius: selected ? 30 : 16,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (selected)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, size: 16, color: Color(0xFF16A085)),
              ),
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.28),
                      border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.4),
                    ),
                    child: Icon(icon, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 1))],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  const _CarouselArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: _HudChip(onTap: onTap, child: Icon(icon, color: Colors.white, size: 22)),
    );
  }
}

class _EmptyStageMessage extends StatelessWidget {
  const _EmptyStageMessage();

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
  const _HudChip({required this.child, this.onTap, this.expand = false});

  final Widget child;
  final VoidCallback? onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      alignment: expand ? Alignment.center : null,
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
