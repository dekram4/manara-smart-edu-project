import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/academic_context.dart';
import 'package:manara_student/src/models/duel_chat.dart';
import 'package:manara_student/src/models/duel_question.dart';
import 'package:manara_student/src/models/student_content.dart';
import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/screens/duel_match_screen.dart';
import 'package:manara_student/src/screens/student_duel_screen.dart';
import 'package:manara_student/src/services/duel_live_controller.dart';
import 'package:manara_student/src/services/student_challenge_service.dart';
import 'package:manara_student/src/services/student_duel_service.dart';
import 'package:manara_student/src/services/student_leaderboard_service.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:manara_student/src/widgets/arena_widgets.dart';
import 'package:manara_student/src/widgets/duel_chat.dart';

const me = StudentProfile(
  id: 'me',
  username: 'me',
  name: 'أنا',
  role: 'student',
  teacherId: 't1',
  grade: '4',
);

DuelMatch matchOf(String id, {int? mine, int? theirs, bool iWon = false}) => DuelMatch(
      id: id,
      lessonId: 'L1',
      game: 'sprint',
      mode: 'live',
      status: mine == null ? 'pending' : 'done',
      opponentId: 'r1',
      mine: mine,
      theirs: theirs,
      rounds: 3,
      winnerId: null,
      iWon: iWon,
    );

final questions = [
  for (var i = 0; i < 3; i++)
    DuelQuestion(
      id: 'q$i',
      category: 'general',
      prompt: 'ما جواب السؤال رقم $i؟',
      options: const ['الأول', 'الثاني', 'الثالث', 'الرابع'],
      answerAt: 0,
    ),
];

/// الخدمةُ مُحاكاة: قناةُ الصفّ والمباراة في الذاكرة، والاختبارُ يلعب دورَ الزميل.
class FakeDuel implements StudentDuelService {
  @override
  final ValueNotifier<Set<String>> online = ValueNotifier({'r1'});

  final StreamController<DuelInviteEvent> events =
      StreamController<DuelInviteEvent>.broadcast();
  final List<String> log = [];
  void Function(String, Map<String, dynamic>)? signal;

  @override
  Stream<DuelInviteEvent> get inviteEvents => events.stream;

  @override
  Future<void> joinClass({required String classKey, required String myId}) async {}
  @override
  Future<void> leaveClass() async {}
  @override
  Future<List<DuelStanding>> standings() async => const [];
  @override
  Future<List<DuelChatMessage>> messages(String matchId) async => const [];

  @override
  Future<DuelMatch> invite({required String lessonId, required String guestId}) async {
    log.add('invite:$guestId');
    return matchOf('m1');
  }

  @override
  bool sendInvite({
    required String to,
    required DuelMatch match,
    required String myName,
    Map<String, dynamic>? myAppearance,
  }) {
    log.add('sendInvite:$to:${match.id}');
    return true;
  }

  @override
  bool replyInvite({required String to, required String matchId, required bool accepted}) {
    log.add('reply:$matchId:$accepted');
    return true;
  }

  @override
  bool cancelInvite({required String to, required String matchId}) {
    log.add('cancelInvite:$matchId');
    return true;
  }

  @override
  Future<void> cancel(String matchId) async => log.add('cancel:$matchId');

  @override
  Future<void> watchMatch({
    required String matchId,
    required void Function(String studentId, int progress) onProgress,
    void Function(DuelChatMessage message)? onChat,
    void Function(String studentId, bool muted)? onMute,
    void Function(String studentId, int index, int points)? onAnswered,
    void Function(String event, Map<String, dynamic> payload)? onSignal,
  }) async {
    signal = onSignal;
  }

  @override
  Future<void> leaveMatch() async {}

  @override
  bool sendSignal(String event, Map<String, Object?> payload) {
    log.add('signal:$event');
    return true;
  }

  // يُرسَل بها الجوابُ ويُحسم: الأوّلُ لي دائماً إن أصبت.
  final Set<int> won = {};

  @override
  Future<List<DuelQuestion>?> claimPack(String matchId) async => questions;

  @override
  Future<DuelAnswerResult> answer({
    required String matchId,
    required int index,
    required int choice,
  }) async {
    final correct = choice == questions[index].answerAt;
    final win = correct && won.add(index);
    return DuelAnswerResult(correct: correct, won: win, answerAt: 0, points: win ? 10 : 0);
  }

  int finishMine = 20;
  int finishTheirs = 10;
  int finishGems = 5;
  bool finishTaken = false;

  @override
  Future<DuelResult> finish(String matchId) async => DuelResult(
        match: matchOf(matchId,
            mine: finishMine, theirs: finishTheirs, iWon: finishMine > finishTheirs),
        gems: finishGems,
        draw: finishMine == finishTheirs,
        rewardTaken: finishTaken,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeBoard implements StudentLeaderboardService {
  @override
  Future<LeaderboardResult> fetch() async => const LeaderboardResult.ready(
        Leaderboard(
          entries: [
            LeaderboardEntry(id: 'r1', name: 'سارة', gems: 9, xp: 9, level: 1, rank: 1, isMe: false),
            LeaderboardEntry(id: 'r2', name: 'خالد', gems: 5, xp: 5, level: 1, rank: 2, isMe: false),
            LeaderboardEntry(id: 'r3', name: 'منى', gems: 3, xp: 3, level: 1, rank: 3, isMe: false),
            LeaderboardEntry(id: 'me', name: 'أنا', gems: 1, xp: 1, level: 1, rank: 4, isMe: true),
          ],
          myRank: 4,
          total: 4,
          topGems: 9,
          gemsToNext: 2,
          listed: true,
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class NoChallenge implements StudentChallengeService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final lessonContext = AcademicContext(
  grade: '4',
  subject: 'العلوم',
  term: 'الأول',
  unit: 'الأولى',
  selectedLesson: const LessonContent(
    id: 'L1',
    lessonId: 'L1',
    grade: '4',
    subject: 'العلوم',
    term: 'الأول',
    unit: 'الأولى',
    lessonName: 'الجهاز الهضمي',
    createdAt: '2026-01-01T00:00:00Z',
    ownerId: 't1',
    videos: [],
    games: [],
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  void sized(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester, [int steps = 10]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('الساحة', () {
    Future<FakeDuel> pumpLobby(WidgetTester tester, {Size size = const Size(390, 844)}) async {
      sized(tester, size);
      final duel = FakeDuel();
      addTearDown(duel.events.close);
      await tester.pumpWidget(
        MaterialApp(
          home: StudentDuelScreen(
            profile: me,
            duelService: duel,
            challengeService: NoChallenge(),
            leaderboardService: FakeBoard(),
            academicContext: lessonContext,
          ),
        ),
      );
      await settle(tester);
      return duel;
    }

    testWidgets('المتصلُ وحده يُتحدّى، والغائبون شاحبون بلا زرّ', (tester) async {
      await pumpLobby(tester);
      expect(find.text(trf('arena.online', {'n': '1'})), findsOneWidget);
      expect(find.text(tr('arena.challenge')), findsOneWidget);
      expect(find.text('سارة'), findsOneWidget);
      expect(find.text(tr('arena.unavailable')), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('ولا زرَّ دردشة في الساحة', (tester) async {
      await pumpLobby(tester);
      expect(find.byType(DuelChatButton), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('يتحدّى فينتظر، ويُقبل فتُفتح غرفةُ النزال وتبقى مفتوحة', (tester) async {
      final duel = await pumpLobby(tester);
      await tester.tap(find.text(tr('arena.challenge')));
      await settle(tester, 3);
      expect(duel.log, containsAll(['invite:r1', 'sendInvite:r1:m1']));
      expect(find.text(trf('arena.waitingTitle', {'name': 'سارة'})), findsOneWidget);

      duel.events.add(const DuelInviteEvent(
        kind: DuelInviteKind.accepted,
        matchId: 'm1',
        fromId: 'r1',
      ));
      await settle(tester, 5);
      // والنافذةُ أزالت مسارَها هي: الغرفةُ التي فُتحت للتوّ باقية.
      expect(find.byType(DuelMatchScreen), findsOneWidget);
      expect(find.text(trf('arena.waitingTitle', {'name': 'سارة'})), findsNothing);
    });

    testWidgets('يُرفض التحدي: يقال ذلك، وتُلغى المباراة', (tester) async {
      final duel = await pumpLobby(tester);
      await tester.tap(find.text(tr('arena.challenge')));
      await settle(tester, 3);
      duel.events.add(const DuelInviteEvent(
        kind: DuelInviteKind.declined,
        matchId: 'm1',
        fromId: 'r1',
      ));
      await settle(tester, 5);
      expect(find.text(trf('arena.declined', {'name': 'سارة'})), findsOneWidget);
      expect(duel.log, contains('cancel:m1'));
      expect(find.byType(DuelMatchScreen), findsNothing);
    });

    testWidgets('يصلني تحدٍّ فأقبله: أردّ، وتُفتح الغرفةُ ضيفاً', (tester) async {
      final duel = await pumpLobby(tester);
      duel.events.add(const DuelInviteEvent(
        kind: DuelInviteKind.invite,
        matchId: 'm9',
        fromId: 'r1',
        fromName: 'سارة',
      ));
      await settle(tester, 3);
      expect(find.text(trf('arena.inviteTitle', {'name': 'سارة'})), findsOneWidget);
      await tester.tap(find.text(tr('arena.accept')));
      await settle(tester, 5);
      expect(duel.log, contains('reply:m9:true'));
      final screen = tester.widget<DuelMatchScreen>(find.byType(DuelMatchScreen));
      expect(screen.isHost, isFalse);
      expect(screen.matchId, 'm9');
    });

    testWidgets('وسحبه صاحبُه قبل أن أقرّر: تُغلق النافذةُ ويقال ذلك', (tester) async {
      final duel = await pumpLobby(tester);
      duel.events.add(const DuelInviteEvent(
        kind: DuelInviteKind.invite,
        matchId: 'm9',
        fromId: 'r1',
        fromName: 'سارة',
      ));
      await settle(tester, 3);
      duel.events.add(const DuelInviteEvent(
        kind: DuelInviteKind.cancelled,
        matchId: 'm9',
        fromId: 'r1',
      ));
      await settle(tester, 5);
      expect(find.text(trf('arena.inviteTitle', {'name': 'سارة'})), findsNothing);
      expect(find.text(trf('arena.withdrawn', {'name': 'سارة'})), findsOneWidget);
    });

    testWidgets('لا تجاوزَ على شاشةٍ ضيّقةٍ ولا عريضة', (tester) async {
      await pumpLobby(tester, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      await pumpLobby(tester, size: const Size(1280, 720));
      expect(tester.takeException(), isNull);
    });
  });

  group('غرفةُ النزال', () {
    Future<FakeDuel> pumpMatch(WidgetTester tester, {Size size = const Size(390, 844)}) async {
      sized(tester, size);
      final duel = FakeDuel();
      addTearDown(duel.events.close);
      await tester.pumpWidget(
        MaterialApp(
          home: DuelMatchScreen(
            profile: me,
            duelService: duel,
            matchId: 'm1',
            rivalId: 'r1',
            rivalName: 'سارة',
            isHost: true,
            transport: ServiceDuelTransport(duel),
          ),
        ),
      );
      await settle(tester, 3);
      return duel;
    }

    Future<void> toFirstQuestion(WidgetTester tester, FakeDuel duel) async {
      expect(find.text(trf('arena.waitingRival', {'name': 'سارة'})), findsOneWidget);
      duel.signal!('ready', {'id': 'r1'});
      await settle(tester, 2);
      expect(duel.log, contains('signal:start'));
      expect(find.text(tr('arena.getReady')), findsOneWidget);
      await settle(tester, 32);
      expect(find.text(questions[0].prompt), findsOneWidget);
    }

    testWidgets('مواجهة، ثم ٣-٢-١، ثم السؤالُ بخياراته الأربعة وعدّاده', (tester) async {
      final duel = await pumpMatch(tester);
      await toFirstQuestion(tester, duel);
      expect(find.byType(AnswerTile), findsNWidgets(4));
      expect(find.byType(ArenaTimerRing), findsOneWidget);
      expect(find.byType(DuelChatButton), findsOneWidget, reason: 'الدردشةُ داخل النزال');
      expect(tester.takeException(), isNull);
    });

    testWidgets('أصبتُ أوّلاً: «أنت الأسرع!»', (tester) async {
      final duel = await pumpMatch(tester);
      await toFirstQuestion(tester, duel);
      await tester.tap(find.text('الأول'));
      await settle(tester, 2);
      expect(find.text(trf('arena.youWon', {'points': '10'})), findsOneWidget);
      expect(duel.log, contains('signal:won'));
    });

    testWidgets('سبقني زميلي: «سارة كانت أسرع!» ويُقفل السؤال', (tester) async {
      final duel = await pumpMatch(tester);
      await toFirstQuestion(tester, duel);
      duel.signal!('won', {'by': 'r1', 'index': 0});
      await settle(tester, 2);
      expect(find.text(trf('arena.rivalWon', {'name': 'سارة'})), findsOneWidget);
      final tiles = tester.widgetList<AnswerTile>(find.byType(AnswerTile));
      expect(tiles.every((t) => t.onPressed == null), isTrue);
    });

    testWidgets('النهاية: فزت، وخمسُ جواهر', (tester) async {
      final duel = await pumpMatch(tester);
      await toFirstQuestion(tester, duel);
      for (var q = 0; q < 3; q++) {
        await tester.tap(find.text('الأول'));
        await settle(tester, 25);
      }
      await settle(tester, 10);
      expect(find.text(tr('arena.win')), findsOneWidget);
      expect(find.text(trf('arena.gems', {'gems': '5'})), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('فزتُ وجائزةُ الدرس صُرفت: يقال ذلك بدل صفر', (tester) async {
      final duel = await pumpMatch(tester);
      duel.finishGems = 0;
      duel.finishTaken = true;
      await toFirstQuestion(tester, duel);
      for (var q = 0; q < 3; q++) {
        await tester.tap(find.text('الأول'));
        await settle(tester, 25);
      }
      await settle(tester, 10);
      expect(find.text(tr('arena.rewardTaken')), findsOneWidget);
    });

    testWidgets('الزميلُ لم يدخل: رسالةٌ وعودة', (tester) async {
      await pumpMatch(tester);
      await settle(tester, 270);
      expect(find.text(trf('arena.failRival', {'name': 'سارة'})), findsOneWidget);
      expect(find.text(tr('arena.back')), findsOneWidget);
    });

    testWidgets('لا تجاوزَ في السؤال على شاشةٍ ضيّقة وعريضة', (tester) async {
      for (final size in const [Size(320, 640), Size(1280, 720)]) {
        final duel = await pumpMatch(tester, size: size);
        await toFirstQuestion(tester, duel);
        expect(tester.takeException(), isNull, reason: '$size');
        await tester.pumpWidget(const SizedBox());
        await settle(tester, 2);
      }
    });
  });
}
