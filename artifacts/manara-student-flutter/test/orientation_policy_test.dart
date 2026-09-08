import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/utils/student_orientation.dart';

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
}
