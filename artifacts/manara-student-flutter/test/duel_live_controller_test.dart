import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/models/duel_question.dart';
import 'package:manara_student/src/services/duel_live_controller.dart';
import 'package:manara_student/src/services/student_duel_service.dart';

/// الخادم: يحسم الأسبقيةَ والنتيجة كما يحسمها `record_duel_answer`.
class FakeServer {
  FakeServer(this.questions);

  final List<DuelQuestion> questions;
  final Map<int, String> winners = {};
  final Set<String> attempts = {};
  final List<String> cancelled = [];
  bool packAvailable = true;

  /// تأخيرُ ردّ الجواب لكل لاعب: به يُختبر من يصل أوّلاً.
  final Map<String, Duration> answerDelay = {};

  int points(String id) =>
      winners.values.where((winner) => winner == id).length * 10;

  Future<DuelAnswerResult> answer(String who, int index, int choice) async {
    await Future<void>.delayed(answerDelay[who] ?? Duration.zero);
    final key = '$who:$index';
    final correct = choice == questions[index].answerAt;
    if (!attempts.add(key)) {
      return DuelAnswerResult(
        correct: correct,
        won: winners[index] == who,
        answerAt: questions[index].answerAt,
        points: 0,
      );
    }
    final won = correct && !winners.containsKey(index);
    if (won) winners[index] = who;
    return DuelAnswerResult(
      correct: correct,
      won: won,
      answerAt: questions[index].answerAt,
      points: won ? 10 : 0,
    );
  }

  DuelResult finish(String me, String rival) {
    final mine = points(me);
    final theirs = points(rival);
    return DuelResult(
      match: DuelMatch(
        id: 'm',
        lessonId: 'L',
        game: 'sprint',
        mode: 'live',
        status: 'done',
        opponentId: rival,
        mine: mine,
        theirs: theirs,
        rounds: questions.length,
        winnerId: mine == theirs ? null : (mine > theirs ? me : rival),
        iWon: mine > theirs,
      ),
      gems: mine > theirs ? 5 : 0,
      draw: mine == theirs,
      rewardTaken: false,
    );
  }
}

/// قناةُ المباراة بين جهازين: ما يُرسله أحدُهما يصل الآخرَ بعد لحظة — أو لا
/// يصل، إن طُلب إسقاطُه.
class FakeTransport implements DuelLiveTransport {
  FakeTransport(this.server, this.me, this.rival);

  final FakeServer server;
  final String me;
  final String rival;
  DuelLiveController? peer;
  final List<String> sent = [];

  /// إشاراتٌ تُسقط في الطريق، لاختبار المهل الاحتياطية.
  final Set<String> drop = {};

  @override
  Future<List<DuelQuestion>?> claimPack(String matchId) async =>
      server.packAvailable ? server.questions : null;

  @override
  Future<DuelAnswerResult> answer({
    required String matchId,
    required int index,
    required int choice,
  }) =>
      server.answer(me, index, choice);

  @override
  Future<DuelResult> finish(String matchId) async => server.finish(me, rival);

  @override
  Future<void> cancel(String matchId) async => server.cancelled.add(me);

  @override
  bool send(String event, Map<String, Object?> payload) {
    sent.add(event);
    if (drop.contains(event)) return true;
    final target = peer;
    if (target != null) {
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
          answerAt: i % 4,
        ),
    ];

void main() {
  late FakeServer server;
  late FakeTransport hostLink;
  late FakeTransport guestLink;
  late DuelLiveController host;
  late DuelLiveController guest;

  void build({int questions = 3, bool guestPresent = true}) {
    server = FakeServer(pack(questions));
    hostLink = FakeTransport(server, 'h', 'g');
    guestLink = FakeTransport(server, 'g', 'h');
    host = DuelLiveController(
      transport: hostLink,
      matchId: 'm',
      myId: 'h',
      rivalId: 'g',
      isHost: true,
      questionWindow: const Duration(seconds: 5),
      revealHold: const Duration(milliseconds: 500),
      rivalWait: const Duration(seconds: 4),
    );
    guest = DuelLiveController(
      transport: guestLink,
      matchId: 'm',
      myId: 'g',
      rivalId: 'h',
      isHost: false,
      questionWindow: const Duration(seconds: 5),
      revealHold: const Duration(milliseconds: 500),
      rivalWait: const Duration(seconds: 4),
    );
    hostLink.peer = guestPresent ? guest : null;
    guestLink.peer = host;
  }

  Future<void> run(WidgetTester tester, Duration total) async {
    final steps = total.inMilliseconds ~/ 50;
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> startBoth(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    unawaited(host.start());
    unawaited(guest.start());
    await run(tester, const Duration(milliseconds: 300));
    expect(host.phase, DuelPhase.countdown);
    expect(guest.phase, DuelPhase.countdown);
    await run(tester, const Duration(seconds: 3));
    expect(host.phase, DuelPhase.question);
    expect(guest.phase, DuelPhase.question);
  }

  /// يُتخلّص من المحرّكين داخل الاختبار نفسه: فحصُ المؤقّتات المعلّقة يقع قبل
  /// tearDown، ومحرّكٌ حيٌّ يُبقي عدّادَه يدور.
  void scenario(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      await body(tester);
      host.dispose();
      guest.dispose();
      await tester.pump(const Duration(seconds: 5));
    });
  }

  scenario('الاثنان يدخلان فيبدأ العدُّ التنازليّ ثم السؤالُ الأوّل معاً',
      (tester) async {
    build();
    await startBoth(tester);
    expect(host.index, 0);
    expect(guest.index, 0);
  });

  scenario('أوّلُ صحيحٍ يكسب السؤال، ويُقفل عند زميله', (tester) async {
    build();
    await startBoth(tester);
    unawaited(host.pick(0)); // صحيح: answerAt = 0
    await run(tester, const Duration(milliseconds: 200));

    expect(host.winner, QuestionWinner.me);
    expect(host.myPoints, 10);
    expect(guest.winner, QuestionWinner.rival);
    expect(guest.rivalPoints, 10);
    expect(guest.phase, DuelPhase.reveal);

    // ومن جاء بعده لا يكسب شيئاً، ولو أصاب.
    unawaited(guest.pick(0));
    await run(tester, const Duration(milliseconds: 100));
    expect(guest.myPoints, 0);
  });

  scenario('جوابان صحيحان يكاد يتزامنان: الخادمُ يحكم بالأسبق', (tester) async {
    build();
    await startBoth(tester);
    server.answerDelay['h'] = const Duration(milliseconds: 120);
    server.answerDelay['g'] = const Duration(milliseconds: 20);
    unawaited(host.pick(0));
    unawaited(guest.pick(0));
    await run(tester, const Duration(milliseconds: 400));
    expect(server.winners[0], 'g');
    expect(guest.myPoints, 10);
    expect(host.myPoints, 0);
    expect(host.rivalPoints, 10);
    expect(host.pickedCorrect, isTrue, reason: 'أصاب، لكنّ زميله أسرع');
  });

  scenario('أخطأ الاثنان: يُكشف الجوابُ فوراً بلا انتظار الوقت', (tester) async {
    build();
    await startBoth(tester);
    unawaited(host.pick(1));
    unawaited(guest.pick(2));
    await run(tester, const Duration(milliseconds: 300));
    expect(host.phase, DuelPhase.reveal);
    expect(guest.phase, DuelPhase.reveal);
    expect(host.winner, QuestionWinner.none);
  });

  scenario('محاولةٌ واحدة: الضغطةُ الثانية لا تُرسل', (tester) async {
    build();
    await startBoth(tester);
    unawaited(host.pick(1));
    unawaited(host.pick(0));
    await run(tester, const Duration(milliseconds: 100));
    expect(host.picked, 1);
    expect(server.attempts.where((a) => a.startsWith('h:')), hasLength(1));
  });

  scenario('انتهى الوقت بلا جواب: يُكشف ويُنتقل للتالي معاً', (tester) async {
    build();
    await startBoth(tester);
    await run(tester, const Duration(seconds: 5, milliseconds: 200));
    expect(host.phase, DuelPhase.reveal);
    await run(tester, const Duration(milliseconds: 700));
    expect(host.index, 1);
    expect(guest.index, 1);
    expect(guest.phase, DuelPhase.question);
  });

  scenario('مباراةٌ كاملة: النتيجةُ من الخادم، والفائزُ بالنقاط', (tester) async {
    build(questions: 3);
    await startBoth(tester);
    for (var q = 0; q < 3; q++) {
      expect(host.index, q);
      // المضيفُ يكسب سؤالين، والضيفُ واحداً.
      if (q == 1) {
        unawaited(guest.pick(q % 4));
      } else {
        unawaited(host.pick(q % 4));
      }
      await run(tester, const Duration(milliseconds: 1200));
    }
    await run(tester, const Duration(milliseconds: 500));
    expect(host.phase, DuelPhase.result);
    expect(guest.phase, DuelPhase.result);
    expect(host.myPoints, 20);
    expect(host.rivalPoints, 10);
    expect(host.result!.gems, 5);
    expect(guest.result!.gems, 0);
    expect(guest.result!.match!.iWon, isFalse);
  });

  scenario('سقطت إشارةُ «التالي»: الضيفُ يمضي بمهلته', (tester) async {
    build();
    hostLink.drop.add('next');
    await startBoth(tester);
    unawaited(host.pick(0));
    await run(tester, const Duration(milliseconds: 600));
    expect(guest.phase, DuelPhase.reveal);
    await run(tester, const Duration(seconds: 3));
    expect(guest.index, 1);
    expect(guest.phase, DuelPhase.question);
  });

  scenario('الزميلُ لم يدخل: تفشل بسببها وتُلغى المباراة', (tester) async {
    build(guestPresent: false);
    await tester.pumpWidget(const SizedBox());
    unawaited(host.start());
    await run(tester, const Duration(seconds: 5));
    expect(host.phase, DuelPhase.failed);
    expect(host.failure, DuelFailureKind.rivalMissing);
    expect(server.cancelled, contains('h'));
  });

  scenario('لا أسئلة: تفشل ولا تُلعب', (tester) async {
    build();
    server.packAvailable = false;
    await tester.pumpWidget(const SizedBox());
    await host.start();
    expect(host.phase, DuelPhase.failed);
    expect(host.failure, DuelFailureKind.noQuestions);
    expect(server.cancelled, contains('h'));
  });

  scenario('غادر الزميلُ في المنتصف: يُكمل الباقي وحده', (tester) async {
    build(questions: 2);
    await startBoth(tester);
    guest.leave();
    guestLink.peer = null;
    hostLink.peer = null;
    await run(tester, const Duration(milliseconds: 100));
    expect(host.rivalLeft, isTrue);
    unawaited(host.pick(0));
    await run(tester, const Duration(milliseconds: 900));
    expect(host.index, 1);
    unawaited(host.pick(1));
    await run(tester, const Duration(milliseconds: 900));
    expect(host.phase, DuelPhase.result);
    expect(host.result!.gems, 5);
  });
}
