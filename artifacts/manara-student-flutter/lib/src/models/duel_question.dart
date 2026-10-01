/// سؤالُ مبارزةٍ كما كتبه الخادم في صفّ المباراة.
///
/// ── ولماذا من الخادم لا يُبنى هنا ──
/// كان كلُّ جهازٍ يبني أسئلتَه من بذرةٍ هي معرّفُ المباراة، فعدلُ المباراة
/// معلّقٌ بأن يبقى حسابُ البذرة والترتيبُ متطابقين على الجهازين إلى الأبد:
/// نسخةٌ أقدمُ من التطبيق، أو بنكُ درسٍ تغيّر بين القراءتين، أو تعديلٌ في
/// الخلط — وكلُّها تُخرج أسئلةً مختلفةً **بلا خطأٍ يظهر**. كلُّ جهازٍ يعمل
/// وحده صحيحاً، والفرقُ لا يراه إلا من جمع الشاشتين.
///
/// والحزمةُ الآن تُكتب في الخادم مرّةً عند الدعوة، والجهازان يقرآن الصفَّ
/// نفسه: الأسئلةُ نفسها بالترتيب نفسه والخياراتُ في المواضع نفسها — لا
/// باتّفاقِ حسابين بل لأنها شيءٌ واحد.
class DuelQuestion {
  const DuelQuestion({
    required this.id,
    required this.category,
    required this.prompt,
    required this.options,
    required this.answerAt,
  });

  final String id;

  /// بابُ السؤال: `general` أو `logic` أو `quick` أو `school` أو `lesson`.
  final String category;

  final String prompt;
  final List<String> options;
  final int answerAt;

  /// ما يُعرض للطفل عنواناً للباب.
  String get categoryKey => 'duel.cat.$category';

  /// ── وكلُّ حقلٍ يُفحص ──
  /// الصفُّ قد يكون كُتب بنسخةٍ أقدم، أو ضاع منه حقل، أو جاء موضعُ الجواب
  /// خارج الخيارات — وكلُّها تُخرج سؤالاً لا جوابَ صحيحَ له بلا خطأٍ يظهر.
  static DuelQuestion? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = _text(raw['id']);
    final prompt = _text(raw['prompt']);
    if (id.isEmpty || prompt.isEmpty) return null;

    final options = <String>[];
    final list = raw['options'];
    if (list is List) {
      for (final option in list) {
        final value = _text(option);
        if (value.isNotEmpty) options.add(value);
      }
    }
    if (options.length < 2) return null;

    final answerAt = raw['answerAt'];
    if (answerAt is! int || answerAt < 0 || answerAt >= options.length) {
      return null;
    }

    final category = _text(raw['category']);
    return DuelQuestion(
      id: id,
      category: _known.contains(category) ? category : 'general',
      prompt: prompt,
      options: options,
      answerAt: answerAt,
    );
  }

  static const _known = {
    'domain',
    'general',
    'logic',
    'quick',
    'school',
    'lesson',
  };

  static String _text(Object? value) =>
      value is String ? value.trim() : '';
}

/// أقلُّ ما تُلعب به مباراة. وحزمةٌ أقصرُ منه تُترك للبنك المحليّ.
const int duelPackMin = 8;

/// يقرأ حزمةً كما تعيدها `claim_duel_pack`، أو `null` لما لا يُلعب.
///
/// ── ولا سؤالَ من الدرس ──
/// صفٌّ كتب حزمتَه خادمٌ أقدمُ فيها أسئلةُ الدرس الحرفية. فتُترك كلُّها، لا
/// السؤالُ وحده: حزمةٌ ناقصةٌ يلعبها جهازٌ وكاملةٌ يلعبها الآخر مباراتان.
List<DuelQuestion>? duelPackFrom(Object? raw) {
  if (raw is! Map) return null;
  final list = raw['questions'];
  if (list is! List) return null;
  final questions = <DuelQuestion>[];
  for (final entry in list) {
    final question = DuelQuestion.fromJson(entry);
    if (question == null) continue;
    if (question.category == 'lesson') return null;
    questions.add(question);
  }
  return questions.length < duelPackMin ? null : questions;
}

/// قواعدُ المباراة كما يُعلنها الخادم.
///
/// ── ولماذا تأتي منه لا تُكتب في التطبيق ──
/// الخادم يرفض نتيجةً تتجاوز سقفَه. فلو حسب التطبيقُ النقاطَ بأرقامٍ مكتوبةٍ
/// عنده وتغيّرت في الخادم، لُعبت مباراةٌ كاملةٌ ثم رُدّت نتيجتُها — ولا شيء
/// يقول للطفل لماذا.
class DuelRules {
  const DuelRules({
    this.questionSeconds = 10,
    this.pointsCorrect = 10,
    this.pointsSpeedMax = 5,
    this.maxScore = 150,
    this.announced = false,
  });

  /// هل أعلنها الخادمُ فعلاً؟ خادمٌ أقدمُ لا يعرف النقاط ويقبل عددَ الإجابات
  /// الصحيحة وحده — فتُرسل له نتيجةٌ يقبلها بدل نقاطٍ يردّها.
  final bool announced;

  /// ثوانيَ السؤال في المباراة الحيّة.
  final int questionSeconds;

  /// نقاطُ الجواب الصحيح.
  final int pointsCorrect;

  /// وما يُضاف لسرعته على الأكثر.
  final int pointsSpeedMax;

  /// أقصى نتيجةٍ يقبلها الخادم.
  final int maxScore;

  Duration get window => Duration(seconds: questionSeconds);

  /// نقاطُ جوابٍ صحيحٍ أُجيب وقد بقي [left] من وقت السؤال.
  ///
  /// ── والحسابُ هو حسابُ الخادم نفسه ──
  /// `speedPoints` في `lib/duel.ts`. وحسابان يفترقان يجعلان نتيجةً صحيحةً
  /// تُرفض عند الإرسال.
  int pointsFor({required bool correct, Duration? left}) {
    if (!correct) return 0;
    if (left == null) return pointsCorrect;
    return pointsCorrect + speedPoints(left);
  }

  int speedPoints(Duration left) {
    final windowMs = window.inMilliseconds;
    final leftMs = left.inMilliseconds;
    if (windowMs <= 0 || leftMs <= 0) return 0;
    final share = leftMs / windowMs;
    return (share.clamp(0.0, 1.0) * pointsSpeedMax).round();
  }

  static DuelRules fromJson(Object? raw) {
    if (raw is! Map) return const DuelRules();
    int read(String key, int fallback) {
      final value = raw[key];
      return value is int && value > 0 ? value : fallback;
    }

    return DuelRules(
      questionSeconds: read('questionSeconds', 10),
      pointsCorrect: read('pointsCorrect', 10),
      pointsSpeedMax: read('pointsSpeedMax', 5),
      maxScore: read('maxScore', 150),
      announced: raw['maxScore'] is int,
    );
  }
}
