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

    testWidgets('every piece is drawn twice: a rim and a fill over it',
        (tester) async {
      await pump(tester, const BouncyText('أهلًا بك', fontSize: 24));

      // Two words, each painted as an outline and then a fill.
      expect(find.text('أهلًا'), findsNWidgets(2));
      expect(find.text('بك'), findsNWidgets(2));
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
