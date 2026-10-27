import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/student_strings.dart';
import '../models/student_gamification.dart';
import '../services/quran_recitation.dart';
import '../services/student_sound_service.dart';
import '../services/student_voice_service.dart';
import '../theme/student_theme.dart';

/// سورةٌ سُمِّعت كاملةً صحيحة: مكافأتُها من الخادم، مرّةً لكل سورة.
typedef QuranRecitationWin = Future<RewardResult?> Function(QuranSurah surah);

/// استماعٌ حيّ: كلُّ ما سُمع حتى الآن مع كل كلمة، ثم انتهاء.
typedef QuranListen = Future<bool> Function({
  required ValueChanged<String> onWords,
  required VoidCallback onEnd,
});

/// ما تعرضه البطاقةُ من مكافأة السورة — والخادمُ هو من يصرفها (`QURAN_REWARD`).
const quranGemsPerSurah = 3;

/// مظهرُ بطاقة كل سورة في شاشة الاختيار: تدرّجٌ زاهٍ وأيقونةٌ كبيرة.
const _surahLooks = <String, (List<Color>, String)>{
  'fatiha': ([Color(0xFF7C3AED), Color(0xFFDB2777)], '📖'),
  'nas': ([Color(0xFF0EA5E9), Color(0xFF2563EB)], '🤲'),
  'falaq': ([Color(0xFFF97316), Color(0xFFE11D48)], '🌅'),
  'ikhlas': ([Color(0xFF10B981), Color(0xFF0D9488)], '☝️'),
  'masad': ([Color(0xFFEF4444), Color(0xFFB91C1C)], '🔥'),
  'nasr': ([Color(0xFFF59E0B), Color(0xFFEA580C)], '🌟'),
  'kafirun': ([Color(0xFF6366F1), Color(0xFF7C3AED)], '🕌'),
  'kawthar': ([Color(0xFF06B6D4), Color(0xFF0284C7)], '💧'),
};

/// لعبةُ «تسميع القرآن الكريم»: يختار الطفلُ سورةً فيسمع اسمها، ويضغط المايك
/// ويقرأ — الاستعاذةَ ثم البسملةَ ثم السورة — فيظهر تحت كل كلمةٍ في الحال
/// خطٌّ أخضرُ إن قرأها صحيحة وأحمرُ إن أخطأها أو تخطّاها ([RecitationTracker]).
/// ولا ينتقل إلى الآية التالية حتى تخضرّ الجارية كلُّها، وبجانبها زرٌّ يُسمعه
/// تلاوتها الصحيحة ليردّدها. والمايكُ يبقى مفتوحاً حتى يُغلقه. وحين تصحّ
/// السورةُ كلُّها: عبارةُ تشجيعٍ وخلفها التصفيق، والمكافأةُ لأول مرّة.
class QuranRecitationGame extends StatefulWidget {
  const QuranRecitationGame({
    required this.onRecited,
    required this.onBack,
    this.listen,
    this.stopListening,
    this.playName,
    this.playRecitation,
    this.surahs = quranSurahs,
    super.key,
  });

  final QuranRecitationWin onRecited;

  /// العودةُ إلى رفّ الألعاب.
  final VoidCallback onBack;

  /// للاختبار: محرّكُ تعرّفٍ مزيّف. وإلا [StudentVoiceService.listenLive].
  final QuranListen? listen;
  final Future<void> Function()? stopListening;

  /// للاختبار: تشغيلُ اسم السورة. وإلا [StudentSoundService.playClip].
  final void Function(String asset)? playName;

  /// للاختبار: تلاوةُ آيةٍ حتى آخرها. وإلا [StudentSoundService.playClipToEnd].
  final Future<void> Function(String asset)? playRecitation;

  final List<QuranSurah> surahs;

  @override
  State<QuranRecitationGame> createState() => QuranRecitationGameState();
}

@visibleForTesting
class QuranRecitationGameState extends State<QuranRecitationGame> with TickerProviderStateMixin {
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFDC2626);
  static const emerald = Color(0xFF059669);
  static const teal = Color(0xFF0D9488);
  static const gold = Color(0xFFF59E0B);

  late final AnimationController _pulse;

  /// ساعةُ بطاقات السور: ظلٌّ يتنفّس وأيقونةٌ تطفو.
  late final AnimationController _shine;

  QuranSurah? _surah;
  RecitationTracker? _tracker;

  /// آخرُ ما سُمع في الاستماع الجاري — يُعاد تقديمه عند انتهائه.
  String _heard = '';

  /// فتح الطفلُ المايكَ ولم يُغلقه: ما يُنهيه النظامُ (صمتٌ أو مهلة) يُفتح من
  /// جديد، فيبقى مفتوحاً ما دام يقرأ.
  bool _wantListening = false;
  bool _listening = false;

  /// تُسمَع التلاوةُ الصحيحة الآن، والمايكُ مغلقٌ لها.
  bool _helping = false;

  /// آخرُ كلمةٍ سمعها المحرّك: تظهر تحت النصّ لحظةَ تُسمع، فيرى الطفلُ أن
  /// صوته وصل.
  String? _lastHeard;

  /// رقمُ الاستماع الجاري: ما يصل من استماعٍ سابقٍ لا يُحسب.
  int _session = 0;
  int _endedSession = -1;

  bool _done = false;
  String? _message;
  int? _gems;
  bool _alreadyRewarded = false;
  final Set<String> _recited = {};

  /// للاختبار: حالُ كل كلمةٍ في السورة المفتوحة، من الاستعاذة إلى آخرها.
  @visibleForTesting
  List<RecitedWord> get status => _tracker?.status ?? const [];

  @visibleForTesting
  RecitationTracker? get tracker => _tracker;

  @visibleForTesting
  bool get done => _done;

  @visibleForTesting
  bool get listening => _listening;

  @override
  void initState() {
    super.initState();
    // هنا لا كسولاً: أوّلُ من يلمسهما قد يكون dispose، والتكّةُ لا تُنشأ بعد
    // أن تخرج الشجرة.
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _shine = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (still) {
      _shine.stop();
    } else if (!_shine.isAnimating && _surah == null) {
      _shine.repeat();
    }
  }

  @override
  void dispose() {
    _wantListening = false;
    if (_listening) unawaited(_stop());
    _pulse.dispose();
    _shine.dispose();
    super.dispose();
  }

  bool get _still => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  Future<void> _stop() => (widget.stopListening ?? StudentVoiceService.instance.stopListening)();

  void _open(QuranSurah surah) {
    HapticFeedback.lightImpact();
    // اسمُ السورة بصوتٍ مسجّل، لحظةَ اختيارها.
    final playName = widget.playName ?? (asset) => StudentSoundService.instance.playClip(asset, volume: 1.0);
    playName(surah.nameClip);
    // ساعةُ البطاقات لا تدور خلف التلاوة.
    _shine.stop();
    setState(() {
      _surah = surah;
      _reset();
    });
  }

  void _reset() {
    final surah = _surah;
    _tracker = surah == null ? null : RecitationTracker(surah);
    _heard = '';
    _lastHeard = null;
    _done = false;
    _message = null;
    _gems = null;
    _alreadyRewarded = false;
  }

  Future<void> _quiet() async {
    _wantListening = false;
    if (_listening) await _stop();
    _onEnd(_session);
  }

  Future<void> _close() async {
    await _quiet();
    if (!mounted) return;
    setState(() {
      _surah = null;
      _tracker = null;
    });
    if (!_still) _shine.repeat();
  }

  /// السورةُ السابقة أو التالية في القائمة، من شاشة التسميع نفسها.
  Future<void> _step(int delta) async {
    final surah = _surah;
    if (surah == null) return;
    final index = widget.surahs.indexOf(surah) + delta;
    if (index < 0 || index >= widget.surahs.length) return;
    await _quiet();
    if (!mounted) return;
    _open(widget.surahs[index]);
  }

  Future<void> _restart() async {
    await _quiet();
    if (!mounted) return;
    setState(_reset);
  }

  Future<void> _toggleMic() async {
    if (_done || _tracker == null || _helping) return;
    if (_wantListening) {
      await _quiet();
      return;
    }
    _wantListening = true;
    setState(() => _message = null);
    HapticFeedback.mediumImpact();
    await _startListening();
  }

  Future<void> _startListening() async {
    final tracker = _tracker;
    if (tracker == null || !_wantListening || _done || _helping) return;
    final session = ++_session;
    tracker.startSession();
    _heard = '';
    final listen = widget.listen ?? StudentVoiceService.instance.listenLive;
    final started = await listen(onWords: (words) => _onWords(session, words), onEnd: () => _onEnd(session));
    if (!mounted || session != _session) return;
    if (!started) {
      _wantListening = false;
      StudentSoundService.instance.play(StudentSoundCue.warning);
      _pulse.stop();
      setState(() {
        _listening = false;
        _message = tr('quran.micUnavailable');
      });
      return;
    }
    setState(() => _listening = true);
    if (!_still && !_pulse.isAnimating) _pulse.repeat(reverse: true);
  }

  void _onWords(int session, String heard) {
    final tracker = _tracker;
    if (!mounted || session != _session || _done || _helping || tracker == null) return;
    _heard = heard;
    setState(() {
      tracker.hear(heard);
      final words = heard.trim().split(RegExp(r'\s+'));
      _lastHeard = heard.trim().isEmpty ? null : words.last;
    });
    if (tracker.complete) unawaited(_complete());
  }

  void _onEnd(int session) {
    if (!mounted || session == _endedSession) return;
    _endedSession = session;
    final tracker = _tracker;
    if (session == _session) tracker?.hear(_heard, ended: true);
    setState(() => _listening = false);
    if (tracker != null && tracker.complete) {
      unawaited(_complete());
      return;
    }
    if (_wantListening && !_helping && !_done) {
      // أغلقه النظامُ والطفلُ لم يُغلقه: يُفتح من جديد في الحال — كلُّ
      // لحظةٍ بين استماعين كلماتٌ تضيع.
      scheduleMicrotask(() {
        if (mounted) unawaited(_startListening());
      });
    } else {
      _pulse.stop();
    }
  }

  /// التلاوةُ الصحيحة للخطوة الجارية، والمايكُ مغلقٌ لها — ثم يُفتح ليردّد.
  Future<void> _help(RecitationUnit unit) async {
    if (_helping) return;
    final resume = _wantListening;
    setState(() => _helping = true);
    if (_listening) {
      await _stop();
      _onEnd(_session);
    }
    final play = widget.playRecitation ??
        (asset) => StudentSoundService.instance.playClipToEnd(asset, volume: 1.0);
    await play(unit.clip);
    if (!mounted) return;
    setState(() => _helping = false);
    if (resume && _wantListening && !_done) await _startListening();
  }

  Future<void> _complete() async {
    final surah = _surah;
    if (surah == null || _done) return;
    _wantListening = false;
    setState(() {
      _done = true;
      _listening = false;
      _pulse.stop();
      _recited.add(surah.id);
    });
    unawaited(_stop());
    // عبارةُ تشجيعٍ وخلفها التصفيق — ولا لحنَ معهما.
    StudentSoundService.instance.playApplause();
    try {
      final result = await widget.onRecited(surah);
      if (!mounted || _surah != surah) return;
      setState(() {
        _gems = result?.gems ?? 0;
        _alreadyRewarded = result?.alreadyRewarded ?? false;
      });
      if ((result?.gems ?? 0) > 0) StudentSoundService.instance.playReward();
    } catch (error) {
      debugPrint('[quran] reward failed for ${surah.id}: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final surah = _surah;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      child: surah == null
          ? _picker(context)
          : KeyedSubtree(key: ValueKey('quran-${surah.id}'), child: _reciting(context, surah)),
    );
  }

  // ── اختيارُ السورة ─────────────────────────────────────────────────

  Widget _picker(BuildContext context) {
    return Column(
      key: const ValueKey('quran-picker'),
      children: [
        _topBar(context, tr('quran.title'), widget.onBack),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
          child: Text(
            tr('quran.pick'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: StudentSurface.ink(context)),
          ),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final columns = box.maxWidth >= 760 ? 4 : (box.maxWidth >= 460 ? 3 : 2);
            return GridView.count(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
              crossAxisCount: columns,
              mainAxisSpacing: 18,
              crossAxisSpacing: 16,
              childAspectRatio: 0.92,
              children: [
                for (var i = 0; i < widget.surahs.length; i++) _surahTile(widget.surahs[i], i),
              ],
            );
          }),
        ),
      ],
    );
  }

  /// ‎0..1 ذهاباً وإياباً، من ساعة البطاقات — بإزاحة [phase] من دورتها.
  double _wave(double phase) => 0.5 - 0.5 * math.cos(2 * math.pi * ((_shine.value + phase) % 1.0));

  Widget _surahTile(QuranSurah surah, int index) {
    final recited = _recited.contains(surah.id);
    final (colors, icon) = _surahLooks[surah.id] ?? (const [emerald, teal], '📖');
    return Semantics(
      button: true,
      label: trf('quran.surah', {'name': surah.name}),
      child: GestureDetector(
        key: ValueKey('quran-surah-${surah.id}'),
        onTap: () => _open(surah),
        child: AnimatedBuilder(
          animation: _shine,
          builder: (context, _) {
            final glow = _shine.isAnimating ? _wave(index * 0.12) : 0.5;
            final float = _shine.isAnimating ? _wave(index * 0.12 + 0.25) : 0.0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: colors.first.withValues(alpha: 0.35 + 0.3 * glow),
                          blurRadius: 14 + 14 * glow,
                          spreadRadius: 1 + 3 * glow,
                          offset: Offset(0, 6 + 4 * glow),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Transform.translate(
                          offset: Offset(0, -6 * float),
                          child: Container(
                            width: 84,
                            height: 84,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.24),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
                            ),
                            child: Text(icon, style: const TextStyle(fontSize: 50)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            surah.name,
                            style: const TextStyle(
                              fontSize: 30,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: [Shadow(color: Color(0x80000000), offset: Offset(0, 3), blurRadius: 6)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (recited)
                  PositionedDirectional(
                    top: -10,
                    end: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Text(
                        tr('quran.recited'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: green),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, String title, VoidCallback onBack) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('quran-back'),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: StudentSurface.ink(context),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: StudentSurface.ink(context)),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ── التلاوة ────────────────────────────────────────────────────────

  String? _hintText(RecitationTracker tracker) {
    if (_message != null) return _message;
    if (_done) return null;
    if (_helping) return tr('quran.helping');
    if (tracker.blocked) return tr('quran.blocked');
    if (_listening) return tr('quran.listening');
    if (tracker.currentUnit == 0 && !tracker.status.contains(RecitedWord.correct)) return tr('quran.tapMic');
    return tr('quran.continue');
  }

  Widget _reciting(BuildContext context, QuranSurah surah) {
    final tracker = _tracker!;
    final hint = _hintText(tracker);
    return Column(
      children: [
        _topBar(context, trf('quran.surah', {'name': surah.name}), _close),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              if (_done) ...[
                _doneBanner(),
                const SizedBox(height: 12),
              ] else if (hint != null) ...[
                _hint(context, hint, strong: tracker.blocked && !_helping),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
                decoration: BoxDecoration(
                  color: StudentSurface.card(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: emerald.withValues(alpha: 0.35), width: 2),
                  boxShadow: [BoxShadow(color: emerald.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 5))],
                ),
                child: _units(context, tracker),
              ),
              if (_wantListening && _lastHeard != null && !_done) ...[
                const SizedBox(height: 10),
                Center(child: _heardChip(_lastHeard!)),
              ],
            ],
          ),
        ),
        // تحت النصّ دائماً، لا في آخر ما يُمرَّر إليه.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: _surahNav(surah),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                key: const ValueKey('quran-restart'),
                onPressed: _restart,
                icon: const Icon(Icons.replay_rounded),
                label: Text(tr('quran.again'), style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 18),
              _micButton(),
              const SizedBox(width: 18 + 48),
            ],
          ),
        ),
      ],
    );
  }

  /// الخطواتُ بترتيبها: ما قُرئ أخضر، والجاريةُ مظلّلة وبجانبها زرُّ
  /// «استمع» إن كان فيها أحمر، وما بعدها باهتٌ حتى يُبلغ.
  Widget _units(BuildContext context, RecitationTracker tracker) {
    final unitOf = tracker.unitOf;
    final current = tracker.currentUnit;
    final children = <Widget>[];
    for (var u = 0; u < tracker.units.length; u++) {
      final unit = tracker.units[u];
      final isCurrent = u == current && !_done;
      final words = [
        for (var k = 0; k < unitOf.length; k++)
          if (unitOf[k] == u) _word(context, tracker, k, isCurrent: isCurrent),
      ];
      children.add(AnimatedOpacity(
        key: ValueKey('quran-unit-$u'),
        duration: const Duration(milliseconds: 220),
        opacity: u > current && !_done ? 0.42 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
          decoration: BoxDecoration(
            color: isCurrent
                ? gold.withValues(alpha: tracker.blocked ? 0.2 : 0.12)
                : (unit.kind == RecitationUnitKind.verse ? null : emerald.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(16),
            border: isCurrent ? Border.all(color: gold.withValues(alpha: 0.6), width: 2) : null,
          ),
          child: Column(
            children: [
              if (unit.kind != RecitationUnitKind.verse)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(color: emerald, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    tr(unit.kind == RecitationUnitKind.istiadha ? 'quran.istiadha' : 'quran.basmala'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...words,
                  if (unit.number != null)
                    Text(
                      '﴿${_arabicDigits(unit.number!)}﴾',
                      style: const TextStyle(fontSize: 20, height: 2.1, fontWeight: FontWeight.w800, color: gold),
                    ),
                  if (isCurrent && tracker.blocked) _helpButton(unit),
                ],
              ),
            ],
          ),
        ),
      ));
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  /// آخرُ ما سُمع، لحظةَ يُسمع.
  Widget _heardChip(String word) => Container(
        key: const ValueKey('quran-heard'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: teal.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: teal.withValues(alpha: 0.4)),
        ),
        child: Text(
          '🎙️ $word',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: teal),
        ),
      );

  /// السورةُ السابقة والتالية: ينتقل الطفلُ إليهما دون الرجوع إلى القائمة.
  Widget _surahNav(QuranSurah surah) {
    final index = widget.surahs.indexOf(surah);
    final hasPrev = index > 0;
    final hasNext = index >= 0 && index < widget.surahs.length - 1;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // ‏بترتيب القراءة: السابقةُ في البداية (يمين العربية) والتالية في النهاية.
    return Row(
      children: [
        _navButton(
          key: const ValueKey('quran-prev'),
          enabled: hasPrev,
          label: hasPrev ? trf('quran.prev', {'name': widget.surahs[index - 1].name}) : tr('quran.prevNone'),
          icon: rtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
          iconFirst: true,
          onTap: () => _step(-1),
        ),
        const SizedBox(width: 12),
        _navButton(
          key: const ValueKey('quran-next'),
          enabled: hasNext,
          label: hasNext ? trf('quran.next', {'name': widget.surahs[index + 1].name}) : tr('quran.nextNone'),
          icon: rtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
          iconFirst: false,
          onTap: () => _step(1),
        ),
      ],
    );
  }

  Widget _navButton({
    required Key key,
    required bool enabled,
    required String label,
    required IconData icon,
    required bool iconFirst,
    required VoidCallback onTap,
  }) {
    final colors = enabled
        ? const [Color(0xFF6366F1), Color(0xFF8B5CF6)]
        : const [Color(0xFFCBD5E1), Color(0xFFCBD5E1)];
    final iconWidget = Icon(icon, color: Colors.white, size: 26);
    final text = Flexible(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
      ),
    );
    return Expanded(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: GestureDetector(
          key: key,
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(18),
              boxShadow: enabled
                  ? [BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: iconFirst
                  ? [iconWidget, const SizedBox(width: 6), text]
                  : [text, const SizedBox(width: 6), iconWidget],
            ),
          ),
        ),
      ),
    );
  }

  /// «استمع»: التلاوةُ الصحيحة للآية الخاطئة، يسمعها الطفلُ ثم يردّدها.
  Widget _helpButton(RecitationUnit unit) {
    return Semantics(
      button: true,
      label: tr('quran.listen'),
      child: Material(
        color: _helping ? teal : const Color(0xFF2563EB),
        shape: const StadiumBorder(),
        elevation: 3,
        child: InkWell(
          key: const ValueKey('quran-help'),
          customBorder: const StadiumBorder(),
          onTap: _helping ? null : () => _help(unit),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_helping ? Icons.hearing_rounded : Icons.volume_up_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 4),
                Text(
                  tr('quran.listen'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _word(BuildContext context, RecitationTracker tracker, int k, {required bool isCurrent}) {
    final state = tracker.status[k];
    // الكلمةُ التي ينتظرها الآن: أوّلُ ما لم يخضرّ في الخطوة الجارية.
    final unitOf = tracker.unitOf;
    var cursor = -1;
    for (var j = 0; j < unitOf.length; j++) {
      if (unitOf[j] == tracker.currentUnit && tracker.status[j] != RecitedWord.correct) {
        cursor = j;
        break;
      }
    }
    final next = isCurrent && k == cursor && state == RecitedWord.pending;
    final line = switch (state) {
      RecitedWord.correct => green,
      RecitedWord.wrong => red,
      RecitedWord.pending => next ? gold : Colors.transparent,
    };
    final ink = switch (state) {
      RecitedWord.correct => green,
      RecitedWord.wrong => red,
      RecitedWord.pending => StudentSurface.ink(context),
    };
    return Container(
      key: ValueKey('quran-word-$k'),
      padding: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: line, width: 3.5)),
        color: state == RecitedWord.wrong
            ? red.withValues(alpha: 0.12)
            : (next ? gold.withValues(alpha: 0.14) : null),
      ),
      child: Text(
        tracker.words[k],
        style: TextStyle(fontSize: 27, height: 1.9, fontWeight: FontWeight.w800, color: ink),
      ),
    );
  }

  static String _arabicDigits(int n) =>
      n.toString().split('').map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)]).join();

  Widget _hint(BuildContext context, String text, {bool strong = false}) => Container(
        key: const ValueKey('quran-hint'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: strong
            ? BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFDE68A), gold]),
                borderRadius: BorderRadius.circular(18),
              )
            : null,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: strong ? 17 : 15,
            height: 1.5,
            fontWeight: FontWeight.w900,
            color: strong ? const Color(0xFF7C2D12) : StudentSurface.mutedInk(context),
          ),
        ),
      );

  Widget _doneBanner() {
    final gems = _gems;
    return Container(
      key: const ValueKey('quran-done'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [emerald, teal]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            tr('quran.done'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          if (gems != null) ...[
            const SizedBox(height: 6),
            Text(
              gems > 0 ? trf('quran.gems', {'gems': gems}) : (_alreadyRewarded ? tr('quran.alreadyRewarded') : ''),
              key: const ValueKey('quran-gems'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFFDE68A)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _micButton() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final on = _wantListening && !_helping;
        final t = on ? _pulse.value : 0.0;
        final color = _done ? green : (on ? red : emerald);
        return Semantics(
          button: true,
          label: on ? tr('quran.listening') : tr('quran.tapMic'),
          child: GestureDetector(
            key: const ValueKey('quran-mic'),
            onTap: _toggleMic,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35 + 0.3 * t),
                    blurRadius: 14 + 16 * t,
                    spreadRadius: 2 + 8 * t,
                  ),
                ],
              ),
              child: Icon(
                _done ? Icons.check_rounded : (on ? Icons.stop_rounded : Icons.mic_rounded),
                color: Colors.white,
                size: 44,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// بطاقةُ «تسميع القرآن الكريم» على رفّ ألعاب الدرس: تدرّجٌ زمرّديٌّ ذهبيّ،
/// وتوهّجٌ ينبض، ومصحفٌ يطفو، وشارةٌ تتمايل — وتسكن لمن طلب تقليل الحركة.
class QuranShelfCard extends StatefulWidget {
  const QuranShelfCard({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  State<QuranShelfCard> createState() => _QuranShelfCardState();
}

class _QuranShelfCardState extends State<QuranShelfCard> with SingleTickerProviderStateMixin {
  static const emerald = QuranRecitationGameState.emerald;
  static const teal = QuranRecitationGameState.teal;
  static const gold = QuranRecitationGameState.gold;

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  bool _still = false;
  bool _pressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_still) {
      _clock
        ..stop()
        ..value = 0.3;
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  double _wave(double phase) => 0.5 - 0.5 * math.cos(2 * math.pi * ((_clock.value + phase) % 1.0));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Semantics(
        button: true,
        label: '${tr('quran.title')} — ${tr('quran.badge')}',
        child: GestureDetector(
          key: const ValueKey('quran-shelf-card'),
          onTapDown: (_) {
            HapticFeedback.selectionClick();
            setState(() => _pressed = true);
          },
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) {
            HapticFeedback.lightImpact();
            setState(() => _pressed = false);
            widget.onTap();
          },
          child: AnimatedScale(
            scale: _pressed ? 0.94 : 1.0,
            duration: const Duration(milliseconds: 140),
            child: AnimatedBuilder(animation: _clock, builder: (context, _) => _card()),
          ),
        ),
      ),
    );
  }

  Widget _card() {
    final pulse = _still ? 0.0 : _wave(0);
    final float = _still ? 0.0 : _wave(0.25);
    final swing = _still ? 0.5 : _wave(0.1);
    return Transform.scale(
      scale: 1 + 0.025 * pulse,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: SweepGradient(
                colors: const [gold, Colors.white, emerald, gold],
                transform: GradientRotation(2 * math.pi * _clock.value),
              ),
              boxShadow: [
                BoxShadow(color: emerald.withValues(alpha: 0.35 + 0.25 * pulse), blurRadius: 14 + 14 * pulse, spreadRadius: 1 + 2 * pulse),
                BoxShadow(color: gold.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 6)),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: const LinearGradient(
                  colors: [emerald, teal, gold],
                  stops: [0.0, 0.6, 1.0],
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    height: 100,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 2),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(0, -6 * float),
                          child: const Text('📖', style: TextStyle(fontSize: 48)),
                        ),
                        PositionedDirectional(
                          bottom: -6,
                          end: -8,
                          child: Transform.scale(
                            scale: 0.9 + 0.2 * pulse,
                            child: const Text('🎙️', style: TextStyle(fontSize: 26)),
                          ),
                        ),
                        PositionedDirectional(
                          top: -8,
                          start: -6,
                          child: Opacity(
                            opacity: 0.4 + 0.6 * swing,
                            child: const Text('✨', style: TextStyle(fontSize: 18)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tr('quran.title'),
                          style: const TextStyle(
                            fontSize: 22,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 4)],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('quran.subtitle'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.24),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                              ),
                              child: Text(
                                '💎 ${trf('quran.perSurah', {'gems': quranGemsPerSurah})}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(tr('quran.play'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: emerald)),
                                  const Icon(Icons.mic_rounded, color: emerald, size: 18),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          PositionedDirectional(
            top: -14,
            end: 14,
            child: Transform.rotate(
              angle: 0.14 * (swing - 0.5),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFDE047), gold]),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.6), blurRadius: 8 + 6 * swing, offset: const Offset(0, 3))],
                ),
                child: Text(
                  tr('quran.badge'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF7C2D12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
