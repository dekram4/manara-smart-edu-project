import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:manara_student/src/widgets/youtube_kiosk_controls.dart';

/// يضغط أزرارَ مشغّل الدرس ويسأل: هل بلغت الضغطةُ المشغّل؟
///
/// ── ولماذا هذا الاختبار بعينه ──
/// هذه الأزرارُ أُخطئ فيها أربع مرّاتٍ متتابعة، وكلُّ مرّةٍ كان العطبُ
/// الواحد: **تُرى ولا تعمل**. حاجبٌ يبتلع اللمسة، أو مساحةٌ صفرٌ في صفر،
/// أو طبقةٌ تُرسم تحت الصورة لا فوقها. ولا واحدٌ من الثلاثة يرفع خطأً، ولا
/// يمسكه `flutter analyze`، ولا يظهر في بناءٍ ناجح — يظهر في إصبعِ طفلٍ
/// يضغط فلا يحدث شيء.
///
/// فالسؤالُ الذي لم يكن يُسأل: هل وصلت الضغطة؟ وهذا الملفُّ يسأله.
void main() {
  /// مشغّلٌ يسجّل ما نُودي فيه، ويُطعم الأزرارَ حالاً نختارها.
  late _FakePlayback playback;
  late int exits;

  setUp(() {
    playback = _FakePlayback();
    exits = 0;
  });

  tearDown(() => playback.dispose());

  Future<void> pump(
    WidgetTester tester, {
    bool fullscreen = false,
    Size size = const Size(400, 225),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Colors.black),
                  YoutubeKioskControls(
                    playback: playback,
                    isFullscreen: fullscreen,
                    onExit: () => exits += 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder centerButton(IconData icon) => find.byIcon(icon);

  group('زرُّ التشغيل في المنتصف', () {
    testWidgets('يُشغّل في الوضع المصغّر', (tester) async {
      await pump(tester);
      expect(centerButton(Icons.play_arrow_rounded), findsOneWidget);
      await tester.tap(centerButton(Icons.play_arrow_rounded));
      await tester.pump();
      expect(playback.calls, ['play']);
    });

    testWidgets('ويُشغّل في ملء الشاشة', (tester) async {
      // ── والوضعان لا وضعٌ واحد ──
      // ملءُ الشاشة تعرضه الحزمةُ في طبقةٍ أخرى، فكان زرُّ المنتصف يعمل
      // مصغّراً ولا يعمل مكبَّراً — أو العكس. فيُسأل عنهما معاً.
      await pump(tester, fullscreen: true, size: const Size(800, 450));
      await tester.tap(centerButton(Icons.play_arrow_rounded));
      await tester.pump();
      expect(playback.calls, ['play']);
    });

    testWidgets('ويُوقف ما يعمل', (tester) async {
      await pump(tester);
      playback.emit(PlayerState.playing);
      // إطارٌ للحدث وإطارٌ للبناء: المَجرى يوصل في مهمّةٍ صغرى بعد هذه.
      await tester.pump();
      await tester.pump();
      expect(centerButton(Icons.pause_rounded), findsOneWidget);
      await tester.tap(centerButton(Icons.pause_rounded));
      await tester.pump();
      expect(playback.calls, ['pause']);
    });

    testWidgets('والمنتهي يُعاد من أوّله لا يبدو معطّلاً', (tester) async {
      await pump(tester);
      playback.emit(PlayerState.ended);
      await tester.pump();
      await tester.pump();
      // شاشةُ النهاية تُغطّي مقترحاتِ يوتيوب، وفيها زرُّ الإعادة.
      await tester.tap(centerButton(Icons.replay_rounded));
      await tester.pump();
      expect(playback.calls, ['replay']);
    });
  });

  group('زرُّ التكبير والتصغير', () {
    testWidgets('يعمل في الوضع المصغّر', (tester) async {
      // الطلبُ المُبلَّغ بعينه: زرُّ التكبير في الوضع المصغّر لا يفعل شيئاً.
      await pump(tester);
      expect(centerButton(Icons.fullscreen_rounded), findsOneWidget);
      await tester.tap(centerButton(Icons.fullscreen_rounded));
      await tester.pump();
      expect(playback.calls, ['fullscreen']);
    });

    testWidgets('ويعمل في ملء الشاشة، وأيقونتُه تنقلب', (tester) async {
      await pump(tester, fullscreen: true, size: const Size(800, 450));
      expect(centerButton(Icons.fullscreen_exit_rounded), findsOneWidget);
      expect(centerButton(Icons.fullscreen_rounded), findsNothing);
      await tester.tap(centerButton(Icons.fullscreen_exit_rounded));
      await tester.pump();
      expect(playback.calls, ['fullscreen']);
    });
  });

  group('زرُّ الرجوع', () {
    testWidgets('يُنادي الخروج في الوضعين', (tester) async {
      await pump(tester);
      await tester.tap(centerButton(Icons.arrow_back_rounded));
      await tester.pump();
      expect(exits, 1);

      await pump(tester, fullscreen: true, size: const Size(800, 450));
      await tester.tap(centerButton(Icons.arrow_back_rounded));
      await tester.pump();
      expect(exits, 2);
    });
  });

  group('وما يحرس الأزرارَ من أن تُرى ولا تُلمس', () {
    testWidgets('للأدوات أبعادٌ داخل قيدٍ فضفاض', (tester) async {
      // ── عطبٌ وقع: `Stack` كلُّ أبنائه موضَّعون تحت قيدٍ فضفاض يأخذ
      // صفراً في صفر، فرُسمت الأزرارُ في مساحةٍ لا أبعادَ لها.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 320,
                  height: 180,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      YoutubeKioskControls(
                        playback: playback,
                        isFullscreen: false,
                        onExit: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final box = tester.getSize(find.byType(YoutubeKioskControls));
      expect(box.width, greaterThan(0));
      expect(box.height, greaterThan(0));
      // والضغطةُ تصل فعلاً، لا أنّ للودجت أبعاداً فحسب.
      await tester.tap(centerButton(Icons.play_arrow_rounded));
      await tester.pump();
      expect(playback.calls, ['play']);
    });

    testWidgets('ولا تفرش الأدواتُ حاجباً على الصورة', (tester) async {
      // ── عطبٌ وقع: `GestureDetector` مفروشٌ على الفيديو كلِّه ليلتقط
      // لمسةَ الإظهار، فكان يبتلع كلَّ لمسةٍ تقصد زرّاً.
      //
      // فما تحت الأدوات يجب أن يبقى قابلاً للّمس في المواضع الخالية: لو
      // فُرش حاجبٌ يوماً سقط هذا.
      var beneath = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 225,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onTap: () => beneath += 1,
                      child: const ColoredBox(color: Colors.black),
                    ),
                    YoutubeKioskControls(
                      playback: playback,
                      isFullscreen: false,
                      onExit: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // زاويةٌ لا زرَّ فيها: أعلى النهاية.
      final area = tester.getRect(find.byType(YoutubeKioskControls));
      await tester.tapAt(Offset(area.right - 10, area.top + 10));
      await tester.pump();
      expect(beneath, 1, reason: 'حاجبٌ مفروشٌ يبتلع اللمس');
      expect(playback.calls, isEmpty);
    });

    testWidgets('ومساحةُ كل زرٍّ تكفي إصبعَ طفل', (tester) async {
      await pump(tester);
      for (final icon in [
        Icons.play_arrow_rounded,
        Icons.fullscreen_rounded,
        Icons.arrow_back_rounded,
      ]) {
        final size = tester.getSize(
          find.ancestor(
            of: find.byIcon(icon),
            matching: find.byType(SizedBox),
          ).first,
        );
        expect(size.width, greaterThanOrEqualTo(48), reason: '$icon');
        expect(size.height, greaterThanOrEqualTo(48), reason: '$icon');
      }
    });
  });
}

/// مشغّلٌ بديلٌ يسجّل النداء ولا يمسّ منصّة.
class _FakePlayback implements KioskPlayback {
  final _controller = StreamController<PlayerState>.broadcast();
  final List<String> calls = [];

  void emit(PlayerState state) => _controller.add(state);
  void dispose() => _controller.close();

  @override
  Stream<PlayerState> get states => _controller.stream;

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> replay() async => calls.add('replay');

  @override
  void toggleFullscreen() => calls.add('fullscreen');
}
