import 'dart:async';

import 'package:flutter/material.dart';

import '../models/student_content.dart';
import '../services/meeting_links.dart';
import '../services/student_media_permissions.dart';
import '../services/student_settings.dart';
import '../l10n/student_strings.dart';
import '../services/student_sound_service.dart';
import '../widgets/portal_watermark.dart';
import '../widgets/student_avatar_view.dart';
import '../widgets/student_experience.dart';
import '../widgets/did_agent_embed.dart';
import '../widgets/tutor_embed.dart';

/// Shows the virtual teacher configured for one selected academic path.
///
/// Only HTTPS avatar URLs are accepted.  This is deliberately kept as a
/// separate screen so avatar providers remain inside the student application.
class StudentTutorScreen extends StatefulWidget {
  const StudentTutorScreen({
    required this.selection,
    required this.apiBaseUrl,
    this.fullscreen = false,
    super.key,
  });

  final TutorExperienceSelection selection;
  final String apiBaseUrl;
  final bool fullscreen;

  @override
  State<StudentTutorScreen> createState() => _StudentTutorScreenState();
}

class _StudentTutorScreenState extends State<StudentTutorScreen> {
  var _embedRevision = 0;

  /// صفحةُ ويبٍ بديلةٌ حمّلناها بدل رابط تطبيقٍ طلبته صفحةُ الاجتماع. انظر
  /// [_onAppLink].
  String? _fallbackUrl;

  /// ما حُمّل من صفحاتٍ بديلة: صفحةٌ تطلب التطبيقَ مرّةً ثانية بعد تحميل
  /// بديلتها تدور في حلقة، فلا تُحمَّل البديلةُ مرّتين.
  final Set<String> _fallbacksTried = {};

  @override
  void initState() {
    super.initState();
    // Asked for here, before the page loads, rather than left to the
    // WebView. The embed grants its own getUserMedia request, but on
    // Android that only works if the app already holds the runtime
    // permission — and when it does not, the failure surfaces inside the
    // page as "open this in a browser", which is the last thing to show a
    // child. The live class asks for the camera as well: it is video.
    unawaited(
      _isLiveMeeting
          ? StudentMediaPermissions.requestForMeeting()
          : StudentMediaPermissions.requestForTutor(),
    );
  }

  String? get _avatarUrl => widget.selection.url;
  LessonContent? get _avatarLesson => widget.selection.lesson;

  /// ما يُحمَّل في الإطار: رابطُ الدرس، أو بديلتُه حين طلبت صفحتُه تطبيقاً.
  String? get _embedUrl => _fallbackUrl ?? _avatarUrl;

  bool get _isLiveMeeting =>
      widget.selection.type == TutorExperienceType.liveMeeting;

  /// D-ID Studio is the content-authoring dashboard. It depends on a creator
  /// login session and cannot be used as the embedded teacher. D-ID Agents
  /// must be shared or embedded through their Agent Embed configuration.
  bool get _isDIdStudioUrl {
    final host = Uri.tryParse(_avatarUrl ?? '')?.host.toLowerCase() ?? '';
    return host == 'studio.d-id.com' || host.endsWith('.studio.d-id.com');
  }

  /// صفحةُ الاجتماع طلبت تطبيقَها (`intent://` من Meet، `zoomus://` من Zoom).
  ///
  /// ── ولا يُغادَر التطبيق ──
  /// الطلبُ يُترجم إلى صفحة الويب البديلة وتُحمَّل في الإطار نفسه. وما لا بديلَ
  /// له يُقال للطفل بجملةٍ يفهمها — لا يُسقط بصمتٍ كما كان، ولا يُخرجه إلى
  /// تطبيقٍ لا يعرف كيف يعود منه.
  void _onAppLink(Uri requested) {
    final fallback = MeetingLinks.webFallback(requested)?.toString();
    if (fallback != null && _fallbacksTried.add(fallback)) {
      setState(() {
        _fallbackUrl = fallback;
        _embedRevision++;
      });
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: Text(
          tr('tutor.meetingNeedsApp'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  /// «إعادة الاتصال»: الاجتماعُ من رابطه الأصليّ، في الإطار نفسه.
  void _reload() {
    if (_avatarUrl == null) return;
    StudentSoundService.instance.playTap();
    setState(() {
      _fallbackUrl = null;
      _fallbacksTried.clear();
      _embedRevision++;
    });
  }

  void _openFullscreen() {
    StudentSoundService.instance.playTap();
    Navigator.of(context).push(
      StudentPageRoute<void>(
        builder: (_) => StudentTutorScreen(
          selection: widget.selection,
          apiBaseUrl: widget.apiBaseUrl,
          fullscreen: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Directionality(
      textDirection: StudentSettings.direction,
      child: _buildBody(),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF17364F),
      appBar: widget.fullscreen
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF17364F),
              foregroundColor: Colors.white,
              title: Text(_isLiveMeeting ? tr('tutor.meetingTitle') : tr('tutor.title')),
              actions: [
                const StudentSoundToggle(),
                IconButton(
                  onPressed: _avatarUrl == null ? null : _reload,
                  tooltip: tr('tutor.reload'),
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  onPressed: _avatarUrl == null ? null : _openFullscreen,
                  tooltip: tr('tutor.fullscreen'),
                  icon: const Icon(Icons.fullscreen_rounded),
                ),
              ],
            ),
      // The virtual teacher and the live meeting are the same screen with
      // different content, so the background follows the experience type.
      body: widget.fullscreen
          ? Stack(
              children: [
                PortalWatermark(
                  asset: _isLiveMeeting
                      ? PortalBackgrounds.liveMeeting
                      : PortalBackgrounds.tutor,
                  dark: true,
                ),
                Positioned.fill(child: body),
                SafeArea(
                  child: Align(
                    // Directional, not topLeft: the way out of a screen
                    // belongs on the edge the reader starts from — top
                    // right in Arabic, top left in English — the same
                    // corner the app bar's back button occupies
                    // everywhere else.
                    alignment: AlignmentDirectional.topStart,
                    child: IconButton.filledTonal(
                      onPressed: () {
                        StudentSoundService.instance.playTap();
                        Navigator.of(context).pop();
                      },
                      tooltip: tr('tutor.exitFullscreen'),
                      icon: const Icon(Icons.fullscreen_exit_rounded),
                    ),
                  ),
                ),
              ],
            )
          : Stack(
              children: [
                PortalWatermark(
                  asset: _isLiveMeeting
                      ? PortalBackgrounds.liveMeeting
                      : PortalBackgrounds.tutor,
                  dark: true,
                ),
                body,
              ],
            ),
    );
  }

  Widget _buildBody() {
    if (_avatarUrl == null) {
      final missingContext =
          widget.selection.status == TutorExperienceStatus.missingAcademicContext;
      final unsafeUrl = widget.selection.status == TutorExperienceStatus.unsafeUrl;
      return StudentEntrance(
        child: _TutorStateCard(
          icon: unsafeUrl
              ? Icons.link_off_rounded
              : missingContext
                  ? Icons.school_outlined
                  : _isLiveMeeting
                  ? Icons.videocam_off_rounded
                  : Icons.smart_toy_outlined,
          title: unsafeUrl
              ? _isLiveMeeting
                  ? tr('tutor.badMeetingLink')
                  : tr('tutor.badLink')
              : missingContext
                  ? tr('tutor.pickPath')
                  : _isLiveMeeting
                  ? tr('tutor.noMeeting')
                  : tr('tutor.noLink'),
          message: unsafeUrl
              ? tr('tutor.httpsOnly')
              : missingContext
                  ? tr('tutor.pickPathBody')
                  : _isLiveMeeting
                  ? tr('tutor.noMeetingBody')
                  : tr('tutor.noLinkBody'),
        ),
      );
    }

    if (_isDIdStudioUrl) {
      return StudentEntrance(
        child: DIdAgentEmbed(
          apiBaseUrl: widget.apiBaseUrl,
          directUrl: _avatarUrl,
        ),
      );
    }

    return Column(
      children: [
        if (!widget.fullscreen)
          StudentEntrance(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  StudentCardAvatar(
                    icon: _isLiveMeeting
                        ? Icons.videocam_rounded
                        : Icons.smart_toy_rounded,
                    accent: const Color(0xFFC4B5FD),
                    size: 48,
                    label: _isLiveMeeting ? tr('tutor.meetingTitle') : tr('tutor.short'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _avatarLesson?.lessonName.trim().isNotEmpty == true
                          ? _avatarLesson!.lessonName
                          : _isLiveMeeting
                              ? tr('tutor.meetingReady')
                              : tr('tutor.ready'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // This screen builds its own header rather than using
                  // StudentScreenHero, so it needs the student's character
                  // added explicitly — otherwise the teacher and the live
                  // meeting would be the only cards without it.
                  const StudentAvatarView(size: 48),
                ],
              ),
            ),
          ),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: StudentEntrance(
                  delay: const Duration(milliseconds: 100),
                  child: Container(
                    margin: EdgeInsets.fromLTRB(
                      widget.fullscreen ? 0 : 14,
                      0,
                      widget.fullscreen ? 0 : 14,
                      0,
                    ),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D3B55),
                      borderRadius: BorderRadius.circular(widget.fullscreen ? 0 : 24),
                      border: widget.fullscreen
                          ? null
                          : Border.all(color: const Color(0xFF5B3B87)),
                    ),
                    child: TutorEmbed(
                      key: ValueKey('${_embedUrl!}:$_embedRevision'),
                      url: _embedUrl!,
                      title: _isLiveMeeting ? tr('tutor.meetingTitle') : tr('tutor.short'),
                      // اللقاءُ وحده يحوّل روابطَ تطبيقاته إلى صفحاتها في
                      // الإطار نفسه؛ المعلمُ الافتراضيّ يُسقطها كما كان.
                      onAppLink: _isLiveMeeting ? _onAppLink : null,
                    ),
                  ),
                ),
              ),
              if (_isLiveMeeting)
                StudentEntrance(
                  delay: const Duration(milliseconds: 200),
                  child: Container(
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
                        Expanded(
                          child: Text(
                            // Meet يرفض التشغيلَ داخل التطبيقات في أحيانٍ كثيرة:
                            // يُقال ذلك صراحةً بدل إطارٍ فارغٍ بلا تفسير.
                            MeetingLinks.isGoogleMeet(_avatarUrl)
                                ? tr('tutor.googleMeetHint')
                                : tr('tutor.meetingHint'),
                            textAlign: TextAlign.start,
                            style: const TextStyle(color: Color(0xFFC8D5E5), fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(tr('tutor.reconnect')),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TutorStateCard extends StatelessWidget {
  const _TutorStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

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
          ],
        ),
      ),
    );
  }
}
