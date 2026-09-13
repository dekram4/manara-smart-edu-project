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
