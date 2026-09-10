import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Holds the microphone/camera permission the virtual teacher needs, and
/// the D-ID session bookkeeping that goes with it.
///
/// The WebView already grants the page's own `getUserMedia` request, but
/// that grant is only as good as the app's: on Android the capture fails
/// inside the page unless the process already holds RECORD_AUDIO. When it
/// fails there, the provider's page reports it as an unsupported browser
/// and invites the child to open a real one — which is what was being
/// seen, and why the fix belongs here rather than in the embed.
class StudentMediaPermissions {
  const StudentMediaPermissions._();

  /// Whether the ask has already been made this run. The platform only
  /// shows its dialog once anyway, but repeating the call on every visit
  /// to the teacher costs a channel round trip for nothing.
  static bool _asked = false;

  /// Requests the microphone ahead of the virtual teacher's page.
  ///
  /// Never throws and never blocks the screen: a student who declines, or
  /// a platform with no such permission at all, still gets the teacher —
  /// just without their voice — which is a better outcome than a screen
  /// that refuses to open. The camera is deliberately not requested; the
  /// teacher listens and speaks, and asking a child for their camera
  /// without needing it is not something to do by default.
  static Future<bool> requestForTutor() async {
    if (_asked) return true;
    _asked = true;
    // Desktop and web have no runtime permission model here; the plugin
    // throws rather than answering on some of them.
    if (kIsWeb) return true;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return true;
    }
    try {
      final status = await Permission.microphone.request();
      return status.isGranted || status.isLimited;
    } catch (_) {
      return false;
    }
  }

  /// Test seam: lets a test start from a clean slate.
  @visibleForTesting
  static void resetForTest() => _asked = false;
}
