import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../models/academic_context.dart';
import '../models/student_profile.dart';
import '../services/duel_live_controller.dart';
import '../services/student_challenge_service.dart';
import '../services/student_duel_service.dart';
import '../services/student_leaderboard_service.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import '../widgets/arena_widgets.dart';
import '../widgets/peer_challenge_card.dart' show duelWinGems;
import '../widgets/student_avatar_view.dart';
import '../widgets/student_experience.dart';
import 'duel_match_screen.dart';

/// ساحةُ التحدي: تختار اللعبة، ثم تتحدّى زميلاً متصلاً.
///
/// ── لا يُتحدّى إلا متصل ──
/// المبارزةُ حيّة: السؤالُ نفسه للاثنين في اللحظة نفسها، وأوّلُ صحيحٍ يكسبه. فلا
/// معنى لدعوةٍ تنتظر زميلاً غائباً. «متصل» يعني أنه في هذه الشاشة الآن.
///
/// ── والخادمُ حَكَمُ الدعوة ──
/// كان الضيفُ يدخل غرفةَ النزال لحظةَ يضغط «اقبل»، والداعي يعرف الردَّ من إشارةٍ
/// قد تفوته ومؤقّتٍ ينتهي عنده — فرأى الداعي «لا يستطيع» والضيفُ يلعب وحده.
/// والآن: القَبولُ يكتبه الخادم (\`respond\`)، ولا يدخل الضيفُ إلا إن كُتب؛ والداعي
/// يسأل الخادمَ عن الردّ ولا يكتفي بالإشارة. فيرى الاثنان الشيءَ نفسه.
///
/// ── ولا دردشةَ هنا ──
/// الدردشةُ داخل غرفة النزال وحدها، وبعد أن يدخلها الاثنان.
class StudentDuelScreen extends StatefulWidget {
  const StudentDuelScreen({
    required this.profile,
    required this.duelService,
    required this.challengeService,
    required this.leaderboardService,
    this.academicContext,
    super.key,
  });

  final StudentProfile profile;
  final StudentDuelService duelService;
  final StudentChallengeService challengeService;
  final StudentLeaderboardService leaderboardService;
  final AcademicContext? academicContext;

  @override
  State<StudentDuelScreen> createState() => _StudentDuelScreenState();
}

/// مهلةُ الردّ على الدعوة: \`DUEL_INVITE_SECONDS\` في الخادم.
const _inviteWindow = Duration(seconds: 30);

/// ما يُسأل به الخادمُ عن ردّ الزميل.
const _pollEvery = Duration(seconds: 1);

enum _WaitOutcome { accepted, declined, timeout, cancelled }

enum _IncomingOutcome { accepted, declined, withdrawn }

/// شكلُ كل لعبة في بطاقتها: رمزٌ ولون.
const _gameLooks = <DuelGame, (String, Color)>{
  DuelGame.sprint: ('🏁', Color(0xFF7C3AED)),
  DuelGame.balloons: ('🎈', Color(0xFFDB2777)),
  DuelGame.tug: ('🪢', Color(0xFFEA580C)),
  DuelGame.gems: ('💎', Color(0xFF0891B2)),
};

class _StudentDuelScreenState extends State<StudentDuelScreen> {
  List<LeaderboardEntry> _classmates = const [];
  List<DuelStanding> _standings = const [];
  bool _loading = true;

  /// اللعبةُ المختارة. ولا تحدّيَ قبلها.
  DuelGame? _game;

  /// نزالٌ يُجهَّز أو يُلعب: لا تُقبل دعوةٌ أخرى ولا تُرسل.
  bool _busy = false;

  String? _waitingMatch;
  String? _incomingMatch;

  /// مؤقّتاتُ الدعوة الجارية، وزميلُها. تُوقف عند مغادرة الساحة — وكانت تبقى
  /// تعمل، والمباراةُ معلّقةٌ في الخادم لا يُلغيها أحد.
  Timer? _waitPoll;
  Timer? _waitTimer;
  Timer? _incomingTimer;
  String? _waitingRival;
  DuelInviteEvent? _incomingEvent;
  Completer<_IncomingOutcome>? _incoming;

  /// دعواتٌ رأيتُها: الإشارةُ قد تصل مرّتين، والثانيةُ ليست دعوةً ثانية. وكانت
  /// تُرفض آلياً بحجّة «مشغول»، فيرى الداعي رفضاً لم يختره زميلُه.
  final Set<String> _seenInvites = {};

  StreamSubscription<DuelInviteEvent>? _invites;

  String get _lessonId => widget.academicContext?.lessonId ?? '';

  String get _classKey {
    final teacher = (widget.profile.teacherId ?? '').trim();
    final grade = (widget.profile.grade ?? '').trim();
    return teacher.isEmpty || grade.isEmpty ? '' : '$teacher:$grade';
  }

  @override
  void initState() {
    super.initState();
    _invites = widget.duelService.inviteEvents.listen(_onInviteEvent);
    unawaited(_load());
    final key = _classKey;
    if (key.isNotEmpty) {
      unawaited(
        widget.duelService.joinClass(classKey: key, myId: widget.profile.id),
      );
    }
  }

  @override
  void dispose() {
    _waitPoll?.cancel();
    _waitTimer?.cancel();
    _incomingTimer?.cancel();
    // ── ومن غادر والدعوةُ قائمة لا يتركها معلّقة ──
    // دعوتي تُسحب في الخادم وعند زميلي، ودعوةٌ وصلتني تُرفض: وإلا قبلها زميلٌ
    // ودخل غرفةً لن أدخلها.
    final waiting = _waitingMatch;
    final rival = _waitingRival;
    if (waiting != null) {
      if (rival != null) {
        widget.duelService.cancelInvite(to: rival, matchId: waiting);
      }
      unawaited(widget.duelService.cancel(waiting));
    }
    final incoming = _incomingEvent;
    if (incoming != null) unawaited(_decline(incoming));
    unawaited(_invites?.cancel());
    unawaited(widget.duelService.leaveClass());
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (board, standings) = await (
      widget.leaderboardService.fetch(),
      widget.duelService.standings().catchError((_) => <DuelStanding>[]),
    ).wait;
    if (!mounted) return;
    setState(() {
      _classmates = [
        for (final entry in board.board?.entries ?? const <LeaderboardEntry>[])
          if (!entry.isMe && entry.id != widget.profile.id) entry,
      ];
      _standings = standings;
      _loading = false;
    });
  }

  ({String name, Map<String, dynamic>? look}) _whoIs(String id) {
    for (final mate in _classmates) {
      if (mate.id == id) return (name: mate.name, look: mate.appearance);
    }
    for (final standing in _standings) {
      if (standing.studentId == id) {
        return (name: standing.name, look: standing.appearance);
      }
    }
    return (name: '', look: null);
  }

  // ── أتحدّى ──

  Future<void> _challenge(LeaderboardEntry rival) async {
    final game = _game;
    if (_busy) return;
    if (game == null) {
      _say(tr('arena.pickGameFirst'));
      return;
    }
    if (_lessonId.isEmpty) {
      _say(tr('arena.noLesson'));
      return;
    }
    StudentSoundService.instance.playTap();
    setState(() => _busy = true);
    DuelMatch match;
    try {
      match = await widget.duelService.invite(
        lessonId: _lessonId,
        guestId: rival.id,
        game: game,
      );
    } on DuelFailure catch (failure) {
      if (mounted) setState(() => _busy = false);
      _say(failure.message);
      return;
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      _say(tr('arena.notSent'));
      return;
    }
    if (!mounted) return;

    if (!widget.duelService.sendInvite(
      to: rival.id,
      match: match,
      myName: widget.profile.name,
      myAppearance: widget.profile.appearance,
    )) {
      unawaited(widget.duelService.cancel(match.id));
      setState(() => _busy = false);
      _say(tr('arena.notSent'));
      return;
    }

    final waiting = Completer<_WaitOutcome>();
    _waitingMatch = match.id;
    _waitingRival = rival.id;

    // ── والردُّ من الخادم ──
    // الإشارةُ تُسرّع السؤال ولا تُغني عنه: كلَّ ثانيةٍ يُسأل الخادمُ عن حال الدعوة،
    // وما يقوله هو ما يُفعل.
    var asking = false;
    Future<void> ask() async {
      if (asking || waiting.isCompleted) return;
      asking = true;
      try {
        final room = await widget.duelService.room(match.id);
        if (waiting.isCompleted) return;
        if (room.phase == DuelRoomPhase.accepted || room.phase == DuelRoomPhase.ready) {
          waiting.complete(_WaitOutcome.accepted);
        } else if (room.phase == DuelRoomPhase.expired) {
          waiting.complete(_WaitOutcome.declined);
        }
      } catch (_) {
        // سؤالٌ تعثّر: يُعاد في النبضة التالية.
      } finally {
        asking = false;
      }
    }

    _askWaiting = ask;
    _waitPoll = Timer.periodic(_pollEvery, (_) => unawaited(ask()));
    _waitTimer = Timer(_inviteWindow, () {
      if (!waiting.isCompleted) waiting.complete(_WaitOutcome.timeout);
    });
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _WaitingDialog(
          name: rival.name,
          appearance: rival.appearance,
          window: _inviteWindow,
          outcome: waiting.future,
          onCancel: () {
            if (!waiting.isCompleted) waiting.complete(_WaitOutcome.cancelled);
          },
        ),
      ),
    );
    var outcome = await waiting.future;
    _waitPoll?.cancel();
    _waitTimer?.cancel();
    if (!mounted) return;
    _waitingMatch = null;
    _waitingRival = null;
    _askWaiting = null;
    if (!mounted) return;

    if (outcome == _WaitOutcome.timeout) {
      // ── المهلةُ عندي ليست الحكم ──
      // يُلغى في الخادم، والإلغاءُ مشروط: إن كان الزميلُ قد قبل في اللحظة الأخيرة
      // لم يُكتب، وتعود الغرفةُ قائمةً فأدخلها — لا أتركه فيها وحده.
      final room = await widget.duelService.cancel(match.id);
      if (!mounted) return;
      if (room != null &&
          (room.phase == DuelRoomPhase.accepted || room.phase == DuelRoomPhase.ready)) {
        outcome = _WaitOutcome.accepted;
      }
    }

    switch (outcome) {
      case _WaitOutcome.accepted:
        await _play(
          matchId: match.id,
          rivalId: rival.id,
          rivalName: rival.name,
          rivalLook: rival.appearance,
          isHost: true,
          game: game,
        );
        return;
      case _WaitOutcome.declined:
        _say(trf('arena.declined', {'name': rival.name}));
      case _WaitOutcome.timeout:
        widget.duelService.cancelInvite(to: rival.id, matchId: match.id);
        _say(trf('arena.noAnswer', {'name': rival.name}));
      case _WaitOutcome.cancelled:
        widget.duelService.cancelInvite(to: rival.id, matchId: match.id);
        unawaited(widget.duelService.cancel(match.id));
    }
    setState(() => _busy = false);
  }

  /// يسأل الخادمَ فوراً عن الدعوة الجارية — تُناديه إشارةُ الردّ.
  Future<void> Function()? _askWaiting;

  // ── يتحدّاني ──

  void _onInviteEvent(DuelInviteEvent event) {
    if (!mounted) return;
    switch (event.kind) {
      case DuelInviteKind.invite:
        // ── والمكرّرُ يُهمل ──
        // دعوةٌ وصلت مرّتين دعوةٌ واحدة.
        if (!_seenInvites.add(event.matchId)) return;
        unawaited(_onInvited(event));
      case DuelInviteKind.accepted:
      case DuelInviteKind.declined:
        if (_waitingMatch == event.matchId) unawaited(_askWaiting?.call());
      case DuelInviteKind.cancelled:
        final incoming = _incoming;
        if (incoming != null &&
            !incoming.isCompleted &&
            _incomingMatch == event.matchId) {
          incoming.complete(_IncomingOutcome.withdrawn);
        }
    }
  }

  Future<void> _decline(DuelInviteEvent event) async {
    widget.duelService.replyInvite(
      to: event.fromId,
      matchId: event.matchId,
      accepted: false,
    );
    try {
      await widget.duelService.respond(matchId: event.matchId, accept: false);
    } catch (_) {
      // الرفضُ لم يُكتب: تنتهي الدعوةُ بمهلتها في الخادم على كل حال.
    }
  }

  Future<void> _onInvited(DuelInviteEvent event) async {
    // مشغولٌ بنزالٍ آخر أو بدعوةٍ أخرى: يُعتذر عنها فوراً.
    if (_busy || _incoming != null) {
      unawaited(_decline(event));
      return;
    }
    final known = _whoIs(event.fromId);
    final name = event.fromName.isNotEmpty ? event.fromName : known.name;
    final look = event.fromAppearance ?? known.look;

    StudentSoundService.instance.play(StudentSoundCue.gameReward);
    final incoming = Completer<_IncomingOutcome>();
    _incoming = incoming;
    _incomingMatch = event.matchId;
    _incomingEvent = event;
    _incomingTimer = Timer(_inviteWindow, () {
      if (!incoming.isCompleted) incoming.complete(_IncomingOutcome.declined);
    });
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _IncomingDialog(
          name: name,
          appearance: look,
          game: event.game,
          window: _inviteWindow,
          outcome: incoming.future,
          onAccept: () {
            if (!incoming.isCompleted) incoming.complete(_IncomingOutcome.accepted);
          },
          onDecline: () {
            if (!incoming.isCompleted) incoming.complete(_IncomingOutcome.declined);
          },
        ),
      ),
    );
    final outcome = await incoming.future;
    _incomingTimer?.cancel();
    if (!mounted) return;
    _incoming = null;
    _incomingMatch = null;
    _incomingEvent = null;
    if (!mounted) return;

    switch (outcome) {
      case _IncomingOutcome.accepted:
        // ── القَبولُ يُكتب في الخادم أوّلاً ──
        // ولا تُفتح الغرفةُ إلا إن كتبه: دعوةٌ سحبها صاحبُها أو فاتت مهلتُها لا
        // يدخلها الضيفُ وحده.
        setState(() => _busy = true);
        DuelRoom? room;
        try {
          room = await widget.duelService.respond(
            matchId: event.matchId,
            accept: true,
          );
        } catch (_) {
          room = null;
        }
        if (!mounted) return;
        final open = room != null &&
            (room.phase == DuelRoomPhase.accepted || room.phase == DuelRoomPhase.ready);
        if (!open) {
          setState(() => _busy = false);
          _say(room == null ? tr('arena.notSent') : tr('arena.inviteGone'));
          return;
        }
        widget.duelService.replyInvite(
          to: event.fromId,
          matchId: event.matchId,
          accepted: true,
        );
        await _play(
          matchId: event.matchId,
          rivalId: event.fromId,
          rivalName: name,
          rivalLook: look,
          isHost: false,
          game: event.game,
        );
      case _IncomingOutcome.declined:
        unawaited(_decline(event));
      case _IncomingOutcome.withdrawn:
        _say(trf('arena.withdrawn', {'name': name}));
    }
  }

  Future<void> _play({
    required String matchId,
    required String rivalId,
    required String rivalName,
    required Map<String, dynamic>? rivalLook,
    required bool isHost,
    required DuelGame game,
  }) async {
    setState(() => _busy = true);
    await Navigator.of(context).push(
      StudentPageRoute<void>(
        immersive: true,
        builder: (_) => DuelMatchScreen(
          profile: widget.profile,
          duelService: widget.duelService,
          matchId: matchId,
          rivalId: rivalId,
          rivalName: rivalName,
          rivalAppearance: rivalLook,
          isHost: isHost,
          game: game,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Scaffold(
        backgroundColor: StudentSurface.ground(context),
        body: ArenaBackdrop(
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ValueListenableBuilder<Set<String>>(
                valueListenable: widget.duelService.online,
                builder: (context, online, _) => _list(context, online),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, Set<String> online) {
    final present = [for (final m in _classmates) if (online.contains(m.id)) m];
    final away = [for (final m in _classmates) if (!online.contains(m.id)) m];
    DuelStanding? mine;
    for (final item in _standings) {
      if (item.isMe) mine = item;
    }
    final ink = StudentSurface.ink(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const BackButtonIcon(),
              color: ink,
            ),
            Expanded(
              child: Text(
                tr('arena.title'),
                style: TextStyle(color: ink, fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
            const StudentSoundToggle(),
          ],
        ),
        const SizedBox(height: 6),
        StudentEntrance(child: _HeroCard(standing: mine)),
        if (_lessonId.isEmpty) ...[
          const SizedBox(height: 12),
          _Notice(text: tr('arena.noLesson')),
        ],
        const SizedBox(height: 18),
        _SectionTitle(text: tr('arena.stepGame')),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 640 ? 4 : 2;
            const gap = 10.0;
            final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final game in DuelGame.values)
                  SizedBox(
                    width: width,
                    child: _GameCard(
                      game: game,
                      selected: _game == game,
                      onTap: () {
                        StudentSoundService.instance.playTap();
                        setState(() => _game = game);
                      },
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        _SectionTitle(
          text: '${tr('arena.stepRival')} — ${trf('arena.online', {'n': '${present.length}'})}',
          leading: const OnlinePulse(size: 12),
        ),
        const SizedBox(height: 10),
        if (_game == null) ...[
          _Notice(text: tr('arena.pickGameFirst')),
          const SizedBox(height: 10),
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
          )
        else if (present.isEmpty)
          _Notice(text: tr('arena.onlineEmpty'))
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / 170).floor().clamp(2, 5);
              const gap = 10.0;
              final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final mate in present)
                    SizedBox(
                      width: width,
                      child: _RivalCard(
                        entry: mate,
                        enabled: !_busy && _lessonId.isNotEmpty && _game != null,
                        onChallenge: () => unawaited(_challenge(mate)),
                      ),
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: 22),
        _SectionTitle(text: tr('arena.champions'), leading: const Text('🏆')),
        const SizedBox(height: 10),
        _Champions(standings: _standings),
        if (away.isNotEmpty) ...[
          const SizedBox(height: 22),
          _SectionTitle(text: trf('arena.offline', {'n': '${away.length}'})),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final mate in away) _OfflineChip(entry: mate)],
          ),
        ],
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.standing});

  final DuelStanding? standing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C3AED), Color(0xFFC026D3)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0xFF5B21B6), offset: Offset(0, 6)),
          BoxShadow(color: Color(0x44000000), blurRadius: 16, offset: Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          const StudentAvatarView(size: 72),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trf('arena.reward', {'gems': '$duelWinGems'}),
                  style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('arena.rewardNote'),
                  style: const TextStyle(color: Color(0xFFF5D0FE), fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Pill(text: trf('arena.rules', {'seconds': '$duelQuestionSeconds'})),
                    if (standing != null)
                      _Pill(
                        text: trf('arena.myRecord', {
                          'wins': '${standing!.wins}',
                          'played': '${standing!.played}',
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقةُ لعبة: مجسّمةٌ على حافّتها، والمختارةُ ترتفع وتتلوّن.
class _GameCard extends StatefulWidget {
  const _GameCard({required this.game, required this.selected, required this.onTap});

  final DuelGame game;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final (emoji, color) = _gameLooks[widget.game]!;
    final selected = widget.selected;
    const ledge = 6.0;
    final sink = _down ? ledge : (selected ? 0.0 : 2.0);
    return Semantics(
      button: true,
      selected: selected,
      label: widget.game.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: Padding(
          padding: EdgeInsets.only(top: sink),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: EdgeInsets.only(bottom: ledge - sink),
            decoration: BoxDecoration(
              color: Color.lerp(color, Colors.black, 0.35),
              borderRadius: BorderRadius.circular(20),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
              decoration: BoxDecoration(
                color: selected ? color : StudentSurface.card(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color, width: selected ? 2.5 : 1.5),
              ),
              child: Column(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 34)),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.game.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: selected ? Colors.white : StudentSurface.ink(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr('arena.how.${widget.game.id}'),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.9)
                          : StudentSurface.mutedInk(context),
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

class _RivalCard extends StatelessWidget {
  const _RivalCard({
    required this.entry,
    required this.enabled,
    required this.onChallenge,
  });

  final LeaderboardEntry entry;
  final bool enabled;
  final VoidCallback onChallenge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: StudentSurface.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22C55E), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              StudentAvatarView(size: 64, appearance: entry.appearance),
              const PositionedDirectional(end: 0, bottom: 2, child: OnlinePulse(size: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: StudentSurface.ink(context),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: Arena3DButton(
              onPressed: enabled ? onChallenge : null,
              color: const Color(0xFFF97316),
              ledge: 5,
              radius: 14,
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⚔️', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 6),
                  Text(tr('arena.challenge')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineChip extends StatelessWidget {
  const _OfflineChip({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${entry.name} — ${tr('arena.unavailable')}',
      child: ExcludeSemantics(
        child: Opacity(
          opacity: 0.6,
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 12, 4),
            decoration: BoxDecoration(
              color: StudentSurface.card(context),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: StudentSurface.outline(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StudentAvatarView(size: 30, appearance: entry.appearance, showRing: false),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: StudentSurface.ink(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  tr('arena.unavailable'),
                  style: TextStyle(
                    color: StudentSurface.mutedInk(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
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

class _Champions extends StatelessWidget {
  const _Champions({required this.standings});

  final List<DuelStanding> standings;

  @override
  Widget build(BuildContext context) {
    final top = standings.where((s) => s.wins > 0).take(5).toList();
    if (top.isEmpty) return _Notice(text: tr('arena.championsEmpty'));
    const medals = ['🥇', '🥈', '🥉'];
    return Column(
      children: [
        for (final s in top)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: StudentSurface.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: s.isMe ? const Color(0xFFF59E0B) : StudentSurface.outline(context),
                width: s.isMe ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    s.rank >= 1 && s.rank <= 3 ? medals[s.rank - 1] : '${s.rank}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: StudentSurface.ink(context),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                StudentAvatarView(size: 38, appearance: s.appearance, showRing: false),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: StudentSurface.ink(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${s.wins} 🏆',
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, this.leading});

  final String text;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: StudentSurface.ink(context),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudentSurface.glass(context, 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StudentSurface.outline(context)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: StudentSurface.mutedInk(context),
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// نافذةٌ تُغلق نفسها حين يُحسم ما تنتظره — أيّاً كان من حسمه.
///
/// ── وتُزيل مسارَها هي، لا أعلى المسارات ──
/// حين يُقبل التحدي تستأنف الساحةُ أوّلاً فتفتح غرفةَ النزال، ثم يصل هذا. و`pop`
/// كان سيُغلق الغرفةَ التي فُتحت للتوّ لا النافذة.
mixin _ClosesOnOutcome<T extends StatefulWidget, R> on State<T> {
  Future<R> get outcome;

  @override
  void initState() {
    super.initState();
    unawaited(outcome.then((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && route.isActive) {
        Navigator.of(context).removeRoute(route);
      }
    }));
  }
}

/// عدٌّ تنازليٌّ يُرسم في النافذتين.
class _WindowCountdown extends StatefulWidget {
  const _WindowCountdown({required this.window});

  final Duration window;

  @override
  State<_WindowCountdown> createState() => _WindowCountdownState();
}

class _WindowCountdownState extends State<_WindowCountdown> {
  late final DateTime _end = DateTime.now().add(widget.window);
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
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
    final left = _end.difference(DateTime.now());
    return ArenaTimerRing(
      left: left.isNegative ? Duration.zero : left,
      window: widget.window,
      size: 56,
    );
  }
}

class _WaitingDialog extends StatefulWidget {
  const _WaitingDialog({
    required this.name,
    required this.appearance,
    required this.window,
    required this.outcome,
    required this.onCancel,
  });

  final String name;
  final Map<String, dynamic>? appearance;
  final Duration window;
  final Future<_WaitOutcome> outcome;
  final VoidCallback onCancel;

  @override
  State<_WaitingDialog> createState() => _WaitingDialogState();
}

class _WaitingDialogState extends State<_WaitingDialog>
    with _ClosesOnOutcome<_WaitingDialog, _WaitOutcome> {
  @override
  Future<_WaitOutcome> get outcome => widget.outcome;

  @override
  Widget build(BuildContext context) {
    return _ArenaDialog(
      appearance: widget.appearance,
      title: trf('arena.waitingTitle', {'name': widget.name}),
      body: tr('arena.waitingBody'),
      top: _WindowCountdown(window: widget.window),
      actions: [
        Arena3DButton(
          onPressed: widget.onCancel,
          color: const Color(0xFF64748B),
          child: Text(tr('arena.cancel')),
        ),
      ],
    );
  }
}

class _IncomingDialog extends StatefulWidget {
  const _IncomingDialog({
    required this.name,
    required this.appearance,
    required this.game,
    required this.window,
    required this.outcome,
    required this.onAccept,
    required this.onDecline,
  });

  final String name;
  final Map<String, dynamic>? appearance;
  final DuelGame game;
  final Duration window;
  final Future<_IncomingOutcome> outcome;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  State<_IncomingDialog> createState() => _IncomingDialogState();
}

class _IncomingDialogState extends State<_IncomingDialog>
    with _ClosesOnOutcome<_IncomingDialog, _IncomingOutcome> {
  @override
  Future<_IncomingOutcome> get outcome => widget.outcome;

  @override
  Widget build(BuildContext context) {
    final (emoji, _) = _gameLooks[widget.game]!;
    return _ArenaDialog(
      appearance: widget.appearance,
      title: trf('arena.inviteTitle', {'name': widget.name}),
      body: '$emoji ${trf('arena.inviteGame', {'game': widget.game.label})}\n${tr('arena.inviteBody')}',
      top: _WindowCountdown(window: widget.window),
      actions: [
        Arena3DButton(
          onPressed: widget.onAccept,
          color: const Color(0xFF16A34A),
          child: Text(tr('arena.accept')),
        ),
        Arena3DButton(
          onPressed: widget.onDecline,
          color: const Color(0xFF64748B),
          child: Text(tr('arena.decline')),
        ),
      ],
    );
  }
}

class _ArenaDialog extends StatelessWidget {
  const _ArenaDialog({
    required this.appearance,
    required this.title,
    required this.body,
    required this.top,
    required this.actions,
  });

  final Map<String, dynamic>? appearance;
  final String title;
  final String body;
  final Widget top;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(22),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: StudentSurface.card(context),
            border: Border.all(color: const Color(0xFFA78BFA), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x667C3AED), blurRadius: 30, spreadRadius: 2),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StudentAvatarView(size: 84, appearance: appearance),
                    const SizedBox(width: 14),
                    top,
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: StudentSurface.ink(context),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: StudentSurface.mutedInk(context),
                    fontSize: 14.5,
                    height: 1.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: actions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
