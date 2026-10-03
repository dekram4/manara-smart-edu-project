import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/student_strings.dart';
import '../models/duel_question.dart';
import '../models/student_profile.dart';
import '../services/duel_live_controller.dart';
import '../services/student_duel_service.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import '../widgets/arena_widgets.dart';
import '../widgets/duel_arenas.dart';
import '../widgets/duel_chat_mixin.dart';
import '../widgets/duel_versus.dart';
import '../widgets/student_avatar_view.dart';
import '../widgets/student_experience.dart';

/// غرفةُ النزال: المواجهة، ثم الأسئلة، ثم النتيجة — والدردشةُ معها.
///
/// المنطقُ كلُّه في [DuelLiveController] — الساعةُ والإشاراتُ والخادم — وعليه
/// اختباراته. وهذه الشاشةُ ترسمه وتُسمعه.
class DuelMatchScreen extends StatefulWidget {
  const DuelMatchScreen({
    required this.profile,
    required this.duelService,
    required this.matchId,
    required this.rivalId,
    required this.rivalName,
    required this.isHost,
    this.game = DuelGame.sprint,
    this.rivalAppearance,
    this.rivals = const [],
    this.transport,
    super.key,
  });

  /// كلُّ المنافسين في تحدٍّ جماعي. فارغةٌ في نزالٍ بين اثنين: [rivalId] وحده.
  final List<DuelRival> rivals;

  final StudentProfile profile;
  final StudentDuelService duelService;
  final String matchId;
  final String rivalId;
  final String rivalName;
  final Map<String, dynamic>? rivalAppearance;

  /// الداعي: ساعةُ المباراة عنده. انظر [DuelLiveController].
  final bool isHost;

  /// اللعبةُ التي اختارها الداعي: تُغيّر الحلبةَ وشكلَ الخيارات، والمحرّكُ واحد.
  final DuelGame game;

  /// الخادمُ وقناةُ المباراة. الخدمةُ نفسها في التطبيق، ومُحاكىً في الاختبار.
  @visibleForTesting
  final DuelLiveTransport? transport;

  @override
  State<DuelMatchScreen> createState() => _DuelMatchScreenState();
}

class _DuelMatchScreenState extends State<DuelMatchScreen>
    with DuelChatMixin<DuelMatchScreen> {
  late final DuelLiveController _game = DuelLiveController(
    transport: widget.transport ?? ServiceDuelTransport(widget.duelService),
    matchId: widget.matchId,
    myId: widget.profile.id,
    rivalId: widget.rivalId,
    rivalIds: [for (final rival in _allRivals) rival.id],
    isHost: widget.isHost,
  );

  List<DuelRival> get _allRivals => widget.rivals.isNotEmpty
      ? widget.rivals
      : [
          DuelRival(
            id: widget.rivalId,
            name: widget.rivalName,
            appearance: widget.rivalAppearance,
          ),
        ];

  DuelRival? _rivalById(String id) {
    for (final rival in _allRivals) {
      if (rival.id == id) return rival;
    }
    return null;
  }

  String _nameOf(String id) {
    if (id == widget.profile.id) return tr('duel.you');
    final name = _rivalById(id)?.name ?? '';
    return name.isEmpty ? tr('duel.rival') : name;
  }

  Map<String, dynamic>? _lookOf(String id) => id == widget.profile.id
      ? widget.profile.appearance
      : _rivalById(id)?.appearance;

  /// تحدٍّ جماعي: أكثرُ من منافسٍ واحد.
  bool get _party => _game.rivals.length > 1;

  /// المنافسُ المتقدّم: هو من تُرسم أمامه الحلبةُ وشريطُ المواجهة.
  String get _leaderName => _nameOf(_game.leaderId);
  Map<String, dynamic>? get _leaderLook => _lookOf(_game.leaderId);

  /// يُغلق الشاشةَ مرّةً بعد أن يُقال للطفل إنّ أحداً لم يوافق.
  bool _autoClosing = false;

  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(milliseconds: 900));

  DuelPhase? _lastPhase;
  int _lastCountdown = -1;
  QuestionWinner _lastWinner = QuestionWinner.none;
  bool? _lastCorrect;

  @override
  StudentDuelService get chatService => widget.duelService;
  @override
  String get chatMyId => widget.profile.id;
  @override
  String get chatMatchId => widget.matchId;
  @override
  Map<String, dynamic>? get chatMyAppearance => widget.profile.appearance;
  @override
  Map<String, dynamic>? get chatRivalAppearance => _leaderLook;

  @override
  void initState() {
    super.initState();
    _game.addListener(_onGame);
    initChat();
    unawaited(_connect());
  }

  Future<void> _connect() async {
    await widget.duelService.watchMatch(
      matchId: widget.matchId,
      onProgress: (_, __) {},
      onChat: onChatMessage,
      onMute: onRivalMute,
      onSignal: _game.onSignal,
    );
    if (mounted) await _game.start();
  }

  /// الأصواتُ والاهتزاز على ما يتغيّر — لا على كل إطار.
  void _onGame() {
    if (!mounted) return;
    final phase = _game.phase;
    final sound = StudentSoundService.instance;
    if (phase == DuelPhase.countdown && _game.countdown != _lastCountdown) {
      _lastCountdown = _game.countdown;
      sound.play(StudentSoundCue.navigation);
    }
    if (phase == DuelPhase.question && _lastPhase != DuelPhase.question) {
      _lastWinner = QuestionWinner.none;
      _lastCorrect = null;
      sound.play(StudentSoundCue.answerSelected);
    }
    if (_game.winner != _lastWinner) {
      _lastWinner = _game.winner;
      if (_game.winner == QuestionWinner.me) {
        HapticFeedback.mediumImpact();
        sound.play(StudentSoundCue.success);
        _confetti.play();
      } else if (_game.winner == QuestionWinner.rival) {
        sound.play(StudentSoundCue.warning);
      }
    }
    if (_game.pickedCorrect == false && _lastCorrect != false) {
      HapticFeedback.lightImpact();
      sound.play(StudentSoundCue.warning);
    }
    _lastCorrect = _game.pickedCorrect;
    if (phase == DuelPhase.result && _lastPhase != DuelPhase.result) {
      final result = _game.result;
      if (result?.match?.iWon == true) {
        _confetti.play();
        sound.playApplause();
        if ((result?.gems ?? 0) > 0) sound.play(StudentSoundCue.gameReward);
      }
    }
    if (phase == DuelPhase.failed &&
        _game.failure == DuelFailureKind.nobodyAccepted &&
        !_autoClosing) {
      // ── لم يوافق أحد: يعود إلى الساحة وحده ──
      _autoClosing = true;
      Future<void>.delayed(const Duration(milliseconds: 2500), () {
        if (!mounted) return;
        final route = ModalRoute.of(context);
        if (route != null && route.isCurrent) {
          Navigator.of(context).pop('nobody');
        }
      });
    }
    _lastPhase = phase;
    setState(() {});
  }

  @override
  void dispose() {
    _game.removeListener(_onGame);
    _game.leave();
    _game.dispose();
    _confetti.dispose();
    disposeChat();
    unawaited(widget.duelService.leaveMatch());
    super.dispose();
  }

  bool get _midMatch => switch (_game.phase) {
        DuelPhase.countdown || DuelPhase.question || DuelPhase.reveal => true,
        _ => false,
      };

  /// المغادرةُ في منتصف النزال تُسأل عنها: زميلُه يكمل ويفوز.
  Future<bool> _confirmLeave() async {
    if (!_midMatch) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: StudentSettings.direction,
        child: AlertDialog(
          title: Text(tr('arena.leaveTitle')),
          content: Text(tr('arena.leaveBody')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(tr('arena.stay')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48)),
              child: Text(tr('arena.leave')),
            ),
          ],
        ),
      ),
    );
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_midMatch,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave() && mounted) navigator.pop();
      },
      child: Directionality(
        textDirection: StudentSettings.direction,
        child: Scaffold(
          backgroundColor: StudentSurface.ground(context),
          // ── والدردشةُ بعد أن يدخل الاثنان ──
          // كان الضيفُ يدردش وزميلُه لم يدخل: رسائلُ تُرسل إلى غرفةٍ فارغة.
          floatingActionButton: _game.roomOpen ? chatButtons() : null,
          body: ArenaBackdrop(
            child: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      _TopBar(
                        onClose: () async {
                          final navigator = Navigator.of(context);
                          if (await _confirmLeave() && mounted) navigator.pop();
                        },
                      ),
                      if (_game.lastLeft != null &&
                          _game.phase != DuelPhase.result &&
                          _game.phase != DuelPhase.failed)
                        _Banner(
                          text: trf('arena.rivalLeft',
                              {'name': _nameOf(_game.lastLeft!)}),
                          color: const Color(0xFFF59E0B),
                        ),
                      Expanded(child: _phaseBody()),
                    ],
                  ),
                  if (_game.roomOpen)
                    Positioned(
                        top: 56, left: 0, right: 0, child: chatBubbles()),
                  Align(
                    alignment: Alignment.topCenter,
                    child: IgnorePointer(
                      child: ConfettiWidget(
                        confettiController: _confetti,
                        blastDirection: math.pi / 2,
                        emissionFrequency: 0.04,
                        numberOfParticles: 18,
                        maxBlastForce: 22,
                        minBlastForce: 8,
                        gravity: 0.3,
                        shouldLoop: false,
                      ),
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

  Widget _phaseBody() {
    Widget versus(Widget footer, {bool rivalPresent = true}) => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ArenaVersus(
              myName: tr('duel.you'),
              rivalName: _leaderName,
              myAppearance: widget.profile.appearance,
              rivalAppearance: _leaderLook,
              rivalPresent: rivalPresent,
              footer: footer,
            ),
          ),
        );

    switch (_game.phase) {
      case DuelPhase.preparing:
        return versus(_Status(text: tr('arena.preparing')),
            rivalPresent: false);
      case DuelPhase.waitingRival:
        // الداعي، أو تحدٍّ جماعي: غرفةُ انتظارٍ بردّ كلِّ مدعوّ وما بقي من المهلة.
        if (widget.isHost || _allRivals.length > 1) {
          return _WaitingRoom(
            room: _game.room,
            invited: [for (final rival in _allRivals) rival.id],
            myId: widget.profile.id,
            nameOf: _nameOf,
            lookOf: _lookOf,
          );
        }
        return versus(
          _Status(text: trf('arena.waitingRival', {'name': _leaderName})),
          rivalPresent: false,
        );
      case DuelPhase.countdown:
        return versus(_CountdownNumber(value: _game.countdown));
      case DuelPhase.question:
      case DuelPhase.reveal:
        return _questionView();
      case DuelPhase.finishing:
        return Center(child: _Status(text: tr('arena.finishing')));
      case DuelPhase.result:
        return _resultView();
      case DuelPhase.failed:
        return _failedView();
    }
  }

  Widget _questionView() {
    final question = _game.question;
    if (question == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 120),
      children: [
        DuelVersusBar(
          myName: tr('duel.you'),
          rivalName: _leaderName,
          myAppearance: widget.profile.appearance,
          rivalAppearance: _leaderLook,
          myPoints: _game.myPoints,
          rivalPoints: _game.rivalPoints,
          live: true,
        ),
        if (_party) ...[
          const SizedBox(height: 10),
          _Scoreboard(
            rows: [
              for (final row in _game.standings)
                (
                  id: row.id,
                  name: _nameOf(row.id),
                  look: _lookOf(row.id),
                  points: row.points,
                  rank: row.rank,
                ),
            ],
            myId: widget.profile.id,
          ),
        ],
        const SizedBox(height: 10),
        // حلبةُ اللعبة: السباقُ أو البالوناتُ أو الحبلُ أو الجواهر — بعدد ما
        // كسبه كلٌّ من الأسئلة.
        DuelArena(
          game: widget.game,
          mine: _game.myPoints ~/ _game.pointsPerQuestion,
          theirs: _game.rivalPoints ~/ _game.pointsPerQuestion,
          total: _game.questions.length,
          live: true,
          myAppearance: widget.profile.appearance,
          theirAppearance: _leaderLook,
          opponentName: _leaderName,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                trf('arena.questionOf', {
                  'n': '${_game.index + 1}',
                  'total': '${_game.questions.length}',
                }),
                style: TextStyle(
                  color: StudentSurface.mutedInk(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            // والعدّادُ للسؤال المفتوح وحده: «٠» أحمرُ بعد الكشف يُقرأ إنذاراً.
            if (_game.phase == DuelPhase.question)
              ArenaTimerRing(
                left: _game.timeLeft,
                window: _game.questionWindow,
                size: 58,
              )
            else
              const SizedBox(width: 58, height: 58),
          ],
        ),
        const SizedBox(height: 10),
        _QuestionCard(question: question),
        const SizedBox(height: 10),
        _Feedback(
          game: _game,
          rivalName: _nameOf(_game.winnerId ?? _game.leaderId),
        ),
        const SizedBox(height: 10),
        DuelChoices(
          game: widget.game,
          options: question.options,
          answerAt: question.answerAt,
          picked: _game.picked,
          pickedCorrect: _game.pickedCorrect,
          revealed: _game.phase == DuelPhase.reveal,
          onPick: _game.phase == DuelPhase.question && _game.picked == null
              ? (index) => unawaited(_game.pick(index))
              : null,
        ),
      ],
    );
  }

  Widget _resultView() {
    final result = _game.result;
    final match = result?.match;
    final won = match?.iWon == true;
    final draw = result?.draw == true;
    final title = draw
        ? tr('arena.draw')
        : won
            ? tr('arena.win')
            : tr('arena.lose');
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                StudentAvatarView(
                  size: 120,
                  appearance:
                      won || draw ? widget.profile.appearance : _leaderLook,
                ),
                if (!draw)
                  const Positioned(
                    top: -34,
                    child: Text('👑', style: TextStyle(fontSize: 40)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    won ? const Color(0xFFF59E0B) : StudentSurface.ink(context),
                fontSize: 34,
                fontWeight: FontWeight.w900,
                shadows: const [
                  Shadow(color: Color(0x88000000), blurRadius: 6)
                ],
              ),
            ),
            const SizedBox(height: 14),
            DuelVersusBar(
              myName: tr('duel.you'),
              rivalName: _leaderName,
              myAppearance: widget.profile.appearance,
              rivalAppearance: _leaderLook,
              myPoints: _game.myPoints,
              rivalPoints: _game.rivalPoints,
              live: false,
            ),
            if (_party) ...[
              const SizedBox(height: 12),
              _Scoreboard(
                final_: true,
                rows: [
                  for (final row in _game.standings)
                    (
                      id: row.id,
                      name: _nameOf(row.id),
                      look: _lookOf(row.id),
                      points: row.points,
                      rank: _rankFromServer(row.id) ?? row.rank,
                    ),
                ],
                myId: widget.profile.id,
              ),
            ],
            const SizedBox(height: 12),
            // الحلبةُ تُري الحسم: الحبلُ يُسحب كلُّه إلى الفائز، والسباقُ والجرّتان
            // على ما انتهت إليه.
            DuelArena(
              game: widget.game,
              mine: _game.myPoints ~/ _game.pointsPerQuestion,
              theirs: _game.rivalPoints ~/ _game.pointsPerQuestion,
              total: _game.questions.length,
              live: false,
              finished: true,
              myAppearance: widget.profile.appearance,
              theirAppearance: _leaderLook,
              opponentName: _leaderName,
            ),
            const SizedBox(height: 16),
            if (won && (result?.gems ?? 0) > 0)
              _GemsBadge(gems: result!.gems)
            else if (won && result?.rewardTaken == true)
              _Note(text: tr('arena.rewardTaken'))
            else if (draw)
              _Note(text: tr('arena.drawBody'))
            else if (!won)
              _Note(text: tr('arena.loseBody')),
            const SizedBox(height: 22),
            Arena3DButton(
              onPressed: () => Navigator.of(context).pop(),
              color: const Color(0xFF7C3AED),
              child: Text(tr('arena.back')),
            ),
          ],
        ),
      ),
    );
  }

  /// المركزُ كما حسمه الخادم.
  int? _rankFromServer(String id) {
    for (final player
        in _game.result?.match?.players ?? const <DuelPlayerScore>[]) {
      if (player.id == id) return player.rank;
    }
    return null;
  }

  Widget _failedView() {
    final text = switch (_game.failure) {
      DuelFailureKind.noQuestions => tr('arena.failNoQuestions'),
      DuelFailureKind.nobodyAccepted => tr('arena.failNobody'),
      DuelFailureKind.excluded => tr('arena.failExcluded'),
      DuelFailureKind.rivalMissing =>
        trf('arena.failRival', {'name': _leaderName}),
      _ => tr('arena.failServer'),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sentiment_dissatisfied_rounded,
                color: Color(0xFF8B5CF6), size: 64),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: StudentSurface.ink(context),
                fontSize: 18,
                height: 1.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            Arena3DButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('arena.back')),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: Icon(Icons.close_rounded, color: StudentSurface.ink(context)),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              tr('arena.title'),
              style: TextStyle(
                color: StudentSurface.ink(context),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const StudentSoundToggle(),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: Color(0xFF7C3AED)),
        const SizedBox(height: 14),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: StudentSurface.ink(context),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CountdownNumber extends StatelessWidget {
  const _CountdownNumber({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tr('arena.getReady'),
          style: TextStyle(
            color: StudentSurface.mutedInk(context),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          key: ValueKey(value),
          tween: Tween(begin: 1.8, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Text(
            '$value',
            style: const TextStyle(
              color: Color(0xFFF59E0B),
              fontSize: 84,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Color(0xAAF97316), blurRadius: 24)],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question});

  final DuelQuestion question;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      decoration: BoxDecoration(
        color: StudentSurface.card(context),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0xFF7C3AED), offset: Offset(0, 6)),
          BoxShadow(
              color: Color(0x55000000), blurRadius: 14, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tr(question.categoryKey),
                style: const TextStyle(
                  color: Color(0xFF6D28D9),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            question.prompt,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: StudentSurface.ink(context),
              fontSize: 21,
              height: 1.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// سطرُ ما حدث: كسبتُ، أو سبقني زميلي، أو أخطأت، أو انتهى الوقت.
class _Feedback extends StatelessWidget {
  const _Feedback({required this.game, required this.rivalName});

  final DuelLiveController game;
  final String rivalName;

  @override
  Widget build(BuildContext context) {
    final reveal = game.phase == DuelPhase.reveal;
    final (String? text, Color color) = switch (game.winner) {
      QuestionWinner.me => (
          trf('arena.youWon', {'points': '${game.pointsPerQuestion}'}),
          const Color(0xFF22C55E),
        ),
      QuestionWinner.rival => (
          game.pickedCorrect == true
              ? trf('arena.correctLate', {'name': rivalName})
              : trf('arena.rivalWon', {'name': rivalName}),
          const Color(0xFFF97316),
        ),
      QuestionWinner.none when game.submitting => (
          tr('arena.checking'),
          const Color(0xFF6366F1),
        ),
      QuestionWinner.none when game.pickedCorrect == false => (
          tr('arena.wrong'),
          const Color(0xFFE11D48),
        ),
      QuestionWinner.none when reveal && game.picked == null => (
          tr('arena.timeUp'),
          const Color(0xFF64748B),
        ),
      QuestionWinner.none when game.picked != null && !reveal => (
          trf('arena.waitingAnswer', {'name': rivalName}),
          const Color(0xFF6366F1),
        ),
      _ => (null, Colors.transparent),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: child,
      ),
      child: text == null
          ? const SizedBox(key: ValueKey('none'), height: 44)
          : _Banner(key: ValueKey(text), text: text, color: color),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color, super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 12),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _GemsBadge extends StatelessWidget {
  const _GemsBadge({required this.gems});

  final int gems;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(
                color: Color(0x8806B6D4), blurRadius: 20, spreadRadius: 2),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💎', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 8),
            Text(
              trf('arena.gems', {'gems': '$gems'}),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: StudentSurface.mutedInk(context),
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

/// غرفةُ الانتظار: من دُعي، وبماذا ردّ، وما بقي من المهلة.
///
/// يبدأ النزالُ فور ردّ الجميع — أو بعد المهلة مع من وافق. والحكمُ للخادم.
class _WaitingRoom extends StatefulWidget {
  const _WaitingRoom({
    required this.room,
    required this.invited,
    required this.myId,
    required this.nameOf,
    required this.lookOf,
  });

  final DuelRoom? room;
  final List<String> invited;
  final String myId;
  final String Function(String id) nameOf;
  final Map<String, dynamic>? Function(String id) lookOf;

  @override
  State<_WaitingRoom> createState() => _WaitingRoomState();
}

class _WaitingRoomState extends State<_WaitingRoom> {
  Timer? _tick;

  /// إن لم يصل موعدُ الخادم بعد: عشرون ثانيةً من فتح الغرفة.
  late final DateTime _fallbackEnd =
      DateTime.now().add(const Duration(seconds: 20));

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final statuses = {
      for (final player in room?.players ?? const <DuelRoomPlayer>[])
        player.id: player.status,
    };
    final ids = [
      ...?room?.players.map((player) => player.id),
      for (final id in widget.invited)
        if (!(room?.players.any((player) => player.id == id) ?? false)) id,
    ];
    final left = (room?.decideBy ?? _fallbackEnd).difference(DateTime.now());
    final accepted =
        statuses.values.where((s) => s == DuelPlayerStatus.accepted).length;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ArenaTimerRing(
              left: left.isNegative ? Duration.zero : left,
              window: const Duration(seconds: 20),
              size: 76,
            ),
            const SizedBox(height: 12),
            Text(
              tr('arena.party.waitingTitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: StudentSurface.ink(context),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr('arena.party.waitingBody'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: StudentSurface.mutedInk(context),
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              trf('arena.party.acceptedCount', {
                'n': '$accepted',
                'total':
                    '${ids.where((id) => statuses[id] != DuelPlayerStatus.host).length}',
              }),
              style: const TextStyle(
                color: Color(0xFF16A34A),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            for (final id in ids)
              _WaitingRow(
                key: ValueKey('wait-$id'),
                name: widget.nameOf(id),
                look: widget.lookOf(id),
                isMe: id == widget.myId,
                status: statuses[id] ?? DuelPlayerStatus.pending,
              ),
          ],
        ),
      ),
    );
  }
}

class _WaitingRow extends StatelessWidget {
  const _WaitingRow({
    required this.name,
    required this.look,
    required this.isMe,
    required this.status,
    super.key,
  });

  final String name;
  final Map<String, dynamic>? look;
  final bool isMe;
  final DuelPlayerStatus status;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (status) {
      DuelPlayerStatus.host => (
          tr('arena.party.host'),
          const Color(0xFF7C3AED)
        ),
      DuelPlayerStatus.accepted => (
          tr('arena.party.accepted'),
          const Color(0xFF16A34A)
        ),
      DuelPlayerStatus.declined => (
          tr('arena.party.declined'),
          const Color(0xFFDC2626)
        ),
      DuelPlayerStatus.late => (
          tr('arena.party.late'),
          const Color(0xFF64748B)
        ),
      DuelPlayerStatus.pending => (
          tr('arena.party.pending'),
          const Color(0xFFF59E0B)
        ),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: StudentSurface.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.6),
      ),
      child: Row(
        children: [
          StudentAvatarView(size: 38, appearance: look, showRing: false),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isMe ? '$name (${tr('arena.party.you')})' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: StudentSurface.ink(context),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (status == DuelPlayerStatus.pending)
            const Padding(
              padding: EdgeInsetsDirectional.only(end: 6),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFFF59E0B)),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _ScoreRow = ({
  String id,
  String name,
  Map<String, dynamic>? look,
  int points,
  int rank,
});

/// لوحةُ النتائج المصغّرة: ترتيبُ الجميع ونقاطُهم، حيّةً أثناء النزال ونهائيةً بعده.
class _Scoreboard extends StatelessWidget {
  const _Scoreboard(
      {required this.rows, required this.myId, this.final_ = false});

  final List<_ScoreRow> rows;
  final String myId;

  /// بعد الحسم: الأوّلُ بتاجه، والمراكزُ الثلاثةُ بأوسمتها.
  final bool final_;

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: StudentSurface.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFA78BFA), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '📊 ${tr('arena.scoreboard')}',
            style: TextStyle(
              color: StudentSurface.ink(context),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          for (final row in rows)
            AnimatedContainer(
              key: ValueKey('score-${row.id}'),
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: row.id == myId
                    ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      row.rank <= 3 && (final_ || row.points > 0)
                          ? _medals[row.rank - 1]
                          : '${row.rank}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: StudentSurface.ink(context),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      StudentAvatarView(
                          size: 30, appearance: row.look, showRing: false),
                      if (final_ && row.rank == 1)
                        const Positioned(
                          top: -12,
                          child: Text('👑', style: TextStyle(fontSize: 13)),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: StudentSurface.ink(context),
                        fontSize: 14,
                        fontWeight:
                            row.id == myId ? FontWeight.w900 : FontWeight.w700,
                      ),
                    ),
                  ),
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: row.points, end: row.points),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, value, _) => Text(
                      trf('arena.party.points', {'n': '$value'}),
                      style: const TextStyle(
                        color: Color(0xFF7C3AED),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
