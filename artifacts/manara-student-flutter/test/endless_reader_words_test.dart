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

  group('reading the teacher\'s groups', () {
    const grouped = '''
الكائنات الحية: النبات، الحيوان، الإنسان
الجمادات: الحجر، الماء، الهواء
''';

    test('reads the groups and their members straight off the lesson', () {
      final sorting = LessonGroupings.fromLesson(lessonText: grouped);

      expect(sorting, isNotNull);
      expect(sorting!.buckets, containsAll(['الكائنات الحية', 'الجمادات']));
      expect(sorting.items['النبات'], 'الكائنات الحية');
      expect(sorting.items['الحجر'], 'الجمادات');
    });

    test('invents nothing when the lesson names no groups', () {
      // The whole point of the rewrite: prose about science is not a
      // classification, and guessing one would be a confident wrong
      // answer rather than a missing round.
      final sorting = LessonGroupings.fromLesson(
        lessonText: 'الماء مادة مهمة للحياة. النبات يحتاج الماء والضوء.',
      );
      expect(sorting, isNull);
    });

    test('one group is a titled list, not a classification', () {
      final sorting = LessonGroupings.fromLesson(
        lessonText: 'الكائنات الحية: النبات، الحيوان، الإنسان',
      );
      expect(sorting, isNull);
    });

    test('an item listed under two groups is dropped, not guessed at', () {
      final sorting = LessonGroupings.fromLesson(
        lessonText: '''
الأولى: الماء، النبات، الهواء
الثانية: الماء، الحجر، التراب
''',
      );
      // "الماء" cannot be sorted into one bucket, so it is not offered.
      expect(sorting, isNotNull);
      expect(sorting!.items.containsKey('الماء'), isFalse);
      expect(sorting.items['النبات'], 'الأولى');
      expect(sorting.items['الحجر'], 'الثانية');
    });
  });

  group('reading the teacher\'s definitions', () {
    const defined = '''
الخلية هي وحدة البناء الأساسية في الكائن الحي.
المادة هي كل ما له كتلة ويشغل حيزا من الفراغ.
الطاقة هي القدرة على إنجاز شغل ما.
الذرة هي أصغر جزء في العنصر الكيميائي.
''';

    test('pulls term and meaning out of the lesson\'s own sentences', () {
      final pairs = LessonDefinitions.fromLesson(lessonText: defined);

      expect(pairs.length, greaterThanOrEqualTo(3));
      final terms = pairs.map((pair) => pair.term).toList();
      expect(terms, contains('الخلية'));
      expect(
        pairs.firstWhere((pair) => pair.term == 'الخلية').meaning,
        contains('وحدة البناء'),
      );
    });

    test('a lesson with too few definitions yields no round at all', () {
      final pairs = LessonDefinitions.fromLesson(
        lessonText: 'الخلية هي وحدة البناء الأساسية في الكائن الحي.',
      );
      expect(pairs, isEmpty);
    });

    test('a comma list after a colon is a group, not a definition', () {
      // Otherwise the same line would be mined twice and the student
      // would meet it as both a classification and a match.
      final pairs = LessonDefinitions.fromLesson(
        lessonText: '''
الكائنات الحية: النبات، الحيوان، الإنسان
الجمادات: الحجر، الماء، الهواء
المعادن: الحديد، النحاس، الذهب
''',
      );
      expect(pairs, isEmpty);
    });
  });

  group('dealing a challenge run', () {
    /// A lesson with enough of all three kinds to fill a full run.
    const rich = '''
الخلية هي وحدة البناء الأساسية في الكائن الحي.
المادة هي كل ما له كتلة ويشغل حيزا من الفراغ.
الطاقة هي القدرة على إنجاز شغل ما.
الذرة هي أصغر جزء في العنصر الكيميائي.
النبات يصنع غذاءه بنفسه عن طريق عملية البناء الضوئي.
الحيوانات تحتاج إلى الغذاء والماء والهواء لكي تعيش.
الشمس هي المصدر الرئيسي للطاقة على سطح الأرض.
الماء يتكون من ذرتي هيدروجين وذرة أكسجين واحدة.
الكائنات الحية: النبات، الحيوان، الإنسان، الفطريات
الجمادات: الحجر، الماء، الهواء، التراب
''';

    test('a rich lesson fills a full ten-question run', () {
      final plan = ChallengeSession.build(lessonText: rich, seed: 1);
      expect(plan.length, ChallengeSession.questionCount);
    });

    test('the run mixes the kinds rather than blocking them', () {
      final plan = ChallengeSession.build(lessonText: rich, seed: 7);
      final kinds = plan.map((round) => round.runtimeType).toSet();
      expect(kinds.length, greaterThan(1));
    });

    test('a different seed deals a different run', () {
      // This is what "إعادة التحدي" has to deliver: another go at the
      // material, not the same ten screens again.
      String shape(List<ChallengeRound> plan) => plan
          .map((round) => switch (round) {
                FillRound(:final sentence) => 'fill:${sentence.answer}',
                ClassifyRound(:final sorting) =>
                  'sort:${(sorting.items.keys.toList()..sort()).join(",")}',
                MatchRound(:final pairs) =>
                  'match:${(pairs.map((p) => p.term).toList()..sort()).join(",")}',
              })
          .join('|');

      final first = shape(ChallengeSession.build(lessonText: rich, seed: 11));
      final second = shape(ChallengeSession.build(lessonText: rich, seed: 12));
      expect(first, isNot(second));
    });

    test('the same seed deals the same run', () {
      // Determinism per seed is what makes the difference above a real
      // signal rather than two coin flips that happened to disagree.
      final a = ChallengeSession.build(lessonText: rich, seed: 99);
      final b = ChallengeSession.build(lessonText: rich, seed: 99);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].runtimeType, b[i].runtimeType);
      }
    });

    test('a thin lesson gives a short honest run, never a padded one', () {
      final plan = ChallengeSession.build(
        lessonText:
            'الماء مادة مهمة جدا للحياة على سطح الأرض ولكل الكائنات الحية.',
        seed: 3,
      );
      expect(plan.length, lessThan(ChallengeSession.questionCount));
    });

    test('no lesson text is an empty run rather than a crash', () {
      expect(ChallengeSession.build(lessonText: null, seed: 1), isEmpty);
      expect(ChallengeSession.build(lessonText: '   ', seed: 1), isEmpty);
    });

    test('every classify round it deals can actually be completed', () {
      // A board missing a whole bucket has no valid finishing move, which
      // would strand a child on question seven of ten.
      final plan = ChallengeSession.build(lessonText: rich, seed: 5);
      for (final round in plan.whereType<ClassifyRound>()) {
        expect(round.sorting.items, isNotEmpty);
        expect(
          round.sorting.items.values.toSet().length,
          round.sorting.buckets.length,
        );
      }
    });
  });
}
