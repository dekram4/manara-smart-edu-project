import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/models/student_gamification.dart';
import 'package:manara_student/src/models/study_games.dart';
import 'package:manara_student/src/services/quran_recitation.dart';
import 'package:manara_student/src/widgets/quran_recitation_game.dart';

/// ما يكتبه محرّكُ التعرّف: الكلماتُ بلا تشكيل.
List<String> spokenWords(Iterable<String> words) => words.map(normalizeQuranWord).toList();

QuranSurah surahOf(String id) => quranSurahs.firstWhere((s) => s.id == id);

/// كلُّ ما يُقرأ من السورة بترتيبه: الاستعاذة والبسملة والآيات.
List<String> fullReading(String id) => spokenWords(RecitationTracker(surahOf(id)).words);

/// يُسمع النصُّ كما يصل من المحرّك: يكبر كلمةً كلمة.
void sayGrowing(RecitationTracker tracker, List<String> words, {List<List<RecitedWord>>? snapshots}) {
  for (var n = 1; n <= words.length; n++) {
    tracker.hear(words.take(n).join(' '));
    snapshots?.add(tracker.status);
  }
}

const correct = RecitedWord.correct;
const wrong = RecitedWord.wrong;
const pending = RecitedWord.pending;

StudyGame matchingGame() => StudyGame.fromMap({
      'id': 'matching',
      'game_type': 'matching',
      'title': 'صِل',
      'instructions': 'صل',
      'items': {
        'drag_items': ['أ', 'ب'],
        'drop_targets': ['١', '٢'],
        'correct_pairs': [
          {'item': 'أ', 'target': '١'},
          {'item': 'ب', 'target': '٢'},
        ],
      },
      'gems_reward': 5,
      'points_reward': 20,
    })!;

void main() {
  group('متى تظهر: الروضةُ والقرآنُ ودرسُ السور القصيرة معاً، وحصراً', () {
    test('الثلاثةُ معاً — بأيّ همزةٍ وتاءٍ كُتبت', () {
      expect(
        quranRecitationAllowedFor(grade: 'روضة منارة المعرفة', subject: 'القرآن الكريم', lesson: 'حفظ وشرح السور القصيرة'),
        isTrue,
      );
      expect(
        quranRecitationAllowedFor(grade: 'روضه مناره المعرفه', subject: 'القران الكريم', lesson: 'درس: حفظ وشرح السور القصيره'),
        isTrue,
      );
      // ‏والاسمُ الجديد للدرس.
      expect(
        quranRecitationAllowedFor(grade: 'روضة منارة المعرفة', subject: 'القرآن الكريم', lesson: 'تعلم وحفظ السور القصيرة'),
        isTrue,
      );
    });

    test('وأيُّ صفٍّ أو مادّةٍ أو درسٍ آخر: لا', () {
      expect(quranRecitationAllowedFor(grade: 'الصف الأول', subject: 'القرآن الكريم', lesson: 'حفظ وشرح السور القصيرة'), isFalse);
      expect(quranRecitationAllowedFor(grade: 'روضة منارة المعرفة', subject: 'الحروف العربية', lesson: 'حفظ وشرح السور القصيرة'), isFalse);
      expect(quranRecitationAllowedFor(grade: 'روضة منارة المعرفة', subject: 'القرآن الكريم', lesson: 'سورة الفيل'), isFalse);
      expect(quranRecitationAllowedFor(grade: null, subject: null, lesson: null), isFalse);
    });
  });

  group('السور الثماني', () {
    test('بعددِ آياتها، وبمعرّفات الخادم', () {
      final verses = {for (final s in quranSurahs) s.id: s.verses.length};
      expect(verses, {
        'fatiha': 7,
        'nas': 6,
        'falaq': 5,
        'ikhlas': 4,
        'masad': 5,
        'nasr': 3,
        'kafirun': 6,
        'kawthar': 3,
      });
    });

    test('تبدأ كلُّ سورةٍ بالاستعاذة ثم البسملة — وفي الفاتحة البسملةُ آيتُها الأولى', () {
      final ikhlas = surahOf('ikhlas').units;
      expect(ikhlas.map((u) => u.kind).take(3), [
        RecitationUnitKind.istiadha,
        RecitationUnitKind.basmala,
        RecitationUnitKind.verse,
      ]);
      expect(ikhlas[2].number, 1);
      final fatiha = surahOf('fatiha').units;
      expect(fatiha[0].kind, RecitationUnitKind.istiadha);
      expect(fatiha[1].kind, RecitationUnitKind.verse);
      expect(fatiha[1].text, basmala);
      expect(fatiha.where((u) => u.kind == RecitationUnitKind.basmala), isEmpty);
    });

    test('اسمُ كل سورةٍ بصوتٍ مسجّل داخل assets/audio/surah_names/', () {
      for (final surah in quranSurahs) {
        expect(surah.nameClip, startsWith('audio/surah_names/'));
        expect(File('assets/${surah.nameClip}').existsSync(), isTrue, reason: surah.nameClip);
      }
    });
  });

  group('التقييم: فوراً، ولا انتقالَ قبل التصحيح', () {
    test('كلُّ سورةٍ تُقرأ كاملةً كلمةً كلمة: تكتمل، والأخضرُ لا ينقلب', () {
      for (final surah in quranSurahs) {
        final tracker = RecitationTracker(surah)..startSession();
        final snapshots = <List<RecitedWord>>[];
        sayGrowing(tracker, fullReading(surah.id), snapshots: snapshots);
        expect(tracker.complete, isTrue, reason: surah.id);
        for (var s = 1; s < snapshots.length; s++) {
          for (var k = 0; k < snapshots[s].length; k++) {
            if (snapshots[s - 1][k] == correct) expect(snapshots[s][k], correct, reason: '${surah.id} كلمة $k');
          }
        }
      }
    });

    test('الكلمةُ الصحيحة تخضرّ لحظةَ تُقال', () {
      final tracker = RecitationTracker(surahOf('ikhlas'))..startSession();
      tracker.hear('اعوذ');
      expect(tracker.status.first, correct);
    });

    test('الكلمةُ الخاطئة تحمرّ لحظةَ تُقال — لا حين تُقرأ التي بعدها', () {
      final tracker = RecitationTracker(surahOf('ikhlas'))..startSession();
      final opening = spokenWords([...istiadha.split(' '), ...basmala.split(' ')]);
      sayGrowing(tracker, [...opening, 'قل', 'هو', 'الله', 'واحد']);
      expect(tracker.status[opening.length + 3], wrong);
      expect(tracker.blocked, isTrue);
    });

    test('آيةٌ فيها أحمر توقف التلاوة: ما يقرؤه بعدها لا يُحسب حتى يصحّحها', () {
      final tracker = RecitationTracker(surahOf('ikhlas'))..startSession();
      final opening = spokenWords([...istiadha.split(' '), ...basmala.split(' ')]);
      final verse1 = opening.length; // أوّلُ كلمةٍ من «قل هو الله أحد»
      final said = [...opening, 'قل', 'هو', 'الله', 'واحد', 'الله', 'الصمد'];
      sayGrowing(tracker, said);
      expect(tracker.currentUnit, 2, reason: 'ما زال في الآية الأولى');
      expect(tracker.status[verse1 + 4], pending, reason: '«الله الصمد» لم تُحسب للآية الثانية');

      // يعيد الكلمةَ الحمراء: تخضرّ، فينتقل.
      sayGrowing(tracker, [...said, 'قل', 'هو', 'الله', 'احد']);
      expect(tracker.status[verse1 + 3], correct);
      expect(tracker.blocked, isFalse);
      expect(tracker.currentUnit, 3);
    });

    test('الاستعاذةُ والبسملةُ إجباريتان: من بدأ بالسورة مباشرةً لا يتقدّم', () {
      final tracker = RecitationTracker(surahOf('ikhlas'))..startSession();
      final verses = spokenWords(surahOf('ikhlas').verses.expand((v) => v.split(' ')));
      sayGrowing(tracker, verses);
      tracker.hear(verses.join(' '), ended: true);
      expect(tracker.currentUnit, 0);
      expect(tracker.complete, isFalse);

      tracker.startSession();
      sayGrowing(tracker, fullReading('ikhlas'));
      expect(tracker.complete, isTrue);
    });

    test('يكمل في استماعٍ جديد من حيث توقّف', () {
      final tracker = RecitationTracker(surahOf('kafirun'))..startSession();
      final words = fullReading('kafirun');
      sayGrowing(tracker, words.take(20).toList());
      tracker.hear(words.take(20).join(' '), ended: true);
      tracker.startSession();
      sayGrowing(tracker, words.skip(20).toList());
      expect(tracker.complete, isTrue);
    });

    test('حرفُ العطف مفصولاً («و لم») يُلصق بما بعده، وبدونه كلمةٌ أخرى', () {
      final tracker = RecitationTracker(surahOf('ikhlas'))..startSession();
      final words = fullReading('ikhlas');
      tracker.hear(words.map((w) => w == 'ولم' ? 'و لم' : w).join(' '));
      expect(tracker.complete, isTrue);
      expect(quranWordMatches('الله', 'بِاللَّهِ'), isFalse);
      expect(quranWordMatches('لم', 'وَلَمْ'), isFalse);
    });

    test('خطأُ الحركة لا يُغتفر: مدٌّ زائدٌ أو ناقص، وتنوين', () {
      // «مَلِكِ» مكانَ «مَالِكِ»: مدٌّ ناقص — كان يُقبل بتساهل الحرف.
      expect(quranWordMatches('ملك', 'مَالِكِ'), isFalse);
      expect(quranWordMatches('مالك', 'مَالِكِ'), isTrue);
      // مدٌّ زائد.
      expect(quranWordMatches('الرحيمي', 'الرَّحِيمِ'), isFalse);
      expect(quranWordMatches('العلمين', 'الْعَالَمِينَ'), isFalse);
      // تنوينٌ زائدٌ في آخر الكلمة.
      expect(quranWordMatches('مسدن', 'مَسَدٍ'), isFalse);
      // وحرفٌ ساكنٌ أخطأه المحرّكُ يبقى مغتفراً.
      expect(quranWordMatches('المستقين', 'الْمُسْتَقِيمَ'), isTrue);
    });

    test('حركاتٌ كتبها المحرّك تُقارن بحركات الآية، وغيابُها ليس خطأً', () {
      expect(quranWordMatches('الْحَمْدُ', 'الْحَمْدُ'), isTrue);
      // ضمّةُ الدال صارت فتحة.
      expect(quranWordMatches('الْحَمْدَ', 'الْحَمْدُ'), isFalse);
      // كسرةُ الباء صارت فتحة.
      expect(quranWordMatches('رَبَّ', 'رَبِّ'), isFalse);
      // شدّةٌ ناقصة.
      expect(quranWordMatches('رَبِ', 'رَبِّ'), isFalse);
      // تشكيلٌ جزئيّ صحيح: يُحاسَب على ما كُتب وحده.
      expect(quranWordMatches('ربِّ', 'رَبِّ'), isTrue);
      // بلا تشكيلٍ أصلاً كما تكتب أكثرُ المحرّكات.
      expect(quranWordMatches('رب', 'رَبِّ'), isTrue);
    });

    test('الخطُّ الأحمر لحظةَ تُخطأ الحركة، ولا يتقدّم حتى تُصحَّح', () {
      final tracker = RecitationTracker(quranSurahs.firstWhere((s) => s.id == 'fatiha'))..startSession();
      // الاستعاذةُ ثم البسملةُ ثم الآياتُ حتى «مالك يوم الدين».
      tracker.hear('أعوذ بالله من الشيطان الرجيم');
      tracker.hear('أعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم');
      tracker.startSession();
      tracker.hear('الحمد لله رب العالمين');
      tracker.startSession();
      tracker.hear('الرحمن الرحيم');
      tracker.startSession();
      final unit = tracker.currentUnit;
      tracker.hear('ملك يوم الدين');
      expect(tracker.currentUnit, unit, reason: 'لا انتقالَ والمدُّ ناقص');
      expect(tracker.blocked, isTrue);
      tracker.hear('ملك يوم الدين مالك يوم الدين');
      expect(tracker.currentUnit, greaterThan(unit), reason: 'صحّح فاخضرّت');
    });

    test('خطأُ حرفٍ من محرّك التعرّف في كلمةٍ طويلة يُقبل، وفي القصيرة لا', () {
      expect(quranWordMatches('المستقيم', 'الْمُسْتَقِيمَ'), isTrue);
      expect(quranWordMatches('المستقين', 'الْمُسْتَقِيمَ'), isTrue);
      expect(quranWordMatches('لن', 'لَمْ'), isFalse);
      expect(quranWordMatches('واحد', 'أَحَدٌ'), isFalse);
      expect(quranWordMatches('إياك', 'إِيَّاكَ'), isTrue);
    });

    test('لكل خطوةٍ تلاوتُها الصحيحة داخل assets/audio/quran/', () {
      for (final surah in quranSurahs) {
        for (final unit in surah.units) {
          expect(unit.clip, startsWith('audio/quran/'));
          expect(File('assets/${unit.clip}').existsSync(), isTrue, reason: unit.clip);
        }
      }
    });
  });

  group('واجهةُ التسميع', () {
    testWidgets('النصُّ المباشر لا يعيد بناءَ السورة، والخطُّ الأحمر في الإطار التالي', (tester) async {
      ValueChanged<String>? heard;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QuranRecitationGame(
            onRecited: (_) async => null,
            onBack: () {},
            playName: (_) {},
            listen: ({required onWords, required onEnd}) async {
              heard = onWords;
              return true;
            },
            stopListening: () async {},
          ),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('quran-surah-kawthar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quran-mic')));
      await tester.pump();

      final opening = spokenWords(istiadha.split(' '));
      heard!(opening.join(' '));
      await tester.pump();
      final before = tester.widget(find.byKey(const ValueKey('quran-word-0')));

      // المحرّكُ يعيد النصَّ نفسَه، ثم دفعةٌ من الأجزاء في إطارٍ واحد: لا لونَ
      // تغيّر، فلا تُعاد السورة — والكلمةُ المسموعة تلحق بآخرها بإيقاعها.
      heard!(opening.join(' '));
      await tester.pump();
      expect(identical(tester.widget(find.byKey(const ValueKey('quran-word-0'))), before), isTrue,
          reason: 'نصٌّ جزئيٌّ لم يغيّر لوناً لا يعيد بناءَ السورة');
      for (final partial in ['ب', 'بس', 'بسم']) {
        heard!('${opening.join(' ')} $partial');
      }
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.state<QuranRecitationGameState>(find.byType(QuranRecitationGame)).heardWord, 'بسم',
          reason: 'الكلمةُ المسموعة آخرُ ما قيل');

      // خطأٌ في البسملة: أحمرُ في الإطار التالي مباشرةً.
      final basmalaStart = opening.length;
      heard!('${opening.join(' ')} بسم الله الرحيم');
      await tester.pump();
      final state = tester.state<QuranRecitationGameState>(find.byType(QuranRecitationGame));
      expect(state.tracker!.statusAt(basmalaStart + 2), wrong);
      final word = tester.widget<Container>(find.byKey(ValueKey('quran-word-${basmalaStart + 2}')));
      expect(((word.decoration! as BoxDecoration).border! as Border).bottom.color, QuranRecitationGameState.red);
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('السورُ الثماني في القائمة، واسمُ السورة يُسمع لحظةَ اختيارها', (tester) async {
      final played = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QuranRecitationGame(onRecited: (_) async => null, onBack: () {}, playName: played.add),
        ),
      ));
      for (final surah in quranSurahs) {
        expect(find.byKey(ValueKey('quran-surah-${surah.id}')), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('quran-surah-nas')));
      await tester.pump();
      expect(played, ['audio/surah_names/surah_nas.mp3']);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('خطأٌ يوقفه، و«استمع» تُسمعه الآيةَ والمايكُ مغلق، ثم يُفتح؛ والسورةُ كاملةً تُكافأ مرّةً', (tester) async {
      final recited = <String>[];
      final recitations = <String>[];
      var sessions = 0;
      var stops = 0;
      ValueChanged<String>? heard;
      VoidCallback? ended;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QuranRecitationGame(
            onRecited: (surah) async {
              recited.add(surah.id);
              return const RewardResult(
                xp: 3,
                gems: 3,
                alreadyRewarded: false,
                levelUp: false,
                newAchievements: [],
                snapshot: StudentGamification(),
              );
            },
            onBack: () {},
            playName: (_) {},
            playRecitation: (asset) async => recitations.add(asset),
            listen: ({required onWords, required onEnd}) async {
              sessions++;
              heard = onWords;
              ended = onEnd;
              return true;
            },
            stopListening: () async => stops++,
          ),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('quran-surah-kawthar')));
      await tester.pumpAndSettle();
      final state = tester.state<QuranRecitationGameState>(find.byType(QuranRecitationGame));

      await tester.tap(find.byKey(const ValueKey('quran-mic')));
      await tester.pump();
      expect(sessions, 1);
      final opening = spokenWords([...istiadha.split(' '), ...basmala.split(' ')]);
      final said = [...opening, 'انا', 'اعطيناك', 'الكوكب'];
      for (var n = 1; n <= said.length; n++) {
        heard!(said.take(n).join(' '));
        await tester.pump();
      }
      expect(state.tracker!.blocked, isTrue);
      expect(find.byKey(const ValueKey('quran-help')), findsOneWidget);

      // النظامُ أغلق المايك بعد صمت: يُفتح من جديد وحده.
      ended!();
      await tester.pump(const Duration(milliseconds: 300));
      expect(sessions, 2);
      expect(state.listening, isTrue);

      // «استمع»: يُغلَق المايك، وتُسمع الآية، ثم يُفتح.
      await tester.tap(find.byKey(const ValueKey('quran-help')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(recitations, ['audio/quran/kawthar_1.mp3']);
      expect(stops, greaterThanOrEqualTo(1));
      expect(sessions, 3);

      final rest = fullReading('kawthar').skip(opening.length).toList();
      for (var n = 1; n <= rest.length; n++) {
        heard!(rest.take(n).join(' '));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(state.done, isTrue);
      expect(state.status, everyElement(correct));
      expect(recited, ['kawthar']);
      expect(find.byKey(const ValueKey('quran-gems')), findsOneWidget);

      heard!('انا اعطيناك الكوثر');
      await tester.pumpAndSettle();
      expect(recited, ['kawthar']);
    });

    testWidgets('السابقةُ والتالية من شاشة التسميع نفسها', (tester) async {
      final played = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QuranRecitationGame(onRecited: (_) async => null, onBack: () {}, playName: played.add),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('quran-surah-nas')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quran-next')));
      await tester.pumpAndSettle();
      expect(played.last, quranSurahs[2].nameClip);
      await tester.tap(find.byKey(const ValueKey('quran-prev')));
      await tester.pumpAndSettle();
      expect(played.last, quranSurahs[1].nameClip);
      // الأولى: لا سابقةَ لها.
      await tester.tap(find.byKey(const ValueKey('quran-prev')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quran-prev')));
      await tester.pumpAndSettle();
      expect(played.last, quranSurahs.first.nameClip);
      expect(played.where((c) => c == quranSurahs.first.nameClip), hasLength(1));
    });

    test('المطابقةُ والتلوينُ على الجهاز وحده: لا شبكةَ في ملفّيهما', () {
      for (final path in ['lib/src/services/quran_recitation.dart', 'lib/src/widgets/quran_recitation_game.dart']) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains('package:http')), reason: path);
        expect(source, isNot(contains('dart:io')), reason: path);
        expect(source, isNot(contains('content_service')), reason: path);
      }
    });
  });
}
