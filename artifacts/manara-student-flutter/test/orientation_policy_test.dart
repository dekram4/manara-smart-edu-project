import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/utils/student_orientation.dart';
import 'package:manara_student/src/widgets/student_experience.dart';

/// Guards the bug where exiting a lesson video left the app pinned to
/// portrait for the rest of the session: the fullscreen player "restored"
/// `portraitUp/portraitDown` instead of the app's own policy, so landscape
/// became unreachable until a relaunch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the app policy always permits landscape', () {
    expect(
      StudentOrientation.allowed,
      containsAll(<DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
      reason: 'restoring after a video must never make landscape '
          'unreachable — that was the reported crash',
    );
  });

  test('every orientation, on every device', () {
    // The app was briefly locked to landscape. It is not any more: a
    // student holding a phone upright gets the app the way they are
    // holding it, and the responsive tests cover both shapes.
    expect(
      StudentOrientation.allowed,
      containsAll(<DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
  });

  test('a player can still be given every orientation', () {
    // The flexibility the players need: a lesson filmed in portrait
    // should be watchable upright rather than letterboxed into the app's
    // own shape.
    expect(
      StudentOrientation.unrestricted,
      containsAll(<DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
  });

  testWidgets('apply() pushes exactly the policy to the platform',
      (tester) async {
    final sent = <List<String>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          sent.add(List<String>.from(call.arguments as List));
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await StudentOrientation.apply();

    expect(sent, hasLength(1));
    expect(
      sent.single,
      StudentOrientation.allowed
          .map((orientation) => orientation.toString())
          .toList(),
    );
    // The specific regression: the restore must not be portrait-only.
    expect(sent.single, contains('DeviceOrientation.landscapeLeft'));
  });

  testWidgets(
      'closing any pushed screen releases an orientation an embed pinned',
      (tester) async {
    final sent = <List<String>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          sent.add(List<String>.from(call.arguments as List));
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('home')),
      ),
    );

    // Any screen — cinema, lesson, live meeting, avatar creator — is pushed
    // through StudentPageRoute, which is where the guard lives.
    navigator.currentState!.push(
      StudentPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('media screen')),
      ),
    );
    await tester.pumpAndSettle();

    // Stand in for an embed that pins the device and never undoes it.
    await SystemChrome.setPreferredOrientations(
      const [DeviceOrientation.portraitUp],
    );
    expect(sent.last, ['DeviceOrientation.portraitUp']);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    // Leaving the screen must have handed the device back to the app.
    expect(
      sent.last,
      StudentOrientation.allowed
          .map((orientation) => orientation.toString())
          .toList(),
      reason: 'a pinned orientation must not survive leaving the screen',
    );
  });
}
