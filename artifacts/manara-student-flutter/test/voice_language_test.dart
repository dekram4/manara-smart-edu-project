import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:manara_student/src/services/student_voice_service.dart';

/// محرّكُ نطقٍ مزيّف يسجّل ما يُطلب منه — لغتَه وحدّتَه وما يُنطق.
class _RecordingTts extends FlutterTts {
  _RecordingTts({required this.available});

  /// اللغاتُ التي «يملكها» هذا الجهاز.
  final Set<String> available;
  final List<String> languages = [];
  final List<double> pitches = [];
  final List<String> spoken = [];

  String? get language => languages.isEmpty ? null : languages.last;

  @override
  Future<dynamic> isLanguageAvailable(String language) async => available.contains(language);
  @override
  Future<dynamic> setLanguage(String language) async => languages.add(language);
  @override
  Future<dynamic> setPitch(double pitch) async => pitches.add(pitch);
  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;
  @override
  Future<dynamic> setVolume(double volume) async => 1;
  @override
  Future<dynamic> stop() async => 1;
  @override
  Future<dynamic> get getVoices async => const [];
  @override
  Future<dynamic> setVoice(Map<String, String> voice) async => 1;
  @override
  Future<dynamic> speak(String text, {bool focus = false}) async => spoken.add(text);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('العربيةُ تبقى ar-SA حين يملكها الجهاز — لا تمحوها «ar» بعدها', () async {
    // كانت `setLanguage('ar')` تُنادى بعد اختيار ar-SA في كل حال، فتمحوها.
    final tts = _RecordingTts(available: {'ar-SA', 'ar', 'en-US'});
    await StudentVoiceService(tts: tts).speakIn('باء', lang: 'ar');
    expect(tts.language, 'ar-SA');
    expect(tts.languages, ['ar-SA']);
    expect(tts.spoken, ['باء']);
  });

  test('جهازٌ بلا ar-SA: «ar» العامّة', () async {
    final tts = _RecordingTts(available: {'ar', 'en-US'});
    await StudentVoiceService(tts: tts).speakIn('خمسة وعشرون', lang: 'ar');
    expect(tts.language, 'ar');
  });

  test('جهازٌ لا يجيب عن أيّ لغة: تُطلب ar-SA على كل حال', () async {
    final tts = _RecordingTts(available: {});
    await StudentVoiceService(tts: tts).speakIn('باء', lang: 'ar');
    expect(tts.language, 'ar-SA');
  });

  test('الإنجليزيةُ بصوتٍ إنجليزي en-US لا عربيّ', () async {
    final tts = _RecordingTts(available: {'ar-SA', 'en-US', 'en-GB'});
    await StudentVoiceService(tts: tts).speakIn('B', lang: 'en');
    expect(tts.language, 'en-US');
    expect(tts.spoken, ['B']);
  });

  test('حدّةُ صوت الطفل تصل المحرّك، وبقيّةُ النطق بصوته كما هو', () async {
    final tts = _RecordingTts(available: {'ar-SA', 'en-US'});
    final voice = StudentVoiceService(tts: tts);
    await voice.speakIn('باء', lang: 'ar', pitch: StudentVoiceService.childPitch);
    await voice.speakIn('A', lang: 'en', pitch: StudentVoiceService.childPitch);
    await voice.speak('شرحُ الدرس');
    expect(tts.pitches, [StudentVoiceService.childPitch, StudentVoiceService.childPitch, 1.0]);
    expect(StudentVoiceService.childPitch, inInclusiveRange(1.05, 1.3), reason: 'أعلى قليلاً لا مشوِّهاً');
  });
}
