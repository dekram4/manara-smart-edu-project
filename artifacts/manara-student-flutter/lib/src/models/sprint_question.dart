import 'dart:math' as math;

import '../services/student_challenge_service.dart';

/// سؤالُ شوطٍ في سباق الحلبة: جملةٌ ناقصةٌ وخياراتٌ مرتّبة.
///
/// ── لماذا خارج الشاشة ──
/// أصلُ السباق أن يرى الخصمان الشيءَ نفسه: الأسئلةَ نفسها بالترتيب نفسه،
/// والخياراتَ في المواضع نفسها. وهذا شرطٌ لا يُرى في تشغيلٍ على جهازٍ واحد
/// — يحتاج جهازين — فيُختبر هنا بلا شاشة.
class SprintQuestion {
  const SprintQuestion({
    required this.before,
    required this.after,
    required this.options,
    required this.answerAt,
  });

  final String before;
  final String after;
  final List<String> options;
  final int answerAt;

  /// ── والخياراتُ تُخلط ببذرةٍ من نصّها ──
  /// فترتيبُها ثابتٌ لكل من يرى السؤالَ نفسه. ولو خُلطت بعشوائيةٍ حرّة لرأى
  /// كلُّ لاعبٍ ترتيباً، وصار «الخيارُ الثاني» غيرَ ما يظنّه صاحبُه — ولا
  /// يظهر ذلك عطباً: كلُّ جهازٍ يعمل وحده صحيحاً.
  ///
  /// ويُرتَّب قبل الخلط: البنك قد يأتي بالخيارات بترتيبٍ مختلف من قراءةٍ
  /// إلى قراءة، فبذرةٌ واحدة على ترتيبٍ مختلف تُخرج خلطاً مختلفاً.
  static SprintQuestion of(RemoteFill round) {
    final options = [round.answer, ...round.distractors]..sort();
    final seeded = math.Random(stableSeed(round.answer));
    for (var i = options.length - 1; i > 0; i -= 1) {
      final j = seeded.nextInt(i + 1);
      final swap = options[i];
      options[i] = options[j];
      options[j] = swap;
    }
    return SprintQuestion(
      before: round.before,
      after: round.after,
      options: options,
      answerAt: options.indexOf(round.answer),
    );
  }
}

/// أسئلةُ الشوط من جولات البنك.
///
/// ── والمليءُ وحده ──
/// جولاتُ البنك ثلاثةُ أنواع: ملءُ فراغٍ وتصنيفٌ ومطابقة. والسباقُ يحتاج
/// سؤالاً يُجاب بضغطةٍ واحدة — والتصنيفُ والمطابقةُ يحتاجان سحباً وترتيباً،
/// وهما لعبتان أخريان لا شوطُ سباق.
List<SprintQuestion> sprintQuestionsOf(Iterable<RemoteRound> rounds) => [
      for (final round in rounds)
        if (round is RemoteFill) SprintQuestion.of(round),
    ];

/// بذرةٌ ثابتةٌ من نصّ.
///
/// ── ولا يُتّخذ `hashCode` بذرةً ──
/// قيمتُه تفصيلُ تنفيذٍ لا عقدٌ: قد تختلف بين إصدارَي Dart. وبذرةٌ تختلف بين
/// الجهازين تُفسد أصلَ السباق. فتُحسب بحسابٍ مكتوبٍ هنا لا يتغيّر إلا إن
/// غُيّر.
int stableSeed(String text) {
  var seed = 7;
  for (final unit in text.codeUnits) {
    seed = (seed * 31 + unit) & 0x1FFFFFFF;
  }
  return seed;
}
