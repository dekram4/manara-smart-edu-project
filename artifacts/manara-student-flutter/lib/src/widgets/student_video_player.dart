import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart';

import '../models/student_content.dart';
import 'student_experience.dart';

/// A realistic, up to date mobile-Chrome user agent.
///
/// Android's system WebView appends a " wv" (WebView) token to its default
/// user agent. YouTube's embed player treats that token as "unsupported
/// browser" and refuses playback with error 153, even though the exact same
/// device renders the embed fine in real Chrome. Overriding the WebView user
/// agent with a normal browser string — and skipping the override on
/// iOS/macOS, where WKWebView already reports a standard Safari UA — is the
/// standard fix.
const String _kAndroidWebViewUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

/// A realistic mobile-Safari user agent, used on iOS/macOS so direct video
/// requests present a browser identity that matches the platform actually
/// making them (AVFoundation otherwise identifies itself as a bare media
/// player, which some CDNs treat as a hotlinking client and reject).
const String _kApplePlatformUserAgent =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 '
    'Mobile/15E148 Safari/604.1';

/// The user agent presented to the in-app browser used for YouTube/Vimeo
/// embeds. `null` leaves the platform default (already a normal browser UA
/// on iOS/macOS/Windows) untouched.
String? get _webViewUserAgent =>
    (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
        ? _kAndroidWebViewUserAgent
        : null;

/// The user agent sent with direct MP4/HLS network requests. Some CDNs
/// (and YouTube's redirect chain when a raw video URL is resolved from it)
/// reject requests from generic HTTP clients that don't look like a browser.
String get _videoRequestUserAgent => (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS))
    ? _kApplePlatformUserAgent
    : _kAndroidWebViewUserAgent;

/// Picks a `Referer` header matching the video's own origin. Sending a
/// same-origin referer is accepted by virtually every hotlink-protection
/// and embed-permission check (YouTube, Vimeo, Supabase Storage, generic
/// CDNs), whereas sending no `Referer` at all — the default for Flutter's
/// native HTTP clients — is what a number of providers block outright.
String _refererFor(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return 'https://www.youtube.com/';
  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  if (isYoutubeHost(host)) return 'https://www.youtube.com/';
  if (host == 'vimeo.com' || host.endsWith('.vimeo.com')) {
    return 'https://player.vimeo.com/';
  }
  return '${uri.scheme}://${uri.host}/';
}

/// Plays a short, muted preview only while a desktop pointer is over a card.
/// The underlying player is mounted lazily, so scrolling a library does not
/// open every video connection at once.
class StudentVideoHoverPreview extends StatefulWidget {
  const StudentVideoHoverPreview({
    required this.video,
    required this.apiBaseUrl,
    required this.child,
    this.enabled = true,
    this.previewDuration = const Duration(seconds: 3),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    super.key,
  });

  final LessonVideo video;
  final String apiBaseUrl;
  final Widget child;
  final bool enabled;
  final Duration previewDuration;
  final BorderRadius borderRadius;

  @override
  State<StudentVideoHoverPreview> createState() =>
      _StudentVideoHoverPreviewState();
}

class _StudentVideoHoverPreviewState extends State<StudentVideoHoverPreview> {
  Timer? _previewTimer;
  bool _previewing = false;

  bool get _motionEnabled =>
      !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

  void _startPreview(PointerEnterEvent _) {
    if (!widget.enabled || !_motionEnabled) return;
    _previewTimer?.cancel();
    if (!_previewing) setState(() => _previewing = true);
    _previewTimer = Timer(widget.previewDuration, _finishPreview);
  }

  void _finishPreview() {
    _previewTimer?.cancel();
    if (mounted && _previewing) setState(() => _previewing = false);
  }

  void _stopPreview(PointerExitEvent _) => _finishPreview();

  @override
  void didUpdateWidget(covariant StudentVideoHoverPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _previewing) _finishPreview();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor:
          widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: widget.enabled ? _startPreview : null,
      onExit: widget.enabled ? _stopPreview : null,
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (_previewing)
              Positioned.fill(
                child: IgnorePointer(
                  child: StudentVideoPlayer(
                    key: ValueKey('hover-preview-${widget.video.id}'),
                    video: widget.video,
                    apiBaseUrl: widget.apiBaseUrl,
                    compact: true,
                    autoPlay: true,
                    muted: true,
                  ),
                ),
              ),
            if (_previewing)
              const PositionedDirectional(
                top: 12,
                end: 12,
                child: _PreviewBadge(),
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD9071425),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF5EEAD4).withOpacity(0.7)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_rounded, color: Color(0xFFBFFBFA), size: 15),
            SizedBox(width: 5),
            Text(
              'معاينة ٣ ثوانٍ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentVideoPlayer extends StatefulWidget {
  const StudentVideoPlayer({
    required this.video,
    this.apiBaseUrl = '',
    this.compact = false,
    this.initialPosition = Duration.zero,
    this.autoPlay = true,
    this.muted = false,
    this.fullscreen = false,
    this.allowInteractivePermissions = false,
    this.onCompleted,
    super.key,
  });

  final LessonVideo video;
  final String apiBaseUrl;
  final bool compact;
  final Duration initialPosition;
  final bool autoPlay;
  final bool muted;
  final bool fullscreen;

  /// Enables only the browser permissions required by an interactive tutor
  /// embedded from another origin. Lesson videos keep this disabled.
  final bool allowInteractivePermissions;
  final VoidCallback? onCompleted;

  @override
  State<StudentVideoPlayer> createState() => _StudentVideoPlayerState();
}

class _StudentVideoPlayerState extends State<StudentVideoPlayer> {
  Player? _player;
  VideoController? _videoController;
  VideoPlayerController? _networkController;
  bool _completionReported = false;
  String? _error;
  int _embedReloadTicket = 0;

  String get _url => resolveStudentVideoUrl(
        widget.video,
        apiBaseUrl: widget.apiBaseUrl,
      );

  bool get _isNativeVideo => isDirectVideoUrl(_url, widget.video);
  bool get _usesMediaKit =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.android);
  String get _embedUrl {
    if (!widget.muted) return _url;
    final uri = Uri.tryParse(_url);
    if (uri == null) return _url;
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'mute': '1',
        'controls': '0',
      },
    ).toString();
  }

  @override
  void initState() {
    super.initState();
    if (_isNativeVideo) _openVideo();
  }

  Future<void> _openVideo() async {
    final uri = Uri.tryParse(_url);
    final isWebRelativeUrl = kIsWeb && _url.startsWith('/');
    if (uri == null ||
        (!(uri.scheme == 'http' || uri.scheme == 'https') &&
            !isWebRelativeUrl)) {
      setState(() {
        _error = 'يجب أن يكون رابط الفيديو رابط HTTP أو HTTPS عامًا.';
      });
      return;
    }

    if (_usesMediaKit) {
      await _openWithMediaKit();
    } else {
      await _openWithVideoPlayer(uri);
    }
  }

  Future<void> _openWithMediaKit() async {
    final player = Player();
    _player = player;
    _videoController = VideoController(player);
    player.stream.error.listen((error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    });
    player.stream.completed.listen((completed) {
      if (completed && !_completionReported) {
        _completionReported = true;
        widget.onCompleted?.call();
      }
    });

    try {
      if (widget.muted) await player.setVolume(0);
      // media_kit uses the HTTP Range protocol for seeking. Supplying an
      // initial range keeps Windows' native backend on the streaming path
      // for public Supabase Storage objects and API compatibility URLs.
      // The User-Agent/Referer pair mirrors a real mobile browser request,
      // which several CDNs require before they will serve the video body.
      await player.open(
        Media(
          _url,
          httpHeaders: {
            'Accept': 'video/*',
            'Range': 'bytes=0-',
            'User-Agent': _videoRequestUserAgent,
            'Referer': _refererFor(_url),
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _openWithVideoPlayer(Uri uri) async {
    // iOS/macOS use AVFoundation through this controller, which also needs
    // a browser-like User-Agent/Referer pair for the same reasons as the
    // media_kit path above.
    final controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: {
        'Accept': 'video/*',
        'User-Agent': _videoRequestUserAgent,
        'Referer': _refererFor(uri.toString()),
      },
    );
    _networkController = controller;
    controller.addListener(() {
      final value = controller.value;
      if (value.isInitialized &&
          value.duration > Duration.zero &&
          value.position >= value.duration &&
          !_completionReported) {
        _completionReported = true;
        widget.onCompleted?.call();
      }
      if (!mounted || !value.hasError) return;
      setState(() {
        _error = value.errorDescription ?? 'تعذر تحميل مصدر الفيديو.';
      });
    });

    try {
      await controller.initialize();
      if (widget.muted) await controller.setVolume(0);
      if (widget.initialPosition > Duration.zero &&
          widget.initialPosition < controller.value.duration) {
        await controller.seekTo(widget.initialPosition);
      }
      await controller.setLooping(false);
      if (!mounted) return;
      setState(() {});
      if (widget.autoPlay) await controller.play();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    _networkController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isNativeVideo) return _buildInlineEmbed();

    final controller = _videoController;
    final networkController = _networkController;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_usesMediaKit && controller != null)
          Video(
            controller: controller,
            fill: Colors.black,
            controls: MaterialVideoControls,
          )
        else if (!_usesMediaKit &&
            networkController != null &&
            networkController.value.isInitialized)
          _NetworkVideoSurface(
            controller: networkController,
            video: widget.video,
            apiBaseUrl: widget.apiBaseUrl,
            fullscreen: widget.fullscreen,
          )
        else
          const ColoredBox(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF5EEAD4)),
            ),
          ),
        if (_error != null)
          _buildError('تعذر تشغيل الفيديو', onRetry: _retryNativePlayback),
      ],
    );
  }

  Widget _buildInlineEmbed() {
    return Stack(
      fit: StackFit.expand,
      children: [
        InAppWebView(
          key: ValueKey('embed-$_embedReloadTicket'),
          initialUrlRequest: URLRequest(
            url: WebUri(_embedUrl),
            // A same-origin Referer is what stops YouTube's embed player
            // from surfacing error 153 ("disallowed embed request") when
            // the request otherwise looks like it has no referring page,
            // which is the default for a WebView navigated to directly.
            headers: {'Referer': _refererFor(_embedUrl)},
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            mediaPlaybackRequiresUserGesture: false,
            // iOS: play video in place instead of forcing the system's
            // full-screen media player, and allow it to keep playing in
            // Picture-in-Picture / via AirPlay like a native player would.
            allowsInlineMediaPlayback: true,
            allowsPictureInPictureMediaPlayback: true,
            allowsAirPlayForMediaPlayback: true,
            // Android: swap the WebView's default "...; wv) ... Mobile
            // Safari" user agent for a normal Chrome UA. YouTube's embed
            // page detects the "wv" (WebView) token and refuses playback
            // with error 153; a browser-identical UA fixes it.
            userAgent: _webViewUserAgent,
            mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
            supportZoom: !widget.compact,
            transparentBackground: true,
            supportMultipleWindows: false,
            javaScriptCanOpenWindowsAutomatically: false,
            // Flutter Web renders InAppWebView as an iframe. Interactive tutor
            // providers request getUserMedia from inside that frame, so the
            // microphone/camera feature policy must be delegated explicitly.
            iframeAllow: widget.allowInteractivePermissions
                ? 'camera *; microphone *; autoplay *; clipboard-write *; '
                    'encrypted-media *; fullscreen *; picture-in-picture *'
                : null,
            iframeAllowFullscreen: widget.allowInteractivePermissions,
          ),
          shouldOverrideUrlLoading: (controller, action) async {
            final target = action.request.url;
            if (target == null) return NavigationActionPolicy.CANCEL;
            return target.scheme == 'http' || target.scheme == 'https'
                ? NavigationActionPolicy.ALLOW
                : NavigationActionPolicy.CANCEL;
          },
          onReceivedError: (controller, request, error) {
            // Only the top-level document failing to load should surface
            // as a player error; a blocked sub-resource (analytics beacon,
            // ad request, etc.) is normal and must not hide the video.
            if (request.isForMainFrame != true || !mounted) return;
            setState(() => _error = error.description);
          },
          onReceivedHttpError: (controller, request, response) {
            final statusCode = response.statusCode ?? 0;
            if (request.isForMainFrame != true ||
                !mounted ||
                statusCode < 400) {
              return;
            }
            setState(() => _error = 'HTTP $statusCode');
          },
        ),
        if (_error != null)
          _buildError('تعذر تشغيل الفيديو', onRetry: _retryEmbed),
      ],
    );
  }

  Future<void> _retryNativePlayback() async {
    await _player?.dispose();
    await _networkController?.dispose();
    if (!mounted) return;
    setState(() {
      _error = null;
      _player = null;
      _videoController = null;
      _networkController = null;
    });
    await _openVideo();
  }

  void _retryEmbed() {
    if (!mounted) return;
    setState(() {
      _error = null;
      // Forces the InAppWebView below to remount with a fresh key, which
      // reloads the embed URL from scratch rather than replaying whatever
      // failed request is still cached in the existing webview instance.
      _embedReloadTicket++;
    });
  }

  Widget _buildError(String title, {required VoidCallback onRetry}) {
    return ColoredBox(
      color: const Color(0xED071425),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(widget.compact ? 14 : 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: const Color(0xFF5EEAD4),
                size: widget.compact ? 34 : 52,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.compact ? 15 : 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFBFFBFA),
                  side: const BorderSide(color: Color(0xFF5EEAD4)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkVideoSurface extends StatefulWidget {
  const _NetworkVideoSurface({
    required this.controller,
    required this.video,
    required this.apiBaseUrl,
    this.fullscreen = false,
  });

  final VideoPlayerController controller;
  final LessonVideo video;
  final String apiBaseUrl;
  final bool fullscreen;

  @override
  State<_NetworkVideoSurface> createState() => _NetworkVideoSurfaceState();
}

class _NetworkVideoSurfaceState extends State<_NetworkVideoSurface> {
  bool _showControls = true;

  void _togglePlayback() {
    final controller = widget.controller;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() => _showControls = true);
  }

  Future<void> _openFullscreen() async {
    final controller = widget.controller;
    final wasPlaying = controller.value.isPlaying;
    final position = controller.value.position;
    await controller.pause();
    final result = await Navigator.of(context).push<_FullscreenPlaybackState>(
      StudentPageRoute<_FullscreenPlaybackState>(
        builder: (_) => _FullscreenNetworkVideoScreen(
          video: widget.video,
          apiBaseUrl: widget.apiBaseUrl,
          initialPosition: position,
          autoPlay: wasPlaying,
        ),
      ),
    );
    if (!mounted) return;
    if (!controller.value.isInitialized) return;
    await controller.seekTo(result?.position ?? position);
    if (result?.isPlaying ?? wasPlaying) {
      await controller.play();
    } else {
      await controller.pause();
    }
    setState(() => _showControls = true);
  }

  @override
  Widget build(BuildContext context) {
    final ratio = widget.controller.value.aspectRatio;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlayback,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: ratio <= 0 ? 16 / 9 : ratio,
              child: VideoPlayer(widget.controller),
            ),
          ),
          if (_showControls)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(80),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    widget.controller.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VideoProgressIndicator(
                  widget.controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Color(0xFF5EEAD4),
                    bufferedColor: Color(0x885EEAD4),
                    backgroundColor: Color(0x66788A9F),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    IconButton(
                      tooltip: widget.controller.value.isPlaying
                          ? 'إيقاف مؤقت'
                          : 'تشغيل',
                      onPressed: _togglePlayback,
                      icon: Icon(
                        widget.controller.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip:
                          widget.fullscreen ? 'إغلاق ملء الشاشة' : 'ملء الشاشة',
                      onPressed: widget.fullscreen
                          ? () => Navigator.of(context).pop(
                                _FullscreenPlaybackState(
                                  position: widget.controller.value.position,
                                  isPlaying: widget.controller.value.isPlaying,
                                ),
                              )
                          : _openFullscreen,
                      icon: Icon(
                        widget.fullscreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FullscreenPlaybackState {
  const _FullscreenPlaybackState({
    required this.position,
    required this.isPlaying,
  });

  final Duration position;
  final bool isPlaying;
}

class _FullscreenNetworkVideoScreen extends StatelessWidget {
  const _FullscreenNetworkVideoScreen({
    required this.video,
    required this.apiBaseUrl,
    required this.initialPosition,
    required this.autoPlay,
  });

  final LessonVideo video;
  final String apiBaseUrl;
  final Duration initialPosition;
  final bool autoPlay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: StudentVideoPlayer(
              video: video,
              apiBaseUrl: apiBaseUrl,
              initialPosition: initialPosition,
              autoPlay: autoPlay,
              fullscreen: true,
            ),
          ),
        ),
      ),
    );
  }
}

String resolveStudentVideoUrl(
  LessonVideo video, {
  String apiBaseUrl = '',
}) {
  var raw = video.url.trim();
  if (raw.startsWith('/')) {
    final base = apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    if (base.isNotEmpty) raw = '$base$raw';
  }
  if (video.sourceType == VideoSourceType.mp4) return raw;

  final uri = Uri.tryParse(raw);
  if (uri == null) return raw;
  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  if (isYoutubeHost(host)) {
    final id = youtubeVideoId(uri, host);
    if (id.isNotEmpty) {
      return Uri.https(
        'www.youtube.com',
        '/embed/$id',
        const {
          'autoplay': '1',
          'playsinline': '1',
          'rel': '0',
          'modestbranding': '1',
        },
      ).toString();
    }
  }
  if (host == 'vimeo.com') {
    final id = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return 'https://player.vimeo.com/video/$id?autoplay=1';
  }
  return raw;
}

bool isDirectVideoUrl(String url, LessonVideo video) {
  if (video.sourceType == VideoSourceType.mp4) return true;
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
    return false;
  }
  final path = uri.path.toLowerCase();
  return RegExp(r'\.(mp4|m4v|mov|webm|m3u8)$').hasMatch(path) ||
      (uri.host.endsWith('supabase.co') &&
          path.contains('/storage/v1/object/public/'));
}

bool isYoutubeVideoUrl(String url) {
  final uri = Uri.tryParse(url);
  return uri != null &&
      isYoutubeHost(uri.host.toLowerCase().replaceFirst('www.', ''));
}

bool isYoutubeHost(String host) =>
    host == 'youtube.com' ||
    host == 'youtube-nocookie.com' ||
    host == 'youtu.be' ||
    host.endsWith('.youtube.com') ||
    host.endsWith('.youtube-nocookie.com');

String youtubeVideoId(Uri uri, String host) {
  if (host == 'youtu.be') {
    return uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
  }
  final queryId = uri.queryParameters['v'];
  if (queryId != null && queryId.trim().isNotEmpty) return queryId;
  if (uri.pathSegments.length >= 2 &&
      const {'embed', 'shorts', 'live'}.contains(uri.pathSegments.first)) {
    return uri.pathSegments[1];
  }
  return '';
}
