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
import '../widgets/student_avatar_room.dart';
import '../widgets/student_experience.dart';
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

class _StudentHomeScreenState extends State<StudentHomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambientController;
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
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
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
    _ambientController.dispose();
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
      ),
      body: Stack(
        children: [
          _AnimatedManaraBackground(animation: _ambientController),
          StudentCelebration(controller: _rewardController),
          SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    size.width >= 700 ? 18 : 0,
                    8,
                    size.width >= 700 ? 18 : 0,
                    32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  // On a wide/landscape window the three summary cards sit
                  // side by side instead of stacking full-width one after
                  // another — a tall, narrow window still gets the original
                  // vertical stack, since each card's own content wants
                  // real width to read comfortably.
                  if (size.width >= 700)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: StudentAnimatedCard(
                                child: _WelcomeCard(profile: widget.profile),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StudentAnimatedCard(
                                delay: const Duration(milliseconds: 60),
                                child: StudentAvatarRoom(
                                  stats: _gamification,
                                  onCustomize: _openPersonality,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
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
                          ],
                        ),
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: StudentAnimatedCard(
                         child: _WelcomeCard(profile: widget.profile),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: StudentAnimatedCard(
                        delay: const Duration(milliseconds: 60),
                        child: StudentAvatarRoom(
                          stats: _gamification,
                          onCustomize: _openPersonality,
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
                  ],
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
        color: const Color(0xFFE6FFFB).withAlpha(230),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF99F6E4)),
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
  Widget build(BuildContext context) => StudentPressScale(
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: StudentShapes.playfulCard,
            side: const BorderSide(color: Color(0x1F4F46E5)),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: StudentShapes.playfulCard,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: StudentShapes.playfulCard,
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFFFFFFFF), Color(0xFFF0F4FF)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x224F46E5),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
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
                    const Expanded(child: Text('تقدمك ومكافآتك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'المستوى ${stats.level}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: StudentPalette.deepIndigo,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceAround,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ProgressMetric(
                      icon: Icons.star_rounded,
                      color: StudentPalette.orange,
                      label: '${stats.xp} XP',
                    ),
                    StudentRewardPulse(
                      child: _ProgressMetric(
                        icon: Icons.diamond_rounded,
                        color: StudentPalette.sky,
                        label: '${stats.gems} جوهرة',
                      ),
                    ),
                    _ProgressMetric(
                      icon: Icons.local_fire_department_rounded,
                      color: Color(0xFFFB7185),
                      label: '${stats.streak} يوم',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: stats.levelProgress / 100,
                    minHeight: 12,
                    color: StudentPalette.orange,
                    backgroundColor: const Color(0xFFDDE6FF),
                  ),
                ),
                const SizedBox(height: 5),
                Text('باقي ${stats.xpToNextLevel} XP للمستوى التالي • اضغط لعرض الإنجازات', style: const TextStyle(fontSize: 12, color: Color(0xFF49617C), fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            ),
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

/// A shelf of chunky, individually-shaped module tiles — the "لمسة"-style
/// mechanism the student picks a destination from: a scrollable grid of big
/// touch targets, each with its own toy-like medallion icon, rather than a
/// single swipeable card at a time.
class _HomeSectionGrid extends StatelessWidget {
  const _HomeSectionGrid({required this.onSectionPressed});

  final ValueChanged<int> onSectionPressed;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 22),
      itemCount: _homeSections.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: wide ? 3 : 2,
        mainAxisSpacing: 22,
        crossAxisSpacing: 14,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (context, index) => _SectionTile(
        section: _homeSections[index],
        shapeVariant: index % 3,
        onPressed: () => onSectionPressed(index),
      ),
    );
  }
}

/// One "توي" (toy) tile: a chunky sticker-shaped card topped with a raised
/// medallion badge. [shapeVariant] cycles the card's corner silhouette and
/// the medallion's own shape so neighboring tiles never look like clones of
/// each other — only their color, icon and text change otherwise.
class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.section,
    required this.shapeVariant,
    required this.onPressed,
  });

  final _HomeSection section;
  final int shapeVariant;
  final VoidCallback? onPressed;

  BorderRadius get _cardRadius => switch (shapeVariant) {
    0 => StudentShapes.playfulCard,
    1 => const BorderRadius.only(
      topLeft: Radius.circular(34),
      topRight: Radius.circular(16),
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(34),
    ),
    _ => BorderRadius.circular(32),
  };

  @override
  Widget build(BuildContext context) {
    return StudentPressScale(
      child: GestureDetector(
        onTap: onPressed,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 26),
              padding: const EdgeInsets.fromLTRB(10, 30, 10, 12),
              decoration: BoxDecoration(
                borderRadius: _cardRadius,
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: section.colors,
                ),
                boxShadow: [
                  BoxShadow(
                    color: section.colors.last.withAlpha(105),
                    blurRadius: 18,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: _cardRadius,
                child: Stack(
                  children: [
                    // A diagonal glossy sheen — the "candy button" bevel
                    // that reads as a raised 3D toy rather than a flat tile.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.26),
                              Colors.transparent,
                              Colors.black.withOpacity(0.05),
                            ],
                            stops: const [0, 0.5, 1],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
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
                          const SizedBox(height: 3),
                          Text(
                            section.subtitle,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: section.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _ToyMedallion(
              icon: section.icon,
              accent: section.accent,
              baseColor: section.colors.first,
              shapeVariant: shapeVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// The raised icon badge sitting on top of a module tile — a coin (circle),
/// an app-icon squircle, or a rotated diamond, depending on [shapeVariant].
class _ToyMedallion extends StatelessWidget {
  const _ToyMedallion({
    required this.icon,
    required this.accent,
    required this.baseColor,
    required this.shapeVariant,
  });

  final IconData icon;
  final Color accent;
  final Color baseColor;
  final int shapeVariant;

  @override
  Widget build(BuildContext context) {
    const size = 60.0;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, accent.withOpacity(0.7)],
    );
    final shadow = [
      BoxShadow(
        color: baseColor.withOpacity(0.45),
        blurRadius: 10,
        offset: const Offset(0, 5),
      ),
    ];
    final border = Border.all(color: Colors.white, width: 3);

    final Widget background = switch (shapeVariant) {
      0 => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradient,
          border: border,
          boxShadow: shadow,
        ),
      ),
      1 => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.32),
          gradient: gradient,
          border: border,
          boxShadow: shadow,
        ),
      ),
      _ => Transform.rotate(
        angle: math.pi / 4,
        child: Container(
          width: size * 0.72,
          height: size * 0.72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.16),
            gradient: gradient,
            border: border,
            boxShadow: shadow,
          ),
        ),
      ),
    };

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          background,
          Icon(icon, color: baseColor, size: 27),
        ],
      ),
    );
  }
}

class _AnimatedManaraBackground extends StatelessWidget {
  const _AnimatedManaraBackground({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFF3F8F9), Color(0xFFEAF1FA)],
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final wave = Curves.easeInOut.transform(animation.value);
          return Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0xFFF3F8F9), Color(0xFFEAF1FA)],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -90 + (wave * 38),
                right: -70 + (wave * 44),
                child: _FloatingLight(
                  size: 230,
                  color: const Color(0x3348C6D9),
                ),
              ),
              Positioned(
                bottom: -100 + ((1 - wave) * 34),
                left: -80 + (wave * 32),
                child: _FloatingLight(
                  size: 270,
                  color: const Color(0x337C3AED),
                ),
              ),
              Positioned(
                top: 260 + ((1 - wave) * 30),
                left: 24 + (wave * 24),
                child: _FloatingLight(
                  size: 86,
                  color: const Color(0x33F59E0B),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FloatingLight extends StatelessWidget {
  const _FloatingLight({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 55,
              spreadRadius: 18,
            ),
          ],
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
