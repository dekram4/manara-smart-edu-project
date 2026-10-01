import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../models/academic_context.dart';
import '../models/student_profile.dart';
import '../services/student_challenge_service.dart';
import '../services/student_duel_service.dart';
import '../services/student_leaderboard_service.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import '../widgets/portal_watermark.dart';
import '../widgets/student_avatar_view.dart';
import '../widgets/student_experience.dart';
import 'student_duel_game_screen.dart';

/// حلبةُ الصفّ: من متصلٌ الآن، ومن يدعوني، ومن في الصدارة.
///
/// ── لماذا شاشةُ ردهةٍ لا زرٌّ في بطاقة التحدي ──
/// التحدّي بين طالبين ليس لعبةً تُفتح وتُغلق: فيه دعوةٌ تُرسل وتُقبل، ونتيجةٌ
/// تنتظر خصماً قد يلعب غداً. فلذلك مكانٌ يُرى فيه ما يَنتظر وما يُنتظر — وإلا
/// أرسل الطفلُ دعوةً ولم يعرف أين تذهب.
///
/// ── والحضورُ يُغيّر الشكل لا القاعدة ──
/// زميلٌ متصلٌ الآن تصله الدعوةُ فوراً فتكون المباراةُ تزامناً، وزميلٌ غائبٌ
/// تنتظره دعوتُه أسبوعاً. والحسابُ في الخادم واحدٌ في الحالين.
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

class _StudentDuelScreenState extends State<StudentDuelScreen> {
  List<LeaderboardEntry> _classmates = const [];
  List<DuelMatch> _inbox = const [];
  List<DuelStanding> _standings = const [];

  bool _loading = true;

  /// دعوةٌ جاريةٌ الآن، بمعرّف الزميل — فلا يُضغط الزرُّ مرّتين.
  String? _inviting;

  @override
  void initState() {
    super.initState();
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
    unawaited(widget.duelService.leaveClass());
    super.dispose();
  }

  /// مفتاحُ الصفّ كما يحسبه الخادم: معلّمي وصفّي.
  String get _classKey {
    final teacher = (widget.profile.teacherId ?? '').trim();
    final grade = (widget.profile.grade ?? '').trim();
    return teacher.isEmpty || grade.isEmpty ? '' : '$teacher:$grade';
  }

  String get _lessonId => widget.academicContext?.lessonId ?? '';

  Future<void> _load() async {
    setState(() => _loading = true);
    // ── وثلاثةٌ معاً لا واحدةً بعد واحدة ──
    // لا يتوقّف أيٌّ منها على الآخر، وتتاليها يجعل فتحَ الشاشة ثلاثةَ
    // انتظارات متعاقبة على شبكةِ مدرسة.
    //
    // وكلُّ واحدٍ يحمل تعذُّرَه: سقوطُ الصدارة لا يمنع قائمةَ الزملاء، وسقوطُ
    // القائمة لا يمنع الدعواتِ المنتظرة. فالشاشةُ تعرض ما وصل.
    final (board, inbox, standings) = await (
      widget.leaderboardService.fetch(),
      widget.duelService.inbox().catchError((_) => <DuelMatch>[]),
      widget.duelService.standings().catchError((_) => <DuelStanding>[]),
    ).wait;
    if (!mounted) return;
    setState(() {
      _classmates = [
        // ونفسي لا تُعرض في قائمة من أتحدّى.
        for (final entry in board.board?.entries ?? const <LeaderboardEntry>[])
          if (!entry.isMe && entry.id != widget.profile.id) entry,
      ];
      _inbox = inbox;
      _standings = standings;
      _loading = false;
    });
  }

  /// يفتح مختارَ اللعبة، ثم يرسل الدعوة.
  Future<void> _challenge(LeaderboardEntry rival) async {
    if (_inviting != null) return;
    if (_lessonId.isEmpty) {
      _say(tr('duel.error.noLesson'));
      return;
    }
    final game = await showModalBottomSheet<DuelGame>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GameSheet(rivalName: rival.name),
    );
    if (game == null || !mounted) return;

    final live = widget.duelService.online.value.contains(rival.id);
    setState(() => _inviting = rival.id);
    try {
      final match = await widget.duelService.invite(
        lessonId: _lessonId,
        guestId: rival.id,
        game: game,
        live: live,
      );
      if (!mounted) return;
      setState(() => _inviting = null);
      StudentSoundService.instance.play(StudentSoundCue.gameReward);
      // ── والداعي يلعب جولتَه الآن ──
      // ولا ينتظر قَبولاً: المباراةُ مقارنةُ نتيجتين، فمن دعا يسجّل نتيجتَه
      // ويترك المقارنةَ لحين يحضر زميله. وانتظارُ القَبول يجعل الدعوةَ
      // موعداً، وهذا صفٌّ لا نادٍ.
      await _play(match, rival.name, rival.appearance);
    } on DuelFailure catch (failure) {
      if (!mounted) return;
      setState(() => _inviting = null);
      _say(failure.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _inviting = null);
      _say(tr('duel.error.failed'));
    }
  }

  Future<void> _play(
    DuelMatch match,
    String rivalName,
    Map<String, dynamic>? rivalLook,
  ) async {
    // والألعابُ الأربع على شاشةٍ واحدة: المحرّكُ واحد — بذرةٌ من معرّف
    // المباراة وخمسةُ أشواط ونتيجةٌ يحسمها الخادم — واللعبةُ تُغيّر الحلبةَ
    // وشكلَ الخيارات. فلا تحتاج واحدةٌ منها فتحاً ولا قفلاً.
    await Navigator.of(context).push(
      StudentPageRoute<void>(
        immersive: true,
        builder: (_) => StudentDuelGameScreen(
          profile: widget.profile,
          match: match,
          duelService: widget.duelService,
          challengeService: widget.challengeService,
          opponentName: rivalName,
          opponentAppearance: rivalLook,
        ),
      ),
    );
    if (!mounted) return;
    // والعودةُ تُحدّث الصندوقَ والصدارة: نتيجةٌ سُجّلت قد حسمت مباراة.
    await _load();
  }

  /// اسمُ صاحبِ المعرّف وشكلُه، مما قرأناه من الصفّ.
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

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Scaffold(
        backgroundColor: StudentSurface.ground(context),
        appBar: AppBar(
          title: Text(tr('duel.title')),
          centerTitle: true,
          actions: const [StudentSoundToggle()],
        ),
        body: Stack(
          children: [
            // خلفيةُ بطاقة التحدي نفسها: البطاقةُ تفتح هذه الشاشة، فتكون
            // استمراراً لها لا شاشةً غريبةً عنها.
            const PortalWatermark(
              asset: PortalBackgrounds.endlessReader,
              opacity: 0.22,
            ),
            SafeArea(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _loading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF7C3AED)),
                      )
                    : _list(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final waiting = [for (final match in _inbox) if (match.waitingForMe) match];
    // ── ومبارياتٌ لعبتُها وأنتظر فيها زميلي ──
    // كانت تُقرأ من الخادم ولا تُعرض، فكان الطفل يلعب جولتَه ثم لا يجد لها
    // أثراً في القائمة — فيظنّها ضائعة، أو يظنّ أنه لم يلعب.
    final pending = [for (final match in _inbox) if (match.waitingForThem) match];
    DuelStanding? mine;
    for (final item in _standings) {
      if (item.isMe) mine = item;
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        StudentEntrance(child: _MyRecord(standing: mine)),
        if (_lessonId.isEmpty) ...[
          const SizedBox(height: 12),
          _Warning(text: tr('duel.error.noLesson')),
        ],
        if (waiting.isNotEmpty) ...[
          const SizedBox(height: 18),
          _Heading(text: trf('duel.section.waiting', {'n': '${waiting.length}'})),
          const SizedBox(height: 8),
          for (final match in waiting)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _InviteTile(
                match: match,
                who: _whoIs(match.opponentId),
                onPlay: () {
                  final who = _whoIs(match.opponentId);
                  return _play(match, who.name, who.look);
                },
              ),
            ),
        ],
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 18),
          _Heading(text: trf('duel.section.pending', {'n': '${pending.length}'})),
          const SizedBox(height: 8),
          for (final match in pending)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PendingTile(
                match: match,
                who: _whoIs(match.opponentId),
              ),
            ),
        ],
        const SizedBox(height: 18),
        _Heading(text: tr('duel.section.classmates')),
        const SizedBox(height: 8),
        if (_classmates.isEmpty)
          _Warning(text: tr('duel.empty.classmates'))
        else
          // ── والنقاطُ الخضراء تتبع القناةَ بلا إعادةِ بناءِ الشاشة ──
          // الحضورُ يتغيّر كلَّ ثانيةٍ في حصّة، وبناءُ القائمة كلَّها عند كل
          // تغيّر يقطع سحبةَ الإصبع. فالمستمعُ هنا حول القائمة وحدها.
          ValueListenableBuilder<Set<String>>(
            valueListenable: widget.duelService.online,
            builder: (context, online, _) => Column(
              children: [
                for (final mate in _classmates)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MateTile(
                      mate: mate,
                      online: online.contains(mate.id),
                      busy: _inviting == mate.id,
                      locked: _inviting != null || _lessonId.isEmpty,
                      onChallenge: () => _challenge(mate),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        _Heading(text: tr('duel.section.standings')),
        const SizedBox(height: 8),
        if (_standings.isEmpty)
          _Warning(text: tr('duel.empty.standings'))
        else
          for (final standing in _standings.take(10))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _StandingTile(standing: standing),
            ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w900,
          color: StudentSurface.ink(context),
        ),
      );
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
          border: Border.all(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.22),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            fontWeight: FontWeight.w800,
            color: StudentSurface.ink(context),
          ),
        ),
      );
}

/// سجلّي: فوزٌ من كم مباراة.
class _MyRecord extends StatelessWidget {
  const _MyRecord({required this.standing});

  final DuelStanding? standing;

  @override
  Widget build(BuildContext context) {
    final wins = standing?.wins ?? 0;
    final played = standing?.played ?? 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
      ),
      child: Row(
        children: [
          const Text('🏟️', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  played == 0
                      ? tr('duel.record.none')
                      : trf('duel.record', {
                          'wins': '$wins',
                          'played': '$played',
                        }),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('duel.record.hint'),
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.88),
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

/// دعوةٌ تنتظرني.
class _InviteTile extends StatelessWidget {
  const _InviteTile({
    required this.match,
    required this.who,
    required this.onPlay,
  });

  final DuelMatch match;
  final ({String name, Map<String, dynamic>? look}) who;
  final Future<void> Function() onPlay;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFEF3C7),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onPlay(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              StudentAvatarView(size: 42, appearance: who.look, showRing: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trf('duel.invitedYou', {
                        'name': who.name.isEmpty ? tr('duel.rival') : who.name,
                      }),
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF78350F),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('duel.game.${match.game}'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_fill_rounded,
                  size: 32, color: Color(0xFFD97706)),
            ],
          ),
        ),
      ),
    );
  }
}

/// مباراةٌ لعبتُها وأنتظر فيها زميلي.
///
/// ونتيجتي المسجَّلة ظاهرةٌ فيها: الرقمُ هو ما يقول إنها حُفظت فعلاً، و«في
/// انتظار الخصم» وحدها تُقرأ تعليقاً لا حفظاً.
class _PendingTile extends StatelessWidget {
  const _PendingTile({required this.match, required this.who});

  final DuelMatch match;
  final ({String name, Map<String, dynamic>? look}) who;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF7C3AED).withValues(alpha: 0.07),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.26),
          width: 1.3,
        ),
      ),
      child: Row(
        children: [
          StudentAvatarView(size: 40, appearance: who.look, showRing: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trf('duel.pendingOn', {
                    'name': who.name.isEmpty ? tr('duel.rival') : who.name,
                  }),
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    fontWeight: FontWeight.w900,
                    color: StudentSurface.ink(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${tr('duel.game.${match.game}')} • '
                  '${trf('duel.myScore', {'score': '${match.mine ?? 0}'})}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: StudentSurface.mutedInk(context),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.hourglass_top_rounded,
              size: 26, color: Color(0xFF7C3AED)),
        ],
      ),
    );
  }
}

/// زميلٌ في الصفّ، ونقطةٌ تقول إن كان متصلاً.
class _MateTile extends StatelessWidget {
  const _MateTile({
    required this.mate,
    required this.online,
    required this.busy,
    required this.locked,
    required this.onChallenge,
  });

  final LeaderboardEntry mate;
  final bool online;
  final bool busy;
  final bool locked;
  final VoidCallback onChallenge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: StudentSurface.card(context),
        border: Border.all(
          color: online
              ? const Color(0xFF16A34A).withValues(alpha: 0.45)
              : StudentSurface.mutedInk(context).withValues(alpha: 0.16),
          width: 1.3,
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              StudentAvatarView(
                size: 40,
                appearance: mate.appearance,
                showRing: false,
              ),
              if (online)
                PositionedDirectional(
                  end: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF22C55E),
                      border: Border.all(
                        color: StudentSurface.card(context),
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mate.name.isEmpty ? tr('duel.rival') : mate.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: StudentSurface.ink(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr(online ? 'duel.online' : 'duel.offline'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: online
                        ? const Color(0xFF16A34A)
                        : StudentSurface.mutedInk(context),
                  ),
                ),
              ],
            ),
          ),
          busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : FilledButton.icon(
                  onPressed: locked ? null : onChallenge,
                  icon: const Icon(Icons.sports_kabaddi_rounded, size: 18),
                  label: Text(tr('duel.challenge')),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _StandingTile extends StatelessWidget {
  const _StandingTile({required this.standing});

  final DuelStanding standing;

  @override
  Widget build(BuildContext context) {
    final crown = switch (standing.rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '${standing.rank}',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: standing.isMe
            ? const Color(0xFF7C3AED).withValues(alpha: 0.10)
            : StudentSurface.card(context),
        border: standing.isMe
            ? Border.all(color: const Color(0xFF7C3AED), width: 1.4)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              crown,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: StudentSurface.mutedInk(context),
              ),
            ),
          ),
          const SizedBox(width: 6),
          StudentAvatarView(
            size: 32,
            appearance: standing.appearance,
            showRing: false,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              standing.name.isEmpty ? tr('duel.rival') : standing.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: StudentSurface.ink(context),
              ),
            ),
          ),
          Text(
            trf('duel.winsOf', {
              'wins': '${standing.wins}',
              'played': '${standing.played}',
            }),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF7C3AED),
            ),
          ),
        ],
      ),
    );
  }
}

/// مختارُ اللعبة. سباقُ الحلبة جاهز، والثلاثةُ الباقية تُعرض ولا تُفتح.
class _GameSheet extends StatelessWidget {
  const _GameSheet({required this.rivalName});

  final String rivalName;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: StudentSurface.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 46,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: StudentSurface.mutedInk(context).withValues(alpha: 0.3),
                ),
              ),
            ),
            Text(
              trf('duel.pickGame', {
                'name': rivalName.isEmpty ? tr('duel.rival') : rivalName,
              }),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: StudentSurface.ink(context),
              ),
            ),
            const SizedBox(height: 14),
            // والأربعُ تُلعب: محرّكُها واحد، فلا واحدةَ منها «قريباً».
            for (final game in DuelGame.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _GameChoice(
                  game: game,
                  onTap: () => Navigator.of(context).pop(game),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GameChoice extends StatelessWidget {
  const _GameChoice({required this.game, required this.onTap});

  final DuelGame game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final emoji = switch (game) {
      DuelGame.sprint => '🏃',
      DuelGame.balloons => '🎈',
      DuelGame.tug => '🪢',
      DuelGame.gems => '💎',
    };
    return Material(
      color: const Color(0xFF7C3AED).withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.28),
              width: 1.3,
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: StudentSurface.ink(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // وسطرٌ يقول ما تفعله: أربعةُ أسماءٍ بلا شرحٍ تُختار
                    // بالعشوائية، وطفلٌ يريد أن يعرف قبل أن يرسل التحدي.
                    Text(
                      tr('duel.how.${game.id}'),
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                        color: StudentSurface.mutedInk(context),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded,
                  color: Color(0xFF7C3AED), size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
