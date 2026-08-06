import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class LiveMeetingsScreen extends StatelessWidget {
  const LiveMeetingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الاجتماعات المباشرة',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          if (state.permissions['canAccessLiveMeeting'] != true) {
            return const _MeetingEmpty(
              icon: Icons.lock_outline_rounded,
              message: 'لا تملك صلاحية الوصول إلى الاجتماعات المباشرة.',
            );
          }
          final lessons = state.lessonsForCurrentRole
              .where((lesson) => lesson.liveMeetingUrl.trim().isNotEmpty)
              .toList();
          if (lessons.isEmpty) {
            return const _MeetingEmpty(
              icon: Icons.podcasts_outlined,
              message: 'لا توجد اجتماعات مباشرة مرتبطة بدروسك حالياً.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
            children: [
              const Text(
                'الاجتماعات المرتبطة بالدروس الحالية',
                style: TextStyle(
                    color: ManaraColors.muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              ...lessons.map((lesson) => _MeetingCard(lesson: lesson)),
            ],
          );
        },
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({required this.lesson});
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(21)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                  backgroundColor: Color(0xFFE4FAF2),
                  child: Text('📡')),
              const SizedBox(width: 13),
              Expanded(
                child: Text(lesson.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              const Chip(
                  label: Text('متاح'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Color(0xFFE4FAF2)),
            ],
          ),
          const SizedBox(height: 10),
          Text('${lesson.subject} • ${lesson.unit}',
              style: const TextStyle(
                  color: ManaraColors.muted, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showLink(context),
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('عرض رابط الاجتماع'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  context.read<AppState>().recordInteraction(
                        action: 'live_meeting_join',
                        lessonId: lesson.id,
                        grade: lesson.grade,
                        subject: lesson.subject,
                        unit: lesson.unit,
                      );
                  await _openMeeting(context);
                },
                child: const Text('انضمام'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLink(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(lesson.title),
        content: SelectableText(lesson.liveMeetingUrl),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                  ClipboardData(text: lesson.liveMeetingUrl));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('نسخ الرابط'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _openMeeting(context);
            },
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('فتح الاجتماع'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Future<void> _openMeeting(BuildContext context) async {
    final uri = Uri.tryParse(lesson.liveMeetingUrl.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('رابط الاجتماع غير صالح')),
        );
      }
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح الرابط، يمكنك نسخه يدوياً')),
      );
    }
  }
}

class _MeetingEmpty extends StatelessWidget {
  const _MeetingEmpty({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 58, color: ManaraColors.muted),
              const SizedBox(height: 14),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: ManaraColors.muted,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
}