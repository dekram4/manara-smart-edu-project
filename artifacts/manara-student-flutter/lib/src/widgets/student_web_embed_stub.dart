import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class StudentWebEmbed extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest:
          htmlContent == null ? URLRequest(url: WebUri(url)) : null,
      initialData: htmlContent == null
          ? null
          : InAppWebViewInitialData(
              data: htmlContent!,
              baseUrl: WebUri('https://manara.local/'),
            ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        supportMultipleWindows: false,
        iframeAllow: allow,
        iframeAllowFullscreen: true,
      ),
      onLoadStop: (_, __) => onLoaded?.call(),
      onLoadError: (_, controller, request, description) =>
          onError?.call(description),
    );
  }
}