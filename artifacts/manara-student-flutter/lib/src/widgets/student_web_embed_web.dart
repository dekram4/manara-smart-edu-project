import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class StudentWebEmbed extends StatefulWidget {
  const StudentWebEmbed({
    required this.url,
    this.htmlContent,
    this.allow = 'autoplay; fullscreen; encrypted-media; picture-in-picture',
    this.onLoaded,
    this.onError,
    super.key,
  });

  final String url;
  final String? htmlContent;
  final String allow;
  final VoidCallback? onLoaded;
  final ValueChanged<String>? onError;

  @override
  State<StudentWebEmbed> createState() => _StudentWebEmbedState();
}

class _StudentWebEmbedState extends State<StudentWebEmbed> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'manara-web-embed-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int _) {
      final frame = html.IFrameElement()
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = widget.allow
        ..allowFullscreen = true;
      if (widget.htmlContent == null) {
        frame.src = widget.url;
      } else {
        frame.srcdoc = widget.htmlContent;
      }
      frame.onLoad.listen((_) => widget.onLoaded?.call());
      frame.onError.listen(
        (_) => widget.onError?.call('تعذر تحميل المحتوى من المصدر.'),
      );
      return frame;
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewId);
}