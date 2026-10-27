import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// قاعدةُ الأصول: كلُّ وسيطٍ داخل `assets/`، ومعلنٌ في `pubspec.yaml`، ويُطلب
/// بمساره النسبيّ وحده.
///
/// ── لماذا اختبار ──
/// ملفٌّ يُطلب من مسارٍ على جهاز المطوّر (`D:\…`) يعمل عنده ويصمت في كل APK؛
/// وملفٌّ في مجلّدٍ فرعيٍّ لم يُعلَن يُنسخ إلى المشروع ولا يدخل الحزمة —
/// فـ`pubspec.yaml` لا يضمّ المجلّداتِ الفرعية من تلقاء نفسه. وكلاهما لا
/// يُرى إلا على جهاز الطفل. فهذا يفشل في كل `flutter test` قبل أن يُبنى APK.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final assetSection = pubspec.split('\n  assets:\n')[1].split('\n  fonts:')[0];
  final declared = [
    for (final line in assetSection.split('\n'))
      if (line.trim().startsWith('- ')) line.trim().substring(2).trim(),
  ];
  final fonts = [
    for (final match in RegExp(r'asset:\s*(\S+)').allMatches(pubspec)) match.group(1)!,
  ];

  /// ما يدخل الحزمة: ملفٌّ معلنٌ بعينه، أو مباشرةً في مجلّدٍ معلن.
  bool bundled(String path) {
    if (fonts.contains(path) || declared.contains(path)) return true;
    final dir = path.substring(0, path.lastIndexOf('/') + 1);
    return declared.contains(dir);
  }

  String norm(String path) => path.replaceAll(r'\', '/');

  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  test('لا مسارَ مطلقاً ولا مسارَ جهازٍ في الكود', () {
    final absolute = RegExp(
      // `/storage/emulated/` لا `/storage/` وحدها: روابطُ Supabase فيها
      // `/storage/v1/object/public/`، وهي عناوينُ خادمٍ لا مساراتُ جهاز.
      r'''['"](?:[A-Za-z]:[\\/]|/Users/|/home/|/mnt/|/sdcard/|/storage/emulated/|file://)''',
    );
    final offenders = <String>[];
    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue;
        if (absolute.hasMatch(line)) offenders.add('${norm(file.path)}:${i + 1}: $line');
      }
    }
    expect(offenders, isEmpty, reason: 'الأصولُ بمساراتها النسبية داخل assets/ وحدها');
  });

  test('كلُّ أصلٍ يطلبه الكود موجودٌ في assets/ ومعلنٌ في pubspec', () {
    final literal = RegExp(
      r'''['"]((?:assets/)?(?:audio|images|video|sounds|animations|fonts)/[^'"$\s]+\.(?:mp3|wav|m4a|ogg|png|jpe?g|webp|gif|svg|mp4|webm|json|ttf|otf|riv))['"]''',
    );
    final problems = <String>[];
    var count = 0;
    for (final file in dartFiles) {
      for (final match in literal.allMatches(file.readAsStringSync())) {
        count++;
        final ref = match.group(1)!;
        final path = ref.startsWith('assets/') ? ref : 'assets/$ref';
        if (!File(path).existsSync()) {
          problems.add('$ref غير موجود ← ${norm(file.path)}');
        } else if (!bundled(path)) {
          problems.add('$ref موجودٌ لكنه غير معلن في pubspec ← ${norm(file.path)}');
        }
      }
    }
    expect(count, greaterThan(50), reason: 'النمطُ يجد أصولَ التطبيق');
    expect(problems, isEmpty);
  });

  test('كلُّ ملفٍّ في assets/ يدخل الحزمة', () {
    // استثناءان مقصودان: مدخلاتُ أيقونة التطبيق تُولَّد منها عند التطوير ولا
    // يرسمها التطبيق (انظر pubspec)، ورخصةُ الخطّ نصٌّ لا يُقرأ وقتَ التشغيل.
    bool intentional(String path) => path.startsWith('assets/icon/') || path.endsWith('-OFL.txt');
    final stray = [
      for (final entity in Directory('assets').listSync(recursive: true))
        if (entity is File && !bundled(norm(entity.path)) && !intentional(norm(entity.path)))
          norm(entity.path),
    ];
    expect(stray, isEmpty, reason: 'أضِف مجلّدَها إلى pubspec.yaml — المجلّداتُ الفرعية لا تُضمّ تلقائياً');
  });

  test('ولا وسائطَ خارج assets/', () {
    final media = RegExp(r'\.(mp3|wav|m4a|ogg|mp4|webm|mov|png|jpe?g|webp|gif|ttf|otf)$', caseSensitive: false);
    const platform = {'build', '.dart_tool', 'assets', 'android', 'windows', 'web', 'ios', 'linux', 'macos', '.git'};
    final outside = <String>[];
    void walk(Directory dir) {
      for (final entity in dir.listSync()) {
        final name = norm(entity.path).split('/').last;
        if (entity is Directory) {
          if (!platform.contains(name)) walk(entity);
        } else if (media.hasMatch(name)) {
          outside.add(norm(entity.path));
        }
      }
    }

    walk(Directory('.'));
    expect(outside, isEmpty, reason: 'انقلها إلى assets/ وأعلنها في pubspec.yaml');
  });
}
