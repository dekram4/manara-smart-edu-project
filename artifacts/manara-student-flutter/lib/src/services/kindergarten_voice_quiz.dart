import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'tracing_scope.dart';

/// ألعابُ الروضة الصوتية في «الثقافة العامة»: الألوانُ والأشكالُ والحساب.
///
/// ── الجولة ──
/// عشرةُ أسئلةٍ عشوائية في كل مرّة ([buildKgVoiceRound]): يظهر لونٌ أو شكلٌ أو
/// علامةٌ أو مسألةٌ مصوّرة، ويُسمع سؤالُها المسجّل، فيضغط الطفلُ المايكَ ويقول
/// الجواب. والجوابُ يُقبل بكل صيغةٍ يقولها طفل: «حمرا» و«أحمر» و«الأحمر»،
/// «زائد» و«جمع»، «تلاتة» و«٣» و«3» ([KgVoiceQuestion.judge]).
///
/// ── منطقٌ بلا واجهة ──
/// كلُّه هنا ليُختبر وحده: توليدُ الأسئلة ومطابقةُ ما سمعه المحرّك. والشاشةُ
/// في `kindergarten_voice_games.dart`.

enum KgVoiceGameKind { colors, shapes, math }

/// مقاطعُ الأسئلة والإجابة الخاطئة، بلا بادئة `assets/`: حزمةُ الصوت تضيفها.
const kgQuestionColorClip = 'audio/kg_games/question_color.mp3';
const kgQuestionShapeClip = 'audio/kg_games/question_shape.mp3';
const kgQuestionSignClip = 'audio/kg_games/question_sign.mp3';
const kgQuestionResultClip = 'audio/kg_games/question_result.mp3';
const kgWrongAnswerClip = 'audio/kg_games/wrong_answer.mp3';

/// عددُ أسئلة الجولة.
const kgVoiceRoundLength = 10;

/// مادّةُ «الثقافة العامة» — بأيّ همزةٍ أو تاءٍ كُتبت، أو بالإنجليزية.
bool isGeneralCultureSubject(String? subject) {
  final key = kgNormalize(subject ?? '');
  return RegExp(r'ثقافه|general knowledge|general culture').hasMatch(key);
}

/// تظهر الألعابُ الثلاث في درس «الثقافة العامة» بالروضة وحده.
bool kgVoiceGamesAllowedFor({required String? grade, required String? subject}) =>
    isKindergartenGrade(grade) && isGeneralCultureSubject(subject);

// ── التطبيع ───────────────────────────────────────────────────────────

final _tashkeel = RegExp('[ً-ْٰـ]');
final _punctuation = RegExp(r'''[.,!?؟،؛:"'()\[\]{}\-_/\\]''');

/// يوحّد ما يكتبه المحرّك: بلا تشكيل ولا همزات ولا تاء مربوطة، وأرقامٌ
/// غربية، وحروفٌ صغيرة.
String kgNormalize(String text) {
  var out = text.toLowerCase().replaceAll(_tashkeel, '').replaceAll(_punctuation, ' ');
  out = out
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll('ء', '')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < eastern.length; i++) {
    out = out.replaceAll(eastern[i], '$i');
  }
  return out.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// كلماتُ ما قيل، كلٌّ منها بلا «ال» ولا «و» العطف في أوّله.
List<String> _tokens(String heard) {
  final words = kgNormalize(heard).split(' ').where((w) => w.isNotEmpty);
  final out = <String>[];
  for (final word in words) {
    out.add(word);
    var w = word;
    if (w.startsWith('و') && w.length > 3) w = w.substring(1);
    if (w.startsWith('ال') && w.length > 3) w = w.substring(2);
    if (w != word) out.add(w);
  }
  return out;
}

/// خيارٌ يُجاب به: اسمُه للعرض، وكلُّ ما يُقبل منه.
class KgVoiceOption {
  const KgVoiceOption(this.id, this.label, this.words);

  final String id;

  /// يُعرض للطفل ويُنطق عند كشف الجواب.
  final String label;

  /// الصيغُ المقبولة، مطبَّعةً ([kgNormalize]).
  final List<String> words;

  bool heardIn(List<String> tokens) => tokens.any(words.contains);
}

// ── الألوان ───────────────────────────────────────────────────────────

class KgColor {
  const KgColor(this.option, this.color);

  final KgVoiceOption option;
  final Color color;
}

const kgColors = <KgColor>[
  KgColor(KgVoiceOption('white', 'أبيض', ['ابيض', 'بيضا', 'بيضه', 'white']), Color(0xFFFFFFFF)),
  KgColor(KgVoiceOption('black', 'أسود', ['اسود', 'سودا', 'سوده', 'black']), Color(0xFF111111)),
  KgColor(KgVoiceOption('red', 'أحمر', ['احمر', 'حمرا', 'حمره', 'red']), Color(0xFFE11D2E)),
  KgColor(KgVoiceOption('green', 'أخضر', ['اخضر', 'خضرا', 'خضره', 'green']), Color(0xFF16A34A)),
  KgColor(KgVoiceOption('blue', 'أزرق', ['ازرق', 'زرقا', 'زرقه', 'blue']), Color(0xFF1D4ED8)),
  KgColor(KgVoiceOption('yellow', 'أصفر', ['اصفر', 'صفرا', 'صفره', 'yellow']), Color(0xFFFACC15)),
  KgColor(
    KgVoiceOption('purple', 'بنفسجي', ['بنفسجي', 'بنفسجيه', 'بنفسج', 'موف', 'ليلكي', 'purple', 'violet']),
    Color(0xFF7E22CE),
  ),
  KgColor(KgVoiceOption('brown', 'بني', ['بني', 'بنيه', 'بنا', 'بن', 'brown']), Color(0xFF7C4A21)),
  KgColor(KgVoiceOption('pink', 'وردي', ['وردي', 'ورديه', 'زهري', 'زهريه', 'بمبي', 'pink']), Color(0xFFF472B6)),
  KgColor(KgVoiceOption('orange', 'برتقالي', ['برتقالي', 'برتقاليه', 'برتقال', 'orange']), Color(0xFFF97316)),
  KgColor(
    KgVoiceOption('gray', 'رمادي', ['رمادي', 'رماديه', 'رصاصي', 'رصاصيه', 'gray', 'grey']),
    Color(0xFF9CA3AF),
  ),
];

// ── الأشكال ───────────────────────────────────────────────────────────

enum KgShape { circle, rectangle, square, parallelogram, sphere, cube, pyramid }

const kgShapes = <KgShape, KgVoiceOption>{
  KgShape.circle: KgVoiceOption('circle', 'دائرة', ['دايره', 'داير', 'دوايره', 'circle']),
  KgShape.rectangle: KgVoiceOption('rectangle', 'مستطيل', ['مستطيل', 'مستطيله', 'rectangle']),
  KgShape.square: KgVoiceOption('square', 'مربع', ['مربع', 'مربعه', 'square']),
  KgShape.parallelogram: KgVoiceOption(
    'parallelogram',
    'متوازي الأضلاع',
    ['متوازي', 'متوازيه', 'اضلاع', 'parallelogram'],
  ),
  KgShape.sphere: KgVoiceOption('sphere', 'كرة', ['كره', 'كوره', 'كرا', 'ball', 'sphere']),
  KgShape.cube: KgVoiceOption('cube', 'مكعب', ['مكعب', 'مكعبه', 'cube']),
  KgShape.pyramid: KgVoiceOption('pyramid', 'هرم', ['هرم', 'هرمي', 'pyramid']),
};

// ── الحساب ────────────────────────────────────────────────────────────

enum KgSign { plus, minus, times, divide }

const kgSigns = <KgSign, (String, KgVoiceOption)>{
  KgSign.plus: ('+', KgVoiceOption('plus', 'جمع', ['جمع', 'زايد', 'زائد', 'زاد', 'اضافه', 'plus', 'add'])),
  KgSign.minus: ('−', KgVoiceOption('minus', 'طرح', ['طرح', 'ناقص', 'نقص', 'minus', 'subtract'])),
  KgSign.times: ('×', KgVoiceOption('times', 'ضرب', ['ضرب', 'مضروب', 'اضرب', 'times', 'multiply'])),
  KgSign.divide: ('÷', KgVoiceOption('divide', 'قسمة', ['قسمه', 'تقسيم', 'مقسوم', 'قسم', 'divide'])),
};

/// الأعدادُ من صفر إلى عشرة بكل ما يقوله الطفل (والأرقامُ تُقرأ وحدها).
const _numberWords = <int, List<String>>{
  0: ['صفر', 'zero'],
  1: ['واحد', 'واحده', 'one'],
  2: ['اثنين', 'اثنان', 'اثنتين', 'اثنتان', 'اتنين', 'ثنين', 'two'],
  3: ['ثلاثه', 'ثلاث', 'تلاته', 'تلات', 'three'],
  4: ['اربعه', 'اربع', 'four'],
  5: ['خمسه', 'خمس', 'five'],
  6: ['سته', 'ست', 'سيته', 'six'],
  7: ['سبعه', 'سبع', 'seven'],
  8: ['ثمانيه', 'ثماني', 'ثمان', 'تمانيه', 'تمنيه', 'eight'],
  9: ['تسعه', 'تسع', 'nine'],
  10: ['عشره', 'عشر', 'ten'],
};

const _numberNames = ['صفر', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة', 'عشرة'];

KgVoiceOption kgNumberOption(int n) => KgVoiceOption('n$n', '$n — ${_numberNames[n]}', [..._numberWords[n]!, '$n']);

/// أشياءُ المسائل المصوّرة: تفاحٌ في اليد وفي الشجرة، وبالوناتٌ تطير…
const _storyItems = ['🍎', '🍊', '🍓', '⭐', '🎈', '🐟', '🌸', '🍌', '🧁', '🐥'];

/// مسألةٌ مصوّرة: [a] [sign] [b] = ؟ — جمعٌ حاصلُه عشرةٌ فأقلّ، أو طرحٌ لا
/// يقلّ عن صفر.
class KgStory {
  const KgStory(this.a, this.b, this.sign, this.item);

  final int a;
  final int b;
  final KgSign sign;
  final String item;

  int get result => sign == KgSign.plus ? a + b : a - b;
}

// ── السؤال ────────────────────────────────────────────────────────────

class KgVoiceQuestion {
  const KgVoiceQuestion._({
    required this.kind,
    required this.answer,
    required this.distractors,
    required this.promptClip,
    this.color,
    this.shape,
    this.sign,
    this.story,
  });

  final KgVoiceGameKind kind;
  final KgVoiceOption answer;

  /// خياراتٌ أخرى من النوع نفسه: لمطابقة ما قيل (جوابٌ يذكر لونين لا يُقبل)،
  /// ولأزرار الاختيار إن لم يكن المايكُ متاحاً.
  final List<KgVoiceOption> distractors;

  /// السؤالُ المسجّل الذي يُسمع مع ظهوره.
  final String promptClip;

  final Color? color;
  final KgShape? shape;
  final KgSign? sign;
  final KgStory? story;

  /// ما قيل يطابق الجواب — ولا يذكر خياراً آخر من نوعه معه.
  bool judge(String heard) {
    final tokens = _tokens(heard);
    if (tokens.isEmpty) return false;
    if (story != null) {
      // ‏آخرُ عددٍ قيل هو الجواب: «خمسة»، أو المسألةُ كلُّها «ثلاثة زائد اثنين
      // ‏يساوي خمسة».
      final said = kgNumbersIn(heard);
      return said.isNotEmpty && said.last == story!.result;
    }
    if (!answer.heardIn(tokens)) return false;
    return !distractors.any((other) => other.heardIn(tokens));
  }
}

/// الأعدادُ المذكورة فيما قيل بترتيبها، أرقاماً أو كلمات.
List<int> kgNumbersIn(String heard) {
  final found = <int>[];
  for (final word in kgNormalize(heard).split(' ')) {
    final digits = int.tryParse(word);
    if (digits != null) {
      found.add(digits);
      continue;
    }
    final forms = _tokens(word);
    for (final entry in _numberWords.entries) {
      if (forms.any(entry.value.contains)) {
        found.add(entry.key);
        break;
      }
    }
  }
  return found;
}

/// عشرةُ أسئلةٍ عشوائية، بلا سؤالين متتاليين متطابقين.
List<KgVoiceQuestion> buildKgVoiceRound(KgVoiceGameKind kind, math.Random random, {int count = kgVoiceRoundLength}) {
  return switch (kind) {
    KgVoiceGameKind.colors => _colorRound(random, count),
    KgVoiceGameKind.shapes => _shapeRound(random, count),
    KgVoiceGameKind.math => _mathRound(random, count),
  };
}

/// عناصرُ [pool] بترتيبٍ عشوائي، تتكرّر إن قلّت عن [count] ولا يتجاور مثلان.
List<T> _deal<T>(List<T> pool, int count, math.Random random) {
  final out = <T>[];
  while (out.length < count) {
    final deck = [...pool]..shuffle(random);
    if (out.isNotEmpty && deck.first == out.last && deck.length > 1) {
      deck.add(deck.removeAt(0));
    }
    out.addAll(deck);
  }
  return out.sublist(0, count);
}

List<KgVoiceQuestion> _colorRound(math.Random random, int count) => [
      for (final c in _deal(kgColors, count, random))
        KgVoiceQuestion._(
          kind: KgVoiceGameKind.colors,
          answer: c.option,
          distractors: [for (final other in kgColors) if (other != c) other.option],
          promptClip: kgQuestionColorClip,
          color: c.color,
        ),
    ];

List<KgVoiceQuestion> _shapeRound(math.Random random, int count) => [
      for (final shape in _deal(KgShape.values, count, random))
        KgVoiceQuestion._(
          kind: KgVoiceGameKind.shapes,
          answer: kgShapes[shape]!,
          distractors: [
            for (final entry in kgShapes.entries)
              if (entry.key != shape) entry.value,
          ],
          promptClip: kgQuestionShapeClip,
          shape: shape,
        ),
    ];

/// نصفُ الجولة علاماتٌ تُسمّى، ونصفُها مسائلُ مصوّرة يُقال ناتجُها — مخلوطةً.
List<KgVoiceQuestion> _mathRound(math.Random random, int count) {
  final signs = _deal(KgSign.values, count ~/ 2, random);
  final questions = <KgVoiceQuestion>[
    for (final sign in signs)
      KgVoiceQuestion._(
        kind: KgVoiceGameKind.math,
        answer: kgSigns[sign]!.$2,
        distractors: [
          for (final entry in kgSigns.entries)
            if (entry.key != sign) entry.value.$2,
        ],
        promptClip: kgQuestionSignClip,
        sign: sign,
      ),
  ];
  final seen = <String>{};
  while (questions.length < count) {
    final story = _story(random);
    if (!seen.add('${story.a}${story.sign}${story.b}')) continue;
    final wrong = <int>{};
    while (wrong.length < 3) {
      final n = random.nextInt(11);
      if (n != story.result) wrong.add(n);
    }
    questions.add(
      KgVoiceQuestion._(
        kind: KgVoiceGameKind.math,
        answer: kgNumberOption(story.result),
        distractors: [for (final n in wrong) kgNumberOption(n)],
        promptClip: kgQuestionResultClip,
        story: story,
      ),
    );
  }
  questions.shuffle(random);
  // ‏علامتان متتاليتان متطابقتان تُفصلان.
  for (var i = 1; i < questions.length; i++) {
    final prev = questions[i - 1].sign;
    if (prev != null && prev == questions[i].sign) {
      final swap = questions.indexWhere((q) => q.sign != prev, i + 1);
      if (swap > 0) {
        final tmp = questions[i];
        questions[i] = questions[swap];
        questions[swap] = tmp;
      }
    }
  }
  return questions;
}

/// مسألةٌ صغيرة لطفل الروضة: الأعدادُ من ١ إلى ٥، والجمعُ حتى العشرة، والطرحُ
/// من الأكبر.
KgStory _story(math.Random random) {
  final item = _storyItems[random.nextInt(_storyItems.length)];
  if (random.nextBool()) {
    final a = 1 + random.nextInt(5);
    final b = 1 + random.nextInt(5);
    return KgStory(a, b, KgSign.plus, item);
  }
  final a = 2 + random.nextInt(4);
  final b = 1 + random.nextInt(a - 1);
  return KgStory(a, b, KgSign.minus, item);
}
