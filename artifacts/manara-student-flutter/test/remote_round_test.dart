import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/services/student_challenge_service.dart';

/// The rounds arrive already filtered by the server; these cover what the
/// client still decides — reading the shape, and refusing one it cannot
/// draw rather than putting a broken board in front of a child.
void main() {
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
