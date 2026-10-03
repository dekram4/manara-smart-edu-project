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
      // Unlike the old `onLoadError`, this fires for every resource the page
      // fails to fetch — an image, a tracker. Only the page itself failing is
      // an error for the embed, so everything else is let through.
      onReceivedError: (_, request, error) {
        if (request.isForMainFrame ?? true) onError?.call(error.description);
      },
    );
  }
}