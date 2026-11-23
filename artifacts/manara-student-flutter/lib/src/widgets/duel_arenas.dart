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

/// حصّةُ الحبل: من −١ (عند المنافسين كلَّه) إلى +١ (عندي كلَّه).
///
/// أنا في طرف، والمنافسون — واحداً كانوا أو خمسة — في الطرف المقابل، والحبلُ
/// يسير بما بيني وبين أقواهم: من أصاب أكثر يشدّه إليه.
double duelRopeShift(List<ArenaRacer> racers, int total) {
  if (racers.isEmpty) return 0;
  final mine = racers.where((r) => r.me).fold<int>(0, (best, r) => math.max(best, r.at));
  final rivals = racers.where((r) => !r.me).map((r) => r.at);
  final best = rivals.isEmpty ? 0 : rivals.reduce(math.max);
  final steps = total <= 0 ? 1 : total;
  return ((mine - best) / steps).clamp(-1.0, 1.0);
}

/// بنائي اكتمل: كلُّ طوبةٍ في مكانها.
bool duelBuildingComplete(List<ArenaRacer> racers, int total) =>
    total > 0 && racers.any((r) => r.me && r.at >= total);

class _DuelArenaState extends State<DuelArena> with SingleTickerProviderStateMixin {
  late final AnimationController _beat =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) setState(() => _kind = null);
        });

  /// الحركةُ الجارية، أو `null` والمشهدُ هادئ.
  DuelBeat? _kind;

  /// من كسب النقطةَ في هذه الحركة (رقمُه في [ArenaRacer]s): أنا في النجاح،
  /// والسابقُ في «سبقك».
  int? _scorer;

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
    // ‏من كسب: أوّلُ لاعبٍ زادت نقطتُه.
    int? scorer;
    if (before.length == now.length) {
      for (var i = 0; i < now.length; i++) {
        if (now[i].at > before[i].at) {
          scorer = i;
          break;
        }
      }
    }
    // ‏أخطأتُ ثم سبقني زميلٌ في السؤال نفسه: تعثّرٌ واحد — لكنّ السابقَ يُعرف ويُرى.
    if (beat == DuelBeat.beaten && _kind == DuelBeat.wrong && _beat.isAnimating) {
      setState(() => _scorer = scorer);
      return;
    }
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    _kind = beat;
    _scorer = scorer;
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
        // ‏الهاتف: مشهدٌ لا يُبعد السؤال. التابلت: مشهدٌ بنسبته يملأ عموده.
        final sceneHeight = width < 520
            ? (widget.compact ? 150.0 : (width * 9 / 16).clamp(170.0, 220.0))
            : (width * 9 / 16).clamp(200.0, 330.0);
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
                      racers: racers,
                      total: widget.total,
                      finished: widget.finished,
                      winner: winner,
                      scorer: _scorer,
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

/// لحظةٌ من الحركة: ما يحتاجه كلُّ مسرحٍ ليرسمها.
class _Moment {
  const _Moment({
    required this.racers,
    required this.total,
    required this.kind,
    required this.t,
    required this.scorer,
    required this.finished,
    required this.winner,
  });

  final List<ArenaRacer> racers;
  final int total;
  final DuelBeat? kind;
  final double t;
  final int? scorer;
  final bool finished;
  final int? winner;

  bool get up => kind == DuelBeat.success;
  bool get down => kind == DuelBeat.wrong || kind == DuelBeat.beaten;

  /// ٠ ← ١ ← ٠ على طول الحركة.
  double get arc => kind == null ? 0 : math.sin(math.pi * t);

  /// تتلاشى في آخر الحركة.
  double get leave => t > 0.8 ? (1 - (t - 0.8) / 0.2) : 1.0;

  int get meIndex {
    final i = racers.indexWhere((r) => r.me);
    return i < 0 ? 0 : i;
  }

  /// السابقُ في «سبقك»: زميلٌ لا أنا.
  int? get rivalScorer => kind == DuelBeat.beaten && scorer != null && !racers[scorer!].me ? scorer : null;
}

/// المشهدُ وحركتُه، ومسرحُ اللعبة فوقه، وكلمةُ ما جرى.
class _BeatScene extends StatelessWidget {
  const _BeatScene({
    required this.game,
    required this.racers,
    required this.total,
    required this.finished,
    required this.winner,
    required this.scorer,
    required this.height,
    required this.kind,
    required this.serial,
    required this.t,
    required this.chips,
  });

  final DuelGame game;
  final List<ArenaRacer> racers;
  final int total;
  final bool finished;
  final int? winner;
  final int? scorer;
  final double height;
  final DuelBeat? kind;
  final int serial;
  final double t;
  final Widget chips;

  @override
  Widget build(BuildContext context) {
    final moment = _Moment(
      racers: racers,
      total: total,
      kind: kind,
      t: t,
      scorer: scorer,
      finished: finished,
      winner: winner,
    );
    final shake = kind == null ? 0.0 : math.sin(t * math.pi * 6) * (1 - t);
    // ‏الكاميرا: ارتجاجٌ خفيفٌ مع التعثّر، ونبضةٌ مع النجاح — والقصّةُ في المسرح.
    final dx = moment.down ? 6 * shake : 0.0;
    final scale = moment.up ? 1 + 0.02 * moment.arc : 1.0;
    final stumbling = moment.down && t < 0.8;
    Widget scene = DuelGameScene(
      game: game,
      players: racers.length,
      height: height,
      // ‏التعثّرُ يُوقف المشهدَ لحظة، ويبهت لونُه.
      paused: stumbling,
      overlay: Padding(
        padding: const EdgeInsets.all(8),
        child: Align(alignment: AlignmentDirectional.topStart, child: chips),
      ),
    );
    if (stumbling) {
      scene = ColorFiltered(
        colorFilter: ColorFilter.mode(Colors.grey.withValues(alpha: 0.45 * moment.arc), BlendMode.saturation),
        child: scene,
      );
    }
    final stage = switch (game) {
      DuelGame.tug => _TugStage(moment: moment),
      DuelGame.sprint => _SprintStage(moment: moment),
      DuelGame.gems => _WallStage(moment: moment),
      DuelGame.balloons => _FruitStage(moment: moment),
    };
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.scale(scale: scale, child: scene),
              ),
            ),
            Positioned.fill(child: IgnorePointer(child: stage)),
            if (kind != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: _BeatLabel(
                    key: ValueKey('duel-beat-${game.id}-${kind!.name}-$serial'),
                    game: game,
                    moment: moment,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// كلمةُ ما جرى، في وسط المشهد: «قفزةٌ فوق الحاجز!»، «ارتخى الحبل · سبقك خالد».
class _BeatLabel extends StatelessWidget {
  const _BeatLabel({required this.game, required this.moment, super.key});

  final DuelGame game;
  final _Moment moment;

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
    final kind = moment.kind!;
    final up = kind == DuelBeat.success;
    final appear = Curves.easeOutBack.transform((moment.t / 0.25).clamp(0.0, 1.0));
    final by = moment.scorer;
    final beaten = kind == DuelBeat.beaten
        ? (by != null && !moment.racers[by].me
            ? trf('arena.beat.beatenBy', {'name': moment.racers[by].name})
            : tr('arena.beat.beaten'))
        : null;
    final label = beaten == null ? tr(labelKey(game, kind)) : '${tr(labelKey(game, kind))} · $beaten';
    return Align(
      alignment: const Alignment(0, -0.25),
      child: Opacity(
        opacity: moment.leave.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.6 + 0.4 * appear,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: up ? const Color(0xEB16A34A) : const Color(0xEBB91C1C),
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
    );
  }
}

/// شريطٌ داكنٌ شفّافٌ أسفل المشهد: ما فوقه يُقرأ على أيّ خلفية.
class _Band extends StatelessWidget {
  const _Band({required this.child, this.height});

  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x8C0F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: child,
      );
}

Widget _emoji(String text, double size, {Key? key}) =>
    Text(text, key: key, style: TextStyle(fontSize: size, height: 1));

// ─────────────────────────── شدُّ الحبل ───────────────────────────

/// أنا في طرف (البداية)، والمنافسون — واحدٌ أو أكثر — في الطرف المقابل يشدّون
/// معاً. والرايةُ في وسط الحبل تسير إلى من يتقدّم ([duelRopeShift])، وتُجذب
/// مع كل سؤال: نحوي إن سبقتُ، ونحوهم إن أخطأتُ أو سبقني أحدهم.
class _TugStage extends StatelessWidget {
  const _TugStage({required this.moment});

  final _Moment moment;

  @override
  Widget build(BuildContext context) {
    final rivals = moment.racers.length - 1;
    final shift = duelRopeShift(moment.racers, moment.total);
    // ‏الجذبةُ نفسُها: الرايةُ تتجاوز موضعَها الجديد ثم تعود إليه.
    final jerk = moment.up ? 0.35 * moment.arc : (moment.down ? -0.35 * moment.arc : 0.0);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final towardMe = rtl ? Icons.keyboard_double_arrow_right_rounded : Icons.keyboard_double_arrow_left_rounded;
    final towardThem = rtl ? Icons.keyboard_double_arrow_left_rounded : Icons.keyboard_double_arrow_right_rounded;
    final winner = moment.winner;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: _Band(
          height: 46,
          child: Row(
            children: [
              // ‏طرفي.
              Transform.translate(
                offset: Offset((rtl ? 1 : -1) * 4 * (moment.up ? moment.arc : 0), 0),
                child: _TugEnd(
                  key: const ValueKey('duel-tug-me'),
                  label: '💪 ${tr('duel.you')}',
                  color: _mineTint,
                  crowned: winner != null && moment.racers[winner].me,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: shift),
                  duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
                      ? Duration.zero
                      : const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack,
                  builder: (context, base, _) {
                    final at = (base + jerk).clamp(-1.0, 1.0);
                    return Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // ‏الحبل، وعلامةُ المنتصف.
                        Container(
                          key: const ValueKey('duel-tug-rope'),
                          height: 6,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFD6A15C), Color(0xFF92400E), Color(0xFFD6A15C)]),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Container(width: 2, height: 22, color: Colors.white70),
                        Align(
                          // ‏−١ في الاتّجاه = البداية = جهتي.
                          alignment: AlignmentDirectional(-at * 0.92, 0),
                          child: _emoji('🚩', 22, key: const ValueKey('duel-tug-flag')),
                        ),
                        if (moment.kind != null)
                          Opacity(
                            opacity: moment.leave.clamp(0.0, 1.0),
                            child: Icon(
                              moment.up ? towardMe : towardThem,
                              key: ValueKey(moment.up ? 'duel-tug-pull-me' : 'duel-tug-pull-them'),
                              size: 30 + 8 * moment.arc,
                              color: moment.up ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
              // ‏الطرفُ المقابل: كلُّ المنافسين يشدّون معاً.
              Transform.translate(
                offset: Offset((rtl ? -1 : 1) * 4 * (moment.down ? moment.arc : 0), 0),
                child: _TugEnd(
                  key: ValueKey('duel-tug-rivals-$rivals'),
                  label: rivals == 1
                      ? '💪 ${moment.racers.firstWhere((r) => !r.me, orElse: () => moment.racers.last).name}'
                      : '${'🧍' * math.min(rivals, 5)} ${trf('arena.tug.rivals', {'n': '$rivals'})}',
                  color: _rivalTints.first,
                  crowned: winner != null && !moment.racers[winner].me,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TugEnd extends StatelessWidget {
  const _TugEnd({required this.label, required this.color, required this.crowned, super.key});

  final String label;
  final Color color;
  final bool crowned;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 130),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white, width: 1.4),
          ),
          child: Text(
            '${crowned ? '🏆 ' : ''}$label',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ),
      );
}

// ─────────────────────────── سباقُ الحواجز ───────────────────────────

/// مسارٌ لكل لاعب بحواجزه، والعدّاءُ عند ما أصاب. مع كل سؤال: يقفز عدّائي
/// الحاجزَ إن سبقت، ويتعثّر ويسقط عنده إن أخطأتُ أو سُبقت — وعدّاءُ السابق
/// يقفز حاجزَه أمامي.
class _SprintStage extends StatelessWidget {
  const _SprintStage({required this.moment});

  final _Moment moment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final lanes = moment.racers.length;
        final laneHeight = ((box.maxHeight * 0.55 - 10) / lanes).clamp(10.0, 22.0);
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: _Band(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < lanes; i++)
                    SizedBox(height: laneHeight, child: _Lane(moment: moment, index: i, height: laneHeight)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Lane extends StatelessWidget {
  const _Lane({required this.moment, required this.index, required this.height});

  final _Moment moment;
  final int index;
  final double height;

  @override
  Widget build(BuildContext context) {
    final racer = moment.racers[index];
    final tint = _tintOf(moment.racers, index);
    final total = moment.total <= 0 ? 1 : moment.total;
    final mine = index == moment.meIndex;
    final jumping = (mine && moment.up) || moment.rivalScorer == index;
    final falling = mine && moment.down;
    final runner = (height * 0.95).clamp(10.0, 20.0);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Row(
      children: [
        Container(
          width: runner,
          height: runner,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          child: FittedBox(
            child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth - runner;
              return TweenAnimationBuilder<double>(
                tween: Tween(end: racer.at / total),
                duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
                    ? Duration.zero
                    : const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, p, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ‏المضمار.
                    Positioned.fill(
                      top: height * 0.75,
                      child: Container(color: tint.withValues(alpha: mine ? 0.85 : 0.5)),
                    ),
                    // ‏الحواجز: واحدٌ لكل سؤال.
                    for (var k = 0; k < total; k++)
                      PositionedDirectional(
                        start: runner / 2 + w * (k + 0.6) / total,
                        bottom: height * 0.2,
                        child: Container(
                          width: 3,
                          height: height * 0.55,
                          color: k < racer.at ? Colors.white38 : const Color(0xFFF97316),
                        ),
                      ),
                    PositionedDirectional(
                      start: w * p,
                      bottom: (jumping ? height * 0.9 * moment.arc : 0),
                      child: Transform.rotate(
                        // ‏السقوط: يميل العدّاءُ حتى يرتمي.
                        angle: falling ? (rtl ? -1 : 1) * 1.4 * math.min(1.0, moment.t * 3) * moment.leave : 0,
                        child: Transform.flip(
                          flipX: !rtl, // ‏الرمزُ يجري يساراً: بالعربية كما هو.
                          child: _emoji(
                            '🏃',
                            runner,
                            key: ValueKey(jumping
                                ? (mine ? 'duel-runner-jump' : 'duel-runner-rival-jump')
                                : falling
                                    ? 'duel-runner-fall'
                                    : 'duel-runner-$index'),
                          ),
                        ),
                      ),
                    ),
                    if (falling)
                      PositionedDirectional(
                        start: w * p + runner * 0.6,
                        bottom: height * 0.3,
                        child: Opacity(opacity: moment.leave.clamp(0.0, 1.0), child: _emoji('💥', runner * 0.8)),
                      ),
                    if (jumping)
                      PositionedDirectional(
                        start: w * p,
                        bottom: height * 0.9 * moment.arc + runner,
                        child: Opacity(opacity: moment.leave.clamp(0.0, 1.0), child: _emoji('✨', runner * 0.7)),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── بناءُ الجدار ───────────────────────────

/// جداري طوبةٌ لكل جوابٍ صحيح، وأبراجُ المنافسين بجانبه. مع النجاح تهبط
/// طوبةٌ إلى مكانها؛ ومع الخطأ أو السبق تسقط طوبةٌ من أعلى الجدار ويهتزّ —
/// ويعلو برجُ من سبق. وحين تكتمل طوبُ الجدار يظهر البناءُ كاملاً 🏰.
class _WallStage extends StatelessWidget {
  const _WallStage({required this.moment});

  final _Moment moment;

  @override
  Widget build(BuildContext context) {
    final me = moment.racers[moment.meIndex];
    final total = moment.total <= 0 ? 1 : moment.total;
    final columns = math.min(total, 5);
    final rows = (total / columns).ceil();
    final complete = duelBuildingComplete(moment.racers, moment.total);
    final shake = moment.down ? math.sin(moment.t * math.pi * 8) * (1 - moment.t) : 0.0;
    final drop = Curves.bounceOut.transform((moment.t / 0.7).clamp(0.0, 1.0));
    const brickW = 18.0, brickH = 10.0, gap = 2.0;
    Widget brick(Color color, {Key? key}) => Container(
          key: key,
          width: brickW,
          height: brickH,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: const Color(0xFF7C2D12), width: 1),
          ),
        );
    final wallW = columns * (brickW + gap);
    final wallH = rows * (brickH + gap);
    // ‏الطوبُ من الأسفل إلى الأعلى.
    Offset place(int k) => Offset((k % columns) * (brickW + gap), wallH - ((k ~/ columns) + 1) * (brickH + gap));
    final newest = me.at - 1;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: _Band(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ‏جداري.
              Transform.rotate(
                angle: 0.05 * shake,
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  key: const ValueKey('duel-wall-me'),
                  width: wallW,
                  height: wallH + 18,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var k = 0; k < total; k++)
                        Positioned(
                          left: place(k).dx,
                          top: 18 + place(k).dy,
                          child: brick(Colors.white.withValues(alpha: 0.12)),
                        ),
                      for (var k = 0; k < me.at.clamp(0, total); k++)
                        Positioned(
                          left: place(k).dx,
                          // ‏الأحدثُ يهبط من فوق إلى مكانه مع النجاح.
                          top: 18 + place(k).dy - (moment.up && k == newest ? (1 - drop) * 60 : 0),
                          child: brick(const Color(0xFFEA580C), key: const ValueKey('duel-wall-brick')),
                        ),
                      if (moment.down)
                        // ‏طوبةٌ تسقط من أعلى الجدار وتختفي.
                        Positioned(
                          left: place(me.at.clamp(0, total - 1)).dx + 30 * moment.t,
                          top: 18 + place(me.at.clamp(0, total - 1)).dy - 14 + 70 * moment.t * moment.t,
                          child: Opacity(
                            opacity: (1 - moment.t).clamp(0.0, 1.0),
                            child: Transform.rotate(
                              angle: 2.5 * moment.t,
                              child: brick(const Color(0xFFEA580C), key: const ValueKey('duel-wall-fall')),
                            ),
                          ),
                        ),
                      if (complete)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: -2,
                          child: Center(
                            child: Text(
                              '🏰 ${tr('arena.beat.wallDone')}',
                              key: const ValueKey('duel-wall-complete'),
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // ‏أبراجُ المنافسين: بطولِ ما أصابوا، ويعلو برجُ من سبق.
              for (var i = 0; i < moment.racers.length; i++)
                if (i != moment.meIndex)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 4),
                    child: Transform.translate(
                      offset: Offset(0, moment.rivalScorer == i ? -6 * moment.arc : 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var k = math.min(moment.racers[i].at, total) - 1; k >= 0; k--)
                            Container(
                              width: 10,
                              height: (wallH / total).clamp(3.0, 8.0),
                              margin: const EdgeInsets.only(top: 1),
                              color: _tintOf(moment.racers, i),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            '${i + 1}',
                            style: TextStyle(color: _tintOf(moment.racers, i), fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── جمعُ الفواكه ───────────────────────────

/// سلّتي وسلالُ المنافسين. مع النجاح تسقط ثمرةٌ في سلّتي؛ ومع الخطأ أو
/// السبق تسقط ثمرتي على الأرض بجانب السلّة — وتمتلئ سلّةُ من سبق.
class _FruitStage extends StatelessWidget {
  const _FruitStage({required this.moment});

  final _Moment moment;

  @override
  Widget build(BuildContext context) {
    final me = moment.racers[moment.meIndex];
    final fall = Curves.easeIn.transform((moment.t / 0.6).clamp(0.0, 1.0));
    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight;
        return Stack(
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: _Band(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Basket(
                        key: const ValueKey('duel-basket-me'),
                        count: me.at,
                        color: _mineTint,
                        label: tr('duel.you'),
                        big: true,
                      ),
                      for (var i = 0; i < moment.racers.length; i++)
                        if (i != moment.meIndex)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 8),
                            child: Transform.scale(
                              scale: moment.rivalScorer == i ? 1 + 0.2 * moment.arc : 1,
                              child: _Basket(
                                key: ValueKey(moment.rivalScorer == i ? 'duel-fruit-rival-catch' : 'duel-basket-$i'),
                                count: moment.racers[i].at,
                                color: _tintOf(moment.racers, i),
                                label: '${i + 1}',
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
            if (moment.up)
              // ‏الثمرةُ تسقط في سلّتي.
              Positioned(
                left: 0,
                right: 0,
                top: (h - 70) * fall,
                child: Center(
                  child: Opacity(
                    opacity: moment.leave.clamp(0.0, 1.0),
                    child: _emoji('🍎', 26, key: const ValueKey('duel-fruit-in')),
                  ),
                ),
              ),
            if (moment.down)
              // ‏وتفلت إلى الأرض بجانب السلّة، تتدحرج وتبقى حتى تهدأ الحركة.
              Positioned(
                left: 0,
                right: 0,
                top: math.min((h - 30) * fall, h - 30),
                child: Center(
                  child: Transform.translate(
                    offset: Offset(60 * fall, 0),
                    child: Transform.rotate(
                      angle: 3 * fall,
                      child: Opacity(
                        opacity: moment.leave.clamp(0.0, 1.0),
                        child: _emoji('🍎', 24, key: const ValueKey('duel-fruit-ground')),
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

class _Basket extends StatelessWidget {
  const _Basket({required this.count, required this.color, required this.label, this.big = false, super.key});

  final int count;
  final Color color;
  final String label;
  final bool big;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🍎×$count',
            style: TextStyle(color: Colors.white, fontSize: big ? 12 : 10, fontWeight: FontWeight.w900),
          ),
          _emoji('🧺', big ? 28 : 18),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(color: color == _mineTint ? const Color(0xFF86EFAC) : color, fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ],
      );
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
          key: const ValueKey('duel-racer-board'),
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
