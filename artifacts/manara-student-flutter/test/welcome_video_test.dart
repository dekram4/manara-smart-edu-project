import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:manara_student/src/screens/student_startup_screen.dart';

import 'support/fake_video_platform.dart';

const _sizes = <String, Size>{
  'portrait phone 393x851': Size(393, 851),
  'landscape phone 851x393': Size(851, 393),
  'landscape tablet 1280x800': Size(1280, 800),
  'iPad portrait 4:3 768x1024': Size(768, 1024),
  'iPad landscape 4:3 1024x768': Size(1024, 768),
};

Widget _app() => const MaterialApp(
      home: StudentStartupScreen(
        authService: null,
        initializationError: null,
        apiBaseUrl: '',
      ),
    );

// الشعارُ يُفكّ بقدر الشارة، فمزوّدُه مغلّفٌ بـResizeImage.
final _logo = find.byWidgetPredicate((widget) {
  if (widget is! Image) return false;
  final image = widget.image;
  final source = image is ResizeImage ? image.imageProvider : image;
  return source == const AssetImage(StudentStartupScreen.welcomeLogoAsset);
});

/// فيلمُ الترحيب على شاشة الإقلاع، بمنصّة فيديو مزيّفة.
///
/// ── لماذا منصّةٌ مزيّفة ──
/// الاختباراتُ بلا مفكّك فيديو، فتعدل الشاشةُ فيها إلى الافتتاحية المرسومة —
/// وذاك ما تختبره `welcome_screen_test.dart`. وهنا يُعطى الفيلمُ منصّةً تُعلن
/// طولَه وتُبلغ انتهاءه، فيُرى مسلكُه هو: يُعرض، والشعارُ عليه، ويُغادر عند
/// آخره أو بنقرة.
void main() {
  late VideoPlayerPlatform original;
  setUp(() => original = VideoPlayerPlatform.instance);
  tearDown(() => VideoPlayerPlatform.instance = original);

  for (final entry in _sizes.entries) {
    testWidgets('الفيلمُ يُعرض والشعارُ على زاويته (${entry.key})',
        (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final platform = FakeVideoPlatform();
      VideoPlayerPlatform.instance = platform;

      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1600));

      expect(tester.takeException(), isNull);
      expect(platform.asset, StudentStartupScreen.welcomeVideoAsset);
      expect(platform.calls, contains('play'));
      expect(platform.volume, 1);
      expect(find.byType(VideoPlayer), findsOneWidget);
      expect(_logo, findsOneWidget);
      // الافتتاحيةُ المرسومة لا تبدأ مع الفيلم — وصوتُه فيه.
      expect(find.text('منارة المعرفة التعليمية'), findsNothing);

      // الفيلمُ يملأ الشاشةَ كلَّها بنسبته — لا هوامش — ووسطُه وسطُها.
      final film = tester.getRect(find.byType(VideoPlayer));
      expect(film.width / film.height, closeTo(1080 / 1920, 0.01));
      final screen = Offset.zero & entry.value;
      expect(film.intersect(screen), screen);
      expect(
        (film.width - screen.width).abs() < 0.5 ||
            (film.height - screen.height).abs() < 0.5,
        isTrue,
        reason: 'يُكبَّر بقدر ما يغطّي، لا أكثر',
      );
      expect((film.center - screen.center).distance, lessThan(0.5));
      // والشارةُ داخل الشاشة، على يمينها الأعلى.
      final badge = tester.getRect(_logo);
      expect(screen.intersect(badge), badge);
      expect(badge.center.dx, greaterThan(screen.center.dx));
      expect(badge.center.dy, lessThan(screen.center.dy));

      await tester.tap(find.byType(StudentStartupScreen));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(StudentStartupScreen), findsNothing);
      expect(platform.calls, contains('pause'));
    });
  }

  testWidgets('أشرطةُ النظام مخفيّةٌ طوال الترحيب، وتعود بعده', (tester) async {
    tester.view.physicalSize = const Size(393, 851);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    VideoPlayerPlatform.instance = FakeVideoPlatform();
    final modes = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
          modes.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 100));
    // أوّلُ ما يُطلب: لا شريطَ حالةٍ ولا أزرارَ رجوعٍ ورئيسية فوق الفيلم.
    expect(modes, ['SystemUiMode.immersiveSticky']);

    await tester.tap(find.byType(StudentStartupScreen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(StudentStartupScreen, skipOffstage: false), findsNothing);
    // وشاشةُ الدخول بأشرطتها: الطفلُ لا يبقى بلا زرّ رجوع.
    expect(modes.last, 'SystemUiMode.edgeToEdge');
  });

  testWidgets('تُغادر الشاشةُ حين ينتهي الفيلم، لا قبله', (tester) async {
    tester.view.physicalSize = const Size(393, 851);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final platform = FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 100));
    // بعد سبع ثوانٍ — مهلةُ الافتتاحية القديمة — والفيلمُ لم ينتهِ: باقية.
    await tester.pump(const Duration(seconds: 8));
    expect(find.byType(StudentStartupScreen), findsOneWidget);

    platform.complete();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(StudentStartupScreen), findsNothing);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });

  testWidgets('ولا تعلق إن لم يُبلَّغ انتهاؤه', (tester) async {
    tester.view.physicalSize = const Size(393, 851);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    VideoPlayerPlatform.instance = FakeVideoPlatform();

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 100));
    // طولُ الفيلم وثانيتان فوقه.
    await tester.pump(const Duration(milliseconds: 12546 + 2100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(StudentStartupScreen), findsNothing);
  });

  testWidgets('فيلمٌ لا يُفكّ: الافتتاحيةُ المرسومة كما كانت', (tester) async {
    tester.view.physicalSize = const Size(393, 851);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    VideoPlayerPlatform.instance = FakeVideoPlatform(fail: true);

    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(tester.takeException(), isNull);
    expect(find.byType(VideoPlayer), findsNothing);
    expect(find.text('منارة المعرفة التعليمية'), findsOneWidget);

    await tester.tap(find.byType(StudentStartupScreen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(StudentStartupScreen), findsNothing);
  });

  test('الفيلمُ والشعارُ في الحزمة فعلاً', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final bundled = manifest.listAssets().toSet();
    expect(bundled, contains(StudentStartupScreen.welcomeVideoAsset));
    expect(bundled, contains(StudentStartupScreen.welcomeLogoAsset));
  });
}
