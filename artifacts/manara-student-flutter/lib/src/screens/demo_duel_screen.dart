import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/student_strings.dart';
import '../services/demo_mode.dart';
import '../services/duel_voice_recorder.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import '../widgets/arena_widgets.dart';
import '../widgets/chat_voice.dart';
import '../widgets/demo_lock.dart';
import '../widgets/demo_ui.dart';
import '../widgets/duel_versus.dart';

/// «تحدَّ زملاءك» للزائر: مباراةٌ مع شخصيةٍ افتراضية («روبوت منارة») على
/// الجهاز وحده.
///
/// حلبةُ التحدي الحقيقية تمرّ بالخادم وقنواته الحيّة، والزائرُ بلا جلسة. فهنا
/// المباراةُ نفسُها بلا شبكة: بحثٌ عن منافسٍ ثم اتصال، وثلاثةُ أسئلةٍ من الدرس
/// ([DemoMode.duelQuestions]) بعدّادٍ ونقاطٍ للسرعة، ومنافسٌ يفكّر ويجيب
/// ويخطئ أحياناً — ومعها ما في الحلبة من تفاعل: رموزٌ تطير على الشاشة،
/// ومقاطعُ صوتية، وعباراتٌ سريعة، يردّ عليها المنافس.
class DemoDuelScreen extends StatefulWidget {
  const DemoDuelScreen({
    super.key,
    required this.questions,
    this.lessonName,
    this.onGetAccount,
    this.recorder,
    this.playBytes,
    this.random,
    this.botDelay,
    this.connectDelay = const Duration(milliseconds: 1800),
  });

  /// أسئلةُ الدرس: `{question, options, answer}` — يُختار منها ثلاثة.
  final List<Map<String, dynamic>> questions;
  final String? lessonName;
  final VoidCallback? onGetAccount;

  /// للاختبار: المسجّل والمشغّل، والعشوائية، ومهلةُ جواب المنافس والاتصال.
  final DuelVoiceRecorder? recorder;
  final Future<void> Function(Uint8List bytes)? playBytes;
  final math.Random? random;
  final Duration? botDelay;
  final Duration connectDelay;

  @override
  State<DemoDuelScreen> createState() => DemoDuelScreenState();
}

enum DemoDuelPhase { connecting, playing, done }

/// أسئلةُ التحدي التي لعبها الزائرُ اليوم: ثلاثةٌ في اليوم كلِّه
/// ([DemoMode.duelQuestions]) — لا في كل مباراة.
///
/// ‏كانت «تحدٍّ جديد» تبدأ ثلاثةً أخرى بلا نهاية. فصار العدُّ على الجهاز بمفتاح
/// ‏تاريخ اليوم (`YYYY-MM-DD`): الخروجُ والرجوع لا يُعيدانه، وغداً يبدأ من
/// ‏جديد. ولا يُقرأ ولا يُكتب إلا في وضع الزائر: الحسابُ الرسمي لا يمرّ بهذه
/// ‏الشاشة أصلاً، ولا يمسّه هذا.
abstract final class DemoDuelQuota {
  static const _prefix = 'demo.duel.asked.';

  static String dayKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  /// كم سؤالاً لعب الزائرُ اليوم. صفرٌ لغير الزائر.
  static Future<int> used({DateTime? now}) async {
    if (!DemoMode.active) return 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('$_prefix${dayKey(now)}') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// يسجّل سؤالاً لُعب اليوم ويعيد العدد بعده، ويمحو ما قبل اليوم.
  static Future<int> record({DateTime? now}) async {
    if (!DemoMode.active) return 0;
    final key = '$_prefix${dayKey(now)}';
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = (prefs.getInt(key) ?? 0) + 1;
      await prefs.setInt(key, next);
      for (final old in prefs.getKeys().where((k) => k.startsWith(_prefix) && k != key).toList()) {
        await prefs.remove(old);
      }
      return next;
    } catch (_) {
      return DemoMode.duelQuestions;
    }
  }
}

class _Q {
  _Q(this.question, this.options, this.answer);
  final String question;
  final List<String> options;
  final String answer;
}

class _Msg {
  _Msg({required this.mine, this.text, this.voice, this.durationMs = 0});
  final bool mine;
  final String? text;
  final Uint8List? voice;
  final int durationMs;
}

class _Flying {
  _Flying(this.id, this.emoji, this.mine, this.x);
  final int id;
  final String emoji;
  final bool mine;
  final double x;
}

class DemoDuelScreenState extends State<DemoDuelScreen> {
  static const seconds = 15;
  static const emojis = ['👏', '🔥', '😂', '😮', '💪', '❤️'];

  late final math.Random _random = widget.random ?? math.Random();
  late final DuelVoiceRecorder _recorder =
      widget.recorder ?? DuelVoiceRecorder(maxDuration: const Duration(seconds: 8), maxBytes: chatVoiceMaxBytes);
  final List<Timer> _timers = [];
  Timer? _tick;

  DemoDuelPhase _phase = DemoDuelPhase.connecting;
  List<_Q> _round = const [];
  int _index = 0;
  int _left = seconds;
  String? _mine;
  String? _bot;
  bool _botAnswered = false;
  bool _reveal = false;
  int _myScore = 0;
  int _botScore = 0;
  int _myCorrect = 0;

  /// ما بقي للزائر من أسئلة اليوم ([DemoDuelQuota]).
  int _leftToday = DemoMode.duelQuestions;

  final List<_Msg> _messages = [];
  final List<_Flying> _flying = [];
  int _flyId = 0;
  bool _recording = false;
  int? _playing;
  final _clock = Stopwatch();

  @visibleForTesting
  DemoDuelPhase get phase => _phase;
  @visibleForTesting
  int get questionIndex => _index;
  @visibleForTesting
  int get roundLength => _round.length;
  @visibleForTesting
  int get myScore => _myScore;
  @visibleForTesting
  int get botScore => _botScore;
  @visibleForTesting
  int get messageCount => _messages.length;
  @visibleForTesting
  int get flyingCount => _flying.length;
  @visibleForTesting
  int get leftToday => _leftToday;

  /// الشخصيتان: الطالبُ بشخصيته المختارة على الجهاز، والروبوتُ بشخصيةٍ من أصول النظام.
  static const botAppearance = {'avatarId': 'a2'};

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _tick?.cancel();
    if (_playing != null) unawaited(StudentSoundService.instance.stopSpeaking());
    if (_recording) unawaited(_recorder.cancel());
    super.dispose();
  }

  void _after(Duration d, VoidCallback f) {
    late final Timer t;
    t = Timer(d, () {
      _timers.remove(t);
      if (mounted) f();
    });
    _timers.add(t);
  }

  /// ما بقي من أسئلة اليوم من الدرس بترتيبٍ جديد، ثم البحثُ عن المنافس.
  Future<void> _start() async {
    final used = await DemoDuelQuota.used();
    if (!mounted) return;
    _leftToday = math.max(0, DemoMode.duelQuestions - used);
    final pool = [
      for (final q in widget.questions)
        if ('${q['question'] ?? ''}'.trim().isNotEmpty && (q['options'] as List?)?.contains(q['answer']) == true)
          _Q('${q['question']}', [for (final o in q['options'] as List) '$o'], '${q['answer']}'),
    ]..shuffle(_random);
    setState(() {
      _round = pool.take(_leftToday).toList();
      _phase = DemoDuelPhase.connecting;
      _index = 0;
      _myScore = 0;
      _botScore = 0;
      _myCorrect = 0;
    });
    _after(widget.connectDelay, () {
      StudentSoundService.instance.play(StudentSoundCue.success);
      setState(() {
        _phase = _round.isEmpty ? DemoDuelPhase.done : DemoDuelPhase.playing;
        _messages.add(_Msg(mine: false, text: tr('demo.duel.hello')));
      });
      if (_round.isNotEmpty) _ask(0);
    });
  }

  void _ask(int i) {
    // ‏السؤالُ يُعدّ حين يُعرض: الخروجُ في منتصفه لا يعيده.
    unawaited(DemoDuelQuota.record().then((n) {
      if (mounted) setState(() => _leftToday = math.max(0, DemoMode.duelQuestions - n));
    }));
    setState(() {
      _index = i;
      _left = seconds;
      _mine = null;
      _bot = null;
      _botAnswered = false;
      _reveal = false;
    });
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _reveal) return;
      setState(() => _left = math.max(0, _left - 1));
      if (_left == 0) _settle();
    });
    // ‏المنافسُ يفكّر ثم يجيب — صائباً في أغلب المرّات.
    final think = widget.botDelay ?? Duration(milliseconds: 2000 + _random.nextInt(4500));
    _after(think, () {
      if (_reveal || _index != i) return;
      final q = _round[i];
      final right = _random.nextDouble() < 0.65;
      final wrong = q.options.where((o) => o != q.answer).toList();
      setState(() {
        _bot = right || wrong.isEmpty ? q.answer : wrong[_random.nextInt(wrong.length)];
        _botAnswered = true;
        if (_bot == q.answer) _botScore += 10 + _left;
      });
      if (_mine != null) _settle();
    });
  }

  void _choose(String option) {
    if (_mine != null || _reveal || _phase != DemoDuelPhase.playing) return;
    final q = _round[_index];
    final right = option == q.answer;
    StudentSoundService.instance.play(right ? StudentSoundCue.success : StudentSoundCue.warning);
    setState(() {
      _mine = option;
      if (right) {
        _myScore += 10 + _left;
        _myCorrect++;
      }
    });
    if (right && _random.nextBool()) _after(const Duration(milliseconds: 700), () => _fly('👏', mine: false));
    if (_botAnswered) _settle();
  }

  /// يُكشف الجوابُ الصحيح، ثم السؤالُ التالي أو النتيجة.
  void _settle() {
    if (_reveal) return;
    _tick?.cancel();
    setState(() => _reveal = true);
    _after(const Duration(milliseconds: 1600), () {
      if (_index + 1 < _round.length) {
        _ask(_index + 1);
      } else {
        setState(() => _phase = DemoDuelPhase.done);
        final won = _myScore > _botScore;
        StudentSoundService.instance.play(won ? StudentSoundCue.success : StudentSoundCue.warning);
        _after(const Duration(milliseconds: 500), () => _fly(won ? '👏' : '😎', mine: false));
      }
    });
  }

  // ── التفاعل: رموزٌ وصوتٌ وعبارات ──

  void _fly(String emoji, {required bool mine}) {
    final item = _Flying(_flyId++, emoji, mine, 0.15 + _random.nextDouble() * 0.7);
    setState(() => _flying.add(item));
    _after(const Duration(milliseconds: 1600), () => setState(() => _flying.remove(item)));
  }

  void _sendEmoji(String emoji) {
    StudentSoundService.instance.playTap();
    _fly(emoji, mine: true);
    // ‏المنافسُ يردّ أحياناً برمزٍ من عنده.
    if (_random.nextDouble() < 0.6) {
      _after(Duration(milliseconds: 600 + _random.nextInt(700)), () => _fly(emojis[_random.nextInt(emojis.length)], mine: false));
    }
  }

  void _say(String text) {
    StudentSoundService.instance.playTap();
    setState(() => _messages.add(_Msg(mine: true, text: text)));
    _botReply();
  }

  void _botReply({bool voice = false}) {
    final replies = voice
        ? [tr('demo.duel.heard')]
        : [tr('demo.duel.reply1'), tr('demo.duel.reply2'), tr('demo.duel.reply3')];
    _after(const Duration(milliseconds: 900), () {
      setState(() => _messages.add(_Msg(mine: false, text: replies[_random.nextInt(replies.length)])));
    });
  }

  void _toast(String text) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));
  }

  Future<void> _toggleVoice() async {
    if (!_recording) {
      final began = await _recorder.start();
      if (!mounted) return;
      if (!began) {
        _toast(tr('demo.chat.noMic'));
        return;
      }
      _clock
        ..reset()
        ..start();
      setState(() => _recording = true);
      return;
    }
    final note = await _recorder.stop();
    _clock.stop();
    if (!mounted) return;
    setState(() => _recording = false);
    if (!note.ok) {
      _toast(tr('demo.chat.tooShort'));
      return;
    }
    setState(() => _messages.add(_Msg(mine: true, voice: note.bytes, durationMs: _clock.elapsedMilliseconds)));
    _botReply(voice: true);
  }

  Future<void> _play(int index) async {
    final bytes = _messages[index].voice;
    if (bytes == null || _recording) return;
    final sound = StudentSoundService.instance;
    if (_playing == index) {
      await sound.stopSpeaking();
      if (mounted) setState(() => _playing = null);
      return;
    }
    if (widget.playBytes == null && sound.muted.value) {
      _toast(tr('demo.chat.soundMuted'));
      return;
    }
    setState(() => _playing = index);
    try {
      if (widget.playBytes != null) {
        await widget.playBytes!(bytes);
      } else {
        final done = Completer<void>();
        await sound.playVoiceNote(bytes, onDone: () {
          if (!done.isCompleted) done.complete();
        });
        await done.future.timeout(Duration(milliseconds: _messages[index].durationMs + 3000), onTimeout: () {});
      }
    } catch (_) {
      // ‏يتعذّر التشغيل: يبقى المقطعُ ظاهراً.
    } finally {
      if (mounted && _playing == index) setState(() => _playing = null);
    }
  }

  // ── الواجهة ──

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Scaffold(
        backgroundColor: StudentSurface.ground(context),
        extendBodyBehindAppBar: false,
        appBar: AppBar(
          foregroundColor: Colors.white,
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: DemoPalette.violetGradient)),
          title: Text(tr('portal.challenge'), style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: ArenaBackdrop(
          child: SafeArea(
          child: Stack(children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _scoreboard(context),
                    const SizedBox(height: 14),
                    switch (_phase) {
                      DemoDuelPhase.connecting => _connecting(context),
                      DemoDuelPhase.playing => _question(context),
                      DemoDuelPhase.done => _result(context),
                    },
                    const SizedBox(height: 14),
                    _reactions(context),
                    const SizedBox(height: 10),
                    _chat(context),
                  ],
                ),
              ),
            ),
            // ‏الرموزُ تطير فوق الكلّ، ولا تستقبل لمسة.
            Positioned.fill(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, box) => Stack(children: [
                    for (final f in _flying)
                      TweenAnimationBuilder<double>(
                        key: ValueKey('demo-duel-fly-${f.id}'),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1500),
                        builder: (context, t, child) => Positioned(
                          left: box.maxWidth * f.x - 22,
                          bottom: (f.mine ? 120.0 : 220.0) + t * box.maxHeight * 0.45,
                          child: Opacity(opacity: (1 - t).clamp(0, 1), child: child),
                        ),
                        child: Text(f.emoji, style: const TextStyle(fontSize: 44)),
                      ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
        ),
      ),
    );
  }

  Widget _scoreboard(BuildContext context) {
    final botBadge = _phase != DemoDuelPhase.playing
        ? tr('demo.duel.botSub')
        : _botAnswered
            ? tr('demo.duel.botAnswered')
            : tr('demo.duel.botThinking');
    return Column(
      key: const ValueKey('demo-duel-score'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DuelVersusBar(
          myName: tr('demo.duel.you'),
          rivalName: tr('demo.duel.botName'),
          myAppearance: null,
          rivalAppearance: botAppearance,
          myPoints: _myScore,
          rivalPoints: _botScore,
          live: _phase == DemoDuelPhase.playing,
        ),
        const SizedBox(height: 6),
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Container(
              key: ValueKey(botBadge),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _botAnswered ? ArenaPalette.rival.withValues(alpha: 0.14) : ArenaPalette.violet.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: (_botAnswered ? ArenaPalette.rival : ArenaPalette.violet).withValues(alpha: 0.5)),
              ),
              child: Text('🤖 $botBadge',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: StudentSurface.ink(context))),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, {required Widget child, Key? key}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: key,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF221536) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DemoPalette.gold.withValues(alpha: 0.6), width: 1.4),
        boxShadow: [BoxShadow(color: DemoPalette.violet.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _connecting(BuildContext context) => _card(
        context,
        key: const ValueKey('demo-duel-connecting'),
        child: ArenaVersus(
          myName: tr('demo.duel.you'),
          rivalName: tr('demo.duel.botName'),
          myAppearance: null,
          rivalAppearance: botAppearance,
          rivalPresent: false,
          footer: Column(children: [
            const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3.5, color: DemoPalette.violet)),
            const SizedBox(height: 12),
            Text(tr('demo.duel.searching'),
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: StudentSurface.ink(context))),
            const SizedBox(height: 6),
            DemoQuotaChip(text: trf('demo.duel.left', {'n': _leftToday, 'total': DemoMode.duelQuestions})),
          ]),
        ),
      );

  Widget _question(BuildContext context) {
    final q = _round[_index];
    return _card(
      context,
      key: ValueKey('demo-duel-q-$_index'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DemoQuotaChip(text: trf('demo.duel.questionOf', {'n': _index + 1, 'total': _round.length})),
              if ((widget.lessonName ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(widget.lessonName!,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: DemoPalette.violet, fontWeight: FontWeight.w800)),
              ],
            ]),
          ),
          // ‏حلقةُ الوقت: خضراءُ ثم ذهبيةٌ ثم حمراءُ متوهّجة في ثوانيها الأخيرة.
          Semantics(
            key: const ValueKey('demo-duel-timer'),
            label: trf('demo.duel.seconds', {'n': _left}),
            child: ArenaTimerRing(
              left: Duration(seconds: _left),
              window: const Duration(seconds: seconds),
              size: 58,
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Text(q.question,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, height: 1.5, color: StudentSurface.ink(context))),
        const SizedBox(height: 14),
        for (var i = 0; i < q.options.length; i++) ...[
          _option(context, q, i),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }

  /// حالُ الخيار: قبل الاختيار مفتوح، وبعده لونُ ما حدث — والصحيحُ يظهر عند الكشف.
  AnswerTileState _stateOf(_Q q, String o) {
    final chosen = _mine == o;
    final correct = o == q.answer;
    if (_reveal) {
      if (correct) return AnswerTileState.correct;
      return chosen ? AnswerTileState.wrong : AnswerTileState.dimmed;
    }
    if (_mine == null) return AnswerTileState.idle;
    if (chosen) return correct ? AnswerTileState.correct : AnswerTileState.wrong;
    return AnswerTileState.dimmed;
  }

  Widget _option(BuildContext context, _Q q, int index) {
    final o = q.options[index];
    final badge = [
      if (_mine == o) '🧒',
      if (_reveal && _bot == o) '🤖',
    ].join();
    return AnswerTile(
      key: ValueKey('demo-duel-option-$o'),
      index: index,
      label: o,
      state: _stateOf(q, o),
      badge: badge.isEmpty ? null : badge,
      onPressed: _mine == null && !_reveal ? () => _choose(o) : null,
    );
  }

  Widget _result(BuildContext context) {
    // ‏لعب أسئلةَ اليوم كلَّها قبل أن يفتح: بطاقةُ الترويج وحدها، لا «تعادل» بصفرٍ من صفر.
    if (_round.isEmpty) {
      return DemoLockedCard(key: const ValueKey('demo-duel-locked'), message: tr('demo.duel.dailyDone'));
    }
    final title = _myScore > _botScore
        ? tr('demo.duel.win')
        : _myScore < _botScore
            ? tr('demo.duel.lose')
            : tr('demo.duel.draw');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _card(
        context,
        key: const ValueKey('demo-duel-result'),
        child: Column(children: [
          Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
            ArenaFighter(
              appearance: _myScore >= _botScore ? null : botAppearance,
              size: 96,
              team: _myScore >= _botScore ? ArenaPalette.me : ArenaPalette.rival,
            ),
            if (_myScore != _botScore)
              const Positioned(top: -30, child: Text('👑', style: TextStyle(fontSize: 34))),
          ]),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: StudentSurface.ink(context))),
          const SizedBox(height: 6),
          Text(trf('demo.duel.correct', {'n': _myCorrect, 'total': _round.length}),
              textAlign: TextAlign.center, style: const TextStyle(color: DemoPalette.violet, fontWeight: FontWeight.w800)),
          // ‏«تحدٍّ جديد» لمن بقيت له أسئلةٌ اليوم وحده: لا ثلاثةٌ أخرى كلَّ مرّة.
          if (_leftToday > 0) ...[
            const SizedBox(height: 12),
            DemoGradientButton(
              key: const ValueKey('demo-duel-again'),
              label: tr('demo.duel.again'),
              icon: Icons.replay_rounded,
              height: 48,
              onPressed: () => unawaited(_start()),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 14),
      DemoLockedCard(
        key: const ValueKey('demo-duel-locked'),
        message: tr(_leftToday > 0 ? 'demo.duel.more' : 'demo.duel.dailyDone'),
      ),
    ]);
  }

  Widget _reactions(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in emojis)
            DemoPressable(
              key: ValueKey('demo-duel-emoji-$e'),
              onTap: () => _sendEmoji(e),
              child: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DemoPalette.gold.withValues(alpha: 0.18),
                  border: Border.all(color: DemoPalette.gold.withValues(alpha: 0.6)),
                ),
                child: Text(e, style: const TextStyle(fontSize: 22)),
              ),
            ),
        ],
      );

  Widget _chat(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final recent = _messages.length <= 4 ? 0 : _messages.length - 4;
    return _card(
      context,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = recent; i < _messages.length; i++)
          Align(
            alignment: _messages[i].mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
            child: Container(
              key: ValueKey('demo-duel-msg-$i'),
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                gradient: _messages[i].mine ? DemoPalette.violetGradient : null,
                color: _messages[i].mine ? null : (dark ? const Color(0xFF2A1C40) : const Color(0xFFFFF7E0)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: _messages[i].voice != null
                  ? ChatVoiceNoteView(
                      seed: 'duel-$i',
                      duration: Duration(milliseconds: _messages[i].durationMs),
                      playing: _playing == i,
                      loading: false,
                      mine: _messages[i].mine,
                      onTap: () => unawaited(_play(i)),
                    )
                  : Text(
                      _messages[i].text ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _messages[i].mine ? Colors.white : StudentSurface.ink(context),
                      ),
                    ),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final p in [tr('demo.duel.phrase1'), tr('demo.duel.phrase2'), tr('demo.duel.phrase3')])
            ActionChip(
              key: ValueKey('demo-duel-phrase-$p'),
              label: Text(p, style: const TextStyle(fontWeight: FontWeight.w800)),
              onPressed: () => _say(p),
            ),
          ActionChip(
            key: const ValueKey('demo-duel-voice'),
            avatar: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded,
                color: _recording ? const Color(0xFFDC2626) : DemoPalette.goldDeep),
            label: Text(tr(_recording ? 'demo.duel.voiceStop' : 'demo.duel.voice'), style: const TextStyle(fontWeight: FontWeight.w800)),
            onPressed: () => unawaited(_toggleVoice()),
          ),
        ]),
      ]),
    );
  }
}
