import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/academic_context.dart';
import '../models/student_content.dart';
import '../models/student_profile.dart';
import '../models/student_gamification.dart';
import '../services/student_auth_service.dart';
import '../services/student_content_service.dart';
import '../widgets/lesson_scope_sheet.dart';
import '../widgets/manara_logo.dart';
import '../widgets/student_display_toggles.dart';
import '../widgets/student_experience.dart';
import '../widgets/student_avatar_view.dart';
import '../services/student_sound_service.dart';
import '../l10n/student_strings.dart';
import '../theme/student_theme.dart';
import 'login_screen.dart';
import 'student_cinema_screen.dart';
import 'student_chat_screen.dart';
import 'student_content_screen.dart';
import 'student_endless_reader_screen.dart';
import 'student_personality_screen.dart';
import 'student_problem_solver_screen.dart';
import 'student_progress_screen.dart';
import 'student_quiz_screen.dart';
import 'student_tutor_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({
    required this.profile,
    required this.authService,
    required this.apiBaseUrl,
    this.academicContext,
    super.key,
  });

  final StudentProfile profile;
  final StudentAuthService authService;
  final String apiBaseUrl;
  final AcademicContext? academicContext;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class StudentDashboardScreen extends StudentHomeScreen {
  const StudentDashboardScreen({
    required super.profile,
    required super.authService,
    required super.apiBaseUrl,
    super.academicContext,
    super.key,
  });
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  late StudentGamification _gamification;
  late final StudentContentService _contentService;
  late final ConfettiController _rewardController;
  bool _openingTutor = false;

  /// The lesson every card opens against. It starts as whatever the path
  /// screen chose and can be changed from the bar without leaving the hub
  /// — the cards read it at the moment they are opened, so a change
  /// reaches all of them at once rather than each holding its own copy.
  AcademicContext? _academicContext;

  /// Cached so reopening the switcher is instant; the hierarchy does not
  /// change while a student is looking at it.
  AcademicSelectionData? _selectionData;
  bool _loadingSelection = false;

  @override
  void initState() {
    super.initState();
    _academicContext = widget.academicContext;
    _gamification = widget.profile.gamification;
    _contentService = StudentContentService(widget.authService.client, baseUrl: widget.apiBaseUrl);
    _rewardController = ConfettiController(duration: const Duration(seconds: 2));
    _loadGamification();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playWelcome());
  }

  Future<void> _loadGamification() async {
    final previous = _gamification;
    StudentGamification? updated;
    try {
      final result = await _contentService.checkStreak(widget.profile);
      updated = result.snapshot;
    } catch (_) {
      try {
        updated = await _contentService.fetchGamification(widget.profile);
      } catch (_) {}
    }
    if (updated == null || !mounted) return;
    setState(() => _gamification = updated!);
    _celebrateProgress(previous, updated);
  }

  /// Completes the gamification loop: whenever a lesson, video, quiz or game
  /// closed and came back with more XP/gems than before, celebrate right
  /// here on the home screen with confetti, a reward chime and a random
  /// Arabic encouragement — instead of only the module screen's own toast.
  void _celebrateProgress(
    StudentGamification previous,
    StudentGamification updated,
  ) {
    if (!mounted) return;
    final gainedXp = updated.xp - previous.xp;
    final gainedGems = updated.gems - previous.gems;
    if (gainedXp <= 0 && gainedGems <= 0) return;

    if (!(MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      _rewardController.play();
    }
    if (updated.level > previous.level) {
      StudentSoundService.instance.playLevelUp();
    } else {
      StudentSoundService.instance.playReward();
    }
    final phrase = StudentSoundService.instance.playEncouragementArabic();

    final parts = <String>[];
    if (gainedXp > 0) parts.add('+$gainedXp XP');
    if (gainedGems > 0) parts.add(trf('home.gems', {'count': gainedGems}));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$phrase ${parts.join(tr('home.and'))}')),
    );
  }

  Future<void> _playWelcome() async {
    StudentSoundService.instance.play(StudentSoundCue.welcome);
  }

  @override
  void dispose() {
    _rewardController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    StudentSoundService.instance.playTap();
    try {
      await widget.authService.client.auth.signOut();
    } catch (_) {}
    widget.authService.clearApiSession();
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      StudentPageRoute<void>(
        builder: (_) => LoginScreen(
          authService: widget.authService,
          initializationError: null,
          apiBaseUrl: widget.apiBaseUrl,
        ),
      ),
      (_) => false,
    );
  }

  void _openModule(int index) {
    StudentSoundService.instance.playTap();
    final modules = [
      StudentContentModule.lesson,
      StudentContentModule.games,
    ];

    if (index == 1) {
      Navigator.of(context)
          .push(
        StudentPageRoute<void>(
          immersive: true,
          builder: (_) => StudentCinemaScreen(
            profile: widget.profile,
            authService: widget.authService,
            apiBaseUrl: widget.apiBaseUrl,
            academicContext: _academicContext,
          ),
        ),
      )
          .then((_) => _loadGamification());
      return;
    }

    if (index == 3) {
      _openPersonality();
      return;
    }

    if (index == 4) {
      _openTutor();
      return;
    }

    if (index == 5) {
      Navigator.of(context)
          .push(
        StudentPageRoute<void>(
          immersive: true,
          builder: (_) => StudentQuizScreen(
            profile: widget.profile,
            contentService: StudentContentService(
              widget.authService.client,
              baseUrl: widget.apiBaseUrl,
            ),
            academicContext: _academicContext,
          ),
        ),
      )
          .then((_) => _loadGamification());
      return;
    }

    if (index == 6) {
      _openProblemSolver();
      return;
    }

    if (index == 7) {
      _openTutor(liveMeeting: true);
      return;
    }

    if (index == 8) {
      Navigator.of(context).push(
        StudentPageRoute<void>(
          immersive: true,
          builder: (_) => StudentChatScreen(
            profile: widget.profile,
            apiBaseUrl: widget.apiBaseUrl,
            authService: widget.authService,
          ),
        ),
      );
      return;
    }

    if (index == 9) {
      Navigator.of(context).push(
        StudentPageRoute<void>(
          immersive: true,
          builder: (_) => StudentEndlessReaderScreen(
            academicContext: _academicContext,
          ),
        ),
      );
      return;
    }

    Navigator.of(context)
        .push(
      StudentPageRoute<void>(
        immersive: true,
        builder: (_) => StudentContentScreen(
          profile: widget.profile,
          authService: widget.authService,
          apiBaseUrl: widget.apiBaseUrl,
          academicContext: _academicContext,
          // The first card is "شرح الدرس"; the cinema card is handled above.
          // Subtracting one here made the first card access modules[-1].
          initialModule: modules[index == 0 ? 0 : index - 1],
        ),
      ),
    )
        .then((_) => _loadGamification());
  }

  /// Opens the lesson switcher and, if the student confirms, swaps the
  /// lesson every card works against.
  ///
  /// The hierarchy is fetched once and kept: it does not change while a
  /// student is looking at it, and re-fetching on every open would put a
  /// spinner in front of a menu.
  Future<void> _changeLesson() async {
    StudentSoundService.instance.playTap();
    final messenger = ScaffoldMessenger.of(context);
    if (_selectionData == null) {
      if (_loadingSelection) return;
      setState(() => _loadingSelection = true);
      try {
        _selectionData =
            await _contentService.fetchAcademicSelectionData(widget.profile);
      } catch (_) {
        _selectionData = null;
      } finally {
        if (mounted) setState(() => _loadingSelection = false);
      }
    }
    if (!mounted) return;
    final data = _selectionData;
    if (data == null || data.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('home.pathLoadFailed'))),
      );
      return;
    }

    final chosen = await LessonScopeSheet.show(
      context,
      data: data,
      current: _academicContext,
    );
    if (chosen == null || !mounted) return;
    setState(() => _academicContext = chosen);
    StudentSoundService.instance.play(StudentSoundCue.success);
    messenger.showSnackBar(
      SnackBar(content: Text(trf('home.lessonChosen', {'lesson': chosen.lesson}))),
    );
  }

  void _openPersonality() {
    Navigator.of(context).push(
      StudentPageRoute<void>(
        immersive: true,
        builder: (_) => StudentPersonalityScreen(
          profile: widget.profile,
          contentService: StudentContentService(widget.authService.client),
          creatorUrl: const String.fromEnvironment('READY_PLAYER_ME_CREATOR_URL'),
        ),
      ),
    );
  }

  Future<void> _openTutor({bool liveMeeting = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    if (liveMeeting && !widget.profile.canAccessLiveMeeting) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('home.meetingOff'))),
      );
      return;
    }
    // Looking up the teacher takes a round trip, during which the card
    // still accepts taps. Without this guard an impatient second tap
    // stacked a second lookup and a second screen on top of the first.
    if (_openingTutor) return;
    _openingTutor = true;
    try {
      final selection = await StudentContentService(
        widget.authService.client,
        baseUrl: widget.apiBaseUrl,
      ).fetchTutorExperience(
        widget.profile,
        academicContext: _academicContext,
        type: liveMeeting
            ? TutorExperienceType.liveMeeting
            : TutorExperienceType.virtualTeacher,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        StudentPageRoute<void>(
          immersive: true,
          builder: (_) => StudentTutorScreen(
            selection: selection,
          apiBaseUrl: widget.apiBaseUrl,
          ),
        ),
      );
      if (mounted) _loadGamification();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            liveMeeting
                ? tr('home.meetingLoadFailed')
                : tr('home.tutorLoadFailed'),
          ),
        ),
      );
    } finally {
      // Released on every path, including the failing one — otherwise one
      // failed lookup would leave the card permanently unresponsive.
      _openingTutor = false;
    }
  }

  Future<void> _openProblemSolver() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final lessons = await StudentContentService(
        widget.authService.client,
        baseUrl: widget.apiBaseUrl,
      ).fetchLessons(widget.profile, academicContext: _academicContext);
      if (!mounted) return;
      await Navigator.of(context).push(
        StudentPageRoute<void>(
          immersive: true,
          builder: (_) => StudentProblemSolverScreen(
            lessons: lessons,
            apiBaseUrl: widget.apiBaseUrl,
            profile: widget.profile,
            contentService: StudentContentService(
              widget.authService.client,
              baseUrl: widget.apiBaseUrl,
            ),
            authService: widget.authService,
            academicContext: _academicContext,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(tr('home.solverLoadFailed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: StudentPalette.canvas,
      appBar: AppBar(
        // The enlarged mark is 54px and its pill adds 14px of padding, so
        // 70 left only 2px of slack — raised so the bigger logo cannot
        // press against the bar.
        toolbarHeight: 82,
        titleSpacing: 16,
        title: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(9, 7, 14, 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white),
            boxShadow: const [
              BoxShadow(
                color: Color(0x224F46E5),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          // The mark is bigger and the old tiny "SMART EDU" line is
          // replaced by the app's full Arabic name. FittedBox keeps that
          // longer name from ever widening the bar past its room.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ManaraLogo(size: 54),
              const SizedBox(width: 10),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    tr('app.name'),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Changing the lesson without going back to the path screen.
          // Every card reads the hub's lesson when it opens, so one
          // change here reaches the explanation, the cinema, the teacher
          // and the reading challenge together.
          // A labelled button rather than a bare glyph. This is the one
          // control that changes what every other card shows, so it says
          // what it does instead of leaving a student to guess at an
          // icon. It collapses to just the icon on a narrow bar.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: _loadingSelection
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    ),
                  )
                : Tooltip(
                    message: tr('hub.changeLessonTooltip'),
                    child: FilledButton.icon(
                      onPressed: _changeLesson,
                      icon: const Icon(Icons.alt_route_rounded, size: 20),
                      label: Text(
                        tr('hub.changeLesson'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0E5F6B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                    ),
                  ),
          ),
          // Theme and language, side by side, on the one bar a student
          // sees on every visit.
          const StudentDisplayToggles(color: Color(0xFF0E5F6B)),
          // The profile icon is the chosen character too, so the bar and
          // the card always agree.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: StudentAvatarView(size: 38, onTap: _openPersonality),
          ),
          const StudentSoundToggle(),
          IconButton(
            onPressed: _signOut,
            tooltip: tr('home.signOut'),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
        // Level, XP and gems live here and nowhere else — they used to be
        // printed three times over (avatar room, progress card, and the
        // card's own level pill).
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _TopStatsBar(
            stats: _gamification,
            // The "تقدمك ومكافآتك" panel was the only way into the
            // achievements screen, so the badges inherit that route
            // rather than the screen becoming unreachable with it.
            onPressed: () {
              StudentSoundService.instance.playTap();
              Navigator.of(context).push(
                StudentPageRoute<void>(
                  immersive: true,
                  builder: (_) => StudentProgressScreen(
                    profile: widget.profile,
                    stats: _gamification,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      body: Stack(
        children: [
          const _LighthouseBackdrop(),
          StudentCelebration(controller: _rewardController),
          SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: SingleChildScrollView(
                  // The dashboard is the one place a scroll is legitimate —
                  // it genuinely has more content than any phone screen
                  // holds. Clamping rather than bouncing so it does not
                  // read as a stray drag on a screen that nearly fits.
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    size.width >= 700 ? 18 : 0,
                    8,
                    size.width >= 700 ? 18 : 0,
                    32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: StudentAnimatedCard(
                      child: _WelcomeCard(
                        profile: widget.profile,
                        onCharacterTap: _openPersonality,
                      ),
                    ),
                  ),
                  if (_academicContext != null) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: _AcademicContextSummary(
                        academicContext: _academicContext!,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      tr('home.pickPortal'),
                      style: TextStyle(
                        color: StudentSurface.ink(context),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      tr('home.pickPortalHint'),
                      style: TextStyle(
                        color: StudentSurface.mutedInk(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _HomeSectionGrid(onSectionPressed: _openModule),
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

class _HomeSection {
  const _HomeSection({
    required this.titleKey,
    required this.subtitleKey,
    required this.descriptionKey,
    required this.image,
    required this.colors,
    required this.accent,
  });

  /// Translation keys rather than finished text, because the table below
  /// is `const` and a `const` list cannot hold a value that changes with
  /// the language. Resolving at build time is what lets the rail switch
  /// from Arabic to English without rebuilding the data itself.
  final String titleKey;
  final String subtitleKey;

  String get title => tr(titleKey);
  String get subtitle => tr(subtitleKey);

  /// Read out by the screen reader, so it follows the language like
  /// every other label on the card.
  final String descriptionKey;

  String get description => tr(descriptionKey);

  /// The portal's own 3D artwork. Each card is now a distinct illustration
  /// rather than a stock glyph on a coloured square, so adding a portal
  /// means adding an entry here with its asset — no per-card widget.
  final String image;
  final List<Color> colors;
  final Color accent;
}

class _AcademicContextSummary extends StatelessWidget {
  const _AcademicContextSummary({required this.academicContext});

  final AcademicContext academicContext;

  @override
  Widget build(BuildContext context) {
    return Student3DCard(
      maxTilt: 0.035,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x8099F6E4), width: 1.4),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_stories_rounded, color: Color(0xFF0B8693)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              academicContext.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF115E59),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}


const _homeSections = <_HomeSection>[
  _HomeSection(
    titleKey: 'portal.lesson',
    subtitleKey: 'portal.lesson.sub',
    descriptionKey: 'portal.lesson.desc',
    image: 'assets/images/icon_teacher.png',
    colors: [Color(0xFF9A5B09), Color(0xFFF59E0B)],
    accent: Color(0xFFFFE08A),
  ),
  _HomeSection(
    titleKey: 'portal.cinema',
    subtitleKey: 'portal.cinema.sub',
    descriptionKey: 'portal.cinema.desc',
    image: 'assets/images/icon_cinema.png',
    colors: [Color(0xFF0B5D66), Color(0xFF0B8693)],
    accent: Color(0xFF9EEBEA),
  ),
  _HomeSection(
    titleKey: 'portal.games',
    subtitleKey: 'portal.games.sub',
    descriptionKey: 'portal.games.desc',
    image: 'assets/images/icon_game.png',
    colors: [Color(0xFF4B267F), Color(0xFF8B5CF6)],
    accent: Color(0xFFE9D5FF),
  ),
  _HomeSection(
    titleKey: 'portal.personality',
    subtitleKey: 'portal.personality.sub',
    descriptionKey: 'portal.personality.desc',
    image: 'assets/images/icon_prof.png',
    colors: [Color(0xFF9B3E68), Color(0xFFE05A86)],
    accent: Color(0xFFFFD0DF),
  ),
  _HomeSection(
    titleKey: 'portal.tutor',
    subtitleKey: 'portal.tutor.sub',
    descriptionKey: 'portal.tutor.desc',
    image: 'assets/images/icon_avatar.png',
    colors: [Color(0xFF274E76), Color(0xFF1394D2)],
    accent: Color(0xFFBAE6FD),
  ),
  _HomeSection(
    titleKey: 'portal.quiz',
    subtitleKey: 'portal.quiz.sub',
    descriptionKey: 'portal.quiz.desc',
    image: 'assets/images/icon_quez.png',
    colors: [Color(0xFF165B4A), Color(0xFF16A085)],
    accent: Color(0xFFB7F7DD),
  ),
  _HomeSection(
    titleKey: 'portal.solver',
    subtitleKey: 'portal.solver.sub',
    descriptionKey: 'portal.solver.desc',
    image: 'assets/images/icon_ai.png',
    colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
    accent: Color(0xFFE9D5FF),
  ),
  _HomeSection(
    titleKey: 'portal.meeting',
    subtitleKey: 'portal.meeting.sub',
    descriptionKey: 'portal.meeting.desc',
    image: 'assets/images/icon_meet.png',
    colors: [Color(0xFFB45309), Color(0xFFF59E0B)],
    accent: Color(0xFFFFE4A3),
  ),
  _HomeSection(
    titleKey: 'portal.chat',
    subtitleKey: 'portal.chat.sub',
    descriptionKey: 'portal.chat.desc',
    image: 'assets/images/icon_chat.png',
    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
    accent: Color(0xFFBFDBFE),
  ),
  // Index 9. Added at the end so every portal before it keeps the index
  // it already had — _openModule dispatches on position, and inserting
  // anywhere else would silently send a student to the wrong card.
  _HomeSection(
    titleKey: 'portal.challenge',
    subtitleKey: 'portal.challenge.sub',
    descriptionKey: 'portal.challenge.desc',
    image: 'assets/images/endless_challenge.png',
    colors: [Color(0xFF3B2A6B), Color(0xFF6D28D9)],
    accent: Color(0xFFDDD6FE),
  ),
];

/// A shelf of wide 3D game-portal tiles — the module grid the student picks
/// a destination from. `SliverGridDelegateWithMaxCrossAxisExtent` sizes each
/// tile toward the target ~230x170 game-card proportions and fits as many
/// columns as the available (landscape-favoring) width allows, rather than
/// a fixed 2/3-column breakpoint.
/// The eight portals as a single horizontal rail instead of a vertical
/// grid.
///
/// The grid stacked into four rows and covered the whole lighthouse; one
/// row that scrolls sideways leaves the backdrop visible and reads as a
/// shelf of toys to swipe through. Indices are passed through untouched,
/// so every portal still opens exactly what it did before, and a future
/// bespoke design per portal only has to change [_SectionTile] — the rail
/// itself makes no assumption about what a card looks like beyond its
/// height.
class _HomeSectionGrid extends StatelessWidget {
  const _HomeSectionGrid({required this.onSectionPressed});

  final ValueChanged<int> onSectionPressed;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // The rail is sized from the screen's shorter edge so a phone in
    // landscape gets a shorter rail rather than one that eats the view.
    final shortest = math.min(size.width, size.height);
    final cardHeight = (shortest * 0.34).clamp(132.0, 178.0).toDouble();
    final cardWidth = (cardHeight * 1.32).clamp(150.0, 235.0).toDouble();

    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        itemCount: _homeSections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => SizedBox(
          width: cardWidth,
          child: _SectionTile(
            // Named by its portal rather than its position, so the key
            // survives the rail being reordered.
            key: ValueKey('portal-tile-${_homeSections[index].titleKey}'),
            section: _homeSections[index],
            // Staggers each card's float so the rail breathes rather than
            // pulsing as one block.
            index: index,
            onPressed: () => onSectionPressed(index),
          ),
        ),
      ),
    );
  }
}

/// One portal in the rail: its own 3D illustration above the portal's name.
///
/// This replaced a gradient square with a white circular medallion and a
/// stock Material glyph inside it. Nine identical coloured boxes told a
/// child nothing about what each one opened; the illustrations do. The
/// card behind them is deliberately quiet — a soft translucent panel with
/// a rim tinted in the portal's own colour — so the artwork is what reads
/// and the lighthouse still shows through the rail.
class _SectionTile extends StatefulWidget {
  const _SectionTile({
    required this.section,
    required this.index,
    required this.onPressed,
    super.key,
  });

  final _HomeSection section;
  final int index;
  final VoidCallback? onPressed;

  @override
  State<_SectionTile> createState() => _SectionTileState();
}

class _SectionTileState extends State<_SectionTile>
    with TickerProviderStateMixin {
  /// The idle float. Each card gets its own slightly different period, so
  /// nine cards drifting together never lock into one rhythm.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 2900 + (widget.index % 5) * 170),
  );

  /// The reaction to a finger or a pointer resting on the card: it rises,
  /// grows and lights its rim. Quick up, slower down — which is what makes
  /// it feel sprung rather than switched.
  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    reverseDuration: const Duration(milliseconds: 520),
  );

  late final Animation<double> _liftCurve = CurvedAnimation(
    parent: _lift,
    // Overshoots and settles rather than easing flat into place — that
    // bounce is the difference between a card that answers a finger and
    // one that merely changes size. easeOutBack was too polite to read
    // as a reaction at all.
    curve: Curves.elasticOut,
    reverseCurve: Curves.easeOutCubic,
  );

  /// The push itself, separate from the lift.
  ///
  /// The lift says "this card is under your finger"; this says "you just
  /// pushed it". They have to be separate, because on a desktop the card
  /// is already lifted by the hover before the click ever lands — driving
  /// both from one controller means a click on a hovered card animates
  /// nothing at all, which is exactly how the old version felt.
  ///
  /// Unbounded and driven by a real spring rather than a curve: a curve
  /// plays a fixed shape over a fixed time, so releasing mid-press
  /// restarts it from wherever it happens to be and reads as a stutter. A
  /// spring carries the current velocity into the release, so a quick tap
  /// and a slow press settle differently — which is what physical means.
  late final AnimationController _push =
      AnimationController.unbounded(vsync: this);

  /// Stiff enough to answer immediately, damped just under critical so it
  /// overshoots once on release and settles — one bounce, not a wobble.
  static const _pushSpring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 17,
  );

  bool _hovered = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _drift.repeat(reverse: true);
  }

  @override
  void dispose() {
    _drift.dispose();
    _lift.dispose();
    _push.dispose();
    super.dispose();
  }

  /// Hover and press are tracked apart and combined here: on a desktop the
  /// pointer is still over the card after the click, so clearing the state
  /// on tap-up alone would drop the card while the mouse still rests on it.
  void _sync() {
    final engaged = _hovered || _pressed;
    if (engaged) {
      _lift.forward();
    } else {
      _lift.reverse();
    }
  }

  void _springPushTo(double target) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _push.value = target;
      return;
    }
    _push.animateWith(
      SpringSimulation(_pushSpring, _push.value, target, _push.velocity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tint = widget.section.colors.first;
    const radius = 24.0;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final contents = Column(
      children: [
        // The illustration takes whatever height the rail gives the
        // card after the label, and `contain` keeps every one of the
        // nine at its own aspect — none is stretched to fit.
        Expanded(
          child: Image.asset(
            widget.section.image,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => Icon(
              Icons.image_not_supported_rounded,
              color: tint.withOpacity(0.5),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Scales down rather than wrapping or clipping, so a long
        // portal name cannot change the card's height.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            widget.section.title,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: StudentSurface.isDark(context)
                ? Color.lerp(tint, Colors.white, 0.55)
                : Color.lerp(tint, Colors.black, 0.35),
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );

    final interactive = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        _hovered = true;
        _sync();
      },
      onExit: (_) {
        _hovered = false;
        _sync();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          _pressed = true;
          _sync();
          _springPushTo(1);
        },
        onTapUp: (_) {
          _pressed = false;
          _sync();
          _springPushTo(0);
        },
        onTapCancel: () {
          _pressed = false;
          _sync();
          _springPushTo(0);
        },
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: Listenable.merge([_drift, _liftCurve, _push]),
          builder: (context, child) {
            // A plain sine over a controller that already reverses would
            // ease twice and stall at the ends; the raw value mapped
            // through a cosine gives one clean rise and fall.
            final drift = reduceMotion
                ? 0.0
                : (1 - math.cos(_drift.value * math.pi)) / 2 - 0.5;
            final lift = reduceMotion ? 0.0 : _liftCurve.value.clamp(0.0, 1.4);
            // The spring overshoots past 1 on the way down and past 0 on
            // the way back; both are wanted, so this is clamped only
            // loosely — just enough that a violent fling cannot invert
            // the card.
            final push = reduceMotion ? 0.0 : _push.value.clamp(-0.35, 1.25);

            // Real depth rather than a flat scale: the card tilts a
            // little away from the finger as it rises, with a
            // perspective entry in the matrix, so it reads as an object
            // lifting off the rail instead of a picture growing.
            //
            // The idle float also breathes a fraction of a percent of
            // scale with the rise. Vertical travel alone reads as sliding;
            // the two together read as floating toward the viewer.
            final matrix = Matrix4.identity()
              ..setEntry(3, 2, 0.0014)
              ..translate(0.0, drift * 11 - lift * 16 + push * 5)
              ..scale(1 + drift * 0.012 + lift * 0.07 - push * 0.055)
              ..rotateX(-lift * 0.16)
              ..rotateZ(drift * 0.012);

            // The rim is the neon: it stays a quiet tinted hairline at
            // rest and burns into the portal's own colour as the card
            // comes up, so each card glows as itself rather than every
            // card glowing the same white.
            final glow = lift.clamp(0.0, 1.0);

            return Transform(
              alignment: Alignment.center,
              transform: matrix,
              child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    color: StudentSurface.glass(context, 0.72 + lift * 0.18),
                    border: Border.all(
                      color: tint.withOpacity(0.45 + glow * 0.50),
                      width: 1.6 + lift * 1.3,
                    ),
                    boxShadow: [
                      // Three layers, each with one job. A tight contact
                      // shadow that stays put so the card keeps its
                      // footing; a coloured bloom that grows as it rises;
                      // and a wide, very soft halo that only appears on
                      // engagement — that outermost one is what reads as
                      // a glow rather than as a drop shadow.
                      BoxShadow(
                        color: const Color(0x33000000),
                        blurRadius: 6 + lift * 6,
                        offset: Offset(0, 3 + lift * 3),
                      ),
                      BoxShadow(
                        color: tint.withOpacity(0.20 + glow * 0.42),
                        blurRadius: 18 + lift * 34,
                        spreadRadius: lift * 5,
                        offset: Offset(0, 9 + lift * 12),
                      ),
                      if (glow > 0.01)
                        BoxShadow(
                          color: tint.withOpacity(glow * 0.34),
                          blurRadius: 30 + glow * 44,
                          spreadRadius: 2 + glow * 10,
                        ),
                    ],
                  ),
                  child: child,
                ),
            );
          },
          child: contents,
        ),
      ),
    );

    return Semantics(button: true, label: widget.section.title, child: interactive);
  }
}

/// The dashboard's one and only background: the Manara lighthouse over a
/// warm light wash.
///
/// This replaced a separate animated layer of coloured blobs that used to
/// sit underneath — two competing backgrounds read as clutter, and the
/// blobs were what showed at the screen edges. The lighthouse is drawn at
/// 55% so its own colours and detail actually read, which is only legible
/// because the cards on top of it are glass. `BoxFit.contain` keeps the
/// tower whole in either orientation (covering would crop the lantern off
/// a landscape screen), and [IgnorePointer] keeps it from eating taps.
class _LighthouseBackdrop extends StatelessWidget {
  const _LighthouseBackdrop();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFF6E7),
                  Color(0xFFFDF3EA),
                  Color(0xFFEFF5FB),
                ],
              ),
            ),
          ),
          Opacity(
            opacity: 0.55,
            child: Image(
              image: AssetImage('assets/images/lighthouse_main_bg.png'),
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Level, XP and gems as three raised glass badges, centred in the top
/// bar — the panel that used to carry them is gone.
///
/// Each badge is a rounded capsule with a tinted 3D ledge under it, a
/// coloured icon disc, the count and its label. The row sits in a
/// [FittedBox] so a narrow phone scales the trio down rather than
/// overflowing or wrapping them.
class _TopStatsBar extends StatelessWidget {
  const _TopStatsBar({required this.stats, this.onPressed});

  final StudentGamification stats;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatBadge(
                icon: Icons.workspace_premium_rounded,
                tint: const Color(0xFF6D5AE6),
                value: '${stats.level}',
                label: tr('home.level'),
                onPressed: onPressed,
              ),
              const SizedBox(width: 10),
              _StatBadge(
                icon: Icons.star_rounded,
                tint: const Color(0xFFF59E0B),
                value: '${stats.xp}',
                label: 'XP',
                onPressed: onPressed,
              ),
              const SizedBox(width: 10),
              StudentRewardPulse(
                child: _StatBadge(
                  icon: Icons.diamond_rounded,
                  tint: const Color(0xFF0EA5A5),
                  value: '${stats.gems}',
                  label: tr('home.gem'),
                  onPressed: onPressed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.icon,
    required this.tint,
    required this.value,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final Color tint;
  final String value;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final deep = Color.lerp(tint, Colors.black, 0.38)!;
    return StudentPressScale(
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          // The darker copy of the tint peeking out below the face is the
          // whole 3D effect — the same trick the book dropdowns use.
          padding: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: deep.withOpacity(0.55),
            boxShadow: [
              BoxShadow(
                color: deep.withOpacity(0.34),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(7, 6, 13, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.94),
                  Colors.white.withOpacity(0.74),
                ],
              ),
              border: Border.all(color: Colors.white, width: 1.4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [tint, deep],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tint.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 17),
                ),
                const SizedBox(width: 7),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        color: deep,
                        fontSize: 15,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF5A7286),
                        fontSize: 9.5,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A translucent card, so the lighthouse behind it stays visible.

/// The greeting banner. Deliberately pale rather than the old deep-indigo
/// slab: the lighthouse behind it is now a full-strength background, and a
/// dark band across the top fought it. The student's own character stands
/// where the logo medallion used to be, floating beside their name.
class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.profile,
    required this.onCharacterTap,
  });

  final StudentProfile profile;
  final VoidCallback onCharacterTap;

  @override
  Widget build(BuildContext context) {
    return Student3DCard(
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Colors.white.withOpacity(0.85),
          border: Border.all(color: Colors.white, width: 1.6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A4F46E5),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            // The saved character itself, not the emoji stand-in it used
            // to route through — that path could still prefer a Ready
            // Player Me portrait and hide the chosen picture.
            StudentAvatarView(size: 62, onTap: onCharacterTap)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 0, end: -5, duration: 2200.ms, curve: Curves.easeInOut),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('hub.welcome'),
                    style: TextStyle(
                      color: StudentSurface.mutedInk(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      profile.name,
                      maxLines: 1,
                      style: TextStyle(
                        color: StudentSurface.ink(context),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
