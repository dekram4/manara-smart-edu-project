import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/student_content.dart';

/// Shows the virtual teacher configured for the current set of lessons.
///
/// Only HTTPS avatar URLs are accepted.  This is deliberately kept as a
/// separate screen so avatar providers remain inside the student application.
class StudentTutorScreen extends StatefulWidget {
  const StudentTutorScreen({
    required this.contents,
    this.liveMeeting = false,
    this.fullscreen = false,
    super.key,
  });

  final List<LessonContent> contents;
  final bool liveMeeting;
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
    final selection = _firstValidExperience(widget.contents);
    _avatarUrl = selection.$1;
    _avatarLesson = selection.$2;
    _loading = _avatarUrl != null;
  }

  /// Normalizes harmless shorthand while rejecting non-web and malformed URLs.
  ///
  /// URLs are data controlled by lesson authors, so schemes such as
  /// `javascript:`, credentials in a URL, and whitespace are never handed to
  /// the embedded browser.
  static String? normalizeAvatarUrl(String? value) {
    if (value == null) return null;
    final raw = value.trim();
    if (raw.isEmpty || RegExp(r'[\s\x00-\x1F\x7F]').hasMatch(raw)) {
      return null;
    }

    var candidate = raw;
    if (candidate.startsWith('//')) {
      candidate = 'https:$candidate';
    } else if (!candidate.contains('://') && !candidate.contains(':')) {
      candidate = 'https://$candidate';
    }

    final uri = Uri.tryParse(candidate);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri.toString();
  }

  (String?, LessonContent?) _firstValidExperience(List<LessonContent> contents) {
    for (final content in contents) {
      final url = normalizeAvatarUrl(
        widget.liveMeeting ? content.liveMeetingUrl : content.avatarInteractionUrl,
      );
      if (url != null) return (url, content);
    }
    return (null, null);
  }

  bool get _hasProvidedAvatarUrl => widget.contents.any(
        (content) => ((widget.liveMeeting
                    ? content.liveMeetingUrl
                    : content.avatarInteractionUrl) ??
                '')
            .trim()
            .isNotEmpty,
      );

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
          contents: widget.contents,
          liveMeeting: widget.liveMeeting,
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
              title: Text(widget.liveMeeting ? 'اللقاء المباشر' : 'صديقك المعلم الافتراضي'),
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
      return _TutorStateCard(
        icon: _hasProvidedAvatarUrl
            ? Icons.link_off_rounded
            : widget.liveMeeting
                ? Icons.videocam_off_rounded
                : Icons.smart_toy_outlined,
        title: _hasProvidedAvatarUrl
            ? widget.liveMeeting
                ? 'رابط اللقاء المباشر غير صالح'
                : 'رابط المعلم الافتراضي غير صالح'
            : widget.liveMeeting
                ? 'لم يتم إضافة لقاء مباشر بعد'
                : 'لم يتم إضافة رابط التفاعل بعد',
        message: _hasProvidedAvatarUrl
            ? 'يجب أن يكون الرابط آمنًا ويبدأ بـ HTTPS.'
            : widget.liveMeeting
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
                  widget.liveMeeting
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
                        : widget.liveMeeting
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
                      _frameError = error.description.isEmpty
                          ? 'تعذر الاتصال بخدمة المعلم الافتراضي.'
                          : 'تعذر تحميل خدمة المعلم الافتراضي: ${error.description}';
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
                            widget.liveMeeting
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
                      title: widget.liveMeeting
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