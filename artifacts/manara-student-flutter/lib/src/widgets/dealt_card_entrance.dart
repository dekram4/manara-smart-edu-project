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
class DealtCardEntrance extends StatefulWidget {
  const DealtCardEntrance({
    required this.index,
    required this.child,
    this.stagger = const Duration(milliseconds: 260),
    this.duration = const Duration(milliseconds: 620),
    this.sound = true,
    super.key,
  });

  /// Position in the rail; decides this card's turn.
  final int index;

  final Widget child;

  /// Gap between one card starting and the next one starting.
  ///
  /// Long enough that the eye follows one card at a time. At the 70ms this
  /// began with, nine cards were all in the air together and the rail simply
  /// appeared — the sequence was there in the code and invisible on screen.
  final Duration stagger;

  /// How long a single card takes to land.
  ///
  /// Deliberately longer than the gap between cards, so a card is still
  /// settling as the next one starts. Waiting for full rest before beginning
  /// the next makes nine cards take three seconds and reads as stalling;
  /// overlapping the tail of one with the head of the next keeps the order
  /// unmistakable while the rail still fills at a watchable pace.
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

    // A student who has asked the system for less motion gets the rail
    // already dealt — and in silence. Honouring the setting means no
    // animation and no sound, not a faster one.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.value = 1;
      return;
    }

    // The first card deals immediately rather than through a zero-length
    // timer. A `Timer(Duration.zero)` does not run until the frame is over,
    // so the card would sit folded for the whole of that frame however long
    // it lasted — and a test that pumps 400ms and then measures would catch
    // the card at the very start of its flight instead of at rest.
    if (widget.index <= 0) {
      if (widget.sound) StudentSoundService.instance.playCardDeal();
      _controller.forward();
      return;
    }

    _cue = Timer(widget.stagger * widget.index, () {
      if (!mounted) return;
      if (widget.sound) StudentSoundService.instance.playCardDeal();
      _controller.forward();
    });
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
        // Straight from a quarter turn away, not a half: at 180° the card
        // starts back-on and spends the first half of its flight showing a
        // mirror image of itself, which reads as a glitch. -90° starts it
        // edge-on, so it is never seen reversed.
        final remaining = 1 - _turn.value;
        final matrix = Matrix4.identity()
          // Perspective: without it `rotateY` is an affine squash and the
          // card looks like it is being flattened rather than turned.
          ..setEntry(3, 2, 0.0012)
          // Pushed back along z as well as scaled down, so the card really
          // is further away at the start rather than just smaller. With the
          // perspective entry above, the two together are what make it read
          // as coming out of the depth.
          ..translate(0.0, 0.0, -160.0 * remaining)
          // The quarter turn, and a little roll that unwinds with it: a card
          // dealt by hand does not arrive perfectly square, and the roll is
          // what separates this from a panel being un-flattened.
          ..rotateY(remaining * (-math.pi / 2))
          ..rotateZ(remaining * 0.22)
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
