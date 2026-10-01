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
import '../widgets/arena_widgets.dart';
import '../widgets/peer_challenge_card.dart' show duelWinGems;
import '../widgets/student_avatar_view.dart';
import '../widgets/student_experience.dart';
import 'duel_match_screen.dart';

/// ساحةُ التحدي: من في الساحة الآن، ومن يتحدّاني، وأبطالُ الصف.
///
/// ── لا يُتحدّى إلا متصل ──
/// المبارزةُ حيّة: السؤالُ نفسه للاثنين في اللحظة نفسها، وأوّلُ صحيحٍ يكسبه. فلا
/// معنى لدعوةٍ تنتظر زميلاً غائباً. الغائبون يُعرضون شاحبين بلا زرّ، ويُبعث
/// التحدي للحاضر فتصله دعوةٌ فورية يقبلها أو يرفضها.
///
/// ── والحضورُ هو الساحة ──
/// «متصل» يعني أنه في هذه الشاشة الآن: من فتح بطاقة التحدي. فالدعوةُ تصل إلى من
/// يستطيع أن يلعبها فوراً، لا إلى طفلٍ في منتصف درسه.
///
/// ── ولا دردشةَ هنا ──
/// الدردشةُ داخل غرفة النزال وحدها، مع من تلعب معه.
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

/// مهلةُ الردّ على الدعوة.
const _inviteWindow = Duration(seconds: 20);

enum _WaitOutcome { accepted, declined, timeout, cancelled }

enum _IncomingOutcome { accepted, declined, withdrawn }

class _StudentDuelScreenState extends State<StudentDuelScreen> {
  List<LeaderboardEntry> _classmates = const [];
  List<DuelStanding> _standings = const [];
  bool _loading = true;

  /// نزالٌ يُجهَّز أو يُلعب: لا تُقبل دعوةٌ أخرى ولا تُرسل.
  bool _busy = false;

  /// الدعوةُ التي أنتظر ردَّها، أو التي وصلتني وأنا أقرّر.
  String? _waitingMatch;
  Completer<_WaitOutcome>? _waiting;
  String? _incomingMatch;
  Completer<_IncomingOutcome>? _incoming;

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
    if (_busy) return;
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

    final sent = widget.duelService.sendInvite(
      to: rival.id,
      match: match,
      myName: widget.profile.name,
      myAppearance: widget.profile.appearance,
    );
    if (!sent) {
      unawaited(widget.duelService.cancel(match.id));
      setState(() => _busy = false);
      _say(tr('arena.notSent'));
      return;
    }

    final waiting = Completer<_WaitOutcome>();
    _waiting = waiting;
    _waitingMatch = match.id;
    final timer = Timer(_inviteWindow, () {
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
    final outcome = await waiting.future;
    timer.cancel();
    _waiting = null;
    _waitingMatch = null;
    if (!mounted) return;

    switch (outcome) {
      case _WaitOutcome.accepted:
        await _play(
          matchId: match.id,
          rivalId: rival.id,
          rivalName: rival.name,
          rivalLook: rival.appearance,
          isHost: true,
        );
        return;
      case _WaitOutcome.declined:
        _say(trf('arena.declined', {'name': rival.name}));
      case _WaitOutcome.timeout:
        widget.duelService.cancelInvite(to: rival.id, matchId: match.id);
        _say(trf('arena.noAnswer', {'name': rival.name}));
      case _WaitOutcome.cancelled:
        widget.duelService.cancelInvite(to: rival.id, matchId: match.id);
    }
    unawaited(widget.duelService.cancel(match.id));
    setState(() => _busy = false);
  }

  // ── يتحدّاني ──

  void _onInviteEvent(DuelInviteEvent event) {
    if (!mounted) return;
    switch (event.kind) {
      case DuelInviteKind.invite:
        unawaited(_onInvited(event));
      case DuelInviteKind.accepted:
      case DuelInviteKind.declined:
        final waiting = _waiting;
        if (waiting != null &&
            !waiting.isCompleted &&
            _waitingMatch == event.matchId) {
          waiting.complete(event.kind == DuelInviteKind.accepted
              ? _WaitOutcome.accepted
              : _WaitOutcome.declined);
        }
      case DuelInviteKind.cancelled:
        final incoming = _incoming;
        if (incoming != null &&
            !incoming.isCompleted &&
            _incomingMatch == event.matchId) {
          incoming.complete(_IncomingOutcome.withdrawn);
        }
    }
  }

  Future<void> _onInvited(DuelInviteEvent event) async {
    // مشغولٌ بنزالٍ آخر أو بدعوةٍ أخرى: يُعتذر عنها فوراً، فلا ينتظر زميلُه
    // عشرين ثانيةً بلا ردّ.
    if (_busy || _incoming != null) {
      widget.duelService.replyInvite(
        to: event.fromId,
        matchId: event.matchId,
        accepted: false,
      );
      return;
    }
    final known = _whoIs(event.fromId);
    final name = event.fromName.isNotEmpty ? event.fromName : known.name;
    final look = event.fromAppearance ?? known.look;

    StudentSoundService.instance.play(StudentSoundCue.gameReward);
    final incoming = Completer<_IncomingOutcome>();
    _incoming = incoming;
    _incomingMatch = event.matchId;
    final timer = Timer(_inviteWindow, () {
      if (!incoming.isCompleted) incoming.complete(_IncomingOutcome.declined);
    });
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _IncomingDialog(
          name: name,
          appearance: look,
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
    timer.cancel();
    _incoming = null;
    _incomingMatch = null;
    if (!mounted) return;

    switch (outcome) {
      case _IncomingOutcome.accepted:
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
        );
      case _IncomingOutcome.declined:
        widget.duelService.replyInvite(
          to: event.fromId,
          matchId: event.matchId,
          accepted: false,
        );
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
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    // والعودةُ تحدّث الأبطال: مباراةٌ حُسمت.
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
        backgroundColor: const Color(0xFF1E1B4B),
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
              color: Colors.white,
            ),
            Expanded(
              child: Text(
                tr('arena.title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const IconTheme(
              data: IconThemeData(color: Colors.white),
              child: StudentSoundToggle(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        StudentEntrance(child: _HeroCard(standing: mine)),
        if (_lessonId.isEmpty) ...[
          const SizedBox(height: 12),
          _Notice(text: tr('arena.noLesson')),
        ],
        const SizedBox(height: 18),
        _SectionTitle(
          text: trf('arena.online', {'n': '${present.length}'}),
          leading: const OnlinePulse(size: 12),
        ),
        const SizedBox(height: 10),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: Color(0xFFFBBF24))),
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
                        enabled: !_busy && _lessonId.isNotEmpty,
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
          BoxShadow(color: Color(0xFF3B0764), offset: Offset(0, 7)),
          BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 12)),
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
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('arena.rewardNote'),
                  style: const TextStyle(
                    color: Color(0xFFF5D0FE),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
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
        color: const Color(0xFF312E81),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0xFF1E1B4B), offset: Offset(0, 5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              StudentAvatarView(size: 64, appearance: entry.appearance),
              const PositionedDirectional(
                end: 0,
                bottom: 2,
                child: OnlinePulse(size: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
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
          opacity: 0.55,
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 12, 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(999),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  tr('arena.unavailable'),
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
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
              color: s.isMe ? const Color(0xFF4C1D95) : const Color(0xFF312E81),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: s.isMe ? const Color(0xFFFBBF24) : const Color(0xFF4338CA),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    s.rank >= 1 && s.rank <= 3 ? medals[s.rank - 1] : '${s.rank}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${s.wins} 🏆',
                  style: const TextStyle(
                    color: Color(0xFFFDE047),
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
            style: const TextStyle(
              color: Colors.white,
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
        color: const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFE9D5FF),
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
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
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
    required this.window,
    required this.outcome,
    required this.onAccept,
    required this.onDecline,
  });

  final String name;
  final Map<String, dynamic>? appearance;
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
    return _ArenaDialog(
      appearance: widget.appearance,
      title: trf('arena.inviteTitle', {'name': widget.name}),
      body: tr('arena.inviteBody'),
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
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4C1D95), Color(0xFF1E1B4B)],
            ),
            border: Border.all(color: const Color(0xFFA78BFA), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x887C3AED), blurRadius: 30, spreadRadius: 2),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFE9D5FF),
                    fontSize: 14.5,
                    height: 1.5,
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
