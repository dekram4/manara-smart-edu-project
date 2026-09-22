import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/models/student_content.dart';

/// What counts as a lesson the child can finish.
///
/// The reward button hangs on this. A lesson the teacher has not written yet
/// must not pay gems for being opened — a child who is paid for opening
/// empty lessons learns that gems come from tapping, not from learning.
void main() {
  LessonContent lesson({
    String? text,
    String? avatar,
    String? meeting,
    List<LessonVideo> videos = const [],
    List<HtmlGame> games = const [],
  }) =>
      LessonContent(
        id: 'l1',
        lessonId: 'l1',
        grade: 'الرابع',
        subject: 'الرياضيات',
        term: 'الفصل الأول',
        unit: 'الجمع والطرح',
        lessonName: 'خصائص الجمع',
        createdAt: '',
        lessonText: text,
        avatarInteractionUrl: avatar,
        liveMeetingUrl: meeting,
        videos: videos,
        games: games,
      );

  test('a lesson with nothing in it has no explanation', () {
    expect(lesson().hasExplanation, isFalse);
  });

  test('blank text is not an explanation', () {
    expect(lesson(text: '   ').hasExplanation, isFalse);
  });

  group('any one of the four counts', () {
    test('written text', () {
      expect(lesson(text: 'الجمع تبديلي').hasExplanation, isTrue);
    });

    test('a video', () {
      expect(
        lesson(videos: const [
          LessonVideo(
            id: 'v1',
            url: 'https://x/v.mp4',
            sourceType: VideoSourceType.mp4,
            title: 'شرح',
          ),
        ])
            .hasExplanation,
        isTrue,
      );
    });

    test('the virtual teacher', () {
      expect(lesson(avatar: 'https://x/avatar').hasExplanation, isTrue);
    });

    test('a live meeting', () {
      expect(lesson(meeting: 'https://x/meet').hasExplanation, isTrue);
    });
  });

  test('a game alone is not an explanation', () {
    // ‏اللعبة مرافقة للدرس لا شرحٌ له، ودرسٌ لا يحمل إلا لعبة لم يشرحه
    // ‏معلّمه بعد — فلا يُكافأ الطفل على «إنهائه».
    expect(
      lesson(games: const [
        HtmlGame(id: 'g1', url: 'https://x/g', title: 'لعبة', subtitle: ''),
      ]).hasExplanation,
      isFalse,
    );
  });
}
