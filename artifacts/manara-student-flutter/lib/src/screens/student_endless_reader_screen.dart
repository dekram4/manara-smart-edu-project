import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/academic_context.dart';
import '../services/student_sound_service.dart';
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
  static List<String> fromLesson({String? lessonText, String? lessonName}) {
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
        if (word.length < minLength || word.length > maxLength) continue;
        if (!seen.add(word)) continue;
        words.add(word);
        if (words.length >= maxWords) return words;
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

  /// The most sentence rounds one visit plays through.
  static const maxSentences = 8;

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
    super.key,
  });

  final AcademicContext? academicContext;

  @override
  State<StudentEndlessReaderScreen> createState() =>
      _StudentEndlessReaderScreenState();
}

class _StudentEndlessReaderScreenState
    extends State<StudentEndlessReaderScreen> {
  late final ConfettiController _confetti;
  late final List<String> _words;
  late final List<EndlessReaderSentence> _sentences;

  /// Letter rounds first, then sentence rounds. Spelling a term before
  /// being asked to place it in a definition is the order that teaches;
  /// the reverse asks a student to use a word they have not met yet.
  int get _letterStages => _words.length;
  int get _sentenceStages => _sentences.length;
  bool get _onSentence => _wordIndex >= _letterStages;
  EndlessReaderSentence get _sentence =>
      _sentences[(_wordIndex - _letterStages).clamp(0, _sentences.length - 1)];

  /// The word dropped into the sentence gap, once one has been.
  String? _filled;

  var _wordIndex = 0;
  List<int> _blanks = const [];
  List<String> _tiles = const [];

  /// How many words this lesson's round runs for. Every word is a stage,
  /// so the student can see the end of the run rather than playing an
  /// unmarked stream.
  int get _stageCount => _letterStages + _sentenceStages;
  bool get _onLastStage => _wordIndex >= _stageCount - 1;

  /// Position in the word -> the letter dropped there. A position missing
  /// from this map is still an empty slot.
  final Map<int, String> _placed = {};

  /// The slot that just accepted a letter, so it alone plays the landing
  /// bounce rather than the whole row twitching.
  int? _justLanded;

  /// Set while the finished-word celebration is on screen, which is also
  /// what stops a second tap racing the next word in.
  bool _celebrating = false;

  String get _word => _words[_wordIndex.clamp(0, _words.length - 1)];

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _words = EndlessReaderWords.fromLesson(
      lessonText: widget.academicContext?.selectedLesson.lessonText,
      lessonName: widget.academicContext?.selectedLesson.lessonName,
    );
    _sentences = EndlessReaderSentences.fromLesson(
      lessonText: widget.academicContext?.selectedLesson.lessonText,
    );
    if (_stageCount > 0) _startRound();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _startRound() {
    _placed.clear();
    _filled = null;
    _justLanded = null;
    _celebrating = false;
    if (_onSentence) {
      _blanks = const [];
      _tiles = const [];
      return;
    }
    final seed = _wordIndex * 7919 + _word.length;
    _blanks = EndlessReaderWords.blanksFor(_word, seed: seed);
    _tiles = EndlessReaderWords.tilesFor(_word, _blanks, seed: seed);
  }

  /// A word dropped into the sentence gap. Only the right one is ever
  /// accepted, so this always means success.
  void _onSentenceAccept(String word) {
    setState(() => _filled = word);
    HapticFeedback.lightImpact();
    StudentSoundService.instance.play(StudentSoundCue.success);
    _finishWord();
  }

  void _onAccept(int position, String letter) {
    setState(() {
      _placed[position] = letter;
      _justLanded = position;
    });
    HapticFeedback.lightImpact();
    StudentSoundService.instance.play(StudentSoundCue.success);
    if (_placed.length == _blanks.length) _finishWord();
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

  /// Starts the whole run again from the first word. Offered at the end
  /// of a lesson's words, and at any point through the bar, because a
  /// child who wants another go should not have to leave and come back.
  void _restart() {
    StudentSoundService.instance.playTap();
    setState(() {
      _wordIndex = 0;
      _startRound();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFDF3EA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF3B2A6B),
          foregroundColor: Colors.white,
          title: const Text('تحدي القراءة والكلمات'),
          centerTitle: true,
          actions: [
            if (_stageCount > 0)
              IconButton(
                onPressed: _restart,
                tooltip: "إعادة المرحلة من البداية",
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
              child: _stageCount == 0 ? _emptyState() : _game(),
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
              const Text(
                'لا توجد كلمات في هذا الدرس بعد',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF3B2A6B),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.academicContext == null
                    ? 'اختر درسك أولًا من زر تغيير الدرس، ثم عد إلى هنا.'
                    : 'سيظهر التحدي هنا عندما يضيف المعلم نص الدرس.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF5B4A7A),
                  height: 1.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _game() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The slot size is solved from the row that must hold the whole
        // word, so a seven-letter word on a small phone shrinks its tiles
        // instead of running off the side — and the floor keeps every
        // tile inside what a child's finger can reliably hit.
        final available = constraints.maxWidth - 32;
        final slot = (available / math.max(_word.length, 4) - 8)
            .clamp(34.0, 74.0)
            .toDouble();

        // The whole arena is centred rather than spread to the edges: the
        // word, its tiles and the progress above them read as one panel
        // in the middle of the screen with the artwork around it.
        return Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _progress(),
                const SizedBox(height: 14),
                Text(
                  _celebrating
                      ? (_onSentence ? 'أحسنت! جملة صحيحة 🎉' : 'أحسنت! كلمة صحيحة 🎉')
                      : (_onSentence
                          ? 'اسحب الكلمة الناقصة إلى الفراغ'
                          : 'اسحب الحروف إلى مكانها'),
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
                if (_onSentence) _sentenceCard() else _wordRow(slot),
                const SizedBox(height: 24),
                if (_celebrating)
                  _afterWordActions()
                else if (_onSentence)
                  _choiceTray()
                else
                  _tileTray(slot),
              ],
            ),
          ),
        );
      },
    );
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
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF6D28D9), width: 1.6),
          ),
          child: Text(
            'الكلمة ${_wordIndex + 1} من $_stageCount',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF3B2A6B),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _stageCount == 0 ? 0 : done / _stageCount,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.7),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF15803D)),
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
            label: const Text(
              'الكلمة التالية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            style: _actionStyle(const Color(0xFF6D28D9)),
          )
        else ...[
          const Text(
            'أنهيت كل كلمات الدرس! 🌟',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Color(0xFF15803D),
            ),
          ),
          FilledButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.replay_rounded),
            label: const Text(
              'إعادة المرحلة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
        color: Colors.white.withOpacity(0.92),
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
            Text(sentence.before, style: _sentenceStyle),
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
                      : Colors.white.withOpacity(hovering ? 0.98 : 0.6),
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
                  style: _sentenceStyle.copyWith(
                    color: filled != null
                        ? const Color(0xFF15803D)
                        : const Color(0xFF9C8AC4),
                  ),
                ),
              );
            },
          ),
          if (sentence.after.isNotEmpty)
            Text(sentence.after, style: _sentenceStyle),
        ],
      ),
    );
  }

  static const _sentenceStyle = TextStyle(
    fontSize: 19,
    height: 1.6,
    fontWeight: FontWeight.w800,
    color: Color(0xFF3B2A6B),
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

  Widget _wordRow(double slot) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < _word.length; index++)
          _blanks.contains(index)
              ? _slot(index, slot)
              : _fixedLetter(_word[index], slot),
      ],
    );
  }

  Widget _fixedLetter(String letter, double slot) => Container(
        width: slot,
        height: slot,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x33000000)),
        ),
        child: Text(
          letter,
          style: TextStyle(
            fontSize: slot * 0.52,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF3B2A6B),
          ),
        ),
      );

  Widget _slot(int index, double slot) {
    final placed = _placed[index];
    final landed = _justLanded == index;

    return DragTarget<String>(
      // Only the right letter is taken. A wrong one is refused before it
      // lands, so the tile springs back to the tray on its own and the
      // child is never shown their own mistake sitting in the word.
      onWillAcceptWithDetails: (details) =>
          placed == null && details.data == _word[index],
      onAcceptWithDetails: (details) => _onAccept(index, details.data),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return AnimatedScale(
          scale: landed ? 1.12 : (hovering ? 1.06 : 1.0),
          duration: Duration(milliseconds: landed ? 220 : 140),
          curve: Curves.easeOutBack,
          onEnd: () {
            if (landed && mounted) setState(() => _justLanded = null);
          },
          child: Container(
            width: slot,
            height: slot,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: placed != null
                  ? const Color(0xFFD1FAE5)
                  : Colors.white.withOpacity(hovering ? 0.95 : 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: placed != null
                    ? const Color(0xFF15803D)
                    : const Color(0xFF6D28D9),
                width: hovering || placed != null ? 3 : 2,
              ),
              boxShadow: [
                if (hovering || placed != null)
                  BoxShadow(
                    color: (placed != null
                            ? const Color(0xFF15803D)
                            : const Color(0xFF6D28D9))
                        .withOpacity(0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
              ],
            ),
            child: Text(
              placed ?? '',
              style: TextStyle(
                fontSize: slot * 0.52,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF15803D),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tileTray(double slot) {
    // Letters already placed leave the tray, so what is left is always
    // what is still needed plus the decoys.
    final used = _placed.values.toList();
    final remaining = <String>[];
    for (final tile in _tiles) {
      final at = used.indexOf(tile);
      if (at >= 0) {
        used.removeAt(at);
      } else {
        remaining.add(tile);
      }
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final letter in remaining) _tile(letter, slot),
      ],
    );
  }

  Widget _tile(String letter, double slot) {
    final face = Container(
      width: slot,
      height: slot,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
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
        letter,
        style: TextStyle(
          fontSize: slot * 0.52,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF3B2A6B),
        ),
      ),
    );

    return Draggable<String>(
      data: letter,
      // Drawn a little larger under the finger so the letter stays
      // visible past the fingertip covering it.
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(scale: 1.18, child: face),
      ),
      childWhenDragging: Opacity(opacity: 0.28, child: face),
      child: face,
    );
  }
}
