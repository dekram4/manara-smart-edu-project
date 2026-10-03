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
const _inviteWindow = Duration(seconds: 20);

/// أقصى عددٍ من الزملاء في تحدٍّ واحد: \`DUEL_MAX_INVITEES\` في الخادم.
const _maxInvitees = 5;

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

  /// الصفُّ كلُّه وأنا معه: منه يُرتَّب «أبطال الصف».
  List<LeaderboardEntry> _board = const [];

  /// يُعاد ترتيبُ الأبطال وحده ما دامت الساحةُ مفتوحة: زميلٌ فاز الآن أو أنهى
  /// درساً يصعد أمام الصفّ بلا أن يُحدِّث أحدٌ الشاشة.
  Timer? _boardTick;
  static const _boardEvery = Duration(seconds: 20);
  List<DuelStanding> _standings = const [];
  bool _loading = true;

  /// اللعبةُ المختارة. ولا تحدّيَ قبلها.
  DuelGame? _game;

  /// نزالٌ يُجهَّز أو يُلعب: لا تُقبل دعوةٌ أخرى ولا تُرسل.
  bool _busy = false;

  /// الزملاءُ المختارون للتحدي — واحدٌ أو أكثر.
  final Set<String> _picked = {};

  String? _incomingMatch;

  /// مؤقّتُ الدعوة الواردة. يُوقف عند مغادرة الساحة.
  Timer? _incomingTimer;
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
    _boardTick = Timer.periodic(_boardEvery, (_) => unawaited(_refreshBoard()));
    final key = _classKey;
    if (key.isNotEmpty) {
      unawaited(
        widget.duelService.joinClass(classKey: key, myId: widget.profile.id),
      );
    }
  }

  @override
  void dispose() {
    _boardTick?.cancel();
    _incomingTimer?.cancel();
    // ── ومن غادر والدعوةُ قائمة لا يتركها معلّقة ──
    // دعوةٌ وصلتني تُرفض: وإلا انتظرني الداعي حتى نهاية المهلة.
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
      _applyBoard(board.board?.entries ?? const <LeaderboardEntry>[]);
      _standings = standings;
      _loading = false;
    });
  }

  void _applyBoard(List<LeaderboardEntry> entries) {
    _board = entries;
    _classmates = [
      for (final entry in entries)
        if (!entry.isMe && entry.id != widget.profile.id) entry,
    ];
  }

  /// تحديثٌ صامت للوحة: لا مؤشّرَ تحميل، ولا يُمسّ شيءٌ إن تعذّر.
  Future<void> _refreshBoard() async {
    if (!mounted || _loading || _busy) return;
    final result = await widget.leaderboardService.fetch();
    final board = result.board;
    if (!mounted || board == null) return;
    setState(() => _applyBoard(board.entries));
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

  void _togglePick(LeaderboardEntry mate) {
    StudentSoundService.instance.playTap();
    setState(() {
      if (!_picked.remove(mate.id)) {
        if (_picked.length >= _maxInvitees) {
          _say(trf('arena.party.max', {'n': '$_maxInvitees'}));
          return;
        }
        _picked.add(mate.id);
      }
    });
  }

  /// يتحدّى المختارين: زميلاً أو أكثر.
  ///
  /// ── والانتظارُ في غرفة النزال لا في نافذة ──
  /// الداعي يدخل غرفةَ الانتظار فوراً، فيرى ردَّ كلِّ زميلٍ وما بقي من المهلة.
  /// ويبدأ النزالُ حين يردّ الجميع أو تنتهي العشرون ثانية — والحكمُ للخادم.
  Future<void> _challenge(List<LeaderboardEntry> rivals) async {
    final game = _game;
    if (_busy || rivals.isEmpty) return;
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
        guestIds: [for (final rival in rivals) rival.id],
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

    final everyone = [widget.profile.id, for (final rival in rivals) rival.id];
    var reached = 0;
    for (final rival in rivals) {
      if (widget.duelService.sendInvite(
        to: rival.id,
        match: match,
        myName: widget.profile.name,
        myAppearance: widget.profile.appearance,
        players: everyone,
      )) {
        reached += 1;
      }
    }
    if (reached == 0) {
      unawaited(widget.duelService.cancel(match.id));
      setState(() => _busy = false);
      _say(tr('arena.notSent'));
      return;
    }
    setState(() => _picked.clear());

    final outcome = await _play(
      matchId: match.id,
      rivals: [
        for (final rival in rivals)
          DuelRival(
              id: rival.id, name: rival.name, appearance: rival.appearance),
      ],
      isHost: true,
      game: game,
    );
    // ── وما لم يُردَّ عليه يُسحب ──
    // نافذةُ الدعوة عند من لم يردّ تُغلق: بدأ النزالُ بدونه، أو أُلغي.
    for (final rival in rivals) {
      widget.duelService.cancelInvite(to: rival.id, matchId: match.id);
    }
    if (outcome == 'nobody') _say(tr('arena.failNobody'));
  }

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
        // الداعي في غرفة النزال يسأل الخادمَ بنفسه.
        break;
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
          others: [
            for (final id in event.players)
              if (id != event.fromId && id != widget.profile.id)
                _whoIs(id).name,
          ],
          window: _inviteWindow,
          outcome: incoming.future,
          onAccept: () {
            if (!incoming.isCompleted) {
              incoming.complete(_IncomingOutcome.accepted);
            }
          },
          onDecline: () {
            if (!incoming.isCompleted) {
              incoming.complete(_IncomingOutcome.declined);
            }
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
        // وافقتُ: أنتظر في الغرفة مع الداعي حتى يُحسم من يلعب.
        final open = room != null &&
            (room.phase == DuelRoomPhase.invited ||
                room.phase == DuelRoomPhase.accepted ||
                room.phase == DuelRoomPhase.ready);
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
          rivals: [
            DuelRival(id: event.fromId, name: name, appearance: look),
            for (final id in event.players)
              if (id != event.fromId && id != widget.profile.id)
                DuelRival(
                    id: id, name: _whoIs(id).name, appearance: _whoIs(id).look),
          ],
          isHost: false,
          game: event.game,
        );
      case _IncomingOutcome.declined:
        unawaited(_decline(event));
      case _IncomingOutcome.withdrawn:
        _say(trf('arena.withdrawn', {'name': name}));
    }
  }

  /// يفتح غرفةَ النزال ويعود بما أُغلقت به — `'nobody'` إن لم يوافق أحد.
  Future<Object?> _play({
    required String matchId,
    required List<DuelRival> rivals,
    required bool isHost,
    required DuelGame game,
  }) async {
    setState(() => _busy = true);
    final first = rivals.first;
    final outcome = await Navigator.of(context).push<Object?>(
      StudentPageRoute<Object?>(
        immersive: true,
        builder: (_) => DuelMatchScreen(
          profile: widget.profile,
          duelService: widget.duelService,
          matchId: matchId,
          rivalId: first.id,
          rivalName: first.name,
          rivalAppearance: first.appearance,
          rivals: rivals,
          isHost: isHost,
          game: game,
        ),
      ),
    );
    if (!mounted) return outcome;
    setState(() => _busy = false);
    await _load();
    return outcome;
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
    final present = [
      for (final m in _classmates)
        if (online.contains(m.id)) m
    ];
    final away = [
      for (final m in _classmates)
        if (!online.contains(m.id)) m
    ];
    DuelStanding? mine;
    for (final item in _standings) {
      if (item.isMe) mine = item;
    }
    // المختارون من المتصلين الآن: من غاب يسقط من الاختيار.
    final picked = [
      for (final mate in present)
        if (_picked.contains(mate.id)) mate
    ];
    final ink = StudentSurface.ink(context);
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                style: TextStyle(
                    color: ink, fontSize: 22, fontWeight: FontWeight.w900),
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
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
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
          text: '${tr('arena.stepRival')} — ${trf('arena.online', {
                'n': '${present.length}'
              })}',
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
            child: Center(
                child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
          )
        else if (present.isEmpty)
          _Notice(text: tr('arena.onlineEmpty'))
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / 170).floor().clamp(2, 5);
              const gap = 10.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final mate in present)
                    SizedBox(
                      width: width,
                      child: _RivalCard(
                        entry: mate,
                        selected: _picked.contains(mate.id),
                        enabled:
                            !_busy && _lessonId.isNotEmpty && _game != null,
                        onToggle: () => _togglePick(mate),
                      ),
                    ),
                ],
              );
            },
          ),
        if (present.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ChallengeBar(
            count: picked.length,
            enabled: !_busy &&
                _lessonId.isNotEmpty &&
                _game != null &&
                picked.isNotEmpty,
            onChallenge: () => unawaited(_challenge(picked)),
          ),
        ],
        const SizedBox(height: 22),
        _SectionTitle(text: tr('arena.champions'), leading: const Text('🏆')),
        const SizedBox(height: 4),
        Text(
          tr('arena.championsBlurb'),
          style: TextStyle(
            color: StudentSurface.mutedInk(context),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        _Champions(
          rows: rankChampions(_board),
          myId: widget.profile.id,
        ),
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
          BoxShadow(
              color: Color(0x44000000), blurRadius: 16, offset: Offset(0, 10)),
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
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('arena.rewardNote'),
                  style: const TextStyle(
                      color: Color(0xFFF5D0FE),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Pill(
                        text: trf('arena.rules',
                            {'seconds': '$duelQuestionSeconds'})),
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
  const _GameCard(
      {required this.game, required this.selected, required this.onTap});

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
                        color: selected
                            ? Colors.white
                            : StudentSurface.ink(context),
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
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  final LeaderboardEntry entry;
  final bool selected;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    const pick = Color(0xFFF97316);
    return Semantics(
      button: true,
      selected: selected,
      label: entry.name,
      child: GestureDetector(
        onTap: enabled ? onToggle : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          decoration: BoxDecoration(
            color: selected
                ? pick.withValues(alpha: 0.12)
                : StudentSurface.card(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? pick : const Color(0xFF22C55E),
              width: selected ? 2.6 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (selected ? pick : const Color(0xFF22C55E))
                    .withValues(alpha: selected ? 0.35 : 0.18),
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
                  const PositionedDirectional(
                      end: 0, bottom: 2, child: OnlinePulse(size: 14)),
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
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      color: selected ? pick : Colors.transparent,
                      border: Border.all(
                        color:
                            enabled ? pick : StudentSurface.mutedInk(context),
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded,
                            size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      tr(selected ? 'arena.party.picked' : 'arena.party.pick'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            selected ? pick : StudentSurface.mutedInk(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// زرُّ التحدي تحت قائمة المتصلين: «⚔️ تحدَّ (٣)».
class _ChallengeBar extends StatelessWidget {
  const _ChallengeBar({
    required this.count,
    required this.enabled,
    required this.onChallenge,
  });

  final int count;
  final bool enabled;
  final VoidCallback onChallenge;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Arena3DButton(
          onPressed: enabled ? onChallenge : null,
          color: const Color(0xFFF97316),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚔️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(count == 0
                  ? tr('arena.challenge')
                  : trf('arena.party.challengeN', {'n': '$count'})),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tr(count > 1 ? 'arena.party.rules' : 'arena.party.selectHint'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: StudentSurface.mutedInk(context),
            fontSize: 12.5,
            height: 1.45,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
                StudentAvatarView(
                    size: 30, appearance: entry.appearance, showRing: false),
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

/// «أبطال الصف»: الصفُّ كلُّه مرتّباً بمجموع الخبرة والجواهر.
///
/// الأوّلُ بتاجٍ ذهبيّ ووسام 🥇، ثم 🥈 و🥉، ثم بقيةُ الصفّ بأرقامها. وتُعرض
/// العشرةُ الأولى، ومن كان بعدها يرى صفَّه هو في آخر القائمة — فيعرف أين هو.
class _Champions extends StatelessWidget {
  const _Champions({required this.rows, required this.myId});

  final List<ChampionRow> rows;
  final String myId;

  static const _shown = 10;

  bool _isMe(ChampionRow row) => row.entry.isMe || row.entry.id == myId;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return _Notice(text: tr('arena.championsEmpty'));
    final top = rows.take(_shown).toList();
    ChampionRow? me;
    for (final row in rows.skip(_shown)) {
      if (_isMe(row)) me = row;
    }
    return Column(
      children: [
        for (final row in top) _ChampionTile(row: row, isMe: _isMe(row)),
        if (me != null) ...[
          Text(
            '⋯',
            style: TextStyle(
              color: StudentSurface.mutedInk(context),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          _ChampionTile(row: me, isMe: true),
        ],
      ],
    );
  }
}

/// ألوانُ المراكز الثلاثة: ذهبٌ وفضّةٌ وبرونز.
const _podiumTints = <int, Color>{
  1: Color(0xFFF59E0B),
  2: Color(0xFF94A3B8),
  3: Color(0xFFB45309),
};

class _ChampionTile extends StatelessWidget {
  const _ChampionTile({required this.row, required this.isMe});

  final ChampionRow row;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final tint = _podiumTints[row.rank];
    final medal = row.medal;
    final entry = row.entry;
    return Container(
      key: ValueKey('champion-${entry.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: StudentSurface.card(context),
        gradient: tint == null
            ? null
            : LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: [
                  tint.withValues(alpha: 0.22),
                  StudentSurface.card(context),
                ],
              ),
        border: Border.all(
          color: isMe
              ? const Color(0xFF7C3AED)
              : tint?.withValues(alpha: 0.7) ?? StudentSurface.outline(context),
          width: isMe || tint != null ? 2 : 1,
        ),
        boxShadow: row.rank == 1
            ? [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: medal != null
                  ? Text(
                      medal,
                      key: ValueKey(medal),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24),
                    )
                  : Container(
                      key: ValueKey(row.rank),
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: StudentSurface.track(context),
                      ),
                      child: Text(
                        '${row.rank}',
                        style: TextStyle(
                          color: StudentSurface.ink(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 6),
          // البطلُ الأوّل بتاجٍ ذهبيّ فوق شخصيته.
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              StudentAvatarView(
                size: 40,
                appearance: entry.appearance,
                showRing: false,
              ),
              if (row.rank == 1)
                const Positioned(
                  top: -14,
                  child: Text('👑', style: TextStyle(fontSize: 18)),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe
                      ? '${entry.name} (${tr('arena.championsYou')})'
                      : entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: StudentSurface.ink(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                // قطعتان لا سطرٌ واحد: الأرقامُ اللاتينية و«XP» في سطرٍ عربيٍّ
                // يخلطها اتجاهُ النصّ فتُقرأ «9 9».
                Wrap(
                  spacing: 10,
                  children: [
                    _StatChip(text: '⭐ ${entry.xp} XP'),
                    _StatChip(text: '💎 ${entry.gems}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // المجموعُ يعدّ إلى قيمته الجديدة حين يتحدّث: يُرى أنه تغيّر.
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: row.score, end: row.score),
            duration: const Duration(milliseconds: 600),
            builder: (context, value, _) => Text(
              trf('arena.championsScore', {'n': '$value'}),
              style: TextStyle(
                color: tint ?? const Color(0xFF7C3AED),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
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
        style: const TextStyle(
            color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
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

class _IncomingDialog extends StatefulWidget {
  const _IncomingDialog({
    required this.name,
    required this.appearance,
    required this.game,
    required this.window,
    required this.outcome,
    required this.onAccept,
    required this.onDecline,
    this.others = const [],
  });

  final String name;
  final Map<String, dynamic>? appearance;
  final DuelGame game;

  /// زملاءُ آخرون في التحدي نفسه.
  final List<String> others;
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
      body: '$emoji ${trf('arena.inviteGame', {
            'game': widget.game.label
          })}\n${widget.others.isEmpty ? '' : '${trf('arena.party.withOthers', {
              'names': widget.others.where((n) => n.isNotEmpty).join('، '),
              'n': '${widget.others.length}',
            })}\n'}${tr('arena.inviteBody')}',
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
              BoxShadow(
                  color: Color(0x667C3AED), blurRadius: 30, spreadRadius: 2),
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

/// رقمٌ صغيرٌ برمزه، باتجاهٍ ثابت: «⭐ 9 XP» لا يُقلَب في سطرٍ عربي.
class _StatChip extends StatelessWidget {
  const _StatChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      style: TextStyle(
        color: StudentSurface.mutedInk(context),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
