import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/student_profile.dart';
import '../services/student_auth_service.dart';
import '../widgets/student_experience.dart';
import 'login_screen.dart';
import 'student_home_screen.dart';

/// The app's opening screen: the Manara characters pop in, bounce a
/// greeting, and the recorded welcome plays over them. It replaced a
/// static indigo card with a progress bar.
///
/// It still owns the session restore it always did — the animation runs
/// while `restoreActiveStudentSession` is in flight, so the greeting costs
/// no extra startup time, and a returning student still lands on the
/// dashboard rather than the login screen.
class StudentStartupScreen extends StatefulWidget {
  const StudentStartupScreen({
    required this.authService,
    required this.initializationError,
    required this.apiBaseUrl,
    super.key,
  });

  final StudentAuthService? authService;
  final String? initializationError;
  final String apiBaseUrl;

  @override
  State<StudentStartupScreen> createState() => _StudentStartupScreenState();
}

class _StudentStartupScreenState extends State<StudentStartupScreen> {
  /// How long the characters take to pop in. The voice starts as the
  /// bounce does, not before, so the greeting lands with the movement.
  static const _entrance = Duration(milliseconds: 900);

  /// The greeting lasts exactly this long unless the student skips it.
  ///
  /// It is a fixed timer rather than "however long the voice runs" on
  /// purpose: the audio finishing is not a reliable signal (a missing
  /// asset, a muted device, or a platform that never reports completion
  /// would leave a child sitting on the splash), and a predictable seven
  /// seconds is what the app should cost on every launch.
  static const _dwell = Duration(seconds: 7);

  /// The screen runs in two halves. For the first two seconds the
  /// character simply hovers in place; at this mark it begins to spin
  /// away, and the spin is timed to land exactly on [_dwell] so the
  /// composition is gone at the moment the route changes rather than
  /// being cut off mid-movement.
  static const _spinAt = Duration(seconds: 2);
  static const _spinFor = Duration(seconds: 5);

  // Created only when the voice is actually played. Constructing an
  // AudioPlayer talks to the platform, so building it eagerly would make
  // this screen unmountable anywhere the plugin is absent — a widget test
  // included.
  AudioPlayer? _player;
  final _destination = Completer<Widget>();
  StreamSubscription<void>? _completionSub;
  Timer? _voiceTimer;
  Timer? _dwellTimer;
  Timer? _spinTimer;
  bool _leaving = false;

  /// Flipped once, two seconds in: the hover stops and the spin-out
  /// begins. A tap skips straight past it.
  bool _spinningOut = false;

  @override
  void initState() {
    super.initState();
    _resolveDestination();
    _voiceTimer = Timer(_entrance, _playWelcomeVoice);
    _spinTimer = Timer(_spinAt, () {
      if (mounted) setState(() => _spinningOut = true);
    });
    _dwellTimer = Timer(_dwell, _leave);
  }

  @override
  void dispose() {
    _voiceTimer?.cancel();
    _dwellTimer?.cancel();
    _spinTimer?.cancel();
    _completionSub?.cancel();
    // Releases the platform player as well as the Dart object; without
    // this the decoder stays alive for the rest of the session.
    _player?.dispose();
    _player = null;
    super.dispose();
  }

  Future<void> _playWelcomeVoice() async {
    try {
      final player = _player ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(AssetSource('audio/welcome.mp3'), volume: 0.85);
    } catch (_) {
      // No audio is not a reason to block the app: fall through and let
      // the dwell timer move on.
    }
  }

  /// Works out where to go, but does not navigate — the greeting decides
  /// when, this decides where.
  Future<void> _resolveDestination() async {
    final authService = widget.authService;
    StudentProfile? profile;
    if (authService != null) {
      try {
        profile = await authService.restoreActiveStudentSession();
      } catch (_) {
        profile = null;
      }
    }
    if (_destination.isCompleted) return;
    _destination.complete(
      profile != null && authService != null
          ? StudentHomeScreen(
              profile: profile,
              authService: authService,
              apiBaseUrl: widget.apiBaseUrl,
            )
          : LoginScreen(
              authService: authService,
              initializationError: widget.initializationError,
              apiBaseUrl: widget.apiBaseUrl,
            ),
    );
  }

  /// Called by the seven-second mark or by a tap to skip — whichever comes
  /// first, and only ever once.
  ///
  /// Unlike the old exit, this does not schedule another animation before
  /// navigating. By the time the dwell timer fires the spin-out has
  /// already finished on screen; and a tap is meant to be immediate, so
  /// making it wait for a farewell animation is the opposite of skipping.
  Future<void> _leave() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    _spinTimer?.cancel();
    _dwellTimer?.cancel();
    // Deliberately not awaited. Skipping is a direct response to a tap and
    // must not wait on the audio backend to acknowledge a stop — if that
    // call is slow, or never answers on a platform without the plugin, the
    // student would be stuck staring at the splash. `dispose` releases the
    // player regardless.
    final stopping = _player?.stop();
    if (stopping != null) unawaited(stopping.catchError((_) {}));
    final destination = await _destination.future;
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      StudentPageRoute<void>(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7EA),
      body: GestureDetector(
        // Tap anywhere to skip.
        behavior: HitTestBehavior.opaque,
        onTap: _leave,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Color(0xFFFFF4DF),
                    Color(0xFFFDECD8),
                    Color(0xFFE7F3F6),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final area = constraints.biggest;
                  final portrait = area.height > area.width;
                  final shortest = area.shortestSide;

                  final logoSize =
                      (shortest * 0.20).clamp(64.0, 150.0).toDouble();
                  final titleSize =
                      (shortest * 0.055).clamp(17.0, 34.0).toDouble();
                  final characterHeight =
                      ((portrait ? area.height * 0.24 : area.height * 0.42))
                          .clamp(90.0, 250.0)
                          .toDouble();

                  // The whole composition is authored at its natural size
                  // and then scaled down to whatever the screen is. That
                  // makes an overflow impossible on any aspect ratio or
                  // pixel density rather than merely unlikely.
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: area.width * 0.05,
                      vertical: area.height * 0.04,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      // The character and the greeting leave together —
                      // the character spinning, the words simply shrinking
                      // and fading with it — so the screen empties as one
                      // composition rather than in pieces.
                      child: _SpinAway(
                        away: _spinningOut,
                        duration: _spinFor,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _WelcomeBrand(
                              logoSize: logoSize,
                              titleSize: titleSize,
                            ),
                            SizedBox(height: shortest * 0.045),
                            _GreetingCharacter(
                              asset: 'assets/images/start.png',
                              height: characterHeight * 1.35,
                              entrance: _entrance,
                              spinning: _spinningOut,
                              spinDuration: _spinFor,
                            ),
                            SizedBox(height: shortest * 0.05),
                            Text(
                              'اضغط في أي مكان للتخطي',
                              style: TextStyle(
                                color: const Color(0xFF7B8B99),
                                fontSize: titleSize * 0.46,
                                fontWeight: FontWeight.w700,
                              ),
                            ).animate(delay: 1400.ms).fadeIn(duration: 600.ms),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeBrand extends StatelessWidget {
  const _WelcomeBrand({required this.logoSize, required this.titleSize});

  final double logoSize;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/manara-logo-mark-transparent.png',
          height: logoSize,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .scale(
              begin: const Offset(0.55, 0.55),
              end: const Offset(1, 1),
              duration: 800.ms,
              curve: Curves.elasticOut,
            ),
        SizedBox(height: logoSize * 0.08),
        Text(
          'منارة المعرفة التعليمية',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: titleSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
            // A black drop shadow under black text only muddies its edges;
            // a white glow is what actually holds the name apart from the
            // artwork behind it now that the name itself is black.
            shadows: const [
              Shadow(color: Colors.white, blurRadius: 8),
            ],
          ),
        )
            .animate(delay: 260.ms)
            .fadeIn(duration: 520.ms)
            .moveY(begin: 14, end: 0, curve: Curves.easeOutBack),
      ],
    );
  }
}

/// One character: an elastic pop-in, then a soft hover in place, and
/// finally a spin as it leaves.
///
/// The hover is deliberately quieter than the old bounce — a slow, even
/// rise and fall with no squash — because it now has to hold the screen
/// on its own for two seconds before anything else happens, and a
/// character hopping that long reads as restless rather than alive.
class _GreetingCharacter extends StatelessWidget {
  const _GreetingCharacter({
    required this.asset,
    required this.height,
    required this.entrance,
    required this.spinning,
    required this.spinDuration,
  });

  final String asset;
  final double height;
  final Duration entrance;

  /// Flipped once, at the two-second mark.
  final bool spinning;
  final Duration spinDuration;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => SizedBox(height: height),
    );

    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return image;

    // Once the spin starts the hover stops: leaving both running would
    // have the character bobbing while it turns, which reads as a glitch
    // rather than a flourish. _SpinAway above handles the shrink and the
    // fade for the whole composition; this adds only the rotation.
    if (spinning) return _Spin(duration: spinDuration, child: image);

    final hovering = Animate(
      onPlay: (controller) => controller.repeat(reverse: true),
      delay: entrance,
      effects: [
        MoveEffect(
          begin: Offset.zero,
          end: Offset(0, -height * 0.055),
          duration: 1500.ms,
          curve: Curves.easeInOut,
        ),
        RotateEffect(
          begin: -0.008,
          end: 0.008,
          duration: 1500.ms,
          curve: Curves.easeInOut,
        ),
      ],
      child: image,
    );

    return Animate(
      delay: Duration.zero,
      effects: [
        FadeEffect(duration: 320.ms),
        ScaleEffect(
          begin: const Offset(0.2, 0.2),
          end: const Offset(1, 1),
          alignment: Alignment.bottomCenter,
          duration: entrance,
          curve: Curves.elasticOut,
        ),
      ],
      child: hovering,
    );
  }
}

/// Turns its child a full three times about its vertical axis, with a
/// perspective entry in the matrix so it reads as a figure rotating in
/// space rather than a flat picture being squeezed side to side.
class _Spin extends StatefulWidget {
  const _Spin({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  State<_Spin> createState() => _SpinState();
}

class _SpinState extends State<_Spin> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Eased in rather than linear: the character drifts into the turn
        // and is at its fastest as it disappears, which is what stops the
        // spin looking mechanical.
        final t = Curves.easeInCubic.transform(_controller.value);
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(t * 3 * 2 * math.pi),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Shrinks and fades whatever it wraps once [away] flips, over exactly
/// [duration], and holds it steady before then.
class _SpinAway extends StatelessWidget {
  const _SpinAway({
    required this.away,
    required this.duration,
    required this.child,
  });

  final bool away;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!away) return child;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return const SizedBox.shrink();
    }
    return child
        .animate()
        .scaleXY(begin: 1, end: 0.04, duration: duration, curve: Curves.easeInCubic)
        .fadeOut(duration: duration, curve: Curves.easeInCubic);
  }
}
