import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart';

import '../models/student_content.dart';

class StudentVideoPlayer extends StatefulWidget {
  const StudentVideoPlayer({
    required this.video,
    this.apiBaseUrl = '',
    this.compact = false,
    this.initialPosition = Duration.zero,
    this.autoPlay = true,
    this.fullscreen = false,
    super.key,
  });

  final LessonVideo video;
  final String apiBaseUrl;
  final bool compact;
  final Duration initialPosition;
  final bool autoPlay;
  final bool fullscreen;

  @override
  State<StudentVideoPlayer> createState() => _StudentVideoPlayerState();
}

class _StudentVideoPlayerState extends State<StudentVideoPlayer> {
  Player? _player;
  VideoController? _videoController;
  VideoPlayerController? _networkController;
  String? _error;

  String get _url => resolveStudentVideoUrl(
        widget.video,
        apiBaseUrl: widget.apiBaseUrl,
      );

  bool get _isNativeVideo => isDirectVideoUrl(_url, widget.video);
  bool get _usesMediaKit => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

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

    try {
      // media_kit uses the HTTP Range protocol for seeking. Supplying an
      // initial range keeps Windows' native backend on the streaming path
      // for public Supabase Storage objects and API compatibility URLs.
      await player.open(
        Media(
          _url,
          httpHeaders: const {
            'Accept': 'video/*',
            'Range': 'bytes=0-',
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _openWithVideoPlayer(Uri uri) async {
    final controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: const {'Accept': 'video/*'},
    );
    _networkController = controller;
    controller.addListener(() {
      final value = controller.value;
      if (!mounted || !value.hasError) return;
      setState(() {
        _error = value.errorDescription ?? 'تعذر تحميل مصدر الفيديو.';
      });
    });

    try {
      await controller.initialize();
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
        if (_error != null) _buildError('تعذر تشغيل الفيديو'),
      ],
    );
  }

  Widget _buildInlineEmbed() {
    final url = resolveStudentVideoUrl(
      widget.video,
      apiBaseUrl: widget.apiBaseUrl,
    );
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(url),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        supportZoom: !widget.compact,
        transparentBackground: true,
        supportMultipleWindows: false,
        javaScriptCanOpenWindowsAutomatically: false,
      ),
      shouldOverrideUrlLoading: (controller, action) async {
        final target = action.request.url;
        if (target == null) return NavigationActionPolicy.CANCEL;
        return target.scheme == 'http' || target.scheme == 'https'
            ? NavigationActionPolicy.ALLOW
            : NavigationActionPolicy.CANCEL;
      },
    );
  }

  Widget _buildError(String title) {
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
                onPressed: () async {
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
                },
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
      MaterialPageRoute<_FullscreenPlaybackState>(
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
                      tooltip: widget.fullscreen ? 'إغلاق ملء الشاشة' : 'ملء الشاشة',
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
  return uri != null && isYoutubeHost(uri.host.toLowerCase().replaceFirst('www.', ''));
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
