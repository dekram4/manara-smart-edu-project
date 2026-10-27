import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/models/student_gamification.dart';
import 'package:manara_student/src/models/study_games.dart';
import 'package:manara_student/src/services/quran_recitation.dart';
import 'package:manara_student/src/widgets/quran_recitation_game.dart';
import 'package:manara_student/src/widgets/study_games.dart';

/// ما يكتبه محرّكُ التعرّف: الكلماتُ بلا تشكيل.
String spoken(Iterable<String> words) => words.map(normalizeQuranWord).join(' ');

QuranSurah surahOf(String id) => quranSurahs.firstWhere((s) => s.id == id);

List<String> wordsOf(String id) => [for (final w in surahOf(id).words) w.word];

const correct = RecitedWord.correct;
const wrong = RecitedWord.wrong;
const pending = RecitedWord.pending;

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
      expect(surahOf('fatiha').basmalaIsVerse, isTrue);
      expect(surahOf('ikhlas').basmalaIsVerse, isFalse);
    });
  });

  group('التقييم كلمةً كلمة', () {
    test('كلُّ سورةٍ تُقرأ كاملةً كما يكتبها محرّكُ التعرّف: كلُّها خضراء', () {
      for (final surah in quranSurahs) {
        final words = wordsOf(surah.id);
        expect(alignRecitation(words, spoken(words)), everyElement(correct), reason: surah.id);
      }
    });

    test('الاستعاذةُ والبسملةُ قبل السورة لا تُحسبان على الطفل', () {
      final words = wordsOf('ikhlas');
      final heard = 'اعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم ${spoken(words)}';
      expect(alignRecitation(words, heard), everyElement(correct));
    });

    test('كلمةٌ خاطئة حمراء، وما قبلها أخضر، وما بعد ما بلغه بلا لون', () {
      final words = wordsOf('ikhlas'); // قل هو الله أحد | الله الصمد | ...
      final status = alignRecitation(words, 'قل هو الله واحد الله الصمد');
      expect(status.sublist(0, 6), [correct, correct, correct, wrong, correct, correct]);
      expect(status.sublist(6), everyElement(pending));
    });

    test('كلمةٌ تخطّاها حمراء', () {
      final words = wordsOf('kawthar'); // انا اعطيناك الكوثر ...
      final status = alignRecitation(words, 'انا الكوثر فصل لربك');
      expect(status.sublist(0, 5), [correct, wrong, correct, correct, correct]);
    });

    test('خطأُ حرفٍ من محرّك التعرّف في كلمةٍ طويلة يُقبل، وفي كلمةٍ من حرفين لا', () {
      expect(quranWordMatches('المستقيم', 'الْمُسْتَقِيمَ'), isTrue);
      expect(quranWordMatches('المستقين', 'الْمُسْتَقِيمَ'), isTrue);
      expect(quranWordMatches('لن', 'لَمْ'), isFalse);
      expect(quranWordMatches('إياك', 'إِيَّاكَ'), isTrue);
    });

    test('يعيد الآيةَ التي أخطأها وحدها: تصحّ وتبقى ما قبلها خضراء', () {
      final words = wordsOf('ikhlas');
      var settled = alignRecitation(words, 'قل هو الله احد الله الصمد لم يلد ولن يولد');
      expect(settled[8], wrong); // «ولم» قرأها «ولن»
      final from = settled.indexWhere((s) => s != correct);
      final again = alignRecitation(words, 'لم يلد ولم يولد ولم يكن له كفوا احد', from: from);
      settled = mergeRecitation(settled, again);
      expect(settled, everyElement(correct));
    });

    test('في الكافرون تتكرّر آية: المتابعةُ من حيث توقّف لا من أوّل موضعها', () {
      final words = wordsOf('kafirun');
      final surah = surahOf('kafirun');
      final first = alignRecitation(words, spoken(surah.verses.take(4).expand((v) => v.split(' '))));
      final from = first.indexWhere((s) => s != correct);
      final rest = alignRecitation(words, spoken(surah.verses.skip(4).expand((v) => v.split(' '))), from: from);
      expect(mergeRecitation(first, rest), everyElement(correct));
    });
  });

  group('واجهةُ التسميع', () {
    Future<({List<String> recited, void Function(String) say})> openIkhlas(WidgetTester tester) async {
      final recited = <String>[];
      ValueChanged<String>? heard;
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
            listen: ({required onWords, required onEnd}) async {
              heard = onWords;
              return true;
            },
            stopListening: () async {},
          ),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('quran-surah-ikhlas')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quran-mic')));
      await tester.pump();
      return (recited: recited, say: (String text) => heard!(text));
    }

    testWidgets('السورُ الثماني في القائمة', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: QuranRecitationGame(onRecited: (_) async => null, onBack: () {})),
      ));
      for (final surah in quranSurahs) {
        expect(find.byKey(ValueKey('quran-surah-${surah.id}')), findsOneWidget);
      }
    });

    testWidgets('الكلماتُ تتلوّن وهو يقرأ، والسورةُ كاملةً تُكافأ مرّةً واحدة', (tester) async {
      final session = await openIkhlas(tester);
      final state = tester.state<QuranRecitationGameState>(find.byType(QuranRecitationGame));

      session.say('قل هو الله');
      await tester.pump();
      expect(state.status.take(3), everyElement(correct));
      expect(state.status.skip(3), everyElement(pending));
      expect(state.done, isFalse);

      session.say('قل هو الله واحد');
      await tester.pump();
      expect(state.status[3], wrong);

      session.say('قل هو الله واحد احد الله الصمد لم يلد ولم يولد ولم يكن له كفوا احد');
      await tester.pumpAndSettle();
      expect(state.done, isTrue);
      expect(session.recited, ['ikhlas']);
      expect(find.byKey(const ValueKey('quran-done')), findsOneWidget);
      expect(find.byKey(const ValueKey('quran-gems')), findsOneWidget);

      // كلماتٌ تصل بعد الاكتمال لا تُكافئ مرّةً ثانية.
      session.say('قل هو الله احد');
      await tester.pumpAndSettle();
      expect(session.recited, ['ikhlas']);
    });

    testWidgets('بطاقتُها على الرفّ لدرسها وحده', (tester) async {
      Future<StudyGamesPack> load() async => const StudyGamesPack(lessonId: 'L1', games: []);
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
      expect(find.byType(QuranShelfCard), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quran-shelf-card')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(QuranRecitationGame), findsOneWidget);
    });
  });
}
