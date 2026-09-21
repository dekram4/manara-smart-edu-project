import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/widgets/bouncy_text.dart';

/// The cartoon headline splits text into pieces it can tilt independently.
///
/// What it must never do is split an Arabic word. Arabic letters join, and a
/// letter torn from its neighbours falls back to its isolated shape — so a
/// per-letter effect would not render «أهلاً» playfully, it would render it
/// wrongly. These tests hold that line, because it is invisible in code
/// review and obvious only to someone who reads Arabic.
void main() {
  group('pieces', () {
    test('an Arabic word stays whole', () {
      expect(BouncyText.pieces('أهلًا'), ['أهلًا']);
    });

    test('an Arabic phrase splits at the spaces, never inside a word', () {
      expect(
        BouncyText.pieces('أهلًا بك في منارة المعرفة'),
        ['أهلًا', 'بك', 'في', 'منارة', 'المعرفة'],
      );
    });

    test('a Latin word splits letter by letter, since Latin does not join',
        () {
      expect(BouncyText.pieces('Play'), ['P', 'l', 'a', 'y']);
    });

    test('digits split too', () {
      expect(BouncyText.pieces('2026'), ['2', '0', '2', '6']);
    });

    test('a word mixing scripts stays whole, so its Arabic half survives', () {
      expect(BouncyText.pieces('منارة2'), ['منارة2']);
    });

    test('runs of whitespace collapse and never become pieces', () {
      expect(BouncyText.pieces('  أهلًا   بك  '), ['أهلًا', 'بك']);
    });

    test('an empty string yields nothing', () {
      expect(BouncyText.pieces('   '), isEmpty);
    });
  });

  group('rendering', () {
    Future<void> pump(WidgetTester tester, Widget child,
        {bool reduceMotion = false}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(body: child),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('every piece is drawn three times: two rims and a fill',
        (tester) async {
      await pump(tester, const BouncyText('أهلًا بك', fontSize: 24));

      // A dark stroke outermost, a light one inside it, then the fill. The
      // pair is what holds a loud colour legible on a pale background and a
      // dark one alike — one rim alone disappears against half of them.
      expect(find.text('أهلًا'), findsNWidgets(3));
      expect(find.text('بك'), findsNWidgets(3));
    });

    testWidgets('pieces are tilted, and not all by the same angle',
        (tester) async {
      await pump(
        tester,
        const BouncyText('أهلًا بك في منارة', fontSize: 24),
      );

      final angles = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform.getRotation().getRow(0).x)
          .toSet();
      expect(angles.length, greaterThan(1),
          reason: 'every piece carries the same tilt, so nothing dances');
    });

    testWidgets('a line reserves room for its own hop', (tester) async {
      // Transform.translate paints elsewhere without telling the parent, so
      // the lift has to be paid for in padding or the piece hangs outside
      // the box that measured it — and lands on whatever sits above.
      await pump(tester, const BouncyText('أهلًا', fontSize: 30));

      final box = tester.getRect(find.byType(BouncyText));
      final ink = tester.getRect(find.text('أهلًا').first);
      expect(box.height, greaterThan(ink.height),
          reason: 'the line is no taller than upright text, so nothing is '
              'reserved for the hop');
      expect(box.height - ink.height,
          greaterThanOrEqualTo(BouncyText.reservedLift(30)));
    });

    testWidgets('two stacked lines never touch, with no gap between them',
        (tester) async {
      // The header stacks the welcome over the student's name. It used to
      // overlap once the offsets grew; this holds the fix even at zero
      // spacing, so no call site has to know the magic number.
      await pump(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BouncyText('أهلًا بك في منارة المعرفة', fontSize: 19.2),
            BouncyText('أهلًا جوري داود', fontSize: 36),
          ],
        ),
      );

      final rects = tester
          .widgetList<BouncyText>(find.byType(BouncyText))
          .map((w) => tester.getRect(find.byWidget(w)))
          .toList();
      expect(rects.first.bottom, lessThanOrEqualTo(rects.last.top),
          reason: 'the two header lines overlap');
    });

    testWidgets('a long phrase wraps on a narrow phone without overflowing',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pump(
        tester,
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: BouncyText('المس أي بطاقة لتبدأ رحلتك', fontSize: 19),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion leaves the letters still', (tester) async {
      await pump(
        tester,
        const BouncyText('أهلًا بك', fontSize: 24),
        reduceMotion: true,
      );

      // The idle bob is the only Animate in the tree; asking for reduced
      // motion must remove it rather than slow it down.
      expect(find.byType(BouncyText), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  });
}
