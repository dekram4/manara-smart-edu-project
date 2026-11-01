import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/student_strings.dart';
import '../services/student_voice_service.dart';
import 'attention_glow.dart';

/// يستمع إلى الطفل مرّةً: الكلماتُ وهي تُقال ([onPartial])، ثم النصُّ النهائيّ
/// ([onResult]). ويُعيد `false` إن تعذّر الاستماع (لا إذنَ بالمايك، أو لا
/// خدمةَ تعرّف على الجهاز).
typedef VoiceListen = Future<bool> Function({
  required ValueChanged<String> onResult,
  ValueChanged<String>? onPartial,
});

/// الاستماعُ الافتراضيّ: محرّكُ التعرّف بالعربية، بمهلةٍ قصيرة — كلمةٌ أو اسم —
/// وصمتٌ قصيرٌ يُنهيه: الطفلُ يقول كلمةً ويسكت، فلا يُنتظر ثلاثَ ثوانٍ.
Future<bool> defaultVoiceListen({required ValueChanged<String> onResult, ValueChanged<String>? onPartial}) =>
    StudentVoiceService.instance.listen(
      onResult: onResult,
      onPartial: onPartial,
      limit: const Duration(seconds: 8),
      pause: const Duration(milliseconds: 1200),
    );

/// زرُّ ميكروفونٍ كبيرٌ يتوهّج: يُلمس فيسمع الطفل، ويسلّم ما قاله ([onHeard]).
///
/// [prompt]: سؤالٌ مسموعٌ قبل الاستماع («إيش اسمك يا بطل؟») — المايكُ يُفتح
/// بعده لا أثناءه، وإلا كتب محرّكُ التعرّف السؤالَ نفسه. و[autoStart]: يبدأ
/// وحده مرّةً حين يظهر.
class VoiceMicButton extends StatefulWidget {
  const VoiceMicButton({
    required this.onHeard,
    this.onPartial,
    this.stop,
    this.listen,
    this.prompt,
    this.autoStart = false,
    this.size = 64,
    this.color = const Color(0xFF7C3AED),
    super.key,
  });

  final Future<void> Function(String heard) onHeard;

  /// الكلماتُ وهي تُقال: يُعيد `true` إن كفاه ما سمع (اسمٌ كاملٌ عُرف)، فيُغلق
  /// المايكُ في لحظته ويمضي — بلا انتظار الصمت ولا النصّ النهائيّ.
  final bool Function(String words)? onPartial;

  /// إغلاقُ المايك حين يكفي الكلامُ الجزئيّ؛ وبلا قيمةٍ محرّكُ التعرّف.
  final Future<void> Function()? stop;
  final VoiceListen? listen;
  final Future<void> Function()? prompt;
  final bool autoStart;
  final double size;
  final Color color;

  @override
  State<VoiceMicButton> createState() => VoiceMicButtonState();
}

class VoiceMicButtonState extends State<VoiceMicButton> {
  bool _busy = false;
  bool _listening = false;
  Timer? _giveUp;

  /// يستمع الآن.
  bool get listening => _listening;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(start());
      });
    }
  }

  @override
  void dispose() {
    _giveUp?.cancel();
    super.dispose();
  }

  /// السؤالُ إن كان، ثم الاستماع.
  Future<void> start() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    final prompt = widget.prompt;
    if (prompt != null) await prompt();
    if (!mounted) return;
    var answered = false;
    final early = widget.onPartial;
    final started = await (widget.listen ?? defaultVoiceListen)(
      onResult: (heard) {
        if (answered || !mounted) return;
        answered = true;
        _giveUp?.cancel();
        setState(() => _listening = false);
        unawaited(widget.onHeard(heard).whenComplete(() {
          if (mounted) setState(() => _busy = false);
        }));
      },
      onPartial: early == null
          ? null
          : (words) {
              if (answered || !mounted || !early(words)) return;
              // ‏كفى ما سُمع: يُغلق المايكُ الآن، والنصُّ النهائيُّ إن وصل يُهمَل.
              answered = true;
              _giveUp?.cancel();
              unawaited((widget.stop ?? StudentVoiceService.instance.stopListening)());
              setState(() {
                _listening = false;
                _busy = false;
              });
            },
    );
    if (!mounted) return;
    if (!started) {
      setState(() {
        _busy = false;
        _listening = false;
      });
      return;
    }
    if (!answered) setState(() => _listening = true);
    // ‏لا نتيجةَ نهائيةً تصل أحياناً (صمتٌ تام): يعود الزرُّ إلى حاله.
    _giveUp = Timer(const Duration(seconds: 10), () {
      if (!mounted || answered) return;
      setState(() {
        _busy = false;
        _listening = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _listening ? const Color(0xFFDC2626) : widget.color;
    return Semantics(
      button: true,
      label: tr(_listening ? 'voice.listening' : 'voice.tapToSpeak'),
      child: GestureDetector(
        onTap: _busy ? null : start,
        child: AttentionGlow(
          color: color,
          active: _listening || !_busy,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(color, Colors.white, 0.25)!, color],
              ),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Icon(
              _listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: widget.size * 0.52,
            ),
          ),
        ),
      ),
    );
  }
}
