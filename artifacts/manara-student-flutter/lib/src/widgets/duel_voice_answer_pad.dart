import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';

/// حالُ زرّ «أجب بصوتك».
enum VoiceAnswerState {
  /// جاهز: يُلمس فيسمع.
  idle,

  /// يُفتح المايك: الإذنُ، وإسكاتُ ما يُشغَّل.
  preparing,

  /// يسمع الطفل الآن.
  listening,

  /// سُمع الجوابُ ويُختار الخيار.
  matching,

  /// لم يُسمع شيء، أو لم يُفهم: يُلمس ثانيةً.
  missed,
}

/// «أجب بصوتك» في «تحدَّ زملاءك»: زرُّ جوابِ السؤال، لا رسالةٌ للزملاء.
///
/// ── لماذا يختلف عن زرّ الرسالة الصوتية في كل شيء ──
/// كان زرّان بمايكٍ واحدٍ متشابهين في الصفحة، فيضغط الطفلُ زرَّ الرسالة ليجيب
/// فيُرسل كلامَه لزملائه ولا يُحسب جواباً. فهذا دائرةٌ كبيرةٌ خضراء بلمسةٍ
/// واحدة، بين السؤال والخيارات؛ وذاك شريطٌ بنفسجيّ بالضغط المطوّل، في بطاقة
/// «دردشة الزملاء» آخرَ الصفحة.
///
/// وكلُّ حالٍ تُرى: حلقاتٌ تنبض وموجةُ صوتٍ تتراقص وهو يسمع، ودائرةٌ تدور وهو
/// يفهم، وما سمعه مكتوباً تحته. ومن طلب تقليلَ الحركة يراها ساكنة.
class DuelVoiceAnswerPad extends StatefulWidget {
  const DuelVoiceAnswerPad({
    required this.state,
    required this.onTap,
    this.heard = '',
    this.enabled = true,
    this.size = 88,
    super.key,
  });

  final VoiceAnswerState state;
  final VoidCallback onTap;

  /// ما سمعه المايكُ حتى الآن.
  final String heard;
  final bool enabled;
  final double size;

  @override
  State<DuelVoiceAnswerPad> createState() => _DuelVoiceAnswerPadState();
}

class _DuelVoiceAnswerPadState extends State<DuelVoiceAnswerPad> with SingleTickerProviderStateMixin {
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  bool get _live => widget.state == VoiceAnswerState.listening || widget.state == VoiceAnswerState.preparing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(DuelVoiceAnswerPad old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animate = !still && widget.enabled && widget.state != VoiceAnswerState.missed;
    if (animate && !_clock.isAnimating) {
      _clock.repeat();
    } else if (!animate && _clock.isAnimating) {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  (List<Color>, IconData, String) get _look => switch (widget.state) {
        VoiceAnswerState.idle => (const [Color(0xFF22C55E), Color(0xFF15803D)], Icons.mic_rounded, tr('duel.kg.mic')),
        VoiceAnswerState.preparing =>
          (const [Color(0xFFF97316), Color(0xFFC2410C)], Icons.mic_rounded, tr('duel.kg.preparing')),
        VoiceAnswerState.listening =>
          (const [Color(0xFFEF4444), Color(0xFFB91C1C)], Icons.graphic_eq_rounded, tr('duel.kg.listening')),
        VoiceAnswerState.matching =>
          (const [Color(0xFFF59E0B), Color(0xFFB45309)], Icons.hourglass_top_rounded, tr('duel.kg.matching')),
        VoiceAnswerState.missed =>
          (const [Color(0xFF22C55E), Color(0xFF15803D)], Icons.replay_rounded, tr('duel.kg.again')),
      };

  @override
  Widget build(BuildContext context) {
    final (colors, icon, label) = _look;
    final size = widget.size;
    final heard = widget.heard.trim();
    final enabled = widget.enabled && widget.state != VoiceAnswerState.matching;
    return Semantics(
      button: true,
      enabled: enabled,
      liveRegion: true,
      label: heard.isEmpty ? label : '$label: $heard',
      child: Container(
        key: const ValueKey('duel-voice-answer'),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: colors.last.withValues(alpha: 0.10),
          border: Border.all(color: colors.first.withValues(alpha: 0.55), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              key: const ValueKey('duel-kg-mic'),
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? widget.onTap : null,
              child: SizedBox(
                width: size * 1.7,
                height: size * 1.45,
                child: AnimatedBuilder(
                  animation: _clock,
                  builder: (context, _) {
                    final t = _clock.value;
                    final breathe = _live ? 1 + 0.06 * math.sin(t * 2 * math.pi) : 1 + 0.025 * math.sin(t * 2 * math.pi);
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // ‏حلقاتٌ تنطلق من الزرّ وهو يسمع: «أنا أسمعك».
                        if (_live)
                          for (final phase in const [0.0, 0.5])
                            _Ripple(progress: (t + phase) % 1, size: size, color: colors.first),
                        if (widget.state == VoiceAnswerState.matching)
                          SizedBox(
                            width: size + 14,
                            height: size + 14,
                            child: CircularProgressIndicator(strokeWidth: 5, color: colors.first),
                          ),
                        Transform.scale(
                          scale: enabled ? breathe : 1,
                          child: Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: enabled ? colors : const [Color(0xFF94A3B8), Color(0xFF64748B)],
                              ),
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.first.withValues(alpha: enabled ? 0.55 : 0.2),
                                  blurRadius: _live ? 26 : 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: widget.state == VoiceAnswerState.listening
                                ? _Equalizer(progress: t, color: Colors.white, size: size * 0.5)
                                : Icon(icon, color: Colors.white, size: size * 0.5),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              key: const ValueKey('duel-voice-label'),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.last, fontSize: 17, fontWeight: FontWeight.w900),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              child: heard.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        key: const ValueKey('duel-voice-heard'),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '«$heard»',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ripple extends StatelessWidget {
  const _Ripple({required this.progress, required this.size, required this.color});

  final double progress;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final extent = size * (1 + 0.6 * progress);
    return IgnorePointer(
      child: Container(
        width: extent,
        height: extent,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: (1 - progress) * 0.7), width: 4),
        ),
      ),
    );
  }
}

/// موجةُ صوتٍ تتراقص: خمسةُ أعمدةٍ بأطوارٍ مختلفة.
class _Equalizer extends StatelessWidget {
  const _Equalizer({required this.progress, required this.color, required this.size});

  final double progress;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < 5; i++)
            Container(
              width: size / 9,
              height: size * (0.3 + 0.7 * (0.5 + 0.5 * math.sin((progress * 2 + i * 0.37) * 2 * math.pi)).abs()),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size)),
            ),
        ],
      ),
    );
  }
}
