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
    this.stagger = const Duration(milliseconds: 620),
    this.duration = const Duration(milliseconds: 780),
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
  /// Set so that a card is almost entirely at rest before the next one begins
  /// — 620ms against a 780ms flight leaves only the last fifth overlapping,
  /// which is the tail of the settle rather than any of the spiral. One card
  /// is in the air at a time, which is what "one after another" means.
  ///
  /// It began at 70ms, where all nine were airborne together and the rail
  /// simply appeared: the sequence existed in the code and nowhere on screen.
  final Duration stagger;

  /// How long a single card takes to land.
  ///
  /// Slow enough to be watched. The spiral is the point of the entrance, and
  /// a card that completes three-quarters of a turn in a third of a second
  /// only reads as a flicker.
  final Duration duration;

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

  /// From nothing at all, not from half size.
  ///
  /// The rail starts empty and each card is *born* out of the depth — at 0.5
  /// every card was already half-drawn before it moved, so the screen was
  /// never empty and the arrival had nothing to arrive from.
  late final Animation<double> _scale = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      // A touch of overshoot so the card settles rather than stopping dead.
      curve: Curves.easeOutBack,
    ),
  );

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
    if (widget.index <= 0) {
      _deal();
      return;
    }

    _cue = Timer(widget.stagger * widget.index, () {
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
