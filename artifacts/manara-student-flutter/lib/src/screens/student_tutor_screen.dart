import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/student_content.dart';

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
  InAppWebViewController? _controller;
  late final String? _avatarUrl;
  late final LessonContent? _avatarLesson;
  bool _loading = false;
  String? _frameError;

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.selection.url;
    _avatarLesson = widget.selection.lesson;
    _loading = _avatarUrl != null;
  }

  bool get _isLiveMeeting =>
      widget.selection.type == TutorExperienceType.liveMeeting;

  void _reload() {
    if (_avatarUrl == null) return;
    setState(() {
      _loading = true;
      _frameError = null;
    });
    _controller?.reload();
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
          child: Container(
            margin: EdgeInsets.fromLTRB(
              widget.fullscreen ? 0 : 14,
              0,
              widget.fullscreen ? 0 : 14,
              widget.fullscreen ? 0 : 18,
            ),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF101D33),
              borderRadius: BorderRadius.circular(widget.fullscreen ? 0 : 24),
              border: widget.fullscreen
                  ? null
                  : Border.all(color: const Color(0xFF5B3B87)),
            ),
            child: Stack(
              children: [
                InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(_avatarUrl!)),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    supportZoom: true,
                    supportMultipleWindows: false,
                    javaScriptCanOpenWindowsAutomatically: false,
                    transparentBackground: false,
                  ),
                  onWebViewCreated: (controller) => _controller = controller,
                  onLoadStart: (_, __) {
                    if (mounted) {
                      setState(() {
                        _loading = true;
                        _frameError = null;
                      });
                    }
                  },
                  onLoadStop: (_, __) {
                    if (mounted) setState(() => _loading = false);
                  },
                  onReceivedError: (_, request, error) {
                    if (!mounted || request.url?.toString() != _avatarUrl) return;
                    setState(() {
                      _loading = false;
                      _frameError = _isLiveMeeting
                          ? 'تعذر الاتصال بخدمة اللقاء. تحقق من الرابط ثم أعد المحاولة.'
                          : 'تعذر الاتصال بخدمة المعلم الافتراضي. حاول مرة أخرى.';
                    });
                  },
                  shouldOverrideUrlLoading: (_, action) async {
                    final target = action.request.url;
                    return target != null && target.scheme.toLowerCase() == 'https'
                        ? NavigationActionPolicy.ALLOW
                        : NavigationActionPolicy.CANCEL;
                  },
                ),
                if (_loading)
                  ColoredBox(
                    color: const Color(0xFF101D33),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFFC4B5FD)),
                          SizedBox(height: 14),
                          Text(
                            _isLiveMeeting
                                ? 'جارٍ تجهيز اللقاء المباشر...'
                                : 'جارٍ تجهيز المعلم الافتراضي...',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_frameError != null)
                  ColoredBox(
                    color: const Color(0xF0101D33),
                    child: _TutorStateCard(
                      icon: Icons.error_outline_rounded,
                      title: _isLiveMeeting
                          ? 'تعذر تحميل اللقاء المباشر'
                          : 'تعذر تحميل المعلم الافتراضي',
                      message: _frameError!,
                      actionLabel: 'إعادة المحاولة',
                      onAction: _reload,
                    ),
                  ),
              ],
            ),
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
