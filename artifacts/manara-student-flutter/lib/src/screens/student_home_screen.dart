import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../models/academic_context.dart';
import '../models/student_content.dart';
import '../models/student_profile.dart';
import '../models/student_gamification.dart';
import '../services/student_auth_service.dart';
import '../services/student_content_service.dart';
import '../widgets/manara_logo.dart';
import '../widgets/student_experience.dart';
import '../widgets/student_floating_character.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import 'login_screen.dart';
import 'student_cinema_screen.dart';
import 'student_chat_screen.dart';
import 'student_content_screen.dart';
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

  @override
  void initState() {
    super.initState();
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
    if (gainedGems > 0) parts.add('+$gainedGems جوهرة');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$phrase ${parts.join(' و ')}')),
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
          builder: (_) => StudentCinemaScreen(
            profile: widget.profile,
            authService: widget.authService,
            apiBaseUrl: widget.apiBaseUrl,
            academicContext: widget.academicContext,
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
          builder: (_) => StudentQuizScreen(
            profile: widget.profile,
            contentService: StudentContentService(
              widget.authService.client,
              baseUrl: widget.apiBaseUrl,
            ),
            academicContext: widget.academicContext,
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
          builder: (_) => StudentChatScreen(
            profile: widget.profile,
            apiBaseUrl: widget.apiBaseUrl,
            authService: widget.authService,
          ),
        ),
      );
      return;
    }

    Navigator.of(context)
        .push(
      StudentPageRoute<void>(
        builder: (_) => StudentContentScreen(
          profile: widget.profile,
          authService: widget.authService,
          apiBaseUrl: widget.apiBaseUrl,
          academicContext: widget.academicContext,
          // The first card is "شرح الدرس"; the cinema card is handled above.
          // Subtracting one here made the first card access modules[-1].
          initialModule: modules[index == 0 ? 0 : index - 1],
        ),
      ),
    )
        .then((_) => _loadGamification());
  }

  void _openPersonality() {
    Navigator.of(context).push(
      StudentPageRoute<void>(
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
        const SnackBar(content: Text('اللقاء المباشر غير مفعّل لحسابك حاليًا.')),
      );
      return;
    }
    try {
      final selection = await StudentContentService(
        widget.authService.client,
        baseUrl: widget.apiBaseUrl,
      ).fetchTutorExperience(
        widget.profile,
        academicContext: widget.academicContext,
        type: liveMeeting
            ? TutorExperienceType.liveMeeting
            : TutorExperienceType.virtualTeacher,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        StudentPageRoute<void>(
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
                ? 'تعذر تحميل اللقاء المباشر. حاول مرة أخرى.'
                : 'تعذر تحميل المعلم الافتراضي. حاول مرة أخرى.',
          ),
        ),
      );
    }
  }

  Future<void> _openProblemSolver() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final lessons = await StudentContentService(
        widget.authService.client,
        baseUrl: widget.apiBaseUrl,
      ).fetchLessons(widget.profile, academicContext: widget.academicContext);
      if (!mounted) return;
      await Navigator.of(context).push(
        StudentPageRoute<void>(
          builder: (_) => StudentProblemSolverScreen(
            lessons: lessons,
            apiBaseUrl: widget.apiBaseUrl,
            profile: widget.profile,
            contentService: StudentContentService(
              widget.authService.client,
              baseUrl: widget.apiBaseUrl,
            ),
            authService: widget.authService,
            academicContext: widget.academicContext,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذر تحميل الدروس لحل المسائل. حاول مرة أخرى.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final characterSize =
        (math.min(size.width, size.height) * 0.30).clamp(96.0, 190.0).toDouble();

    return Scaffold(
      backgroundColor: StudentPalette.canvas,
      appBar: AppBar(
        toolbarHeight: 70,
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
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ManaraLogo(size: 38),
              SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مَنارة',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: StudentPalette.ink,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'SMART EDU',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: StudentPalette.indigo,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          const StudentSoundToggle(),
          IconButton(
            onPressed: _signOut,
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
        // Level, XP and gems live here and nowhere else — they used to be
        // printed three times over (avatar room, progress card, and the
        // card's own level pill).
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _TopStatsBar(stats: _gamification),
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
                       child: _WelcomeCard(profile: widget.profile),
                    ),
                  ),
                  // The selected character alone, floating over the
                  // backdrop — no card, no duplicated stats. Its size comes
                  // from the screen's shorter edge so it stays in
                  // proportion in both orientations.
                  SizedBox(
                    height: characterSize * 1.28,
                    child: Center(
                      child: StudentFloatingCharacter(
                        appearance: widget.profile.appearance,
                        size: characterSize,
                        onTap: _openPersonality,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: StudentAnimatedCard(
                      delay: const Duration(milliseconds: 80),
                      child: _ProgressCard(
                        stats: _gamification,
                        onPressed: () {
                          StudentSoundService.instance.playTap();
                          Navigator.of(context).push(
                            StudentPageRoute<void>(
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
                  if (widget.academicContext != null) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: _AcademicContextSummary(
                        academicContext: widget.academicContext!,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      'اختر بوابتك',
                      style: TextStyle(
                        color: Color(0xFF0E1B2A),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      'المس أي بطاقة لتبدأ رحلتك',
                      style: TextStyle(
                        color: Color(0xFF5680AC),
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
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.colors,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
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

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.stats, required this.onPressed});
  final StudentGamification stats;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => _GlassCard(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [StudentPalette.indigo, StudentPalette.sky],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'تقدمك ومكافآتك',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  // The level, XP and gems that used to be repeated here
                  // now live in the top bar. Only the streak, which is not
                  // shown there, stays.
                  _ProgressMetric(
                    icon: Icons.local_fire_department_rounded,
                    color: const Color(0xFFFB7185),
                    label: '${stats.streak} يوم',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: stats.levelProgress / 100,
                  minHeight: 12,
                  color: StudentPalette.orange,
                  backgroundColor: const Color(0x33DDE6FF),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'باقي ${stats.xpToNextLevel} XP للمستوى التالي • اضغط لعرض الإنجازات',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF49617C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: StudentPalette.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

const _homeSections = <_HomeSection>[
  _HomeSection(
    title: 'شرح الدرس',
    subtitle: 'تعلم بطريقة ممتعة',
    description: 'افتح الدرس وشاهد الشرح خطوة بخطوة.',
    icon: Icons.play_lesson_rounded,
    colors: [Color(0xFF9A5B09), Color(0xFFF59E0B)],
    accent: Color(0xFFFFE08A),
  ),
  _HomeSection(
    title: 'سينما منارة',
    subtitle: 'فيديوهات المعلم والمشرف',
    description: 'اسحب بين الفيديوهات وشاهد الشروحات بجودة عالية.',
    icon: Icons.movie_filter_rounded,
    colors: [Color(0xFF0B5D66), Color(0xFF0B8693)],
    accent: Color(0xFF9EEBEA),
  ),
  _HomeSection(
    title: 'عالم الترفيه',
    subtitle: 'ألعاب تعليمية',
    description: 'تعلّم والعب واكسب مكافآت جديدة.',
    icon: Icons.sports_esports_rounded,
    colors: [Color(0xFF4B267F), Color(0xFF8B5CF6)],
    accent: Color(0xFFE9D5FF),
  ),
  _HomeSection(
    title: 'شخصيتي',
    subtitle: 'أصنع بطلي',
    description: 'غيّر شعرك وملابسك واحفظ شخصيتك.',
    icon: Icons.face_retouching_natural_rounded,
    colors: [Color(0xFF9B3E68), Color(0xFFE05A86)],
    accent: Color(0xFFFFD0DF),
  ),
  _HomeSection(
    title: 'المعلم الافتراضي',
    subtitle: 'صديقك الذكي',
    description: 'اسأل واستكشف أفكارًا تساعدك في رحلتك.',
    icon: Icons.smart_toy_rounded,
    colors: [Color(0xFF274E76), Color(0xFF1394D2)],
    accent: Color(0xFFBAE6FD),
  ),
  _HomeSection(
    title: 'مركز الاختبارات',
    subtitle: 'اختبارات المعلم والدورية',
    description: 'أجب عن أسئلتك وشاهد نتيجتك المحفوظة بأمان.',
    icon: Icons.quiz_rounded,
    colors: [Color(0xFF165B4A), Color(0xFF16A085)],
    accent: Color(0xFFB7F7DD),
  ),
  _HomeSection(
    title: 'حلّ المسائل',
    subtitle: 'اسأل عن الدرس',
    description: 'مساعد ذكي يقدم شرحًا مباشرًا ومفيدًا لأسئلتك.',
    icon: Icons.auto_awesome_rounded,
    colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
    accent: Color(0xFFE9D5FF),
  ),
  _HomeSection(
    title: 'اللقاء المباشر',
    subtitle: 'انضم داخل منارة',
    description: 'ادخل لقاء الدرس من دون مغادرة التطبيق.',
    icon: Icons.videocam_rounded,
    colors: [Color(0xFFB45309), Color(0xFFF59E0B)],
    accent: Color(0xFFFFE4A3),
  ),
  _HomeSection(
    title: 'دردشة منارة',
    subtitle: 'تواصل آمن',
    description: 'نتحقق من الخصوصية قبل عرض أي رسالة أو زميل.',
    icon: Icons.forum_rounded,
    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
    accent: Color(0xFFBFDBFE),
  ),
];

/// A shelf of wide 3D game-portal tiles — the module grid the student picks
/// a destination from. `SliverGridDelegateWithMaxCrossAxisExtent` sizes each
/// tile toward the target ~230x170 game-card proportions and fits as many
/// columns as the available (landscape-favoring) width allows, rather than
/// a fixed 2/3-column breakpoint.
class _HomeSectionGrid extends StatelessWidget {
  const _HomeSectionGrid({required this.onSectionPressed});

  final ValueChanged<int> onSectionPressed;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 22),
      itemCount: _homeSections.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: 16,
        crossAxisSpacing: 14,
        childAspectRatio: 230 / 170,
      ),
      itemBuilder: (context, index) => _SectionTile(
        section: _homeSections[index],
        onPressed: () => onSectionPressed(index),
      ),
    );
  }
}

/// One wide 3D game-portal card: a dark extrusion base under a beveled,
/// bright board, a big icon medallion centered above the bold title — a
/// single consistent shape for every tile, no tall/narrow capsule and no
/// dead vertical space above or below the content.
class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.section, required this.onPressed});

  final _HomeSection section;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final base = section.colors.first;
    final top = section.colors.last;
    final extrusion = Color.lerp(base, Colors.black, 0.32)!;
    const radius = 22.0;
    return StudentPressScale(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.only(bottom: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: extrusion.withOpacity(0.80),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.20), blurRadius: 12, offset: const Offset(0, 8)),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              // Translucent so the lighthouse reads through the grid too,
              // but still each portal's own colour and 3D ledge — turning
              // these plain white would have thrown away the chunky toy
              // cards the dashboard is built around.
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [top.withOpacity(0.82), base.withOpacity(0.82)],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.65), width: 2.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Stack(
                children: [
                  // A diagonal glossy sheen — the same raised-3D-toy bevel
                  // the rest of the app's cards use.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.22),
                            Colors.transparent,
                            Colors.black.withOpacity(0.06),
                          ],
                          stops: const [0, 0.5, 1],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.white, section.accent.withOpacity(0.75)],
                            ),
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(color: base.withOpacity(0.45), blurRadius: 8, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Icon(section.icon, color: base, size: 30),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          section.title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

/// Level, XP and gems, shown once, in the top bar.
///
/// The row is wrapped in a [FittedBox] so a narrow phone scales it down
/// instead of overflowing.
class _TopStatsBar extends StatelessWidget {
  const _TopStatsBar({required this.stats});

  final StudentGamification stats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.9)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A4F46E5),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TopStat(
                icon: Icons.workspace_premium_rounded,
                color: StudentPalette.indigo,
                label: 'المستوى ${stats.level}',
              ),
              const SizedBox(width: 14),
              _TopStat(
                icon: Icons.star_rounded,
                color: StudentPalette.orange,
                label: '${stats.xp} XP',
              ),
              const SizedBox(width: 14),
              StudentRewardPulse(
                child: _TopStat(
                  icon: Icons.diamond_rounded,
                  color: StudentPalette.sky,
                  label: '${stats.gems} جوهرة',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopStat extends StatelessWidget {
  const _TopStat({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF0E1B2A),
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

/// A translucent card, so the lighthouse behind it stays visible.
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: StudentShapes.playfulCard,
        border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A4F46E5),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return StudentPressScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: StudentShapes.playfulCard,
          child: card,
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.profile});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    return Student3DCard(
      child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            StudentPalette.deepIndigo,
            StudentPalette.indigo,
            StudentPalette.sky,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.28)),
            ),
            child: const ManaraLogo(size: 56),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أهلًا بك في منارة المعرفة',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  profile.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
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
