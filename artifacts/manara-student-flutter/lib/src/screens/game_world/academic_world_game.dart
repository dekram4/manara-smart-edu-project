import 'dart:math' as math;
// dart:ui's TextStyle would otherwise collide with the Flutter TextStyle
// that TextPaint (below) actually expects.
import 'dart:ui' hide TextStyle;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier, VoidCallback;
import 'package:flutter/material.dart' show Colors, TextStyle, Icons, IconData;
import 'package:flutter/scheduler.dart' show SchedulerBinding;

/// One selectable option in the current step of the academic path (a grade,
/// a term, a subject, a chapter, a unit, or a lesson) — rendered as a
/// station on the road-map the student taps.
class WorldStation {
  const WorldStation({required this.id, required this.label});

  final String id;
  final String label;
}

/// A distinctive icon per stage, cycled by the station's index so
/// neighbouring stages always look different from one another.
const _stationIcons = <IconData>[
  Icons.flag_rounded,
  Icons.star_rounded,
  Icons.auto_awesome_rounded,
  Icons.emoji_events_rounded,
  Icons.rocket_launch_rounded,
  Icons.local_fire_department_rounded,
  Icons.favorite_rounded,
  Icons.bolt_rounded,
];

/// A real journey always shows at least this many stops on the map, even
/// when only one (or a couple) real option(s) exist for the current step —
/// the rest are rendered as locked "قريباً" placeholders continuing the
/// same winding path, so the screen never reads as one lonely circle in an
/// empty sky.
const _minVisualStops = 4;

String _truncateLabel(String label) =>
    label.length > 16 ? '${label.substring(0, 15)}…' : label;

/// The interactive game world behind [AcademicSelectionScreen]'s stage
/// picker: a living sky with drifting cartoon clouds and twinkling stars,
/// and — for whichever step is currently active — that step's options laid
/// out as floating 3D islands along a winding, glowing dotted road, the way
/// an adventure/level map lays out its stages (padded with locked stops so
/// it always reads as an extending journey). Flutter (not Flame) owns the
/// actual selection state; this game only ever reports "the student tapped
/// station X" through [onStationSelected] and shows whatever station list
/// it's told to via [showStations].
class AcademicWorldGame extends FlameGame {
  AcademicWorldGame({required this.onStationSelected});

  /// Called with the tapped station's id. The screen is responsible for
  /// applying that to the real selection state and then calling
  /// [showStations] again for the next step.
  final void Function(String stationId) onStationSelected;

  /// World-space (== screen-space, see [onLoad]) position of the currently
  /// selected island, so the Flutter-side avatar overlay can stand there /
  /// travel there. Null until a station is selected for the first time.
  final ValueNotifier<Vector2?> avatarTarget = ValueNotifier(null);

  /// Current step's theme color, driving both the sky and the stations.
  final ValueNotifier<Color> accent = ValueNotifier(const Color(0xFF4F46E5));

  double _breatheTime = 0;
  List<WorldStation> _pendingStations = const [];
  String? _pendingSelectedId;
  final List<Vector2> _stationPositions = [];

  @override
  Color backgroundColor() => const Color(0xFF6C8CF5);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // World (0,0) == the top-left pixel of the GameWidget, with no
    // zoom/pan — the simplest possible mapping, and the one the Flutter
    // avatar overlay relies on to place itself directly from a station's
    // `position` with no coordinate conversion.
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    world.add(_CloudCluster(startX: 0.12, y: 90, scale: 1.0, speed: 9));
    world.add(_CloudCluster(startX: 0.75, y: 160, scale: 0.7, speed: -6));
    world.add(_CloudCluster(startX: 0.4, y: 50, scale: 0.55, speed: 5));

    final rng = math.Random(7); // fixed seed: stable, non-jittery star field
    for (var i = 0; i < 14; i++) {
      world.add(
        _TwinkleStar(
          xFrac: rng.nextDouble(),
          yFrac: rng.nextDouble() * 0.55,
          phase: rng.nextDouble() * math.pi * 2,
          radius: 1.4 + rng.nextDouble() * 1.8,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _breatheTime += dt;
  }

  @override
  void render(Canvas canvas) {
    if (!hasLayout) return;
    // A slow "breathing" sky wash — bright and cheerful, tinted by the
    // current step's accent color — behind everything else.
    final breathe = (math.sin(_breatheTime * 0.5) + 1) / 2; // 0..1
    final top = Color.lerp(
      const Color(0xFF6C8CF5),
      accent.value,
      0.35 + breathe * 0.15,
    )!;
    final bottom = Color.lerp(const Color(0xFFB794F6), accent.value, 0.25)!;
    final paint = Paint()
      ..shader = Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.y),
        [top, bottom],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
    _drawRoad(canvas);
    super.render(canvas);
  }

  /// The glowing dotted road connecting one station to the next, drawn
  /// under the stations (and clouds, which is fine — clouds drift above
  /// everything) but over the sky wash. Runs through locked stations too,
  /// so the path always reads as continuing further into the journey.
  void _drawRoad(Canvas canvas) {
    if (_stationPositions.length < 2) return;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.25);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.85);
    for (var i = 0; i < _stationPositions.length - 1; i++) {
      _drawDottedSegment(canvas, _stationPositions[i], _stationPositions[i + 1], glow);
      _drawDottedSegment(canvas, _stationPositions[i], _stationPositions[i + 1], line);
    }
  }

  void _drawDottedSegment(Canvas canvas, Vector2 a, Vector2 b, Paint paint) {
    final total = (b - a).length;
    if (total <= 0) return;
    const dashLen = 12.0;
    const gapLen = 10.0;
    final dir = (b - a) / total;
    var covered = 0.0;
    while (covered < total) {
      final start = a + dir * covered;
      final end = a + dir * math.min(covered + dashLen, total);
      canvas.drawLine(Offset(start.x, start.y), Offset(end.x, end.y), paint);
      covered += dashLen + gapLen;
    }
  }

  /// Clears whatever stations are currently shown and lays out a new set
  /// for [stations], themed with [stepAccent]. [selectedId] (if any of
  /// these stations was already picked for this step, e.g. after going
  /// back) gets a highlighted "current pick" look. Called by the screen
  /// every time the active step changes (including going back a step) —
  /// this can happen before the GameWidget has ever been laid out (the
  /// very first call arrives from an async data fetch that may resolve
  /// before Flutter has even built the widget once), so it must never
  /// touch `size` directly; see [_applyPendingStations].
  void showStations(
    List<WorldStation> stations, {
    required Color stepAccent,
    String? selectedId,
  }) {
    accent.value = stepAccent;
    _pendingStations = stations;
    _pendingSelectedId = selectedId;
    _applyPendingStations();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // The first resize callback is exactly what makes `hasLayout` true, so
    // this is also where an earlier showStations() call that arrived too
    // early finally gets to actually lay itself out. A later, genuine
    // resize re-flows the same (still-current) stations for the new size.
    _applyPendingStations();
  }

  /// Safe to call at any time, including before the game has a layout yet
  /// (`hasLayout` is false right up until Flame calls [onGameResize] for
  /// the first time) — in that case it's a no-op and [onGameResize] will
  /// call it again once a real size is available. Never accesses `size`
  /// (which asserts `hasLayout` internally) except behind that guard, so
  /// the student is never left looking at a debug assertion instead of
  /// their academic path.
  void _applyPendingStations() {
    if (!hasLayout) return;
    world.removeWhere((component) => component is _IslandComponent);
    _layoutStations();
  }

  void _layoutStations() {
    _stationPositions.clear();
    if (_pendingStations.isEmpty || size.x <= 0 || size.y <= 0) return;
    const stationDiameter = 88.0;
    const topMargin = 110.0;
    const bottomMargin = 130.0;
    final realCount = _pendingStations.length;
    // Pad the visible path with locked placeholders so even a single
    // available option still reads as a real, extending adventure map.
    final visualCount = math.max(realCount, _minVisualStops);
    final usableHeight = math.max(size.y - topMargin - bottomMargin, 0.0);
    final verticalSpacing = visualCount > 1 ? usableHeight / (visualCount - 1) : 0.0;
    final centerX = size.x / 2;
    // How far the road winds side to side — generous on a wide screen,
    // clamped so it never pushes a station off a narrow one.
    final amplitude = math.min(size.x * 0.28, size.x / 2 - stationDiameter);

    // Where the traveling guide (the Flutter-side avatar overlay) should
    // stand for this layout — the already-picked station, if any, so the
    // guide is visible standing at the student's current spot on the path
    // from the moment it loads, not only after their first tap.
    Vector2? selectedPosition;

    for (var i = 0; i < visualCount; i++) {
      final y = visualCount > 1
          ? topMargin + i * verticalSpacing
          : topMargin + usableHeight / 2;
      final x = centerX + math.sin(i * 0.9) * amplitude;
      final position = Vector2(x, y);
      _stationPositions.add(position);

      final locked = i >= realCount;
      final station = locked ? null : _pendingStations[i];
      final isSelected = !locked && station!.id == _pendingSelectedId;
      if (isSelected) selectedPosition = position.clone();

      final island = _IslandComponent(
        station: station,
        accent: accent.value,
        baseY: y,
        phase: i * 0.7,
        selected: isSelected,
        locked: locked,
        icon: _stationIcons[i % _stationIcons.length],
        stageNumber: i + 1,
        onSelected: locked
            ? null
            : () {
                avatarTarget.value = position.clone();
                onStationSelected(station!.id);
              },
      )
        ..position = position.clone()
        ..size = Vector2.all(stationDiameter)
        ..anchor = Anchor.center;
      world.add(island);
    }

    // Deferred: this can run synchronously *during* Flutter's build/layout
    // phase (the very first layout arrives from onGameResize, which Flame
    // calls from inside the GameWidget's own LayoutBuilder). Setting a
    // ValueNotifier's value there triggers its ValueListenableBuilder's
    // setState() mid-build, which throws. A post-frame callback runs after
    // that phase finishes, which is always safe — and one frame's delay is
    // imperceptible for a guide standing still on a station.
    if (selectedPosition != null) {
      final target = selectedPosition;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        avatarTarget.value = target;
      });
    }
  }
}

/// A soft drifting cartoon cloud — a cluster of overlapping blurred puffs
/// plus a light top highlight for a touch of puffy 3D shading — that wraps
/// around horizontally once it drifts off either edge of the screen.
class _CloudCluster extends PositionComponent {
  _CloudCluster({
    required double startX,
    required double y,
    required double scale,
    required this.speed,
  }) : _startXFraction = startX,
       _scale = scale,
       super(anchor: Anchor.center) {
    position.y = y;
  }

  final double _startXFraction;
  final double _scale;
  final double speed;
  bool _initialized = false;

  static const _puffs = [
    Offset(-26, 4),
    Offset(-6, -10),
    Offset(18, -4),
    Offset(34, 6),
    Offset(4, 10),
  ];

  @override
  void update(double dt) {
    super.update(dt);
    final game = findGame();
    if (game == null || !game.hasLayout) return;
    final gameSize = game.size;
    if (gameSize.x <= 0) return;
    final margin = 70 * _scale;
    if (!_initialized) {
      position.x = gameSize.x * _startXFraction;
      _initialized = true;
    }
    position.x += speed * dt;
    if (position.x < -margin) position.x = gameSize.x + margin;
    if (position.x > gameSize.x + margin) position.x = -margin;
  }

  @override
  void render(Canvas canvas) {
    final base = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    for (final puff in _puffs) {
      canvas.drawCircle(puff * _scale, 22 * _scale, base);
    }
    canvas.drawCircle(
      const Offset(-6, -12) * _scale,
      14 * _scale,
      Paint()..color = Colors.white.withOpacity(0.25),
    );
  }
}

/// A tiny, independently-pulsing star scattered across the upper sky for
/// visual depth. Its screen position is fixed once the game first has a
/// layout (fractional, the same trick [_CloudCluster] uses), then it just
/// twinkles in place.
class _TwinkleStar extends PositionComponent {
  _TwinkleStar({
    required double xFrac,
    required double yFrac,
    required double phase,
    this.radius = 2.2,
  }) : _xFrac = xFrac,
       _yFrac = yFrac,
       _phase = phase,
       super(anchor: Anchor.center);

  final double _xFrac;
  final double _yFrac;
  final double _phase;
  final double radius;
  double _time = 0;
  bool _placed = false;

  @override
  void update(double dt) {
    super.update(dt);
    final game = findGame();
    if (game == null || !game.hasLayout) return;
    if (!_placed) {
      position = Vector2(game.size.x * _xFrac, game.size.y * _yFrac);
      _placed = true;
    }
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    if (!_placed) return;
    final twinkle = (math.sin(_time * 2.2 + _phase) + 1) / 2; // 0..1
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()..color = Colors.white.withOpacity(0.25 + twinkle * 0.6),
    );
  }
}

/// One stop on the road-map, rendered as a floating 3D "island/pod" that
/// bobs continuously on a sine wave. An unlocked station carries a
/// distinctive [icon], its 1-based [stageNumber], and its label; tapping it
/// gives a short scale-bounce and reports the tap upward via [onSelected].
/// A [selected] station (already picked for this step) gets a bright
/// checkmark badge. A [locked] station (a placeholder beyond the real
/// options, so the map always reads as an extending journey) renders
/// desaturated with a lock icon and a "قريباً" label, and a tap on it only
/// gives a gentle denial shake — it never reports a selection.
class _IslandComponent extends PositionComponent with TapCallbacks {
  _IslandComponent({
    required this.station,
    required this.accent,
    required double baseY,
    required double phase,
    this.selected = false,
    this.locked = false,
    this.icon = Icons.star_rounded,
    this.stageNumber = 1,
    this.onSelected,
  }) : assert(locked || station != null, 'an unlocked island needs a station'),
       _baseY = baseY,
       _phase = phase;

  final WorldStation? station;
  final Color accent;
  final bool selected;
  final bool locked;
  final IconData icon;
  final int stageNumber;
  final VoidCallback? onSelected;
  final double _baseY;
  final double _phase;

  double _time = 0;
  late final TextComponent _label;
  late final TextComponent _iconGlyph;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    const shadows = [
      Shadow(color: Color(0xE6000000), blurRadius: 6),
      Shadow(color: Color(0xFF000000), blurRadius: 2, offset: Offset(0, 1)),
    ];
    _label = TextComponent(
      text: locked ? 'قريباً' : _truncateLabel(station!.label),
      anchor: Anchor.topCenter,
      position: Vector2(size.x / 2, size.y + 8),
      textRenderer: TextPaint(
        style: TextStyle(
          color: locked ? Colors.white.withOpacity(0.75) : Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          shadows: shadows,
        ),
      ),
    );
    add(_label);

    final glyph = locked ? Icons.lock_rounded : icon;
    _iconGlyph = TextComponent(
      text: String.fromCharCode(glyph.codePoint),
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y / 2),
      textRenderer: TextPaint(
        style: TextStyle(
          fontSize: locked ? 24 : 28,
          fontFamily: glyph.fontFamily,
          package: glyph.fontPackage,
          color: locked ? Colors.white.withOpacity(0.85) : Colors.white,
          shadows: const [Shadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1))],
        ),
      ),
    );
    add(_iconGlyph);

    if (!locked) {
      add(
        TextComponent(
          text: '$stageNumber',
          anchor: Anchor.center,
          position: Vector2(15, 15),
          textRenderer: TextPaint(
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    position.y = _baseY + math.sin(_time * 1.6 + _phase) * 6;
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);

    // A soft drop shadow beneath the island gives it a bit of floating-3D
    // lift off the sky behind it.
    canvas.drawOval(
      rect.translate(0, size.y * 0.16).deflate(size.x * 0.1),
      Paint()
        ..color = Colors.black.withOpacity(locked ? 0.12 : 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    if (selected) {
      // A soft glow ring behind a selected station makes it read as "this
      // is your current pick" at a glance among the rest of the stations.
      canvas.drawOval(
        rect.inflate(7),
        Paint()
          ..color = Colors.white.withOpacity(0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    final topColor = locked ? const Color(0xFFC3C9D4) : Colors.white;
    final bottomColor = locked ? const Color(0xFF808A9C) : accent;
    final gradient = Paint()
      ..shader = Gradient.radial(
        Offset(size.x * 0.35, size.y * 0.32),
        size.x * 0.75,
        [topColor, bottomColor],
      );
    canvas.drawOval(rect, gradient);

    // A short rim-light arc fakes a glassy/3D pod highlight along the
    // island's upper edge.
    canvas.drawArc(
      rect.deflate(3),
      math.pi * 1.05,
      math.pi * 0.6,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacity(locked ? 0.25 : 0.55),
    );

    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 4.5 : 3
        ..color = selected
            ? const Color(0xFFFFE08A)
            : Colors.white.withOpacity(locked ? 0.5 : 0.9),
    );

    if (!locked) {
      // Backing for the stage-number badge (top-left) so light digits stay
      // legible against any accent color.
      canvas.drawCircle(const Offset(15, 15), 13, Paint()..color = Colors.black.withOpacity(0.28));
    }

    if (selected) {
      final checkPaint = Paint()
        ..color = const Color(0xFFFFE08A)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(size.x - 12, 12), 12, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(size.x - 12, 12), 12, checkPaint..style = PaintingStyle.stroke..strokeWidth = 2);
      final path = Path()
        ..moveTo(size.x - 17, 12)
        ..lineTo(size.x - 13, 16)
        ..lineTo(size.x - 7, 8);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF16A085)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    super.render(canvas);
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (locked) {
      // A gentle "not yet" shake — never reports a selection.
      add(
        SequenceEffect([
          MoveEffect.by(Vector2(6, 0), EffectController(duration: 0.05)),
          MoveEffect.by(Vector2(-12, 0), EffectController(duration: 0.05)),
          MoveEffect.by(Vector2(12, 0), EffectController(duration: 0.05)),
          MoveEffect.by(Vector2(-6, 0), EffectController(duration: 0.05)),
        ]),
      );
      return;
    }
    add(
      SequenceEffect([
        ScaleEffect.to(Vector2.all(1.22), EffectController(duration: 0.11)),
        ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.2)),
      ]),
    );
    onSelected?.call();
  }
}
