import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/duel_question_bank.dart';
import '../l10n/student_strings.dart';
import '../models/duel_chat.dart';
import '../models/duel_question.dart';
import '../models/student_profile.dart';
import '../services/duel_voice_recorder.dart';
import '../services/student_challenge_service.dart';
import '../services/student_duel_service.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import '../widgets/duel_arenas.dart';
import '../widgets/duel_chat.dart';
import '../widgets/duel_versus.dart';
import '../widgets/portal_watermark.dart';
import '../widgets/student_experience.dart';

/// مباراةُ التحدي: أربعُ ألعابٍ على محرّكٍ واحد.
///
/// ── لماذا شاشةٌ واحدةٌ لا أربع ──
/// ما يجعل المباراةَ مباراةً ليس شكلَها: أسئلةٌ واحدةٌ للخصمين، وعددُ أشواطٍ
/// واحد، ونقاطٌ تُحسب بحسابٍ واحد، ونتيجةٌ تُرسل إلى الخادم فيحسم هو الفائزَ
/// ويصرف الجوهرة. ولو نُسخ ذلك أربعَ مرّات لاختلفت الأربعُ عند أوّل تعديل:
/// يُصلَح حسابٌ في واحدةٍ ويبقى في ثلاث، فتصير لعبةٌ عادلةً وثلاثٌ ليست —
/// بلا خطأٍ يظهر.
///
/// فالمحرّكُ هنا، واللعبةُ تُغيّر ما يُرى: الحلبةَ وشكلَ الخيارات.
///
/// ── والأسئلةُ من بنك التطبيق، لا من الخادم ولا من الدرس ──
/// عشرةُ أسئلةٍ عامّةٍ تُبنى من معرّف المباراة بحساب الخادم نفسه — انظر
/// `buildLocalDuelPack`. فلا تتعلّق الأسئلةُ بحال الخادم: لم يُنشر، أو صفٌّ
/// بلا حزمة، أو شبكةٌ ساقطة — والمبارزةُ هي هي.
///
/// ── والنتيجةُ تُحسم في الخادم ──
/// هذه الشاشةُ تعدّ النقاطَ وترسلها، ولا تقول من فاز.
class StudentDuelGameScreen extends StatefulWidget {
  const StudentDuelGameScreen({
    required this.profile,
    required this.match,
    required this.duelService,
    required this.challengeService,
    this.opponentName = '',
    this.opponentAppearance,
    this.chatOnly = false,
    super.key,
  });

  final StudentProfile profile;
  final DuelMatch match;
  final StudentDuelService duelService;
  final StudentChallengeService challengeService;
  final String opponentName;
  final Map<String, dynamic>? opponentAppearance;

  /// تُفتح للدردشة وحدها — من زرّ الدردشة في الردهة — فلا تُلعب المباراةُ
  /// مرّةً ثانية، وتُفتح نافذةُ المحادثة فوراً.
  final bool chatOnly;

  @override
  State<StudentDuelGameScreen> createState() => _StudentDuelGameScreenState();
}

class _StudentDuelGameScreenState extends State<StudentDuelGameScreen> {
  /// أسئلةُ المباراة كما قرأها الخادم لنا.
  List<DuelQuestion> _questions = const [];
  DuelRules _rules = const DuelRules();
  String? _error;
  bool _loading = true;

  int _at = 0;
  int _correct = 0;

  /// نقاطي: عشرٌ للصحيح، وخمسٌ على الأكثر لسرعته.
  int _points = 0;
  int? _picked;

  /// ونقاطُ الخصم كما يبثّها.
  late int _rivalPoints = widget.match.theirs ?? 0;
  late int _rivalCorrect =
      ((widget.match.theirs ?? 0) / math.max(1, _rules.pointsCorrect)).floor();

  /// أيُّ سؤالٍ أجابه الخصم. وبه يُقفل السؤالُ ويُنتقل تزامناً.
  int _rivalAt = -1;

  bool _sending = false;

  /// ── عدّادُ السؤال، في الحيّة وحدها ──
  /// المؤجَّلةُ يلعب فيها الطفلُ وحده، وعدّادٌ يضغطه بلا خصمٍ يراه ضغطٌ بلا
  /// معنى — ويجعل انقطاعَ انتباهٍ لحظةً يُفقده سؤالاً.
  DateTime? _deadline;
  Timer? _tick;

  /// نتيجةُ المباراة بعد أن تُحسم في الخادم.
  DuelMatch? _settled;
  int _gems = 0;
  bool _draw = false;

  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(milliseconds: 700));

  bool get _live => widget.match.live;

  DuelChatMuteState _mute = const DuelChatMuteState();

  final _cooldown = DuelChatCooldown();
  final ValueNotifier<Duration> _cooldownLeft = ValueNotifier(Duration.zero);
  Timer? _cooldownTick;

  late final DuelVoiceRecorder _recorder = DuelVoiceRecorder();
  final ValueNotifier<bool> _recording = ValueNotifier(false);

  /// سجلُّ المحادثة: ما قُرئ من الخادم وما جرى في هذه الجلسة.
  final List<DuelChatMessage> _transcript = [];
  bool _loadingChat = false;

  /// آخرُ ما أرسلتُه وآخرُ ما وصلني، وكلٌّ يعيش ثلاثَ ثوانٍ فوق الشخصية.
  DuelChatMessage? _myBubble;
  DuelChatMessage? _theirBubble;
  Timer? _myBubbleTimer;
  Timer? _theirBubbleTimer;

  bool _playingTheirs = false;
  bool _unread = false;
  bool _sheetOpen = false;

  DuelGame get _game {
    for (final game in DuelGame.values) {
      if (game.id == widget.match.game) return game;
    }
    return DuelGame.sprint;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_loadChat());
    unawaited(
      widget.duelService.watchMatch(
        matchId: widget.match.id,
        onProgress: (id, at) {
          if (!mounted || id == widget.profile.id) return;
          // ولا يتراجع الخصم: بثٌّ وصل متأخّراً بعد أحدثَ منه كان سيرجعه
          // خطوةً إلى الوراء أمام عين الطفل.
          setState(() => _rivalCorrect = math.max(_rivalCorrect, at));
        },
        onAnswered: _live ? _onRivalAnswered : null,
        onChat: _onChat,
        onMute: _onRivalMute,
      ),
    );
    _recorder.onAutoStop = () => _endHold(cancelled: false);
    // من زرّ الدردشة في الردهة: تُفتح النافذةُ فوراً.
    if (widget.chatOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openChat();
      });
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    _tick?.cancel();
    _cooldownTick?.cancel();
    _myBubbleTimer?.cancel();
    _theirBubbleTimer?.cancel();
    _cooldownLeft.dispose();
    _recording.dispose();
    unawaited(_recorder.dispose());
    unawaited(widget.duelService.leaveMatch());
    super.dispose();
  }

  // ── تحضيرُ المباراة ──

  Future<void> _load() async {
    // ── الأسئلةُ من بنك التطبيق دائماً ──
    // كانت تُقرأ من الخادم، وإن لم يجدها عاد إلى أسئلة الدرس — فخادمٌ لم
    // يُنشر كان يُعيد الطفلَ إلى الأسئلة نفسها تتكرّر. والآن لا مسلكَ إلى
    // الدرس أصلاً: الحزمةُ تُبنى هنا من معرّف المباراة، فالجهازان يريان
    // العشرةَ نفسها بالترتيب نفسه.
    final questions = buildLocalDuelPack(widget.match.id);

    // ── والخادمُ للقواعد وحدها، ولا يُنتظر طويلاً ──
    // ثوانيَ السؤال والنقاط. وسقوطُه لا يمنع المباراة: تُلعب بالقواعد
    // المعروفة، وترسل نتيجةً يقبلها خادمٌ أقدم — انظر `_finish`.
    var rules = widget.match.rules;
    if (!widget.chatOnly) {
      try {
        final match = await widget.duelService
            .fetchMatch(widget.match.id)
            .timeout(const Duration(seconds: 6));
        rules = match.rules;
      } catch (_) {}
    }
    if (!mounted) return;

    setState(() {
      _questions = questions;
      _rules = rules;
      _loading = false;
      _error = null;
    });
    if (!widget.chatOnly) _armQuestion();
  }

  Future<void> _loadChat() async {
    setState(() => _loadingChat = true);
    try {
      final stored = await widget.duelService.messages(widget.match.id);
      if (!mounted) return;
      setState(() {
        _transcript
          ..clear()
          ..addAll(stored);
        _loadingChat = false;
        // ── ونقطةٌ إن تُرك لي شيء ──
        // المبارزةُ المؤجَّلةُ يفتحها الطفلُ فيجد رسالةً من أمسِ: بلا نقطةٍ
        // لا يعرف أنّ هناك ما يُقرأ، فلا يفتح النافذةَ أبداً.
        _unread = stored.any((message) => message.senderId != widget.profile.id);
      });
      // وتُشغَّل آخرُ رسالةٍ صوتيةٍ تُركت لي، مرّةً واحدة.
      final mine = widget.profile.id;
      for (final message in stored.reversed) {
        if (message.senderId != mine && message.isVoice) {
          _playVoice(message);
          break;
        }
      }
    } catch (_) {
      if (!mounted) return;
      // سجلٌّ لم يُقرأ لا يُسقط مباراة: تُفتح الدردشةُ فارغةً وتعمل.
      setState(() => _loadingChat = false);
    }
  }

  // ── العدّاد ──

  /// يبدأ عدّادَ السؤال الحالي، في الحيّة وحدها.
  void _armQuestion() {
    _tick?.cancel();
    if (!_live) {
      _deadline = null;
      return;
    }
    _deadline = DateTime.now().add(_rules.window);
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final left = _timeLeft;
      if (left <= Duration.zero) {
        _tick?.cancel();
        // انتهى الوقتُ ولم يُجب: يُحسب تركاً ويُنتقل.
        if (_picked == null) {
          _record(-1);
        } else {
          _advance();
        }
        return;
      }
      // ── ونبضةٌ في الثواني الثلاث الأخيرة ──
      // الرقمُ وحده لا يُرى وعينُ الطفل على الخيارات.
      if (left.inMilliseconds <= 3000 && left.inMilliseconds % 1000 < 100) {
        StudentSoundService.instance.play(StudentSoundCue.navigation);
      }
      setState(() {});
    });
  }

  Duration get _timeLeft {
    final deadline = _deadline;
    if (deadline == null) return Duration.zero;
    final left = deadline.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  // ── اللعب ──

  void _pick(int index) {
    if (_picked != null || _sending) return;
    _record(index);
  }

  /// يسجّل الجوابَ — أو تركَه حين يكون [index] سالباً — ثم يقرّر الانتقال.
  void _record(int index) {
    final question = _questions[_at];
    final right = index == question.answerAt;
    final earned = _rules.pointsFor(
      correct: right,
      left: _live ? _timeLeft : null,
    );
    setState(() {
      _picked = index < 0 ? -1 : index;
      if (right) {
        _correct += 1;
        _points += earned;
      }
    });
    if (right) {
      _confetti.play();
      HapticFeedback.lightImpact();
      StudentSoundService.instance.play(StudentSoundCue.success);
      widget.duelService.sendProgress(myId: widget.profile.id, at: _correct);
    } else if (index >= 0) {
      StudentSoundService.instance.play(StudentSoundCue.warning);
    }
    if (_live) {
      widget.duelService.sendAnswered(
        myId: widget.profile.id,
        index: _at,
        points: _points,
      );
      // ── والانتقالُ تزامناً إن كان الخصمُ قد أجاب ──
      // من أجاب أوّلاً كان ينتظر عدّادَه كلَّه بلا سبب.
      if (_rivalAt >= _at) {
        _tick?.cancel();
        unawaited(_afterBeat(_advance));
      }
    }
  }

  void _onRivalAnswered(String studentId, int index, int points) {
    if (!mounted || studentId == widget.profile.id) return;
    setState(() {
      _rivalAt = math.max(_rivalAt, index);
      _rivalPoints = math.max(_rivalPoints, points);
    });
    // وإن كنتُ قد أجبتُ هذا السؤال فقد أجاب الطرفان: يُقفل ويُنتقل.
    if (_picked != null && _rivalAt >= _at && _settled == null) {
      _tick?.cancel();
      unawaited(_afterBeat(_advance));
    }
  }

  /// لحظةٌ يرى فيها الطفلُ الجوابَ الصحيحَ قبل أن تتبدّل الشاشة.
  Future<void> _afterBeat(VoidCallback action) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) action();
  }

  void _advance() {
    if (!mounted || _settled != null || _sending) return;
    if (_at + 1 < _questions.length) {
      setState(() {
        _at += 1;
        _picked = null;
      });
      _armQuestion();
      return;
    }
    _tick?.cancel();
    unawaited(_finish());
  }

  Future<void> _next() async {
    // الزرُّ اليدويُّ للمؤجَّلة: الحيّةُ تنتقل تزامناً أو بانتهاء الوقت.
    if (_live) return;
    _advance();
  }

  Future<void> _finish() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      // ── ونتيجةٌ يقبلها الخادمُ الذي أمامنا ──
      // خادمٌ أعلن قواعدَه يقبل النقاط. وخادمٌ أقدمُ لم يُعلنها يردّ ما فوق
      // عددِ أشواطه — فيُرسل له عددُ الإجابات الصحيحة، فلا تُرفض مباراةٌ
      // لُعبت كاملة.
      final score = _rules.announced
          ? _points.clamp(0, _rules.maxScore)
          : math.min(_correct, widget.match.rounds);
      final result = await widget.duelService.submitScore(
        matchId: widget.match.id,
        score: score,
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

  // ── الدردشة ──

  void _toggleMute() {
    final next = !_mute.isChatMuted;
    setState(() {
      _mute = _mute.copyWith(isChatMuted: next);
      if (next) {
        _theirBubble = null;
        _playingTheirs = false;
        _unread = false;
      }
    });
    _theirBubbleTimer?.cancel();
    if (next) {
      unawaited(StudentSoundService.instance.stopSpeaking());
      unawaited(_endHold(cancelled: true));
    }
    widget.duelService.sendChatMute(myId: widget.profile.id, muted: next);
    _say(tr(next ? 'duel.chat.mutedOn' : 'duel.chat.mutedOff'));
  }

  void _onRivalMute(String studentId, bool muted) {
    if (!mounted || studentId == widget.profile.id) return;
    final was = _mute.isRivalMuted;
    setState(() => _mute = _mute.copyWith(isRivalMuted: muted));
    if (muted && !was && _mute.warnsRivalMuted) _say(tr('duel.chat.rivalMuted'));
  }

  void _onChat(DuelChatMessage message) {
    if (!mounted) return;
    if (message.senderId == widget.profile.id) return;
    if (!_mute.showsIncoming) {
      widget.duelService.sendChatMute(myId: widget.profile.id, muted: true);
      return;
    }
    // ── والبثُّ يُضاف إلى السجلّ أيضاً ──
    // الخادم يحفظها، لكنّ إعادةَ قراءةِ السجلّ لكل رسالةٍ تصل طلبٌ في كل
    // إيموجي. فتُضاف هنا، ويُعرف تكرارُها بمعرّفها إن أُعيدت القراءة.
    setState(() => _transcript.add(message));
    _showBubble(message, mine: false);
    if (!_sheetOpen) setState(() => _unread = true);
    if (message.isVoice && _mute.playsIncomingVoice) _playVoice(message);
  }

  void _playVoice(DuelChatMessage message) {
    final audio = message.audio;
    if (audio == null || !_mute.playsIncomingVoice) return;
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

  bool _send(DuelChatMessage message) {
    if (!_mute.canSend) {
      _say(tr('duel.chat.mutedSelf'));
      return false;
    }
    if (!_cooldown.claim()) {
      _startCooldownTick();
      return false;
    }
    // ── والبثُّ والحفظُ معاً، وسقوطُ أحدهما لا يُسقط الآخر ──
    // البثُّ للحاضر الآن، والحفظُ لمن يفتح لاحقاً. ورسالةٌ وصلت ولم تُحفظ
    // خيرٌ من لا شيء، ورسالةٌ حُفظت ولم تُبثّ تُقرأ عند الفتح.
    widget.duelService.sendChat(message);
    unawaited(
      widget.duelService.saveMessage(
        matchId: widget.match.id,
        message: message,
      ),
    );
    setState(() => _transcript.add(message));
    _showBubble(message, mine: true);
    _startCooldownTick();
    if (_mute.warnsRivalMuted) _say(tr('duel.chat.rivalMuted'));
    return true;
  }

  void _startCooldownTick() {
    _cooldownTick?.cancel();
    void beat() {
      final left = _cooldown.remaining;
      _cooldownLeft.value = left;
      if (left == Duration.zero) _cooldownTick?.cancel();
    }

    beat();
    _cooldownTick =
        Timer.periodic(const Duration(milliseconds: 250), (_) => beat());
  }

  Future<void> _startHold() async {
    if (_recording.value) return;
    if (!_mute.canSend) {
      _say(tr('duel.chat.mutedSelf'));
      return;
    }
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
        muted: _mute.isChatMuted,
        onUnmute: () {
          Navigator.of(context).pop();
          _toggleMute();
        },
        transcript: _transcript,
        myId: widget.profile.id,
        loadingTranscript: _loadingChat,
        onPlay: _playVoice,
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
        // ── زرُّ الدردشة في موضع الزرّ العائم، دائماً ──
        // كان مرسوماً داخل الـStack ومشروطاً بأن لا تكون المباراةُ قد حُسمت،
        // فلم يكن يُرى في كل حال. والزرُّ العائمُ للـScaffold يُرسم فوق كل شيء
        // في كل حال: تحميلٌ، أو خطأٌ، أو لعبٌ، أو نتيجة — بلا شرطِ اتصال.
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DuelMuteToggle(
              muted: _mute.isChatMuted,
              onPressed: _toggleMute,
            ),
            const SizedBox(height: 10),
            DuelChatButton(
              onPressed: _openChat,
              unread: _unread,
              muted: _mute.isChatMuted,
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: Stack(
          children: [
            const PortalWatermark(
              asset: PortalBackgrounds.endlessReader,
              opacity: 0.20,
            ),
            SafeArea(child: _body(context)),
            // فقاعاتُ الدردشة فوق الشخصيتين، بلا شرط.
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
    if (widget.chatOnly) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            trf('duel.chat.only', {'name': widget.opponentName}),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 140),
      children: [
        // شريطُ المقارنة: نقاطي أمام نقاطه، ومن يتقدّم يُرى.
        DuelVersusBar(
          myName: tr('duel.you'),
          rivalName: widget.opponentName,
          myAppearance: widget.profile.appearance,
          rivalAppearance: widget.opponentAppearance,
          myPoints: _points,
          rivalPoints: _live ? _rivalPoints : (widget.match.theirs ?? 0),
          live: _live,
        ),
        const SizedBox(height: 12),
        DuelArena(
          game: _game,
          mine: _correct,
          theirs: _live ? _rivalCorrect : _rivalCorrect,
          total: _questions.length,
          live: _live,
          myAppearance: widget.profile.appearance,
          theirAppearance: widget.opponentAppearance,
          opponentName: widget.opponentName,
        ),
        const SizedBox(height: 14),
        if (settled != null)
          StudentEntrance(
            child: _ResultCard(
              match: settled,
              gems: _gems,
              draw: _draw,
              opponentName: widget.opponentName,
              points: _points,
              correct: _correct,
              total: _questions.length,
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
              live: _live,
              timeLeft: _timeLeft,
              window: _rules.window,
              waitingForRival: _picked != null && _live && _rivalAt < _at,
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
    required this.live,
    required this.timeLeft,
    required this.window,
    required this.waitingForRival,
    required this.onPick,
    required this.onNext,
  });

  final DuelGame game;
  final DuelQuestion question;
  final int at;
  final int total;
  final int? picked;
  final bool busy;
  final bool live;
  final Duration timeLeft;
  final Duration window;
  final bool waitingForRival;
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
            Row(
              children: [
                // والبابُ يتقلّص قبل أن يتجاوز السطر على شاشةٍ ضيّقة.
                Flexible(child: _CategoryChip(category: question.category)),
                const SizedBox(width: 8),
                const Spacer(),
                Text(
                  trf('duel.step', {'n': '${at + 1}', 'total': '$total'}),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: StudentSurface.mutedInk(context),
                  ),
                ),
              ],
            ),
            if (live) ...[
              const SizedBox(height: 10),
              DuelCountdown(left: timeLeft, window: window),
            ],
            const SizedBox(height: 12),
            Text(
              question.prompt,
              style: TextStyle(
                fontSize: 16.5,
                height: 1.7,
                fontWeight: FontWeight.w900,
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
              // ── وفي الحيّة لا زرَّ «التالي» ──
              // الانتقالُ تزامنيٌّ: فور إجابة الطرفين أو انتهاء الوقت. وزرٌّ
              // يدويٌّ هنا يجعل من ضغطه أسبقَ إلى السؤال التالي، فتُفقد
              // المزامنةُ التي عليها يقوم العدّاد.
              if (live)
                Text(
                  tr(waitingForRival ? 'duel.waitRival' : 'duel.nextSoon'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: StudentSurface.mutedInk(context),
                  ),
                )
              else
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

/// بابُ السؤال: يُقرأ قبل الجملة فيعرف الطفلُ عمّا يُسأل.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final (emoji, tint) = switch (category) {
      'logic' => ('🧠', const Color(0xFF7C3AED)),
      'quick' => ('⚡', const Color(0xFFF59E0B)),
      'school' => ('🎒', const Color(0xFF0EA5E9)),
      'lesson' => ('📘', const Color(0xFF16A34A)),
      _ => ('🌍', const Color(0xFFDB2777)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: tint.withValues(alpha: 0.12),
        border: Border.all(color: tint.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              tr('duel.cat.$category'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: tint,
              ),
            ),
          ),
        ],
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
    required this.points,
    required this.correct,
    required this.total,
  });

  final DuelMatch match;
  final int gems;
  final bool draw;
  final String opponentName;
  final int points;
  final int correct;
  final int total;

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
              'score': '${match.mine ?? points}',
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
          const SizedBox(height: 8),
          // وتفصيلُ النقاط: كم أصاب، وكم نالت سرعتُه.
          Text(
            trf('duel.breakdown', {
              'correct': '$correct',
              'total': '$total',
              'points': '${match.mine ?? points}',
            }),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF3B2A12),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trf('duel.scoreLine', {
              'mine': '${match.mine ?? points}',
              'theirs': match.theirs == null ? '—' : '${match.theirs}',
            }),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF3B2A12),
            ),
          ),
        ],
      ),
    );
  }
}
