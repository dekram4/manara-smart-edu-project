import 'package:flutter/material.dart';

import '../models/student_content.dart';
import '../widgets/student_video_player.dart';

/// Shows the virtual teacher configured for one selected academic path.
///
/// Only HTTPS avatar URLs are accepted.  This is deliberately kept as a
/// separate screen so avatar providers remain inside the student application.
class StudentTutorScreen extends StatefulWidget {
  const StudentTutorScreen({
    required this.selection,
    this.fullscreen = false,
    super.key,
  });

  final TutorExperienceSelection selection;
  final bool fullscreen;

  @override
  State<StudentTutorScreen> createState() => _StudentTutorScreenState();
}

class _StudentTutorScreenState extends State<StudentTutorScreen> {
  var _embedRevision = 0;
  var _showInlineMeeting = false;

  String? get _avatarUrl => widget.selection.url;
  LessonContent? get _avatarLesson => widget.selection.lesson;

  bool get _isLiveMeeting =>
      widget.selection.type == TutorExperienceType.liveMeeting;

  bool get _isBlockedMeetingEmbed {
    if (!_isLiveMeeting || _avatarUrl == null || _showInlineMeeting) return false;
    final host = Uri.tryParse(_avatarUrl!)?.host.toLowerCase() ?? '';
    return host == 'meet.google.com' ||
        host == 'zoom.us' ||
        host.endsWith('.zoom.us') ||
        host == 'teams.microsoft.com' ||
        host.endsWith('.teams.microsoft.com') ||
        host == 'webex.com' ||
        host.endsWith('.webex.com');
  }

  void _joinMeeting() {
    if (_avatarUrl == null) return;
    setState(() {
      _showInlineMeeting = true;
      _embedRevision++;
    });
  }

  void _reload() {
    if (_avatarUrl == null) return;
    setState(() => _embedRevision++);
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentTutorScreen(
          selection: widget.selection,
          fullscreen: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Directionality(
      textDirection: TextDirection.rtl,
      child: _buildBody(),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF071425),
      appBar: widget.fullscreen
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF071425),
              foregroundColor: Colors.white,
              title: Text(_isLiveMeeting ? 'اللقاء المباشر' : 'صديقك المعلم الافتراضي'),
              actions: [
                IconButton(
                  onPressed: _avatarUrl == null ? null : _reload,
                  tooltip: 'إعادة التحميل',
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  onPressed: _avatarUrl == null ? null : _openFullscreen,
                  tooltip: 'ملء الشاشة',
                  icon: const Icon(Icons.fullscreen_rounded),
                ),
              ],
            ),
      body: widget.fullscreen
          ? Stack(
              children: [
                Positioned.fill(child: body),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'إنهاء ملء الشاشة',
                      icon: const Icon(Icons.fullscreen_exit_rounded),
                    ),
                  ),
                ),
              ],
            )
          : body,
    );
  }

  Widget _buildBody() {
    if (_avatarUrl == null) {
      final missingContext =
          widget.selection.status == TutorExperienceStatus.missingAcademicContext;
      final unsafeUrl = widget.selection.status == TutorExperienceStatus.unsafeUrl;
      return _TutorStateCard(
        icon: unsafeUrl
            ? Icons.link_off_rounded
            : missingContext
                ? Icons.school_outlined
                : _isLiveMeeting
                ? Icons.videocam_off_rounded
                : Icons.smart_toy_outlined,
        title: unsafeUrl
            ? _isLiveMeeting
                ? 'رابط اللقاء المباشر غير صالح'
                : 'رابط المعلم الافتراضي غير صالح'
            : missingContext
                ? 'اختر مسارك الدراسي أولًا'
                : _isLiveMeeting
                ? 'لم يتم إضافة لقاء مباشر بعد'
                : 'لم يتم إضافة رابط التفاعل بعد',
        message: unsafeUrl
            ? 'يجب أن يكون الرابط آمنًا ويبدأ بـ HTTPS.'
            : missingContext
                ? 'اختر الصف والفصل والمادة والترم والوحدة، ثم افتح التجربة الخاصة بالدرس.'
                : _isLiveMeeting
                ? 'سيظهر اللقاء هنا عندما يضيف المعلم رابطًا للدرس.'
                : 'سيظهر صديقك المعلم هنا عندما يضيف المعلم رابط التفاعل للدرس.',
      );
    }

    if (_isBlockedMeetingEmbed) {
      return _BlockedMeetingCard(onJoin: _joinMeeting);
    }

    return Column(
      children: [
        if (!widget.fullscreen)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Icon(
                  _isLiveMeeting
                      ? Icons.videocam_rounded
                      : Icons.smart_toy_rounded,
                  color: Color(0xFFC4B5FD),
                  size: 34,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _avatarLesson?.lessonName.trim().isNotEmpty == true
                        ? _avatarLesson!.lessonName
                        : _isLiveMeeting
                            ? 'اللقاء المباشر جاهز للانضمام'
                            : 'صديقك الذكي مستعد للعب والكلام!',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(
                    widget.fullscreen ? 0 : 14,
                    0,
                    widget.fullscreen ? 0 : 14,
                    0,
                  ),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFF101D33),
                    borderRadius: BorderRadius.circular(widget.fullscreen ? 0 : 24),
                    border: widget.fullscreen
                        ? null
                        : Border.all(color: const Color(0xFF5B3B87)),
                  ),
                  child: StudentVideoPlayer(
                    key: ValueKey('${_avatarUrl!}:$_embedRevision'),
                    video: LessonVideo(
                      id: 'tutor-${_avatarLesson?.id ?? 'experience'}',
                      url: _avatarUrl!,
                      sourceType: VideoSourceType.embed,
                      title: _isLiveMeeting ? 'اللقاء المباشر' : 'المعلم الافتراضي',
                    ),
                    autoPlay: false,
                    allowInteractivePermissions: true,
                  ),
                ),
              ),
              if (_isLiveMeeting)
                Container(
                  margin: EdgeInsets.fromLTRB(
                    widget.fullscreen ? 0 : 14,
                    10,
                    widget.fullscreen ? 0 : 14,
                    widget.fullscreen ? 0 : 18,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: const Color(0xFF0B1628),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'استخدم زر الاتصال إذا لم يعمل الاجتماع داخل الصفحة.',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: Color(0xFFC8D5E5), fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _joinMeeting,
                        child: const Text('اتصال بالاجتماع'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BlockedMeetingCard extends StatelessWidget {
  const _BlockedMeetingCard({required this.onJoin});

  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Card(
          color: const Color(0xFF101D33),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_rounded, color: Color(0xFFFB7185), size: 58),
                const SizedBox(height: 14),
                const Text(
                  'الاجتماع جاهز للانضمام',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                const Text(
                  'اضغط للاتصال وعرض الاجتماع داخل بطاقة منارة المعرفة. قد تحتاج إلى السماح بالكاميرا والميكروفون عند طلبهما.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFC8D5E5), height: 1.6, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onJoin,
                  icon: const Icon(Icons.videocam_rounded),
                  label: const Text('الاتصال بالاجتماع'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorStateCard extends StatelessWidget {
  const _TutorStateCard({
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFC4B5FD), size: 56),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFC8D5E5),
                height: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel ?? 'إعادة المحاولة'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC4B5FD),
                  foregroundColor: const Color(0xFF1D1035),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
