// Web-only: this file is reached solely through the `if (dart.library.html)`
// conditional import, so `dart:html` is never compiled for Android, iOS or
// Windows. Moving it to package:web is a rewrite of the embed that has to be
// tested in a browser, and belongs in its own change.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import '../l10n/student_strings.dart';

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
        (_) => widget.onError?.call(tr('embed.contentFailed')),
      );
      return frame;
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewId);
}