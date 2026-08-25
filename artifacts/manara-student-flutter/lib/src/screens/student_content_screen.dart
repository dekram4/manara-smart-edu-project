// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:ui' show PointerDeviceKind;
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/academic_context.dart';
import '../models/student_content.dart';
import '../models/student_gamification.dart';
import '../models/student_profile.dart';
import '../services/student_auth_service.dart';
import '../services/student_content_service.dart';
import '../services/student_sound_service.dart';
import '../widgets/student_experience.dart';
import '../widgets/student_video_player.dart';

enum StudentContentModule { lesson, games }

class StudentContentScreen extends StatefulWidget {
  const StudentContentScreen({
    required this.profile,
    required this.authService,
    required this.initialModule,
    this.academicContext,
    this.apiBaseUrl = '',
    super.key,
  });

  final StudentProfile profile;
  final StudentAuthService authService;
  final StudentContentModule initialModule;
  final AcademicContext? academicContext;
  final String apiBaseUrl;

  @override
  State<StudentContentScreen> createState() => _StudentContentScreenState();
}

class _StudentContentScreenState extends State<StudentContentScreen>
    with SingleTickerProviderStateMixin {
  late final StudentContentService _contentService;
  late StudentContentModule _activeModule;
  List<LessonContent> _lessons = const [];
  List<HtmlGame> _apiGames = const [];
  LessonContent? _selectedLesson;
  late StudentGamification _gamification;
  bool _loading = true;
  String? _error;
  late final ConfettiController _rewardController;

  @override
  void initState() {
    super.initState();
    _contentService = StudentContentService(
      widget.authService.client,
      baseUrl: widget.apiBaseUrl,
    );
    _activeModule = widget.initialModule;
    _gamification = widget.profile.gamification;
    _rewardController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _loadContent();
  }

  @override
  void dispose() {
    _rewardController.dispose();
    super.dispose();
  }

  void _applyGamification(StudentGamification stats) {
    final earnedNewReward =
        stats.xp > _gamification.xp || stats.gems > _gamification.gems;
    setState(() => _gamification = stats);
    if (earnedNewReward &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      _rewardController.play();
    }
  }

  Future<void> _loadContent() async {
    List<LessonContent> lessons = const [];
    String? lessonError;
    try {
      lessons = await _contentService.fetchLessons(
        widget.profile,
        academicContext: widget.academicContext,
      );
    } catch (error) {
      lessonError = 'تعذر تحميل الدروس: $error';
    }

    List<HtmlGame> apiGames = const [];
    try {
      // The API catalog is intentionally independent from lesson_configs so
      // the games portal still works when the lesson query is unavailable.
      apiGames = await _contentService.fetchGameCatalog();
    } catch (_) {
      // Supabase lesson games remain available if the optional API catalog
      // is unavailable.
    }

    var gamification = _gamification;
    try {
      gamification = await _contentService.fetchGamification(widget.profile);
    } catch (_) {
      // The profile snapshot keeps content usable when progress is unavailable.
    }

    if (!mounted) return;
    setState(() {
      _lessons = lessons;
      _apiGames = apiGames;
      _selectedLesson = lessons.isEmpty ? null : lessons.first;
      _gamification = gamification;
      _loading = false;
      _error = lessonError;
    });
  }

  Future<void> _retryContent() async {
    if (!mounted) return;
    setState(() => _loading = true);
    await _loadContent();
  }

  bool get _hasGameContent {
    if (_apiGames.isNotEmpty) return true;
    return _lessons.any((lesson) => lesson.games.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F9),
      appBar: AppBar(
        title: Text(_moduleTitle(_activeModule)),
        actions: const [StudentSoundToggle()],
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'إغلاق',
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _ModuleSwitcher(
                  activeModule: _activeModule,
                  onChanged: (module) {
                    StudentSoundService.instance.play(StudentSoundCue.navigation);
                    setState(() => _activeModule = module);
                  },
                ),
                Expanded(child: StudentEntrance(child: _buildBody())),
              ],
            ),
          ),
          StudentCelebration(controller: _rewardController),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0B8693)));
    }
    if (_error != null &&
        (_activeModule == StudentContentModule.lesson ||
            (_activeModule == StudentContentModule.games &&
                !_hasGameContent))) {
      return _StateCard(
        icon: Icons.cloud_off_rounded,
        title: 'تعذر تحميل المحتوى',
        message: _error!,
        actionLabel: 'إعادة المحاولة',
        onAction: _retryContent,
      );
    }

    switch (_activeModule) {
      case StudentContentModule.lesson:
        return _LessonModule(
          lessons: _lessons,
          selectedLesson: _selectedLesson,
          apiBaseUrl: widget.apiBaseUrl,
          profile: widget.profile,
          gamification: _gamification,
          contentService: _contentService,
          onGamificationChanged: _applyGamification,
          onLessonChanged: (lesson) => setState(() => _selectedLesson = lesson),
        );
      case StudentContentModule.games:
        return _GamesModule(
          games: _gamesFromLessons,
          apiBaseUrl: widget.apiBaseUrl,
          profile: widget.profile,
          gamification: _gamification,
          contentService: _contentService,
          onGamificationChanged: _applyGamification,
        );
    }
  }

  List<HtmlGame> get _gamesFromLessons {
    final games = <HtmlGame>[];
    final seen = <String>{};
    for (final lesson in _lessons) {
      for (final game in lesson.games) {
        if (seen.add(game.url)) games.add(game);
      }
    }
    for (final game in _apiGames) {
      if (seen.add(game.url)) games.add(game);
    }
    return games;
  }
}

String _moduleTitle(StudentContentModule module) {
  switch (module) {
    case StudentContentModule.lesson:
      return 'شرح الدرس';
    case StudentContentModule.games:
      return 'الترفيه والألعاب';
  }
}

class _ModuleSwitcher extends StatelessWidget {
  const _ModuleSwitcher({required this.activeModule, required this.onChanged});

  final StudentContentModule activeModule;
  final ValueChanged<StudentContentModule> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      (StudentContentModule.lesson, Icons.play_lesson_rounded, 'الدرس'),
      (StudentContentModule.games, Icons.sports_esports_rounded, 'الألعاب'),
    ];
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = activeModule == item.$1;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => onChanged(item.$1),
            avatar: Icon(item.$2, size: 19, color: selected ? Colors.white : const Color(0xFF0B8693)),
            label: Text(item.$3),
            labelStyle: TextStyle(
              color: selected ? Colors.white : const Color(0xFF274E76),
              fontWeight: FontWeight.w900,
            ),
            selectedColor: const Color(0xFF0B8693),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFD7E3EF)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          );
        },
      ),
    );
  }
}

class _LessonModule extends StatelessWidget {
  const _LessonModule({
    required this.lessons,
    required this.selectedLesson,
    required this.onLessonChanged,
    required this.apiBaseUrl,
    required this.profile,
    required this.gamification,
    required this.contentService,
    required this.onGamificationChanged,
  });

  final List<LessonContent> lessons;
  final LessonContent? selectedLesson;
  final ValueChanged<LessonContent> onLessonChanged;
  final String apiBaseUrl;
  final StudentProfile profile;
  final StudentGamification gamification;
  final StudentContentService contentService;
  final ValueChanged<StudentGamification> onGamificationChanged;

  @override
  Widget build(BuildContext context) {
    if (lessons.isEmpty) {
      return const _StateCard(
        icon: Icons.video_library_outlined,
        title: 'لا توجد فيديوهات بعد',
        message: 'سيظهر هنا محتوى المعلم والمشرف المطابق لمسارك الأكاديمي.',
      );
    }

    final lesson = selectedLesson ?? lessons.first;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Text(
          'فيديو شرح الدرس',
          style: const TextStyle(color: Color(0xFF0E1B2A), fontSize: 24, fontWeight: FontWeight.w900),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08),
        const SizedBox(height: 4),
        Text(
          lesson.scopeLabel.isEmpty ? 'فيديوهات الشرح الخاصة بك' : lesson.scopeLabel,
          style: const TextStyle(color: Color(0xFF5680AC), fontWeight: FontWeight.w700),
        ),
        if (lessons.length > 1) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 45,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: lessons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = lessons[index];
                return ChoiceChip(
                  selected: item.id == lesson.id,
                  onSelected: (_) => onLessonChanged(item),
                  label: Text(item.lessonName.isNotEmpty ? item.lessonName : item.unit),
                  selectedColor: const Color(0xFFBFEFED),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (lesson.videos.isEmpty)
          const _StateCard(
            icon: Icons.video_call_outlined,
            title: 'لم تتم إضافة فيديو',
            message: 'يمكن للمعلم أو المشرف إضافة رابط فيديو لهذا الدرس.',
          )
        else
           _VideoCarousel(
             videos: lesson.videos,
             apiBaseUrl: apiBaseUrl,
             profile: profile,
              gamification: gamification,
             contentService: contentService,
              onGamificationChanged: onGamificationChanged,
           ),
      ],
    );
  }
}

class _GamesModule extends StatelessWidget {
  const _GamesModule({
    required this.games,
    required this.apiBaseUrl,
    required this.profile,
    required this.gamification,
    required this.contentService,
    required this.onGamificationChanged,
  });

  final List<HtmlGame> games;
  final String apiBaseUrl;
  final StudentProfile profile;
  final StudentGamification gamification;
  final StudentContentService contentService;
  final ValueChanged<StudentGamification> onGamificationChanged;

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) {
      return const _StateCard(
        icon: Icons.sports_esports_rounded,
        title: 'لا توجد ألعاب متاحة',
        message: 'ستظهر هنا الألعاب التعليمية المرتبطة بدروس مسارك الأكاديمي.',
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        const Text(
          'الألعاب التعليمية',
          style: TextStyle(
            color: Color(0xFF0E1B2A),
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08),
        const SizedBox(height: 4),
        const Text(
          'تعلّم والعب داخل منارة المعرفة',
          style: TextStyle(
            color: Color(0xFF5680AC),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _GamificationSummary(stats: gamification),
        const SizedBox(height: 16),
        ...games.map(
          (game) {
            final locked = gamification.level < game.requiredLevel;
            final completed = gamification.completedActivities
                .contains('game:${game.id}');
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _GameCard(
                game: game,
                locked: locked,
                completed: completed,
                onPressed: () {
                  if (locked) {
                    StudentSoundService.instance.play(StudentSoundCue.warning);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'هذه اللعبة تُفتح عند الوصول إلى المستوى ${game.requiredLevel}. مستواك الحالي: ${gamification.level}',
                        ),
                      ),
                    );
                    return;
                  }
                  StudentSoundService.instance.play(StudentSoundCue.navigation);
                  Navigator.of(context).push(
                    StudentPageRoute<void>(
                      builder: (_) => _GamePlayerScreen(
                        game: game,
                        apiBaseUrl: apiBaseUrl,
                        initiallyCompleted: completed,
                        onCompleted: () async {
                          try {
                            final reward = await contentService.rewardActivity(
                              profile: profile,
                              activityType: 'game',
                              activityId: game.id,
                            );
                            onGamificationChanged(reward.snapshot);
                            StudentSoundService.instance.play(
                              reward.alreadyRewarded
                                  ? StudentSoundCue.navigation
                                  : StudentSoundCue.gameReward,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(reward.alreadyRewarded
                                    ? 'أنهيت اللعبة وحصلت على المكافأة مسبقًا.'
                                    : 'أحسنت! +${reward.xp} XP و +${reward.gems} جواهر'),
                              ));
                            }
                            return true;
                          } catch (_) {
                            StudentSoundService.instance.play(StudentSoundCue.warning);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تعذر حفظ إتمام اللعبة. حاول مرة أخرى.'),
                                ),
                              );
                            }
                            return false;
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _GamificationSummary extends StatelessWidget {
  const _GamificationSummary({required this.stats});

  final StudentGamification stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF6D28D9)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'المستوى ${stats.level}',
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('⭐ ${stats.xp} XP', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              Text('💎 ${stats.gems} جواهر', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              Text('🔥 ${stats.streak} يوم', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: stats.levelProgress / 100,
              minHeight: 9,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFDE68A)),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${stats.xpToNextLevel} XP للوصول إلى المستوى التالي',
            textAlign: TextAlign.right,
            style: const TextStyle(color: Color(0xFFE9D5FF), fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.game,
    required this.locked,
    required this.completed,
    required this.onPressed,
  });

  final HtmlGame game;
  final bool locked;
  final bool completed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return StudentPressScale(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: locked
                  ? const [Color(0xFF4B5563), Color(0xFF6B7280)]
                  : const [Color(0xFF4B267F), Color(0xFF8B5CF6)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x458B5CF6),
                blurRadius: 18,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            children: [
               Icon(
                 locked ? Icons.lock_rounded : completed ? Icons.verified_rounded : Icons.sports_esports_rounded,
                 color: locked ? const Color(0xFFFDE68A) : const Color(0xFFE9D5FF),
                size: 48,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      game.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      game.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFFE9D5FF),
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
               Icon(
                 locked
                     ? Icons.lock_rounded
                     : completed
                         ? Icons.verified_rounded
                         : Icons.play_circle_fill_rounded,
                 color: Colors.white,
                size: 32,
              ),
               const SizedBox(width: 6),
               Text(
                 locked
                     ? 'المستوى ${game.requiredLevel}'
                     : completed
                         ? 'اكتملت المكافأة'
                         : '+15 XP • 3 جواهر',
                 style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
               ),
            ],
          ),
        ),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms).slideX(begin: 0.08);
  }
}

class _GamePlayerScreen extends StatefulWidget {
  const _GamePlayerScreen({
    required this.game,
    required this.apiBaseUrl,
    required this.initiallyCompleted,
    required this.onCompleted,
  });

  final HtmlGame game;
  final String apiBaseUrl;
  final bool initiallyCompleted;
  final Future<bool> Function() onCompleted;

  @override
  State<_GamePlayerScreen> createState() => _GamePlayerScreenState();
}

class _GamePlayerScreenState extends State<_GamePlayerScreen> {
  late final String _viewId;
  html.IFrameElement? _frame;
  String? _error;
  bool _loading = true;
  late bool _completed;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _completed = widget.initiallyCompleted;
    _viewId = 'manara-game-${widget.game.id}-${identityHashCode(this)}';
    _registerGameFrame();
  }

  String get _url {
    final raw = widget.game.url.trim();
    if (!raw.startsWith('/')) return raw;
    final base = widget.apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    return base.isEmpty ? raw : '$base$raw';
  }

  bool get _isRelativeApiGame =>
      RegExp(r'^/api/game-embed/[a-zA-Z0-9-]+/index\.html(?:[?#]|$)')
          .hasMatch(_url);

  void _registerGameFrame() {
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int _) {
      final frame = html.IFrameElement()
        ..src = _url
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow =
            'autoplay; fullscreen; gamepad; clipboard-read; clipboard-write'
        ..allowFullscreen = true;
      frame.onLoad.listen((_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = null;
        });
      });
      frame.onError.listen((_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'تعذر تحميل محتوى اللعبة من المصدر.';
        });
      });
      _frame = frame;
      return frame;
    });
  }

  void _reload() {
    setState(() {
      _error = null;
      _loading = true;
    });
    final uri = Uri.tryParse(_url);
    if (uri == null) return;
    _frame?.src = uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        '_reload': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    ).toString();
  }

  Future<void> _completeGame() async {
    if (_completed || _saving || _loading) return;
    setState(() => _saving = true);
    final saved = await widget.onCompleted();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _completed = saved;
    });
  }

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(_url);
    final validUrl = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty || _isRelativeApiGame;

    return Scaffold(
      backgroundColor: const Color(0xFF160C2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF160C2D),
        foregroundColor: Colors.white,
        title: Text(widget.game.title),
        actions: [
          IconButton(
            onPressed: validUrl ? _reload : null,
            tooltip: 'إعادة تحميل اللعبة',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: !validUrl
          ? _StateCard(
              icon: Icons.link_off_rounded,
              title: 'رابط اللعبة غير صالح',
              message: 'لا يمكن فتح هذه اللعبة حاليًا.',
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: HtmlElementView(viewType: _viewId),
                ),
                if (_loading)
                  const ColoredBox(
                    color: Color(0xFF160C2D),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE9D5FF),
                      ),
                    ),
                  ),
                if (_error != null)
                  ColoredBox(
                    color: const Color(0xF2160C2D),
                    child: Center(
                      child: _StateCard(
                        icon: Icons.error_outline_rounded,
                        title: 'تعذر تشغيل اللعبة',
                        message: _error!,
                        actionLabel: 'إعادة المحاولة',
                        onAction: _reload,
                      ),
                    ),
                  ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FilledButton.icon(
                    onPressed: _loading || _saving || _completed ? null : _completeGame,
                    icon: Icon(
                      _completed
                          ? Icons.verified_rounded
                          : Icons.check_circle_rounded,
                    ),
                    label: Text(
                      _completed
                          ? 'أنهيت اللعبة وحصلت على المكافأة مسبقًا'
                          : _saving
                              ? 'جارٍ حفظ إتمام اللعبة...'
                              : 'أنهيت اللعبة — +15 XP و3 جواهر',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _completed
                          ? Colors.grey.shade500
                          : const Color(0xFF6D28D9),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _VideoCarousel extends StatefulWidget {
  const _VideoCarousel({
    required this.videos,
    required this.apiBaseUrl,
    required this.profile,
    required this.gamification,
    required this.contentService,
    required this.onGamificationChanged,
  });

  final List<LessonVideo> videos;
  final String apiBaseUrl;
  final StudentProfile profile;
  final StudentGamification gamification;
  final StudentContentService contentService;
  final ValueChanged<StudentGamification> onGamificationChanged;

  @override
  State<_VideoCarousel> createState() => _VideoCarouselState();
}

class _VideoCarouselState extends State<_VideoCarousel> {
  final _controller = PageController(viewportFraction: 0.88);
  int _activeIndex = 0;

  bool _isVideoCompleted(LessonVideo video) => widget
      .gamification.completedActivities
      .contains('lesson_video:${video.id}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 285,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
              },
            ),
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.videos.length,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              onPageChanged: (index) => setState(() => _activeIndex = index),
              itemBuilder: (context, index) {
                final video = widget.videos[index];
                final completed = _isVideoCompleted(video);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: _VideoCard(
                    video: video,
                    completed: completed,
                    onPressed: () {
                      StudentSoundService.instance.play(StudentSoundCue.navigation);
                      Navigator.of(context).push(
                        StudentPageRoute<void>(
                          builder: (_) => _LessonPlayerScreen(
                            video: video,
                            apiBaseUrl: widget.apiBaseUrl,
                            initiallyCompleted: completed,
                            onCompleted: () => _rewardVideo(video),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.videos.length,
            (index) => AnimatedContainer(
              duration: 220.ms,
              width: index == _activeIndex ? 26 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: index == _activeIndex ? const Color(0xFF0B8693) : const Color(0xFFB3C8DE),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _rewardVideo(LessonVideo video) async {
    try {
      final lessonReward = await widget.contentService.rewardActivity(
        profile: widget.profile,
        activityType: 'lesson_video',
        activityId: video.id,
      );
      if (!mounted) return false;
      StudentSoundService.instance.play(
        lessonReward.alreadyRewarded
            ? StudentSoundCue.navigation
            : StudentSoundCue.success,
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          lessonReward.alreadyRewarded
              ? 'أنهيت هذا الفيديو وحصلت على مكافأته مسبقًا.'
              : 'أحسنت! +${lessonReward.xp} XP و +${lessonReward.gems} جواهر لإتمام هذا الفيديو.',
        ),
      ));
      widget.onGamificationChanged(lessonReward.snapshot);
      return true;
    } catch (_) {
      StudentSoundService.instance.play(StudentSoundCue.warning);
      // Playback remains usable if the network is temporarily unavailable.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ إتمام الدرس. حاول مرة أخرى.')),
        );
      }
      return false;
    }
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.video,
    required this.completed,
    required this.onPressed,
  });

  final LessonVideo video;
  final bool completed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return StudentPressScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
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
                color: Color(0x450B8693),
                blurRadius: 20,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: dynamicPaddingAlignment(context),
                children: [
                  Icon(
                    completed
                        ? Icons.verified_rounded
                        : Icons.play_circle_fill_rounded,
                    color: const Color(0xFFBFFBFA),
                    size: 38,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(38),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      video.sourceType == VideoSourceType.mp4 ? 'MP4 / AI' : 'يوتيوب',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                video.description ?? 'اضغط للمشاهدة الفورية داخل التطبيق',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFBFFBFA), height: 1.4, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: completed ? null : onPressed,
                icon: Icon(
                  completed
                      ? Icons.verified_rounded
                      : Icons.play_arrow_rounded,
                ),
                label: Text(completed ? 'تم إتمام الفيديو' : 'شاهد الآن'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0B8693),
                  disabledBackgroundColor: Colors.grey.shade500,
                  disabledForegroundColor: Colors.white,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1);
  }

  MainAxisAlignment dynamicPaddingAlignment(BuildContext context) =>
      MainAxisAlignment.spaceBetween;
}

class _LessonPlayerScreen extends StatefulWidget {
  const _LessonPlayerScreen({
    required this.video,
    required this.apiBaseUrl,
    this.initiallyCompleted = false,
    this.onCompleted,
  });

  final LessonVideo video;
  final String apiBaseUrl;
  final bool initiallyCompleted;
  final Future<bool> Function()? onCompleted;

  @override
  State<_LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<_LessonPlayerScreen> {
  late bool _completed;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _completed = widget.initiallyCompleted;
  }

  Future<void> _completeLesson() async {
    if (_completed || _saving || widget.onCompleted == null) return;
    setState(() => _saving = true);
    final saved = await widget.onCompleted!();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _completed = saved;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071425),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071425),
        foregroundColor: Colors.white,
        title: Text(widget.video.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: StudentVideoPlayer(
                  video: widget.video,
                  apiBaseUrl: widget.apiBaseUrl,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.onCompleted == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _completed || _saving ? null : _completeLesson,
                  icon: Icon(
                    _completed
                        ? Icons.verified_rounded
                        : Icons.check_circle_rounded,
                  ),
                  label: Text(
                    _completed
                        ? 'أنهيت الدرس وحصلت على المكافأة مسبقًا'
                        : _saving
                            ? 'جارٍ حفظ إتمام الدرس...'
                            : 'أنهيت مشاهدة الدرس',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: _completed
                        ? Colors.grey.shade500
                        : const Color(0xFF0B8693),
                    disabledBackgroundColor: Colors.grey.shade500,
                    disabledForegroundColor: Colors.white,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
    );
  }
}

class UniversalWebVideoScreen extends StatelessWidget {
  const UniversalWebVideoScreen({
    required this.video,
    this.apiBaseUrl = '',
    super.key,
  });

  final LessonVideo video;
  final String apiBaseUrl;

  String _extractYouTubeId(String url) {
    final clean = url.trim();
    if (clean.contains('/embed/')) {
      final parts = clean.split('/embed/');
      if (parts.length > 1) {
        return parts[1].split('?').first.split('&').first.split('/')[0];
      }
    }
    if (clean.contains('youtu.be/')) {
      final parts = clean.split('youtu.be/');
      if (parts.length > 1) {
        return parts[1].split('?').first.split('&').first.split('/')[0];
      }
    }
    final uri = Uri.tryParse(clean);
    if (uri != null && uri.queryParameters.containsKey('v')) {
      return uri.queryParameters['v'] ?? '';
    }
    return '';
  }

  String _getFinalUrl(String raw) {
    final clean = raw.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }
    if (clean.startsWith('/')) {
      final base = apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
      return base.isEmpty ? clean : '$base$clean';
    }
    if (clean.startsWith('videos/')) {
      return 'https://kpqlotlyniomssnzcgqn.supabase.co/storage/v1/object/public/lesson-videos/$clean';
    }
    return clean;
  }

  @override
  Widget build(BuildContext context) {
    final targetUrl = _getFinalUrl(video.url);
    if (video.sourceType == VideoSourceType.mp4) {
      return Scaffold(
        backgroundColor: const Color(0xFF071425),
        appBar: AppBar(
          backgroundColor: const Color(0xFF071425),
          foregroundColor: Colors.white,
          title: Text(video.title),
        ),
        body: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: StudentVideoPlayer(
              video: video,
              apiBaseUrl: apiBaseUrl,
            ),
          ),
        ),
      );
    }
    final ytId = _extractYouTubeId(targetUrl);
    final isYouTube = ytId.isNotEmpty && video.sourceType != VideoSourceType.mp4;
    final viewId = 'player-${DateTime.now().microsecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
      final iframe = html.IFrameElement()
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'autoplay; fullscreen; encrypted-media; picture-in-picture'
        ..allowFullscreen = true;

      if (isYouTube) {
        iframe.src = 'https://www.youtube-nocookie.com/embed/$ytId?autoplay=1&rel=0&playsinline=1';
      } else {
        iframe.srcdoc = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    * { margin:0; padding:0; box-sizing:border-box; background:#071425; font-family:sans-serif; }
    html, body { width:100%; height:100%; display:flex; flex-direction:column; align-items:center; justify-content:center; }
    video { width:100%; height:100%; object-fit:contain; }
  </style>
</head>
<body>
  <video id="v" controls autoplay muted playsinline preload="auto">
    <source src="$targetUrl" type="video/mp4">
  </video>
  <script>
    const v = document.getElementById('v');
    v.play().catch(function() {
      v.controls = true;
    });
    // إلغاء الكتم عند أول نقرة
    window.addEventListener('click', function() {
      v.muted = false;
    }, { once: true });
  </script>
</body>
</html>
''';
      }
      return iframe;
    });

    return Scaffold(
      backgroundColor: const Color(0xFF071425),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071425),
        foregroundColor: Colors.white,
        title: Text(video.title),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: HtmlElementView(viewType: viewId),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(225),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF0B8693), size: 54),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF0E1B2A),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF5680AC), height: 1.5, fontWeight: FontWeight.w700),
              ),
              if (onAction != null) ...[
                const SizedBox(height: 14),
                FilledButton(onPressed: onAction, child: Text(actionLabel ?? 'متابعة')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
