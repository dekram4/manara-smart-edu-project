import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../models/student_gamification.dart';
import '../models/study_games.dart';
import '../services/student_sound_service.dart';
import '../services/student_study_service.dart';
import '../theme/student_theme.dart';

/// يصرف مكافأة لعبةٍ فاز بها الطفل — الخادمُ يقرّر المقدار من سجلّ الدرس.
typedef StudyGameWin = Future<RewardResult?> Function(StudyGame game);

/// تبويبُ «ألعاب الدرس» في بطاقة المذاكرة: ثلاثُ ألعابٍ يولّدها الذكاءُ
/// الاصطناعي من نصّ الدرس — سحبٌ وإسقاط، ومطابقة، وسباقُ أسئلةٍ بلا نهاية.
///
/// الألعابُ تُطلب حين يُفتح التبويب أوّلَ مرّة لا مع الشاشة: من جاء ليقرأ
/// الخريطة لا ينتظر توليدَ ألعابٍ لم يطلبها.
class StudyGamesTab extends StatefulWidget {
  const StudyGamesTab({
    required this.load,
    required this.onWin,
    super.key,
  });

  final Future<StudyGamesPack> Function() load;
  final StudyGameWin onWin;

  @override
  State<StudyGamesTab> createState() => _StudyGamesTabState();
}

class _StudyGamesTabState extends State<StudyGamesTab>
    with AutomaticKeepAliveClientMixin {
  StudyGamesPack? _pack;
  String? _error;
  bool _loading = true;
  StudyGame? _active;

  /// كلُّ فتحٍ للعبة يأخذ مفتاحاً جديداً، فـ«العب مرة أخرى» تبدأ من الصفر.
  int _round = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_fetch());
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pack = await widget.load();
      if (!mounted) return;
      setState(() {
        _pack = pack;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      final message = switch (error) {
        StudyServerFailure(:final message) => message,
        StudyFailure(:final message) => message,
        _ => '',
      };
      setState(() {
        _loading = false;
        _error = message.isNotEmpty ? message : tr('study.error.failed');
      });
    }
  }

  void _open(StudyGame game) {
    StudentSoundService.instance.playTap();
    setState(() {
      _active = game;
      _round += 1;
    });
  }

  Future<void> _won(StudyGame game) async {
    StudentSoundService.instance.playApplause();
    RewardResult? result;
    var failed = false;
    try {
      result = await widget.onWin(game);
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    if (result != null && result.gems > 0) {
      StudentSoundService.instance.playReward();
    }
    if (result?.levelUp ?? false) StudentSoundService.instance.playLevelUp();
    await showStudyGameReward(
      context,
      game: game,
      result: result,
      failed: failed,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Bouncing(child: Text('🎲', style: TextStyle(fontSize: 54))),
            const SizedBox(height: 14),
            Text(
              tr('study.games.loading'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: StudentSurface.ink(context),
              ),
            ),
          ],
        ),
      );
    }
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🧩', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 12),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  fontWeight: FontWeight.w800,
                  color: StudentSurface.ink(context),
                ),
              ),
              const SizedBox(height: 16),
              _GameButton(
                label: tr('study.again'),
                color: _Palette.violet,
                onPressed: _fetch,
              ),
            ],
          ),
        ),
      );
    }
    final pack = _pack;
    if (pack == null) return const SizedBox.shrink();
    final active = _active;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: active == null
          ? _GameShelf(
              key: const ValueKey('shelf'),
              games: pack.games,
              onOpen: _open,
            )
          : _GameStage(
              key: ValueKey('game-${active.id}-$_round'),
              game: active,
              onBack: () => setState(() => _active = null),
              onReplay: () => _open(active),
              onWin: () => _won(active),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// الرفّ
// ─────────────────────────────────────────────────────────────────────

class _Palette {
  static const violet = Color(0xFF7C3AED);
  static const sky = Color(0xFF0EA5E9);
  static const pink = Color(0xFFDB2777);
  static const green = Color(0xFF16A34A);
  static const gold = Color(0xFFF59E0B);
  static const red = Color(0xFFDC2626);

  /// ألوانُ السلال والبطاقات بالتناوب.
  static const bins = [sky, pink, gold, green];

  static Color of(StudyGameType type) => switch (type) {
        StudyGameType.dragDrop => sky,
        StudyGameType.matching => pink,
        StudyGameType.endlessQuiz => violet,
      };

  static String emoji(StudyGameType type) => switch (type) {
        StudyGameType.dragDrop => '🧺',
        StudyGameType.matching => '🔗',
        StudyGameType.endlessQuiz => '🚀',
      };

  static String kind(StudyGameType type) => switch (type) {
        StudyGameType.dragDrop => tr('study.games.dragDrop'),
        StudyGameType.matching => tr('study.games.matching'),
        StudyGameType.endlessQuiz => tr('study.games.endless'),
      };
}

class _GameShelf extends StatelessWidget {
  const _GameShelf({required this.games, required this.onOpen, super.key});

  final List<StudyGame> games;
  final ValueChanged<StudyGame> onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Text(
          tr('study.games.pick'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: StudentSurface.ink(context),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < games.length; i++)
          _ShelfCard(game: games[i], index: i, onTap: () => onOpen(games[i])),
      ],
    );
  }
}

class _ShelfCard extends StatelessWidget {
  const _ShelfCard({
    required this.game,
    required this.index,
    required this.onTap,
  });

  final StudyGame game;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _Palette.of(game.type);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index * 140),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 30 * (1 - t)), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Semantics(
          button: true,
          label: game.title,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, Color.lerp(color, Colors.white, 0.25)!],
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Color.lerp(color, Colors.black, 0.4)!,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _Bouncing(
                    delay: Duration(milliseconds: index * 300),
                    child: Text(
                      _Palette.emoji(game.type),
                      style: const TextStyle(fontSize: 44),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _Palette.kind(game.type),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          game.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          game.instructions,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _RewardPill(
                          gems: game.gemsReward,
                          points: game.pointsReward,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.play_circle_fill_rounded,
                      color: Colors.white, size: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardPill extends StatelessWidget {
  const _RewardPill({required this.gems, required this.points});

  final int gems;
  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        trf('study.games.reward', {'gems': gems, 'points': points}),
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// المسرح: رأسُ اللعبة ثم اللعبة
// ─────────────────────────────────────────────────────────────────────

class _GameStage extends StatelessWidget {
  const _GameStage({
    required this.game,
    required this.onBack,
    required this.onReplay,
    required this.onWin,
    super.key,
  });

  final StudyGame game;
  final VoidCallback onBack;
  final VoidCallback onReplay;
  final Future<void> Function() onWin;

  @override
  Widget build(BuildContext context) {
    final color = _Palette.of(game.type);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.grid_view_rounded),
                label: Text(tr('study.games.back')),
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const Spacer(),
              Text(_Palette.emoji(game.type),
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  game.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: StudentSurface.ink(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            game.instructions,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: StudentSurface.mutedInk(context),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: switch (game.type) {
            StudyGameType.dragDrop =>
              DragDropGame(game: game, onWin: onWin, onReplay: onReplay),
            StudyGameType.matching =>
              MatchingGame(game: game, onWin: onWin, onReplay: onReplay),
            StudyGameType.endlessQuiz =>
              EndlessQuizGame(game: game, onWin: onWin, onReplay: onReplay),
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// ١) السحب والإسقاط: بطاقاتٌ إلى سلالها
// ─────────────────────────────────────────────────────────────────────

/// اسحب كلَّ بطاقةٍ إلى سلّتها. والسحبُ ليس الطريقَ الوحيد: ضغطُ البطاقة
/// ثم السلّة يفعل الشيءَ نفسه — لطفلٍ لم تتعوّد يدُه السحبَ بعد.
class DragDropGame extends StatefulWidget {
  const DragDropGame({
    required this.game,
    required this.onWin,
    required this.onReplay,
    super.key,
  });

  final StudyGame game;
  final Future<void> Function() onWin;
  final VoidCallback onReplay;

  @override
  State<DragDropGame> createState() => _DragDropGameState();
}

class _DragDropGameState extends State<DragDropGame> {
  late final List<String> _pool = [...widget.game.dragItems]
    ..shuffle(math.Random());
  final Map<String, List<String>> _placed = {};
  String? _selected;
  String? _shaking;
  int _mistakes = 0;
  bool _done = false;

  int get _total => widget.game.dragItems.length;
  int get _doneCount => _total - _pool.length;

  void _drop(String item, String target) {
    if (_done || !_pool.contains(item)) return;
    final right = widget.game.targetOf(item) == target;
    if (right) {
      StudentSoundService.instance.play(StudentSoundCue.success);
      setState(() {
        _pool.remove(item);
        _placed.putIfAbsent(target, () => []).add(item);
        _selected = null;
      });
      if (_pool.isEmpty) {
        _done = true;
        unawaited(widget.onWin());
      }
    } else {
      StudentSoundService.instance.play(StudentSoundCue.warning);
      setState(() {
        _mistakes += 1;
        _shaking = target;
        _selected = null;
      });
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted && _shaking == target) setState(() => _shaking = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final targets = widget.game.dropTargets;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 28),
          child: Column(
            children: [
              _ProgressRow(
                done: _doneCount,
                total: _total,
                mistakes: _mistakes,
                color: _Palette.sky,
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < _pool.length; i++)
                    _DraggableCard(
                      key: ValueKey('drag-${_pool[i]}'),
                      label: _pool[i],
                      color: _Palette.bins[i % _Palette.bins.length],
                      selected: _selected == _pool[i],
                      onTap: () {
                        StudentSoundService.instance.playTap();
                        setState(() => _selected =
                            _selected == _pool[i] ? null : _pool[i]);
                      },
                    ),
                ],
              ),
              if (_pool.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  tr('study.games.tapHint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: StudentSurface.mutedInk(context),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < targets.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _Shake(
                        active: _shaking == targets[i],
                        child: _Bin(
                          label: targets[i],
                          color: _Palette.bins[(i + 1) % _Palette.bins.length],
                          items: _placed[targets[i]] ?? const [],
                          armed: _selected != null,
                          onAccept: (item) => _drop(item, targets[i]),
                          onTap: () {
                            final selected = _selected;
                            if (selected != null) _drop(selected, targets[i]);
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (_done) ...[
                const SizedBox(height: 20),
                _GameButton(
                  label: tr('study.games.playAgain'),
                  color: _Palette.sky,
                  onPressed: widget.onReplay,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DraggableCard extends StatelessWidget {
  const _DraggableCard({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final card = _CardFace(label: label, color: color, lifted: selected);
    return Draggable<String>(
      data: label,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.rotate(
          angle: -0.06,
          child: Transform.scale(
            scale: 1.12,
            child: _CardFace(label: label, color: color, lifted: true),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: card),
      onDragStarted: StudentSoundService.instance.playTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(onTap: onTap, child: card),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.label,
    required this.color,
    this.lifted = false,
    this.done = false,
  });

  final String label;
  final Color color;
  final bool lifted;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final base = done ? _Palette.green : color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      transform: Matrix4.translationValues(0, lifted ? -4 : 0, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: const BoxConstraints(minWidth: 70, maxWidth: 220),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: lifted ? Colors.white : Colors.transparent,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Color.lerp(base, Colors.black, 0.4)!,
            offset: Offset(0, lifted ? 7 : 4),
            blurRadius: lifted ? 6 : 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done) ...[
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bin extends StatelessWidget {
  const _Bin({
    required this.label,
    required this.color,
    required this.items,
    required this.armed,
    required this.onAccept,
    required this.onTap,
  });

  final String label;
  final Color color;
  final List<String> items;
  final bool armed;
  final ValueChanged<String> onAccept;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              constraints: const BoxConstraints(minHeight: 150),
              padding: const EdgeInsets.all(10),
              transform: Matrix4.diagonal3Values(
                  hovering ? 1.05 : 1, hovering ? 1.05 : 1, 1),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: hovering || armed ? 0.24 : 0.12),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: color,
                  width: hovering ? 3.5 : 2.5,
                ),
              ),
              child: Column(
                children: [
                  Text(hovering ? '😮' : '🧺',
                      style: const TextStyle(fontSize: 30)),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color.lerp(color, Colors.black, 0.25),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _PopIn(
                        child: _CardFace(label: item, color: color, done: true),
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

// ─────────────────────────────────────────────────────────────────────
// ٢) المطابقة: كلُّ مفهومٍ إلى معناه
// ─────────────────────────────────────────────────────────────────────

class MatchingGame extends StatefulWidget {
  const MatchingGame({
    required this.game,
    required this.onWin,
    required this.onReplay,
    super.key,
  });

  final StudyGame game;
  final Future<void> Function() onWin;
  final VoidCallback onReplay;

  @override
  State<MatchingGame> createState() => _MatchingGameState();
}

class _MatchingGameState extends State<MatchingGame> {
  final _random = math.Random();
  late final List<String> _left = [
    for (final pair in widget.game.pairs) pair.item,
  ]..shuffle(_random);
  late final List<String> _right = [
    for (final pair in widget.game.pairs) pair.target,
  ]..shuffle(_random);
  final Set<String> _matched = {};
  String? _selected;
  String? _shaking;
  int _mistakes = 0;
  bool _done = false;

  void _match(String item, String target) {
    if (_done || _matched.contains(item)) return;
    if (widget.game.targetOf(item) == target) {
      StudentSoundService.instance.play(StudentSoundCue.success);
      setState(() {
        _matched.add(item);
        _selected = null;
      });
      if (_matched.length == _left.length) {
        _done = true;
        unawaited(widget.onWin());
      }
    } else {
      StudentSoundService.instance.play(StudentSoundCue.warning);
      setState(() {
        _mistakes += 1;
        _shaking = target;
        _selected = null;
      });
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted && _shaking == target) setState(() => _shaking = null);
      });
    }
  }

  String? _matchedItemFor(String target) {
    for (final item in _matched) {
      if (widget.game.targetOf(item) == target) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      children: [
        _ProgressRow(
          done: _matched.length,
          total: _left.length,
          mistakes: _mistakes,
          color: _Palette.pink,
        ),
        const SizedBox(height: 6),
        Text(
          tr('study.games.tapHint'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: StudentSurface.mutedInk(context),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _left.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: _matched.contains(_left[i])
                      ? _PopIn(
                          child: _CardFace(
                            label: _left[i],
                            color: _Palette.pink,
                            done: true,
                          ),
                        )
                      : _DraggableCard(
                          key: ValueKey('match-${_left[i]}'),
                          label: _left[i],
                          color: _Palette.pink,
                          selected: _selected == _left[i],
                          onTap: () {
                            StudentSoundService.instance.playTap();
                            setState(() => _selected =
                                _selected == _left[i] ? null : _left[i]);
                          },
                        ),
                ),
                const SizedBox(width: 8),
                Text(
                  _matchedItemFor(_right[i]) != null ? '🔗' : '➜',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: _Shake(
                    active: _shaking == _right[i],
                    child: _MeaningSlot(
                      label: _right[i],
                      matched: _matchedItemFor(_right[i]) != null,
                      armed: _selected != null,
                      onAccept: (item) => _match(item, _right[i]),
                      onTap: () {
                        final selected = _selected;
                        if (selected != null) _match(selected, _right[i]);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_done) ...[
          const SizedBox(height: 8),
          Center(
            child: _GameButton(
              label: tr('study.games.playAgain'),
              color: _Palette.pink,
              onPressed: widget.onReplay,
            ),
          ),
        ],
      ],
    );
  }
}

class _MeaningSlot extends StatelessWidget {
  const _MeaningSlot({
    required this.label,
    required this.matched,
    required this.armed,
    required this.onAccept,
    required this.onTap,
  });

  final String label;
  final bool matched;
  final bool armed;
  final ValueChanged<String> onAccept;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => !matched,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        final color = matched ? _Palette.green : _Palette.violet;
        return Semantics(
          button: !matched,
          label: label,
          child: GestureDetector(
            onTap: matched ? null : onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: color.withValues(
                    alpha: matched ? 0.18 : (hovering || armed ? 0.2 : 0.08)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color, width: hovering ? 3 : 2),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w900,
                  color: Color.lerp(color, Colors.black, 0.3),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// ٣) سباقٌ بلا نهاية: أسئلةٌ متتالية حتى تنفد القلوب
// ─────────────────────────────────────────────────────────────────────

/// أسئلةٌ سريعةٌ تدور بلا نهاية — كلُّ دورةٍ بترتيبٍ جديد — وثلاثةُ قلوب.
///
/// والفوزُ بلوغُ [goal] إجاباتٍ صحيحة: تُصرف المكافأة مرّةً، ويبقى الطفلُ
/// يلعب ما شاء ليحطّم رقمه.
class EndlessQuizGame extends StatefulWidget {
  const EndlessQuizGame({
    required this.game,
    required this.onWin,
    required this.onReplay,
    super.key,
  });

  final StudyGame game;
  final Future<void> Function() onWin;
  final VoidCallback onReplay;

  @override
  State<EndlessQuizGame> createState() => _EndlessQuizGameState();
}

class _EndlessQuizGameState extends State<EndlessQuizGame> {
  static const _hearts = 3;
  final _random = math.Random();
  late List<StudyQuickQuestion> _deck = _shuffled();
  int _at = 0;
  late List<String> _options = _optionsFor(_deck.first);
  int _lives = _hearts;
  int _score = 0;
  int _streak = 0;
  String? _picked;
  bool _won = false;

  int get goal => math.min(10, math.max(5, widget.game.questions.length));

  List<StudyQuickQuestion> _shuffled() =>
      [...widget.game.questions]..shuffle(_random);

  List<String> _optionsFor(StudyQuickQuestion question) =>
      [...question.options]..shuffle(_random);

  StudyQuickQuestion get _current => _deck[_at];

  void _pick(String option) {
    if (_picked != null || _lives == 0) return;
    final right = option == _current.answer;
    setState(() {
      _picked = option;
      if (right) {
        _score += 1;
        _streak += 1;
      } else {
        _lives -= 1;
        _streak = 0;
      }
    });
    StudentSoundService.instance
        .play(right ? StudentSoundCue.success : StudentSoundCue.warning);
    if (right && !_won && _score >= goal) {
      _won = true;
      unawaited(widget.onWin());
    }
    Future.delayed(const Duration(milliseconds: 750), () {
      if (!mounted || _lives == 0) return;
      setState(() {
        _at += 1;
        if (_at >= _deck.length) {
          _deck = _shuffled();
          _at = 0;
        }
        _options = _optionsFor(_current);
        _picked = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final over = _lives == 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Row(
          children: [
            for (var i = 0; i < _hearts; i++)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 2),
                child: AnimatedScale(
                  scale: i < _lives ? 1 : 0.7,
                  duration: const Duration(milliseconds: 200),
                  child: Text(i < _lives ? '❤️' : '🤍',
                      style: const TextStyle(fontSize: 22)),
                ),
              ),
            const Spacer(),
            if (_streak >= 2)
              _PopIn(
                key: ValueKey('streak-$_streak'),
                child: Text(
                  trf('study.games.streak', {'n': _streak}),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _Palette.gold,
                  ),
                ),
              ),
            const SizedBox(width: 10),
            Text(
              trf('study.games.score', {'n': _score}),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: StudentSurface.ink(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (_score / goal).clamp(0.0, 1.0),
            minHeight: 10,
            color: _won ? _Palette.green : _Palette.violet,
            backgroundColor: _Palette.violet.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          trf('study.games.goal', {'n': goal}),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: StudentSurface.mutedInk(context),
          ),
        ),
        const SizedBox(height: 16),
        if (over) ...[
          const Center(child: Text('🏁', style: TextStyle(fontSize: 56))),
          const SizedBox(height: 8),
          Text(
            trf('study.games.over', {'n': _score}),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: StudentSurface.ink(context),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: _GameButton(
              label: tr('study.games.playAgain'),
              color: _Palette.violet,
              onPressed: widget.onReplay,
            ),
          ),
        ] else
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween(begin: const Offset(0.25, 0), end: Offset.zero)
                  .animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Column(
              key: ValueKey('q-$_score-$_lives-$_at'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _Palette.violet,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFF4C1D95), offset: Offset(0, 5)),
                    ],
                  ),
                  child: Text(
                    _current.question,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                for (final option in _options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OptionButton(
                      label: option,
                      state: _picked == null
                          ? _OptionState.idle
                          : option == _current.answer
                              ? _OptionState.right
                              : option == _picked
                                  ? _OptionState.wrong
                                  : _OptionState.faded,
                      onTap: () => _pick(option),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

enum _OptionState { idle, right, wrong, faded }

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _OptionState.right => _Palette.green,
      _OptionState.wrong => _Palette.red,
      _ => _Palette.sky,
    };
    final filled = state == _OptionState.right || state == _OptionState.wrong;
    return AnimatedOpacity(
      opacity: state == _OptionState.faded ? 0.45 : 1,
      duration: const Duration(milliseconds: 180),
      child: _Shake(
        active: state == _OptionState.wrong,
        child: Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: filled ? color : StudentSurface.card(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.55),
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: filled ? Colors.white : color,
                      ),
                    ),
                  ),
                  if (state == _OptionState.right)
                    const Icon(Icons.star_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// شاشةُ الاحتفال
// ─────────────────────────────────────────────────────────────────────

/// الاحتفالُ بالفوز: ورقٌ يتناثر، وما كسبه الطفل من جواهر ونقاط يعدّ أمامه.
Future<void> showStudyGameReward(
  BuildContext context, {
  required StudyGame game,
  required RewardResult? result,
  bool failed = false,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: tr('study.games.collect'),
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 360),
    transitionBuilder: (context, animation, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
      child: child,
    ),
    pageBuilder: (context, _, __) =>
        _RewardPopup(game: game, result: result, failed: failed),
  );
}

class _RewardPopup extends StatefulWidget {
  const _RewardPopup({
    required this.game,
    required this.result,
    required this.failed,
  });

  final StudyGame game;
  final RewardResult? result;
  final bool failed;

  @override
  State<_RewardPopup> createState() => _RewardPopupState();
}

class _RewardPopupState extends State<_RewardPopup> {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final gems = result?.gems ?? 0;
    final points = result?.xp ?? 0;
    final already = result?.alreadyRewarded ?? false;
    return Center(
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            child: Container(
              width: 320,
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF4C1D95), offset: Offset(0, 7)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Bouncing(
                    child: Text('🏆', style: TextStyle(fontSize: 64)),
                  ),
                  Text(
                    tr('study.games.winTitle'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trf('study.games.winBody', {'title': widget.game.title}),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (gems > 0 || points > 0)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _CountUp(
                          value: gems,
                          builder: (n) => trf('study.games.gems', {'n': n}),
                        ),
                        _CountUp(
                          value: points,
                          builder: (n) => trf('study.games.points', {'n': n}),
                        ),
                      ],
                    )
                  else
                    Text(
                      widget.failed || result == null
                          ? tr('study.games.rewardFailed')
                          : already
                              ? tr('study.games.already')
                              : '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  if (result?.levelUp ?? false) ...[
                    const SizedBox(height: 10),
                    Text(
                      tr('study.games.levelUp'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFDE68A),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _GameButton(
                    label: tr('study.games.collect'),
                    color: _Palette.gold,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
          IgnorePointer(
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 28,
              maxBlastForce: 24,
              minBlastForce: 10,
              gravity: 0.3,
              shouldLoop: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.builder});

  final int value;
  final String Function(int) builder;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          builder(t.round()),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Color(0xFF4C1D95),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// أدواتٌ صغيرة
// ─────────────────────────────────────────────────────────────────────

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.done,
    required this.total,
    required this.mistakes,
    required this.color,
  });

  final int done;
  final int total;
  final int mistakes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              trf('study.games.placed', {'done': done, 'total': total}),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: StudentSurface.ink(context),
              ),
            ),
            const Spacer(),
            if (mistakes > 0)
              Text(
                trf('study.games.mistakes', {'n': mistakes}),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: StudentSurface.mutedInk(context),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: total == 0 ? 0 : done / total),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 10,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ),
      ],
    );
  }
}

class _GameButton extends StatelessWidget {
  const _GameButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () {
        StudentSoundService.instance.playTap();
        onPressed();
      },
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
      child: Text(label),
    );
  }
}

/// يقفز بلطفٍ بلا توقّف — للرموز التي تدعو الطفل إلى اللعب. ويسكن لمن
/// طلب تقليل الحركة.
class _Bouncing extends StatefulWidget {
  const _Bouncing({required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<_Bouncing> createState() => _BouncingState();
}

class _BouncingState extends State<_Bouncing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  Timer? _start;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (still) {
      _start?.cancel();
      _controller.stop();
    } else if (!_controller.isAnimating && _start == null) {
      _start = Timer(widget.delay, () {
        if (mounted) _controller.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    _start?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -8 * Curves.easeInOut.transform(_controller.value)),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// يهتزّ مرّةً حين يصير [active] — خطأٌ يُرى لا يُقرأ.
class _Shake extends StatelessWidget {
  const _Shake({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(active),
      tween: Tween(begin: 0, end: active ? 1 : 0),
      duration: const Duration(milliseconds: 420),
      builder: (context, t, child) => Transform.translate(
        offset: Offset(math.sin(t * math.pi * 6) * 8 * (1 - t), 0),
        child: child,
      ),
      child: child,
    );
  }
}

/// يظهر بنبضة: بطاقةٌ استقرّت في مكانها الصحيح.
class _PopIn extends StatelessWidget {
  const _PopIn({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.elasticOut,
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
      child: child,
    );
  }
}
