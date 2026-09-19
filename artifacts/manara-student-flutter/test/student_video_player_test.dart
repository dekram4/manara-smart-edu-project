import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/models/student_content.dart';
import 'package:manara_student/src/widgets/student_video_player.dart';

LessonVideo _video({
  required String url,
  VideoSourceType sourceType = VideoSourceType.embed,
}) {
  return LessonVideo(
    id: 'v1',
    url: url,
    sourceType: sourceType,
    title: 'اختبار',
  );
}

void main() {
  group('resolveStudentVideoUrl', () {
    test('rewrites a youtube watch URL into a privacy embed URL', () {
      final resolved = resolveStudentVideoUrl(
        _video(url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
      );
      expect(resolved, contains('youtube.com/embed/dQw4w9WgXcQ'));
      expect(resolved, contains('playsinline=1'));
    });

    test('rewrites a youtu.be short link into an embed URL', () {
      final resolved = resolveStudentVideoUrl(
        _video(url: 'https://youtu.be/dQw4w9WgXcQ?t=5'),
      );
      expect(resolved, contains('youtube.com/embed/dQw4w9WgXcQ'));
    });

    test('leaves a direct mp4 URL untouched', () {
      const mp4Url =
          'https://project.supabase.co/storage/v1/object/public/lesson-videos/a.mp4';
      final resolved = resolveStudentVideoUrl(
        _video(url: mp4Url, sourceType: VideoSourceType.mp4),
      );
      expect(resolved, mp4Url);
    });

    test('resolves a relative API path against the configured base URL', () {
      final resolved = resolveStudentVideoUrl(
        _video(url: '/media/lesson.mp4', sourceType: VideoSourceType.mp4),
        apiBaseUrl: 'https://api.manara.example/',
      );
      expect(resolved, 'https://api.manara.example/media/lesson.mp4');
    });
  });

  group('isDirectVideoUrl', () {
    test('treats an mp4-typed lesson video as a native/direct video', () {
      final video = _video(
        url: 'https://cdn.example.com/lesson.mp4',
        sourceType: VideoSourceType.mp4,
      );
      expect(isDirectVideoUrl(video.url, video), isTrue);
    });

    test('treats a youtube embed as not a direct/native video', () {
      final video = _video(url: 'https://www.youtube.com/embed/dQw4w9WgXcQ');
      expect(isDirectVideoUrl(video.url, video), isFalse);
    });

    test('detects a public Supabase Storage object as a direct video', () {
      final video = _video(
        url: 'https://p.supabase.co/storage/v1/object/public/videos/a.mp4',
      );
      expect(isDirectVideoUrl(video.url, video), isTrue);
    });
  });

  group('youtube host/id helpers', () {
    test('recognizes every youtube host variant', () {
      expect(isYoutubeHost('youtube.com'), isTrue);
      expect(isYoutubeHost('m.youtube.com'), isTrue);
      expect(isYoutubeHost('youtu.be'), isTrue);
      expect(isYoutubeHost('youtube-nocookie.com'), isTrue);
      expect(isYoutubeHost('vimeo.com'), isFalse);
    });

    test('extracts the video id from a watch URL', () {
      final uri = Uri.parse('https://www.youtube.com/watch?v=abc123XYZ_-');
      expect(youtubeVideoId(uri, 'youtube.com'), 'abc123XYZ_-');
    });

    test('extracts the video id from a shorts URL', () {
      final uri = Uri.parse('https://www.youtube.com/shorts/abc123XYZ_-');
      expect(youtubeVideoId(uri, 'youtube.com'), 'abc123XYZ_-');
    });
  });

  group('fullscreen fills the screen', () {
    // The side bars a 16:9 lesson left on a 20:9 phone were the "still
    // stuck in the middle" report: fullscreen now fills unless that would
    // crop too much of the picture.
    test('a 16:9 lesson fills a 20:9 phone held sideways', () {
      expect(
        studentVideoFillsScreen(const Size(800, 360), const Size(1920, 1080)),
        isTrue,
      );
    });

    test('a 16:9 lesson fills a 16:10 tablet', () {
      expect(
        studentVideoFillsScreen(const Size(1280, 800), const Size(1280, 720)),
        isTrue,
      );
    });

    test('a clip filmed upright is shown whole on a wide screen', () {
      expect(
        studentVideoFillsScreen(const Size(800, 360), const Size(720, 1280)),
        isFalse,
      );
    });

    test('an unknown size fills', () {
      expect(studentVideoFillsScreen(const Size(800, 360), Size.zero), isTrue);
    });
  });
}
