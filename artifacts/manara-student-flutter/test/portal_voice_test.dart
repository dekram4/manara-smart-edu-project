import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/services/student_sound_service.dart';

/// The portal lines are recorded clips, not the device's speech engine — the
/// engine was what read them in a robotic, foreign-sounding voice. These hold
/// what would quietly send a portal back to silence (a missing clip, a folder
/// the build does not bundle), and what keeps the supplied recordings in
/// place and at one loudness.
void main() {
  /// Every portal on the hub's rail, by the key its line is stored under.
  const portals = [
    'lesson',
    'cinema',
    'games',
    'personality',
    'tutor',
    'quiz',
    'solver',
    'meeting',
    'chat',
    'challenge',
  ];

  test('every portal has its line recorded in both languages', () {
    for (final portal in [...portals, 'generic']) {
      if (portal != 'generic') {
        expect(StudentStrings.has('portal.$portal.voice'), isTrue,
            reason: 'portal.$portal.voice has no text');
      }
      for (final language in ['ar', 'en']) {
        final clip = File('assets/audio/voice/${portal}_$language.mp3');
        expect(clip.existsSync(), isTrue, reason: '${clip.path} is missing');
        expect(clip.lengthSync(), greaterThan(1000),
            reason: '${clip.path} is empty');
      }
    }
  });

  test('the path screen has its greeting recorded in both languages', () {
    expect(StudentStrings.has('path.voice'), isTrue);
    for (final language in ['ar', 'en']) {
      final clip = File('assets/audio/voice/path_$language.mp3');
      expect(clip.existsSync(), isTrue, reason: '${clip.path} is missing');
      expect(clip.lengthSync(), greaterThan(1000));
    }
  });

  test('the retired generator cannot overwrite the supplied recordings', () {
    // The Arabic clips are recordings in the hub welcome's voice; an edge-tts
    // render over any of them is exactly the mismatch they replaced.
    final tool = File('tool/build_portal_voices.py').readAsStringSync();
    expect(tool, contains('if "--allow" not in sys.argv[1:]:'));
    for (final name in [
      'path',
      'lesson',
      'tutor',
      'cinema',
      'games',
      'meeting',
      'chat',
      'challenge',
      'solver',
      'quiz',
      'personality',
    ]) {
      expect(tool, contains('"${name}_ar",'),
          reason: '${name}_ar.mp3 is not protected from the generator');
    }
  });

  test('every clip has a measured level', () {
    // A clip with no entry falls back to a guessed volume — a replaced
    // recording has to be re-measured, and this is what says so.
    final clips = Directory('assets/audio/voice')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => name.endsWith('.mp3'));
    for (final clip in clips) {
      final name = clip.substring(0, clip.length - '.mp3'.length);
      expect(StudentSoundService.voiceRms.containsKey(name), isTrue,
          reason: '$clip has no measured level in StudentSoundService.voiceRms');
    }
  });

  test('each line plays at the hub welcome\'s loudness', () {
    const welcome = 0.122 * 0.78;
    StudentSoundService.voiceRms.forEach((name, rms) {
      final volume = StudentSoundService.voiceVolume('audio/voice/$name.mp3');
      expect(volume, inInclusiveRange(0.0, 1.0));
      if (welcome / rms <= 1.0) {
        expect(volume * rms, closeTo(welcome, 0.0001), reason: name);
      } else {
        // Quieter than the welcome even at full volume: as loud as it goes.
        expect(volume, 1.0, reason: name);
      }
    });
    // The loudest recording is turned down furthest.
    expect(
      StudentSoundService.voiceVolume('audio/voice/challenge_ar.mp3'),
      lessThan(StudentSoundService.voiceVolume('audio/voice/cinema_ar.mp3')),
    );
  });

  test('the clips folder is bundled with the app', () {
    // `assets/audio/` alone does not reach into `voice/`: Flutter asset
    // directories are not recursive, and every clip would fail to load.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/audio/voice/'));
  });

  test('a portal plays its own clip when it has one', () {
    const bundled = {
      'assets/audio/voice/lesson_ar.mp3',
      'assets/audio/voice/generic_ar.mp3',
    };
    expect(
      StudentSoundService.portalVoiceAsset('portal.lesson', 'ar', bundled),
      'audio/voice/lesson_ar.mp3',
    );
  });

  test('a portal with no clip yet falls back to the generic line', () {
    const bundled = {'assets/audio/voice/generic_en.mp3'};
    expect(
      StudentSoundService.portalVoiceAsset('portal.brandNew', 'en', bundled),
      'audio/voice/generic_en.mp3',
    );
  });

  group('المقاطع المورَّدة', () {
    const overrides = StudentSoundService.arabicVoiceOverrides;

    test('لكل بطاقة في اللوحة مقطعٌ مورَّد باسمه', () {
      // الأسماء كما سُلِّمت. تغييرُ أحدها في الجدول بلا تغييره هنا يمرّ
      // صامتاً، فيبحث التطبيق عن ملفٍّ لم يُسقطه أحد ويعود إلى القديم.
      expect(overrides, {
        'portal.lesson': 'audio/sharh.mp3',
        'portal.cinema': 'audio/cinemahejaz.mp3',
        'portal.tutor': 'audio/avatarhejaz.mp3',
        'portal.solver': 'audio/halhejaz.mp3',
        'portal.games': 'audio/alaab.mp3',
        'portal.quiz': 'audio/quezhejaz.mp3',
        'portal.chat': 'audio/chathejaz.mp3',
        'portal.meeting': 'audio/meethejaz.mp3',
        'portal.challenge': 'audio/tahadde.mp3',
        'portal.personality': 'audio/profhejaz.mp3',
      });
    });

    test('المقطع المورَّد يسبق القديم متى كان في الحزمة', () {
      final bundled = {
        'assets/audio/sharh.mp3',
        'assets/audio/voice/lesson_ar.mp3',
      };
      expect(
        StudentSoundService.portalVoiceAsset('portal.lesson', 'ar', bundled),
        'audio/sharh.mp3',
      );
    });

    test('وغيابُه يعيد الأمر إلى القديم لا إلى الصمت', () {
      // من يضع سبعةً من أربعةَ عشرَ يسمع السبعة الجديدة والسبعة القديمة.
      final bundled = {'assets/audio/voice/lesson_ar.mp3'};
      expect(
        StudentSoundService.portalVoiceAsset('portal.lesson', 'ar', bundled),
        'audio/voice/lesson_ar.mp3',
      );
    });

    test('الإنجليزية لا تأخذ المقطع العربي', () {
      // تسجيلاتٌ عربية، وطفلٌ يقرأ بالإنجليزية لا يفهمها.
      final bundled = {
        'assets/audio/sharh.mp3',
        'assets/audio/voice/lesson_en.mp3',
      };
      expect(
        StudentSoundService.portalVoiceAsset('portal.lesson', 'en', bundled),
        'audio/voice/lesson_en.mp3',
      );
    });

    test('كل ملفٍ في الجدول موجودٌ فعلاً في مجلّد الأصوات', () {
      // الجدول وحده لا يُسمع شيئاً. وقد مرّ تعديلٌ كامل على الكود قبل
      // أن تُنسخ الملفات، فبقي التطبيق يشغّل القديم بلا أن يشكو أحد:
      // الارتداد إلى المقطع القديم يُخفي الغياب عمداً. فيُفحص الوجود هنا.
      for (final asset in [
        ...StudentSoundService.arabicVoiceOverrides.values,
        'audio/signin.mp3',
        'audio/tarheeb.mp3',
        'audio/masar.mp3',
        'audio/start.mp3',
        'audio/happychild.mp3',
      ]) {
        expect(
          File('assets/$asset').existsSync(),
          isTrue,
          reason: 'assets/$asset غير موجود — الكود يناديه ولا يجده',
        );
      }
    });

    test('كل بطاقة في اللوحة مذكورة في الجدول', () {
      // بطاقةٌ تُضاف بلا مقطعٍ لها تبقى على القديم، وذلك مقصود — لكن
      // بطاقةً موجودةً اليوم بلا مقطعٍ في الخريطة المطلوبة خطأُ نقل.
      const cards = [
        'portal.lesson', 'portal.cinema', 'portal.games', 'portal.personality',
        'portal.tutor', 'portal.quiz', 'portal.solver', 'portal.meeting',
        'portal.chat', 'portal.challenge',
      ];
      for (final card in cards) {
        expect(overrides.containsKey(card), isTrue, reason: card);
      }
    });
  });
}
