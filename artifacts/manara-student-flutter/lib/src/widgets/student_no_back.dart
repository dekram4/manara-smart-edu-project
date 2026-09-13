import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Seals a screen the student is not meant to leave backwards.
///
/// Three screens are the app's own spine — signing in, choosing the
/// course, and the portal hub — and going "back" from any of them means
/// either dropping out of the app or landing on a screen the student has
/// already finished with. On a child's device that is a dead end they
/// cannot reason their way out of, so back is closed off at all three
/// places it can come from:
///
/// - the Android hardware/gesture back, and the iOS edge swipe, via
///   `PopScope(canPop: false)`;
/// - the app bar's own arrow, via `automaticallyImplyLeading: false` at
///   each call site (a leading widget is the screen's business, not this
///   widget's);
/// - the system navigation bar itself, by hiding it.
///
/// Sticky immersive rather than plain immersive, for the same reason the
/// cards use it: a deliberate swipe from the edge still brings the bars
/// back for a moment when an adult actually wants them, and they hide
/// themselves again afterwards. Plain `immersive` would leave them up for
/// good after one stray swipe.
///
/// The mode is re-asserted when the app returns to the foreground, because
/// coming back from the recents switcher or a phone call drops the flag on
/// some Android builds.
class StudentNoBack extends StatefulWidget {
  const StudentNoBack({required this.child, super.key});

  final Widget child;

  @override
  State<StudentNoBack> createState() => _StudentNoBackState();
}

class _StudentNoBackState extends State<StudentNoBack>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enter();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _enter();
  }

  /// Deliberately does not restore the bars on dispose.
  ///
  /// These screens only ever leave by going *forward* — login to the path,
  /// the path to the hub, the hub into a card — and every destination
  /// wants the same full screen. Handing the bars back on the way out
  /// would flash them for a frame between two screens that both hide them.
  void _enter() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(canPop: false, child: widget.child);
  }
}
