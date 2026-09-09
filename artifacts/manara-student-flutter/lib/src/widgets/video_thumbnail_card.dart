import 'package:flutter/material.dart';

import '../models/student_content.dart';
import 'student_video_player.dart' show isYoutubeHost, youtubeVideoId;

/// Resolves the cover image for a video the way a video app does.
///
/// YouTube publishes a still for every video at a predictable URL, so the
/// real frame is fetched straight from the id — no API key, no extra
/// request to our own backend. Anything else (an MP4 in storage, a Vimeo
/// link) has no such endpoint, so those fall back to a themed cover with
/// the play affordance on it rather than a broken image box.
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
/// themed placeholder otherwise, and the placeholder again if the network
/// image fails — a cover must never render as a broken box.
class _Cover extends StatelessWidget {
  const _Cover({required this.video});

  final LessonVideo video;

  @override
  Widget build(BuildContext context) {
    final thumbnail = youtubeThumbnailUrl(video.url);
    if (thumbnail == null) return const _CoverPlaceholder();
    return Image.network(
      thumbnail,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const _CoverPlaceholder(),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const _CoverPlaceholder(),
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
