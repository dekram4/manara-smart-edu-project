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
  // اسم المنصّة يُرى في الوضعين.
  //
  // كان يُخفى في الوضع الأفقي إخفاءً تامّاً — حلّاً لضيق الارتفاع —
  // فيفتح الطفل التطبيق أفقياً فلا يرى اسم منصّته إطلاقاً. وهو الآن
  // يُرسم في الركن بمقياس الارتفاع، فيُرى ولا يزاحم السبورة.
  for (final entry in _landscapeSizes.entries) {
    testWidgets('اسم المنصّة ظاهرٌ على ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 350));

      final name = find.text('منارة المعرفة التعليمية');
      expect(name, findsOneWidget, reason: entry.key);

      // ظاهرٌ فعلاً لا مرسومٌ خارج الشاشة.
      final box = tester.getRect(name);
      final window = Offset.zero & tester.view.physicalSize;
      expect(box.left, greaterThanOrEqualTo(window.left - 1), reason: entry.key);
      expect(box.right, lessThanOrEqualTo(window.right + 1), reason: entry.key);
      expect(box.top, greaterThanOrEqualTo(window.top - 1), reason: entry.key);
      expect(box.bottom, lessThanOrEqualTo(window.bottom + 1), reason: entry.key);
      expect(box.width, greaterThan(0), reason: entry.key);
    });
  }

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

  /// عرض رسم السبورة على الشاشة، نسبةً إلى عرض النافذة.
  ///
  /// الرسم يشغل ٩٤٪ من عرض الصورة المربّعة والباقي شفّاف، فيُحسب عليه
  /// لا على المربّع كلّه.
  double boardShare(WidgetTester tester, Size window) {
    final board = tester.getRect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/board_login_bg.png',
      ),
    );
    return board.width * 0.942 / window.width;
  }

  group('the board fills the window without a scroll', () {
    // ‏جُرّبت أرضيةٌ تعلو بالمشهد فوق النافذة ليتّسع، فكبرت السبورة ولزم
    // ‏النزول والطلوع لرؤيتها. فنُزع التمرير، وأُخذ العرض من مكان أصدق:
    // ‏كتلة الشعار تتنحّى في الوضع الأفقي حيث الارتفاع هو القيد.
    const expectations = <String, ({Size size, double atLeast})>{
      'landscape tablet 4:3 1024x768': (size: Size(1024, 768), atLeast: 0.9),
      'landscape tablet 16:10 1280x800': (size: Size(1280, 800), atLeast: 0.9),
      'portrait tablet 4:3 768x1024': (size: Size(768, 1024), atLeast: 0.9),
      'portrait phone 393x851': (size: Size(393, 851), atLeast: 0.9),
      // ‏الهاتف الأفقي لا يبلغها: ٣٩٣ نقطة ارتفاعاً لا تتّسع لأكثر، وبلوغها
      // ‏يقتضي تمريراً — وهو ما نُزع عمداً. ٦٥٪ تمسك الانهيار إلى شريط،
      // ‏وكان ٥٣٪ قبل أن يتنحّى الشعار.
      'landscape phone 851x393': (size: Size(851, 393), atLeast: 0.65),
    };

    for (final entry in expectations.entries) {
      testWidgets(entry.key, (tester) async {
        tester.view.physicalSize = entry.value.size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_app());
        await tester.pump(const Duration(milliseconds: 350));

        expect(
          boardShare(tester, entry.value.size),
          greaterThanOrEqualTo(entry.value.atLeast),
          reason: 'the board shrank back into a narrow strip',
        );
        // ‏ولا تمرير في الشجرة كلّها: ملء الشاشة لا نزولاً وطلوعاً.
        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the keyboard does not shrink the board', () {
    // ‏كان المشهد يُقاس على ما يبقى من الارتفاع بعد الكيبورد، فتنكمش
    // ‏السبورة وما عليها إلى شريط مشوّه في الوضع الأفقي. صارت النافذة
    // ‏تبقى بكامل ارتفاعها والمشهد يُرفع رفعاً، فلا تتغيّر أبعاده.
    const sizes = <String, Size>{
      'landscape tablet 4:3 1024x768': Size(1024, 768),
      'landscape phone 851x393': Size(851, 393),
      'portrait phone 393x851': Size(393, 851),
    };

    for (final entry in sizes.entries) {
      testWidgets(entry.key, (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_app());
        await tester.pump(const Duration(milliseconds: 350));
        final before = boardShare(tester, entry.value);

        tester.view.viewInsets =
            FakeViewPadding(bottom: entry.value.height * 0.6);
        addTearDown(() => tester.view.resetViewInsets());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(
          boardShare(tester, entry.value),
          closeTo(before, 0.001),
          reason: 'the board changed size when the keyboard opened',
        );
      });
    }
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
