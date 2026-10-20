import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
      // ── اللمسةُ الأولى للعبة ──
      // الصفحةُ داخل شاشاتٍ لها إيماءاتُها (سحبُ الرجوع، والتمرير)، وساحةُ
      // الإيماءات في Flutter كانت تحسم اللمسةَ الأولى قبل أن تصل الصفحة —
      // فيضغط الطفلُ «ابدأ» مرّتين. فالصفحةُ تأخذ كلَّ لمسةٍ عليها فوراً.
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
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
        // ‏صريحةٌ لا مفترضة — كلُّ لعبةٍ حاليةٍ أو قادمة: الرسمُ بالعتاد،
        // ‏وتخزينُ الصفحة (localStorage وIndexedDB: تقدّمُ اللعبة وذاكرةُ Unity)،
        // ‏وذاكرةُ HTTP. وملفّاتُ الألعاب الثقيلة يحفظها عاملُ خدمةٍ في الخادم
        // ‏(GAME_ASSET_CACHE_SW) فتُحمَّل مرّةً واحدة.
        hardwareAcceleration: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        cacheEnabled: true,
        cacheMode: CacheMode.LOAD_DEFAULT,
      ),
      onLoadStop: (controller, __) {
        // ‏وألعابُ Unity وCanvas لا تستقبل أوّلَ لمسةٍ حتى تأخذ الصفحةُ
        // ‏التركيز — فتُعطاه حين تكتمل.
        controller.evaluateJavascript(source: _focusScript).ignore();
        onLoaded?.call();
      },
      // Unlike the old `onLoadError`, this fires for every resource the page
      // fails to fetch — an image, a tracker. Only the page itself failing is
      // an error for the embed, so everything else is let through.
      onReceivedError: (_, request, error) {
        if (request.isForMainFrame ?? true) onError?.call(error.description);
      },
    );
  }
}

/// يعطي الصفحةَ ولوحةَ اللعبة التركيز، فتعمل اللمسةُ الأولى.
const _focusScript = '''
(function(){try{window.focus();var c=document.querySelector("canvas");
if(c){if(!c.hasAttribute("tabindex"))c.setAttribute("tabindex","0");c.focus();}}catch(e){}})();
''';
