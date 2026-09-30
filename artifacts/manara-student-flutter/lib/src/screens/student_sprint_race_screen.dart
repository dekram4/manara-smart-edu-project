import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../models/sprint_question.dart';
import '../models/student_profile.dart';
import '../services/student_challenge_service.dart';
import '../services/student_duel_service.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import '../widgets/student_avatar_view.dart';
import '../widgets/student_experience.dart';

/// سباقُ الحلبة: كلُّ إجابةٍ صحيحةٍ تُقدّم عدّاءك خطوة.
///
/// ── لماذا سباقٌ لا اختبار ──
/// الأسئلةُ نفسها في البطاقتين، والفرقُ أنّ هنا خصماً يتقدّم. والطفل الذي
/// يقرأ السؤالَ ليجيب يقرؤه هنا ليسبق — وهو الفرقُ بين واجبٍ ولعبة.
///
/// ── والنتيجةُ تُحسم في الخادم ──
/// هذه الشاشةُ تعدّ الصحيحَ وترسله، ولا تقول من فاز. الخادم يقارن
/// النتيجتين ويصرف الجوهرة، فلا يستطيع تطبيقٌ معدَّلٌ أن يدّعي فوزاً.
class StudentSprintRaceScreen extends StatefulWidget {
  const StudentSprintRaceScreen({
    required this.profile,
    required this.match,
    required this.duelService,
    required this.challengeService,
    this.opponentName = '',
    this.opponentAppearance,
    super.key,
  });

  final StudentProfile profile;
  final DuelMatch match;
  final StudentDuelService duelService;
  final StudentChallengeService challengeService;
  final String opponentName;
  final Map<String, dynamic>? opponentAppearance;

  @override
  State<StudentSprintRaceScreen> createState() =>
      _StudentSprintRaceScreenState();
}

class _StudentSprintRaceScreenState extends State<StudentSprintRaceScreen> {
  /// أسئلةُ الشوط: جملةٌ ناقصةٌ وخيارات.
  List<SprintQuestion> _questions = const [];
  String? _error;
  bool _loading = true;

  int _at = 0;
  int _correct = 0;
  int? _picked;

  /// تقدّمُ الخصم كما يبثّه، في المباراة الحيّة.
  ///
  /// ويبدأ من نتيجته إن كان قد لعب: البثُّ لا يُعاد لمن دخل متأخّراً، فلو
  /// بدأ من صفرٍ لرأى الثاني خصمَه في أوّل المضمار وقد أنهى السباق.
  late int _rivalAt = widget.match.theirs ?? 0;

  bool _sending = false;

  /// نتيجةُ المباراة بعد أن تُحسم في الخادم.
  DuelMatch? _settled;
  int _gems = 0;
  bool _draw = false;

  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    if (widget.match.live) {
      unawaited(
        widget.duelService.watchMatch(
          matchId: widget.match.id,
          onProgress: (id, at) {
            // تقدّمي يعود إليّ أيضاً — القناةُ تبثّ للجميع — فيُهمل.
            if (!mounted || id == widget.profile.id) return;
            // ولا يتراجع العدّاء: بثٌّ وصل متأخّراً بعد أحدثَ منه كان
            // سيرجع خصمَه خطوةً إلى الوراء أمام عين الطفل.
            setState(() => _rivalAt = math.max(_rivalAt, at));
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    unawaited(widget.duelService.leaveMatch());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rounds = await widget.challengeService.fetchRound(
        lessonId: widget.match.lessonId,
        count: widget.match.rounds,
        // ── والبذرةُ معرّفُ المباراة ──
        // فالخصمان يُسألان الأسئلةَ نفسها: سباقٌ بأسئلةٍ مختلفة ليس سباقاً.
        // ومباراةٌ أخرى بذرتُها أخرى، فلا تُعاد الأسئلة.
        seed: widget.match.id,
        draw: math.Random(stableSeed(widget.match.id)),
      );
      final questions = sprintQuestionsOf(rounds);
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _loading = false;
        _error = questions.isEmpty ? tr('duel.error.noQuestions') : null;
      });
    } on ChallengeFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = switch (failure.message) {
          'noService' => tr('challenge.error.noService'),
          'sessionFailed' => tr('challenge.error.noSession'),
          'offline' => tr('challenge.error.offline'),
          'notDeployed' => tr('challenge.error.notDeployed'),
          'badResponse' || 'serviceSilent' => tr('challenge.error.badResponse'),
          'empty' => tr('challenge.error.empty'),
          final other => other,
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = tr('duel.error.failed');
      });
    }
  }

  void _pick(int index) {
    if (_picked != null || _sending) return;
    final question = _questions[_at];
    final right = index == question.answerAt;
    setState(() {
      _picked = index;
      if (right) _correct += 1;
    });
    if (right) {
      _confetti.play();
      StudentSoundService.instance.play(StudentSoundCue.success);
      // والخطوةُ تُبثّ فور وقوعها: الخصم يرى عدّائي يتقدّم فيستعجل.
      widget.duelService.sendProgress(myId: widget.profile.id, at: _correct);
    } else {
      StudentSoundService.instance.play(StudentSoundCue.warning);
    }
  }

  Future<void> _next() async {
    if (_at + 1 < _questions.length) {
      setState(() {
        _at += 1;
        _picked = null;
      });
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    setState(() => _sending = true);
    try {
      final result = await widget.duelService.submitScore(
        matchId: widget.match.id,
        score: _correct,
      );
      if (!mounted) return;
      setState(() {
        _settled = result.match;
        _gems = result.gems;
        _draw = result.draw;
        _sending = false;
      });
      if (result.gems > 0) {
        _confetti.play();
        StudentSoundService.instance.playApplause();
      }
    } on DuelFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = failure.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = tr('duel.error.failed');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Scaffold(
        backgroundColor: StudentSurface.ground(context),
        appBar: AppBar(
          title: Text(tr('duel.game.sprint')),
          centerTitle: true,
          actions: const [StudentSoundToggle()],
        ),
        body: Stack(
          children: [
            SafeArea(child: _body(context)),
            Align(
              alignment: Alignment.topCenter,
              child: IgnorePointer(
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirection: math.pi / 2,
                  emissionFrequency: 0,
                  numberOfParticles: 16,
                  maxBlastForce: 16,
                  minBlastForce: 8,
                  gravity: 0.25,
                  shouldLoop: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF7C3AED)),
            const SizedBox(height: 14),
            Text(tr('duel.preparing'), style: _hint(context)),
          ],
        ),
      );
    }
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              fontWeight: FontWeight.w800,
              color: StudentSurface.ink(context),
            ),
          ),
        ),
      );
    }

    final settled = _settled;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        _Track(
          profile: widget.profile,
          opponentName: widget.opponentName,
          opponentAppearance: widget.opponentAppearance,
          mine: _correct,
          // ── وشريطُ الخصم في المؤجَّلة ──
          // نتيجتُه إن كان قد لعب، وصفرٌ إن لم يلعب بعد. فالطفل يرى ما
          // عليه أن يسبقه، أو يعرف أنه يسبق أوّلاً.
          theirs: widget.match.live ? _rivalAt : (widget.match.theirs ?? 0),
          total: _questions.length,
          live: widget.match.live,
        ),
        const SizedBox(height: 16),
        if (settled != null)
          StudentEntrance(
            child: _ResultCard(
              match: settled,
              gems: _gems,
              draw: _draw,
              opponentName: widget.opponentName,
            ),
          )
        else
          StudentEntrance(
            child: _QuestionCard(
              question: _questions[_at],
              at: _at,
              total: _questions.length,
              picked: _picked,
              busy: _sending,
              onPick: _pick,
              onNext: _next,
            ),
          ),
      ],
    );
  }

  TextStyle _hint(BuildContext context) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: StudentSurface.ink(context),
      );
}

/// الحلبة: عدّاءان يتقدّمان بعدد الإجابات الصحيحة.
class _Track extends StatelessWidget {
  const _Track({
    required this.profile,
    required this.opponentName,
    required this.opponentAppearance,
    required this.mine,
    required this.theirs,
    required this.total,
    required this.live,
  });

  final StudentProfile profile;
  final String opponentName;
  final Map<String, dynamic>? opponentAppearance;
  final int mine;
  final int theirs;
  final int total;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: StudentSurface.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _Lane(
              label: tr('duel.you'),
              appearance: profile.appearance,
              at: mine,
              total: total,
              tint: const Color(0xFF16A34A),
            ),
            const SizedBox(height: 10),
            _Lane(
              label: opponentName.isEmpty ? tr('duel.rival') : opponentName,
              appearance: opponentAppearance,
              at: theirs,
              total: total,
              tint: const Color(0xFFDC2626),
              // ونقطةٌ تقول إن كان يلعب الآن أو لعب من قبل.
              badge: live ? tr('duel.liveNow') : tr('duel.ghost'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Lane extends StatelessWidget {
  const _Lane({
    required this.label,
    required this.appearance,
    required this.at,
    required this.total,
    required this.tint,
    this.badge,
  });

  final String label;
  final Map<String, dynamic>? appearance;
  final int at;
  final int total;
  final Color tint;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final fraction = total <= 0 ? 0.0 : (at / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: StudentSurface.ink(context),
                ),
              ),
            ),
            if (badge != null)
              Text(
                badge!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: StudentSurface.mutedInk(context),
                ),
              ),
            const SizedBox(width: 6),
            Text(
              '$at/$total',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: tint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // المضمارُ: خطٌّ يمشي عليه العدّاء، وخطُّ النهاية في آخره.
        LayoutBuilder(
          builder: (context, constraints) {
            const runner = 34.0;
            final span = (constraints.maxWidth - runner).clamp(0.0, 4000.0);
            return SizedBox(
              height: runner + 8,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: runner / 2,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: tint.withValues(alpha: 0.16),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    end: 0,
                    top: 0,
                    child: Text('🏁', style: TextStyle(fontSize: runner * 0.6)),
                  ),
                  AnimatedPositionedDirectional(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    start: span * fraction,
                    top: 0,
                    child: StudentAvatarView(size: runner, appearance: appearance),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.at,
    required this.total,
    required this.picked,
    required this.busy,
    required this.onPick,
    required this.onNext,
  });

  final SprintQuestion question;
  final int at;
  final int total;
  final int? picked;
  final bool busy;
  final ValueChanged<int> onPick;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final answered = picked != null;
    return Card(
      color: StudentSurface.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              trf('duel.step', {'n': '${at + 1}', 'total': '$total'}),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: StudentSurface.mutedInk(context),
              ),
            ),
            const SizedBox(height: 10),
            // الجملةُ وفيها فراغٌ يُملأ.
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: question.before),
                  TextSpan(
                    text: ' ____ ',
                    style: TextStyle(
                      color: const Color(0xFF7C3AED),
                      fontWeight: FontWeight.w900,
                      backgroundColor:
                          const Color(0xFF7C3AED).withValues(alpha: 0.10),
                    ),
                  ),
                  TextSpan(text: question.after),
                ],
              ),
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
                fontWeight: FontWeight.w700,
                color: StudentSurface.ink(context),
              ),
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < question.options.length; index += 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _Choice(
                  text: question.options[index],
                  right: answered && index == question.answerAt,
                  wrong: answered && index == picked && index != question.answerAt,
                  onTap: answered ? null : () => onPick(index),
                ),
              ),
            if (answered) ...[
              const SizedBox(height: 6),
              FilledButton(
                onPressed: busy ? null : onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  tr(at + 1 < total ? 'duel.next' : 'duel.finish'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.text,
    required this.right,
    required this.wrong,
    required this.onTap,
  });

  final String text;
  final bool right;
  final bool wrong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (border, fill, ink) = right
        ? (
            const Color(0xFF16A34A),
            const Color(0xFFDCFCE7),
            const Color(0xFF14532D),
          )
        : wrong
            ? (
                const Color(0xFFDC2626),
                const Color(0xFFFEE2E2),
                const Color(0xFF7F1D1D),
              )
            : (
                const Color(0xFF7C3AED).withValues(alpha: 0.30),
                Colors.transparent,
                StudentSurface.ink(context),
              );
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.4),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// ما بعد الشوط: فزتَ، أو تنتظر، أو خسرت.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.match,
    required this.gems,
    required this.draw,
    required this.opponentName,
  });

  final DuelMatch match;
  final int gems;
  final bool draw;
  final String opponentName;

  @override
  Widget build(BuildContext context) {
    // ── وثلاثُ حالاتٍ لا اثنتان ──
    // «تنتظر» حالٌ كاملة: من لعب أوّلاً لم يفز ولم يخسر، وقولُ «خسرت» له
    // كذبٌ، وقولُ لا شيء يجعله يظنّ المباراةَ ضائعة.
    final (emoji, title, colors) = !match.settled
        ? (
            '⏳',
            trf('duel.waiting', {'name': opponentName}),
            const [Color(0xFFDDD6FE), Color(0xFFC4B5FD)],
          )
        : draw
            ? (
                '🤝',
                tr('duel.draw'),
                const [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
              )
            : match.iWon
                ? (
                    '🏆',
                    trf('duel.won', {'gems': '$gems'}),
                    const [Color(0xFFFDE68A), Color(0xFFFBBF24)],
                  )
                : (
                    '💪',
                    tr('duel.lost'),
                    const [Color(0xFFFEE2E2), Color(0xFFFCA5A5)],
                  );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: colors,
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 34)),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15.5,
              height: 1.55,
              fontWeight: FontWeight.w900,
              color: Color(0xFF3B2A12),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            trf('duel.scoreLine', {
              'mine': '${match.mine ?? 0}',
              'theirs': match.theirs == null ? '—' : '${match.theirs}',
            }),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF3B2A12),
            ),
          ),
        ],
      ),
    );
  }
}
