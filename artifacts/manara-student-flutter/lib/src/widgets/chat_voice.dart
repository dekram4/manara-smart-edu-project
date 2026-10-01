import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/student_strings.dart';
import '../theme/student_theme.dart';

/// الرسائلُ الصوتية في دردشة الصفّ: زرُّ الميكروفون، وشريطُ التسجيل، والمشغّل.

/// أقصى مدّةٍ للرسالة الصوتية: جملةٌ أو جملتان، والمسجّلُ يتوقّف عندها وحده.
const chatVoiceMaxDuration = Duration(seconds: 30);

/// أقصى حجمٍ للمقطع — وهو نفسُه سقفُ الخادم (`CHAT_VOICE_MAX_BYTES`).
const chatVoiceMaxBytes = 160 * 1024;

/// أقصرُ من هذا ضغطةٌ لا كلام: لا تُرفع ولا تُرسل.
const chatVoiceMinDuration = Duration(milliseconds: 700);

/// كم يُسحب الإصبعُ عن الزرّ ليصير الإفلاتُ إلغاءً.
const chatVoiceCancelDistance = 72.0;

String voiceClock(Duration value) {
  final seconds = value.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// زرُّ الميكروفون: يُسجّل ما دام الإصبعُ عليه.
///
/// ── والإفلاتُ يُرسل، والسحبُ بعيداً يُلغي ──
/// كما في كل تطبيق رسائلَ يعرفه الطفل. و[Listener] لا [GestureDetector]: الضغطُ
/// المطوّل في الثاني ينتظر نصفَ ثانيةٍ قبل أن يبدأ، فتضيع أوّلُ كلمة.
class ChatVoiceMicButton extends StatefulWidget {
  const ChatVoiceMicButton({
    required this.recording,
    required this.cancelArmed,
    required this.onHoldStart,
    required this.onHoldMove,
    required this.onHoldEnd,
    super.key,
  });

  final bool recording;
  final bool cancelArmed;
  final VoidCallback onHoldStart;

  /// كم ابتعد الإصبعُ عن موضع الضغط.
  final ValueChanged<double> onHoldMove;
  final void Function({required bool cancelled}) onHoldEnd;

  @override
  State<ChatVoiceMicButton> createState() => _ChatVoiceMicButtonState();
}

class _ChatVoiceMicButtonState extends State<ChatVoiceMicButton> {
  /// موضعُ الضغط. في الحالة لا في `build`: بدءُ التسجيل يُعيد البناء، ومتغيّرٌ
  /// محلّيٌّ يُنسى عنده فلا يُعرف كم سُحب الإصبع.
  Offset? _origin;

  @override
  Widget build(BuildContext context) {
    final color = widget.cancelArmed
        ? const Color(0xFF6B7280)
        : widget.recording
            ? const Color(0xFFDC2626)
            : const Color(0xFF7C3AED);
    return Semantics(
      button: true,
      label: tr('chat.voice.record'),
      child: Listener(
        onPointerDown: (event) {
          _origin = event.position;
          HapticFeedback.mediumImpact();
          widget.onHoldStart();
        },
        onPointerMove: (event) {
          final from = _origin;
          if (from != null) widget.onHoldMove((event.position - from).distance);
        },
        onPointerUp: (_) {
          _origin = null;
          widget.onHoldEnd(cancelled: false);
        },
        onPointerCancel: (_) {
          _origin = null;
          widget.onHoldEnd(cancelled: true);
        },
        child: AnimatedScale(
          scale: widget.recording ? 1.22 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: widget.recording ? 0.55 : 0.3),
                  blurRadius: widget.recording ? 16 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              widget.cancelArmed
                  ? Icons.delete_outline_rounded
                  : widget.recording
                      ? Icons.mic_rounded
                      : Icons.mic_none_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

/// ما يحلّ محلَّ حقل الكتابة أثناء التسجيل: نقطةٌ تنبض، والزمنُ من ثلاثين،
/// وكيف يُلغى.
class ChatRecordingStrip extends StatefulWidget {
  const ChatRecordingStrip({
    required this.elapsed,
    required this.cancelArmed,
    super.key,
  });

  final ValueListenable<Duration> elapsed;
  final bool cancelArmed;

  @override
  State<ChatRecordingStrip> createState() => _ChatRecordingStripState();
}

class _ChatRecordingStripState extends State<ChatRecordingStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (still) {
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final armed = widget.cancelArmed;
    final tint = armed ? const Color(0xFF6B7280) : const Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: tint.withValues(alpha: 0.1),
        border: Border.all(color: tint.withValues(alpha: 0.6), width: 1.4),
      ),
      child: ValueListenableBuilder<Duration>(
        valueListenable: widget.elapsed,
        builder: (context, elapsed, _) {
          final fraction =
              (elapsed.inMilliseconds / chatVoiceMaxDuration.inMilliseconds)
                  .clamp(0.0, 1.0);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  FadeTransition(
                    opacity: Tween(begin: 0.25, end: 1.0).animate(_pulse),
                    child: Icon(Icons.fiber_manual_record_rounded,
                        size: 14, color: tint),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${voiceClock(elapsed)} / ${voiceClock(chatVoiceMaxDuration)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: tint,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr(armed
                          ? 'chat.voice.releaseCancel'
                          : 'chat.voice.slideCancel'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: armed ? tint : StudentSurface.mutedInk(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 4,
                  color: tint,
                  backgroundColor: tint.withValues(alpha: 0.15),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// مشغّلُ رسالةٍ صوتية داخل الفقاعة: زرٌّ، وموجةٌ تمتلئ بما سُمع، والمدّة.
class ChatVoiceNoteView extends StatefulWidget {
  const ChatVoiceNoteView({
    required this.seed,
    required this.duration,
    required this.playing,
    required this.loading,
    required this.mine,
    required this.onTap,
    super.key,
  });

  /// معرّفُ المقطع: منه شكلُ الموجة، فتبقى الرسالةُ نفسُها بشكلٍ واحد.
  final String seed;
  final Duration duration;
  final bool playing;
  final bool loading;
  final bool mine;
  final VoidCallback onTap;

  @override
  State<ChatVoiceNoteView> createState() => _ChatVoiceNoteViewState();
}

class _ChatVoiceNoteViewState extends State<ChatVoiceNoteView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heard = AnimationController(
    vsync: this,
    duration: _length,
  );

  Duration get _length => widget.duration > Duration.zero
      ? widget.duration
      : const Duration(seconds: 3);

  late final List<double> _bars = _wave(widget.seed);

  static List<double> _wave(String seed) {
    var hash = 17;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return List.generate(22, (index) {
      hash = (hash * 1103515245 + 12345) & 0x7fffffff;
      // أطرافُ الموجة أهدأ من وسطها كما في الكلام.
      final edge = 1 - ((index - 10.5).abs() / 14);
      return 0.25 + (hash % 1000) / 1000 * 0.75 * edge;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.playing) _heard.forward(from: 0);
  }

  @override
  void didUpdateWidget(ChatVoiceNoteView old) {
    super.didUpdateWidget(old);
    _heard.duration = _length;
    if (widget.playing && !old.playing) {
      _heard.forward(from: 0);
    } else if (!widget.playing && old.playing) {
      _heard.reset();
    }
  }

  @override
  void dispose() {
    _heard.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = widget.mine ? Colors.white : const Color(0xFF0B8693);
    final faint = ink.withValues(alpha: 0.35);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: tr(widget.playing ? 'chat.voice.stop' : 'chat.voice.play'),
          child: InkResponse(
            onTap: widget.loading ? null : widget.onTap,
            radius: 26,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.mine
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFF0B8693).withValues(alpha: 0.12),
              ),
              alignment: Alignment.center,
              child: widget.loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: ink),
                    )
                  : Icon(
                      widget.playing
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      color: ink,
                      size: 26,
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedBuilder(
          animation: _heard,
          builder: (context, _) {
            final heard = widget.playing ? _heard.value : 0.0;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < _bars.length; index++)
                  Container(
                    width: 3,
                    height: 4 + _bars[index] * 22,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: index / _bars.length < heard ? ink : faint,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(width: 8),
        Text(
          voiceClock(_length),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
