import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import 'student_avatar_view.dart';
import 'student_mascot.dart';

/// The width to decode the artwork at, never a value that can throw.
///
/// `cacheWidth` takes an `int`, and getting there from a layout measurement
/// means `round()` — which throws `UnsupportedError` on `NaN` and on
/// `infinity`. A single bad frame during layout was therefore enough to take
/// the whole screen down, which is precisely the failure this guards.
int _safeCacheWidth(double raw) {
  if (!raw.isFinite || raw <= 0) return 900;
  return raw.clamp(360.0, 1800.0).round();
}

/// One level of the academic tree, bound to one painted square.
@immutable
class MasarStage {
  const MasarStage({
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String? value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  bool get isChosen => (value ?? '').trim().isNotEmpty;
  bool get isOpen => options.isNotEmpty;
}

/// A rectangle inside the artwork, in fractions of it.
///
/// Every one of these was measured off the image rather than eyeballed: the
/// pixels were scanned for the thing being covered — a green sign, an orange
/// arrow, the parchment scroll — and the bounding box read back. A patch
/// placed by guesswork leaves a sliver of what it was meant to hide.
typedef _Frac = Rect;

const _Frac _tileGrade = Rect.fromLTRB(0.4045, 0.2961, 0.5167, 0.4453);
const _Frac _tileAtram = Rect.fromLTRB(0.6011, 0.2961, 0.7111, 0.4453);
const _Frac _tileSubject = Rect.fromLTRB(0.7939, 0.2961, 0.9039, 0.4453);
const _Frac _tileTerm = Rect.fromLTRB(0.4045, 0.5945, 0.5167, 0.7437);
const _Frac _tileUnit = Rect.fromLTRB(0.6011, 0.5945, 0.7111, 0.7429);
const _Frac _tileLesson = Rect.fromLTRB(0.7961, 0.5945, 0.9039, 0.7429);

const List<_Frac> _tiles = [
  _tileGrade,
  _tileAtram,
  _tileSubject,
  _tileTerm,
  _tileUnit,
  _tileLesson,
];

/// The three hanging signs, with their gold frames included so nothing of the
/// English underneath shows at the edges.
const List<_Frac> _signs = [
  Rect.fromLTRB(0.0244, 0.0337, 0.2778, 0.1515),
  Rect.fromLTRB(0.0244, 0.1806, 0.2778, 0.2984),
  Rect.fromLTRB(0.0244, 0.3320, 0.2778, 0.4499),
];

/// The two orange arrows at the foot of the scene.
const List<_Frac> _arrows = [
  Rect.fromLTRB(0.0778, 0.8584, 0.1511, 0.9594),
  Rect.fromLTRB(0.8578, 0.8646, 0.9311, 0.9594),
];

/// The blank parchment scroll over the schoolhouse.
const _Frac _scroll = Rect.fromLTRB(0.3944, 0.0459, 0.9522, 0.1576);

/// Where the two cheering mascots stand, on the grass between the painted
/// children and the schoolhouse.
///
/// They are additions to the scene, not replacements for the children painted
/// into it. Those two cannot be animated: they are part of the picture, and
/// they share their colours with the fence and the sky behind them, so no
/// colour key separates them. Cutting a rectangle around them and bouncing
/// that would drag a moving seam across the artwork, and would reveal the
/// originals still standing underneath.
const List<_Frac> _cheerSpots = [
  Rect.fromLTRB(0.300, 0.700, 0.372, 0.885),
  Rect.fromLTRB(0.368, 0.726, 0.430, 0.885),
];

/// The path artwork with the six levels printed into the squares drawn on it.
///
/// The picture is the screen: it is stretched to fill, and everything on top
/// is placed as a fraction of that same rect, so a patch or a field lands on
/// the thing it belongs to at any window size.
class MasarPathBoard extends StatefulWidget {
  const MasarPathBoard({
    required this.stages,
    required this.activeIndex,
    super.key,
  });

  final List<MasarStage> stages;

  /// Which square the character is standing on.
  final int activeIndex;

  @override
  State<MasarPathBoard> createState() => _MasarPathBoardState();
}

class _MasarPathBoardState extends State<MasarPathBoard>
    with TickerProviderStateMixin {
  late final AnimationController _walk = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 680),
  );

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  int _from = 0;
  int _to = 0;
  bool _started = false;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _from = widget.activeIndex;
    _to = widget.activeIndex;
    _walk.value = 1;
    _walk.addStatusListener(_onWalkFinished);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_started && reduced == _reducedMotion) return;
    _started = true;
    _reducedMotion = reduced;
    if (reduced) {
      _pulse.stop();
      _pulse.value = 0;
    } else {
      _pulse.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant MasarPathBoard old) {
    super.didUpdateWidget(old);
    if (widget.activeIndex != _to) _startWalk(widget.activeIndex);
  }

  void _startWalk(int target) {
    _from = _to;
    _to = target;
    if (_reducedMotion) {
      _walk.value = 1;
      _onArrived();
      return;
    }
    if (target > _from) StudentSoundService.instance.playTap();
    _walk.forward(from: 0);
  }

  void _onWalkFinished(AnimationStatus status) {
    if (status == AnimationStatus.completed && _from != _to) _onArrived();
  }

  void _onArrived() {
    if (!mounted) return;
    final landed = _to;
    _from = _to;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _to != landed) return;
      openStage(landed);
    });
  }

  @override
  void dispose() {
    _walk.removeStatusListener(_onWalkFinished);
    _walk.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// True while a level's card is on screen.
  ///
  /// Without this the board can stack dialogs on top of each other: one route
  /// opens from a tap and another from the character arriving a moment later,
  /// and because each choice walks the character on to the next square, the
  /// second arrival opens a third. The student then has to dismiss a pile of
  /// cards they never asked for, which is indistinguishable from the screen
  /// having locked up.
  bool _dialogOpen = false;

  /// Opens the options for one level, as a card that grows out of the middle
  /// of the screen over a blurred scene.
  ///
  /// Not a bottom sheet. A sheet slides up from an edge and belongs to the
  /// chrome of the app; this screen is a place, and the choice should arrive
  /// in front of the student rather than from underneath the picture.
  Future<void> openStage(int index) async {
    if (_dialogOpen) return;
    if (index < 0 || index >= widget.stages.length) return;
    final stage = widget.stages[index];
    if (!stage.isOpen) return;
    StudentSoundService.instance.playTap();

    _dialogOpen = true;
    try {
      await _showStageDialog(stage);
    } finally {
      // In a `finally` so a dismissed route, a pop during a rebuild, or an
      // error inside the card can never leave the board unable to open
      // anything again — which would be a real lock-up rather than a
      // cosmetic one.
      _dialogOpen = false;
    }
  }

  Future<void> _showStageDialog(MasarStage stage) async {
    final picked = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: stage.label,
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, _, __) {
        final eased = CurvedAnimation(
          parent: animation,
          // Overshoot on the way in, plain ease on the way out: a card that
          // bounces as it leaves reads as indecision.
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        return Stack(
          children: [
            // The blur is driven by the same animation, so the scene softens
            // as the card grows rather than snapping out of focus first.
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: 6 * animation.value,
                  sigmaY: 6 * animation.value,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.75, end: 1).animate(eased),
                  child: _StageDialog(stage: stage),
                ),
              ),
            ),
          ],
        );
      },
    );
    if (picked != null) stage.onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // Nothing below may run on a size that is not a real number.
        //
        // An unbounded parent gives `infinity` here and a broken one can give
        // `NaN`; both then flow into every `Positioned.fromRect` on the board
        // and into `cacheWidth`, where `NaN.round()` throws outright. The
        // result on a device is a screen that never paints. A board with no
        // room is not an error worth crashing over — it just waits for a real
        // constraint on the next layout.
        if (!box.maxWidth.isFinite ||
            !box.maxHeight.isFinite ||
            box.maxWidth <= 1 ||
            box.maxHeight <= 1) {
          return const ColoredBox(color: Color(0xFFBFE3F5));
        }
        final area = Rect.fromLTWH(0, 0, box.maxWidth, box.maxHeight);
        Rect place(_Frac f) => Rect.fromLTRB(
              area.left + f.left * area.width,
              area.top + f.top * area.height,
              area.left + f.right * area.width,
              area.top + f.bottom * area.height,
            );

        return AnimatedBuilder(
          animation: Listenable.merge([_walk, _pulse]),
          builder: (context, _) {
            final travelled = Curves.easeInOutCubic.transform(_walk.value);
            final fromTile = place(_tiles[_from.clamp(0, _tiles.length - 1)]);
            final toTile = place(_tiles[_to.clamp(0, _tiles.length - 1)]);
            final stand =
                Offset.lerp(fromTile.topCenter, toTile.topCenter, travelled)!;
            final hop = _from == _to
                ? 0.0
                : math.sin(travelled * math.pi) * toTile.height * 0.45;
            final avatar = (toTile.height * 0.70).clamp(28.0, 96.0).toDouble();

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Stretched to fill, as the brief asks: no letterboxing and
                // no crop, so every square and every patch below lands on the
                // part of the picture it was measured against.
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/masar.png',
                    fit: BoxFit.fill,
                    cacheWidth: _safeCacheWidth(
                      area.width * MediaQuery.devicePixelRatioOf(context),
                    ),
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: Color(0xFFBFE3F5)),
                  ),
                ),

                // The three English signs, replaced with Arabic cheers.
                for (var i = 0; i < _signs.length; i++)
                  Positioned.fromRect(
                    rect: place(_signs[i]),
                    child: _CheerSign(
                      text: tr(_cheerKeys[i]),
                      accent: _cheerColors[i],
                    ),
                  ),

                // The two arrows, replaced with something worth earning.
                for (var i = 0; i < _arrows.length; i++)
                  Positioned.fromRect(
                    rect: place(_arrows[i]),
                    child: _RewardBadge(
                      icon: i == 0
                          ? Icons.star_rounded
                          : Icons.local_fire_department_rounded,
                      color: i == 0
                          ? const Color(0xFFFFC107)
                          : const Color(0xFFFF6B35),
                      pulse: (_pulse.value + i * 0.5) % 1.0,
                    ),
                  ),

                // Two mascots cheering the student on from the grass.
                for (var i = 0; i < _cheerSpots.length; i++)
                  Positioned.fromRect(
                    rect: place(_cheerSpots[i]),
                    child: _CheeringMascot(
                      builder: (size) => i == 0
                          ? PathMascot(size: size)
                          : StudentMascot(size: size),
                      // Half a cycle apart, so they bounce alternately the way
                      // two children egging each other on would, rather than
                      // in lockstep like a pair of metronomes.
                      pulse: (_pulse.value + i * 0.5) % 1.0,
                    ),
                  ),

                // The blank scroll over the schoolhouse, now the school's name.
                Positioned.fromRect(
                  rect: place(_scroll),
                  child: _SchoolBanner(text: tr('path.schoolName')),
                ),

                for (var i = 0; i < widget.stages.length && i < _tiles.length; i++)
                  Positioned.fromRect(
                    rect: place(_tiles[i]),
                    child: _StageField(
                      stage: widget.stages[i],
                      active: i == widget.activeIndex,
                      pulse: _pulse.value,
                      onTap: () => openStage(i),
                    ),
                  ),

                Positioned(
                  left: stand.dx - avatar / 2,
                  top: stand.dy - hop - avatar,
                  width: avatar,
                  height: avatar,
                  child: IgnorePointer(
                    child: StudentAvatarView(size: avatar, showRing: false),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

const List<String> _cheerKeys = [
  'path.cheer1',
  'path.cheer2',
  'path.cheer3',
];

const List<Color> _cheerColors = [
  Color(0xFF12806A),
  Color(0xFF9C4221),
  Color(0xFF1E4E8C),
];

/// A wooden plaque carrying one Arabic cheer, sized to cover the sign beneath.
class _CheerSign extends StatelessWidget {
  const _CheerSign({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = (box.maxHeight * 0.36).clamp(10.0, 30.0).toDouble();
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(accent, Colors.white, 0.18)!,
                Color.lerp(accent, Colors.black, 0.20)!,
              ],
            ),
            borderRadius: BorderRadius.circular(box.maxHeight * 0.22),
            border: Border.all(
              color: const Color(0xFFE8B75A),
              width: math.max(2, box.maxHeight * 0.07),
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: box.maxWidth * 0.06),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: const [
                Shadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 2)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One mascot bouncing on the spot, cheering the student on.
///
/// Takes a builder rather than an asset path on purpose. Each mascot image is
/// owned by exactly one widget in `student_mascot.dart`, and a test walks the
/// source tree to make sure no other file names those files — so that changing
/// the illustration is a one-line edit rather than a search. This bounces
/// whatever that widget renders instead of reaching past it.
class _CheeringMascot extends StatelessWidget {
  const _CheeringMascot({required this.builder, required this.pulse});

  final Widget Function(double size) builder;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final height = box.maxHeight;
        // A bounce, not a float: the figure leaves the ground on a half sine
        // and spends the rest of the cycle standing on it, which is the shape
        // of a jump. A full sine would have it hovering half the time.
        final beat = math.max(0.0, math.sin(pulse * math.pi * 2));
        final lift = beat * height * 0.13;
        // Squashed at the bottom of the bounce and stretched at the top —
        // the weight of the landing, without which a jump reads as a glide.
        final squash = (1 - beat) * (1 - beat);
        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.identity()
            ..translate(0.0, -lift)
            ..scale(1 + squash * 0.07, 1 - squash * 0.07 + beat * 0.05),
          // Sized by width: both mascot widgets take a width and keep their
          // own aspect, so asking for a height would stretch them.
          child: Align(
            alignment: Alignment.bottomCenter,
            child: builder(box.maxWidth),
          ),
        );
      },
    );
  }
}

/// A glowing badge in place of a navigation arrow.
class _RewardBadge extends StatelessWidget {
  const _RewardBadge({
    required this.icon,
    required this.color,
    required this.pulse,
  });

  final IconData icon;
  final Color color;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final swell = math.sin(pulse * math.pi * 2) * 0.5 + 0.5;
    return LayoutBuilder(
      builder: (context, box) {
        final d = math.min(box.maxWidth, box.maxHeight);
        return Center(
          child: Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color.lerp(color, Colors.white, 0.35)!,
                  color,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45 + swell * 0.25),
                  blurRadius: 10 + swell * 12,
                  spreadRadius: swell * 2,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: d * 0.62),
          ),
        );
      },
    );
  }
}

/// The school's name, written across the parchment scroll on the building.
class _SchoolBanner extends StatelessWidget {
  const _SchoolBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = (box.maxHeight * 0.42).clamp(11.0, 40.0).toDouble();
        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: box.maxWidth * 0.06,
            vertical: box.maxHeight * 0.14,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFDF3DC), Color(0xFFEBD9AE)],
            ),
            borderRadius: BorderRadius.circular(box.maxHeight * 0.18),
            border: Border.all(
              color: const Color(0xFFB98A3C),
              width: math.max(1.5, box.maxHeight * 0.05),
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2)),
            ],
          ),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: box.maxWidth * 0.04),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
              color: const Color(0xFF7A4B12),
            ),
          ),
        );
      },
    );
  }
}

/// The field printed inside one painted square.
class _StageField extends StatelessWidget {
  const _StageField({
    required this.stage,
    required this.active,
    required this.pulse,
    required this.onTap,
  });

  final MasarStage stage;
  final bool active;
  final double pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final swell = active ? (math.sin(pulse * math.pi * 2) * 0.5 + 0.5) : 0.0;
        // Sized by whichever of the square's two dimensions runs out first.
        // Taking only the height made the type overflow sideways on a narrow
        // portrait window, where the squares are tall and thin.
        final valueSize = math
            .min(box.maxHeight * 0.20, box.maxWidth * 0.20)
            .clamp(11.0, 28.0)
            .toDouble();
        final labelSize = (valueSize * 0.66).clamp(8.0, 17.0).toDouble();

        return Semantics(
          button: true,
          label: '${stage.label}: ${stage.value ?? tr('path.choose')}',
          child: GestureDetector(
            onTap: stage.isOpen ? onTap : null,
            behavior: HitTestBehavior.opaque,
            child: Container(
              // Tight on purpose. On a narrow portrait window the squares
              // are only about a ninth of the screen wide, and every pixel
              // the frame takes is one the Arabic cannot have.
              margin: EdgeInsets.all(
                math.min(box.maxHeight, box.maxWidth) * 0.04,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: box.maxWidth * 0.03,
                vertical: box.maxHeight * 0.03,
              ),
              decoration: BoxDecoration(
                // The square already has a tick or a bomb painted on it; the
                // plate covers that, so what the student reads is their own
                // answer and not a mark that means nothing here.
                color: StudentSurface.glass(context, 0.90),
                borderRadius: BorderRadius.circular(box.maxHeight * 0.12),
                border: Border.all(
                  color: stage.color.withValues(
                    alpha: active ? 0.55 + swell * 0.45 : 0.30,
                  ),
                  width: active ? 2.0 + swell : 1.2,
                ),
                boxShadow: [
                  if (active)
                    BoxShadow(
                      color: stage.color.withValues(alpha: 0.30 + swell * 0.2),
                      blurRadius: 8 + swell * 10,
                    ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Flexible on every line, so a square too small for its
                  // caption gives ground instead of overflowing. Never a
                  // FittedBox: scaling the type is the regression the layout
                  // test guards against.
                  Flexible(
                    child: Text(
                      stage.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: labelSize,
                        fontWeight: FontWeight.w700,
                        color: StudentSurface.mutedInk(context),
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      stage.isChosen
                          ? stage.value!
                          : (stage.isOpen
                              ? tr('path.choose')
                              : tr('path.unavailable')),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: valueSize,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                        color: stage.isChosen
                            ? StudentSurface.ink(context)
                            : StudentSurface.mutedInk(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The floating glass card that carries one level's options.
class _StageDialog extends StatelessWidget {
  const _StageDialog({required this.stage});

  final MasarStage stage;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(size.width * 0.86, 420),
          maxHeight: size.height * 0.74,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: StudentSurface.glass(context, 0.94),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: stage.color.withValues(alpha: 0.55),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: stage.color.withValues(alpha: 0.28),
                blurRadius: 30,
                spreadRadius: 2,
              ),
              const BoxShadow(
                color: Colors.black26,
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      stage.color.withValues(alpha: 0.22),
                      stage.color.withValues(alpha: 0.06),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: stage.color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(stage.icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        stage.label,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: StudentSurface.ink(context),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: tr('common.close'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: StudentSurface.mutedInk(context),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                  itemCount: stage.options.length,
                  itemBuilder: (context, index) {
                    final option = stage.options[index];
                    final chosen = option == stage.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Material(
                        color: chosen
                            ? stage.color.withValues(alpha: 0.16)
                            : StudentSurface.controlWash(context),
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            StudentSoundService.instance.playTap();
                            Navigator.of(context).pop(option);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 15,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  chosen
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  color: chosen
                                      ? stage.color
                                      : StudentSurface.mutedInk(context),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    option,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: chosen
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      color: StudentSurface.ink(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }
}
