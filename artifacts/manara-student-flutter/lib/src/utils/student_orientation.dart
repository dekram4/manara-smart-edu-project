import 'package:flutter/services.dart';

/// The single source of truth for the app's orientation policy.
///
/// This exists because the app used to set orientations from several
/// places, and one of them — the video player's fullscreen scope — restored
/// `portraitUp/portraitDown` on exit. That did not "restore" anything: it
/// pinned the whole app to portrait for the rest of the session, so a
/// student who watched one lesson video could never get back to landscape.
///
/// Nothing may call `SystemChrome.setPreferredOrientations` directly any
/// more. Every screen that temporarily narrows the orientation must hand it
/// back through [apply], which puts the app back on this policy rather than
/// on whatever that screen happened to want.
class StudentOrientation {
  const StudentOrientation._();

  /// The orientations the app supports.
  ///
  /// To lock the app to landscape again, this is the only line that
  /// changes:
  ///
  /// ```dart
  /// static const allowed = <DeviceOrientation>[
  ///   DeviceOrientation.landscapeLeft,
  ///   DeviceOrientation.landscapeRight,
  /// ];
  /// ```
  static const allowed = DeviceOrientation.values;

  /// Puts the device back on the app's policy. Safe to call repeatedly.
  static Future<void> apply() =>
      SystemChrome.setPreferredOrientations(allowed);
}
