/// مجموعاتُ «تعلّم الكتابة» كاملةً على الجهاز — نقلٌ أمين لـ`alphabetItems`
/// في الخادم (`lib/tracing.ts`).
///
/// ── لماذا على الجهاز ──
/// بطاقةُ الكتابة في الواجهة تُفتح على الحروف فوراً، لا بعد أن يولّد الخادمُ
/// ألعابَ الدرس كلَّها. والمجموعةُ ثابتة — حروفٌ بترتيبها وأعدادٌ من الصفر
/// إلى المئة — فلا شيء فيها يحتاج الخادم. أمّا الجوهرةُ فيصرفها الخادم كما
/// كان، ولا يصرفها إلا لعنصرٍ من المجموعة نفسها: فالنصوصُ هنا حرفاً بحرف
/// كما هناك، وإلا رُدّت المكافأة.
library;

import '../models/study_games.dart';
import 'tracing_scope.dart';

/// معرّفُ اللعبة في الخادم: مكافأتُها `درس::tracing`.
const tracingGameId = 'tracing';

const _arabicLetters = <(String, String)>[
  ('ا', 'ألف'), ('ب', 'باء'), ('ت', 'تاء'), ('ث', 'ثاء'), ('ج', 'جيم'), ('ح', 'حاء'),
  ('خ', 'خاء'), ('د', 'دال'), ('ذ', 'ذال'), ('ر', 'راء'), ('ز', 'زاي'), ('س', 'سين'),
  ('ش', 'شين'), ('ص', 'صاد'), ('ض', 'ضاد'), ('ط', 'طاء'), ('ظ', 'ظاء'), ('ع', 'عين'),
  ('غ', 'غين'), ('ف', 'فاء'), ('ق', 'قاف'), ('ك', 'كاف'), ('ل', 'لام'), ('م', 'ميم'),
  ('ن', 'نون'), ('ه', 'هاء'), ('و', 'واو'), ('ي', 'ياء'),
];

const _numbersMax = 100;

const _arUnits = [
  'صفر', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة',
  'عشرة', 'أحد عشر', 'اثنا عشر', 'ثلاثة عشر', 'أربعة عشر', 'خمسة عشر', 'ستة عشر',
  'سبعة عشر', 'ثمانية عشر', 'تسعة عشر',
];
const _arTens = ['', '', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون', 'تسعون'];

const _enUnits = [
  'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten',
  'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen',
  'nineteen',
];
const _enTens = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];

String arabicNumberWords(int n) {
  if (n == 100) return 'مئة';
  if (n < 20) return _arUnits[n];
  final unit = n % 10;
  final tens = _arTens[n ~/ 10];
  return unit == 0 ? tens : '${_arUnits[unit]} و$tens';
}

String englishNumberWords(int n) {
  if (n == 100) return 'one hundred';
  if (n < 20) return _enUnits[n];
  final unit = n % 10;
  final tens = _enTens[n ~/ 10];
  return unit == 0 ? tens : '$tens ${_enUnits[unit]}';
}

/// «25» بالأرقام الهندية: «٢٥».
String toArabicIndic(String value) => value.replaceAllMapped(
      RegExp('[0-9]'),
      (m) => String.fromCharCode(0x0660 + int.parse(m[0]!)),
    );

/// أيُّ المجموعات الأربع لمادّةٍ، كما في `alphabetSetOf` بالخادم.
enum AlphabetSet { arabicLetters, englishLetters, arabicDigits, englishDigits }

AlphabetSet? alphabetSetOf(String? subject) {
  if (!isTracingSubject(subject)) return null;
  final key = (subject ?? '')
      .toLowerCase()
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه');
  final english = RegExp('انجليز|انكليز|english').hasMatch(key);
  final arabic = RegExp('عربي|arabic').hasMatch(key);
  if (RegExp('حروف|الحرف|letters|alphabet').hasMatch(key)) {
    if (english) return AlphabetSet.englishLetters;
    if (arabic) return AlphabetSet.arabicLetters;
  }
  if (RegExp('ارقام|اعداد|numbers|digits').hasMatch(key)) {
    if (english) return AlphabetSet.englishDigits;
    if (arabic) return AlphabetSet.arabicDigits;
  }
  return null;
}

/// المجموعةُ كاملةً بترتيبها.
List<TracingItem> alphabetItems(AlphabetSet set) => switch (set) {
      AlphabetSet.arabicLetters => [
          for (final (text, speech) in _arabicLetters)
            TracingItem(text: text, kind: 'letter', lang: 'ar', speech: speech),
        ],
      // الكبيرُ والصغيرُ معاً: «Aa» يُتتبّع ويُنطق «A».
      AlphabetSet.englishLetters => [
          for (var i = 0; i < 26; i++)
            TracingItem(
              text: '${String.fromCharCode(65 + i)}${String.fromCharCode(97 + i)}',
              kind: 'letter',
              lang: 'en',
              speech: String.fromCharCode(65 + i),
            ),
        ],
      AlphabetSet.arabicDigits => [
          for (var n = 0; n <= _numbersMax; n++)
            TracingItem(
              text: toArabicIndic('$n'),
              kind: 'number',
              lang: 'ar',
              speech: arabicNumberWords(n),
            ),
        ],
      AlphabetSet.englishDigits => [
          for (var n = 0; n <= _numbersMax; n++)
            TracingItem(
              text: '$n',
              kind: 'number',
              lang: 'en',
              speech: englishNumberWords(n),
            ),
        ],
    };

/// لعبةُ الكتابة لدرسٍ من دروس الروضة، أو `null` خارج نطاقها.
StudyGame? writingGameFor({required String? grade, required String? subject}) {
  if (!tracingAllowedFor(grade: grade, subject: subject)) return null;
  final set = alphabetSetOf(subject);
  if (set == null) return null;
  final items = alphabetItems(set);
  final en = items.first.lang == 'en';
  return StudyGame(
    id: tracingGameId,
    type: StudyGameType.tracing,
    title: en ? 'Trace and write!' : 'تتبّع واكتب!',
    instructions: en
        ? 'Tap a letter or number to hear it, then trace it.'
        : 'المس حرفاً أو رقماً لتسمعه، ثم تتبّعه بإصبعك.',
    dragItems: const [],
    dropTargets: const [],
    pairs: const [],
    questions: const [],
    gemsReward: 1,
    pointsReward: 1,
    tracing: items,
  );
}
