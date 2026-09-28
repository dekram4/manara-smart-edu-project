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
    final line = speakableText(text);
    if (line.isEmpty) return;
    await stopListening();
    try {
      await _tts.stop();
      // `ar-SA` أوّلاً، و`ar` إن لم تكن على الجهاز.
      //
      // محرّك النظام يردّ لغةً لا يملكها فيصمت بلا خطأ — وهذا أسوأ من
      // لهجةٍ غير مفضّلة: الطفل يضغط الزرّ فلا يسمع شيئاً ولا يعرف لماذا.
      await _setBestArabic(locale);
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

  /// يضبط أقرب لغةٍ عربية يملكها الجهاز.
  Future<void> _setBestArabic(String preferred) async {
    for (final candidate in [preferred, 'ar-SA', 'ar']) {
      try {
        final available = await _tts.isLanguageAvailable(candidate);
        if (available == true) {
          await _tts.setLanguage(candidate);
          return;
        }
      } catch (_) {
        // منصّةٌ لا تجيب عن السؤال: تُجرَّب التالية.
      }
    }
    // ولا شيء منها: تُضبط العربية على كل حال، فمحرّكٌ يفهمها ضمناً
    // خيرٌ من ألّا يُطلب منه شيء.
    try {
      await _tts.setLanguage('ar');
    } catch (_) {
      // لا محرّك: `speak` أدناه ستفشل بهدوء.
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



/// يُهيّئ نصّ الإجابة للنطق.
///
/// ── لماذا ──
/// النموذج يكتب بتنسيق Markdown: نجمتان حول ما يُبرزه، وشبكاتٌ للعناوين،
/// وسياجُ شيفرة، و LaTeX للمعادلات. ومحرّك النطق لا يعرف شيئاً من ذلك،
/// فينطقه حرفاً حرفاً — «نجمة نجمة الخطوة الأولى نجمة نجمة» — أو يتوقّف
/// عنده. والطفل يسمع ضجيجاً مكان شرح.
///
/// ولا يُمسّ نصُّ الإجابة المعروض: هذا للنطق وحده. الطفل يقرأ التنسيق
/// مفيداً ويسمعه ضجيجاً، فلكلٍّ صورتُه.
String speakableText(String raw) {
  // `replaceAllMapped` لا `replaceAll` حيث يُحتفظ بما بين العلامات:
  // الثانية تأخذ نصّاً حرفياً ولا تعرف مجموعات الالتقاط، فـ `$1` فيها
  // تُنطق دولاراً وواحداً.
  String keepInner(String input, RegExp pattern) =>
      input.replaceAllMapped(pattern, (match) => match.group(1) ?? '');

  var text = raw
      // سياج الشيفرة وما فيه: لا يُنطق أصلاً.
      .replaceAll(RegExp(r'```[\s\S]*?```'), ' ');

  text = keepInner(text, RegExp(r'`([^`]*)`'));
  // الإبراز: يبقى ما بين العلامات وتذهب هي.
  text = keepInner(text, RegExp(r'\*\*([^*]*)\*\*'));
  text = keepInner(text, RegExp(r'\*([^*]*)\*'));
  text = keepInner(text, RegExp(r'__([^_]*)__'));
  // روابط Markdown: يُنطق نصُّها لا عنوانها.
  text = keepInner(text, RegExp(r'\[([^\]]*)\]\([^)]*\)'));

  // وعلاماتُ بناء السطر تسقط هنا، قبل أسماء العمليات لا بعدها: علامةُ
  // القائمة «+» في أوّل السطر ليست جمعاً، ولو قُرئت بعد التحويل لنُطقت
  // «زائد أوّلاً».
  text = text
      .replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*>\s*', multiLine: true), '')
      // وعنوانٌ عارٍ يُقرأ حرفاً حرفاً، فيُحذف.
      .replaceAll(RegExp(r'https?://\S+'), ' ');

  // ── LaTeX ──
  //
  // النموذج يكتب الرياضيات بها حين يُسأل عن معادلة: `$\frac{2}{3}$`. ولو
  // مُسحت رموزُها بلا فهمٍ لبقي «frac 2 3» فيُنطق «فراك اثنان ثلاثة».
  // فتُفكّ الأوامرُ المعروفة إلى ما تعنيه، ثم يسقط ما بقي باسمه.
  text = text
      .replaceAll(RegExp(r'\$\$?'), ' ')
      .replaceAll(RegExp(r'\\(?:times|cdot)'), '\u00D7')
      .replaceAll(RegExp(r'\\div'), '\u00F7')
      .replaceAll(RegExp(r'\\pm'), '\u00B1');
  text = text.replaceAllMapped(
    RegExp(r'\\frac\s*\{([^{}]*)\}\s*\{([^{}]*)\}'),
    (match) => '${match.group(1)}\u00F7${match.group(2)}',
  );
  text = text
      .replaceAll(RegExp(r'\\[a-zA-Z]+'), ' ')
      .replaceAll(RegExp(r'[{}]'), ' ');

  // ── ورموزُ الحساب تُنطق بأسمائها ──
  //
  // المحرّك يقرأ «+» زائداً في لغةٍ ويتجاهلها في أخرى ويقول «بلَس» في
  // ثالثة، وطفلٌ يسمع «خمسة بلَس ثلاثة» لا يسمع جمعاً. والكتابةُ
  // بالكلمة تصل إلى كل محرّكٍ واحدةً ولا تحتمل تجاهلاً.
  //
  // وهي تحقّق الشرط من جهةٍ أخرى: لا يُنطق في النهاية إلا كلامٌ وأرقام.
  const signs = <String, String>{
    '\u00D7': ' \u0636\u0631\u0628 ',
    '\u00F7': ' \u062A\u0642\u0633\u064A\u0645 ',
    '+': ' \u0632\u0627\u0626\u062F ',
    '=': ' \u064A\u0633\u0627\u0648\u064A ',
    '%': ' \u0628\u0627\u0644\u0645\u0626\u0629 ',
    '\u00B1': ' \u0632\u0627\u0626\u062F \u0623\u0648 \u0646\u0627\u0642\u0635 ',
  };
  signs.forEach((sign, word) => text = text.replaceAll(sign, word));

  // والملتبِسُ منها لا يُنطق إلا بين رقمين.
  //
  // الشَّرطةُ ناقصٌ في «٧-٣» وواصلةٌ في «أ-ب»، والمائلةُ قسمةٌ في «١٢/٤»
  // وفاصلةٌ في تاريخ، والنجمةُ ضربٌ في «٦*٧» وبقيّةُ إبرازٍ لم يُغلق في
  // «**مهم». فلا تُنطق حيث تحتمل غير العملية، بل تسقط مع بقيّة الرموز.
  // \u0648\u00AB\u0627\u0644\u0631\u0642\u0645\u00BB \u0647\u0646\u0627 \u0623\u0648\u0633\u0639 \u0645\u0646 `\d`: \u0647\u0630\u0647 \u0641\u064A Dart \u0623\u0631\u0642\u0627\u0645\u064F ASCII \u0648\u062D\u062F\u0647\u0627\u060C \u0648\u0627\u0644\u0646\u0645\u0648\u0630\u062C
  // \u064A\u0643\u062A\u0628 \u0644\u0644\u0637\u0641\u0644 \u0628\u0627\u0644\u0623\u0631\u0642\u0627\u0645 \u0627\u0644\u0639\u0631\u0628\u064A\u0629-\u0627\u0644\u0647\u0646\u062F\u064A\u0629 \u0643\u0645\u0627 \u0641\u064A \u0643\u062A\u0627\u0628\u0647. \u0641\u0644\u0648\u0644\u0627 \u0647\u0630\u0627 \u0627\u0644\u0635\u0641\u0651
  // \u0644\u0645 \u062A\u064F\u0646\u0637\u0642 \u00AB\u0667-\u0663\u00BB \u0634\u064A\u0626\u0627\u064B \u0648\u0633\u0642\u0637\u062A \u0634\u064E\u0631\u0637\u062A\u064F\u0647\u0627 \u0635\u0627\u0645\u062A\u0629.
  const digit = r'[0-9\u0660-\u0669\u06F0-\u06F9]';
  const ambiguous = <List<String>>[
    [r'[-\u2212]', '\u0646\u0627\u0642\u0635'],
    [r'/', '\u062A\u0642\u0633\u064A\u0645'],
    [r'\*', '\u0636\u0631\u0628'],
  ];
  for (final rule in ambiguous) {
    text = text.replaceAllMapped(
      RegExp('($digit)\\s*${rule[0]}\\s*($digit)'),
      (match) => '${match.group(1)} ${rule[1]} ${match.group(2)}',
    );
  }

  return text
      // ثم لا يبقى إلا ما يُنطق.
      //
      // ── لماذا قائمةُ مسموحٍ لا قائمةُ ممنوع ──
      // حذفُ الرموز واحداً واحداً سباقٌ لا يُربح: الإيموجي وحدها آلاف،
      // وتزيد كل سنة، ولكل محرّكِ نطقٍ اسمٌ ينطقه لكلٍّ منها — «وجهٌ
      // مبتسم بعينين على شكل قلب» في منتصف شرح المسألة. فيُقلب الشرط:
      // يمرّ الحرفُ والرقمُ وعلاماتُ الوقف، ويسقط كلُّ ما عداها.
      //
      // وعلاماتُ الوقف تبقى لأنها لا تُنطق أصلاً: المحرّك يقرؤها صمتاً
      // بين الجمل. وحذفُها يجعل الشرح نَفَساً واحداً لا يلتقط فيه الطفل
      // أين انتهت خطوةٌ وبدأت التي بعدها.
      //
      // وعلاماتُ الحساب صارت كلماتٍ قبل هذا السطر، فتسقط بقاياها هنا.
      //
      // و`\p{M}` مع `\p{L}`: التشكيل علاماتٌ مركّبة لا حروف، فلا يُمرّره
      // `\p{L}` وحده. ونصُّ درسٍ لصغار القرّاء مشكولٌ كلُّه — فلولا هذا
      // لصارت كلُّ فتحةٍ مسافةً و«أوّلاً» كلمتين: «أو» و«لا».
      .replaceAll(
        RegExp(r'[^\p{L}\p{M}\p{N}\s.,،؛;:!?؟]', unicode: true),
        ' ',
      )
      // وعلامةُ وقفٍ مكرّرة — «؟؟» و«!!» — تُوحَّد.
      .replaceAllMapped(
        RegExp(r'([.,،؛;:!?؟])\1+'),
        (match) => match.group(1)!,
      )
      // ومسافةٌ قبل علامة الوقف تجعل بعض المحرّكات تتجاهلها.
      .replaceAllMapped(
        RegExp(r'\s+([.,،؛;:!?؟])'),
        (match) => match.group(1)!,
      )
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      // وسطرٌ لم يبق فيه إلا مسافةٌ — مكانَ سياج شيفرةٍ حُذف — يُطوى،
      // وإلا بقي في النصّ فراغٌ يقرؤه المحرّك وقفةً بلا سبب.
      .replaceAll(RegExp(r'[ \t]*\n[ \t]*'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
