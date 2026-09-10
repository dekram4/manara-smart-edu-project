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

  /// The orientations the app itself runs in: landscape, either way up.
  ///
  /// The app is built for a tablet held sideways — the login board, the
  /// path scene and the portal rail are all composed for a wide screen —
  /// so this is the shape the student should find it in, and both
  /// landscape directions are allowed so it never matters which way the
  /// tablet is turned.
  ///
  /// Widening it back to every orientation is one line:
  ///
  /// ```dart
  /// static const allowed = DeviceOrientation.values;
  /// ```
  static const allowed = <DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  /// Everything, for a screen that must not be held to the app's own
  /// shape. A player is the case this exists for: a video shot in
  /// portrait, or a game built for a tall screen, should be watchable as
  /// filmed rather than letterboxed into landscape because the app
  /// prefers it. A screen that opens this up hands the device back with
  /// [apply] when it closes.
  static const unrestricted = DeviceOrientation.values;

  /// Puts the device back on the app's policy. Safe to call repeatedly.
  static Future<void> apply() =>
      SystemChrome.setPreferredOrientations(allowed);

  /// Lets a player accept any orientation for as long as it is on screen.
  static Future<void> release() =>
      SystemChrome.setPreferredOrientations(unrestricted);
}
