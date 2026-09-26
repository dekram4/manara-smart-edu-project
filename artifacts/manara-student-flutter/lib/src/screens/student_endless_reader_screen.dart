import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/academic_context.dart';
import '../services/student_challenge_service.dart';
import '../services/student_settings.dart';
import '../l10n/student_strings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import '../widgets/portal_watermark.dart';
import '../widgets/student_experience.dart';

/// Pulls the words a round is played with out of the lesson the student
/// currently has open.
///
/// Kept separate from the screen and free of Flutter so it can be tested
/// directly: the picking rules below are the part most likely to be wrong
/// on real lesson text, and they are not something a widget test would
/// show clearly.
class EndlessReaderWords {
  const EndlessReaderWords._();

  /// Arabic letters that never join to the letter after them. A word
  /// containing one still reads correctly when its letters are shown
  /// separately, which is what this game does — so these are not a
  /// problem, they are simply the reason the game shows isolated forms
  /// and does not try to reproduce joined script in the slots.
  static const _nonJoining = 'اأإآدذرزوؤى';

  /// Words too short to be a puzzle or too long to fit a row of slots on
  /// a phone. Three to seven letters is what a row can show at a size a
  /// child can actually hit with a finger.
  static const minLength = 3;
  static const maxLength = 7;

  /// The most words one visit will play through before repeating.
  static const maxWords = 12;

  /// Extracts playable words from a lesson's own text and title.
  ///
  /// Everything that is not an Arabic letter is a separator — digits,
  /// Latin script, punctuation, tatweel — so a lesson that mixes a
  /// formula or an English term into its text contributes its Arabic
  /// words and quietly drops the rest rather than producing a puzzle of
  /// symbols no child can spell.
  static List<String> fromLesson({
    String? lessonText,
    String? lessonName,
    int? minLengthOverride,
    int? maxLengthOverride,
    int? limit,
  }) {
    final low = minLengthOverride ?? minLength;
    final high = maxLengthOverride ?? maxLength;
    final cap = limit ?? maxWords;
    final seen = <String>{};
    final words = <String>[];

    for (final source in [lessonName, lessonText]) {
      if (source == null || source.trim().isEmpty) continue;
      // Diacritics are stripped from the whole text *before* it is split,
      // not from each word after. They fall outside the letter range that
      // defines a word here, so vowelled text — which is exactly how a
      // lesson for young readers is written — would otherwise break at
      // every fatha: "الشَّمْسُ" split into "الش", "م", "س".
      for (final raw in _strip(source).split(RegExp(r'[^ء-غف-ي]+'))) {
        final word = raw.trim();
        if (word.length < low || word.length > high) continue;
        if (!seen.add(word)) continue;
        words.add(word);
        if (words.length >= cap) return words;
      }
    }
    return words;
  }

  /// Drops the diacritics a child is not asked to place, and the tatweel
  /// used only to stretch a word visually. Leaving them in would put a
  /// fatha and a shadda among the letter tiles, which is a different and
  /// much harder game than the one intended here.
  static String _strip(String value) =>
      value.replaceAll(RegExp(r'[ً-ْـٰ]'), '');

  /// Which positions in [word] are blanked out for the student to fill.
  ///
  /// Scales with length so a three-letter word is not almost entirely
  /// missing while a seven-letter one gives away all but one letter, and
  /// it is deterministic in [seed] so a word plays the same way twice
  /// rather than being unfair once and trivial the next time.
  static List<int> blanksFor(String word, {required int seed}) {
    if (word.length < minLength) return const [];
    final count = math.max(1, (word.length / 3).floor());
    final positions = List<int>.generate(word.length, (index) => index)
      ..shuffle(math.Random(seed));
    final chosen = positions.take(count).toList()..sort();
    return chosen;
  }

  /// The tiles offered for a round: every missing letter, plus a few
  /// decoys drawn from the word's own other letters so a student cannot
  /// win by elimination alone.
  static List<String> tilesFor(
    String word,
    List<int> blanks, {
    required int seed,
  }) {
    final needed = blanks.map((index) => word[index]).toList();
    final decoys = <String>[];
    for (var index = 0; index < word.length; index++) {
      if (blanks.contains(index)) continue;
      decoys.add(word[index]);
    }
    decoys.shuffle(math.Random(seed + 1));
    final tiles = [...needed, ...decoys.take(math.max(1, needed.length))];
    tiles.shuffle(math.Random(seed + 2));
    return tiles;
  }

  /// Whether [letter] is one that never joins forward. Exposed so the
  /// screen can be honest about why it renders letters in isolation.
  static bool isNonJoining(String letter) => _nonJoining.contains(letter);
}

/// A sorting round: words from the lesson, and the two buckets they
/// belong in.
class EndlessReaderSorting {
  const EndlessReaderSorting({
    required this.prompt,
    required this.buckets,
    required this.items,
  });

  /// What the student is being asked to do, in words.
  final String prompt;

  /// The bucket labels, in display order.
  final List<String> buckets;

  /// Each word and the bucket it belongs to.
  final Map<String, String> items;
}

/// Builds the classification round out of the groups the teacher wrote.
///
/// This replaced a grammar round — singular against plural — which was
/// honest about Arabic but had nothing to do with science, and asked a
/// question the lesson never posed. The rule now is that the app invents
/// no categories of its own: a classification round exists only when the
/// lesson text itself names groups and lists what is in them. If the
/// teacher did not write groups, there is no round, and the challenge
/// runs the other two. Guessing "living/non-living" from bare prose is
/// exactly the sort of confident wrong answer this avoids.
///
/// The shape it reads is the one science lessons are written in:
///
///   الكائنات الحية: النبات، الحيوان، الإنسان
///   الجمادات: الحجر، الماء، الهواء
///
/// A heading, a colon, then the members separated by commas or "و".
class LessonGroupings {
  const LessonGroupings._();

  /// A round needs at least this many groups, and this many members in
  /// each, or it is not a classification — it is a list with a title.
  static const minGroups = 2;
  static const minItemsPerGroup = 2;

  /// Caps, so one long lesson cannot produce a board a child scrolls.
  static const maxGroups = 3;
  static const maxItemsPerGroup = 4;

  /// A group label longer than this is a sentence that happens to contain
  /// a colon, not a heading.
  static const maxLabelWords = 4;

  /// A member longer than this is a clause, not a thing being classified.
  static const maxItemWords = 3;

  static EndlessReaderSorting? fromLesson({String? lessonText}) {
    final text = lessonText?.trim() ?? '';
    if (text.isEmpty) return null;

    final groups = <String, List<String>>{};
    for (final line in text.split(RegExp(r'[\n\r]+'))) {
      final parsed = _parseLine(line);
      if (parsed == null) continue;
      // First writing wins: a teacher who repeats a heading later in the
      // lesson is elaborating, not redefining.
      groups.putIfAbsent(parsed.$1, () => parsed.$2);
      if (groups.length >= maxGroups) break;
    }

    if (groups.length < minGroups) return null;

    // A word listed under two headings cannot be sorted into one bucket,
    // so it is dropped rather than being marked wrong wherever it lands.
    final seen = <String>{};
    final duplicates = <String>{};
    for (final members in groups.values) {
      for (final item in members) {
        if (!seen.add(item)) duplicates.add(item);
      }
    }

    final items = <String, String>{};
    for (final entry in groups.entries) {
      final usable =
          entry.value.where((item) => !duplicates.contains(item)).toList();
      if (usable.length < minItemsPerGroup) return null;
      for (final item in usable.take(maxItemsPerGroup)) {
        items[item] = entry.key;
      }
    }

    return EndlessReaderSorting(
      prompt: tr('challenge.classifyPrompt'),
      buckets: groups.keys.toList(),
      items: items,
    );
  }

  /// `(label, members)` for a line that names a group, or null.
  static (String, List<String>)? _parseLine(String line) {
    final clean = line.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return null;

    final colon = clean.indexOf(RegExp('[:：]'));
    if (colon <= 0 || colon >= clean.length - 1) return null;

    final label = _strip(clean.substring(0, colon));
    if (label.isEmpty || _wordCount(label) > maxLabelWords) return null;

    // Commas, Arabic commas, and a standalone "و" all separate members
    // in the way these lessons are written.
    final members = clean
        .substring(colon + 1)
        .split(RegExp(r'[،,؛;]| و '))
        .map(_strip)
        .where((item) => item.isNotEmpty && _wordCount(item) <= maxItemWords)
        .toList();

    // De-duplicated within the line, because "الماء، الماء" is a typo and
    // two identical tiles cannot both be dragged.
    final unique = <String>[];
    for (final item in members) {
      if (!unique.contains(item)) unique.add(item);
    }
    if (unique.length < minItemsPerGroup) return null;
    return (label, unique);
  }

  static int _wordCount(String value) =>
      value.split(' ').where((part) => part.isNotEmpty).length;

  /// Trailing punctuation and the leading conjunction a list picks up.
  static String _strip(String value) => value
      .replaceAll(RegExp(r'^[\s\-–—•*]+'), '')
      .replaceAll(RegExp(r'[\s.،,؛;:]+$'), '')
      .trim();
}

/// One term from the lesson and what the lesson says it is.
class LessonDefinition {
  const LessonDefinition({required this.term, required this.meaning});

  /// The scientific term — what the student drags.
  final String term;

  /// The teacher's own wording of what it means — the card it lands on.
  final String meaning;
}

/// Builds the concept-matching round out of the lesson's own definitions.
///
/// Like the classification round, this invents nothing: it pulls pairs
/// only where the teacher actually wrote a definition, in one of the two
/// shapes these lessons use — "الخلية هي وحدة بناء الكائن الحي", or a
/// heading and a colon. A lesson with no definitions yields no round.
class LessonDefinitions {
  const LessonDefinitions._();

  /// Three pairs is a match; two is a coin toss and four is a wall of
  /// text on a phone.
  static const minPairs = 3;
  static const maxPairs = 4;

  /// A term longer than this is a clause; a meaning shorter than this is
  /// a label, and matching labels to labels teaches nothing.
  static const maxTermWords = 4;
  static const minMeaningWords = 2;
  static const maxMeaningWords = 12;

  /// The copulas that mark "X is Y" in the prose these lessons are
  /// written in. Order matters: the longer forms are tried first so
  /// "يُعرَّف ... بأنه" is not cut short by a bare "هو" inside it.
  static const _copulas = ['بأنها', 'بأنه', 'تعني', 'يعني', 'هي', 'هو'];

  static List<LessonDefinition> fromLesson({String? lessonText}) {
    final text = lessonText?.trim() ?? '';
    if (text.isEmpty) return const [];

    final pairs = <LessonDefinition>[];
    final usedTerms = <String>{};

    for (final piece in text.split(RegExp(r'[.!?؟\n\r]+'))) {
      final sentence = piece.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (sentence.isEmpty) continue;

      final pair = _parse(sentence);
      if (pair == null) continue;
      if (!usedTerms.add(pair.term)) continue;
      pairs.add(pair);
      if (pairs.length >= maxPairs) break;
    }

    return pairs.length >= minPairs ? pairs : const [];
  }

  static LessonDefinition? _parse(String sentence) {
    for (final copula in _copulas) {
      final at = sentence.indexOf(' $copula ');
      if (at <= 0) continue;
      final term = _strip(sentence.substring(0, at));
      final meaning = _strip(sentence.substring(at + copula.length + 2));
      if (_fits(term, meaning)) {
        return LessonDefinition(term: term, meaning: meaning);
      }
    }

    // A colon line is a definition only when what follows is prose. A
    // comma list after a colon is a classification, and belongs to the
    // other round rather than to this one.
    final colon = sentence.indexOf(RegExp('[:：]'));
    if (colon > 0 && colon < sentence.length - 1) {
      final term = _strip(sentence.substring(0, colon));
      final meaning = _strip(sentence.substring(colon + 1));
      if (!meaning.contains(RegExp(r'[،,؛;]')) && _fits(term, meaning)) {
        return LessonDefinition(term: term, meaning: meaning);
      }
    }
    return null;
  }

  static bool _fits(String term, String meaning) {
    if (term.isEmpty || meaning.isEmpty) return false;
    final termWords = _wordCount(term);
    final meaningWords = _wordCount(meaning);
    return termWords >= 1 &&
        termWords <= maxTermWords &&
        meaningWords >= minMeaningWords &&
        meaningWords <= maxMeaningWords;
  }

  static int _wordCount(String value) =>
      value.split(' ').where((part) => part.isNotEmpty).length;

  static String _strip(String value) => value
      .replaceAll(RegExp(r'^[\s\-–—•*]+'), '')
      .replaceAll(RegExp(r'[\s.،,؛;:]+$'), '')
      .trim();
}

/// One question in a challenge run.
///
/// The run used to be index arithmetic over three fixed blocks, which is
/// why adding a round meant rewriting the offsets in five getters. A run
/// is now a plain list of these, built up front: the screen asks what
/// round it is on rather than working it out.
sealed class ChallengeRound {
  const ChallengeRound();
}

/// Complete the teacher's own sentence with the term taken out of it.
class FillRound extends ChallengeRound {
  const FillRound(this.sentence);
  final EndlessReaderSentence sentence;
}

/// Drag each item into the group the lesson put it in.
class ClassifyRound extends ChallengeRound {
  const ClassifyRound(this.sorting);
  final EndlessReaderSorting sorting;
}

/// Drag each term onto the teacher's definition of it.
class MatchRound extends ChallengeRound {
  const MatchRound(this.pairs);
  final List<LessonDefinition> pairs;
}

/// يحوّل جولةً جاءت من الخادم إلى جولةٍ تعرفها هذه الشاشة.
///
/// الأنواع الثلاثة هي أنواعُها نفسها، فلا ويدجت جديدة: ما يتغيّر مصدرُ
/// الجولة لا شكلُها. كانت تُقتطع من نصّ الدرس بقواعدَ تعمل على الجهاز،
/// وصارت تُولَّد منه بالذكاء الاصطناعي وتُحفظ في بنكٍ مع الدرس.
ChallengeRound? roundFromRemote(RemoteRound remote, math.Random rng) {
  switch (remote) {
    case RemoteFill():
      // الجواب مع مشتّتاته، مخلوطين — ولولا الخلط لكان في أوّل الصفّ
      // دائماً.
      final choices = [remote.answer, ...remote.distractors]..shuffle(rng);
      return FillRound(EndlessReaderSentence(
        before: remote.before,
        after: remote.after,
        answer: remote.answer,
        choices: choices,
      ));
    case RemoteClassify():
      return ClassifyRound(EndlessReaderSorting(
        prompt: remote.prompt.isEmpty
            ? tr('challenge.classifyPrompt')
            : remote.prompt,
        buckets: remote.buckets,
        items: remote.items,
      ));
    case RemoteMatch():
      return MatchRound([
        for (final pair in remote.pairs)
          LessonDefinition(term: pair.term, meaning: pair.meaning),
      ]);
  }
}

/// Builds one run of the challenge from the current lesson.
///
/// Two things matter here and neither was true before. A run is a fixed
/// length, so a child can see the end of it. And a run is *sampled*: the
/// lesson's sentences, groups and definitions are a bank, and each visit
/// draws a different hand from it, in a different order, with the choices
/// shuffled — so replaying is another go at the material rather than the
/// same ten screens again.
///
/// When the lesson cannot fill ten, the run is honestly shorter rather
/// than padded with invented questions.
class ChallengeSession {
  const ChallengeSession._();

  /// The length of a full run.
  static const questionCount = 10;

  static List<ChallengeRound> build({
    required String? lessonText,
    required int seed,
  }) {
    final rng = math.Random(seed);

    // Every sentence the lesson can yield, not the two the run will use
    // — the surplus is exactly what makes the next attempt different.
    // Copied before shuffling: the builder returns a `const []` when the
    // lesson has no usable sentence, and a const list cannot be shuffled
    // in place.
    final sentences = [
      ...EndlessReaderSentences.fromLesson(
        lessonText: lessonText,
        random: rng,
      ),
    ]..shuffle(rng);

    final grouping = LessonGroupings.fromLesson(lessonText: lessonText);
    final definitions = LessonDefinitions.fromLesson(lessonText: lessonText);

    // Each pool is turned into whole rounds first, then the rounds are
    // interleaved. Interleaving the kinds rather than blocking them means
    // a child is not asked the same thing five times running.
    final fills = <ChallengeRound>[
      for (final sentence in sentences) FillRound(sentence),
    ];
    final classifies = _classifyRounds(grouping, rng);
    final matches = _matchRounds(definitions, rng);

    final plan = <ChallengeRound>[];
    final pools = [fills, classifies, matches]
        .where((pool) => pool.isNotEmpty)
        .toList()
      ..shuffle(rng);
    if (pools.isEmpty) return const [];

    // Round-robin across whatever pools have material left, so the mix
    // stays varied right to the end of a run instead of degenerating into
    // whichever pool is deepest.
    var cursor = 0;
    while (plan.length < questionCount && pools.isNotEmpty) {
      final pool = pools[cursor % pools.length];
      plan.add(pool.removeAt(0));
      if (pool.isEmpty) {
        pools.remove(pool);
      } else {
        cursor++;
      }
    }
    return plan;
  }

  /// Classification rounds, each a different hand of items from the same
  /// groups. One board per pass through the lesson's items, so a lesson
  /// naming six creatures gives more than a single round.
  static List<ChallengeRound> _classifyRounds(
    EndlessReaderSorting? grouping,
    math.Random rng,
  ) {
    if (grouping == null) return const [];

    // Back to the items grouped by bucket, so each generated board can
    // take a different slice while still holding every bucket.
    final byBucket = <String, List<String>>{
      for (final bucket in grouping.buckets) bucket: <String>[],
    };
    for (final entry in grouping.items.entries) {
      byBucket[entry.value]?.add(entry.key);
    }
    for (final items in byBucket.values) {
      items.shuffle(rng);
    }

    const perBucket = 2;
    final deepest = byBucket.values
        .map((items) => items.length ~/ perBucket)
        .fold<int>(0, math.max);

    final rounds = <ChallengeRound>[];
    for (var pass = 0; pass < deepest; pass++) {
      final items = <String, String>{};
      for (final entry in byBucket.entries) {
        final slice = entry.value.skip(pass * perBucket).take(perBucket);
        for (final item in slice) {
          items[item] = entry.key;
        }
      }
      // A board missing a whole bucket cannot be completed, so the pass
      // that runs out ends the sequence rather than shipping a broken one.
      final covered = items.values.toSet();
      if (covered.length < grouping.buckets.length) break;
      rounds.add(
        ClassifyRound(
          EndlessReaderSorting(
            prompt: grouping.prompt,
            buckets: grouping.buckets,
            items: items,
          ),
        ),
      );
    }
    return rounds;
  }

  /// Matching rounds, each on a different set of the lesson's pairs.
  static List<ChallengeRound> _matchRounds(
    List<LessonDefinition> definitions,
    math.Random rng,
  ) {
    if (definitions.length < LessonDefinitions.minPairs) return const [];
    final shuffled = [...definitions]..shuffle(rng);

    const perRound = LessonDefinitions.minPairs;
    final rounds = <ChallengeRound>[];
    for (var at = 0; at + perRound <= shuffled.length; at += perRound) {
      rounds.add(MatchRound(shuffled.sublist(at, at + perRound)));
    }
    // A tail too short for its own round still makes one when it can
    // borrow from the front — the pairs differ from the round that used
    // them because the partners around them do.
    final remainder = shuffled.length % perRound;
    if (remainder > 0 && shuffled.length > perRound) {
      final tail = shuffled.sublist(shuffled.length - perRound);
      rounds.add(MatchRound(tail));
    }
    return rounds;
  }
}

/// One sentence from the lesson with a single word taken out of it, for
/// the second kind of challenge: reading a real definition and choosing
/// the word that completes it.
class EndlessReaderSentence {
  const EndlessReaderSentence({
    required this.before,
    required this.answer,
    required this.after,
    required this.choices,
  });

  /// The sentence text either side of the gap.
  final String before;
  final String after;

  /// The word that was removed.
  final String answer;

  /// The answer plus decoys, already shuffled.
  final List<String> choices;
}

/// Builds sentence-completion rounds out of a lesson's own prose.
///
/// This is the half of the game that teaches the concept rather than the
/// spelling: the sentences are the teacher's own definitions, and the
/// word removed is a content word from within them, so completing one
/// means having read and understood the line.
class EndlessReaderSentences {
  const EndlessReaderSentences._();

  /// The shortest and longest sentence worth showing. Under five words
  /// there is not enough context to work the gap out; over eighteen it
  /// stops being a puzzle and becomes a paragraph.
  static const minWords = 5;
  static const maxWords = 18;

  /// The size of the sentence bank, not the length of a run.
  ///
  /// A run plays a handful of these; the rest is the surplus a retry
  /// draws a different hand from. Capped so a very long lesson does not
  /// spend the frame budget building sentences nobody will reach.
  static const maxSentences = 24;

  /// Words never chosen as the missing one: they carry no meaning on
  /// their own, so blanking them tests nothing.
  static const _stopWords = <String>{
    'من', 'في', 'على', 'إلى', 'عن', 'هي', 'هو', 'التي', 'الذي', 'هذا',
    'هذه', 'ذلك', 'تلك', 'كان', 'كانت', 'مع', 'أو', 'ثم', 'قد', 'بين',
    'كل', 'عند', 'حتى', 'لكن', 'أن', 'إن', 'لا', 'ما', 'كما', 'وهي',
    'وهو', 'يتم', 'يكون', 'تكون',
  };

  static List<EndlessReaderSentence> fromLesson({
    String? lessonText,
    math.Random? random,
  }) {
    final text = lessonText?.trim() ?? '';
    if (text.isEmpty) return const [];
    final rng = random ?? math.Random(text.length);

    // Split on the marks that actually end a sentence in Arabic prose,
    // including the Arabic full stop and question mark.
    final raw = text.split(RegExp(r'[.!?؟\n\r]+'));
    final built = <EndlessReaderSentence>[];
    final usedAnswers = <String>{};

    for (final piece in raw) {
      final sentence = piece.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (sentence.isEmpty) continue;
      final words = sentence.split(' ').where((w) => w.isNotEmpty).toList();
      if (words.length < minWords || words.length > maxWords) continue;

      // Candidates are content words long enough to be worth removing,
      // and never the first word — a gap at the very start leaves the
      // student nothing to read into.
      final candidates = <int>[];
      for (var i = 1; i < words.length; i++) {
        final clean = _clean(words[i]);
        if (clean.length < 3) continue;
        if (_stopWords.contains(clean)) continue;
        if (usedAnswers.contains(clean)) continue;
        candidates.add(i);
      }
      if (candidates.isEmpty) continue;

      final at = candidates[rng.nextInt(candidates.length)];
      final answer = _clean(words[at]);
      usedAnswers.add(answer);

      built.add(
        EndlessReaderSentence(
          before: words.sublist(0, at).join(' '),
          answer: answer,
          after: words.sublist(at + 1).join(' '),
          choices: const [],
        ),
      );
      if (built.length >= maxSentences) break;
    }

    // Decoys are drawn from the other sentences' answers, so every option
    // is a real word from this lesson. A decoy pulled from nowhere would
    // stand out as obviously wrong without the student reading anything.
    final pool = built.map((s) => s.answer).toList();
    return [
      for (final sentence in built)
        EndlessReaderSentence(
          before: sentence.before,
          answer: sentence.answer,
          after: sentence.after,
          choices: _choicesFor(sentence.answer, pool, rng),
        ),
    ];
  }

  static List<String> _choicesFor(
    String answer,
    List<String> pool,
    math.Random rng,
  ) {
    final decoys = pool.where((word) => word != answer).toList()..shuffle(rng);
    final choices = <String>[answer, ...decoys.take(3)];
    choices.shuffle(rng);
    return choices;
  }

  /// Strips the punctuation clinging to a word and the diacritics inside
  /// it, so the tile a student drags matches the gap it belongs in.
  static String _clean(String value) => value
      .replaceAll(RegExp(r'[ً-ْـٰ]'), '')
      .replaceAll(RegExp(r'[^ء-غف-ي]'), '')
      .trim();
}

/// "تحدي القراءة والكلمات" — the student rebuilds words from their own
/// current lesson by dragging the missing letters into place.
class StudentEndlessReaderScreen extends StatefulWidget {
  const StudentEndlessReaderScreen({
    required this.academicContext,
    this.challengeService,
    super.key,
  });

  final AcademicContext? academicContext;

  /// مولّد أسئلة الجولة. غيابه يعني لعبةً بالجولات الثلاث وحدها — وهو
  /// ما يجري في الاختبارات وفي أي مسارٍ لا يملك جلسةً للخادم.
  final StudentChallengeService? challengeService;

  @override
  State<StudentEndlessReaderScreen> createState() =>
      _StudentEndlessReaderScreenState();
}

class _StudentEndlessReaderScreenState
    extends State<StudentEndlessReaderScreen> {
  late final ConfettiController _confetti;

  /// The ten questions of this run, drawn when the screen opens and drawn
  /// again — differently — on every retry.
  ///
  /// Three kinds of science round, all built from the lesson the teacher
  /// wrote: complete the term inside their own sentence, sort the items
  /// into the groups they named, match each term to their definition of
  /// it.
  ///
  /// The letter-dragging round this used to open with is gone. Spelling a
  /// word out of loose letters is a reading exercise, not a science one,
  /// and it was the easiest thing on the screen by a distance. The
  /// grammar sort — singular against plural — went with it for the same
  /// reason: a true statement about Arabic that the science lesson had
  /// never asked.
  List<ChallengeRound> _plan = const [];

  /// Changed on every retry so the next run samples a different hand.
  int _seed = DateTime.now().microsecondsSinceEpoch;

  /// أسئلة الخادم لهذه الجولة، وحالةُ جلبها.
  ///
  /// الجلب لا يوقف اللعب: تُبنى الجولات الثلاث فوراً ويبدأ الطفل، فإذا
  /// وصلت الأسئلة أُعيد بناء الخطة بها. وانتظارُ الشبكة قبل عرض شيءٍ
  /// يجعل بطاقةً تُفتح بضغطة تبدو معطّلةً عشر ثوانٍ.
  List<RemoteRound> _generated = const [];
  bool _fetching = false;

  /// سببُ تعذّر التوليد، إن تعذّر.
  ///
  /// كان الفشل صامتاً وتُعرض جولاتُ الجهاز مكانه. وهي جولاتٌ تُقتطع من
  /// شكل الجملة لا من معناها — «طابق» و«صنّف» — فيظنّ الناظر أن هذا هو
  /// التحدي، ويشكو من سطحيّته. فصار يُقال ما جرى.
  String? _failure;

  /// يزيد مع كل توزيع، فتُهمل نتيجةُ جلبٍ سبقه.
  int _dealToken = 0;


  ChallengeRound? get _round =>
      _wordIndex < _plan.length ? _plan[_wordIndex] : null;

  bool get _onSorting => _round is ClassifyRound;
  bool get _onMatching => _round is MatchRound;
  EndlessReaderSentence get _sentence => (_round as FillRound).sentence;
  EndlessReaderSorting? get _sorting =>
      _round is ClassifyRound ? (_round! as ClassifyRound).sorting : null;
  List<LessonDefinition> get _pairs =>
      _round is MatchRound ? (_round! as MatchRound).pairs : const [];

  /// The definitions of the current matching round in the order they are
  /// shown — shuffled, so the answer is never the card opposite.
  List<LessonDefinition> _meaningOrder = const [];

  /// Which bucket each classified item has been dropped into so far.
  final Map<String, String> _sorted = {};

  /// Which term has been matched to its definition so far.
  final Map<String, String> _matched = {};

  /// The word dropped into the sentence gap, once one has been.
  String? _filled;

  var _wordIndex = 0;

  /// How many rounds this run holds, so the student can see the end of it
  /// rather than playing an unmarked stream.
  int get _stageCount => _plan.length;
  bool get _onLastStage => _wordIndex >= _stageCount - 1;

  /// Set while the finished-round celebration is on screen, which is also
  /// what stops a second tap racing the next round in.
  bool _celebrating = false;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _deal();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  /// Draws a fresh run. Called on open and on every retry, each time with
  /// a new seed, which is what makes the second attempt a different set of
  /// questions rather than a replay of the first.
  void _deal() {
    // بلا مولّد: الجولات الثلاث كما كانت — وهو ما يجري في الاختبارات
    // وفي أي مسارٍ لا جلسةَ خادمٍ له.
    if (widget.challengeService == null) {
      _plan = ChallengeSession.build(
        lessonText: widget.academicContext?.selectedLesson.lessonText,
        seed: _seed,
      );
      _wordIndex = 0;
      _startRound();
      return;
    }
    // ومعه: جولاتُ بنك الدرس وحدها.
    //
    // لا تُخلط بجولات الجهاز ولا يُرتدّ إليها عند الفشل. جولاتُ البنك
    // مبنيّةٌ على معنى الدرس، وتلك على شكل جملةٍ فيه — وخلطُهما يجعل
    // نصف التحدي سطحياً، والارتدادُ إليها يجعله كلَّه.
    final rng = math.Random(_seed);
    _plan = [
      for (final remote in _generated)
        if (roundFromRemote(remote, rng) case final round?) round,
    ];
    _wordIndex = 0;
    _startRound();
    _fetchGenerated();
  }

  /// يطلب جولةً جديدة من الخادم ويعيد بناء الخطة بها.
  ///
  /// كل توزيعٍ يحمل رقمه، فإن ضغط الطفل «تحدٍّ جديد» قبل وصول الجلب
  /// أُهملت نتيجتُه بدل أن تُقحَم في جولةٍ بدأت بعدها. والفشل صامت:
  /// الجولات الثلاث تكفي لعبةً، وشريطُ خطأٍ فوق لعبةٍ تعمل إزعاجٌ بلا
  /// فائدة.
  Future<void> _fetchGenerated() async {
    final service = widget.challengeService;
    final lesson = widget.academicContext?.selectedLesson;
    final lessonId = lesson?.id ?? '';
    if (service == null) return;

    if (lessonId.isEmpty) {
      setState(() {
        _failure = tr('challenge.emptyNoLesson');
        _fetching = false;
      });
      return;
    }
    // درسٌ بلا نصّ: يُقال صراحةً أن المعلّم لم يضف محتواه، ولا تُولَّد
    // أسئلةٌ من لا شيء — النموذج بلا نصٍّ يسأل من معرفته العامة، فيُخطئ
    // طفلاً على ما لم يُعلَّم.
    if ((lesson?.lessonText ?? '').trim().isEmpty) {
      setState(() {
        _failure = tr('challenge.emptyNoText');
        _fetching = false;
      });
      return;
    }

    final token = ++_dealToken;
    setState(() {
      _fetching = true;
      _failure = null;
    });
    try {
      final rounds = await service.fetchRound(lessonId: lessonId);
      if (!mounted || token != _dealToken) return;
      final rng = math.Random(_seed);
      setState(() {
        _generated = rounds;
        _plan = [
          for (final remote in rounds)
            if (roundFromRemote(remote, rng) case final round?) round,
        ];
        _wordIndex = 0;
        _failure = null;
        _fetching = false;
      });
      _startRound();
    } on ChallengeFailure catch (error) {
      if (!mounted || token != _dealToken) return;
      setState(() {
        _failure = _explain(error.message);
        _fetching = false;
      });
    } catch (_) {
      if (!mounted || token != _dealToken) return;
      setState(() {
        _failure = tr('challenge.error.offline');
        _fetching = false;
      });
    }
  }

  /// رمزُ الفشل بعبارةٍ تُقرأ، أو ما قاله الخادم إن كان كلاماً.
  String _explain(String code) => switch (code) {
        'noService' => tr('challenge.error.noService'),
        'sessionFailed' => tr('challenge.error.noSession'),
        'offline' => tr('challenge.error.offline'),
        'badResponse' || 'serviceSilent' => tr('challenge.error.badResponse'),
        'notDeployed' => tr('challenge.error.notDeployed'),
        'empty' => tr('challenge.error.empty'),
        _ => code,
      };

  void _startRound() {
    _sorted.clear();
    _matched.clear();
    _filled = null;
    _celebrating = false;
    // The definition cards are ordered per round rather than per run, so
    // meeting the same pair again in a later round still reads as a new
    // question.
    final pairs = _pairs;
    _meaningOrder = pairs.isEmpty
        ? const []
        : ([...pairs]..shuffle(math.Random(_seed ^ (_wordIndex + 1) * 7919)));
  }

  /// A word dropped into the sentence gap. Only the right one is ever
  /// accepted, so this always means success.
  void _onSentenceAccept(String word) {
    setState(() => _filled = word);
    HapticFeedback.lightImpact();
    StudentSoundService.instance.play(StudentSoundCue.success);
    _finishWord();
  }

  /// A word dropped into a sorting bucket. Only its own bucket accepts
  /// it, so a wrong drop springs back instead of being marked wrong.
  void _onSortAccept(String word, String bucket) {
    setState(() => _sorted[word] = bucket);
    HapticFeedback.lightImpact();
    StudentSoundService.instance.play(StudentSoundCue.success);
    final sorting = _sorting;
    if (sorting != null && _sorted.length == sorting.items.length) {
      _finishWord();
    }
  }

  /// A term dropped onto a definition card. Only its own card accepts it,
  /// so a wrong drop springs back rather than being marked wrong — the
  /// same rule the other two rounds use.
  void _onMatchAccept(String term, String meaning) {
    setState(() => _matched[term] = meaning);
    HapticFeedback.lightImpact();
    StudentSoundService.instance.play(StudentSoundCue.success);
    if (_matched.length == _pairs.length) _finishWord();
  }

  void _finishWord() {
    setState(() => _celebrating = true);
    if (!(MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      _confetti.play();
    }
    HapticFeedback.mediumImpact();
    StudentSoundService.instance.playApplause();
  }

  void _nextWord() {
    if (!_celebrating || _onLastStage) return;
    StudentSoundService.instance.playTap();
    setState(() {
      _wordIndex++;
      _startRound();
    });
  }

  /// Deals a whole new run. Offered at the end and at any point through
  /// the bar, because a child who wants another go should not have to
  /// leave and come back.
  ///
  /// A new seed, so this is genuinely another set of questions: different
  /// sentences drawn from the bank, different items in the buckets,
  /// different pairs to match, and every list shuffled again. Replaying
  /// the identical ten screens is what this deliberately does not do.
  void _restart() {
    StudentSoundService.instance.playTap();
    setState(() {
      _seed = DateTime.now().microsecondsSinceEpoch ^ (_seed * 31 + 17);
      _deal();
    });
  }

  /// عنوان الشاشة باسم المادة التي اختارها الطالب من المسار.
  ///
  /// كان ثابتاً على «تحدي العلوم»، فيقرؤه طالب الرياضيات على تحدٍّ مبنيّ من
  /// درس الرياضيات نفسه. النص الاحتياطي لا يُستعمل إلا حين لا تكون هناك مادة
  /// مختارة أصلاً — لا كبديل دائم.
  String get _challengeTitle {
    final subject = widget.academicContext?.subject.trim() ?? '';
    return subject.isEmpty
        ? tr('challenge.titleFallback')
        : trf('challenge.title', {'subject': subject});
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Scaffold(
        backgroundColor: StudentSurface.ground(context),
        appBar: AppBar(
          backgroundColor: const Color(0xFF3B2A6B),
          foregroundColor: Colors.white,
          title: Text(_challengeTitle),
          centerTitle: true,
          actions: [
            if (_stageCount > 0)
              IconButton(
                onPressed: _restart,
                tooltip: tr('challenge.replayFromStart'),
                icon: const Icon(Icons.replay_rounded),
              ),
            const StudentSoundToggle(),
          ],
        ),
        body: Stack(
          children: [
            // The portal's own artwork, filling the screen with
            // BoxFit.cover in either orientation — the same treatment
            // every other card gets, at a slightly stronger presence
            // because this screen carries less text to compete with.
            const PortalWatermark(
              asset: PortalBackgrounds.endlessReader,
              opacity: 0.24,
            ),
            SafeArea(
              child: _stageCount > 0
                  ? _game()
                  : _fetching
                      ? _waiting()
                      : _emptyState(),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 18,
                gravity: 0.28,
                shouldLoop: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.menu_book_rounded,
                size: 64,
                color: Color(0xFF6D28D9),
              ),
              const SizedBox(height: 16),
              Text(
                tr('challenge.empty'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: StudentSurface.ink(context),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                // سببُ التعذّر بعينه إن عُرف، لا جملةً عامّة تصلح لكل
                // حال ولا تشرح أيّها وقع.
                _failure ??
                    (widget.academicContext == null
                        ? tr('challenge.emptyNoLesson')
                        : tr('challenge.emptyNoText')),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: StudentSurface.mutedInk(context),
                  height: 1.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_failure != null && widget.challengeService != null) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(tr('challenge.retry')),
                ),
              ],
            ],
          ),
        ),
      );

  /// أثناء انتظار أسئلة الدرس.
  ///
  /// شاشةٌ تقول «لا يوجد تحدٍّ» وهي تنتظر كذبٌ صغير يدفع الطفل إلى
  /// المغادرة قبل أن تصل الأسئلة.
  Widget _waiting() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF6D28D9)),
            const SizedBox(height: 18),
            Text(
              tr('challenge.loadingMore'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: StudentSurface.ink(context),
              ),
            ),
          ],
        ),
      );

  Widget _game() {
    // The whole arena is centred rather than spread to the edges: the
    // question, its pieces and the progress above them read as one panel
    // in the middle of the screen with the artwork around it.
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _progress(),
            // الجلب لا يوقف اللعب، لكنّه يُعلَن: الطفل الذي بدأ بجولةٍ
            // من جولات الجهاز يرى أن أسئلةً في الطريق بدل أن تظهر فجأةً
            // في منتصف اللعب بلا سبب.
            if (_fetching) ...[
              const SizedBox(height: 8),
              Text(
                tr('challenge.loadingMore'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6D28D9),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              _celebrating ? _doneLine() : _promptLine(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _celebrating
                    ? const Color(0xFF15803D)
                    : const Color(0xFF3B2A6B),
              ),
            ),
            const SizedBox(height: 18),
            if (_onSorting)
              _sortingBoard()
            else if (_onMatching)
              _matchingBoard()
            else
              _sentenceCard(),
            const SizedBox(height: 24),
            if (_celebrating)
              _afterWordActions()
            else if (_onSorting)
              _sortingTray()
            else if (_onMatching)
              _matchingTray()
            else
              _choiceTray(),
          ],
        ),
      ),
    );
  }

  String _promptLine() {
    if (_onSorting) return _sorting?.prompt ?? tr('challenge.classifyPrompt');
    if (_onMatching) return tr('challenge.matchPrompt');
    return tr('challenge.dragWord');
  }

  String _doneLine() {
    if (_onSorting) return tr('challenge.sortDone');
    if (_onMatching) return tr('challenge.matchDone');
    return tr('challenge.sentenceDone');
  }

  /// "الكلمة ٢ من ٥", with a bar under it. A child playing through a
  /// lesson's words should be able to see how far along they are and that
  /// the run actually ends.
  Widget _progress() {
    final done = _celebrating ? _wordIndex + 1 : _wordIndex;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: StudentSurface.glass(context, 0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF6D28D9), width: 1.6),
          ),
          // "السؤال ٣ من ١٠" — one counter for the whole run rather than
          // a different wording per kind of round. The student is working
          // through ten questions; which kind each one happens to be is
          // already obvious from the board under it.
          child: Text(
            trf('challenge.questionOf', {
              'n': _wordIndex + 1,
              'total': _stageCount,
            }),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: StudentSurface.ink(context),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            // Animated rather than jumping: the bar sliding to its new
            // length is what makes finishing a question feel like ground
            // gained instead of a number changing.
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                end: _stageCount == 0 ? 0 : done / _stageCount,
              ),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: StudentSurface.glass(context, 0.7),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF15803D)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// What is offered once a word is finished: the next one, or — on the
  /// last word — the chance to run the lesson again.
  Widget _afterWordActions() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        if (!_onLastStage)
          FilledButton.icon(
            onPressed: _nextWord,
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(
              tr('challenge.nextWord'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            style: _actionStyle(const Color(0xFF6D28D9)),
          )
        else ...[
          Text(
            tr('challenge.allDone'),
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Color(0xFF15803D),
            ),
          ),
          FilledButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.replay_rounded),
            label: Text(
              tr('challenge.replay'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            style: _actionStyle(const Color(0xFF15803D)),
          ),
        ],
      ],
    );
  }

  ButtonStyle _actionStyle(Color background) => FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      );

  /// The two buckets, side by side. A bucket only accepts the words that
  /// belong in it, so a wrong drop springs back rather than being marked
  /// wrong — the same rule the other two rounds use.
  Widget _sortingBoard() {
    final sorting = _sorting;
    if (sorting == null) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final bucket in sorting.buckets)
          Expanded(child: _bucket(bucket, sorting)),
      ],
    );
  }

  Widget _bucket(String bucket, EndlessReaderSorting sorting) {
    final inside = _sorted.entries
        .where((entry) => entry.value == bucket)
        .map((entry) => entry.key)
        .toList();

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          !_sorted.containsKey(details.data) &&
          sorting.items[details.data] == bucket,
      onAcceptWithDetails: (details) => _onSortAccept(details.data, bucket),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 14),
          constraints: const BoxConstraints(minHeight: 150),
          decoration: BoxDecoration(
            color: StudentSurface.glass(context, hovering ? 0.96 : 0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF6D28D9),
              width: hovering ? 3 : 2,
            ),
            boxShadow: [
              if (hovering)
                BoxShadow(
                  color: const Color(0xFF6D28D9).withValues(alpha: 0.32),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                bucket,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: StudentSurface.ink(context),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final word in inside)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF15803D)),
                      ),
                      child: Text(
                        word,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// The words still waiting to be sorted.
  Widget _sortingTray() {
    final sorting = _sorting;
    if (sorting == null) return const SizedBox.shrink();
    final left = sorting.items.keys
        .where((word) => !_sorted.containsKey(word))
        .toList();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [for (final word in left) _wordTile(word)],
    );
  }

  /// The definition cards, stacked. Each accepts only the term it defines,
  /// so a wrong drop springs back rather than being marked wrong — the
  /// same rule the other two rounds use, and the reason this screen never
  /// tells a child they are wrong.
  Widget _matchingBoard() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final pair in _meaningOrder) ...[
            _meaningCard(pair),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _meaningCard(LessonDefinition pair) {
    final matchedTerm = _matched.entries
        .where((entry) => entry.value == pair.meaning)
        .map((entry) => entry.key)
        .firstOrNull;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          matchedTerm == null && details.data == pair.term,
      onAcceptWithDetails: (details) =>
          _onMatchAccept(details.data, pair.meaning),
      builder: (context, candidate, _) {
        final hovering = candidate.isNotEmpty;
        final settled = matchedTerm != null;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: settled
                ? const Color(0xFFDCFCE7)
                : StudentSurface.glass(context, hovering ? 0.98 : 0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: settled
                  ? const Color(0xFF15803D)
                  : hovering
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF6D28D9),
              width: settled || hovering ? 2.4 : 1.6,
            ),
          ),
          child: Row(
            children: [
              // The term lands here, at the head of its own definition, so
              // a finished board reads back as a list of full sentences
              // rather than as a score.
              if (settled)
                Container(
                  margin: const EdgeInsetsDirectional.only(end: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF15803D),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    matchedTerm,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  pair.meaning,
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: StudentSurface.ink(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _matchingTray() {
    final left = _pairs
        .map((pair) => pair.term)
        .where((term) => !_matched.containsKey(term))
        .toList();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [for (final term in left) _wordTile(term)],
    );
  }

  /// The sentence with its gap, as one readable line. The gap is a drop
  /// target sized to the answer, so the line does not jump when a word
  /// lands in it.
  Widget _sentenceCard() {
    final sentence = _sentence;
    final filled = _filled;
    return Container(
      constraints: const BoxConstraints(maxWidth: 620),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: StudentSurface.glass(context, 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF6D28D9), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 8,
        children: [
          if (sentence.before.isNotEmpty)
            Text(sentence.before, style: _sentenceStyle(context)),
          DragTarget<String>(
            onWillAcceptWithDetails: (details) =>
                filled == null && details.data == sentence.answer,
            onAcceptWithDetails: (details) => _onSentenceAccept(details.data),
            builder: (context, candidate, rejected) {
              final hovering = candidate.isNotEmpty;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutBack,
                constraints: BoxConstraints(
                  minWidth: (sentence.answer.length * 15.0).clamp(70.0, 200.0),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: filled != null
                      ? const Color(0xFFD1FAE5)
                      : Colors.white.withValues(alpha: hovering ? 0.98 : 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: filled != null
                        ? const Color(0xFF15803D)
                        : const Color(0xFF6D28D9),
                    width: hovering || filled != null ? 3 : 2,
                  ),
                ),
                child: Text(
                  filled ?? '؟',
                  textAlign: TextAlign.center,
                  style: _sentenceStyle(context).copyWith(
                    color: filled != null
                        ? const Color(0xFF15803D)
                        : const Color(0xFF9C8AC4),
                  ),
                ),
              );
            },
          ),
          if (sentence.after.isNotEmpty)
            Text(sentence.after, style: _sentenceStyle(context)),
        ],
      ),
    );
  }

  /// A method rather than a constant: the colour follows the theme, and a
  /// `const` initializer cannot call anything.
  TextStyle _sentenceStyle(BuildContext context) => TextStyle(
        fontSize: 19,
        height: 1.6,
        fontWeight: FontWeight.w800,
        color: StudentSurface.ink(context),
      );

  /// The candidate words for a sentence round. Every one is a real word
  /// from this lesson, so a student cannot pick the answer out by it
  /// being the only plausible thing on screen.
  Widget _choiceTray() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final word in _sentence.choices) _wordTile(word),
      ],
    );
  }

  Widget _wordTile(String word) {
    final face = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        word,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );

    return Draggable<String>(
      data: word,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(scale: 1.12, child: face),
      ),
      childWhenDragging: Opacity(opacity: 0.28, child: face),
      child: face,
    );
  }

}
