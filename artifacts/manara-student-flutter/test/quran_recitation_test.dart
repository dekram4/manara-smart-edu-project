import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/models/student_gamification.dart';
import 'package:manara_student/src/models/study_games.dart';
import 'package:manara_student/src/services/quran_recitation.dart';
import 'package:manara_student/src/widgets/quran_recitation_game.dart';
import 'package:manara_student/src/widgets/study_games.dart';

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

  group('التقييم: الخطُّ يثبت لحظةَ يُقرَّر', () {
    test('كلُّ سورةٍ تُقرأ كاملةً كلمةً كلمة: تكتمل، ولا يتغيّر لونٌ بعد ظهوره', () {
      for (final surah in quranSurahs) {
        final tracker = RecitationTracker(surah)..startSession();
        final snapshots = <List<RecitedWord>>[];
        sayGrowing(tracker, fullReading(surah.id), snapshots: snapshots);
        expect(tracker.complete, isTrue, reason: surah.id);
        for (var s = 1; s < snapshots.length; s++) {
          for (var k = 0; k < snapshots[s].length; k++) {
            if (snapshots[s - 1][k] != pending) {
              expect(snapshots[s][k], snapshots[s - 1][k], reason: '${surah.id} كلمة $k');
            }
          }
        }
      }
    });

    test('الكلمةُ الصحيحة تخضرّ لحظةَ تُقال', () {
      final tracker = RecitationTracker(surahOf('ikhlas'))..startSession();
      tracker.hear('اعوذ');
      expect(tracker.status.first, correct);
      expect(tracker.position, 1);
    });

    test('الكلمةُ الخاطئة تحمرّ حين تُقرأ التي بعدها، وتبقى حمراء', () {
      final tracker = RecitationTracker(surahOf('ikhlas'))..startSession();
      final opening = spokenWords([...istiadha.split(' '), ...basmala.split(' ')]);
      final said = [...opening, 'قل', 'هو', 'الله', 'واحد'];
      sayGrowing(tracker, said);
      final ahad = opening.length + 3;
      expect(tracker.status[ahad], pending, reason: 'قد تكون كلمةً لم يُتمّها المحرّك بعد');
      sayGrowing(tracker, [...said, 'الله', 'الصمد']);
      expect(tracker.status[ahad], wrong);
      expect(tracker.status[ahad + 1], correct);
      sayGrowing(tracker, [...said, 'الله', 'الصمد', 'لم', 'يلد']);
      expect(tracker.status[ahad], wrong);
    });

    test('سكت بعد كلمةٍ خاطئة: تثبت حمراء', () {
      final tracker = RecitationTracker(surahOf('kawthar'))..startSession();
      final words = fullReading('kawthar');
      final said = [...words.take(words.length - 1), 'الابيض'];
      tracker.hear(said.join(' '));
      expect(tracker.status.last, pending);
      tracker.hear(said.join(' '), ended: true);
      expect(tracker.status.last, wrong);
      expect(tracker.reviewing, isTrue);
    });

    test('الاستعاذةُ والبسملةُ إجباريتان: من بدأ بالسورة مباشرةً تحمرّان', () {
      final tracker = RecitationTracker(surahOf('ikhlas'))..startSession();
      final verses = spokenWords(surahOf('ikhlas').verses.expand((v) => v.split(' ')));
      sayGrowing(tracker, verses);
      tracker.hear(verses.join(' '), ended: true);
      final opening = istiadha.split(' ').length + basmala.split(' ').length;
      expect(tracker.status.take(opening), everyElement(wrong));
      expect(tracker.status.skip(opening), everyElement(correct));
      expect(tracker.reviewing, isTrue);
      expect(tracker.reviewUnit, 0);
    });

    test('بعد آخر السورة تُعاد الخطواتُ الحمراء وحدها، الأولى فالتي بعدها، حتى تكتمل', () {
      final tracker = RecitationTracker(surahOf('ikhlas'))..startSession();
      final verses = spokenWords(surahOf('ikhlas').verses.expand((v) => v.split(' ')));
      tracker.hear(verses.join(' '), ended: true);
      expect(tracker.reviewUnit, 0);

      tracker.startSession();
      sayGrowing(tracker, spokenWords(istiadha.split(' ')));
      expect(tracker.reviewUnit, 1, reason: 'صحّت الاستعاذة، والبسملةُ بعدها');
      expect(tracker.complete, isFalse);

      tracker.startSession();
      sayGrowing(tracker, spokenWords(basmala.split(' ')));
      expect(tracker.complete, isTrue);
    });

    test('في الكافرون تتكرّر آية: تُتابَع بالترتيب', () {
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
      final split = words.map((w) => w == 'ولم' ? 'و لم' : w).join(' ');
      tracker.hear(split);
      expect(tracker.complete, isTrue);
      expect(quranWordMatches('الله', 'بِاللَّهِ'), isFalse);
      expect(quranWordMatches('لم', 'وَلَمْ'), isFalse);
    });

    test('خطأُ حرفٍ من محرّك التعرّف في كلمةٍ طويلة يُقبل، وفي القصيرة لا', () {
      expect(quranWordMatches('المستقيم', 'الْمُسْتَقِيمَ'), isTrue);
      expect(quranWordMatches('المستقين', 'الْمُسْتَقِيمَ'), isTrue);
      expect(quranWordMatches('لن', 'لَمْ'), isFalse);
      expect(quranWordMatches('واحد', 'أَحَدٌ'), isFalse);
      expect(quranWordMatches('إياك', 'إِيَّاكَ'), isTrue);
    });
  });

  group('واجهةُ التسميع', () {
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

    testWidgets('الخطوطُ تثبت وهو يقرأ، والحمراءُ تُعاد، والسورةُ كاملةً تُكافأ مرّةً واحدة', (tester) async {
      final recited = <String>[];
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
            listen: ({required onWords, required onEnd}) async {
              heard = onWords;
              ended = onEnd;
              return true;
            },
            stopListening: () async {},
          ),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('quran-surah-ikhlas')));
      await tester.pumpAndSettle();
      final state = tester.state<QuranRecitationGameState>(find.byType(QuranRecitationGame));

      // يبدأ بالسورة ناسياً الاستعاذةَ والبسملة.
      await tester.tap(find.byKey(const ValueKey('quran-mic')));
      await tester.pump();
      final verses = spokenWords(surahOf('ikhlas').verses.expand((v) => v.split(' ')));
      for (var n = 1; n <= verses.length; n++) {
        heard!(verses.take(n).join(' '));
        await tester.pump();
      }
      ended!();
      await tester.pump();
      expect(state.tracker!.reviewing, isTrue);
      expect(find.text('أحسنت، الآن أعد قراءة الآيات التي فيها خط أحمر 🔴'), findsOneWidget);
      expect(recited, isEmpty);

      // يعيد الاستعاذة ثم البسملة.
      await tester.tap(find.byKey(const ValueKey('quran-mic')));
      await tester.pump();
      final opening = spokenWords([...istiadha.split(' '), ...basmala.split(' ')]);
      for (var n = 1; n <= opening.length; n++) {
        heard!(opening.take(n).join(' '));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(state.done, isTrue);
      expect(state.status, everyElement(correct));
      expect(recited, ['ikhlas']);
      expect(find.byKey(const ValueKey('quran-gems')), findsOneWidget);

      // كلماتٌ تصل بعد الاكتمال لا تُكافئ مرّةً ثانية.
      heard!('قل هو الله احد');
      await tester.pumpAndSettle();
      expect(recited, ['ikhlas']);
    });

    testWidgets('بطاقتُها الرابعةُ على الرفّ بعد ألعاب الدرس، ولدرسها وحده', (tester) async {
      final games = [matchingGame()];
      Future<StudyGamesPack> load() async => StudyGamesPack(lessonId: 'L1', games: games);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StudyGamesTab(load: load, onWin: (_) async => null)),
      ));
      await tester.pump();
      expect(find.byType(QuranShelfCard), findsNothing);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StudyGamesTab(key: const ValueKey('b'), load: load, onWin: (_) async => null, onRecited: (_) async => null),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(QuranShelfCard), findsOneWidget);
      final gameTop = tester.getTopLeft(find.text('صِل')).dy;
      final quranTop = tester.getTopLeft(find.byType(QuranShelfCard)).dy;
      expect(quranTop, greaterThan(gameTop), reason: 'بعد ألعاب الدرس لا قبلها');

      await tester.tap(find.byKey(const ValueKey('quran-shelf-card')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(QuranRecitationGame), findsOneWidget);
    });
  });
}
