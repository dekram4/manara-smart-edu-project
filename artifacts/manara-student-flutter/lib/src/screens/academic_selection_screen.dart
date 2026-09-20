import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/academic_context.dart';
import '../models/student_content.dart';
import '../models/student_gamification.dart';
import '../models/student_profile.dart';
import '../l10n/student_strings.dart';
import '../services/student_auth_service.dart';
import '../services/student_avatar_store.dart';
import '../services/student_sound_service.dart';
import '../services/student_content_service.dart';
import '../theme/student_theme.dart';
import '../widgets/masar_path_board.dart';
import '../widgets/student_experience.dart';
import '../widgets/student_no_back.dart';
import '../widgets/student_mascot.dart';
import 'student_home_screen.dart';

class AcademicSelectionScreen extends StatefulWidget {
  const AcademicSelectionScreen({
    required this.profile,
    required this.authService,
    required this.apiBaseUrl,
    this.initialData,
    super.key,
  });

  final StudentProfile profile;
  final StudentAuthService authService;
  final String apiBaseUrl;

  /// Stands in for the network fetch so the laid-out scene can be tested.
  ///
  /// Without this the screen can only ever be pumped in its loading or
  /// error state — the books and the start button never render, so any
  /// test that measures them passes by finding nothing. Every visual
  /// report about this screen has been about those widgets, so they are
  /// exactly the ones that need to be reachable.
  @visibleForTesting
  final AcademicSelectionData? initialData;

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
  /// Set once, when the student starts the adventure: the characters fly
  /// off and fade before the route is replaced.
  bool _leaving = false;
  String? _loadError;
  StudentGamification _gamification = const StudentGamification();

  bool get _ready => !_loading && _data != null && !_data!.isEmpty;

  @override
  void initState() {
    super.initState();
    _contentService = StudentContentService(
      widget.authService.client,
      baseUrl: widget.apiBaseUrl,
      authService: widget.authService,
    );
    final seeded = widget.initialData;
    if (seeded != null) {
      _data = seeded;
      _loading = false;
      _applyInitialSelection(seeded);
    } else {
      _loadSelectionData();
    }
    _loadGamification();
    unawaited(StudentAvatars.adoptFromProfile(widget.profile.appearance));
    // The screen greets the student once it is on screen, in the same voice
    // as the welcome before it and the hub after it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(StudentSoundService.instance.speakPath());
    });
  }

  @override
  void dispose() {
    // Leaving mid-sentence ends the sentence. Screen locks are handled by
    // the sound service itself.
    unawaited(StudentSoundService.instance.stopPathVoice());
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
              tr('path.noPaths');
          _clearSelection();
          return;
        }
        _applyInitialSelection(data);
        if (data.hierarchyUnavailable) {
          _loadError =
              tr('path.treeFallback');
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _data = null;
        _clearSelection();
        _loadError = trf('path.loadError', {'error': error});
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
          term: _term!,
        ),
        null,
      );
      _lesson = _lessonsForSelection().firstOrNull;
    });
    _playSelectionFeedback();
  }

  void _selectUnit(String? unit) {
    if (_data == null || unit == null) return;
    setState(() {
      _unit = unit;
      _lesson = _lessonsForSelection().firstOrNull;
    });
    _playSelectionFeedback();
  }

  /// The lesson dropdown deals in names, so the pick is resolved back to the
  /// real [LessonContent] the rest of the app navigates with.
  void _selectLessonNamed(String? lessonName) {
    if (lessonName == null) return;
    final matches = _lessonsForSelection().where(
      (lesson) => _normalized(lesson.lessonName) == _normalized(lessonName),
    );
    if (matches.isEmpty) return;
    setState(() => _lesson = matches.first);
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

  /// The options behind each of the three books, read from exactly the same
  /// [AcademicSelectionData] getters the original dropdown UI used — the
  /// real hierarchy the teacher configured, each level filtered by what is
  /// picked above it.
  List<String> get _gradeOptions => _data?.grades ?? const [];

  List<String> get _atramOptions {
    final data = _data;
    if (data == null || _grade == null) return const [];
    return data.atramsFor(_grade!);
  }

  List<String> get _subjectOptions {
    final data = _data;
    if (data == null || _grade == null || _atram == null) return const [];
    return data.subjectsFor(grade: _grade!, atram: _atram!);
  }

  List<String> get _termOptions {
    final data = _data;
    if (data == null || _grade == null || _atram == null || _subject == null) {
      return const [];
    }
    return data.termsFor(grade: _grade!, atram: _atram!, subject: _subject!);
  }

  List<String> get _unitOptions {
    final data = _data;
    if (data == null ||
        _grade == null ||
        _atram == null ||
        _subject == null ||
        _term == null) {
      return const [];
    }
    return data.unitsFor(
      grade: _grade!,
      atram: _atram!,
      subject: _subject!,
      term: _term!,
    );
  }

  List<String> get _lessonOptions =>
      _lessonsForSelection().map((lesson) => lesson.lessonName).toList();

  Future<void> _enterDashboard() async {
    final selection = _selection;
    if (selection == null || _isEntering) return;
    StudentSoundService.instance.playTap();
    // Silenced here, at the tap, rather than in dispose: by the time this
    // route is torn down the hub has begun its own welcome on the same player.
    unawaited(StudentSoundService.instance.stopPathVoice());
    // The characters fly off before the route changes, so starting the
    // adventure reads as them leading the way rather than as a cut.
    setState(() {
      _isEntering = true;
      _leaving = true;
    });
    try {
      await Future<void>.delayed(const Duration(milliseconds: 620));
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
    return StudentNoBack(
      child: Scaffold(
      backgroundColor: StudentSurface.coolGround(context),
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final areaSize = constraints.biggest;
                // The whole area above the start band goes to the board.
                //
                // It used to be shared with a guide character who took a
                // column in landscape and a band across the top in portrait —
                // between a quarter and a third of the screen. She is gone
                // from this screen for two reasons. The artwork already has
                // two schoolchildren painted into it, so she was a third
                // character in the same scene; and the six fields now live
                // inside the squares in that artwork, so every pixel she held
                // came straight out of their size. Dropping her is what makes
                // the text in the squares readable rather than merely present.

                const edge = 12.0;
                // The start button keeps its own band across the foot.
                const startBand = 76.0;

                // اللوح يملأ الشاشة كلها. الرقع والزر تطفو فوقه، ولا
                // تقتطع منه: الصورة هي الشاشة، وكل ما عليها موضوع بنسبة
                // من رقعتها هي — فاقتطاع شريط لها كان يزيح كل رقعة عمّا
                // وُضعت لتغطّيه.
                final imageRect = Rect.fromLTWH(
                  0,
                  0,
                  areaSize.width,
                  areaSize.height,
                );

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The board: the artwork stretched to fill the screen,
                    // with the six levels printed into the squares already
                    // drawn on it and patches over the English signs.
                    if (_ready)
                      Positioned.fromRect(
                        rect: imageRect,
                        child: MasarPathBoard(
                          stages: _journeyStations,
                          activeIndex: _journeyStage,
                        ),
                      ),
                    if (!_ready)
                      Positioned.fromRect(
                        rect: imageRect,
                        child: Center(child: _buildLoadingOrError()),
                      ),
                    // The start button.
                    //
                    // Portrait: a band across the foot of the screen, under
                    // every book, as wide as the screen — a child should
                    // not have to aim for it.
                    //
                    // Landscape: inside the guide's own column, beneath
                    // her, so it can never reach across and cover a book
                    // or the character the way a full-width band did on a
                    // short window.
                    if (_ready)
                      Positioned(
                        left: edge,
                        right: edge,
                        bottom: edge,
                        height: startBand - edge,
                        child: _FlyAway(
                          away: _leaving,
                          angle: 0.18,
                          delay: const Duration(milliseconds: 60),
                          child: _StartAdventureButton(
                            enabled: _selection != null && !_isEntering,
                            busy: _isEntering,
                            onPressed: _enterDashboard,
                          ),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 8,
                      child: Row(
                        children: [
                          if (_ready)
                            _HudChip(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.diamond_rounded,
                                      color: Color(0xFF0EA5A5), size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_gamification.gems}',
                                    style: TextStyle(
                                      color: StudentSurface.ink(context),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(width: 8),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0x14000000),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const StudentSoundToggle(),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildLoadingOrError() {
    if (_loading) {
      return StudentEntrance(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PathMascot(size: 120),
            const SizedBox(height: 10),
            Text(
              trf('path.greeting', {'name': widget.profile.name}),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: StudentSurface.ink(context),
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            StudentRiveLoading(size: 84, label: tr('path.loading')),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: _InfoBanner(
        message: _loadError ?? tr('path.empty'),
      ),
    );
  }

  /// One control per book, in hierarchy order, each pinned onto that book's
  /// page area via its measured slot.
  ///
  /// Six levels, six books, one each — grade, term, subject, chapter, unit,
  /// lesson.
  ///
  /// The chapter used to share the red book with the unit, and only when
  /// the teacher had configured more than one of them; with a single
  /// chapter it was not shown at all. So a level the teacher had filled in
  /// was invisible here, and even when it appeared it was half a book wide.
  /// Freeing the navy book — the start button moved out from under the
  /// stack to its own band below — gave every level a book of its own and
  /// let the control read the same way at every level.
  /// The six levels, in the order the cascade resolves them.
  ///
  /// Built fresh on each frame from the same fields the cascade writes, so
  /// the map can hold no stale copy of the tree. Every `onSelected` is the
  /// existing selector, untouched: the map changes how a level is picked,
  /// never what picking one does.
  List<MasarStage> get _journeyStations => [
        MasarStage(
          label: tr('path.grade'),
          icon: Icons.school_rounded,
          color: const Color(0xFF2FA8BE),
          value: _grade,
          options: _gradeOptions,
          onSelected: (value) {
            _selectGrade(value);
            _advanceJourney(0);
          },
        ),
        MasarStage(
          label: tr('path.atram'),
          icon: Icons.calendar_month_rounded,
          color: const Color(0xFFE8930C),
          value: _atram,
          options: _atramOptions,
          onSelected: (value) {
            _selectAtram(value);
            _advanceJourney(1);
          },
        ),
        MasarStage(
          label: tr('path.subject'),
          icon: Icons.menu_book_rounded,
          color: const Color(0xFFA974BE),
          value: _subject,
          options: _subjectOptions,
          onSelected: (value) {
            _selectSubject(value);
            _advanceJourney(2);
          },
        ),
        MasarStage(
          label: tr('path.term'),
          icon: Icons.bookmarks_rounded,
          color: const Color(0xFFC0392B),
          value: _term,
          options: _termOptions,
          onSelected: (value) {
            _selectTerm(value);
            _advanceJourney(3);
          },
        ),
        MasarStage(
          label: tr('path.unit'),
          icon: Icons.category_rounded,
          color: const Color(0xFF2E7D4F),
          value: _unit,
          options: _unitOptions,
          onSelected: (value) {
            _selectUnit(value);
            _advanceJourney(4);
          },
        ),
        MasarStage(
          label: tr('path.lesson'),
          icon: Icons.play_lesson_rounded,
          color: const Color(0xFF12406B),
          value: _lesson?.lessonName,
          options: _lessonOptions,
          onSelected: (value) {
            _selectLessonNamed(value);
            _advanceJourney(5);
          },
        ),
      ];

  /// How far along the trail the student has walked.
  ///
  /// Deliberately *not* derived from which levels hold a value. The cascade
  /// fills every level below the one just chosen with a sensible default the
  /// moment it resolves, so "the first level with no answer" is the last
  /// station almost immediately — the avatar would teleport to the end on the
  /// first tap and the trail would mean nothing.
  ///
  /// So the stage is the student's own progress: one station per choice they
  /// actually made. Re-answering an earlier level walks them back to it,
  /// because everything under it has just been reset and is theirs to confirm
  /// again.
  int _journeyStage = 0;

  void _advanceJourney(int from) {
    final next = math.min(from + 1, _journeyStations.length - 1);
    if (next == _journeyStage) return;
    setState(() => _journeyStage = next);
  }

}

/// The chunky 3D "start the adventure" button on the lower books.
class _StartAdventureButton extends StatelessWidget {
  const _StartAdventureButton({
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? const Color(0xFFFF9F1C) : const Color(0xFFB6BEC6);
    return StudentPressScale(
      child: StudentEmbossedShell(
        color: color,
        depth: 6,
        borderRadius: 24,
        // Expands so the button's face covers the whole shell — without
        // this the button sizes to its label and leaves the darker 3D
        // ledge showing beside it.
        child: SizedBox.expand(
          child: FilledButton.icon(
            onPressed: enabled ? onPressed : null,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : const Icon(Icons.rocket_launch_rounded),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(tr(busy ? 'path.preparing' : 'path.start')),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFB6BEC6),
              disabledForegroundColor: Colors.white70,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
      ),
    );
  }
}

/// A piece of side art kept aloft by a continuous bob, optionally with a
/// tilt sway a quarter cycle behind it — that offset is what stops the
/// motion looking mechanical. Used for the pencil crew and the reading
/// pair, with different periods so the two never drift in lockstep.
/// How a character on the path moves.
///
/// The screen used to give every character the same sine drift, which read
/// as one lifeless motion repeated. Each style below has its own shape and
/// its own beat, so the characters look like separate creatures reacting
/// rather than parts of one mechanism.
enum _Motion {
  /// A hop with squash-and-stretch: stretched tall leaving the ground,
  /// squashed wide on landing, with a hang at the top.
  bounce,

  /// Stays put and rocks side to side, like a wave.
  wiggle,

  /// Breathes — a slow scale pulse with the faintest lift.
  pulse,

  /// Hovers: a slow, even rise and fall with no squash and the barest
  /// tilt. The quietest of the four, for a character that should feel
  /// alive without drawing the eye away from what it is pointing at.
  float,
}

class _FloatingArt extends StatefulWidget {
  const _FloatingArt({
    required this.asset,
    required this.size,
  });

  final String asset;
  final double size;

  /// Fixed rather than parameters: no call site ever passed anything else.
  final _Motion motion = _Motion.bounce;
  final Duration period = const Duration(milliseconds: 3400);

  /// The tilt, the liveliness and the offset into the cycle used to be
  /// constructor parameters, and every one of them was left at its
  /// default at every call site — so they are the defaults themselves
  /// now. The values are unchanged; only the unused dials are gone.
  static const baseAngle = 0.0;
  static const amount = 1.0;
  static const phase = 0.0;

  @override
  State<_FloatingArt> createState() => _FloatingArtState();
}

class _FloatingArtState extends State<_FloatingArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      widget.asset,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );

    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return Transform.rotate(angle: _FloatingArt.baseAngle, child: image);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = (_controller.value + _FloatingArt.phase) % 1.0;
        final turn = t * 2 * math.pi;
        final k = _FloatingArt.amount;
        final s = widget.size;

        double dy = 0;
        double scaleX = 1;
        double scaleY = 1;
        double tilt = 0;

        switch (widget.motion) {
          case _Motion.bounce:
            // `sin` raised to a power spends longer near zero and peaks
            // sharply — a hop with a hang at the top, rather than the
            // even glide a plain sine gives.
            final hop = math.pow(math.sin(turn).abs(), 0.65).toDouble();
            dy = -hop * s * 0.16 * k;
            // Squash on the ground, stretch in the air.
            scaleY = 1 + (hop - 0.35) * 0.10 * k;
            scaleX = 1 - (hop - 0.35) * 0.10 * k;
            tilt = math.sin(turn * 2) * 0.03 * k;
          case _Motion.wiggle:
            tilt = math.sin(turn) * 0.13 * k;
            // A small counter-lift on the swing, so the rock has weight.
            dy = -math.sin(turn * 2).abs() * s * 0.03 * k;
          case _Motion.pulse:
            final breath = (math.sin(turn) + 1) / 2;
            scaleX = scaleY = 1 + breath * 0.07 * k;
            dy = -breath * s * 0.05 * k;
            tilt = math.sin(turn) * 0.02 * k;
          case _Motion.float:
            // A plain sine, so the rise and the fall take the same time
            // and neither end snaps — the character simply hovers.
            dy = math.sin(turn) * s * 0.045 * k;
            tilt = math.sin(turn) * 0.012 * k;
        }

        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(
            angle: _FloatingArt.baseAngle + tilt,
            // Anchored to the feet so a character deforms without
            // sinking through the floor it stands on.
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
              child: child,
            ),
          ),
        );
      },
      child: image,
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white),
      ),
      child: child,
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
          fontSize: 16,
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

/// Sends the guide flying off-screen on a diagonal and fades her out when
/// the student starts the adventure, so the exit reads as her heading off
/// rather than a layer being switched off.
class _FlyAway extends StatelessWidget {
  const _FlyAway({
    required this.away,
    required this.child,
    this.angle = 0,
    this.delay = Duration.zero,
  });

  /// Flipped once. While false the child is drawn untouched, so the idle
  /// motion underneath is unaffected.
  final bool away;

  final Widget child;

  /// Direction of travel, in radians from straight up — the guide and the
  /// pencil lean opposite ways.
  final double angle;

  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (!away) return child;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return const SizedBox.shrink();
    }
    const travel = Duration(milliseconds: 520);
    // Up and out along `angle`, shrinking and fading as it goes.
    final dx = math.sin(angle) * 420;
    final dy = -math.cos(angle) * 420;
    return child
        .animate(delay: delay)
        .move(
          begin: Offset.zero,
          end: Offset(dx, dy),
          duration: travel,
          curve: Curves.easeInBack,
        )
        .fadeOut(duration: travel, curve: Curves.easeIn)
        .scaleXY(begin: 1, end: 0.72, duration: travel)
        .rotate(begin: 0, end: angle * 0.5, duration: travel);
  }
}
