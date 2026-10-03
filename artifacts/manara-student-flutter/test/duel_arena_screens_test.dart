import 'dart:async';

import 'package:clock/clock.dart';

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

DuelMatch matchOf(String id, {int? mine, int? theirs, bool iWon = false}) =>
    DuelMatch(
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
  Future<void> joinClass(
      {required String classKey, required String myId}) async {}
  @override
  Future<void> leaveClass() async {}
  @override
  Future<List<DuelStanding>> standings() async => const [];
  @override
  Future<List<DuelChatMessage>> messages(String matchId) async => const [];

  @override
  Future<DuelMatch> invite({
    required String lessonId,
    required List<String> guestIds,
    DuelGame game = DuelGame.sprint,
  }) async {
    log.add('invite:${guestIds.join(',')}:${game.id}');
    phases['m1'] = DuelRoomPhase.invited;
    return matchOf('m1');
  }

  // ── الخادم: حالُ كل غرفة، ومن دخلها ──
  final Map<String, DuelRoomPhase> phases = {};
  final Set<String> joined = {};
  bool rivalJoined = false;
  DateTime? startAt;

  DuelRoom roomOf(String id) {
    final phase = phases[id] ?? DuelRoomPhase.accepted;
    if (phase == DuelRoomPhase.accepted && joined.contains(id) && rivalJoined) {
      startAt ??= clock.now().add(const Duration(seconds: 2));
      return DuelRoom(phase: DuelRoomPhase.ready, startAt: startAt);
    }
    return DuelRoom(phase: phase);
  }

  @override
  Future<DuelRoom> respond(
      {required String matchId, required bool accept}) async {
    log.add('respond:$matchId:$accept');
    final now = phases[matchId] ?? DuelRoomPhase.invited;
    if (now == DuelRoomPhase.invited) {
      phases[matchId] = accept ? DuelRoomPhase.accepted : DuelRoomPhase.expired;
    }
    return roomOf(matchId);
  }

  @override
  Future<DuelRoom> join(String matchId) async {
    log.add('join:$matchId');
    joined.add(matchId);
    return roomOf(matchId);
  }

  @override
  Future<DuelRoom> room(String matchId) async => roomOf(matchId);

  @override
  bool sendInvite({
    required String to,
    required DuelMatch match,
    required String myName,
    Map<String, dynamic>? myAppearance,
    List<String> players = const [],
  }) {
    log.add('sendInvite:$to:${match.id}:${players.join(',')}');
    return true;
  }

  @override
  bool replyInvite(
      {required String to, required String matchId, required bool accepted}) {
    log.add('reply:$matchId:$accepted');
    return true;
  }

  @override
  bool cancelInvite({required String to, required String matchId}) {
    log.add('cancelInvite:$matchId');
    return true;
  }

  @override
  Future<DuelRoom?> cancel(String matchId) async {
    log.add('cancel:$matchId');
    if (!rivalJoined) phases[matchId] = DuelRoomPhase.expired;
    return roomOf(matchId);
  }

  @override
  Future<void> watchMatch({
    required String matchId,
    required void Function(String studentId, int progress) onProgress,
    void Function(DuelChatMessage message)? onChat,
    void Function(String studentId, bool muted)? onMute,
    void Function(String studentId, int index, int points)? onAnswered,
    void Function(String event, Map<String, dynamic> payload)? onSignal,
    void Function(String studentId, String emoji)? onReaction,
  }) async {
    signal = onSignal;
    reaction = onReaction;
  }

  void Function(String studentId, String emoji)? reaction;

  @override
  void sendReaction({required String myId, required String emoji}) {
    log.add('react:$emoji');
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
    return DuelAnswerResult(
        correct: correct, won: win, answerAt: 0, points: win ? 10 : 0);
  }

  int finishMine = 20;
  int finishTheirs = 10;
  int finishGems = 5;
  bool finishTaken = false;

  @override
  Future<DuelResult> finish(String matchId) async => DuelResult(
        match: matchOf(matchId,
            mine: finishMine,
            theirs: finishTheirs,
            iWon: finishMine > finishTheirs),
        gems: finishGems,
        draw: finishMine == finishTheirs,
        rewardTaken: finishTaken,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeBoard implements StudentLeaderboardService {
  int fetches = 0;
  List<LeaderboardEntry> entries = const [
    LeaderboardEntry(
        id: 'r1', name: 'سارة', gems: 9, xp: 9, level: 1, rank: 1, isMe: false),
    LeaderboardEntry(
        id: 'r2', name: 'خالد', gems: 5, xp: 5, level: 1, rank: 2, isMe: false),
    LeaderboardEntry(
        id: 'r3', name: 'منى', gems: 3, xp: 3, level: 1, rank: 3, isMe: false),
    LeaderboardEntry(
        id: 'me', name: 'أنا', gems: 1, xp: 1, level: 1, rank: 4, isMe: true),
  ];

  @override
  Future<LeaderboardResult> fetch() async {
    fetches += 1;
    return LeaderboardResult.ready(
      Leaderboard(
        entries: entries,
        myRank: 4,
        total: 4,
        topGems: 9,
        gemsToNext: 2,
        listed: true,
      ),
    );
  }

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
  gamesAndThemes();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  void sized(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// يمرّر الساحةَ حتى يظهر الهدف: بطاقاتُ الألعاب تدفع الزملاءَ تحت حافّة الهاتف.
  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    // والقائمةُ كسولة: ما تحت الحافّة بكثيرٍ لم يُبنَ بعد، فيُمرَّر إليه.
    // والهدفُ قد يكون فوق ما مُرِّر إليه: يُجرَّب الاتجاهان.
    for (final step in const [200.0, -200.0]) {
      if (target.evaluate().isNotEmpty) break;
      try {
        await tester.scrollUntilVisible(
          target,
          step,
          scrollable: find.byType(Scrollable).first,
        );
      } on StateError {
        // ليس في هذا الاتجاه.
      }
    }
    await tester.ensureVisible(target);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(target);
  }

  Future<void> settle(WidgetTester tester, [int steps = 10]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('الساحة', () {
    Future<FakeDuel> pumpLobby(
      WidgetTester tester, {
      Size size = const Size(390, 844),
      FakeBoard? board,
    }) async {
      sized(tester, size);
      final duel = FakeDuel();
      addTearDown(duel.events.close);
      await tester.pumpWidget(
        MaterialApp(
          home: StudentDuelScreen(
            profile: me,
            duelService: duel,
            challengeService: NoChallenge(),
            leaderboardService: board ?? FakeBoard(),
            academicContext: lessonContext,
          ),
        ),
      );
      await settle(tester);
      return duel;
    }

    Finder championRow(String id) => find.byKey(ValueKey('champion-$id'));

    testWidgets('أبطالُ الصف: بمجموع الخبرة والجواهر، والأوّلُ بالذهب والتاج',
        (tester) async {
      await pumpLobby(tester, size: const Size(390, 2200));
      expect(find.text(tr('arena.championsEmpty')), findsNothing);
      for (final (id, medal) in [('r1', '🥇'), ('r2', '🥈'), ('r3', '🥉')]) {
        expect(
          find.descendant(of: championRow(id), matching: find.text(medal)),
          findsOneWidget,
          reason: id,
        );
      }
      expect(find.descendant(of: championRow('r1'), matching: find.text('👑')),
          findsOneWidget);
      expect(
          find.descendant(
              of: championRow('r1'),
              matching: find.text(trf('arena.championsScore', {'n': '18'}))),
          findsOneWidget);
      // الرابعُ برقمه، وصفّي معلَّم.
      expect(find.descendant(of: championRow('me'), matching: find.text('4')),
          findsOneWidget);
      expect(
          find.descendant(
              of: championRow('me'),
              matching: find.textContaining(tr('arena.championsYou'))),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('أبطالُ الصف يتحدّثون وحدهم: زميلٌ تقدّم فيصعد',
        (tester) async {
      final board = FakeBoard();
      await pumpLobby(tester, size: const Size(390, 2200), board: board);
      final before = board.fetches;
      board.entries = [
        ...board.entries.where((e) => e.id != 'r3'),
        const LeaderboardEntry(
            id: 'r3',
            name: 'منى',
            gems: 20,
            xp: 15,
            level: 2,
            rank: 3,
            isMe: false),
      ];
      await tester.pump(const Duration(seconds: 21));
      await settle(tester);
      expect(board.fetches, greaterThan(before));
      expect(find.descendant(of: championRow('r3'), matching: find.text('🥇')),
          findsOneWidget);
      expect(find.descendant(of: championRow('r1'), matching: find.text('🥈')),
          findsOneWidget);
    });

    /// يختار زميلاً بالضغط على بطاقته.
    Future<void> pick(WidgetTester tester, String name) async {
      final card = find.ancestor(
        of: find.text(name),
        matching: find
            .byWidgetPredicate((w) => w.runtimeType.toString() == '_RivalCard'),
      );
      await tapVisible(tester, card);
      await settle(tester, 2);
    }

    testWidgets('اللعبةُ أوّلاً: التحدي مقفلٌ حتى تُختار', (tester) async {
      final duel = await pumpLobby(tester);
      expect(find.text(tr('arena.pickGameFirst')), findsOneWidget);
      for (final game in DuelGame.values) {
        expect(find.text(game.label), findsOneWidget);
      }
      await pick(tester, 'سارة');
      expect(find.text(tr('arena.party.picked')), findsNothing,
          reason: 'لا اختيارَ قبل اللعبة');
      await tapVisible(tester, find.text(tr('arena.challenge')));
      await settle(tester, 2);
      expect(duel.log.where((e) => e.startsWith('invite')), isEmpty);
      await tapVisible(tester, find.text(DuelGame.balloons.label));
      await settle(tester, 2);
      expect(find.text(tr('arena.pickGameFirst')), findsNothing);
      await pick(tester, 'سارة');
      expect(find.text(tr('arena.party.picked')), findsOneWidget);
      await tapVisible(
          tester, find.text(trf('arena.party.challengeN', {'n': '1'})));
      await settle(tester, 3);
      expect(duel.log, contains('invite:r1:balloons'));
    });

    testWidgets('المتصلُ وحده يُتحدّى، والغائبون شاحبون بلا زرّ',
        (tester) async {
      // شاشةٌ طويلة: القائمةُ تُبنى كسولةً، والغائبون في آخرها.
      await pumpLobby(tester, size: const Size(390, 1800));
      expect(
          find.textContaining(trf('arena.online', {'n': '1'})), findsOneWidget);
      expect(find.text(tr('arena.party.pick')), findsOneWidget);
      // مرّةً في بطاقة التحدّي، ومرّةً في «أبطال الصف».
      expect(find.text('سارة'), findsNWidgets(2));
      expect(find.text(tr('arena.unavailable')), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'اختيارٌ متعدّد: زميلان بضغطةٍ لكلٍّ، ودعوةٌ واحدةٌ تصلهما معاً',
        (tester) async {
      sized(tester, const Size(390, 1800));
      final duel = FakeDuel();
      duel.online.value = {'r1', 'r2'};
      addTearDown(duel.events.close);
      await tester.pumpWidget(MaterialApp(
        home: StudentDuelScreen(
          profile: me,
          duelService: duel,
          challengeService: NoChallenge(),
          leaderboardService: FakeBoard(),
          academicContext: lessonContext,
        ),
      ));
      await settle(tester);
      await tapVisible(tester, find.text(DuelGame.tug.label));
      await settle(tester, 2);
      await pick(tester, 'سارة');
      await pick(tester, 'خالد');
      expect(find.text(tr('arena.party.picked')), findsNWidgets(2));
      expect(find.text(tr('arena.party.rules')), findsOneWidget);
      await tapVisible(
          tester, find.text(trf('arena.party.challengeN', {'n': '2'})));
      await settle(tester, 3);
      expect(duel.log, contains('invite:r1,r2:tug'));
      expect(
          duel.log,
          containsAll(
              ['sendInvite:r1:m1:me,r1,r2', 'sendInvite:r2:m1:me,r1,r2']));
      final screen =
          tester.widget<DuelMatchScreen>(find.byType(DuelMatchScreen));
      expect(screen.rivals.map((r) => r.id), ['r1', 'r2']);
      expect(find.text(tr('arena.party.waitingTitle')), findsOneWidget);
    });

    testWidgets('يتحدّى فيدخل غرفةَ الانتظار فوراً، ويبدأ حين يوافق الزميل',
        (tester) async {
      final duel = await pumpLobby(tester);
      await tapVisible(tester, find.text(DuelGame.sprint.label));
      await settle(tester, 2);
      await pick(tester, 'سارة');
      await tapVisible(
          tester, find.text(trf('arena.party.challengeN', {'n': '1'})));
      await settle(tester, 3);
      expect(duel.log,
          containsAll(['invite:r1:sprint', 'sendInvite:r1:m1:me,r1']));
      expect(find.byType(DuelMatchScreen), findsOneWidget);
      expect(find.text(tr('arena.party.waitingTitle')), findsOneWidget);
      expect(find.text(tr('arena.party.pending')), findsOneWidget);

      // الخادمُ: وافق الزميلُ فحُسم من يلعب.
      duel.phases['m1'] = DuelRoomPhase.accepted;
      duel.rivalJoined = true;
      await settle(tester, 6);
      expect(find.text(tr('arena.getReady')), findsOneWidget);
    });

    testWidgets('لم يوافق أحد: يعود إلى الساحة وحده ويقال ذلك', (tester) async {
      final duel = await pumpLobby(tester);
      await tapVisible(tester, find.text(DuelGame.sprint.label));
      await settle(tester, 2);
      await pick(tester, 'سارة');
      await tapVisible(
          tester, find.text(trf('arena.party.challengeN', {'n': '1'})));
      await settle(tester, 3);
      duel.phases['m1'] = DuelRoomPhase.expired;
      await settle(tester, 10);
      expect(find.text(tr('arena.failNobody')), findsOneWidget);
      await settle(tester, 30);
      expect(find.byType(DuelMatchScreen), findsNothing,
          reason: 'عاد إلى الساحة');
      expect(find.text(tr('arena.failNobody')), findsOneWidget,
          reason: 'رسالةٌ في الساحة');
      expect(duel.log, contains('cancelInvite:m1'));
    });

    testWidgets('غادرتُ غرفةَ الانتظار: تُلغى الدعوة', (tester) async {
      final duel = await pumpLobby(tester);
      await tapVisible(tester, find.text(DuelGame.sprint.label));
      await settle(tester, 2);
      await pick(tester, 'سارة');
      await tapVisible(
          tester, find.text(trf('arena.party.challengeN', {'n': '1'})));
      await settle(tester, 3);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await settle(tester, 5);
      expect(duel.log, containsAll(['cancel:m1', 'cancelInvite:m1']));
      expect(find.byType(DuelMatchScreen), findsNothing);
    });

    testWidgets('ولا زرَّ دردشة في الساحة', (tester) async {
      await pumpLobby(tester);
      expect(find.byType(DuelVoiceButton), findsNothing);
      expect(find.byType(DuelReactionBar), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('تحدٍّ جماعيٌّ يصلني: أعرف من معي، وأدخل بهم جميعاً',
        (tester) async {
      final duel = await pumpLobby(tester);
      duel.events.add(const DuelInviteEvent(
        kind: DuelInviteKind.invite,
        matchId: 'm9',
        fromId: 'r1',
        fromName: 'سارة',
        players: ['r1', 'me', 'r2'],
      ));
      await settle(tester, 3);
      expect(find.textContaining('خالد'), findsWidgets);
      await tester.tap(find.text(tr('arena.accept')));
      await settle(tester, 5);
      final screen =
          tester.widget<DuelMatchScreen>(find.byType(DuelMatchScreen));
      expect(screen.rivals.map((r) => r.id), ['r1', 'r2']);
      expect(screen.isHost, isFalse);
    });

    testWidgets('يصلني تحدٍّ فأقبله: أردّ، وتُفتح الغرفةُ ضيفاً',
        (tester) async {
      final duel = await pumpLobby(tester);
      duel.events.add(const DuelInviteEvent(
        kind: DuelInviteKind.invite,
        matchId: 'm9',
        fromId: 'r1',
        fromName: 'سارة',
      ));
      await settle(tester, 3);
      expect(find.text(trf('arena.inviteTitle', {'name': 'سارة'})),
          findsOneWidget);
      await tester.tap(find.text(tr('arena.accept')));
      await settle(tester, 5);
      expect(duel.log, containsAll(['respond:m9:true', 'reply:m9:true']));
      final screen =
          tester.widget<DuelMatchScreen>(find.byType(DuelMatchScreen));
      expect(screen.isHost, isFalse);
      expect(screen.matchId, 'm9');
    });

    testWidgets('قبلتُ دعوةً انتهت في الخادم: لا غرفة، ويقال ذلك',
        (tester) async {
      final duel = await pumpLobby(tester);
      duel.phases['m9'] = DuelRoomPhase.expired;
      duel.events.add(const DuelInviteEvent(
        kind: DuelInviteKind.invite,
        matchId: 'm9',
        fromId: 'r1',
        fromName: 'سارة',
      ));
      await settle(tester, 3);
      await tester.tap(find.text(tr('arena.accept')));
      await settle(tester, 5);
      expect(find.byType(DuelMatchScreen), findsNothing);
      expect(find.text(tr('arena.inviteGone')), findsOneWidget);
      expect(duel.log.where((e) => e == 'reply:m9:true'), isEmpty);
    });

    testWidgets('الدعوةُ المكرّرة لا تُرفض آلياً', (tester) async {
      // ما رآه الداعي: «لا يستطيع» وزميلُه قبل. كانت الإشارةُ تصل مرّتين،
      // والثانيةُ تُرفض بحجّة «مشغول».
      final duel = await pumpLobby(tester);
      const event = DuelInviteEvent(
        kind: DuelInviteKind.invite,
        matchId: 'm9',
        fromId: 'r1',
        fromName: 'سارة',
      );
      duel.events.add(event);
      duel.events.add(event);
      await settle(tester, 3);
      expect(duel.log.where((e) => e.endsWith(':false')), isEmpty);
      expect(find.text(trf('arena.inviteTitle', {'name': 'سارة'})),
          findsOneWidget);
    });

    testWidgets('وسحبه صاحبُه قبل أن أقرّر: تُغلق النافذةُ ويقال ذلك',
        (tester) async {
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
      expect(
          find.text(trf('arena.inviteTitle', {'name': 'سارة'})), findsNothing);
      expect(
          find.text(trf('arena.withdrawn', {'name': 'سارة'})), findsOneWidget);
    });

    testWidgets('لا تجاوزَ على شاشةٍ ضيّقةٍ ولا عريضة', (tester) async {
      await pumpLobby(tester, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      await pumpLobby(tester, size: const Size(1280, 720));
      expect(tester.takeException(), isNull);
    });
  });

  group('غرفةُ النزال', () {
    Future<FakeDuel> pumpMatch(WidgetTester tester,
        {Size size = const Size(390, 844)}) async {
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
      expect(find.text(tr('arena.party.waitingTitle')), findsOneWidget);
      expect(find.byType(DuelReactionBar), findsNothing,
          reason: 'لا تواصلَ والزميلُ غائب');
      duel.rivalJoined = true;
      duel.signal!('ready', {'id': 'r1'});
      await settle(tester, 4);
      expect(find.text(tr('arena.getReady')), findsOneWidget);
      expect(find.byType(DuelReactionBar), findsOneWidget);
      await settle(tester, 24);
      expect(find.text(questions[0].prompt), findsOneWidget);
    }

    testWidgets('مواجهة، ثم ٣-٢-١، ثم السؤالُ بخياراته الأربعة وعدّاده',
        (tester) async {
      final duel = await pumpMatch(tester);
      await toFirstQuestion(tester, duel);
      expect(find.byType(AnswerTile), findsNWidgets(4));
      expect(find.byType(ArenaTimerRing), findsOneWidget);
      expect(find.byType(DuelReactionBar), findsOneWidget,
          reason: 'التفاعلاتُ داخل النزال');
      // ولا دردشةَ كتابية: لا حقلَ كتابةٍ في النزال.
      expect(find.byType(TextField), findsNothing);
      // وزرُّ الصوت تحت الخيارات.
      await tester.dragUntilVisible(
        find.byType(DuelVoiceButton),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.byType(DuelVoiceButton), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(DuelVoiceButton)).dy,
        greaterThan(tester.getTopLeft(find.byType(AnswerTile).last).dy),
        reason: 'أسفلَ الخيارات',
      );
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
      expect(
          find.text(trf('arena.rivalWon', {'name': 'سارة'})), findsOneWidget);
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

    testWidgets('الزميلُ لم يدخل: لا عدَّ ولا سؤالَ ولا دردشة، ثم رسالةٌ وعودة',
        (tester) async {
      await pumpMatch(tester);
      for (var i = 0; i < 33; i++) {
        await settle(tester, 10);
        expect(find.text(tr('arena.getReady')), findsNothing);
        expect(find.byType(AnswerTile), findsNothing);
        expect(find.byType(DuelReactionBar), findsNothing);
      }
      expect(
          find.text(trf('arena.failRival', {'name': 'سارة'})), findsOneWidget);
      expect(find.text(tr('arena.back')), findsOneWidget);
    });

    testWidgets('نزالٌ جماعي: لوحةُ نتائجٍ حيّة، ومن كسب السؤالَ يُسمّى',
        (tester) async {
      sized(tester, const Size(390, 1000));
      final duel = FakeDuel();
      addTearDown(duel.events.close);
      await tester.pumpWidget(MaterialApp(
        home: DuelMatchScreen(
          profile: me,
          duelService: duel,
          matchId: 'm1',
          rivalId: 'r1',
          rivalName: 'سارة',
          rivals: const [
            DuelRival(id: 'r1', name: 'سارة'),
            DuelRival(id: 'r2', name: 'خالد'),
          ],
          isHost: true,
          transport: ServiceDuelTransport(duel),
        ),
      ));
      await settle(tester, 3);
      expect(find.text(tr('arena.party.waitingTitle')), findsOneWidget);
      expect(find.text('سارة'), findsOneWidget);
      expect(find.text('خالد'), findsOneWidget);
      await toFirstQuestion(tester, duel);
      expect(find.textContaining(tr('arena.scoreboard')), findsOneWidget);
      duel.signal!('won', {'by': 'r2', 'index': 0});
      await settle(tester, 6);
      expect(
          find.text(trf('arena.rivalWon', {'name': 'خالد'})), findsOneWidget);
      expect(find.text(trf('arena.party.points', {'n': '10'})), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('تفاعلٌ: يطير عندي ويُبثّ، وتفاعلُ زميلي يطير باسمه',
        (tester) async {
      final duel = await pumpMatch(tester);
      await toFirstQuestion(tester, duel);
      await tester.tap(find.descendant(
          of: find.byType(DuelReactionBar), matching: find.text('🔥')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(duel.log, contains('react:🔥'));
      expect(find.text('🔥'), findsNWidgets(2),
          reason: 'في الشريط، وطائرٌ فوقه');
      duel.reaction!('r1', '👏');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('👏'), findsNWidgets(2));
      expect(find.text('سارة'), findsWidgets);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('🔥'), findsOneWidget, reason: 'طار واختفى');
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

/// كلُّ لعبةٍ بحلبتها وخياراتها، في الوضعين.
void gamesAndThemes() {
  for (final dark in [false, true]) {
    for (final game in DuelGame.values) {
      testWidgets(
          '${game.id} ${dark ? 'داكن' : 'فاتح'}: الحلبةُ والخياراتُ بلا تجاوز',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        StudentSettings.resetForTest();
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final duel = FakeDuel();
        addTearDown(duel.events.close);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: DuelMatchScreen(
              profile: me,
              duelService: duel,
              matchId: 'm1',
              rivalId: 'r1',
              rivalName: 'سارة',
              isHost: true,
              game: game,
              transport: ServiceDuelTransport(duel),
            ),
          ),
        );
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        duel.rivalJoined = true;
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text(questions[0].prompt), findsOneWidget);
        // الأرضيةُ تتبع الوضع: لا ليلٌ بنفسجيٌّ ثابتٌ في الفاتح.
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(
          scaffold.backgroundColor,
          dark ? const Color(0xFF0E1117) : const Color(0xFFFDF3EA),
        );
        await tester.tap(find.text('الأول').first);
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
      });
    }
  }
}
