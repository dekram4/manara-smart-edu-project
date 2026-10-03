import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../models/duel_question.dart';
import 'student_duel_service.dart';

/// ما يحتاجه المحرّكُ من العالم: الخادمُ وقناةُ المباراة.
///
/// واجهةٌ لا الخدمةُ نفسها: فيُختبر المحرّكُ بخصمٍ مُحاكى وخادمٍ مُحاكى،
/// بلا شبكةٍ ولا مقابس.
abstract class DuelLiveTransport {
  Future<List<DuelQuestion>?> claimPack(String matchId);
  Future<DuelAnswerResult> answer({
    required String matchId,
    required int index,
    required int choice,
  });
  Future<DuelResult> finish(String matchId);
  Future<void> cancel(String matchId);
  bool send(String event, Map<String, Object?> payload);

  /// أدخل الغرفة في الخادم، وحالُها بعد دخولي.
  Future<DuelRoom> join(String matchId);

  /// حالُ الغرفة الآن.
  Future<DuelRoom> room(String matchId);
}

/// الخدمةُ الحقيقية.
class ServiceDuelTransport implements DuelLiveTransport {
  const ServiceDuelTransport(this.service);

  final StudentDuelService service;

  @override
  Future<List<DuelQuestion>?> claimPack(String matchId) =>
      service.claimPack(matchId);

  @override
  Future<DuelAnswerResult> answer({
    required String matchId,
    required int index,
    required int choice,
  }) =>
      service.answer(matchId: matchId, index: index, choice: choice);

  @override
  Future<DuelResult> finish(String matchId) => service.finish(matchId);

  @override
  Future<void> cancel(String matchId) async {
    await service.cancel(matchId);
  }

  @override
  Future<DuelRoom> join(String matchId) => service.join(matchId);

  @override
  Future<DuelRoom> room(String matchId) => service.room(matchId);

  @override
  bool send(String event, Map<String, Object?> payload) =>
      service.sendSignal(event, payload);
}

/// ثوانيَ السؤال — `DUEL_QUESTION_SECONDS` في الخادم.
const int duelQuestionSeconds = 10;

/// مراحلُ المباراة الحيّة.
enum DuelPhase {
  /// تُجهَّز الأسئلة.
  preparing,

  /// ننتظر الزميلَ أن يدخل.
  waitingRival,

  /// ٣، ٢، ١…
  countdown,

  /// السؤالُ مفتوح.
  question,

  /// حُسم السؤال: يُرى الجوابُ ومن كسبه.
  reveal,

  /// تُحسم المباراةُ في الخادم.
  finishing,

  /// النتيجة.
  result,

  /// تعذّر شيءٌ لا يُكمَل معه: انظر [DuelLiveController.failure].
  failed,
}

/// لماذا لم تُكمل المباراة.
///
///   nobodyAccepted — دعوتُ ولم يوافق أحدٌ في المهلة: يُلغى التحدي.
///   excluded       — وافقتُ لكنّ النزالَ بدأ بدوني (ردٌّ متأخّر).
enum DuelFailureKind {
  noQuestions,
  rivalMissing,
  nobodyAccepted,
  excluded,
  server
}

/// من كسب السؤالَ الحالي.
enum QuestionWinner { none, me, rival }

/// محرّكُ المبارزة الحيّة: السؤالُ نفسه للجميع في اللحظة نفسها، وأوّلُ صحيحٍ
/// يكسبه — بين لاعبَين أو ستّة.
///
/// ── من يلعب يقرّره الخادم ──
/// الداعي ومن وافق ينتظرون في الغرفة، ويسألون الخادمَ عن حالها. حين يردّ كلُّ
/// المدعوّين — أو تنتهي مهلةُ العشرين ثانية — يقول الخادمُ «ready» ومعه قائمةُ
/// اللاعبين وموعدُ أوّل سؤال. ومن لم يوافق في المهلة ليس في القائمة.
///
/// ── ولا يبدأ إلا والاثنان في الغرفة ──
/// كلُّ جهازٍ يدخل الغرفةَ في الخادم ثم يسأله عن حالها حتى يقول «دخلا» ويعطي
/// موعدَ أوّل سؤال. فلا عدٌّ تنازليٌّ ولا سؤالٌ عند أحدهما والآخرُ غائب — وكان
/// الضيفُ يبدأ وحده بمهلةٍ احتياطيةٍ إن فاتته إشارةُ «ابدأ». والموعدُ واحدٌ
/// للاثنين، منقولاً إلى ساعة كلّ جهاز (`DuelRoom.fromJson`).
///
/// ── وما بعد البدء عند الداعي ──
/// الداعي (المضيف) يُعلن السؤالَ التالي، والضيفُ يتبعه، وله مهلةٌ احتياطيةٌ إن
/// لم تصله الإشارة — فانقطاعُ بثٍّ واحد لا يعلّق مباراةً بدأت.
///
/// ── والأوّلُ يقرّره الخادم ──
/// المحرّكُ يُرسل الجوابَ ويعرض ما قاله الخادم: أصبتُ؟ وكنتُ الأوّل؟ ثم يبثّ
/// «كسبتُ السؤال» فيُقفل عند الزميل. ولا يحسم المحرّكُ الأسبقيةَ بما وصله من
/// بثّ — كلُّ جهازٍ كان سيرى نفسَه الأوّلَ أحياناً.
class DuelLiveController extends ChangeNotifier {
  DuelLiveController({
    required this.transport,
    required this.matchId,
    required this.myId,
    required this.rivalId,
    required this.isHost,
    List<String>? rivalIds,
    this.questionWindow = const Duration(seconds: duelQuestionSeconds),
    this.revealHold = const Duration(milliseconds: 1600),
    this.rivalWait = const Duration(seconds: 32),
    this.pointsPerQuestion = 10,
  }) : _rivals = [
          ...(rivalIds ?? [rivalId])
        ];

  final DuelLiveTransport transport;
  final String matchId;
  final String myId;

  /// أوّلُ منافس — للعرض في نزالٍ بين اثنين.
  final String rivalId;

  /// المنافسون: المدعوّون قبل الحسم، ثم من وافق منهم.
  List<String> _rivals;
  List<String> get rivals => List.unmodifiable(_rivals);

  /// غرفةُ الانتظار كما قالها الخادمُ آخرَ مرّة: من وافق ومن ينتظر.
  DuelRoom? _room;
  DuelRoom? get room => _room;

  String? _hostId;
  final bool isHost;
  final Duration questionWindow;
  final Duration revealHold;
  final Duration rivalWait;
  final int pointsPerQuestion;

  DuelPhase _phase = DuelPhase.preparing;
  DuelPhase get phase => _phase;

  DuelFailureKind? _failure;
  DuelFailureKind? get failure => _failure;

  List<DuelQuestion> _questions = const [];
  List<DuelQuestion> get questions => _questions;

  int _index = 0;
  int get index => _index;
  DuelQuestion? get question =>
      _index < _questions.length ? _questions[_index] : null;

  int _countdown = 0;
  int get countdown => _countdown;

  int _myPoints = 0;
  int get myPoints => _myPoints;

  /// نقاطُ كلِّ منافس.
  final Map<String, int> _points = {};
  int pointsOf(String id) => id == myId ? _myPoints : (_points[id] ?? 0);

  /// نقاطُ المتقدّم بين المنافسين — من أنافسه على القمّة.
  int get rivalPoints => _rivals.fold<int>(
      0, (best, id) => (_points[id] ?? 0) > best ? _points[id]! : best);

  /// المنافسُ المتقدّم. وعند التساوي أوّلُهم.
  String get leaderId {
    var leader = _rivals.isEmpty ? rivalId : _rivals.first;
    for (final id in _rivals) {
      if ((_points[id] ?? 0) > (_points[leader] ?? 0)) leader = id;
    }
    return leader;
  }

  /// الترتيبُ الحيّ: أنا والمنافسون، الأعلى أوّلاً، والمتساويان في مركزٍ واحد.
  List<({String id, int points, int rank})> get standings {
    final ids = [myId, ..._rivals];
    ids.sort((a, b) => pointsOf(b).compareTo(pointsOf(a)));
    final out = <({String id, int points, int rank})>[];
    for (var i = 0; i < ids.length; i++) {
      final points = pointsOf(ids[i]);
      final rank = i > 0 && out.last.points == points ? out.last.rank : i + 1;
      out.add((id: ids[i], points: points, rank: rank));
    }
    return out;
  }

  /// ما اخترتُه في السؤال الحالي.
  int? _picked;
  int? get picked => _picked;

  /// أصبتُ؟ `null` قبل أن يردّ الخادم.
  bool? _pickedCorrect;
  bool? get pickedCorrect => _pickedCorrect;

  /// الجوابُ يُرسل الآن: الخياراتُ مقفلةٌ حتى يردّ.
  bool _submitting = false;
  bool get submitting => _submitting;

  QuestionWinner _winner = QuestionWinner.none;
  QuestionWinner get winner => _winner;

  /// من كسب السؤالَ الحالي، إن كسبه منافس.
  String? _winnerId;
  String? get winnerId => _winnerId;

  /// من أجاب السؤالَ الحاليّ من المنافسين، ومن غادر النزال.
  final Set<String> _answered = {};
  final Set<String> _left = {};

  /// غادر المنافسون كلُّهم.
  bool get rivalLeft => _rivals.isNotEmpty && _rivals.every(_left.contains);

  /// آخرُ من غادر — يُذكر اسمُه.
  String? _lastLeft;
  String? get lastLeft => _lastLeft;

  DateTime? _deadline;
  Duration get timeLeft {
    final deadline = _deadline;
    if (deadline == null || _phase != DuelPhase.question) return Duration.zero;
    final left = deadline.difference(clock.now());
    return left.isNegative ? Duration.zero : left;
  }

  DuelResult? _result;
  DuelResult? get result => _result;

  /// موعدُ أوّل سؤال كما أعطاه الخادم، بساعة هذا الجهاز.
  DateTime? _startAt;

  /// الطرفان في الغرفة والنزالُ بدأ أو يبدأ: الدردشةُ تُفتح بهذا وحده.
  bool get roomOpen => switch (_phase) {
        DuelPhase.countdown ||
        DuelPhase.question ||
        DuelPhase.reveal ||
        DuelPhase.finishing ||
        DuelPhase.result =>
          true,
        _ => false,
      };

  Timer? _roomPoll;
  bool _polling = false;
  Timer? _tick;
  Timer? _rivalTimeout;
  Timer? _hold;
  Timer? _fallback;
  bool _disposed = false;

  /// يبدأ: يجهّز الأسئلة، ويعلن أنّي هنا، وينتظر الزميل.
  Future<void> start() async {
    _set(DuelPhase.preparing);
    List<DuelQuestion>? pack;
    try {
      pack = await transport.claimPack(matchId);
    } catch (_) {
      pack = null;
    }
    if (_disposed) return;
    if (pack == null || pack.isEmpty) {
      _fail(DuelFailureKind.noQuestions);
      unawaited(transport.cancel(matchId));
      return;
    }
    _questions = pack;
    _set(DuelPhase.waitingRival);

    // «دخلتُ» على القناة تُسرّع زميلي إلى سؤال الخادم، ولا تُغني عنه.
    transport.send('ready', {'id': myId});
    DuelRoom? room;
    try {
      room = await transport.join(matchId);
    } catch (_) {
      room = null;
    }
    if (_disposed) return;
    _onRoom(room);
    if (_phase != DuelPhase.waitingRival) return;

    _roomPoll = Timer.periodic(const Duration(milliseconds: 700), (_) {
      unawaited(_checkRoom());
    });
    _rivalTimeout = Timer(rivalWait, () {
      if (_phase != DuelPhase.waitingRival) return;
      _fail(DuelFailureKind.rivalMissing);
      unawaited(transport.cancel(matchId));
    });
  }

  Future<void> _checkRoom() async {
    if (_polling || _phase != DuelPhase.waitingRival) return;
    _polling = true;
    DuelRoom? room;
    try {
      room = await transport.room(matchId);
    } catch (_) {
      room = null;
    } finally {
      _polling = false;
    }
    if (!_disposed) _onRoom(room);
  }

  /// ما قاله الخادمُ عن الغرفة.
  void _onRoom(DuelRoom? room) {
    if (room == null || _phase != DuelPhase.waitingRival) return;
    _room = room;
    _hostId = room.hostId ?? _hostId;
    switch (room.phase) {
      case DuelRoomPhase.ready:
        // ── من يلعب: من في القائمة ──
        if (room.roster.isNotEmpty) {
          if (!room.roster.contains(myId)) {
            _fail(DuelFailureKind.excluded);
            return;
          }
          _rivals = [
            for (final id in room.roster)
              if (id != myId) id
          ];
        }
        final startAt = room.startAt;
        if (startAt != null) _beginCountdown(startAt);
      case DuelRoomPhase.expired:
      case DuelRoomPhase.done:
        // الداعي: لم يوافق أحد. والمدعوّ: أُلغي التحدي.
        _fail(isHost
            ? DuelFailureKind.nobodyAccepted
            : DuelFailureKind.rivalMissing);
      case DuelRoomPhase.invited:
      case DuelRoomPhase.accepted:
        notifyListeners();
    }
  }

  /// إشارةٌ وصلت على قناة المباراة.
  void onSignal(String event, Map<String, dynamic> payload) {
    if (_disposed) return;
    final from = payload['id'] ?? payload['by'];
    if (from is String && from == myId) return;
    if (from is! String) return;
    switch (event) {
      case 'ready':
        unawaited(_checkRoom());
      case 'won':
        final at = payload['index'];
        if (at is int && at == _index && _rivals.contains(from)) {
          _rivalWon(from);
        }
      case 'answered':
        final at = payload['index'];
        if (at is int && at == _index && _rivals.contains(from)) {
          _answered.add(from);
          _maybeAllAnswered();
        }
      case 'next':
        final at = payload['index'];
        if (!isHost && at is int && _questions.isNotEmpty) _goTo(at);
      case 'left':
        if (_rivals.contains(from) && _left.add(from)) {
          _lastLeft = from;
          _maybeAllAnswered();
          notifyListeners();
        }
    }
  }

  /// العدُّ إلى موعد الخادم. ولا سؤالَ قبله عند أحد.
  void _beginCountdown(DateTime startAt) {
    if (_phase != DuelPhase.waitingRival) return;
    _roomPoll?.cancel();
    _rivalTimeout?.cancel();
    _startAt = startAt;
    _countdown = _secondsToStart();
    _set(DuelPhase.countdown);
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final left = _secondsToStart();
      if (left <= 0) {
        timer.cancel();
        _openQuestion(0);
      } else if (left != _countdown) {
        _countdown = left;
        notifyListeners();
      }
    });
  }

  int _secondsToStart() {
    final startAt = _startAt;
    if (startAt == null) return 0;
    final left = startAt.difference(clock.now()).inMilliseconds;
    return left <= 0 ? 0 : (left / 1000).ceil();
  }

  void _openQuestion(int at) {
    _hold?.cancel();
    _fallback?.cancel();
    _index = at;
    _picked = null;
    _pickedCorrect = null;
    _submitting = false;
    _winner = QuestionWinner.none;
    _winnerId = null;
    _answered.clear();
    _deadline = clock.now().add(questionWindow);
    _set(DuelPhase.question);
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_phase != DuelPhase.question) return;
      if (timeLeft == Duration.zero) {
        _reveal();
      } else {
        notifyListeners();
      }
    });
  }

  /// يختار الطالبُ جواباً. محاولةٌ واحدةٌ لكل سؤال.
  Future<void> pick(int choice) async {
    if (_phase != DuelPhase.question || _picked != null || _submitting) return;
    final at = _index;
    _picked = choice;
    _submitting = true;
    notifyListeners();
    transport.send('answered', {'id': myId, 'index': at});

    DuelAnswerResult? answer;
    try {
      answer =
          await transport.answer(matchId: matchId, index: at, choice: choice);
    } catch (_) {
      answer = null;
    }
    if (_disposed || at != _index) return;
    _submitting = false;
    if (answer == null) {
      // الخادمُ لم يردّ: لا نقاطَ تُدّعى، ويُكمل السؤالُ وقتَه.
      _pickedCorrect = null;
      notifyListeners();
      _maybeAllAnswered();
      return;
    }
    _pickedCorrect = answer.correct;
    if (answer.won && _winner == QuestionWinner.none) {
      _winner = QuestionWinner.me;
      _myPoints += answer.points > 0 ? answer.points : pointsPerQuestion;
      transport.send('won', {'by': myId, 'index': at});
      _reveal();
      return;
    }
    notifyListeners();
    _maybeAllAnswered();
  }

  void _rivalWon(String id) {
    if (_winner != QuestionWinner.none) return;
    _winner = QuestionWinner.rival;
    _winnerId = id;
    _points[id] = (_points[id] ?? 0) + pointsPerQuestion;
    if (_phase == DuelPhase.question) {
      _reveal();
    } else {
      notifyListeners();
    }
  }

  /// أجاب الجميعُ ولم يكسب أحد: لا معنى لانتظار الوقت كلّه.
  void _maybeAllAnswered() {
    if (_phase != DuelPhase.question) return;
    final everyone =
        _rivals.every((id) => _answered.contains(id) || _left.contains(id));
    if (_picked != null && !_submitting && everyone) _reveal();
  }

  /// غادر الداعي: لا أحدَ يُعلن «التالي»، فيمضي كلٌّ بساعته.
  bool get _hostGone => _hostId != null && _left.contains(_hostId);

  void _reveal() {
    if (_phase != DuelPhase.question) return;
    _tick?.cancel();
    _set(DuelPhase.reveal);
    final at = _index;
    _hold?.cancel();
    _hold = Timer(revealHold, () {
      if (_phase != DuelPhase.reveal || at != _index) return;
      if (isHost || rivalLeft || _hostGone) {
        final next = at + 1;
        if (isHost && !rivalLeft) {
          transport.send('next', {'id': myId, 'index': next});
        }
        _goTo(next);
      } else {
        // الضيفُ ينتظر «التالي»، وله مهلةٌ إن فاتته.
        _fallback?.cancel();
        _fallback = Timer(const Duration(milliseconds: 2500), () {
          if (_phase == DuelPhase.reveal && at == _index) _goTo(at + 1);
        });
      }
    });
  }

  void _goTo(int at) {
    if (_phase == DuelPhase.finishing || _phase == DuelPhase.result) return;
    if (at >= _questions.length) {
      unawaited(_finish());
      return;
    }
    if (at < _index || (at == _index && _phase == DuelPhase.question)) return;
    _openQuestion(at);
  }

  Future<void> _finish() async {
    if (_phase == DuelPhase.finishing || _phase == DuelPhase.result) return;
    _tick?.cancel();
    _hold?.cancel();
    _fallback?.cancel();
    _set(DuelPhase.finishing);
    DuelResult? result;
    for (var attempt = 0; attempt < 3 && result == null; attempt++) {
      try {
        result = await transport.finish(matchId);
      } catch (_) {
        if (_disposed) return;
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
    }
    if (_disposed) return;
    if (result == null) {
      _fail(DuelFailureKind.server);
      return;
    }
    _result = result;
    // النقاطُ النهائيةُ من الخادم: ما عُدّ محلياً من البثّ قد يفوته إشارة.
    final match = result.match;
    if (match != null) {
      _myPoints = match.mine ?? _myPoints;
      for (final player in match.players) {
        if (player.id != myId && player.score != null) {
          _points[player.id] = player.score!;
        }
      }
      // خادمٌ أقدمُ بلا قائمة: نتيجةُ المنافس الواحد.
      if (match.players.isEmpty && match.theirs != null) {
        _points[rivalId] = match.theirs!;
      }
    }
    _set(DuelPhase.result);
  }

  /// يغادر الطالبُ قبل النهاية: يُبلَّغ زميلُه، وتُلغى المباراةُ إن لم تبدأ.
  void leave() {
    if (_phase == DuelPhase.result || _phase == DuelPhase.failed) return;
    transport.send('left', {'id': myId});
    if (_phase == DuelPhase.preparing || _phase == DuelPhase.waitingRival) {
      unawaited(transport.cancel(matchId));
    }
  }

  void _fail(DuelFailureKind kind) {
    _failure = kind;
    _tick?.cancel();
    _roomPoll?.cancel();
    _rivalTimeout?.cancel();
    _hold?.cancel();
    _fallback?.cancel();
    _set(DuelPhase.failed);
  }

  void _set(DuelPhase phase) {
    _phase = phase;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _tick?.cancel();
    _roomPoll?.cancel();
    _rivalTimeout?.cancel();
    _hold?.cancel();
    _fallback?.cancel();
    super.dispose();
  }
}
