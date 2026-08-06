import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.video});
  final VideoLesson video;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? controller;
  Object? error;
  bool recordedView = false;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    final rawUrl = widget.video.url?.trim() ?? '';
    final rawUri = Uri.tryParse(rawUrl);
    if (_isExternalWebVideo(rawUri)) {
      if (mounted) {
        setState(() {
          error = StateError('external web video');
        });
      }
      return;
    }
    final url = await context.read<AppState>().resolveVideoUrl(widget.video.url);
    final uri = url == null ? null : Uri.tryParse(url.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      if (mounted) {
        setState(() => error = StateError('invalid video url'));
      }
      return;
    }
    if (mounted) {
      setState(() {
        error = null;
      });
    }
    final next = VideoPlayerController.networkUrl(uri);
    final previous = controller;
    controller = next;
    await previous?.dispose();
    try {
      await next.initialize();
      if (!mounted) {
        await next.dispose();
        return;
      }
      _recordView();
      setState(() {});
    } catch (caught) {
      await next.dispose();
      if (mounted) {
        setState(() {
          controller = null;
          error = caught;
        });
      }
    }
  }

  bool _isExternalWebVideo(Uri? uri) {
    if (uri == null || !uri.hasScheme) return false;
    final host = uri.host.toLowerCase();
    return host.contains('youtube.com') ||
        host.contains('youtu.be') ||
        host.contains('vimeo.com') ||
        host.contains('drive.google.com');
  }

  Future<void> _openExternalVideo() async {
    final uri = Uri.tryParse(widget.video.url?.trim() ?? '');
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح رابط الفيديو')),
      );
    }
  }

  void _recordView() {
    if (recordedView || !mounted) return;
    recordedView = true;
    context.read<AppState>().recordInteraction(
          action: 'video_view',
          subject: widget.video.subject,
          unit: widget.video.title,
        );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = controller;
    final ready = player != null && player.value.isInitialized && error == null;
    return Scaffold(
      appBar: AppBar(title: Text(widget.video.title, style: const TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AspectRatio(
            aspectRatio: ready ? player!.value.aspectRatio : 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [ManaraColors.deepPurple, ManaraColors.blue]),
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: ready
                  ? Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        VideoPlayer(player!),
                        VideoProgressIndicator(player!, allowScrubbing: true, colors: const VideoProgressColors(playedColor: ManaraColors.orange)),
                        Center(
                          child: IconButton.filled(
                            onPressed: () => setState(() => player!.value.isPlaying ? player!.pause() : player!.play()),
                            iconSize: 34,
                            icon: Icon(player!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: error != null
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                               Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Text(
                                    widget.video.url == null ||
                                            widget.video.url!.trim().isEmpty
                                        ? 'لا يوجد رابط فيديو لهذا المحتوى'
                                        : 'تعذر تحميل الفيديو، تحقق من الاتصال أو الرابط',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (_isExternalWebVideo(
                                  Uri.tryParse(widget.video.url?.trim() ?? ''),
                                ))
                                  OutlinedButton.icon(
                                    onPressed: _openExternalVideo,
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('فتح الفيديو'),
                                  ),
                                if (widget.video.url != null &&
                                    widget.video.url!.trim().isNotEmpty)
                                  OutlinedButton.icon(
                                    onPressed: _loadVideo,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('إعادة المحاولة'),
                                  ),
                              ],
                            )
                          : const CircularProgressIndicator(color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Text(widget.video.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('${widget.video.subject} • ${widget.video.duration}', style: const TextStyle(color: ManaraColors.purple, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
           if (_scope.isNotEmpty)
             Text(
               _scope,
               style: const TextStyle(
                 color: ManaraColors.muted,
                 fontSize: 13,
                 height: 1.5,
               ),
             ),
           if (widget.video.description.trim().isNotEmpty) ...[
             const SizedBox(height: 12),
             Text(
               widget.video.description,
               style: const TextStyle(
                 color: ManaraColors.muted,
                 fontSize: 16,
                 height: 1.6,
               ),
             ),
           ],
           const SizedBox(height: 12),
           const Text('شاهد الدرس ثم أجب عن التحدي المرتبط به لتحصل على XP وجواهر إضافية.', style: TextStyle(color: ManaraColors.muted, fontSize: 16, height: 1.6)),
        ],
      ),
    );
  }

  String get _scope => [
        if (widget.video.grade.isNotEmpty) widget.video.grade,
        if (widget.video.atram.isNotEmpty) widget.video.atram,
        if (widget.video.term.isNotEmpty) widget.video.term,
        if (widget.video.unit.isNotEmpty) widget.video.unit,
      ].join(' • ');
}