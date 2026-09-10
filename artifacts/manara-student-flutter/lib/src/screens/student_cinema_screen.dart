import 'package:flutter/material.dart';

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
  static const _gemsPerVideo = 5;

  late final StudentContentService _contentService;
  List<LessonVideo> _videos = const [];
  StudentGamification _gamification = const StudentGamification();
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
          content: Text('هذا الفيديو مقفول. تحتاج 5 جواهر لكل فيديو جديد.'),
        ),
      );
      return;
    }

    StudentSoundService.instance.playTap();
    await Navigator.of(context).push(
      StudentPageRoute<void>(
        builder: (_) =>
            _CinemaPlayerScreen(video: video, apiBaseUrl: widget.apiBaseUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF17364F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17364F),
        foregroundColor: Colors.white,
        title: const Text('سينما منارة'),
        actions: const [StudentSoundToggle()],
      ),
      body: Stack(
        children: [
          const PortalWatermark(asset: PortalBackgrounds.cinema, dark: true),
          _buildBody(),
        ],
      ),
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
          // Two translucent capsules instead of one solid blue slab, so
          // the gem count and the unlock count read as separate facts.
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CinemaBadge(
                    icon: Icons.diamond_rounded,
                    tint: const Color(0xFF5EEAD4),
                    label: 'الجواهر',
                    value: '${_gamification.gems}',
                  ),
                  const SizedBox(width: 10),
                  _CinemaBadge(
                    icon: Icons.lock_open_rounded,
                    tint: const Color(0xFFFFD166),
                    label: 'المفتوح',
                    value: '$_unlockedVideoCount / ${_videos.length}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'كل 5 جواهر تفتح فيديو واحدًا. مشاهدة السينما لا تمنح مكافآت.',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Color(0xFFB3C8DE),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          // A grid of covers, the way a video library reads — one column on
          // a phone, more as the screen widens, so it adapts to tablets and
          // to either orientation without a breakpoint list.
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _videos.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 330,
              mainAxisSpacing: 18,
              crossAxisSpacing: 14,
              // Cover (16:9) plus the two lines of text under it.
              childAspectRatio: 1.30,
            ),
            itemBuilder: (context, index) {
              final video = _videos[index];
              return _CinemaVideoCard(
                video: video,
                apiBaseUrl: widget.apiBaseUrl,
                locked: index >= _unlockedVideoCount,
                onPressed: () => _openVideo(video, index),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A translucent capsule for one cinema statistic: a tinted icon disc, the
/// number, and its label. Deliberately semi-transparent with a bright rim
/// so it sits on the dark room without becoming another solid block.
class _CinemaBadge extends StatelessWidget {
  const _CinemaBadge({
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.black.withOpacity(0.45),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(7, 6, 14, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.20),
              Colors.white.withOpacity(0.07),
            ],
          ),
          border: Border.all(color: tint.withOpacity(0.55), width: 1.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint.withOpacity(0.22),
                border: Border.all(color: tint.withOpacity(0.8)),
              ),
              child: Icon(icon, color: tint, size: 17),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: tint.withOpacity(0.9),
                    fontSize: 9.5,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
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
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: StudentPressScale(
        child: VideoThumbnailCard(
          video: video,
          dark: true,
          locked: locked,
          onTap: onPressed,
          subtitle: locked
              ? 'مقفول — تحتاج 5 جواهر لفتحه'
              : video.description ?? 'اضغط للمشاهدة داخل التطبيق',
        ),
      ),
    );
  }
}


class _CinemaPlayerScreen extends StatelessWidget {
  const _CinemaPlayerScreen({required this.video, required this.apiBaseUrl});

  final LessonVideo video;
  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF17364F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17364F),
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
              color: const Color(0xFF224863),
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
