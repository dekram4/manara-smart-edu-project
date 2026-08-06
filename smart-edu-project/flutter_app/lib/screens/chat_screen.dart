import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final controller = TextEditingController();
  String? contactId;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.chatEnabled && state.role != UserRole.admin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'المحادثة',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'تم إيقاف الدردشة الجماعية مؤقتاً من إعدادات المنصة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ManaraColors.muted,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }
    final contacts = <MapEntry<String, String>>[];
    if (state.role == UserRole.teacher) {
      final teacherStudentIds = state.studentsForCurrentTeacher
          .map((student) => student.id)
          .toSet();
      contacts
        ..addAll(state.guardiansForCurrentRole
            .where((guardian) => guardian.childIds
                .any((childId) => teacherStudentIds.contains(childId)))
            .map((item) => MapEntry(item.id, item.name)))
        ..addAll(state.studentsForCurrentTeacher
            .map((item) => MapEntry(item.id, item.name)));
    } else if (state.role == UserRole.student) {
      contacts.addAll(state.teachersForCurrentRole
          .where((teacher) {
            final subject = teacher.subject?.trim().toLowerCase() ?? '';
            return subject.isEmpty ||
                state.student?.enrollments.any(
                      (enrollment) =>
                          enrollment.subject.trim().toLowerCase() == subject,
                    ) ==
                    true;
          })
          .map((item) => MapEntry(item.id, item.name)));
    } else if (state.role == UserRole.guardian) {
      final children = state.studentsForCurrentRole
          .where((student) =>
              state.guardian?.childIds.contains(student.id) == true)
          .toList();
      contacts.addAll(state.teachersForCurrentRole
          .where((teacher) {
            final subject = teacher.subject?.trim().toLowerCase() ?? '';
            return subject.isEmpty ||
                children.any(
                  (child) => child.enrollments.any(
                    (enrollment) =>
                        enrollment.subject.trim().toLowerCase() == subject,
                  ),
                );
          })
          .map((item) => MapEntry(item.id, item.name)));
    } else if (state.role == UserRole.admin) {
      contacts
        ..addAll(state.teachersForCurrentRole
            .map((item) => MapEntry(item.id, item.name)))
        ..addAll(state.guardiansForCurrentRole
            .map((item) => MapEntry(item.id, item.name)));
    }
    final selectedConversation = contactId == null
        ? 'classroom'
        : state.privateConversationId(contactId!);
    final legacyConversation = contactId == null ? null : 'private-$contactId';
    final messages = state.messagesForCurrentRole
        .where((item) =>
            item.conversationId == selectedConversation ||
            item.conversationId == legacyConversation)
        .toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        state.markConversationRead(selectedConversation);
        if (legacyConversation != null) {
          state.markConversationRead(legacyConversation);
        }
      }
    });
    return Scaffold(
      appBar: AppBar(title: Text(contactId == null ? 'المحادثة الخاصة' : 'محادثة مباشرة', style: const TextStyle(fontWeight: FontWeight.w900))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
            child: DropdownButtonFormField<String?>(
              value: contactId,
              decoration: const InputDecoration(labelText: 'جهة الاتصال'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('محادثة الصف')),
                ...contacts.map((item) => DropdownMenuItem<String?>(value: item.key, child: Text(item.value))),
              ],
              onChanged: (value) => setState(() => contactId = value),
            ),
          ),
          Expanded(
            child: ListView.builder(
              reverse: false,
              padding: const EdgeInsets.all(18),
              itemCount: messages.length,
              itemBuilder: (_, index) {
                final message = messages[index];
                final mine = message.senderId == state.userId;
                return Align(
                  alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    decoration: BoxDecoration(
                      color: mine ? ManaraColors.purple : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(message.senderName, style: TextStyle(color: mine ? Colors.white70 : ManaraColors.purple, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        Text(message.message, style: TextStyle(color: mine ? Colors.white : ManaraColors.ink, fontSize: 15)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: controller, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'اكتب رسالتك...'))),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(onPressed: _send, backgroundColor: ManaraColors.purple, foregroundColor: Colors.white, child: const Icon(Icons.send_rounded)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _send() {
    final state = context.read<AppState>();
    final id = contactId == null
        ? 'classroom'
        : state.privateConversationId(contactId!);
    state.sendMessage(controller.text,
        conversationId: id, recipientId: contactId ?? '');
    controller.clear();
  }
}