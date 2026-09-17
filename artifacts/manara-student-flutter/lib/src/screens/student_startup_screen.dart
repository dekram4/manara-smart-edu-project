import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/student_profile.dart';
import '../l10n/student_strings.dart';
import '../services/student_auth_service.dart';
import '../theme/student_theme.dart';
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
      backgroundColor: StudentSurface.warmGround(context),
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
                              asset: 'assets/images/path_mascot.png',
                              // A standing figure drawn tall, where the old
                              // asset was three children drawn wide. The same
                              // multiplier would have her towering over the
                              // title.
                              height: characterHeight * 1.15,
                              entrance: _entrance,
                            ),
                            SizedBox(height: shortest * 0.05),
                            Text(
                              tr('app.skipHint'),
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
        // Drawn as a flat black silhouette, matching the name beneath it
        // and the lockup on the login board. srcIn keeps the mark's own
        // shape — the ring, the open book, the arrow — and replaces only
        // its colours, so what is lost is the teal gradient, not the
        // drawing.
        ColorFiltered(
          colorFilter: const ColorFilter.mode(StudentPalette.brandBlue, BlendMode.srcIn),
          child: Image.asset(
            'assets/images/manara-logo-mark-transparent.png',
            height: logoSize,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
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
          tr('app.name'),
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

/// The welcome character: three schoolchildren, drawn mid-stride with their
/// arms up and grinning.
///
/// What the art already contains decided the animation. They are drawn
/// *running*, so they run in from the side rather than fading up on the spot;
/// their arms are already raised and their mouths already open, so a rock of
/// the body reads as waving and cheering without needing a second frame.
///
/// The sequence is one controller with four stretches of a single timeline —
/// run in, land, wave, settle — because these are phases of one movement. Four
/// separate controllers would let them drift apart, and the landing squash
/// only reads as a landing if it is locked to the arrival.
class _GreetingCharacter extends StatefulWidget {
  const _GreetingCharacter({
    required this.asset,
    required this.height,
    required this.entrance,
  });

  final String asset;
  final double height;
  final Duration entrance;

  @override
  State<_GreetingCharacter> createState() => _GreetingCharacterState();
}

class _GreetingCharacterState extends State<_GreetingCharacter>
    with TickerProviderStateMixin {
  /// Run in, land, wave — played once.
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1750),
  );

  /// The living idle underneath, which never stops.
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _arrival.value = 1;
      return;
    }
    _arrival.forward();
    _idle.repeat();
  }

  @override
  void dispose() {
    _arrival.dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      widget.asset,
      height: widget.height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => SizedBox(height: widget.height),
    );

    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return image;
    return AnimatedBuilder(
      animation: Listenable.merge([_arrival, _idle]),
      child: image,
      builder: (context, child) {
        final t = _arrival.value;

        // ── Hop in ──────────────────────────────────────────────────────
        // She is drawn standing, one hand on her hip, so she arrives with a
        // hop rather than a run: up from below the frame, stretched tall at
        // the top of the arc the way a jumping figure is drawn, then landing.
        final hopPhase = (t / 0.32).clamp(0.0, 1.0);
        final rise = Curves.easeOutCubic.transform(hopPhase);
        final dy = (1 - rise) * widget.height * 0.55;
        // Forward, not just upward: she grows through the jump as if coming
        // toward the student. Without this the hop reads as a figure bobbing
        // in place on a flat plane, which is what "jump in to greet" is not.
        final approach = 0.82 + 0.18 * rise;
        // Stretch while airborne, strongest at the start of the arc.
        final airborne = (1 - hopPhase) * math.sin(hopPhase * math.pi);
        final stretchY = 1 + airborne * 0.10;
        final stretchX = 1 - airborne * 0.07;

        // ── Land ────────────────────────────────────────────────────────
        // Squash on contact, then a smaller rebound. Volume is traded
        // between the axes rather than both shrinking, which is what
        // separates a landing from the whole figure simply getting smaller.
        final landPhase = ((t - 0.28) / 0.20).clamp(0.0, 1.0);
        final squash = math.sin(landPhase * math.pi) * (1 - landPhase * 0.45);
        final squashX = 1 + squash * 0.14;
        final squashY = 1 - squash * 0.14;

        // ── Wave ────────────────────────────────────────────────────────
        // Three rocks from the waist, fading out. She has a free arm and a
        // smile already drawn, so leaning into that side is what reads as a
        // greeting on a figure that cannot lift its hand.
        final wavePhase = ((t - 0.46) / 0.54).clamp(0.0, 1.0);
        final waveFade = wavePhase <= 0 ? 0.0 : (1 - wavePhase);
        final wave = math.sin(wavePhase * math.pi * 6) * 0.075 * waveFade;

        // ── Idle ────────────────────────────────────────────────────────
        // Only once the greeting has finished, so the two are never fighting.
        final settled =
            Curves.easeIn.transform(((t - 0.74) / 0.26).clamp(0.0, 1.0));
        final phase = _idle.value * math.pi * 2;
        final float = math.sin(phase) * widget.height * 0.026 * settled;
        // Wider than it is tall, and on its own slower period, so the breath
        // never locks into the float and turns the pair into one bob.
        final breath = math.sin(phase * 0.71) * 0.013 * settled;
        final sway = math.sin(phase * 0.5) * 0.010 * settled;


        return Transform(
          // Pivoted at her feet: a figure that leans or squashes does so
          // about the ground it stands on. About the centre she would appear
          // to slide sideways as she rocks.
          alignment: Alignment.bottomCenter,
          transform: Matrix4.identity()
            ..translate(0.0, dy - float)
            ..rotateZ(wave + sway)
            ..scale(
              approach * stretchX * squashX * (1 + breath),
              approach * stretchY * squashY * (1 - breath * 0.6),
            ),
          child: Opacity(
            opacity: Curves.easeOut.transform((t / 0.18).clamp(0.0, 1.0)),
            child: child,
          ),
        );
      },
    );
  }
}

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
