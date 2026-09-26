import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/services/student_challenge_service.dart';

/// The rounds arrive already filtered by the server; these cover what the
/// client still decides — reading the shape, and refusing one it cannot
/// draw rather than putting a broken board in front of a child.
Map<String, Object?> _fill(String answer) => {
  'kind': 'fill',
  'before': 'الخلية هي أصغر',
  'after': 'قادرة على الحياة.',
  'answer': answer,
  'distractors': const ['نواة', 'غشاء', 'نسيج'],
};

Map<String, Object?> _bank(int size) => {
  'version': 1,
  'generatedAt': '2026-01-01T00:00:00Z',
  'subject': 'العلوم',
  'rounds': [for (var i = 0; i < size; i += 1) _fill('كلمة$i')],
};

void main() {
  group('drawFromBank', () {
    test('يسحب العدد المطلوب بلا تكرار', () {
      final drawn = drawFromBank(_bank(20), 5, random: math.Random(7));
      expect(drawn, hasLength(5));
      final answers = drawn.map((r) => (r as RemoteFill).answer).toSet();
      expect(answers, hasLength(5));
    });

    test('إعادة اللعب تُخرج غير ما خرج', () {
      // كلّ الفائدة من بنكٍ بعشرين: خمسٌ غير الخمس في المرّة التالية.
      final first = drawFromBank(_bank(20), 5, random: math.Random(1))
          .map((r) => (r as RemoteFill).answer)
          .toList();
      final second = drawFromBank(_bank(20), 5, random: math.Random(2))
          .map((r) => (r as RemoteFill).answer)
          .toList();
      expect(first, isNot(equals(second)));
    });

    test('بنكٌ أصغر من المطلوب يُسحب كلّه', () {
      expect(drawFromBank(_bank(3), 5, random: math.Random(1)), hasLength(3));
    });

    test('صيغةٌ غير مفهومة تُترك ليولّد الخادم غيرها', () {
      // قراءتُها بقواعدَ تغيّرت تُخرج لوحةً لا تُلعب.
      expect(drawFromBank({..._bank(20), 'version': 99}, 5), isEmpty);
      expect(drawFromBank({..._bank(20), 'rounds': 'خطأ'}, 5), isEmpty);
      expect(drawFromBank(null, 5), isEmpty);
      expect(drawFromBank('nonsense', 5), isEmpty);
    });

    test('الجولات المعطوبة تسقط ويبقى السليم', () {
      final mixed = {
        ..._bank(0),
        'rounds': [
          _fill('صحيح'),
          {'kind': 'mcq', 'question': 'ما؟'},
          {'kind': 'fill', 'answer': 'ناقص'},
        ],
      };
      final drawn = drawFromBank(mixed, 5, random: math.Random(1));
      expect(drawn, hasLength(1));
      expect((drawn.single as RemoteFill).answer, 'صحيح');
    });
  });

  group('RemoteRound.fromJson', () {
    test('reads a drag-the-word round', () {
      final round = RemoteRound.fromJson({
        'kind': 'fill',
        'before': 'الخلية هي أصغر',
        'after': 'قادرة على الحياة.',
        'answer': 'وحدة',
        'distractors': ['نواة', 'غشاء', 'نسيج'],
      });
      expect(round, isA<RemoteFill>());
      final fill = round! as RemoteFill;
      expect(fill.answer, 'وحدة');
      expect(fill.distractors, hasLength(3));
    });

    test('reads a sorting round', () {
      final round = RemoteRound.fromJson({
        'kind': 'classify',
        'prompt': 'صنّف',
        'buckets': ['مزرعة', 'برّية'],
        'items': {'بقرة': 'مزرعة', 'أسد': 'برّية', 'خروف': 'مزرعة'},
      });
      expect(round, isA<RemoteClassify>());
      expect((round! as RemoteClassify).items, hasLength(3));
    });

    test('reads a matching round', () {
      final round = RemoteRound.fromJson({
        'kind': 'match',
        'pairs': [
          {'term': 'النواة', 'meaning': 'مركز التحكّم'},
          {'term': 'الغشاء', 'meaning': 'غطاء خارجي'},
        ],
      });
      expect(round, isA<RemoteMatch>());
      expect((round! as RemoteMatch).pairs.first.term, 'النواة');
    });

    test('refuses a round it cannot draw', () {
      // لوحةٌ ناقصة أسوأ من جولةٍ أقلّ: الطفل يحاول ولا ينجح ولا يفهم
      // لماذا.
      expect(
        RemoteRound.fromJson({'kind': 'fill', 'answer': 'وحدة', 'distractors': ['نواة']}),
        isNull,
        reason: 'مشتّت واحد',
      );
      expect(
        RemoteRound.fromJson({
          'kind': 'classify',
          'buckets': ['أ'],
          'items': {'س': 'أ'},
        }),
        isNull,
        reason: 'مجموعة واحدة',
      );
      expect(
        RemoteRound.fromJson({
          'kind': 'match',
          'pairs': [
            {'term': 'أ', 'meaning': 'ب'},
          ],
        }),
        isNull,
        reason: 'زوج واحد',
      );
    });

    test('drops an item pointing at a bucket that was never declared', () {
      final round = RemoteRound.fromJson({
        'kind': 'classify',
        'buckets': ['مزرعة', 'برّية'],
        'items': {
          'بقرة': 'مزرعة',
          'أسد': 'برّية',
          'خروف': 'مزرعة',
          'حوت': 'بحرية',
        },
      });
      // العنصر الشارد يسقط، والباقي يُلعب — ولا يُعرض صندوقٌ لا وجود له.
      expect((round! as RemoteClassify).items.keys, isNot(contains('حوت')));
      expect((round as RemoteClassify).items, hasLength(3));
    });

    test('refuses a kind it has no board for', () {
      // سؤال اختيارٍ من متعدّد لم يعد من أنواع التحدي.
      expect(RemoteRound.fromJson({'kind': 'mcq', 'question': 'ما؟'}), isNull);
      expect(RemoteRound.fromJson('nonsense'), isNull);
      expect(RemoteRound.fromJson(null), isNull);
    });
  });
}
