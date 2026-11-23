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
import 'package:manara_student/src/widgets/duel_game_scene.dart';

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

  /// كلُّ طلبٍ للحضور: الصفُّ ومن أنا.
  final List<String> joins = [];

  @override
  Future<void> joinClass(
      {required String classKey, required String myId}) async {
    joins.add('$classKey/$myId');
  }
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

  /// حزمةٌ بعينها (أسئلةُ الروضة المسموعة) بدل [questions].
  List<DuelQuestion>? pack;

  /// ما اختاره اللاعبُ لكلّ سؤال، بترتيبه.
  final choices = <int>[];

  @override
  Future<List<DuelQuestion>?> claimPack(String matchId, {bool kindergarten = false}) async => pack ?? questions;

  @override
  Future<DuelAnswerResult> answer({
    required String matchId,
    required int index,
    required int choice,
  }) async {
    choices.add(choice);
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
  kindergartenDuel();
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
      // ‏بطاقاتُ الألعاب بمشاهدها المتحرّكة أطول: التنبيهُ تحتها.
      await tester.scrollUntilVisible(find.text(tr('arena.pickGameFirst')), 200, scrollable: find.byType(Scrollable).first);
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

    testWidgets('فتحُ الساحة يطلب الحضورَ في لحظته، ومن يتصل يظهر فوراً', (tester) async {
      sized(tester, const Size(390, 1800));
      final duel = FakeDuel();
      duel.online.value = const {};
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
      expect(duel.joins, ['t1:4/me'], reason: 'الصفُّ والطالبُ يُمرَّران كما هما');
      expect(find.text(tr('arena.onlineEmpty')), findsOneWidget);
      // ‏زميلٌ فتح التطبيق: يظهر بلا إعادة فتح الشاشة.
      duel.online.value = {'r1'};
      await tester.pump();
      expect(find.text(tr('arena.onlineEmpty')), findsNothing);
      expect(find.textContaining(trf('arena.online', {'n': '1'})), findsOneWidget);
      duel.online.value = const {};
      await tester.pump();
      expect(find.text(tr('arena.onlineEmpty')), findsOneWidget);
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

    testWidgets(
        'دعوةٌ وصلتني خارج الساحة: تُفتح لها فوراً، و«مشغول» يرفضها ويعيدني حيث كنت',
        (tester) async {
      sized(tester, const Size(390, 844));
      final duel = FakeDuel();
      addTearDown(duel.events.close);
      const invite = DuelInviteEvent(
        kind: DuelInviteKind.invite,
        matchId: 'm7',
        fromId: 'r1',
        fromName: 'سارة',
      );
      // ‏الواجهةُ تفتح الساحةَ بالدعوة فوق شاشةٍ أخرى من التطبيق.
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('open-for-invite'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => StudentDuelScreen(
                    profile: me,
                    duelService: duel,
                    challengeService: NoChallenge(),
                    leaderboardService: FakeBoard(),
                    initialInvite: invite,
                  ),
                )),
                child: const Text('درسي'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('open-for-invite')));
      await settle(tester, 6);
      expect(find.text(trf('arena.inviteTitle', {'name': 'سارة'})), findsOneWidget);
      expect(find.text(tr('arena.accept')), findsOneWidget);
      expect(find.text(tr('arena.decline')), findsOneWidget);

      await tester.tap(find.text(tr('arena.decline')));
      await settle(tester, 8);
      expect(duel.log, contains('respond:m7:false'));
      expect(find.byType(StudentDuelScreen), findsNothing);
      expect(find.text('درسي'), findsOneWidget);
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

/// صفُّ الروضة وحده: أسئلتُه المسموعة وزرُّ المايك. وغيرُه بلا مايك كما كان.
void kindergartenDuel() {
  final kgPack = [
    for (var i = 1; i <= 3; i++)
      DuelQuestion(
        id: 'kg_00$i',
        category: 'general',
        prompt: 'سؤال الروضة $i؟',
        options: const ['القطة', 'الكلب', 'البقرة', 'الفيل'],
        answerAt: 0,
      ),
  ];

  /// شاشةُ نزالِ روضةٍ بمايكٍ مزيّف: يُسجَّل ما يُطلب منه، والاختبارُ يقول الكلام.
  Future<({FakeDuel duel, List<Duration> windows, List<ValueChanged<String>> results, List<ValueChanged<String>?> partials, List<int> stops})>
      openKg(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final duel = FakeDuel()..pack = kgPack;
    addTearDown(duel.events.close);
    final windows = <Duration>[];
    final results = <ValueChanged<String>>[];
    final partials = <ValueChanged<String>?>[];
    final stops = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: DuelMatchScreen(
          profile: const StudentProfile(
            id: 'me',
            username: 'me',
            name: 'أنا',
            role: 'student',
            teacherId: 't1',
            grade: 'روضة منارة المعرفة',
          ),
          duelService: duel,
          matchId: 'm1',
          rivalId: 'r1',
          rivalName: 'سارة',
          isHost: true,
          transport: ServiceDuelTransport(duel, kindergarten: true),
          ensureMic: (_) async => true,
          quietForMic: () async {},
          voiceStop: () => stops.add(1),
          voiceListen: ({required onResult, onPartial, required window}) async {
            windows.add(window);
            results.add(onResult);
            partials.add(onPartial);
            return true;
          },
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    duel.rivalJoined = true;
    // ‏العدُّ ثم مقطعُ السؤال (مهلةُ بدئه في الاختبار أربعُ ثوانٍ) ثم يظهر المايك.
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(const ValueKey('duel-kg-mic')).evaluate().isNotEmpty) break;
    }
    return (duel: duel, windows: windows, results: results, partials: partials, stops: stops);
  }

  Future<void> closeKg(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('الروضة: «أجب بصوتك» يسمع، و«بسّة» تختار «القطة» في لحظتها', (tester) async {
    final kg = await openKg(tester, const Size(360, 780));
    final mic = find.byKey(const ValueKey('duel-kg-mic'));
    await Scrollable.ensureVisible(tester.element(mic), alignment: 0.3);
    await tester.pump();
    expect(find.text(tr('duel.kg.mic')), findsOneWidget);
    await tester.tap(mic);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(kg.windows, hasLength(1), reason: 'فُتح المايكُ بعد الإذن وإسكاتِ الأصوات');
    expect(kg.windows.single.inSeconds, inInclusiveRange(3, 12));
    expect(find.text(tr('duel.kg.listening')), findsOneWidget, reason: 'حالُ الاستماع ظاهرة');
    // ‏كلامٌ لم يكتمل: يُكتب تحت الزرّ ولا يُختار شيء.
    kg.partials.single!('ال');
    await tester.pump();
    expect(kg.duel.choices, isEmpty);
    // ‏«بسّة» — لا «القطة» حرفاً — تكفي.
    kg.partials.single!('بسة');
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(kg.duel.choices, [0]);
    expect(kg.stops, isNotEmpty, reason: 'أُغلق المايكُ حين كفى الكلام');
    expect(find.byKey(const ValueKey('duel-kg-mic')), findsNothing, reason: 'أجاب: لا مايك');
    expect(tester.takeException(), isNull);
    await closeKg(tester);
  });

  for (final size in const [Size(360, 780), Size(390, 844), Size(820, 1180), Size(768, 1024), Size(1024, 768), Size(1366, 1024)]) {
    testWidgets('الترتيب على ${size.width.toInt()}×${size.height.toInt()}:المشهدُ ثم السؤالُ ثم زرُّ الجواب ثم الخيارات، بلا فيضانٍ ولا تداخل',
        (tester) async {
      await openKg(tester, size);
      expect(tester.takeException(), isNull);
      final arena = find.byKey(const ValueKey('duel-arena'));
      final scene = find.byType(DuelGameScene);
      final mic = find.byKey(const ValueKey('duel-kg-mic'));
      final chat = find.byKey(const ValueKey('duel-chat-section'));
      expect(arena, findsOneWidget);
      expect(scene, findsOneWidget, reason: 'المشهدُ المتحرّكُ حاضرٌ أثناء اللعب على كل جهاز');
      final wide = find.byKey(const ValueKey('duel-question-wide')).evaluate().isNotEmpty;
      expect(wide, size.width >= 760, reason: 'العمودان للتابلت والآيباد');
      if (!wide) {
        // ‏الهاتف: مشهدٌ قصيرٌ لا يُبعد السؤال.
        expect(tester.getSize(scene).height, lessThanOrEqualTo(140));
      }
      await Scrollable.ensureVisible(tester.element(mic), alignment: 0.2);
      await tester.pump();
      final choice = find.text('الكلب').first;
      await Scrollable.ensureVisible(tester.element(choice), alignment: 0.5);
      await tester.pump();
      expect(tester.getCenter(mic).dy, lessThan(tester.getCenter(choice).dy), reason: 'زرُّ الجواب فوق الخيارات');
      // ‏الخياراتُ داخل الشاشة، وبعرضٍ يُلمس بإصبع.
      final tile = tester.getRect(choice);
      expect(tile.left, greaterThanOrEqualTo(0));
      expect(tile.right, lessThanOrEqualTo(size.width));
      // ‏الزرُّ والخيارُ لا يتداخلان.
      expect(tester.getRect(mic).overlaps(tester.getRect(choice)), isFalse);
      if (!wide) await tester.scrollUntilVisible(chat, 200);
      expect(chat, findsOneWidget);
      expect(tester.takeException(), isNull);
      await closeKg(tester);
    });
  }

  testWidgets('الروضة: كلامٌ لم يُفهم يُقال للطفل، والزرُّ يعود «جرّب مرة أخرى»', (tester) async {
    final kg = await openKg(tester, const Size(360, 780));
    final mic = find.byKey(const ValueKey('duel-kg-mic'));
    await Scrollable.ensureVisible(tester.element(mic), alignment: 0.3);
    await tester.pump();
    await tester.tap(mic);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    kg.results.single('سيارة');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(kg.duel.choices, isEmpty);
    expect(find.text(tr('duel.kg.again')), findsOneWidget);
    expect(find.byKey(const ValueKey('duel-kg-notice')), findsOneWidget);
    // ‏ويُعاد: «الفيل» هذه المرّة.
    await tester.tap(find.byKey(const ValueKey('duel-kg-mic')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(kg.results, hasLength(2));
    kg.results.last('افيال');
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(kg.duel.choices, [3]);
    await closeKg(tester);
  });

  testWidgets('التابلت: عمودان مرتّبان، وزرُّ الجواب فوق الخيارات، والرسالةُ الصوتية في «دردشة الزملاء» ولا تسجّل والمايكُ يسمع الجواب',
      (tester) async {
    final kg = await openKg(tester, const Size(1280, 800));
    expect(find.byKey(const ValueKey('duel-question-wide')), findsOneWidget);
    final mic = find.byKey(const ValueKey('duel-kg-mic'));
    final choice = find.text('القطة').first;
    final chat = find.byKey(const ValueKey('duel-chat-section'));
    expect(mic, findsOneWidget);
    expect(chat, findsOneWidget);
    expect(tester.getCenter(mic).dy, lessThan(tester.getCenter(choice).dy), reason: 'زرُّ الجواب قبل الخيارات');
    // ‏الدردشةُ في عمود المواجهة تحت المشهد، والسؤالُ وجوابُه وحدهما في العمود الآخر.
    final arena = find.byKey(const ValueKey('duel-arena'));
    expect((tester.getCenter(chat).dx - tester.getCenter(choice).dx).abs(), greaterThan(300), reason: 'الدردشةُ بعيدةٌ عن الخيارات');
    expect((tester.getCenter(chat).dx - tester.getCenter(arena).dx).abs(), lessThan(40), reason: 'في عمود المشهد');
    expect(tester.getCenter(chat).dy, greaterThan(tester.getCenter(arena).dy), reason: 'تحت المشهد');
    expect(find.descendant(of: chat, matching: find.byType(DuelVoiceButton)), findsOneWidget);
    expect(find.descendant(of: chat, matching: mic), findsNothing);
    expect(tester.takeException(), isNull, reason: 'لا فيضانَ في العرض العريض');

    await tester.tap(mic);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(kg.windows, hasLength(1));
    // ‏ضغطٌ مطوّلٌ على الرسالة الصوتية والمايكُ يسمع الجواب: لا تسجيل، ويُقال لماذا.
    final gesture = await tester.startGesture(tester.getCenter(find.byType(DuelVoiceButton)));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(tr('duel.voice.busyAnswer')), findsOneWidget);
    // ‏لمسةٌ ثانيةٌ على زرّ الجواب تُنهي الاستماع.
    await tester.tap(mic);
    await tester.pump();
    expect(kg.stops, isNotEmpty);
    kg.results.single('');
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(tr('duel.kg.notHeard')), findsOneWidget);
    await closeKg(tester);
  });

  for (final kg in [true, false]) {
    testWidgets(kg ? 'الروضة: مقطعُ السؤال ثم المايكُ، و«أحسنت يا بطل» للأسرع' : 'الرابع: لا مايكَ ولا مقطع — كما كان',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      StudentSettings.resetForTest();
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final duel = FakeDuel()..pack = kg ? kgPack : null;
      addTearDown(duel.events.close);
      await tester.pumpWidget(
        MaterialApp(
          home: DuelMatchScreen(
            profile: StudentProfile(
              id: 'me',
              username: 'me',
              name: 'أنا',
              role: 'student',
              teacherId: 't1',
              grade: kg ? 'روضة منارة المعرفة' : 'الصف الرابع الابتدائي',
            ),
            duelService: duel,
            matchId: 'm1',
            rivalId: 'r1',
            rivalName: 'سارة',
            isHost: true,
            transport: ServiceDuelTransport(duel, kindergarten: kg),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      duel.rivalJoined = true;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(kg ? kgPack[0].prompt : questions[0].prompt), findsOneWidget);
      final mic = find.byKey(const ValueKey('duel-kg-mic'));
      if (kg) {
        await tester.scrollUntilVisible(mic, 200, scrollable: find.byType(Scrollable).first);
        expect(mic, findsOneWidget);
      } else {
        expect(mic, findsNothing);
        expect(find.byKey(const ValueKey('duel-kg-hearing')), findsNothing);
      }
      final option = find.text(kg ? 'القطة' : 'الأول').first;
      await Scrollable.ensureVisible(tester.element(option), alignment: 0.5);
      await tester.pump();
      await tester.tap(option);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const ValueKey('duel-kg-mic')), findsNothing, reason: 'أجاب: لا مايك');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      // ‏«أحسنت يا بطل» ينتظر انتهاءَ العبارة (حتى ٦ ثوانٍ).
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    });
  }
}
