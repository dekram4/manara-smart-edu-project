import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'records_manager.dart';

class VideoNotificationsScreen extends StatefulWidget {
  const VideoNotificationsScreen({super.key});

  @override
  State<VideoNotificationsScreen> createState() => _VideoNotificationsScreenState();
}

class _VideoNotificationsScreenState extends State<VideoNotificationsScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('إشعارات الفيديو', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            Consumer<AppState>(
              builder: (_, state, __) => state.videoNotifications.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                        onPressed: state.clearVideoNotifications,
                        tooltip: 'حذف الإشعارات',
                        icon: const Icon(Icons.delete_sweep_outlined),
                      ),
            ),
            if (context.read<AppState>().role == UserRole.admin ||
                context.read<AppState>().role == UserRole.teacher)
              IconButton(
                tooltip: 'إضافة فيديو',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const CreateRecordScreen(type: RecordType.videos),
                  ),
                ),
                icon: const Icon(Icons.add_circle_outline),
              ),
          ],
        ),
        body: Consumer<AppState>(
          builder: (context, state, _) {
            final videos = state.videosForCurrentRole;
            final hasContent =
                videos.isNotEmpty || state.videoNotifications.isNotEmpty;
            return !hasContent
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('📢', style: TextStyle(fontSize: 64)),
                      SizedBox(height: 12),
                      Text('لا توجد إشعارات حالياً',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 20)),
                      SizedBox(height: 8),
                      Text('ستظهر هنا إشعارات الفيديوهات الجديدة من المعلمين',
                          style: TextStyle(color: ManaraColors.muted)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (videos.isNotEmpty) ...[
                      const Text(
                        'سجل الفيديوهات',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...videos.map(
                        (video) => _VideoRecordTile(
                          video: video,
                          canManage: state.role == UserRole.admin ||
                              state.role == UserRole.teacher,
                          onEdit: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateRecordScreen(
                                type: RecordType.videos,
                                video: video,
                              ),
                            ),
                          ),
                          onDelete: () => _confirmDelete(context, state, video),
                        ),
                      ),
                    ],
                    if (state.videoNotifications.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Text(
                        'آخر الإشعارات',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...state.videoNotifications.map(
                        (notification) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFFFFF0E2),
                                child: Text('📢'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  notification,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                );
          },
        ),
      );

  Future<void> _confirmDelete(
    BuildContext context,
    AppState state,
    VideoLesson video,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الفيديو؟'),
        content: Text('سيتم حذف «${video.title}» من السجل.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) state.removeVideo(video.id);
  }
}

class _VideoRecordTile extends StatelessWidget {
  const _VideoRecordTile({
    required this.video,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final VideoLesson video;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scope = [
      if (video.grade.isNotEmpty) video.grade,
      if (video.atram.isNotEmpty) video.atram,
      if (video.subject.isNotEmpty) video.subject,
      if (video.term.isNotEmpty) video.term,
      if (video.unit.isNotEmpty) video.unit,
    ].join(' • ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFFFF0E2),
            child: Text('🎬'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (scope.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    scope,
                    style: const TextStyle(
                      color: ManaraColors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${video.createdByName} • ${video.duration}',
                  style: const TextStyle(
                    color: ManaraColors.muted,
                    fontSize: 12,
                  ),
                ),
                if (video.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    video.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ManaraColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (canManage) ...[
            IconButton(
              tooltip: 'تعديل',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, color: ManaraColors.blue),
            ),
            IconButton(
              tooltip: 'حذف',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            ),
          ],
        ],
      ),
    );
  }
}