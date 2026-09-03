import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// A normal Chrome user agent for Android's WebView. Some virtual-teacher
/// providers (the same class of avatar/embed hosts that block plain YouTube
/// iframes) reject the WebView's default UA — which advertises itself with
/// a trailing " wv" (WebView) token — the same failure mode fixed for
/// lesson-video embeds in student_video_player.dart. Keeping both in sync.
const String _kAndroidWebViewUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

/// Native fallback for the virtual-teacher embed. Flutter Web uses the
/// browser-native iframe implementation in tutor_embed_web.dart instead.
class TutorEmbed extends StatefulWidget {
  const TutorEmbed({
    required this.url,
    required this.title,
    super.key,
  });

  final String url;
  final String title;

  @override
  State<TutorEmbed> createState() => _TutorEmbedState();
}

class _TutorEmbedState extends State<TutorEmbed> {
  Timer? _timeout;
  InAppWebViewController? _controller;
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimeout();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  void _startTimeout() {
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 12), () {
      if (mounted && _loading) {
        setState(
            () => _error = 'استغرق المعلم الافتراضي وقتًا أطول من المعتاد.');
      }
    });
  }

  void _reload() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _startTimeout();
    _controller?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        InAppWebView(
          onWebViewCreated: (controller) => _controller = controller,
          initialUrlRequest: URLRequest(url: WebUri(widget.url)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            // Explicit even though both already default to `true` in this
            // plugin — most avatar/embed providers rely on
            // localStorage/IndexedDB-backed session state across reloads.
            domStorageEnabled: true,
            databaseEnabled: true,
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            allowsPictureInPictureMediaPlayback: true,
            transparentBackground: true,
            supportMultipleWindows: false,
            iframeAllow:
                'camera *; microphone *; autoplay *; clipboard-write *; '
                'encrypted-media *; fullscreen *; picture-in-picture *',
            iframeAllowFullscreen: true,
            // Same fix as the lesson-video embed: Android's default WebView
            // UA carries a " wv" token some avatar/embed providers reject
            // outright, and mixed-content compatibility mode avoids a blank
            // embed when a provider mixes http/https sub-resources.
            userAgent:
                (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
                    ? _kAndroidWebViewUserAgent
                    : null,
            mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
          ),
          // Some virtual-teacher providers listen for the student's voice
          // through getUserMedia; without granting the request here (on top
          // of the `iframeAllow` feature-policy above) it is denied outright
          // and the embed silently falls back to a degraded, text-only mode.
          onPermissionRequest: (controller, request) async =>
              PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.GRANT,
          ),
          // Surfaces JS errors/warnings from inside the embed page to the
          // app's own debug console — a silent in-page failure (a blocked
          // script, a CORS rejection) otherwise looks identical to "still
          // loading" from here.
          onConsoleMessage: (controller, consoleMessage) {
            if (kDebugMode) {
              debugPrint(
                'TutorEmbed console[${consoleMessage.messageLevel}]: '
                '${consoleMessage.message}',
              );
            }
          },
          onLoadStart: (_, __) {
            if (mounted) setState(() => _loading = true);
            _startTimeout();
          },
          onLoadStop: (_, __) {
            _timeout?.cancel();
            if (mounted) setState(() => _loading = false);
          },
          onReceivedError: (controller, request, error) {
            // Only a failed top-level document load counts; a blocked
            // sub-resource (analytics, a font, an ad) is normal and must
            // not hide an otherwise-working embed.
            if (request.isForMainFrame != true || !mounted) return;
            _timeout?.cancel();
            setState(() {
              _loading = false;
              _error = 'تعذر تحميل المعلم الافتراضي: ${error.description}';
            });
          },
          onReceivedHttpError: (controller, request, response) {
            // Without this, a dead/expired teacher link (410, 404, a login
            // wall returning 403...) "loads" successfully as far as
            // onLoadStop is concerned — the loading spinner just clears
            // and the student is left staring at a blank or broken embed
            // with no error message and no way to retry.
            final statusCode = response.statusCode ?? 0;
            if (request.isForMainFrame != true ||
                !mounted ||
                statusCode < 400) {
              return;
            }
            _timeout?.cancel();
            setState(() {
              _loading = false;
              _error = 'تعذر تحميل المعلم الافتراضي: HTTP $statusCode';
            });
          },
        ),
        if (_loading && _error == null) const _TutorEmbedLoading(),
        if (_error != null)
          _TutorEmbedFailure(
            message: _error!,
            onRetry: _reload,
          ),
      ],
    );
  }
}

class _TutorEmbedLoading extends StatelessWidget {
  const _TutorEmbedLoading();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFF101D33),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFC4B5FD)),
              SizedBox(height: 14),
              Text(
                'يتم تجهيز المعلم الافتراضي...',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
}

class _TutorEmbedFailure extends StatelessWidget {
  const _TutorEmbedFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xF0101D33),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.smart_toy_outlined,
                    color: Color(0xFFC4B5FD), size: 52),
                const SizedBox(height: 12),
                const Text(
                  'تعذر تجهيز المعلم الافتراضي',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFC8D5E5), height: 1.5),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة التحميل'),
                ),
              ],
            ),
          ),
        ),
      );
}
