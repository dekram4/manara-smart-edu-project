import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../models/student_content.dart';
import 'student_video_player.dart' show isYoutubeHost, youtubeVideoId;

/// Resolves the cover image for a video the way a video app does.
///
/// YouTube publishes a still for every video at a predictable URL, so the
/// real frame is fetched straight from the id — no API key, no extra
/// request to our own backend. Anything else has no such endpoint, and is
/// handled by decoding a frame out of the clip itself; see
/// [_Mp4FrameCover].
String? youtubeThumbnailUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  if (!isYoutubeHost(host)) return null;
  final id = youtubeVideoId(uri, host);
  if (id.isEmpty) return null;
  return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
}

/// Formats a duration the way a video badge does: 5:20, or 1:05:20 past an
/// hour. Returns null for an unknown or zero duration so the badge can be
/// omitted rather than showing a fake 00:00.
String? formatVideoDuration(Duration? duration) {
  if (duration == null || duration.inSeconds <= 0) return null;
  final seconds = duration.inSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final mm = h > 0 ? m.toString().padLeft(2, '0') : m.toString();
  return h > 0
      ? '$h:$mm:${s.toString().padLeft(2, '0')}'
      : '$mm:${s.toString().padLeft(2, '0')}';
}

/// A video card in the shape people already know: a 16:9 cover with a play
/// button over it and a duration badge in its corner, the title underneath,
/// then a line of secondary detail.
///
/// This replaced solid colour tiles with a glyph on them, which gave a
/// child no idea what any clip actually was.
class VideoThumbnailCard extends StatelessWidget {
  const VideoThumbnailCard({
    required this.video,
    required this.onTap,
    this.duration,
    this.subtitle,
    this.progress,
    this.locked = false,
    this.dark = false,
    super.key,
  });

  final LessonVideo video;
  final VoidCallback? onTap;

  /// Shown as the corner badge when known. The catalogue does not record
  /// clip lengths yet, so this is usually null and the badge is simply not
  /// drawn — better than inventing a number.
  final Duration? duration;

  final String? subtitle;

  /// 0..1 watched fraction, drawn as the red bar across the cover's foot.
  final double? progress;

  final bool locked;

  /// The cinema is a dark room; the lesson list is not.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final titleColor = dark ? Colors.white : const Color(0xFF0E1B2A);
    final subColor = dark ? const Color(0xFFA9BBD0) : const Color(0xFF5A7286);
    final durationLabel = formatVideoDuration(duration);

    return InkWell(
      onTap: locked ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              // The shape every video cover uses; it also stops a long or
              // short thumbnail from changing the card's height.
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Cover(video: video),
                  // A soft scrim so the play button and the badge stay
                  // readable over a bright frame.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0x59000000)],
                        stops: [0.55, 1],
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.85),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        locked
                            ? Icons.lock_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  if (durationLabel != null)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.78),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          durationLabel,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  if (progress != null && progress! > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: progress!.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: Colors.black26,
                        color: const Color(0xFFE53935),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            video.title.trim().isEmpty ? 'مقطع تعليمي' : video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: titleColor,
              fontSize: 14.5,
              height: 1.35,
              fontWeight: FontWeight.w900,
            ),
          ),
          if ((subtitle ?? video.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              (subtitle ?? video.description!).trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: subColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The cover image itself: the real YouTube still when there is one, a
/// frame grabbed from the clip when it is an MP4, and a themed placeholder
/// otherwise — a cover must never render as a broken box.
class _Cover extends StatelessWidget {
  const _Cover({required this.video});

  final LessonVideo video;

  @override
  Widget build(BuildContext context) {
    final thumbnail = youtubeThumbnailUrl(video.url);
    if (thumbnail != null) {
      return Image.network(
        thumbnail,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _CoverPlaceholder(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const _CoverPlaceholder(),
      );
    }
    return _Mp4FrameCover(url: video.url);
  }
}

/// Grabs the first frame of a non-YouTube clip.
///
/// `video_thumbnail` is an Android/iOS plugin — it has no desktop or web
/// implementation — so everywhere else this degrades to the themed cover
/// rather than throwing a MissingPluginException at a child.
///
/// Extraction decodes part of the clip, so results are memoised by URL for
/// the process: a grid that scrolls back and forth, or a rebuild from any
/// unrelated setState, must not re-decode the same video.
class _Mp4FrameCover extends StatefulWidget {
  const _Mp4FrameCover({required this.url});

  final String url;

  static final Map<String, Uint8List?> _cache = <String, Uint8List?>{};

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  State<_Mp4FrameCover> createState() => _Mp4FrameCoverState();
}

class _Mp4FrameCoverState extends State<_Mp4FrameCover> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _Mp4FrameCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _resolve();
  }

  Future<void> _resolve() async {
    if (!_Mp4FrameCover.isSupported) return;
    final url = widget.url;
    if (url.trim().isEmpty) return;

    if (_Mp4FrameCover._cache.containsKey(url)) {
      final cached = _Mp4FrameCover._cache[url];
      if (cached != null && mounted) setState(() => _bytes = cached);
      return;
    }

    Uint8List? data;
    try {
      data = await VideoThumbnail.thumbnailData(
        video: url,
        imageFormat: ImageFormat.JPEG,
        // Wide enough for a card cover on any phone, small enough that
        // decoding stays cheap.
        maxWidth: 640,
        quality: 60,
      );
    } catch (_) {
      // A clip the device cannot decode, or an unreachable URL — the
      // placeholder is a perfectly good cover.
      data = null;
    }
    // Negative results are cached too, so an undecodable clip is attempted
    // once rather than on every rebuild.
    _Mp4FrameCover._cache[url] = data;
    if (data != null && mounted) setState(() => _bytes = data);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) return const _CoverPlaceholder();
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const _CoverPlaceholder(),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16324A), Color(0xFF0B8693)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.movie_creation_rounded,
          color: Color(0x66FFFFFF),
          size: 40,
        ),
      ),
    );
  }
}
