import 'dart:math' as math;

/// مطابقةُ ما يقوله الطفلُ بصوته مع أسماءٍ مكتوبة: اسمُه المحفوظ، أو مادّةٌ
/// أو وحدةٌ أو درسٌ في خريطة المسار.
///
/// ── لماذا لا تطابقٌ حرفيّ ──
/// محرّكُ التعرّف يكتب ما سمعه بلا تشكيل، وبهمزاتٍ وتاءاتٍ كما اتّفق
/// («قران» و«القرآن»، «نورانيه» و«النورانية»). والطفلُ يقول كلمةً واحدةً
/// بسيطة — «قرآن»، «حروف»، «أرقام»، «الأول» — لا الاسمَ كاملاً. فيُوحَّد
/// الرسمُ أوّلاً، وتُقصّ «ال» وأخواتها، وتُردّ مرادفاتُ الأطفال إلى كلمةٍ
/// واحدة، ثم يُختار الخيارُ الذي التقى بأكثر كلماته — ولا يُختار شيءٌ إن
/// تعادل خياران: سؤالُ الطفل ثانيةً خيرٌ من أخذه إلى غير ما أراد.

/// يوحّد الرسم: بلا تشكيلٍ ولا تطويل، وهمزاتُ الألف ألفٌ، والتاءُ المربوطة
/// هاء، والأرقامُ الهندية لاتينية، وبلا علامات.
String normalizeSpoken(String text) {
  var t = text.toLowerCase();
  t = t.replaceAll(RegExp('[ً-ٰٟـ]'), '');
  t = t
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي');
  const indic = '٠١٢٣٤٥٦٧٨٩';
  for (var d = 0; d < indic.length; d++) {
    t = t.replaceAll(indic[d], '$d');
  }
  t = t.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
  return t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');
}

/// مرادفاتُ الأطفال: كلُّ كلمةٍ تُردّ إلى أصلٍ واحد.
const Map<String, String> _synonyms = {
  'اول': '1', 'اولي': '1', 'واحد': '1', 'one': '1', 'first': '1',
  'ثاني': '2', 'ثانيه': '2', 'اثنين': '2', 'two': '2', 'second': '2',
  'ثالث': '3', 'ثالثه': '3', 'ثلاثه': '3', 'three': '3', 'third': '3',
  'رابع': '4', 'رابعه': '4', 'اربعه': '4', 'four': '4',
  'خامس': '5', 'خامسه': '5', 'خمسه': '5', 'five': '5',
  'سادس': '6', 'سادسه': '6', 'سته': '6', 'six': '6',
  'قران': 'قران', 'قرءان': 'قران', 'مصحف': 'قران', 'quran': 'قران',
  'نوراني': 'نوراني', 'نورانيه': 'نوراني', 'قاعده': 'نوراني',
  'حرف': 'حروف', 'حروف': 'حروف', 'هجاء': 'حروف', 'letters': 'حروف', 'letter': 'حروف', 'abc': 'حروف',
  'رقم': 'ارقام', 'ارقام': 'ارقام', 'عدد': 'ارقام', 'اعداد': 'ارقام', 'numbers': 'ارقام', 'number': 'ارقام',
  'انجليزي': 'english', 'انجليزيه': 'english', 'انقليزي': 'english', 'انكليزي': 'english', 'english': 'english',
  'علم': 'علوم', 'علوم': 'علوم', 'science': 'علوم',
  'رياضيات': 'رياضيات', 'رياضه': 'رياضيات', 'حساب': 'رياضيات', 'math': 'رياضيات', 'maths': 'رياضيات',
  'روضه': 'روضه', 'تمهيدي': 'روضه', 'kg': 'روضه',
  'سوره': 'سوره', 'سور': 'سوره',
};

/// كلماتُ النصّ بعد التوحيد وقصّ السوابق وردّ المرادفات.
List<String> spokenWords(String text) => [
      for (final word in normalizeSpoken(text).split(' '))
        if (_root(word) case final root when root.isNotEmpty) root,
    ];

String _root(String word) {
  var w = word;
  if (_synonyms[w] case final s?) return s;
  for (final prefix in const ['وال', 'بال', 'فال', 'كال', 'لل', 'ال']) {
    if (w.startsWith(prefix) && w.length - prefix.length >= 2) {
      w = w.substring(prefix.length);
      break;
    }
  }
  if (_synonyms[w] case final s?) return s;
  // ‏«و» العطف لاصقةً بكلمة: «وحروف».
  if (w.length > 3 && w.startsWith('و') && _synonyms[w.substring(1)] != null) return _synonyms[w.substring(1)]!;
  return w.length >= 2 || RegExp(r'^\d$').hasMatch(w) ? w : '';
}

/// كلمتان متقاربتان: متطابقتان، أو إحداهما بدايةُ الأخرى، أو بينهما حرفٌ
/// واحد في الكلمات الطويلة — خطأُ سماعٍ لا اسمٌ آخر.
bool _close(String said, String written) {
  if (said == written) return true;
  if (said.length >= 3 && written.length >= 3 && (written.startsWith(said) || said.startsWith(written))) return true;
  return said.length >= 4 && written.length >= 4 && _distance(said, written) <= 1;
}

int _distance(String a, String b) {
  if ((a.length - b.length).abs() > 1) return 2;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = [i, ...List<int>.filled(b.length, 0)];
    for (var j = 1; j <= b.length; j++) {
      current[j] = math.min(
        math.min(current[j - 1] + 1, previous[j] + 1),
        previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
      );
    }
    previous = current;
  }
  return previous[b.length];
}

/// خيارٌ التقى بكلام الطفل: رقمُه، ودرجتُه، وهل قيلت كلماتُه كلُّها.
class SpokenMatch {
  const SpokenMatch(this.index, this.score, {required this.complete});

  final int index;
  final double score;

  /// قيلت كلُّ كلمات الخيار («سورة الفاتحة» لا «سورة» وحدها): كلامٌ لم ينتهِ
  /// بعد يُؤخذ به في لحظته إن اكتمل الاسم، وإلا انتُظر آخرُه.
  final bool complete;
}

/// كلماتُ خياراتٍ مقطّعةٌ مرّةً واحدة، فتُطابَق عليها كلُّ كلمةٍ جزئيةٍ يسمعها
/// المايك في لحظتها — بلا إعادة تقطيعٍ مع كل مقطع.
class SpokenIndex {
  SpokenIndex(List<String> options) : _words = [for (final option in options) spokenWords(option)];

  final List<List<String>> _words;

  int get length => _words.length;

  /// الخياراتُ الأعلى درجةً (أكثرُ من واحدٍ إن تعادلت)، أو فارغةٌ إن لم يلتقِ
  /// الكلامُ بشيء. [only]: يُقصر البحثُ على هذه الأرقام.
  List<SpokenMatch> best(String spoken, {Iterable<int>? only}) {
    final said = spokenWords(spoken).toSet();
    if (said.isEmpty) return const [];
    var top = 0.0;
    var winners = <SpokenMatch>[];
    for (final i in only ?? List<int>.generate(_words.length, (i) => i)) {
      final written = _words[i];
      if (written.isEmpty) continue;
      final hits = said.where((s) => written.any((w) => _close(s, w))).length;
      if (hits == 0) continue;
      // ‏الأقربُ ما التقى بأكثر كلماته، ثم الأخصُّ (أقلُّ كلماتٍ زائدة).
      final score = hits + hits / (written.length + 1);
      final complete = written.every((w) => said.any((s) => _close(s, w)));
      if (score > top + 1e-9) {
        top = score;
        winners = [SpokenMatch(i, score, complete: complete)];
      } else if ((score - top).abs() <= 1e-9) {
        winners.add(SpokenMatch(i, score, complete: complete));
      }
    }
    return winners;
  }
}

/// الخيارُ الذي قصده الطفلُ من [options] — رقمُه، أو `null` إن لم يُفهم أو
/// تعادل خياران.
int? matchSpoken(String spoken, List<String> options) {
  final winners = SpokenIndex(options).best(spoken);
  return winners.length == 1 ? winners.single.index : null;
}

/// اسمُ الطالب كما قاله: الاسمُ الأوّل والثاني معاً («جوري داود»)، لا الأوّلُ
/// وحده — فلا يدخل طالبٌ بحساب زميلٍ يشاركه اسمَه الأوّل. ومن ليس له في
/// حسابه إلا اسمٌ واحد يكفيه ذاك. ولا يُختار أحدٌ إن انطبق الكلامُ على اسمين.
int? matchFullName(String spoken, List<String> names) {
  final said = spokenWords(spoken).toSet();
  if (said.isEmpty) return null;
  int? found;
  for (var i = 0; i < names.length; i++) {
    final required = spokenWords(names[i]).take(2).toList();
    if (required.isEmpty) continue;
    if (!required.every((w) => said.any((s) => _close(s, w)))) continue;
    if (found != null) return null;
    found = i;
  }
  return found;
}
