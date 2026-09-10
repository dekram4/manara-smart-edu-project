import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hides the phone's status bar and its back/home/recents bar for as long
/// as one of the portal cards is open.
///
/// The games card needed this first: the system bar sat on top of the
/// game's own bottom controls, so a tap aimed at the game hit the bar
/// instead. The same thing happens anywhere a card puts something near an
/// edge, so every card now runs the same way and the app keeps the whole
/// screen while a student is inside one.
///
/// "Sticky" is the right variant for children: a swipe from the edge still
/// brings the bars back for a moment when they are actually wanted, then
/// they hide themselves again — as opposed to plain `immersive`, where one
/// stray swipe leaves the bars up for good.
///
/// Restoring is deliberately spread across three paths — the pop callback,
/// disposal, and a re-show when this comes back to the foreground — because
/// leaving a device with no navigation bar is far worse than briefly having
/// one: a missed restore would strand the student outside the app too.
class StudentImmersive extends StatefulWidget {
  const StudentImmersive({required this.child, super.key});

  final Widget child;

  @override
  State<StudentImmersive> createState() => _StudentImmersiveState();
}

class _StudentImmersiveState extends State<StudentImmersive>
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
    _restore();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the recents switcher or a phone call drops the
    // immersive flag on some Android builds, which would leave the card
    // with the bars back on top of it. Re-asserting on resume is what
    // keeps the card whole across that round trip.
    if (state == AppLifecycleState.resumed && mounted) _enter();
  }

  void _enter() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _restore() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Gives the bars back as the card closes rather than a frame later,
      // so the portal hub behind it is never seen without them.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _restore();
      },
      child: widget.child,
    );
  }
}
