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

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

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

  group('شاشةُ المبارزة والخادمُ ساقط', () {
    Future<void> pump(WidgetTester tester, DuelMatch match) async {
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
            duelService: _DownDuel(),
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
