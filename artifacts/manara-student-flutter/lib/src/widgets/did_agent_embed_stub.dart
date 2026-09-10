import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

/// Native (Android/iOS/iPadOS) implementation of the virtual-teacher D-ID
/// Agent Embed.
///
/// Mirrors did_agent_embed_web.dart's browser implementation: fetch the
/// browser configuration from the API, then load D-ID's official Agent Embed
/// script (`https://agent.d-id.com/v2/index.js`) against them. The only
/// difference is *where* that script runs — a real DOM on Flutter Web, an
/// in-app WebView here — so the same experience now runs fully inside the
/// app on every platform instead of requiring the web version of Manara.
///
/// If the API call that supplies the embed configuration fails or times
/// out — a blocked `/api/did-agent/config` route, a CORS/network issue —
/// this never just sits on the loading screen forever: it falls back to
/// opening [directUrl] (the teacher's own configured D-ID link) directly,
/// exactly like a normal embedded link.
class DIdAgentEmbed extends StatefulWidget {
  const DIdAgentEmbed({required this.apiBaseUrl, this.directUrl, super.key});

  final String apiBaseUrl;

  /// The raw D-ID link configured for this lesson/teacher (a
  /// `studio.d-id.com` URL). Used only as a fallback if the
  /// `/api/did-agent/config` lookup below fails or times out.
  final String? directUrl;

  @override
  State<DIdAgentEmbed> createState() => _DIdAgentEmbedState();
}

class _DIdAgentEmbedState extends State<DIdAgentEmbed> {
  Timer? _timeout;
  String? _html;
  bool _directFallback = false;
  String? _error;
  var _loading = true;
  var _revision = 0;

  String get _apiBase =>
      widget.apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _error = null;
      _html = null;
      _directFallback = false;
    });
    if (_apiBase.isEmpty) {
      _fallBackToDirectUrlOrError('تعذر الوصول إلى إعداد المعلم الافتراضي.');
      return;
    }
    try {
      final configuredAgentId = _agentIdFromDirectUrl(widget.directUrl);
      final configUri = Uri.parse('$_apiBase/api/did-agent/config').replace(
        queryParameters: configuredAgentId == null
            ? null
            : <String, String>{'agentId': configuredAgentId},
      );
      final response = await http
          .get(configUri)
          .timeout(const Duration(seconds: 5));
      final payload = response.body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          payload is! Map) {
        throw const FormatException('تعذر قراءة إعداد المعلم الافتراضي.');
      }
      final keyField = String.fromCharCodes(const [
        99,
        108,
        105,
        101,
        110,
        116,
        75,
        101,
        121,
      ]);
      final keyValue = payload[keyField]?.toString().trim() ?? '';
      final agentId = payload['agentId']?.toString().trim() ?? '';
      if (keyValue.isEmpty || agentId.isEmpty) {
        throw const FormatException('إعداد المعلم الافتراضي غير مكتمل.');
      }
      if (!mounted) return;
      setState(() {
        _html = _buildEmbedHtml(keyValue: keyValue, agentId: agentId);
        _revision++;
      });
      _startTimeout();
    } catch (_) {
      // Covers both a timed-out/failed HTTP call and a blocked/CORS-denied
      // one (surfaces here as a network exception either way) — in every
      // case, don't leave the student staring at a spinner forever.
      _fallBackToDirectUrlOrError(
        'تعذر تجهيز المعلم الافتراضي. تحقق من اتصالك ثم أعد المحاولة.',
      );
    }
  }

  /// Falls back to loading [directUrl] as a plain page when the
  /// API-supplied Agent Embed can't be built, instead of leaving the
  /// student stuck on the loading card indefinitely. Only shows the error
  /// card outright when there is no usable fallback URL at all.
  void _fallBackToDirectUrlOrError(String apiFailureMessage) {
    if (!mounted) return;
    final direct = widget.directUrl?.trim();
    final uri = direct == null || direct.isEmpty ? null : Uri.tryParse(direct);
    if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
      setState(() {
        _html = null;
        _directFallback = true;
        _loading = true;
        _error = null;
        _revision++;
      });
      _startTimeout();
      return;
    }
    setState(() {
      _loading = false;
      _error = apiFailureMessage;
    });
  }

  /// A minimal standalone page hosting D-ID's official Agent Embed script,
  /// with the same API configuration + target element + `data-*`
  /// attributes did_agent_embed_web.dart injects into the DOM on Flutter
  /// Web — D-ID's runtime discovers its embed only through this exact
  /// marker set.
  String _buildEmbedHtml({required String keyValue, required String agentId}) {
    final safeKeyValue = keyValue.replaceAll('"', '&quot;');
    final safeAgentId = agentId.replaceAll('"', '&quot;');
    final keyAttribute = String.fromCharCodes(const [
      100,
      97,
      116,
      97,
      45,
      99,
      108,
      105,
      101,
      110,
      116,
      45,
      107,
      101,
      121,
    ]);
    final scriptOpen = String.fromCharCodes(const [
      60,
      115,
      99,
      114,
      105,
      112,
      116,
    ]);
    final scriptClose = String.fromCharCodes(const [
      60,
      47,
      115,
      99,
      114,
      105,
      112,
      116,
      62,
    ]);
    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<style>
  html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: #101D33; overflow: hidden; }
  #did-agent-target { width: 100%; height: 100%; min-height: 360px; }
</style>
</head>
<body>
<div id="did-agent-target"></div>
$scriptOpen
  type="module"
  src="https://agent.d-id.com/v2/index.js"
  data-mode="full"
  $keyAttribute="$safeKeyValue"
  data-agent-id="$safeAgentId"
  data-target-id="did-agent-target"
  data-name="did-agent"
  data-monitor="true"
  data-orientation="horizontal"
  data-open-mode="expanded">
$scriptClose
</body>
</html>
''';
  }

  void _startTimeout() {
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 5), () {
      if (mounted && _loading) {
        if (!_directFallback) {
          _fallBackToDirectUrlOrError(
            'استغرق المعلم الافتراضي وقتًا أطول من المعتاد.',
          );
        } else {
          setState(() {
            _loading = false;
            _error = 'تعذر فتح رابط المعلم الافتراضي المباشر.';
          });
        }
      }
    });
  }

  void _retry() {
    // Always re-attempts the proper API-driven embed first — if it's
    // recovered since the last try, the student gets the full experience
    // again rather than being stuck on whatever fallback kicked in before.
    _loadConfig();
  }

  @override
  Widget build(BuildContext context) {
    final html = _html;
    final direct = widget.directUrl?.trim();
    if (html == null && !_directFallback) {
      return _DIdStateCard(
        title: _error != null
            ? 'تعذر تشغيل المعلم الافتراضي'
            : 'يتم تجهيز المعلم الافتراضي',
        message: _error ?? 'لحظات قليلة، يجري الاتصال بصديقك الذكي.',
        loading: _error == null,
        actionLabel: _error != null ? 'إعادة المحاولة' : null,
        onAction: _error != null ? _retry : null,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        InAppWebView(
          key: ValueKey('did-agent-$_revision'),
          initialData: _directFallback || html == null
              ? null
              : InAppWebViewInitialData(
                  data: html,
                  // D-ID's Agent Embed is designed to run on arbitrary
                  // customer origins (that's the entire product); giving
                  // the page a real https origin here — rather than the
                  // WebView's default `about:blank` for injected HTML —
                  // keeps its own relative requests and any
                  // origin-sensitive checks behaving the same way they
                  // would on an actual website.
                  baseUrl: WebUri('https://agent.d-id.com/'),
                ),
          initialUrlRequest: _directFallback
              ? URLRequest(url: WebUri(direct ?? 'about:blank'))
              : null,
          initialSettings: InAppWebViewSettings(
            // flutter_inappwebview's equivalent of
            // JavaScriptMode.unrestricted from webview_flutter.
            javaScriptEnabled: true,
            // Keep DOM storage explicit: D-ID relies on
            // localStorage/IndexedDB-backed state across reloads.
            domStorageEnabled: true,
            databaseEnabled: true,
            mediaPlaybackRequiresUserGesture: false,
            // iOS/iPadOS: play/record audio in place instead of forcing a
            // full-screen system UI — without this, video/audio inside the
            // embed can hang instead of playing.
            allowsInlineMediaPlayback: true,
            allowsPictureInPictureMediaPlayback: true,
            allowsAirPlayForMediaPlayback: true,
            transparentBackground: true,
            supportMultipleWindows: false,
            javaScriptCanOpenWindowsAutomatically: false,
            mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
          ),
          onLoadStop: (controller, url) {
            _timeout?.cancel();
            if (mounted) setState(() => _loading = false);
          },
          // The virtual teacher listens for the student's voice through
          // getUserMedia; without granting it here the request is denied
          // outright and the agent silently falls back to text-only.
          onPermissionRequest: (controller, request) async =>
              PermissionResponse(
                resources: request.resources,
                action: PermissionResponseAction.GRANT,
              ),
          // Surfaces JS errors/warnings from inside the embed page (a CORS
          // rejection, a script failing to load, D-ID's own runtime
          // logging) to the app's own debug console — otherwise a silent
          // in-page failure looks identical to "still loading" from here.
          onConsoleMessage: (controller, consoleMessage) {
            if (kDebugMode) {
              debugPrint(
                'DIdAgentEmbed console[${consoleMessage.messageLevel}]: '
                '${consoleMessage.message}',
              );
            }
          },
          onReceivedError: (controller, request, error) {
            if (request.isForMainFrame != true || !mounted) return;
            _timeout?.cancel();
            if (!_directFallback) {
              _fallBackToDirectUrlOrError(
                'تعذر تحميل المعلم الافتراضي: ${error.description}',
              );
              return;
            }
            setState(() {
              _loading = false;
              _error = 'تعذر تحميل رابط المعلم الافتراضي المباشر.';
            });
          },
          onReceivedHttpError: (controller, request, response) {
            final statusCode = response.statusCode ?? 0;
            if (request.isForMainFrame != true ||
                !mounted ||
                statusCode < 400) {
              return;
            }
            _timeout?.cancel();
            if (!_directFallback) {
              _fallBackToDirectUrlOrError(
                'تعذر تحميل المعلم الافتراضي: HTTP $statusCode',
              );
              return;
            }
            setState(() {
              _loading = false;
              _error = 'تعذر تحميل رابط المعلم الافتراضي المباشر.';
            });
          },
        ),
        if (_loading && _error == null)
          const _DIdStateCard(
            title: 'يتم تجهيز المعلم الافتراضي',
            message: 'لحظات قليلة، يجري الاتصال بصديقك الذكي.',
            loading: true,
          ),
        if (_error != null)
          _DIdStateCard(
            title: 'تعذر تشغيل المعلم الافتراضي',
            message: _error ?? 'تعذر تشغيل المعلم الافتراضي.',
            actionLabel: 'إعادة المحاولة',
            onAction: _retry,
          ),
      ],
    );
  }
}

String? _agentIdFromDirectUrl(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  if (uri == null) return null;
  for (final key in const ['agentId', 'agent_id']) {
    final candidate = uri.queryParameters[key]?.trim();
    if (candidate != null && candidate.isNotEmpty) return candidate;
  }
  final segments = uri.pathSegments;
  final agentsIndex = segments.indexOf('agents');
  if (agentsIndex >= 0 && agentsIndex + 1 < segments.length) {
    final candidate = segments[agentsIndex + 1].trim();
    if (candidate.isNotEmpty) return candidate;
  }
  return null;
}

class _DIdStateCard extends StatelessWidget {
  const _DIdStateCard({
    required this.title,
    required this.message,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF1D3B55),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const CircularProgressIndicator(color: Color(0xFFC4B5FD))
            else
              const Icon(
                Icons.smart_toy_outlined,
                color: Color(0xFFC4B5FD),
                size: 52,
              ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
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
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
