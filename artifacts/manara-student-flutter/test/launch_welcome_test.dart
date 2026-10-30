import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/services/student_sound_service.dart';

/// ترحيبُ فتح التطبيق: ملفٌّ واحدٌ باسمه، لهذا الموضع وحده.
///
/// ── لماذا اختبارٌ عليه ──
/// مقطعٌ غاب عن الحزمة — أو قيدٌ نُسي في `pubspec.yaml` — لا يُسقط شيئاً ولا
/// يُرفع خطأً: تُفتح الشاشةُ صامتةً أو يُسمع مقطعٌ آخر، ولا يمسكه تحليلٌ ولا
/// بناء. وهو العطبُ المُبلَّغ بعينه.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Set<String> bundled;

  setUpAll(() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    bundled = manifest.listAssets().toSet();
  });

  test('ترحيبُ الإقلاع هو المقطعُ المورَّد باسمه', () {
    expect(StudentSoundService.launchWelcomeClip, 'audio/tarheeeeeeeb.mp3');
  });

  test('وهو في الحزمة فعلاً', () {
    // بيانُ الأصول هو ما يقرؤه التطبيق: ملفٌّ في المجلّد بلا قيدٍ يشمله لا
    // يدخل الحزمة، وتُفتح الشاشةُ صامتةً بلا خطأ.
    expect(
      bundled,
      contains('assets/${StudentSoundService.launchWelcomeClip}'),
      reason: 'ترحيبُ الإقلاع ليس في الحزمة — يُفتح التطبيق صامتاً',
    );
  });

  test('ولا يُنادى إلا من موضعٍ واحد', () {
    // ── والطلبُ المُبلَّغ: هذا الملفُّ لبداية الدخول وحدها ──
    // فلو نُسخ اسمُه إلى مسلكٍ ثانٍ — ترحيبُ اللوحة، أو سطرُ بوابة — صار
    // يُسمع في مكانين، وهو ما لم يُطلب. فيُعدّ المواضع.
    final uses = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final text = file.readAsStringSync();
      for (final line in text.split('\n')) {
        // التعريفُ نفسه لا يُعدّ استعمالاً، ولا التعليقات.
        final trimmed = line.trim();
        if (!trimmed.contains('tarheeeeeeeb.mp3')) continue;
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
        uses.add('${file.path}: $trimmed');
      }
    }
    expect(
      uses,
      hasLength(1),
      reason: 'ترحيبُ الإقلاع مذكورٌ في أكثر من موضع:\n${uses.join('\n')}',
    );
    expect(uses.single, contains('launchWelcomeClip ='));
  });

  test('وترحيبُ اللوحة مقطعٌ آخر', () {
    // اللوحةُ لها ترحيبُها، ولا يحلّ ترحيبُ الإقلاع محلَّه.
    expect(bundled, contains('assets/audio/manara-arabic-student-welcome.mp3'));
  });

  test('وخلفيةُ شاشة الدخول وموسيقى المشهد في الحزمة', () {
    // الخلفيةُ تُشغَّل تحت الترحيب على مشغّلٍ ثانٍ، وغيابُها لا يمسّه.
    expect(bundled, contains('assets/audio/signin.mp3'));
    expect(bundled, contains('assets/audio/happychild.mp3'));
  });
}
