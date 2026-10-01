import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/data/duel_question_bank.dart';
import 'package:manara_student/src/models/duel_chat.dart';
import 'package:manara_student/src/models/duel_question.dart';
import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/screens/student_duel_game_screen.dart';
import 'package:manara_student/src/services/student_challenge_service.dart';
import 'package:manara_student/src/services/student_duel_service.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:manara_student/src/widgets/duel_chat.dart';

/// ما يبنيه `buildDuelPack` في الخادم لهذه المعرّفات، بلا أسئلة درس.
/// أُخرج من `artifacts/api-server/src/lib/duelQuestions.ts` نفسه.
const _serverPacks = r'''{"m-1":["general:dbsjk@0@الصيف|الخريف|الشتاء|لا شيء","school:21paha@0@شكراً|اذهب|بسرعة|لا شيء","quick:ytakwx@1@14|24|22|26","logic:b060xz@1@متساويان|٣/٤|لا يُقارنان|١/٢","general:4m3f03@2@المتجمد|الأطلسي|الهادي|الهندي","school:ueqbp7@1@المقصف|المختبر|الإدارة|المكتبة","quick:9g34ck@2@60|12|24|30","logic:99wfpj@3@6|8|10|9","general:nnpanw@2@اثنان|خمسة|ثلاثة|أربعة","school:t7kcsg@1@المكتبة|الملعب|المختبر|الصف"],"3f2a9c1e-7b44-4d2e-9a10-55c0e1d2b3a4":["logic:fok88p@3@15|60|30|45","school:t7kcsg@3@الصف|المكتبة|المختبر|الملعب","general:dbsjk@1@الخريف|الصيف|الشتاء|لا شيء","quick:rc62ik@2@14|12|13|11","logic:n3kbkl@3@4|3|1|2","school:21paha@1@اذهب|شكراً|لا شيء|بسرعة","general:iosq11@3@زحل|المشتري|الزهرة|الأرض","quick:eve0cq@2@6|5|7|30","logic:tl906l@2@18|20|25|24","school:we6oa7@2@المختبر|المقصف|المكتبة|الملعب"],"abc":["school:ueqbp7@2@الإدارة|المقصف|المختبر|المكتبة","general:p8n9o0@0@365|375|360|350","quick:sdb4z5@2@24|21|27|30","logic:6riw45@1@5|2|3|0","school:j474l2@2@الكرسي|السبورة|الحقيبة|القلم","general:ivp27c@3@المريخ|الأرض|عطارد|المشتري","quick:rc62ik@1@14|13|12|11","logic:tl906l@0@25|18|24|20","school:we6oa7@3@الملعب|المختبر|المقصف|المكتبة","general:5g32sa@3@الحصان|الثور|الحمار|الجمل"]}''';

/// حزمةٌ كما أعادتها `claim_duel_pack` من `scripts/duel-question-bank.sql`.
const _realPack = r'''{"source": "bank", "builtAt": "2026-10-01T11:43:07.545922+00:00", "subject": "science", "version": 1, "questions": [{"id": "domain:science:t26pm6", "prompt": "أي هذه الحيوانات من الثدييات؟", "options": ["الدلفين", "النسر", "الضفدع", "السمكة"], "answerAt": 0, "category": "domain"}, {"id": "logic:70s0q4", "prompt": "أكمل النمط: ٢، ٤، ٦، ٨، ...", "options": ["10", "9", "12", "11"], "answerAt": 0, "category": "logic"}, {"id": "domain:science:w029t5", "prompt": "ما العضو الذي يضخ الدم في الجسم؟", "options": ["الرئة", "القلب", "الكبد", "المعدة"], "answerAt": 1, "category": "domain"}, {"id": "domain:science:7e4j1l", "prompt": "في أي حالة يكون الجليد؟", "options": ["سائلة", "صلبة", "غازية"], "answerAt": 1, "category": "domain"}, {"id": "quick:ytakwx", "prompt": "بسرعة! ما ضعف العدد ١٢؟", "options": ["22", "14", "24", "26"], "answerAt": 2, "category": "quick"}, {"id": "domain:science:x5c2om", "prompt": "كم عدد كواكب المجموعة الشمسية؟", "options": ["7", "10", "9", "8"], "answerAt": 3, "category": "domain"}, {"id": "domain:science:db6uxd", "prompt": "ما القوة التي تجذب الأجسام نحو الأرض؟", "options": ["الاحتكاك", "الضوء", "الجاذبية", "الرياح"], "answerAt": 2, "category": "domain"}, {"id": "logic:fok88p", "prompt": "إذا بدأ الدرس ٨:٠٠ وانتهى ٨:٤٥، كم دقيقة طوله؟", "options": ["30", "45", "15", "60"], "answerAt": 1, "category": "logic"}, {"id": "domain:science:adtb0o", "prompt": "ما الغاز الذي نتنفسه لنعيش؟", "options": ["النيتروجين", "الهيليوم", "الأكسجين", "ثاني أكسيد الكربون"], "answerAt": 2, "category": "domain"}, {"id": "quick:rc62ik", "prompt": "بسرعة! ما ناتج ٧ + ٦؟", "options": ["12", "14", "11", "13"], "answerAt": 3, "category": "quick"}]}''';

/// خادمٌ في أسوأ حاله: لا مباراةَ تُقرأ، ولا سجلّ.
class _DownDuel implements StudentDuelService {
  @override
  final ValueNotifier<Set<String>> online = ValueNotifier(<String>{});

  @override
  Future<DuelMatch> fetchMatch(String matchId) async =>
      throw DuelFailure('down');

  @override
  Future<List<DuelChatMessage>> messages(String matchId) async =>
      throw DuelFailure('down');

  @override
  Future<void> watchMatch({
    required String matchId,
    required void Function(String studentId, int progress) onProgress,
    void Function(DuelChatMessage message)? onChat,
    void Function(String studentId, bool muted)? onMute,
    void Function(String studentId, int index, int points)? onAnswered,
  }) async {}

  @override
  Future<void> leaveMatch() async {}

  /// ما تعيده `claim_duel_pack`. و`null`: لا اتصال، أو لا حزمة.
  Object? claimed;
  int claims = 0;

  @override
  Future<List<DuelQuestion>?> claimPack(String matchId) async {
    claims += 1;
    return duelPackFrom(claimed);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// حزمةٌ كما تكتبها `claim_duel_pack`: ستّةٌ من المجال وأربعةٌ ذكاءٌ وسرعة.
Map<String, Object?> _bankPack({String domainCategory = 'domain'}) => {
      'version': 1,
      'source': 'bank',
      'questions': [
        for (var i = 0; i < 10; i++)
          {
            'id': 'q$i',
            'category': 'DBDDBDDBDB'[i] == 'D'
                ? domainCategory
                : (i.isOdd ? 'logic' : 'quick'),
            'prompt': 'سؤال المجال رقم $i؟',
            'options': ['أ$i', 'ب$i', 'ج$i', 'د$i'],
            'answerAt': i % 4,
          },
      ],
    };

/// ولا يُلمَس بنكُ الدرس أبداً: أيُّ نداءٍ له يُسقط الاختبار.
class _NoLessonBank implements StudentChallengeService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      fail('لا مسلكَ إلى أسئلة الدرس: ${invocation.memberName}');
}

DuelMatch _match(String id, {String mode = 'ghost'}) => DuelMatch(
      id: id,
      lessonId: 'lesson-1',
      game: 'sprint',
      mode: mode,
      status: 'pending',
      opponentId: 'rival',
      mine: null,
      theirs: null,
      rounds: 5,
      winnerId: null,
      iWon: false,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  group('بنكُ المبارزة في التطبيق', () {
    test('عشرةُ أسئلةٍ عامّة، بلا درس، بلا تكرار، والجوابُ داخل خياراته', () {
      expect(duelBankSize, 51);
      for (final id in ['a', 'match-42', '3f2a9c1e-7b44-4d2e-9a10-55c0e1d2b3a4']) {
        final pack = buildLocalDuelPack(id);
        expect(pack, hasLength(10));
        expect(pack.map((q) => q.id).toSet(), hasLength(10));
        expect(pack.where((q) => q.category == 'lesson'), isEmpty);
        expect(pack.map((q) => q.category).toSet().length, 4);
        for (final q in pack) {
          expect(q.answerAt, inInclusiveRange(0, q.options.length - 1));
        }
      }
    });

    test('ثابتةٌ على المعرّف نفسه، ومختلفةٌ بين مباراتين', () {
      String sig(List<DuelQuestion> pack) =>
          pack.map((q) => '${q.id}@${q.answerAt}').join(',');
      expect(sig(buildLocalDuelPack('m-1')), sig(buildLocalDuelPack('m-1')));
      expect(sig(buildLocalDuelPack('m-1')), isNot(sig(buildLocalDuelPack('m-2'))));
    });

    test('تطابق ما يبنيه الخادم حرفاً بحرف', () {
      final expected = jsonDecode(_serverPacks) as Map<String, dynamic>;
      for (final entry in expected.entries) {
        final local = [
          for (final q in buildLocalDuelPack(entry.key))
            '${q.id}@${q.answerAt}@${q.options.join('|')}',
        ];
        expect(local, entry.value, reason: entry.key);
      }
    });
  });

  group('قراءةُ الحزمة من Supabase', () {
    test('حزمةُ البنك تُقرأ بترتيبها وأبوابها', () {
      final pack = duelPackFrom(_bankPack())!;
      expect(pack, hasLength(10));
      expect(pack.where((q) => q.category == 'domain'), hasLength(6));
      expect(pack.first.prompt, 'سؤال المجال رقم 0؟');
      expect(pack[3].options[pack[3].answerAt], 'د3');
    });

    test('حزمةٌ حقيقيةٌ من claim_duel_pack تُقرأ كاملة', () {
      // أُخرجت من الدالّة نفسها على PostgreSQL، لدرس علومٍ في الصف الرابع.
      final pack = duelPackFrom(jsonDecode(_realPack))!;
      expect(pack, hasLength(10));
      expect(
        pack.map((q) => q.category).join(','),
        'domain,logic,domain,domain,quick,domain,domain,logic,domain,quick',
      );
      expect(pack.where((q) => q.id.startsWith('domain:science:')), hasLength(6));
    });

    test('حزمةٌ فيها سؤالٌ من الدرس تُترك كلُّها', () {
      expect(duelPackFrom(_bankPack(domainCategory: 'lesson')), isNull);
    });

    test('وحزمةٌ قصيرةٌ أو معطوبةٌ تُترك', () {
      final short = _bankPack();
      short['questions'] = (short['questions']! as List).take(7).toList();
      expect(duelPackFrom(short), isNull);
      expect(duelPackFrom(null), isNull);
      expect(duelPackFrom({'questions': 'x'}), isNull);
    });
  });

  group('شاشةُ المبارزة والخادمُ ساقط', () {
    Future<void> pump(
      WidgetTester tester,
      DuelMatch match, {
      _DownDuel? duel,
    }) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: StudentDuelGameScreen(
            profile: const StudentProfile(
              id: 'me',
              username: 'me',
              name: 'أنا',
              role: 'student',
            ),
            match: match,
            duelService: duel ?? _DownDuel(),
            challengeService: _NoLessonBank(),
            opponentName: 'سارة',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('تُعرض أسئلةُ البنك العامّة لا أسئلةُ الدرس', (tester) async {
      await pump(tester, _match('m-1'));
      final first = buildLocalDuelPack('m-1').first;
      expect(find.text(first.prompt), findsOneWidget);
      expect(find.byType(DuelChatButton), findsOneWidget);
    });

    testWidgets('حزمةُ Supabase تُعرض قبل البنك المحليّ', (tester) async {
      final duel = _DownDuel()..claimed = _bankPack();
      await pump(tester, _match('m-3'), duel: duel);
      expect(duel.claims, 1);
      expect(find.text('سؤال المجال رقم 0؟'), findsOneWidget);
      expect(find.text(buildLocalDuelPack('m-3').first.prompt), findsNothing);
    });

    testWidgets('وحزمةٌ فيها أسئلةُ الدرس لا تُعرض: البنكُ المحليّ', (tester) async {
      final duel = _DownDuel()..claimed = _bankPack(domainCategory: 'lesson');
      await pump(tester, _match('m-4'), duel: duel);
      expect(find.text('سؤال المجال رقم 0؟'), findsNothing);
      expect(find.text(buildLocalDuelPack('m-4').first.prompt), findsOneWidget);
    });

    testWidgets('وزرُّ الدردشة ظاهرٌ ويفتح النافذة بلا اتصال', (tester) async {
      await pump(tester, _match('m-2'));
      expect(find.byType(DuelChatButton), findsOneWidget);
      await tester.tap(find.byType(DuelChatButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(DuelChatSheet), findsOneWidget);
    });
  });
}
