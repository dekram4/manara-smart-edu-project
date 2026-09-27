import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// الإملاء والنطق في بطاقة حلّ المسائل.
///
/// ── لماذا وحدةٌ واحدة ──
/// المحرّكان يتنازعان الميكروفون ومخرج الصوت: نطقُ إجابةٍ بينما الميكروفون
/// يسمع يجعل الجهاز يُملي على نفسه. فوضعُهما خلف بابٍ واحد يجعل القاعدة
/// «لا يعملان معاً» مكتوبةً في مكانٍ واحد بدل أن تُتذكَّر في كل نداء.
///
/// ── وكلّ شيءٍ هنا يفشل بهدوء ──
/// جهازٌ بلا محرّك نطقٍ عربي، أو بلا خدمة تعرّفٍ على الكلام، أو رفض
/// الطفلُ إذن الميكروفون — كلّها تعني زرّاً لا يعمل، لا شاشةً تنهار.
/// والبطاقة تعمل بالكتابة على كل حال.
class StudentVoiceService {
  StudentVoiceService({SpeechToText? speech, FlutterTts? tts})
      : _speech = speech ?? SpeechToText(),
        _tts = tts ?? FlutterTts();

  final SpeechToText _speech;
  final FlutterTts _tts;

  bool _speechReady = false;
  bool _speechAvailable = false;
  bool _speaking = false;

  /// هل يُسمع الطفل الآن؟
  bool get listening => _speech.isListening;

  /// هل يُنطق شيءٌ الآن؟
  bool get speaking => _speaking;

  /// يُهيّئ محرّك التعرّف مرّةً واحدة.
  ///
  /// النتيجة تُحفظ: `initialize` يسأل النظام عن الإذن وعن وجود خدمة،
  /// ونداؤه عند كل ضغطةٍ يُظهر نافذة إذنٍ متكرّرة.
  Future<bool> prepare() async {
    if (_speechReady) return _speechAvailable;
    _speechReady = true;
    try {
      _speechAvailable = await _speech.initialize(
        onError: (_) {},
        onStatus: (_) {},
      );
    } catch (_) {
      _speechAvailable = false;
    }
    return _speechAvailable;
  }

  /// يبدأ الإملاء، ويُسلّم ما سمعه عند انتهائه.
  ///
  /// [onResult] يُنادى بالنصّ النهائي وحده لا بكل كلمةٍ جزئية: حقلٌ
  /// يتبدّل نصُّه مع كل مقطعٍ يُربك الطفل ويجعل التراجع مستحيلاً.
  Future<bool> listen({
    required ValueChanged<String> onResult,
    String locale = 'ar_SA',
    Duration limit = const Duration(seconds: 30),
  }) async {
    if (!await prepare()) return false;
    // النطق يتوقّف أوّلاً: وإلا أملى الجهاز على نفسه ما ينطقه.
    await stopSpeaking();
    try {
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: locale,
          listenFor: limit,
          // صمتٌ ثلاث ثوانٍ يُنهي الإملاء. الطفل لا يعرف متى يضغط
          // «توقّف»، والانتظار إلى آخر المهلة يجعل البطاقة تبدو معلّقة.
          pauseFor: const Duration(seconds: 3),
        ),
        onResult: (result) {
          if (result.finalResult) onResult(result.recognizedWords.trim());
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {
      // لا محرّك: لا شيء يُوقَف.
    }
  }

  /// ينطق [text] بالعربية، ويوقف ما قبله.
  Future<void> speak(String text, {String locale = 'ar-SA'}) async {
    final line = text.trim();
    if (line.isEmpty) return;
    await stopListening();
    try {
      await _tts.stop();
      await _tts.setLanguage(locale);
      // أبطأ من الافتراضي: محرّكات النظام تقرأ العربية بسرعةٍ تناسب
      // بالغاً يعرف ما يُقال، لا طفلاً يسمع الشرح أوّل مرّة.
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _speaking = true;
      _tts.setCompletionHandler(() => _speaking = false);
      _tts.setCancelHandler(() => _speaking = false);
      _tts.setErrorHandler((_) => _speaking = false);
      await _tts.speak(line);
    } catch (_) {
      _speaking = false;
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {
      // لا محرّك نطق: لا شيء يُوقَف.
    }
    _speaking = false;
  }

  Future<void> dispose() async {
    await stopListening();
    await stopSpeaking();
  }
}

/// ما يُرسل إلى الخادم حين يُصوَّر سؤال.
///
/// مفصولٌ عن الخدمة ليُختبر: القاعدة هنا هي أنّ صورةً بلا سؤالٍ مكتوب
/// تحتاج سؤالاً افتراضياً، وإلا وصل الخادمُ طلبٌ بلا سؤال.
class PhotoQuestion {
  const PhotoQuestion({required this.question, required this.imageBase64});

  final String question;
  final String imageBase64;

  /// السؤال الافتراضي حين يكتفي الطفل بالتصوير.
  static const defaultPrompt = 'حلّ هذه المسألة واشرح الخطوات.';

  factory PhotoQuestion.from({required String typed, required String base64}) {
    final written = typed.trim();
    return PhotoQuestion(
      question: written.isEmpty ? defaultPrompt : written,
      imageBase64: base64,
    );
  }
}
