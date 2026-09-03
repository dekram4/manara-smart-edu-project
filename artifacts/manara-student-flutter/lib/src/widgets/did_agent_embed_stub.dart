import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

/// Native (Android/iOS/iPadOS) implementation of the virtual-teacher D-ID
/// Agent Embed.
///
/// Mirrors did_agent_embed_web.dart's browser implementation exactly: fetch
/// the client key/agent id from the API, then load D-ID's official Agent
/// Embed script (`https://agent.d-id.com/v2/index.js`) against them. The
/// only difference is *where* that script runs — a real DOM on Flutter Web,
/// an in-app WebView here — so the same experience now runs fully inside
/// the app on every platform instead of requiring the web version of
/// Manara.
class DIdAgentEmbed extends StatefulWidget {
  const DIdAgentEmbed({
    required this.apiBaseUrl,
    super.key,
  });

  final String apiBaseUrl;

  @override
  State<DIdAgentEmbed> createState() => _DIdAgentEmbedState();
}

class _DIdAgentEmbedState extends State<DIdAgentEmbed> {
  Timer? _timeout;
  String? _html;
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
    });
    if (_apiBase.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'تعذر الوصول إلى إعداد المعلم الافتراضي.';
      });
      return;
    }
    try {
      final response = await http
          .get(Uri.parse('$_apiBase/api/did-agent/config'))
          .timeout(const Duration(seconds: 12));
      final payload = response.body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          payload is! Map) {
        throw const FormatException('تعذر قراءة إعداد المعلم الافتراضي.');
      }
      final clientKey = payload['clientKey']?.toString().trim() ?? '';
      final agentId = payload['agentId']?.toString().trim() ?? '';
      if (clientKey.isEmpty || agentId.isEmpty) {
        throw const FormatException('إعداد المعلم الافتراضي غير مكتمل.');
      }
      if (!mounted) return;
      setState(() {
        _html = _buildEmbedHtml(clientKey: clientKey, agentId: agentId);
        _revision++;
      });
      _startTimeout();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'تعذر تجهيز المعلم الافتراضي. تحقق من اتصالك ثم أعد المحاولة.';
      });
    }
  }

  /// A minimal standalone page hosting D-ID's official Agent Embed script,
  /// with the same `clientKey`/`agentId` + target element + `data-*`
  /// attributes did_agent_embed_web.dart injects into the DOM on Flutter
  /// Web — D-ID's runtime discovers its embed only through this exact
  /// marker set.
  String _buildEmbedHtml({required String clientKey, required String agentId}) {
    final safeClientKey = clientKey.replaceAll('"', '&quot;');
    final safeAgentId = agentId.replaceAll('"', '&quot;');
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
<script
  type="module"
  src="https://agent.d-id.com/v2/index.js"
  data-mode="full"
  data-client-key="$safeClientKey"
  data-agent-id="$safeAgentId"
  data-target-id="did-agent-target"
  data-name="did-agent"
  data-monitor="true"
  data-orientation="horizontal"
  data-open-mode="expanded">
</script>
</body>
</html>
''';
  }

  void _startTimeout() {
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 15), () {
      if (mounted && _loading) {
        setState(() {
          _loading = false;
          _error = 'استغرق المعلم الافتراضي وقتًا أطول من المعتاد.';
        });
      }
    });
  }

  void _retry() {
    if (_html == null) {
      // The API call itself never succeeded last time — re-fetch the
      // config rather than just reloading an embed that was never built.
      _loadConfig();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      // Forces the InAppWebView below to remount with a fresh key, which
      // reloads the D-ID script from scratch.
      _revision++;
    });
    _startTimeout();
  }

  @override
  Widget build(BuildContext context) {
    final html = _html;
    if (html == null) {
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
          initialData: InAppWebViewInitialData(
            data: html,
            // D-ID's Agent Embed is designed to run on arbitrary customer
            // origins (that's the entire product); giving the page a real
            // https origin here — rather than the WebView's default
            // `about:blank` for injected HTML — keeps its own relative
            // requests and any origin-sensitive checks behaving the same
            // way they would on an actual website.
            baseUrl: WebUri('https://agent.d-id.com/'),
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            mediaPlaybackRequiresUserGesture: false,
            // iOS: play/record audio in place instead of forcing a
            // full-screen system UI.
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
          onReceivedError: (controller, request, error) {
            if (request.isForMainFrame != true || !mounted) return;
            _timeout?.cancel();
            setState(() {
              _loading = false;
              _error = 'تعذر تحميل المعلم الافتراضي: ${error.description}';
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
            setState(() {
              _loading = false;
              _error = 'تعذر تحميل المعلم الافتراضي: HTTP $statusCode';
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
            message: _error!,
            actionLabel: 'إعادة المحاولة',
            onAction: _retry,
          ),
      ],
    );
  }
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
        color: const Color(0xFF101D33),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const CircularProgressIndicator(color: Color(0xFFC4B5FD))
                else
                  const Icon(Icons.smart_toy_outlined,
                      color: Color(0xFFC4B5FD), size: 52),
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
