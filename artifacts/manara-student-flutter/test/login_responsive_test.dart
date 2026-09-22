import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/screens/login_screen.dart';

/// Sizes the app actually ships to, in both orientations: a desktop
/// window, an iPad-shaped 4:3 tablet, a 16:10 tablet, and two phones. The
/// 4:3 tablet in landscape is the one that used to open a stray vertical
/// scroll on the board.
const _landscapeSizes = <String, Size>{
  'landscape desktop 1280x720': Size(1280, 720),
  'landscape tablet 4:3 1024x768': Size(1024, 768),
  'landscape tablet 16:10 1280x800': Size(1280, 800),
  'landscape phone 851x393': Size(851, 393),
  'landscape small phone 740x360': Size(740, 360),
  'portrait tablet 4:3 768x1024': Size(768, 1024),
  'portrait tablet 16:10 800x1280': Size(800, 1280),
  'portrait phone 393x851': Size(393, 851),
  'portrait small phone 360x740': Size(360, 740),
};

Widget _app() => const MaterialApp(
      home: LoginScreen(
        authService: null,
        initializationError: null,
        apiBaseUrl: '',
      ),
    );

void main() {
  for (final entry in _landscapeSizes.entries) {
    testWidgets('login screen lays out without overflow on ${entry.key}',
        (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 350));

      // Any RenderFlex overflow paints an error and is recorded by the
      // test binding, so an empty exception slot is the assertion.
      expect(tester.takeException(), isNull);

      // Both fields and the submit button must be laid out on screen, not
      // pushed off the bottom of the board.
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('تسجيل الدخول'), findsOneWidget);
    });
  }

  testWidgets('the board does not drag where it already fits',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 350));

    // ‏ما كان يُشكى منه هو السحب الرأسي فوق السبورة على التابلت، لا وجود
    // ‏`SingleChildScrollView` في الشجرة. وقد عاد المكوّن ليحمل المشهد
    // ‏حين يفيض عن نافذة قصيرة — وفيزياؤه `NeverScrollable` ما دام
    // ‏يسعها، فلا سحب. والقياس على السلوك أصدق من القياس على غياب ويدجت:
    // ‏الغياب كان وسيلةً إلى هذا الشرط لا الشرط نفسه.
    final scene = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(scene.physics, isA<NeverScrollableScrollPhysics>());

    // ‏وكل تمرير رأسي في الشجرة لا يستجيب للإصبع. أما الأفقي فهو تمرير
    // ‏المؤشّر داخل حقول النصّ، ولم يكن يوماً موضع الشكوى.
    for (final scrollable in tester.widgetList<Scrollable>(find.byType(Scrollable))) {
      if (scrollable.axisDirection == AxisDirection.right) continue;
      expect(scrollable.axisDirection, AxisDirection.down);
      expect(scrollable.physics, isA<NeverScrollableScrollPhysics>());
    }
  });

  testWidgets('a short landscape window scrolls instead of shrinking',
      (tester) async {
    // ‏في الوضع الأفقي على هاتف كان المشهد يُقاس على نافذة قصيرة فتخرج
    // ‏سبورة محشورة. صار له حدٌّ أدنى، وما فاض يُمرَّر.
    tester.view.physicalSize = const Size(851, 393);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 350));

    final scene = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(scene.physics, isA<ClampingScrollPhysics>());
    expect(tester.takeException(), isNull);
  });

  // The reported problem: on a phone or tablet in landscape the soft
  // keyboard covered the username and password boxes, so a child could not
  // see what they were typing. The scene cannot resize or scroll — it is a
  // fixed composition measured against the window — so it lifts instead.
  group('the keyboard never covers what the student is typing', () {
    const keyboardSizes = <String, Size>{
      'landscape phone 851x393': Size(851, 393),
      'landscape tablet 4:3 1024x768': Size(1024, 768),
      'portrait phone 393x851': Size(393, 851),
    };

    for (final entry in keyboardSizes.entries) {
      testWidgets('on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_app());
        await tester.pump(const Duration(milliseconds: 350));

        // The password box, not the username one: it sits lowest on the
        // board and is the one the keyboard reaches first. Asserting on
        // the first field passed whether or not anything worked.
        Rect field() => tester.getRect(find.byType(TextFormField).last);
        final before = field();

        // 60% of the height — what a phone really gives up to a keyboard
        // in landscape, and the case that was reported.
        tester.view.viewInsets =
            FakeViewPadding(bottom: entry.value.height * 0.6);
        addTearDown(() => tester.view.resetViewInsets());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final after = field();
        final keyboardTop = entry.value.height * 0.4;

        expect(
          after.bottom,
          lessThanOrEqualTo(keyboardTop),
          reason: 'the field must end above the keyboard, not under it',
        );
        expect(
          after.top,
          greaterThanOrEqualTo(0),
          reason: 'making room must not push it off the top instead',
        );
        expect(
          after.top,
          lessThanOrEqualTo(before.top),
          reason: 'the scene moves up, never further under the keys',
        );
      });
    }
  });
}
