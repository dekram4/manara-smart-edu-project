import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  String? _viewId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEmbed();
  }

  String _apiBase() {
    var base = widget.apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    if (base.isNotEmpty) return base;
    final current = Uri.base;
    if (current.scheme != 'http' && current.scheme != 'https') return '';
    final local = current.host == 'localhost' || current.host == '127.0.0.1';
    return local ? 'http://localhost:8080' : current.origin;
  }

  Future<void> _loadEmbed() async {
    setState(() {
      _viewId = null;
      _error = null;
    });
    final base = _apiBase();
    if (base.isEmpty) {
      setState(() => _error = 'تعذر الوصول إلى إعداد المعلم الافتراضي.');
      return;
    }
    try {
      final response = await http
          .get(Uri.parse('$base/api/did-agent/config'))
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
      final viewId = 'manara-did-agent-${identityHashCode(this)}';
      _registerEmbed(viewId: viewId, clientKey: clientKey, agentId: agentId);
      if (mounted) setState(() => _viewId = viewId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'تعذر تجهيز المعلم الافتراضي. تحقق من اتصالك ثم أعد المحاولة.';
        });
      }
    }
  }

  void _registerEmbed({
    required String viewId,
    required String clientKey,
    required String agentId,
  }) {
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int _) {
      final rootId = '$viewId-target';
      final root = html.DivElement()
        ..id = rootId
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.minHeight = '360px'
        ..style.backgroundColor = '#101D33'
        ..style.overflow = 'hidden';
      final script = html.ScriptElement()
        ..type = 'module'
        ..src = 'https://agent.d-id.com/v2/index.js'
        ..setAttribute('data-mode', 'full')
        ..setAttribute('data-client-key', clientKey)
        ..setAttribute('data-agent-id', agentId)
        ..setAttribute('data-target-id', rootId)
        // D-ID's runtime discovers its embed only through this exact marker.
        ..setAttribute('data-name', 'did-agent')
        ..setAttribute('data-monitor', 'true')
        ..setAttribute('data-orientation', 'horizontal')
        ..setAttribute('data-open-mode', 'expanded');
      // Keep the script as a document-level element, like D-ID's official
      // embed example. The target itself remains the platform-view root.
      // Waiting until the root is connected also makes the target discoverable
      // when the module starts.
      var attempts = 0;
      void appendScriptWhenConnected() {
        if (root.isConnected == true) {
          html.document.body?.append(script);
          return;
        }
        if (attempts++ < 40) {
          Timer(const Duration(milliseconds: 50), appendScriptWhenConnected);
        }
      }

      Timer.run(appendScriptWhenConnected);
      return root;
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return _DIdStateCard(
        title: 'تعذر تشغيل المعلم الافتراضي',
        message: error,
        actionLabel: 'إعادة المحاولة',
        onAction: _loadEmbed,
      );
    }
    final viewId = _viewId;
    if (viewId == null) {
      return const _DIdStateCard(
        title: 'يتم تجهيز المعلم الافتراضي',
        message: 'لحظات قليلة، يجري الاتصال بصديقك الذكي.',
        loading: true,
      );
    }
    return HtmlElementView(viewType: viewId);
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