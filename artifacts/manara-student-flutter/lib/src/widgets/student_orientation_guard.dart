import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/student_orientation.dart';

/// Hands the device's orientation back to the app whenever a screen closes.
///
/// Media screens do not own the orientation, but the things they embed
/// think they do: a YouTube iframe going fullscreen, a WebView playing
/// video, a native player — any of them can call
/// `setPreferredOrientations` (or hide the system overlays) and simply not
/// undo it. When that happens the device is left pinned, and the student
/// cannot rotate out of it for the rest of the session.
///
/// Rather than trusting every embed to clean up, this guard restores the
/// app's own policy at all three moments the device could otherwise be
/// observed pinned:
///
/// * on pop — the moment the student actually leaves the screen;
/// * on dispose — the backstop, including routes closed without a pop;
/// * on resume — covers an embed that changed the orientation while the
///   app was in the background, where neither of the above would fire.
///
/// It is applied once in [StudentPageRoute], so every pushed screen in the
/// app is covered without each one having to remember.
class StudentOrientationGuard extends StatefulWidget {
  const StudentOrientationGuard({required this.child, super.key});

  final Widget child;

  @override
  State<StudentOrientationGuard> createState() =>
      _StudentOrientationGuardState();
}

class _StudentOrientationGuardState extends State<StudentOrientationGuard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _release();
  }

  void _release() {
    StudentOrientation.apply();
    // An embed that went fullscreen may also have hidden the status and
    // navigation bars. This puts back whatever overlay style the app had
    // without imposing a new one.
    SystemChrome.restoreSystemUIOverlays();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        // Only on a pop that actually happened: a screen with its own
        // `canPop: false` handler is still on screen and must keep
        // whatever orientation it chose.
        if (didPop) _release();
      },
      child: widget.child,
    );
  }
}
