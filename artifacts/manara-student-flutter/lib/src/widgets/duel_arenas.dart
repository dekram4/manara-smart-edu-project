import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../services/student_duel_service.dart';
import '../theme/student_theme.dart';
import 'arena_widgets.dart';
import 'duel_game_scene.dart';

/// حلبةُ «تحدَّ زملاءك»: المشهدُ المتحرّكُ للّعبة، يتفاعل مع كل جواب، وتحته
/// لوحةُ اللاعبين بنقاطهم.
///
/// ── لماذا الشكلُ وحده هنا ──
/// الألعابُ الأربع مباراةٌ واحدة في جوهرها: الأسئلةُ نفسها ببذرةٍ واحدة،
/// وخمسةُ أشواط، ونتيجةٌ يحسمها الخادم. فالمحرّكُ واحدٌ في شاشة المباراة،
/// وهذه تُريه: لا تحسب شيئاً ولا تخترع نقطة.
///
/// ── والمشهدُ يجيب الجواب ──
/// كانت الحلبةُ رسوماً ثابتةً (مضمارٌ وشجرةٌ وحبلٌ وبرجٌ مرسومة) والمشهدُ
/// المتحرّكُ فوقها زينة. الآن المشهدُ هو الحلبة، ويتحرّك مع ما يجري:
///   • أصبتُ أوّلاً → [DuelBeat.success]: يقفز العدّاءُ الحاجز، يُشدّ الحبل،
///     تسقط الثمرةُ في السلّة، يوضع حجرٌ في الجدار.
///   • أخطأتُ → [DuelBeat.wrong]، أو سبقني زميلٌ بالصحيح → [DuelBeat.beaten]:
///     يتعثّر العدّاء، يرتخي الحبل، تسقط الثمرة، يهتزّ الجدار — والمشهدُ يقف
///     لحظةً باهتاً كمن تعثّر.
/// والحركةُ تقع مرّةً وتهدأ، وتُطفأ كلُّها مع «تقليل الحركة».

/// لاعبٌ في الحلبة.
class ArenaRacer {
  const ArenaRacer({
    required this.name,
    required this.at,
    this.appearance,
    this.me = false,
    this.badge,
  });

  final String name;

  /// ما أصاب من الأسئلة.
  final int at;
  final Map<String, dynamic>? appearance;
  final bool me;

  /// حالٌ تحت الاسم («يلعب الآن» مثلاً).
  final String? badge;
}

/// ما جرى لي في السؤال، كما يُرى في المشهد.
enum DuelBeat {
  /// أصبتُ أوّلاً فكسبتُ النقطة.
  success,

  /// اخترتُ خطأً.
  wrong,

  /// سبقني زميلٌ بالجواب الصحيح.
  beaten,
}

/// ما يُقرأ من تغيّر النتائج: نقطتي زادت → نجاح؛ اخترتُ خطأً في سؤالٍ جديد →
/// خطأ؛ زادت نقطةُ غيري ولم تزد نقطتي → سبقني.
///
/// والخادمُ يعطي السؤالَ لأوّل صحيحٍ وحده، فنقطةُ زميلٍ في سؤالٍ هي سبقٌ لي فيه.
DuelBeat? duelBeatOf({
  required int myBefore,
  required int myNow,
  required int othersBefore,
  required int othersNow,
  required int? missBefore,
  required int? missNow,
}) {
  if (myNow > myBefore) return DuelBeat.success;
  if (missNow != null && missNow != missBefore) return DuelBeat.wrong;
  if (othersNow > othersBefore) return DuelBeat.beaten;
  return null;
}

/// ألوانُ اللاعبين: أخضرُ لي، ولونٌ لكل زميل يكفي غرفةً كاملة.
const _mineTint = Color(0xFF16A34A);
const _rivalTints = [
  Color(0xFFDC2626),
  Color(0xFF2563EB),
  Color(0xFF9333EA),
  Color(0xFFEA580C),
  Color(0xFF0891B2),
  Color(0xFFDB2777),
];

Color _tintOf(List<ArenaRacer> racers, int index) {
  if (racers[index].me) return _mineTint;
  final rivals = [for (var i = 0; i < racers.length; i++) if (!racers[i].me) i];
  return _rivalTints[rivals.indexOf(index) % _rivalTints.length];
}

/// الفائزُ إن حُسمت المباراة وتقدّم واحدٌ وحده.
int? _winnerOf(List<ArenaRacer> racers, bool finished) {
  if (!finished || racers.isEmpty) return null;
  final best = racers.map((r) => r.at).reduce(math.max);
  final leaders = [for (var i = 0; i < racers.length; i++) if (racers[i].at == best) i];
  return leaders.length == 1 ? leaders.single : null;
}

class DuelArena extends StatefulWidget {
  const DuelArena({
    required this.game,
    required this.mine,
    required this.theirs,
    required this.total,
    required this.live,
    required this.myAppearance,
    required this.theirAppearance,
    required this.opponentName,
    this.finished = false,
    this.players,
    this.missAt,
    this.compact = false,
    super.key,
  });

  /// انتهت المباراة: اللوحةُ تُري الحسم — التاجُ لمن تقدّم.
  final bool finished;

  final DuelGame game;
  final int mine;
  final int theirs;
  final int total;
  final bool live;
  final Map<String, dynamic>? myAppearance;
  final Map<String, dynamic>? theirAppearance;
  final String opponentName;

  /// التحدي الجماعي: كلُّ اللاعبين بأرقامهم ١، ٢، ٣… وإن غاب فاللاعبان: أنا
  /// والمتقدّم من خصومي.
  final List<ArenaRacer>? players;

  /// السؤالُ الذي اخترتُ فيه خطأً (رقمُه)، أو `null`: يتعثّر المشهدُ حين يتغيّر.
  final int? missAt;

  /// الهاتفُ أثناء الأسئلة: مشهدٌ أقصر يُبقي الخياراتِ في الشاشة.
  final bool compact;

  @override
  State<DuelArena> createState() => _DuelArenaState();
}

class _DuelArenaState extends State<DuelArena> with SingleTickerProviderStateMixin {
  late final AnimationController _beat =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) setState(() => _kind = null);
        });

  /// الحركةُ الجارية، أو `null` والمشهدُ هادئ.
  DuelBeat? _kind;

  /// كم مرّةً تحرّك المشهد: يُعيد بناءَ طبقة الحركة من أوّلها.
  int _serial = 0;

  List<ArenaRacer> _racersOf(DuelArena w) =>
      w.players ??
      [
        ArenaRacer(name: tr('duel.you'), at: w.mine, appearance: w.myAppearance, me: true),
        ArenaRacer(
          name: w.opponentName.isEmpty ? tr('duel.rival') : w.opponentName,
          at: w.theirs,
          appearance: w.theirAppearance,
          badge: w.live ? tr('duel.liveNow') : null,
        ),
      ];

  static int _mineOf(List<ArenaRacer> racers) =>
      racers.where((r) => r.me).fold(0, (sum, r) => sum + r.at);
  static int _othersOf(List<ArenaRacer> racers) =>
      racers.where((r) => !r.me).fold(0, (sum, r) => sum + r.at);

  @override
  void didUpdateWidget(DuelArena old) {
    super.didUpdateWidget(old);
    if (widget.finished) return;
    final before = _racersOf(old);
    final now = _racersOf(widget);
    final beat = duelBeatOf(
      myBefore: _mineOf(before),
      myNow: _mineOf(now),
      othersBefore: _othersOf(before),
      othersNow: _othersOf(now),
      missBefore: old.missAt,
      missNow: widget.missAt,
    );
    if (beat == null) return;
    // ‏أخطأتُ ثم سبقني زميلٌ في السؤال نفسه: تعثّرٌ واحدٌ لا اثنان.
    if (beat == DuelBeat.beaten && _kind == DuelBeat.wrong && _beat.isAnimating) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    _kind = beat;
    _serial++;
    _beat.forward(from: 0);
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final racers = _racersOf(widget);
    final score = racers.fold<int>(0, (sum, racer) => sum + racer.at);
    final winner = _winnerOf(racers, widget.finished);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
        // ‏الهاتف: شريطٌ لا يُبعد السؤال. التابلت: مشهدٌ بنسبته يملأ عموده.
        final sceneHeight = width < 520
            ? (widget.compact ? 128.0 : (width * 9 / 16).clamp(150.0, 210.0))
            : (width * 9 / 16).clamp(170.0, 320.0);
        return DuelScenePulse(
          score: score,
          child: Card(
            key: const ValueKey('duel-arena'),
            color: StudentSurface.card(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedBuilder(
                    animation: _beat,
                    builder: (context, _) => _BeatScene(
                      game: widget.game,
                      players: racers.length,
                      height: sceneHeight,
                      kind: _kind,
                      serial: _serial,
                      t: _beat.value,
                      chips: Wrap(spacing: 6, runSpacing: 6, children: [
                        DuelSceneChip(text: widget.game.label),
                        DuelSceneChip(
                          text: trf('arena.scenePlayers', {'n': '${racers.length}'}),
                          color: const Color(0xCC9A3412),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _RacerBoard(racers: racers, total: widget.total, winner: winner),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// المشهدُ وحركتُه في لحظةٍ [t] من حركة [kind] (من ٠ إلى ١).
class _BeatScene extends StatelessWidget {
  const _BeatScene({
    required this.game,
    required this.players,
    required this.height,
    required this.kind,
    required this.serial,
    required this.t,
    required this.chips,
  });

  final DuelGame game;
  final int players;
  final double height;
  final DuelBeat? kind;
  final int serial;
  final double t;
  final Widget chips;

  bool get _up => kind == DuelBeat.success;
  bool get _down => kind == DuelBeat.wrong || kind == DuelBeat.beaten;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // ‏«نحوي»: جهةُ البداية — اليمينُ بالعربية.
    final toMe = rtl ? 1.0 : -1.0;
    final arc = math.sin(math.pi * t); // ٠ ← ١ ← ٠
    final fade = 1 - t;
    final shake = math.sin(t * math.pi * 6) * fade; // اهتزازٌ يخفت
    var dx = 0.0, dy = 0.0, turn = 0.0, scale = 1.0;
    if (kind != null) {
      switch ((game, _up)) {
        // ‏العدّاءُ يقفز الحاجز: المشهدُ يعلو بقوسٍ ثم يهبط.
        case (DuelGame.sprint, true):
          dy = -16 * arc;
          scale = 1 + 0.03 * arc;
        // ‏يتعثّر: يرتجّ أفقياً ويميل.
        case (DuelGame.sprint, false):
          dx = 9 * shake;
          turn = 0.025 * shake;
        // ‏الحبلُ يُشدّ نحوي، أو يرتخي ويُسحب بعيداً.
        case (DuelGame.tug, true):
          dx = 18 * arc * toMe;
        case (DuelGame.tug, false):
          dx = -18 * arc * toMe;
          turn = -0.012 * arc * toMe;
        // ‏السلّةُ تمتلئ: نبضةٌ خفيفة. والثمرةُ تسقط: ارتجاجٌ صغير.
        case (DuelGame.balloons, true):
          scale = 1 + 0.035 * arc;
        case (DuelGame.balloons, false):
          dx = 5 * shake;
        // ‏حجرٌ يُوضع: هبوطٌ قصيرٌ عند ارتطامه. والجدارُ يهتزّ عند التعثّر.
        case (DuelGame.gems, true):
          dy = t > 0.55 ? 6 * math.sin((t - 0.55) / 0.45 * math.pi) : 0;
        case (DuelGame.gems, false):
          turn = 0.03 * shake;
          dy = 2 * shake.abs();
      }
    }
    final stumbling = _down && t < 0.8;
    Widget scene = DuelGameScene(
      game: game,
      players: players,
      height: height,
      // ‏التعثّرُ يُوقف المشهدَ لحظة: العدّاءُ والحبلُ والسلّةُ والجدارُ كمن توقّف.
      paused: stumbling,
      overlay: Padding(
        padding: const EdgeInsets.all(8),
        child: Align(alignment: AlignmentDirectional.topStart, child: chips),
      ),
    );
    if (stumbling) {
      // ‏وباهتاً: لونٌ يخفت بقدر التعثّر.
      scene = ColorFiltered(
        colorFilter: ColorFilter.mode(Colors.grey.withValues(alpha: 0.45 * arc), BlendMode.saturation),
        child: scene,
      );
    }
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(dx, dy),
              child: Transform.rotate(
                angle: turn,
                alignment: Alignment.bottomCenter,
                child: Transform.scale(scale: scale, child: scene),
              ),
            ),
          ),
          if (kind != null)
            Positioned.fill(
              child: IgnorePointer(
                child: _BeatLayer(
                  key: ValueKey('duel-beat-${game.id}-${kind!.name}-$serial'),
                  game: game,
                  kind: kind!,
                  t: t,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ما يطير فوق المشهد مع الحركة: الحاجزُ والنجوم، الغبار، الثمار، الحجر —
/// وكلمةٌ تقول ما جرى.
class _BeatLayer extends StatelessWidget {
  const _BeatLayer({required this.game, required this.kind, required this.t, super.key});

  final DuelGame game;
  final DuelBeat kind;
  final double t;

  static String labelKey(DuelGame game, DuelBeat kind) {
    final up = kind == DuelBeat.success;
    return switch (game) {
      DuelGame.sprint => up ? 'arena.beat.sprintUp' : 'arena.beat.sprintDown',
      DuelGame.tug => up ? 'arena.beat.tugUp' : 'arena.beat.tugDown',
      DuelGame.balloons => up ? 'arena.beat.fruitUp' : 'arena.beat.fruitDown',
      DuelGame.gems => up ? 'arena.beat.wallUp' : 'arena.beat.wallDown',
    };
  }

  @override
  Widget build(BuildContext context) {
    final up = kind == DuelBeat.success;
    final appear = Curves.easeOutBack.transform((t / 0.25).clamp(0.0, 1.0));
    final leave = t > 0.8 ? (1 - (t - 0.8) / 0.2) : 1.0;
    final label = kind == DuelBeat.beaten ? '${tr(labelKey(game, kind))} · ${tr('arena.beat.beaten')}' : tr(labelKey(game, kind));
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final flying = <Widget>[];
        void emoji(String text, double x, double y, {double size = 26, double opacity = 1, double angle = 0}) {
          flying.add(Positioned(
            left: x - size / 2,
            top: y - size / 2,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.rotate(angle: angle, child: Text(text, style: TextStyle(fontSize: size))),
            ),
          ));
        }

        final fall = Curves.easeIn.transform(t.clamp(0.0, 1.0));
        switch ((game, up)) {
          case (DuelGame.sprint, true):
            // ‏حاجزٌ يمرّ تحت القفزة، ونجومٌ تتناثر.
            emoji('🚧', w * (0.75 - 0.5 * t), h * 0.78, size: 28, opacity: leave);
            for (var i = 0; i < 3; i++) {
              emoji('⭐', w * (0.35 + 0.15 * i), h * (0.45 - 0.3 * t) - 10 * i, size: 18, opacity: leave);
            }
          case (DuelGame.sprint, false):
            emoji('🚧', w * 0.5, h * 0.78, size: 30, angle: 0.9 * t, opacity: leave);
            emoji('💫', w * 0.5, h * 0.45, size: 26, angle: 6 * t, opacity: leave);
          case (DuelGame.tug, true):
            emoji('💪', w * 0.5, h * 0.55, size: 30, opacity: leave);
            emoji('💨', w * (0.5 - 0.3 * t), h * 0.8, size: 22, opacity: leave);
          case (DuelGame.tug, false):
            emoji('〰️', w * 0.5, h * 0.62, size: 30, opacity: leave);
            emoji('😣', w * 0.5, h * 0.4, size: 26, opacity: leave);
          case (DuelGame.balloons, true):
            // ‏ثلاثُ ثمارٍ تسقط في السلّة.
            const fruits = ['🍎', '🍊', '🍇'];
            for (var i = 0; i < 3; i++) {
              final start = 0.12 * i;
              final p = ((t - start) / 0.6).clamp(0.0, 1.0);
              emoji(fruits[i], w * (0.42 + 0.08 * i), h * (0.05 + 0.7 * Curves.easeIn.transform(p)), size: 24, opacity: p >= 1 ? leave : 1);
            }
            emoji('🧺', w * 0.5, h * 0.85, size: 32, opacity: leave);
          case (DuelGame.balloons, false):
            // ‏الثمرةُ تفلت وتتدحرج بعيداً وتختفي.
            emoji('🍎', w * (0.5 + 0.3 * fall), h * (0.2 + 0.6 * fall), size: 26, angle: 4 * t, opacity: 1 - fall);
            emoji('🍂', w * 0.45, h * 0.5, size: 22, opacity: leave);
          case (DuelGame.gems, true):
            // ‏حجرٌ يهبط إلى مكانه في الجدار.
            final drop = Curves.bounceOut.transform((t / 0.7).clamp(0.0, 1.0));
            emoji('🧱', w * 0.5, h * (0.0 + 0.72 * drop), size: 32, opacity: leave);
          case (DuelGame.gems, false):
            emoji('🧱', w * (0.5 + 0.12 * fall), h * (0.3 + 0.5 * fall), size: 28, angle: 1.4 * t, opacity: 1 - fall);
            emoji('⚠️', w * 0.5, h * 0.3, size: 24, opacity: leave);
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            ...flying,
            Align(
              alignment: const Alignment(0, 0.15),
              child: Opacity(
                opacity: leave.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.6 + 0.4 * appear,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: up ? const Color(0xE616A34A) : const Color(0xE6B91C1C),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 3))],
                    ),
                    child: Text(
                      label,
                      key: const ValueKey('duel-beat-label'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// لوحةُ اللاعبين تحت المشهد: رقمُ كلٍّ ولونُه واسمُه وما أصاب — والتاجُ للفائز.
class _RacerBoard extends StatelessWidget {
  const _RacerBoard({required this.racers, required this.total, required this.winner});

  final List<ArenaRacer> racers;
  final int total;
  final int? winner;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = racers.length <= 2 ? 2 : (width >= 520 ? 3 : 2);
        const gap = 8.0;
        final cell = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < racers.length; i++)
              SizedBox(
                width: cell,
                child: _RacerChip(
                  racer: racers[i],
                  lane: i + 1,
                  total: total,
                  tint: _tintOf(racers, i),
                  crowned: winner == i,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RacerChip extends StatelessWidget {
  const _RacerChip({
    required this.racer,
    required this.lane,
    required this.total,
    required this.tint,
    required this.crowned,
  });

  final ArenaRacer racer;
  final int lane;
  final int total;
  final Color tint;
  final bool crowned;

  @override
  Widget build(BuildContext context) {
    final pips = total > 0 && total <= 10;
    // ‏«تقليل الحركة»: النقاطُ تتبدّل في مكانها بلا حركة.
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    Duration motion(int ms) => still ? Duration.zero : Duration(milliseconds: ms);
    return AnimatedContainer(
      duration: motion(300),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: racer.me ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: racer.me ? 0.9 : 0.45), width: racer.me ? 2 : 1.2),
        boxShadow: [
          if (crowned) const BoxShadow(color: Color(0x88F59E0B), blurRadius: 14, spreadRadius: 1),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Text('$lane', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${crowned ? '👑 ' : ''}${racer.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: StudentSurface.ink(context)),
                ),
                if (pips)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        for (var p = 0; p < total; p++)
                          Flexible(
                            child: AnimatedContainer(
                              duration: motion(350),
                              curve: Curves.easeOutBack,
                              height: 6,
                              margin: const EdgeInsetsDirectional.only(end: 2),
                              decoration: BoxDecoration(
                                color: p < racer.at ? tint : tint.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (racer.badge != null)
                  Text(
                    racer.badge!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: StudentSurface.mutedInk(context)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          AnimatedSwitcher(
            duration: motion(250),
            transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
            child: Text(
              '${racer.at}/$total',
              key: ValueKey(racer.at),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: tint),
            ),
          ),
        ],
      ),
    );
  }
}

/// الخياراتُ بالشكل الذي تُلمس به في هذه اللعبة.
///
/// ── والجوابُ الصحيحُ لا يُكشف قبل وقته ──
/// من أخطأ مبكّراً يرى خطأه وحده، لا الصحيح: زميلُه ما زال يفكّر، والدردشةُ
/// مفتوحةٌ بينهما — وجوابٌ يُرى قبل الكشف يُرسل في رسالة. فالصحيحُ يظهر للاثنين
/// معاً حين يُحسم السؤال ([revealed]).
class DuelChoices extends StatelessWidget {
  const DuelChoices({
    required this.game,
    required this.options,
    required this.answerAt,
    required this.picked,
    required this.pickedCorrect,
    required this.revealed,
    required this.onPick,
    super.key,
  });

  final DuelGame game;
  final List<String> options;
  final int answerAt;
  final int? picked;

  /// ما قاله الخادمُ عن اختياري: `null` قبل أن يردّ.
  final bool? pickedCorrect;

  /// حُسم السؤال: يُرى الصحيح.
  final bool revealed;

  /// `null`: الخياراتُ مقفلة — اخترتُ، أو حُسم السؤال.
  final ValueChanged<int>? onPick;

  _ChoiceState _state(int index) =>
      _stateOf(index, picked, pickedCorrect, answerAt, revealed);

  AnswerTileState _tile(int index) {
    if (revealed) {
      if (index == answerAt) return AnswerTileState.correct;
      if (index == picked) return AnswerTileState.wrong;
      return AnswerTileState.dimmed;
    }
    if (picked == null) return AnswerTileState.idle;
    if (index == picked) {
      return pickedCorrect == false
          ? AnswerTileState.wrong
          : AnswerTileState.picked;
    }
    return AnswerTileState.dimmed;
  }

  @override
  Widget build(BuildContext context) {
    return switch (game) {
      DuelGame.balloons => _BalloonChoices(
          options: options,
          state: _state,
          picked: picked,
          onPick: onPick,
        ),
      DuelGame.gems => _GemChoices(
          options: options,
          state: _state,
          picked: picked,
          onPick: onPick,
        ),
      // سباقُ الحواجز ومغامرةُ الفضاء: بلاطاتٌ مجسّمةٌ على طراز Kahoot — لونٌ وشكلٌ لكل
      // موضع. والفرقُ بينهما في الحلبة لا في الخيار.
      DuelGame.sprint || DuelGame.tug => LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520 ? 2 : 1;
            const gap = 10.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var index = 0; index < options.length; index += 1)
                  SizedBox(
                    width: width,
                    child: AnswerTile(
                      index: index,
                      label: options[index],
                      state: _tile(index),
                      onPressed: onPick == null ? null : () => onPick!(index),
                    ),
                  ),
              ],
            );
          },
        ),
    };
  }
}

/// حالُ الخيار بعد الاختيار: صحيحٌ، أو خطأٌ اختِير، أو محايد.
enum _ChoiceState { idle, right, wrong }

_ChoiceState _stateOf(
  int index,
  int? picked,
  bool? pickedCorrect,
  int answerAt,
  bool revealed,
) {
  if (revealed) {
    if (index == answerAt) return _ChoiceState.right;
    if (index == picked) return _ChoiceState.wrong;
    return _ChoiceState.idle;
  }
  if (index != picked) return _ChoiceState.idle;
  return switch (pickedCorrect) {
    true => _ChoiceState.right,
    false => _ChoiceState.wrong,
    null => _ChoiceState.idle,
  };
}

({Color border, Color fill, Color ink}) _paint(
  _ChoiceState state,
  BuildContext context,
) =>
    switch (state) {
      _ChoiceState.right => (
          border: const Color(0xFF16A34A),
          fill: const Color(0xFFDCFCE7),
          ink: const Color(0xFF14532D),
        ),
      _ChoiceState.wrong => (
          border: const Color(0xFFDC2626),
          fill: const Color(0xFFFEE2E2),
          ink: const Color(0xFF7F1D1D),
        ),
      _ChoiceState.idle => (
          border: const Color(0xFF7C3AED).withValues(alpha: 0.30),
          fill: Colors.transparent,
          ink: StudentSurface.ink(context),
        ),
    };

/// ثمارُ البستان: الجوابُ في واحدةٍ منها، تُقطف فتسقط في السلّة.
class _BalloonChoices extends StatelessWidget {
  const _BalloonChoices({
    required this.options,
    required this.state,
    required this.picked,
    required this.onPick,
  });

  final List<String> options;
  final _ChoiceState Function(int index) state;
  final int? picked;
  final ValueChanged<int>? onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var index = 0; index < options.length; index += 1)
          _BalloonChoice(
            text: options[index],
            state: state(index),
            popped: picked != null && index == picked,
            onTap: onPick == null ? null : () => onPick!(index),
          ),
      ],
    );
  }
}

class _BalloonChoice extends StatelessWidget {
  const _BalloonChoice({
    required this.text,
    required this.state,
    required this.popped,
    required this.onTap,
  });

  final String text;
  final _ChoiceState state;
  final bool popped;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final paint = _paint(state, context);
    final neutral = state == _ChoiceState.idle;
    return AnimatedScale(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      // المفرقعةُ تصغر: أثرُ الضغطة يُرى على البالونة التي لُمست.
      scale: popped ? 0.86 : 1,
      child: Material(
        color: neutral ? const Color(0xFFFFE4E6) : paint.fill,
        // ثمرةٌ بعُنقٍ صغير — الشكلُ نفسُه الذي كان بالونة، مقلوباً.
        shape: const _BalloonBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 104,
            height: 104,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: ShapeDecoration(
              shape: _BalloonBorder(
                  side: BorderSide(color: paint.border, width: 1.6)),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: paint.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// بالونةٌ: دائرةٌ بذيلٍ صغير أسفلها.
class _BalloonBorder extends ShapeBorder {
  const _BalloonBorder({this.side = BorderSide.none});

  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final body = Rect.fromLTWH(
      rect.left,
      rect.top,
      rect.width,
      rect.height * 0.88,
    );
    final tailTop = body.bottom - 2;
    final centre = rect.center.dx;
    return Path()
      ..addOval(body)
      ..moveTo(centre - 6, tailTop)
      ..lineTo(centre + 6, tailTop)
      ..lineTo(centre, rect.bottom)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(
      getOuterPath(rect, textDirection: textDirection),
      side.toPaint()..style = PaintingStyle.stroke,
    );
  }

  @override
  ShapeBorder scale(double t) => _BalloonBorder(side: side.scale(t));
}

/// جواهرُ في كهف: الجوابُ محفورٌ في واحدةٍ منها.
class _GemChoices extends StatelessWidget {
  const _GemChoices({
    required this.options,
    required this.state,
    required this.picked,
    required this.onPick,
  });

  final List<String> options;
  final _ChoiceState Function(int index) state;
  final int? picked;
  final ValueChanged<int>? onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var index = 0; index < options.length; index += 1)
          _GemChoice(
            text: options[index],
            state: state(index),
            taken: picked != null && index == picked,
            onTap: onPick == null ? null : () => onPick!(index),
          ),
      ],
    );
  }
}

class _GemChoice extends StatelessWidget {
  const _GemChoice({
    required this.text,
    required this.state,
    required this.taken,
    required this.onTap,
  });

  final String text;
  final _ChoiceState state;
  final bool taken;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final paint = _paint(state, context);
    final neutral = state == _ChoiceState.idle;
    return AnimatedScale(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      scale: taken ? 1.06 : 1,
      child: Material(
        color: neutral ? const Color(0xFFFFEDD5) : paint.fill,
        // مكعّبٌ بزوايا ناعمة: شكلُ قطعة البناء يُعرف قبل أن يُقرأ ما فيها.
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 112,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: paint.border, width: 1.6),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // مكعّبٌ يُختار فيسقط في البرج.
                const Text('🧱', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 6),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: paint.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
