import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/models/duel_question.dart';
import 'package:manara_student/src/services/duel_live_controller.dart';
import 'package:manara_student/src/services/student_duel_service.dart';

/// التحدي الجماعي: ثلاثةٌ أو أكثر في الغرفة نفسها، وأوّلُ صحيحٍ يكسب السؤال.
///
/// الخادمُ مُحاكى كما يحكم \`partyRoomOf\` و\`record_duel_answer\`، والقناةُ تبثّ
/// ما يرسله كلُّ جهازٍ إلى البقية.
class PartyServer {
  PartyServer(this.questions);

  final List<DuelQuestion> questions;

  /// \`null\` ما دامت الدعوةُ تنتظر الردود؛ ثم قائمةُ من يلعب، أو فارغةٌ للإلغاء.
  List<String>? roster;
  DateTime? startAt;
  final Map<int, String> winners = {};
  final List<String> cancelled = [];

  DuelRoom room() {
    final list = roster;
    if (list == null) {
      return const DuelRoom(
        phase: DuelRoomPhase.invited,
        players: [
          DuelRoomPlayer(id: 'h', status: DuelPlayerStatus.host),
          DuelRoomPlayer(id: 'a', status: DuelPlayerStatus.accepted),
          DuelRoomPlayer(id: 'b', status: DuelPlayerStatus.pending),
        ],
      );
    }
    if (list.isEmpty) return const DuelRoom(phase: DuelRoomPhase.expired);
    startAt ??= clock.now().add(const Duration(seconds: 2));
    return DuelRoom(
      phase: DuelRoomPhase.ready,
      roster: list,
      startAt: startAt,
      players: const [DuelRoomPlayer(id: 'h', status: DuelPlayerStatus.host)],
    );
  }

  DuelAnswerResult answer(String who, int index, int choice) {
    final correct = choice == questions[index].answerAt;
    final won = correct && !winners.containsKey(index);
    if (won) winners[index] = who;
    return DuelAnswerResult(
      correct: correct,
      won: won,
      answerAt: questions[index].answerAt,
      points: won ? 10 : 0,
    );
  }
}

class PartyLink implements DuelLiveTransport {
  PartyLink(this.server, this.me, this.everyone);

  final PartyServer server;
  final String me;
  final Map<String, DuelLiveController> everyone;

  @override
  Future<List<DuelQuestion>?> claimPack(String matchId) async =>
      server.questions;

  @override
  Future<DuelAnswerResult> answer({
    required String matchId,
    required int index,
    required int choice,
  }) async =>
      server.answer(me, index, choice);

  @override
  Future<DuelResult> finish(String matchId) async => const DuelResult(
        match: null,
        gems: 0,
        draw: false,
        rewardTaken: false,
      );

  @override
  Future<void> cancel(String matchId) async => server.cancelled.add(me);

  @override
  Future<DuelRoom> join(String matchId) async => server.room();

  @override
  Future<DuelRoom> room(String matchId) async => server.room();

  @override
  bool send(String event, Map<String, Object?> payload) {
    for (final entry in everyone.entries) {
      if (entry.key == me) continue;
      final target = entry.value;
      Timer(const Duration(milliseconds: 30), () {
        target.onSignal(event, Map<String, dynamic>.from(payload));
      });
    }
    return true;
  }
}

List<DuelQuestion> pack(int n) => [
      for (var i = 0; i < n; i++)
        DuelQuestion(
          id: 'q$i',
          category: 'general',
          prompt: 'سؤال $i',
          options: const ['a', 'b', 'c', 'd'],
          answerAt: 0,
        ),
    ];

void main() {
  late PartyServer server;
  late Map<String, DuelLiveController> players;

  void build({List<String> ids = const ['h', 'a', 'b']}) {
    server = PartyServer(pack(3));
    players = {};
    for (final id in ids) {
      players[id] = DuelLiveController(
        transport: PartyLink(server, id, players),
        matchId: 'm',
        myId: id,
        rivalId: ids.firstWhere((other) => other != id),
        rivalIds: [
          for (final other in ids)
            if (other != id) other
        ],
        isHost: id == 'h',
        questionWindow: const Duration(seconds: 5),
        revealHold: const Duration(milliseconds: 500),
        rivalWait: const Duration(seconds: 25),
      );
    }
  }

  Future<void> run(WidgetTester tester, Duration total) async {
    for (var i = 0; i < total.inMilliseconds ~/ 50; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  void scenario(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      await tester.pumpWidget(const SizedBox());
      await body(tester);
      for (final player in players.values) {
        player.dispose();
      }
      await tester.pump(const Duration(seconds: 5));
    });
  }

  Future<void> startAll(WidgetTester tester) async {
    for (final player in players.values) {
      unawaited(player.start());
    }
    await run(tester, const Duration(milliseconds: 300));
  }

  scenario('ينتظرون الردود، ثم يبدأ الجميعُ معاً حين يُحسم من يلعب',
      (tester) async {
    build();
    await startAll(tester);
    for (final player in players.values) {
      expect(player.phase, DuelPhase.waitingRival);
    }
    expect(players['h']!.room?.players.length, 3,
        reason: 'غرفةُ الانتظار بحال كلِّ مدعوّ');
    server.roster = ['h', 'a', 'b'];
    await run(tester, const Duration(milliseconds: 800));
    for (final player in players.values) {
      expect(player.phase, DuelPhase.countdown);
    }
    await run(tester, const Duration(milliseconds: 2200));
    for (final player in players.values) {
      expect(player.phase, DuelPhase.question);
      expect(player.index, 0);
    }
  });

  scenario('أوّلُ صحيحٍ يكسب، والجميعُ يرى من كسب، والترتيبُ حيّ',
      (tester) async {
    build();
    server.roster = ['h', 'a', 'b'];
    await startAll(tester);
    await run(tester, const Duration(milliseconds: 2500));
    unawaited(players['a']!.pick(0));
    await run(tester, const Duration(milliseconds: 200));
    expect(players['a']!.winner, QuestionWinner.me);
    for (final id in ['h', 'b']) {
      expect(players[id]!.winner, QuestionWinner.rival, reason: id);
      expect(players[id]!.winnerId, 'a', reason: id);
      expect(players[id]!.pointsOf('a'), 10, reason: id);
      expect(players[id]!.leaderId, 'a', reason: id);
    }
    final board = players['h']!.standings;
    expect(board.first.id, 'a');
    expect(board.first.rank, 1);
    expect(board.where((row) => row.rank == 2).length, 2,
        reason: 'المتساويان في مركزٍ واحد');
  });

  scenario('أجاب الجميعُ خطأً: يُكشف الجوابُ بلا انتظار الوقت', (tester) async {
    build();
    server.roster = ['h', 'a', 'b'];
    await startAll(tester);
    await run(tester, const Duration(milliseconds: 2500));
    for (final player in players.values) {
      unawaited(player.pick(1));
    }
    await run(tester, const Duration(milliseconds: 300));
    for (final player in players.values) {
      expect(player.phase, DuelPhase.reveal);
    }
  });

  scenario('من تأخّر خارجُ القائمة: يقال له «بدأ بدونك»، ولا يُنتظر',
      (tester) async {
    build();
    server.roster = ['h', 'a'];
    await startAll(tester);
    expect(players['b']!.phase, DuelPhase.failed);
    expect(players['b']!.failure, DuelFailureKind.excluded);
    expect(players['h']!.rivals, ['a']);
    await run(tester, const Duration(milliseconds: 2500));
    // b لم يلعب: جوابُ a وحده يكفي ليُكشف السؤالُ عند h بعد جوابه.
    unawaited(players['h']!.pick(1));
    unawaited(players['a']!.pick(1));
    await run(tester, const Duration(milliseconds: 300));
    expect(players['h']!.phase, DuelPhase.reveal);
  });

  scenario('لم يوافق أحد: الداعي يُقال له ذلك، والمدعوُّ يُقال له أُلغي',
      (tester) async {
    build();
    server.roster = [];
    await startAll(tester);
    expect(players['h']!.failure, DuelFailureKind.nobodyAccepted);
    expect(players['a']!.failure, DuelFailureKind.rivalMissing);
  });

  scenario('غادر أحدُهم في منتصف النزال: يُذكر اسمُه ويُكمل الباقون',
      (tester) async {
    build();
    server.roster = ['h', 'a', 'b'];
    await startAll(tester);
    await run(tester, const Duration(milliseconds: 2500));
    players['b']!.leave();
    await run(tester, const Duration(milliseconds: 100));
    expect(players['h']!.lastLeft, 'b');
    expect(players['h']!.rivalLeft, isFalse, reason: 'ما زال a');
    unawaited(players['h']!.pick(1));
    unawaited(players['a']!.pick(1));
    await run(tester, const Duration(milliseconds: 300));
    expect(players['h']!.phase, DuelPhase.reveal, reason: 'لا ينتظر من غادر');
  });
}
