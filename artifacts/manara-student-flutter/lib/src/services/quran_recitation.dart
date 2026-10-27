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
/// الحروف ([normalizeQuranWord]) بالترتيب ([RecitationTracker]): ما قرأه
/// صحيحاً أخضر، وما أخطأه أو تخطّاه أحمر — ويثبت كلٌّ منهما لحظةَ يُقرَّر
/// ولا يتغيّر بعدها. وبعد آخر السورة تُعاد الآياتُ الحمراء وحدها.
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
        const RecitationUnit(RecitationUnitKind.istiadha, istiadha),
        if (!basmalaIsVerse) const RecitationUnit(RecitationUnitKind.basmala, basmala),
        for (var v = 0; v < verses.length; v++) RecitationUnit(RecitationUnitKind.verse, verses[v], number: v + 1),
      ];
}

enum RecitationUnitKind { istiadha, basmala, verse }

/// خطوةٌ من التلاوة: الاستعاذة، أو البسملة، أو آيةٌ برقمها.
class RecitationUnit {
  const RecitationUnit(this.kind, this.text, {this.number});

  final RecitationUnitKind kind;
  final String text;

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

/// مطابقةُ [said] بـ[expected] من أوّله (مسافةُ تحرير بالكلمات)، ونهايتُها
/// حيث انتهى ما قيل. لكل كلمةٍ متوقَّعة: حالُها، وأيُّ كلمةٍ مسموعةٍ قابلتها
/// (-1 لمتخطّاةٍ أو لم تُبلغ).
@visibleForTesting
({List<RecitedWord> status, List<int> heardAt}) alignFromStart(List<String> expected, List<String> said) {
  final m = expected.length;
  final n = said.length;
  final status = List<RecitedWord>.filled(m, RecitedWord.pending);
  final heardAt = List<int>.filled(m, -1);
  if (m == 0 || n == 0) return (status: status, heardAt: heardAt);
  // كلمةٌ قالها مكانَ كلمةٍ أرخصُ قليلاً من «زائدةٍ ثم متخطّاة».
  const extra = 1.0;
  const missed = 1.0;
  const substitute = 0.95;
  final cost = List.generate(n + 1, (_) => List<double>.filled(m + 1, 0));
  final move = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var j = 1; j <= m; j++) {
    cost[0][j] = cost[0][j - 1] + missed;
    move[0][j] = 2;
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
    final how = i == 0 ? 2 : (j == 0 ? 1 : move[i][j]);
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

/// يتابع تلاوةَ سورةٍ كلمةً كلمة، ويُثبّت ما قُرّر منها.
///
/// ── الخطُّ لا يتغيّر بعد أن يظهر ──
/// كانت التلاوةُ كلُّها تُطابَق من جديد مع كل كلمةٍ يسمعها المحرّك، فيتبدّل
/// لونُ ما سبق: يتأخّر الأخضر، أو ينقلب أحمرَ عند الانتقال إلى الآية التالية.
/// والآن يتقدّم مؤشّرٌ ([position]): ما قبله ثابتٌ لا يُطابَق ثانيةً، وما
/// بعده وحده يُطابَق بما سُمع بعد آخر ما ثُبِّت. فتثبت الكلمةُ خضراءَ لحظةَ
/// تُقرأ صحيحة، وتثبت حمراءَ حين تُقرأ كلمةٌ بعدها صحيحة (فقد أخطأها أو
/// تخطّاها) أو حين يسكت الطفلُ بعد أن قالها خطأً.
///
/// ── ثم الآياتُ الحمراء وحدها ──
/// بعد آخر كلمة: كلُّ خطوةٍ فيها أحمرُ تُعاد ([reviewing]) — الأولى فالتي
/// بعدها — وتخضرّ كلماتُها حين تُقرأ صحيحة، حتى تصحّ السورةُ كلُّها.
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

  int _position = 0;
  int _consumed = 0;

  /// أوّلُ كلمةٍ لم تُقرَّر بعد في القراءة الأولى.
  int get position => _position;

  bool get firstPassDone => _position >= _words.length;
  bool get reviewing => firstPassDone && _status.contains(RecitedWord.wrong);
  bool get complete => firstPassDone && _status.every((s) => s == RecitedWord.correct);

  /// الخطوةُ التي تُعاد الآن، أثناء المراجعة.
  int? get reviewUnit => reviewing ? _unitOf[_status.indexOf(RecitedWord.wrong)] : null;

  /// استماعٌ جديد: نصُّه يبدأ من الصفر.
  void startSession() => _consumed = 0;

  /// كلُّ ما سُمع في الاستماع الجاري حتى الآن. [ended]: سكت الطفل أو أوقف
  /// المايك — فما قاله خطأً في آخر تلاوته يثبت أحمر.
  void hear(String transcript, {bool ended = false}) {
    final said = _heardWords(transcript);
    for (var guard = 0; guard < 256; guard++) {
      if (_consumed > said.length) _consumed = said.length;
      final tail = said.sublist(_consumed);
      if (tail.isEmpty) return;
      final moved = !firstPassDone ? _advance(tail, ended) : (reviewing && _review(tail, ended));
      if (!moved) return;
    }
  }

  bool _advance(List<String> tail, bool ended) {
    final end = (_position + tail.length + 6).clamp(0, _words.length);
    final result = alignFromStart(_words.sublist(_position, end), tail);
    var lock = -1;
    for (var k = result.status.length - 1; k >= 0; k--) {
      final settled = ended ? result.heardAt[k] >= 0 : result.status[k] == RecitedWord.correct;
      if (settled) {
        lock = k;
        break;
      }
    }
    if (lock < 0) {
      // سكت ولم يُطابِق شيئاً: ما قاله لا يُحسب، والمؤشّرُ مكانه.
      if (ended) _consumed += tail.length;
      return false;
    }
    for (var k = 0; k <= lock; k++) {
      _status[_position + k] = result.status[k] == RecitedWord.correct ? RecitedWord.correct : RecitedWord.wrong;
    }
    _consumed += result.heardAt[lock] + 1;
    _position += lock + 1;
    return true;
  }

  bool _review(List<String> tail, bool ended) {
    final unit = reviewUnit!;
    final indices = [for (var k = 0; k < _words.length; k++) if (_unitOf[k] == unit) k];
    final result = alignFromStart([for (final k in indices) _words[k]], tail);
    for (var k = 0; k < indices.length; k++) {
      if (result.status[k] == RecitedWord.correct) _status[indices[k]] = RecitedWord.correct;
    }
    final last = result.heardAt.lastIndexWhere((h) => h >= 0);
    final fixed = indices.every((k) => _status[k] == RecitedWord.correct);
    if (last >= 0 && (fixed || result.status.last != RecitedWord.pending)) {
      // صحّت الخطوة، أو قرأها إلى آخرها: ما بعدها في النصّ قراءةٌ جديدة.
      _consumed += last + 1;
      return true;
    }
    if (ended) _consumed += tail.length;
    return false;
  }
}
