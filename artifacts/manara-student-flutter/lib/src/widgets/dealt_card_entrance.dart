import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/student_sound_service.dart';

/// Deals one card in: it arrives from behind the screen, turning to face the
/// student as it grows into place.
///
/// Each card owns its own controller and starts after `index * stagger`, so a
/// rail deals itself out one card at a time instead of every card appearing
/// at once. That sequencing is the whole effect — a single shared controller
/// driving all of them would land them together.
///
/// **It transforms nothing the card itself owns.** The card's own motion
/// (its breath, its tilt under a finger) is produced by its own `Transform`
/// further down the tree, and tests read that matrix directly. Keeping this
/// widget strictly *above* the card — and above the card's key — is what
/// leaves that matrix describing only the card's own motion.
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

  bool isDealt(int index) => _dealt.contains(index);

  void markDealt(int index) => _dealt.add(index);
}

class DealtCardEntrance extends StatefulWidget {
  const DealtCardEntrance({
    required this.index,
    required this.child,
    this.tracker,
    this.stagger = const Duration(milliseconds: 180),
    this.duration = const Duration(milliseconds: 620),
    this.startDelay = const Duration(milliseconds: 1250),
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
  /// put the ninth card nearly six seconds after the first, which is the lag
  /// that made the last of them feel like they were never coming. At 180ms the
  /// whole rail is dealt inside two seconds and the order is still plain,
  /// because each card's own pop is far louder than the overlap between them.
  final Duration stagger;

  /// How long a single card takes to arrive.
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

  late final Animation<double> _turn = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  /// Nothing, then far too big, then right.
  ///
  /// The card is born out of the depth at 0.0 — not 0.5, where every card was
  /// already half-drawn before it moved and the rail was never really empty —
  /// rushes past its own size to 1.8, and eases back down to 1.0.
  ///
  /// Two-thirds of the time goes to the rush and a third to the settle,
  /// because an overshoot that takes as long to come back as it took to go out
  /// reads as a wobble rather than a pop. The rail is drawn with `Clip.none`,
  /// which is what lets a card at 1.8 spill over its neighbours instead of
  /// being sliced off at the edge of its slot.
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 0.0, end: 1.8)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 62,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.8, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 38,
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

    // The first card deals immediately rather than through a zero-length
    // timer. A `Timer(Duration.zero)` does not run until the frame is over,
    // so the card would sit folded for the whole of that frame however long
    // it lasted — and a test that pumps 400ms and then measures would catch
    // the card at the very start of its flight instead of at rest.
    // Every card waits, including the first: the greeting speaks over the
    // whole rail, not just over the cards after it.
    _cue = Timer(widget.startDelay + widget.stagger * widget.index, () {
      if (!mounted) return;
      _deal();
    });
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
          // Pushed back along z as well as scaled down, so the card really is
          // further away at the start rather than just smaller.
          // In logical pixels rather than a fraction of the card: the arc
          // should look the same on every card in the rail, and the cards are
          // not all the same width.
          ..translate(swing * 120.0, rise * 70.0, -420.0 * remaining)
          // Three-quarters of a turn, not a quarter: the card winds in rather
          // than simply facing round. Kept under a full turn so it never
          // shows its back, which reads as a rendering fault at this speed.
          ..rotateY(remaining * -math.pi * 0.75)
          // A roll that unwinds with it — a card dealt by hand does not
          // arrive square — and a touch of tilt so the spiral has depth.
          ..rotateZ(remaining * 0.42)
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
