import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/student_content.dart';

class StudentCinemaScreen extends StatelessWidget {
  const StudentCinemaScreen({
    required this.videos,
    this.apiBaseUrl = '',
    super.key,
  });

  final List<LessonVideo> videos;
  final String apiBaseUrl;

  Future<void> _openVideo(BuildContext context, LessonVideo video) async {
    var raw = video.url.trim();

    if (raw.startsWith('/')) {
      final base = apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
      if (base.isNotEmpty) {
        raw = '$base$raw';
      } else {
        raw = 'https://manara-smart-edu-new.replit.app$raw';
      }
    }

    if (raw.contains('/embed/')) {
      final parts = raw.split('/embed/');
      if (parts.length > 1) {
        final id = parts[1].split('?').first.split('&').first;
        raw = 'https://www.youtube.com/watch?v=$id';
      }
    }

    final uri = Uri.tryParse(raw);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر تشغيل الفيديو: $raw')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('سينما منارة')),
        body: const Center(child: Text('لا توجد مقاطع سينما متاحة حالياً.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF071425),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071425),
        foregroundColor: Colors.white,
        title: const Text('سينما منارة'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          return Card(
            color: const Color(0xFF132337),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF0B8693), size: 40),
              title: Text(
                video.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
              ),
              subtitle: Text(
                video.description ?? 'اضغط للمشاهدة بأعلى جودة',
                style: const TextStyle(color: Color(0xFFB3C8DE)),
              ),
              trailing: const Icon(Icons.open_in_new_rounded, color: Colors.white70),
              onTap: () => _openVideo(context, video),
            ),
          );
        },
      ),
    );
  }
}
