import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import 'student_avatar_view.dart';

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

/// Where one painted square sits inside `masar.png`, as fractions of the
/// artwork.
///
/// Measured, not estimated: the image was read pixel by pixel and each
/// square's inner edge found by walking out from its centre until the gold
/// frame began. That is why these are not six copies of one rounded number —
/// the squares really are a few pixels apart, and a field pinned with a
/// tidied-up average sits visibly off-centre in its frame.
@immutable
class _Tile {
  const _Tile(this.cx, this.cy, this.w, this.h);
  final double cx;
  final double cy;
  final double w;
  final double h;

  Rect resolve(Rect image) => Rect.fromCenter(
        center: Offset(
          image.left + cx * image.width,
          image.top + cy * image.height,
        ),
        width: w * image.width,
        height: h * image.height,
      );
}

/// Top row left to right, then the bottom row: the order the path is walked.
const List<_Tile> _tiles = [
  _Tile(0.4606, 0.3707, 0.1122, 0.1492),
  _Tile(0.6561, 0.3707, 0.1100, 0.1492),
  _Tile(0.8489, 0.3707, 0.1100, 0.1492),
  _Tile(0.4606, 0.6691, 0.1122, 0.1492),
  _Tile(0.6561, 0.6687, 0.1100, 0.1484),
  _Tile(0.8500, 0.6687, 0.1078, 0.1484),
];

/// The artwork's own aspect ratio (1800 x 1307). Everything is placed as a
/// fraction of the rect `BoxFit.contain` actually draws it into, so a field
/// lands inside its painted square at any window size.
const double masarAspect = 1800 / 1307;

/// The academic path, laid straight onto the `masar.png` artwork.
///
/// No trail is drawn in code. The picture already has one — six framed
/// squares across a schoolyard — and the six levels are placed *into* those
/// squares. The student taps the square itself, and their character walks
/// across the picture to stand on the one they chose.
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
  /// The character's walk from one square to the next.
  late final AnimationController _walk = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 680),
  );

  /// The glow on the square waiting to be answered.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  int _from = 0;
  int _to = 0;
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
    if (reduced == _reducedMotion && (_reducedMotion || _pulse.isAnimating)) {
      return;
    }
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
    // Opening a route from inside an animation callback rebuilds the tree
    // mid-tick, so the sheet waits for the frame to finish.
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

  Future<void> openStage(int index) async {
    if (index < 0 || index >= widget.stages.length) return;
    final stage = widget.stages[index];
    if (!stage.isOpen) return;
    StudentSoundService.instance.playTap();

    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: StudentSurface.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _StageSheet(stage: stage),
    );
    if (picked != null) stage.onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final area = Size(box.maxWidth, box.maxHeight);
        final image = _imageRectFor(area);

        return AnimatedBuilder(
          animation: Listenable.merge([_walk, _pulse]),
          builder: (context, _) {
            final travelled = Curves.easeInOutCubic.transform(_walk.value);
            final fromRect = _tiles[_from.clamp(0, _tiles.length - 1)]
                .resolve(image);
            final toRect =
                _tiles[_to.clamp(0, _tiles.length - 1)].resolve(image);
            final stand = Offset.lerp(
              fromRect.topCenter,
              toRect.topCenter,
              travelled,
            )!;
            // The hop, flat at both ends so the character leaves and lands on
            // a square rather than through it.
            final hop = _from == _to
                ? 0.0
                : math.sin(travelled * math.pi) * toRect.height * 0.45;
            final avatar =
                (toRect.height * 0.62).clamp(22.0, 78.0).toDouble();

            return Stack(
              // Clipped, because on a narrow window the artwork is drawn
              // larger than this box on purpose and its scenery runs off the
              // edges. Without this it would paint over the HUD chips and the
              // start button.
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fromRect(
                  rect: image,
                  child: Image.asset(
                    'assets/images/masar.png',
                    fit: BoxFit.fill,
                    // Decoded at the size actually drawn. At full size the
                    // artwork holds about 9MB of pixels, which a cheap phone
                    // cannot spare for a background.
                    cacheWidth: (image.width *
                            MediaQuery.devicePixelRatioOf(context))
                        .clamp(360.0, 1800.0)
                        .round(),
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0xFFBFE3F5),
                    ),
                  ),
                ),
                for (var i = 0; i < widget.stages.length && i < _tiles.length; i++)
                  Positioned.fromRect(
                    rect: _tiles[i].resolve(image),
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
        // Sized from the square, because the square is sized from the
        // artwork, which is sized from the window. A fixed point size would
        // be right at one window width and wrong at every other.
        final valueSize = (box.maxHeight * 0.20).clamp(9.0, 26.0).toDouble();
        final labelSize = (valueSize * 0.66).clamp(8.0, 16.0).toDouble();

        return Semantics(
          button: true,
          label: '${stage.label}: ${stage.value ?? tr('path.choose')}',
          child: GestureDetector(
            onTap: stage.isOpen ? onTap : null,
            behavior: HitTestBehavior.opaque,
            child: Container(
              // Inset so the plate sits inside the painted gold frame rather
              // than over it — the frame is part of the picture and should
              // still read as the square's edge.
              margin: EdgeInsets.all(box.maxHeight * 0.06),
              padding: EdgeInsets.symmetric(
                horizontal: box.maxWidth * 0.06,
                vertical: box.maxHeight * 0.04,
              ),
              decoration: BoxDecoration(
                // The square already has a tick or a bomb painted on it. The
                // plate covers that, so what the student reads is their own
                // answer and not a mark that means nothing here.
                color: StudentSurface.glass(context, 0.90),
                borderRadius: BorderRadius.circular(box.maxHeight * 0.14),
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
                  // Flexible on every line: the squares are small on a narrow
                  // phone, and a caption that cannot fit must give ground
                  // rather than overflow. Never a FittedBox — scaling the
                  // type down is the regression the layout test guards.
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

/// The options for one level.
class _StageSheet extends StatelessWidget {
  const _StageSheet({required this.stage});

  final MasarStage stage;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Icon(stage.icon, color: stage.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    stage.label,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: StudentSurface.ink(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: stage.options.length,
              itemBuilder: (context, index) {
                final option = stage.options[index];
                final chosen = option == stage.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Material(
                    color: chosen
                        ? stage.color.withValues(alpha: 0.14)
                        : StudentSurface.controlWash(context),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).pop(option),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
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
    );
  }
}

/// The part of the artwork the six squares occupy, with a margin of scenery
/// around them.
///
/// Everything outside it — the hanging signs, the two children, the progress
/// bar along the foot — is scene-setting. This is the part that carries the
/// content.
const Rect _pathRegion = Rect.fromLTRB(0.395, 0.275, 0.915, 0.775);

/// Below this, a square is too small to print a level into.
///
/// Measured rather than chosen: on a 393-wide phone the whole artwork fits in
/// 369px, which makes each square 40px across and drives the type down to the
/// 9pt floor — present, and unreadable by the child it is for.
const double _minTileWidth = 62.0;

/// Where to draw the whole artwork so the squares come out usable.
///
/// Wide windows get the entire scene. Narrow ones get the path instead: the
/// picture is scaled up until the six squares fill the space and the scenery
/// around them runs off the edges. The squares are still located by exactly
/// the same fractions of the same artwork — only how much of it is on screen
/// changes — so a field never drifts out of its painted frame.
Rect _imageRectFor(Size area) {
  final whole = _containRect(area, masarAspect);
  if (whole.width * _tiles.first.w >= _minTileWidth) return whole;

  final focusAspect = (_pathRegion.width * masarAspect) / _pathRegion.height;
  final focus = _containRect(area, focusAspect);
  final fullWidth = focus.width / _pathRegion.width;
  final fullHeight = focus.height / _pathRegion.height;
  return Rect.fromLTWH(
    focus.left - _pathRegion.left * fullWidth,
    focus.top - _pathRegion.top * fullHeight,
    fullWidth,
    fullHeight,
  );
}

/// The rect `BoxFit.contain` would draw an image of [aspectRatio] into.
Rect _containRect(Size container, double aspectRatio) {
  if (container.width <= 0 || container.height <= 0) return Rect.zero;
  double width;
  double height;
  if (container.width / container.height > aspectRatio) {
    height = container.height;
    width = height * aspectRatio;
  } else {
    width = container.width;
    height = width / aspectRatio;
  }
  return Rect.fromLTWH(
    (container.width - width) / 2,
    (container.height - height) / 2,
    width,
    height,
  );
}
