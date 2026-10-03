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

  /// Every orientation, on every device.
  ///
  /// The app was briefly locked to landscape. It is not any more: a
  /// student holding a phone upright should get the app the way they are
  /// holding it, and every screen is laid out to survive both shapes —
  /// which the responsive tests check at nine sizes in both orientations.
  static const allowed = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  /// The same set. Kept as its own name because the players call it to
  /// say "do not hold me to the app's shape" — that intent stays true
  /// whatever the app policy happens to be, so a future narrowing of
  /// [allowed] leaves the players alone rather than silently catching
  /// them too.
  static const unrestricted = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  /// Puts the device back on the app's policy. Safe to call repeatedly.
  static Future<void> apply() =>
      SystemChrome.setPreferredOrientations(allowed);

  /// Lets a player accept any orientation for as long as it is on screen.
  static Future<void> release() =>
      SystemChrome.setPreferredOrientations(unrestricted);
}
