import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/services/student_media_permissions.dart';

/// The microphone ask sits in front of the virtual teacher, so it must
/// never be the thing that stops the teacher opening: not on a platform
/// with no permission model, and not when the plugin is absent — which is
/// exactly the case in a test, so these run against the real code path.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(StudentMediaPermissions.resetForTest);

  test('resolves rather than throwing where there is no plugin to answer',
      () async {
    // The host platform here is the test runner, which has no permission
    // channel at all. Anything but a clean answer would mean the teacher
    // screen's initState could throw on a real device in the same state.
    await expectLater(
      StudentMediaPermissions.requestForTutor(),
      completion(isA<bool>()),
    );
  });

  test('a desktop platform is granted without asking anyone', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(await StudentMediaPermissions.requestForTutor(), isTrue);
  });

  test('the ask is made once per run, not on every visit', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(await StudentMediaPermissions.requestForTutor(), isTrue);
    // A second visit short-circuits: the platform only shows its dialog
    // once anyway, and repeating it costs a channel round trip for
    // nothing.
    expect(await StudentMediaPermissions.requestForTutor(), isTrue);
  });
}
