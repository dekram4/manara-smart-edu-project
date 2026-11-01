import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:manara_student/src/services/student_voice_service.dart';

/// محرّكُ تعرّفٍ مزيّف: يسجّل كلَّ جلسةٍ ومهلتَها، ويُطلق الأحداث كما يطلقها
/// Android — كلماتٌ جزئية، و«انتهى».
class _FakeSpeech implements SpeechToText {
  void Function(String)? status;
  final sessions = <SpeechListenOptions>[];
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
    return true;
  }

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
    expect(speech.pauses, [const Duration(milliseconds: 1800)], reason: 'مرّةً واحدة، عند أوّل كلمة');
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
}
