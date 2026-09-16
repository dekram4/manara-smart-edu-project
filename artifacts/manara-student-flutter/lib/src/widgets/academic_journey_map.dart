import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import 'student_avatar_view.dart';

/// The label size that pairs with a given value size.
double _labelFontFor(double valueSize) =>
    (valueSize * 0.62).clamp(11.0, 17.0).toDouble();

/// How tall a caption is: one label line over [lines] of the value, plus the
/// gap between them.
///
/// Shared by the layout that budgets the space and the waypoint that fills
/// it. Two copies of this sum is exactly how a caption ends up four pixels
/// taller than the cell reserved for it.
double _captionHeight(double valueSize, int lines) =>
    _labelFontFor(valueSize) * 1.35 + valueSize * 1.15 * lines + 2;

/// One stop on the journey: a level of the academic tree.
///
/// Deliberately a plain description, not a widget. The map decides where a
/// station is drawn and what it looks like; the screen decides only what a
/// station *is* — and the screen's cascade (`_selectGrade`, `_selectAtram`,
/// …) stays exactly where it was, reached through [onSelected].
@immutable
class JourneyStation {
  const JourneyStation({
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

/// The six levels of the academic path drawn as a trail the student walks.
///
/// The dropdowns this replaced were correct and unreadable: six controls of
/// equal weight, none of which said which came first or what depended on
/// what. The cascade was in the code and nowhere on the screen. A trail puts
/// it where a child can see it — you are here, that is next, and the stations
/// beyond are dim until you reach them.
///
/// The map holds no academic state of its own. It is told the stations and
/// which one is live; every choice goes straight back out through
/// [JourneyStation.onSelected]. That is what keeps the cascade the single
/// source of truth.
class AcademicJourneyMap extends StatefulWidget {
  const AcademicJourneyMap({
    required this.stations,
    required this.activeIndex,
    this.onStationChosen,
    super.key,
  });

  final List<JourneyStation> stations;

  /// The station the avatar stands on — the first one still unanswered.
  final int activeIndex;

  /// Fired once the avatar has finished walking to a new station, so the
  /// screen can open that station's choices without the student hunting for
  /// them.
  final ValueChanged<int>? onStationChosen;

  @override
  State<AcademicJourneyMap> createState() => _AcademicJourneyMapState();
}

class _AcademicJourneyMapState extends State<AcademicJourneyMap>
    with TickerProviderStateMixin {
  /// The breathing of every waypoint. One controller for all six, with each
  /// station reading it at its own phase offset — six controllers would cost
  /// six tickers to draw the same thing.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  /// The avatar's walk from one station to the next.
  late final AnimationController _walk = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  /// Where the avatar is walking from and to, as station indices. They are
  /// equal whenever it is standing still.
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
    if (reduced != _reducedMotion) {
      _reducedMotion = reduced;
      if (reduced) {
        _pulse.stop();
        _pulse.value = 0;
      } else if (!_pulse.isAnimating) {
        _pulse.repeat();
      }
    }
  }

  @override
  void didUpdateWidget(covariant AcademicJourneyMap old) {
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
    // Only a forward step is worth a hop. Going back to change an earlier
    // answer should feel like a correction, not a reward.
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
    // The station the student just walked to is the one they came here to
    // answer, so its choices open on their own. Deferred to the next frame
    // because arrival is reported from inside an animation callback, and
    // opening a route there rebuilds the tree mid-tick.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _to != landed) return;
      widget.onStationChosen?.call(landed);
      // Only if the student has not already walked on. Arrivals can queue up
      // when taps come faster than the walk, and a sheet for a station the
      // avatar has since left would be answering the wrong question.
      openStation(landed);
    });
  }

  @override
  void dispose() {
    _walk.removeStatusListener(_onWalkFinished);
    _walk.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Opens one station's options.
  ///
  /// A sheet rather than the popup menu the books used, for two reasons: a
  /// child's finger wants a big target, and a sheet can be opened from code
  /// when the avatar arrives — a `PopupMenuButton` only opens from its own
  /// tap.
  Future<void> openStation(int index) async {
    if (index < 0 || index >= widget.stations.length) return;
    final station = widget.stations[index];
    if (!station.isOpen) return;
    StudentSoundService.instance.playTap();

    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: StudentSurface.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => _StationSheet(station: station),
    );
    if (picked != null) station.onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final horizontal = size.width > size.height * 1.35;
        final layout = _TrailLayout.of(size, widget.stations.length,
            horizontal: horizontal);

        return AnimatedBuilder(
          animation: Listenable.merge([_pulse, _walk]),
          builder: (context, _) {
            final travelled = Curves.easeInOutCubic.transform(_walk.value);
            final walker = layout.pointBetween(_from, _to, travelled);
            // The hop: a half sine lifted off the trail, flat at both ends so
            // the avatar leaves and lands on the path rather than through it.
            final hop = _from == _to
                ? 0.0
                : math.sin(travelled * math.pi) * layout.hopHeight;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TrailPainter(
                      layout: layout,
                      reached: widget.activeIndex,
                      pulse: _pulse.value,
                      ink: StudentSurface.mutedInk(context),
                      track: StudentSurface.track(context),
                      stations: widget.stations,
                    ),
                  ),
                ),
                for (var i = 0; i < widget.stations.length; i++)
                  _positioned(
                    layout,
                    i,
                    _JourneyWaypoint(
                      station: widget.stations[i],
                      order: i + 1,
                      diameter: layout.nodeSize,
                      labelWidth: layout.labelWidth,
                      valueSize: layout.valueSize,
                      valueLines: layout.valueLines,
                      // Only the phase differs, so the six do not throb as
                      // one block.
                      pulse: (_pulse.value + i * 0.16) % 1.0,
                      active: i == widget.activeIndex,
                      reached: i <= widget.activeIndex,
                      below: layout.labelBelow(i),
                      onTap: () => openStation(i),
                    ),
                  ),
                Positioned(
                  left: walker.dx - layout.avatarSize / 2,
                  top: walker.dy - hop - layout.avatarSize - layout.nodeSize * 0.1,
                  width: layout.avatarSize,
                  height: layout.avatarSize,
                  child: IgnorePointer(
                    child: StudentAvatarView(
                      size: layout.avatarSize,
                      showRing: false,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _positioned(_TrailLayout layout, int index, Widget child) {
    final centre = layout.centre(index);
    final width = layout.labelWidth;
    final height = layout.slotHeight;
    return Positioned(
      left: centre.dx - width / 2,
      top: centre.dy - height / 2,
      width: width,
      height: height,
      child: child,
    );
  }
}

/// Where every station sits, and how big the parts of one are.
///
/// Pulled out of the widget so the painter and the waypoints agree on the
/// geometry by construction rather than by two copies of the same sums.
class _TrailLayout {
  const _TrailLayout._({
    required this.points,
    required this.nodeSize,
    required this.labelWidth,
    required this.slotHeight,
    required this.valueSize,
    required this.valueLines,
    required this.avatarSize,
    required this.hopHeight,
    required this.horizontal,
  });

  /// Lays the stations out as a serpentine — left to right along one row,
  /// right to left along the next.
  ///
  /// A single file of six was the obvious shape and the wrong one. Stacked
  /// down a portrait screen each station got about a seventh of the height,
  /// which is not enough to print the chosen value at a size a child can
  /// read from arm's length — and shrinking the type to fit is exactly the
  /// regression the layout test guards against. Folding the trail into rows
  /// trades length for width: every station gets a cell instead of a strip.
  factory _TrailLayout.of(Size size, int count, {required bool horizontal}) {
    final safeCount = math.max(count, 1);
    // Wide and short fits three across; tall and narrow fits two.
    final columns = horizontal ? 3 : 2;
    final rows = (safeCount / columns).ceil();

    final cellWidth = size.width / columns;
    final cellHeight = size.height / rows;

    final labelWidth = (cellWidth - 16).clamp(64.0, 340.0).toDouble();
    final node = (cellHeight * 0.26).clamp(20.0, 46.0).toDouble();
    final slotHeight = (cellHeight * 0.94).clamp(48.0, size.height).toDouble();

    // The value is sized by whichever runs out first — the cell's width or
    // what is left of its height once the node is in. Taking only the width
    // is what overflowed the caption off the bottom of its cell.
    //
    // Solved rather than estimated: the label's own size is clamped, so the
    // caption's height is not a straight multiple of the value's size and a
    // single ratio was wrong by a few pixels at the small end — which is an
    // overflow, not a rounding difference.
    final captionBudget = math.max(0.0, slotHeight - node - 8);
    var value = (labelWidth * 0.115).clamp(11.0, 30.0).toDouble();
    var lines = 2;
    while (value > 11.0 && _captionHeight(value, lines) > captionBudget) {
      value -= 0.5;
    }
    // At the floor and still too tall: the answer gives up its second line
    // before it gives up legibility.
    if (_captionHeight(value, lines) > captionBudget) lines = 1;
    final valueSize = value;
    final valueLines = lines;

    final points = <Offset>[];
    for (var i = 0; i < safeCount; i++) {
      final row = i ~/ columns;
      final within = i % columns;
      // Odd rows run backwards, so the trail turns at the end of a row
      // rather than jumping back to the start of the next.
      final column = row.isEven ? within : columns - 1 - within;
      points.add(Offset(
        cellWidth * (column + 0.5),
        cellHeight * (row + 0.5),
      ));
    }

    return _TrailLayout._(
      points: points,
      nodeSize: node,
      labelWidth: labelWidth,
      slotHeight: slotHeight,
      valueSize: valueSize,
      valueLines: valueLines,
      avatarSize: (node * 0.92).clamp(20.0, 44.0).toDouble(),
      hopHeight: node * 0.75,
      horizontal: horizontal,
    );
  }

  final List<Offset> points;
  final double nodeSize;
  final double labelWidth;
  final double slotHeight;
  final double valueSize;
  final int valueLines;
  final double avatarSize;
  final double hopHeight;
  final bool horizontal;

  Offset centre(int index) =>
      points[index.clamp(0, points.length - 1)];

  /// Every caption hangs under its node: in a grid the cells already keep
  /// neighbours apart, so alternating the side only made the rows ragged.
  bool labelBelow(int index) => true;

  Offset pointBetween(int from, int to, double t) {
    final a = centre(from);
    final b = centre(to);
    return Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
  }
}

/// Draws the trail itself: the line between stations, and the glow on the
/// stretch already walked.
class _TrailPainter extends CustomPainter {
  const _TrailPainter({
    required this.layout,
    required this.reached,
    required this.pulse,
    required this.ink,
    required this.track,
    required this.stations,
  });

  final _TrailLayout layout;
  final int reached;
  final double pulse;
  final Color ink;
  final Color track;
  final List<JourneyStation> stations;

  @override
  void paint(Canvas canvas, Size size) {
    if (layout.points.length < 2) return;

    final rest = Paint()
      ..color = track
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // The whole trail first, then the walked part painted over it — one pass
    // each rather than a per-segment colour decision.
    canvas.drawPath(_path(0, layout.points.length - 1), rest);

    if (reached > 0) {
      final done = Paint()
        ..shader = LinearGradient(
          colors: [
            stations.first.color,
            stations[reached.clamp(0, stations.length - 1)].color,
          ],
        ).createShader(Offset.zero & size)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(_path(0, reached), done);
    }

    // Milestones between stations, fading along the untravelled stretch so
    // the eye is pulled forward to the next stop.
    final dot = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < layout.points.length - 1; i++) {
      final a = layout.points[i];
      final b = layout.points[i + 1];
      for (final t in const [0.34, 0.66]) {
        final p = Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
        final ahead = i >= reached;
        dot.color = ink.withValues(alpha: ahead ? 0.16 : 0.42);
        canvas.drawCircle(p, ahead ? 2.4 : 3.2, dot);
      }
    }
  }

  Path _path(int from, int to) {
    final path = Path()..moveTo(layout.points[from].dx, layout.points[from].dy);
    for (var i = from; i < to; i++) {
      final a = layout.points[i];
      final b = layout.points[i + 1];
      // A curve through the midpoint, so the trail bends between stations
      // instead of turning a corner at each one.
      final control = layout.horizontal
          ? Offset((a.dx + b.dx) / 2, a.dy)
          : Offset(a.dx, (a.dy + b.dy) / 2);
      path.quadraticBezierTo(control.dx, control.dy, b.dx, b.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) =>
      old.reached != reached ||
      old.pulse != pulse ||
      old.ink != ink ||
      old.track != track;
}

/// One circular stop on the trail, with its level name and the answer given.
class _JourneyWaypoint extends StatelessWidget {
  const _JourneyWaypoint({
    required this.station,
    required this.order,
    required this.diameter,
    required this.labelWidth,
    required this.valueSize,
    required this.valueLines,
    required this.pulse,
    required this.active,
    required this.reached,
    required this.below,
    required this.onTap,
  });

  final JourneyStation station;
  final int order;
  final double diameter;
  final double labelWidth;
  final double valueSize;
  final int valueLines;
  final double pulse;
  final bool active;
  final bool reached;
  final bool below;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Only the station being answered breathes. A map where all six pulse is
    // a map that points nowhere.
    final swell = active ? (math.sin(pulse * math.pi * 2) * 0.5 + 0.5) : 0.0;
    final colour = reached ? station.color : StudentSurface.mutedInk(context);

    final node = SizedBox(
      width: diameter + 16,
      height: diameter + 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (active)
            Container(
              width: diameter + 8 + swell * 8,
              height: diameter + 8 + swell * 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: station.color.withValues(alpha: 0.10 + swell * 0.12),
              ),
            ),
          Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: reached
                  ? colour
                  : StudentSurface.card(context),
              border: Border.all(
                color: colour.withValues(alpha: reached ? 1 : 0.45),
                width: 2.5,
              ),
              boxShadow: [
                if (active)
                  BoxShadow(
                    color: station.color.withValues(alpha: 0.35),
                    blurRadius: 12 + swell * 8,
                    spreadRadius: swell * 2,
                  ),
              ],
            ),
            child: Icon(
              station.isChosen ? Icons.check_rounded : station.icon,
              size: diameter * 0.5,
              color: reached ? Colors.white : colour,
            ),
          ),
        ],
      ),
    );

    // Every line is `Flexible`, which is what makes the caption incapable of
    // overflowing rather than merely unlikely to.
    //
    // The budget in `_TrailLayout` picks a good size; it cannot pick a
    // provably safe one, because the real line height belongs to whichever
    // Arabic face the theme resolves and is not knowable from the point size.
    // Two attempts at a safety factor left 3.9px and then 5.9px hanging off
    // the bottom. Flexible ends the guessing: if a line does not fit it is
    // given less room and ellipsises, and the type is never scaled — which
    // is the property the layout test actually protects.
    final caption = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            station.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _labelFontFor(valueSize),
              fontWeight: FontWeight.w700,
              color: StudentSurface.mutedInk(context),
            ),
          ),
        ),
        // No FittedBox here, ever. The value carries the answer and is sized
        // from the width the trail gave it; wrapping it in a box that scales
        // to fit is what once shrank it to an unreadable few pixels on a
        // narrow screen, and the layout test compares the painted height
        // against the laid-out height to catch that returning.
        Flexible(
          child: Text(
            station.isChosen
                ? station.value!
                : (station.isOpen ? tr('path.choose') : tr('path.unavailable')),
            maxLines: valueLines,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: valueSize,
              height: 1.15,
              fontWeight: FontWeight.w900,
              color: station.isChosen
                  ? StudentSurface.ink(context)
                  : StudentSurface.mutedInk(context),
            ),
          ),
        ),
      ],
    );

    // The caption sits on its own plate.
    //
    // The trail is drawn over painted scenery — sky, a school, grass — and
    // Arabic set straight onto that is hard to read however heavy the weight,
    // because the ground behind any given letter changes. The plate gives
    // every caption one flat ground of its own. It is sized by its content,
    // so it never becomes a fixed box the text has to be squeezed into.
    final plated = DecoratedBox(
      decoration: BoxDecoration(
        color: StudentSurface.glass(context, 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: station.color.withValues(alpha: reached ? 0.55 : 0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: caption,
      ),
    );

    final children = below
        ? [node, Flexible(child: plated)]
        : [Flexible(child: plated), node];

    return Semantics(
      button: true,
      label: '${station.label}: ${station.value ?? tr('path.choose')}',
      child: GestureDetector(
        onTap: station.isOpen ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

/// The options for one station, as a sheet a child can actually hit.
class _StationSheet extends StatelessWidget {
  const _StationSheet({required this.station});

  final JourneyStation station;

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
                Icon(station.icon, color: station.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    station.label,
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
              itemCount: station.options.length,
              itemBuilder: (context, index) {
                final option = station.options[index];
                final chosen = option == station.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Material(
                    color: chosen
                        ? station.color.withValues(alpha: 0.14)
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
                                  ? station.color
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
