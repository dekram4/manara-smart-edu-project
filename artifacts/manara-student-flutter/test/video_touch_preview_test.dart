import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/models/student_content.dart';
import 'package:manara_student/src/services/student_sound_service.dart';
import 'package:manara_student/src/widgets/student_video_player.dart';

/// معاينةُ الفيديو باللمس (٣ ثوانٍ) في «شرح الدرس» و«سينما منارة»، وصوتُ الجواهر.
void main() {
  const video = LessonVideo(
    id: 'v1',
    url: 'https://www.youtube.com/watch?v=abcdefghijk',
    sourceType: VideoSourceType.embed,
    title: 'فيديو',
  );

  Future<List<int>> pumpCard(WidgetTester tester) async {
    final taps = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            height: 220,
            child: StudentVideoHoverPreview(
              video: video,
              apiBaseUrl: '',
              child: InkWell(onTap: () => taps.add(1), child: const ColoredBox(color: Colors.blue)),
            ),
          ),
        ),
      ),
    ));
    return taps;
  }

  testWidgets('لمسةٌ سريعة تفتح الفيديو ولا معاينة', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final taps = await pumpCard(tester);
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    expect(taps, [1]);
    expect(find.text('معاينة ٣ ثوانٍ'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('إبقاءُ الإصبع يُشغّل المعاينة، ورفعُه يوقفها ولا يفتح الفيديو', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final taps = await pumpCard(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(InkWell)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('معاينة ٣ ثوانٍ'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(find.text('معاينة ٣ ثوانٍ'), findsNothing);
    expect(taps, isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('المعاينةُ تنتهي وحدها بعد ثلاث ثوانٍ', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await pumpCard(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(InkWell)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('معاينة ٣ ثوانٍ'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('معاينة ٣ ثوانٍ'), findsNothing);
    await gesture.up();
    debugDefaultTargetPlatformOverride = null;
  });

  test('صوتُ الجواهر داخل assets/audio/encouragement/', () {
    expect(StudentSoundService.gemsClip, 'audio/encouragement/jawaher.mp3');
    expect(File('assets/${StudentSoundService.gemsClip}').existsSync(), isTrue);
  });
}
