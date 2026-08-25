import 'dart:ui' show PointerDeviceKind;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/academic_context.dart';
import '../models/student_content.dart';
import '../models/student_profile.dart';
import '../models/student_gamification.dart';
import '../services/student_auth_service.dart';
import '../services/student_content_service.dart';
import '../widgets/manara_logo.dart';
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
  final _audioPlayer = AudioPlayer();
  final _pageController = PageController(viewportFraction: 0.86);
  late final AnimationController _ambientController;
  int _activePage = 0;
  late StudentGamification _gamification;
  late final StudentContentService _contentService;

  @override
  void initState() {
    super.initState();
    _gamification = widget.profile.gamification;
    _contentService = StudentContentService(widget.authService.client, baseUrl: widget.apiBaseUrl);
    _loadGamification();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playWelcome());
  }

  Future<void> _loadGamification() async {
    try {
      final result = await _contentService.checkStreak(widget.profile);
      if (!mounted) return;
      setState(() => _gamification = result.snapshot);
    } catch (_) {
      try {
        final snapshot = await _contentService.fetchGamification(widget.profile);
        if (mounted) setState(() => _gamification = snapshot);
      } catch (_) {}
    }
  }

  void _showReward(RewardResult result) {
    if (!mounted || (result.xp == 0 && result.gems == 0)) return;
    final parts = <String>[];
    if (result.xp > 0) parts.add('+${result.xp} XP');
    if (result.gems > 0) parts.add('+${result.gems} جوهرة');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('أحسنت! ${parts.join(' و ')}')));
  }

  Future<void> _playWelcome() async {
    try {
      await _audioPlayer.play(
        AssetSource('audio/manara-arabic-student-welcome.mp3'),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _pageController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    try {
      await widget.authService.client.auth.signOut();
    } catch (_) {}
    widget.authService.clearApiSession();
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
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
    final modules = [
      StudentContentModule.lesson,
      StudentContentModule.games,
    ];

    if (index == 1) {
      Navigator.of(context)
          .push(
        MaterialPageRoute<void>(
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
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StudentPersonalityScreen(
            profile: widget.profile,
            contentService: StudentContentService(widget.authService.client),
            creatorUrl: const String.fromEnvironment('READY_PLAYER_ME_CREATOR_URL'),
          ),
        ),
      );
      return;
    }

    if (index == 4) {
      _openTutor();
      return;
    }

    if (index == 5) {
      Navigator.of(context)
          .push(
        MaterialPageRoute<void>(
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
        MaterialPageRoute<void>(
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
      MaterialPageRoute<void>(
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
        MaterialPageRoute<void>(
          builder: (_) => StudentTutorScreen(
            selection: selection,
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
        MaterialPageRoute<void>(
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
    final carouselHeight = (size.height * 0.38).clamp(290.0, 420.0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F9),
      appBar: AppBar(
        title: const Text(
          'بوابة الطالب',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
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
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _WelcomeCard(profile: widget.profile)
                        .animate()
                        .fadeIn(duration: 450.ms)
                        .slideY(begin: 0.12),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _ProgressCard(
                      stats: _gamification,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => StudentProgressScreen(profile: widget.profile, stats: _gamification),
                        ),
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
                      'اختر بوابتك واسحب البطاقات',
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
                      'مرّر يمينًا ويسارًا لاستكشاف رحلة التعلم',
                      style: TextStyle(
                        color: Color(0xFF5680AC),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  SizedBox(
                    height: carouselHeight,
                    child: _HomeSectionCarousel(
                      controller: _pageController,
                      activePage: _activePage,
                      onPageChanged: (page) => setState(() => _activePage = page),
                      onSectionPressed: _openModule,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CarouselIndicator(
                    count: _homeSections.length,
                    activeIndex: _activePage,
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
    return Container(
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
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.stats, required this.onPressed});
  final StudentGamification stats;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Color(0xFF0B8693)),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('تقدمك ومكافآتك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                    Text('المستوى ${stats.level}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0B8693))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('⭐ ${stats.xp} XP', style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text('💎 ${stats.gems}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text('🔥 ${stats.streak} يوم', style: const TextStyle(fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(value: stats.levelProgress / 100, minHeight: 9, color: Colors.amber, backgroundColor: const Color(0xFFDCE8F2)),
                ),
                const SizedBox(height: 5),
                Text('باقي ${stats.xpToNextLevel} XP للمستوى التالي • اضغط لعرض الإنجازات', style: const TextStyle(fontSize: 12, color: Color(0xFF49617C), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
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

class _HomeSectionCarousel extends StatelessWidget {
  const _HomeSectionCarousel({
    required this.controller,
    required this.activePage,
    required this.onPageChanged,
    required this.onSectionPressed,
  });

  final PageController controller;
  final int activePage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onSectionPressed;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      child: PageView.builder(
        controller: controller,
        itemCount: _homeSections.length,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        onPageChanged: onPageChanged,
        itemBuilder: (context, index) {
          final section = _homeSections[index];
          return _SectionCard(
            section: section,
            onPressed: () => onSectionPressed(index),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.onPressed,
  });

  final _HomeSection section;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
        padding: const EdgeInsets.all(21),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: section.colors,
          ),
          boxShadow: [
            BoxShadow(
              color: section.colors.last.withAlpha(105),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Icon(section.icon, size: 48, color: Colors.white),
            ),
            const Spacer(),
            Text(
              section.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              section.subtitle,
              style: TextStyle(
                color: section.accent,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselIndicator extends StatelessWidget {
  const _CarouselIndicator({
    required this.count,
    required this.activeIndex,
  });

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) => AnimatedContainer(
          duration: 250.ms,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: index == activeIndex ? 27 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: index == activeIndex
                ? const Color(0xFF0B8693)
                : const Color(0xFFB3C8DE),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

class _AnimatedManaraBackground extends StatelessWidget {
  const _AnimatedManaraBackground({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
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
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.profile});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0B8693), Color(0xFF274E76)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: [
          const ManaraLogo(size: 64),
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
    );
  }
}
