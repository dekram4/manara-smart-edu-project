import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/student_profile.dart';

class StudentChatScreen extends StatefulWidget {
  const StudentChatScreen({
    required this.profile,
    required this.apiBaseUrl,
    required this.studentSessionToken,
    super.key,
  });

  final StudentProfile profile;
  final String apiBaseUrl;
  final String? studentSessionToken;

  @override
  State<StudentChatScreen> createState() => _StudentChatScreenState();
}

class _StudentChatScreenState extends State<StudentChatScreen> {
  final _messageController = TextEditingController();
  List<_ChatMessage> _messages = const [];
  List<_ChatPeer> _peers = const [];
  String _recipient = 'all';
  String? _error;
  bool _loading = true;
  bool _sending = false;

  String? get _token {
    final token = widget.studentSessionToken?.trim();
    return token == null || token.isEmpty ? null : token;
  }

  Uri? _endpoint(String route) {
    var base = widget.apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    if (base.isEmpty) {
      final current = Uri.base;
      if (current.scheme == 'http' || current.scheme == 'https') {
        base = current.host == 'localhost' || current.host == '127.0.0.1'
            ? 'http://localhost:8080'
            : current.origin;
      }
    }
    return base.isEmpty ? null : Uri.tryParse('$base/api/student/chat/$route');
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${_token!}',
        'Content-Type': 'application/json',
      };

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!widget.profile.canAccessChat) {
      setState(() {
        _loading = false;
        _error = 'الدردشة غير مفعلة لحسابك.';
      });
      return;
    }
    if (_token == null || _endpoint('messages') == null) {
      setState(() {
        _loading = false;
        _error = 'تعذر التحقق من جلسة الطالب. سجّل الدخول مرة أخرى.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final responses = await Future.wait([
        http.get(_endpoint('messages')!, headers: _headers),
        http.get(_endpoint('peers')!, headers: _headers),
      ]).timeout(const Duration(seconds: 15));
      final messageData = _decode(responses[0]);
      final peerData = _decode(responses[1]);
      if (responses[0].statusCode != 200 || responses[1].statusCode != 200) {
        throw Exception(_responseError(messageData) ?? _responseError(peerData) ?? 'تعذر تحميل الدردشة.');
      }
      final messages = messageData['messages'] is List
          ? (messageData['messages'] as List).map(_ChatMessage.fromJson).toList()
          : <_ChatMessage>[];
      final peers = peerData['peers'] is List
          ? (peerData['peers'] as List).map(_ChatPeer.fromJson).toList()
          : <_ChatPeer>[];
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _peers = peers;
        if (_recipient != 'all' && !peers.any((peer) => peer.id == _recipient)) _recipient = 'all';
      });
    } catch (error) {
      if (mounted) setState(() => _error = _safeError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final endpoint = _endpoint('messages');
    final message = _messageController.text.trim();
    if (message.isEmpty || endpoint == null || _token == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final response = await http
          .post(endpoint, headers: _headers, body: jsonEncode({'message': message, 'to': _recipient}))
          .timeout(const Duration(seconds: 15));
      final data = _decode(response);
      if (response.statusCode != 201) throw Exception(_responseError(data) ?? 'تعذر إرسال الرسالة.');
      _messageController.clear();
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = _safeError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(response.body);
    return decoded is Map ? decoded.map((key, value) => MapEntry('$key', value)) : <String, dynamic>{};
  }

  String? _responseError(Map<String, dynamic> data) => data['error']?.toString();

  @override
  Widget build(BuildContext context) {
    final disabled = !widget.profile.canAccessChat;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FF),
        appBar: AppBar(
          title: const Text('دردشة منارة'),
          actions: [IconButton(onPressed: _loading ? null : _refresh, icon: const Icon(Icons.refresh_rounded))],
        ),
        body: disabled || _token == null
            ? _ChatStatus(icon: Icons.lock_outline_rounded, message: disabled
                ? 'الدردشة غير مفعلة لحسابك.'
                : 'سجّل الدخول مرة أخرى لتفعيل الدردشة الآمنة.')
            : Column(
                children: [
                  if (_error != null) _ChatError(text: _error!),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _messages.isEmpty
                            ? const _ChatStatus(icon: Icons.forum_outlined, message: 'لا توجد رسائل بعد. ابدأ حديثًا لطيفًا مع زملائك.')
                            : ListView.builder(
                                padding: const EdgeInsets.all(14),
                                itemCount: _messages.length,
                                itemBuilder: (_, index) => _MessageBubble(
                                  message: _messages[index],
                                  mine: _messages[index].from == widget.profile.id,
                                ),
                              ),
                  ),
                  _composer(),
                ],
              ),
      ),
    );
  }

  Widget _composer() => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          color: Colors.white,
          child: Column(children: [
            DropdownButtonFormField<String>(
              value: _recipient,
              decoration: const InputDecoration(labelText: 'إرسال إلى', isDense: true),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('زملاء صفي')),
                ..._peers.map((peer) => DropdownMenuItem(value: peer.id, child: Text(peer.name))),
              ],
              onChanged: _sending ? null : (value) => setState(() => _recipient = value ?? 'all'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  enabled: !_sending,
                  maxLength: 1000,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'اكتب رسالة محترمة...', counterText: ''),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
              ),
            ]),
          ]),
        ),
      );
}

class _ChatMessage {
  const _ChatMessage({required this.id, required this.from, required this.name, required this.to, required this.message, required this.time});
  factory _ChatMessage.fromJson(dynamic value) {
    final map = value is Map ? value : const <String, dynamic>{};
    return _ChatMessage(id: '${map['id'] ?? ''}', from: '${map['from'] ?? ''}', name: '${map['name'] ?? 'طالب'}', to: '${map['to'] ?? 'all'}', message: '${map['message'] ?? ''}', time: '${map['time'] ?? ''}');
  }
  final String id, from, name, to, message, time;
}

class _ChatPeer {
  const _ChatPeer(this.id, this.name);
  factory _ChatPeer.fromJson(dynamic value) {
    final map = value is Map ? value : const <String, dynamic>{};
    return _ChatPeer('${map['id'] ?? ''}', '${map['name'] ?? 'طالب'}');
  }
  final String id, name;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});
  final _ChatMessage message;
  final bool mine;
  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(color: mine ? const Color(0xFF0B8693) : Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(mine ? 'أنت' : message.name, style: TextStyle(fontWeight: FontWeight.w800, color: mine ? Colors.white : const Color(0xFF0B8693))),
        const SizedBox(height: 4),
        Text(message.message, style: TextStyle(height: 1.45, color: mine ? Colors.white : const Color(0xFF17233A))),
      ]),
    ),
  );
}

class _ChatStatus extends StatelessWidget {
  const _ChatStatus({required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 58, color: const Color(0xFF0B8693)), const SizedBox(height: 14), Text(message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.6))])));
}

class _ChatError extends StatelessWidget {
  const _ChatError({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(12)), child: Text(text, style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w700)));
}

String _safeError(Object error) {
  final text = error.toString().replaceFirst('Exception: ', '').trim();
  if (text.contains('الدردشة') || text.contains('جلسة') || text.contains('رسالة')) return text;
  return 'تعذر الوصول إلى الدردشة الآن. تحقق من اتصالك ثم حاول مرة أخرى.';
}