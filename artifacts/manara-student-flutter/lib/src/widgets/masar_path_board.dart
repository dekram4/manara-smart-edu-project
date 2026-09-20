import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import 'student_avatar_view.dart';
import '../services/student_avatar_store.dart';

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

// The six boards in the artwork, in reading order: three across the top,
// three across the bottom. The five levels fill the first five.
//
// The sixth is painted into the background and cannot be removed from it,
// and left bare it read as a sixth field the child was expected to fill —
// one that never filled, because the level it once held («الترم») is gone
// from the whole system. So it carries a plaque instead: how many of the
// five are chosen. It answers rather than asks, and nothing about it
// invites a tap.
const _Frac _tileGrade = Rect.fromLTRB(0.4045, 0.2961, 0.5167, 0.4453);
const _Frac _tileSubject = Rect.fromLTRB(0.6011, 0.2961, 0.7111, 0.4453);
const _Frac _tileTerm = Rect.fromLTRB(0.7939, 0.2961, 0.9039, 0.4453);
const _Frac _tileUnit = Rect.fromLTRB(0.4045, 0.5945, 0.5167, 0.7437);
const _Frac _tileLesson = Rect.fromLTRB(0.6011, 0.5945, 0.7111, 0.7429);
const _Frac _tileSpare = Rect.fromLTRB(0.7961, 0.5945, 0.9039, 0.7429);

const List<_Frac> _tiles = [
  _tileGrade,
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

/// Where the two cheering characters stand: side by side in front of the tree
/// that hides the painted children.
///
/// Both stop at x 0.326, short of the schoolhouse. The pale wall begins at
/// 0.330 and the window frame at 0.343, and the right-hand figure used to run
/// to 0.356 — standing on the glazing. Their feet sit at y 0.870, just above
/// the speaker and the progress bar painted across the foot at 0.872.
const List<_Frac> _cheerSpots = [
  Rect.fromLTRB(0.036, 0.545, 0.176, 0.870),
  Rect.fromLTRB(0.186, 0.545, 0.326, 0.870),
];

/// The same two characters on an upright screen, 30% larger.
///
/// The painting is stretched to fill the screen, so on a tall window it is
/// squeezed sideways, and a figure fitted into its box is limited by the box's
/// *width* — 14% of a narrow screen. That left two small figures at the foot
/// of a tall stretch of sky. The height was never the constraint, so growing
/// them means widening their boxes: 0.182 wide instead of 0.140.
///
/// Two boxes that wide do not fit side by side between the screen's left edge
/// and the schoolhouse wall at 0.330, so they overlap by 0.040 — one child
/// standing slightly in front of the other, which is how two friends pose
/// anyway. The speaker on the right is drawn second, so it is the one in
/// front, under its bubble.
///
/// Their feet stay exactly where they were, at 0.870, so the extra size goes
/// upwards and outwards — clear of the start button across the foot and of
/// the reward badge below. The right edge stops at 0.328, short of the wall.
const List<_Frac> _cheerSpotsPortrait = [
  Rect.fromLTRB(0.004, 0.545, 0.186, 0.870),
  Rect.fromLTRB(0.146, 0.545, 0.328, 0.870),
];

/// Which layout of the two characters a scene of [size] uses.
List<_Frac> _cheerSpotsFor(Size size) =>
    size.height > size.width ? _cheerSpotsPortrait : _cheerSpots;

/// The speech bubble, sitting just above the right-hand character's head.
///
/// Anchored to a figure rather than pinned to a corner of the screen: the line
/// is an instruction to the student, and coming out of a character's mouth is
/// what makes an instruction feel like encouragement instead of a label. Its
/// tail points down at that character's head, so which of the two is speaking
/// is never in doubt.
///
/// Its top sits at 0.452, immediately under the "تحدَّ واكسب!" plaque, which
/// ends at 0.4499 — the bubble used to start at 0.372 and cover it. This is
/// only the designed slot: where the bubble finally sits is worked out against
/// the speaker's head by [_bubbleRect].
const _Frac _speechBubble = Rect.fromLTRB(0.028, 0.452, 0.330, 0.560);

/// How far the bubble is lifted above where it would sit lapped over the head,
/// in logical pixels.
///
/// Pixels rather than a fraction of the scene, because what it buys is
/// breathing room a person sees — about the same on a phone as on a tablet.
/// 18px moves the tail's tip from inside the hair to the top of the head, and
/// leaves the bubble's body about 20px clear of it.
const double _bubbleHeadroom = 18;

/// The patch that hides the two children painted into the artwork.
///
/// Their extent was measured off the image: they run from x 0.045 to 0.325 and
/// from the tops of their heads at y 0.425 down to their shoes at 0.855.
///
/// The right edge stops at 0.328 — past the children, short of the pale wall
/// at 0.330. It reached 0.378 before, which put foliage across the wall and
/// the window of the "الفصل" square. The hanging sign above overlaps the top of
/// this patch, but that one is drawn after it and covers it.
///
/// It replaces them with scenery rather than a rectangle of flat colour,
/// because the ground behind them is not one colour: sky at the top, a white
/// fence across the middle, grass at the foot. A shrub and a tree occupy all
/// three bands the way something growing there would, and read as part of the
/// painting rather than as something laid over it.
const _Frac _childrenPatch = Rect.fromLTRB(0.022, 0.395, 0.328, 0.872);

/// Which of the "my character" cards cheer from the path.
///
/// Drawn from the same set the student picks their own avatar from, so the
/// figures on the map belong to the app rather than being a second, unrelated
/// cast. Two fixed picks rather than random ones: the scene should look the
/// same every time a child opens it.
///
/// Held as ids, not indices. The character list is append-only precisely
/// because the student's own pick is stored by id, and an index here would
/// silently point at a different figure the first time that list is reordered.
const List<String> _cheerAvatarIds = ['h2', 'h4'];

/// Each cheering character's height over its width, as the image is drawn.
///
/// Needed because the figure is fitted into its box and anchored at the feet,
/// so on a narrow window it is far shorter than the box that holds it — and
/// anything positioned against the *box* ends up floating over empty air. That
/// is what left a wide gap between the speech bubble and the characters in
/// portrait: the bubble was above the box, and the box was mostly sky.
///
/// Read off the trimmed assets: hero1 is 640x978 and hero3 640x785.
const Map<String, double> _cheerAspect = {'h2': 978 / 640, 'h4': 785 / 640};

/// Where the bubble actually goes, given the slot it was designed in and the
/// box the speaking character stands in.
///
/// The figure is fitted to its box and stands at the bottom of it, so on a
/// narrow window it fills only part of that height — the rest is empty. Sitting
/// the bubble on the *box* therefore leaves it floating well above the head it
/// belongs to, which is the gap that showed up in portrait and not in
/// landscape. This works out where the head really is and places the bubble
/// just above it: the tail reaches down to the head, the body stays clear.
///
/// The result is clamped so the bubble can never rise into the hanging sign
/// above it, whatever the window shape.
Rect _bubbleRect(Rect designed, Rect speaker) {
  final aspect = _cheerAspect[_cheerAvatarIds[1]] ?? 1.5;
  final figureHeight = math.min(speaker.height, speaker.width * aspect);
  final headTop = speaker.bottom - figureHeight;

  // Seated a little into the head, then lifted clear of it by
  // [_bubbleHeadroom]. Seated alone, the tail's tip sank into the hair and
  // the bubble's body sat right on the characters' heads — crowded rather
  // than connected. Lifted, the tail's tip still reaches the head, so which
  // of the two is speaking stays obvious, and the body clears it by about
  // 20px.
  var bottom = headTop + designed.height * 0.18 - _bubbleHeadroom;
  var top = bottom - designed.height;
  if (top < designed.top) {
    top = designed.top;
    bottom = top + designed.height;
  }
  return Rect.fromLTRB(designed.left, top, designed.right, bottom);
}

/// The scene's layout, opened up for the test that guards it.
///
/// These fractions have now drifted three separate times — foliage onto the
/// schoolhouse wall, a figure standing on the window glass, the bubble over the
/// "تحدَّ واكسب!" plaque — and each time it was caught by measuring the render by
/// hand rather than by anything that would fail on its own. The separations
/// they have to keep are arithmetic between constants in this file, so the test
/// needs the constants; nothing here is for the app to use.
@visibleForTesting
class MasarPathLayout {
  const MasarPathLayout._();

  /// Where the schoolhouse's pale wall starts, and its window frame after it.
  /// Everything on the left of the scene has to stop before these.
  static const double wallLeft = 0.330;
  static const double windowLeft = 0.343;

  /// The lowest hanging sign — the one the bubble used to cover.
  static Rect get lowestSign => _signs.last;

  /// Both layouts of the two characters, landscape first.
  static List<List<Rect>> get cheerSpotLayouts =>
      [_cheerSpots, _cheerSpotsPortrait];

  static List<Rect> cheerSpotsFor(Size size) => _cheerSpotsFor(size);
  static Rect get childrenPatch => _childrenPatch;
  static Rect get speechBubble => _speechBubble;

  /// The share of the bubble's height its tail takes, below the body. The
  /// bubble draws its tail from this, so the test measures the same body.
  static const double tailShare = 0.22;

  /// The bubble's real position for a scene of [size] — the same computation
  /// the widget does, which is the point: the gap this closes only appears once
  /// the figure has been fitted into its box.
  static Rect bubbleFor(Size size) {
    Rect place(Rect f) => Rect.fromLTRB(
          f.left * size.width,
          f.top * size.height,
          f.right * size.width,
          f.bottom * size.height,
        );
    return _bubbleRect(place(_speechBubble), place(_cheerSpotsFor(size)[1]));
  }

  /// The speaking character's box for a scene of [size].
  static Rect speakerFor(Size size) {
    final spot = _cheerSpotsFor(size)[1];
    return Rect.fromLTRB(
      spot.left * size.width,
      spot.top * size.height,
      spot.right * size.width,
      spot.bottom * size.height,
    );
  }

  /// Where the speaking figure's head actually starts for a scene of [size] —
  /// not where its box starts. On a narrow window the figure fills only part of
  /// its box, and the difference is the gap this all exists to close.
  static double headTopFor(Size size) {
    final box = speakerFor(size);
    final aspect = _cheerAspect[_cheerAvatarIds[1]] ?? 1.5;
    return box.bottom - math.min(box.height, box.width * aspect);
  }
}

/// The character for one of those ids, or null if it has been removed.
StudentAvatar? _cheerAvatar(String id) {
  for (final avatar in StudentAvatars.all) {
    if (avatar.id == id) return avatar;
  }
  return null;
}

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
        final cheerSpots = _cheerSpotsFor(area.size);
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

                // The two painted children, hidden behind a tree and a shrub.
                // Drawn before everything else on top of the artwork so the
                // patches, the fields and the cheering figures all sit over
                // it rather than behind it.
                Positioned.fromRect(
                  rect: place(_childrenPatch),
                  child: const IgnorePointer(
                    child: CustomPaint(painter: _SceneryPatchPainter()),
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
                for (var i = 0; i < cheerSpots.length; i++)
                  Positioned.fromRect(
                    rect: place(cheerSpots[i]),
                    child: _CheeringMascot(
                      avatarId: _cheerAvatarIds[i % _cheerAvatarIds.length],
                      // Half a cycle apart, so they bounce alternately the way
                      // two children egging each other on would, rather than
                      // in lockstep like a pair of metronomes.
                      pulse: (_pulse.value + i * 0.5) % 1.0,
                    ),
                  ),

                // What the character is saying. Drawn after the figures so the
                // bubble sits in front of whoever is speaking.
                Positioned.fromRect(
                  rect: _bubbleRect(place(_speechBubble), place(cheerSpots[1])),
                  child: IgnorePointer(
                    child: _SpeechBubble(
                      text: tr('path.chooseTitle'),
                      // Breathes with the same clock as the waypoints, half a
                      // cycle out, so the bubble lifts as the character lands.
                      pulse: (_pulse.value + 0.5) % 1.0,
                    ),
                  ),
                ),

                // The blank scroll over the schoolhouse, now the school's name.
                Positioned.fromRect(
                  rect: place(_scroll),
                  child: _SchoolBanner(text: tr('path.schoolName')),
                ),

                Positioned.fromRect(
                  rect: place(_tileSpare),
                  child: IgnorePointer(
                    child: _ProgressPlaque(
                      done: widget.stages
                          .where((stage) => (stage.value ?? '').isNotEmpty)
                          .length,
                      total: widget.stages.length,
                    ),
                  ),
                ),

                for (var i = 0;
                    i < widget.stages.length && i < _tiles.length;
                    i++)
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

/// لوحة صغيرة على اللوح السادس: كم مستوى اختاره الطفل من خمسة.
///
/// تملأ لوحاً كان فارغاً يُقرأ حقلاً منتظِراً. وهي عدّ لا زينة: تتحرّك مع
/// كل اختيار، فيرى الطفل مساره يقصر أمامه.
class _ProgressPlaque extends StatelessWidget {
  const _ProgressPlaque({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final unit = (box.maxHeight * 0.20).clamp(9.0, 22.0).toDouble();
        // يتقلّص ليسع اللوح مهما صغر: اللوح جزء من صورة خلفية تتغيّر
        // نسبتها مع كل مقاس شاشة، فالحجم المحسوب وحده لا يضمن الاتّساع.
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: unit * 0.55,
                vertical: unit * 0.35,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(unit),
                border: Border.all(color: const Color(0xFFFFB703), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('⭐', style: TextStyle(fontSize: unit * 1.25)),
                  SizedBox(height: unit * 0.18),
                  Text(
                    '$done / $total',
                    style: TextStyle(
                      color: const Color(0xFF92400E),
                      fontSize: unit,
                      fontWeight: FontWeight.w900,
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
              BoxShadow(
                  color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
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
                Shadow(
                    color: Colors.black38, blurRadius: 3, offset: Offset(0, 2)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A tree and a flowering shrub, painted over the two children in the artwork.
///
/// Everything is drawn in fractions of the box it is given, so the scenery
/// scales with the picture and keeps covering what it was measured to cover.
/// The greens are sampled from the artwork's own grass and foliage rather than
/// chosen, which is what stops the patch reading as a sticker.
class _SceneryPatchPainter extends CustomPainter {
  const _SceneryPatchPainter();

  // Sampled from the scene: its grass, its hedge, and the shade between them.
  static const _grass = Color(0xFF92CB0A);
  static const _grassLit = Color(0xFFAFDB11);
  static const _leaf = Color(0xFF4E9A2F);
  static const _leafDark = Color(0xFF357A22);
  static const _leafLit = Color(0xFF6FBF45);
  static const _trunk = Color(0xFF8A5A2B);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..isAntiAlias = true;

    // Every lobe is an oval in the box's own coordinates: its horizontal
    // radius is a fraction of the width and its vertical radius a fraction of
    // the height.
    //
    // They used to be circles with a radius taken from the width alone, which
    // is why the children reappeared on a tablet held upright. The artwork is
    // stretched to fill the screen, so this box is as tall as the screen makes
    // it: 365x366 on a landscape tablet but 273x488 on a portrait one. A
    // circle sized off the width covered half the box's height in the first
    // case and barely a quarter in the second, and the heads showed over the
    // top of the tree. Sized per axis, the foliage covers the same share of
    // the box in every shape.
    void lobe(double cx, double cy, double rx, double ry, Color colour) {
      paint.color = colour;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * cx, h * cy),
          width: rx * w * 2,
          height: ry * h * 2,
        ),
        paint,
      );
    }

    // Two trunks, drawn first so both canopies and the shrub close over them.
    paint.color = _trunk;
    for (final cx in const [0.26, 0.70]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * (cx - 0.038), h * 0.36, w * 0.076, h * 0.52),
          Radius.circular(w * 0.036),
        ),
        paint,
      );
    }

    // Two canopies rather than one.
    //
    // A single tree in the middle left both children showing at the edges —
    // the first preview of this patch had the painted girl standing clear of
    // it on the right. The box is nearly a third of the artwork wide; it needs
    // foliage at both ends, not one shape in the centre.
    for (final cx in const [0.26, 0.70]) {
      lobe(cx, 0.19, 0.25, 0.23, _leafDark);
      lobe(cx - 0.13, 0.26, 0.21, 0.20, _leafDark);
      lobe(cx + 0.13, 0.27, 0.20, 0.19, _leafDark);
      lobe(cx - 0.02, 0.16, 0.215, 0.20, _leaf);
      lobe(cx - 0.12, 0.24, 0.175, 0.165, _leaf);
      lobe(cx + 0.12, 0.25, 0.165, 0.155, _leaf);
      // A highlight up and to the left, matching where the scene's sun is.
      lobe(cx - 0.07, 0.12, 0.105, 0.10, _leafLit);
    }

    // The shrub across the foot, covering the fence and both sets of legs.
    //
    // It runs past each edge of the box, and its crown is set high enough to
    // overlap the underside of the canopies: the canopies reach down to 0.46
    // of the box and the shrub's dark lobes start at 0.42, so the two meet.
    // Before that they left a band open between them, and an early preview
    // had a pink hair-bow and a shoulder showing through it.
    for (var i = 0; i < 6; i++) {
      final cx = -0.04 + i * 0.216;
      lobe(cx, 0.66 + (i.isEven ? 0.0 : 0.035), 0.235, 0.24, _leafDark);
    }
    for (var i = 0; i < 6; i++) {
      final cx = -0.02 + i * 0.216;
      lobe(cx, 0.635 + (i.isEven ? 0.0 : 0.03), 0.195, 0.20, _leaf);
    }
    lobe(0.18, 0.595, 0.085, 0.085, _leafLit);
    lobe(0.52, 0.605, 0.078, 0.078, _leafLit);
    lobe(0.82, 0.598, 0.072, 0.072, _leafLit);

    // Grass along the base, so the shrub is planted rather than floating.
    paint.color = _grass;
    canvas.drawOval(
      Rect.fromLTWH(-w * 0.04, h * 0.86, w * 1.08, h * 0.22),
      paint,
    );
    paint.color = _grassLit;
    canvas.drawOval(
      Rect.fromLTWH(w * 0.06, h * 0.875, w * 0.62, h * 0.10),
      paint,
    );

    // A handful of flowers, placed rather than random so the scene is the
    // same every time it is drawn.
    const flowers = <Offset>[
      Offset(0.22, 0.735),
      Offset(0.37, 0.695),
      Offset(0.52, 0.745),
      Offset(0.64, 0.705),
      Offset(0.30, 0.785),
    ];
    const petals = <Color>[
      Color(0xFFFFD34E),
      Color(0xFFFF7BA9),
      Color(0xFFFFFFFF),
      Color(0xFFFFD34E),
      Color(0xFFFF7BA9),
    ];
    for (var i = 0; i < flowers.length; i++) {
      lobe(flowers[i].dx, flowers[i].dy, 0.026, 0.026, petals[i]);
      lobe(flowers[i].dx, flowers[i].dy, 0.010, 0.010, const Color(0xFFFFB300));
    }
  }

  @override
  bool shouldRepaint(covariant _SceneryPatchPainter oldDelegate) => false;
}

/// A comic speech bubble with a tail pointing down at the character below it.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text, required this.pulse});

  final String text;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        // Sized from the box's own height so the line stays in proportion to
        // the bubble at every screen shape, the way the fields in the squares
        // are sized.
        final fontSize = (h * 0.30).clamp(11.0, 26.0).toDouble();
        // A small lift, in step with the character's bounce.
        final lift = math.sin(pulse * math.pi * 2) * h * 0.035;
        // The tail's share of the height, left free below the body.
        final tailHeight = h * MasarPathLayout.tailShare;

        return Transform.translate(
          offset: Offset(0, -lift),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: w,
                  padding: EdgeInsets.symmetric(
                    horizontal: w * 0.07,
                    vertical: h * 0.06,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(h * 0.30),
                    border: Border.all(
                      color: const Color(0xFF0E7490),
                      width: math.max(2, h * 0.035),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FittedBox(
                    // The one place a FittedBox is right: a bubble is drawn to
                    // fit its words, and there is no layout test guarding a
                    // point size here — unlike the answers in the squares,
                    // where scaling the type was the regression.
                    fit: BoxFit.scaleDown,
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0B3F52),
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: tailHeight,
                width: w,
                child: CustomPaint(
                  painter: _BubbleTailPainter(
                    border: const Color(0xFF0E7490),
                    borderWidth: math.max(2, h * 0.035),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The little pointer under the bubble, aimed at the character's head.
class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter({required this.border, required this.borderWidth});

  final Color border;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    // Placed right of centre, over the character the bubble belongs to.
    final tipX = size.width * 0.72;
    final path = Path()
      ..moveTo(size.width * 0.58, -borderWidth)
      ..lineTo(size.width * 0.80, -borderWidth)
      ..lineTo(tipX, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..strokeJoin = StrokeJoin.round,
    );
    // Paint over the join with the bubble so the shared edge does not show
    // as a line across the mouth of the tail.
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.58 + borderWidth * 0.6,
        -borderWidth * 1.6,
        size.width * 0.22 - borderWidth * 1.2,
        borderWidth * 2,
      ),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter old) =>
      old.border != border || old.borderWidth != borderWidth;
}

/// One "my character" card bouncing on the spot, cheering the student on.
class _CheeringMascot extends StatelessWidget {
  const _CheeringMascot({required this.avatarId, required this.pulse});

  /// Id of a character in [StudentAvatars.all] — the same set the student
  /// chooses from.
  final String avatarId;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final asset = _cheerAvatar(avatarId)?.asset;
    if (asset == null) return const SizedBox.shrink();
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
            ..translateByDouble(0.0, -lift, 0.0, 1.0)
            ..scaleByDouble(
              1 + squash * 0.07,
              1 - squash * 0.07 + beat * 0.05,
              1 + squash * 0.07,
              1.0,
            ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Image.asset(
              asset,
              height: height,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              cacheWidth: _safeCacheWidth(
                box.maxWidth * MediaQuery.devicePixelRatioOf(context),
              ),
              // A missing character costs the scene nothing; the six squares
              // are what this screen is for.
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
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
              BoxShadow(
                  color: Colors.black26, blurRadius: 5, offset: Offset(0, 2)),
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
        final swell =
            active ? (math.sin(pulse * math.pi * 2) * 0.5 + 0.5) : 0.0;
        // Sized by whichever of the square's two dimensions runs out first.
        // Taking only the height made the type overflow sideways on a narrow
        // portrait window, where the squares are tall and thin.
        final valueSize = math
            .min(box.maxHeight * 0.20, box.maxWidth * 0.20)
            .clamp(11.0, 28.0)
            .toDouble();
        // The level's name is the square's heading, so it is the largest
        // type in it — a fifth larger than the answer below. It used to be two
        // thirds of the answer's size, medium weight and in the muted grey,
        // and read as a faint caption rather than as what the square is for.
        final labelSize = (valueSize * 1.2).clamp(13.0, 32.0).toDouble();
        final dark = StudentSurface.isDark(context);
        // Royal navy on the white plate; on the dark plate navy would vanish,
        // so the heading turns gold there instead. Either way it is the
        // strongest contrast the plate allows.
        final headingColor =
            dark ? const Color(0xFFFFD166) : const Color(0xFF0B2E7A);

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
                    // Two parts in five of the height to the heading, three
                    // to the answer. Equal shares — the default — let the
                    // larger heading take half the square and cut the second
                    // line of a two-line answer off.
                    flex: 2,
                    // The one line here allowed to scale: a heading is a
                    // single word, and on a narrow phone "Subject" at full
                    // size would be cut to "Subj…". The answer below keeps
                    // its size untouched, which is what the layout test
                    // guards.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            stage.label,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: labelSize,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              color: headingColor,
                              shadows: [
                                Shadow(
                                  color: dark
                                      ? Colors.black.withValues(alpha: 0.65)
                                      : Colors.white,
                                  blurRadius: 3,
                                ),
                                Shadow(
                                  color: headingColor.withValues(alpha: 0.35),
                                  offset: const Offset(0, 1.5),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          // A short bar in the level's own colour under the
                          // name, the way a heading is underlined: it marks
                          // the line as the title of the square.
                          Container(
                            margin: EdgeInsets.only(top: labelSize * 0.12),
                            width: labelSize * 1.6,
                            height: math.max(2.0, labelSize * 0.12),
                            decoration: BoxDecoration(
                              color: stage.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    flex: 3,
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
