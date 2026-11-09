import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/painting.dart';

import 'tracing_scope.dart';

/// ألعابُ الروضة الصوتية في «الثقافة العامة»: الألوانُ والأشكالُ والحساب،
/// وأسئلةُ الروضة العامة (الفصولُ والحيواناتُ والأيامُ والبيئة).
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

enum KgVoiceGameKind { colors, shapes, math, general }

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
  const KgVoiceOption(this.id, this.label, this.words, {this.emoji = ''});

  final String id;

  /// رمزٌ يُرى على زرّ الخيار — لطفلٍ لا يقرأ بعد.
  final String emoji;

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
    this.general,
  });

  /// السؤالُ العامّ [q] كما يُسأل في الجولة.
  factory KgVoiceQuestion._general(KgGeneralQuestion q) => KgVoiceQuestion._(
        kind: KgVoiceGameKind.general,
        answer: q.answer,
        distractors: q.others,
        promptClip: q.clip,
        general: q,
      );

  @visibleForTesting
  factory KgVoiceQuestion.generalForTest(KgGeneralQuestion q) = KgVoiceQuestion._general;

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
  final KgGeneralQuestion? general;

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
    KgVoiceGameKind.general => _generalRound(random, count),
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

// ── أسئلةُ الروضة العامة ─────────────────────────────────────────────

/// موضوعاتُ الأسئلة العامة: الفصولُ والحيواناتُ وألوانُ ما حولنا والأيامُ
/// وبيئةُ الطفل.
enum KgTopic { seasons, animals, colors, days, environment }

/// سؤالٌ عامّ: نصُّه يُعرض ويُسمع بمقطعه المسجّل ([clip])، ومشهدُه رموزٌ
/// تتحرّك ([scene])، والجوابُ وثلاثةُ خياراتٍ أخرى.
class KgGeneralQuestion {
  const KgGeneralQuestion(this.id, this.topic, this.text, this.scene, this.answer, this.others);

  final String id;
  final KgTopic topic;

  /// بتشكيله: يقرؤه مولّدُ المقاطع (tool/build_kg_general_voices.py) كما هو.
  final String text;
  final String scene;
  final KgVoiceOption answer;
  final List<KgVoiceOption> others;

  String get clip => 'audio/kg_games/general/$id.mp3';
}

/// خيارٌ عامّ: كلماتُه تُطبَّع، وتُقبل كلٌّ منها بـ«ال» وبدونها — فـ«والصيف»
/// تُفهم «صيف» كما تُفهم «الصيف».
KgVoiceOption _o(String id, String label, String emoji, List<String> words) => KgVoiceOption(
      id,
      label,
      {
        for (final w in words.map(kgNormalize)) ...[
          w,
          if (w.startsWith('ال') && w.length > 3) w.substring(2),
        ],
      }.toList(),
      emoji: emoji,
    );

final _winter = _o('winter', 'الشتاء', '❄️', ['الشتاء', 'شتا', 'شتوي', 'winter']);
final _summer = _o('summer', 'الصيف', '☀️', ['الصيف', 'صيفي', 'summer']);
final _spring = _o('spring', 'الربيع', '🌸', ['الربيع', 'ربيعي', 'spring']);
final _autumn = _o('autumn', 'الخريف', '🍂', ['الخريف', 'autumn', 'fall']);

final _cat = _o('cat', 'القطة', '🐱', ['قطة', 'قطط', 'قطوة', 'بسة', 'بسبس', 'بسه', 'cat']);
final _dog = _o('dog', 'الكلب', '🐶', ['كلب', 'dog']);
final _cow = _o('cow', 'البقرة', '🐄', ['بقرة', 'بقر', 'cow']);
final _lion = _o('lion', 'الأسد', '🦁', ['أسد', 'lion']);
final _fish = _o('fish', 'السمكة', '🐟', ['سمكة', 'سمك', 'fish']);
final _giraffe = _o('giraffe', 'الزرافة', '🦒', ['زرافة', 'giraffe']);
final _bird = _o('bird', 'العصفور', '🐦', ['عصفور', 'عصفورة', 'عصافير', 'طير', 'طيور', 'bird']);
final _elephant = _o('elephant', 'الفيل', '🐘', ['فيل', 'elephant']);
final _sheep = _o('sheep', 'الخروف', '🐑', ['خروف', 'غنم', 'sheep']);
final _rabbit = _o('rabbit', 'الأرنب', '🐰', ['أرنب', 'rabbit']);

KgVoiceOption _color(String id) => kgColors.firstWhere((c) => c.option.id == id).option;

final _saturday = _o('saturday', 'السبت', '📅', ['السبت', 'سبت']);
final _sunday = _o('sunday', 'الأحد', '📅', ['الأحد', 'احد', 'حد']);
final _monday = _o('monday', 'الاثنين', '📅', ['الاثنين', 'اثنين', 'الاتنين', 'اتنين', 'تنين']);
final _tuesday = _o('tuesday', 'الثلاثاء', '📅', ['الثلاثاء', 'ثلاثاء', 'تلات', 'التلات']);
final _wednesday = _o('wednesday', 'الأربعاء', '📅', ['الأربعاء', 'أربعاء', 'الاربع']);
final _thursday = _o('thursday', 'الخميس', '📅', ['الخميس', 'خميس']);
final _friday = _o('friday', 'الجمعة', '📅', ['الجمعة', 'جمعة']);

final _bin = _o('bin', 'سلة المهملات', '🗑️', ['سلة', 'المهملات', 'مهملات', 'الزبالة', 'زبالة', 'القمامة', 'قمامة']);
final _street = _o('street', 'الشارع', '🛣️', ['شارع', 'الطريق', 'طريق']);
final _sea = _o('sea', 'البحر', '🌊', ['بحر']);
final _garden = _o('garden', 'الحديقة', '🏞️', ['حديقة', 'جنينة']);
final _tap = _o('tap', 'الصنبور', '🚰', ['صنبور', 'حنفية', 'بزبوز', 'الماء', 'ماء', 'مويه']);
final _door = _o('door', 'الباب', '🚪', ['باب']);
final _window = _o('window', 'النافذة', '🪟', ['نافذة', 'شباك', 'الشباك']);
final _book = _o('book', 'الكتاب', '📖', ['كتاب']);
final _trees = _o('trees', 'الأشجار', '🌳', ['أشجار', 'شجر', 'شجرة', 'ورد', 'زهور', 'نباتات']);
final _stones = _o('stones', 'الحجارة', '🪨', ['حجارة', 'حجر']);
final _cars = _o('cars', 'السيارات', '🚗', ['سيارات', 'سيارة']);
final _bags = _o('bags', 'الأكياس', '🛍️', ['أكياس', 'كيس']);
final _firefighter = _o('firefighter', 'رجل الإطفاء', '🚒', ['الإطفاء', 'اطفاء', 'الاطفائي', 'اطفائي', 'المطافي', 'مطافي']);
final _doctor = _o('doctor', 'الطبيب', '🩺', ['طبيب', 'طبيبة', 'دكتور', 'دكتورة', 'الدكتور']);
final _teacher = _o('teacher', 'المعلم', '📚', ['معلم', 'معلمة', 'استاذ', 'أستاذة', 'مدرس', 'مدرسة']);
final _baker = _o('baker', 'الخباز', '🥖', ['خباز']);
final _police = _o('police', 'الشرطي', '👮', ['شرطي', 'الشرطة', 'شرطة', 'بوليس']);
final _night = _o('night', 'الليل', '🌙', ['الليل', 'ليل', 'بالليل', 'ليلا']);
final _morning = _o('morning', 'الصباح', '🌅', ['الصباح', 'صباح', 'الصبح', 'صبح']);
final _noon = _o('noon', 'الظهر', '🌞', ['الظهر', 'ظهر']);
final _afternoon = _o('afternoon', 'العصر', '🌇', ['العصر', 'عصر']);
final _brush = _o('brush', 'فرشاة الأسنان', '🪥', ['فرشاة', 'فرشة', 'الفرشه', 'المعجون', 'معجون']);
final _spoon = _o('spoon', 'الملعقة', '🥄', ['ملعقة', 'معلقة']);
final _pencil = _o('pencil', 'القلم', '✏️', ['قلم']);
final _ball = _o('ball', 'الكرة', '⚽', ['كرة', 'كورة']);

/// الأسئلةُ العامة كلُّها؛ والجولةُ عشرةٌ منها بموضوعاتٍ متعاقبة.
final kgGeneralQuestions = <KgGeneralQuestion>[
  KgGeneralQuestion('season_winter', KgTopic.seasons, 'ما هُوَ فَصْلُ السَّنَةِ الَّذي يَتَمَيَّزُ بِالبَرْدِ وَالأَمْطار؟',
      '🌧️☃️❄️', _winter, [_summer, _spring, _autumn]),
  KgGeneralQuestion('season_summer', KgTopic.seasons, 'في أَيِّ فَصْلٍ يَكونُ الجَوُّ حارّاً وَنَسْبَحُ في البَحْر؟',
      '☀️🏖️🍉', _summer, [_winter, _spring, _autumn]),
  KgGeneralQuestion('season_spring', KgTopic.seasons, 'في أَيِّ فَصْلٍ تَتَفَتَّحُ الأَزْهارُ وَيَخْضَرُّ العُشْب؟',
      '🌷🦋🌼', _spring, [_winter, _summer, _autumn]),
  KgGeneralQuestion('season_autumn', KgTopic.seasons, 'في أَيِّ فَصْلٍ تَتَساقَطُ أَوْراقُ الأَشْجار؟',
      '🍁🌬️🍂', _autumn, [_winter, _summer, _spring]),
  KgGeneralQuestion('animal_meow', KgTopic.animals, 'أَيُّ حَيَوانٍ يَقولُ: مِياو؟', '🧶🥛🐾', _cat, [_dog, _cow, _lion]),
  KgGeneralQuestion('animal_milk', KgTopic.animals, 'أَيُّ حَيَوانٍ يُعْطينا الحَليب؟', '🥛🧀🌾', _cow, [_lion, _fish, _bird]),
  KgGeneralQuestion('animal_king', KgTopic.animals, 'مَنْ هُوَ مَلِكُ الغابَة؟', '👑🌴🌴', _lion, [_rabbit, _cat, _sheep]),
  KgGeneralQuestion('animal_water', KgTopic.animals, 'أَيُّ حَيَوانٍ يَعيشُ في الماءِ وَيَسْبَح؟', '🌊💧🐚', _fish,
      [_cat, _lion, _elephant]),
  KgGeneralQuestion('animal_neck', KgTopic.animals, 'أَيُّ حَيَوانٍ لَهُ رَقَبَةٌ طَويلَةٌ جِدّاً؟', '🌳🍃🌳', _giraffe,
      [_elephant, _rabbit, _dog]),
  KgGeneralQuestion('animal_fly', KgTopic.animals, 'أَيُّ حَيَوانٍ يَطيرُ في السَّماء؟', '☁️🌤️☁️', _bird,
      [_fish, _cow, _elephant]),
  KgGeneralQuestion('animal_trunk', KgTopic.animals, 'أَيُّ حَيَوانٍ لَهُ خُرْطومٌ طَويل؟', '🥜🌿💦', _elephant,
      [_giraffe, _lion, _sheep]),
  KgGeneralQuestion('animal_carrot', KgTopic.animals, 'أَيُّ حَيَوانٍ يُحِبُّ أَكْلَ الجَزَر؟', '🥕🥕🥕', _rabbit,
      [_lion, _fish, _dog]),
  KgGeneralQuestion('color_banana', KgTopic.colors, 'ما لَوْنُ المَوْز؟', '🍌🍌', _color('yellow'),
      [_color('red'), _color('blue'), _color('black')]),
  KgGeneralQuestion('color_sky', KgTopic.colors, 'ما لَوْنُ السَّماءِ في يَوْمٍ صافٍ؟', '🌤️🕊️', _color('blue'),
      [_color('green'), _color('red'), _color('brown')]),
  KgGeneralQuestion('color_grass', KgTopic.colors, 'ما لَوْنُ العُشْبِ وَأَوْراقِ الشَّجَر؟', '🌿🌳🍀', _color('green'),
      [_color('yellow'), _color('blue'), _color('pink')]),
  KgGeneralQuestion('color_strawberry', KgTopic.colors, 'ما لَوْنُ الفَراوِلَة؟', '🍓🍓', _color('red'),
      [_color('green'), _color('white'), _color('blue')]),
  KgGeneralQuestion('color_snow', KgTopic.colors, 'ما لَوْنُ الثَّلْج؟', '⛄❄️', _color('white'),
      [_color('black'), _color('orange'), _color('purple')]),
  KgGeneralQuestion('color_orange', KgTopic.colors, 'ما لَوْنُ البُرْتُقالَة؟', '🍊🍊', _color('orange'),
      [_color('blue'), _color('pink'), _color('gray')]),
  KgGeneralQuestion('days_week', KgTopic.days, 'كَمْ يَوْماً في الأُسْبوع؟', '📅🗓️', kgNumberOption(7),
      [kgNumberOption(5), kgNumberOption(6), kgNumberOption(8)]),
  KgGeneralQuestion('days_after_saturday', KgTopic.days, 'ما اليَوْمُ الَّذي يَأْتي بَعْدَ السَّبْت؟', '📅➡️', _sunday,
      [_monday, _friday, _thursday]),
  KgGeneralQuestion('days_after_thursday', KgTopic.days, 'ما اليَوْمُ الَّذي يَأْتي بَعْدَ الخَميس؟', '📅➡️', _friday,
      [_saturday, _sunday, _wednesday]),
  KgGeneralQuestion('days_before_tuesday', KgTopic.days, 'ما اليَوْمُ الَّذي يَأْتي قَبْلَ الثُّلاثاء؟', '⬅️📅', _monday,
      [_wednesday, _saturday, _thursday]),
  KgGeneralQuestion('days_before_thursday', KgTopic.days, 'ما اليَوْمُ الَّذي يَأْتي قَبْلَ الخَميس؟', '⬅️📅', _wednesday,
      [_tuesday, _friday, _sunday]),
  KgGeneralQuestion('env_trash', KgTopic.environment, 'أَيْنَ نَرْمي النُّفايات؟', '🧃🍌🥤', _bin, [_street, _sea, _garden]),
  KgGeneralQuestion('env_tap', KgTopic.environment, 'ماذا نُغْلِقُ بَعْدَ غَسْلِ أَيْدينا حَتّى لا يَضيعَ الماء؟', '🧼💧👐',
      _tap, [_door, _window, _book]),
  KgGeneralQuestion('env_plant', KgTopic.environment, 'ماذا نَزْرَعُ لِتُصْبِحَ بيئَتُنا خَضْراءَ جَميلَة؟', '🌱🌍💚',
      _trees, [_stones, _cars, _bags]),
  KgGeneralQuestion('env_fire', KgTopic.environment, 'مَنِ الَّذي يُطْفِئُ الحَرائِق؟', '🔥🧯', _firefighter,
      [_doctor, _teacher, _baker]),
  KgGeneralQuestion('env_doctor', KgTopic.environment, 'مَنِ الَّذي يُعالِجُ المَرْضى؟', '🤒💊', _doctor,
      [_firefighter, _teacher, _police]),
  KgGeneralQuestion('env_night', KgTopic.environment, 'مَتى نَرى القَمَرَ وَالنُّجوم؟', '🌙⭐✨', _night,
      [_morning, _noon, _afternoon]),
  KgGeneralQuestion('env_teeth', KgTopic.environment, 'بِماذا نُنَظِّفُ أَسْنانَنا؟', '🦷✨😁', _brush,
      [_spoon, _pencil, _ball]),
];

/// عشرةُ أسئلةٍ عامة: موضوعاتُها متعاقبةٌ (لا موضوعان متتاليان متطابقان)،
/// ولا يتكرّر سؤالٌ في الجولة، وتتبدّل كلَّ مرّة.
List<KgVoiceQuestion> _generalRound(math.Random random, int count) {
  final byTopic = {
    for (final topic in KgTopic.values)
      topic: [for (final q in kgGeneralQuestions) if (q.topic == topic) q]..shuffle(random),
  };
  final used = {for (final topic in KgTopic.values) topic: 0};
  final out = <KgVoiceQuestion>[];
  for (final topic in _deal(KgTopic.values, count, random)) {
    final pool = byTopic[topic]!;
    final n = used[topic]!;
    used[topic] = n + 1;
    final q = pool[n % pool.length];
    out.add(KgVoiceQuestion._general(q));
  }
  return out;
}
