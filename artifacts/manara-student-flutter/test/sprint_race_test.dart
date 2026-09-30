import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/models/sprint_question.dart';
import 'package:manara_student/src/services/student_challenge_service.dart';
import 'package:manara_student/src/services/student_duel_service.dart';

/// يحرس أصلَ سباق الحلبة: أن يرى الخصمان الشيءَ نفسه.
///
/// ── ولماذا هذا موضعُ الحراسة ──
/// السباقُ بين جهازين، والخللُ فيه لا يظهر على جهازٍ واحد: كلٌّ يعمل وحده
/// صحيحاً، والفرقُ بينهما لا يراه إلا من جمع الشاشتين. فيُختبر هنا بلا شاشة.
void main() {
  RemoteFill fill(String answer) => RemoteFill(
        before: 'الماءُ يتحوّل إلى',
        after: 'عند التبريد',
        answer: answer,
        distractors: const ['بخار', 'سائل', 'غاز'],
      );

  group('بذرةٌ ثابتة', () {
    test('النصُّ الواحد يعطي البذرةَ نفسها دائماً', () {
      expect(stableSeed('duel_abc_123'), stableSeed('duel_abc_123'));
    });

    test('ونصّان مختلفان يفترقان', () {
      expect(stableSeed('duel_a'), isNot(stableSeed('duel_b')));
    });

    test('وقيمتُها مكتوبةٌ لا مستنتجة', () {
      // رقمٌ محسوبٌ من الدالّة نفسها: تغييرُ الحساب يكسر هذا الاختبار، وهو
      // المقصود — بذرةٌ تغيّرت بين نسختين من التطبيق تجعل جهازين يريان
      // ترتيبين، وهو عطبٌ لا يظهر في تشغيل.
      expect(stableSeed('a'), 7 * 31 + 'a'.codeUnitAt(0));
    });

    test('ولا تخرج عن حدود مولّدٍ عشوائيّ', () {
      // `math.Random` يرفض بذرةً سالبة أو أكبر من حدٍّ، فتُجرَّب نصوصٌ طويلة.
      for (final text in ['', 'duel_${'x' * 200}', 'مباراةٌ بالعربية']) {
        final seed = stableSeed(text);
        expect(seed, greaterThanOrEqualTo(0));
        expect(() => math.Random(seed), returnsNormally);
      }
    });
  });

  group('خياراتُ السؤال', () {
    test('ترتيبُها واحدٌ في كل بناء', () {
      final first = SprintQuestion.of(fill('جليد'));
      final second = SprintQuestion.of(fill('جليد'));
      expect(first.options, second.options);
      expect(first.answerAt, second.answerAt);
    });

    test('والترتيبُ لا يتبع ترتيبَ ما وصل من البنك', () {
      // ── وهذا هو العطبُ الذي يحرسه ──
      // البنكُ قد يأتي بالمشتّتات بترتيبٍ مختلف من قراءةٍ إلى قراءة. فلو
      // خُلطت بالبذرة دون ترتيبٍ قبلها لرأى الجهازان ترتيبين، وصار «الخيار
      // الثاني» غيرَ ما يظنّه صاحبُه.
      final ordered = SprintQuestion.of(
        const RemoteFill(
          before: 'قبل',
          after: 'بعد',
          answer: 'جليد',
          distractors: ['بخار', 'سائل', 'غاز'],
        ),
      );
      final scrambled = SprintQuestion.of(
        const RemoteFill(
          before: 'قبل',
          after: 'بعد',
          answer: 'جليد',
          distractors: ['غاز', 'بخار', 'سائل'],
        ),
      );
      expect(ordered.options, scrambled.options);
      expect(ordered.answerAt, scrambled.answerAt);
    });

    test('والجوابُ فيها، وموضعُه صحيح', () {
      final question = SprintQuestion.of(fill('جليد'));
      expect(question.options, hasLength(4));
      expect(question.options[question.answerAt], 'جليد');
    });

    test('وسؤالان مختلفان لا يلزمُ أن يتّفقا', () {
      // بذرةُ كلِّ سؤالٍ من جوابه، فلا يصطفّ الجوابُ في الموضع نفسه في كل
      // شوط — وإلا تعلّم الطفلُ موضعَ الزرّ بدل قراءة السؤال.
      final seats = {
        for (final answer in ['جليد', 'ثلج', 'صلب', 'ماء', 'برد'])
          SprintQuestion.of(fill(answer)).answerAt,
      };
      expect(seats.length, greaterThan(1));
    });
  });

  group('أسئلةُ الشوط من البنك', () {
    test('تأخذ الملءَ وتترك التصنيفَ والمطابقة', () {
      final questions = sprintQuestionsOf([
        fill('جليد'),
        const RemoteClassify(
          prompt: 'افرز',
          buckets: ['أ', 'ب'],
          items: {'واحد': 'أ'},
        ),
        const RemoteMatch(pairs: [(term: 'ماء', meaning: 'سائل')]),
        fill('بخار'),
      ]);
      expect(questions, hasLength(2));
      expect(questions.first.options[questions.first.answerAt], 'جليد');
    });

    test('وبنكٌ بلا ملءٍ يعطي شوطاً فارغاً لا رمية', () {
      // الشاشةُ تعرض رسالةً على الفارغ، والرميةُ هنا كانت ستُسقط الحلبة.
      expect(
        sprintQuestionsOf([const RemoteMatch(pairs: [])]),
        isEmpty,
      );
    });
  });

  group('حالُ المباراة كما تقرؤها الشاشة', () {
    DuelMatch read(Map<String, Object?> raw) {
      final match = DuelMatch.fromJson(raw);
      expect(match, isNotNull);
      return match!;
    }

    test('من لم يلعب بعد ينتظره الدور', () {
      final match = read({'id': 'duel_1', 'mine': null, 'theirs': 3});
      expect(match.waitingForMe, isTrue);
      expect(match.waitingForThem, isFalse);
    });

    test('ومن لعب وحده ينتظر زميله', () {
      final match = read({'id': 'duel_1', 'mine': 4, 'theirs': null});
      expect(match.waitingForMe, isFalse);
      expect(match.waitingForThem, isTrue);
    });

    test('ونتيجةُ الصفر ليست غياباً', () {
      // ── وهذا فرقٌ يسهل أن يضيع ──
      // صفرٌ نتيجةٌ حاضرة: من لعب ولم يُصب شيئاً قد لعب. ولو قُرئ غياباً
      // لعُرضت عليه جولتُه ثانيةً، ولرفضها الخادمُ لأنها كُتبت.
      final match = read({'id': 'duel_1', 'mine': 0, 'theirs': null});
      expect(match.waitingForMe, isFalse);
      expect(match.mine, 0);
    });

    test('والحيّةُ تُعرف من الوصف لا من الحال', () {
      expect(read({'id': 'd', 'mode': 'live'}).live, isTrue);
      expect(read({'id': 'd', 'mode': 'ghost'}).live, isFalse);
      // ولا وصفَ يعني مؤجَّلة: الأقدمُ من الصفوف بلا `mode`، وقراءتُها حيّةً
      // تفتح قناةً لخصمٍ ليس هناك.
      expect(read({'id': 'd'}).live, isFalse);
    });

    test('والمحسومةُ وحدها تُظهر نتيجةً', () {
      expect(read({'id': 'd', 'status': 'done'}).settled, isTrue);
      expect(read({'id': 'd', 'status': 'pending'}).settled, isFalse);
    });

    test('وصفٌّ بلا معرّفٍ لا يُقرأ مباراةً', () {
      // مباراةٌ بلا معرّفٍ لا تُسجَّل نتيجتُها، فعرضُها يعطي زرّاً يفشل دائماً.
      expect(DuelMatch.fromJson({'mine': 3}), isNull);
      expect(DuelMatch.fromJson({'id': '  '}), isNull);
      expect(DuelMatch.fromJson('duel_1'), isNull);
    });

    test('وعددُ الأشواط له قيمةٌ حين يسكت الخادم', () {
      // شريطُ الحلبة يُقسم على العدد، وصفرٌ فيه قسمةٌ على صفر.
      expect(read({'id': 'd'}).rounds, 5);
      expect(read({'id': 'd', 'rounds': 3}).rounds, 3);
    });
  });
}
