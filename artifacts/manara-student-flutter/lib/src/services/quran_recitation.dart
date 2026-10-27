/// لعبةُ «تسميع القرآن الكريم»: السورُ القصيرة، ومتى تظهر، وتقييمُ التلاوة.
///
/// ── متى تظهر ──
/// صفُّ «روضة منارة المعرفة» **و**مادّةُ «القرآن الكريم» **و**درسُ «حفظ وشرح
/// السور القصيرة» معاً ([quranRecitationAllowedFor]). ولا تظهر في غيره أبداً.
/// والقاعدةُ نفسُها في الخادم (`quranRecitationAllowed` في
/// `lib/quranRecitation.ts`)، وهو من يصرف المكافأة.
///
/// ── التقييم ──
/// تبدأ كلُّ سورةٍ بخطوتين إجباريتين تُقيَّمان كبقيّة الآيات: الاستعاذة، ثم
/// البسملة (وهي في الفاتحة آيتُها الأولى) — [QuranSurah.units].
///
/// ما يسمعه محرّكُ التعرّف كلماتٌ بلا تشكيل، فتُطابَق بالنصّ بعد توحيد
/// الحروف ([normalizeQuranWord]) لحظةَ تُسمع ([RecitationTracker]): ما قرأه
/// صحيحاً أخضر، وما أخطأه أو تخطّاه أحمر. ولا ينتقل إلى الآية التالية حتى
/// تخضرّ الجارية كلُّها.
library;

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'tracing_scope.dart' show isKindergartenGrade;

/// سورةٌ قصيرة: آياتُها بالرسم الإملائي مشكولة.
class QuranSurah {
  const QuranSurah({required this.id, required this.name, required this.verses});

  /// معرّفُها عند الخادم (`QURAN_SURAHS`).
  final String id;
  final String name;
  final List<String> verses;

  /// البسملةُ آيةٌ من الفاتحة؛ وفي غيرها خطوةٌ قبل السورة.
  bool get basmalaIsVerse => id == 'fatiha';

  /// اسمُ السورة بصوتٍ مسجّل، يُسمع لحظةَ اختيارها.
  String get nameClip => 'audio/surah_names/surah_$id.mp3';

  /// ما يُقرأ بترتيبه: الاستعاذة، ثم البسملة، ثم الآيات — وكلُّها تُقيَّم.
  List<RecitationUnit> get units => [
        const RecitationUnit(RecitationUnitKind.istiadha, istiadha, clip: 'audio/quran/istiadha.mp3'),
        if (!basmalaIsVerse)
          const RecitationUnit(RecitationUnitKind.basmala, basmala, clip: 'audio/quran/basmala.mp3'),
        for (var v = 0; v < verses.length; v++)
          RecitationUnit(RecitationUnitKind.verse, verses[v], number: v + 1, clip: 'audio/quran/${id}_${v + 1}.mp3'),
      ];
}

enum RecitationUnitKind { istiadha, basmala, verse }

/// خطوةٌ من التلاوة: الاستعاذة، أو البسملة، أو آيةٌ برقمها.
class RecitationUnit {
  const RecitationUnit(this.kind, this.text, {required this.clip, this.number});

  final RecitationUnitKind kind;
  final String text;

  /// تلاوتُها الصحيحة (الحصري، مرتّل) — يسمعها الطفلُ ثم يردّدها.
  final String clip;

  /// رقمُ الآية؛ `null` للاستعاذة وللبسملة قبل السورة.
  final int? number;

  List<String> get words => [for (final w in text.split(' ')) if (w.isNotEmpty) w];
}

const istiadha = 'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ';
const basmala = 'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ';

/// السورُ الثماني في الدرس، بترتيب المصحف من آخره كما تُحفَظ.
const quranSurahs = <QuranSurah>[
  QuranSurah(id: 'fatiha', name: 'الفاتحة', verses: [
    'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
    'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
    'الرَّحْمَنِ الرَّحِيمِ',
    'مَالِكِ يَوْمِ الدِّينِ',
    'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ',
    'اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ',
    'صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ',
  ]),
  QuranSurah(id: 'nas', name: 'الناس', verses: [
    'قُلْ أَعُوذُ بِرَبِّ النَّاسِ',
    'مَلِكِ النَّاسِ',
    'إِلَهِ النَّاسِ',
    'مِنْ شَرِّ الْوَسْوَاسِ الْخَنَّاسِ',
    'الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ',
    'مِنَ الْجِنَّةِ وَالنَّاسِ',
  ]),
  QuranSurah(id: 'falaq', name: 'الفلق', verses: [
    'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ',
    'مِنْ شَرِّ مَا خَلَقَ',
    'وَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ',
    'وَمِنْ شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ',
    'وَمِنْ شَرِّ حَاسِدٍ إِذَا حَسَدَ',
  ]),
  QuranSurah(id: 'ikhlas', name: 'الإخلاص', verses: [
    'قُلْ هُوَ اللَّهُ أَحَدٌ',
    'اللَّهُ الصَّمَدُ',
    'لَمْ يَلِدْ وَلَمْ يُولَدْ',
    'وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ',
  ]),
  QuranSurah(id: 'masad', name: 'المسد', verses: [
    'تَبَّتْ يَدَا أَبِي لَهَبٍ وَتَبَّ',
    'مَا أَغْنَى عَنْهُ مَالُهُ وَمَا كَسَبَ',
    'سَيَصْلَى نَارًا ذَاتَ لَهَبٍ',
    'وَامْرَأَتُهُ حَمَّالَةَ الْحَطَبِ',
    'فِي جِيدِهَا حَبْلٌ مِنْ مَسَدٍ',
  ]),
  QuranSurah(id: 'nasr', name: 'النصر', verses: [
    'إِذَا جَاءَ نَصْرُ اللَّهِ وَالْفَتْحُ',
    'وَرَأَيْتَ النَّاسَ يَدْخُلُونَ فِي دِينِ اللَّهِ أَفْوَاجًا',
    'فَسَبِّحْ بِحَمْدِ رَبِّكَ وَاسْتَغْفِرْهُ إِنَّهُ كَانَ تَوَّابًا',
  ]),
  QuranSurah(id: 'kafirun', name: 'الكافرون', verses: [
    'قُلْ يَا أَيُّهَا الْكَافِرُونَ',
    'لَا أَعْبُدُ مَا تَعْبُدُونَ',
    'وَلَا أَنْتُمْ عَابِدُونَ مَا أَعْبُدُ',
    'وَلَا أَنَا عَابِدٌ مَا عَبَدْتُمْ',
    'وَلَا أَنْتُمْ عَابِدُونَ مَا أَعْبُدُ',
    'لَكُمْ دِينُكُمْ وَلِيَ دِينِ',
  ]),
  QuranSurah(id: 'kawthar', name: 'الكوثر', verses: [
    'إِنَّا أَعْطَيْنَاكَ الْكَوْثَرَ',
    'فَصَلِّ لِرَبِّكَ وَانْحَرْ',
    'إِنَّ شَانِئَكَ هُوَ الْأَبْتَرُ',
  ]),
];

// ── متى تظهر ──────────────────────────────────────────────────────────

String _key(String value) => normalizeQuranWord(value).replaceAll(RegExp(r'\s+'), ' ').trim();

bool isQuranSubject(String? subject) => _key(subject ?? '').contains('القران الكريم');

bool isShortSurahsLesson(String? lesson) =>
    _key(lesson ?? '').contains(_key('حفظ وشرح السور القصيرة'));

bool quranRecitationAllowedFor({
  required String? grade,
  required String? subject,
  required String? lesson,
}) =>
    isKindergartenGrade(grade) && isQuranSubject(subject) && isShortSurahsLesson(lesson);

// ── التقييم ───────────────────────────────────────────────────────────

// بالرموز: التشكيلُ، والألفُ الخنجرية، والتطويل.
final _marks = RegExp('[ً-ٰٟـ]');

/// الكلمةُ كما يكتبها محرّكُ التعرّف: بلا تشكيل، والهمزاتُ والتاءُ المربوطة
/// والألفُ المقصورة موحّدة.
String normalizeQuranWord(String word) => word
    .replaceAll(_marks, '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAll('ؤ', 'و')
    .replaceAll('ئ', 'ي')
    .replaceAll('ء', '')
    .replaceAll(RegExp(r'[^ء-ي\s]'), '');

int _edit(String a, String b) {
  var previous = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final row = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      row[j] = [previous[j] + 1, row[j - 1] + 1, previous[j - 1] + cost].reduce((x, y) => x < y ? x : y);
    }
    previous = row;
  }
  return previous[b.length];
}

/// هل [heard] هي [expected]؟ تساهلٌ بحرفٍ في الكلمة المتوسّطة وحرفين في
/// الطويلة — محرّكُ التعرّف يخطئ في حرفٍ ما يقرؤه الطفل صحيحاً — ولا تساهلَ
/// في كلمةٍ من ثلاثة أحرفٍ فأقلّ («لم» ليست «لن»، و«أحد» ليست «واحد»).
bool quranWordMatches(String heard, String expected) {
  final a = normalizeQuranWord(heard);
  final b = normalizeQuranWord(expected);
  if (a == b) return true;
  if (a.isEmpty || b.isEmpty) return false;
  // حرفُ عطفٍ أو جرٍّ في أوّلها يجعلها كلمةً أخرى: «الله» ليست «بالله»،
  // و«لم» ليست «ولم».
  if ((a.length - b.length).abs() == 1) {
    final (short, long) = a.length < b.length ? (a, b) : (b, a);
    if (long.substring(1) == short && 'وفبلك'.contains(long[0])) return false;
  }
  final allowed = b.length <= 3 ? 0 : (b.length <= 6 ? 1 : 2);
  return _edit(a, b) <= allowed;
}

enum RecitedWord { pending, correct, wrong }

/// كلماتُ ما سُمع. وحرفُ عطفٍ أو جرٍّ كتبه المحرّكُ وحده («و لم») يُلصق
/// بما بعده كما في المصحف («ولم»).
List<String> _heardWords(String heard) {
  final out = <String>[];
  String? clitic;
  for (final w in heard.split(RegExp(r'\s+'))) {
    final word = normalizeQuranWord(w);
    if (word.isEmpty) continue;
    if (word.length == 1 && 'وفبلك'.contains(word)) {
      clitic = (clitic ?? '') + word;
      continue;
    }
    out.add('${clitic ?? ''}$word');
    clitic = null;
  }
  if (clitic != null) out.add(clitic);
  return out;
}

/// مطابقةُ [said] بكلمات خطوةٍ ([expected]) — مسافةُ تحريرٍ بالكلمات تنتهي
/// حيث انتهى ما قيل. لكل كلمةٍ متوقَّعة: حالُها، وأيُّ كلمةٍ مسموعةٍ قابلتها
/// (-1 لمتخطّاةٍ أو لم تُبلغ).
///
/// [from]: إن وُجد فللطفل أن يبدأ من أيّ كلمةٍ في الخطوة (يعيدها من أوّلها،
/// أو يكمل من حيث توقّف)، ويُرجَّح [from] عند التساوي — وما قبل ما بدأ منه
/// لا يُلوَّن. وإلا فالبدءُ من أوّلها، وما تخطّاه منه خطأ.
@visibleForTesting
({List<RecitedWord> status, List<int> heardAt}) alignWords(List<String> expected, List<String> said, {int? from}) {
  final m = expected.length;
  final n = said.length;
  final status = List<RecitedWord>.filled(m, RecitedWord.pending);
  final heardAt = List<int>.filled(m, -1);
  if (m == 0 || n == 0) return (status: status, heardAt: heardAt);
  // كلمةٌ قالها مكانَ كلمةٍ أرخصُ قليلاً من «زائدةٍ ثم متخطّاة»: فتُرى حمراءَ
  // لحظةَ يقولها.
  const extra = 1.0;
  const missed = 1.0;
  const substitute = 0.95;
  final cost = List.generate(n + 1, (_) => List<double>.filled(m + 1, 0));
  final move = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var j = 1; j <= m; j++) {
    cost[0][j] = from == null ? cost[0][j - 1] + missed : 0.001 * (j - from).abs();
    move[0][j] = from == null ? 2 : -1;
  }
  for (var i = 1; i <= n; i++) {
    cost[i][0] = cost[i - 1][0] + extra;
    move[i][0] = 1;
    for (var j = 1; j <= m; j++) {
      var best = cost[i - 1][j - 1] + (quranWordMatches(said[i - 1], expected[j - 1]) ? 0 : substitute);
      var how = 0;
      if (cost[i - 1][j] + extra < best) {
        best = cost[i - 1][j] + extra;
        how = 1;
      }
      if (cost[i][j - 1] + missed < best) {
        best = cost[i][j - 1] + missed;
        how = 2;
      }
      cost[i][j] = best;
      move[i][j] = how;
    }
  }
  var end = 0;
  for (var j = 1; j <= m; j++) {
    if (cost[n][j] < cost[n][end]) end = j;
  }
  var i = n;
  var j = end;
  while (i > 0 || j > 0) {
    final how = i == 0 ? move[0][j] : (j == 0 ? 1 : move[i][j]);
    if (how == -1) break; // بدايةٌ حرّة: ما قبلها لا يُلوَّن.
    switch (how) {
      case 0:
        status[j - 1] = quranWordMatches(said[i - 1], expected[j - 1]) ? RecitedWord.correct : RecitedWord.wrong;
        heardAt[j - 1] = i - 1;
        i--;
        j--;
      case 1:
        i--;
      default:
        status[j - 1] = RecitedWord.wrong;
        j--;
    }
  }
  return (status: status, heardAt: heardAt);
}

/// يتابع تلاوةَ سورةٍ خطوةً خطوة: الاستعاذة، ثم البسملة، ثم الآيات.
///
/// ── فوراً ──
/// كلُّ كلمةٍ يسمعها المحرّك تُطابَق لحظتَها بكلمات الخطوة الجارية: الصحيحةُ
/// تخضرّ، والخاطئةُ أو المتخطّاة تحمرّ — في الحال، لا حين تُقرأ التي بعدها.
/// والأخضرُ لا ينقلب أحمر أبداً؛ والأحمرُ يخضرّ حين يعيد الطفلُ الكلمةَ صحيحة.
///
/// ── لا انتقالَ قبل التصحيح ──
/// لا تبدأ الخطوةُ التالية حتى تخضرّ الجارية كلُّها ([blocked]): ما يقرؤه
/// الطفلُ من الآية التالية قبل ذلك لا يُحسب لها. يعيد الآيةَ — من أوّلها أو
/// من الكلمة الحمراء — حتى تصحّ، فينتقل.
class RecitationTracker {
  RecitationTracker(QuranSurah surah) : units = surah.units {
    for (var u = 0; u < units.length; u++) {
      for (final w in units[u].words) {
        _words.add(w);
        _unitOf.add(u);
      }
    }
    _status = List.filled(_words.length, RecitedWord.pending);
  }

  final List<RecitationUnit> units;
  final List<String> _words = [];
  final List<int> _unitOf = [];
  late final List<RecitedWord> _status;

  List<String> get words => List.unmodifiable(_words);

  /// خطوةُ كل كلمة في [units].
  List<int> get unitOf => List.unmodifiable(_unitOf);

  List<RecitedWord> get status => List.unmodifiable(_status);

  int _unit = 0;
  int _consumed = 0;

  /// الخطوةُ التي يقرؤها الآن؛ تساوي عددَ الخطوات بعد آخرها.
  int get currentUnit => _unit;

  bool get complete => _unit >= units.length;

  /// في الخطوة الجارية كلمةٌ حمراء: لا انتقالَ حتى تخضرّ.
  bool get blocked => !complete && _indicesOf(_unit).any((k) => _status[k] == RecitedWord.wrong);

  /// هل تخضرّ الخطوةُ كلُّها بما بقي أخضرَ منها وبهذه المطابقة؟
  bool _greenWith(List<int> indices, List<RecitedWord> now) {
    for (var k = 0; k < indices.length; k++) {
      if (_status[indices[k]] != RecitedWord.correct && now[k] != RecitedWord.correct) return false;
    }
    return true;
  }

  List<int> _indicesOf(int unit) => [for (var k = 0; k < _words.length; k++) if (_unitOf[k] == unit) k];

  /// استماعٌ جديد: نصُّه يبدأ من الصفر.
  void startSession() => _consumed = 0;

  /// كلُّ ما سُمع في الاستماع الجاري حتى الآن. [ended]: انتهى هذا الاستماع —
  /// فما قيل فيه لا يُعاد في الاستماع التالي.
  void hear(String transcript, {bool ended = false}) {
    final said = _heardWords(transcript);
    for (var guard = 0; guard < 256 && !complete; guard++) {
      if (_consumed > said.length) _consumed = said.length;
      final tail = said.sublist(_consumed);
      if (tail.isEmpty) return;
      final indices = _indicesOf(_unit);
      final from = indices.indexWhere((k) => _status[k] != RecitedWord.correct);
      final expected = [for (final k in indices) _words[k]];
      // أقصرُ ما يُتمّ الخطوةَ ممّا قيل: فما بعده للخطوة التالية — لا تأخذ
      // «الرجيم» من الاستعاذة «الرحيم» من البسملة بعدها.
      final start = from < 0 ? 0 : from;
      var r = alignWords(expected, tail, from: start);
      if (_greenWith(indices, r.status)) {
        // تخضرّ بما قيل كلِّه: فبأقصرِ بدايةٍ منه — والبحثُ وحده حين تخضرّ،
        // لا مع كل كلمةٍ يسمعها المحرّك.
        for (var p = 1; p < tail.length; p++) {
          final shorter = alignWords(expected, tail.sublist(0, p), from: start);
          if (_greenWith(indices, shorter.status)) {
            r = shorter;
            break;
          }
        }
      }
      for (var k = 0; k < indices.length; k++) {
        final now = r.status[k];
        if (now == RecitedWord.correct) {
          _status[indices[k]] = RecitedWord.correct;
        } else if (now == RecitedWord.wrong && _status[indices[k]] != RecitedWord.correct) {
          _status[indices[k]] = RecitedWord.wrong;
        }
      }
      final last = r.heardAt.lastIndexWhere((h) => h >= 0);
      if (indices.every((k) => _status[k] == RecitedWord.correct)) {
        // خضراءُ كلُّها: الخطوةُ التالية، وما بعدها في النصّ لها.
        _consumed += last >= 0 ? r.heardAt[last] + 1 : 0;
        _unit++;
        continue;
      }
      // قرأها إلى آخرها وفيها أحمر: ما يقوله بعدها محاولةٌ جديدةٌ لها. لكن
      // لا قبل أن يقول شيئاً بعدها — آخرُ كلمةٍ قد يصحّحها المحرّكُ نفسُه
      // في النصّ الجزئي التالي.
      if (last >= 0 && r.status.last != RecitedWord.pending && (r.heardAt[last] < tail.length - 1 || ended)) {
        _consumed += r.heardAt[last] + 1;
        continue;
      }
      if (ended) _consumed = said.length;
      return;
    }
  }
}
