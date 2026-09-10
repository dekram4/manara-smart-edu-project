import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/screens/student_endless_reader_screen.dart';

/// The reading challenge builds its puzzles out of whatever text a teacher
/// happened to write into the lesson. That text is not clean — it carries
/// punctuation, numbers, the odd English term, and diacritics — so these
/// cover what the picker does with real material rather than with a tidy
/// word list.
void main() {
  group('picking words out of a lesson', () {
    test('takes Arabic words and drops everything around them', () {
      final words = EndlessReaderWords.fromLesson(
        lessonText: 'الماء، والهواء: عنصران 2 مهمان جدا! water مفيد.',
      );

      expect(words, contains('الماء'));
      expect(words, contains('والهواء'));
      expect(words, contains('عنصران'));
      expect(words, contains('مهمان'));
      // The English word and the digit contribute nothing: a child cannot
      // be asked to spell them with Arabic letter tiles.
      expect(words.every((word) => !word.contains(RegExp('[a-zA-Z0-9]'))), isTrue);
    });

    test('strips the diacritics rather than making tiles of them', () {
      final words = EndlessReaderWords.fromLesson(lessonText: 'الشَّمْسُ مُشْرِقَة');
      // A fatha and a shadda among the letter tiles would be a different,
      // much harder game than the one intended.
      expect(words.every((w) => !w.contains(RegExp(r'[ً-ْـ]'))), isTrue);
      expect(words, contains('الشمس'));
    });

    test('skips words too short or too long to be a fair puzzle', () {
      final words = EndlessReaderWords.fromLesson(
        lessonText: 'في من المستشفيات الكبيرة الاستراتيجيات شمس',
      );
      for (final word in words) {
        expect(word.length, greaterThanOrEqualTo(EndlessReaderWords.minLength));
        expect(word.length, lessThanOrEqualTo(EndlessReaderWords.maxLength));
      }
      expect(words, contains('شمس'));
      expect(words, isNot(contains('في')));
      expect(words, isNot(contains('الاستراتيجيات')));
    });

    test('never repeats a word and never runs away with a long lesson', () {
      final words = EndlessReaderWords.fromLesson(
        lessonText: List.filled(40, 'الماء الهواء التراب').join(' '),
      );
      expect(words.toSet().length, words.length, reason: 'no duplicates');
      expect(words.length, lessThanOrEqualTo(EndlessReaderWords.maxWords));
    });

    test('the lesson title is used, and used first', () {
      final words = EndlessReaderWords.fromLesson(
        lessonName: 'دورة الماء',
        lessonText: 'التبخر والتكاثف',
      );
      expect(words.first, 'دورة');
    });

    test('no text at all is empty rather than a crash', () {
      expect(EndlessReaderWords.fromLesson(), isEmpty);
      expect(EndlessReaderWords.fromLesson(lessonText: '   '), isEmpty);
      expect(EndlessReaderWords.fromLesson(lessonText: '123 !!! abc'), isEmpty);
    });
  });

  group('building a round', () {
    test('blanks scale with the word and stay inside it', () {
      for (final word in ['شمس', 'مدرسة', 'المدرسة']) {
        final blanks = EndlessReaderWords.blanksFor(word, seed: 3);
        expect(blanks, isNotEmpty);
        expect(blanks.length, lessThan(word.length),
            reason: 'a word with every letter missing is not a puzzle');
        for (final index in blanks) {
          expect(index, inInclusiveRange(0, word.length - 1));
        }
        expect(blanks.toSet().length, blanks.length);
      }
    });

    test('the same word blanks the same way twice', () {
      // Otherwise a word is unfair on one visit and trivial on the next.
      expect(
        EndlessReaderWords.blanksFor('مدرسة', seed: 11),
        EndlessReaderWords.blanksFor('مدرسة', seed: 11),
      );
    });

    test('every missing letter is offered, plus decoys', () {
      const word = 'مدرسة';
      final blanks = EndlessReaderWords.blanksFor(word, seed: 5);
      final tiles = EndlessReaderWords.tilesFor(word, blanks, seed: 5);

      // Counted, not just contained: a word needing the same letter twice
      // must be given it twice.
      final needed = <String>[for (final index in blanks) word[index]];
      final pool = [...tiles];
      for (final letter in needed) {
        final at = pool.indexOf(letter);
        expect(at, greaterThanOrEqualTo(0), reason: 'missing tile for $letter');
        pool.removeAt(at);
      }
      expect(pool, isNotEmpty, reason: 'decoys stop winning by elimination');
    });
  });

  group('building sentence rounds', () {
    const lesson = 'الخلية هي أصغر وحدة في الكائن الحي. '
        'تحتوي الخلية على النواة والسيتوبلازم والغشاء. '
        'يقوم الغشاء بحماية محتويات الخلية من الخارج. '
        'قصير.';

    test('splits on sentence marks and skips the ones too short', () {
      final built = EndlessReaderSentences.fromLesson(lessonText: lesson);
      expect(built, isNotEmpty);
      // "قصير." is one word — nothing to read into, so it is not a round.
      for (final sentence in built) {
        final words = '${sentence.before} ${sentence.after}'
            .split(' ')
            .where((w) => w.trim().isNotEmpty)
            .length;
        expect(words + 1, greaterThanOrEqualTo(EndlessReaderSentences.minWords));
      }
    });

    test('the gap is never the first word and never a stop word', () {
      final built = EndlessReaderSentences.fromLesson(lessonText: lesson);
      for (final sentence in built) {
        expect(
          sentence.before.trim(),
          isNotEmpty,
          reason: 'a gap at the very start leaves nothing to read into',
        );
        expect(sentence.answer.length, greaterThanOrEqualTo(3));
        expect(
          const {'من', 'في', 'على', 'هي', 'هو'},
          isNot(contains(sentence.answer)),
        );
      }
    });

    test('the answer is always among the choices, with decoys beside it', () {
      final built = EndlessReaderSentences.fromLesson(lessonText: lesson);
      for (final sentence in built) {
        expect(sentence.choices, contains(sentence.answer));
        expect(
          sentence.choices.length,
          greaterThan(1),
          reason: 'one option is not a choice',
        );
        expect(sentence.choices.toSet().length, sentence.choices.length);
      }
    });

    test('no text, or text with no usable sentence, is empty not a crash', () {
      expect(EndlessReaderSentences.fromLesson(), isEmpty);
      expect(EndlessReaderSentences.fromLesson(lessonText: '   '), isEmpty);
      expect(EndlessReaderSentences.fromLesson(lessonText: 'كلمة.'), isEmpty);
    });

    test('a word is never blanked twice across the round', () {
      final built = EndlessReaderSentences.fromLesson(lessonText: lesson);
      final answers = built.map((s) => s.answer).toList();
      expect(answers.toSet().length, answers.length);
    });
  });
}
