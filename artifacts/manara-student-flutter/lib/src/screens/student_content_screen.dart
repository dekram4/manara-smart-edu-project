import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

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
    this.lessonOnly = false,
    super.key,
  });

  final StudentProfile profile;
  final StudentAuthService authService;
  final StudentContentModule initialModule;
  final AcademicContext? academicContext;
  final String apiBaseUrl;
  final bool lessonOnly;

  @override
  State<StudentContentScreen> createState() => _StudentContentScreenState();
}

class _StudentContentScreenState extends State<StudentContentScreen> {
  late final StudentContentService _contentService;
  late StudentContentModule _activeModule;
  List<LessonContent> _lessons = const [];
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
    _activeModule = widget.lessonOnly
        ? StudentContentModule.lesson
        : widget.initialModule;
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final lessons = await _contentService.fetchLessons(
        widget.profile,
        academicContext: widget.academicContext,
      );
      if (!mounted) return;
      setState(() {
        final selectedFromContext = widget.academicContext?.selectedLesson;
        final includesSelected = selectedFromContext != null &&
            lessons.any((lesson) => lesson.id == selectedFromContext.id);
        _lessons = selectedFromContext == null || includesSelected
            ? lessons
            : [selectedFromContext, ...lessons];
        _selectedLesson = selectedFromContext ?? (lessons.isEmpty ? null : lessons.first);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل محتوى الدروس من Supabase: $error';
      });
    }
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
            if (!widget.lessonOnly)
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
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0B8693)),
      );
    }
    if (_error != null && _activeModule == StudentContentModule.lesson) {
      return _StateCard(
        icon: Icons.cloud_off_rounded,
        title: 'تعذر تحميل المحتوى',
        message: _error!,
        actionLabel: 'إعادة المحاولة',
        onAction: () {
          setState(() => _loading = true);
          _loadContent();
        },
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
        return _GamesModule(lesson: _selectedLesson);
      case StudentContentModule.personality:
        return _PersonalityModule(
          profile: widget.profile,
          contentService: _contentService,
        );
      case StudentContentModule.tutor:
        return _TutorModule(
          profile: widget.profile,
          lesson: _selectedLesson,
          contentService: _contentService,
          apiBaseUrl: widget.apiBaseUrl,
        );
    }
  }
}

String _moduleTitle(StudentContentModule module) {
  switch (module) {
    case StudentContentModule.lesson:
      return 'تفاصيل الدرس';
    case StudentContentModule.games:
      return 'الترفيه والألعاب';
    case StudentContentModule.personality:
      return 'شخصيتي';
    case StudentContentModule.tutor:
      return 'المعلم الافتراضي';
  }
}

class _ModuleSwitcher extends StatelessWidget {
  const _ModuleSwitcher({
    required this.activeModule,
    required this.onChanged,
  });

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
            avatar: Icon(
              item.$2,
              size: 19,
              color: selected ? Colors.white : const Color(0xFF0B8693),
            ),
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
    required this.apiBaseUrl,
    required this.onLessonChanged,
  });

  final List<LessonContent> lessons;
  final LessonContent? selectedLesson;
  final String apiBaseUrl;
  final ValueChanged<LessonContent> onLessonChanged;

  @override
  Widget build(BuildContext context) {
    if (lessons.isEmpty) {
      return const _StateCard(
        icon: Icons.auto_stories_outlined,
        title: 'لا توجد دروس متاحة',
        message: 'ستظهر هنا الدروس المنشورة لمسارك الأكاديمي.',
      );
    }

    final lesson = selectedLesson ?? lessons.first;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Text(
          'تفاصيل الدرس',
          style: const TextStyle(
            color: Color(0xFF0E1B2A),
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08),
        const SizedBox(height: 4),
        Text(
          lesson.scopeLabel.isEmpty
              ? 'المحتوى المرتبط بمسارك الأكاديمي'
              : lesson.scopeLabel,
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
                  label: Text(
                    item.lessonName.isNotEmpty
                        ? item.lessonName
                        : (item.unit.isEmpty ? 'درس ${index + 1}' : item.unit),
                  ),
                  selectedColor: const Color(0xFFBFEFED),
                  labelStyle: const TextStyle(
                    color: Color(0xFF0E1B2A),
                    fontWeight: FontWeight.w800,
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (lesson.videos.isNotEmpty) ...[
          const SizedBox(height: 16),
            _VideoCarousel(
              videos: lesson.videos,
              apiBaseUrl: apiBaseUrl,
            ),
        ],
        if (lesson.videos.isEmpty)
          const _StateCard(
            icon: Icons.menu_book_outlined,
            title: 'محتوى الدرس غير متوفر بعد',
            message: 'الدرس موجود في المسار، لكن لم تتم إضافة نص أو فيديو له بعد.',
          )
      ],
    );
  }
}

class _VideoCarousel extends StatefulWidget {
  const _VideoCarousel({
    required this.videos,
    required this.apiBaseUrl,
  });

  final List<LessonVideo> videos;
  final String apiBaseUrl;

  @override
  State<_VideoCarousel> createState() => _VideoCarouselState();
}

class _VideoCarouselState extends State<_VideoCarousel> {
  final _controller = PageController(viewportFraction: 0.9);
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
              dragDevices: const {
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
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: _VideoCard(
                    video: video,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => VideoViewerScreen(
                          video: video,
                          apiBaseUrl: widget.apiBaseUrl,
                          videos: widget.videos,
                          initialIndex: index,
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
    required this.onPressed,
  });

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.movie_filter_rounded, color: Color(0xFFBFFBFA), size: 34),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(38),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      video.sourceType == VideoSourceType.mp4 ? 'MP4' : 'مشاهدة',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                video.description ?? 'اضغط لفتح المشغل والتكبير',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFBFFBFA),
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
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
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1).shimmer(
          delay: 500.ms,
          duration: 1300.ms,
          color: const Color(0x55BFFBFA),
        );
  }
}

class VideoViewerScreen extends StatefulWidget {
  const VideoViewerScreen({
    required this.video,
    required this.apiBaseUrl,
    this.videos = const [],
    this.initialIndex = 0,
    super.key,
  });

  final LessonVideo video;
  final String apiBaseUrl;
  final List<LessonVideo> videos;
  final int initialIndex;

  @override
  State<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends State<VideoViewerScreen> {
  late final PageController _pageController;
  late final List<LessonVideo> _videos;
  late int _activeIndex;

  @override
  void initState() {
    super.initState();
    _videos = widget.videos.isEmpty ? [widget.video] : widget.videos;
    _activeIndex = widget.initialIndex.clamp(0, _videos.length - 1).toInt();
    _pageController = PageController(initialPage: _activeIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeVideo = _videos[_activeIndex];
    return Scaffold(
      backgroundColor: const Color(0xFF071425),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071425),
        foregroundColor: Colors.white,
        title: Text(activeVideo.title),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'إغلاق المشغل',
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: const {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                },
              ),
              child: PageView.builder(
                controller: _pageController,
                itemCount: _videos.length,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _activeIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final video = _videos[index];
                  final url = resolveStudentVideoUrl(
                    video,
                    apiBaseUrl: widget.apiBaseUrl,
                  );
                  final needsApiBaseUrl =
                      isDirectVideoUrl(url, video) && url.startsWith('/');
                  if (needsApiBaseUrl) {
                    return const _VideoConfigurationMessage();
                  }
                  return Center(
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: StudentVideoPlayer(
                        key: ValueKey(url),
                        video: video,
                        apiBaseUrl: widget.apiBaseUrl,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (_videos.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${_activeIndex + 1} / ${_videos.length}  •  اسحب للتنقل بين الفيديوهات',
                style: const TextStyle(
                  color: Color(0xFFBFFBFA),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoConfigurationMessage extends StatelessWidget {
  const _VideoConfigurationMessage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off_rounded, color: Color(0xFF5EEAD4), size: 52),
            SizedBox(height: 14),
            Text(
              'رابط الفيديو غير متاح',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'لم يتم العثور على ملف الفيديو أو لا تملك صلاحية الوصول إليه. '
              'تأكد من اتصال الإنترنت ثم حاول فتحه مرة أخرى.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFBFEFED), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _GamesModule extends StatefulWidget {
  const _GamesModule({required this.lesson});

  final LessonContent? lesson;

  @override
  State<_GamesModule> createState() => _GamesModuleState();
}

class _GamesModuleState extends State<_GamesModule> {
  static const _fallbackGames = [
    HtmlGame(
      id: 'manara-default-game',
      url: 'https://html5.gamedistribution.com/rvvASMiM/2618b45729854f8cbdf0616f8f175702/index.html',
      title: 'عالم الحيوانات اللطيف',
      subtitle: 'لعبة HTML5 داخل منصة منارة',
    ),
  ];

  InAppWebViewController? _controller;
  late List<HtmlGame> _games;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _games = widget.lesson?.games.isNotEmpty == true ? widget.lesson!.games : _fallbackGames;
  }

  @override
  Widget build(BuildContext context) {
    final game = _games[_activeIndex];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              game.subtitle,
              style: const TextStyle(color: Color(0xFF5680AC), fontWeight: FontWeight.w700),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _games.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) => ChoiceChip(
              selected: index == _activeIndex,
              onSelected: (_) {
                setState(() {
                  _activeIndex = index;
                  _controller = null;
                });
              },
              label: Text(_games[index].title),
              selectedColor: const Color(0xFFDCC7FF),
              labelStyle: const TextStyle(
                color: Color(0xFF392065),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InAppWebView(
                      key: ValueKey(game.id),
                      initialUrlRequest: URLRequest(url: WebUri(game.url)),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        mediaPlaybackRequiresUserGesture: false,
                        allowsInlineMediaPlayback: true,
                        supportZoom: false,
                        useShouldOverrideUrlLoading: true,
                        transparentBackground: true,
                      ),
                      onWebViewCreated: (controller) => _controller = controller,
                      shouldOverrideUrlLoading: (controller, action) async {
                        final target = action.request.url;
                        if (target == null) return NavigationActionPolicy.CANCEL;
                        if (target.scheme == 'http' || target.scheme == 'https') {
                          return NavigationActionPolicy.ALLOW;
                        }
                        return NavigationActionPolicy.CANCEL;
                      },
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                      color: Colors.black.withAlpha(150),
                      borderRadius: BorderRadius.circular(18),
                      child: IconButton(
                        onPressed: () => _controller?.reload(),
                        tooltip: 'إعادة تشغيل اللعبة',
                        color: Colors.white,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonalityModule extends StatefulWidget {
  const _PersonalityModule({
    required this.profile,
    required this.contentService,
  });

  final StudentProfile profile;
  final StudentContentService contentService;

  @override
  State<_PersonalityModule> createState() => _PersonalityModuleState();
}

class _PersonalityModuleState extends State<_PersonalityModule> {
  late Map<String, dynamic> _appearance;
  double _rotation = 0;
  bool _saving = false;

  static const _hair = ['🦱', '🧑‍🦱', '🧢', '🎓', '🦲'];
  static const _tops = ['👕', '🧥', '🦺', '🥋', '🧑‍🚀', '🎓'];
  static const _bottoms = ['👖', '🩳', '🥋', '🩲', '🦿'];
  static const _shoes = ['👟', '🥾', '🥿', '🛼', '🩴'];
  static const _skinTones = ['#edb891', '#c68642', '#8d5524', '#f1c27d'];

  @override
  void initState() {
    super.initState();
    _appearance = {
      'shape': 'full-body',
      'color': '#38bdf8',
      'outfit': '👕',
      'hair': '🧑‍🦱',
      'top': '👕',
      'bottom': '👖',
      'shoes': '👟',
      'skinTone': '#edb891',
      ...?widget.profile.appearance,
    };
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.contentService.saveAppearance(
        profile: widget.profile,
        appearance: _appearance,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ شخصيتك في ملف الطالب بنجاح!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ الشخصية في Supabase: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        const Text(
          'اصنع شخصيتك كاملة الجسم',
          style: TextStyle(
            color: Color(0xFF0E1B2A),
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08),
        const SizedBox(height: 5),
        const Text(
          'اسحب الشخصية لتدويرها ثم اختر الشعر والملابس والحذاء.',
          style: TextStyle(color: Color(0xFF5680AC), fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onPanUpdate: (details) => setState(() {
            _rotation += details.delta.dx * 0.012;
          }),
          child: _GlassPanel(
            child: SizedBox(
              height: 330,
              child: Center(
                child: Transform.rotate(
                  angle: _rotation,
                  child: _FullBodyAvatar(appearance: _appearance),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _AvatarPicker(
          title: 'الشعر',
          values: _hair,
          selected: _appearance['hair']?.toString() ?? '',
          onSelected: (value) => setState(() => _appearance['hair'] = value),
        ),
        _AvatarPicker(
          title: 'القطعة العلوية',
          values: _tops,
          selected: _appearance['top']?.toString() ?? '',
          onSelected: (value) {
            setState(() {
              _appearance['top'] = value;
              _appearance['outfit'] = value;
            });
          },
        ),
        _AvatarPicker(
          title: 'القطعة السفلية',
          values: _bottoms,
          selected: _appearance['bottom']?.toString() ?? '',
          onSelected: (value) => setState(() => _appearance['bottom'] = value),
        ),
        _AvatarPicker(
          title: 'الحذاء',
          values: _shoes,
          selected: _appearance['shoes']?.toString() ?? '',
          onSelected: (value) => setState(() => _appearance['shoes'] = value),
        ),
        _AvatarPicker(
          title: 'لون البشرة',
          values: _skinTones,
          selected: _appearance['skinTone']?.toString() ?? '',
          onSelected: (value) => setState(() => _appearance['skinTone'] = value),
          isColor: true,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_saving ? 'جاري الحفظ...' : 'حفظ شخصيتي'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0B8693),
            padding: const EdgeInsets.symmetric(vertical: 15),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.title,
    required this.values,
    required this.selected,
    required this.onSelected,
    this.isColor = false,
  });

  final String title;
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;
  final bool isColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(color: Color(0xFF274E76), fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 53,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final value = values[index];
                final selectedValue = value == selected;
                return GestureDetector(
                  onTap: () => onSelected(value),
                  child: AnimatedContainer(
                    duration: 180.ms,
                    width: 53,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isColor ? _hexColor(value) : Colors.white,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: selectedValue ? const Color(0xFF0B8693) : const Color(0xFFD7E3EF),
                        width: selectedValue ? 3 : 1,
                      ),
                    ),
                    child: isColor
                        ? null
                        : Text(value, style: const TextStyle(fontSize: 27)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FullBodyAvatar extends StatelessWidget {
  const _FullBodyAvatar({required this.appearance});

  final Map<String, dynamic> appearance;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          appearance['hair']?.toString() ?? '🧑‍🦱',
          style: const TextStyle(fontSize: 70),
        ),
        Text(
          appearance['top']?.toString() ?? '👕',
          style: const TextStyle(fontSize: 92),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(appearance['bottom']?.toString() ?? '👖', style: const TextStyle(fontSize: 72)),
            Text(appearance['shoes']?.toString() ?? '👟', style: const TextStyle(fontSize: 58)),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 350.ms).scale(begin: const Offset(0.88, 0.88));
  }
}

class _TutorModule extends StatefulWidget {
  const _TutorModule({
    required this.profile,
    required this.lesson,
    required this.contentService,
    required this.apiBaseUrl,
  });

  final StudentProfile profile;
  final LessonContent? lesson;
  final StudentContentService contentService;
  final String apiBaseUrl;

  @override
  State<_TutorModule> createState() => _TutorModuleState();
}

class _TutorModuleState extends State<_TutorModule> {
  final _questionController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_TutorMessage> _messages = [];
  bool _solving = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      const _TutorMessage(
        text: 'أهلًا! أنا معلمك الافتراضي. اكتب سؤالك وسأساعدك خطوة بخطوة.',
        fromStudent: false,
      ),
    );
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await widget.contentService.loadTutorHistory(widget.profile.id);
      if (!mounted || history.isEmpty) return;
      final restored = <_TutorMessage>[];
      for (final record in history) {
        final data = record['data'];
        if (data is! Map) continue;
        final question = data['question']?.toString().trim() ?? '';
        final answer = data['answer']?.toString().trim() ?? '';
        if (question.isNotEmpty) {
          restored.add(_TutorMessage(text: question, fromStudent: true));
        }
        if (answer.isNotEmpty) {
          restored.add(_TutorMessage(text: answer, fromStudent: false));
        }
      }
      if (restored.isEmpty) return;
      setState(() {
        _messages
          ..clear()
          ..add(
            const _TutorMessage(
              text: 'أهلًا بك مجددًا! تذكرت آخر أسئلتك، ما الذي نكمله اليوم؟',
              fromStudent: false,
            ),
          )
          ..addAll(restored);
      });
      _scrollToEnd();
    } catch (_) {
      // A missing history must not prevent the tutor from opening.
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _solving) return;
    _questionController.clear();
    setState(() {
      _messages.add(_TutorMessage(text: question, fromStudent: true));
      _solving = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 280));

    String answer;
    try {
      answer = await _requestAnswer(question);
    } catch (_) {
      answer = _friendlyFallback(question);
    }
    if (!mounted) return;
    setState(() {
      _messages.add(_TutorMessage(text: answer, fromStudent: false));
      _solving = false;
    });
    _scrollToEnd();
    try {
      await widget.contentService.saveTutorInteraction(
        studentId: widget.profile.id,
        question: question,
        answer: answer,
      );
    } catch (_) {
      // Saving history is helpful but must not interrupt the lesson conversation.
    }
  }

  Future<String> _requestAnswer(String question) async {
    final base = widget.apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    if (base.isEmpty) return _friendlyFallback(question);
    final response = await http
        .post(
          Uri.parse('$base/api/gemini/answer'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'lesson': widget.lesson?.lessonName.isNotEmpty == true
                ? widget.lesson!.lessonName
                : (widget.lesson?.subject.isNotEmpty == true
                    ? widget.lesson!.subject
                    : 'الدرس'),
            'question': question,
          }),
        )
        .timeout(const Duration(seconds: 18));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Tutor request failed: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body);
    final answer = payload is Map ? payload['answer']?.toString().trim() : '';
    if (answer == null || answer.isEmpty) throw Exception('Empty tutor answer');
    return '💡 $answer';
  }

  String _friendlyFallback(String question) {
    final lesson = widget.lesson?.subject;
    final topic = lesson == null || lesson.isEmpty ? 'الدرس' : lesson;
    return 'لنحلها معًا يا بطل! ابدأ بتحديد الكلمات المهمة في سؤالك عن $topic، ثم جرّب كتابة ما تعرفه أولًا. سؤالك كان: «$question»';
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: 260.ms,
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return Align(
                alignment: message.fromStudent ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 340),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: message.fromStudent
                        ? const Color(0xFF274E76)
                        : const Color(0xFF0B8693),
                    borderRadius: BorderRadius.circular(21),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x180E1B2A),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: const TextStyle(
                      color: Colors.white,
                      height: 1.55,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.08);
            },
          ),
        ),
        if (_solving)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'المعلم يفكر في أفضل إجابة... ✨',
              style: TextStyle(color: Color(0xFF0B8693), fontWeight: FontWeight.w800),
            ),
          ).animate(onPlay: (controller) => controller.repeat()).shimmer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _questionController,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _ask(),
                  decoration: const InputDecoration(
                    hintText: 'اكتب سؤالك هنا...',
                    prefixIcon: Icon(Icons.auto_awesome_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _solving ? null : _ask,
                tooltip: 'إرسال السؤال',
                icon: const Icon(Icons.send_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0B8693),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TutorMessage {
  const _TutorMessage({
    required this.text,
    required this.fromStudent,
  });

  final String text;
  final bool fromStudent;
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
        child: _GlassPanel(
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
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(225),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withAlpha(210)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180E1B2A),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: child,
    );
  }
}

Color _hexColor(String value) {
  final normalized = value.replaceFirst('#', '');
  final parsed = int.tryParse(normalized, radix: 16);
  return parsed == null ? const Color(0xFFEDB891) : Color(0xFF000000 | parsed);
}
