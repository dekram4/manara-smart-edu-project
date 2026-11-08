import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/services/kindergarten_voice_quiz.dart';

void main() {
  group('متى تظهر الألعاب', () {
    test('في «الثقافة العامة» بالروضة وحدها — بأيّ همزةٍ أو تاءٍ كُتبت', () {
      for (final subject in ['الثقافة العامة', 'الثقافه العامه', 'ثقافة عامة', 'General Knowledge']) {
        expect(kgVoiceGamesAllowedFor(grade: 'روضة منارة المعرفة', subject: subject), isTrue, reason: subject);
      }
      expect(kgVoiceGamesAllowedFor(grade: 'الصف الأول', subject: 'الثقافة العامة'), isFalse);
      expect(kgVoiceGamesAllowedFor(grade: 'روضة منارة المعرفة', subject: 'الحروف العربية'), isFalse);
      expect(kgVoiceGamesAllowedFor(grade: null, subject: null), isFalse);
    });
  });

  group('الجولة: عشرةُ أسئلةٍ عشوائية', () {
    for (final kind in KgVoiceGameKind.values) {
      test('$kind: عشرة، بلا سؤالين متتاليين متطابقين، ومتغيّرةٌ بين جولة وأخرى', () {
        final rounds = <String>{};
        for (var seed = 0; seed < 20; seed++) {
          final round = buildKgVoiceRound(kind, math.Random(seed));
          expect(round, hasLength(kgVoiceRoundLength));
          for (var i = 1; i < round.length; i++) {
            final a = round[i - 1];
            final b = round[i];
            final same = a.answer.id == b.answer.id && a.story == null && b.story == null;
            expect(same, isFalse, reason: 'سؤالان متتاليان: ${a.answer.label}');
          }
          rounds.add(round.map((q) => q.answer.id).join(','));
        }
        expect(rounds.length, greaterThan(15), reason: 'الجولاتُ تتغيّر');
      });
    }

    test('الألوانُ الإحدى عشرة كلُّها تُسأل', () {
      final asked = <String>{};
      for (var seed = 0; seed < 10; seed++) {
        asked.addAll(buildKgVoiceRound(KgVoiceGameKind.colors, math.Random(seed)).map((q) => q.answer.id));
      }
      expect(asked, hasLength(11));
    });

    test('الأشكالُ السبعة كلُّها في كل جولة', () {
      final round = buildKgVoiceRound(KgVoiceGameKind.shapes, math.Random(3));
      expect(round.map((q) => q.shape).toSet(), KgShape.values.toSet());
    });

    test('الحساب: نصفُه علاماتٌ ونصفُه مسائلُ مصوّرة، بأعدادٍ لطفل الروضة', () {
      for (var seed = 0; seed < 30; seed++) {
        final round = buildKgVoiceRound(KgVoiceGameKind.math, math.Random(seed));
        expect(round.where((q) => q.sign != null), hasLength(5));
        expect(round.where((q) => q.story != null), hasLength(5));
        for (final q in round.where((q) => q.story != null)) {
          final story = q.story!;
          expect(story.result, inInclusiveRange(0, 10));
          expect(story.sign, anyOf(KgSign.plus, KgSign.minus));
          expect(q.promptClip, kgQuestionResultClip);
        }
        for (final q in round.where((q) => q.sign != null)) {
          expect(q.promptClip, kgQuestionSignClip);
        }
      }
    });

    test('كلُّ سؤالٍ بمقطعه المسجّل، والمقاطعُ في assets/', () {
      expect(buildKgVoiceRound(KgVoiceGameKind.colors, math.Random(1)).first.promptClip, kgQuestionColorClip);
      expect(buildKgVoiceRound(KgVoiceGameKind.shapes, math.Random(1)).first.promptClip, kgQuestionShapeClip);
      for (final clip in [
        kgQuestionColorClip,
        kgQuestionShapeClip,
        kgQuestionSignClip,
        kgQuestionResultClip,
        kgWrongAnswerClip,
      ]) {
        expect(File('assets/$clip').existsSync(), isTrue, reason: clip);
      }
    });
  });

  group('الحكمُ على ما قاله الطفل', () {
    KgVoiceQuestion colorQuestion(String id) => buildKgVoiceRound(KgVoiceGameKind.colors, math.Random(0), count: 40)
        .firstWhere((q) => q.answer.id == id);
    KgVoiceQuestion shapeQuestion(KgShape shape) =>
        buildKgVoiceRound(KgVoiceGameKind.shapes, math.Random(0), count: 7).firstWhere((q) => q.shape == shape);

    test('الألوان بكل صيغها', () {
      final red = colorQuestion('red');
      for (final said in ['أحمر', 'احمر', 'الأحمر', 'حمراء', 'اللون الأحمر', 'هذا أحمر', 'red']) {
        expect(red.judge(said), isTrue, reason: said);
      }
      expect(red.judge('أزرق'), isFalse);
      expect(red.judge('أحمر وأزرق'), isFalse, reason: 'لونان: لا يُقبل');
      expect(red.judge(''), isFalse);
      expect(colorQuestion('pink').judge('زهري'), isTrue);
      expect(colorQuestion('gray').judge('رصاصي'), isTrue);
      expect(colorQuestion('white').judge('أبيض'), isTrue);
      expect(colorQuestion('orange').judge('برتقالي'), isTrue);
      expect(colorQuestion('purple').judge('بنفسجي'), isTrue);
      expect(colorQuestion('brown').judge('بني'), isTrue);
    });

    test('الأشكال', () {
      expect(shapeQuestion(KgShape.circle).judge('دائرة'), isTrue);
      expect(shapeQuestion(KgShape.circle).judge('الدايره'), isTrue);
      expect(shapeQuestion(KgShape.parallelogram).judge('متوازي الأضلاع'), isTrue);
      expect(shapeQuestion(KgShape.sphere).judge('كرة'), isTrue);
      expect(shapeQuestion(KgShape.sphere).judge('كورة'), isTrue);
      expect(shapeQuestion(KgShape.cube).judge('مكعب'), isTrue);
      expect(shapeQuestion(KgShape.pyramid).judge('هرم'), isTrue);
      expect(shapeQuestion(KgShape.square).judge('مستطيل'), isFalse);
      expect(shapeQuestion(KgShape.rectangle).judge('مستطيل'), isTrue);
    });

    test('العلامات والمسائل', () {
      final round = buildKgVoiceRound(KgVoiceGameKind.math, math.Random(5));
      final plus = round.firstWhere((q) => q.sign == KgSign.plus, orElse: () => round.firstWhere((q) => q.sign != null));
      final words = {
        KgSign.plus: 'زائد',
        KgSign.minus: 'ناقص',
        KgSign.times: 'ضرب',
        KgSign.divide: 'قسمة',
      };
      expect(plus.judge(words[plus.sign]!), isTrue);
      final story = round.firstWhere((q) => q.story != null);
      final n = story.story!.result;
      expect(story.judge('$n'), isTrue);
      expect(story.judge('٠١٢٣٤٥٦٧٨٩'[n == 10 ? 1 : n] + (n == 10 ? '٠' : '')), isTrue);
      expect(story.judge('${story.story!.a} زائد ${story.story!.b} يساوي $n'), isTrue, reason: 'آخرُ عددٍ هو الجواب');
      expect(story.judge('${(n + 1) % 11}'), isFalse);
    });

    test('الأعدادُ كلماتٍ بعاميّتها', () {
      expect(kgNumbersIn('تلاتة'), [3]);
      expect(kgNumbersIn('خمسة'), [5]);
      expect(kgNumbersIn('اتنين'), [2]);
      expect(kgNumbersIn('عشرة'), [10]);
      expect(kgNumbersIn('صفر'), [0]);
      expect(kgNumbersIn('٧'), [7]);
    });
  });
}
