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
    this.stagger = const Duration(milliseconds: 70),
    this.duration = const Duration(milliseconds: 380),
    this.sound = true,
    super.key,
  });

  /// Position in the rail; decides this card's turn.
  final int index;

  final Widget child;

  /// Gap between one card's arrival and the next.
  final Duration stagger;

  /// How long a single card takes to land.
  ///
  /// The default keeps the first card settled inside 400ms. That is a real
  /// constraint, not a taste: the hub's motion tests press and drag the first
  /// card after a 400ms pump, and a card still flying at that moment would be
  /// measured mid-flight.
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

  late final Animation<double> _scale = Tween<double>(
    begin: 0.5,
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
    curve: const Interval(0, 0.45, curve: Curves.easeOut),
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
        final radians = (1 - _turn.value) * (-math.pi / 2);
        final matrix = Matrix4.identity()
          // Perspective: without it `rotateY` is an affine squash and the
          // card looks like it is being flattened rather than turned.
          ..setEntry(3, 2, 0.0012)
          ..rotateY(radians)
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
