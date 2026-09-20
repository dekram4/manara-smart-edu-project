import 'dart:async';
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
import '../widgets/dealt_card_entrance.dart';
import '../widgets/student_no_back.dart';
import '../widgets/student_avatar_view.dart';
import '../services/student_avatar_store.dart';
import '../services/student_sound_service.dart';
import '../l10n/student_strings.dart';
import '../theme/student_theme.dart';
import '../utils/student_route_observer.dart';
import '../widgets/bouncy_text.dart';
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

class _StudentHomeScreenState extends State<StudentHomeScreen> with RouteAware {
  late StudentGamification _gamification;
  late final StudentContentService _contentService;
  late final ConfettiController _rewardController;

  /// يعيش خارج البطاقات لأن القائمة تتخلّص منها عند السحب. بدونه تعيد كل
  /// بطاقة حركة دخولها كلّما عادت إلى الشاشة.
  final DealEntranceTracker _dealTracker = DealEntranceTracker();

  /// Starts the deal a beat after the hub opens.
  Timer? _dealCue;

  /// How long the hub shows before the first card sets off.
  ///
  /// The cards used to wait for the spoken welcome to finish. That clip
  /// runs ten seconds, so they sat behind the six-second fallback every
  /// time — and then dealt at 1.7s a card, the last one landing some
  /// twenty seconds after the path was chosen. They now start under the
  /// greeting, on the rail's own opening beat, and the ten of them are in
  /// place ten seconds after the hub opens.
  static const _dealAfter = DealtCardEntrance.defaultStartDelay;
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
    // The character the student chose, as their profile records it — the
    // pick used to live only on the phone that made it.
    unawaited(StudentAvatars.adoptFromProfile(widget.profile.appearance));
    _contentService = StudentContentService(widget.authService.client,
        baseUrl: widget.apiBaseUrl, authService: widget.authService);
    _rewardController = ConfettiController(duration: const Duration(seconds: 2));
    _loadGamification();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runOpeningSequence());
  }

  /// The hub's opening: music underneath from the first frame, the greeting
  /// over it, and the cards dealt in straight away — see [_dealAfter]. The
  /// card sounds step down under the greeting so the sentence stays clear
  /// (see `StudentSoundService.playCardDeal`).
  void _runOpeningSequence() {
    // The music starts with the screen and never stops for anything on it.
    //
    // It used to wait for the whole deal to finish, on the reasoning that it
    // would otherwise compete with the greeting and the card sounds. It does
    // not: it plays at a twentieth of full volume, and since every player now
    // mixes rather than taking audio focus, the greeting and the taps simply
    // sit on top of it.
    StudentSoundService.instance.ensureAmbient();

    // Owned here and cancelled in dispose, so nothing outlives this screen.
    _dealCue = Timer(_dealAfter, _beginDeal);
    StudentSoundService.instance.speakWelcome();
  }

  bool _dealBegun = false;

  /// The rail deals itself in, one card at a time.
  void _beginDeal() {
    if (_dealBegun || !mounted) return;
    _dealBegun = true;
    _dealCue?.cancel();
    _dealTracker.arm();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) studentRouteObserver.subscribe(this, route);
  }

  /// A card was opened on top of the hub: the lesson gets the silence.
  @override
  void didPushNext() => StudentSoundService.instance.pauseAmbient();

  /// Back on the hub: the music comes back where it left off.
  @override
  void didPopNext() {
    // Whatever the portal was saying belongs to the portal; if the student
    // came straight back out, it stops with them.
    unawaited(StudentSoundService.instance.stopSpeaking());
    StudentSoundService.instance.resumeAmbient();
    // The course may have changed while the student was inside a card —
    // a teacher adds a unit or renames one mid-session. The cached copy is
    // dropped so the next lesson switch reads the tree again rather than
    // offering what the hub happened to fetch an hour ago.
    _selectionData = null;
    unawaited(_loadGamification());
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

  @override
  void dispose() {
    studentRouteObserver.unsubscribe(this);
    _dealCue?.cancel();
    _dealTracker.dispose();
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
    // The portal introduces itself.
    //
    // Spoken here rather than inside each destination screen: there are ten
    // of them, several sharing a screen with different arguments, and the one
    // thing they all have in common is being opened from this method. The
    // music is already stepping aside by the time the line starts — the route
    // push that follows triggers `didPushNext`.
    if (index >= 0 && index < _homeSections.length) {
      unawaited(StudentSoundService.instance.speakPortal(
        _homeSections[index].titleKey,
      ));
    }
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
              authService: widget.authService,
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
  /// The hierarchy is fetched when it is needed and kept until the student
  /// leaves the hub and comes back — see [didPopNext], which drops it. Held
  /// that long because re-fetching on every open would put a spinner in
  /// front of a menu; dropped that often because a teacher editing the
  /// course mid-session should reach the student on their next move, not on
  /// their next sign-in.
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
          contentService: StudentContentService(widget.authService.client,
              baseUrl: widget.apiBaseUrl, authService: widget.authService),
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
        authService: widget.authService,
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
        authService: widget.authService,
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
              authService: widget.authService,
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
    // Below this the bar cannot hold a labelled button and the four
    // controls beside it. Measured against the overflow, not guessed.
    final narrowBar = size.width < 560;

    return StudentNoBack(
      child: Scaffold(
      backgroundColor: StudentSurface.ground(context),
      appBar: AppBar(
        // No back arrow. The hub is where a signed-in student lives, and
        // everything behind it in the stack is a screen they have already
        // finished with. Without this the bar would draw one automatically
        // and it would be the one way back that PopScope does not close.
        automaticallyImplyLeading: false,
        // The enlarged mark is 54px and its pill adds 14px of padding, so
        // 70 left only 2px of slack — raised so the bigger logo cannot
        // press against the bar.
        toolbarHeight: 82,
        titleSpacing: narrowBar ? 6 : 16,
        title: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(9, 7, 14, 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
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
              ManaraLogo(size: narrowBar ? 42 : 54),
              // On a phone the mark alone names the app, and the words beside
              // it were part of what pushed the bar past its width.
              if (!narrowBar) const SizedBox(width: 10),
              if (!narrowBar) Flexible(
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
            padding: EdgeInsets.symmetric(horizontal: narrowBar ? 0 : 4, vertical: 8),
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
                    // The comment above has always said this collapses to
                    // the icon on a narrow bar. It never did, and the
                    // label plus the four controls after it overflowed a
                    // portrait phone's bar by 81px — an error the student
                    // saw as a yellow-and-black bar across the top.
                    child: narrowBar
                        ? IconButton(
                            onPressed: _changeLesson,
                            icon: const Icon(Icons.alt_route_rounded),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF0E5F6B),
                              foregroundColor: Colors.white,
                            ),
                          )
                        : FilledButton.icon(
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
            padding: EdgeInsets.symmetric(horizontal: narrowBar ? 0 : 4),
            child: StudentAvatarView(size: narrowBar ? 34 : 38, onTap: _openPersonality),
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
                    child: BouncyText(
                      tr('home.pickPortal'),
                      fontSize: 32,
                    ),
                  ),
                  const SizedBox(height: 7),
                  // الإرشاد أصغر وألطف من العنوان فوقه: يُقرأ جملةً لا
                  // عنواناً ثانياً يزاحم الأول.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: BouncyText(
                      tr('home.pickPortalHint'),
                      fontSize: 19,
                      maxScale: 1.12,
                      minScale: 0.92,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _HomeSectionGrid(
                      onSectionPressed: _openModule,
                      dealTracker: _dealTracker,
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
        color: Colors.white.withValues(alpha: 0.75),
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
  const _HomeSectionGrid({
    required this.onSectionPressed,
    required this.dealTracker,
  });

  final ValueChanged<int> onSectionPressed;
  final DealEntranceTracker dealTracker;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // The rail is sized from the screen's shorter edge so a phone in
    // landscape gets a shorter rail rather than one that eats the view.
    final shortest = math.min(size.width, size.height);
    final cardHeight = (shortest * 0.34).clamp(132.0, 178.0).toDouble();
    final cardWidth = (cardHeight * 1.32).clamp(150.0, 235.0).toDouble();

    // Room above and below the cards, and no clipping.
    //
    // The rail used to be exactly one card tall, which meant the viewport
    // cut every part of a card that was not at rest: the 16px it rises
    // under a finger, the breath, the 7% it grows by, and — most visibly —
    // the neon glow, whose outermost bloom reaches about 90px past the
    // card's own edge. A card cannot look like it is floating inside a box
    // trimmed to its exact size.
    //
    // The box is grown by twice `breathingRoom` and the same amount is
    // given back as cross-axis padding, so each card still lays out at
    // exactly `cardHeight` and only the space around it changed. The body
    // is a scroll view, so the extra height costs nothing on a short
    // screen.
    const breathingRoom = 46.0;

    return SizedBox(
      height: cardHeight + breathingRoom * 2,
      // Every card is built at once, not as it scrolls into view.
      //
      // This was a `ListView.separated`, which builds lazily: the cards past
      // the right edge did not exist yet, so their entrance never started.
      // A student saw two or three cards deal themselves in and the rest of
      // the rail apparently empty — and then, as they dragged sideways
      // looking for the others, each one sprang into its entrance the moment
      // it was built. That is what made the sequence look erratic and
      // out of order: it was not a timing problem, it was nine animations
      // waiting to be constructed.
      //
      // Nine cards is a small enough list to build eagerly, and that is what
      // makes the deal a single sequence the student can simply watch.
      child: SingleChildScrollView(
        // Named, because the page body is a scroll view too: finding the rail
        // by type picks whichever comes first in the tree, which is not this
        // one.
        key: const ValueKey('portal-rail'),
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        // Clip.none so the glow and the lift are not shaved off at the
        // rail's edges the moment a card reacts.
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: breathingRoom,
        ),
        child: Row(
          children: [
            for (var index = 0; index < _homeSections.length; index++) ...[
              if (index > 0) const SizedBox(width: 12),
              SizedBox(
                width: cardWidth,
                // The deal sits outside the tile's key on purpose: the hub's
                // motion tests read the first `Transform` under that key and
                // assert on the card's own breath and tilt. Wrapping the key
                // would put this transform there instead.
                child: DealtCardEntrance(
                  index: index,
                  tracker: dealTracker,
                  child: _SectionTile(
                    // Named by its portal rather than its position, so the
                    // key survives the rail being reordered.
                    key: ValueKey('portal-tile-${_homeSections[index].titleKey}'),
                    section: _homeSections[index],
                    // Staggers each card's float so the rail breathes rather
                    // than pulsing as one block.
                    index: index,
                    onPressed: () => onSectionPressed(index),
                  ),
                ),
              ),
            ],
          ],
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
  /// The idle life of the card: a slow breath and a glow that swells with
  /// it, running whenever nothing is touching it.
  ///
  /// This is the second attempt at idle motion. The first was a vertical
  /// drift, which was removed for reading as restless — nine cards sliding
  /// on their own timers. The difference here is what moves: a breath is a
  /// scale and a depth change about its own centre, so the card stays put
  /// and appears to be alive rather than adrift, and the glow pulsing with
  /// it does the attracting that the travel was trying to do.
  ///
  /// Each card is given its own period and starts part-way into the cycle,
  /// so nine of them never breathe in unison — that lockstep is what makes
  /// a row of animated cards look mechanical.
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 3400 + (widget.index % 5) * 260),
  );

  /// The breath, eased at both ends so it never snaps at the turn.
  late final Animation<double> _idleCurve = CurvedAnimation(
    parent: _idle,
    curve: Curves.easeInOutSine,
  );

  /// The reaction to a finger or a pointer resting on the card: it rises,
  /// grows and lights its rim. Fast in, quick out — no lingering.
  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 130),
    reverseDuration: const Duration(milliseconds: 190),
  );

  late final Animation<double> _liftCurve = CurvedAnimation(
    parent: _lift,
    curve: Curves.easeOutCubic,
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

  /// Going down: very stiff, so the card answers the finger the instant it
  /// lands. Nothing about a press should feel like it is catching up.
  static const _pressSpring = SpringDescription(
    mass: 1,
    stiffness: 900,
    damping: 26,
  );

  /// Coming back: still fast, and just under critical damping so it
  /// overshoots once and is done inside a couple of hundred milliseconds.
  /// A slow, soft return reads as the card sagging rather than springing.
  static const _releaseSpring = SpringDescription(
    mass: 1,
    stiffness: 620,
    damping: 17,
  );

  /// Where the finger is on the card right now, as -1..1 from its centre.
  ///
  /// Updated on every pointer move while a finger is down, not just once
  /// on touch: the tilt follows the drag continuously, so sliding a thumb
  /// across the card swings it like a panel on a gimbal. Set straight into
  /// a ValueNotifier rather than through setState so a move never costs a
  /// widget rebuild — the AnimatedBuilder listening to it repaints the
  /// transform alone.
  final ValueNotifier<Offset> _pointerAlign = ValueNotifier(Offset.zero);

  bool _hovered = false;
  bool _pressed = false;

  @override
  void dispose() {
    _idle.dispose();
    _lift.dispose();
    _push.dispose();
    _pointerAlign.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Offset into the cycle so the rail is never in unison, then run
    // forever, reversing at each end.
    _idle.value = (widget.index % 7) / 7;
    _idle.repeat(reverse: true);
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
      SpringSimulation(
        target > 0 ? _pressSpring : _releaseSpring,
        _push.value,
        target,
        _push.velocity,
      ),
    );
  }

  /// Tracks the finger, normalised against the card's own box.
  ///
  /// Called on down *and* on every move, which is what makes the tilt
  /// follow a drag instead of freezing at wherever the touch began.
  void _trackPointer(Offset localPosition) {
    final box = context.findRenderObject() as RenderBox?;
    final size = box?.size;
    if (size == null || size.isEmpty) {
      _pointerAlign.value = Offset.zero;
      return;
    }
    // Allowed a little past the card's own edge, so a drag that runs off
    // the side keeps swinging instead of hitting a wall at the border.
    _pointerAlign.value = Offset(
      ((localPosition.dx / size.width) * 2 - 1).clamp(-1.4, 1.4),
      ((localPosition.dy / size.height) * 2 - 1).clamp(-1.4, 1.4),
    );
  }

  /// Lets go: the tilt returns to flat with the same spring as the push,
  /// so the card swings back level rather than snapping.
  void _releasePointer() {
    _pointerAlign.value = Offset.zero;
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
              color: tint.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Scales down rather than wrapping or clipping, so a long
        // portal name cannot change the card's height.
        // عنوان البطاقة بالحروف المتمايلة نفسها، بلا رقصة مستمرة: البطاقة
        // تتمايل تحت الإصبع أصلاً، وعنوانٌ يقفز فوق بطاقة تقفز ضجيج.
        // والتمايل هنا أهدأ لأن المساحة ضيّقة.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: BouncyText(
            widget.section.title,
            fontSize: 21,
            animate: false,
            maxScale: 1.12,
            minScale: 0.92,
            alignment: WrapAlignment.center,
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
      // A raw Listener under the GestureDetector, not more gesture
      // callbacks.
      //
      // The rail is a horizontal ListView, so a drag on a card belongs to
      // the list's scroll — a pan recognizer here would fight it for the
      // arena and either steal the scroll or never fire. A Listener sees
      // every pointer event without entering the arena at all, so the tilt
      // can follow the finger while the list still scrolls normally and
      // the tap still fires.
      child: Listener(
        behavior: HitTestBehavior.deferToChild,
        onPointerDown: (event) {
          // النقرة تُسمع عند ملامسة الإصبع لا عند رفعه.
          //
          // التعليق على `onTap` يعني انتظار حلبة الإيماءات حتى تحسم أن هذه
          // نقرة لا سحب — وهو تأخّر يُدرَك، فيبدو الصوت منفصلاً عن اللمسة.
          //
          // و`onPointerDown` يقع مرة واحدة لكل إصبع: سحب الشريط أفقياً
          // يبدأ بملامسة واحدة ثم حركة، فلا ينتج رشقة نقرات على كل بطاقة
          // يمرّ فوقها — تكّة واحدة عند البداية، وهي تغذية راجعة مناسبة.
          StudentSoundService.instance.playTap();
          _pressed = true;
          _trackPointer(event.localPosition);
          _sync();
          _springPushTo(1);
        },
        onPointerMove: (event) {
          if (_pressed) _trackPointer(event.localPosition);
        },
        onPointerUp: (_) {
          _pressed = false;
          _releasePointer();
          _sync();
          _springPushTo(0);
        },
        onPointerCancel: (_) {
          _pressed = false;
          _releasePointer();
          _sync();
          _springPushTo(0);
        },
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation:
              Listenable.merge([_idleCurve, _liftCurve, _push, _pointerAlign]),
          builder: (context, child) {
            final lift = reduceMotion ? 0.0 : _liftCurve.value.clamp(0.0, 1.4);
            final aim = reduceMotion ? Offset.zero : _pointerAlign.value;
            // The spring overshoots past 1 on the way down and past 0 on
            // the way back; both are wanted, so this is clamped only
            // loosely — just enough that a violent fling cannot invert
            // the card.
            final push = reduceMotion ? 0.0 : _push.value.clamp(-0.35, 1.25);

            // The breath, -1..1 about the resting size, faded out by the
            // lift so it hands over to the touch rather than fighting it.
            // Multiplying by (1 - lift) is what makes the two blend: as a
            // finger arrives the idle motion recedes to nothing over the
            // same 130ms the card takes to rise, so there is no cut.
            final breath = reduceMotion
                ? 0.0
                : (_idleCurve.value * 2 - 1) * (1 - lift.clamp(0.0, 1.0));

            // Real depth rather than a flat scale: a perspective entry in
            // the matrix, a tilt away from the rail as the card rises, and
            // a tilt that tracks the finger across the card while it is
            // down. Drag a thumb left and the card swings like a panel on
            // a gimbal; that continuous following is what separates a card
            // being handled from one playing a canned animation.
            //
            // The tilt is driven by `aim`, which the Listener updates on
            // every pointer move, and scaled by `push` so it is only ever
            // present while something is actually on the card.
            //
            // The squash is deliberately not uniform: pressing takes more
            // off the height than the width, the way a real soft object
            // gives under a thumb. A uniform shrink reads as the card
            // moving away instead of compressing.
            final squashX =
                1 + breath * 0.014 + lift * 0.07 - push * 0.045;
            final squashY =
                1 + breath * 0.014 + lift * 0.07 - push * 0.080;

            final matrix = Matrix4.identity()
              ..setEntry(3, 2, 0.0020)
              // A couple of pixels of rise on the breath — enough to read
              // as the card drawing toward the viewer, far short of the
              // travel that made the old drift look adrift.
              ..translateByDouble(0.0, breath * -2.5 - lift * 16 + push * 5, 0.0, 1.0)
              ..rotateX(-lift * 0.10 - aim.dy * push * 0.26)
              ..rotateY(breath * 0.012 + aim.dx * push * 0.26)
              ..scaleByDouble(squashX, squashY, squashX, 1.0);

            // The rim is the neon: a quiet tinted hairline at rest that
            // burns into the portal's own colour as the card comes up, so
            // each card glows as itself rather than every card glowing
            // the same white. Past halfway it blends toward white, which
            // is what gives a neon tube its hot core.
            //
            // It also breathes. The ambient pulse is a floor under the
            // touch glow rather than a separate effect, so the rim is
            // never fully dark and arriving with a finger only takes it
            // brighter — no seam between the two.
            final ambient = ((breath + 1) / 2) * 0.30;
            final glow = math.max(ambient, lift.clamp(0.0, 1.0));
            final rim = Color.lerp(tint, Colors.white, glow * 0.35)!;

            return Transform(
              alignment: Alignment.center,
              transform: matrix,
              child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    color: StudentSurface.glass(context, 0.72 + lift * 0.18),
                    border: Border.all(
                      color: rim.withValues(alpha: 0.45 + glow * 0.52),
                      width: 1.6 + lift * 1.4,
                    ),
                    boxShadow: [
                      // Four layers, each with one job. A tight contact
                      // shadow that stays put so the card keeps its
                      // footing; a coloured bloom that grows as it rises;
                      // a wide soft halo that only appears on engagement —
                      // that one is what reads as a glow rather than a
                      // drop shadow; and a tight, nearly opaque ring hard
                      // against the border, which is the lit tube itself.
                      BoxShadow(
                        color: const Color(0x33000000),
                        blurRadius: 6 + lift * 6,
                        offset: Offset(0, 3 + lift * 3),
                      ),
                      BoxShadow(
                        color: tint.withValues(alpha: 0.20 + glow * 0.42),
                        blurRadius: 18 + lift * 34,
                        spreadRadius: lift * 5,
                        offset: Offset(0, 9 + lift * 12),
                      ),
                      if (glow > 0.01) ...[
                        BoxShadow(
                          color: tint.withValues(alpha: glow * 0.34),
                          blurRadius: 30 + glow * 52,
                          spreadRadius: 2 + glow * 12,
                        ),
                        BoxShadow(
                          color: rim.withValues(alpha: glow * 0.55),
                          blurRadius: 5 + glow * 9,
                          spreadRadius: glow * 1.4,
                        ),
                      ],
                    ],
                  ),
                  child: child,
                ),
            );
          },
          child: contents,
        ),
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
    // This gradient *is* the hub's background — it covers the whole
    // screen behind the rail, so leaving it cream was what kept the hub
    // looking like a light app with dark cards sitting on it. It follows
    // the theme now, and the lighthouse is dimmed at night so it reads as
    // artwork in the dark rather than a bright panel.
    final night = StudentSurface.isDark(context);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: night
                    ? const [
                        Color(0xFF0B0F19),
                        Color(0xFF0E1117),
                        Color(0xFF11151F),
                      ]
                    : const [
                        Color(0xFFFFF6E7),
                        Color(0xFFFDF3EA),
                        Color(0xFFEFF5FB),
                      ],
              ),
            ),
          ),
          Opacity(
            opacity: night ? 0.22 : 0.55,
            child: const Image(
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
            color: deep.withValues(alpha: 0.55),
            boxShadow: [
              BoxShadow(
                color: deep.withValues(alpha: 0.34),
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
                  Colors.white.withValues(alpha: 0.94),
                  Colors.white.withValues(alpha: 0.74),
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
                        color: tint.withValues(alpha: 0.5),
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
          // Both of these were hardcoded white, which is what made the
          // greeting unreadable in the dark theme: the panel stayed white
          // while the text colours followed the theme and turned pale, so
          // "أهلًا جوري داود" was near-white on near-white.
          color: StudentSurface.glass(context, 0.90),
          border: Border.all(
            color: StudentSurface.isDark(context)
                ? const Color(0x33FFD27A)
                : Colors.white,
            width: 1.6,
          ),
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
                  // الترحيب والاسم كتلة واحدة مرحة: كلاهما بالحروف
                  // المتمايلة، والاسم أكبر لأنه ما يخصّ الطفل وحده.
                  //
                  // ولم يعد لونهما يتبع السمة: الحروف تحمل ألوانها الزاهية
                  // وحدّاً أبيض حولها، فتُقرأ على الفاتح والداكن معاً.
                  BouncyText(
                    tr('hub.welcome'),
                    fontSize: 19.2,
                    maxScale: 1.1,
                    minScale: 0.94,
                  ),
                  const SizedBox(height: 5),
                  // The student's own name, at a size that reads as a
                  // greeting rather than a caption.
                  //
                  // It was inside a `FittedBox(scaleDown)`, which meant the
                  // 22pt set here was a ceiling and not a size: a long name
                  // on a narrow phone was quietly shrunk to whatever fitted,
                  // and the one line meant to welcome the child by name came
                  // out smaller than the label above it. Ellipsis instead —
                  // a trimmed name at a readable size beats a whole one too
                  // small to read.
                  // The one line that greets the child by name, so it is
                  // the one line that gets the playful face and the rainbow.
                  // The drop shadow lives inside RainbowText, outside the
                  // shader — a tinted shadow is just a coloured blur.
                  BouncyText(
                    trf('path.greeting', {'name': profile.name}),
                    fontSize: 36,
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
