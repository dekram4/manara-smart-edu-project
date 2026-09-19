import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/student_sound_service.dart';

/// Remembers which cards have already been dealt.
///
/// The rail is a `ListView`, which builds its children lazily and throws away
/// the ones scrolled out of view. Without somewhere outside the card to record
/// that it has arrived, every card rebuilt on scroll started its entrance from
/// nothing again — so dragging the rail sideways made cards vanish and spiral
/// back in, over and over.
///
/// Owned by the screen, not the card, precisely because it has to outlive the
/// card. Indices are stable here because the rail's contents are fixed.
class DealEntranceTracker {
  final Set<int> _dealt = <int>{};

  /// Whether the rail has been given permission to start.
  ///
  /// The deal used to begin on a fixed delay guessed to be longer than the
  /// spoken greeting. A guess is wrong on any device where the voice is slower
  /// — or is skipped, where it then waits for nothing. The screen now arms the
  /// rail when the greeting has actually finished, and every card listens for
  /// that rather than counting.
  final ValueNotifier<bool> armed = ValueNotifier<bool>(false);

  bool isDealt(int index) => _dealt.contains(index);

  void markDealt(int index) => _dealt.add(index);

  void arm() => armed.value = true;

  void dispose() => armed.dispose();
}

/// Deals one card in: it arrives from behind the screen, growing and turning
/// to face the student before settling into place.
///
/// Each card owns its own controller and starts after `index * stagger`, so a
/// rail deals itself out one card at a time instead of every card appearing at
/// once. That sequencing is the whole effect — a single shared controller
/// driving all of them would land them together.
///
/// **It transforms nothing the card itself owns.** The card's own motion — its
/// breath, its tilt under a finger — is produced by its own `Transform` further
/// down the tree, and tests read that matrix directly. Keeping this widget
/// strictly *above* the card, and above the card's key, is what leaves that
/// matrix describing only the card's own motion.
class DealtCardEntrance extends StatefulWidget {
  /// The defaults, named so callers can reason about the rail's timing
  /// without copying the numbers.
  static const defaultStagger = Duration(milliseconds: 650);
  static const defaultDuration = Duration(milliseconds: 1450);
  static const defaultStartDelay = Duration(milliseconds: 1250);

  /// How long the deal itself runs, measured from the moment the rail is
  /// armed. This is what the music waits for.
  ///
  /// Derived from the same constants the cards use, so anything that waits for
  /// the deal stays in step with it. Hard-coding a matching delay elsewhere is
  /// how the two drift apart the first time a timing is tuned.
  static Duration dealSpanFor(int count) =>
      defaultStagger * (count - 1).clamp(0, 1 << 20) + defaultDuration;

  /// The same span, plus the fixed wait used when no screen is sequencing the
  /// rail — tests and any caller without a tracker.
  static Duration totalFor(int count) =>
      defaultStartDelay + dealSpanFor(count);

  const DealtCardEntrance({
    required this.index,
    required this.child,
    this.tracker,
    this.stagger = defaultStagger,
    this.duration = defaultDuration,
    this.startDelay = defaultStartDelay,
    this.sound = true,
    super.key,
  });

  /// Position in the rail; decides this card's turn.
  final int index;

  final Widget child;

  /// Where this card records that it has arrived. Without one, a card rebuilt
  /// by the list deals itself in all over again.
  final DealEntranceTracker? tracker;

  /// Gap between one card starting and the next one starting.
  ///
  /// A flat step, not a wait for the card before to finish. Waiting for rest
  /// put the ninth card nearly six seconds after the first, which made the last
  /// of them feel like they were never coming; a flat step keeps every gap the
  /// same, so no card is ever the one that lags.
  ///
  /// At 650ms against a 1450ms flight, a card is already down to roughly its
  /// own size and into its settle before the next one leaves — the cards arrive
  /// singly and are plainly in order, which is the whole point of dealing them.
  final Duration stagger;

  /// How long a single card takes to arrive.
  ///
  /// Slow on purpose, and slower than instinct suggests. The card travels
  /// three-quarters of a turn while shrinking from nearly three times its own
  /// size; at 620ms that was over before the eye had found it, at 1200ms it
  /// could be watched but not savoured. At 1450ms the shrink has a visible
  /// middle and a visible end, which is the only reason the movement exists.
  final Duration duration;

  /// How long the rail waits before dealing anything at all.
  ///
  /// The hub greets the student by name as it opens, and the deal used to
  /// start under that: nine page-turns over a spoken sentence, so neither was
  /// heard properly. This lets the greeting have the first second to itself.
  final Duration startDelay;

  /// Whether this card ticks as it lands.
  final bool sound;

  @override
  State<DealtCardEntrance> createState() => _DealtCardEntranceState();
}

class _DealtCardEntranceState extends State<DealtCardEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  /// The pending start of this card's turn, kept so it can be cancelled if
  /// the rail is disposed before the card ever deals.
  Timer? _cue;

  /// Set once the reduced-motion answer is known. [MediaQuery] is not
  /// readable from [initState], so the decision waits for the first
  /// dependency change.
  bool _started = false;

  /// Drives the turn and the arc through space.
  ///
  /// Eased at *both* ends, not just the out. An ease-out alone spends its
  /// rotation in the first third and then holds still for the rest of a 1450ms
  /// flight, which reads as a snap followed by a stall. Easing in as well gives
  /// the roll a slow beginning, a body, and a slow end — and lands it on the
  /// same frame the shrink finishes on.
  late final Animation<double> _turn = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );

  /// Enormous, then right.
  ///
  /// The card comes in from the front of the scene at 2.9 times its size and
  /// shrinks the whole way down to 1.0 — it is arriving, not being inflated.
  /// The rail is drawn with `Clip.none`, which is what lets a card that large
  /// spill over its neighbours instead of being sliced off at the edge of its
  /// slot.
  ///
  /// Split in two because one curve cannot do both jobs. The first 60% carries
  /// it from 2.9 down to 1.35, eased at both ends so the travel has a middle
  /// instead of collapsing in the first few frames; the last 40% — a full 580ms
  /// — is the settle from 1.35 to rest, slow enough to be seen stopping. A
  /// single ease-out across the whole flight put 80% of the shrink in the first
  /// 400ms and left a second of near-stillness after it.
  ///
  /// Sine rather than cubic on that first stretch. A cubic ease-in is nearly
  /// flat at the start, and the card fades in during exactly that stretch — so
  /// it appeared at 2.9 and hung there, motionless and filling the screen,
  /// before it began to move. Sine is moving by the time the card can be seen.
  ///
  /// It ends flat at 1.0, with no overshoot past it: the card stops where it
  /// stops.
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 2.9, end: 1.35)
          .chain(CurveTween(curve: Curves.easeInOutSine)),
      weight: 60,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.35, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 40,
    ),
  ]).animate(_controller);

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    // Opaque well before the card stops turning: a card that is still fading
    // while it settles reads as a rendering fault rather than a deal.
    curve: const Interval(0, 0.35, curve: Curves.easeOut),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Already arrived once. Scrolling the rail rebuilt this card; it must
    // appear exactly where it was, at rest, in silence. Re-running the
    // entrance here is the bug where cards blink out mid-drag.
    if (widget.tracker?.isDealt(widget.index) ?? false) {
      _controller.value = 1;
      return;
    }

    // A student who has asked the system for less motion gets the rail
    // already dealt — and in silence. Honouring the setting means no
    // animation and no sound, not a faster one.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.value = 1;
      widget.tracker?.markDealt(widget.index);
      return;
    }

    final tracker = widget.tracker;
    if (tracker == null) {
      // No screen is sequencing this rail, so fall back to the fixed wait.
      _cue = Timer(widget.startDelay + widget.stagger * widget.index, _dealIfMounted);
      return;
    }
    if (tracker.armed.value) {
      _scheduleTurn();
    } else {
      tracker.armed.addListener(_onArmed);
    }
  }

  void _onArmed() {
    if (!mounted) return;
    final tracker = widget.tracker;
    if (tracker == null || !tracker.armed.value) return;
    tracker.armed.removeListener(_onArmed);
    _scheduleTurn();
  }

  /// This card's place in the queue, counted from the moment the rail was
  /// armed rather than from the moment the screen opened.
  void _scheduleTurn() {
    _cue?.cancel();
    _cue = Timer(widget.stagger * widget.index, _dealIfMounted);
  }

  void _dealIfMounted() {
    if (!mounted) return;
    _deal();
  }

  void _deal() {
    if (widget.sound) StudentSoundService.instance.playCardDeal();
    // Recorded at the start of the flight rather than at its end. A card
    // scrolled out of view mid-arrival is disposed before it can finish, and
    // marking it only on completion would let it deal itself in again when it
    // came back — which is the very flicker this is here to stop.
    widget.tracker?.markDealt(widget.index);
    _controller.forward();
  }

  @override
  void dispose() {
    // Both matter: the timer can outlive the widget when the student leaves
    // the hub mid-deal, and the controller holds a ticker until released.
    widget.tracker?.armed.removeListener(_onArmed);
    _cue?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      // The card subtree is built once and reused on every frame; only the
      // transform around it changes. Rebuilding the illustration 60 times a
      // second is what would cost the frame budget here.
      child: widget.child,
      builder: (context, child) {
        final remaining = 1 - _turn.value;
        // The spiral: the card travels a shallow arc as it turns, instead of
        // growing on the spot. Sine across, cosine falling — so it swings out
        // to one side early and curves back in as it settles, which is what
        // makes the motion read as a path through space rather than a zoom.
        final swing = math.sin(remaining * math.pi) * 0.34;
        final rise = (1 - math.cos(remaining * math.pi * 0.5)) * 0.22;

        final matrix = Matrix4.identity()
          // Perspective: without it the rotations are affine squashes and the
          // card looks flattened rather than turned.
          ..setEntry(3, 2, 0.0014)
          // Brought *forward* along z, not pushed back — the card starts in
          // front of the scene and recedes into its slot. Negative is forward
          // here: the perspective row divides by `1 + 0.0014 * z`, so a
          // negative z divides by less than one and magnifies. Getting this
          // sign wrong pushes the card away while the scale says it is close,
          // and the two cancel into a flat zoom.
          //
          // Kept small (90px against a 2.9 scale) because that divide
          // multiplies whatever the scale is already doing — 90px is another
          // 14% on top. The size is the scale tween's job; this only has to
          // make the movement read as depth rather than zoom.
          //
          // The lateral swing is in logical pixels rather than a fraction of
          // the card: the arc should look the same on every card in the rail,
          // and the cards are not all the same width.
          ..translate(swing * 120.0, rise * 70.0, -90.0 * remaining)
          // Just under a quarter turn — 77°, deliberately short of 90°.
          //
          // This used to be 135°, which is past edge-on, and Flutter does no
          // backface culling: past 90° the card paints mirrored. That was
          // survivable while the turn was front-loaded and the card was still
          // fading in, but at 1450ms with an eased-in turn the card holds past
          // 90° for the first 600ms — fully opaque, three times its size, and
          // showing its artwork and text in mirror. It reads as a rendering
          // fault, not a deal. Stopping at 77° keeps the card facing the
          // student for every frame it can actually be seen in.
          ..rotateY(remaining * -math.pi * 0.43)
          // The roll now carries the winding the Y turn gave up. Z rotation is
          // in the plane of the screen, so it can be as generous as the motion
          // wants without ever turning the card away: 54° is a card arriving
          // askew and straightening, which is how a card dealt by hand lands.
          ..rotateZ(remaining * 0.95)
          // A touch of tilt so the arc has depth rather than being flat.
          ..rotateX(remaining * 0.18)
          ..scale(_scale.value);
        return Opacity(
          opacity: _fade.value.clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: matrix,
            child: child,
          ),
        );
      },
    );
  }
}
