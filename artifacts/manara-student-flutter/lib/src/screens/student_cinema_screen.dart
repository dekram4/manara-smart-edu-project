import 'package:flutter/material.dart';

import '../models/academic_context.dart';
import '../models/student_content.dart';
import '../models/student_gamification.dart';
import '../models/student_profile.dart';
import '../services/student_auth_service.dart';
import '../services/student_content_service.dart';
import '../services/student_sound_service.dart';
import '../widgets/student_experience.dart';
import '../widgets/student_video_player.dart';

class StudentCinemaScreen extends StatefulWidget {
  const StudentCinemaScreen({
    required this.profile,
    required this.authService,
    this.academicContext,
    this.apiBaseUrl = '',
    super.key,
  });

  final StudentProfile profile;
  final StudentAuthService authService;
  final AcademicContext? academicContext;
  final String apiBaseUrl;

  @override
  State<StudentCinemaScreen> createState() => _StudentCinemaScreenState();
}

class _StudentCinemaScreenState extends State<StudentCinemaScreen> {
  static const _gemsPerVideo = 2;

  late final StudentContentService _contentService;
  final _pageController = PageController(viewportFraction: 0.9);
  List<LessonVideo> _videos = const [];
  StudentGamification _gamification = const StudentGamification();
  int _activeIndex = 0;
  bool _loading = true;
  String? _error;

  int get _unlockedVideoCount => _gamification.gems ~/ _gemsPerVideo;

  @override
  void initState() {
    super.initState();
    _contentService = StudentContentService(
      widget.authService.client,
      baseUrl: widget.apiBaseUrl,
    );
    _loadVideos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        _contentService.fetchCinemaVideos(
          widget.profile,
          academicContext: widget.academicContext,
        ),
        _contentService.fetchGamification(widget.profile),
      ]);
      if (!mounted) return;
      setState(() {
        _videos = values[0] as List<LessonVideo>;
        _gamification = values[1] as StudentGamification;
        _activeIndex = 0;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل فيديوهات السينما: $error';
      });
    }
  }

  Future<void> _openVideo(LessonVideo video, int index) async {
    if (index >= _unlockedVideoCount) {
      StudentSoundService.instance.play(StudentSoundCue.warning);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذا الفيديو مقفول. تحتاج جوهرتين لكل فيديو جديد.'),
        ),
      );
      return;
    }

    StudentSoundService.instance.play(StudentSoundCue.navigation);
    await Navigator.of(context).push(
      StudentPageRoute<void>(
        builder: (_) => _CinemaPlayerScreen(
          video: video,
          apiBaseUrl: widget.apiBaseUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071425),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071425),
        foregroundColor: Colors.white,
        title: const Text('سينما منارة'),
        actions: const [StudentSoundToggle()],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF5EEAD4)),
      );
    }
    if (_error != null) {
      return _CinemaStateCard(
        icon: Icons.cloud_off_rounded,
        title: 'تعذر تحميل السينما',
        message: _error!,
        actionLabel: 'إعادة المحاولة',
        onAction: _loadVideos,
      );
    }
    if (_videos.isEmpty) {
      return const _CinemaStateCard(
        icon: Icons.movie_filter_outlined,
        title: 'لا توجد فيديوهات متاحة',
        message: 'ستظهر هنا فيديوهات المعلم والمشرف المطابقة لمسارك الأكاديمي.',
      );
    }

    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final activeIndex = _activeIndex.clamp(0, _videos.length - 1).toInt();
    final activeVideo = _videos[activeIndex];
    return StudentEntrance(
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      children: [
        const StudentScreenHero(
          title: 'شاهد وتعلّم',
          subtitle: 'فيديوهات آمنة ومطابقة لمسارك الأكاديمي.',
          icon: Icons.movie_filter_rounded,
          colors: [Color(0xFF0B5D66), Color(0xFF0B8693)],
          dark: true,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1D4ED8),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            '💎 الجواهر: ${_gamification.gems}  |  المفتوح: $_unlockedVideoCount من ${_videos.length}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'كل فيديو جديد يحتاج جوهرتين لفتحه. المشاهدة لا تمنح XP أو جواهر.',
          textAlign: TextAlign.right,
          style: TextStyle(color: Color(0xFFB3C8DE), fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 310,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _videos.length,
            onPageChanged: (index) {
              if (index < _videos.length) {
                setState(() => _activeIndex = index);
              }
            },
            itemBuilder: (context, index) {
              final video = _videos[index];
              final locked = index >= _unlockedVideoCount;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _CinemaVideoCard(
                  video: video,
                  apiBaseUrl: widget.apiBaseUrl,
                  locked: locked,
                  onPressed: () => _openVideo(video, index),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _videos.length,
            (index) => AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              width: index == _activeIndex ? 28 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: index == _activeIndex
                    ? const Color(0xFF5EEAD4)
                    : const Color(0xFF49617C),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _CinemaDetails(
          video: activeVideo,
          locked: activeIndex >= _unlockedVideoCount,
          onPressed: () => _openVideo(activeVideo, activeIndex),
        ),
      ],
      ),
    );
  }
}

class _CinemaVideoCard extends StatelessWidget {
  const _CinemaVideoCard({
    required this.video,
    required this.apiBaseUrl,
    required this.locked,
    required this.onPressed,
  });

  final LessonVideo video;
  final String apiBaseUrl;
  final bool locked;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return StudentVideoHoverPreview(
      video: video,
      apiBaseUrl: apiBaseUrl,
      enabled: !locked,
      borderRadius: const BorderRadius.all(Radius.circular(26)),
      child: StudentPressScale(
        child: Material(
        color: const Color(0xFF132337),
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(
                    Icons.movie_filter_rounded,
                    color: Color(0xFF5EEAD4),
                    size: 46,
                  ),
                  locked
                      ? const Icon(Icons.lock_rounded, color: Color(0xFFFFD166), size: 32)
                      : _VideoTypeBadge(sourceType: video.sourceType),
                ],
              ),
              const Spacer(),
              Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                locked
                    ? 'تحتاج جوهرتين لكل فيديو جديد لفتحه.'
                    : video.description ?? 'اضغط للمشاهدة داخل التطبيق',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFFB3C8DE),
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onPressed,
                icon: Icon(locked ? Icons.lock_rounded : Icons.play_arrow_rounded),
                label: Text(locked ? 'مقفول — تحتاج جوهرتين' : 'شاهد الآن'),
                style: FilledButton.styleFrom(
                  backgroundColor: locked ? const Color(0xFF4B5563) : const Color(0xFF5EEAD4),
                  foregroundColor: locked ? Colors.white : const Color(0xFF071425),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
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

class _CinemaDetails extends StatelessWidget {
  const _CinemaDetails({
    required this.video,
    required this.locked,
    required this.onPressed,
  });

  final LessonVideo video;
  final bool locked;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Student3DCard(
      child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF132337),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF274E76)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: onPressed,
            tooltip: locked ? 'يتطلب جوهرتين' : 'فتح المشغل',
            icon: const Icon(
              Icons.fullscreen_rounded,
              color: Color(0xFF5EEAD4),
              size: 30,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _VideoTypeBadge extends StatelessWidget {
  const _VideoTypeBadge({required this.sourceType});

  final VideoSourceType sourceType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        sourceType == VideoSourceType.mp4 ? 'MP4' : 'يوتيوب',
        style: const TextStyle(
          color: Color(0xFFBFFBFA),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CinemaPlayerScreen extends StatelessWidget {
  const _CinemaPlayerScreen({
    required this.video,
    required this.apiBaseUrl,
  });

  final LessonVideo video;
  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
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
}

class _CinemaStateCard extends StatelessWidget {
  const _CinemaStateCard({
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
            color: const Color(0xFF132337),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF5EEAD4), size: 54),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB3C8DE),
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (onAction != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel ?? 'إعادة المحاولة'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5EEAD4),
                    side: const BorderSide(color: Color(0xFF5EEAD4)),
                  ),
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
