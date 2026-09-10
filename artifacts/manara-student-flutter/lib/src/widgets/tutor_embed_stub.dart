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

/// The longest a child is ever asked to watch a spinner here.
///
/// It caps both the per-navigation timer and the per-attempt deadline, so
/// twelve seconds is the real worst case rather than the two adding up.
/// Past it the wait is abandoned in favour of something the student can
/// act on, because a teacher that has not arrived in twelve seconds is
/// usually not coming — the account's stream is busy elsewhere, or the
/// handshake failed silently.
const Duration _kMaxWait = Duration(seconds: 12);

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
  /// Restarted on every navigation the page makes. Catches the ordinary
  /// "this one request is taking too long" case.
  Timer? _timeout;

  /// Started once per attempt and *never* restarted. A provider page that
  /// bounces through a chain of redirects fires onLoadStart each time, and
  /// with only the soft timer above that reset the clock on every hop —
  /// so the spinner could stay up indefinitely without a single timeout
  /// ever firing. This is the backstop that guarantees the student always
  /// gets either the teacher or a retry button.
  Timer? _deadline;

  var _loading = true;

  /// Bumped on retry so the WebView itself is rebuilt. The old retry called
  /// `_controller?.reload()`, which did nothing at all when the controller
  /// was still null — exactly the case where the embed had hung before it
  /// ever came up, so the one button meant to rescue a stuck screen was
  /// dead precisely when it was needed.
  var _revision = 0;

  String? _error;

  /// Kept so the page can be closed deliberately rather than left for the
  /// provider to time out — see [_endProviderSession].
  InAppWebViewController? _controller;

  @override
  void initState() {
    super.initState();
    _startTimeout();
    _startDeadline();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _deadline?.cancel();
    _endProviderSession();
    super.dispose();
  }

  /// Navigates the page away before the widget goes, so the embed runs its
  /// own teardown and drops any stream it holds. Left to itself, that
  /// stream stays counted against the account until the provider expires
  /// it — which is what makes the next visit, or a second device, wait on
  /// a session that will not be granted.
  void _endProviderSession() {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    unawaited(controller.stopLoading().catchError((_) {}));
    unawaited(
      controller
          .loadUrl(urlRequest: URLRequest(url: WebUri('about:blank')))
          .catchError((_) {}),
    );
  }

  void _startTimeout() {
    _timeout?.cancel();
    _timeout = Timer(_kMaxWait, _giveUp);
  }

  void _startDeadline() {
    _deadline?.cancel();
    _deadline = Timer(_kMaxWait, _giveUp);
  }

  void _giveUp() {
    if (!mounted || !_loading || _error != null) return;
    _timeout?.cancel();
    _deadline?.cancel();
    setState(() {
      _loading = false;
      _error = 'صديقك المعلم تأخر أكثر من المعتاد. قد يكون مشغولًا في جهاز '
          'آخر — اضغط إعادة المحاولة لنجرب من جديد.';
    });
  }

  /// Clears the loading cover once the page has painted enough to be worth
  /// showing. Some teacher/avatar providers hold a streaming connection
  /// open for the whole session, so `onLoadStop` never arrives — the page
  /// underneath was live and interactive while the spinner sat on top of
  /// it forever.
  void _onProgress(int progress) {
    if (!mounted || progress < 70) return;
    _timeout?.cancel();
    _deadline?.cancel();
    if (_loading) setState(() => _loading = false);
  }

  void _reload() {
    // Closes the attempt that failed before opening another, so this is a
    // new session rather than a second try at resuming the one that was
    // refused or never arrived.
    _endProviderSession();
    setState(() {
      _loading = true;
      _error = null;
      _revision++;
    });
    _startTimeout();
    _startDeadline();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        InAppWebView(
          key: ValueKey('tutor-embed-$_revision'),
          onWebViewCreated: (controller) => _controller = controller,
          // The teacher lives in this card and never hands the child off
          // to a browser: web navigations load here, and anything asking
          // for another app is dropped.
          shouldOverrideUrlLoading: (controller, action) async {
            final url = action.request.url;
            if (url == null) return NavigationActionPolicy.ALLOW;
            const webSchemes = {'http', 'https', 'about', 'data', 'blob'};
            return webSchemes.contains(url.scheme.toLowerCase())
                ? NavigationActionPolicy.ALLOW
                : NavigationActionPolicy.CANCEL;
          },
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
            if (mounted && !_loading) setState(() => _loading = true);
            // Only the per-navigation timer restarts here; the attempt
            // deadline deliberately keeps running so a redirect chain
            // cannot postpone it forever.
            _startTimeout();
          },
          onProgressChanged: (_, progress) => _onProgress(progress),
          onLoadStop: (_, __) {
            _timeout?.cancel();
            _deadline?.cancel();
            if (mounted) setState(() => _loading = false);
          },
          onReceivedError: (controller, request, error) {
            // Only a failed top-level document load counts; a blocked
            // sub-resource (analytics, a font, an ad) is normal and must
            // not hide an otherwise-working embed.
            if (request.isForMainFrame != true || !mounted) return;
            _timeout?.cancel();
            _deadline?.cancel();
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
            _deadline?.cancel();
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
        color: Color(0xFF1D3B55),
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
                  'صديقك المعلم غير جاهز الآن',
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
                // Big, filled and unmissable: when a child is looking at a
                // screen that did not work, the way out should be the most
                // obvious thing on it.
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 26),
                  label: const Text(
                    'إعادة المحاولة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6D28D9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
