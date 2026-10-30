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
import 'student_experience.dart';

/// يصرف مكافأة لعبةٍ فاز بها الطفل — الخادمُ يقرّر المقدار من سجلّ الدرس.
typedef StudyGameWin = Future<RewardResult?> Function(StudyGame game);

/// أسئلةُ الألعاب الأربع من حزمة الدرس.
///
/// أسئلةُ السباق كما ولّدها الذكاءُ الاصطناعيّ من نصّ الدرس الذي أدخله
/// المعلّم (اختيارٌ من متعدّد، وصحٌّ وخطأ، وأكمل الفراغ)، ومعها أسئلةٌ تُبنى
/// من أزواج التصنيف والمطابقة في الحزمة نفسها («القطّ من أيّ مجموعة؟»
/// وخياراتُه المجموعات) — فتتنوّع الأسئلة، ولا يبقى درسٌ بلا لعبٍ إن غاب
/// السباق. و`null` إن لم يكن في الحزمة سؤالٌ واحد.
StudyGame? arcadeGameOf(StudyGamesPack pack) {
  StudyGame? quiz;
  for (final game in pack.games) {
    if (game.type == StudyGameType.endlessQuiz) {
      quiz = game;
      break;
    }
  }
  final derived = [for (final game in pack.games) ...pairQuestionsOf(game)];
  final base = quiz ??
      [for (final game in pack.games) if (game.pairs.isNotEmpty) game].firstOrNull;
  final questions = [...?quiz?.questions, ...derived];
  if (base == null || questions.isEmpty) return null;
  return base.withQuestions(questions);
}

/// أسئلةٌ من أزواج لعبةِ تصنيفٍ أو مطابقة: لكل بطاقةٍ سؤالٌ خياراتُه سلّتُها
/// وما سواها من السلال (أربعٌ على الأكثر).
List<StudyQuickQuestion> pairQuestionsOf(StudyGame game) {
  final sort = game.type == StudyGameType.dragDrop;
  if (!sort && game.type != StudyGameType.matching) return const [];
  final targets = <String>{...game.dropTargets, for (final pair in game.pairs) pair.target}.toList();
  if (targets.length < 2) return const [];
  return [
    for (final pair in game.pairs)
      StudyQuickQuestion(
        question: trf(sort ? 'study.games.ask.sort' : 'study.games.ask.match', {'item': pair.item}),
        options: [
          pair.target,
          for (var k = 1; k < math.min(targets.length, 4); k++)
            targets[(targets.indexOf(pair.target) + k) % targets.length],
        ],
        answer: pair.target,
      ),
  ];
}

/// «ألعاب الدرس» في بطاقة المذاكرة: أربعُ ألعابٍ تفاعليةٍ وحدها — البالونات
/// المتفجّرة، والصيدُ البحريّ، وقطارُ الإجابات السعيد، والمقلاعُ الذكيّ —
/// تُلعب فيها أسئلةُ الدرس ([arcadeGameOf]).
///
/// الرفُّ أغلفةٌ مجسّمةٌ بطوله في صفحة المذاكرة (تمرّره الصفحة)، وكلُّ لعبةٍ
/// تُفتح في صفحةٍ كاملةٍ فوقها، بشريطٍ علويٍّ ثابتٍ يُنتقل منه إلى أيّ لعبةٍ
/// أخرى فوراً بلا رجوع.
class StudyGamesTab extends StatefulWidget {
  const StudyGamesTab({
    required this.load,
    required this.onWin,
    this.fresh,
    this.seenKey,
    this.cached,
    super.key,
  });

  final Future<StudyGamesPack> Function() load;

  /// الحزمةُ المحفوظة على الجهاز: تُعرض فوراً، وتحلّ محلّها [load] حين تصل.
  final Future<StudyGamesPack?> Function()? cached;
  final StudyGameWin onWin;

  /// نسخةٌ جديدة من أسئلة الدرس، متجنّبةً ما رآه الطالب — من الذكاء الاصطناعي.
  final Future<StudyGame> Function(StudyGame base, List<String> exclude)? fresh;

  /// مفتاحُ ما رآه هذا الطالب في هذا الدرس على الجهاز (`study.seen.<طالب>.<درس>`).
  final String? seenKey;

  @override
  State<StudyGamesTab> createState() => _StudyGamesTabState();
}

class _StudyGamesTabState extends State<StudyGamesTab> {
  StudyGamesPack? _pack;
  String? _error;
  bool _loading = true;

  /// تُحضَّر أسئلةٌ جديدة الآن.
  bool _preparing = false;

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
        _pack = saved;
        _loading = false;
      });
    }
    try {
      final pack = await widget.load();
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

  // ── لا تتكرّر الأسئلة ──
  // الحزمةُ المحفوظة مع الدرس تُلعب أوّلَ مرّة. وكلُّ لعبٍ بعدها — ولو في
  // جلسةٍ أخرى — يطلب من الذكاء الاصطناعي أسئلةً جديدة من النصّ الكامل للدرس،
  // ويُرسل معها ما رآه الطالب فيتجنّبه. وما رآه محفوظٌ على الجهاز لكل طالبٍ
  // ودرس. وتعذُّرُ الجديدة لا يمنع اللعب: تُلعب المحفوظة.
  static const _maxSeen = 300;

  String? get _seenKey =>
      widget.seenKey == null ? null : '${widget.seenKey}.${StudyGameType.endlessQuiz.wire}';

  Future<List<String>> _loadSeen() async {
    final key = _seenKey;
    if (key == null) return const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(key) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _addSeen(Iterable<String> items) async {
    final key = _seenKey;
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
      // تخزينٌ محجوب: تُطلب أسئلةٌ جديدة بلا قائمة تجنّب.
    }
  }

  /// ما يعدّه الطالبُ «رآه» من لعبة: أسئلتُها.
  static List<String> seenItemsOf(StudyGame game) => [for (final q in game.questions) q.question];

  /// لعبةُ السباق في الحزمة: أصلُ ما يُطلب من جديد.
  StudyGame? get _quizBase {
    for (final game in _pack?.games ?? const <StudyGame>[]) {
      if (game.type == StudyGameType.endlessQuiz) return game;
    }
    return null;
  }

  /// الأسئلةُ كما تُلعب الآن: المحفوظةُ أوّلَ مرّة، ثم جديدةٌ لا تكرّر ما رآه.
  Future<StudyGame?> _choose() async {
    final pack = _pack;
    if (pack == null) return null;
    var chosen = arcadeGameOf(pack);
    if (chosen == null) return null;
    final seen = await _loadSeen();
    final fresh = widget.fresh;
    final base = _quizBase;
    if (seen.isNotEmpty && fresh != null && base != null) {
      if (!mounted) return null;
      setState(() => _preparing = true);
      try {
        final next = await fresh(base, seen);
        chosen = next.withQuestions([...next.questions, for (final game in pack.games) ...pairQuestionsOf(game)]);
      } catch (_) {
        // ‏تُلعب المحفوظة.
      }
      if (mounted) setState(() => _preparing = false);
    }
    final picked = chosen;
    if (!mounted || picked == null) return null;
    unawaited(_addSeen(seenItemsOf(picked)));
    return picked;
  }

  Future<void> _open(QuizGameStyle style) async {
    if (_preparing) return;
    StudentSoundService.instance.playTap();
    final chosen = await _choose();
    if (chosen == null || !mounted) return;
    final direction = Directionality.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (page) => Directionality(
          textDirection: direction,
          child: _GamePage(
            first: chosen,
            style: style,
            replay: _choose,
            onWin: _won,
            onNeedMore: widget.fresh == null ? null : _moreQuestions,
          ),
        ),
      ),
    );
  }

  /// أسئلةٌ جديدة حين يقترب الطالب من آخر ما عنده — لا يدور على المكرّر.
  Future<List<StudyQuickQuestion>> _moreQuestions(List<String> shown) async {
    final fresh = widget.fresh;
    final base = _quizBase;
    if (fresh == null || base == null) return const [];
    final seen = {...await _loadSeen(), ...shown}.toList();
    final game = await fresh(base, seen);
    unawaited(_addSeen(seenItemsOf(game)));
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
    if (_loading) {
      return _Waiting(emoji: '🎲', text: tr('study.games.loading'));
    }
    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧩', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.6, fontWeight: FontWeight.w800, color: StudentSurface.ink(context)),
            ),
            const SizedBox(height: 16),
            _GameButton(label: tr('study.again'), color: _Palette.violet, onPressed: _fetch),
          ],
        ),
      );
    }
    final pack = _pack;
    final arcade = pack == null ? null : arcadeGameOf(pack);
    if (arcade == null) return const SizedBox.shrink();
    if (_preparing) return _Waiting(emoji: '✨', text: tr('study.games.fresh'));
    return _ArcadeShelf(game: arcade, onOpen: _open);
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.emoji, required this.text});

  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Bouncing(child: Text(emoji, style: const TextStyle(fontSize: 54))),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: StudentSurface.ink(context)),
          ),
        ],
      ),
    );
  }
}

class _Palette {
  static const violet = Color(0xFF7C3AED);
  static const gold = Color(0xFFF59E0B);
}

// ─────────────────────────────────────────────────────────────────────
// الرفّ: أربعةُ أغلفةٍ مجسّمة
// ─────────────────────────────────────────────────────────────────────

/// ألعابُ الأسئلة الأربع: اسمُ كلٍّ منها ورمزُها وألوانُها.
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
}

/// رفُّ ألعاب الأسئلة: أربعةُ أغلفةٍ، كلٌّ منها يلعب أسئلةَ الدرس بطريقته.
class _ArcadeShelf extends StatelessWidget {
  const _ArcadeShelf({required this.game, required this.onOpen});

  final StudyGame game;
  final ValueChanged<QuizGameStyle> onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _Bouncing(child: Text('🎮', style: TextStyle(fontSize: 24))),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('study.games.arcade.title'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: StudentSurface.ink(context)),
                ),
              ),
              Text(
                trf('study.games.reward', {'gems': game.gemsReward, 'points': game.pointsReward}),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _Palette.gold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, box) {
            final columns = box.maxWidth >= 640 ? 4 : 2;
            const gap = 14.0;
            final width = (box.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap + 6,
              children: [
                for (final style in QuizGameStyle.values)
                  SizedBox(
                    width: width,
                    child: _ArcadeCover(style: style, onTap: () => onOpen(style)),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// غلافُ لعبةٍ مجسّم: لوحٌ مائلٌ بمنظورٍ على حافّةٍ سميكةٍ أغمق، فيه خلفيةُ
/// اللعبة نفسها، وبطلُها (بالونات، سمكة، قطار، هدف) يبرز من فوق إطاره ويطفو،
/// وشريطُ اسمها في أسفله. تحت الإصبع يستوي اللوحُ وينضغط.
class _ArcadeCover extends StatefulWidget {
  const _ArcadeCover({required this.style, required this.onTap});

  final QuizGameStyle style;
  final VoidCallback onTap;

  @override
  State<_ArcadeCover> createState() => _ArcadeCoverState();
}

class _ArcadeCoverState extends State<_ArcadeCover> with SingleTickerProviderStateMixin {
  late final AnimationController _float =
      AnimationController(vsync: this, duration: Duration(milliseconds: 2300 + widget.style.index * 260));
  bool _down = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _float
        ..stop()
        ..value = 0.5;
    } else if (!_float.isAnimating) {
      _float.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final colors = _ArcadeInfo.colors(style);
    final ledge = Color.lerp(colors.first, Colors.black, 0.42)!;
    return Semantics(
      button: true,
      label: _ArcadeInfo.title(style),
      child: GestureDetector(
        key: ValueKey('arcade-${style.name}'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          setState(() => _down = true);
        },
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _float,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_float.value);
            final tilt = _down ? 0.0 : 0.16;
            return Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0014)
                ..rotateX(tilt)
                ..multiply(Matrix4.diagonal3Values(_down ? 0.96 : 1.0, _down ? 0.96 : 1.0, 1)),
              child: SizedBox(
                height: 214,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ‏اللوحُ على حافّته.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 34,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.only(bottom: _down ? 3 : 8),
                        decoration: BoxDecoration(
                          color: ledge,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(color: colors.first.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 10)),
                          ],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(23),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(
                                  QuizGameArt.background(style),
                                  fit: BoxFit.cover,
                                  cacheWidth: 480,
                                  errorBuilder: (_, __, ___) => ColoredBox(color: colors.last),
                                ),
                                // ‏لمعةُ زجاجٍ مائلة.
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.32),
                                        Colors.white.withValues(alpha: 0.0),
                                        colors.last.withValues(alpha: 0.15),
                                      ],
                                      stops: const [0, 0.45, 1],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [colors.first, colors.last]),
                                      border: const Border(top: BorderSide(color: Colors.white, width: 2)),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '${_ArcadeInfo.emoji(style)} ${_ArcadeInfo.title(style)}',
                                            maxLines: 1,
                                            style: const TextStyle(
                                              fontSize: 19,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              shadows: [Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _ArcadeInfo.hint(style),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // ‏بطلُ اللعبة يبرز من فوق الإطار ويطفو.
                    Positioned(
                      left: 8,
                      right: 8,
                      top: -6 + t * 8,
                      height: 128,
                      child: IgnorePointer(child: QuizGameCoverArt(style: style)),
                    ),
                    // ‏زرُّ اللعب.
                    PositionedDirectional(
                      end: 10,
                      top: 44,
                      child: Transform.scale(
                        scale: 0.94 + t * 0.12,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [BoxShadow(color: ledge.withValues(alpha: 0.6), offset: const Offset(0, 3))],
                          ),
                          child: Icon(Icons.play_arrow_rounded, color: colors.first, size: 30),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// صفحةُ اللعب: شريطُ الألعاب الأربع ثابتاً، ثم الجولة
// ─────────────────────────────────────────────────────────────────────

/// لعبةٌ في صفحةٍ كاملةٍ فوق صفحة المذاكرة. الشريطُ العلويّ ثابتٌ فيه الألعابُ
/// الأربع: لمسةٌ تنقل إلى غيرها بأسئلة الدرس نفسها، بلا رجوعٍ إلى البطاقة.
/// و«العب مرة أخرى» أسئلةٌ جديدة.
///
/// ── مقدّمةٌ لا دخولٌ مفاجئ ──
/// كلُّ لعبةٍ تُفتح — أوّلَ مرّةٍ أو انتقالاً من أخرى — على شاشةٍ قصيرةٍ
/// تُقدّمها بعبارتها المسجّلة ([QuizGameArt.intro])، ثم تبدأ حين تنتهي
/// العبارة. ولمسةُ «هيا نلعب!» تبدأها قبل ذلك.
class _GamePage extends StatefulWidget {
  const _GamePage({
    required this.first,
    required this.style,
    required this.replay,
    required this.onWin,
    this.onNeedMore,
  });

  final StudyGame first;
  final QuizGameStyle style;
  final Future<StudyGame?> Function() replay;
  final Future<void> Function(StudyGame game) onWin;
  final Future<List<StudyQuickQuestion>> Function(List<String> shown)? onNeedMore;

  @override
  State<_GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<_GamePage> {
  late StudyGame _game = widget.first;
  late QuizGameStyle _style = widget.style;
  int _round = 0;
  bool _preparing = false;

  /// شاشةُ المقدّمة ظاهرة.
  bool _intro = true;
  bool _introHeard = false;
  bool _introSeen = false;
  Timer? _introMin;
  Timer? _introCap;

  /// أقصرُ ما تبقى المقدّمة (تُرى ولو كان الصوتُ مكتوماً)، وأطولُ ما تنتظر
  /// العبارةَ إن لم يُعلَم انتهاؤها.
  static const _introShortest = Duration(milliseconds: 1800);
  static const _introLongest = Duration(seconds: 7);

  @override
  void initState() {
    super.initState();
    _beginIntro();
  }

  @override
  void dispose() {
    _introMin?.cancel();
    _introCap?.cancel();
    StudentSoundService.instance.stopGameSounds();
    super.dispose();
  }

  void _beginIntro() {
    _introMin?.cancel();
    _introCap?.cancel();
    _intro = true;
    _introHeard = false;
    _introSeen = false;
    final style = _style;
    _introMin = Timer(_introShortest, () {
      _introSeen = true;
      _maybeStart();
    });
    _introCap = Timer(_introLongest, _startGame);
    StudentSoundService.instance.playGameIntro(
      QuizGameArt.intro(style),
      onComplete: () {
        // ‏عبارةُ لعبةٍ تُركت قبل أن تنتهي لا تبدأ غيرها.
        if (style != _style) return;
        _introHeard = true;
        _maybeStart();
      },
    );
  }

  void _maybeStart() {
    if (_introHeard && _introSeen) _startGame();
  }

  void _startGame() {
    _introMin?.cancel();
    _introCap?.cancel();
    if (!mounted || !_intro) return;
    setState(() => _intro = false);
  }

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

  void _switch(QuizGameStyle style) {
    if (style == _style) return;
    StudentSoundService.instance.playTap();
    setState(() {
      _style = style;
      _round += 1;
      _beginIntro();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ArcadeInfo.colors(_style);
    return Scaffold(
      backgroundColor: Color.lerp(colors.last, Colors.white, 0.82),
      body: SafeArea(
        child: Column(
          children: [
            _GameBar(
              style: _style,
              onBack: () => Navigator.of(context).maybePop(),
              onPick: _switch,
            ),
            Expanded(
              child: _intro
                  ? _GameIntro(key: ValueKey('intro-${_style.name}'), style: _style, onStart: _startGame)
                  : _preparing
                  ? _Waiting(emoji: '✨', text: tr('study.games.fresh'))
                  : ArcadeQuizGame(
                      key: ValueKey('arcade-${_style.name}-$_round'),
                      game: _game,
                      style: _style,
                      onWin: () => widget.onWin(_game),
                      onReplay: _replay,
                      onNeedMore: widget.onNeedMore,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// مقدّمةُ اللعبة: خلفيتُها وبطلُها يقفز إلى الشاشة، واسمُها كبيراً ودعوتُها،
/// وزرُّ «هيا نلعب!» ينبض — والعبارةُ المسجّلة تُسمع.
class _GameIntro extends StatefulWidget {
  const _GameIntro({required this.style, required this.onStart, super.key});

  final QuizGameStyle style;
  final VoidCallback onStart;

  @override
  State<_GameIntro> createState() => _GameIntroState();
}

class _GameIntroState extends State<_GameIntro> with TickerProviderStateMixin {
  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _enter.value = 1;
      _pulse.stop();
    } else {
      if (_enter.value == 0 && !_enter.isAnimating) _enter.forward();
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final colors = _ArcadeInfo.colors(style);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onStart,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(QuizGameArt.background(style), fit: BoxFit.cover, cacheWidth: 1280),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [colors.first.withValues(alpha: 0.25), colors.last.withValues(alpha: 0.75)],
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: Listenable.merge([_enter, _pulse]),
                builder: (context, _) {
                  final t = Curves.elasticOut.transform(_enter.value);
                  final fade = Curves.easeOut.transform(_enter.value);
                  final beat = Curves.easeInOut.transform(_pulse.value);
                  return LayoutBuilder(builder: (context, box) {
                    final art = (box.maxHeight * 0.36).clamp(90.0, 220.0).toDouble();
                    final title = (box.maxWidth / 14).clamp(28.0, 52.0).toDouble();
                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.scale(
                              scale: 0.4 + 0.6 * t,
                              child: SizedBox(height: art, width: art * 1.8, child: QuizGameCoverArt(style: style)),
                            ),
                            const SizedBox(height: 10),
                            Opacity(
                              opacity: fade,
                              child: Text(
                                '${_ArcadeInfo.emoji(style)} ${_ArcadeInfo.title(style)}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: title,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 10, offset: Offset(0, 3))],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Opacity(
                              opacity: fade,
                              child: Text(
                                _ArcadeInfo.hint(style),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: title * 0.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 8)],
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Transform.scale(
                              scale: 0.94 + beat * 0.1,
                              child: Semantics(
                                button: true,
                                child: GestureDetector(
                                  key: const ValueKey('game-intro-start'),
                                  onTap: widget.onStart,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: colors.first, width: 3),
                                      boxShadow: [BoxShadow(color: Color.lerp(colors.first, Colors.black, 0.4)!, offset: const Offset(0, 5))],
                                    ),
                                    child: Text(
                                      tr('study.games.intro.start'),
                                      style: TextStyle(fontSize: title * 0.55, fontWeight: FontWeight.w900, color: colors.first),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// الشريطُ العلويّ الثابت: الرجوعُ، والألعابُ الأربع (المفتوحةُ ملوّنةٌ
/// بلونها)، وزرُّ الصوت.
class _GameBar extends StatelessWidget {
  const _GameBar({required this.style, required this.onBack, required this.onPick});

  final QuizGameStyle style;
  final VoidCallback onBack;
  final ValueChanged<QuizGameStyle> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const BackButtonIcon(),
            color: const Color(0xFF1E293B),
          ),
          Expanded(
            // ‏على هاتفٍ ضيّق: رمزُ اللعبة كبيراً وحده، واسمُها يُقرأ لقارئ الشاشة.
            child: LayoutBuilder(builder: (context, box) {
              final compact = box.maxWidth < 440;
              return Row(
                children: [
                  for (final each in QuizGameStyle.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _BarChip(style: each, selected: each == style, compact: compact, onTap: () => onPick(each)),
                      ),
                    ),
                ],
              );
            }),
          ),
          const StudentSoundToggle(),
        ],
      ),
    );
  }
}

class _BarChip extends StatelessWidget {
  const _BarChip({required this.style, required this.selected, required this.compact, required this.onTap});

  final QuizGameStyle style;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _ArcadeInfo.colors(style);
    return Semantics(
      button: true,
      selected: selected,
      label: _ArcadeInfo.title(style),
      child: GestureDetector(
        key: ValueKey('switch-${style.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: selected ? LinearGradient(colors: colors) : null,
            color: selected ? null : colors.first.withValues(alpha: 0.09),
            border: Border.all(color: selected ? Colors.white : colors.first.withValues(alpha: 0.35), width: 2),
            boxShadow: selected
                ? [BoxShadow(color: Color.lerp(colors.first, Colors.black, 0.4)!, offset: const Offset(0, 3))]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_ArcadeInfo.emoji(style), style: TextStyle(fontSize: compact ? 26 : 22)),
                if (!compact) ...[
                  const SizedBox(width: 5),
                  Text(
                    _ArcadeInfo.title(style),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: selected ? Colors.white : colors.first,
                    ),
                  ),
                ],
              ],
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
  const _Bouncing({required this.child});

  final Widget child;

  @override
  State<_Bouncing> createState() => _BouncingState();
}

class _BouncingState extends State<_Bouncing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (still) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
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
