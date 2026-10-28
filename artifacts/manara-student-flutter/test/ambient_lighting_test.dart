import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/widgets/ambient_lighting.dart';
import 'package:manara_student/src/widgets/portal_watermark.dart';

/// إضاءةُ البوابات: في الداكن وحده، ولكلّ بوابةٍ مشهدُها.
void main() {
  Future<void> pump(WidgetTester tester, Brightness brightness) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: const Scaffold(
        body: PortalWatermark(asset: PortalBackgrounds.quiz),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('dark mode lights the portal', (tester) async {
    await pump(tester, Brightness.dark);
    expect(find.byKey(const ValueKey('ambient-lighting')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('light mode stays unlit', (tester) async {
    await pump(tester, Brightness.light);
    expect(find.byKey(const ValueKey('ambient-lighting')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  test('every portal background has its own scene', () {
    const all = [
      PortalBackgrounds.lesson,
      PortalBackgrounds.games,
      PortalBackgrounds.cinema,
      PortalBackgrounds.personality,
      PortalBackgrounds.tutor,
      PortalBackgrounds.liveMeeting,
      PortalBackgrounds.quiz,
      PortalBackgrounds.problemSolver,
      PortalBackgrounds.chat,
      PortalBackgrounds.endlessReader,
      PortalBackgrounds.study,
    ];
    for (final asset in all) {
      final lights = AmbientScenes.of(asset);
      expect(lights, isNotEmpty, reason: asset);
      expect(identical(lights, AmbientScenes.of('nothing.png')), isFalse,
          reason: '$asset has no scene of its own');
    }
    expect(
      AmbientScenes.of(PortalBackgrounds.quiz)
          .any((l) => l.kind == AmbientKind.clock),
      isTrue,
    );
  });
}
