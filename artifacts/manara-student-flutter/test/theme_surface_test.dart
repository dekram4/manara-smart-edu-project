import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/theme/student_theme.dart';
import 'package:manara_student/src/widgets/portal_watermark.dart';

/// The screens used to paint fixed light grounds, which is why dark mode
/// darkened the chrome and left the pages bright. These pin the roles
/// that replaced those literals: every one must actually differ between
/// the two brightnesses, or the screen using it has not really converted.
void main() {
  Future<T> resolve<T>(
    WidgetTester tester,
    Brightness brightness,
    T Function(BuildContext) read,
  ) async {
    late T value;
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light(),
        home: Builder(
          builder: (context) {
            value = read(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    // MaterialApp animates between themes, so a single pump reads a
    // colour part-way through the crossfade rather than the destination.
    await tester.pumpAndSettle();
    return value;
  }

  testWidgets('every surface role changes with the brightness',
      (tester) async {
    final roles = <String, Color Function(BuildContext)>{
      'ground': StudentSurface.ground,
      'coolGround': StudentSurface.coolGround,
      'card': StudentSurface.card,
      'ink': StudentSurface.ink,
      'mutedInk': StudentSurface.mutedInk,
      'outline': StudentSurface.outline,
      'warmGround': StudentSurface.warmGround,
      'track': StudentSurface.track,
      'controlWash': (context) => StudentSurface.controlWash(context),
      'barSweep': (context) => StudentSurface.barSweep(context).first,
    };

    for (final entry in roles.entries) {
      final light = await resolve(tester, Brightness.light, entry.value);
      final dark = await resolve(tester, Brightness.dark, entry.value);
      expect(
        light,
        isNot(dark),
        reason: '${entry.key} is the same in both themes — not converted',
      );
    }
  });

  test('the surfaces Material builds for itself are dark in the dark theme',
      () {
    // A dialog, a sheet or a dropdown that is never handed a colour paints
    // the framework's default — which is light. No screen writes these,
    // so no screen-by-screen audit can catch them; only the theme can.
    //
    // Asserted as relationships rather than frozen hex values: the point
    // is that every built-in surface is the app's raised colour and that
    // the page sits below it, not that either is one particular black.
    // Pinning the literals made retuning the palette a test edit.
    final dark = StudentTheme.dark();
    final raised = dark.cardTheme.color!;
    final page = dark.scaffoldBackgroundColor;

    expect(dark.dialogTheme.backgroundColor, raised);
    expect(dark.bottomSheetTheme.backgroundColor, raised);
    expect(dark.bottomSheetTheme.modalBackgroundColor, raised);
    expect(dark.popupMenuTheme.color, raised);

    // Both genuinely dark, and the card readable as raised above the page.
    expect(page.computeLuminance(), lessThan(0.05));
    expect(raised.computeLuminance(), lessThan(0.08));
    expect(raised.computeLuminance(), greaterThan(page.computeLuminance()));

    // And each must be materially darker than its light counterpart.
    final light = StudentTheme.light();
    for (final pair in <List<Color?>>[
      [light.dialogTheme.backgroundColor, dark.dialogTheme.backgroundColor],
      [
        light.bottomSheetTheme.backgroundColor,
        dark.bottomSheetTheme.backgroundColor,
      ],
      [light.popupMenuTheme.color, dark.popupMenuTheme.color],
      [light.scaffoldBackgroundColor, dark.scaffoldBackgroundColor],
    ]) {
      expect(
        pair[0]!.computeLuminance(),
        greaterThan(pair[1]!.computeLuminance() + 0.3),
      );
    }
  });

  /// WCAG relative-contrast ratio, so "high contrast" is a number rather
  /// than an opinion. 4.5 is the AA floor for body text; 7 is AAA.
  double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  testWidgets('dark-mode text clears AAA against both dark surfaces',
      (tester) async {
    // The complaint that started this was dark navy text surviving into
    // dark mode. A ratio is what catches that: #183047 on #0E1117 scores
    // about 1.4, nowhere near the 7 this demands.
    final ground = await resolve(tester, Brightness.dark, StudentSurface.ground);
    final card = await resolve(tester, Brightness.dark, StudentSurface.card);
    final ink = await resolve(tester, Brightness.dark, StudentSurface.ink);
    final muted =
        await resolve(tester, Brightness.dark, StudentSurface.mutedInk);

    expect(contrast(ink, ground), greaterThan(7));
    expect(contrast(ink, card), greaterThan(7));
    // Secondary text is allowed to be quieter, but never below AA.
    expect(contrast(muted, ground), greaterThan(4.5));
    expect(contrast(muted, card), greaterThan(4.5));
  });

  testWidgets('dark-mode ink is a light neutral, never a dark blue',
      (tester) async {
    for (final role in <Color Function(BuildContext)>[
      StudentSurface.ink,
      StudentSurface.mutedInk,
    ]) {
      final colour = await resolve(tester, Brightness.dark, role);
      // Bright enough to read as white or light grey…
      expect(colour.computeLuminance(), greaterThan(0.4));
      // …and near-neutral, so it cannot drift back to a navy or a teal.
      final channels = [colour.r, colour.g, colour.b];
      final spread = channels.reduce((a, b) => a > b ? a : b) -
          channels.reduce((a, b) => a < b ? a : b);
      expect(spread, lessThan(0.1), reason: '$colour is not a neutral');
    }
  });

  test('the dark theme states a readable colour for every text surface', () {
    final dark = StudentTheme.dark();
    final raised = dark.cardTheme.color!;
    for (final ink in <Color?>[
      dark.listTileTheme.textColor,
      dark.expansionTileTheme.textColor,
      dark.expansionTileTheme.collapsedTextColor,
      dark.iconTheme.color,
    ]) {
      expect(ink, isNotNull);
      final gap = (ink!.computeLuminance() - raised.computeLuminance()).abs();
      expect(gap, greaterThan(0.4), reason: '$ink is too close to the card');
    }
  });

  testWidgets('text stays readable against its own ground', (tester) async {
    // A dark ink on a dark ground is the failure this guards: the
    // conversion has to keep contrast, not merely change values.
    for (final brightness in Brightness.values) {
      final ground = await resolve(tester, brightness, StudentSurface.ground);
      final ink = await resolve(tester, brightness, StudentSurface.ink);
      final gap = (ground.computeLuminance() - ink.computeLuminance()).abs();
      expect(
        gap,
        greaterThan(0.4),
        reason: 'ink and ground are too close in $brightness',
      );
    }
  });

  testWidgets('the watermark follows the theme, except where a screen '
      'declares itself a dark room', (tester) async {
    Future<Color> firstGradientColor(Brightness brightness, bool dark) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light(),
          home: PortalWatermark(
            asset: PortalBackgrounds.lesson,
            dark: dark,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
      final gradient =
          (box.decoration as BoxDecoration).gradient! as LinearGradient;
      return gradient.colors.first;
    }

    final light = await firstGradientColor(Brightness.light, false);
    final dark = await firstGradientColor(Brightness.dark, false);
    expect(light, isNot(dark), reason: 'the watermark must follow the theme');

    // A screen that is a dark room stays its own navy in light mode.
    final room = await firstGradientColor(Brightness.light, true);
    expect(room, isNot(light));
  });
}
