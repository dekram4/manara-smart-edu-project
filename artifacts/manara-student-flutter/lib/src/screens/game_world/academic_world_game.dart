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
/// floating "island" the student taps.
class WorldStation {
  const WorldStation({required this.id, required this.label});

  final String id;
  final String label;
}

/// The interactive game world behind [AcademicSelectionScreen]'s stage
/// picker: a breathing sky, a few drifting clouds, and — for whichever step
/// is currently active — a set of floating island stations the student taps
/// to advance. Flutter (not Flame) owns the actual selection state; this
/// game only ever reports "the student tapped station X" through
/// [onStationSelected] and shows whatever station list it's told to via
/// [showStations].
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

  /// Current step's theme color, driving both the sky and the islands.
  final ValueNotifier<Color> accent = ValueNotifier(const Color(0xFF4F46E5));

  double _breatheTime = 0;
  List<WorldStation> _pendingStations = const [];

  @override
  Color backgroundColor() => const Color(0xFF0B1B3A);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // World (0,0) == the top-left pixel of the GameWidget, with no
    // zoom/pan — the simplest possible mapping, and the one the Flutter
    // avatar overlay relies on to place itself directly from an island's
    // `position` with no coordinate conversion.
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    world.add(_CloudBlob(startX: 0.15, y: 70, radius: 46, speed: 9));
    world.add(_CloudBlob(startX: 0.72, y: 130, radius: 34, speed: -6));
    world.add(_CloudBlob(startX: 0.42, y: 40, radius: 26, speed: 5));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _breatheTime += dt;
  }

  @override
  void render(Canvas canvas) {
    if (!hasLayout) return;
    // A slow "breathing" sky wash behind everything else, before the
    // component tree (clouds + islands) paints on top of it.
    final breathe = (math.sin(_breatheTime * 0.5) + 1) / 2; // 0..1
    final top = Color.lerp(
      const Color(0xFF0B1B3A),
      accent.value.withOpacity(0.55),
      0.25 + breathe * 0.15,
    )!;
    const bottom = Color(0xFF13284F);
    final paint = Paint()
      ..shader = Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.y),
        [top, bottom],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
    super.render(canvas);
  }

  /// Clears whatever islands are currently shown and lays out a new set for
  /// [stations], themed with [stepAccent]. Called by the screen every time
  /// the active step changes (including going back a step) — this can
  /// happen before the GameWidget has ever been laid out (the very first
  /// call arrives from an async data fetch that may resolve before Flutter
  /// has even built the widget once), so it must never touch `size`
  /// directly; see [_applyPendingStations].
  void showStations(List<WorldStation> stations, {required Color stepAccent}) {
    accent.value = stepAccent;
    _pendingStations = stations;
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
    if (_pendingStations.isEmpty || size.x <= 0) return;
    const islandDiameter = 84.0;
    const cellWidth = 116.0;
    const cellHeight = 138.0;
    final columns = ((size.x - 24) / cellWidth).floor().clamp(2, 4);
    final rowWidth = columns * cellWidth;
    final startX = (size.x - rowWidth) / 2 + cellWidth / 2;
    const startY = 96.0;

    for (var i = 0; i < _pendingStations.length; i++) {
      final row = i ~/ columns;
      final column = i % columns;
      final baseX = startX + column * cellWidth;
      final baseY = startY + row * cellHeight;
      final island = _IslandComponent(
        station: _pendingStations[i],
        accent: accent.value,
        baseY: baseY,
        phase: i * 0.7,
        onSelected: () {
          avatarTarget.value = Vector2(baseX, baseY);
          onStationSelected(_pendingStations[i].id);
        },
      )
        ..position = Vector2(baseX, baseY)
        ..size = Vector2.all(islandDiameter)
        ..anchor = Anchor.center;
      world.add(island);
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
           ..color = const Color(0x33FFFFFF)
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

/// One floating, tappable station. Bobs continuously on a sine wave and
/// gives a short scale-bounce when tapped, then reports the tap upward via
/// [onSelected].
class _IslandComponent extends PositionComponent with TapCallbacks {
  _IslandComponent({
    required this.station,
    required this.accent,
    required double baseY,
    required double phase,
    required this.onSelected,
  }) : _baseY = baseY,
       _phase = phase;

  final WorldStation station;
  final Color accent;
  final double _baseY;
  final double _phase;
  final VoidCallback onSelected;

  double _time = 0;
  late final TextComponent _label;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final shortLabel = station.label.length > 14
        ? '${station.label.substring(0, 13)}…'
        : station.label;
    _label = TextComponent(
      text: shortLabel,
      anchor: Anchor.topCenter,
      position: Vector2(size.x / 2, size.y + 6),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
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
        ..strokeWidth = 3
        ..color = Colors.white.withOpacity(0.9),
    );
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
