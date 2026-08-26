import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

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
  late final String _viewId;
  html.IFrameElement? _frame;
  Timer? _timeout;
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _viewId = 'manara-tutor-${identityHashCode(this)}';
    _registerFrame();
    _startTimeout();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  void _registerFrame() {
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int _) {
      final frame = html.IFrameElement()
        ..src = widget.url
        ..title = widget.title
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#101D33'
        ..allow =
            'camera; microphone; autoplay; clipboard-write; encrypted-media; '
            'fullscreen; picture-in-picture'
        ..allowFullscreen = true
        ..referrerPolicy = 'strict-origin-when-cross-origin';
      frame.onLoad.listen((_) {
        _timeout?.cancel();
        if (mounted) {
          setState(() {
            _loading = false;
            _error = null;
          });
        }
      });
      frame.onError.listen((_) {
        _timeout?.cancel();
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'رفض المصدر تحميل محتوى المعلم داخل التطبيق.';
          });
        }
      });
      _frame = frame;
      return frame;
    });
  }

  void _startTimeout() {
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 12), () {
      if (mounted && _loading) {
        setState(() {
          _loading = false;
          _error =
              'استغرق المصدر وقتًا أطول من المعتاد. تحقق من رابط المعلم أو أعد المحاولة.';
        });
      }
    });
  }

  void _reload() {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    _startTimeout();
    _frame?.src = uri
        .replace(queryParameters: {
          ...uri.queryParameters,
          '_manaraReload': DateTime.now().millisecondsSinceEpoch.toString(),
        })
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView(viewType: _viewId),
        if (_loading && _error == null) const _TutorEmbedLoading(),
        if (_error != null) _TutorEmbedFailure(message: _error!, onRetry: _reload),
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