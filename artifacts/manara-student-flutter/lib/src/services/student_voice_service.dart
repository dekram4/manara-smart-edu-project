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

  /// الخدمةُ الواحدة التي تعيش ما عاش التطبيق.
  ///
  /// ── لماذا مفردةٌ لا نسخةٌ لكل شاشة ──
  /// الشاشة كانت تُنشئ نسختَها في حقلٍ من [State]: `late final _voice =
  /// StudentVoiceService()`. وحقلُ [State] يعيش ما عاش الكائن، لا ما عاشت
  /// الشاشة — فكلُّ ما يُسقط [State] ويُنشئه من جديد كان يُنشئ محرّكَ
  /// نطقٍ جديداً ويترك الأول ناطقاً في الخلفية، أو يقطعه.
  ///
  /// ودورانُ الشاشة أحدُ ما يفعل ذلك: تغيُّرُ الاتجاه يُعيد بناء الشجرة،
  /// وكلُّ فرقٍ في نوع الودجت أو في مفتاحه بين البناءين يُسقط ما تحته —
  /// فينقطع الشرحُ في منتصف الجملة بلا أن يمسّ الطفلُ شيئاً. وهو يقلب
  /// الهاتف ليقرأ خطواتٍ عريضة، فيخسر بذلك ما جاء يقرؤه.
  ///
  /// والمحرّكُ خارج الشجرة لا يُسقطه بناءٌ ولا اتجاه: النطقُ يتّصل، وما
  /// يوقفه ضغطةُ الطفل أو مغادرتُه الشاشةَ وحدهما.
  ///
  /// ولا يُغلق أبداً — انظر [dispose].
  static final StudentVoiceService instance = StudentVoiceService();

  /// سرعةُ النطق.
  ///
  /// ٠٫٥٢: أبطأ من افتراضيّ المحرّك، الذي يقرأ العربية بسرعةٍ تناسب
  /// بالغاً يعرف ما يُقال لا طفلاً يسمع الشرح أوّل مرّة. وكانت ٠٫٤٥،
  /// وهي عند هذا الحدّ تُسمع متقطّعةً متكلّفة — كلُّ كلمةٍ وحدَها — فيضيع
  /// إيقاعُ الجملة الذي يُفهم منه أين انتهت خطوةٌ وبدأت التي بعدها.
  static const speechRate = 0.52;

  /// لهجةُ النطق المطلوبة.
  ///
  /// مكتوبةٌ في موضعٍ واحد لا قيمةً افتراضيةً في توقيعِ دالّة: قيمةُ
  /// المُعامل الافتراضية لا تُقرأ من خارج الدالّة فلا يحرسها اختبار —
  /// وتبدُّلها إلى `ar` يجعل المحرّك يختار أقرب عربيّةٍ عنده، وقد تكون
  /// نبرةً غريبةً عن نبرة الطفل السعودي، بلا أن يسقط شيء.
  static const preferredLocale = 'ar-SA';

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
  Future<void> speak(String text, {String locale = preferredLocale}) async {
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
      await _tts.setSpeechRate(speechRate);
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
          break;
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
    await _setSaudiVoice();
  }

  /// يختار صوتاً سعودياً بعينه، إن كان على الجهاز.
  ///
  /// ── لماذا الصوت لا اللغة وحدها ──
  /// `setLanguage('ar-SA')` تطلب لهجةً، والمحرّك يجيبها بأقرب ما عنده —
  /// وقد يكون صوتاً مصرياً أو مغربياً مضبوطاً على العربية، فيسمع الطفل
  /// السعودي نبرةً غريبة عن نبرته. وقائمةُ الأصوات تُصرّح بلهجة كلٍّ
  /// منها، فيُنتقى منها ما يوافق.
  ///
  /// ── وما لا تستطيعه ──
  /// أصواتُ المحرّكات على الأجهزة فُصحى: `ar-SA` تعني «فصحى بنبرةٍ
  /// سعودية» لا حجازيّةً محكيّة. واللهجةُ الحجازية الحقيقية تحتاج خدمةً
  /// سحابية تُنطق على الخادم ويُنزَّل صوتُها — وهي كلفةُ شبكةٍ وانتظارٍ
  /// لكل جملة. فهذا أقربُ ما يُنال بلا ذلك، وقولُه صراحةً خيرٌ من
  /// الإيهام بأن اللهجة ضُبطت.
  Future<void> _setSaudiVoice() async {
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return;
      final arabic = <Map<String, String>>[];
      for (final entry in voices) {
        if (entry is! Map) continue;
        final name = entry['name']?.toString() ?? '';
        final locale = entry['locale']?.toString() ?? '';
        if (name.isEmpty || !locale.toLowerCase().startsWith('ar')) continue;
        arabic.add({'name': name, 'locale': locale});
      }
      if (arabic.isEmpty) return;
      // السعوديُّ أوّلاً، ثم الخليجي، ثم أيُّ عربيّ.
      final chosen = arabic.firstWhere(
        (voice) => voice['locale']!.toLowerCase().contains('sa'),
        orElse: () => arabic.firstWhere(
          (voice) => RegExp(
            'ae|kw|bh|qa|om',
          ).hasMatch(voice['locale']!.toLowerCase()),
          orElse: () => arabic.first,
        ),
      );
      await _tts.setVoice(chosen);
    } catch (_) {
      // منصّةٌ لا تعرف `getVoices`، أو صوتٌ رفض الضبط: تبقى اللغة
      // وحدها، وهي تكفي نطقاً.
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

  /// يُغلق المحرّكين. للنُسخ المملوكة — في الاختبارات — وحدها.
  ///
  /// ── ولماذا لا تُغلق [instance] ──
  /// إغلاقُها من شاشةٍ يوقف النطقَ على التطبيق كلِّه لا على الشاشة التي
  /// أُغلقت منها. وشاشةٌ تُغلق في [State.dispose] تُغلق في كل إسقاطٍ
  /// لـ[State] — ودورانُ الشاشة أحدُها — فيعود العطبُ الذي جاءت المفردة
  /// لتمنعه، من بابٍ آخر.
  ///
  /// وما تحتاجه الشاشة عند المغادرة [stopSpeaking]: تُسكت الجملةَ
  /// الجارية ولا تُغلق محرّكاً.
  ///
  /// و[assert] لا استثناء: خطأٌ في الاستدعاء يُقال في وقت التطوير
  /// والاختبار، ولا يُسقط تطبيقاً في يد طفل.
  Future<void> dispose() async {
    assert(
      !identical(this, instance),
      'StudentVoiceService.instance لا تُغلق — استخدم stopSpeaking() عند مغادرة الشاشة.',
    );
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
      // ── التشكيلُ يسقط أوّلاً ──
      //
      // محرّكاتُ النظام تنطق الحركةَ المكتوبة: نصٌّ مشكولٌ يُقرأ بالإعراب
      // حرفاً حرفاً — «الخَلِيَّةُ» تُسمع «الخَ-لِي-يَ-ةُ» — فيسمع الطفل
      // درساً في النحو لا شرحاً لمسألته. وهي تصل من بابين: النموذج يكتبها
      // حين يتفصّح، وقارئُ الصورة ينقلها كما في الكتاب.
      //
      // ويُحذف الحرفُ ولا يُستبدل بمسافة: الحركةُ علامةٌ فوق حرفها لا
      // بينه وبين ما يليه، فمسافةٌ مكانَها تقطع الكلمة — «أوّلاً» تصير
      // «أو» و«لا».
      //
      // ولا يمسّ هذا النصَّ المعروض: الطفل يقرأ المشكول مُعيناً على
      // القراءة، ويسمعه تكلّفاً. فلكلٍّ صورتُه.
      .replaceAll(
        RegExp(
          '[ً-ٰٕۖ-ۭـ]',
        ),
        '',
      )
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
      // و`\p{M}` مع `\p{L}`: العلاماتُ المركّبة لا يُمرّرها `\p{L}` وحده،
      // ومسافةٌ مكانَ علامةٍ فوق حرفٍ تقطع كلمتَه. وتشكيلُ العربية سقط
      // أعلاه محذوفاً لا مُستبدَلاً، وهذا لما بقي من علامات — همزةٌ
      // مركّبة، أو حرفٌ من لغةٍ أخرى في اسمٍ علميّ.
      //
      // ── وعلاماتُ الترقيم تُحذف، ووقفتُها تبقى ──
      // محرّكاتٌ تقرأ «؟» صمتاً، وأخرى تنطقها «علامة استفهام» في آخر كل
      // سؤال. فلا يُؤتمن عليها، وتُحذف كلُّها.
      //
      // لكنّ حذفَها وحده يجعل الشرح نَفَساً واحداً لا يلتقط فيه الطفل
      // أين انتهت خطوةٌ وبدأت التي بعدها. فتُقلب علامةُ نهاية الجملة
      // سطراً جديداً قبل أن تُحذف: السطرُ وقفةٌ لا ينطقها محرّكٌ ولا
      // يتجاهلها.
      .replaceAll(RegExp(r'\s*[.!?؟]+'), '\n')
      // وما دون نهاية الجملة — فاصلةٌ ونقطتان — مسافةٌ لا وقفة.
      .replaceAll(RegExp(r'[،,؛;:]'), ' ')
      // ثم لا يبقى إلا حرفٌ ورقمٌ وفراغ.
      .replaceAll(
        RegExp(r'[^\p{L}\p{M}\p{N}\s]', unicode: true),
        ' ',
      )
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      // وسطرٌ لم يبق فيه إلا مسافةٌ — مكانَ سياج شيفرةٍ حُذف — يُطوى،
      // وإلا بقي في النصّ فراغٌ يقرؤه المحرّك وقفةً بلا سبب.
      .replaceAll(RegExp(r'[ \t]*\n[ \t]*'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
