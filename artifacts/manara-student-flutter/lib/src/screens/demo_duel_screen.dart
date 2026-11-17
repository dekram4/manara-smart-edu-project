import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../services/demo_mode.dart';
import '../services/duel_voice_recorder.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import '../widgets/chat_voice.dart';
import '../widgets/demo_lock.dart';
import '../widgets/demo_ui.dart';

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

  @override
  void initState() {
    super.initState();
    _start();
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

  /// ثلاثةُ أسئلةٍ من الدرس بترتيبٍ جديد، ثم البحثُ عن المنافس.
  void _start() {
    final pool = [
      for (final q in widget.questions)
        if ('${q['question'] ?? ''}'.trim().isNotEmpty && (q['options'] as List?)?.contains(q['answer']) == true)
          _Q('${q['question']}', [for (final o in q['options'] as List) '$o'], '${q['answer']}'),
    ]..shuffle(_random);
    setState(() {
      _round = pool.take(DemoMode.duelQuestions).toList();
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
        appBar: AppBar(
          foregroundColor: Colors.white,
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: DemoPalette.violetGradient)),
          title: Text(tr('portal.challenge'), style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: SafeArea(
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
    );
  }

  Widget _player({required String emoji, required String name, required int score, bool right = false, String? badge}) {
    return Expanded(
      child: Column(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: right ? DemoPalette.goldGradient : DemoPalette.violetGradient,
            border: Border.all(color: Colors.white, width: 2.5),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 26)),
        ),
        const SizedBox(height: 6),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        Text('$score', style: const TextStyle(color: DemoPalette.goldLight, fontWeight: FontWeight.w900, fontSize: 22)),
        if (badge != null)
          Text(badge, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _scoreboard(BuildContext context) {
    final botBadge = _phase != DemoDuelPhase.playing
        ? tr('demo.duel.botSub')
        : _botAnswered
            ? tr('demo.duel.botAnswered')
            : tr('demo.duel.botThinking');
    return Container(
      key: const ValueKey('demo-duel-score'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: DemoPalette.violetGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DemoPalette.gold, width: 1.6),
        boxShadow: [BoxShadow(color: DemoPalette.violet.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        _player(emoji: '🧒', name: tr('demo.duel.you'), score: _myScore, right: true),
        Column(children: [
          const Text('VS', style: TextStyle(color: DemoPalette.goldLight, fontWeight: FontWeight.w900, fontSize: 22)),
          if (_phase == DemoDuelPhase.playing)
            Text(
              trf('demo.duel.seconds', {'n': _left}),
              key: const ValueKey('demo-duel-timer'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
        ]),
        _player(emoji: '🤖', name: tr('demo.duel.botName'), score: _botScore, badge: botBadge),
      ]),
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
        child: Column(children: [
          const SizedBox(height: 8),
          const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3.5, color: DemoPalette.violet)),
          const SizedBox(height: 14),
          Text(tr('demo.duel.searching'),
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: StudentSurface.ink(context))),
          const SizedBox(height: 6),
          Text(trf('demo.duel.limit', {'n': DemoMode.duelQuestions}),
              textAlign: TextAlign.center, style: const TextStyle(color: DemoPalette.goldDeep, fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _question(BuildContext context) {
    final q = _round[_index];
    return _card(
      context,
      key: ValueKey('demo-duel-q-$_index'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          DemoQuotaChip(text: trf('demo.duel.questionOf', {'n': _index + 1, 'total': _round.length})),
          const Spacer(),
          if ((widget.lessonName ?? '').isNotEmpty)
            Flexible(
              child: Text(widget.lessonName!,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: DemoPalette.violet, fontWeight: FontWeight.w800)),
            ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _left / seconds,
            minHeight: 8,
            color: _left <= 5 ? const Color(0xFFDC2626) : DemoPalette.gold,
            backgroundColor: DemoPalette.violet.withValues(alpha: 0.12),
          ),
        ),
        const SizedBox(height: 14),
        Text(q.question,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, height: 1.5, color: StudentSurface.ink(context))),
        const SizedBox(height: 14),
        for (final o in q.options) ...[
          _option(context, q, o),
          const SizedBox(height: 8),
        ],
      ]),
    );
  }

  Widget _option(BuildContext context, _Q q, String o) {
    final chosen = _mine == o;
    final correct = o == q.answer;
    final Color? fill = !_reveal && !chosen
        ? null
        : correct && (_reveal || chosen)
            ? const Color(0xFF16A34A)
            : chosen
                ? const Color(0xFFDC2626)
                : null;
    return DemoPressable(
      key: ValueKey('demo-duel-option-$o'),
      onTap: () => _choose(o),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: fill ?? DemoPalette.violet.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: fill ?? DemoPalette.violet.withValues(alpha: 0.35), width: 1.4),
        ),
        child: Row(children: [
          Expanded(
            child: Text(o,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: fill != null ? Colors.white : StudentSurface.ink(context))),
          ),
          if (_reveal && _bot == o) const Text('🤖', style: TextStyle(fontSize: 18)),
          if (chosen) const Padding(padding: EdgeInsetsDirectional.only(start: 6), child: Text('🧒', style: TextStyle(fontSize: 18))),
        ]),
      ),
    );
  }

  Widget _result(BuildContext context) {
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
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: StudentSurface.ink(context))),
          const SizedBox(height: 6),
          Text(trf('demo.duel.correct', {'n': _myCorrect, 'total': _round.length}),
              textAlign: TextAlign.center, style: const TextStyle(color: DemoPalette.violet, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          DemoGradientButton(
            key: const ValueKey('demo-duel-again'),
            label: tr('demo.duel.again'),
            icon: Icons.replay_rounded,
            height: 48,
            onPressed: _start,
          ),
        ]),
      ),
      const SizedBox(height: 14),
      DemoLockedCard(key: const ValueKey('demo-duel-locked'), message: tr('demo.duel.more')),
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
