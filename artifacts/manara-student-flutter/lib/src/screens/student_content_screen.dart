// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/academic_context.dart';
import '../models/student_content.dart';
import '../models/student_profile.dart';
import '../services/student_auth_service.dart';
import '../services/student_content_service.dart';
import '../widgets/student_video_player.dart';

enum StudentContentModule { lesson, games, personality, tutor }

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

class _StudentContentScreenState extends State<StudentContentScreen> {
  late final StudentContentService _contentService;
  late StudentContentModule _activeModule;
  List<LessonContent> _lessons = const [];
  List<HtmlGame> _apiGames = const [];
  LessonContent? _selectedLesson;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contentService = StudentContentService(
      widget.authService.client,
      baseUrl: widget.apiBaseUrl,
    );
    _activeModule = widget.initialModule;
    _loadContent();
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

    if (!mounted) return;
    setState(() {
      _lessons = lessons;
      _apiGames = apiGames;
      _selectedLesson = lessons.isEmpty ? null : lessons.first;
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
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'إغلاق',
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ModuleSwitcher(
              activeModule: _activeModule,
              onChanged: (module) => setState(() => _activeModule = module),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
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
          onLessonChanged: (lesson) => setState(() => _selectedLesson = lesson),
        );
      case StudentContentModule.games:
        return _GamesModule(
          games: _gamesFromLessons,
          apiBaseUrl: widget.apiBaseUrl,
        );
      case StudentContentModule.personality:
        return const _StateCard(
          icon: Icons.face_retouching_natural_rounded,
          title: 'شخصيتي',
          message: 'تعديل وتخصيص البطل.',
        );
      case StudentContentModule.tutor:
        return const _StateCard(
          icon: Icons.smart_toy_rounded,
          title: 'المعلم الافتراضي',
          message: 'المساعد الذكي للدروس.',
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
    case StudentContentModule.personality:
      return 'شخصيتي';
    case StudentContentModule.tutor:
      return 'المعلم الافتراضي';
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
      (StudentContentModule.personality, Icons.face_retouching_natural_rounded, 'شخصيتي'),
      (StudentContentModule.tutor, Icons.smart_toy_rounded, 'المعلم'),
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
  });

  final List<LessonContent> lessons;
  final LessonContent? selectedLesson;
  final ValueChanged<LessonContent> onLessonChanged;
  final String apiBaseUrl;

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
          _VideoCarousel(videos: lesson.videos, apiBaseUrl: apiBaseUrl),
      ],
    );
  }
}

class _GamesModule extends StatelessWidget {
  const _GamesModule({
    required this.games,
    required this.apiBaseUrl,
  });

  final List<HtmlGame> games;
  final String apiBaseUrl;

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
        ...games.map(
          (game) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _GameCard(
              game: game,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _GamePlayerScreen(
                    game: game,
                    apiBaseUrl: apiBaseUrl,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.game,
    required this.onPressed,
  });

  final HtmlGame game;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF4B267F), Color(0xFF8B5CF6)],
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
              const Icon(
                Icons.sports_esports_rounded,
                color: Color(0xFFE9D5FF),
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
              const Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 32,
              ),
            ],
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
  });

  final HtmlGame game;
  final String apiBaseUrl;

  @override
  State<_GamePlayerScreen> createState() => _GamePlayerScreenState();
}

class _GamePlayerScreenState extends State<_GamePlayerScreen> {
  late final String _viewId;
  html.IFrameElement? _frame;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
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
              ],
            ),
    );
  }
}

class _VideoCarousel extends StatefulWidget {
  const _VideoCarousel({required this.videos, required this.apiBaseUrl});

  final List<LessonVideo> videos;
  final String apiBaseUrl;

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
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: _VideoCard(
                    video: video,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => UniversalWebVideoScreen(
                          video: video,
                          apiBaseUrl: widget.apiBaseUrl,
                        ),
                      ),
                    ),
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
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video, required this.onPressed});

  final LessonVideo video;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
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
                  const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFBFFBFA), size: 38),
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
                onPressed: onPressed,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('شاهد الآن'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0B8693),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1);
  }

  MainAxisAlignment dynamicPaddingAlignment(BuildContext context) =>
      MainAxisAlignment.spaceBetween;
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF0B192C),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => html.window.open(targetUrl, '_blank'),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('تشغيل في تبويب جديد مباشر'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0B8693),
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
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
