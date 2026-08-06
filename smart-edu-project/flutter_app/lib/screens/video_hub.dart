import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/academic_scope_selector.dart';
import 'video_player_screen.dart';

class VideoHub extends StatefulWidget {
  const VideoHub({super.key, this.initialSelection});
  final AcademicScopeSelection? initialSelection;

  @override
  State<VideoHub> createState() => _VideoHubState();
}

class _VideoHubState extends State<VideoHub> {
  String query = '';
  late AcademicScopeSelection selection;

  @override
  void initState() {
    super.initState();
    selection = widget.initialSelection ?? const AcademicScopeSelection();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final videos = state.videosForCurrentRole.where((video) {
          final text = '${video.title} ${video.subject}'.toLowerCase();
          return (query.trim().isEmpty ||
                  text.contains(query.trim().toLowerCase())) &&
              _matchesSelection(video);
        }).toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('مركز الفيديو',
                style: TextStyle(fontWeight: FontWeight.w900)),
            actions: [
              if (query.isNotEmpty)
                IconButton(
                  tooltip: 'مسح البحث',
                  onPressed: () => setState(() => query = ''),
                  icon: const Icon(Icons.clear_rounded),
                ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: TextField(
                  onChanged: (value) => setState(() => query = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'ابحث باسم الفيديو أو المادة...',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: AcademicScopeSelector(
                  paths: state.academicPathsForCurrentRole,
                  initialGrade: state.student?.primaryGrade ?? '',
                  initialSelection: selection,
                  onChanged: (next) => setState(() => selection = next),
                ),
              ),
              Expanded(
                child: videos.isEmpty
                    ? Center(
                        child: Text(
                            query.isEmpty
                                ? 'لا توجد فيديوهات متاحة حالياً'
                                : 'لا توجد نتائج مطابقة',
                            style: const TextStyle(
                                color: ManaraColors.muted,
                                fontWeight: FontWeight.w700)))
                    : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                  itemCount: videos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    return _VideoCard(video: video);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _matchesSelection(VideoLesson video) {
    bool matches(String selected, String actual) =>
        selected.isEmpty ||
        actual.trim().isEmpty ||
        selected.trim().toLowerCase() == actual.trim().toLowerCase();

    return matches(selection.grade, video.grade) &&
        matches(selection.atram, video.atram) &&
        matches(selection.subject, video.subject) &&
        matches(selection.term, video.term) &&
        matches(selection.unit, video.unit);
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video});
  final VideoLesson video;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: video))),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 150,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [ManaraColors.deepPurple, ManaraColors.blue]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Stack(
                children: [
                  Center(child: Text(video.emoji, style: const TextStyle(fontSize: 66))),
                  Positioned(
                    bottom: 12,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
                      child: Text(video.duration, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (video.isNew)
                    Positioned(
                      top: 12,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: ManaraColors.orange, borderRadius: BorderRadius.circular(12)),
                        child: const Text('جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  const Center(
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.play_arrow_rounded, color: ManaraColors.purple, size: 32),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(video.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(video.subject, style: const TextStyle(color: ManaraColors.purple, fontWeight: FontWeight.bold)),
                   if (_scope(video).isNotEmpty) ...[
                     const SizedBox(height: 5),
                     Text(
                       _scope(video),
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis,
                       style: const TextStyle(
                         color: ManaraColors.muted,
                         fontSize: 12,
                       ),
                     ),
                   ],
                   if (video.description.trim().isNotEmpty) ...[
                     const SizedBox(height: 7),
                     Text(
                       video.description,
                       maxLines: 2,
                       overflow: TextOverflow.ellipsis,
                       style: const TextStyle(
                         color: ManaraColors.muted,
                         fontSize: 13,
                       ),
                     ),
                   ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _scope(VideoLesson video) => [
        if (video.grade.isNotEmpty) video.grade,
        if (video.atram.isNotEmpty) video.atram,
        if (video.term.isNotEmpty) video.term,
        if (video.unit.isNotEmpty) video.unit,
      ].join(' • ');
}