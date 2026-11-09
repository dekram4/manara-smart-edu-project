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

/// أشياءُ كل قصّة: ما يُقطف ويُجمع، وما يطير، وما يوضع في الصحون، وما يُوزَّع.
const _storyItems = <KgSign, List<String>>{
  KgSign.plus: ['🍎', '🍊', '🍓', '🍌', '🍐'],
  KgSign.minus: ['🎈', '🐦', '🦋'],
  KgSign.times: ['🍪', '🍓', '🧁', '🍩'],
  KgSign.divide: ['⭐', '🍬', '🍪', '🍎'],
};

/// مسألةٌ مصوّرة على قدر طفل الروضة، لكل عمليةٍ قصّتُها:
///   • جمع: [a] على الشجرة و[b] في السلّة — كم الكلّ؟ (حتى ٨)
///   • طرح: [a] بالونات طار منها [b] — كم بقي؟ (من ٦ فأقلّ)
///   • ضرب: [a] صحون في كلٍّ منها [b] — كم الكلّ؟ (حتى ٩)
///   • قسمة: [a] نوزّعها على [b] صناديق بالتساوي — كم في كل صندوق؟ (حتى ٩)
class KgStory {
  const KgStory(this.a, this.b, this.sign, this.item);

  final int a;
  final int b;
  final KgSign sign;
  final String item;

  int get result => switch (sign) {
        KgSign.plus => a + b,
        KgSign.minus => a - b,
        KgSign.times => a * b,
        KgSign.divide => a ~/ b,
      };
}

/// كلماتُ العمليات بصوتٍ مسجّل، تُقرأ بها المعادلة: «ثلاثة زائد اثنين، كم يساوي؟».
const kgOperatorClips = <KgSign, String>{
  KgSign.plus: 'audio/kg_games/op_plus.mp3',
  KgSign.minus: 'audio/kg_games/op_minus.mp3',
  KgSign.times: 'audio/kg_games/op_times.mp3',
  KgSign.divide: 'audio/kg_games/op_divide.mp3',
};
const kgHowMuchClip = 'audio/kg_games/how_much.mp3';

/// اسمُ عددٍ بصوتٍ مسجّل (٠–١٠٠) — انظر tool/build_tracing_voices.py.
String kgNumberClip(int n) => 'audio/numbers_ar/n_$n.mp3';

// ── السؤال ────────────────────────────────────────────────────────────

class KgVoiceQuestion {
  const KgVoiceQuestion._({
    required this.kind,
    required this.answer,
    required this.distractors,
    required this.promptClip,
    this.followUpClips = const [],
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

  /// ما يُسمع بعده بترتيبه: المعادلةُ مقروءةً في المسائل المصوّرة.
  final List<String> followUpClips;

  /// كلُّ مقاطع السؤال بترتيبها.
  List<String> get promptClips => [promptClip, ...followUpClips];

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

/// جولةُ الحساب: مسألتان مصوّرتان لكل عملية (جمعٌ وطرحٌ وضربٌ وقسمة)، وسؤالان
/// عن اسم العلامة — مخلوطةً بلا عمليتين متتاليتين متطابقتين ما أمكن.
List<KgVoiceQuestion> _mathRound(math.Random random, int count) {
  final signQuestions = count >= 6 ? 2 : 0;
  final stories = <KgStory>[];
  final seen = <String>{};
  var op = 0;
  while (stories.length < count - signQuestions) {
    final sign = KgSign.values[op % KgSign.values.length];
    final story = _story(sign, random);
    if (!seen.add('${story.a}${story.sign}${story.b}')) continue;
    stories.add(story);
    op++;
  }
  final questions = <KgVoiceQuestion>[
    for (final sign in _deal(KgSign.values, signQuestions, random))
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
    for (final story in stories)
      KgVoiceQuestion._(
        kind: KgVoiceGameKind.math,
        answer: kgNumberOption(story.result),
        distractors: [for (final n in _wrongNumbers(story.result, random)) kgNumberOption(n)],
        promptClip: kgQuestionResultClip,
        followUpClips: [
          kgNumberClip(story.a),
          kgOperatorClips[story.sign]!,
          kgNumberClip(story.b),
          kgHowMuchClip,
        ],
        story: story,
      ),
  ]..shuffle(random);
  // ‏عمليتان متتاليتان متطابقتان تُفصلان.
  KgSign? opOf(KgVoiceQuestion q) => q.story?.sign ?? q.sign;
  for (var i = 1; i < questions.length; i++) {
    if (opOf(questions[i - 1]) == opOf(questions[i])) {
      final swap = questions.indexWhere((q) => opOf(q) != opOf(questions[i - 1]), i + 1);
      if (swap > 0) {
        final tmp = questions[i];
        questions[i] = questions[swap];
        questions[swap] = tmp;
      }
    }
  }
  return questions;
}

/// ثلاثةُ أعدادٍ قريبةٍ من الجواب لأزرار الاختيار.
Set<int> _wrongNumbers(int result, math.Random random) {
  final wrong = <int>{};
  for (final delta in [1, -1, 2, -2, 3]..shuffle(random)) {
    final n = result + delta;
    if (n >= 0 && n <= 10) wrong.add(n);
    if (wrong.length == 3) break;
  }
  return wrong;
}

/// مسألةٌ صغيرة لطفل الروضة من العملية [sign].
KgStory _story(KgSign sign, math.Random random) {
  final items = _storyItems[sign]!;
  final item = items[random.nextInt(items.length)];
  switch (sign) {
    case KgSign.plus:
      return KgStory(1 + random.nextInt(4), 1 + random.nextInt(4), sign, item);
    case KgSign.minus:
      final a = 2 + random.nextInt(5);
      return KgStory(a, 1 + random.nextInt(math.min(3, a - 1)), sign, item);
    case KgSign.times:
      // ‏صحنان أو ثلاثة، في كلٍّ منها شيءٌ إلى ثلاثة.
      return KgStory(2 + random.nextInt(2), 1 + random.nextInt(3), sign, item);
    case KgSign.divide:
      // ‏صندوقان أو ثلاثة، ونصيبُ كلٍّ منها شيءٌ إلى ثلاثة.
      final boxes = 2 + random.nextInt(2);
      final each = 1 + random.nextInt(3);
      return KgStory(boxes * each, boxes, sign, item);
  }
}
