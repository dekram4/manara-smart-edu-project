import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/student_strings.dart';
import '../models/student_gamification.dart';
import '../models/study_games.dart';
import '../services/student_sound_service.dart';
import '../services/student_study_service.dart';
import '../theme/student_theme.dart';
import 'quiz_games.dart';
import 'quran_recitation_game.dart';
import 'tracing_game.dart';
import 'tracing_shelf_card.dart';

/// يصرف مكافأة لعبةٍ فاز بها الطفل — الخادمُ يقرّر المقدار من سجلّ الدرس.
typedef StudyGameWin = Future<RewardResult?> Function(StudyGame game);

/// يصرف جوهرةَ حرفٍ كُتب في «تتبّع واكتب» — مرّةً لكل حرفٍ في الدرس.
typedef StudyTracingWin = Future<RewardResult?> Function(StudyGame game, TracingItem item);

/// «ألعاب الدرس» في بطاقة المذاكرة: ألعابٌ يولّدها الذكاءُ الاصطناعي من نصّ
/// الدرس — سحبٌ وإسقاط، ومطابقة، وأسئلةُ الدرس تُلعب بالبالونات والصيد
/// والقطار والمقلاع لا تُقرأ في قائمة.
///
/// الألعابُ تُطلب حين يُفتح التبويب أوّلَ مرّة لا مع الشاشة: من جاء ليقرأ
/// الخريطة لا ينتظر توليدَ ألعابٍ لم يطلبها.
class StudyGamesTab extends StatefulWidget {
  const StudyGamesTab({
    required this.load,
    required this.onWin,
    this.fresh,
    this.seenKey,
    this.allowTracing = true,
    this.onTraced,
    this.onRecited,
    this.cached,
    this.embedded = false,
    super.key,
  });

  final Future<StudyGamesPack> Function() load;

  /// داخل صفحة المذاكرة الواحدة: الرفُّ بطوله بلا تمريرٍ خاصٍّ به (تمرّره
  /// الصفحة)، وكلُّ لعبةٍ تُفتح في صفحةٍ كاملةٍ فوقها.
  final bool embedded;

  /// الحزمةُ المحفوظة على الجهاز: تُعرض فوراً، وتحلّ محلّها [load] حين تصل.
  final Future<StudyGamesPack?> Function()? cached;
  final StudyGameWin onWin;

  /// حرفٌ كُتب صحيحاً في «تتبّع واكتب»: جوهرتُه بلا نافذة احتفال.
  final StudyTracingWin? onTraced;

  /// لعبةُ التتبّع لهذا الدرس: لروضة منارة المعرفة في موادّها الأربع وحدها
  /// ([tracingAllowedFor]). وإلا تُحذف من الرفّ ولو أرسلها الخادم.
  final bool allowTracing;

  /// «تسميع القرآن الكريم»: لدرس «حفظ وشرح السور القصيرة» في الروضة وحده
  /// ([quranRecitationAllowedFor]) — وإلا `null` فلا تظهر بطاقتُها أبداً.
  final QuranRecitationWin? onRecited;

  /// نسخةٌ جديدة من لعبة، متجنّبةً ما رآه الطالب — من الذكاء الاصطناعي.
  final Future<StudyGame> Function(StudyGame base, List<String> exclude)? fresh;

  /// مفتاحُ ما رآه هذا الطالب في هذا الدرس على الجهاز (`study.seen.<طالب>.<درس>`).
  final String? seenKey;

  @override
  State<StudyGamesTab> createState() => _StudyGamesTabState();
}

class _StudyGamesTabState extends State<StudyGamesTab>
    with AutomaticKeepAliveClientMixin {
  StudyGamesPack? _pack;
  String? _error;
  bool _loading = true;
  StudyGame? _active;

  /// لعبةُ الأسئلة التي اختارها لأسئلة الدرس.
  QuizGameStyle? _style;

  /// «تسميع القرآن» مفتوحة.
  bool _quranOpen = false;

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
    // الرفُّ المحفوظ أوّلاً، بلا انتظار الخادم.
    final saved = await widget.cached?.call();
    if (saved != null && mounted && _pack == null) {
      setState(() {
        _pack = _allowed(saved);
        _loading = false;
      });
    }
    try {
      final pack = _allowed(await widget.load());
      if (!mounted) return;
      setState(() {
        _pack = pack;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      // الخادمُ تعذّر والرفُّ المحفوظ معروض: يبقى، بلا رسالة خطأ.
      if (_pack != null) return;
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

  StudyGamesPack _allowed(StudyGamesPack pack) => widget.allowTracing
      ? pack
      : StudyGamesPack(
          lessonId: pack.lessonId,
          games: [for (final game in pack.games) if (game.type != StudyGameType.tracing) game],
        );

  /// تُحضَّر نسخةٌ جديدة من اللعبة الآن.
  bool _preparing = false;

  // ── لا تتكرّر الأسئلة ──
  // الحزمةُ المحفوظة مع الدرس تُلعب أوّلَ مرّة. وكلُّ إعادةٍ بعدها — ولو في
  // جلسةٍ أخرى — تطلب من الذكاء الاصطناعي نسخةً جديدة من النصّ الكامل للدرس،
  // ويُرسل معها ما رآه الطالب منها فيتجنّبه. وما رآه محفوظٌ على الجهاز لكل
  // طالبٍ ودرسٍ ونوع لعبة. وتعذُّرُ النسخة الجديدة لا يمنع اللعب: تُلعب المحفوظة.
  static const _maxSeen = 300;

  String? _seenKeyFor(StudyGameType type) =>
      widget.seenKey == null ? null : '${widget.seenKey}.${type.wire}';

  Future<List<String>> _loadSeen(StudyGameType type) async {
    final key = _seenKeyFor(type);
    if (key == null) return const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(key) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _addSeen(StudyGameType type, Iterable<String> items) async {
    final key = _seenKeyFor(type);
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = [...(prefs.getStringList(key) ?? const <String>[])];
      for (final item in items) {
        if (item.isNotEmpty && !all.contains(item)) all.add(item);
      }
      await prefs.setStringList(
        key,
        all.length > _maxSeen ? all.sublist(all.length - _maxSeen) : all,
      );
    } catch (_) {
      // تخزينٌ محجوب: تُطلب نسخةٌ جديدة بلا قائمة تجنّب.
    }
  }

  /// ما يعدّه الطالبُ «رآه» من لعبة: أسئلةُ السباق، وبطاقاتُ السحب والمطابقة.
  static List<String> seenItemsOf(StudyGame game) =>
      switch (game.type) {
        StudyGameType.endlessQuiz => [for (final q in game.questions) q.question],
        StudyGameType.tracing => [for (final item in game.tracing) item.text],
        _ => [...game.dragItems],
      };

  StudyGame _baseOf(StudyGameType type) =>
      _pack!.games.firstWhere((game) => game.type == type);

  /// اللعبةُ كما تُلعب الآن: المحفوظةُ أوّلَ مرّة، ثم نسخةٌ جديدة لا تكرّر ما رآه.
  Future<StudyGame?> _choose(StudyGame game) async {
    final base = _baseOf(game.type);
    var chosen = base;
    final seen = await _loadSeen(game.type);
    // التتبّعُ حروفُ الروضة وأرقامُها: المجموعةُ هي هي، لا نسخةَ جديدة لها.
    final fresh = game.type == StudyGameType.tracing ? null : widget.fresh;
    if (seen.isNotEmpty && fresh != null) {
      if (!mounted) return null;
      setState(() => _preparing = true);
      try {
        chosen = await fresh(base, seen);
      } catch (_) {
        chosen = base;
      }
      if (mounted) setState(() => _preparing = false);
    }
    if (!mounted) return null;
    unawaited(_addSeen(game.type, seenItemsOf(chosen)));
    return chosen;
  }

  Future<void> _open(StudyGame game, [QuizGameStyle? style]) async {
    if (_preparing) return;
    StudentSoundService.instance.playTap();
    final chosen = await _choose(game);
    if (chosen == null || !mounted) return;
    if (widget.embedded) {
      await _push(
        (page) => _GamePage(
          first: chosen,
          style: style,
          replay: () => _choose(game),
          onWin: _won,
          onTraced: widget.onTraced,
          onNeedMore: widget.fresh == null ? null : _moreQuestions,
        ),
      );
      return;
    }
    setState(() {
      _active = chosen;
      _style = style;
      _round += 1;
    });
  }

  /// صفحةٌ كاملةٌ فوق صفحة المذاكرة، باتّجاه كتابتها.
  Future<void> _push(Widget Function(BuildContext page) builder) {
    final direction = Directionality.of(context);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (page) => Directionality(textDirection: direction, child: builder(page)),
      ),
    );
  }

  void _openQuran() {
    final onRecited = widget.onRecited;
    if (onRecited == null) return;
    if (!widget.embedded) {
      setState(() => _quranOpen = true);
      return;
    }
    unawaited(_push(
      (page) => Scaffold(
        backgroundColor: StudentSurface.ground(page),
        body: SafeArea(
          child: QuranRecitationGame(
            key: const ValueKey('quran-game'),
            onRecited: onRecited,
            onBack: () => Navigator.of(page).maybePop(),
          ),
        ),
      ),
    ));
  }

  /// أسئلةٌ جديدة للسباق حين يقترب من آخر ما عنده — لا يدور على المكرّر.
  Future<List<StudyQuickQuestion>> _moreQuestions(List<String> shown) async {
    final fresh = widget.fresh;
    if (fresh == null) return const [];
    final type = StudyGameType.endlessQuiz;
    final seen = {...await _loadSeen(type), ...shown}.toList();
    final game = await fresh(_baseOf(type), seen);
    unawaited(_addSeen(type, seenItemsOf(game)));
    return game.questions;
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
      return Padding(
        padding: EdgeInsets.symmetric(vertical: widget.embedded ? 28 : 0),
        child: Center(
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
      ),
      );
    }
    final error = _error;
    final onRecited = widget.onRecited;
    if (onRecited != null && _quranOpen) {
      return QuranRecitationGame(
        key: const ValueKey('quran-game'),
        onRecited: onRecited,
        onBack: () => setState(() => _quranOpen = false),
      );
    }
    if (error != null && onRecited != null) {
      // ألعابُ الدرس تعذّرت، والتسميعُ لا يحتاجها: نصوصُ السور في التطبيق.
      return _GameShelf(
        key: const ValueKey('shelf'),
        games: const [],
        embedded: widget.embedded,
        onOpen: _open,
        onOpenArcade: _open,
        onOpenQuran: _openQuran,
      );
    }
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
    if (_preparing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Bouncing(child: Text('✨', style: TextStyle(fontSize: 54))),
            const SizedBox(height: 14),
            Text(
              tr('study.games.fresh'),
              textAlign: TextAlign.center,
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
              embedded: widget.embedded,
              onOpen: _open,
              onOpenArcade: _open,
              onOpenQuran: onRecited == null ? null : _openQuran,
            )
          : _GameStage(
              key: ValueKey('game-${active.id}-$_round'),
              game: active,
              style: _style,
              onBack: () => setState(() => _active = null),
              onReplay: () => _open(active, _style),
              onWin: () => _won(active),
              onTraced: (item) async => widget.onTraced?.call(active, item),
              onNeedMore: widget.fresh == null ? null : _moreQuestions,
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

  /// ألوانُ السلال والبطاقات بالتناوب.
  static const bins = [sky, pink, gold, green];

  static Color of(StudyGameType type) => switch (type) {
        StudyGameType.dragDrop => sky,
        StudyGameType.matching => pink,
        StudyGameType.endlessQuiz => violet,
        StudyGameType.tracing => green,
      };

  static String emoji(StudyGameType type) => switch (type) {
        StudyGameType.dragDrop => '🧺',
        StudyGameType.matching => '🔗',
        StudyGameType.endlessQuiz => '🚀',
        StudyGameType.tracing => '✍️',
      };

  static String kind(StudyGameType type) => switch (type) {
        StudyGameType.dragDrop => tr('study.games.dragDrop'),
        StudyGameType.matching => tr('study.games.matching'),
        StudyGameType.endlessQuiz => tr('study.games.endless'),
        StudyGameType.tracing => tr('study.games.tracing'),
      };
}

class _GameShelf extends StatelessWidget {
  const _GameShelf({
    required this.games,
    required this.onOpen,
    required this.onOpenArcade,
    this.embedded = false,
    this.onOpenQuran,
    super.key,
  });

  final List<StudyGame> games;
  final ValueChanged<StudyGame> onOpen;

  /// أسئلةُ الدرس في لعبةٍ من الأربع.
  final void Function(StudyGame game, QuizGameStyle style) onOpenArcade;

  /// في صفحة المذاكرة: عمودٌ بطوله تمرّره الصفحة.
  final bool embedded;

  /// بطاقةُ «تسميع القرآن» آخرَ الرفّ — بعد ألعاب الدرس — لدرسها وحده.
  final VoidCallback? onOpenQuran;

  @override
  Widget build(BuildContext context) {
    final children = [
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
          if (games[i].type == StudyGameType.tracing)
            // التتبّعُ للصغار أوّلاً: بطاقتُه أبهجُ ما في الرفّ.
            // حركتُها الدائمة في طبقةٍ وحدها: لا تُعيد رسمَ الرفّ كلّه كلَّ إطار.
            RepaintBoundary(child: TracingShelfCard(game: games[i], index: i, onTap: () => onOpen(games[i])))
          else if (games[i].type == StudyGameType.endlessQuiz)
            // ‏أسئلةُ الدرس لا تُقرأ في قائمة: تُلعب في واحدةٍ من أربع.
            _ArcadeShelf(game: games[i], onOpen: (style) => onOpenArcade(games[i], style))
          else
            _ShelfCard(game: games[i], index: i, onTap: () => onOpen(games[i])),
        // بعد ألعاب الدرس لا مكانها: الرابعةُ بعد الثلاث.
        if (onOpenQuran != null) RepaintBoundary(child: QuranShelfCard(onTap: onOpenQuran!)),
    ];
    if (embedded) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: children,
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
          child: _PressScale(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              // ‏تدرّجٌ زاهٍ بثلاثة ألوان، وحافّةٌ بيضاء مضيئة، وتوهّجٌ بلون اللعبة.
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color,
                    Color.lerp(color, _Palette.pink, 0.35)!,
                    Color.lerp(color, _Palette.gold, 0.35)!,
                  ],
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Color.lerp(color, Colors.black, 0.4)!,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 16, spreadRadius: 1),
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
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Bouncing(
                        delay: Duration(milliseconds: 150 + index * 300),
                        child: const Text('✨', style: TextStyle(fontSize: 16)),
                      ),
                      const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 40),
                    ],
                  ),
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
    this.style,
    required this.onBack,
    required this.onReplay,
    required this.onWin,
    this.onNeedMore,
    this.onTraced,
    super.key,
  });

  final StudyGame game;

  /// لعبةُ الأسئلة لأسئلة الدرس — البالوناتُ إن لم تُختر.
  final QuizGameStyle? style;
  final VoidCallback onBack;
  final VoidCallback onReplay;
  final Future<void> Function() onWin;
  final Future<List<StudyQuickQuestion>> Function(List<String> shown)? onNeedMore;
  final Future<RewardResult?> Function(TracingItem item)? onTraced;

  @override
  Widget build(BuildContext context) {
    final color = _Palette.of(game.type);
    final arcade = game.type == StudyGameType.endlessQuiz ? (style ?? QuizGameStyle.balloons) : null;
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
              Text(arcade == null ? _Palette.emoji(game.type) : _ArcadeInfo.emoji(arcade),
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  arcade == null ? game.title : _ArcadeInfo.title(arcade),
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
            arcade == null ? game.instructions : _ArcadeInfo.hint(arcade),
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
              ArcadeQuizGame(
                game: game,
                style: arcade!,
                onWin: onWin,
                onReplay: onReplay,
                onNeedMore: onNeedMore,
              ),
            StudyGameType.tracing =>
              TracingGame(
                game: game,
                onTraced: (item) async => onTraced?.call(item),
              ),
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
      StudentSoundService.instance.playCheer();
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
    // ‏ضغطةٌ قصيرة ثم سحب: السحبُ الفوريّ كان ينازع التمريرَ في القائمة،
    // ‏فتتحرّك الصفحةُ حين يريد الطفلُ أن يحمل البطاقة. وما دون ذلك لمسةٌ
    // ‏تختار البطاقة (البديلُ بالضغط).
    return LongPressDraggable<String>(
      data: label,
      delay: const Duration(milliseconds: 150),
      hapticFeedbackOnStart: true,
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
      StudentSoundService.instance.playCheer();
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
// ٣) ألعابُ الأسئلة: بالوناتٌ وصيدٌ وقطارٌ ومقلاع
// ─────────────────────────────────────────────────────────────────────

/// ألعابُ الأسئلة الأربع: اسمُ كلٍّ منها ورمزُها وألوانُها ورسمتُها.
class _ArcadeInfo {
  static String emoji(QuizGameStyle style) => switch (style) {
        QuizGameStyle.balloons => '🎈',
        QuizGameStyle.fishing => '🎣',
        QuizGameStyle.train => '🚂',
        QuizGameStyle.slingshot => '🎯',
      };

  static String title(QuizGameStyle style) => tr('study.games.arcade.${style.name}');

  static String hint(QuizGameStyle style) => tr('study.games.arcade.${style.name}Hint');

  static List<Color> colors(QuizGameStyle style) => switch (style) {
        QuizGameStyle.balloons => const [Color(0xFFEC4899), Color(0xFFF59E0B)],
        QuizGameStyle.fishing => const [Color(0xFF0284C7), Color(0xFF14B8A6)],
        QuizGameStyle.train => const [Color(0xFFDC2626), Color(0xFFF97316)],
        QuizGameStyle.slingshot => const [Color(0xFF7C3AED), Color(0xFF16A34A)],
      };

  /// رسومُ التطبيق نفسها خلف البطاقة — لا صورٌ جديدة.
  static String art(QuizGameStyle style) => style == QuizGameStyle.train ? quizClassroomArt : quizSkyArt;
}

/// رفُّ ألعاب الأسئلة: أربعُ بطاقاتٍ، كلٌّ منها تلعب أسئلةَ الدرس بطريقتها.
class _ArcadeShelf extends StatelessWidget {
  const _ArcadeShelf({required this.game, required this.onOpen});

  final StudyGame game;
  final ValueChanged<QuizGameStyle> onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _Bouncing(child: Text('🎮', style: TextStyle(fontSize: 22))),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('study.games.arcade.title'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: StudentSurface.ink(context)),
                ),
              ),
              Text(
                trf('study.games.reward', {'gems': game.gemsReward, 'points': game.pointsReward}),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _Palette.gold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, box) {
            final columns = box.maxWidth >= 640 ? 4 : 2;
            final width = (box.maxWidth - 12 * (columns - 1)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final style in QuizGameStyle.values)
                  SizedBox(
                    width: width,
                    child: _ArcadeCard(style: style, index: style.index, onTap: () => onOpen(style)),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _ArcadeCard extends StatelessWidget {
  const _ArcadeCard({required this.style, required this.index, required this.onTap});

  final QuizGameStyle style;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _ArcadeInfo.colors(style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + index * 120),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.8 + 0.2 * t, child: child),
      ),
      child: Semantics(
        button: true,
        label: _ArcadeInfo.title(style),
        child: _PressScale(
          onTap: onTap,
          child: Container(
            key: ValueKey('arcade-${style.name}'),
            height: 158,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(color: Color.lerp(colors.first, Colors.black, 0.4)!, offset: const Offset(0, 5)),
                BoxShadow(color: colors.first.withValues(alpha: 0.4), blurRadius: 16),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    _ArcadeInfo.art(style),
                    fit: BoxFit.cover,
                    cacheWidth: 400,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [colors.first.withValues(alpha: 0.55), colors.last.withValues(alpha: 0.92)],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Bouncing(
                          delay: Duration(milliseconds: index * 260),
                          child: Text(_ArcadeInfo.emoji(style), style: const TextStyle(fontSize: 44)),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _ArcadeInfo.title(style),
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _ArcadeInfo.hint(style),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// أسئلةُ الدرس لعبةً: [goal] سؤالاً، كلٌّ منها في [style] — بالونٌ يُفقع أو
/// سمكةٌ تُصطاد أو صندوقٌ يُحمَّل أو هدفٌ يُصاب.
///
/// والفوزُ إصابةُ ثلاثة أخماسها: تُصرف المكافأةُ مرّةً، ويُعاد اللعبُ ما شاء.
class ArcadeQuizGame extends StatefulWidget {
  const ArcadeQuizGame({
    required this.game,
    required this.style,
    required this.onWin,
    required this.onReplay,
    this.onNeedMore,
    super.key,
  });

  final StudyGame game;
  final QuizGameStyle style;
  final Future<void> Function() onWin;
  final VoidCallback onReplay;

  /// أسئلةٌ جديدة من الذكاء الاصطناعي حين تقلّ أسئلةُ الدرس عن الجولة.
  final Future<List<StudyQuickQuestion>> Function(List<String> shown)? onNeedMore;

  @override
  State<ArcadeQuizGame> createState() => _ArcadeQuizGameState();
}

class _ArcadeQuizGameState extends State<ArcadeQuizGame> {
  static const _maxGoal = 8;
  final _random = math.Random();
  late List<StudyQuickQuestion> _deck = [...widget.game.questions]..shuffle(_random);
  late final int goal = math.min(_maxGoal, math.max(4, widget.game.questions.length));
  late StudyQuickQuestion? _question = _deck.isEmpty ? null : _deck.first;
  late List<String> _options = _question == null ? const [] : _optionsFor(_question!);
  final _results = <bool>[];
  bool _won = false;

  int get _correct => _results.where((right) => right).length;
  int get _needed => (goal * 0.6).ceil();
  bool get _over => _results.length >= goal;

  @override
  void initState() {
    super.initState();
    _topUp();
  }

  /// أسئلةُ الدرس أقلُّ من الجولة: تُطلب أخرى جديدة، وإلى أن تصل تدور هي.
  void _topUp() {
    final more = widget.onNeedMore;
    if (more == null || _deck.isEmpty || _deck.length >= goal) return;
    more([for (final q in _deck) q.question]).then((fresh) {
      if (!mounted) return;
      final known = {for (final q in _deck) q.question};
      final added = [for (final q in fresh) if (!known.contains(q.question)) q]..shuffle(_random);
      if (added.isNotEmpty) setState(() => _deck = [..._deck, ...added]);
    }).catchError((_) {
      // ‏تعذّرت الدفعة: تدور أسئلةُ الدرس.
    });
  }

  /// ‏صح/خطأ بترتيبهما الثابت — «صح» أوّلاً دائماً — وما سواهما يُخلط.
  List<String> _optionsFor(StudyQuickQuestion question) =>
      question.kind == StudyQuestionKind.trueFalse
          ? [...question.options]
          : ([...question.options]..shuffle(_random));

  void _answered(String option) {
    final question = _question;
    if (question == null || _over) return;
    final right = option == question.answer;
    setState(() {
      _results.add(right);
      if (!_over) {
        _question = _deck[_results.length % _deck.length];
        _options = _optionsFor(_question!);
      }
    });
    if (_over && _correct >= _needed && !_won) {
      _won = true;
      unawaited(widget.onWin());
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = _question;
    if (question == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          _ArcadeProgress(results: _results, goal: goal),
          const SizedBox(height: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(animation), child: child),
              ),
              child: _over
                  ? _ArcadeResult(
                      key: const ValueKey('arcade-result'),
                      correct: _correct,
                      goal: goal,
                      needed: _needed,
                      onReplay: widget.onReplay,
                    )
                  : KeyedSubtree(
                      key: ValueKey('arcade-q-${_results.length}'),
                      child: quizGameFor(
                        widget.style,
                        prompt: question.question,
                        options: _options,
                        isCorrect: (option) => option == question.answer,
                        onAnswered: _answered,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// نجومُ الجولة: نجمةٌ لكل إصابة، ونقطةٌ باهتةٌ لما لم يُصب، والسؤالُ الحاليّ متوهّج.
class _ArcadeProgress extends StatelessWidget {
  const _ArcadeProgress({required this.results, required this.goal});

  final List<bool> results;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final at = math.min(results.length + 1, goal);
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 0; i < goal; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < results.length
                        ? (results[i] ? const Color(0xFFFEF3C7) : StudentSurface.mutedInk(context).withValues(alpha: 0.12))
                        : StudentSurface.card(context),
                    border: Border.all(
                      color: i == results.length ? _Palette.violet : _Palette.gold.withValues(alpha: 0.5),
                      width: i == results.length ? 2.5 : 1.2,
                    ),
                  ),
                  child: i < results.length
                      ? _PopIn(child: Text(results[i] ? '⭐' : '•', style: const TextStyle(fontSize: 14)))
                      : null,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          trf('study.games.arcade.progress', {'n': at, 'total': goal}),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: StudentSurface.ink(context)),
        ),
      ],
    );
  }
}

class _ArcadeResult extends StatelessWidget {
  const _ArcadeResult({
    required this.correct,
    required this.goal,
    required this.needed,
    required this.onReplay,
    super.key,
  });

  final int correct;
  final int goal;
  final int needed;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final won = correct >= needed;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Bouncing(child: Text(won ? '🏆' : '💪', style: const TextStyle(fontSize: 64))),
            const SizedBox(height: 8),
            Text(
              trf('study.games.arcade.result', {'n': correct, 'total': goal}),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: StudentSurface.ink(context)),
            ),
            const SizedBox(height: 6),
            Text(
              won ? tr('study.games.arcade.won') : trf('study.games.arcade.retry', {'n': needed}),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w800, color: StudentSurface.mutedInk(context)),
            ),
            const SizedBox(height: 18),
            _GameButton(label: tr('study.games.playAgain'), color: _Palette.violet, onPressed: onReplay),
          ],
        ),
      ),
    );
  }
}

/// لعبةٌ في صفحةٍ كاملةٍ فوق صفحة المذاكرة: «العب مرة أخرى» نسخةٌ جديدة فيها،
/// والرجوعُ إلى الرفّ رجوعٌ إلى الصفحة.
class _GamePage extends StatefulWidget {
  const _GamePage({
    required this.first,
    required this.style,
    required this.replay,
    required this.onWin,
    this.onTraced,
    this.onNeedMore,
  });

  final StudyGame first;
  final QuizGameStyle? style;
  final Future<StudyGame?> Function() replay;
  final Future<void> Function(StudyGame game) onWin;
  final StudyTracingWin? onTraced;
  final Future<List<StudyQuickQuestion>> Function(List<String> shown)? onNeedMore;

  @override
  State<_GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<_GamePage> {
  late StudyGame _game = widget.first;
  int _round = 0;
  bool _preparing = false;

  Future<void> _replay() async {
    if (_preparing) return;
    setState(() => _preparing = true);
    final next = await widget.replay();
    if (!mounted) return;
    setState(() {
      _preparing = false;
      if (next != null) _game = next;
      _round += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return Scaffold(
      backgroundColor: StudentSurface.ground(context),
      body: SafeArea(
        child: _preparing
            ? const Center(child: _Bouncing(child: Text('✨', style: TextStyle(fontSize: 54))))
            : _GameStage(
                key: ValueKey('page-game-${game.id}-$_round'),
                game: game,
                style: widget.style,
                onBack: () => Navigator.of(context).maybePop(),
                onReplay: _replay,
                onWin: () => widget.onWin(game),
                onTraced: (item) async => widget.onTraced?.call(game, item),
                onNeedMore: widget.onNeedMore,
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
/// يصغر تحت الإصبع ويهتزّ بلمسةٍ خفيفة، ثم يرتدّ — لكل بطاقةٍ في الرفّ.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutBack,
          child: widget.child,
        ),
      );
}

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
  const _PopIn({required this.child});

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
