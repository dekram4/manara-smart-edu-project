import 'dart:math' as math;
// dart:ui's TextStyle would otherwise collide with the Flutter TextStyle
// that TextPaint (below) actually expects.
import 'dart:ui' hide TextStyle;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier, VoidCallback;
import 'package:flutter/material.dart' show Colors, TextStyle;

/// One selectable option in the current step of the academic path (a grade,
/// a term, a subject, a chapter, a unit, or a lesson) — rendered as a
/// station on the road-map the student taps.
class WorldStation {
  const WorldStation({required this.id, required this.label});

  final String id;
  final String label;
}

/// The interactive game world behind [AcademicSelectionScreen]'s stage
/// picker: a bright, cheerful breathing sky, a few drifting clouds, and —
/// for whichever step is currently active — that step's options laid out
/// as stations along a winding, glowing dotted road, the way an
/// adventure/level map lays out its stages. Flutter (not Flame) owns the
/// actual selection state; this game only ever reports "the student tapped
/// station X" through [onStationSelected] and shows whatever station list
/// it's told to via [showStations].
class AcademicWorldGame extends FlameGame {
  AcademicWorldGame({required this.onStationSelected});

  /// Called with the tapped station's id. The screen is responsible for
  /// applying that to the real selection state and then calling
  /// [showStations] again for the next step.
  final void Function(String stationId) onStationSelected;

  /// World-space (== screen-space, see [onLoad]) position of the most
  /// recently tapped island, so the Flutter-side avatar overlay can travel
  /// there. Null until the first tap.
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

    world.add(_CloudBlob(startX: 0.12, y: 90, radius: 50, speed: 9));
    world.add(_CloudBlob(startX: 0.75, y: 160, radius: 38, speed: -6));
    world.add(_CloudBlob(startX: 0.4, y: 50, radius: 28, speed: 5));
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
  /// everything) but over the sky wash.
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
    final count = _pendingStations.length;
    final usableHeight = math.max(size.y - topMargin - bottomMargin, 0.0);
    final verticalSpacing = count > 1 ? usableHeight / (count - 1) : 0.0;
    final centerX = size.x / 2;
    // How far the road winds side to side — generous on a wide screen,
    // clamped so it never pushes a station off a narrow one.
    final amplitude = math.min(size.x * 0.28, size.x / 2 - stationDiameter);

    // Where the traveling guide (the Flutter-side avatar overlay) should
    // sit for this layout — the already-picked station, if any, so the
    // guide is visible "standing" at the student's current spot on the
    // path from the moment it loads, not only after their first tap.
    Vector2? selectedPosition;

    for (var i = 0; i < count; i++) {
      final y = count > 1
          ? topMargin + i * verticalSpacing
          : topMargin + usableHeight / 2;
      final x = centerX + math.sin(i * 0.9) * amplitude;
      final position = Vector2(x, y);
      _stationPositions.add(position);

      final station = _pendingStations[i];
      if (station.id == _pendingSelectedId) {
        selectedPosition = position.clone();
      }
      final island = _IslandComponent(
        station: station,
        accent: accent.value,
        baseY: y,
        phase: i * 0.7,
        selected: station.id == _pendingSelectedId,
        onSelected: () {
          avatarTarget.value = position.clone();
          onStationSelected(station.id);
        },
      )
        ..position = position.clone()
        ..size = Vector2.all(stationDiameter)
        ..anchor = Anchor.center;
      world.add(island);
    }

    if (selectedPosition != null) {
      avatarTarget.value = selectedPosition;
    }
  }
}

/// A soft drifting cloud — a blurred translucent circle that wraps around
/// horizontally once it drifts off either edge of the screen.
class _CloudBlob extends CircleComponent {
  _CloudBlob({
    required double startX,
    required double y,
    required double radius,
    required this.speed,
  }) : _startXFraction = startX,
       super(
         radius: radius,
         anchor: Anchor.center,
         paint: Paint()
           ..color = const Color(0x40FFFFFF)
           ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
       ) {
    position.y = y;
  }

  final double _startXFraction;
  final double speed;
  bool _initialized = false;

  @override
  void update(double dt) {
    super.update(dt);
    final game = findGame();
    if (game == null || !game.hasLayout) return;
    final gameSize = game.size;
    if (gameSize.x <= 0) return;
    if (!_initialized) {
      position.x = gameSize.x * _startXFraction;
      _initialized = true;
    }
    position.x += speed * dt;
    if (position.x < -radius) position.x = gameSize.x + radius;
    if (position.x > gameSize.x + radius) position.x = -radius;
  }
}

/// One station on the road-map. Bobs continuously on a sine wave and gives
/// a short scale-bounce when tapped, then reports the tap upward via
/// [onSelected]. A [selected] station (already picked for this step) gets
/// a bright checkmark ring instead of its number-free plain look.
class _IslandComponent extends PositionComponent with TapCallbacks {
  _IslandComponent({
    required this.station,
    required this.accent,
    required double baseY,
    required double phase,
    required this.onSelected,
    this.selected = false,
  }) : _baseY = baseY,
       _phase = phase;

  final WorldStation station;
  final Color accent;
  final bool selected;
  final double _baseY;
  final double _phase;
  final VoidCallback onSelected;

  double _time = 0;
  late final TextComponent _label;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final shortLabel = station.label.length > 16
        ? '${station.label.substring(0, 15)}…'
        : station.label;
    _label = TextComponent(
      text: shortLabel,
      anchor: Anchor.topCenter,
      position: Vector2(size.x / 2, size.y + 8),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(color: Color(0xE6000000), blurRadius: 6),
            Shadow(color: Color(0xFF000000), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
      ),
    );
    add(_label);
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
    final gradient = Paint()
      ..shader = Gradient.radial(
        Offset(size.x * 0.35, size.y * 0.32),
        size.x * 0.75,
        [Colors.white, accent],
      );
    canvas.drawOval(rect, gradient);
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 4.5 : 3
        ..color = selected ? const Color(0xFFFFE08A) : Colors.white.withOpacity(0.9),
    );
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
    add(
      SequenceEffect([
        ScaleEffect.to(Vector2.all(1.22), EffectController(duration: 0.11)),
        ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.2)),
      ]),
    );
    onSelected();
  }
}
