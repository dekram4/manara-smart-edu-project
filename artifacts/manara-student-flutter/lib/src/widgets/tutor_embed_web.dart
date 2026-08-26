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
  html.DivElement? _loadingPanel;
  html.DivElement? _errorPanel;
  html.ButtonElement? _retryButton;
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
      final root = html.DivElement()
        ..style.position = 'relative'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.overflow = 'hidden'
        ..style.backgroundColor = '#101D33';
      final frame = html.IFrameElement()
        ..src = widget.url
        ..title = widget.title
        ..style.position = 'absolute'
        ..style.top = '0'
        ..style.right = '0'
        ..style.bottom = '0'
        ..style.left = '0'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#101D33'
        ..allow =
            'camera; microphone; autoplay; clipboard-write; encrypted-media; '
            'fullscreen; picture-in-picture'
        ..allowFullscreen = true
        ..referrerPolicy = 'strict-origin-when-cross-origin';
      final loadingPanel = _makeLoadingPanel();
      final errorPanel = _makeErrorPanel();
      root.children
        ..add(frame)
        ..add(loadingPanel)
        ..add(errorPanel);
      _loadingPanel = loadingPanel;
      _errorPanel = errorPanel;
      frame.onLoad.listen((_) {
        _timeout?.cancel();
        _updateDomState(loading: false);
        if (mounted) {
          setState(() {
            _loading = false;
            _error = null;
          });
        }
      });
      frame.onError.listen((_) {
        _timeout?.cancel();
        const message = 'رفض المصدر تحميل محتوى المعلم داخل التطبيق.';
        _updateDomState(loading: false, error: message);
        if (mounted) {
          setState(() {
            _loading = false;
            _error = message;
          });
        }
      });
      _frame = frame;
      return root;
    });
  }

  html.DivElement _makeLoadingPanel() {
    final panel = html.DivElement()
      ..style.position = 'absolute'
      ..style.top = '0'
      ..style.right = '0'
      ..style.bottom = '0'
      ..style.left = '0'
      ..style.display = 'flex'
      ..style.flexDirection = 'column'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.gap = '14px'
      ..style.backgroundColor = '#101D33'
      ..style.color = 'white'
      ..style.fontFamily = 'Arial, sans-serif'
      ..style.fontWeight = '800'
      ..style.fontSize = '16px'
      ..style.zIndex = '2';
    final spinner = html.DivElement()
      ..style.width = '38px'
      ..style.height = '38px'
      ..style.border = '4px solid rgba(196,181,253,0.28)'
      ..style.borderTop = '4px solid #C4B5FD'
      ..style.borderRadius = '50%'
      ..style.animation = 'manara-tutor-spin 1s linear infinite';
    panel
      ..append(spinner)
      ..append(html.DivElement()..text = 'يتم تجهيز المعلم الافتراضي...');
    return panel;
  }

  html.DivElement _makeErrorPanel() {
    final panel = html.DivElement()
      ..style.position = 'absolute'
      ..style.top = '0'
      ..style.right = '0'
      ..style.bottom = '0'
      ..style.left = '0'
      ..style.display = 'none'
      ..style.flexDirection = 'column'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.gap = '12px'
      ..style.padding = '24px'
      ..style.boxSizing = 'border-box'
      ..style.backgroundColor = 'rgba(16,29,51,0.97)'
      ..style.color = 'white'
      ..style.fontFamily = 'Arial, sans-serif'
      ..style.textAlign = 'center'
      ..style.zIndex = '3';
    panel.append(
      html.DivElement()
        ..text = 'تعذر تجهيز المعلم الافتراضي'
        ..style.fontSize = '20px'
        ..style.fontWeight = '900',
    );
    final message = html.DivElement()
      ..style.maxWidth = '560px'
      ..style.lineHeight = '1.7'
      ..style.color = '#C8D5E5';
    panel.append(message);
    final retryButton = html.ButtonElement()
      ..text = 'إعادة التحميل'
      ..style.marginTop = '4px'
      ..style.padding = '10px 18px'
      ..style.border = '1px solid #C4B5FD'
      ..style.borderRadius = '10px'
      ..style.backgroundColor = '#C4B5FD'
      ..style.color = '#101D33'
      ..style.fontWeight = '900'
      ..style.cursor = 'pointer';
    retryButton.onClick.listen((_) => _reload());
    panel.append(retryButton);
    _retryButton = retryButton;
    return panel;
  }

  void _updateDomState({required bool loading, String? error}) {
    _loadingPanel?.style.display = loading ? 'flex' : 'none';
    _errorPanel?.style.display = error == null ? 'none' : 'flex';
    if (error != null) {
      final message = _errorPanel?.children.length == 2
          ? _errorPanel!.children[1]
          : null;
      if (message != null) message.text = error;
    }
    _retryButton?.disabled = false;
  }

  void _startTimeout() {
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 12), () {
      if (mounted && _loading) {
        const message =
            'استغرق المصدر وقتًا أطول من المعتاد. تحقق من رابط المعلم أو أعد المحاولة.';
        _updateDomState(loading: false, error: message);
        setState(() {
          _loading = false;
          _error = message;
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
    _updateDomState(loading: true);
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
    return HtmlElementView(viewType: _viewId);
  }
}