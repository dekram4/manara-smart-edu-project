import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../widgets/lively.dart';
import '../theme/motion.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/academic_context.dart';
import '../models/student_content.dart';
import '../models/student_gamification.dart';
import '../models/student_profile.dart';
import '../l10n/student_strings.dart';
import '../services/student_auth_service.dart';
import '../services/student_content_service.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import '../widgets/arcade_game_card.dart';
import '../widgets/video_rows.dart';
import '../widgets/video_thumbnail_card.dart';
import '../widgets/playful_text.dart';
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

  /// ألعابُ المعلم لم تصل — شبكةٌ أو جلسة — لا «لا ألعاب». الفهرسُ العامّ يفرغ
  /// حين تُسند الألعابُ كلُّها إلى معلّمين، فكان التعذّرُ يُعرض «لا توجد ألعاب»
  /// بلا سببٍ ولا إعادة محاولة.
  String? _gamesError;
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
      authService: widget.authService,
    );
    _activeModule = widget.initialModule;
    _gamification = widget.profile.gamification;
    _rewardController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    // ‏ما وصل من قبل (أو ملأته لوحةُ البطاقات مسبقاً): البطاقةُ تُفتح عليه في
    // ‏إطارها الأوّل، ثم يتجدّد من الخادم بلا مؤشّر.
    final cachedLessons = StudentContentService.lastResult<List<LessonContent>>(
      StudentContentService.resultKey('lessons', widget.profile, widget.academicContext),
    );
    if (cachedLessons != null) {
      _lessons = cachedLessons;
      _selectedLesson = cachedLessons.isEmpty ? null : cachedLessons.first;
      _apiGames = [
        ...?StudentContentService.lastResult<List<HtmlGame>>('gameCatalog|${widget.apiBaseUrl}'),
        ...?StudentContentService.lastResult<List<HtmlGame>>('teacherGames|${widget.apiBaseUrl}'),
      ];
      _loading = false;
    }
    _loadContent();
    // ── المحتوى كما في Supabase الآن ──
    // كان يُقرأ مرّةً عند فتح البطاقة، فتعديلٌ أو حذفٌ من المعلّم لا يصل
    // الطالبَ حتى يخرج ويعود. فيُعاد سؤالُ Supabase عند العودة إلى التطبيق،
    // وكلَّ [_refreshEvery] ما دامت البطاقة مفتوحة.
    _lifecycle = AppLifecycleListener(onResume: _refreshLessons);
    _refreshTimer = Timer.periodic(_refreshEvery, (_) => _refreshLessons());
  }

  static const _refreshEvery = Duration(seconds: 30);
  AppLifecycleListener? _lifecycle;
  Timer? _refreshTimer;
  bool _refreshing = false;

  /// يجلب الدروس من جديد، ويستبدلها إن تغيّرت وحدها — بلا مؤشّر تحميل،
  /// والدرسُ المفتوح يبقى مفتوحاً إن لم يُحذف.
  Future<void> _refreshLessons() async {
    if (_loading || _refreshing || !mounted) return;
    _refreshing = true;
    try {
      final lessons = await _contentService.fetchLessons(
        widget.profile,
        academicContext: widget.academicContext,
      );
      if (!mounted) return;
      if (StudentContentService.lessonsSignature(lessons) ==
          StudentContentService.lessonsSignature(_lessons)) {
        return;
      }
      setState(() {
        _lessons = lessons;
        _selectedLesson =
            StudentContentService.keepSelectedLesson(lessons, _selectedLesson);
        _error = null;
      });
    } catch (_) {
      // شبكةٌ متقطّعة: تبقى آخرُ نسخةٍ ناجحة، والمحاولةُ التالية بعد قليل.
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _lifecycle?.dispose();
    // The celebration belongs to this card. Leaving it should end it,
    // not carry clapping out to the hub behind.
    StudentSoundService.instance.stopEffects();
    _rewardController.dispose();
    super.dispose();
  }

  void _applyGamification(StudentGamification stats) {
    final previous = _gamification;
    final earnedNewReward =
        stats.xp > previous.xp || stats.gems > previous.gems;
    setState(() => _gamification = stats);
    if (!earnedNewReward) return;
    if (!(MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      _rewardController.play();
    }
    StudentSoundService.instance.playCelebration();
    StudentSoundService.instance.playEncouragementArabic();
    _announceUnlockedGames(previous, stats);
  }

  /// Tells the student when their new level has opened another game.
  ///
  /// Crossing 100 XP is otherwise invisible from the lesson they were in
  /// — they would have to wander into the arcade to discover it. Naming
  /// the game is what turns a number going up into a reason to go there.
  void _announceUnlockedGames(
    StudentGamification previous,
    StudentGamification updated,
  ) {
    final games = _gamesFromLessons;
    if (games.isEmpty) return;
    final before =
        _GamesModule.unlockedCount(previous.level).clamp(0, games.length);
    final after =
        _GamesModule.unlockedCount(updated.level).clamp(0, games.length);
    if (after <= before) return;
    final opened = games[after - 1];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF4B267F),
        content: Text(
          trf('content.gameUnlocked',
              {'level': updated.level, 'title': opened.title}),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Future<void> _loadContent() async {
    // ‏الطلباتُ الأربعة معاً لا واحداً بعد واحد: كانت متتاليةً، فتنتظر البطاقةُ
    // ‏أربعَ رحلاتٍ إلى الخادم قبل أن يظهر شيءٌ منها.
    String? lessonError;
    String? gamesError;
    final lessonsRequest = _contentService
        .fetchLessons(widget.profile, academicContext: widget.academicContext)
        .catchError((Object error) {
      lessonError = trf('content.lessonLoadError', {'error': error});
      return const <LessonContent>[];
    });
    // The API catalog is intentionally independent from lesson_configs so
    // the games portal still works when the lesson query is unavailable.
    final catalogRequest = _contentService
        .fetchGameCatalog()
        .catchError((Object _) => const <HtmlGame>[]);
    // ألعابُ معلّم الطالب من «الترفيه والألعاب»: بعد ألعاب الفهرس، فلا
    // تُزيح لعبةً فتحها الطالب بمستواه.
    final teacherRequest = _contentService.fetchTeacherGames().catchError((Object error) {
      // تعذّرت: ألعابُ الفهرس والدروس كما هي، والسببُ يُعرض إن لم يبقَ شيء.
      gamesError = error is StateError ? error.message.toString() : tr('content.gamesUnreachable');
      return const <HtmlGame>[];
    });
    // The profile snapshot keeps content usable when progress is unavailable.
    final progressRequest = _contentService
        .fetchGamification(widget.profile)
        .catchError((Object _) => _gamification);

    final lessons = await lessonsRequest;
    final apiGames = [...await catalogRequest, ...await teacherRequest];
    final gamification = await progressRequest;

    if (!mounted) return;
    setState(() {
      _lessons = lessons;
      _apiGames = apiGames;
      _gamesError = gamesError;
      // ‏درسٌ فتحه الطالبُ وهو يتجدّد يبقى مفتوحاً إن لم يُحذف.
      _selectedLesson = StudentContentService.keepSelectedLesson(lessons, _selectedLesson) ??
          (lessons.isEmpty ? null : lessons.first);
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
      backgroundColor: StudentSurface.ground(context),
      appBar: AppBar(
        // Stated rather than inherited: the theme's bar rendered near-black
        // here, which is what made the title and the close button read as
        // a dark slab over a cream screen. A soft Manara blue-to-cream
        // sweep with deep ink on top instead.
        backgroundColor: Colors.transparent,
        foregroundColor: StudentSurface.ink(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: StudentSurface.barSweep(context),
            ),
          ),
        ),
        title: Text(
          _moduleTitle(_activeModule),
          style: TextStyle(
            color: StudentSurface.ink(context),
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          // Refetches the lesson from the server on demand. Nothing here
          // is cached, so this is not clearing anything — it is for the
          // case where a teacher changes a video while the student has
          // the card open and wants to see it without closing and
          // reopening the screen.
          IconButton(
            onPressed: _loading ? null : _retryContent,
            tooltip: tr('lesson.refresh'),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const StudentSoundToggle(),
        ],
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: tr('action.close'),
          icon: const Icon(Icons.close_rounded),
          style: IconButton.styleFrom(
            foregroundColor: StudentSurface.ink(context),
            backgroundColor: StudentSurface.controlWash(context),
            shape: CircleBorder(
              side: BorderSide(color: StudentSurface.outline(context)),
            ),
          ),
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
                        ? tr('content.lessonBlurb')
                        : tr('content.gamesBlurb'),
                    icon: _activeModule == StudentContentModule.lesson
                        ? Icons.play_lesson_rounded
                        : Icons.sports_esports_rounded,
                    colors: _activeModule == StudentContentModule.lesson
                        ? const [Color(0xFF9A5B09), Color(0xFFF59E0B)]
                        : const [Color(0xFF4B267F), Color(0xFF8B5CF6)],
                  ),
                ),
                // انتقال القسم (مواصفة الحركة §5.4): البطاقةُ فوراً، وشريطٌ
                // رفيعٌ أعلاها حتى يصل المحتوى.
                Expanded(
                  child: MotionSectionOverlay(
                    ready: !_loading,
                    label: tr('content.loading'),
                    child: _loading
                        ? const SizedBox.expand()
                        : StudentEntrance(child: _buildBody()),
                  ),
                ),
              ],
            ),
          ),
          StudentCelebration(controller: _rewardController),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null &&
        (_activeModule == StudentContentModule.lesson ||
            (_activeModule == StudentContentModule.games &&
                !_hasGameContent))) {
      return _StateCard(
        icon: Icons.cloud_off_rounded,
        title: tr('content.loadFailed'),
        message: _error!,
        actionLabel: tr('action.retry'),
        onAction: _retryContent,
      );
    }

    if (_activeModule == StudentContentModule.games &&
        !_hasGameContent &&
        _gamesError != null) {
      return _StateCard(
        icon: Icons.cloud_off_rounded,
        title: tr('content.loadFailed'),
        message: _gamesError!,
        actionLabel: tr('action.retry'),
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
          gamification: _gamification,
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
    // ── أسماءٌ تشدّ الطفل ──
    // «اللعبة 1» و«لعبة تعليمية» لا تقول له لماذا يضغط. فكلُّ اسمٍ عامٍّ يأخذ
    // اسماً حماسياً بالتناوب — ولا يتكرّر اسمان في القائمة نفسها ما دامت
    // الأسماءُ تكفي. واسمٌ سمّاه المعلّمُ يبقى كما هو.
    var generic = 0;
    return [
      for (var index = 0; index < games.length; index++)
        HtmlGame(
          id: games[index].id,
          url: games[index].url,
          title: isGenericGameTitle(games[index].title)
              ? tr('svc.gameName.${generic++ % catchyGameNameCount + 1}')
              : games[index].title,
          subtitle: games[index].subtitle,
          requiredLevel: index + 1,
        ),
    ];
  }
}

String _moduleTitle(StudentContentModule module) {
  switch (module) {
    case StudentContentModule.lesson:
      return tr('content.lessonTab');
    case StudentContentModule.games:
      return tr('content.gamesTab');
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
      return _StateCard(
        icon: Icons.video_library_outlined,
        title: tr('content.noVideos'),
        message: tr('content.noVideosBody'),
      );
    }

    final lesson = selectedLesson ?? lessons.first;
    // ‏تمريرٌ واحد للشاشة كلّها: الرأسُ، ثم صفوفُ الفيديو كسولةً بلا حدٍّ لعددها
    // ‏([SliverVideoRows])، ثم زرُّ الإكمال.
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverList.list(
      children: [
        // ‏لافتةُ الدرس: تدرّجٌ دافئ، وشاشةُ عرضٍ تطفو، واسمُ الدرس كبيراً،
        // ومكانُه في المنهج شاراتٍ ملوّنة — وعددُ فيديوهاته.
        _LessonBanner(lesson: lesson)
            .animate()
            .fadeIn(duration: 320.ms)
            .slideY(begin: 0.08, curve: Curves.easeOutBack),
        if (lessons.length > 1) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 58,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: lessons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = lessons[index];
                return _LessonPill(
                  label: item.lessonName.isNotEmpty ? item.lessonName : item.unit,
                  color: _lessonColors[index % _lessonColors.length],
                  selected: item.id == lesson.id,
                  onTap: () {
                    StudentSoundService.instance.playTap();
                    onLessonChanged(item);
                  },
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (lesson.videos.isNotEmpty)
          _SectionTitle(
            emoji: '🎬',
            text: tr('content.lessonVideo'),
            hint: tr('content.previewHint'),
          ),
        if (lesson.videos.isNotEmpty) const SizedBox(height: 12),
        if (lesson.videos.isEmpty)
          _StateCard(
            icon: Icons.video_call_outlined,
            title: tr('content.noVideoAdded'),
            message: tr('content.noVideoAddedBody'),
          ),
      ],
          ),
        ),
        if (lesson.videos.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            sliver: _VideoCarousel(
              lesson: lesson,
              videos: lesson.videos,
              apiBaseUrl: apiBaseUrl,
              profile: profile,
              gamification: gamification,
              contentService: contentService,
              onGamificationChanged: onGamificationChanged,
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          sliver: SliverToBoxAdapter(
            child: _LessonCompletionButton(
              lesson: lesson,
              profile: profile,
              gamification: gamification,
              contentService: contentService,
              onGamificationChanged: onGamificationChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// ألوانُ الدروس والحلقات بالتناوب: زاهيةٌ دافئة.
const _lessonColors = [
  Color(0xFFF59E0B),
  Color(0xFF0EA5E9),
  Color(0xFFEC4899),
  Color(0xFF10B981),
  Color(0xFF8B5CF6),
  Color(0xFFF97316),
];

/// لافتةُ الدرس في أعلى «شرح الدرس»: تدرّجٌ دافئٌ تعبره لمعة، وشاشةُ عرضٍ
/// تطفو، واسمُ الدرس كبيراً، ومكانُه في المنهج شاراتٍ ملوّنة.
class _LessonBanner extends StatefulWidget {
  const _LessonBanner({required this.lesson});

  final LessonContent lesson;

  @override
  State<_LessonBanner> createState() => _LessonBannerState();
}

class _LessonBannerState extends State<_LessonBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _clock;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (still) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final title = lesson.lessonName.trim().isNotEmpty ? lesson.lessonName : tr('content.yourVideos');
    final chips = [
      if (lesson.subject.trim().isNotEmpty) ('📚', lesson.subject),
      if (lesson.unit.trim().isNotEmpty) ('🧩', lesson.unit),
      if (lesson.videos.isNotEmpty) ('🎞️', trf('content.videoCount', {'n': lesson.videos.length})),
    ];
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          final t = _clock.value;
          final float = math.sin(2 * math.pi * t);
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFFF59E0B), Color(0xFFF97316), Color(0xFFEC4899)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF97316).withValues(alpha: 0.30 + 0.10 * float.abs()),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // لمعةٌ تعبر اللافتة.
                Positioned.fill(
                  child: IgnorePointer(
                    child: FractionalTranslation(
                      translation: Offset(t * 3 - 1.5, 0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.18),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Row(
                    children: [
                      Transform.translate(
                        offset: Offset(0, -5 * float),
                        child: Container(
                          width: 76,
                          height: 76,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 2.5),
                          ),
                          child: const Text('📺', style: TextStyle(fontSize: 42)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('content.lessonVideo'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                height: 1.2,
                                fontWeight: FontWeight.w900,
                                shadows: [Shadow(color: Color(0x55000000), offset: Offset(0, 2), blurRadius: 4)],
                              ),
                            ),
                            if (chips.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final (emoji, label) in chips)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.24),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
                                      ),
                                      child: Text(
                                        '$emoji $label',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// زرُّ درسٍ في شريط الدروس: كبسولةٌ ملوّنة، تمتلئ بلونها وتكبر حين تُختار.
class _LessonPill extends StatelessWidget {
  const _LessonPill({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          margin: EdgeInsets.symmetric(vertical: selected ? 0 : 4),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.15)!])
                : null,
            color: selected ? null : StudentSurface.card(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: selected ? 1 : 0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: selected ? 0.4 : 0.12),
                blurRadius: selected ? 12 : 4,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(selected ? '▶️' : '🎬', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : StudentSurface.ink(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// عنوانُ قسمٍ برمزٍ كبير وتلميحٍ تحته.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.emoji, required this.text, this.hint});

  final String emoji;
  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(color: StudentSurface.ink(context), fontSize: 19, fontWeight: FontWeight.w900),
              ),
              if (hint != null)
                Text(
                  hint!,
                  style: TextStyle(color: StudentSurface.mutedInk(context), fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
            ],
          ),
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
        // هتاف ثم تصفيق عند إنهاء الدرس فعلاً؛ والنقرة المتكرّرة التي لا
        // تكسب شيئاً تأخذ النغمة الهادئة أعلاه.
        StudentSoundService.instance.playLessonComplete();
        if (reward.gems > 0) StudentSoundService.instance.playReward();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reward.alreadyRewarded
                ? tr('content.lessonRewarded')
                : tr('content.lessonReward') +
                    (reward.xp > 0
                        ? trf('content.lessonRewardXp', {'xp': reward.xp})
                        : ''),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('content.completeFailed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ‏درسٌ لم يضع معلّمه فيه شرحاً لا يُكافأ على إنهائه: لا شيء أُنهي.
    // ‏وكان الزرّ يعمل على أي درس، فيكسب الطفل جواهر من فتح درس فارغ —
    // ‏ويتعلّم أن الجواهر تأتي من الضغط لا من التعلّم.
    final empty = !widget.lesson.hasExplanation;
    final enabled = !empty && !_completed && !_saving;
    // Gold while the reward is still to be claimed, emerald once it has
    // been — the colour carries the state, so the label does not have to
    // work alone. A lesson with nothing in it is grey: the colour says it
    // is not waiting for the child, it is waiting for the teacher.
    final gradient = empty
        ? const [Color(0xFFB6BEC6), Color(0xFF98A2AD)]
        : _completed
            ? const [Color(0xFF0E9F6E), Color(0xFF067A54)]
            : const [Color(0xFFFFC542), Color(0xFFF08C1E)];
    final ledge = empty
        ? const Color(0xFF6B7280)
        : _completed
            ? const Color(0xFF04543A)
            : const Color(0xFFB4630C);

    // نبضةُ توهّجٍ خضراء لحظةَ يُنهى الدرس — فوق تصفيقه.
    return LivelyGlow(
      active: _completed,
      radius: 30,
      color: const Color(0xFF0E9F6E),
      child: StudentPressScale(
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
                color: ledge.withValues(alpha: 0.42),
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
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6), width: 1.6),
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
                    color: Colors.white.withValues(alpha: 0.26),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  child: Icon(
                    empty
                        ? Icons.hourglass_empty_rounded
                        : _completed
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
                      tr(empty
                          ? 'content.noLessonYet'
                          : _completed
                              ? 'content.rewardTaken'
                              : _saving
                                  ? 'content.savingCompletion'
                                  : 'content.finishLesson'),
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
      ),
    );
  }
}

/// The arcade. It no longer needs the student's profile, their progress
/// or the content service: nothing here is scored, unlocked or saved, so
/// the list only needs the games themselves and where to load them from.
/// The arcade, unlocked a game at a time by the XP a student earns
/// elsewhere — lessons, videos and quizzes.
///
/// The rule is positional and deliberately simple, because a child has to
/// be able to predict it: the nth game needs level n, and a level is 100
/// XP. So the number of games open is exactly the student's level, and
/// every 100 points opens the next one.
///
/// Nothing here awards XP or spends it. Playing is still free; the points
/// only decide how many games are available.
class _GamesModule extends StatelessWidget {
  const _GamesModule({
    required this.games,
    required this.apiBaseUrl,
    required this.gamification,
  });

  final List<HtmlGame> games;
  final String apiBaseUrl;
  final StudentGamification gamification;

  // القاعدة تعيش في GameUnlockRule لتكون قابلة للاختبار — هذه الشاشة خاصة
  // بملفها فلا يبلغها اختبار. ما هنا تفويض لا نسخة ثانية.
  static int requiredLevelFor(int index) =>
      GameUnlockRule.requiredLevelFor(index);
  static bool isUnlocked(int index, int level) =>
      GameUnlockRule.isUnlocked(index, level);
  static int unlockedCount(int level) => GameUnlockRule.unlockedCount(level);

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) {
      return _StateCard(
        icon: Icons.sports_esports_rounded,
        title: tr('lesson.noGames'),
        message: tr('lesson.noGamesBody'),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        RainbowText(
          tr('content.gamesTitle'),
          fontSize: 28,
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08),
        const SizedBox(height: 4),
        Text(
          tr('content.gamesSubtitle'),
          style: TextStyle(
            color: StudentSurface.mutedInk(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        // الألعاب تُفتح واحدةً مع كل مستوى: المستوى الأول يفتح الأولى،
        // والثاني الثانية، وهكذا — وفي المستوى صفر كلُّها مقفلة.
        //
        // وهذا التعليق كان يقول عكس ما تفعله الشيفرة تحته: أن البوّابة
        // أُزيلت وأن كل لعبة تُفتح بنقرة. وهي قائمةٌ في `itemBuilder`
        // أدناه منذ كُتب. تعليقٌ يكذّب شيفرته أسوأ من لا تعليق: يُقرأ
        // فيُبنى عليه، ولا يُكتشف إلا حين يعطب شيء.
        //
        // والبوّابة بلا عدّادٍ بابٌ مغلق، فالشريط تحتها يقول أين هو
        // وكم بقي.
        _ArcadeProgress(stats: gamification, total: games.length),
        const SizedBox(height: 16),
        // شبكة لا قائمة: بطاقتان في عرض الهاتف وثلاث على الشاشة الواسعة،
        // فتُرى الألعاب معاً كرفّ ألعاب يختار منه الطفل، لا كسطور متتابعة
        // يقرؤها سطراً سطراً.
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth >= 720 ? 3 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: games.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.7,
              ),
              itemBuilder: (context, index) {
                final game = games[index];
                final unlocked = isUnlocked(index, gamification.level);
                final neededLevel = requiredLevelFor(index);
                // تموّجُ اللمسة فوق ضغطة البطاقة الخاصة بها.
                return LivelyTouch(
                  child: ArcadeGameCard(
                  game: game,
                  index: index,
                  locked: !unlocked,
                  requiredLevel: neededLevel,
                  currentLevel: gamification.level,
                  onPressed: () {
                    if (!unlocked) {
                      StudentSoundService.instance
                          .play(StudentSoundCue.warning);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            // المستوى صفر حالٌ خاصة: كلّ شيءٍ مقفل،
                            // و«مستواك 0» ليست خبراً. فتُقال له الخطوة
                            // التالية بدل حاله الراهنة.
                            gamification.level <= 0
                                ? tr('content.firstGameHint')
                                : trf('content.gameLockedHint', {
                                    'level': neededLevel,
                                    'current': gamification.level,
                                  }),
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
                        ),
                      ),
                    );
                  },
                ),
                )
                    .animate()
                    .fadeIn(duration: 260.ms, delay: (60 * index).ms)
                    .scale(begin: const Offset(0.92, 0.92));
              },
            );
          },
        ),
      ],
    );
  }
}

/// The student's level and how far the next game is.
///
/// Gating without showing progress is just a closed door. This says which
/// level they are on, how many games that opens, and exactly how many
/// points remain until the next one.
class _ArcadeProgress extends StatelessWidget {
  const _ArcadeProgress({required this.stats, required this.total});

  final StudentGamification stats;
  final int total;

  @override
  Widget build(BuildContext context) {
    final open = _GamesModule.unlockedCount(stats.level).clamp(0, total);
    final allOpen = open >= total;
    return Student3DCard(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4B267F), Color(0xFF8B5CF6)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.military_tech_rounded,
                    color: Color(0xFFFDE68A), size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    trf('content.gamesProgress', {
                      'level': stats.level,
                      'open': open,
                      'total': total,
                    }),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${stats.xp} XP',
                  style: const TextStyle(
                    color: Color(0xFFFDE68A),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: stats.levelProgress / 100,
                minHeight: 9,
                backgroundColor: Colors.white.withValues(alpha: 0.24),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFFFDE68A)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              allOpen
                  ? tr('content.allGamesOpen')
                  : trf('content.nextGameIn', {'xp': stats.xpToNextLevel}),
              style: const TextStyle(
                color: Color(0xFFE9D5FF),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One game in the arcade. A locked card keeps the same shape so the two
/// read as one family, and says exactly what is needed to open it rather
/// than only that it is shut.
/// شارات الألعاب: ثلاث عائلات تدور بالترتيب.
///
/// اللعبة لا تحمل نوعاً في بياناتها، فالشارة تُشتقّ من موضعها — وهو ثابت،
/// فتحمل اللعبة الواحدة شارتها نفسها في كل مرة بدل أن تتبدّل أمام الطفل.
/// The game itself, full-screen. It reports nothing back: there is no
/// completion to record and no reward to claim, so a student can start
/// one, play for a minute and leave without the app keeping score.
class _GamePlayerScreen extends StatefulWidget {
  const _GamePlayerScreen({
    required this.game,
    required this.apiBaseUrl,
  });

  final HtmlGame game;
  final String apiBaseUrl;

  @override
  State<_GamePlayerScreen> createState() => _GamePlayerScreenState();
}

class _GamePlayerScreenState extends State<_GamePlayerScreen> {
  String? _error;
  bool _loading = true;
  var _reloadKey = 0;

  @override
  void initState() {
    super.initState();
    _enterImmersive();
  }

  @override
  void dispose() {
    _restoreSystemBars();
    super.dispose();
  }

  /// The whole card already runs immersive through [StudentImmersive] on
  /// its route, but the game is pushed as a screen of its own on top of
  /// it, so it re-asserts the mode here: without this, entering the game
  /// would inherit whatever the platform had drifted back to.
  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Returning to the games list stays immersive — the card around it is
  /// still open — so this puts the mode back rather than restoring the
  /// bars, which would flash them over the list on the way out.
  void _restoreSystemBars() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(_url);
    final validUrl = uri != null &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.host.isNotEmpty ||
        _isRelativeApiGame;

    return PopScope(
      // Back out of the game and the phone's own buttons come straight
      // back, without waiting on dispose.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _restoreSystemBars();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF160C2D),
        appBar: AppBar(
          backgroundColor: const Color(0xFF160C2D),
          foregroundColor: Colors.white,
          title: Text(widget.game.title),
          actions: [
            IconButton(
              onPressed: validUrl ? _reload : null,
              tooltip: tr('lesson.reloadGame'),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: !validUrl
            ? _StateCard(
                icon: Icons.link_off_rounded,
                title: tr('lesson.badGameLink'),
                message: tr('lesson.badGameLinkBody'),
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
                    ColoredBox(
                      color: const Color(0xFF160C2D),
                      child: Center(
                        child: StudentRiveLoading(
                          label: tr('content.gameLoading'),
                        ),
                      ),
                    ),
                  if (_error != null)
                    ColoredBox(
                      color: const Color(0xF2160C2D),
                      child: Center(
                        child: _StateCard(
                          icon: Icons.error_outline_rounded,
                          title: tr('content.gameFailed'),
                          message: _error!,
                          actionLabel: tr('action.retry'),
                          onAction: _reload,
                        ),
                      ),
                    ),
                  // The "I finished — collect your XP and gems" button is
                  // gone with the rest of the arcade's bookkeeping. A game
                  // ends when the student is done with it, and they leave
                  // with the app's own back control.
                ],
              ),
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
  @override
  Widget build(BuildContext context) {
    // The same grid the cinema uses — identical maxCrossAxisExtent,
    // spacing and aspect ratio — so a lesson's clips are the size a
    // student already knows from there, instead of one huge page-wide
    // card at a time. The pager and its dots are gone with it.
    //
    // ‏صفوفٌ بارتفاع محتواها لا خاناتٌ بنسبةٍ ثابتة، تُبنى أثناء التمرير —
    // ‏انظر [SliverVideoRows]. البطاقةُ وما تفتحه كما هما.
    return SliverVideoRows(
      itemCount: widget.videos.length,
      itemBuilder: (context, index) {
        final video = widget.videos[index];
        // The reward belongs to the lesson completion button, not to any
        // individual YouTube/MP4 source inside the lesson.
        const completed = false;
        return _VideoCard(
          video: video,
          index: index,
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
                  // Rewarding here is idempotent (rewardActivity guards
                  // against a double grant), so finishing the video can
                  // safely auto-complete the lesson instead of requiring
                  // the separate button below.
                  onCompleted: () async {
                    try {
                      final reward = await widget.contentService.rewardActivity(
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
        );
      },
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.video,
    required this.index,
    required this.apiBaseUrl,
    required this.completed,
    required this.onPressed,
  });

  final LessonVideo video;

  /// ترتيبُه في الدرس: لونُ إطاره ورقمُ شارته.
  final int index;
  final String apiBaseUrl;
  final bool completed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = _lessonColors[index % _lessonColors.length];
    // ‏إطارٌ بلون الحلقة وشارةُ رقمها: الطفلُ يعدّ «الفيديو الأوّل، الثاني…».
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            color.withValues(alpha: StudentSurface.isDark(context) ? 0.30 : 0.16),
            color.withValues(alpha: StudentSurface.isDark(context) ? 0.12 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          StudentVideoHoverPreview(
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
                    ? tr('content.watched')
                    : video.description ?? tr('content.watchHint'),
              ),
            ),
          ),
          PositionedDirectional(
            top: -6,
            start: -6,
            child: IgnorePointer(
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.2)!]),
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: (60 * index.clamp(0, 8)).ms).slideY(begin: 0.12, curve: Curves.easeOutBack);
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
      backgroundColor: const Color(0xFF17364F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17364F),
        foregroundColor: Colors.white,
        title: Text(widget.video.title),
      ),
      // Pinned to the top at the full width of the screen, not floated in
      // the middle of the body.
      //
      // `Expanded > Center` put a 16:9 strip in the vertical middle of a
      // tall portrait screen with dark space above and below it, which is
      // the "small in the middle" in the report. Top-aligned and
      // full-width, the video starts where the student is already looking
      // and is as large as 16:9 allows on the device.
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: double.infinity,
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
    final ytId = _extractYouTubeId(targetUrl);
    final isYouTube =
        ytId.isNotEmpty && video.sourceType != VideoSourceType.mp4;

    // ── ويوتيوب يمرّ بالمشغّل، لا بإطارِ وِبٍّ خام ──
    //
    // كانت هذه الشاشة تفتح `youtube-nocookie.com/embed/...` في
    // `StudentWebEmbed` — إطارُ وِبٍّ لا شيء لنا فوقه: لا زرَّ تشغيلٍ ولا
    // ملءَ شاشة، وأدواتُ يوتيوب وحدها فيه بشعارِها وعنوانِها ومقترحاتِها
    // وبابِها إلى الموقع.
    //
    // وبطاقةُ شرح الدرس تفتح هذه الشاشة، فكلُّ ما بُني في
    // `StudentVideoPlayer` — إقفالُ الصفحة عن اللمس، وشريطُ التشغيل
    // وملءِ الشاشة، وغطاءُ شاشة النهاية — لم يكن يصلها. كان يُصلَح مشغّلٌ
    // ويُفتح آخر.
    //
    // والمشغّلُ يعرف يوتيوب: `_useYoutubePlayerIframe` تختاره متى كان
    // الرابطُ يوتيوبَ والمنصّةُ أندرويد أو iOS أو ويب. فيُعطى الفيديو كما
    // يُعطى mp4، ويبقى `StudentWebEmbed` لما ليس واحداً منهما.
    if (video.sourceType == VideoSourceType.mp4 || isYouTube) {
      return Scaffold(
        backgroundColor: const Color(0xFF17364F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF17364F),
          foregroundColor: Colors.white,
          title: Text(video.title),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: double.infinity,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: StudentVideoPlayer(video: video, apiBaseUrl: apiBaseUrl),
            ),
          ),
        ),
      );
    }
    // وما بقي فيديو خامٌ يُعرض في صفحة HTML من عندنا: لا يوتيوب فيه، فلا
    // شعارَ ولا مقترحاتٍ ولا بابَ إلى موقعٍ خارجي — وأدواتُ المتصفّح
    // وحدها تكفيه.
    final embedHtml = '''
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
      backgroundColor: const Color(0xFF17364F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17364F),
        foregroundColor: Colors.white,
        title: Text(video.title),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: tr('content.back'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: StudentWebEmbed(
                  url: targetUrl,
                  htmlContent: embedHtml,
                ),
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
              // ‏كانت بيضاءَ ثابتة ونصُّها بلون الحبر: في الداكن صار الحبرُ
              // أبيضَ على أبيض فاختفت رسالةُ الخطأ كلُّها.
              color: StudentSurface.glass(context, 0.92),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: StudentSurface.vivid(context, const Color(0xFF0B8693)), size: 54),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: StudentSurface.ink(context),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: StudentSurface.mutedInk(context),
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (onAction != null) ...[
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: onAction,
                    child: Text(actionLabel ?? tr('content.continue')),
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
