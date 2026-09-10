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
import '../widgets/video_thumbnail_card.dart';
import '../widgets/portal_watermark.dart';
import '../widgets/student_experience.dart';
import '../widgets/student_video_player.dart';
import '../widgets/student_web_embed.dart';

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
    final previous = _gamification;
    final earnedNewReward = stats.xp > previous.xp || stats.gems > previous.gems;
    setState(() => _gamification = stats);
    if (!earnedNewReward) return;
    if (!(MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      _rewardController.play();
    }
    if (stats.level > previous.level) {
      StudentSoundService.instance.playLevelUp();
    } else {
      StudentSoundService.instance.playReward();
    }
    StudentSoundService.instance.playEncouragementArabic();
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
      backgroundColor: Colors.transparent,
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
          // The lesson and the games share this screen, so the background
          // follows whichever module is actually open.
          PortalWatermark(
            asset: _activeModule == StudentContentModule.games
                ? PortalBackgrounds.games
                : PortalBackgrounds.lesson,
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 0),
                  child: StudentScreenHero(
                    title: _moduleTitle(_activeModule),
                    subtitle: _activeModule == StudentContentModule.lesson
                        ? 'استكشف دروسك خطوة بخطوة واحتفل بكل إنجاز.'
                        : 'العب وتعلّم واكتشف تحديات تعليمية جديدة.',
                    icon: _activeModule == StudentContentModule.lesson
                        ? Icons.play_lesson_rounded
                        : Icons.sports_esports_rounded,
                    colors: _activeModule == StudentContentModule.lesson
                        ? const [Color(0xFF9A5B09), Color(0xFFF59E0B)]
                        : const [Color(0xFF4B267F), Color(0xFF8B5CF6)],
                  ),
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
      return const Center(
        child: StudentRiveLoading(label: 'جارٍ تحميل محتوى الطالب'),
      );
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
    return games
        .asMap()
        .entries
        .map(
          (entry) => HtmlGame(
            id: entry.value.id,
            url: entry.value.url,
            title: entry.value.title,
            subtitle: entry.value.subtitle,
            requiredLevel: entry.key + 1,
          ),
        )
        .toList();
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
          style: const TextStyle(
            color: Color(0xFF0E1B2A),
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08),
        const SizedBox(height: 4),
        Text(
          lesson.scopeLabel.isEmpty
              ? 'فيديوهات الشرح الخاصة بك'
              : lesson.scopeLabel,
          style: const TextStyle(
            color: Color(0xFF5680AC),
            fontWeight: FontWeight.w700,
          ),
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
                  label: Text(
                    item.lessonName.isNotEmpty ? item.lessonName : item.unit,
                  ),
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
            lesson: lesson,
            videos: lesson.videos,
            apiBaseUrl: apiBaseUrl,
            profile: profile,
            gamification: gamification,
            contentService: contentService,
            onGamificationChanged: onGamificationChanged,
          ),
        const SizedBox(height: 16),
        _LessonCompletionButton(
          lesson: lesson,
          profile: profile,
          gamification: gamification,
          contentService: contentService,
          onGamificationChanged: onGamificationChanged,
        ),
      ],
    );
  }
}

class _LessonCompletionButton extends StatefulWidget {
  const _LessonCompletionButton({
    required this.lesson,
    required this.profile,
    required this.gamification,
    required this.contentService,
    required this.onGamificationChanged,
  });

  final LessonContent lesson;
  final StudentProfile profile;
  final StudentGamification gamification;
  final StudentContentService contentService;
  final ValueChanged<StudentGamification> onGamificationChanged;

  @override
  State<_LessonCompletionButton> createState() =>
      _LessonCompletionButtonState();
}

class _LessonCompletionButtonState extends State<_LessonCompletionButton> {
  bool _saving = false;

  bool get _completed => widget.gamification.completedActivities.contains(
    'lesson:${widget.lesson.id}',
  );

  Future<void> _completeLesson() async {
    if (_completed || _saving) return;
    setState(() => _saving = true);
    try {
      final reward = await widget.contentService.rewardActivity(
        profile: widget.profile,
        activityType: 'lesson',
        activityId: widget.lesson.id,
      );
      if (!mounted) return;
      widget.onGamificationChanged(reward.snapshot);
      if (reward.alreadyRewarded) {
        StudentSoundService.instance.play(StudentSoundCue.navigation);
      } else {
        // The applause chain marks actually finishing the lesson; a
        // repeat tap that earns nothing gets the quiet cue instead.
        StudentSoundService.instance.playApplause();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reward.alreadyRewarded
                ? 'حصلت على مكافأة هذا الدرس مسبقًا.'
                : 'أحسنت! +5 جواهر'
                      '${reward.xp > 0 ? ' و +${reward.xp} XP' : ''}',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ إتمام الدرس. حاول مرة أخرى.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_completed && !_saving;
    // Gold while the reward is still to be claimed, emerald once it has
    // been — the colour carries the state, so the label does not have to
    // work alone.
    final gradient = _completed
        ? const [Color(0xFF0E9F6E), Color(0xFF067A54)]
        : const [Color(0xFFFFC542), Color(0xFFF08C1E)];
    final ledge = _completed ? const Color(0xFF04543A) : const Color(0xFFB4630C);

    return StudentPressScale(
      child: GestureDetector(
        onTap: enabled ? _completeLesson : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          // The darker ledge under the face gives the capsule its depth.
          padding: const EdgeInsets.only(bottom: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: ledge,
            boxShadow: [
              BoxShadow(
                color: ledge.withOpacity(0.42),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Container(
            height: 56,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: gradient,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.26),
                    border: Border.all(color: Colors.white.withOpacity(0.7)),
                  ),
                  child: Icon(
                    _completed
                        ? Icons.verified_rounded
                        : Icons.diamond_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _completed
                          ? 'تم استلام مكافأة هذا الدرس'
                          : _saving
                              ? 'جارٍ حفظ الإتمام...'
                              : 'أنهيت الدرس — احصل على 5 جواهر',
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: Color(0x55000000), blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
        ...games.map((game) {
          final locked = gamification.level < game.requiredLevel;
          final completed = gamification.completedActivities.contains(
            'game:${game.id}',
          );
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
                StudentSoundService.instance.playTap();
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  reward.alreadyRewarded
                                      ? 'أنهيت اللعبة وحصلت على المكافأة مسبقًا.'
                                      : 'أحسنت! +${reward.xp} XP و +${reward.gems} جواهر',
                                ),
                              ),
                            );
                          }
                          return true;
                        } catch (_) {
                          StudentSoundService.instance.play(
                            StudentSoundCue.warning,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تعذر حفظ إتمام اللعبة. حاول مرة أخرى.',
                                ),
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
        }),
      ],
    );
  }
}

class _GamificationSummary extends StatelessWidget {
  const _GamificationSummary({required this.stats});

  final StudentGamification stats;

  @override
  Widget build(BuildContext context) {
    return Student3DCard(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // A cartoon violet-to-magenta sweep with a bright rim and a
          // coloured glow, in place of the flat indigo block.
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFFA855F7), Color(0xFFEC4899)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.45), width: 1.6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(0.42),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'المستوى ${stats.level}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '⭐ ${stats.xp} XP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '💎 ${stats.gems} جواهر',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '🔥 ${stats.streak} يوم',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
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
              style: const TextStyle(
                color: Color(0xFFE9D5FF),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
            // Roomier padding and a three-stop cartoon sweep with a bright
            // rim; a locked card stays grey but keeps the same shape so the
            // two read as one family.
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: locked
                    ? const [Color(0xFF525C6B), Color(0xFF79839A)]
                    : const [
                        Color(0xFF6D28D9),
                        Color(0xFF8B5CF6),
                        Color(0xFF38BDF8),
                      ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(locked ? 0.28 : 0.5),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: (locked
                          ? const Color(0xFF525C6B)
                          : const Color(0xFF8B5CF6))
                      .withOpacity(0.42),
                  blurRadius: 20,
                  offset: const Offset(0, 11),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  locked
                      ? Icons.lock_rounded
                      : completed
                      ? Icons.verified_rounded
                      : Icons.sports_esports_rounded,
                  color: locked
                      ? const Color(0xFFFDE68A)
                      : const Color(0xFFE9D5FF),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
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
  String? _error;
  bool _loading = true;
  late bool _completed;
  bool _saving = false;
  var _reloadKey = 0;

  @override
  void initState() {
    super.initState();
    _completed = widget.initiallyCompleted;
  }

  String get _url {
    final raw = widget.game.url.trim();
    if (!raw.startsWith('/')) return raw;
    final base = widget.apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    return base.isEmpty ? raw : '$base$raw';
  }

  bool get _isRelativeApiGame => RegExp(
    r'^/api/game-embed/[a-zA-Z0-9-]+/index\.html(?:[?#]|$)',
  ).hasMatch(_url);

  void _reload() {
    setState(() {
      _error = null;
      _loading = true;
      _reloadKey++;
    });
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
    final validUrl =
        uri != null &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.host.isNotEmpty ||
        _isRelativeApiGame;

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
                  child: StudentWebEmbed(
                    key: ValueKey(_reloadKey),
                    url: _url,
                    allow:
                        'autoplay; fullscreen; gamepad; clipboard-read; clipboard-write',
                    onLoaded: () {
                      if (!mounted) return;
                      setState(() {
                        _loading = false;
                        _error = null;
                      });
                    },
                    onError: (message) {
                      if (!mounted) return;
                      setState(() {
                        _loading = false;
                        _error = message;
                      });
                    },
                  ),
                ),
                if (_loading)
                  const ColoredBox(
                    color: Color(0xFF160C2D),
                    child: Center(
                      child: StudentRiveLoading(
                        label: 'جارٍ تحميل اللعبة التعليمية',
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
                    onPressed: _loading || _saving || _completed
                        ? null
                        : _completeGame,
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
    required this.lesson,
    required this.videos,
    required this.apiBaseUrl,
    required this.profile,
    required this.gamification,
    required this.contentService,
    required this.onGamificationChanged,
  });

  final LessonContent lesson;
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Column(
      children: [
        // Sized for a 16:9 cover plus its two lines of text, and derived
        // from the page's own width so the card keeps that shape on a
        // phone and on a tablet instead of being cropped or padded.
        SizedBox(
          height: (MediaQuery.sizeOf(context).width * 0.86 * 9 / 16 + 62)
              .clamp(150.0, 320.0)
              .toDouble(),
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
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              onPageChanged: (index) => setState(() => _activeIndex = index),
              itemBuilder: (context, index) {
                final video = widget.videos[index];
                // The reward belongs to the lesson completion button, not to
                // any individual YouTube/MP4 source inside the lesson.
                const completed = false;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: _VideoCard(
                    video: video,
                    apiBaseUrl: widget.apiBaseUrl,
                    completed: completed,
                    onPressed: () {
                      StudentSoundService.instance.playTap();
                      Navigator.of(context).push(
                        StudentPageRoute<void>(
                          builder: (_) => _LessonPlayerScreen(
                            video: video,
                            apiBaseUrl: widget.apiBaseUrl,
                            initiallyCompleted: completed,
                            // Rewarding here is idempotent (rewardActivity
                            // guards against a double grant), so finishing
                            // the video can safely auto-complete the lesson
                            // instead of requiring the separate button below.
                            onCompleted: () async {
                              try {
                                final reward = await widget.contentService
                                    .rewardActivity(
                                      profile: widget.profile,
                                      activityType: 'lesson',
                                      activityId: widget.lesson.id,
                                    );
                                widget.onGamificationChanged(reward.snapshot);
                                return true;
                              } catch (_) {
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
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.videos.length,
            (index) => AnimatedContainer(
              duration: reduceMotion ? Duration.zero : 220.ms,
              width: index == _activeIndex ? 26 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: index == _activeIndex
                    ? const Color(0xFF0B8693)
                    : const Color(0xFFB3C8DE),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.video,
    required this.apiBaseUrl,
    required this.completed,
    required this.onPressed,
  });

  final LessonVideo video;
  final String apiBaseUrl;
  final bool completed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return StudentVideoHoverPreview(
      video: video,
      apiBaseUrl: apiBaseUrl,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: StudentPressScale(
        child: VideoThumbnailCard(
          video: video,
          onTap: onPressed,
          // A finished lesson video shows a full bar, the way a watched
          // clip does, instead of a separate "completed" chip.
          progress: completed ? 1 : null,
          subtitle: completed
              ? 'تمت المشاهدة ✓'
              : video.description ?? 'اضغط للمشاهدة',
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1);
  }
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
                  // Reaching the end of the video is itself "finished
                  // watching the lesson" — grant the reward immediately
                  // instead of waiting for the manual button below, which
                  // stays as a fallback for a student who skipped ahead.
                  onCompleted: _completeLesson,
                ),
              ),
            ),
          ),
        ],
      ),
      // No completion bar here on purpose: the player screen shows the
      // video and nothing else. The reward button lives once, under the
      // video in the lesson card, so the clip is never framed by chrome.
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
            child: StudentVideoPlayer(video: video, apiBaseUrl: apiBaseUrl),
          ),
        ),
      );
    }
    final ytId = _extractYouTubeId(targetUrl);
    final isYouTube =
        ytId.isNotEmpty && video.sourceType != VideoSourceType.mp4;
    final embedUrl = isYouTube
        ? 'https://www.youtube-nocookie.com/embed/$ytId?autoplay=1&rel=0&playsinline=1'
        : targetUrl;
    final embedHtml = isYouTube
        ? null
        : '''
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
                child: StudentWebEmbed(url: embedUrl, htmlContent: embedHtml),
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
        child: Student3DCard(
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
                  style: const TextStyle(
                    color: Color(0xFF5680AC),
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (onAction != null) ...[
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: onAction,
                    child: Text(actionLabel ?? 'متابعة'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
