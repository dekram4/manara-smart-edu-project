import 'package:flutter_tts/flutter_tts.dart';

class ManaraSpeechService {
  ManaraSpeechService._();
  static final instance = ManaraSpeechService._();
  final FlutterTts _tts = FlutterTts();
  bool enabled = true;

  Future<void> init() async {
    await _tts.setLanguage('ar-SA');
    await _tts.setSpeechRate(.42);
    await _tts.setPitch(1.1);
  }

  Future<void> speak(String text) async {
    if (!enabled || text.trim().isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();

  Future<void> greeting() => speak('مرحباً يا بطل! هل أنت جاهز لمغامرة اليوم؟');
  Future<void> quizStart() => speak('هيا نبدأ الاختبار، فكر جيداً وأجب بثقة!');
  Future<void> success() => speak('أحسنت! إجابة رائعة، استمر في التقدم!');
  Future<void> encouragement() => speak('عمل رائع! أنت تتعلم خطوة بخطوة.');
  Future<void> error() => speak('لا تتراجع، حاول مرة أخرى وستنجح!');
}