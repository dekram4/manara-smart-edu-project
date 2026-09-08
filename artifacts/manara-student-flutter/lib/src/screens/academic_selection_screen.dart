import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/academic_context.dart';
import '../models/student_content.dart';
import '../models/student_gamification.dart';
import '../models/student_profile.dart';
import '../services/student_auth_service.dart';
import '../services/student_sound_service.dart';
import '../services/student_content_service.dart';
import '../widgets/manara_logo.dart';
import '../widgets/space_game_theme.dart';
import '../widgets/student_experience.dart';
import '../widgets/student_mascot.dart';
import 'student_home_screen.dart';

/// One selectable option in the current step of the academic path (a grade,
/// a term, a subject, a chapter, a unit, or a lesson) — rendered as a
/// floating rock-island station along the zig-zag mission path.
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

  /// Which of the six steps (grade..lesson) the mission path is currently
  /// showing. Jumping between steps (back, forward, or via a breadcrumb
  /// chip) never clears the selections already made — same behavior the
  /// old dropdowns had when you changed an earlier value.
  int _stepIndex = 0;
  StudentGamification _gamification = const StudentGamification();

  /// The current step's real options, rendered as stations along the
  /// zig-zag path. Rebuilt fresh every time the step changes, via
  /// [_refreshStageOptions].
  List<_StageOption> _stageOptions = const [];

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

  /// Rebuilds the current step's station list from exactly the same
  /// [AcademicSelectionData] getters the dropdown UI used.
  void _refreshStageOptions() {
    setState(() => _stageOptions = _currentStageOptions());
  }

  /// Applies a chosen station to the real selection state via the exact
  /// same `_select*` methods the dropdowns called — passing on exactly the
  /// id the student picked, unchanged, so it reaches [StudentAuthService]
  /// / [AcademicContext] downstream precisely as before — then advances to
  /// the next step (unless this was the last one, the lesson pick).
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
  /// by tapping a breadcrumb chip. Safe at any time: every step already
  /// holds a valid (if default) selection right after the data loads, via
  /// [_applyInitialSelection].
  void _goToStep(int index) {
    if (index == _stepIndex || index < 0 || index > 5) return;
    StudentSoundService.instance.playTap();
    setState(() => _stepIndex = index);
    _refreshStageOptions();
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
      backgroundColor: const Color(0xFF1B0A33),
      body: Stack(
        children: [
          const Positioned.fill(child: SpaceGameBackdrop(rocks: false)),
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
                              child: _ZigzagStationPath(
                                options: _stageOptions,
                                accent: accent,
                                selectedId: _currentStepSelectedId,
                                onSelect: _commitStageOption,
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

/// The zig-zag mission path for the current step: its options laid out as
/// floating rock islands connected by a glowing dashed line, with the path
/// mascot (the girl cutout, [PathMascot]) standing on whichever station is
/// currently selected and gliding smoothly to a new one as the student
/// progresses. A single tap on any station selects it directly — there is
/// no separate "go" button and nothing needs to be centered first.
class _ZigzagStationPath extends StatelessWidget {
  const _ZigzagStationPath({
    required this.options,
    required this.accent,
    required this.selectedId,
    required this.onSelect,
  });

  final List<_StageOption> options;
  final Color accent;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  static const _stationSize = 88.0;
  static const _stationSpacing = 180.0;
  static const _horizontalMargin = 90.0;
  static const _amplitude = 55.0;

  List<Offset> _stationCenters(double height) {
    final centerY = height / 2;
    return [
      for (var i = 0; i < options.length; i++)
        Offset(
          _horizontalMargin + i * _stationSpacing,
          centerY + (i.isEven ? -_amplitude : _amplitude),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite ? constraints.maxHeight : 260.0;
        final centers = _stationCenters(height);
        final contentWidth = math.max(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0,
          options.isEmpty ? 0.0 : centers.last.dx + _horizontalMargin,
        );
        final selectedIndex = options.indexWhere((option) => option.id == selectedId);
        final mascotCenter = centers[selectedIndex >= 0 ? selectedIndex : 0];

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: ZigzagPathPainter(centers)),
                ),
                for (var i = 0; i < options.length; i++)
                  Positioned(
                    left: centers[i].dx - _stationSize / 2,
                    top: centers[i].dy - _stationSize * 0.9,
                    child: SpaceIslandStation(
                      size: _stationSize,
                      label: options[i].label,
                      icon: _stageIcons[i % _stageIcons.length],
                      selected: options[i].id == selectedId,
                      phaseMs: i * 220,
                      onTap: () => onSelect(options[i].id),
                    ),
                  ),
                // The heroine stands on the current station, gliding to a
                // new one whenever the selection changes.
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  left: mascotCenter.dx - 34,
                  top: mascotCenter.dy - _stationSize * 1.55,
                  child: const IgnorePointer(child: PathMascot(size: 76)),
                ),
              ],
            ),
          ),
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
