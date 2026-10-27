import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/services/tracing_glyphs.dart';

/// كلُّ تسجيلٍ في [arabicLetterClips] ملفٌّ موجودٌ في الحزمة: اسمٌ أُخطئ أو
/// ملفٌّ لم يُنسخ يُسكت الحرفَ على الجهاز بلا خطأٍ ظاهر.
void main() {
  test('ملفاتُ أسماء الحروف موجودةٌ ومعلنةٌ في pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/audio/ar/'));
    for (final entry in arabicLetterClips.entries) {
      final file = File('assets/${entry.value}');
      expect(file.existsSync(), isTrue, reason: '${entry.key} → ${entry.value}');
      final head = file.readAsBytesSync().take(3).toList();
      // ‏ID3 أو إطارُ MP3 (0xFF 0xFB/0xF3/0xF2).
      final mp3 = (head[0] == 0x49 && head[1] == 0x44 && head[2] == 0x33) || head[0] == 0xFF;
      expect(mp3, isTrue, reason: '${entry.value} ليس MP3');
    }
  });
}
