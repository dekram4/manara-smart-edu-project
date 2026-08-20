import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/academic_context.dart';
import '../models/student_content.dart';
import '../models/student_profile.dart';
import '../services/student_auth_service.dart';
import '../services/student_content_service.dart';
import 'student_content_screen.dart';

class StudentCinemaScreen extends StatefulWidget {
  const StudentCinemaScreen({
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
  State<StudentCinemaScreen> createState() => _StudentCinemaScreenState();
}

class _StudentCinemaScreenState extends State<StudentCinemaScreen> {
  late final StudentContentService _contentService;
  List<LessonVideo> _videos = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contentService = StudentContentService(
      widget.authService.client,
      baseUrl: widget.apiBaseUrl,
    );
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    try {
      final videos = await _contentService.fetchCinemaVideos(
        widget.profile,
        academicContext: widget.academicContext,
      );
      if (!mounted) return;
      setState(() {
        _videos = videos;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل فيديوهات سينما منارة: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F7),
      appBar: AppBar(
        title: const Text(
          'سينما منارة',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'إغلاق',
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE11D48)),
      );
    }
    if (_error != null) {
      return _CinemaStateCard(
        icon: Icons.cloud_off_rounded,
        title: 'تعذر تحميل السينما',
        message: _error!,
        actionLabel: 'إعادة المحاولة',
        onAction: () {
          setState(() => _loading = true);
          _loadVideos();
        },
      );
    }
    if (_videos.isEmpty) {
      return const _CinemaStateCard(
        icon: Icons.movie_filter_outlined,
        title: 'لا توجد فيديوهات لمسارك',
        message: 'ستظهر هنا فيديوهات المعلم والمشرف المطابقة لمسارك الأكاديمي.',
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        const Text(
          'سينما منارة',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Color(0xFF881337),
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08),
        const SizedBox(height: 5),
        Text(
          widget.academicContext?.label ??
              'فيديوهات تعليمية مرتبطة بمسارك الأكاديمي',
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Color(0xFFBE123C),
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        _CinemaCarousel(videos: _videos),
      ],
    );
  }
}

class _CinemaCarousel extends StatefulWidget {
  const _CinemaCarousel({required this.videos});

  final List<LessonVideo> videos;

  @override
  State<_CinemaCarousel> createState() => _CinemaCarouselState();
}

class _CinemaCarouselState extends State<_CinemaCarousel> {
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
          height: 330,
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
                child: _CinemaVideoCard(
                  video: video,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => VideoViewerScreen(video: video),
                    ),
                  ),
                ),
              );
            },
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
                    ? const Color(0xFFE11D48)
                    : const Color(0xFFFDA4AF),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CinemaVideoCard extends StatelessWidget {
  const _CinemaVideoCard({
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
        borderRadius: BorderRadius.circular(30),
        child: Ink(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [Color(0xFF9F1239), Color(0xFFE11D48), Color(0xFFF97316)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x559F1239),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(
                    Icons.local_movies_rounded,
                    color: Color(0xFFFFE4E6),
                    size: 38,
                  ),
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
                textAlign: TextAlign.right,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  height: 1.35,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                video.description ?? 'فيديو تعليمي من مسارك الأكاديمي',
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFFE4E6),
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('شاهد الآن'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF9F1239),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1);
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
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFFBCFE8)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 58, color: const Color(0xFFE11D48)),
              const SizedBox(height: 15),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF881337),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF9F1239),
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (onAction != null) ...[
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                  ),
                  child: Text(actionLabel ?? 'إعادة المحاولة'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}