import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/student_strings.dart';
import '../services/student_media_permissions.dart';
import '../services/student_voice_service.dart';
import 'attention_glow.dart';

/// يستمع إلى الطفل مرّةً: الكلماتُ وهي تُقال ([onPartial])، ثم ما قاله في
/// الختام ([onResult] — فارغاً إن لم يُسمع شيء). ويُعيد `false` إن تعذّر
/// الاستماع (لا إذنَ بالمايك، أو لا خدمةَ تعرّف على الجهاز).
typedef VoiceListen = Future<bool> Function({
  required ValueChanged<String> onResult,
  ValueChanged<String>? onPartial,
});

/// الاستماعُ الافتراضيّ: نافذةٌ طويلةٌ لا يُغلَق فيها المايكُ قبل أن يتكلّم
/// الطفل ([StudentVoiceService.listenForChild]).
Future<bool> defaultVoiceListen({required ValueChanged<String> onResult, ValueChanged<String>? onPartial}) =>
    StudentVoiceService.instance.listenForChild(onResult: onResult, onPartial: onPartial);

/// إذنُ الميكروفون قبل أن يُفتح: يُسأل النظامُ، وإن رُفض شُرح للطفل بلطف ما
/// يلزم — «اسمح» يسأل ثانيةً، و«افتح الإعدادات» لمن رفض نهائياً. ويُعيد
/// `true` إن صار مسموحاً.
///
/// [ask]: `false` يفحص ولا يُظهر شرحاً (فحصٌ مسبقٌ صامتٌ عند فتح الشاشة).
///
/// ── وحالتُه واحدةٌ للتطبيق كلّه ──
/// ما ثبت به الإذنُ في أيّ شاشة ([StudentVoiceService.micGranted]) يكفي كلَّ
/// شاشة: لا يُسأل ثانيةً، ولا يُناقضه طريقٌ آخر. وإن قال `permission_handler`
/// «لا» سُئل محرّكُ التعرّف نفسُه — فهو ما يسمع، وهو ما يعمل في التسميع.
Future<bool> ensureVoiceMic(BuildContext context, {bool ask = true}) async {
  final voice = StudentVoiceService.instance;
  if (voice.micGranted) return true;
  var access = await StudentMediaPermissions.microphoneForVoiceNote();
  if (access != MicAccess.granted && await voice.hasMicPermission()) access = MicAccess.granted;
  while (access != MicAccess.granted) {
    if (!ask || !context.mounted) return false;
    final blocked = access == MicAccess.blocked;
    final again = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('voice-mic-permission'),
        title: Text(tr('voice.micTitle'), textAlign: TextAlign.center),
        content: Text(
          tr(blocked ? 'voice.micBlocked' : 'voice.micWhy'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w700),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(tr('voice.micLater'))),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr(blocked ? 'voice.micSettings' : 'voice.micAllow')),
          ),
        ],
      ),
    );
    if (again != true) return false;
    if (blocked) {
      await StudentMediaPermissions.openSettings();
      return false;
    }
    access = await StudentMediaPermissions.microphoneForVoiceNote();
  }
  voice.markMicGranted();
  return true;
}

/// زرُّ ميكروفونٍ كبيرٌ يتوهّج: يُلمس فيسمع الطفل، ويسلّم ما قاله ([onHeard]).
///
/// يبقى أحمرَ نابضاً طوال الاستماع — والمايكُ لا يُغلَق قبل أن يتكلّم الطفل —
/// ولمسةٌ ثانيةٌ عليه تُنهيه بما قيل حتى الآن.
///
/// [prompt]: سؤالٌ مسموعٌ قبل الاستماع («إيش اسمك يا بطل؟») — المايكُ يُفتح
/// بعده لا أثناءه، وإلا كتب محرّكُ التعرّف السؤالَ نفسه. و[autoStart]: يبدأ
/// وحده مرّةً حين يظهر.
class VoiceMicButton extends StatefulWidget {
  const VoiceMicButton({
    required this.onHeard,
    this.onPartial,
    this.onListeningChanged,
    this.stop,
    this.listen,
    this.ensureMic,
    this.prompt,
    this.autoStart = false,
    this.size = 64,
    this.color = const Color(0xFF7C3AED),
    super.key,
  });

  /// ما قاله الطفلُ في الختام — فارغاً إن لم يُسمع شيء.
  final Future<void> Function(String heard) onHeard;

  /// الكلماتُ وهي تُقال: يُعيد `true` إن كفاه ما سمع (اسمٌ كاملٌ عُرف)، فيُغلق
  /// المايكُ في لحظته ويمضي — بلا انتظار الصمت ولا النصّ النهائيّ.
  final bool Function(String words)? onPartial;

  /// يستمع الآن أو كفّ — ليقول الشاشةُ «أسمعك…».
  final ValueChanged<bool>? onListeningChanged;

  /// إنهاءُ الاستماع (لمسةٌ ثانية، أو كفى الكلامُ الجزئيّ)؛ وبلا قيمةٍ
  /// [StudentVoiceService.finishChildListening].
  final VoidCallback? stop;
  final VoiceListen? listen;

  /// إذنُ الميكروفون قبل الاستماع؛ وبلا قيمةٍ [ensureVoiceMic].
  final Future<bool> Function(BuildContext context)? ensureMic;
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
  Timer? _safety;

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
    _safety?.cancel();
    super.dispose();
  }

  void _setListening(bool on) {
    if (_listening == on) return;
    setState(() => _listening = on);
    widget.onListeningChanged?.call(on);
  }

  void _stop() => (widget.stop ?? StudentVoiceService.instance.finishChildListening)();

  void _tap() {
    // ‏يستمع: لمسةٌ ثانيةٌ تُنهيه بما قيل.
    if (_listening) {
      HapticFeedback.selectionClick();
      _stop();
      return;
    }
    if (!_busy) unawaited(start());
  }

  /// الإذنُ، ثم السؤالُ إن كان، ثم الاستماع.
  Future<void> start() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    final allowed = await (widget.ensureMic ?? ensureVoiceMic)(context);
    if (!mounted) return;
    if (!allowed) {
      setState(() => _busy = false);
      return;
    }
    final prompt = widget.prompt;
    if (prompt != null) await prompt();
    if (!mounted) return;
    var answered = false;
    void done() {
      _safety?.cancel();
      if (mounted) _setListening(false);
    }

    final early = widget.onPartial;
    final started = await (widget.listen ?? defaultVoiceListen)(
      onResult: (heard) {
        if (answered || !mounted) return;
        answered = true;
        done();
        unawaited(widget.onHeard(heard).whenComplete(() {
          if (mounted) setState(() => _busy = false);
        }));
      },
      onPartial: early == null
          ? null
          : (words) {
              if (answered || !mounted || !early(words)) return;
              // ‏كفى ما سُمع: يُغلق المايكُ الآن، والختامُ إن وصل يُهمَل.
              answered = true;
              done();
              _stop();
              setState(() => _busy = false);
            },
    );
    if (!mounted) return;
    if (!started) {
      done();
      setState(() => _busy = false);
      return;
    }
    if (!answered) _setListening(true);
    // ‏احتياطٌ وحده: محرّكٌ لم يُبلغ بنهايته قطّ. النافذةُ نفسُها خمس عشرة ثانية.
    _safety = Timer(const Duration(seconds: 20), () {
      if (!mounted || answered) return;
      _stop();
      done();
      setState(() => _busy = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _listening ? const Color(0xFFDC2626) : widget.color;
    return Semantics(
      button: true,
      label: tr(_listening ? 'voice.listening' : 'voice.tapToSpeak'),
      child: GestureDetector(
        onTap: _busy && !_listening ? null : _tap,
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
