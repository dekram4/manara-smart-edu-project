import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:manara_student/src/services/student_voice_service.dart';

/// محرّكُ تعرّفٍ مزيّف: يسجّل كلَّ جلسةٍ ومهلتَها، ويُطلق الأحداث كما يطلقها
/// Android — كلماتٌ جزئية، و«انتهى».
class _FakeSpeech implements SpeechToText {
  void Function(String)? status;
  SpeechErrorListener? error;
  final sessions = <SpeechListenOptions>[];

  /// جلسةٌ مفتوحةٌ من شاشةٍ سابقة.
  var stale = false;
  var cancels = 0;

  /// يرمي المحرّكُ عند الاستماع على الجهاز (لا تعرّفَ محلّيّ).
  var refuseOnDevice = false;
  var refuseCloud = false;
  var permitted = true;
  final pauses = <Duration>[];
  SpeechResultListener? onWords;
  var stops = 0;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    dynamic debugLogging = false,
    Duration finalTimeout = const Duration(milliseconds: 2000),
    List<SpeechConfigOption>? options,
  }) async {
    status = onStatus;
    error = onError;
    return permitted;
  }

  @override
  bool get isListening => stale;

  @override
  Future<void> cancel() async {
    cancels++;
    stale = false;
  }

  @override
  Future<bool> get hasPermission async => permitted;

  @override
  Future<void> listen({
    SpeechResultListener? onResult,
    SpeechListenOptions? listenOptions,
    dynamic listenFor,
    dynamic pauseFor,
    String? localeId,
    dynamic onSoundLevelChange,
    dynamic cancelOnError,
    dynamic partialResults,
    dynamic onDevice,
    dynamic listenMode,
    dynamic sampleRate,
  }) async {
    if (stale) throw StateError('already listening');
    if (refuseOnDevice && listenOptions!.onDevice) throw StateError('no on-device recognizer');
    if (refuseCloud && !listenOptions!.onDevice) throw StateError('no recognition service');
    sessions.add(listenOptions!);
    onWords = onResult;
  }

  @override
  void changePauseFor(Duration pauseFor) => pauses.add(pauseFor);

  @override
  Future<void> stop() async => stops++;

  void say(String words, {bool last = false}) => onWords!(
        SpeechRecognitionResult.init([SpeechRecognitionWords(words, null, 0.9)], last ? ResultType.finalResult : ResultType.partial),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QuietTts implements FlutterTts {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<dynamic>.value(1);
}

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late _FakeSpeech speech;
  late StudentVoiceService voice;

  setUp(() {
    speech = _FakeSpeech();
    voice = StudentVoiceService(speech: speech, tts: _QuietTts());
  });

  test('صمتٌ أوّلُ طويل: لا يُغلَق المايكُ قبل أن يتكلّم الطفل', () async {
    final results = <String>[];
    await voice.listenForChild(onResult: results.add, window: const Duration(seconds: 15));
    expect(speech.sessions.single.pauseFor, const Duration(seconds: 8));
    expect(speech.sessions.single.listenFor!.inSeconds, greaterThanOrEqualTo(14));
    expect(speech.sessions.single.partialResults, isTrue);
    expect(speech.sessions.single.listenMode, ListenMode.dictation, reason: 'كلامٌ طبيعيٌّ متّصل');
    expect(results, isEmpty);
  });

  test('أنهى المحرّكُ الجلسةَ ولم يتكلّم: يُفتح المايكُ ثانيةً وحده', () async {
    final results = <String>[];
    await voice.listenForChild(onResult: results.add, window: const Duration(seconds: 6));
    await _wait(500);
    speech.status!(SpeechToText.doneStatus);
    await _wait(400);
    expect(speech.sessions, hasLength(2), reason: 'جلسةٌ ثانيةٌ لا صفّارةُ إغلاق');
    expect(results, isEmpty);
    // ‏«notListening» ثم «done» للجلسة نفسها: لا تُفتح ثالثة.
    speech.status!(SpeechToText.notListeningStatus);
    await _wait(400);
    expect(speech.sessions, hasLength(2));
  });

  test('تكلّم: الصمتُ المُنهي يقصر، والكلماتُ تصل وهي تُقال، ثم ما قاله', () async {
    final results = <String>[];
    final partials = <String>[];
    await voice.listenForChild(onResult: results.add, onPartial: partials.add);
    speech.say('جوري');
    speech.say('جوري داود');
    expect(partials, ['جوري', 'جوري داود']);
    expect(speech.pauses, [const Duration(milliseconds: 1200)], reason: 'مرّةً واحدة، عند أوّل كلمة');
    await _wait(500);
    speech.status!(SpeechToText.doneStatus);
    expect(results, ['جوري داود']);
    expect(speech.sessions, hasLength(1));
  });

  test('لمسةٌ ثانيةٌ تُنهيه بما قيل حتى الآن', () async {
    final results = <String>[];
    await voice.listenForChild(onResult: results.add);
    speech.say('الفصل');
    voice.finishChildListening();
    expect(results, ['الفصل']);
    expect(speech.stops, greaterThanOrEqualTo(1));
  });

  test('انقضت النافذةُ ولم يتكلّم: يُختم فارغاً', () async {
    final results = <String>[];
    await voice.listenForChild(onResult: results.add, window: const Duration(milliseconds: 1900));
    await _wait(500);
    speech.status!(SpeechToText.doneStatus);
    expect(results, ['']);
  });

  group('المايكُ نفسُه في كل الشاشات', () {
    test('الطفلُ يُسمع بالخدمة العادية؛ والتعرّفُ على الجهاز إن رفضها المحرّكُ من أوّلها وحده', () async {
      expect(await voice.listenForChild(onResult: (_) {}), isTrue);
      expect(speech.sessions.single.onDevice, isFalse);

      final cloudless = _FakeSpeech()..refuseCloud = true;
      final voice2 = StudentVoiceService(speech: cloudless, tts: _QuietTts());
      expect(await voice2.listenForChild(onResult: (_) {}), isTrue);
      expect(cloudless.sessions.single.onDevice, isTrue);
      expect(voice2.lastProblem, contains('no recognition service'));
    });

    test('لا يُلغى استماعٌ «قديم» قبل الجديد: إلغاؤه يُنهي الجديدَ فلا يسمع المايكُ أبداً', () async {
      speech.stale = false;
      await voice.listenForChild(onResult: (_) {});
      await voice.listenLive(onWords: (_) {}, onEnd: () {});
      expect(speech.cancels, 0);
    });

    test('التسميع: أيُّ خطأٍ على الجهاز — حتى «لم يُفهم شيء» — يردّ إلى الخدمة العادية', () async {
      // ‏محرّكٌ محلّيٌّ بلا نموذجٍ عربيّ يقول «لم يُفهم شيء» لكل كلمة؛ استثناؤه
      // ‏مرّةً أبقى التطبيقَ كلَّه عليه، فتعطّل المايكُ في كل شاشة.
      var ends = 0;
      await voice.listenLive(onWords: (_) {}, onEnd: () => ends++);
      expect(speech.sessions.single.onDevice, isTrue);
      speech.error!(SpeechRecognitionError('error_no_match', false));
      expect(ends, 1);
      expect(voice.lastProblem, 'error_no_match');
      await voice.listenLive(onWords: (_) {}, onEnd: () {});
      expect(speech.sessions.map((s) => s.onDevice), [true, false]);
    });

    test('الإذنُ حالةٌ واحدة: ما ثبت بالمحرّك يكفي كلَّ شاشة', () async {
      expect(voice.micGranted, isFalse);
      expect(await voice.prepare(), isTrue);
      expect(voice.micGranted, isTrue, reason: 'المحرّكُ لا يتهيّأ إلا بالإذن');

      final denied = _FakeSpeech()..permitted = false;
      final voice2 = StudentVoiceService(speech: denied, tts: _QuietTts());
      expect(await voice2.hasMicPermission(), isFalse);
      expect(await voice2.listenForChild(onResult: (_) {}), isFalse);
      denied.permitted = true;
      expect(await voice2.hasMicPermission(), isTrue);
      expect(voice2.micGranted, isTrue);
    });
  });

  test('كلُّ ظنون المحرّك تُضمّ: الصحيحُ في الظنّ الثاني يكفي', () {
    final result = SpeechRecognitionResult.init([
      const SpeechRecognitionWords('سادة داود', null, 0.6),
      const SpeechRecognitionWords('سادن داود', null, 0.3),
      const SpeechRecognitionWords('سادة داود', null, 0.1),
    ], ResultType.partial);
    expect(StudentVoiceService.childWords(result), 'سادة داود سادن داود');
  });

  group('إملاءُ سؤال «حل المسائل»', () {
    test('وقفةٌ في منتصف السؤال لا تقطعه: يُفتح المايكُ ثانيةً ويُضاف ما بعدها', () async {
      final results = <String>[];
      final partials = <String>[];
      await voice.listenDictation(onResult: results.add, onPartial: partials.add);
      expect(speech.sessions.single.listenMode, ListenMode.dictation);
      expect(speech.sessions.single.partialResults, isTrue);
      expect(speech.sessions.single.listenFor!.inSeconds, greaterThanOrEqualTo(59));
      speech.say('ما منزلة الرقم 7');
      speech.say('ما منزلة الرقم 7', last: true);
      speech.status!(SpeechToText.doneStatus);
      await _wait(300);
      expect(results, isEmpty, reason: 'وقفةٌ قصيرة لا تُنهي السؤال');
      expect(speech.sessions, hasLength(2));
      speech.say('في العدد 4752');
      expect(partials.last, 'ما منزلة الرقم 7 في العدد 4752');
      speech.say('في العدد 4752', last: true);
      expect(results, isEmpty);
      // ‏«توقّف»: يُكتب ما قيل كلُّه.
      voice.finishDictation();
      expect(results, ['ما منزلة الرقم 7 في العدد 4752']);
      expect(voice.dictating, isFalse);
    });

    test('صمتٌ كامل بعد آخر كلمة يُنهي الإملاءَ وحده بالسؤال كاملاً', () async {
      final results = <String>[];
      await voice.listenDictation(onResult: results.add, endSilence: const Duration(milliseconds: 300));
      speech.say('كم عدد الألوان الأساسية');
      await _wait(400);
      speech.say('كم عدد الألوان الأساسية', last: true);
      expect(results, ['كم عدد الألوان الأساسية']);
      expect(speech.sessions, hasLength(1));
    });
  });

  test('«اسمع الإجابة»: الإجابةُ الطويلة مقاطعُ جُمليّة كلُّها، لا يُسقط منها حرف', () {
    final answer = List.generate(40, (i) => 'الخطوة ${i + 1}: نضرب العدد في عشرة ثم نجمع الناتج.').join(' ');
    final chunks = StudentVoiceService.answerChunks(answer);
    expect(chunks.length, greaterThan(1));
    expect(chunks.every((c) => c.length <= StudentVoiceService.answerChunk), isTrue);
    expect(chunks.join(' ').replaceAll(RegExp(r's+'), ' '), answer.replaceAll(RegExp(r's+'), ' '));
    expect(StudentVoiceService.answerChunks('جملةٌ قصيرة.'), ['جملةٌ قصيرة.']);
  });
}
