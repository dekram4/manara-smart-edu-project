import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/student_profile.dart';
import '../services/student_auth_service.dart';
import '../widgets/manara_logo.dart';
import 'login_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({
    required this.profile,
    required this.authService,
    super.key,
  });

  final StudentProfile profile;
  final StudentAuthService authService;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen>
    with SingleTickerProviderStateMixin {
  final _audioPlayer = AudioPlayer();
  final _pageController = PageController(viewportFraction: 0.86);
  late final AnimationController _ambientController;
  int _activePage = 0;
  bool _showGamePreview = false;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playWelcome());
  }

  Future<void> _playWelcome() async {
    try {
      await _audioPlayer.play(
        AssetSource('audio/manara-arabic-student-welcome.mp3'),
      );
    } catch (_) {
      // Audio is optional; the home screen remains usable if a platform blocks it.
    }
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
    } catch (_) {
      // Custom student records do not always create an Auth session.
    }
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(
          authService: widget.authService,
          initializationError: null,
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.profile.isStudent) {
      return const _StudentOnlyGuard();
    }

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
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
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
                    padding: EdgeInsets.symmetric(horizontal: 18),
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
                      onPageChanged: (page) => setState(() {
                        _activePage = page;
                        if (page != 2) _showGamePreview = false;
                      }),
                      onSectionPressed: (index) {
                        setState(() {
                          _activePage = index;
                          _showGamePreview = index == 2;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              index == 2
                                  ? 'مساحة الألعاب التفاعلية جاهزة لك!'
                                  : 'بوابة ${_homeSections[index].title} ستتوفر مع محتوى الدرس.',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CarouselIndicator(
                    count: _homeSections.length,
                    activeIndex: _activePage,
                  ),
                  if (_showGamePreview) ...[
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: const _InteractiveGamePreview()
                          .animate()
                          .fadeIn(duration: 350.ms)
                          .slideY(begin: 0.1),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(235),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFD7E3EF)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified_user_rounded, color: Color(0xFF0B8693)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'تم التحقق من دور الحساب: طالب. هذه البوابة لا تسمح بدخول الأدوار الأخرى.',
                              style: TextStyle(
                                color: Color(0xFF274E76),
                                fontWeight: FontWeight.w700,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
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

const _homeSections = <_HomeSection>[
  _HomeSection(
    title: 'سينما الشرح',
    subtitle: 'شرح الدرس الممتع',
    description: 'شاهد الدرس بطريقة سهلة ومليئة بالحماس.',
    icon: Icons.play_lesson_rounded,
    colors: [Color(0xFF9A5B09), Color(0xFFF59E0B)],
    accent: Color(0xFFFFE08A),
  ),
  _HomeSection(
    title: 'إنجازاتي',
    subtitle: 'أتابع تقدمي',
    description: 'شاهد نجومك وجواهرك وخطواتك القادمة.',
    icon: Icons.emoji_events_rounded,
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
    title: 'المعلم الافتراضي',
    subtitle: 'صديقك الذكي',
    description: 'اسأل واستكشف أفكارًا تساعدك في رحلتك.',
    icon: Icons.smart_toy_rounded,
    colors: [Color(0xFF274E76), Color(0xFF1394D2)],
    accent: Color(0xFFBAE6FD),
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
    return PageView.builder(
      controller: controller,
      itemCount: _homeSections.length,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      onPageChanged: onPageChanged,
      itemBuilder: (context, index) {
        final section = _homeSections[index];
        return AnimatedBuilder(
          animation: controller,
          child: _SectionCard(
            section: section,
            onPressed: () => onSectionPressed(index),
          ),
          builder: (context, child) {
            var page = activePage.toDouble();
            if (controller.hasClients && controller.page != null) {
              page = controller.page!;
            }
            final distance = (page - index).abs().clamp(0.0, 1.0).toDouble();
            final scale = 1.0 - (distance * 0.08);
            final opacity = 1.0 - (distance * 0.18);
            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            );
          },
        );
      },
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
    final card = Container(
      margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: section.colors,
        ),
        border: Border.all(color: Colors.white.withAlpha(90)),
        boxShadow: [
          BoxShadow(
            color: section.colors.last.withAlpha(105),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -35,
            left: -30,
            child: Container(
              width: 135,
              height: 135,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: section.accent.withAlpha(35),
              ),
            ),
          ),
          Positioned(
            bottom: -45,
            right: -25,
            child: Container(
              width: 155,
              height: 155,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: section.accent.withAlpha(40), width: 20),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(45),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'اسحب للاستكشاف',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.touch_app_rounded,
                    color: section.accent,
                    size: 24,
                  ),
                ],
              ),
              const Spacer(),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(42),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withAlpha(105), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: section.accent.withAlpha(75),
                        blurRadius: 18,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Icon(section.icon, size: 49, color: Colors.white),
                ),
              ),
              const SizedBox(height: 17),
              Text(
                section.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                section.subtitle,
                style: TextStyle(
                  color: section.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                section.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return (onPressed == null ? card : GestureDetector(onTap: onPressed, child: card))
        .animate()
        .fadeIn(duration: 450.ms)
        .slideX(begin: 0.12, duration: 500.ms)
        .shimmer(
          delay: 650.ms,
          duration: 1500.ms,
          color: section.accent.withAlpha(55),
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
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final value = animation.value;
          final topColor = Color.lerp(
            const Color(0xFFF3F8F9),
            const Color(0xFFE4F8F6),
            value,
          )!;
          final bottomColor = Color.lerp(
            const Color(0xFFEAF1FA),
            const Color(0xFFF8F2FF),
            value,
          )!;
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [topColor, bottomColor],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -80 + (value * 28),
                left: -55 + (value * 65),
                child: _GlowOrb(
                  size: 220,
                  color: const Color(0xFF63D9DA).withAlpha(32),
                ),
              ),
              Positioned(
                top: 300 - (value * 38),
                right: -75 + (value * 45),
                child: _GlowOrb(
                  size: 245,
                  color: const Color(0xFF8B5CF6).withAlpha(23),
                ),
              ),
              Positioned(
                bottom: -85 + (value * 40),
                left: 80 - (value * 55),
                child: _GlowOrb(
                  size: 200,
                  color: const Color(0xFFF59E0B).withAlpha(20),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: size * 0.42,
            spreadRadius: size * 0.08,
          ),
        ],
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x330B8693),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const ManaraLogo(size: 72),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أهلًا بك في منارة المعرفة',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (profile.grade != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'الصف: ${profile.grade}',
                    style: const TextStyle(
                      color: Color(0xFFCDF6F5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveGamePreview extends StatelessWidget {
  const _InteractiveGamePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF081426),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF63D9DA).withAlpha(90)),
      ),
      child: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri('about:blank')),
        initialSettings: InAppWebViewSettings(
          transparentBackground: true,
          javaScriptEnabled: false,
        ),
        onWebViewCreated: (controller) {
          controller.loadData(
            data: '''
              <html dir="rtl"><body style="margin:0;background:#081426;color:#cdf6f5;font-family:Arial;text-align:center;padding:45px 18px">
              <h2>مساحة الألعاب التفاعلية</h2><p>سيتم تحميل الألعاب المرتبطة بالدرس هنا.</p>
              </body></html>
            ''',
          );
        },
      ),
    );
  }
}

class _StudentOnlyGuard extends StatelessWidget {
  const _StudentOnlyGuard();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            studentOnlyMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF9F1239),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}