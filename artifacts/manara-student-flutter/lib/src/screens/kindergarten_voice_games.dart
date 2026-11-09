import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/student_strings.dart';
import '../services/kindergarten_voice_quiz.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../services/student_voice_service.dart';
import '../theme/student_theme.dart';
import '../widgets/portal_watermark.dart';
import '../widgets/voice_mic_button.dart' show ensureVoiceMic;

/// ألعابُ الروضة الصوتية في «الثقافة العامة»: الألوان، والأشكال، والحساب.
///
/// ── الجولة ──
/// «بدء اللعبة» يأتي بعشرة أسئلةٍ عشوائية جديدة ([buildKgVoiceRound]). يظهر
/// السؤالُ ويُسمع مقطعُه المسجّل («ما هذا اللون؟»)، ثم يُفتح المايكُ بضغطة:
/// يقول الطفلُ الجواب، فإن أصاب سمع «أحسنت يا بطل» والتصفيق وطار الورقُ
/// الملوّن ومضى إلى التالي؛ وإن أخطأ سمع صوتَ الإجابة الخاطئة و«حاول مرة
/// ثانية يا بطل» وبقي السؤال. وبعد ثلاث محاولاتٍ يُقال له الجوابُ ويمضي، فلا
/// يعلق طفلٌ عند سؤال.
///
/// ── والمايكُ جاهزٌ دائماً، ولا يسمع السؤال ──
/// كان المايكُ لا يُفتح إلا بعد أن ينتهي مقطعُ السؤال — وعلى أجهزةٍ لا يعود
/// فيها محرّكُ الصوت من «شغّل» بقي معطّلاً لا يستجيب لضغطٍ أبداً. فصار يستجيب
/// في كل لحظة: ضغطُه أثناء السؤال يُسكت السؤالَ ثم يسمع (فلا يكتب محرّكُ
/// التعرّف صوتَ السؤال جواباً)، ولكل مقطعٍ مهلة. وأوّلُ ضغطةٍ تطلب إذنَ
/// الميكروفون بنافذةٍ تشرح لماذا ([ensureVoiceMic]).
///
/// ── الصوتُ والأزرارُ معاً ──
/// الخياراتُ ظاهرةٌ أزراراً تحت المايك دائماً، برموزها لطفلٍ لا يقرأ بعد:
/// يقول الجوابَ أو يلمسه، وأيُّهما سبق حُكم به (ولمسُ خيارٍ والمايكُ يسمع
/// يُغلقه). كانت الأزرارُ لا تظهر إلا إن تعذّر التعرّف — فبدا ضغطُ المايك
/// كأنه «يُظهر الخيارات» لا يسمع. وإن تعذّر (لا إذن، أو لا محرّك) قيل ذلك
/// بسطرٍ صغير، وبقيت اللعبةُ تُلعب باللمس.
class KgVoiceGameScreen extends StatefulWidget {
  const KgVoiceGameScreen({
    required this.kind,
    this.random,
    this.listen,
    this.stopListening,
    this.playToEnd,
    this.cheer,
    this.speak,
    this.stopPrompt,
    this.ensureMic,
    super.key,
  });

  final KgVoiceGameKind kind;

  /// تُستبدل في الاختبار.
  final math.Random? random;

  /// يفتح المايك ويعيد ما قيل مرّةً في [onResult] (فارغاً إن لم يُسمع شيء)؛
  /// `false` إن تعذّر. وبلا قيمةٍ: [StudentVoiceService.listenForChild].
  final Future<bool> Function({required ValueChanged<String> onResult, ValueChanged<String>? onPartial})? listen;
  final Future<void> Function()? stopListening;

  /// مقطعٌ مسجّل وينتظر انتهاءه.
  final Future<void> Function(String clip)? playToEnd;

  /// التشجيعُ على إجابةٍ صحيحة («أحسنت يا بطل» وخلفها التصفيق) وينتظر العبارة.
  final Future<void> Function()? cheer;

  /// ينطق الجوابَ بعد المحاولة الثالثة.
  final Future<void> Function(String text)? speak;

  /// يُسكت مقطعَ السؤال الجاري حين يضغط الطفلُ المايكَ أثناءه.
  final Future<void> Function()? stopPrompt;

  /// إذنُ الميكروفون قبل أوّل استماع. وبلا قيمةٍ: [ensureVoiceMic].
  final Future<bool> Function(BuildContext context)? ensureMic;

  @override
  State<KgVoiceGameScreen> createState() => KgVoiceGameScreenState();
}

enum _Stage { intro, playing, done }

/// دورُ السؤال الحاضر.
enum KgTurn { prompting, ready, listening, correct, wrong, revealed }

@visibleForTesting
class KgVoiceGameScreenState extends State<KgVoiceGameScreen> {
  /// أقصى المحاولات قبل أن يُقال الجوابُ ويمضي.
  static const maxAttempts = 3;

  /// كم يرى الطفلُ نجاحه قبل السؤال التالي.
  static const celebrateFor = Duration(milliseconds: 1600);

  /// انزلاقُ السؤال خارجاً ودخولُ التالي.
  static const questionTransition = Duration(milliseconds: 450);

  /// أطولُ ما يبقى المايكُ «يسمع»: نافذةُ الاستماع (١٢ ثانية) وهامش.
  static const listenSafety = Duration(seconds: 16);

  late final math.Random _random = widget.random ?? math.Random();
  late final ConfettiController _confetti = ConfettiController(duration: const Duration(milliseconds: 700));

  _Stage _stage = _Stage.intro;
  List<KgVoiceQuestion> _round = const [];
  int _index = 0;
  int _score = 0;
  int _attempts = 0;
  KgTurn _turn = KgTurn.prompting;
  String? _heard;
  bool _notHeard = false;
  /// لماذا لم يُفتح المايكُ آخرَ مرّة — ويُمحى حين يُفتح.
  _MicProblem? _micProblem;

  /// احتياطٌ لمحرّكٍ لا يُبلغ بنهاية الاستماع أبداً: يُنهى بعد نافذته.
  Timer? _listenSafety;

  /// رقمُ السؤال الجاري: ما يعود متأخّراً من سؤالٍ سابق (صوتٌ أو مايك) يُهمَل.
  int _token = 0;

  @visibleForTesting
  KgTurn get turn => _turn;

  @visibleForTesting
  KgVoiceQuestion? get question => _stage == _Stage.playing ? _round[_index] : null;

  @visibleForTesting
  int get score => _score;

  @override
  void dispose() {
    _listenSafety?.cancel();
    _token++;
    unawaited(_stop());
    _confetti.dispose();
    super.dispose();
  }

  // ── الخدمات ─────────────────────────────────────────────────────

  /// مقطعٌ وينتظر انتهاءه — بمهلةٍ لا يتجاوزها مهما فعل محرّكُ الصوت.
  Future<void> _play(String clip) async {
    try {
      await (widget.playToEnd ??
              (clip) => StudentSoundService.instance.playClipToEnd(clip, limit: const Duration(seconds: 6)))(clip)
          .timeout(const Duration(seconds: 8));
    } catch (error) {
      debugPrint('[kg-voice] clip failed $clip: $error');
    }
  }

  /// مقطعٌ لا يُنتظر — اسمُ عددٍ يُعدّ باللمس.
  void _playQuick(String clip) {
    if (widget.playToEnd != null) {
      unawaited(_play(clip));
      return;
    }
    unawaited(StudentSoundService.instance.playClip(clip).catchError((Object _) => false));
  }

  Future<void> _stopPrompt() async {
    try {
      await (widget.stopPrompt ?? StudentSoundService.instance.stopSpeaking)();
    } catch (_) {}
  }

  /// الإذنُ مرّةً: ما سُمح به لا يُسأل عنه ثانية.
  bool _micAllowed = false;

  Future<bool> _ensureMic() async {
    if (_micAllowed) return true;
    try {
      _micAllowed = await (widget.ensureMic ?? ensureVoiceMic)(context);
    } catch (error) {
      debugPrint('[kg-voice] mic permission failed: $error');
      _micAllowed = false;
    }
    return _micAllowed;
  }

  Future<void> _cheer() async {
    try {
      final sound = StudentSoundService.instance;
      await (widget.cheer ?? () => sound.playCheerToEnd(sound.nextEncouragementClip()))();
    } catch (error) {
      debugPrint('[kg-voice] cheer failed: $error');
    }
  }

  Future<void> _say(String text) async {
    try {
      await (widget.speak ?? (text) => StudentVoiceService.instance.speakIn(text, lang: 'ar'))(text);
    } catch (error) {
      debugPrint('[kg-voice] speak failed: $error');
    }
  }

  /// يُنهي استماعَ الطفل بما قيل. إيقافُ المحرّك وحده كانت جلسةُ الطفل تراه
  /// صمتاً فتعيد فتحَ المايك — فلا تنتهي ضغطةُ الإيقاف، ولا مغادرةُ الشاشة.
  Future<void> _stop() async {
    try {
      await (widget.stopListening ?? () async => StudentVoiceService.instance.finishChildListening())();
    } catch (_) {}
  }

  Future<bool> _listen(ValueChanged<String> onResult, ValueChanged<String> onPartial) async {
    try {
      final listen = widget.listen ??
          ({required ValueChanged<String> onResult, ValueChanged<String>? onPartial}) =>
              StudentVoiceService.instance.listenForChild(
                onResult: onResult,
                onPartial: onPartial,
                locale: 'ar_SA',
                window: const Duration(seconds: 12),
                firstPause: const Duration(seconds: 6),
              );
      return await listen(onResult: onResult, onPartial: onPartial);
    } catch (error) {
      debugPrint('[kg-voice] listen failed: $error');
      return false;
    }
  }

  // ── الجولة ──────────────────────────────────────────────────────

  void _start() {
    StudentSoundService.instance.playTap();
    setState(() {
      _round = buildKgVoiceRound(widget.kind, _random);
      _index = 0;
      _score = 0;
      _stage = _Stage.playing;
    });
    unawaited(_ask());
  }

  Future<void> _ask() async {
    final token = ++_token;
    setState(() {
      _attempts = 0;
      _heard = null;
      _notHeard = false;
      _turn = KgTurn.prompting;
    });
    await _sayQuestion(token);
  }

  /// مقاطعُ السؤال بترتيبها (السؤالُ ثم المعادلة)، ما دام السؤالُ يُقال — ضغطُ
  /// المايك أثناءه يقطعها.
  Future<void> _sayQuestion(int token) async {
    for (final clip in _round[_index].promptClips) {
      if (!mounted || token != _token || _turn != KgTurn.prompting) return;
      await _play(clip);
    }
    if (!mounted || token != _token || _turn != KgTurn.prompting) return;
    setState(() => _turn = KgTurn.ready);
  }

  /// «اسمع السؤال»: يُعاد بمقاطعه.
  Future<void> _replay() async {
    if (_turn != KgTurn.ready && _turn != KgTurn.wrong) return;
    setState(() => _turn = KgTurn.prompting);
    await _sayQuestion(_token);
  }

  /// المايكُ يُضغط وقتَ السؤال كذلك — لا ينتظر الصوت.
  bool get _micOpen => _turn == KgTurn.ready || _turn == KgTurn.wrong || _turn == KgTurn.prompting;

  Future<void> _mic() async {
    if (_turn == KgTurn.listening) {
      unawaited(_stop());
      return;
    }
    if (!_micOpen) return;
    HapticFeedback.selectionClick();
    final token = _token;
    // ‏يضغطه والسؤالُ يُقال: يسكت السؤال، فلا يسمعه محرّكُ التعرّف.
    if (_turn == KgTurn.prompting) {
      setState(() => _turn = KgTurn.ready);
      await _stopPrompt();
    }
    if (!await _ensureMic()) {
      if (mounted && token == _token) {
        setState(() {
          _micProblem = _MicProblem.permission;
          _turn = KgTurn.ready;
        });
      }
      return;
    }
    if (!mounted || token != _token) return;
    setState(() {
      _turn = KgTurn.listening;
      _heard = null;
      _notHeard = false;
    });
    void onPartial(String words) {
      if (mounted && token == _token && _turn == KgTurn.listening) setState(() => _heard = words);
    }

    var started = await _listen((text) => _onHeard(token, text), onPartial);
    // ‏فشلٌ عابر (المحرّكُ لم يفرغ بعدُ من صوت السؤال أو من شاشةٍ سابقة):
    // ‏مرّةً ثانيةً قبل أن يُقال «غير متاح».
    if (!started && mounted && token == _token && _turn == KgTurn.listening) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted || token != _token || _turn != KgTurn.listening) return;
      started = await _listen((text) => _onHeard(token, text), onPartial);
    }
    if (!mounted || token != _token) return;
    if (!started) {
      if (_turn == KgTurn.listening) {
        setState(() {
          _micProblem = _MicProblem.engine;
          _turn = KgTurn.ready;
        });
      }
      return;
    }
    if (_micProblem != null) setState(() => _micProblem = null);
    _listenSafety?.cancel();
    _listenSafety = Timer(listenSafety, () {
      if (mounted && token == _token && _turn == KgTurn.listening) unawaited(_stop());
    });
  }

  void _onHeard(int token, String text) {
    if (!mounted || token != _token || _turn != KgTurn.listening) return;
    _listenSafety?.cancel();
    if (text.trim().isEmpty) {
      setState(() {
        _turn = KgTurn.ready;
        _heard = null;
        _notHeard = true;
      });
      return;
    }
    setState(() => _heard = text);
    unawaited(_judge(_round[_index].judge(text)));
  }

  /// يُجاب بلمس الخيار كذلك — والمايكُ يسمع أو لا يسمع.
  bool get _answerable => _micOpen || _turn == KgTurn.listening;

  void _choose(KgVoiceOption option) {
    if (!_answerable) return;
    HapticFeedback.selectionClick();
    final wasListening = _turn == KgTurn.listening;
    if (_turn == KgTurn.prompting) unawaited(_stopPrompt());
    setState(() {
      _heard = option.label;
      // ‏يخرج من «يسمع» قبل إغلاق المايك: ما يُسلّمه الإغلاقُ يُهمَل.
      _turn = KgTurn.ready;
    });
    if (wasListening) unawaited(_stop());
    unawaited(_judge(option.id == _round[_index].answer.id));
  }

  Future<void> _judge(bool correct) async {
    final token = _token;
    if (correct) {
      setState(() {
        _score++;
        _turn = KgTurn.correct;
      });
      _confetti.play();
      await Future.wait([_cheer(), Future<void>.delayed(celebrateFor)]);
      if (!mounted || token != _token) return;
      _next();
      return;
    }
    _attempts++;
    if (_attempts >= maxAttempts) {
      setState(() => _turn = KgTurn.revealed);
      await _play(kgWrongAnswerClip);
      if (!mounted || token != _token) return;
      await _say(trf('kg.voice.answerWas', {'answer': _round[_index].answer.label}));
      await Future<void>.delayed(celebrateFor);
      if (!mounted || token != _token) return;
      _next();
      return;
    }
    setState(() => _turn = KgTurn.wrong);
    await _play(kgWrongAnswerClip);
  }

  void _next() {
    if (_index + 1 >= _round.length) {
      _token++;
      setState(() => _stage = _Stage.done);
      StudentSoundService.instance.playApplause();
      _confetti.play();
      return;
    }
    setState(() => _index++);
    unawaited(_ask());
  }

  // ── الواجهة ─────────────────────────────────────────────────────

  static const _icons = {
    KgVoiceGameKind.colors: 'assets/images/kg_colors.png',
    KgVoiceGameKind.shapes: 'assets/images/kg_shapes.png',
    KgVoiceGameKind.math: 'assets/images/kg_math.png',
    KgVoiceGameKind.general: 'assets/images/kg_general.png',
  };

  static const _titles = {
    KgVoiceGameKind.colors: 'portal.colors',
    KgVoiceGameKind.shapes: 'portal.shapes',
    KgVoiceGameKind.math: 'portal.math',
    KgVoiceGameKind.general: 'portal.general',
  };

  static const _accents = {
    KgVoiceGameKind.colors: Color(0xFFDB2777),
    KgVoiceGameKind.shapes: Color(0xFF0EA5E9),
    KgVoiceGameKind.math: Color(0xFF16A34A),
    KgVoiceGameKind.general: Color(0xFF7C3AED),
  };

  Color get _accent => _accents[widget.kind]!;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Scaffold(
        backgroundColor: StudentSurface.ground(context),
        body: Stack(
          children: [
            const PortalWatermark(asset: PortalBackgrounds.games),
            SafeArea(
              child: Column(
                children: [
                  _topBar(context),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: switch (_stage) {
                        _Stage.intro => _intro(context),
                        _Stage.playing => _playing(context),
                        _Stage.done => _done(context),
                      },
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: IgnorePointer(
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  emissionFrequency: 0,
                  numberOfParticles: 24,
                  maxBlastForce: 20,
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

  Widget _topBar(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 0),
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('kg-voice-back'),
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
              color: StudentSurface.ink(context),
            ),
            Image.asset(_icons[widget.kind]!, width: 34, height: 34),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                tr(_titles[widget.kind]!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: StudentSurface.vivid(context, _accent),
                ),
              ),
            ),
            const Spacer(),
            if (_stage == _Stage.playing) _scoreStars(context),
          ],
        ),
      );

  Widget _scoreStars(BuildContext context) => Container(
        key: const ValueKey('kg-voice-score'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: Text(
          '⭐ $_score',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF92400E)),
        ),
      );

  // ── البداية ──

  Widget _intro(BuildContext context) => Center(
        key: const ValueKey('kg-voice-intro'),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Bobbing(child: Image.asset(_icons[widget.kind]!, width: 170, height: 170)),
              const SizedBox(height: 10),
              Text(
                tr('${_titles[widget.kind]!}.desc'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: StudentSurface.ink(context)),
              ),
              const SizedBox(height: 6),
              Text(
                tr('kg.voice.rounds'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: StudentSurface.mutedInk(context)),
              ),
              const SizedBox(height: 18),
              _BigButton(
                key: const ValueKey('kg-voice-start'),
                label: tr('kg.voice.start'),
                icon: Icons.play_arrow_rounded,
                color: _accent,
                onPressed: _start,
              ),
            ],
          ),
        ),
      );

  // ── السؤال ──

  Widget _playing(BuildContext context) {
    final q = _round[_index];
    return LayoutBuilder(
      key: const ValueKey('kg-voice-playing'),
      builder: (context, constraints) {
        final wide = constraints.maxWidth > constraints.maxHeight * 1.1;
        // ‏السؤالُ السابقُ ينزلق خارجاً ويتلاشى، والتالي يدخل من الجهة الأخرى.
        final visual = Padding(
          padding: const EdgeInsets.all(12),
          child: AnimatedSwitcher(
            duration: questionTransition,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final entering = child.key == ValueKey('kg-question-$_index');
              final from = Offset(entering ? 0.35 : -0.35, 0) *
                  (StudentSettings.direction == TextDirection.rtl ? -1 : 1);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(begin: from, end: Offset.zero).animate(animation),
                  child: child,
                ),
              );
            },
            child: _QuestionCard(
              key: ValueKey('kg-question-$_index'),
              question: q,
              index: _index,
              wrongShake: _turn == KgTurn.wrong ? _attempts : 0,
              celebrating: _turn == KgTurn.correct,
              onCount: (n) => _playQuick(kgNumberClip(n)),
            ),
          ),
        );
        final panel = _panel(context, q);
        return wide
            ? Row(children: [Expanded(flex: 6, child: visual), Expanded(flex: 4, child: panel)])
            : Column(children: [Expanded(flex: 6, child: visual), Expanded(flex: 5, child: panel)]);
      },
    );
  }

  Widget _panel(BuildContext context, KgVoiceQuestion q) {
    final status = switch (_turn) {
      KgTurn.prompting => tr('kg.voice.listenAgain'),
      KgTurn.ready => _notHeard ? tr('kg.voice.notHeard') : tr('kg.voice.tapMic'),
      KgTurn.listening => tr('kg.voice.listening'),
      KgTurn.correct => tr('kg.voice.correct'),
      KgTurn.wrong => tr('kg.voice.tryAgain'),
      KgTurn.revealed => trf('kg.voice.answerWas', {'answer': q.answer.label}),
    };
    final statusColor = switch (_turn) {
      KgTurn.correct => const Color(0xFF16A34A),
      KgTurn.wrong => const Color(0xFFDC2626),
      KgTurn.revealed => const Color(0xFFD97706),
      _ => StudentSurface.ink(context),
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _progressDots(context),
          const SizedBox(height: 4),
          Text(
            trf('kg.voice.question', {'n': _index + 1, 'total': _round.length}),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: StudentSurface.mutedInk(context)),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              status,
              key: ValueKey('kg-status-$_turn-$_notHeard'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: statusColor),
            ),
          ),
          if (_heard != null && _turn != KgTurn.prompting) ...[
            const SizedBox(height: 4),
            Text(
              trf('kg.voice.heard', {'text': _heard}),
              key: const ValueKey('kg-voice-heard'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: StudentSurface.mutedInk(context)),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MicButton(
                key: const ValueKey('kg-voice-mic'),
                listening: _turn == KgTurn.listening,
                enabled: _answerable,
                color: _accent,
                onPressed: _mic,
              ),
              const SizedBox(width: 14),
              IconButton.filledTonal(
                key: const ValueKey('kg-voice-replay'),
                tooltip: tr('kg.voice.listenAgain'),
                iconSize: 30,
                onPressed: _turn == KgTurn.ready || _turn == KgTurn.wrong ? _replay : null,
                icon: const Icon(Icons.volume_up_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tr(switch (_micProblem) {
              _MicProblem.permission => 'kg.voice.micDenied',
              _MicProblem.engine => 'kg.voice.chooseInstead',
              null => 'kg.voice.sayOrTap',
            }),
            key: const ValueKey('kg-voice-hint'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: StudentSurface.mutedInk(context)),
          ),
          const SizedBox(height: 8),
          _choices(context, q),
        ],
      ),
    );
  }

  /// أزرارُ الإجابة تحت المايك: الجوابُ وثلاثةُ خياراتٍ من نوعه، بترتيبٍ ثابت،
  /// تدخل واحداً بعد الآخر.
  Widget _choices(BuildContext context, KgVoiceQuestion q) {
    final pool = [...q.distractors]..shuffle(math.Random(_index * 31 + q.answer.id.hashCode));
    final options = [q.answer, ...pool.take(3)]..shuffle(math.Random(_index * 17 + 3));
    return Wrap(
      key: ValueKey('kg-choices-$_index'),
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (i, option) in options.indexed)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 350 + 90 * i),
            curve: Interval(0.25 * i / options.length, 1, curve: Curves.easeOutBack),
            builder: (context, t, child) => Opacity(
              opacity: t.clamp(0, 1).toDouble(),
              child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
            ),
            child: _ChoiceButton(
              key: ValueKey('kg-choice-${option.id}'),
              option: option,
              color: _vivid[i % _vivid.length],
              onPressed: _answerable ? () => _choose(option) : null,
            ),
          ),
      ],
    );
  }

  Widget _progressDots(BuildContext context) => Wrap(
        spacing: 5,
        children: [
          for (var i = 0; i < _round.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: i == _index ? 20 : 10,
              height: 10,
              decoration: BoxDecoration(
                color: i < _index
                    ? const Color(0xFF16A34A)
                    : i == _index
                        ? _accent
                        : StudentSurface.mutedInk(context).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
        ],
      );

  // ── الختام ──

  Widget _done(BuildContext context) => Center(
        key: const ValueKey('kg-voice-done'),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Bobbing(child: Text('🏆', style: TextStyle(fontSize: 96))),
              Text(
                tr('kg.voice.done'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: StudentSurface.ink(context)),
              ),
              const SizedBox(height: 6),
              Text(
                trf('kg.voice.score', {'n': _score, 'total': _round.length}),
                key: const ValueKey('kg-voice-final-score'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: StudentSurface.mutedInk(context)),
              ),
              const SizedBox(height: 8),
              Text(
                List.filled(_score, '⭐').join(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _BigButton(
                    key: const ValueKey('kg-voice-again'),
                    label: tr('kg.voice.again'),
                    icon: Icons.replay_rounded,
                    color: _accent,
                    onPressed: _start,
                  ),
                  _BigButton(
                    label: tr('kg.voice.back'),
                    icon: Icons.home_rounded,
                    color: const Color(0xFF475569),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

/// لماذا لم يُفتح المايك: لم يُسمح به، أو لم يبدأ محرّكُ التعرّف.
enum _MicProblem { permission, engine }

// ── بطاقةُ السؤال ─────────────────────────────────────────────────────

/// ألوانُ الأشكال والفقاعات: زاهيةٌ ثابتةٌ لموضع السؤال.
const _vivid = [
  Color(0xFFEF4444),
  Color(0xFF3B82F6),
  Color(0xFF22C55E),
  Color(0xFFF59E0B),
  Color(0xFFA855F7),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFFF97316),
];

/// السؤالُ يدخل بقفزةٍ ودورة، ويتمايل وهو ينتظر، ويهتزّ إن أخطأ الطفل،
/// ويكبر فرحاً إن أصاب.
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.index,
    required this.wrongShake,
    required this.celebrating,
    required this.onCount,
    super.key,
  });

  /// عددٌ عُدّ باللمس في المسألة المصوّرة: يُسمع اسمُه.
  final ValueChanged<int> onCount;

  final KgVoiceQuestion question;
  final int index;
  final int wrongShake;
  final bool celebrating;

  @override
  Widget build(BuildContext context) {
    final color = _vivid[index % _vivid.length];
    final Widget body = switch (question) {
      KgVoiceQuestion(color: final c?) => CustomPaint(
          key: const ValueKey('kg-visual-color'),
          painter: _ColorBlobPainter(c),
          size: Size.infinite,
        ),
      KgVoiceQuestion(shape: final s?) => CustomPaint(
          key: ValueKey('kg-visual-${s.name}'),
          painter: KgShapePainter(s, color),
          size: Size.infinite,
        ),
      KgVoiceQuestion(story: final story?) => KgStoryScene(story: story, onCount: onCount),
      KgVoiceQuestion(sign: final sign?) => _SignBubble(sign: sign, color: color),
      KgVoiceQuestion(general: final g?) => KgGeneralScene(question: g),
      _ => const SizedBox.shrink(),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudentSurface.card(context).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: StudentSurface.outline(context), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          builder: (context, t, child) => Transform.rotate(
            angle: (1 - t) * -0.5,
            child: Transform.scale(scale: 0.4 + 0.6 * t, child: child),
          ),
          child: TweenAnimationBuilder<double>(
            key: ValueKey('shake-$wrongShake'),
            tween: Tween(begin: wrongShake == 0 ? 1 : 0, end: 1),
            duration: const Duration(milliseconds: 500),
            builder: (context, t, child) => Transform.translate(
              offset: Offset(math.sin(t * math.pi * 6) * 14 * (1 - t), 0),
              child: child,
            ),
            child: AnimatedScale(
              scale: celebrating ? 1.12 : 1,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: _Bobbing(child: Padding(padding: const EdgeInsets.all(20), child: body)),
            ),
          ),
        ),
      ),
    );
  }
}

/// يتمايل بلطفٍ صعوداً ونزولاً — شيءٌ حيّ ينتظر الطفل.
class _Bobbing extends StatefulWidget {
  const _Bobbing({required this.child});

  final Widget child;

  @override
  State<_Bobbing> createState() => _BobbingState();
}

class _BobbingState extends State<_Bobbing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -6 * Curves.easeInOut.transform(_c.value)),
          child: child,
        ),
        child: widget.child,
      );
}

/// بقعةُ لونٍ كبيرة لامعة وقطراتٌ حولها؛ والأبيضُ بحافّةٍ تُظهره.
class _ColorBlobPainter extends CustomPainter {
  _ColorBlobPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = math.min(size.width, size.height) * 0.36;
    final light = color.computeLuminance() > 0.8;
    final edge = light ? const Color(0xFFCBD5E1) : Color.lerp(color, Colors.black, 0.25)!;
    final blob = Path();
    const lobes = 9;
    for (var i = 0; i <= 72; i++) {
      final a = i / 72 * 2 * math.pi;
      final rr = r * (1 + 0.07 * math.sin(a * lobes) + 0.04 * math.cos(a * 4));
      final p = center + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? blob.moveTo(p.dx, p.dy) : blob.lineTo(p.dx, p.dy);
    }
    blob.close();
    canvas.drawShadow(blob, Colors.black, 8, false);
    canvas.drawPath(
      blob,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [Color.lerp(color, Colors.white, light ? 0 : 0.35)!, color, Color.lerp(color, Colors.black, light ? 0.06 : 0.2)!],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: center, radius: r * 1.1)),
    );
    canvas.drawPath(
      blob,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = light ? 5 : 3
        ..color = edge,
    );
    // ‏قطراتٌ حولها.
    for (final (dx, dy, k) in const [(1.25, -0.6, 0.18), (-1.2, 0.55, 0.14), (0.9, 1.05, 0.11), (-0.95, -0.95, 0.09)]) {
      final c = center + Offset(dx * r, dy * r);
      canvas.drawCircle(c, r * k, Paint()..color = color);
      canvas.drawCircle(
        c,
        r * k,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = edge,
      );
    }
    // ‏لمعة.
    canvas.drawOval(
      Rect.fromCenter(center: center + Offset(-r * 0.35, -r * 0.42), width: r * 0.45, height: r * 0.26),
      Paint()..color = Colors.white.withValues(alpha: light ? 0.0 : 0.45),
    );
  }

  @override
  bool shouldRepaint(_ColorBlobPainter old) => old.color != color;
}

/// الأشكالُ السبعة: المسطّحةُ بتدرّجٍ وحافّة، والمجسّمةُ بوجوهٍ مظلّلة.
@visibleForTesting
class KgShapePainter extends CustomPainter {
  KgShapePainter(this.shape, this.color);

  final KgShape shape;
  final Color color;

  Color _shade(double t) => t >= 0 ? Color.lerp(color, Colors.white, t)! : Color.lerp(color, Colors.black, -t)!;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final s = math.min(size.width, size.height) * 0.78;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(3, s * 0.015)
      ..strokeJoin = StrokeJoin.round
      ..color = _shade(-0.35);
    Paint fill(Rect r) => Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_shade(0.25), color, _shade(-0.15)],
      ).createShader(r);

    void flat(Path path) {
      canvas.drawShadow(path, Colors.black, 6, false);
      canvas.drawPath(path, fill(path.getBounds()));
      canvas.drawPath(path, edge);
    }

    switch (shape) {
      case KgShape.circle:
        flat(Path()..addOval(Rect.fromCircle(center: c, radius: s * 0.42)));
      case KgShape.square:
        flat(Path()
          ..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: s * 0.74, height: s * 0.74), Radius.circular(s * 0.03))));
      case KgShape.rectangle:
        flat(Path()
          ..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: s * 1.0, height: s * 0.56), Radius.circular(s * 0.03))));
      case KgShape.parallelogram:
        final w = s * 0.8, h = s * 0.5, k = s * 0.22;
        flat(Path()
          ..moveTo(c.dx - w / 2 + k, c.dy - h / 2)
          ..lineTo(c.dx + w / 2 + k, c.dy - h / 2)
          ..lineTo(c.dx + w / 2 - k, c.dy + h / 2)
          ..lineTo(c.dx - w / 2 - k, c.dy + h / 2)
          ..close());
      case KgShape.sphere:
        final r = s * 0.4;
        canvas.drawOval(
          Rect.fromCenter(center: c + Offset(0, r * 1.02), width: r * 1.6, height: r * 0.28),
          Paint()..color = Colors.black.withValues(alpha: 0.18),
        );
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.4, -0.45),
              radius: 0.95,
              colors: [_shade(0.7), color, _shade(-0.45)],
              stops: const [0, 0.5, 1],
            ).createShader(Rect.fromCircle(center: c, radius: r)),
        );
      case KgShape.cube:
        final a = s * 0.36;
        final top = Path()
          ..moveTo(c.dx, c.dy - a * 1.0)
          ..lineTo(c.dx + a, c.dy - a * 0.5)
          ..lineTo(c.dx, c.dy)
          ..lineTo(c.dx - a, c.dy - a * 0.5)
          ..close();
        final left = Path()
          ..moveTo(c.dx - a, c.dy - a * 0.5)
          ..lineTo(c.dx, c.dy)
          ..lineTo(c.dx, c.dy + a * 1.1)
          ..lineTo(c.dx - a, c.dy + a * 0.6)
          ..close();
        final right = Path()
          ..moveTo(c.dx + a, c.dy - a * 0.5)
          ..lineTo(c.dx, c.dy)
          ..lineTo(c.dx, c.dy + a * 1.1)
          ..lineTo(c.dx + a, c.dy + a * 0.6)
          ..close();
        canvas.drawShadow(Path()..addPath(left, Offset.zero)..addPath(right, Offset.zero), Colors.black, 8, false);
        canvas.drawPath(top, Paint()..color = _shade(0.35));
        canvas.drawPath(left, Paint()..color = color);
        canvas.drawPath(right, Paint()..color = _shade(-0.28));
        for (final face in [top, left, right]) {
          canvas.drawPath(face, edge);
        }
      case KgShape.pyramid:
        final apex = c + Offset(0, -s * 0.46);
        final bl = c + Offset(-s * 0.46, s * 0.3);
        final bm = c + Offset(s * 0.06, s * 0.42);
        final br = c + Offset(s * 0.46, s * 0.26);
        final front = Path()
          ..moveTo(apex.dx, apex.dy)
          ..lineTo(bl.dx, bl.dy)
          ..lineTo(bm.dx, bm.dy)
          ..close();
        final side = Path()
          ..moveTo(apex.dx, apex.dy)
          ..lineTo(bm.dx, bm.dy)
          ..lineTo(br.dx, br.dy)
          ..close();
        canvas.drawShadow(Path()..addPath(front, Offset.zero)..addPath(side, Offset.zero), Colors.black, 8, false);
        canvas.drawPath(front, Paint()..color = _shade(0.15));
        canvas.drawPath(side, Paint()..color = _shade(-0.3));
        canvas.drawPath(front, edge);
        canvas.drawPath(side, edge);
    }
  }

  @override
  bool shouldRepaint(KgShapePainter old) => old.shape != shape || old.color != color;
}

/// علامةٌ رياضية كبيرة في فقاعةٍ لامعة.
class _SignBubble extends StatelessWidget {
  const _SignBubble({required this.sign, required this.color});

  final KgSign sign;
  final Color color;

  @override
  Widget build(BuildContext context) => Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            key: ValueKey('kg-visual-sign-${sign.name}'),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.4),
                colors: [Color.lerp(color, Colors.white, 0.45)!, color, Color.lerp(color, Colors.black, 0.25)!],
                stops: const [0, 0.6, 1],
              ),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  kgSigns[sign]!.$1,
                  style: const TextStyle(
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1,
                    shadows: [Shadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(2, 4))],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// مسألةٌ مصوّرة يعدّها الطفلُ بإصبعه: كلُّ لمسةٍ لشيءٍ تُظهر عليه رقمَه
/// وتُسمع اسمَه — وفي القسمة تنقله إلى الصندوق التالي حتى يتمّ التوزيع.
///
///   • جمع: على الشجرة 🌳 وفي السلّة 🧺، وبينهما «+».
///   • طرح: بالوناتٌ في السماء، ما طار منها شفّافٌ بعيد، ويُعدّ ما بقي.
///   • ضرب: صحونٌ 🍽️ في كلٍّ منها العددُ نفسُه.
///   • قسمة: كومةٌ تُوزَّع لمسةً لمسة على صناديق 🎁 بالتساوي.
class KgStoryScene extends StatefulWidget {
  const KgStoryScene({required this.story, required this.onCount, super.key});

  final KgStory story;
  final ValueChanged<int> onCount;

  @override
  State<KgStoryScene> createState() => _KgStorySceneState();
}

/// أصدقاءُ المسائل: واحدٌ منها في ركن كل مشهد.
const _mascots = ['🐰', '🐻', '🐥', '🐼', '🦊', '🐸', '🐵', '🐨'];

class _KgStorySceneState extends State<KgStoryScene> {
  /// ترتيبُ كل شيءٍ عُدّ (رقمُه على الشاشة)، بمفتاح موضعه.
  final Map<int, int> _counted = {};

  /// في القسمة: أين وُضع كلُّ شيء (رقمُ الصندوق)، بمفتاح موضعه في الكومة.
  final Map<int, int> _placed = {};

  KgStory get _s => widget.story;

  void _count(int slot) {
    if (_counted.containsKey(slot)) return;
    HapticFeedback.selectionClick();
    setState(() => _counted[slot] = _counted.length + 1);
    widget.onCount(_counted.length);
  }

  void _place(int slot) {
    if (_placed.containsKey(slot)) return;
    HapticFeedback.selectionClick();
    final box = _placed.length % _s.b;
    setState(() => _placed[slot] = box);
    // ‏يُعدّ ما في الصندوق الذي وُضع فيه.
    widget.onCount(_placed.values.where((b) => b == box).length);
  }

  @override
  Widget build(BuildContext context) {
    final ink = StudentSurface.ink(context);
    final sign = kgSigns[_s.sign]!.$1;
    final caption = switch (_s.sign) {
      KgSign.plus => trf('kg.math.plus', {'a': _s.a, 'b': _s.b}),
      KgSign.minus => trf('kg.math.minus', {'a': _s.a, 'b': _s.b}),
      KgSign.times => trf('kg.math.times', {'a': _s.a, 'b': _s.b}),
      KgSign.divide => trf('kg.math.divide', {'a': _s.a, 'b': _s.b}),
    };
    return Column(
      key: const ValueKey('kg-visual-story'),
      children: [
        Text(
          caption,
          key: const ValueKey('kg-story-caption'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: ink),
        ),
        const SizedBox(height: 6),
        // ‏المشهدُ والمعادلةُ باتجاه الواجهة معاً: العددُ الأوّلُ في أوّل السطر في
        // ‏كليهما (يمينَ العربية) — فالشجرةُ حيث رقمُها. وخلفه نجومٌ تلمع،
        // ‏وفي ركنه صديقٌ يقفز فرحاً مع كل شيءٍ يُعدّ.
        Expanded(
          child: Stack(
            children: [
              const Positioned.fill(child: _Twinkles()),
              Positioned.fill(child: _scene(context, sign)),
              PositionedDirectional(
                bottom: 0,
                end: 0,
                child: _Mascot(
                  emoji: _mascots[(_s.a * 7 + _s.b * 3 + _s.sign.index) % _mascots.length],
                  cheers: _counted.length + _placed.length,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_s.a} $sign ${_s.b} = ؟',
          key: const ValueKey('kg-story-equation'),
          textDirection: StudentSettings.direction,
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: ink),
        ),
        Text(
          tr('kg.math.tapToCount'),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: StudentSurface.mutedInk(context)),
        ),
      ],
    );
  }

  Widget _scene(BuildContext context, String sign) {
    final bigSign = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(sign, style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: Color(0xFFDB2777))),
    );
    switch (_s.sign) {
      case KgSign.plus:
        return FittedBox(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _box('🌳', tr('kg.voice.tree'), [for (var i = 0; i < _s.a; i++) _thing(i)], const Color(0xFFF0FDF4)),
              bigSign,
              _box('🧺', tr('kg.math.basket'), [for (var i = 0; i < _s.b; i++) _thing(_s.a + i)], const Color(0xFFFFF7ED)),
            ],
          ),
        );
      case KgSign.minus:
        return FittedBox(
          child: _box(
            '☁️',
            trf('kg.voice.flew', {'n': _s.b}),
            [
              for (var i = 0; i < _s.a; i++)
                i >= _s.a - _s.b ? _flownAway(i) : _thing(i),
            ],
            const Color(0xFFEFF6FF),
            width: 300,
          ),
        );
      case KgSign.times:
        return FittedBox(
          child: Row(
            children: [
              for (var p = 0; p < _s.a; p++) ...[
                if (p > 0) const SizedBox(width: 10),
                _box('🍽️', trf('kg.math.plate', {'n': p + 1}), [for (var i = 0; i < _s.b; i++) _thing(p * _s.b + i)],
                    const Color(0xFFFDF4FF),
                    width: 130),
              ],
            ],
          ),
        );
      case KgSign.divide:
        return FittedBox(
          child: Column(
            children: [
              _box('🧺', tr('kg.math.pile'), [
                for (var i = 0; i < _s.a; i++)
                  if (!_placed.containsKey(i))
                    GestureDetector(
                      key: ValueKey('kg-pile-$i'),
                      onTap: () => _place(i),
                      child: Text(_s.item, style: const TextStyle(fontSize: 40)),
                    ),
              ], const Color(0xFFFEFCE8), width: 360),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var b = 0; b < _s.b; b++) ...[
                    if (b > 0) const SizedBox(width: 10),
                    _box('🎁', trf('kg.math.box', {'n': b + 1}), [
                      for (final entry in _placed.entries)
                        if (entry.value == b) Text(_s.item, style: const TextStyle(fontSize: 36)),
                    ], const Color(0xFFF0F9FF), width: 120, minHeight: 70),
                  ],
                ],
              ),
            ],
          ),
        );
    }
  }

  /// شيءٌ يُعدّ باللمس: يدخل قافزاً بدوره، ويكبر ويظهر عليه رقمُه.
  Widget _thing(int slot) {
    final n = _counted[slot];
    return GestureDetector(
      key: ValueKey('kg-thing-$slot'),
      onTap: () => _count(slot),
      child: _PopIn(
        order: slot,
        child: _Wiggle(
          active: n != null,
          child: AnimatedScale(
        scale: n == null ? 1 : 1.15,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(padding: const EdgeInsets.all(2), child: Text(widget.story.item, style: const TextStyle(fontSize: 40))),
            if (n != null)
              Positioned(
                right: -4,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text('$n', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  /// ما طار: شفّافٌ مرفوعٌ قليلاً، ولا يُعدّ.
  Widget _flownAway(int slot) => Transform.translate(
        key: ValueKey('kg-flown-$slot'),
        offset: const Offset(0, -14),
        child: Opacity(
          opacity: 0.28,
          child: Padding(padding: const EdgeInsets.all(2), child: Text(widget.story.item, style: const TextStyle(fontSize: 40))),
        ),
      );

  Widget _box(String header, String label, List<Widget> children, Color color, {double width = 170, double minHeight = 0}) =>
      Container(
        width: width,
        constraints: BoxConstraints(minHeight: minHeight),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(header, style: const TextStyle(fontSize: 30)),
            Wrap(alignment: WrapAlignment.center, spacing: 2, runSpacing: 2, children: children),
            Text(
              label,
              textDirection: StudentSettings.direction,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
            ),
          ],
        ),
      );
}

// ── الأسئلةُ العامة ───────────────────────────────────────────────────

/// سؤالٌ عامّ: نصُّه مكتوباً، ورموزُ مشهده كبيرةٌ تتمايل كلٌّ بإيقاعه —
/// يلمسها الطفلُ فتقفز وتدور — وخلفها نسخٌ صغيرةٌ منها تتساقط بهدوء كالثلج
/// أو أوراق الخريف.
class KgGeneralScene extends StatefulWidget {
  const KgGeneralScene({required this.question, super.key});

  final KgGeneralQuestion question;

  @override
  State<KgGeneralScene> createState() => _KgGeneralSceneState();
}

class _KgGeneralSceneState extends State<KgGeneralScene> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  /// كم مرّةً لُمس كلُّ رمز: كلُّ لمسةٍ قفزةٌ جديدة.
  final Map<int, int> _taps = {};

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emojis = widget.question.scene.characters.toList();
    return Column(
      key: ValueKey('kg-visual-general-${widget.question.id}'),
      children: [
        Text(
          widget.question.text,
          key: const ValueKey('kg-general-text'),
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 21, height: 1.5, fontWeight: FontWeight.w900, color: StudentSurface.ink(context)),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // ‏نسخٌ صغيرةٌ شفيفة تتساقط وتتمايل.
                    for (var i = 0; i < 7; i++)
                      Positioned(
                        left: box.maxWidth * ((i * 0.37 + 0.08) % 1) + math.sin((t + i / 7) * math.pi * 4) * 12,
                        top: box.maxHeight * ((t + i / 7) % 1) - 20,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: 0.22,
                            child: Text(emojis[i % emojis.length], style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                      ),
                    Center(
                      child: FittedBox(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final (i, emoji) in emojis.indexed)
                              Transform.translate(
                                offset: Offset(0, math.sin((t * 3 + i / emojis.length) * math.pi * 2) * 10),
                                child: GestureDetector(
                                  key: ValueKey('kg-general-emoji-$i'),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _taps[i] = (_taps[i] ?? 0) + 1);
                                  },
                                  child: TweenAnimationBuilder<double>(
                                    key: ValueKey('hop-$i-${_taps[i] ?? 0}'),
                                    tween: Tween(begin: (_taps[i] ?? 0) == 0 ? 1 : 0, end: 1),
                                    duration: const Duration(milliseconds: 650),
                                    builder: (context, h, child) => Transform.translate(
                                      offset: Offset(0, -math.sin(h * math.pi) * 40),
                                      child: Transform.rotate(angle: h * math.pi * 2, child: child),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      child: Text(emoji, style: const TextStyle(fontSize: 76)),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// زرُّ خيار: رمزُه (أو بقعةُ لونه، أو شكلُه، أو رقمُه) فوق اسمه.
class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({required this.option, required this.color, required this.onPressed, super.key});

  final KgVoiceOption option;
  final Color color;
  final VoidCallback? onPressed;

  Widget _face() {
    for (final c in kgColors) {
      if (c.option.id == option.id) {
        return Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: c.color,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF94A3B8), width: 2),
          ),
        );
      }
    }
    for (final entry in kgShapes.entries) {
      if (entry.value.id == option.id) {
        return SizedBox(width: 40, height: 40, child: CustomPaint(painter: KgShapePainter(entry.key, color)));
      }
    }
    for (final entry in kgSigns.entries) {
      if (entry.value.$2.id == option.id) {
        return Text(entry.value.$1, style: TextStyle(fontSize: 30, height: 1.1, fontWeight: FontWeight.w900, color: color));
      }
    }
    if (option.emoji.isNotEmpty) return Text(option.emoji, style: const TextStyle(fontSize: 30, height: 1.1));
    final digits = RegExp(r'^n(\d+)$').firstMatch(option.id);
    if (digits != null) {
      return Text(digits.group(1)!, style: TextStyle(fontSize: 30, height: 1.1, fontWeight: FontWeight.w900, color: color));
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final digits = RegExp(r'^n(\d+)$').hasMatch(option.id);
    // ‏الرقمُ وجهُه، فيكفي اسمُه بلا تكرار الرقم.
    final label = digits ? option.label.split('—').last.trim() : option.label;
    return Material(
      color: Color.lerp(StudentSurface.card(context), color, 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: 0.55), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Opacity(
          opacity: onPressed == null ? 0.55 : 1,
          child: Container(
            constraints: const BoxConstraints(minWidth: 92),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _face(),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: StudentSurface.ink(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── حياةُ المشاهد ──────────────────────────────────────────────────────

/// نجومٌ صغيرةٌ تلمع وتخفت خلف المسألة.
class _Twinkles extends StatefulWidget {
  const _Twinkles();

  @override
  State<_Twinkles> createState() => _TwinklesState();
}

class _TwinklesState extends State<_Twinkles> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(child: CustomPaint(painter: _TwinklePainter(_c))),
      );
}

class _TwinklePainter extends CustomPainter {
  _TwinklePainter(this.t) : super(repaint: t);

  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 14; i++) {
      final x = size.width * ((i * 0.618 + 0.1) % 1);
      final y = size.height * ((i * 0.381 + 0.05) % 1);
      final glow = 0.5 + 0.5 * math.sin((t.value + i / 14) * math.pi * 2);
      final r = 2.0 + 3.5 * glow;
      final paint = Paint()..color = const Color(0xFFFBBF24).withValues(alpha: 0.18 + 0.4 * glow);
      final path = Path();
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4;
        final d = k.isEven ? r * 1.8 : r * 0.5;
        final p = Offset(x + math.cos(a) * d, y + math.sin(a) * d);
        k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path..close(), paint);
    }
  }

  @override
  bool shouldRepaint(_TwinklePainter old) => false;
}

/// صديقُ المسألة: يتمايل منتظراً، ويقفز ويدور فرحاً مع كل شيءٍ يُعدّ
/// ([cheers] يزيد) أو حين يُلمس، وتطير فوقه قلوب.
class _Mascot extends StatefulWidget {
  const _Mascot({required this.emoji, required this.cheers});

  final String emoji;
  final int cheers;

  @override
  State<_Mascot> createState() => _MascotState();
}

class _MascotState extends State<_Mascot> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);
  late final AnimationController _hop = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void didUpdateWidget(_Mascot old) {
    super.didUpdateWidget(old);
    if (widget.cheers > old.cheers) _jump();
  }

  void _jump() => _hop.forward(from: 0);

  @override
  void dispose() {
    _idle.dispose();
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const ValueKey('kg-mascot'),
        onTap: () {
          HapticFeedback.selectionClick();
          _jump();
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_idle, _hop]),
          builder: (context, child) {
            final h = _hop.value;
            final lift = math.sin(h * math.pi) * 34;
            return SizedBox(
              width: 64,
              height: 100,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  if (_hop.isAnimating)
                    Positioned(
                      bottom: 56 + h * 40,
                      child: Opacity(opacity: 1 - h, child: const Text('💖', style: TextStyle(fontSize: 20))),
                    ),
                  Transform.translate(
                    offset: Offset(0, -lift - 4 * _idle.value),
                    child: Transform.rotate(
                      angle: h * math.pi * 2 + (_idle.value - 0.5) * 0.18,
                      child: child,
                    ),
                  ),
                ],
              ),
            );
          },
          child: Text(widget.emoji, style: const TextStyle(fontSize: 46)),
        ),
      );
}

/// يدخل قافزاً بدوره: الأوّلُ أوّلاً ثم ما بعده.
class _PopIn extends StatelessWidget {
  const _PopIn({required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final total = 320 + order * 110;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(order * 110 / total, 1, curve: Curves.elasticOut),
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
      child: child,
    );
  }
}

/// يهتزّ مرّةً فرحاً حين يُعدّ.
class _Wiggle extends StatelessWidget {
  const _Wiggle({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: ValueKey(active),
        tween: Tween(begin: active ? 0 : 1, end: 1),
        duration: const Duration(milliseconds: 450),
        builder: (context, t, child) => Transform.rotate(angle: math.sin(t * math.pi * 4) * 0.25 * (1 - t), child: child),
        child: child,
      );
}


// ── الأزرار ───────────────────────────────────────────────────────────

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.icon, required this.color, required this.onPressed, super.key});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 30),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          elevation: 4,
        ),
      );
}

/// زرُّ المايك: دائرةٌ كبيرة تنبض حلقاتُها وهو يسمع.
class _MicButton extends StatefulWidget {
  const _MicButton({
    required this.listening,
    required this.enabled,
    required this.color,
    required this.onPressed,
    super.key,
  });

  final bool listening;
  final bool enabled;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.listening) _pulse.repeat();
  }

  @override
  void didUpdateWidget(_MicButton old) {
    super.didUpdateWidget(old);
    if (widget.listening && !_pulse.isAnimating) _pulse.repeat();
    if (!widget.listening && _pulse.isAnimating) _pulse.reset();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.listening ? const Color(0xFFDC2626) : widget.color;
    return Semantics(
      button: true,
      label: tr('kg.voice.tapMic'),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onPressed : null,
        child: SizedBox(
          width: 118,
          height: 118,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => Stack(
              alignment: Alignment.center,
              children: [
                if (widget.listening)
                  for (final offset in const [0.0, 0.5])
                    Builder(builder: (context) {
                      final t = (_pulse.value + offset) % 1;
                      return Container(
                        width: 84 + 34 * t,
                        height: 84 + 34 * t,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.28 * (1 - t)),
                        ),
                      );
                    }),
                child!,
              ],
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: widget.enabled ? 1 : 0.4,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color.lerp(color, Colors.white, 0.25)!, color],
                  ),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Icon(widget.listening ? Icons.stop_rounded : Icons.mic_rounded, size: 46, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
