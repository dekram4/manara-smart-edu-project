import 'dart:async';

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
  /// would leave a child sitting on the splash), and a predictable five
  /// seconds is what the app should cost on every launch.
  static const _dwell = Duration(seconds: 5);

  // Created only when the voice is actually played. Constructing an
  // AudioPlayer talks to the platform, so building it eagerly would make
  // this screen unmountable anywhere the plugin is absent — a widget test
  // included.
  AudioPlayer? _player;
  final _destination = Completer<Widget>();
  StreamSubscription<void>? _completionSub;
  Timer? _voiceTimer;
  Timer? _dwellTimer;
  Timer? _exitTimer;
  bool _leaving = false;

  /// How long the fly-up-and-fade runs before the route is replaced. The
  /// navigation waits for it so the exit is seen rather than cut off.
  static const _exit = Duration(milliseconds: 520);

  /// Drives the exit. Set once, on the way out.
  bool _flyingAway = false;

  @override
  void initState() {
    super.initState();
    _resolveDestination();
    _voiceTimer = Timer(_entrance, _playWelcomeVoice);
    _dwellTimer = Timer(_dwell, _leave);
  }

  @override
  void dispose() {
    _voiceTimer?.cancel();
    _dwellTimer?.cancel();
    _exitTimer?.cancel();
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

  /// Called by the voice finishing, by a tap to skip, or by the dwell
  /// backstop — whichever comes first, and only ever once.
  void _leave() {
    if (_leaving || !mounted) return;
    _leaving = true;
    // Play the exit first: the crew flies up and fades, then the route is
    // replaced, so the transition reads as one movement instead of a cut.
    setState(() => _flyingAway = true);
    // Deliberately not awaited. Skipping is a direct response to a tap and
    // must not wait on the audio backend to acknowledge a stop — if that
    // call is slow, or never answers on a platform without the plugin, the
    // student would be stuck staring at the splash. `dispose` releases the
    // player regardless.
    final stopping = _player?.stop();
    if (stopping != null) unawaited(stopping.catchError((_) {}));
    // A cancellable Timer, not Future.delayed: this one has to be torn
    // down with the screen. An uncancellable delay would outlive the
    // widget whenever the route is closed mid-exit.
    _exitTimer = Timer(_exit, _completeExit);
  }

  Future<void> _completeExit() async {
    if (!mounted) return;
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _WelcomeBrand(
                            logoSize: logoSize,
                            titleSize: titleSize,
                          ),
                          SizedBox(height: shortest * 0.045),
                          // One illustration now, instead of the guide and
                          // the reading pair side by side.
                          _GreetingCharacter(
                            asset: 'assets/images/start.png',
                            height: characterHeight * 1.35,
                            entrance: _entrance,
                            leaving: _flyingAway,
                            exitDuration: _exit,
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
            color: const Color(0xFF0E5F6B),
            fontSize: titleSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
            shadows: const [
              Shadow(color: Color(0x33000000), blurRadius: 5, offset: Offset(0, 2)),
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

/// One character: an elastic pop-in, then a continuous joyful bounce with
/// squash-and-stretch and a slight tilt.
///
/// The squash is what makes it read as cartoon rather than as a widget
/// sliding: the character stretches tall as it leaves the ground and
/// squashes wide as it lands, which is the classic pairing. Scale is
/// anchored to the bottom so the feet stay on the floor while it deforms.
class _GreetingCharacter extends StatelessWidget {
  const _GreetingCharacter({
    required this.asset,
    required this.height,
    required this.entrance,
    required this.leaving,
    required this.exitDuration,
  });

  final String asset;
  final double height;
  final Duration entrance;

  /// Flipped once, when the screen is on its way out.
  final bool leaving;
  final Duration exitDuration;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => SizedBox(height: height),
    );

    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return image;

    // The exit takes over from the idle bounce: the crew lifts off the top
    // of the screen and fades as it goes.
    if (leaving) {
      return image
          .animate()
          .moveY(
            begin: 0,
            end: -height * 2.2,
            duration: exitDuration,
            curve: Curves.easeInBack,
          )
          .fadeOut(duration: exitDuration, curve: Curves.easeIn)
          .scaleXY(begin: 1, end: 0.7, duration: exitDuration);
    }

    final bouncing = Animate(
      onPlay: (controller) => controller.repeat(reverse: true),
      delay: entrance,
      effects: [
        MoveEffect(
          begin: Offset.zero,
          end: Offset(0, -height * 0.11),
          duration: 620.ms,
          curve: Curves.easeOutQuad,
        ),
        ScaleEffect(
          begin: const Offset(1.05, 0.95),
          end: const Offset(0.95, 1.06),
          alignment: Alignment.bottomCenter,
          duration: 620.ms,
          curve: Curves.easeOutQuad,
        ),
        RotateEffect(
          begin: 0,
          end: 0.03,
          duration: 620.ms,
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
      child: bouncing,
    );
  }
}
