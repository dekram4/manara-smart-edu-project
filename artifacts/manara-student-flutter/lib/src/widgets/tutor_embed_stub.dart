import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

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
        setState(() => _error = 'استغرق المعلم الافتراضي وقتًا أطول من المعتاد.');
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
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            transparentBackground: true,
            supportMultipleWindows: false,
            iframeAllow:
                'camera *; microphone *; autoplay *; clipboard-write *; '
                'encrypted-media *; fullscreen *; picture-in-picture *',
            iframeAllowFullscreen: true,
          ),
          onLoadStart: (_, __) {
            if (mounted) setState(() => _loading = true);
            _startTimeout();
          },
          onLoadStop: (_, __) {
            _timeout?.cancel();
            if (mounted) setState(() => _loading = false);
          },
          onLoadError: (_, __, __, description) {
            _timeout?.cancel();
            if (mounted) {
              setState(() {
                _loading = false;
                _error = 'تعذر تحميل المعلم الافتراضي: $description';
              });
            }
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
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
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