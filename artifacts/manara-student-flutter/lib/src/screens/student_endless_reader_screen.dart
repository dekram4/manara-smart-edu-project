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

  var _wordIndex = 0;
  List<int> _blanks = const [];
  List<String> _tiles = const [];

  /// Position in the word -> the letter dropped there. A position missing
  /// from this map is still an empty slot.
  final Map<int, String> _placed = {};

  /// The slot that just accepted a letter, so it alone plays the landing
  /// bounce rather than the whole row twitching.
  int? _justLanded;

  /// Set while the finished-word celebration is on screen, which is also
  /// what stops a second tap racing the next word in.
  bool _celebrating = false;

  String get _word => _words[_wordIndex % _words.length];

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _words = EndlessReaderWords.fromLesson(
      lessonText: widget.academicContext?.selectedLesson.lessonText,
      lessonName: widget.academicContext?.selectedLesson.lessonName,
    );
    if (_words.isNotEmpty) _startRound();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _startRound() {
    final seed = _wordIndex * 7919 + _word.length;
    _blanks = EndlessReaderWords.blanksFor(_word, seed: seed);
    _tiles = EndlessReaderWords.tilesFor(_word, _blanks, seed: seed);
    _placed.clear();
    _justLanded = null;
    _celebrating = false;
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
    if (!_celebrating) return;
    setState(() {
      _wordIndex++;
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
          actions: const [StudentSoundToggle()],
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
              child: _words.isEmpty ? _emptyState() : _game(),
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

        return Column(
          children: [
            const SizedBox(height: 10),
            Text(
              _celebrating ? 'أحسنت! كلمة صحيحة 🎉' : 'اسحب الحروف إلى مكانها',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _celebrating
                    ? const Color(0xFF15803D)
                    : const Color(0xFF3B2A6B),
              ),
            ),
            const Spacer(),
            _wordRow(slot),
            const SizedBox(height: 22),
            if (_celebrating)
              FilledButton.icon(
                onPressed: _nextWord,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text(
                  'الكلمة التالية',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6D28D9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              )
            else
              _tileTray(slot),
            const Spacer(),
          ],
        );
      },
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
