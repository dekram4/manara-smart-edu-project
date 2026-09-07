import 'package:flame/game.dart' show GameWidget, Vector2;
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
import 'game_world/academic_world_game.dart';
import 'student_home_screen.dart';

/// Theme color + Arabic label for each of the six stations in the academic
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
  late final AcademicWorldGame _game;
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

  /// Which of the six stations (grade..lesson) the world map is currently
  /// showing. Going back a step never clears the selections already made —
  /// same behavior the old dropdowns had when you changed an earlier value.
  int _stepIndex = 0;
  StudentGamification _gamification = const StudentGamification();

  bool get _ready => !_loading && _data != null && !_data!.isEmpty;

  @override
  void initState() {
    super.initState();
    _contentService = StudentContentService(
      widget.authService.client,
      baseUrl: widget.apiBaseUrl,
    );
    _game = AcademicWorldGame(onStationSelected: _handleStationTap);
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
      if (_ready) _refreshStations();
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

  /// The value already picked for the current step, if any — so the world
  /// can highlight it among this step's stations (e.g. after going back).
  String? get _currentStepSelectedId => switch (_stepIndex) {
    0 => _grade,
    1 => _atram,
    2 => _subject,
    3 => _term,
    4 => _unit,
    _ => _lesson?.id,
  };

  /// The stations to show for the current [_stepIndex], read from exactly
  /// the same [AcademicSelectionData] getters the dropdown UI used.
  List<WorldStation> _currentStationOptions() {
    final data = _data;
    if (data == null) return const [];
    switch (_stepIndex) {
      case 0:
        return data.grades
            .map((value) => WorldStation(id: value, label: value))
            .toList();
      case 1:
        final options = _grade == null ? const <String>[] : data.atramsFor(_grade!);
        return options.map((value) => WorldStation(id: value, label: value)).toList();
      case 2:
        final options = _grade == null || _atram == null
            ? const <String>[]
            : data.subjectsFor(grade: _grade!, atram: _atram!);
        return options.map((value) => WorldStation(id: value, label: value)).toList();
      case 3:
        final options = _grade == null || _atram == null || _subject == null
            ? const <String>[]
            : data.termsFor(grade: _grade!, atram: _atram!, subject: _subject!);
        return options.map((value) => WorldStation(id: value, label: value)).toList();
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
        return options.map((value) => WorldStation(id: value, label: value)).toList();
      default:
        return _lessonsForSelection()
            .map(
              (lesson) => WorldStation(
                id: lesson.id,
                label: lesson.lessonName.isEmpty ? 'درس بدون عنوان' : lesson.lessonName,
              ),
            )
            .toList();
    }
  }

  void _refreshStations() {
    _game.showStations(
      _currentStationOptions(),
      stepAccent: _stepAccents[_stepIndex],
      selectedId: _currentStepSelectedId,
    );
  }

  /// Applies a tapped station to the real selection state via the exact
  /// same `_select*` methods the dropdowns called, then advances to the
  /// next station (unless this was the last one, the lesson pick).
  void _handleStationTap(String stationId) {
    switch (_stepIndex) {
      case 0:
        _selectGrade(stationId);
      case 1:
        _selectAtram(stationId);
      case 2:
        _selectSubject(stationId);
      case 3:
        _selectTerm(stationId);
      case 4:
        _selectUnit(stationId);
      default:
        final match = _lessonsForSelection()
            .where((lesson) => lesson.id == stationId)
            .firstOrNull;
        if (match != null) {
          setState(() => _lesson = match);
          _playSelectionFeedback();
        }
    }
    if (_stepIndex < 5) {
      setState(() => _stepIndex++);
    }
    _refreshStations();
  }

  void _goBackStep() {
    if (_stepIndex == 0) return;
    StudentSoundService.instance.playTap();
    setState(() => _stepIndex--);
    _refreshStations();
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
    return Scaffold(
      backgroundColor: const Color(0xFF6C8CF5),
      body: Stack(
        children: [
          // The game world (or, while it isn't ready yet, a matching
          // gradient + Smart Edu particles) always fills the *entire*
          // screen — no narrow bordered box stealing most of the space.
          Positioned.fill(
            child: _ready ? GameWidget(game: _game) : const _AcademicLoadingBackdrop(),
          ),
          if (_ready)
            ValueListenableBuilder<Vector2?>(
              valueListenable: _game.avatarTarget,
              builder: (context, target, _) {
                if (target == null) return const SizedBox.shrink();
                // Anchored beside (not on top of) the station, so it never
                // covers the station's own label underneath it.
                return AnimatedPositioned(
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  left: target.x - 60,
                  top: target.y - 30,
                  child: const IgnorePointer(child: PathMascot(size: 54)),
                );
              },
            ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Row(
                    children: [
                      if (_ready && _stepIndex > 0)
                        _HudChip(onTap: _goBackStep, child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18))
                      else
                        const SizedBox(width: 40),
                      const SizedBox(width: 8),
                      if (_ready)
                        Expanded(
                          child: _HudChip(
                            expand: true,
                            child: Text(
                              _stepLabels[_stepIndex],
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
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
                                  const StudentMascot(size: 120),
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
                if (_ready) const Spacer(),
                if (_ready && _loadError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _InfoBanner(message: _loadError!),
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
                            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_ready)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: (_stepIndex + 1) / _stepLabels.length,
                        minHeight: 8,
                        color: const Color(0xFFF6C95D),
                        backgroundColor: Colors.white.withOpacity(0.28),
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

/// The backdrop shown while the academic path data is still loading (or
/// failed to load) — a gradient matching the game world's own sky plus
/// Smart Edu floating particles, so the transition into the game once it's
/// ready doesn't jump between two unrelated looks.
class _AcademicLoadingBackdrop extends StatelessWidget {
  const _AcademicLoadingBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: const [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF6C8CF5), Color(0xFFB794F6)],
            ),
          ),
        ),
        SmartEduFloatingBackground(),
      ],
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
