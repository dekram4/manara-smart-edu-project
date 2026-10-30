import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/models/student_content.dart';
import 'package:manara_student/src/services/youtube_availability.dart';
import 'package:manara_student/src/widgets/student_experience.dart';
import 'package:manara_student/src/widgets/student_video_player.dart';
import 'package:manara_student/src/widgets/video_rows.dart';
import 'package:manara_student/src/widgets/video_thumbnail_card.dart';

/// قائمةُ الفيديو بلا حدّ، وحالُ فيديو يوتيوب المحذوف.
void main() {
  testWidgets('أربعون فيديو بعناوين طويلة وخطٍّ كبير: تُمرَّر كلُّها بلا فيضٍ ولا قصّ',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final title = 'عنوانُ فيديو طويلٌ جداً يمتدّ على أكثر من سطرٍ في البطاقة ' * 3;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverVideoRows(
                itemCount: 40,
                itemBuilder: (context, index) => Column(
                  key: ValueKey('v$index'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AspectRatio(aspectRatio: 16 / 9, child: ColoredBox(color: Colors.teal)),
                    Text('$index $title'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // الأوّلُ ظاهر، والأخيرُ لم يُبنَ بعد (كسول)…
    expect(find.byKey(const ValueKey('v0')), findsOneWidget);
    expect(find.byKey(const ValueKey('v39')), findsNothing);
    // …ويُبلغ بالتمرير، ولا خطأ فيضٍ في الطريق.
    await tester.scrollUntilVisible(find.byKey(const ValueKey('v39')), 600);
    expect(find.byKey(const ValueKey('v39')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('البطاقةُ الحقيقية (معاينة + ضغط + غلاف) تظهر في الصفوف ولا تبقى فارغة',
      (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverVideoRows(
                itemCount: 9,
                itemBuilder: (context, index) {
                  final video = LessonVideo(
                    id: 'v$index',
                    url: 'https://www.youtube.com/watch?v=abcdefghij$index',
                    sourceType: VideoSourceType.embed,
                    title: index.isEven ? 'فيديو $index' : 'عنوانٌ طويل ' * 8,
                  );
                  return StudentVideoHoverPreview(
                    apiBaseUrl: '',
                    video: video,
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    child: StudentPressScale(
                      child: VideoThumbnailCard(video: video, onTap: () {}),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    final cards = find.byType(VideoThumbnailCard);
    expect(cards, findsWidgets);
    // كلُّ بطاقةٍ مبنيّة لها ارتفاعٌ حقيقيٌّ محدود، وعنوانها ظاهر.
    for (final element in cards.evaluate()) {
      final size = element.size!;
      expect(size.height, greaterThan(100));
      expect(size.height.isFinite, isTrue);
    }
    expect(find.text('فيديو 0'), findsOneWidget);
  });

  test('عددُ الأعمدة من العرض كما كانت الشبكة', () {
    expect(SliverVideoRows.columnsFor(400, 330, 14), 2);
    expect(SliverVideoRows.columnsFor(300, 330, 14), 1);
    expect(SliverVideoRows.columnsFor(1100, 330, 14), 4);
  });

  test('ردُّ يوتيوب: 404 محذوف، 401 ممنوعُ التضمين، وما سواه لا يحجب', () {
    expect(YoutubeAvailabilityService.statusFor(200), YoutubeAvailability.available);
    expect(YoutubeAvailabilityService.statusFor(404), YoutubeAvailability.unavailable);
    expect(YoutubeAvailabilityService.statusFor(401), YoutubeAvailability.embedBlocked);
    expect(YoutubeAvailabilityService.statusFor(400), YoutubeAvailability.unknown);
    expect(YoutubeAvailabilityService.statusFor(500), YoutubeAvailability.unknown);
  });
}
