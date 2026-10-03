import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../utils/game_navigation.dart';

class StudentWebEmbed extends StatelessWidget {
  const StudentWebEmbed({
    required this.url,
    this.htmlContent,
    this.allow = 'autoplay; fullscreen; encrypted-media; picture-in-picture',
    this.onLoaded,
    this.onError,
    this.allowedHosts,
    super.key,
  });

  final String url;
  final String? htmlContent;
  final String allow;
  final VoidCallback? onLoaded;
  final ValueChanged<String>? onError;

  /// قفلُ التنقّل: إن أُعطيت، لا تنتقل الصفحةُ إلا إليها، ولا تُفتح نافذةٌ جديدة،
  /// ويُحجب ما يُطلب من مضيفي الإعلانات. انظر [allowGameNavigation].
  final Set<String>? allowedHosts;

  @override
  Widget build(BuildContext context) {
    final locked = allowedHosts;
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
        // ── والنوافذُ ممنوعة ──
        // بلا قفل: تعطيلُ النوافذ المتعدّدة كما كان. ومع القفل تُقبل النافذةُ
        // ليُردّ طلبُها في [onCreateWindow] — وإلا فتحتها أندرويد في الصفحة نفسها.
        supportMultipleWindows: locked != null,
        javaScriptCanOpenWindowsAutomatically: false,
        useShouldOverrideUrlLoading: locked != null,
        contentBlockers: locked == null
            ? null
            : [
                for (final host in gameAdHosts)
                  ContentBlocker(
                    trigger: ContentBlockerTrigger(
                      urlFilter: '.*${RegExp.escape(host)}/.*',
                    ),
                    action: ContentBlockerAction(
                      type: ContentBlockerActionType.BLOCK,
                    ),
                  ),
              ],
        iframeAllow: allow,
        iframeAllowFullscreen: true,
      ),
      onCreateWindow: locked == null ? null : (_, __) async => false,
      shouldOverrideUrlLoading: locked == null
          ? null
          : (_, action) async {
              final target = action.request.url;
              if (target == null) return NavigationActionPolicy.CANCEL;
              final allowed = allowGameNavigation(
                target,
                allowedHosts: locked,
                mainFrame: action.isForMainFrame,
              );
              return allowed
                  ? NavigationActionPolicy.ALLOW
                  : NavigationActionPolicy.CANCEL;
            },
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
