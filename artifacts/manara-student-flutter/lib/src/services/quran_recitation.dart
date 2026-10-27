/// لعبةُ «تسميع القرآن الكريم»: السورُ القصيرة، ومتى تظهر، وتقييمُ التلاوة.
///
/// ── متى تظهر ──
/// صفُّ «روضة منارة المعرفة» **و**مادّةُ «القرآن الكريم» **و**درسُ «حفظ وشرح
/// السور القصيرة» معاً ([quranRecitationAllowedFor]). ولا تظهر في غيره أبداً.
/// والقاعدةُ نفسُها في الخادم (`quranRecitationAllowed` في
/// `lib/quranRecitation.ts`)، وهو من يصرف المكافأة.
///
/// ── التقييم ──
/// ما يسمعه محرّكُ التعرّف كلماتٌ بلا تشكيل. فتُطابَق بالنصّ المكتوب بعد
/// توحيد الحروف ([normalizeQuranWord])، كلمةً كلمة ([alignRecitation]):
/// ما قرأه الطفلُ صحيحاً أخضر، وما أخطأه أو تخطّاه أحمر، وما لم يبلغه بعدُ
/// بلا لون.
library;

import 'tracing_scope.dart' show isKindergartenGrade;

/// سورةٌ قصيرة: آياتُها بالرسم الإملائي مشكولة.
class QuranSurah {
  const QuranSurah({required this.id, required this.name, required this.verses});

  /// معرّفُها عند الخادم (`QURAN_SURAHS`).
  final String id;
  final String name;
  final List<String> verses;

  /// البسملةُ آيةٌ من الفاتحة وحدها هنا؛ وفي غيرها تُكتب فوق السورة ولا تُقيَّم.
  bool get basmalaIsVerse => id == 'fatiha';

  /// كلماتُ السورة بترتيبها، وآيةُ كل كلمة.
  List<({String word, int verse})> get words => [
        for (var v = 0; v < verses.length; v++)
          for (final word in verses[v].split(' '))
            if (word.isNotEmpty) (word: word, verse: v),
      ];
}

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
  final allowed = b.length <= 3 ? 0 : (b.length <= 6 ? 1 : 2);
  return _edit(a, b) <= allowed;
}

enum RecitedWord { pending, correct, wrong }

/// حالُ كل كلمةٍ في [expected] بعد تلاوةٍ واحدة سُمع منها [heard].
///
/// مطابقةٌ بالكلمات (مسافةُ تحرير): للطفل أن يبدأ من أيّ آية — من حيث
/// توقّف — وما قبل ما بدأ منه وما بعد ما بلغه لا يُلوَّن. وبين ذلك: الكلمةُ
/// المطابِقة صحيحة، والمستبدَلةُ أو المتخطّاة خطأ. وما زاده الطفل (استعاذةٌ،
/// بسملةٌ، تكرار) لا يُحسب عليه.
///
/// [from]: من أين يُرجَّح أن يبدأ — أوّلُ كلمةٍ لم تصحّ بعد. يحسم التساوي
/// في سورةٍ تتكرّر آياتها (الكافرون) لصالح الموضع الذي وصله، ويجعل كلمةً
/// تخطّاها في أوّل التلاوة خطأً لا بدايةً متأخّرة.
List<RecitedWord> alignRecitation(List<String> expected, String heard, {int from = 0}) {
  final said = [
    for (final w in heard.split(RegExp(r'\s+')))
      if (normalizeQuranWord(w).isNotEmpty) w,
  ];
  final m = expected.length;
  final out = List<RecitedWord>.filled(m, RecitedWord.pending);
  if (said.isEmpty || m == 0) return out;
  final n = said.length;
  // كلمةٌ قالها مكانَ كلمةٍ أرخصُ قليلاً من «زائدةٍ ثم متخطّاة»: فتُرى حمراءَ
  // لحظةَ يقولها، لا حين يقول التي بعدها.
  const extra = 1.0;
  const missed = 1.0;
  const substitute = 0.95;
  // cost[i][j]: أرخصُ مطابقةٍ لأوّل i مما قيل بمقطعٍ من النصّ ينتهي عند j.
  final cost = List.generate(n + 1, (_) => List<double>.filled(m + 1, 0));
  final move = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var j = 0; j <= m; j++) {
    // البدءُ قبل [from] شبهُ مجّاني: الطفلُ يعيد من أوّل الآية أو السورة.
    // والبدءُ بعده يكلّف: كلماتٌ تخطّاها في أوّل التلاوة تبقى حمراء لا
    // تُحسب «بدايةً من هناك» — ولحدٍّ، فمن قصد آيةً بعيدةً يبلغها.
    cost[0][j] = j <= from ? 0.001 * (from - j) : (0.5 * (j - from)).clamp(0.0, 2.0);
    move[0][j] = -1;
  }
  for (var i = 1; i <= n; i++) {
    for (var j = 0; j <= m; j++) {
      var best = cost[i - 1][j] + extra;
      var how = 1;
      if (j > 0) {
        final diag = cost[i - 1][j - 1] + (quranWordMatches(said[i - 1], expected[j - 1]) ? 0 : substitute);
        if (diag <= best) {
          best = diag;
          how = 0;
        }
        final skip = cost[i][j - 1] + missed;
        if (skip < best) {
          best = skip;
          how = 2;
        }
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
  while (i > 0) {
    switch (move[i][j]) {
      case 0:
        out[j - 1] = quranWordMatches(said[i - 1], expected[j - 1]) ? RecitedWord.correct : RecitedWord.wrong;
        i--;
        j--;
      case 1:
        i--;
      default:
        out[j - 1] = RecitedWord.wrong;
        j--;
    }
  }
  return out;
}

/// ما بقي من التلاوات السابقة مع التلاوة الجارية: كلمةٌ صحّت مرّةً تبقى
/// صحيحة — للطفل أن يعيد الآيةَ التي أخطأها وحدها — والخطأُ يبقى أحمرَ
/// حتى يصحّ.
List<RecitedWord> mergeRecitation(List<RecitedWord> settled, List<RecitedWord> current) => [
      for (var k = 0; k < settled.length; k++)
        if (settled[k] == RecitedWord.correct || current[k] == RecitedWord.correct)
          RecitedWord.correct
        else if (settled[k] == RecitedWord.wrong || current[k] == RecitedWord.wrong)
          RecitedWord.wrong
        else
          RecitedWord.pending,
    ];
