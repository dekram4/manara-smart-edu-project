import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_animate/flutter_animate.dart';

import '../models/student_profile.dart';
import '../l10n/student_strings.dart';
import '../services/student_auth_service.dart';
import '../theme/student_theme.dart';
import '../widgets/student_experience.dart';
import 'login_screen.dart';
import 'student_home_screen.dart';

/// The app's opening screen: the hero flies in, rolls once and settles into a
/// hover while the recorded welcome plays over it.
///
/// It still owns the session restore it always did — the animation runs while
/// `restoreActiveStudentSession` is in flight, so the greeting costs no extra
/// startup time, and a returning student still lands on the dashboard rather
/// than the login screen.
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

class _StudentStartupScreenState extends State<StudentStartupScreen>
    with WidgetsBindingObserver {
  /// How long the characters take to pop in. The voice starts as the
  /// bounce does, not before, so the greeting lands with the movement.
  static const _entrance = Duration(milliseconds: 900);

  /// The floor: the splash never costs less than this, even in silence.
  ///
  /// It was also the ceiling, and that cut the greeting off. The recorded
  /// welcome runs past seven seconds, so the route changed mid-sentence —
  /// the child heard half a greeting on every launch.
  static const _dwell = Duration(seconds: 7);

  /// The ceiling, and the reason the floor is not simply "when the voice
  /// ends".
  ///
  /// The audio finishing is not a signal that can be waited on alone: a
  /// missing asset, a muted device, or a platform that never reports
  /// completion would leave a child sitting on the splash forever. So the
  /// clip's own length is read and honoured *within* this bound, and a
  /// timer set to it runs from the first frame whatever the audio does.
  static const _maxDwell = Duration(seconds: 12);

  /// A breath after the last word before the screen changes. Cutting on
  /// the exact sample sounds clipped.
  static const _tail = Duration(milliseconds: 400);

  /// The screen runs in two halves. For the first two seconds the
  /// character simply hovers in place; at this mark it begins to spin
  /// away, and the spin is timed to land exactly on the moment of leaving
  /// so the composition is gone as the route changes rather than being cut
  /// off mid-movement. It is recomputed when the clip's length is known.
  static const _spinAt = Duration(seconds: 2);

  /// How long the spin-out takes. Not const: it stretches to land on the
  /// new leaving time when the greeting turns out to be longer than the
  /// floor.
  Duration _spinFor = const Duration(seconds: 5);

  /// When the screen will leave, measured from the first frame.
  Duration _leaveAt = _dwell;

  /// Ticks from the first frame, so a reschedule knows what is left.
  final _clock = Stopwatch();

  // Created only when the voice is actually played. Constructing an
  // AudioPlayer talks to the platform, so building it eagerly would make
  // this screen unmountable anywhere the plugin is absent — a widget test
  // included.
  AudioPlayer? _player;
  final _destination = Completer<Widget>();
  StreamSubscription<void>? _completionSub;
  StreamSubscription<Duration>? _durationSub;
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
    WidgetsBinding.instance.addObserver(this);
    _clock.start();
    _resolveDestination();
    _voiceTimer = Timer(_entrance, _playWelcomeVoice);
    _spinTimer = Timer(_spinAt, () {
      if (mounted) setState(() => _spinningOut = true);
    });
    _dwellTimer = Timer(_dwell, _leave);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.stop();
    _voiceTimer?.cancel();
    _dwellTimer?.cancel();
    _spinTimer?.cancel();
    _completionSub?.cancel();
    _durationSub?.cancel();
    // Releases the platform player as well as the Dart object; without
    // this the decoder stays alive for the rest of the session.
    _player?.dispose();
    _player = null;
    super.dispose();
  }

  /// The welcome is played here, not through `StudentSoundService`, so it
  /// needs its own answer to the screen locking: stop, and do not start
  /// later if the lock came before the greeting did. It is not replayed on
  /// return — a greeting heard after the fact is not a greeting.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    _voiceTimer?.cancel();
    final player = _player;
    if (player != null) unawaited(player.stop().catchError((_) {}));
  }

  Future<void> _playWelcomeVoice() async {
    try {
      final player = _player ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      // المقطع المورَّد أوّلاً، والقديم إن لم يُسقَط بعد. الفحص من
      // بيان الحزمة لا بمحاولةِ تشغيلٍ تفشل: المحاولةُ الفاشلة على
      // بعض المنصّات تترك المشغّل في حالٍ لا يقبل بعدها ملفاً ثانياً.
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final bundled = manifest.listAssets().toSet();
      final asset = bundled.contains('assets/audio/tarheeb.mp3')
          ? 'audio/tarheeb.mp3'
          : 'audio/welcome.mp3';

      // طولُ المقطع يصل بعد أن يفكّه المشغّل، لا قبله. فيُسمع أولاً ثم
      // تُمدّ المهلة عند وصول الطول — والمهلةُ الأولى قائمةٌ طوال ذلك،
      // فجهازٌ لا يُخبر بالطول أبداً يخرج عند الحدّ الأدنى كما كان.
      _durationSub = player.onDurationChanged.listen(
        _stretchToClip,
        onError: (_) {},
      );
      await player.play(AssetSource(asset), volume: 0.85);
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
  /// يمدّ بقاء الشاشة إلى نهاية الترحيب، في حدود السقف.
  ///
  /// يُنادى حين يُعلن المشغّل طولَ المقطع. ولا يُقصّر البقاء أبداً: طولٌ
  /// أقصر من الحدّ الأدنى يُترك، فالشاشة لها كلفةٌ دنيا لا علاقة لها
  /// بالصوت.
  void _stretchToClip(Duration clip) {
    if (!mounted || _leaving || clip <= Duration.zero) return;
    var end = _entrance + clip + _tail;
    if (end > _maxDwell) end = _maxDwell;
    if (end <= _leaveAt) return;

    final elapsed = _clock.elapsed;
    final remaining = end - elapsed;
    if (remaining <= Duration.zero) return;

    setState(() {
      _leaveAt = end;
      // الدوران يهبط على لحظة المغادرة نفسها: لو بقي على خمس ثوانٍ
      // لانتهى قبلها فتجمد الصورة ثانيةً وشيئاً في مكانها.
      final spin = end - _spinAt;
      if (spin > Duration.zero) _spinFor = spin;
    });

    _dwellTimer?.cancel();
    _dwellTimer = Timer(remaining, _leave);
  }

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
                              // Drawn already in flight — arm forward, cape
                              // streaming — so the motion below only has to
                              // carry a figure that is posed for it.
                              asset: 'assets/images/herrrro.png',
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
  /// The whole scene, on one clock.
  ///
  /// Flight, roll, landing and hover all read from this single controller —
  /// there is no second controller and nothing waits on a listener for a
  /// previous part to end. Every earlier attempt failed in the same way for
  /// the same reason: two clocks, joined at a moment, and the join was
  /// visible however it was smoothed.
  ///
  /// It repeats rather than running once, because the hover has to carry on
  /// after the landing. The cinematic is not tied to the controller's value
  /// but to [AnimationController.lastElapsedDuration], which keeps counting
  /// across repeats — so the flight plays through exactly one cycle, reaches
  /// its end, and simply stays there while the same clock goes on driving the
  /// breath. One timeline, running forward, start to finish.
  static const _sceneLength = Duration(milliseconds: 2500);

  late final AnimationController _scene = AnimationController(
    vsync: this,
    duration: _sceneLength,
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _scene.value = 1;
      return;
    }
    _scene.repeat();
  }

  @override
  void dispose() {
    _scene.dispose();
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

    // No early return for reduced motion either: that too would be a second
    // shape for the same slot. When motion is off the controller is simply
    // parked at 1, which lands the figure at rest — the same tree, the same
    // single `Image`, just not moving.
    return AnimatedBuilder(
      animation: _scene,
      child: image,
      builder: (context, child) {
        // How far into the whole scene we are, 0 to 1, and never back to 0.
        // `lastElapsedDuration` accumulates across the controller's repeats,
        // which is what lets one repeating clock carry a cinematic that plays
        // exactly once and a hover that never stops.
        final elapsedMs =
            (_scene.lastElapsedDuration ?? Duration.zero).inMilliseconds;
        // While it runs, progress comes from elapsed time so the cinematic
        // survives the controller looping. Parked — which is what reduced
        // motion does, at 1 — there is no elapsed time to read, so the value
        // itself stands in and the figure sits at the end of the scene rather
        // than at the start of it.
        final t = _scene.isAnimating
            ? (elapsedMs / _sceneLength.inMilliseconds).clamp(0.0, 1.0)
            : _scene.value;

        // ── Flight ──────────────────────────────────────────────────────
        // A caped figure, so it flies in rather than hops: from off to the
        // left, from far away, climbing as it comes.
        //
        // The arc is what separates flight from a slide. The horizontal is
        // eased, the vertical is a half sine over the same phase, so the
        // figure rises through the middle of its approach and levels out at
        // the end instead of travelling a straight line.
        final flight = Curves.easeOutCubic.transform((t / 0.62).clamp(0.0, 1.0));
        final dx = (1 - flight) * -widget.height * 1.15;
        final dy = (1 - flight) * widget.height * 0.30 -
            math.sin(flight * math.pi) * widget.height * 0.22;
        // Pushed back in z as well as scaled down: with the perspective entry
        // in the matrix the two together read as distance, where scale alone
        // reads as a small figure.
        final depth = (1 - flight) * -900.0;
        final approach = 0.40 + 0.60 * flight;

        // ── Roll ────────────────────────────────────────────────────────
        // One full turn about the vertical axis, completed exactly as the
        // flight lands — a barrel roll, not a spin in place, because it
        // happens while the figure is still travelling.
        final roll = (1 - flight) * math.pi * 2;
        // And a bank into the turn that levels off with it: a body that
        // banks is flying, a body that stays upright is being carried.
        final bank = math.sin(flight * math.pi) * 0.42 * (1 - flight * 0.35);

        // ── Landing ─────────────────────────────────────────────────────
        // The hero comes down hard and absorbs it: the classic drop into a
        // crouch. A half sine over the window straddling touchdown, so the
        // squash builds into the impact and springs back out of it rather
        // than snapping on at the moment of contact.
        //
        // Width and height trade against each other rather than both
        // shrinking — that trade is what makes it read as a body taking the
        // shock instead of the whole figure being scaled down.
        final landing = ((t - 0.56) / 0.26).clamp(0.0, 1.0);
        final impact = math.sin(landing * math.pi) * (1 - landing * 0.35);
        final squashX = 1 + impact * 0.16;
        final squashY = 1 - impact * 0.16;
        // And a dip: the knees give, so the figure drops a little further
        // than its resting height before coming back up to it.
        final crouch = impact * widget.height * 0.07;

        // ── Hover ───────────────────────────────────────────────────────
        // Read from the same clock, and running from the first frame.
        //
        // No cross-fade and no ramp-in weight is needed: every term below
        // begins at sin(0) — zero offset, zero velocity — so the hover is
        // simply present throughout, contributing nothing at the start,
        // growing underneath the flight, and left alone once the flight has
        // reached its end. There is no moment at which one stops and another
        // starts, because there is only ever one.
        final phase = _scene.value * math.pi * 2;
        final float = math.sin(phase) * widget.height * 0.032;
        // Wider than it is tall, and on its own slower period, so the breath
        // never locks into the float and turns the pair into one bob.
        final breath = math.sin(phase * 0.71) * 0.014;
        final drift = math.sin(phase * 0.5) * 0.012;
        final scaleX = approach * squashX * (1 + breath);
        final scaleY = approach * squashY * (1 - breath * 0.6);


        return Transform(
          // About the centre, not the feet: this figure is airborne for the
          // whole sequence, and a roll pivoted at the soles would swing it
          // around a point it is not standing on.
          alignment: Alignment.center,
          transform: Matrix4.identity()
            // Perspective, without which `rotateY` is an affine squash and
            // the roll reads as the figure being flattened and unflattened.
            ..setEntry(3, 2, 0.0011)
            ..translateByDouble(dx, dy - float + crouch, depth, 1.0)
            ..rotateY(roll)
            ..rotateZ(bank + drift)
            ..scaleByDouble(scaleX, scaleY, scaleX, 1.0),
          child: Opacity(
            opacity: Curves.easeOut.transform((t / 0.16).clamp(0.0, 1.0)),
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
    // One shape, always. The branch that used to be here is what made the
    // character blink out and fly in a second time.
    //
    // It returned the bare child while the composition was staying, and an
    // `Animate` wrapper once it was leaving. Those are different widget types
    // at the same position, so at the two-second mark Flutter unmounted the
    // whole subtree and built it again — taking the character's State, and
    // with it the controller driving the flight. The replacement started its
    // scene from zero: invisible for a frame, then flying in all over again,
    // in the middle of the screen's exit.
    //
    // `AnimatedScale` and `AnimatedOpacity` are in the tree whether the screen
    // is leaving or not, and only their targets change. The subtree below them
    // is never rebuilt, so the character's clock runs once from beginning to
    // end.
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final span = reduced ? Duration.zero : duration;
    return AnimatedScale(
      scale: away ? 0.04 : 1,
      duration: span,
      curve: Curves.easeInCubic,
      child: AnimatedOpacity(
        opacity: away ? 0 : 1,
        duration: span,
        curve: Curves.easeInCubic,
        child: child,
      ),
    );
  }
}
