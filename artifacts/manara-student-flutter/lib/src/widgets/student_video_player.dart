import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/student_content.dart';

class StudentVideoPlayer extends StatefulWidget {
  const StudentVideoPlayer({
    required this.video,
    this.apiBaseUrl = '',
    this.compact = false,
    super.key,
  });

  final LessonVideo video;
  final String apiBaseUrl;
  final bool compact;

  @override
  State<StudentVideoPlayer> createState() => _StudentVideoPlayerState();
}

class _StudentVideoPlayerState extends State<StudentVideoPlayer> {
  Player? _player;
  VideoController? _videoController;
  String? _error;

  String get _url => resolveStudentVideoUrl(
        widget.video,
        apiBaseUrl: widget.apiBaseUrl,
      );

  bool get _isNativeVideo => isDirectVideoUrl(_url, widget.video);

  @override
  void initState() {
    super.initState();
    if (_isNativeVideo) _openNativeVideo();
  }

  Future<void> _openNativeVideo() async {
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

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isNativeVideo) return _buildInlineEmbed();

    final controller = _videoController;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (controller != null)
          Video(
            controller: controller,
            fill: Colors.black,
            controls: MaterialVideoControls,
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
      initialUrlRequest: isYoutubeVideoUrl(url)
          ? null
          : URLRequest(url: WebUri(url)),
      initialData: isYoutubeVideoUrl(url)
          ? InAppWebViewInitialData(
              data: youtubeEmbedHtml(url, widget.video.title),
              baseUrl: WebUri('https://www.youtube.com/'),
            )
          : null,
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        supportZoom: !widget.compact,
        transparentBackground: true,
        userAgent: _windowsUserAgent,
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
                  if (!mounted) return;
                  setState(() {
                    _error = null;
                    _player = null;
                    _videoController = null;
                  });
                  await _openNativeVideo();
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

String resolveStudentVideoUrl(
  LessonVideo video, {
  String apiBaseUrl = '',
}) {
  var raw = video.url.trim();
  if (raw.startsWith('/')) {
    final base = apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    final isLocalBase = base.toLowerCase().contains('localhost') ||
        base.contains('127.0.0.1');
    if (base.isNotEmpty && !isLocalBase) raw = '$base$raw';
  }
  if (video.sourceType == VideoSourceType.mp4) return raw;

  final uri = Uri.tryParse(raw);
  if (uri == null) return raw;
  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  if (isYoutubeHost(host)) {
    final id = youtubeVideoId(uri, host);
    if (id.isNotEmpty) {
      return 'https://www.youtube-nocookie.com/embed/'
          '${Uri.encodeComponent(id)}'
          '?autoplay=1&playsinline=1&rel=0&modestbranding=1';
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

String youtubeEmbedHtml(String url, String title) {
  final safeUrl = _escapeHtmlAttribute(url);
  final safeTitle = _escapeHtmlAttribute(title);
  return '''
<!doctype html>
<html lang="ar" dir="rtl">
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    html, body { margin: 0; height: 100%; overflow: hidden; background: #000; }
    iframe { border: 0; width: 100%; height: 100%; }
  </style>
</head>
<body>
  <iframe
    src="$safeUrl"
    title="$safeTitle"
    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
    allowfullscreen
    referrerpolicy="origin"></iframe>
</body>
</html>
''';
}

String _escapeHtml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _escapeHtmlAttribute(String value) =>
    _escapeHtml(value).replaceAll('"', '&quot;');

const _windowsUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/124.0.0.0 Safari/537.36';