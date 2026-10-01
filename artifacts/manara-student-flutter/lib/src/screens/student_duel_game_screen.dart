import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/student_strings.dart';
import '../models/duel_chat.dart';
import '../models/sprint_question.dart';
import '../models/student_profile.dart';
import '../services/duel_voice_recorder.dart';
import '../services/student_challenge_service.dart';
import '../services/student_duel_service.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import '../widgets/duel_arenas.dart';
import '../widgets/duel_chat.dart';
import '../widgets/portal_watermark.dart';
import '../widgets/student_experience.dart';

/// مباراةُ التحدي: أربعُ ألعابٍ على محرّكٍ واحد.
///
/// ── لماذا شاشةٌ واحدةٌ لا أربع ──
/// ما يجعل المباراةَ مباراةً ليس شكلَها: بذرةٌ من معرّفها تُسأل بها الأسئلةُ
/// نفسها للخصمين، وخمسةُ أشواط، ونتيجةٌ تُرسل إلى الخادم فيحسم هو الفائزَ
/// ويصرف الجوهرة. وهذا كلُّه واحدٌ في الأربع.
///
/// ولو نُسخ أربعَ مرّات لاختلفت الأربعُ عند أوّل تعديل: تُصلَح بذرةٌ في واحدة
/// وتبقى في ثلاث، فتصير لعبةٌ عادلةً وثلاثٌ ليست — بلا خطأٍ يظهر. فالمحرّكُ
/// هنا، واللعبةُ تُغيّر ما يُرى: الحلبةَ التي يتقدّم فيها اللاعبان، وشكلَ
/// الخيارات التي تُلمس.
///
/// ── والنتيجةُ تُحسم في الخادم ──
/// هذه الشاشةُ تعدّ الصحيحَ وترسله، ولا تقول من فاز. فلا يستطيع تطبيقٌ
/// معدَّلٌ أن يدّعي فوزاً.
class StudentDuelGameScreen extends StatefulWidget {
  const StudentDuelGameScreen({
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
  State<StudentDuelGameScreen> createState() => _StudentDuelGameScreenState();
}

class _StudentDuelGameScreenState extends State<StudentDuelGameScreen> {
  /// أسئلةُ المباراة: جملةٌ ناقصةٌ وخيارات.
  List<SprintQuestion> _questions = const [];
  String? _error;
  bool _loading = true;

  int _at = 0;
  int _correct = 0;
  int? _picked;

  /// تقدّمُ الخصم كما يبثّه، في المباراة الحيّة.
  ///
  /// ويبدأ من نتيجته إن كان قد لعب: البثُّ لا يُعاد لمن دخل متأخّراً، فلو
  /// بدأ من صفرٍ لرأى الثاني خصمَه في أوّل الحلبة وقد أنهى جولتَه.
  late int _rivalAt = widget.match.theirs ?? 0;

  bool _sending = false;

  /// نتيجةُ المباراة بعد أن تُحسم في الخادم.
  DuelMatch? _settled;
  int _gems = 0;
  bool _draw = false;

  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(milliseconds: 700));

  // ── الدردشةُ في المباراة الحيّة وحدها ──
  // المؤجَّلةُ يلعب فيها كلٌّ جولتَه في وقته، فرسالةٌ تُرسل فيها لا يراها أحد:
  // القناةُ قائمةٌ لكن الطرفَ الآخر ليس عليها.
  late final bool _chatOn = widget.match.live;

  final _cooldown = DuelChatCooldown();
  final ValueNotifier<Duration> _cooldownLeft = ValueNotifier(Duration.zero);
  Timer? _cooldownTick;

  late final DuelVoiceRecorder _recorder = DuelVoiceRecorder();
  final ValueNotifier<bool> _recording = ValueNotifier(false);

  /// آخرُ ما أرسلتُه وآخرُ ما وصلني، وكلٌّ يعيش ثلاثَ ثوانٍ.
  DuelChatMessage? _myBubble;
  DuelChatMessage? _theirBubble;
  Timer? _myBubbleTimer;
  Timer? _theirBubbleTimer;

  /// أيُشغَّل مقطعٌ صوتيٌّ الآن؟ فتنبض أيقونةُ السماعة في فقاعته.
  bool _playingTheirs = false;

  /// وصلت رسالةٌ والنافذةُ مغلقة.
  bool _unread = false;
  bool _sheetOpen = false;

  DuelGame get _game {
    for (final game in DuelGame.values) {
      if (game.id == widget.match.game) return game;
    }
    // لعبةٌ لا تُعرف — صفٌّ أقدمُ من هذا البناء — تُلعب سباقاً: الأسئلةُ
    // والنتيجةُ واحدة، فلا تُفقد مباراةٌ على اسمٍ لم يُفهم.
    return DuelGame.sprint;
  }

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
            // ولا يتراجع الخصم: بثٌّ وصل متأخّراً بعد أحدثَ منه كان سيرجعه
            // خطوةً إلى الوراء أمام عين الطفل.
            setState(() => _rivalAt = math.max(_rivalAt, at));
          },
          onChat: _chatOn ? _onChat : null,
        ),
      );
      _recorder.onAutoStop = () => _endHold(cancelled: false);
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    _cooldownTick?.cancel();
    _myBubbleTimer?.cancel();
    _theirBubbleTimer?.cancel();
    _cooldownLeft.dispose();
    _recording.dispose();
    unawaited(_recorder.dispose());
    unawaited(widget.duelService.leaveMatch());
    super.dispose();
  }

  // ── الدردشة ──

  /// رسالةٌ وصلت من القناة.
  void _onChat(DuelChatMessage message) {
    if (!mounted) return;
    // ورسالتي تعود إليّ أيضاً — القناةُ تبثّ للجميع — فتُهمل: فقاعتي عُرضت
    // لحظةَ الإرسال، وعرضُها ثانيةً يُطيلها بلا سبب.
    if (message.senderId == widget.profile.id) return;
    _showBubble(message, mine: false);
    if (!_sheetOpen) setState(() => _unread = true);
    if (!message.isVoice) return;
    final audio = message.audio;
    if (audio == null) return;
    setState(() => _playingTheirs = true);
    unawaited(
      StudentSoundService.instance.playVoiceNote(
        audio,
        onDone: () {
          if (mounted) setState(() => _playingTheirs = false);
        },
      ),
    );
  }

  void _showBubble(DuelChatMessage message, {required bool mine}) {
    setState(() {
      if (mine) {
        _myBubble = message;
      } else {
        _theirBubble = message;
      }
    });
    final timer = Timer(duelBubbleLife, () {
      if (!mounted) return;
      setState(() {
        if (mine) {
          _myBubble = null;
        } else {
          _theirBubble = null;
          _playingTheirs = false;
        }
      });
    });
    if (mine) {
      _myBubbleTimer?.cancel();
      _myBubbleTimer = timer;
    } else {
      _theirBubbleTimer?.cancel();
      _theirBubbleTimer = timer;
    }
  }

  /// يبثّ رسالةً، ويعود بـ`false` إن مُنعت.
  bool _send(DuelChatMessage message) {
    // والفحصُ والتسجيلُ خطوةٌ واحدة: خطوتان يُنسى بينهما تسجيلُ ما أُرسل.
    if (!_cooldown.claim()) {
      _startCooldownTick();
      return false;
    }
    final sent = widget.duelService.sendChat(message);
    if (!sent) {
      _say(tr('duel.chat.notSent'));
      return false;
    }
    _showBubble(message, mine: true);
    _startCooldownTick();
    return true;
  }

  /// يُحدّث ما بقي من المنع كلَّ ربع ثانية، ما دام هناك بقيّة.
  void _startCooldownTick() {
    _cooldownTick?.cancel();
    void tick() {
      final left = _cooldown.remaining;
      _cooldownLeft.value = left;
      if (left == Duration.zero) _cooldownTick?.cancel();
    }

    tick();
    _cooldownTick =
        Timer.periodic(const Duration(milliseconds: 250), (_) => tick());
  }

  Future<void> _startHold() async {
    if (_recording.value) return;
    if (!_cooldown.ready) {
      _startCooldownTick();
      _say(tr('duel.chat.notSent'));
      return;
    }
    final began = await _recorder.start();
    if (!mounted) return;
    if (!began) {
      _say(tr('duel.chat.noMic'));
      return;
    }
    _recording.value = true;
  }

  Future<void> _endHold({required bool cancelled}) async {
    if (!_recording.value) return;
    _recording.value = false;
    if (cancelled) {
      await _recorder.cancel();
      return;
    }
    final note = await _recorder.stop();
    if (!mounted) return;
    if (!note.ok) {
      _say(switch (note.problem) {
        VoiceNoteProblem.tooShort => tr('duel.chat.tooShort'),
        VoiceNoteProblem.tooBig => tr('duel.chat.tooBig'),
        VoiceNoteProblem.noPermission => tr('duel.chat.noMic'),
        _ => tr('duel.chat.notSent'),
      });
      return;
    }
    _send(
      DuelChatMessage(
        senderId: widget.profile.id,
        kind: DuelChatKind.voice,
        audio: note.bytes,
      ),
    );
  }

  void _openChat() {
    setState(() {
      _sheetOpen = true;
      _unread = false;
    });
    _startCooldownTick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DuelChatSheet(
        recording: _recording,
        cooldownLeft: _cooldownLeft,
        onSendText: (text) => _send(
          DuelChatMessage(
            senderId: widget.profile.id,
            kind: DuelChatKind.text,
            text: text,
          ),
        ),
        onHoldStart: () => unawaited(_startHold()),
        onHoldEnd: ({required cancelled}) =>
            unawaited(_endHold(cancelled: cancelled)),
      ),
    ).whenComplete(() {
      // وتسجيلٌ جارٍ حين تُغلق النافذة يُلغى: لا زرَّ يُفلت عليه.
      unawaited(_endHold(cancelled: true));
      if (mounted) setState(() => _sheetOpen = false);
    });
  }

  void _say(String message) {
    if (!mounted) return;
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

  Future<void> _load() async {
    try {
      final rounds = await widget.challengeService.fetchRound(
        lessonId: widget.match.lessonId,
        count: widget.match.rounds,
        // ── والبذرةُ معرّفُ المباراة ──
        // فالخصمان يُسألان الأسئلةَ نفسها: مباراةٌ بأسئلةٍ مختلفة ليست
        // مباراة. ومباراةٌ أخرى بذرتُها أخرى، فلا تُعاد الأسئلة.
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
      HapticFeedback.lightImpact();
      StudentSoundService.instance.play(StudentSoundCue.success);
      // والخطوةُ تُبثّ فور وقوعها: الخصم يرى تقدّمي فيستعجل.
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
          title: Text(_game.label),
          centerTitle: true,
          actions: const [StudentSoundToggle()],
        ),
        body: Stack(
          children: [
            const PortalWatermark(
              asset: PortalBackgrounds.endlessReader,
              opacity: 0.20,
            ),
            SafeArea(child: _body(context)),
            // ── فقاعاتُ الكلام فوق الحلبة، لا داخلها ──
            // طبقةٌ مستقلّة: الحلباتُ أربعٌ ومنها ما لا شخصيةَ فيه (البالونات
            // والجواهر)، فلو رُسمت الفقاعةُ داخل كلِّ حلبةٍ لاحتاجت أربعَ
            // نسخٍ تفترق. وهي فوق كل شيء فلا يُزاحمها تخطيط.
            if (_chatOn)
              Positioned.fill(
                child: SafeArea(
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DuelSpeechBubble(
                            message: _myBubble,
                            appearance: widget.profile.appearance,
                            mine: true,
                            speaking: false,
                          ),
                          const Spacer(),
                          DuelSpeechBubble(
                            message: _theirBubble,
                            appearance: widget.opponentAppearance,
                            mine: false,
                            speaking: _playingTheirs,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_chatOn && _settled == null)
              PositionedDirectional(
                end: 14,
                bottom: 14,
                child: SafeArea(
                  child: DuelChatButton(onPressed: _openChat, unread: _unread),
                ),
              ),
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
            Text(
              tr('duel.preparing'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
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
        DuelArena(
          game: _game,
          mine: _correct,
          // ── وشريطُ الخصم في المؤجَّلة ──
          // نتيجتُه إن كان قد لعب، وصفرٌ إن لم يلعب بعد. فالطفل يرى ما عليه
          // أن يسبقه، أو يعرف أنه يلعب أوّلاً.
          theirs: widget.match.live ? _rivalAt : (widget.match.theirs ?? 0),
          total: _questions.length,
          live: widget.match.live,
          myAppearance: widget.profile.appearance,
          theirAppearance: widget.opponentAppearance,
          opponentName: widget.opponentName,
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
              game: _game,
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
}

/// السؤالُ وخياراتُه، بالشكل الذي تلبسه اللعبة.
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.game,
    required this.question,
    required this.at,
    required this.total,
    required this.picked,
    required this.busy,
    required this.onPick,
    required this.onNext,
  });

  final DuelGame game;
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
            const SizedBox(height: 6),
            Text(
              tr('duel.pick.${game.id}'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: StudentSurface.mutedInk(context),
              ),
            ),
            const SizedBox(height: 12),
            DuelChoices(
              game: game,
              options: question.options,
              answerAt: question.answerAt,
              picked: picked,
              onPick: onPick,
            ),
            if (answered) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy ? null : onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(
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

/// ما بعد الجولة: فزتَ، أو تنتظر، أو خسرت.
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
    // كذبٌ، وقولُ لا شيء يجعله يظنّ المباراةَ ضائعة. ونتيجتُه تُقال له في
    // الجملة نفسها: الرقمُ هو ما يطمئنه أنها حُفظت.
    final (emoji, title, colors) = !match.settled
        ? (
            '⏳',
            trf('duel.waitingScored', {
              'score': '${match.mine ?? 0}',
              'name': opponentName.isEmpty ? tr('duel.rival') : opponentName,
            }),
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
