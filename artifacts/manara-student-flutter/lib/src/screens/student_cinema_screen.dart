import 'package:flutter/material.dart';
import '../widgets/lively.dart';
import '../theme/motion.dart';

import '../models/academic_context.dart';
import '../models/cinema_unlock.dart';
import '../models/student_content.dart';
import '../models/student_gamification.dart';
import '../models/student_profile.dart';
import '../services/student_auth_service.dart';
import '../services/student_content_service.dart';
import '../l10n/student_strings.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../widgets/video_thumbnail_card.dart';
import '../widgets/portal_watermark.dart';
import '../widgets/student_experience.dart';
import '../widgets/student_video_player.dart';
import '../widgets/video_rows.dart';

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
  late final StudentContentService _contentService;
  List<LessonVideo> _videos = const [];
  StudentGamification _gamification = const StudentGamification();
  bool _loading = true;
  String? _error;
  bool _checkingLocked = false;

  int get _unlockedVideoCount =>
      CinemaUnlockRules.unlockedCount(_gamification.gems);

  @override
  void initState() {
    super.initState();
    _contentService = StudentContentService(
      widget.authService.client,
      baseUrl: widget.apiBaseUrl,
      authService: widget.authService,
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
      final values = await Future.wait<Object>([
        _contentService.fetchCinemaVideos(
          widget.profile,
          academicContext: widget.academicContext,
        ),
        // تعذّرُ قراءة الرصيد لا يُسقط السينما كلّها: يُعرض آخرُ رصيدٍ معروف
        // من حساب الطالب، ويُعاد السؤالُ عنه عند لمس فيديو مقفل.
        _contentService
            .fetchGamification(widget.profile)
            .catchError((Object _) => widget.profile.gamification),
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
        // بطاقةٌ أُغلقت بعد فتح الواجهة: رسالتُها كما هي، لا «تعذّر التحميل».
        _error = error is StudentCardLockedException
            ? error.toString()
            : trf('cinema.loadError', {'error': error});
      });
    }
  }

  /// نافذةُ الفيديو المقفل: كم معك، وكم يحتاج، وكيف تكسب الباقي — وزرّان
  /// يأخذان الطالب إلى حيث يكسب الجواهر فعلاً (شرح الدرس والاختبارات).
  Future<void> _showLockedDialog(int index) async {
    final gems = _gamification.gems;
    final route = await showMotionDialog<CinemaEarnRoute>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: StudentSettings.direction,
        child: AlertDialog(
          icon: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: MotionColors.teal,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: MotionColors.lockYellow,
              size: 34,
            ),
          ),
          title: Text(
            tr('cinema.lockedTitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                trf('cinema.lockedStatus', {
                  'gems': gems,
                  'required': CinemaUnlockRules.requiredGems(index),
                  'missing': CinemaUnlockRules.missingGems(index, gems),
                }),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, height: 1.5),
              ),
              const SizedBox(height: 14),
              Text(
                tr('cinema.howToEarn'),
                style: const TextStyle(fontWeight: FontWeight.w700, height: 1.6),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsOverflowAlignment: OverflowBarAlignment.center,
          actions: [
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(CinemaEarnRoute.lesson),
              icon: const Icon(Icons.play_lesson_rounded),
              label: Text(tr('cinema.goLesson')),
            ),
            FilledButton.tonalIcon(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(CinemaEarnRoute.quiz),
              icon: const Icon(Icons.quiz_rounded),
              label: Text(tr('cinema.goQuiz')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(tr('action.close')),
            ),
          ],
        ),
      ),
    );
    // تُغلق السينما وتفتح الواجهةُ البطاقةَ المطلوبة — بفحص صلاحياتها
    // المعتاد، فبطاقةٌ أغلقها المعلم لا تُفتح من هنا.
    if (route != null && mounted) Navigator.of(context).pop(route);
  }

  Future<void> _openVideo(LessonVideo video, int index) async {
    if (!CinemaUnlockRules.isUnlocked(index, _gamification.gems)) {
      if (_checkingLocked) return;
      // ── الرصيدُ أولاً من المصدر ──
      // لعلّ الطالب كسب جواهر منذ فُتحت السينما (من جهازٍ آخر أو بطاقةٍ
      // أخرى). فإن كفى الرصيدُ الجديد فُتح الفيديو مباشرةً.
      _checkingLocked = true;
      try {
        final fresh = await _contentService
            .fetchGamification(widget.profile)
            .timeout(const Duration(seconds: 4));
        if (mounted) setState(() => _gamification = fresh);
      } catch (_) {
        // يبقى الرصيد المعروف.
      } finally {
        _checkingLocked = false;
      }
      if (!mounted) return;
      if (!CinemaUnlockRules.isUnlocked(index, _gamification.gems)) {
        StudentSoundService.instance.play(StudentSoundCue.warning);
        await _showLockedDialog(index);
        return;
      }
      StudentSoundService.instance.play(StudentSoundCue.success);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('cinema.unlockedNow'))),
      );
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
        title: Text(tr('cinema.title')),
        actions: const [StudentSoundToggle()],
      ),
      body: Stack(
        children: [
          const PortalWatermark(asset: PortalBackgrounds.cinema, dark: true),
          // انتقال القسم (مواصفة الحركة §5.4): تعتيمٌ ومُحمِّلُ الشخصيتين حتى
          // تصل الفيديوهات، ثم يتلاشى الغطاء في 240ms.
          MotionSectionOverlay(
            ready: !_loading,
            label: tr('widget.loading'),
            child: _loading ? const SizedBox.expand() : _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _CinemaStateCard(
        icon: Icons.cloud_off_rounded,
        title: tr('cinema.loadFailed'),
        message: _error!,
        actionLabel: tr('action.retry'),
        onAction: _loadVideos,
      );
    }
    if (_videos.isEmpty) {
      return _CinemaStateCard(
        icon: Icons.movie_filter_outlined,
        title: tr('cinema.empty'),
        message: tr('cinema.emptyBody'),
      );
    }

    // ‏تمريرٌ واحد: الرأسُ ثم صفوفُ الفيديو كسولةً بلا حدٍّ لعددها
    // ‏([SliverVideoRows]) — لا شبكةٌ بنسبة ارتفاعٍ ثابتة تقصّ البطاقة.
    return StudentEntrance(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverList.list(
        children: [
          StudentScreenHero(
            title: tr('cinema.subtitle'),
            subtitle: tr('cinema.blurb'),
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
                    label: tr('cinema.gems'),
                    value: '${_gamification.gems}',
                  ),
                  const SizedBox(width: 10),
                  _CinemaBadge(
                    icon: Icons.lock_open_rounded,
                    tint: const Color(0xFFFFD166),
                    label: tr('cinema.unlocked'),
                    value: '$_unlockedVideoCount / ${_videos.length}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr('cinema.gemRule'),
            textAlign: TextAlign.start,
            style: const TextStyle(
              color: Color(0xFFB3C8DE),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
        ],
            ),
          ),
          // Covers the way a video library reads — one column on a phone,
          // more as the screen widens — each row as tall as its content.
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            sliver: SliverVideoRows(
            itemCount: _videos.length,
            itemBuilder: (context, index) {
              final video = _videos[index];
              return LivelyStagger(
                index: index,
                child: _CinemaVideoCard(
                video: video,
                apiBaseUrl: widget.apiBaseUrl,
                locked: index >= _unlockedVideoCount,
                missingGems:
                    CinemaUnlockRules.missingGems(index, _gamification.gems),
                onPressed: () => _openVideo(video, index),
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
        color: Colors.black.withValues(alpha: 0.45),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(7, 6, 14, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.20),
              Colors.white.withValues(alpha: 0.07),
            ],
          ),
          border: Border.all(color: tint.withValues(alpha: 0.55), width: 1.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint.withValues(alpha: 0.22),
                border: Border.all(color: tint.withValues(alpha: 0.8)),
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
                    color: tint.withValues(alpha: 0.9),
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
    required this.missingGems,
    required this.onPressed,
  });

  final LessonVideo video;
  final String apiBaseUrl;
  final bool locked;
  final int missingGems;
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
              ? trf('cinema.lockedNeed', {'missing': missingGems})
              : video.description ?? tr('cinema.watchHint'),
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
    // دخول المشغّل (مواصفة الحركة §5.7): أسودُ بمؤشّرٍ وزرّ إغلاق، ثم تظهر
    // الشاشة من 0.96 إلى 1. المشغّلُ نفسه يُبنى من اللحظة الأولى تحت الأسود،
    // فيبدأ التحميل ولا يُنتظر.
    return MotionPlayerEntrance(child: _buildScaffold(context));
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF17364F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17364F),
        foregroundColor: Colors.white,
        title: Text(video.title),
      ),
      // Top-aligned and full width, matching the lesson player: a 16:9
      // strip centred in a tall body reads as a small video adrift in
      // black, which is what was reported for the cinema too.
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
                    label: Text(actionLabel ?? tr('action.retry')),
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
